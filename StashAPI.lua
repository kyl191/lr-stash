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

    local postUrl = string.format("https://www.deviantart.com/oauth2/token?grant_type=authorization_code&client_id=%i&client_secret=%s&code=%s", Auth.client_id, Auth.client_secret,code)

    local error = "contacting the sta.sh server to get access"

    local token = Utils.getJSON(postUrl, error)

    return token

end

--------------------------------------------------------------------------------

function StashAPI.refreshAuth()

    -- Refresh the auth token
    -- getToken needs the initial authorization code from the user, an has a different URL (specifically, the grant_type), so it's split off into a separate function

    local postUrl = string.format("https://www.deviantart.com/oauth2/token?grant_type=refresh_token&client_id=%i&client_secret=%s&refresh_token=%s", Auth.client_id, Auth.client_secret, prefs.refresh_token)
    local error = "renewing the authorization"

    local token = Utils.getJSON(postUrl, error)

    StashAPI.processToken( token, nil )

end

--------------------------------------------------------------------------------

function StashAPI.processToken( token, context )

    -- Token gets to here after passing through getResult, with the attendant network error checking
    -- So no need for network errors
    -- Also, one of the checks was to see if the status was 'error', so the default case that we assume is that status == success

    -- Setup the various plugin preferences
    if token.status == "success" then
        prefs.access_token = token.access_token
        prefs.refresh_token = token.refresh_token
        prefs.expire = import 'LrDate'.currentTime() + token.expires_in

    -- If the token has anything other than status = success, oops, we've got a problem
    -- Function context comes from StashUser.login
    else
        import 'LrDialogs'.attachErrorDialogToFunctionContext(context)
        LrErrors.throwUserError( "Unable to authenticate" )
    end

end

--------------------------------------------------------------------------------

