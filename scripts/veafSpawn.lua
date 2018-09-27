-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF spawn command and functions for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Listen to marker change events and execute spawn commands, with optional parameters
-- * Possibilities : 
-- *    - spawn a specific ennemy unit or group
-- *    - create a cargo drop to be picked by a helo
-- * Works with all current and future maps (Caucasus, NTTR, Normandy, PG, ...)
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires the base veaf.lua script library (version 1.0 or higher)
-- * It also requires the veafMarkers.lua script library (version 1.0 or higher)
-- * It also requires the veafUnits.lua script library (version 1.0 or higher)
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
--     * OPEN --> Browse to the location of veafMarkers.lua and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of veafUnits.lua and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of this script and click OK.
--     * ACTION "DO SCRIPT"
--     * set the script command to "veafSpawn.initialize()" and click OK.
-- 4.) Save the mission and start it.
-- 5.) Have fun :)
--
-- Basic Usage:
-- ------------
-- 1.) Place a mark on the F10 map.
-- 2.) As text enter a command
-- 3.) Click somewhere else on the map to submit the new text.
-- 4.) The command will be processed. A message will appear to confirm this
-- 5.) The original mark will disappear.
--
-- Commands and options: see online help function veafSpawn.help()
--
-- *** NOTE ***
-- * All keywords are CaSE inSenSITvE.
-- * Commas are the separators between options ==> They are IMPORTANT!
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- veafSpawn Table.
veafSpawn = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafSpawn.Id = "SPAWN - "

--- Version.
veafSpawn.Version = "1.2.0"

--- Key phrase to look for in the mark text which triggers the weather report.
veafSpawn.Keyphrase = "veaf spawn "

--- Name of the spawned units group 
veafSpawn.RedSpawnedUnitsGroupName = "VEAF Spawned Units"

--- Illumination flare default initial altitude (in meters AGL)
veafSpawn.IlluminationFlareAglAltitude = 1000

veafSpawn.RadioMenuName = "SPAWN (" .. veafSpawn.Version .. ")"

--- All the air unit templates groups must comply with this name
veafSpawn.AirUnitTemplateGroupNamePattern = "^TEMPLATE_AIRUNIT_(.*)$"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpawn.rootPath = nil

-- counts the units generated 
veafSpawn.spawnedUnitsCounter = 0

veafSpawn.AirUnitTemplates = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSpawn.logInfo(message)
    veaf.logInfo(veafSpawn.Id .. message)
end

function veafSpawn.logDebug(message)
    veaf.logDebug(veafSpawn.Id .. message)
end

function veafSpawn.logTrace(message)
    veaf.logTrace(veafSpawn.Id .. message)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafSpawn.onEventMarkChange(eventPos, event)
    -- Check if marker has a text and the veafSpawn.keyphrase keyphrase.
    if event.text ~= nil and event.text:lower():find(veafSpawn.Keyphrase) then

        -- Analyse the mark point text and extract the keywords.
        local options = veafSpawn.markTextAnalysis(event.text)

        if options then
            -- Check options commands
            if options.unit then
                veafSpawn.spawnUnit(eventPos, options.name, options.country, options.speed, options.altitude, options.heading)
            elseif options.airunit then
                veafSpawn.spawnAirUnit(eventPos, options.name, options.copyof, options.country, options.speed, options.altitude, options.heading)
            elseif options.farp then
                veafSpawn.spawnFarp(eventPos, options.name, options.country, options.heading)
            elseif options.group then
                veafSpawn.spawnGroup(eventPos, options.name, options.country, options.speed, options.altitude, options.heading, options.spacing)
            elseif options.cargo then
                veafSpawn.spawnCargo(eventPos, options.cargoType, options.cargoSmoke)
            elseif options.smoke then
                veafSpawn.spawnSmoke(eventPos, options.smokeColor)
            elseif options.flare then
                veafSpawn.spawnIlluminationFlare(eventPos, options.altitude)
            end
        else
            -- None of the keywords matched.
            return
        end

        -- Delete old mark.
        veafSpawn.logDebug(string.format("Removing mark # %d.", event.idx))
        trigger.action.removeMark(event.idx)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Extract keywords from mark text.
