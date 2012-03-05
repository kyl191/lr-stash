--[[----------------------------------------------------------------------------

Utils.lua
Common code for Lightroom plugins

------------------------------------------------------------------------------]]
local LrMD5 = import 'LrMD5'
local LrFileUtils = import 'LrFileUtils'
local logger = import 'LrLogger'( 'Stash' )
logger:enable("logfile")

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

function Utils.md5Files()

    logger:info("Running md5files for directory " .. _PLUGIN.path)
    local digests = {}
    for filePath in LrFileUtils.recursiveFiles( _PLUGIN.path ) do
        local file = assert(io.open(filePath, "rb"))
        local data = file:read("*all")

        local md5sum = LrMD5.digest(data)
        logger:info("MD5sum of " .. filePath .. ": " .. md5sum)
        digests[#digests+1] = {filePath = filePath, md5 = md5sum}
    end

    Utils.logTable(digests)


end

return Utils