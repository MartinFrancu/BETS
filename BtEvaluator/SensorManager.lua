--- .
-- @module SensorManager

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)

local SENSOR_DIRNAME = LUAUI_DIRNAME .. "Widgets/BtSensors/"
local sensors = {}
local sensorEnvironmentMetatable = {
	__metatable = false,
	__index = {
		Spring = Spring,
		System = System
	}
};

local SensorManager = {}
function SensorManager.loadSensor(name)
	local sensorCode = VFS.LoadFile(SENSOR_DIRNAME .. name .. ".lua")
	local sensorFunction = assert(loadstring(sensorCode))
	local sensorConstructor = function(group)
		local sensorEnvironment = {
			units = group
		}
		setmetatable(sensorEnvironment, sensorEnvironmentMetatable)
		setfenv(sensorFunction, sensorEnvironment)
		local evaluator = sensorFunction()
		
		local lastExecutionFrame = nil
		local lastResult = nil
		return function(...)
			local currentFrame = 0
			if(lastExecutionFrame == nil or currentFrame - lastExecutionFrame >= 0)then
				lastResult = { evaluator(...) }
				lastExecutionFrame = currentFrame
			end
			return unpack(lastResult)
		end
	end
	sensors[name] = sensorConstructor
	return sensorConstructor
end

WG.SensorManager = SensorManager
return SensorManager