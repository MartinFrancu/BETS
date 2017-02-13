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


-- BtEvaluator interface definitions
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
function BtEvaluator.assignUnits(units, instanceId, role)
	return BtEvaluator.sendMessage("ASSIGN_UNITS", { units = units, instanceId = instanceId, role = role })
end
function BtEvaluator.createTree(instanceId, treeDefinition)
	return BtEvaluator.sendMessage("CREATE_TREE", { instanceId = instanceId, root = treeDefinition.root })
end
function BtEvaluator.removeTree(insId)
	return BtEvaluator.sendMessage("REMOVE_TREE", { instanceId = insId })
end
function BtEvaluator.reportTree(insId)
	return BtEvaluator.sendMessage("REPORT_TREE", { instanceId = insId })
end


-- ==== luaCommand handling ====

BtEvaluator.scripts = {}
BtEvaluator.commands = {}

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
	commandMap = BtEvaluator.commands[name]
	if not commandMap then
		commandMap = {}
		BtEvaluator.commands[name] = commandMap
	end
	
	cmdsForInstance = commandMap[treeId]
	if not cmdsForInstance then
		cmdsForInstance = {}
		commandMap[treeId] = cmdsForInstance
	end
	
	cmd = cmdsForInstance[id]
	if not cmd then
		cmd = getCommandClass(name):BaseNew()
		cmdsForInstance[id] = cmd
	end
	return cmd
end

BtEvaluator.blackboardsForInstance = {}
BtEvaluator.commandsForUnits = {}-- map(unitId,command)

local function getBlackboardForInstance(treeId)
	local blackboard = BtEvaluator.blackboardsForInstance[treeId]
	if(not blackboard)then
		blackboard = {}
		BtEvaluator.blackboardsForInstance[treeId] = blackboard
	end
	return blackboard
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
	local command = getCommand(params.name, params.id, params.treeId)
	local blackboard = getBlackboardForInstance(params.treeId)
	if (params.func == "RUN") then
		for i = 1, #params.units do
			BtEvaluator.commandsForUnits[params.units[i]] = command
		end
		
		local parameterExpressions, parameters = {}, {}
		for k, v in pairs(params.parameter) do
			local expr = createExpression(tostring(v))
			expr.setBlackboard(blackboard)
			expr.setGroup(params.units)
			parameterExpressions[k] = expr;
			local success, value = pcall(expr.get)
			if(success)then
				parameters[k] = value
			else	
				Logger.error("expression", "Evaluating parameter '", k, "' threw an exception: ", value);
			end
		end
		
		local result, output = command:BaseRun(params.units, parameters)
		
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
		
		Logger.log("luacommand", "Result: ", result)
		return result
	elseif (params.func == "RESET") then
		command:BaseReset()
		return nil
	end
end

function BtEvaluator.OnExpression(params)
	if(params.func == "RESET")then
		return "S"
	end
	
	local blackboard = getBlackboardForInstance(params.treeId)
	local expr = createExpression(params.expression);
	expr.setBlackboard(blackboard)
	expr.setGroup(params.units)
	
	local success, result = pcall(expr.get)
	if(success and result)then
		return "S"
	else
		return "F"
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag) 
	Logger.log("command", "----UnitCommand---")
	local cmd = BtEvaluator.commandsForUnits[unitID]
	if cmd  then
		cmd:AddActiveCommand(unitID,cmdID,cmdTag)
	end
end

function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	Logger.log("command", "----UnitCmdDone---")
	local cmd = BtEvaluator.commandsForUnits[unitID]
	if cmd then
		cmd:CommandDone(unitID,cmdID,cmdTag)
	end
end

function widget:UnitIdle(unitID, unitDefID, unitTeam)
	Logger.log("command", "----UnitIdle---")
	local cmd = BtEvaluator.commandsForUnits[unitID]
	if cmd then
		cmd:SetUnitIdle(unitID)
	end
end
-- ======================================

function widget:Initialize()	
	WG.BtEvaluator = BtEvaluator
	
	BtEvaluator.sendMessage("REINITIALIZE")
	Spring.SendCommands("AIControl "..Spring.GetLocalPlayerID().." BtEvaluator")
end

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
	
	-- internal messages without parameter
	if(messageType == "LOG") then 
		Logger.log("BtEvaluator", messageBody)
		return true
	elseif(messageType == "INITIALIZED") then 
		Dependency.fill(Dependency.BtEvaluator)
		return true
	elseif(messageType == "RESPONSE")then
		local messageBody = messageShorter:sub(indexOfFirstSpace + 1)
		local data = JSON:decode(messageBody)
		lastResponse = data
		return true
	else
		-- messages without parameter
		local handler = ({
			-- none so far
		})[messageType]
		
		if(handler)then
			return handler:Invoke()
		else
			handler = ({
				["UPDATE_STATES"] = BtEvaluator.OnUpdateStates,
				["NODE_DEFINITIONS"] = BtEvaluator.OnNodeDefinitions,
				["COMMAND"] = BtEvaluator.OnCommand,
				["EXPRESSION"] = BtEvaluator.OnExpression
			})[messageType]
			
			if(handler)then
				local messageBody = messageShorter:sub(indexOfFirstSpace + 1)
				local data = JSON:decode(messageBody)
				
				return handler:Invoke(data)
			else
				Logger.log("communication", "Unknown message type: |", messageType, "|")
			end
		end
	end
end
