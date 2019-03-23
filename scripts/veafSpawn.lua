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
-- * It also requires the dcsUnits.lua script library (version 1.0 or higher)
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
veafSpawn.Version = "1.2.3"

--- Key phrase to look for in the mark text which triggers the weather report.
veafSpawn.Keyphrase = "veaf spawn "

--- Name of the spawned units group 
veafSpawn.RedSpawnedUnitsGroupName = "VEAF Spawned Units"

--- Illumination flare default initial altitude (in meters AGL)
veafSpawn.IlluminationFlareAglAltitude = 1000

veafSpawn.RadioMenuName = "SPAWN (" .. veafSpawn.Version .. ")"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpawn.rootPath = nil

-- counts the units generated 
veafSpawn.spawnedUnitsCounter = 0

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
                veafSpawn.spawnUnit(eventPos, options.name, options.country, options.speed, options.altitude, options.heading, options.unitName, options.role, options.laserCode)
            elseif options.group then
                veafSpawn.spawnGroup(eventPos, options.name, options.country, options.speed, options.altitude, options.heading, options.spacing)
            elseif options.cargo then
                veafSpawn.spawnCargo(eventPos, options.cargoType, options.cargoSmoke, options.unitName)
            elseif options.destroy then
                veafSpawn.destroy(eventPos, options.radius, options.unitName)
            elseif options.bomb then
                veafSpawn.spawnBomb(eventPos, options.bombPower, options.unlock)
            elseif options.smoke then
                veafSpawn.spawnSmoke(eventPos, options.smokeColor)
            elseif options.flare then
                veafSpawn.spawnIlluminationFlare(eventPos, options.alt)
            end
        else
            -- None of the keywords matched.
            return
        end

        -- Delete old mark.
        veafSpawn.logTrace(string.format("Removing mark # %d.", event.idx))
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
    switch.group = false
    switch.cargo = false
    switch.smoke = false
    switch.flare = false
    switch.bomb = false
    switch.destroy = false
    switch.role = nil
    switch.laserCode = 1688

    -- spawned group/unit type/alias
    switch.name = ""

    -- spawned unit name
    switch.unitName = nil

    -- spawned group units spacing
    switch.spacing = 5
    
    switch.country = "RUSSIA"
    switch.speed = 0
    switch.altitude = 0
    switch.heading = 0
    
    -- bomb power
    switch.bombPower = 100

    -- smoke color
    switch.smokeColor = trigger.smokeColor.Red

    -- optional cargo smoke
    switch.cargoSmoke = false

    -- destruction radius
    switch.radius = 150

    -- cargo type
    switch.cargoType = "ammo_cargo"

    -- flare agl altitude (meters)
    switch.alt = veafSpawn.IlluminationFlareAglAltitude

    switch.unlock = nil

    -- Check for correct keywords.
    if text:lower():find(veafSpawn.Keyphrase .. "unit") then
        switch.unit = true
    elseif text:lower():find(veafSpawn.Keyphrase .. "group") then
        switch.group = true
    elseif text:lower():find(veafSpawn.Keyphrase .. "smoke") then
        switch.smoke = true
    elseif text:lower():find(veafSpawn.Keyphrase .. "flare") then
        switch.flare = true
    elseif text:lower():find(veafSpawn.Keyphrase .. "cargo") then
        switch.cargo = true
    elseif text:lower():find(veafSpawn.Keyphrase .. "bomb") then
        switch.bomb = true
    elseif text:lower():find(veafSpawn.Keyphrase .. "destroy") then
        switch.destroy = true
    elseif text:lower():find(veafSpawn.Keyphrase .. "jtac") then
        switch.role = 'jtac'
        switch.unit = true
        -- default country for friendly JTAC: USA
        switch.country = "USA"
        -- default name for JTAC
        switch.name = "APC M1025 HMMWV"
        -- default JTAC name (will overwrite previous unit with same name)
        switch.unitName = "JTAC1"
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

        if key:lower() == "unitname" then
            -- Set name.
            veafSpawn.logDebug(string.format("Keyword unitname = %s", val))
            switch.unitName = val
        end

        if (switch.group or switch.unit) and key:lower() == "name" then
            -- Set name.
            veafSpawn.logDebug(string.format("Keyword name = %s", val))
            switch.name = val
        end

        if switch.destroy and key:lower() == "radius" then
            -- Set name.
            veafSpawn.logDebug(string.format("Keyword radius = %d", val))
            local nVal = tonumber(val)
            switch.radius = nVal
        end

        if switch.group and key:lower() == "spacing" then
            -- Set spacing.
            veafSpawn.logDebug(string.format("Keyword spacing = %d", val))
            local nVal = tonumber(val)
            switch.spacing = nVal
        end
        
        if (switch.group or switch.unit) and key:lower() == "alt" then
            -- Set altitude.
            veafSpawn.logDebug(string.format("Keyword alt = %d", val))
            local nVal = tonumber(val)
            switch.altitude = nVal
        end
        
        if (switch.group or switch.unit) and key:lower() == "speed" then
            -- Set altitude.
            veafSpawn.logDebug(string.format("Keyword speed = %d", val))
            local nVal = tonumber(val)
            switch.speed = nVal
        end
        
        if (switch.group or switch.unit) and key:lower() == "hdg" then
            -- Set heading.
            veafSpawn.logDebug(string.format("Keyword hdg = %d", val))
            local nVal = tonumber(val)
            switch.heading = nVal
        end
        
        if (switch.group or switch.unit) and key:lower() == "country" then
            -- Set country
            veafSpawn.logDebug(string.format("Keyword country = %s", val))
            switch.country = val:upper()
        end
        
        if key:lower() == "unlock" then
            -- Unlock the bomb power
            veafSpawn.logDebug(string.format("Keyword unlock", val))
            switch.unlock = val:upper()
        end

        if key:lower() == "power" then
            -- Set bomb power.
            veafSpawn.logDebug(string.format("Keyword power = %d", val))
            local nVal = tonumber(val)
            switch.bombPower = nVal
        end
        
        if key:lower() == "laser" then
            -- Set laser code.
            veafSpawn.logDebug(string.format("laser code = %d", val))
            local nVal = tonumber(val)
            switch.laserCode = nVal
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

        if switch.flare and key:lower() == "alt" then
            -- Set size.
            veafSpawn.logDebug(string.format("Keyword alt = %d", val))
            local nVal = tonumber(val)
            switch.alt = nVal
        end

        if switch.cargo and key:lower() == "name" then
            -- Set cargo type.
            veafSpawn.logDebug(string.format("Keyword name = %s", val))
            switch.cargoType = val
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
    
    return switch
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Group spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Spawn a specific group at a specific spot
function veafSpawn.doSpawnGroup(spawnSpot, groupDefinition, country, speed, alt, hdg, spacing, groupName, silent)
    veafSpawn.logDebug(string.format("doSpawnGroup(country=%s, speed=%d, alt=%d, hdg=%d, spacing=%d, groupName=%s)", country, speed, alt, hdg, spacing, groupName or ""))
    veafSpawn.logDebug("spawnSpot=" .. veaf.vecToString(spawnSpot))
    
    veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1

    if type(groupDefinition) == "string" then
        -- find the desired group in the groups database
        groupDefinition = veafUnits.findGroup(groupDefinition)
        if not(groupDefinition) then
            veafSpawn.logInfo("cannot find group "..name)
            if not(silent) then
                trigger.action.outText("cannot find group "..name, 5) 
            end
            return    
        end
    end

    veafSpawn.logDebug("doSpawnGroup: groupDefinition.description=" .. groupDefinition.description)

    local units = {}

    -- place group units on the map
    local group, cells = veafUnits.placeGroup(groupDefinition, spawnSpot, spacing, hdg)
    veafUnits.debugGroup(group, cells)
    
    if not(groupName) then 
        groupName = group.groupName .. " #" .. veafSpawn.spawnedUnitsCounter
    end

    for i=1, #group.units do
        local unit = group.units[i]
        local unitType = unit.typeName
        local unitName = groupName .. " / " .. unit.displayName .. " #" .. i
        
        local spawnPoint = unit.spawnPoint
        if alt > 0 then
            spawnPoint.y = alt
        end
        
        -- check if position is correct for the unit type
        if not veafUnits.checkPositionForUnit(spawnPoint, unit) then
            veafSpawn.logInfo("cannot find a suitable position for spawning unit ".. unitType)
            if not(silent) then
                trigger.action.outText("cannot find a suitable position for spawning unit "..unitType, 5)
            end
        else 
            local toInsert = {
                    ["x"] = spawnPoint.x,
                    ["y"] = spawnPoint.z,
                    ["alt"] = spawnPoint.y,
                    ["type"] = unitType,
                    ["name"] = unitName,
                    ["speed"] = speed/1.94384,  -- speed in m/s
                    ["skill"] = "Random",
                    ["heading"] = spawnPoint.hdg
            }
            
            veafSpawn.logDebug(string.format("toInsert x=%.1f y=%.1f, alt=%.1f, type=%s, name=%s, speed=%d, heading=%d, skill=%s, country=%s", toInsert.x, toInsert.y, toInsert.alt, toInsert.type, toInsert.name, toInsert.speed, mist.utils.toDegree(toInsert.heading), toInsert.skill, country ))
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
        veaf.moveGroupAt(groupName, hdg, speed) -- TODO check if this still works (no leadUnitName parameter)
    end

    if not(silent) then
        -- message the group spawning
        trigger.action.outText("A " .. group.description .. "("..country..") has been spawned", 5)
    end

    return groupName
