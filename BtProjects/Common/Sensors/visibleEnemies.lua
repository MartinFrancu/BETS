function getInfo()
	return {
		period = 60
	}
end

-- https://springrts.com/wiki/Lua_UnitDefs
-- https://springrts.com/wiki/Gamedev:UnitDefs
-- https://github.com/spring/spring/blob/103.0/rts/Sim/Units/UnitDef.cpp
-- https://springrts.com/wiki/Lua_SyncedRead#Unit_LOS
-- https://springrts.com/wiki/Lua_UnsyncedRead#MyInfo

local getNearestEnemy 		= Spring.GetUnitNearestEnemy
local getUnitDefID 				= Spring.GetUnitDefID
local getUnitPosition			= Spring.GetUnitPosition
local getUnitsInSphere		= Spring.GetUnitsInSphere
local getUnitTeam 				= Spring.GetUnitTeam
local areTeamsAllied			= Spring.AreTeamsAllied
local acos								= math.acos
local deg 								= math.deg

local north = {}
local west  = {}
local south = {}
local east  = {}

local playerTeam = Spring.GetLocalTeamID()

local function dot2D(u, v)
	return u.x*v.x +u.z*v.z
end

local function normalization2D(v)
	local invLength = 1 / math.sqrt(v.x*v.x + v.z*v.z)
	v.x = v.x * invLength
	v.z = v.z * invLength
end

local function length(v)
	local result = math.sqrt(v.x*v.x + v.z*v.z)
	return result
end

-- These tables can be used
-- units
-- UnitDefs
return function()
	if(units.length == 0)then
		return nil
	end

	local seeEnemy = false
	for i=1, units.length do
		local enemyID = getNearestEnemy(units[i], UnitDefs[ getUnitDefID(units[i]) ].losRadius, true)
		if(enemyID) then
			seeEnemy = true
		end
	end

	local visibleUnits2 = {}

	local unitsArray
	for i=1,units.length do
		local x, y, z = getUnitPosition(units[i])
		unitsArray = getUnitsInSphere(x, y, z, UnitDefs[ getUnitDefID(units[i]) ].losRadius)
		for k=1,#unitsArray do
			-- !!discard allied tems!!----------------------------------------------------------------
			--if(not Spring.AreTeamsAllied(playerTeam ,getUnitTeam())) then
			if(areTeamsAllied(playerTeam ,getUnitTeam(unitsArray[k]))) then
				visibleUnits2[ unitsArray[k] ] = true
			end
		end
	end
	-- discard with enemy team------------------------------------------------------
	for i=1,units.length do
		visibleUnits2[ units[i] ] = nil
	end
	--------------------------------------------------------------------------------
	local center = Sensors.groupExtents().center
	local northEast = { x = 1, z = -1, }
	normalization2D(northEast)

	for unitID,_ in pairs(visibleUnits2) do
		local xx, _, zz = getUnitPosition(unitID)
		local direction = { x = xx - center.x, z = zz - center.z, }
		normalization2D(direction)
		local angle = acos(dot2D(direction, northEast))
		if((direction.x*northEast.z - direction.z*northEast.x) < 0) then
			angle = -angle
		end
		angle = deg(angle)
		-- From angle to northEast determine segment where units were seen
		if(angle < -90) then
			north[#north+1] = unitID
		elseif(angle < 0) then
			east[#east+1] = unitID
		elseif(angle < 90) then
			south[#south+1] = unitID
		else
			west[#west+1] = unitID
		end
	end
	return { any = seeEnemy,  north = north, west = west, south = south, east = east, }
end