-- Init script.
-- Currently, just update the plugin if auto-update is enabled in the preferences.

local prefs = import 'LrPrefs'.prefsForPlugin()
require 'Utils'

if prefs.uploadCount == nil then
    prefs.uploadCount = 0
end

if prefs.autoUpdate then
    Utils.updatePlugin()
end
