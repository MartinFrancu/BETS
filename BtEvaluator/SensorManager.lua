--- .
-- @module SensorManager

WG.SensorManager = WG.SensorManager or (function()
	local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
	local Logger = Utils.Debug.Logger
	
	local globalData = {} -- table that is persistent among all sensors (and all groups) and can be used to store persistent data
	
	local System = Utils.Debug.clone(loadstring("return _G")().System)
	setmetatable(System, {
		-- enumerate all tables from Utils or other sources beside System that should be available in sensors
		__index = {
			Global = globalData,
			Logger = Logger,
			System = System,
		}
	})
	
	local getGameFrame = Spring.GetGameFrame;
	
	local SENSOR_DIRNAME = LUAUI_DIRNAME .. "Widgets/BtSensors/"
	local sensors = {}
	local sensorEnvironmentMetatable = {
		__metatable = false,
		__index = System
	};

	local smInstance = {}
	
	local SensorManager = {}
	function SensorManager.loadSensor(name)
		local file = SENSOR_DIRNAME .. name .. ".lua"
		if(not VFS.FileExists(file))then
			return nil
		end
		
		local sensorCode = "--[[" .. name .. "]] " .. VFS.LoadFile(file)
		local sensorFunction, msg = loadstring(sensorCode)
		if(not sensorFunction)then
			Logger.error("sensors", "Failed to compile sensor '", name, "' due to error: ", msg)
			return nil
		end
		
		local function sensorConstructor(groupSensorManager, group)
			group.length = #group
			local sensorEnvironment = setmetatable({
				units = group,
				Sensors = groupSensorManager,
			}, sensorEnvironmentMetatable)
			setfenv(sensorFunction, sensorEnvironment)
			local success, evaluator = pcall(sensorFunction)
			if(not success)then
				Logger.error("sensors", "Creation of sensor '", name ,"' instance failed: ", evaluator)
				return nil
			end
			
			local info = {}
			if(sensorEnvironment.getInfo)then
				info = sensorEnvironment.getInfo()
			end
			info.period = info.period or 0
			
			local lastExecutionFrame = nil
			local lastResult = nil
			local lastPeriod = 0
			return function(...)
				local currentFrame = getGameFrame()
				if(lastExecutionFrame == nil or currentFrame - lastExecutionFrame > lastPeriod)then
					local success, result, period = pcall(evaluator, ...)
					if(not success)then
						Logger.error("sensors", "Evaluation of sensor '", name ,"' failed: ", result)
						return
					end
					lastResult = result
					lastPeriod = period or info.period
					lastExecutionFrame = currentFrame
				end
				return lastResult
			end
		end
		return sensorConstructor
	end

	function SensorManager.forGroup(group)
		local manager = group[smInstance];
		if(not manager)then
			manager = setmetatable({
				Reload = function(self)
					local keys = {}
					for k, _ in pairs(self) do
						if(k ~= "Reload")then
							table.insert(keys, k)
						end
					end
					for _, k in ipairs(keys) do
						rawset(self, k, nil)
					end
					SensorManager.reload()
				end
			}, {
				__index = function(self, key)
					local sensorConstructor = sensors[key]
					if(not sensorConstructor)then
						sensorConstructor = SensorManager.loadSensor(key)
						if(not sensorConstructor)then
							return nil
						end
						sensors[key] = sensorConstructor
					end
					local sensor = sensorConstructor(manager, group);
					if(not sensor)then
						sensors[key] = nil
						return nil
					end
					rawset(self, key, sensor)
					return sensor
				end,
			})

			group[smInstance] = manager
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
	
	function SensorManager.reload()
		globalData = {}
		getmetatable(System).__index.Global = globalData
		sensors = {}
	end
	
	return SensorManager
end)()
	
return WG.SensorManager
