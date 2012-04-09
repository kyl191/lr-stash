--[[----------------------------------------------------------------------------
Info.lua

------------------------------------------------------------------------------]]

return {

	LrSdkVersion = 3.2,
	LrSdkMinimumVersion = 3.2, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = 'net.kyl191.lightroom.export.stash.dev',
	LrPluginName 		= 'Sta.sh Dev',
	UrlHandler			= "UrlHandler.lua",
	LrPluginInfoUrl     = "http://kyl191.net/code-and-stuff/lightroom-export-to-sta-sh/",
	LrExportServiceProvider = {
		title = 'Sta.sh Dev',
		file = 'StashExportServiceProvider.lua',
	},
    LrPluginInfoProvider = "PluginInfoProvider.lua",

    LrInitPlugin = "LrInitPlugin.lua",


    LrHelpMenuItems = { title = "Sta.s&h Dev Testing", file = "Testing.lua"},

	VERSION = {major=20120408, minor=2203, revision=0xda90ef8, },

}
