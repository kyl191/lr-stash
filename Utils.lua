--[[----------------------------------------------------------------------------

Utils.lua
Common code for Lightroom plugins

------------------------------------------------------------------------------]]
local LrMD5 = import 'LrMD5'
local LrFileUtils = import 'LrFileUtils'
local LrTasks = import 'LrTasks'
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

    if data.status and data.status == "error" then
        logger:error(postUrl .. " was supposed to return JSON, but didn't.")
        LrErrors.throwUserError("Huh. We were supposed to get JSON back from the server, but didn't. Wait a while, and try again.")
    end

    -- Now that we have valid JSON, decode it, and try to get the status of our request
    -- If the status is error, show the error to the user, and die.
    local ok, decode = LrTasks.pcall( function() return JSON:decode(data) end)

    -- If the JSON parsing failed, throw an error.
    if not ok then
        logger.error("getJSON: JSON error for url : ".. postUrl .. "\n" .. decode)
        LrErrors.throwUserError("Huh. We were supposed to get JSON back from the server, but got some garbage. Wait a while, and try again.")
    else

        Utils.logTable(decode, "Result from JSON decode")

       if decode.status and decode.status == "error" then
            logger:error("getJSON: JSON error from " .. postUrl)
            logger:info(data)
            return decode
        elseif decode.status and decode.status == "success" then
            logger:info("getJSON for " .. postUrl)
            Utils.logTable(decode)
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
        logger:error("checkResponse: Server error:" .. headers.status .. "for url: " .. url)
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