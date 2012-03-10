-- Empty file that just for testing.

local logger = import 'LrLogger'( 'Stash' )
logger:enable("logfile")

--Utils.md5Files(_PLUGIN.path)
import "LrFunctionContext".postAsyncTaskWithContext( 'Getting remote file', function(context)

    context:addCleanupHandler(function(result,message)
        logger:error("Testing: Cleanup: " .. message)
    end)

    context:addFailureHandler(function(result,message)
        logger:error("Testing: Error message: " .. message)
    end)

    Utils.logTable(Utils.getJSON("http://kyl191.net/"))

end)



