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

local Sentry = Utils.Sentry

local Debug = Utils.Debug
local Logger, dump, copyTable, fileTable = Debug.Logger, Debug.dump, Debug.copyTable, Debug.fileTable

local JSON


-- BtEvaluator interface definitions
local BtEvaluator = Sentry:New()
function BtEvaluator.SendMessage(messageType, messageData)
	local payload = "BETS " .. messageType;
	if(messageData)then
		payload = payload .. " "
		if(type(messageData) == "string")then
			payload = payload .. messageData
		else
			payload = payload .. JSON:encode(messageData)
		end
	end
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), payload)
end

function BtEvaluator.RequestNodeDefinitions()
	BtEvaluator.SendMessage("REQUEST_NODE_DEFINITIONS")
end
function BtEvaluator.AssignUnits()
	BtEvaluator.SendMessage("ASSIGN_UNITS")
end
function BtEvaluator.CreateTree(treeDefinition)
	BtEvaluator.SendMessage("CREATE_TREE", treeDefinition)
end


function listenerOnTestButtonClick(self)
	Spring.Echo("Test message sent from widget to C++ Skirmish AI. ")
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), "Test message from widget - what is written here? Heh?. ")
	return true
end
function listenerOnNodeDefinitionButtonClick (self)
	Spring.Echo ("Requesting node definitions.")
	Spring.SendSkirmishAIMessage (Spring.GetLocalPlayerID (), "BETS REQUEST_NODE_DEFINITIONS")
	return true
end
function listenerOnMoveButtonClick (self)
	local tree = [[{
	"type": "condition",
	"children": [
		{ "type": "flipSensor" },
		{ "type": "echo", "parameters": [ { "name": "message", "value": "Created tree" } ] },
		{ "type": "wait", "parameters": [ { "name": "time", "value": 5 } ] }
	]
}]]

	Spring.Echo ("Creating tree " .. tree)
	Spring.SendSkirmishAIMessage (Spring.GetLocalPlayerID (), "BETS CREATE_TREE " .. tree)
	return true
end


function widget:Initialize()	
	if (not WG.JSON) then
		-- don't run if we can't find JSON
		widgetHandler:RemoveWidget()
		return
	end
 
	JSON = WG.JSON
 
	Spring.SendCommands("AIControl "..Spring.GetLocalPlayerID().." BtEvaluator")
	
	WG.BtEvaluator = BtEvaluator
end

function widget:RecvSkirmishAIMessage(aiTeam, message)
	-- Dont respond to other players AI
	if(aiTeam ~= Spring.GetLocalPlayerID()) then
		return
	end
	-- Check if it starts with "BETS"
	if(message:len() <= 4 and message:sub(1,4):upper() ~= "BETS") then
		return
	end
	
	local messageShorter = message:sub(6)
	local indexOfFirstSpace = string.find(messageShorter, " ")
	local messageType = messageShorter:sub(1, indexOfFirstSpace - 1):upper()	
	
	-- messages without parameter
	if(messageType == "LOG") then 
		Logger.log("BtEvaluator", messageBody)
		return true
	else
		local handler = ({
			["UPDATE_STATES"] = BtEvaluator.OnUpdateStates,
			["NODE_DEFINITIONS"] = BtEvaluator.OnNodeDefinitions,
			["COMMAND"] = BtEvaluator.OnCommand,
		})[messageType]
		
		if(handler)then
			local messageBody = messageShorter:sub(indexOfFirstSpace + 1)
			local data = JSON:decode(messageBody)
			
			return handler:Invoke(data)
		end
	end
end