function StashAPI.uploadPhoto( params )

    -- Prepare to upload.
    -- Make sure that we got a table of parameters
    assert( type( params ) == 'table', 'StashAPI.uploadPhoto: params must be a table' )

    local postUrl = 'https://www.deviantart.com/api/oauth2/stash/submit?token='.. prefs.access_token
    logger:info( 'Uploading photo', params.filePath )

    -- Identification on Sta.sh
    --- Since folder support is still buggy, if we've got the stash id, just use that.
    --- Otherwise, use the folderid if we're uploading a new photo to a known collection
    --- Last resort, new collection, send the foldername

    if not (params.stashid == nil) then
        postUrl = postUrl .. '&stashid=' .. params.stashid
    else if not (params.foldername == nil) then
        postUrl = postUrl .. '&folder=' .. Utils.urlEncode(params.foldername)
    -- I'm just completely ignoring the folderId, because it's horribly *BROKEN* on sta.sh...
    -- else if not (params.folderid == nil) then
    --    postUrl = postUrl .. '&folderid=' .. params.folderid
    end

    -- Overwrite metadata if the user says yes, or there's no stash id (which means the photo hasn't been uploaded)
    if params.overwriteMetadata or (params.stashid == nil) then

        -- If we're overwriting, there might be a case where the user removes everything in Lightroom,
        -- so force an overwrite, even if the variables are empty by appending an empty POST field.
        -- But by not appending a value UNLESS there *is* a value, we avoid a "concating a nil" error
        -- Reported at http://comments.deviantart.com/1/278275666/2450524379
        postUrl = postUrl .. '&title='
        -- We might have a title, so append that
        if not (params.title == nil or #params.title == 0) then
            postUrl = postUrl .. Utils.urlEncode(params.title)
        end

        postUrl = postUrl .. '&keywords='
        -- Append the tags if present
        if not (params.tags == nil or #params.tags == 0) then
            postUrl = postUrl .. Utils.urlEncode(params.tags)
        end

        postUrl = postUrl .. '&artist_comments='
        -- Append the description
        -- Though it's short, so maybe a Memo/long description panel in Lightroom?
        if not (params.description == nil or #params.description == 0) then
            postUrl = postUrl .. Utils.urlEncode(params.description)
        end
    end

    -- Add the photo itself
    local mimeChunks = {}

    local filePath = assert( params.filePath )

    local fileName = LrPathUtils.leafName( filePath )

    mimeChunks[ #mimeChunks + 1 ] = { name = 'photo', fileName = fileName, filePath = filePath, contentType = 'application/octet-stream' }

    -- Before uploading, check to make sure that there's enough space to upload
    local space = StashAPI.getRemainingSpace()
    local fileAttribs = import 'LrFileUtils'.fileAttributes(filePath)

    if tonumber(space) < tonumber(fileAttribs.fileSize) then
        LrErrors.throwUserError( "Not enough space in Sta.sh to upload the file!" )
    end

    -- Post it and wait for confirmation.
    logger:info("Uploading photo to: " .. postUrl)

    local result, headers = LrHttp.postMultipart( postUrl, mimeChunks )

    result = Utils.checkResponse(result, headers, postUrl)

    if result.status and result.status == "error" then

        if result.from == "lightroom" then
            -- We can't do much about a Lightroom error.
            LrErrors.throwUserError ("Lightroom network error while uploading to Sta.sh: " .. result.code .. "\n" .. result.description)

        elseif result.from == "server" then
            -- However, a server error? That we need to check - Sta.sh returns an error code if something goes wrong.
            -- We can recover from certain errors.

            -- If it's an empty result, reset and try again
            if result.code == "empty" then

                -- But check to see if this is a retry first, and die if so.
                if params.retry and params.retry == "empty" then
                    logger:error("Got an empty result from Sta.sh again, giving up.")
                    LrErrors.throwUserError("Sorry, but Sta.sh is just giving me a blank file, even though I re-tried twice. I'm giving up now. :(")
                else
                    params.retry = "empty"
                    return StashAPI.uploadPhoto(params)
                end

            end

            local validJSON, message = LrTasks.pcall( function() return JSON:decode(result.payload) end)

            -- If it's valid JSON, try to identify the error and reupload.
            if validJSON then
                json = message

                if json.error ~= nil and not params.retry then
                    logger:error("Error from Sta.sh:")
                    Utils.logTable(json, "Parsed JSON from Sta.sh, 1st try at uploading photo")

                    if json.error == "internal_error_item" or json.error == "invalid_stashid" then
                        -- internal_error_item seems to mean we tried uploading to a deleted stashid
                        -- Checking invalid_stashid too, since that seems to be another likely one to do with stashid
                        params.stashid = nil
                        params.retry = json.error
                        logger:info('Something wrong with the stashid, retrying with a blank id.')
                        return StashAPI.uploadPhoto(params)

                    elseif json.error == "internal_error_missing_folder" or json.error == "invalid_folderid" or json.error == "internal_error_missing_metadata" then
                        -- internal_error_missing_folder seems to indicate something's gone awry with the folder, so reupload with a different folder id
                        -- Same for invalid_folderid and internal_error_missing_metadata too
                        params.folderid = nil
                        params.retry = json.error
                        logger:info('Something wrong with the folderid, retrying with a blank id.')
                        return StashAPI.uploadPhoto(params)

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
                    LrErrors.throwUserError( "Error uploading to Sta.sh, even after retrying. Last error was: \n" .. json.error .. " : \n" .. json.error_description)

                end

            -- If it's not valid JSON, throw the error up to the user.
            else
                LrErrors.throwUserError ("Sta.sh gave us a server error, and I'm not sure how to handle it, so I'm just giving up: " .. result.code)
            end
        end

    end

    local ok, json = LrTasks.pcall(function() return JSON:decode(result) end)

    -- And of course, if there's no error, return the parsed JSON object
    return json

end

--------------------------------------------------------------------------------

function StashAPI.getUsername()

    -- Get the user's dA username in the form of ~kyl191 (the dA symbol, and the actual name)

    local postUrl = "https://www.deviantart.com/api/oauth2/user/whoami?token=" .. prefs.access_token
    local error = "retriving user details"

    local token = Utils.getJSON(postUrl, error)

    return { symbol = "", name = token.username }

end

--------------------------------------------------------------------------------

function StashAPI.renameFolder(folderid, newName)

    -- Rename a folder after escaping characters in the new folder name.
    local postUrl = "https://www.deviantart.com/api/oauth2/stash/folder?token=" .. prefs.access_token .. "&folder=" .. Utils.urlEncode(newName) .. "&folderid=" .. folderid
    local error = "renaming a folder"

    local token = Utils.getJSON(postUrl, error)
    return token.status

end


--------------------------------------------------------------------------------

function StashAPI.getRemainingSpace()

    -- Get the amount of space left in the sta.sh quota for the user

    local postUrl = "https://www.deviantart.com/api/oauth2/stash/space?token=" .. prefs.access_token
    local error = "getting amount of space in Sta.sh"

    local token = Utils.getJSON(postUrl, error)

    return token.available_space

end

--------------------------------------------------------------------------------

