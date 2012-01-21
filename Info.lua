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

	VERSION = { major=0, minor=2, revision=5, },

}
