--[[----------------------------------------------------------------------------

Utils.lua
Common code for Lightroom plugins

------------------------------------------------------------------------------]]
local LrMD5 = import 'LrMD5'
local LrFileUtils = import 'LrFileUtils'
local LrFunctionContext = import 'LrFunctionContext'
local logger = import 'LrLogger'( 'Stash' )
logger:enable("logfile")

local LrPathUtils = import 'LrPathUtils'

local LrHttp = import 'LrHttp'
local LrErrors = import 'LrErrors'

--------------------------------------------------------------------------------
JSON = (loadfile (LrPathUtils.child(_PLUGIN.path, "json.lua")))()

--------------------------------------------------------------------------------

Utils = {}
--------------------------------------------------------------------------------
-- variation of http://forums.adobe.com/message/3146133#3146133
function Utils.logTable(x, label)
    local function dump1 (x, indent, visited)
        if type (x) ~= "table" then
            logger:info (string.rep (" ", indent) .. tostring (x))
            return
        end

        visited [x] = true
        if indent == 0 then
            logger:info (string.rep (" ", indent) .. tostring (x))
        end
        for k, v in pairs (x) do
            logger:info (string.rep (" ", indent + 4) .. tostring (k) .. " = " ..
                    tostring (v))
            if type (v) == "table" and not visited [v] then
                dump1 (v, indent + 4, visited)
            end
        end
    end

    if label ~= nil then
        logger:info (label .. ":")
    end

    dump1 (x, 0, {})
end

--------------------------------------------------------------------------------

function Utils.md5Files(path)

    logger:info("Running md5files for directory " .. path)
    local digests = {}
    for filePath in LrFileUtils.recursiveFiles( path ) do
        local file = assert(io.open(filePath, "rb"))
        local data = file:read("*all")

        local md5sum = LrMD5.digest(data)
        digests[#digests+1] = {filePath = LrPathUtils.makeRelative(filePath, path), md5 = md5sum}
    end

    return digests
end

--------------------------------------------------------------------------------

function Utils.getJSON( postUrl, errorMessage )

    data = Utils.networkComms( "post", postUrl )

    logger:info("getJSON: Got data back from networkComms.")

    -- We can't do anything about a Lightroom transport error!
    if data.status and data.status == "error" and data.from == "lightroom" then
        logger:error(postUrl .. " was supposed to return JSON, but didn't.")
        LrErrors.throwUserError("Oh dear. There was a problem " .. errorMessage .. ". \nWe were supposed to get JSON back from the server, but Lightroom had a problem:\n" .. data.description)
    end

    -- Other problem is a server error. Sta.sh tries to return errors in JSON, so try parsing it.
    -- Other systems should *also* return JSON - this is getJSON after all.
    logger:info("About to try parsing the supposed returned JSON: " .. data)
    local ok, decode = LrFunctionContext.pcallWithContext("parsing json", function(context, data)
        context:addFailureHandler( function(status,message)
            logger:error("Error parsing JSON: " .. message)
        end)
        context:addOperationTitleForError( "Error parsing a JSON response" )

        logger:info("Got the data... " .. data)
        local json = JSON:decode(data)
        return json
    end,
        data)

    -- If the JSON parsing failed, throw an error.
    if not ok then
        logger.error("getJSON: JSON error for url : ".. postUrl .. "\n" .. decode)
        LrErrors.throwUserError("Oh dear. We were supposed to get JSON back from the server when " .. errorMessage .. ", but got some garbage instead. Wait a while, and try again.")
    else
        -- Otherwise, try parsing the error.
        -- Admittedly, this is skewed towards Sta.sh, with the checking of status == error, but this is the primary target right now...
        if decode.status and decode.status == "error" then
            logger:error("getJSON: JSON error from " .. postUrl)
            Utils.logTable(decode, "Result from JSON decode")
            LrErrors.throwUserError("Oh dear. The server didn't like us " .. errorMessage .. ", it said " .. decode.error .. ", which apparently means \"".. decode.error_description .. "\". \nThis might be a permanent error if you repeatedly get this message.")
        else
            logger:info("Assuming getJSON was a success for " .. postUrl)
            return decode
        end
    end

end

--------------------------------------------------------------------------------

function Utils.networkComms( action, url )

    logger:info("Called Utils.networkComms for " .. url)
    local payload, headers = nil
    -- Do the request
    if action == "post" then
        payload, headers = LrHttp.post(url, "")
    else
        payload, headers = LrHttp.get(url)
    end

    return Utils.checkResponse( payload, headers, url )

end
--------------------------------------------------------------------------------

function Utils.checkResponse( data, headers, url )

    -- If headers.error is set, that means Lightroom had an error.
    if headers and headers.error then
        logger:error("checkResponse: Lightroom network error for url: " .. url)
        Utils.logTable(headers)
        return { status = "error", from = "lightroom", code = headers.error.errorCode, description = headers.error.name }
    end

    -- Alternatively, the server could throw back an error.
    -- Only return data if we're sure
    if headers and tonumber(headers.status) > 299 then
        logger:error("checkResponse: Server error: " .. headers.status .. "for url: " .. url)
        Utils.logTable(headers)
        logger:info(data)
        return { status = "error", from = "server", code = headers.status, payload = data }
    else
        if data ~= nil then
            return data
        else
            logger:error("checkResponse: Response for " .. url .. " was empty.")
            return { status = "error", from = "server", code = "empty", payload = data }
        end
    end
end


return Utils