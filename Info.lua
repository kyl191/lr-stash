--[[----------------------------------------------------------------------------
Info.lua

------------------------------------------------------------------------------]]

return {

	LrSdkVersion = 3.0,
	LrSdkMinimumVersion = 3.0, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = 'net.kyl191.lightroom.export.stash',
	LrPluginName = 'Sta.sh',

	LrExportServiceProvider = {
		title = 'Sta.sh',
		file = 'StashExportServiceProvider.lua',
	},

	VERSION = { major=0, minor=0, revision=0, build=3, },

}
