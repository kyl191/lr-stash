-- Empty file that just for testing.

local logger = import 'LrLogger'( 'Stash' )
logger:enable("logfile")
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
JSON = (loadfile (LrPathUtils.child(_PLUGIN.path, "json.lua")))()

local Info = require 'Info'


--
import "LrFunctionContext".postAsyncTaskWithContext( 'Getting remote file', function(context)

    context:addCleanupHandler(function(result,message)
        logger:error("Testing: Cleanup: " .. message)
    end)

    context:addFailureHandler(function(result,message)
        logger:error("Testing: Error message: " .. message)
    end)

    local version = JSON:encode(Info.VERSION)

    local remoteFiles = Utils.getJSON("http://code.kyl191.net/update.php?plugin=" .. _PLUGIN.id)
    local localFiles = Utils.md5Files(_PLUGIN.path)

    Utils.logTable(remoteFiles, "Remote md5sums")
    Utils.logTable(localFiles, "Local md5sums")
    for k, v in pairs (remoteFiles) do
        if localFiles[k] == v then
            logger:info("File " .. k .. " is up to date.")
        else
            local file = Utils.getFile("http://code.kyl191.net/" .. _PLUGIN.id .. "/head/" .. k, "tempupdatefile", nil)
            local path = LrPathUtils.makeAbsolute(k, _PLUGIN.path)
            LrFileUtils.makeFileWritable(path)
            if LrFileUtils.exists(path) then
                logger:info("Going to move " .. file .. "to " .. path)
                Utils.makeBackups(k, 0)
            end
            local ok, message = LrFileUtils.move(file, path)
            if not ok then
                logger:error(message)
            end

        end


    end

end)