function veafSpawn.markTextAnalysis(text)

    -- Option parameters extracted from the mark text.
    local switch = {}
    switch.unit = false
    switch.airunit = false
    switch.group = false
    switch.cargo = false
    switch.smoke = false
    switch.flare = false
    switch.farp = false

    -- spawned group/unit name
    switch.name = ""
    switch.copyof = nil

    -- spawned group units spacing
    switch.spacing = 5
    
    switch.country = nil
    switch.speed = 0
    switch.altitude = nil
    switch.heading = 0
    
    -- smoke color
    switch.smokeColor = trigger.smokeColor.Red

    -- optional cargo smoke
    switch.cargoSmoke = false

    -- cargo type
    switch.cargoType = "uh1h_cargo"

    -- Check for correct keywords.
    if text:lower():find(veafSpawn.Keyphrase .. "unit") then
        switch.unit = true
    elseif text:lower():find(veafSpawn.Keyphrase .. "airunit") then
            switch.airunit = true
    elseif text:lower():find(veafSpawn.Keyphrase .. "group") then
        switch.group = true
    elseif text:lower():find(veafSpawn.Keyphrase .. "smoke") then
        switch.smoke = true
    elseif text:lower():find(veafSpawn.Keyphrase .. "flare") then
        switch.flare = true
    elseif text:lower():find(veafSpawn.Keyphrase .. "cargo") then
        switch.cargo = true
    elseif text:lower():find(veafSpawn.Keyphrase .. "farp") then
        switch.farp = true
    else
        return nil
    end

    -- keywords are split by ","
    local keywords = veaf.split(text, ",")

    for _, keyphrase in pairs(keywords) do
        -- Split keyphrase by space. First one is the key and second, ... the parameter(s) until the next comma.
        local str = veaf.breakString(veaf.trim(keyphrase), " ")
        local key = str[1]
        local val = str[2]

        if key:lower() == "name" then
            -- Set name.
            veafSpawn.logDebug(string.format("Keyword name = %s", val))
            switch.name = val
        end

        if key:lower() == "copyof" then
            -- Set name.
            veafSpawn.logDebug(string.format("Keyword copyof = %s", val))
            switch.copyof = val
        end

        if switch.group and key:lower() == "spacing" then
            -- Set spacing.
            veafSpawn.logDebug(string.format("Keyword spacing = %d", val))
            local nVal = tonumber(val)
            switch.spacing = nVal
        end
        
        if key:lower() == "alt" then
            -- Set altitude.
            veafSpawn.logDebug(string.format("Keyword alt = %d", val))
            local nVal = tonumber(val)
            switch.altitude = nVal
        end
        
        if key:lower() == "speed" then
            -- Set altitude.
            veafSpawn.logDebug(string.format("Keyword speed = %d", val))
            local nVal = tonumber(val)
            switch.speed = nVal
        end
        
        if key:lower() == "hdg" then
            -- Set altitude.
            veafSpawn.logDebug(string.format("Keyword hdg = %d", val))
            local nVal = tonumber(val)
            switch.heading = nVal
        end
        
        if key:lower() == "country" then
            -- Set country
            veafSpawn.logDebug(string.format("Keyword country = %s", val))
            switch.country = val:upper()
        end
        
        if switch.smoke and key:lower() == "color" then
            -- Set smoke color.
            veafSpawn.logDebug(string.format("Keyword color = %s", val))
            if (val:lower() == "red") then 
                switch.smokeColor = trigger.smokeColor.Red
            elseif (val:lower() == "green") then 
                switch.smokeColor = trigger.smokeColor.Green
            elseif (val:lower() == "orange") then 
                switch.smokeColor = trigger.smokeColor.Orange
            elseif (val:lower() == "blue") then 
                switch.smokeColor = trigger.smokeColor.Blue
            elseif (val:lower() == "white") then 
                switch.smokeColor = trigger.smokeColor.White
            end
        end

        if switch.cargo and key:lower() == "name" then
            -- Set cargo type.
            veafSpawn.logDebug(string.format("Keyword type = %s", val))
            if val:lower() == "ammo" then
                switch.cargoType = "ammo_cargo"
            elseif val:lower() == "barrels" then
                switch.cargoType = "barrels_cargo"
            elseif val:lower() == "container" then
                switch.cargoType = "container_cargo"
            elseif val:lower() == "fbar" then
                switch.cargoType = "f_bar_cargo"
            elseif val:lower() == "fueltank" then
                switch.cargoType = "fueltank_cargo"
            elseif val:lower() == "m117" then
                switch.cargoType = "m117_cargo"
            elseif val:lower() == "oiltank" then
                switch.cargoType = "oiltank_cargo"
            elseif val:lower() == "uh1h" then
                switch.cargoType = "uh1h_cargo"            
            end
        end

        if switch.cargo and key:lower() == "smoke" then
            -- Mark with green smoke.
            veafSpawn.logDebug("Keyword smoke is set")
            switch.cargoSmoke = true
        end
        
    end

    -- check mandatory parameter "name" for command "group"
    if switch.group and not(switch.name) then return nil end
    
    -- check mandatory parameter "name" for command "unit"
    if switch.unit and not(switch.name) then return nil end
    
    if not(switch.altitude) then
        if switch.flare then
            switch.altitude = veafSpawn.IlluminationFlareAglAltitude
        else
            switch.altitude = 0
        end
    end

    if not(switch.country) then
        if switch.farp then
            switch.country = "USA"
        else
            switch.country = "RUSSIA"
        end
    end

    if switch.farp then
        if not switch.name then
            switch.name = "FARP"
        end
    end

    return switch
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Group spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Spawn a specific group at a specific spot
function veafSpawn.spawnGroup(spawnSpot, name, country, speed, alt, hdg, spacing)
    veafSpawn.logDebug(string.format("spawnGroup(name = %s, country=%s, speed=%d, alt=%d, hdg= %d, spacing=%d)",name, country, speed, alt, hdg, spacing))
    veafSpawn.logDebug("spawnGroup: spawnSpot " .. veaf.vecToString(spawnSpot))
    
    veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1

    -- find the desired group in the groups database
    local dbGroup = veafUnits.findGroup(name)
    if not(dbGroup) then
        veafSpawn.logInfo("cannot find group "..name)
        trigger.action.outText("cannot find group "..name, 5)
        return    
    end

    local units = {}

    -- place group units on the map
    local group, cells = veafUnits.placeGroup(dbGroup, spawnSpot, spacing)
    veafUnits.debugGroup(group, cells)
    
    local groupName = group.groupName .. " #" .. veafSpawn.spawnedUnitsCounter

    for i=1, #group.units do
        local unit = group.units[i]
        local unitType = unit.typeName
        local unitName = groupName .. " / " .. unit.displayName .. " #" .. i
        
        local spawnPosition = unit.spawnPoint
        if alt > 0 then
            spawnPosition.y = alt
        end
        
        -- check if position is correct for the unit type
        if not veafUnits.checkPositionForUnit(spawnPosition, unit) then
            veafSpawn.logInfo("cannot find a suitable position for spawning unit ".. unitType)
            trigger.action.outText("cannot find a suitable position for spawning unit "..unitType, 5)
        else 
            local toInsert = {
                    ["x"] = spawnPosition.x,
                    ["y"] = spawnPosition.z,
                    ["alt"] = spawnPosition.y,
                    ["type"] = unitType,
                    ["name"] = unitName,
                    ["speed"] = speed/1.94384,  -- speed in m/s
                    ["skill"] = "Random",
                    ["heading"] = 0
            }

            veafSpawn.logDebug(string.format("toInsert x=%.1f y=%.1f, alt=%.1f, type=%s, name=%s, speed=%d, heading=%d, skill=%s, country=%s", toInsert.x, toInsert.y, toInsert.alt, toInsert.type, toInsert.name, toInsert.speed, toInsert.heading, toInsert.skill, country ))
            table.insert(units, toInsert)
        end
    end

    -- actually spawn the group
    if group.naval then
        mist.dynAdd({country = country, category = "SHIP", name = groupName, hidden = false, units = units})
    elseif group.air then
        mist.dynAdd({country = country, category = "AIRPLANE", name = groupName, hidden = false, units = units})
    else
        mist.dynAdd({country = country, category = "GROUND_UNIT", name = groupName, hidden = false, units = units})
    end

    if speed > 0 then
        veaf.moveGroupAt(groupName, hdg, speed)
    end

    -- message the group spawning
    trigger.action.outText("A " .. group.description .. "("..country..") has been spawned", 5)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Air unit spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Spawn a specific air unit at a specific spot
