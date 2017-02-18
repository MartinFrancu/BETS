function widget:GetInfo()
	return {
		name      = "BtEvaluator loader",
		desc      = "BtEvaluator loader and message test to this AI.",
		author    = "BETS Team",
		date      = "Sep 20, 2016",
		license   = "BY-NC-SA",
		layer     = 0,
		enabled   = true, --  loaded by default?
		version   = version,
	}
end

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)

local JSON = Utils.JSON
local Sentry = Utils.Sentry
local Dependency = Utils.Dependency

local Debug = Utils.Debug
local Logger = Debug.Logger

local SensorManager = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtEvaluator/SensorManager.lua", nil, VFS.RAW_FIRST)

local getGameFrame = Spring.GetGameFrame;


-- ==== tree instance data in Lua ====
local ALL_UNITS = 0;
local unitToRoleMap = {} -- map(unitId, role)
local parentReference = {}
local treeInstances = {}
WG.unitToRoleMap = unitToRoleMap

local function makeInstance(instanceId, roles)
	local instance = {
		id = instanceId,
		blackboard = {},
		roles = {},
		nodes = {},
		activeNodes = {},
	}
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

-- ==== BtEvaluator interface definitions ====
local BtEvaluator = Sentry:New()
local lastResponse = nil
function BtEvaluator.sendMessage(messageType, messageData)
	local payload = "BETS " .. messageType;
	if(messageData)then
		payload = payload .. " "
		if(type(messageData) == "string")then
			payload = payload .. messageData
		else
			payload = payload .. JSON:encode(messageData)
		end
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

function BtEvaluator.requestNodeDefinitions()
	return BtEvaluator.sendMessage("REQUEST_NODE_DEFINITIONS")
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
	BtEvaluator.sendMessage("RESET_TREES", treeList)

	local function removeItem(t, v)
		for j = 1, t.length do
			if(t[j] == v)then
				t[j] = t[t.length]
				t[t.length] = nil
				t.length = t.length - 1
				break
			end
		end
	end
	for i, id in ipairs(units) do
		local oldRole = unitToRoleMap[id]
		if(oldRole)then
			removeItem(oldRole, id)
			local oldAllRole = oldRole[parentReference].roles[ALL_UNITS]
			removeItem(allRole, id)

			oldRole.lastModified = currentFrame
			oldAllRole.lastModified = currentFrame
		end
	end
	role.lastModified = currentFrame
	for i = 1, role.length do
		removeItem(allRole, role[i])
		unitToRoleMap[role[i]] = nil
		role[i] = nil
	end
	for i, id in ipairs(units) do
		role.length = i
		role[i] = id
		unitToRoleMap[id] = role
		allRole.length = allRole.length + 1
		allRole[allRole.length] = id
	end
end
function BtEvaluator.createTree(instanceId, treeDefinition)
	local instance = makeInstance(instanceId, treeDefinition.roles)
	local result, message = BtEvaluator.sendMessage("CREATE_TREE", { instanceId = instanceId, roleCount = #(treeDefinition.roles or {}), root = treeDefinition.root })
	
	return instance;
end
function BtEvaluator.removeTree(instanceId)
	removeInstance(instanceId)
	return BtEvaluator.sendMessage("REMOVE_TREE", { instanceId = instanceId })
end
function BtEvaluator.reportTree(instanceId)
	return BtEvaluator.sendMessage("REPORT_TREE", { instanceId = instanceId })
end


-- ==== luaCommand handling ====

BtEvaluator.scripts = {}

local baseCommandClass = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtEvaluator/command.lua", nil, VFS.RAW_FIRST)

function getCommandClass(name) 
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

local function createExpression(expression)
	local getter, getErrMsg = loadstring("return (" .. expression .. ")")
	local setter, setErrMsg = loadstring(expression .. " = ...");
	local group;
	local blackboard, sensorManager = {}, {}
	local metatable = {
		__index = function(self, key)
			local result = sensorManager[key]
			if(result)then
				return result
			end
			
			return blackboard[key]
		end,
		__newindex = function(self, key, value)
			if(sensorManager[key])then
				Logger.error("expression", "Attempt to overwrite a sensor.")
			end
			blackboard[key] = value
		end
	};
	local environment = setmetatable({}, metatable)
	if(getter)then
		setfenv(getter, environment)
	else
		getter = function() Logger.error("expression", "Expression ", expression, " could not be compiled into a GETTER: ", getErrMsg) end
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
			sensorManager = SensorManager.forGroup(g)
		end,
	}
end


function BtEvaluator.OnCommand(params)
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
		
		if(result == "F")then
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

function BtEvaluator.OnExpression(params)
	if(params.func == "RESET")then
		return "S"
	end
	
	local blackboard = getBlackboardForInstance(params.treeId)
	local units = treeInstances[params.treeId].roles[params.roleId + 1]
	local expr = createExpression(params.expression);
	expr.setBlackboard(blackboard)
	expr.setGroup(units)
	
	local success, result = pcall(expr.get)
	if(success and result)then
		return "S"
	else
		return "F"
	end
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
	WG.BtEvaluator = BtEvaluator
	
	BtEvaluator.sendMessage("REINITIALIZE")
	Spring.SendCommands("AIControl "..Spring.GetLocalPlayerID().." BtEvaluator")
end

local function asHandlerNoparam(event)
	return function()
		return event:Invoke()
	end
end
local function asHandler(event)
	return function(data)
		return event:Invoke(data.asJSON())
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
	["COMMAND"] = asHandler(BtEvaluator.OnCommand),
	["EXPRESSION"] = asHandler(BtEvaluator.OnExpression),
	["UPDATE_STATES"] = asHandler(BtEvaluator.OnUpdateStates),
	["NODE_DEFINITIONS"] = asHandler(BtEvaluator.OnNodeDefinitions),
}
WG.handlers= handlers
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
