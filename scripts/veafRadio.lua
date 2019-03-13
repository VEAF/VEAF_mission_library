-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF radio menu script library for DCS Workd
-- By zip (2018)
--
-- Features:
-- ---------
-- Manage the VEAF radio menus in the F10 - Other menu
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires the base veaf.lua script library (version 1.0 or higher)
--
-- Load the script:
-- ----------------
-- 1.) Download the script and save it anywhere on your hard drive.
-- 2.) Open your mission in the mission editor.
-- 3.) Add a new trigger:
--     * TYPE   "4 MISSION START"
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of MIST and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of veaf.lua and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of this script and click OK.
--     * ACTION "DO SCRIPT"
--     * set the script command to "veafRadio.initialize()" and click OK.
-- 4.) Save the mission and start it.
-- 5.) Have fun :)
--
-- Basic Usage:
-- ------------
-- TODO
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- veafRadio Table.
veafRadio = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafRadio.Id = "RADIO - "

--- Version.
veafRadio.Version = "1.0.0"

veafRadio.RadioMenuName = "VEAF (" .. veaf.Version .. " - radio " .. veafRadio.Version .. ")"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafRadio.rootPath = nil

--- Humans Groups (associative array groupId => group)
veafRadio.humanGroups = {}

--- This structure contains all the radio menus
veafRadio.radioMenu = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRadio.logInfo(message)
    veaf.logInfo(veafRadio.Id .. message)
end

function veafRadio.logDebug(message)
    veaf.logDebug(veafRadio.Id .. message)
end

function veafRadio.logTrace(message)
    veaf.logTrace(veafRadio.Id .. message)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafRadio.buildRadioMenu()
    local rootMenuPath = veafRadio.addSubMenu(veaf.RadioMenuName, nil)
    veafRadio.addCommand('Visit us at http://www.veaf.org', rootMenuPath, veaf.emptyFunction)
end

--- Refresh the radio menu, based on stored information
--- This is called from another method that has first changed the radio menu information by adding or removing elements
function veafRadio.refreshRadioMenu()
    --veafRadio.radioMenuPath = missionCommands.addSubMenu(veaf.RadioMenuName)
end

function veafRadio.addCommand(title, radioMenuPath, method)
    --missionCommands.addCommand('Skip current objective', veafCasMission.rootPath, veafCasMission.skipCasTarget)
end

function veafRadio.addSubMenu(title, radioMenuPath)
    local subMenu = {}
    subMenu.Title = title
    
    --veafCasMission.targetMarkersPath = missionCommands.addSubMenu("Target markers", veafCasMission.rootPath)
end

-- prepare humans groups
function veafRadio.buildHumanGroups() -- TODO make this player-centric, not group-centric

    veafRadio.humanGroups = {}

    -- build menu for each player
    for name, unit in pairs(mist.DBs.humansByName) do
        -- not already in groups list ?
        if veafRadio.humanGroups[unit.groupName] == nil then
            veafRadio.logTrace(string.format("human player found name=%s, groupName=%s", name, unit.groupName))
            veafRadio.humanGroups[unit.groupId] = unit.groupName
        end
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRadio.initialize()
    veafRadio.buildHumanGroups()
    veafRadio.buildRadioMenu()
    veafRadio.refreshRadioMenu()
end

veafRadio.logInfo(string.format("Loading version %s", veafRadio.Version))

