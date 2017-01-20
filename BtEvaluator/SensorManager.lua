--- .
-- @module SensorManager

WG.SensorManager = WG.SensorManager or (function()
	local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
	local Logger = Utils.Debug.Logger
	
	local System = Utils.Debug.clone(loadstring("return _G")().System)
	setmetatable(System, {
		-- enumerate all tables from Utils or other sources beside System that should be available in sensors
		__index = {
			Logger = Logger,
		}
	})
	
	local getGameFrame = Spring.GetGameFrame;
	
	local SENSOR_DIRNAME = LUAUI_DIRNAME .. "Widgets/BtSensors/"
	local sensors = {}
	local sensorEnvironmentMetatable = {
		__metatable = false,
		__index = System
	};
	local managerForGroup = {}

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
			return function(...)
				local currentFrame = getGameFrame()
				if(lastExecutionFrame == nil or currentFrame - lastExecutionFrame >= info.period)then
					lastResult = { pcall(evaluator, ...) }
					if(not lastResult[1])then
						Logger.error("sensors", "Evaluation of sensor '", name ,"' failed: ", lastResult[2])
						return
					end
					table.remove(lastResult, 1)
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
