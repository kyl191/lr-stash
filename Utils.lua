--[[----------------------------------------------------------------------------

Utils.lua
Common code for Lightroom plugins

------------------------------------------------------------------------------]]
local LrMD5 = import 'LrMD5'
local LrFileUtils = import 'LrFileUtils'
local logger = import 'LrLogger'( 'Stash' )
logger:enable("logfile")

local LrPathUtils = import 'LrPathUtils'
JSON = (loadfile (LrPathUtils.child(_PLUGIN.path, "json.lua")))()

local LrHttp = import 'LrHttp'
local LrErrors = import 'LrErrors'

Utils = {}

function Utils.logTable(table)
    for k,v in pairs(table) do
        if type( v ) == 'table' then
            Utils.logTable(v)
        else
            logger:info(k,v)
        end
    end
end

--------------------------------------------------------------------------------

function Utils.md5Files(path)

    logger:info("Running md5files for directory " .. path)
    local digests = {}
    for filePath in LrFileUtils.recursiveFiles( path ) do
        local file = assert(io.open(filePath, "rb"))
        local data = file:read("*all")

        local md5sum = LrMD5.digest(data)
        digests[#digests+1] = {filePath = filePath, md5 = md5sum}
    end

    Utils.logTable(digests)


end

--------------------------------------------------------------------------------

function Utils.getJSON( postUrl )

    json = Utils.networkComms( "post", postUrl )

    if json == nil then
        logger:info(postUrl .. " was supposed to return JSON, but didn't.")
        LrErrors.throwUserError("Server problem! \n Response from server was empty, but we were expecting a JSON response!")
    end

    -- Now that we have valid JSON, decode it, and try to get the status of our request
    -- If the status is error, show the error to the user, and die.
    local decode = JSON:decode(json)
    if decode.status and decode.status == "error" then
        logger:info("JSON error from Sta.sh")
        logger:info(json)
        LrErrors.throwUserError("Error with a JSON response! \n" .. decode.error .. "\n" ..decode.error_description)
    end
    Utils.logTable(decode)
    return decode


end

--------------------------------------------------------------------------------

function Utils.networkComms( action, url )

    logger:info("Called Utils.networkComms for " .. url)

    -- Do the request
    if action == "post" then
        local payload, headers = LrHttp.post(url, "")
    else
        local payload, headers = LrHttp.get(url)
    end

    local data = Utils.checkResponse( payload, headers, url )
    if data ~= nil then
        return data
    else
        return nil
    end

end
--------------------------------------------------------------------------------

function Utils.checkResponse( data, headers, url )

    -- If headers.error is set, that means Lightroom had an error.
    if headers and headers.error then
        logger:info("Lightroom network error:")
        Utils.logTable(headers)
        LrErrors.throwUserError( "Network error: " .. headers.error.errorCode .. "\n" .. headers.error.name )
    end

    -- Alternatively, the server could throw back an error.
    -- Only return data if we're sure
    if headers and tonumber(headers.status) > 299 then
        logger:info("Server error:")
        Utils.logTable(headers)
        logger:info(data)
        LrErrors.throwUserError( "Remote server returned error code " .. headers.status)
    else
        if data ~= nil then
            return data
        else
            logger:info("Response for " .. url .. " was empty.")
            return nil
        end
    end
end
return Utils