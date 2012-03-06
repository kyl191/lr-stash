-- Lightroom Plugin Manager displays

local LrView = import "LrView"
local bind = LrView.bind

local logger = import 'LrLogger'( 'Stash' )
logger:enable("logfile")

local prefs = import 'LrPrefs'.prefsForPlugin()

require 'Utils'


PluginInfoProvider = {}

PluginInfoProvider.sectionsForTopOfDialog = function(viewfactory, propertyTable)

    local f = viewfactory

    local contents = f:column{
        f:row{
            bind_to_object = prefs,
            spacing = f:control_spacing(),
            f:static_text{
                title = "Allow automatic updates",
                alignment = 'right',
            },
            f:checkbox{
                title = "",
                value = bind 'auto_update',
                checked_value = true,
                unchecked_value = false
            }
        },
        f:row{
            bind_to_object = prefs,
            spacing = f:control_spacing(),
            f:static_text{
                title = "Submit error logs and usage information",
                alignment = 'right',
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

            synopsis = "Testing",

            contents
        }

    }
end

return PluginInfoProvider
