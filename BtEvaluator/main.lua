local BehaviourTree = Utils.BehaviourTree
local JSON = Utils.JSON
local Sentry = Utils.Sentry
local Dependency = Utils.Dependency
local sanitizer = Utils.Sanitizer.forWidget(widget)
local CustomEnvironment = Utils.CustomEnvironment

local Debug = Utils.Debug
local Logger = Debug.Logger

local getGameFrame = Spring.GetGameFrame;

-- ==== tree instance data in Lua ====
local ALL_UNITS = 0;
local unitToRoleMap = {} -- map(unitId, role)
local parentReference = {}
local treeInstances = {}
WG.unitToRoleMap = unitToRoleMap

local globalBlackboard = {}
local function makeInstance(instanceId, project, roles)
	local instance = {
		id = instanceId,
		project = project,
		inputs = {},
		roles = {},
		nodes = {},
		instanceBlackboard = {},
		subblackboards = {},
		activeNodes = {},
	}
	local blackboardMetatable = {
		__index = instance.inputs,
	}
	function instance:ResetBlackboard()
		self.blackboard = setmetatable({}, blackboardMetatable)
		self.subblackboards = {}
		return self.blackboard
	end
	instance:ResetBlackboard()
	
	local function makeRole()
		return {
			length = 0,
			[ parentReference ] = instance,
			lastModified = getGameFrame(),
		}
	end
	instance.roles[ALL_UNITS] = makeRole()
	for i, _ in ipairs(roles or {}) do
		instance.roles[i] = makeRole()
	end
	treeInstances[instanceId] = instance
	
	return instance;
end
local function removeInstance(instanceId)
	local instance = treeInstances[instanceId]
	if(not instance)then return end
	
	local allUnits = instance.roles[ALL_UNITS]
	for i = 1, allUnits.length do
		unitToRoleMap[allUnits[i]] = nil
	end
	
	treeInstances[instanceId] = nil
end

local function removeUnitFromRole(role, unitId)
	for j = 1, role.length do
		if(role[j] == unitId)then
			role[j] = role[role.length]
			role[role.length] = nil
			role.length = role.length - 1
			break
		end
	end
end

local function removeUnitFromItsRole(unitId)
	local role = unitToRoleMap[unitId]
	if(not role)then return nil end
	
	local instance = role[parentReference]
	local allRole = instance.roles[ALL_UNITS]
	
	removeUnitFromRole(role, unitId)
	removeUnitFromRole(allRole, unitId)
	
	unitToRoleMap[unitId] = nil
	
	return role
end

local function getUnitsActiveCommands(unitId)
	local role = unitToRoleMap[unitId]
	if(not role)then return nil end
	
	local instance = role[parentReference]
	local allRole = instance.roles[ALL_UNITS]
	local t = {}
	for node, nodeRole in pairs(instance.activeNodes) do
		if(nodeRole == role or nodeRole == allRole)then
			table.insert(t, node)
		end
	end
	return t
end


CustomEnvironment.add("units", { group = true }, function(p)
	return p.group
end)
CustomEnvironment.add("bb", { group = true }, function(p)
	return (p.group[parentReference] or {}).instanceBlackboard
end)
CustomEnvironment.add("global", nil, function(p)
	return globalBlackboard
end)

-- ==== BtEvaluator interface definitions ====
local BtEvaluator = Sentry:New()
local lastResponse = nil

function BtEvaluator.sendMessage(messageType, messageData)
	local payload = "BETS " .. messageType;
	if(messageData)then
		payload = payload .. " "
		--[[if(type(messageData) == "string")then
			payload = payload .. messageData
		else]]
			payload = payload .. JSON:encode(messageData)
		--end
	end
	Logger.log("communication", payload)
	lastResponse = nil
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), payload)
	if(lastResponse ~= nil)then
		local response = lastResponse
		lastResponse = nil
		if(response.result)then
			if(response.data == nil)then
				return true
			else
				return response.data
			end
		else
			return nil, response.error
		end
	end
end
function BtEvaluator.executeOS(command)
	BtEvaluator.sendMessage("EXECUTE", command)
end
Utils.ErrorBox.setExecuteFunction(BtEvaluator.executeOS)