function veafSpawn.spawnAirUnit(spawnPosition, name, copyof, country, speed, altitude, heading)
    veafSpawn.logDebug(string.format("spawnAirUnit(name = %s, country=%s)",name, country))
    veafSpawn.logDebug("spawnAirUnit: spawnPosition = ".. veaf.vecToString(spawnPosition))
    
    if not(copyof) then
        local soughtTypeAndCountry = name:upper()
        if country then 
            soughtTypeAndCountry = soughtTypeAndCountry .. "_" .. country:upper()
        end

        -- find a template in the templates List
        for typeAndCountry, groupName in pairs(veafSpawn.AirUnitTemplates) do
            if typeAndCountry:find(soughtTypeAndCountry) then
                copyof = groupName
                veafSpawn.logTrace("spawnAirUnit: found copyof="..copyof)
                break
            end
        end
    end
    
    -- clone the original group
    local newGroup = mist.teleportToPoint({
        groupName = copyof,
        point = spawnPosition,
        action = "clone"
    })

    -- make the new group move
    mist.groupRandomDistSelf(newGroup.name, 6000, 'cone')

    -- message the unit spawning
    trigger.action.outText("A " .. name .. "("..country..") has been spawned", 5)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Unit spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Spawn a specific unit at a specific spot
function veafSpawn.spawnUnit(spawnPosition, name, country, speed, alt, hdg)
    veafSpawn.logDebug(string.format("spawnUnit(name = %s, country=%s, speed=%d, alt=%d, hdg= %d)",name, country, speed, alt, hdg))
    veafSpawn.logDebug(string.format("spawnUnit: spawnPosition  x=%.1f y=%.1f, z=%.1f", spawnPosition.x, spawnPosition.y, spawnPosition.z))
    
    veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1

    -- find the desired unit in the groups database
    local unit = veafUnits.findUnit(name)
    
    if not(unit) then
        veafSpawn.logInfo("cannot find unit "..name)
        trigger.action.outText("cannot find unit "..name, 5)
        return    
    end
  
    -- cannot spawn planes or helos yet [TODO]
    if unit.air then
        veafSpawn.logInfo("Air units cannot be spawned at the moment (work in progress)")
        trigger.action.outText("Air units cannot be spawned at the moment (work in progress)", 5)
        return    
    end
    
    local units = {}
    
    veafSpawn.logDebug("spawnUnit unit = " .. unit.displayName .. ", dcsUnit = " .. tostring(unit.typeName))
    
    local groupName = veafSpawn.RedSpawnedUnitsGroupName .. " #" .. veafSpawn.spawnedUnitsCounter
    veafSpawn.logTrace("groupName="..groupName)
    local unitName = unit.displayName .. " #" .. veafSpawn.spawnedUnitsCounter
    veafSpawn.logTrace("unitName="..unitName)

    if alt > 0 then
        spawnPosition.y = alt
    end

    -- check if position is correct for the unit type
    if not  veafUnits.checkPositionForUnit(spawnPosition, unit) then
        veafSpawn.logInfo("cannot find a suitable position for spawning unit "..unit.displayName)
        trigger.action.outText("cannot find a suitable position for spawning unit "..unit.displayName, 5)
        return
    else 
        local toInsert = {
                ["x"] = spawnPosition.x,
                ["y"] = spawnPosition.z,
                ["alt"] = spawnPosition.y,
                ["type"] = unit.typeName,
                ["name"] = unitName,
                ["speed"] = speed/1.94384,  -- speed in m/s
                ["skill"] = "Random",
                ["heading"] = heading
        }

        veafSpawn.logTrace(string.format("toInsert x=%.1f y=%.1f, alt=%.1f, type=%s, name=%s, speed=%d, skill=%s, country=%s", toInsert.x, toInsert.y, toInsert.alt, toInsert.type, toInsert.name, toInsert.speed, toInsert.skill, country ))
        table.insert(units, toInsert)       
    end

    -- actually spawn the unit
    if unit.naval then
        veafSpawn.logTrace("Spawning SHIP")
        mist.dynAdd({country = country, category = "SHIP", name = groupName, hidden = false, units = units})
    elseif unit.air then
        veafSpawn.logTrace("Spawning AIRPLANE")
        mist.dynAdd({country = country, category = "PLANE", name = groupName, hidden = false, units = units})
    else
        veafSpawn.logTrace("Spawning GROUND_UNIT")
        mist.dynAdd({country = country, category = "GROUND_UNIT", name = groupName, hidden = false, units = units})
    end

    if speed > 0 then
        veaf.moveGroupAt(groupName, hdg, speed)
    end

    -- message the unit spawning
    trigger.action.outText("A " .. unit.displayName .. "("..country..") has been spawned", 5)
