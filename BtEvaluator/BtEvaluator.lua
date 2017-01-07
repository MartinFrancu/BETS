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
			})[messageType]
			
			if(handler)then
				local messageBody = messageShorter:sub(indexOfFirstSpace + 1)
				local data = JSON:decode(messageBody)
				
				return handler:Invoke(data)
			else
				Logger.log("communication", "Unknown message type: ", messageType)
			end
		end
	end
end
