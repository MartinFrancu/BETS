local Evaluator = require(NOTA_MODULE_PATH .. "evaluator")
local Nodes = require(NOTA_MODULE_PATH .. "nodes")

local BehaviourTree = Utils.BehaviourTree
local Sentry = Utils.Sentry
local UnitCategories = Utils.UnitCategories
local ProjectManager = Utils.ProjectManager
local Dependency = Utils.Dependency
local sanitizer = Utils.Sanitizer.forWidget(widget)

local BtEvaluator = Utils.Sentry:New()
local evaluator
local function makeManager(contentType)
	local manager = {}
	manager.contentType = contentType
	function manager.load(name)
		local path, parameters = ProjectManager.findFile(contentType, name)
		if(not path)then
			return nil, parameters
		end
		if(not parameters.exists)then
			return nil, "Command " .. name .. " does not exist"
		end
		return VFS.LoadFile(path)
	end
	return manager
end

local function convertNodeTypeParameterDefinitions(parameters)
	local parameterDefinitions = {}
	for i, parameter in ipairs(parameters or {}) do
		parameterDefinitions[i] = {
			componentType = parameter.type == "boolean" and "checkBox" or parameter.type == "select" and "comboBox" or parameter.type == "reference" and "treePicker" or "editBox",
			defaultValue = tostring(parameter.defaultValue),
			name = parameter.name,
			variableType = parameter.type == "select" and table.concat(parameter.values, ",") or parameter.type == "reference" and "reference" or parameter == "expression" and "longString" or "expression",
		}
	end
	return parameterDefinitions
end

local CommandManager = makeManager(ProjectManager.makeRegularContentType("Commands", "lua"))
BtEvaluator.CommandManager = CommandManager
function CommandManager.getAvailableCommandScripts()
	local commandList = ProjectManager.listAll(CommandManager.contentType)
	local paramsDefs = {}
	local tooltips = {}
	
	for _,data in ipairs(commandList)do
		local command = evaluator.command[data.qualifiedName]
		if command then
			paramsDefs[data.qualifiedName] = convertNodeTypeParameterDefinitions(command.parameters)
			tooltips[data.qualifiedName] = command.tooltip or ""
		else
			error("script-load".. "Script ".. data.qualifiedName .. " is missing the getInfo() function or it contains an error: ".. Utils.Debug.dump(command))
		end
	end
	
	return paramsDefs, tooltips
end

local SensorManager = makeManager(ProjectManager.makeRegularContentType("Sensors", "lua"))
BtEvaluator.SensorManager = SensorManager
function SensorManager.getAvailableSensors()
	local sensorFiles = ProjectManager.listAll(SensorManager.contentType)
	for i, v in ipairs(sensorFiles) do
		sensorFiles[i] = v.qualifiedName
	end
	return sensorFiles
end

local instanceMap = {} -- { [instanceId] = BehaviourTree.Instance }
evaluator = Evaluator:New({
	namespace = ProjectManager.isProject,
	tree = BehaviourTree.load,
	command = CommandManager.load,
	sensor = SensorManager.load,
})
WG.evaluator = evaluator

function BtEvaluator.requestNodeDefinitions()
	local nodeDefinitions = {}
	
	for name, nodeType in pairs(Nodes) do
		local nodeDefinition = {
			children = nodeType.children ~= true and nodeType.children or nil,
			defaultHeight = 110,
			defaultWidth = 140,
			name = name,
			parameters = convertNodeTypeParameterDefinitions(nodeType.parameters),
			isReferenceNode = name == "reference" or nil,
			tooltip = nodeType.tooltip,
		}
		table.insert(nodeDefinitions, nodeDefinition)
	end

	BtEvaluator.OnNodeDefinitions(nodeDefinitions)
end
function BtEvaluator.resetTrees(instanceIds)
	for i, instanceId in ipairs(instanceIds) do
		local instance = instanceMap[intanceId]
		if(instance)then
			instance:Reset()
		end
	end
end
function BtEvaluator.resetTree(instanceId)
	return BtEvaluator.resetTrees({ instanceId })
end
function BtEvaluator.tickTrees(instanceIds)
	for i, instanceId in ipairs(instanceIds) do
		local instance = instanceMap[intanceId]
		if(instance)then
			instance:Tick()
			-- TODO: report
		end
	end
end
function BtEvaluator.tickTree(instanceId)
	return BtEvaluator.tickTrees({ instanceId })
end
function BtEvaluator.assignUnits(units, instanceId, roleId)
	local instance = instanceMap[instanceId]
	if(not instance)then
		return false
	end
	
	instance:SetUnits(roleId, units)
	
	return true
end
function BtEvaluator.dereferenceTree(treeDefinition)
	return {}
end
function BtEvaluator.createTree(instanceId, treeDefinition, inputs)
	local instance = evaluator:CreateTree(treeDefinition):Instantiate()
	instanceMap[instanceId] = instance
	return instance
end
function BtEvaluator.setInput(instanceId, inputName, data)
	local instance = instanceMap[instanceId]
	if(not instance)then
		return false
	end
	instance:SetInput(inputName, data)
	return true
end
function BtEvaluator.removeTree(instanceId)
	BtEvaluator.resetTree(instanceId)
	instanceMap[instanceId] = nil
	BtEvaluator.OnInstanceRemoved(instanceId)
	return true
end
local reportingInstanceId = nil
function BtEvaluator.reportTree(instanceId)
	reportingInstanceId = instanceId
	return true
end
function BtEvaluator.setBreakpoint(instanceId, nodeId)
	--return BtEvaluator.sendMessage("SET_BREAKPOINT", { instanceId = instanceId, nodeId = nodeId })
	return false, "Breakpoints not implemented yet."
end
function BtEvaluator.removeBreakpoint(instanceId, nodeId)
	--return BtEvaluator.sendMessage("REMOVE_BREAKPOINT", { instanceId = instanceId, nodeId = nodeId })
	return false, "Breakpoints not implemented yet."
end
function BtEvaluator.getInstances()
	local result = {}
	local i = 1
	for id, instance in pairs(instanceMap) do
		result[i] = instance
		i = i + 1
	end
	return result
end

function widget:Update()
	for id, instance in pairs(instanceMap) do
		instance:Tick()
		if(id == reportingInstanceId)then
			-- TODO: report
		end
	end
end
function widget:Initialize()
	WG.BtEvaluator = sanitizer:Export(BtEvaluator)
	Dependency.fill(Dependency.BtEvaluator)
end
function widget:Shutdown()
	Dependency.clear(Dependency.BtEvaluator)
end