function BtEvaluator.requestNodeDefinitions()
	return BtEvaluator.sendMessage("REQUEST_NODE_DEFINITIONS")
end
function BtEvaluator.resetTrees(instanceIds)
	-- reset all nodes with the current blackboards preserved
	local result, msg = BtEvaluator.sendMessage("RESET_TREES", instanceIds)
	
	-- reset the blackboards
	for i, instanceId in ipairs(instanceIds) do
		local instance = treeInstances[instanceId]
		if(instance)then
			instance:ResetBlackboard()
		else
			Logger.error("BtEvaluator", "Attempt to reset a nonexistant tree")
		end
	end
	
	return result, msg
end
function BtEvaluator.resetTree(instanceId)
	return BtEvaluator.resetTrees({ instanceId })
end
function BtEvaluator.tickTrees(instanceIds)
	return BtEvaluator.sendMessage("TICK_TREES", instanceIds)
end
function BtEvaluator.tickTree(instanceId)
	return BtEvaluator.tickTrees({ instanceId })
end
function BtEvaluator.assignUnits(units, instanceId, roleId)
	roleId = roleId + 1
	local instance = treeInstances[instanceId]
	if(not instance)then
		Logger.error("BtEvaluator", "Attempt to assign units to nonexistant tree")
		return
	end
	
	local currentFrame = getGameFrame()
	
	local role = instance.roles[roleId]
	local allRole = instance.roles[ALL_UNITS]
	local treesToReset = { [instance] = true }
	for i, id in ipairs(units) do
		local oldRole = unitToRoleMap[id]
		if(oldRole)then
			treesToReset[oldRole[parentReference]] = true
		end
	end
	
	local treeList, i = {}, 1
	for tree in pairs(treesToReset) do
		treeList[i] = tree.id
		i = i + 1
	end
	BtEvaluator.resetTrees(treeList)

	for i, id in ipairs(units) do
		local oldRole = unitToRoleMap[id]
		if(oldRole)then
			removeUnitFromRole(oldRole, id)
			local oldAllRole = oldRole[parentReference].roles[ALL_UNITS]
			removeUnitFromRole(allRole, id)

			oldRole.lastModified = currentFrame
			oldAllRole.lastModified = currentFrame
		end
	end
	role.lastModified = currentFrame
	for i = 1, role.length do
		removeUnitFromRole(allRole, role[i])
		unitToRoleMap[role[i]] = nil
		role[i] = nil
	end
	role.length = 0
	for i, id in ipairs(units) do
		role.length = i
		role[i] = id
		unitToRoleMap[id] = role
		allRole.length = allRole.length + 1
		allRole[allRole.length] = id
	end
end

local function locateItem(items, name)
	for i, item in ipairs(items) do
		if(item.name == name)then
			return item, i
		end
	end
	return nil
