-- Empty file that just for testing.

local logger = import 'LrLogger'( 'Stash' )
logger:enable("logfile")
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
JSON = (loadfile (LrPathUtils.child(_PLUGIN.path, "json.lua")))()




--




