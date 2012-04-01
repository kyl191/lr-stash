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
        space = f:label_spacing(),
        f:row{
            bind_to_object = prefs,
            spacing = f:control_spacing(),
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
            f:push_button {
                title = "Click here to update now.",
                visible = LrBinding.keyEquals( 'autoUpdate', false ),
                action = function()
                    Utils.updatePlugin()
                end
            },
        },
        f:row{
            bind_to_object = prefs,
            spacing = f:control_spacing(),
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