end
function BtEvaluator.dereferenceTree(treeDefinition)
	local referencedMap, referenceStack = {}, {}
	local failure, message = treeDefinition:Visit(function(node)
		if(node.nodeType == "reference")then
			local behaviourNameParameter = locateItem(node.parameters, "behaviourName")
			local referencedName = behaviourNameParameter.value
			
			local function makeError(text)
				return true, "[node=" .. tostring(node.id) .. "] " .. text
			end
			
			if(not referencedName)then
				return makeError("Reference tree without 'behaviourName' parameter.")
			end
			if(type(referencedName) ~= "string")then
				return makeError("'behaviourName' parameter has to be a string.")
			end
			if(referenceStack[referencedName])then
				return makeError("Cyclic reference to '" .. referencedName .. "'.")
			end
			
			local referenced, message = BehaviourTree.load(referencedName)
			if(not referenced)then
				return makeError(message)
			end
			
			local root = treeDefinition:Combine(referenced, function(n) n:ChangeID(node.id .. "-" .. n.id) end)
			node:Connect(root)
			
			for _, input in ipairs(referenced.inputs) do
				local referenceInput = locateItem(node.referenceInputs, input.name)
				if(referenceInput)then
					referenceInput.matchedInput = input
				else
					return makeError("Referenced tree has an input '" .. input.name .. "' with no value specified.")
				end
			end
			-- ignore missing outputs in referenced node
			
			local count, parameters = 1, {
				{ name = "project", value = referenced.project }
			}
			for i, input in ipairs(node.referenceInputs) do
				if(input.matchedInput)then
					count = count + 1
					parameters[count] = {
						name = "ref_" .. input.name,
						value = {
							type = "input",
							command = (input.matchedInput.command ~= "Variable" and input.matchedInput.command or nil),
							expression = input.value,
						},
					}
				else
					-- ignore missing inputs in referenced tree
				end
			end
			for i, output in ipairs(node.referenceOutputs) do
				local matchedOutput = locateItem(referenced.outputs, output.name)
				if(matchedOutput)then
					count = count + 1
					parameters[count] = {
						name = "ref_" .. output.name,
						value = {
							type = "output",
							expression = output.value,
						},
					}
				else
					-- ignore missing outputs in referenced tree
				end
			end
			node.parameters = parameters
			node.referenceInputs = nil
			node.referenceOutputs = nil

			node.referencedName = referencedName
			referencedMap[referencedName] = true
			referenceStack[referencedName] = true
		end
	end, function(node)
		if(node.nodeType == "reference")then
			referenceStack[node.referencedName] = nil
			node.referencedName = nil
		end
	end)
	
	if(failure)then
		Logger.error("dereference", message)
		return false, message
	else
		local referencedList, count = {}, 0
		for k in pairs(referencedMap) do
			count = count + 1
			referencedList[count] = k
		end
		return referencedList
	end
