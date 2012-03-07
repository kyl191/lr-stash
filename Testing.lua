-- Empty file that just for testing.

local logger = import 'LrLogger'( 'Stash' )
logger:enable("logfile")

--Utils.md5Files(_PLUGIN.path)
import "LrTasks".startAsyncTask( function()
    logger:info(Utils.networkComms("get", "http://kyl191.net/"))
    end)
