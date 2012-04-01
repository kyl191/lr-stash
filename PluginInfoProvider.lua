-- Lightroom Plugin Manager displays

local LrView = import "LrView"
local bind = LrView.bind
local LrBinding = import 'LrBinding'

local logger = import 'LrLogger'( 'Stash' )

local prefs = import 'LrPrefs'.prefsForPlugin()

require 'Utils'


PluginInfoProvider = {}

PluginInfoProvider.sectionsForTopOfDialog = function(viewfactory, propertyTable)

    local f = viewfactory

    local contents = f:column{
        space = f:control_spacing(),
        f:row{
            bind_to_object = prefs,
            spacing = f:label_spacing(),
            f:static_text{
                title = "Allow automatic updates",
                alignment = 'right',
                tooltip = "Note that as part of the update process, information like the plugin version, your Lightroom version and your OS is submitted."
            },
            f:checkbox{
                title = "",
                value = bind 'autoUpdate',
                checked_value = true,
                unchecked_value = false
            },
        },
        f:row{
            bind_to_object = prefs,
            spacing = f:label_spacing(),
            f:static_text{
                visible = LrBinding.keyEquals( 'autoUpdate', false ),
                title = "Prefer to do manual updates? No problem.",
                alignment = 'right',
            },
            f:push_button {
                visible = LrBinding.keyEquals( 'autoUpdate', false ),
                title = "Click here to update now.",
                action = function()
                    Utils.updatePlugin()
                end
            },
        },
        f:row{
            bind_to_object = prefs,
            spacing = f:label_spacing(),
            f:static_text{
                title = "Submit usage information with update check",
                alignment = 'right',
                tooltip = "When checked, the plugin will submit the number of photos you've uploaded, along with your dA username as part of the update check. This is purely to get a sense of who's using the plugin, and how much you're using it.",
            },
            f:checkbox{
                title = "",
                value = bind 'submitData',
                checked_value = true,
                unchecked_value = false
            }
        },
        f:row{
            bind_to_object = prefs,
            spacing = f:label_spacing(),
            f:static_text{
                title = "Enable debug logging",
                alignment = 'right',
                tooltip = "When checked, the plugin will write internal logging to a file. The file will be cleared every time Lightroom opens.",
            },
            f:checkbox{
                title = "",
                value = bind 'debugLogging',
                checked_value = true,
                unchecked_value = false
            }
        }
    }

    return {

        {
            title = "Configure the Sta.sh Plugin",

            synopsis = "Configuration",

            contents
        }

    }
end

return PluginInfoProvider