end

--- Spawn a specific group at a specific spot
function veafSpawn.spawnGroup(spawnSpot, name, country, speed, alt, hdg, spacing)
    veafSpawn.logDebug(string.format("spawnGroup(name = %s, country=%s, speed=%d, alt=%d, hdg=%d, spacing=%d)",name, country, speed, alt, hdg, spacing))
    veafSpawn.logDebug("spawnGroup: spawnSpot " .. veaf.vecToString(spawnSpot))
    
    veafSpawn.doSpawnGroup(spawnSpot, name, country, speed, alt, hdg, spacing, nil, false)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Unit spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Spawn a specific unit at a specific spot
-- @param position spawnPosition
-- @param string name
-- @param string country
-- @param int speed
-- @param int alt
-- @param int speed
-- @param int hdg (0..359)
-- @param string unitName (callsign)
-- @param string role (ex: jtac)
-- @param int laserCode (ex: 1688)
function veafSpawn.spawnUnit(spawnPosition, name, country, speed, alt, hdg, unitName, role, laserCode)
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
    
    if role == 'jtac' and country:lower() == "russia" then
        hidden = true
    else 
        hidden = false
    end

    local units = {}
    local groupName = nil
    
    veafSpawn.logDebug("spawnUnit unit = " .. unit.displayName .. ", dcsUnit = " .. tostring(unit.typeName))
    
    if role == "jtac" then
      groupName = "jtac_" .. laserCode
      unitName = "jtac_" .. laserCode
    else
      groupName = veafSpawn.RedSpawnedUnitsGroupName .. " #" .. veafSpawn.spawnedUnitsCounter
      if not unitName then
        unitName = unit.displayName .. " #" .. veafSpawn.spawnedUnitsCounter
      end
    end
    
    veafSpawn.logTrace("groupName="..groupName)
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
                ["heading"] = mist.utils.toRadian(hdg),
        }

        veafSpawn.logTrace(string.format("toInsert x=%.1f y=%.1f, alt=%.1f, type=%s, name=%s, speed=%d, skill=%s, country=%s", toInsert.x, toInsert.y, toInsert.alt, toInsert.type, toInsert.name, toInsert.speed, toInsert.skill, country ))
        table.insert(units, toInsert)       
    end

    -- actually spawn the unit
    if unit.naval then
        veafSpawn.logTrace("Spawning SHIP")
        mist.dynAdd({country = country, category = "SHIP", name = groupName, hidden = hidden, units = units})
    elseif unit.air then
        veafSpawn.logTrace("Spawning AIRPLANE")
        mist.dynAdd({country = country, category = "PLANE", name = groupName, hidden = hidden, units = units})
    else
        veafSpawn.logTrace("Spawning GROUND_UNIT")
        mist.dynAdd({country = country, category = "GROUND_UNIT", name = groupName, hidden = hidden, units = units})
    end
    
    -- get spwaned groupd
    local spawnGroup = 	Group.getByName(groupName)
    
    -- JTAC needs to be invisible and immortal
    if role == "jtac" then
      -- @todo later - need to refactor JTACAutoLase library
      -- require lib DCS-JTACAutoLaze
      --JTACAutoLase(groupName, laserCode, false, "all")
    end

    if speed > 0 then
        veaf.moveGroupAt(groupName, hdg, speed) -- TODO check if this still works (no leadUnitName parameter)
    end

    -- message the unit spawning
    trigger.action.outText("A " .. unit.displayName .. "("..country..") has been spawned", 5)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Cargo spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Spawn a specific cargo at a specific spot
