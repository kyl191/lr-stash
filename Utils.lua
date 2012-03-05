--[[----------------------------------------------------------------------------

Utils.lua
Common code for Lightroom plugins

------------------------------------------------------------------------------]]

local logger = import 'LrLogger'( 'Stash' )
logger:enable("logfile")

function Utils.logTable(table)
    for k,v in pairs(table) do
        if type( v ) == 'table' then
            Utils.logTable(v)
        else
            logger:info(k,v)
        end
    end
end

--------------------------------------------------------------------------------