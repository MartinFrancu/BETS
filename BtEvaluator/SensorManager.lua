--- .
-- @module SensorManager

WG.SensorManager = WG.SensorManager or (function()
	local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)

	local SENSOR_DIRNAME = LUAUI_DIRNAME .. "Widgets/BtSensors/"
	local sensors = {}
	local sensorEnvironmentMetatable = {
		__metatable = false,
		__index = System,
	};
	local managerForGroup = {}

	local SensorManager = {}
	function SensorManager.loadSensor(name)
		local sensorCode = VFS.LoadFile(SENSOR_DIRNAME .. name .. ".lua")
		local sensorFunction = assert(loadstring(sensorCode))
		local function sensorConstructor(group)
			local sensorEnvironment = setmetatable({
				units = group,
				Sensors = SensorManager.forGroup(group),
			}, sensorEnvironmentMetatable)
			setfenv(sensorFunction, sensorEnvironment)
			local evaluator = sensorFunction()
			
			local info = {}
			if(sensorEnvironment.getInfo)then
				info = sensorEnvironment.getInfo()
			end
			info.period = info.period or 60
			
			local lastExecutionFrame = nil
			local lastResult = nil
			return function(...)
				local currentFrame = Spring.GetGameFrame()
				if(lastExecutionFrame == nil or currentFrame - lastExecutionFrame >= info.period)then
					lastResult = { evaluator(...) }
					lastExecutionFrame = currentFrame
				end
				return unpack(lastResult)
			end
		end
		return sensorConstructor
	end

	function SensorManager.forGroup(group)
		local manager = managerForGroup[group];
		if(not manager)then
			manager = setmetatable({}, {
				__index = function(self, key)
					sensorConstructor = sensors[key]
					if(not sensorConstructor)then
						sensorConstructor = SensorManager.loadSensor(key)
						sensors[key] = sensorConstructor
					end
					local sensor = sensorConstructor(group);
					rawset(self, key, sensor)
					return sensor
				end,
			})
			-- TODO: Once the group management gets resolved (as in the group is always represented by the same object), uncomment:
			-- managerForGroup[group] = manager
		end
		return manager
	end
	
	function SensorManager.getAvailableSensors()
		local sensorFiles = Utils.dirList(SENSOR_DIRNAME, "*.lua")
		for i, v in ipairs(sensorFiles) do
			sensorFiles[i] = v:sub(1, v:len() - 4)
		end
		return sensorFiles
	end
	
	return SensorManager
end)()

return WG.SensorManager
