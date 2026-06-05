--[[ Admin Report Desk — entry point (modules in lib/report_desk_*.lua) ]]
script_name('Admin Report Desk')
script_author('ARP Helper')
script_version('3.49.10')
script_description('/reps \xF0\xE5\xEF\xEE\xF0\xF2\xFB v3, \xE0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2\xFB, \xE1\xE8\xED\xE4')
script_dependencies('SAMP', 'SAMPFUNCS', 'mimgui')
script_moonloader(26)

require 'lib.moonloader'
require 'lib.sampfuncs'

local deskEnv = require('report_desk_app').load()
local runDeskMain = deskEnv and deskEnv.main

function main()
    if runDeskMain then return runDeskMain() end
end

function onScriptTerminate(scr)
    if scr == thisScript() and deskEnv and type(deskEnv.onScriptTerminate) == 'function' then
        deskEnv.onScriptTerminate(scr)
    end
end
