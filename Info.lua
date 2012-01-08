--[[----------------------------------------------------------------------------
Info.lua

------------------------------------------------------------------------------]]

return {

	LrSdkVersion = 3.2,
	LrSdkMinimumVersion = 3.2, -- minimum SDK version required by this plug-in

	URLHandler			= "UrlHandler.lua",
	LrPluginInfoUrl     = "http://kyl191.net/code-and-stuff/lightroom-export-to-sta-sh/",
	LrToolkitIdentifier = 'net.kyl191.lightroom.export.stash',
	LrPluginName = 'Sta.sh',
	LrExportServiceProvider = {
		title = 'Sta.sh',
		file = 'StashExportServiceProvider.lua',
	},
    LrPluginInfoProvider = "PluginInfoProvider.lua",

    LrInitPlugin = "LrInitPlugin.lua",


    LrHelpMenuItems = { title = "Sta.s&h Dev Testing", file = "Testing.lua"},

	VERSION = {major=20140202, minor=2024, revision=0xe25b0f1, },

}
