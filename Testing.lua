-- Empty file that just for testing.

local logger = import 'LrLogger'( 'Stash' )
logger:enable("logfile")
local LrPathUtils = import 'LrPathUtils'
JSON = (loadfile (LrPathUtils.child(_PLUGIN.path, "json.lua")))()

--
import "LrFunctionContext".postAsyncTaskWithContext( 'Getting remote file', function(context)

    context:addCleanupHandler(function(result,message)
        logger:error("Testing: Cleanup: " .. message)
    end)

    context:addFailureHandler(function(result,message)
        logger:error("Testing: Error message: " .. message)
    end)

    local md5s = Utils.md5Files(_PLUGIN.path)
    local json = JSON:encode(md5s)

    Utils.logTable(Utils.networkComms("post", "http://postbin.heroku.com/67def530?md5=" .. json), "POSTbin response")

end)



