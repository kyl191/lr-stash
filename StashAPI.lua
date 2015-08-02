--[[----------------------------------------------------------------------------

StashAPI.lua
Common code to initiate Stash API requests

------------------------------------------------------------------------------]]

    -- Lightroom SDK
local LrErrors = import 'LrErrors'
local LrHttp = import 'LrHttp'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'

local prefs = import 'LrPrefs'.prefsForPlugin()
local logger = import 'LrLogger'( 'Stash' )

require 'Utils'
local Auth = require 'Auth'
JSON = (loadfile (LrPathUtils.child(_PLUGIN.path, "json.lua")))()

--============================================================================--

StashAPI = {}

--------------------------------------------------------------------------------

function StashAPI.getToken(code)

    -- Get the initial authorization token.
    -- ONLY called by StashUser.login

    local url = "https://www.deviantart.com/oauth2/token?grant_type=authorization_code&redirect_uri=http://oauth2.kyl191.net/"
    local args = {url = url,
                    usePost = true,
                    body = {
                        client_id = Auth.client_id,
                        client_secret = Auth.client_secret,
                        code = code
                    }
                }
    logger:debug("Calling StashAPI.getToken")
    local success, token = LrTasks.pcall(StashAPI.getJSON, args)
    logger:debug(token)
    if success then
        return token
    else
        LrErrors.throwUserError(string.format("Error contacting the sta.sh server to get access: %s", token))
    end

end

--------------------------------------------------------------------------------

function StashAPI.refreshAuth()

    -- Refresh the auth token
    -- getToken needs the initial authorization code from the user, an has a different URL (specifically, the grant_type), so it's split off into a separate function

    local url = string.format("https://www.deviantart.com/oauth2/token?grant_type=refresh_token&client_id=%i&client_secret=%s&refresh_token=%s",
        Auth.client_id,
        Auth.client_secret,
        prefs.refresh_token)
    local success, token = LrTasks.pcall(StashAPI.getJSON, url)
    if success then
        StashAPI.processToken(token)
    else
        LrErrors.throwUserError(string.format("Error renewing the authorization token: %s", token))
    end
end

--------------------------------------------------------------------------------

function StashAPI.processToken(token)

    -- Token gets to here after passing through getResult, with the attendant network error checking
    -- So no need for network errors
    -- Also, one of the checks was to see if the status was 'error', so the default case that we assume is that status == success

    -- Setup the various plugin preferences
    prefs.access_token = token.access_token
    prefs.refresh_token = token.refresh_token
    prefs.expire = import 'LrDate'.currentTime() + token.expires_in

end

--------------------------------------------------------------------------------

function StashAPI.uploadPhoto(params)

    -- Prepare to upload.
    -- Make sure that we got a table of parameters
    assert(type(params) == 'table', 'StashAPI.uploadPhoto: params must be a table')
    Utils.logTable(params)
    local postUrl = string.format('https://www.deviantart.com/api/v1/oauth2/stash/submit?token=%s', prefs.access_token)
    logger:info('Uploading photo', params.filePath)

    -- Identification on Sta.sh
    --- Since folder support is still buggy, if we've got the stash id, just use that.
    --- Otherwise, use the stackId if we're uploading a new photo to a known collection
    --- Last resort, new collection, send the foldername
    content = {}
    if params.itemId ~= nil then
        if StashAPI.verifyItemExists(params.itemId) then
            table.insert(content, {name='itemid', value=params.itemId})
        end
    end
    if params.stackName ~= nil then
        table.insert(content, {name='stack', value=Utils.urlEncode(params.stackName)})
    end
    if params.stackId ~= nil then
        if StashAPI.verifyStackExists(params.stackId) then
            table.insert(content, {name='stackid', value=params.stackId})
        end
    end

    -- Overwrite metadata if the user says yes, or there's no stash id (which means the photo hasn't been uploaded)
    if params.overwriteMetadata or (params.itemId == nil) then

        -- If we're overwriting, there might be a case where the user removes everything in Lightroom,
        -- so force an overwrite, even if the variables are empty by appending an empty POST field.
        -- But by not appending a value UNLESS there *is* a value, we avoid a "concating a nil" error
        -- Reported at http://comments.deviantart.com/1/278275666/2450524379

        table.insert(content, {name='title', value=Utils.urlEncode(params.title)})
        table.insert(content, {name='tags', value=Utils.urlEncode(params.tags)})
        table.insert(content, {name='artist_comments', value=Utils.urlEncode(params.description)})
    end

    -- Add the photo itself
    local filePath = assert(params.filePath)
    local fileName = LrPathUtils.leafName(filePath)
    table.insert(content, {name = 'photo',
                    fileName = fileName,
                    filePath = filePath,
                    contentType = 'application/octet-stream' })

    -- Before uploading, check to make sure that there's enough space to upload
    local space = StashAPI.getRemainingSpace()
    local fileAttribs = import 'LrFileUtils'.fileAttributes(filePath)

    if tonumber(space) < tonumber(fileAttribs.fileSize) then
        LrErrors.throwUserError("Not enough space in Sta.sh to upload the file!")
    end

    -- Post it and wait for confirmation.
    logger:info(string.format("Uploading photo to: %s", postUrl))
    logger:info("With form fields:")
    Utils.logTable(content)
    local result, headers = LrHttp.postMultipart(postUrl, content)

    if Utils.isLightroomError(headers) then
        local lr_error = Utils.getLightroomError(headers)
        LrErrors.throwUserError(lr_error.message)

    elseif Utils.isServerError(headers) and data == nil then
        if params.retry and params.retry == "empty" then
            logger:error("Got an empty result from Sta.sh twice, giving up.")
            LrErrors.throwUserError("Sorry, but Sta.sh is just giving me a blank file, even though I re-tried twice. I'm giving up now. :(")
        else
            params.retry = "empty"
            return StashAPI.uploadPhoto(params)
        end

    elseif Utils.isServerError(headers) and data ~= nil then
        local isValid, json = LrTasks.pcall(function() return JSON:decode(data) end)
        if not isValid then
            logger:error("Got an error from sta.sh that isn't JSON-formatted")
            Utils.logTable(headers)
            Utils.logTable(json)
            logger:info(string.format("Data recieved: %s", data))
            LrErrors.throwUserError(string.format("Sta.sh gave us a server error, but isn't saying what the error is: %d",
                                                    headers.code))
        else
            if json.error == nil then
                Utils.logTable(json, "This makes no sense, got back valid JSON but with no indication of an error")
            elseif not params.retry then
                logger:warn("Error from Sta.sh:")
                Utils.logTable(json, "Parsed JSON from Sta.sh, 1st try at uploading photo")

                if json.error == "invalid_request" and json.error_code == 1 then
                    if params.itemId ~= nil  then
                        -- Most common error I'm seeing is item was deleted server side
                        -- Try clearing our item ID & continuing
                        params.itemId = nil
                        logger:info('Something wrong with the item id, retrying with a blank id.')
                        return StashAPI.uploadPhoto(params)

                    else
                        -- item id is nill, only other thing is the stack not being found
                        params.stackId = nil
                        params.retry = json.error
                        logger:info('Something wrong with the stack id, retrying with a blank id.')
                        return StashAPI.uploadPhoto(params)
                    end

                else
                    -- Haven't seen any other errors yet.
                    -- Try uploading again.
                    params.retry = json.error
                    logger:info("Got a JSON error I haven't seen before, automatically retrying")
                    return StashAPI.uploadPhoto(params)
                end

            elseif json.error ~= nil and params.retry then
                logger:error("Retried once, still got an error. Giving up.")
                Utils.logTable(json, "Parsed JSON from Sta.sh, 2nd try at uploading photo")
                local error = string.format("Error uploading to Sta.sh, even after retrying. Last error was: \n %s: \n %s",
                    json.error,
                    json.error_description)
                LrErrors.throwUserError(error)
            end
        end
    end

    local ok, json = LrTasks.pcall(function() return JSON:decode(result) end)

    -- And of course, if there's no error, return the parsed JSON object
    return json