function veafSpawn.spawnCargo(spawnSpot, cargoType, cargoSmoke, unitName)
    veafSpawn.logDebug("spawnCargo(cargoType = " .. cargoType ..")")
    veafSpawn.logDebug(string.format("spawnCargo: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))

    veafSpawn.doSpawnCargo(spawnSpot, cargoType, unitName, cargoSmoke, false)
end

--- Spawn a specific cargo at a specific spot
function veafSpawn.doSpawnCargo(spawnSpot, cargoType, unitName, cargoSmoke, silent)
    veafSpawn.logDebug("spawnCargo(cargoType = " .. cargoType ..")")
    veafSpawn.logDebug(string.format("spawnCargo: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))

    local units = {}

    local spawnPosition = veaf.findPointInZone(spawnSpot, 50, false)

    -- check spawned position validity
    if spawnPosition == nil then
        veafSpawn.logInfo("cannot find a suitable position for spawning cargo "..cargoType)
        if not(silent) then trigger.action.outText("cannot find a suitable position for spawning cargo "..cargoType, 5) end
        return
    end

    veafSpawn.logDebug(string.format("spawnCargo: spawnPosition  x=%.1f y=%.1f", spawnPosition.x, spawnPosition.y))
  
    -- compute cargo weight
    local cargoWeight = 250
    local unit = veafUnits.findDcsUnit(cargoType)
    if not unit then
        cargoType = cargoType.. "_cargo"
        unit = veafUnits.findDcsUnit(cargoType)
    end
    if unit then
        if unit.desc.minMass and unit.desc.maxMass then
            cargoWeight = math.random(unit.desc.minMass, unit.desc.maxMass)
        elseif unit.defaultMass then
            cargoWeight = unit.defaultMass
            cargoWeight = math.random(cargoWeight - cargoWeight / 2, cargoWeight + cargoWeight / 2)
        end
        if cargoWeight then

            if not(unitName) then
                veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1
                unitName = unit.desc.displayName .. " #" .. veafSpawn.spawnedUnitsCounter
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
            local message = "Cargo " .. unitName .. " weighting " .. cargoWeight .. " kg has been spawned"
            if cargoSmoke then 
                message = message .. ". It's marked with green smoke and red flares"
            end
            if not(silent) then trigger.action.outText(message, 5) end
        end
    end
    
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Smoke and Flare commands
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- trigger an explosion at the marker area
function veafSpawn.spawnBomb(spawnSpot, power, unlock)
    veafSpawn.logDebug("spawnBomb(power=" .. power ..")")
    veafSpawn.logDebug(string.format("spawnBomb: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))
    if not(unlock) or unlock ~= "IVEGOTTHEPOWER" then
        if power > 1000 then power = 1000 end
    end

    trigger.action.explosion(spawnSpot, power);
end

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

--- destroy unit(s)
function veafSpawn.destroy(spawnSpot, radius, unitName)
    if unitName then
        -- destroy a specific unit
        local c = Unit.getByName(name)
        if c then
            Unit.destroy(c)
        end

        -- or a specific static
        c = StaticObject.getByName(name)
        if c then
            StaticObject.destroy(c)
        end

        -- or a specific group
        c = Group.getByName(name)
        if c then
            Group.destroy(c)
        end
    else
        -- TODO radius based destruction
        local units = veaf.findUnitsInCircle(spawnSpot, radius)
        if units then
            for name, _ in pairs(units) do
                -- try and find a  unit
                local unit = Unit.getByName(name)
                if unit then 
                    Unit.destroy(unit)
                else
                    unit = StaticObject.getByName(name)
                    if unit then 
                        StaticObject.destroy(unit)
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafSpawn.buildRadioMenu()
    veafSpawn.rootPath = veafRadio.addSubMenu(veafSpawn.RadioMenuName)
    veafRadio.addCommandToSubmenu("HELP", veafSpawn.rootPath, veafSpawn.help, nil, true)
    veafRadio.addCommandToSubmenu("HELP - all units", veafSpawn.rootPath, veafSpawn.helpAllUnits, nil, true)
    veafRadio.addCommandToSubmenu("HELP - all groups", veafSpawn.rootPath, veafSpawn.helpAllGroups, nil, true)
    -- TODO see if it's safe to add this back after radio menu refactoring
    --veafRadio.addCommandToSubmenu("HELP - all cargoes", veafSpawn.rootPath, veafSpawn.helpAllCargoes, nil, true)
    veafRadio.refreshRadioMenu()
end

function veafSpawn.help(groupId)
    local text = 
        'Create a marker and type "veaf spawn <unit|group|smoke|flare> " in the text\n' ..
        'This will spawn the requested object in the DCS world\n' ..
        'You can add options (comma separated) :\n' ..
        '"veaf spawn unit" spawns a target vehicle/ship\n' ..
        '   "name [unit name]" spawns a specific unit ; name can be any DCS type\n' ..
        '   "country [country name]" spawns a unit of a specific country ; name can be any DCS country\n' ..
        '   "speed [speed]" spawns the unit already moving\n' ..
        '   "alt [altitude]" spawns the unit at the specified altitude\n' ..
        '   "hdg [heading]" spawns the unit facing a heading\n' ..
        'veaf spawn group, name [group name]" spawns a specific group ; name must be a group name from the VEAF Groups Database\n' ..
        '   "spacing <spacing>" specifies the (randomly modified) units spacing in unit size multiples\n' ..
        '   "country [country name]" spawns a group of a specific country ; name can be any DCS country\n' ..
        '   "speed [speed]" spawns the group already moving\n' ..
        '   "alt [altitude]" spawns the group at the specified altitude\n' ..
        '   "hdg [heading]" spawns the group facing a heading\n' ..
        '"veaf spawn cargo" creates a cargo ready to be picked up\n' ..
        '   "name [cargo type]" spawns a specific cargo ; name can be any of [ammo, barrels, container, fueltank, f_bar, iso_container, iso_container_small, m117, oiltank, pipes_big, pipes_small, tetrapod, trunks_long, trunks_small, uh1h]\n' ..
        '   "smoke adds a smoke marker\n' ..
        '"veaf spawn bomb" spawns a bomb on the ground\n' ..
        '   "power [value]" specifies the bomb power (default is 100, max is 1000)\n' ..
        '"veaf spawn smoke" spawns a smoke on the ground\n' ..
        '   "color [red|green|blue|white|orange]" specifies the smoke color\n' ..
        '"veaf spawn flare" lights things up with a flare\n' ..
        '   "alt <altitude in meters agl>" specifies the initial altitude'
            
    trigger.action.outTextForGroup(groupId, text, 30)
end

function veafSpawn.helpAllGroups(groupId)
    local text = 'List of all groups defined in dcsUnits :\n'
            
    for _, g in pairs(veafUnits.GroupsDatabase) do
        text = text .. " - " .. (g.group.description or g.group.groupName) .. " -> "
        for i=1, #g.aliases do
            text = text .. g.aliases[i]
            if i < #g.aliases then text = text .. ", " end
        end
        text = text .. "\n"
    end
    trigger.action.outTextForGroup(groupId, text, 30)
end

function veafSpawn.helpAllUnits(groupId)
    local text = 'List of all units defined in dcsUnits :\n'
            
    for _, u in pairs(veafUnits.UnitsDatabase) do
        text = text .. " - " .. u.unitType .. " -> "
        for i=1, #u.aliases do
            text = text .. u.aliases[i]
            if i < #u.aliases then text = text .. ", " end
        end
        text = text .. "\n"
    end
    trigger.action.outTextForGroup(groupId, text, 30)
end

function veafSpawn.helpAllCargoes(groupId)
    local text = 'List of all cargoes defined in dcsUnits :\n'
            
    for name, unit in pairs(dcsUnits.DcsUnitsDatabase) do
        if unit and unit.desc and unit.desc.attributes and unit.desc.attributes.Cargos then
            text = text .. " - " .. unit.desc.typeName .. " -> " .. unit.desc.displayName 
            if unit.desc.minMass and unit.desc.maxMass then
                text = text .. " (" .. unit.desc.minMass .. " - " .. unit.desc.maxMass .. " kg)"
            elseif unit.defaultMass then
                text = text .. " (" .. unit.defaultMass .. " kg)"
            end
            text = text .."\n"
        end
    end
    trigger.action.outTextForGroup(groupId, text, 30)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSpawn.initialize()
    veafSpawn.buildRadioMenu()
    veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafSpawn.onEventMarkChange)
end

veafSpawn.logInfo(string.format("Loading version %s", veafSpawn.Version))

