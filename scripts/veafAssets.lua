-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF assets functions for DCS World
-- By zip (2019)
--
-- Features:
-- ---------
-- * manage the assets that roam the map (tankers, awacs, ...)
-- * Works with all current and future maps (Caucasus, NTTR, Normandy, PG, ...)
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires the base veaf.lua script library (version 1.0 or higher)
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafAssets = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafAssets.Id = "ASSETS - "

--- Version.
veafAssets.Version = "1.0.1"

veafAssets.Assets = {
    {name="T1-Arco", description="Arco (KC-135), 6Y, 138.2"}, 
    {name="T2-Shell", description="Shell (KC-135 MPRS), 14Y, 134.7"}, 
    {name="T3-Texaco", description="Texaco (KC-135 MPRS),12Y, 132.5"}, 
    {name="A1-Overlord", description="Overlord (E-2D) - 251"}, 
    {name="Meet Mig-29", description="RED Mig-29 (dogfight zone)" },
    {name="Meet Mig-29*2", description="RED Mig-29x2 (dogfight zone)"},
    {name="Meet Mig-21", description="RED Mig-21 (dogfight zone)"},
}

veafAssets.RadioMenuName = "ASSETS (" .. veafAssets.Version .. ")"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafAssets.rootPath = nil

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafAssets.logInfo(message)
    veaf.logInfo(veafAssets.Id .. message)
end

function veafAssets.logDebug(message)
    veaf.logDebug(veafAssets.Id .. message)
end

function veafAssets.logTrace(message)
    veaf.logTrace(veafAssets.Id .. message)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafAssets.buildRadioMenu()
    veafAssets.rootPath = veafRadio.addSubMenu(veafAssets.RadioMenuName)
    veafRadio.addCommandToSubmenu("HELP", veafAssets.rootPath, veafAssets.help, nil, true)
    for _, asset in pairs(veafAssets.Assets) do
        veafRadio.addCommandToSubmenu("Respawn "..asset.description, veafAssets.rootPath, veafAssets.respawn, asset.name, false)
    end
    
    veafRadio.refreshRadioMenu()
end

function veafAssets.respawn(name)
    veafAssets.logInfo("veafAssets.respawn "..name)
    local theAsset = nil
    for _, asset in pairs(veafAssets.Assets) do
        if asset.name == name then
            theAsset = asset
        end
    end
    if theAsset then
        mist.respawnGroup(name, true)
        local text = "I've respawned " .. theAsset.description
        trigger.action.outText(text, 30)
    end
end


function veafAssets.help(groupId)
    local text =
        'The radio menu lists all the assets, friendly or enemy\n' ..
        'Use these menus to respawn the assets when needed\n'
    trigger.action.outTextForGroup(groupId, text, 30)
end


-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafAssets.initialize()
    veafAssets.buildRadioMenu()
end

veafAssets.logInfo(string.format("Loading version %s", veafAssets.Version))

--- Enable/Disable error boxes displayed on screen.
env.setErrorMessageBoxEnabled(false)

