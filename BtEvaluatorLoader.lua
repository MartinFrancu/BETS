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
local Logger, dump, copyTable, fileTable = Debug.Logger, Debug.dump, Debug.copyTable, Debug.fileTable


-- BtEvaluator interface definitions
local BtEvaluator = Sentry:New()
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
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), payload)
end

function BtEvaluator.requestNodeDefinitions()
	BtEvaluator.sendMessage("REQUEST_NODE_DEFINITIONS")
end
function BtEvaluator.assignUnits()
	BtEvaluator.sendMessage("ASSIGN_UNITS")
end
function BtEvaluator.createTree(treeDefinition)
	BtEvaluator.sendMessage("CREATE_TREE", JSON:encode(treeDefinition.root))
end


function widget:Initialize()	
	--Spring.SendCommands("AIKill " ..Spring.GetLocalPlayerID())
	Spring.SendCommands("AIControl "..Spring.GetLocalPlayerID().." BtEvaluator")
	
	WG.BtEvaluator = BtEvaluator
	
	Dependency.fill(Dependency.BtEvaluator)
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
	
	-- messages without parameter
	if(messageType == "LOG") then 
		Logger.log("BtEvaluator", messageBody)
		return true
	elseif(messageType == "INITIALIZED") then 
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
