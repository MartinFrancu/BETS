--- .
-- @module SensorManager

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
local CustomEnvironment = Utils.CustomEnvironment
local Logger = Utils.Debug.Logger

local ProjectManager = Utils.ProjectManager

local globalData = {} -- table that is persistent among all sensors (and all groups) and can be used to store persistent data

local getGameFrame = Spring.GetGameFrame;

local sensors = {}
local sensorContentType = ProjectManager.makeRegularContentType("Sensors", "lua")

local sensorEnvironment
local function prepareSensorEnvironment()
	sensorEnvironment = CustomEnvironment:New({
		Global = globalData,
	}, {
		units = function(p) return p.group end,
	})
end
prepareSensorEnvironment()

local smInstance = {} -- handle

local SensorManager = {}

SensorManager.contentType = sensorContentType

function SensorManager.loadSensor(...)
	local path, parameters = ProjectManager.findFile(sensorContentType, ...)
	if(not path)then -- if we tried to load a sensor from a non-existant project
		return nil, parameters
	end
	
	if(not parameters.exists)then
		return nil
	end
	local project = parameters.project
	local name = parameters.qualifiedName
	
	local sensorCode = VFS.LoadFile(path)
	local sensorFunction, msg = loadstring(sensorCode, name)
	if(not sensorFunction)then
		Logger.error("sensors", "Failed to compile sensor '", name, "' due to error: ", msg)
		return nil
	end
	
	local function sensorConstructor(group)
		local environment = sensorEnvironment:Create({
			group = group,
			project = project
		})
		setfenv(sensorFunction, environment)
		local success, evaluator = pcall(sensorFunction)
		if(not success)then
			Logger.error("sensors", "Creation of sensor '", name ,"' instance failed: ", evaluator)
			return nil
		end
		
		local info = {}
		if(environment.getInfo)then
			info = environment.getInfo()
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

function SensorManager.forGroup(group, localProject)
	local managers = group[smInstance];
	if(not managers)then
		managers = setmetatable({
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
			__index = function(self, projectName)
				if(not ProjectManager.isProject(projectName))then
					return nil
				end
				
				local manager = setmetatable({ Reload = function() managers:Reload() end }, {
					__index = function(self, key)
						local qualifiedName = ProjectManager.asQualifiedName(projectName, key)
						local sensorConstructor = sensors[qualifiedName]
						if(not sensorConstructor)then
							sensorConstructor = SensorManager.loadSensor(projectName, key)
							if(not sensorConstructor)then
								return managers[key]
							end
							sensors[qualifiedName] = sensorConstructor
						end
						local sensor = sensorConstructor(group);
						if(not sensor)then
							sensors[qualifiedName] = nil
							return nil
						end
						rawset(self, key, sensor)
						return sensor
					end,
				})
				rawset(self, projectName, manager)
				return manager
			end,
		})

		group[smInstance] = managers
	end
	return managers[localProject] or managers
end

function SensorManager.getAvailableSensors()
	local sensorFiles = ProjectManager.listAll(sensorContentType)
	for i, v in ipairs(sensorFiles) do
		sensorFiles[i] = v.qualifiedName
	end
	return sensorFiles
end

function SensorManager.reload()
	globalData = {}
	prepareSensorEnvironment()
	sensors = {}
end

CustomEnvironment.add("Sensors", { group = true }, function(p)
	return SensorManager.forGroup(p.group, p.project)
end)

return SensorManager
