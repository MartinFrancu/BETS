function widget:GetInfo()
	return {
		name      = "BtEvaluator loader",
		desc      = "BtEvaluator loader and message test to this AI.",
		author    = "JakubStasta",
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


function BtEvaluator.OnExpression(params)
	if(params.func == "RESET")then
		return "S"
	end
	
	local f, msg = loadstring("return " .. params.expression)
	if(not f)then
		return "F"
	end
	setfenv(f, SensorManager.forGroup(params.units))
	
	local success, result = pcall(f)
	if(success and result)then
		return "S"
	else
		return "F"
	end
end


-- ==== luaCommand handling ====

BtEvaluator.scripts = {}
BtEvaluator.commands = {}

function getCommandClass(name) 
	c = BtEvaluator.scripts[name] 
	if not c then 
		c = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCommandScripts/" .. name, nil, VFS.RAW_FIRST)
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

function BtEvaluator.OnCommand(params)
	command = getCommand(params.name, params.id, params.treeId)
	local blackboard = BtEvaluator.blackboardsForInstance[params.treeId]
	if(not blackboard)then
		blackboard = {}
		BtEvaluator.blackboardsForInstance[params.treeId] = blackboard
	end

	if (params.func == "RUN") then
		for i = 1, #params.units do
			BtEvaluator.commandsForUnits[params.units[i]] = command
		end
		
		local parameters = {}
		for k, v in pairs(params.parameter) do
			local value = v
			if(type(value) == "string" and value:match("^%$"))then
				Logger.log("blackboard", "Extracting ", value, " from blackboard and inputting it into ", k, " parameter in node ", params.name)
				value = blackboard[value]
			end
			parameters[k] = value
		end
		
		local result, output = command:BaseRun(params.units, parameters)
		if(output)then
			for k, v in pairs(output) do
				local originalValue = params.parameter[k]
				if(type(originalValue) == "string" and originalValue:match("^%$"))then
					Logger.log("blackboard", "Saving to ", value, " blackboard with value ", v, " in node ", params.name)
					blackboard[originalValue] = v
				else
					Logger.log("blackboard", "A constant value '", originalValue, "' was given to an output or input-output parameter '", k, "' of a command '", params.name, "' in instance ", params.treeId, ".", params.id)
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