end
function BtEvaluator.createTree(instanceId, treeDefinition, inputs)
	local instance = makeInstance(instanceId, treeDefinition.project, treeDefinition.roles)
	local result, message = BtEvaluator.sendMessage("CREATE_TREE", { instanceId = instanceId, roleCount = #(treeDefinition.roles or {}), root = treeDefinition.root })
	
	for k, v in pairs(inputs or {}) do
		instance.inputs[k] = v
	end
	
	BtEvaluator.OnInstanceCreated(instanceId, instance)
	
	return instance;
end
function BtEvaluator.setInput(instanceId, inputName, data)
	local instance = treeInstances[instanceId]
	if(not instance)then
		Logger.error("BtEvaluator", "Attempt to set input of a nonexistant tree")
		return
	end
	
	BtEvaluator.resetTree(instanceId)
	
	Logger.log("inputs", "Input ", inputName, " set to ", data)
	instance.inputs[inputName] = data
end
function BtEvaluator.removeTree(instanceId)
	BtEvaluator.resetTree(instanceId)
	removeInstance(instanceId)
	local result, message = BtEvaluator.sendMessage("REMOVE_TREE", { instanceId = instanceId })
	BtEvaluator.OnInstanceRemoved(instanceId)
	return result, message
end
function BtEvaluator.reportTree(instanceId)
	return BtEvaluator.sendMessage("REPORT_TREE", { instanceId = instanceId })
end
function BtEvaluator.setBreakpoint(instanceId, nodeId)
	return BtEvaluator.sendMessage("SET_BREAKPOINT", { instanceId = instanceId, nodeId = nodeId })
end
function BtEvaluator.removeBreakpoint(instanceId, nodeId)
	return BtEvaluator.sendMessage("REMOVE_BREAKPOINT", { instanceId = instanceId, nodeId = nodeId })
end
function BtEvaluator.getInstances()
	local result = {}
	local i = 1
	for id, instance in pairs(treeInstances) do
		result[i] = instance
		i = i + 1
	end
	return result
end


local SensorManager = require("sensor")
BtEvaluator.SensorManager = SensorManager

local CategoryManager = require("category")
BtEvaluator.CategoryManager = CategoryManager

function BtEvaluator.reloadCaches()
	SensorManager.reload()
	CategoryManager.reload()
	BtEvaluator.scripts = {}
end





-- ==== luaCommand handling ====


BtEvaluator.scripts = {}

local CommandManager = require("command")
BtEvaluator.CommandManager = CommandManager
baseCommandClass = CommandManager.baseClass

local function getCommandClass(name)
	c = BtEvaluator.scripts[name]
	if not c then 
		c = baseCommandClass:Extend(name)
		BtEvaluator.scripts[name] = c
	end
	return c
end

local function getCommand(name, id, treeId)
	local cmdsForInstance = treeInstances[treeId].nodes
	
	cmd = cmdsForInstance[id]
	if not cmd then
		cmd = getCommandClass(name):BaseNew()
		cmdsForInstance[id] = cmd
	end
	return cmd
end

local function getBlackboardForInstance(treeId)
	return (treeInstances[treeId] or {}).blackboard
end

local expressionEnvironment = CustomEnvironment:New()
local function createExpression(expression)
	local getter, getErrMsg = loadstring("return (" .. expression .. ")")
	local setter, setErrMsg = loadstring(expression .. " = ...");
	local group;
	local blackboard, customEnvironment = {}, expressionEnvironment:Create()
	local metatable = {
		__index = function(self, key)
			local result = customEnvironment[key]
			if(result)then
				return result
			end

			result = customEnvironment.Sensors[key]
			if(result)then
				return result
			end
			
			return blackboard[key]
		end,
		__newindex = function(self, key, value)
			if(customEnvironment[key])then
				Logger.error("expression", "Attempt to overwrite an environment variable.")
			end
			blackboard[key] = value
		end
	};
	local environment = setmetatable({}, metatable)
	if(getter)then
		setfenv(getter, environment)
	else
		getter = function() error("Expression " .. expression .. " could not be compiled into a GETTER: " .. getErrMsg) end
	end
	if(setter)then
		setfenv(setter, environment)
	else
		setter = function() Logger.error("expression", "Expression ", expression, " could not be compiled into a SETTER: ", setErrMsg) end
	end
	
	return {
		get = getter,
		set = setter,
		setBlackboard = function(b)
			blackboard = b;
		end,
		setGroup = function(g)
			if(group == g)then return end
			group = g
			customEnvironment = expressionEnvironment:Create({
				group = g,
				project = g[parentReference].project,
			})
		end,
	}
end


local function handleStartTree(params)
	local instance = treeInstances[params.treeId]
	local blackboard = getBlackboardForInstance(params.treeId)
	local subblackboard = instance.subblackboards[params.id]
	local units = instance.roles[params.roleId + 1]
	local projectSwitch = (params.project and params.project ~= "") and params.project or instance.project
	if(not subblackboard)then
		subblackboard = {}
		instance.subblackboards[params.id] = subblackboard
	end
	
	local inputExpressions, outputExpressions = {}, {}
	instance.nodes[params.id] = { inputExpressions = inputExpressions, outputExpressions = outputExpressions }
	
	for k, v in pairs(params.parameter) do
		if(v.type)then
			local expr = createExpression(tostring(v.expression))
			expr.setBlackboard(blackboard)
			expr.setGroup(units)
			if(v.type == "output")then
				outputExpressions[k] = expr
			else
				inputExpressions[k] = expr;
				local success, value = pcall(expr.get)
				if(success)then
					if(v.command and not value)then
						Logger.log("subtree", "Subtree '", params.id, "@", params.treeId, "' has a nil parameter '", k, "'." )
						return Results.FAILURE
					end
					subblackboard[k] = value
				else	
					Logger.error("expression", "Evaluating parameter '", k, "' threw an exception: ", value);
					return Results.FAILURE
				end
			end
		end
	end
	
	local stack = instance.subtreeStack
	if(not stack)then
		stack = { length = 0 }
		instance.subtreeStack = stack
	end
	stack.length = stack.length + 1
	stack[stack.length] = { blackboard = instance.blackboard, project = instance.project }
	instance.blackboard = subblackboard
	instance.project = projectSwitch
	return Results.SUCCESS
end
local function handleEnterTree(params)
	local instance = treeInstances[params.treeId]
	local subblackboard = instance.subblackboards[params.id]
	local projectSwitch = (params.project and params.project ~= "") and params.project or instance.project
	if(not subblackboard)then
		Logger.error("subtree", "Attempt to enter a subtree '", params.id, "@", params.treeId, "' that was not started.")
		return Results.FAILURE
	end
	
	local stack = instance.subtreeStack
	if(not stack)then
		stack = { length = 0 }
		instance.subtreeStack = stack
	end
	stack.length = stack.length + 1
	stack[stack.length] = { blackboard = instance.blackboard, project = instance.project }
	instance.blackboard = subblackboard
	instance.project = projectSwitch
	return Results.SUCCESS
end
local function handleExitTree(params)
	local instance = treeInstances[params.treeId]
	local subblackboard = instance.subblackboards[params.id]
	if(subblackboard ~= instance.blackboard)then
		Logger.error("subtree", "Attempt to exit a subtree '", params.id, "@", params.treeId, "' that was not entered.")
		return Results.FAILURE
	end
	local node = instance.nodes[params.id]
	for k, expr in pairs(node.outputExpressions) do
		local success, value = pcall(expr.set, subblackboard[k])
		if(not success)then
			Logger.error("subtree", "Setting output paramter '", k, "' threw an exception: ", value)
		end
	end
	
	local stack = instance.subtreeStack
	instance.blackboard = stack[stack.length].blackboard
	instance.project = stack[stack.length].project
	stack[stack.length] = nil
	stack.length = stack.length - 1
end

local function handleCommand(params)
	local instance = treeInstances[params.treeId]
	local command = getCommand(params.name, params.id, params.treeId)
	local blackboard = getBlackboardForInstance(params.treeId)
	local units = instance.roles[params.roleId + 1]
	if (params.func == "RUN") then
		instance.activeNodes[command] = units
		
		local parameterExpressions, parameters = {}, {}
		for k, v in pairs(params.parameter) do
			local expr = createExpression(tostring(v))
			expr.setBlackboard(blackboard)
			expr.setGroup(units)
			parameterExpressions[k] = expr;
			local success, value = pcall(expr.get)
			if(success)then
				parameters[k] = value
			else	
				Logger.error("expression", "Evaluating parameter '", k, "' threw an exception: ", value);
				return Results.FAILURE
			end
		end
		
		local result, output = command:BaseRun(units, parameters)
		
		if(output)then
			for k, v in pairs(output) do
				local expr = parameterExpressions[k]
				if(expr)then
					pcall(expr.set, v)
				else
					Logger.warn("expression", "No parameter available for output '", k, "'");
				end
			end
		end
		
		if(result ~= Results.RUNNING)then
			instance.activeNodes[command] = nil
		end
		Logger.log("luacommand", "Result: ", result)
		return result
	elseif (params.func == "RESET") then
		instance.activeNodes[command] = nil
		
		command:BaseReset()
		return nil
	end
end

local function handleExpression(params)
	if(params.func == "RESET")then
		return Results.SUCCESS
	end
	
	local blackboard = getBlackboardForInstance(params.treeId)
	local units = treeInstances[params.treeId].roles[params.roleId + 1]
	local expr = createExpression(params.expression);
	expr.setBlackboard(blackboard)
	expr.setGroup(units)
	
	local success, result = pcall(expr.get)
	if(success and result)then
		return Results.SUCCESS
	elseif(not success)then
		Logger.error("expression", result)
		return Results.FAILURE
	else
		return Results.FAILURE
	end
end

function BtEvaluator.crash() error("Intentional error.") end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	Logger.log("command", "----UnitDestroyed---")
	
	removeUnitFromItsRole(unitID)
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag) 
	Logger.log("command", "----UnitCommand---")
	local cmds = getUnitsActiveCommands(unitID)
	if cmds then
		for _, cmd in ipairs(cmds) do
			cmd:AddActiveCommand(unitID,cmdID,cmdTag)
		end
	end
end

function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	Logger.log("command", "----UnitCmdDone---")
	local cmds = getUnitsActiveCommands(unitID)
	if cmds then
		for _, cmd in ipairs(cmds) do
			cmd:CommandDone(unitID,cmdID,cmdTag)
		end
	end
end

function widget:UnitIdle(unitID, unitDefID, unitTeam)
	Logger.log("command", "----UnitIdle---")
	local cmds = getUnitsActiveCommands(unitID)
	if cmds then
		for _, cmd in ipairs(cmds) do
			cmd:SetUnitIdle(unitID)
		end
	end
end
-- ======================================

function widget:Initialize()	
	local foundAI = false
	for _, ai in ipairs(VFS.GetAvailableAIs()) do
		if(ai.shortName == "BtEvaluator")then
			foundAI = true
			break
		end
	end
	if(not foundAI)then
		Logger.error("BtEvaluator", "BtEvaluator C++ AI is not present")
		widgetHandler:RemoveWidget()
	end

	WG.BtEvaluator = sanitizer:Export(BtEvaluator)
	
	BtEvaluator.sendMessage("REINITIALIZE")
	Spring.SendCommands("AIControl "..Spring.GetLocalPlayerID().." BtEvaluator")
end
function widget:Shutdown()
	--This is not used, because if what we want to do is a reload, it will not manage to start it up again
	--if(Dependency.BtEvaluator.filled)then
	--	Spring.SendCommands("AIKill "..Spring.GetLocalPlayerID())
	--end
	
	Dependency.clear(Dependency.BtEvaluator)
end

local function asHandlerNoparam(event)
	return function()
		return event()
	end
end
local function asHandler(event)
	return function(data)
		return event(data.asJSON())
	end
end
local handlers = {
	-- internal messages
	["LOG"] = function(data)
		Logger.log("BtEvaluator", data.asText())
		return true
	end,
	["INITIALIZED"] = function()
		Dependency.fill(Dependency.BtEvaluator)
		return true
	end,
	["RESPONSE"] = function(data)
		lastResponse = data.asJSON()
		return true
	end,
	
	-- event messages
	["COMMAND"] = asHandler(handleCommand),
	["EXPRESSION"] = asHandler(handleExpression),
	["ENTER_SUBTREE"] = asHandler(handleEnterTree),
	["START_SUBTREE"] = asHandler(handleStartTree),
	["EXIT_SUBTREE"] = asHandler(handleExitTree),
	["UPDATE_STATES"] = function(data)
		local params = data.asJSON()
		local instanceId = params.id
		local instance = treeInstances[instanceId]
		if(instance)then
			params.blackboard = setmetatable({ bb = instance.instanceBlackboard, global = globalBlackboard }, { __index = instance.blackboard })
		end
		return BtEvaluator.OnUpdateStates:Invoke(params)
	end,
	["NODE_DEFINITIONS"] = function(data)
		local nodeDefinitions = data.asJSON()
		table.insert(nodeDefinitions, {
			children = {},
			defaultHeight = 110,
			defaultWidth = 140,
			name = "reference",
			parameters = {
				{
					componentType = "treePicker",
					defaultValue = "",
					name = "behaviourName",
					variableType = "reference",
				}
			},
			isReferenceNode = true,
			tooltip = "Leaf node that serves as a reference to another behaviour tree. It allows specifying (staticly) the tree to be reference as well as its incoming and outgoing parameters.",
		})
		
		-- TODO: add Reference node to nodeDefinitions
		return BtEvaluator.OnNodeDefinitions:Invoke(nodeDefinitions)
	end,
}
function widget:RecvSkirmishAIMessage(aiTeam, message)
	Logger.log("communication", "Received message from team " .. tostring(aiTeam) .. ": " .. message)

	-- Dont respond to other players AI
	if(aiTeam ~= Spring.GetLocalPlayerID()) then
		return
	end
	-- Check if it starts with "BETS"
	if(message:len() <= 4 and message:sub(1,4):upper() ~= "BETS") then
		return
	end
	
	local messageShorter = message:sub(6)
	local indexOfFirstSpace = string.find(messageShorter, " ") or (message:len() + 1)
	local messageType = messageShorter:sub(1, indexOfFirstSpace - 1):upper()	
	
	local textData = function() return messageShorter:sub(indexOfFirstSpace + 1) end
	local jsonData = function() return JSON:decode(textData()) end
	local data = {
		asText = textData,
		asJSON = jsonData,
	}
	
	local handler = handlers[messageType]
	if(handler)then
		return handler(data)
	else
		Logger.log("communication", "Unknown message type: |", messageType, "|")
	end
end