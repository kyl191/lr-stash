-- Init script.
-- Currently, just update the plugin if auto-update is enabled in the preferences.

local prefs = import 'LrPrefs'.prefsForPlugin()
require 'Utils'

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
