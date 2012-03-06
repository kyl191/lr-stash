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

    -- Do the request
    local json, headers = LrHttp.post(postUrl, "")

    -- If we didn't get a result back, that means there was a transport error
    -- So show that error to the user
    logger:info("Called Utils.getJSON for " .. postUrl)

    if headers and headers.error then
        logger:info("Lightroom network error:")
        Utils.logTable(headers)
        LrErrors.throwUserError( "Network error: " .. hdrs.error.nativeCode )
    end

    if headers and tonumber(headers.status) > 299 then
        logger:info("Server error:")
        Utils.logTable(headers)
        logger:info(json)
        LrErrors.throwUserError( "Error connecting to Sta.sh: Server returned error code " .. headers.status)
    else

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

end

return Utils