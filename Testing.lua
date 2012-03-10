-- Empty file that just for testing.

local logger = import 'LrLogger'( 'Stash' )
logger:enable("logfile")

--Utils.md5Files(_PLUGIN.path)
import "LrFunctionContext".callWithContext( 'Getting remote file', function(context)

    context:addFailureHandler(function(result,message)
        logger:error("Testing: Error message: " .. message)
    end)

    context:addCleanupHandler(function(result,message)
        logger:error("Testing: Cleanup: " .. message)
    end)

    import "LrTasks".startAsyncTaskWithoutErrorHandler( function()
        --Utils.logTable(Utils.getJSON("http://kyl191.net/"))
        logger:info("Going to call the assert!")
        assert(false, "For some reason I never see this.")
        logger:info("Called the assert.")
    end)

end)