end

--- Spawn a farp at a specific spot
function veafSpawn.spawnFarp(spawnPosition, name, country, hdg)
    veafSpawn.logDebug(string.format("spawnFarp(name=%s, country=%s, hdg= %d)", name, country, hdg))
    veafSpawn.logDebug("spawnFarp: spawnPosition ".. veaf.vecToString(spawnPosition))
    
    veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1

    local copyof = "TEMPLATE_FARP"

    -- create the farp
    local newGroupName = mist.teleportToPoint({
        groupName = copyof,
        point = spawnPosition,
        action = "clone"
    })

    -- message the unit spawning
    trigger.action.outText("A farp named ".. name .. " ("..country..") has been spawned", 5)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Cargo spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Spawn a specific cargo at a specific spot
function veafSpawn.spawnCargo(spawnSpot, cargoType, cargoSmoke)
    veafSpawn.logDebug("spawnCargo(cargoType = " .. cargoType ..")")
    veafSpawn.logDebug(string.format("spawnCargo: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))

    local units = {}
    veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1
    local unitName = "VEAF Spawned Cargo #" .. veafSpawn.spawnedUnitsCounter

    local spawnPosition = veaf.findPointInZone(spawnSpot, 50, false)

    -- check spawned position validity
    if spawnPosition == nil then
        veafSpawn.logInfo("cannot find a suitable position for spawning cargo "..cargoType)
        trigger.action.outText("cannot find a suitable position for spawning cargo "..cargoType, 5)
        return
    end

    veafSpawn.logDebug(string.format("spawnCargo: spawnPosition  x=%.1f y=%.1f", spawnPosition.x, spawnPosition.y))
  
    -- compute cargo weight
    local cargoWeight = 0
    if cargoType == 'ammo_cargo' then
        cargoWeight = math.random(2205, 3000)
    elseif cargoType == 'barrels_cargo' then
        cargoWeight = math.random(300, 1058)
    elseif cargoType == 'container_cargo' then
        cargoWeight = math.random(300, 3000)
    elseif cargoType == 'f_bar_cargo' then
        cargoWeight = 0
    elseif cargoType == 'fueltank_cargo' then
        cargoWeight = math.random(1764, 3000)
    elseif cargoType == 'm117_cargo' then
        cargoWeight = 0
    elseif cargoType == 'oiltank_cargo' then
        cargoWeight = math.random(1543, 3000)
    elseif cargoType == 'uh1h_cargo' then
        cargoWeight = math.random(220, 3000)
    end
    
    -- create the cargo
    local cargoTable = {
		type = cargoType,
		country = 'USA',
		category = 'Cargos',
		name = unitName,
		x = spawnPosition.x,
		y = spawnPosition.y,
        canCargo = true,
        mass = cargoWeight
	}
	
	mist.dynAddStatic(cargoTable)
    
    -- smoke the cargo if needed
    if cargoSmoke then 
        local smokePosition={x=spawnPosition.x + mist.random(10,20), y=0, z=spawnPosition.y + mist.random(10,20)}
        local height = veaf.getLandHeight(smokePosition)
        smokePosition.y = height
        veafSpawn.logDebug(string.format("spawnCargo: smokePosition  x=%.1f y=%.1f z=%.1f", smokePosition.x, smokePosition.y, smokePosition.z))
        veafSpawn.spawnSmoke(smokePosition, trigger.smokeColor.Green)
        for i = 1, 10 do
            veafSpawn.logDebug("Signal flare 1 at " .. timer.getTime() + i*7)
            mist.scheduleFunction(veafSpawn.spawnSignalFlare, {smokePosition,trigger.flareColor.Red, mist.random(359)}, timer.getTime() + i*3)
        end
    end

    -- message the unit spawning
    local message = "A cargo of type " .. cargoType .. " weighting " .. cargoWeight .. " kg has been spawned"
    if cargoSmoke then 
        message = message .. ". It's marked with green smoke and red flares"
    end
    trigger.action.outText(message, 5)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Smoke and Flare commands
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- add a smoke marker over the marker area
function veafSpawn.spawnSmoke(spawnSpot, color)
    veafSpawn.logDebug("spawnSmoke(color = " .. color ..")")
    veafSpawn.logDebug(string.format("spawnSmoke: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))
	trigger.action.smoke(spawnSpot, color)
end

--- add a signal flare over the marker area
function veafSpawn.spawnSignalFlare(spawnSpot, color, azimuth)
    veafSpawn.logDebug("spawnSignalFlare(color = " .. color ..")")
    veafSpawn.logDebug(string.format("spawnSignalFlare: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))
	trigger.action.signalFlare(spawnSpot, color, azimuth)
end

--- add an illumination flare over the target area
function veafSpawn.spawnIlluminationFlare(spawnSpot, height)
    if height == nil then height = veafSpawn.IlluminationFlareAglAltitude end
    veafSpawn.logDebug("spawnIlluminationFlare(height = " .. height ..")")
    veafSpawn.logDebug(string.format("spawnIlluminationFlare: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))
    local vec3 = {x = spawnSpot.x, y = veaf.getLandHeight(spawnSpot) + height, z = spawnSpot.z}
	trigger.action.illuminationBomb(vec3)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafSpawn.buildRadioMenu()
    veafSpawn.rootPath = missionCommands.addSubMenu(veafSpawn.RadioMenuName, veaf.radioMenuPath)
    missionCommands.addCommand("HELP", veafSpawn.rootPath, veafSpawn.help)
    missionCommands.addCommand("HELP - all units", veafSpawn.rootPath, veafSpawn.helpAllUnits)
    missionCommands.addCommand("HELP - all groups", veafSpawn.rootPath, veafSpawn.helpAllGroups)
end

function veafSpawn.help()
    local text = 
        'Create a marker and type "veaf spawn <unit|group|smoke|flare> " in the text\n' ..
        'This will spawn the requested object in the DCS world\n' ..
        'You can add options (comma separated) :\n' ..
        '"veaf spawn unit" spawns a target vehicle/ship\n' ..
        '   "name [unit name]" spawns a specific unit ; name can be any DCS type\n' ..
        'veaf spawn group, name [group name]" spawns a specific group ; name must be a group name from the VEAF Groups Database\n' ..
        '   "spacing <spacing>" specifies the (randomly modified) units spacing in unit size multiples\n' ..
        '"veaf spawn cargo" creates a cargo mission\n' ..
        '   "name [cargo type]" spawns a specific cargo ; name can be any of [ammo, barrels, container, fbar, fueltank, m117, oiltank, uh1h]\n' ..
        '   "smoke adds a smoke marker\n' ..
        '"veaf spawn smoke" spawns a smoke on the ground\n' ..
        '   "color [red|green|blue|white|orange]" specifies the smoke color\n' ..
        '"veaf spawn flare" lights things up with a flare\n' ..
        '   "alt <altitude in meters agl>" specifies the initial altitude'
            
    trigger.action.outText(text, 30)
end

function veafSpawn.helpAllGroups()
    local text = 'List of all groups defined in dcsUnits :\n'
            
    for _, g in pairs(veafUnits.GroupsDatabase) do
        text = text .. " - " .. (g.group.description or g.group.groupName) .. " -> "
        for i=1, #g.aliases do
            text = text .. g.aliases[i]
            if i < #g.aliases then text = text .. ", " end
        end
        text = text .. "\n"
    end
    trigger.action.outText(text, 30)
end

function veafSpawn.helpAllUnits()
    local text = 'List of all units defined in dcsUnits :\n'
            
    for _, u in pairs(veafUnits.UnitsDatabase) do
        text = text .. " - " .. u.unitType .. " -> "
        for i=1, #u.aliases do
            text = text .. u.aliases[i]
            if i < #u.aliases then text = text .. ", " end
        end
        text = text .. "\n"
    end
    trigger.action.outText(text, 30)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafSpawn.loadAirUnitTemplates()
    veafSpawn.logDebug("loadAirUnitTemplates()")
    for _, g in pairs(mist.DBs.groupsByName) do
        local name = g.groupName
        if name:match(veafSpawn.AirUnitTemplateGroupNamePattern) then
            veafSpawn.logDebug("loadAirUnitTemplates name=" .. name)
            local typeAndCountry = name:match(veafSpawn.AirUnitTemplateGroupNamePattern)
            veafSpawn.logTrace("loadAirUnitTemplates typeAndCountry=" .. typeAndCountry ..")")
            veafSpawn.AirUnitTemplates[typeAndCountry:upper()] = name
        end
    end
end

function veafSpawn.initialize()
    veafSpawn.buildRadioMenu()
    veafSpawn.loadAirUnitTemplates()
    veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafSpawn.onEventMarkChange)
end

veafSpawn.logInfo(string.format("Loading version %s", veafSpawn.Version))