end

--------------------------------------------------------------------------------
function StashAPI.verifyItemExists(itemId)
    local url = string.format("https://www.deviantart.com/api/v1/oauth2/stash/item/%s?token=%s",
                        itemId,
                        prefs.access_token)
    logger:debug(string.format("Verifying item %s exists", itemId))
    local success = LrTasks.pcall(StashAPI.getJSON, url)
    return success
end

function StashAPI.verifyStackExists(stackId)
    local url = string.format("https://www.deviantart.com/api/v1/oauth2/stash/%s?token=%s",
                        stackId,
                        prefs.access_token)
    logger:debug(string.format("Verifying stack %s exists", stackId))
    local success = LrTasks.pcall(StashAPI.getJSON, url)
    return success
end

function StashAPI.getJSON(args)
    data = Utils.getJSON(args)
    -- JSON was parsed successfully, now check if the server returned an error message in JSON.
    if data.status and data.status == "error" then
        local err_message = string.format("StashAPI: error %s from %s: %s", data.error, url, data.error_description)
        logger:error(err_message)
        Utils.logTable(data, "Result from JSON data")
        error(err_message)
    else
        return data
    end
end

function StashAPI.getUsername()

    -- Get the user's dA username in the form of ~kyl191 (the dA symbol, and the actual name)

    local postUrl = "https://www.deviantart.com/api/oauth2/user/whoami?token=" .. prefs.access_token
    local error = "retriving user details"

    local token = Utils.getJSON(postUrl, error)

    return { symbol = "", name = token.username }

end

--------------------------------------------------------------------------------

function StashAPI.renameFolder(stackId, newName)

    -- Rename a folder after escaping characters in the new folder name.
    local url = string.format("https://www.deviantart.com/api/v1/oauth2/stash/update/%s?token=%s",
                                stackId,
                                prefs.access_token)
    local args = {url = url,
                    usePost = true,
                    body = {title = newName}
                }
    local success, data = LrTasks.pcall(StashAPI.getJSON, args)
    if success then
        return data.status
    else
        LrErrors.throwUserError(string.format("Error renaming a folder: %s", data))
    end

end


--------------------------------------------------------------------------------

function StashAPI.getRemainingSpace()

    -- Get the amount of space left in the sta.sh quota for the user

    local url = string.format("https://www.deviantart.com/api/v1/oauth2/stash/space?token=%s", prefs.access_token)

    local success, data = LrTasks.pcall(StashAPI.getJSON, url)
    if success then
        return data.available_space
    else
        LrErrors.throwUserError(string.format("Error getting amount of space in Sta.sh: %s", data))
    end

end

--------------------------------------------------------------------------------

