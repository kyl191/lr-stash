-- Init script.
-- Currently, just update the plugin if auto-update is enabled in the preferences.

local prefs = import 'LrPrefs'.prefsForPlugin()
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local logger = import 'LrLogger'( 'Stash' )

require 'Utils'

local logPath = LrPathUtils.child(LrPathUtils.getStandardFilePath('documents'), "Stash.log")
if LrFileUtils.exists( logPath ) then
	local success, reason = LrFileUtils.delete( logPath )
	if not success then
		logger:error("Error deleting existing logfile!" .. reason)
	end
end

if prefs.debugLogging == nil then
	prefs.debugLogging = false
end

if prefs.debugLogging then
	logger:enable("logfile")
else
	logger:disable()
	logger:enable({
		fatal = "logfile",
		error = "logfile",
		})
end

logger:info("LR/Stash loading.")
logger:info("Version " .. Utils.getVersion() .. " in Lightroom " .. import 'LrApplication'.versionString() .. " running on " .. import 'LrSystemInfo'.summaryString())

if prefs.uploadCount == nil then
    prefs.uploadCount = 0
end

if prefs.submitData == nil then
	prefs.submitData = true
end

if prefs.autoUpdate == true then
	Utils.updatePlugin()
elseif prefs.autoUpdate == false then
	-- do nothing
else
	prefs.autoUpdate = true
	Utils.updatePlugin()
end
