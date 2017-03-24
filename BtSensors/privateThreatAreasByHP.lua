local sensorInfo = {
	name = "privateThreatAreasByHP",
	desc = "Maintain private threat map for given group",
	author = "PepeAmpere",
	date = "2017-22-03",
	license = "notAlicense",
}

-- get madatory module operators
VFS.Include("LuaRules/modules.lua") -- modules table
VFS.Include(modules.attach.data.path .. modules.attach.data.head) -- attach lib module

-- get other madatory dependencies
attach.Module(modules, "message") -- communication backend load

local EVAL_PERIOD_DEFAULT = 0 -- this sensor is not caching any values, it evaluates itself on every request
local TILE_SIZE = 256 -- in elmos
local mapX = Game.mapSizeX 
local mapZ = Game.mapSizeZ
local mapTilesX = math.ceil(mapX / TILE_SIZE)
local mapTilesZ = math.ceil(mapZ / TILE_SIZE)
local mapArraySize = mapTilesX * mapTilesZ
local mapCoordinates = {}

function getInfo()
	return {
		period = EVAL_PERIOD_DEFAULT 
	}
end

local function GetTileIndexForPosition(x, z)
	local ix = math.floor(x / TILE_SIZE)
	local iz = math.floor(z / TILE_SIZE)
	return (ix * mapTilesZ + iz) + 1
end

local function GetTopLeftIndex(startIndex, tileRadius)
	local topLeftIndex = startIndex
	for i=1, tileRadius do
		local newIndex = topLeftIndex - mapTilesZ
		if (newIndex < 1) then
			break
		else
			topLeftIndex = newIndex
		end
	end
	for i=1, tileRadius do
		local newIndex = topLeftIndex - 1
		if (newIndex < 1) then
			break
		else
			topLeftIndex = newIndex
		end
	end
	return topLeftIndex
end

local function GetBottomRightIndex(startIndex, tileRadius)
	local bottomRightIndex = startIndex
	for i=1, tileRadius do
		local newIndex = bottomRightIndex + mapTilesZ
		if (newIndex > mapArraySize) then
			break
		else
			bottomRightIndex = newIndex
		end
	end
	for i=1, tileRadius do
		local newIndex = bottomRightIndex + 1
		if (newIndex > mapArraySize) then
			break
		else
			bottomRightIndex = newIndex
		end
	end
	return bottomRightIndex
end

-- @description Recalculate values for specified areas
-- @argument currentMap [array] previous full threat map
-- @argument tileRadius [number] radius of map update in tiles
-- @argument currentPosition [Vec3|optional] center of update radius (in not provided, we take position of the point-unit)
-- @return currentMap [array] updated version of map
-- @comment map is supposed to be stored
return function(currentMap, tileRadius, currentPosition)
	if (currentMap == nil) then
		currentMap = {}
		local x = -TILE_SIZE
		local z = 0
		for i=1, mapArraySize do	
			if (i % mapTilesZ == 1) then
				z = 0
				x = x + TILE_SIZE
			else
				z = z + TILE_SIZE
			end
		
			currentMap[i] = {
				alliedHP = 0,
				alliedHPFull = 0,
				enemyHP = 0,
				enemyHPFull = 0,
				updateFrame = 0,
			}
			mapCoordinates[i] = {
				topX = x,
				topZ = z,
				bottomX = x + TILE_SIZE,
				bottomZ = z + TILE_SIZE,
			}
		end
		if (Script.LuaUI('privateThreatAreasByHP_init')) then
			Script.LuaUI.privateThreatAreasByHP_init(currentMap, mapCoordinates)
		end
	end
	
	-- if not provided, default value
	if (currentPosition == nil) then
		local x,y,z = Spring.GetUnitPosition(units[1])
		currentPosition = Vec3(x, y, z)
	end
	
	-- select tiles to be updated
	local centerTileIndex = GetTileIndexForPosition(currentPosition.x, currentPosition.z)
	local topLeftIndex = GetTopLeftIndex(centerTileIndex, tileRadius)
	local bottomRightIndex = GetBottomRightIndex(centerTileIndex, tileRadius)
	local updatePool = {}
	local updatePoolIndexes = {}
	local poolIndex = 1
	
	for i=topLeftIndex, topLeftIndex+(2*tileRadius) do
		for k=0, (2*tileRadius) do
			local finalIndex = i + k*mapTilesZ
			updatePool[poolIndex] = mapCoordinates[finalIndex]
			updatePoolIndexes[poolIndex] = finalIndex
			poolIndex = poolIndex + 1
		end
	end
	
	local updates = Sensors.privateThreatAreasByHPUpdate(updatePool)
	if (Script.LuaUI('privateThreatAreasByHP_update')) then
		Script.LuaUI.privateThreatAreasByHP_update(updates, updatePoolIndexes)
	end
	
	for i=1, #updatePoolIndexes do
		local mapIndex = updatePoolIndexes[i]
		currentMap[mapIndex].alliedHP = updates[i].alliedHP
		currentMap[mapIndex].alliedHPFull = updates[i].alliedHPFull
		currentMap[mapIndex].enemyHP = updates[i].enemyHP
		currentMap[mapIndex].enemyHPFull = updates[i].enemyHPFull
		currentMap[mapIndex].updateFrame = updates[i].updateFrame
	end
	
	return currentMap
end
