moduleInfo = {
	name = "threatAreasDebug",
	desc = "Shows private threat map data visually",
	author = "PepeAmpere",
	date = "2017-03-24",
	license = "notAlicense",
	layer = 0,
	enabled = true -- loaded by default?
}

function widget:GetInfo()
	return moduleInfo
end

-- get madatory module operators
VFS.Include("LuaRules/modules.lua") -- modules table
VFS.Include(modules.attach.data.path .. modules.attach.data.head) -- attach lib module

-- get other madatory dependencies
attach.Module(modules, "message") -- communication backend

local mapValues = {}
local mapCoordinates = {}
local alliedHealthMax = 0
local alliedHealthFullMax = 0
local enemyHealthMax = 0
local enemyHealthFullMax = 0

local HEALTH_IF_UNKNOWN = 300

local function InitMap(currentMap, mapCoords)
	for i=1, #currentMap do
		mapValues[i] = {}
		local tileData = currentMap[i]
		for k,v in pairs(tileData) do
			mapValues[i][k] = v
		end
		mapCoordinates[i] = {}
		local tileCoords = mapCoords[i]
		for k,v in pairs(tileCoords) do
			mapCoordinates[i][k] = v
		end
	end
end

local function UpdateMap(updates, updatesIndexes)
	for i=1, #updates do
		local thisUpdate = updates[i]
		local thisUpdateIndex = updatesIndexes[i]
		for k,v in pairs(thisUpdate) do
			mapValues[thisUpdateIndex][k] = v
		end
	end
end

function widget:Initialize ()
	widgetHandler:RegisterGlobal('privateThreatAreasByHP_init', InitMap)
	widgetHandler:RegisterGlobal('privateThreatAreasByHP_update', UpdateMap)
end

function widget:GameFrame(n)
	if n % 30 == 0 then
		alliedHealthMax = HEALTH_IF_UNKNOWN
		alliedHealthFullMax = HEALTH_IF_UNKNOWN
		enemyHealthMax = HEALTH_IF_UNKNOWN
		enemyHealthFullMax = HEALTH_IF_UNKNOWN
		for i=1, #mapValues do
			local thisTileData = mapValues[i]
			alliedHealthMax = math.max(alliedHealthMax, thisTileData.alliedHP)
			alliedHealthFullMax = math.max(alliedHealthFullMax, thisTileData.alliedHPFull)
			enemyHealthMax = math.max(enemyHealthMax, thisTileData.enemyHP)
			enemyHealthFullMax = math.max(enemyHealthFullMax, thisTileData.enemyHPFull)
		end
	end
end

function widget:DrawWorld()
	local r, g, b
	local transparency = 0.3
	local totalMax = math.max(alliedHealthMax, enemyHealthMax)
	gl.PushMatrix()
		for i=1, #mapValues do
			local tileData = mapValues[i]
			local tileCoords = mapCoordinates[i]
			local r = tileData.enemyHP / totalMax
			local g = tileData.alliedHP / totalMax
			
			-- make non-zero tiles visible
			if (r > 0 and r < 0.15) then r = 0.15 end
			if (g > 0 and g < 0.15) then g = 0.15 end
			gl.Color(r, g , 0, transparency)
			gl.DrawGroundQuad(tileCoords.topX, tileCoords.topZ, tileCoords.bottomX, tileCoords.bottomZ)
		end
	gl.PopMatrix()
end