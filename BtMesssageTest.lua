function widget:GetInfo()
  return {
    name    = "BtMessageTest",
    desc    = "Widget to intermediate players commands to Behaviour Tree Evaluator. ",
    author  = "BETS team",
    date    = "today",
    license = "GNU GPL v2",
    layer   = 0,
    enabled = true
  }
end

-- Include debug functions, copyTable() and dump()
--VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCreator/debug_utils.lua", nil, VFS.RAW_FIRST)
local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
local Debug = Utils.Debug;
local Logger, dump, copyTable, fileTable = Debug.Logger, Debug.dump, Debug.copyTable, Debug.fileTable

local Chili, Screen0 --,JSON

local windowMessageTest

local sendMessagesButton
local doubleMessageLengthButton
local doubleMessageCountButton

local messageCountEditBox
local messageLenghtEditBox
local countTextBox
local legnthTextBox
local scrollPanel
local receivedMSGTextBox
local nomessage


local message
local lastMessageSendTime


function addToReceivedMSGTextBox(message)
    if(nomessage == 1) then
		receivedMSGTextBox:SetText(message)
		nomessage = 0
	else
		receivedMSGTextBox:SetText(receivedMSGTextBox.text.."\n"..message)
	end
	scrollPanel:SetScrollPos(0,receivedMSGTextBox.height)
end

function listenerClickOnSend(self)
	local length = tonumber(messageLenghtEditBox.text)

	if(string.len(message) ~= length) then
	  addToReceivedMSGTextBox("need to create messsage")
	  message = "a"
      for i=1, length-1 do
	    message = message .. "a"
	  end
	  addToReceivedMSGTextBox("message created")
	end
	local count = tonumber(messageCountEditBox.text)
	lastMessageSendTime = os.clock()
	for i=1, count do
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), "BETS TMSG " .. message)
	end
end


function listenerClickOnDoubleLength(self)
	local length = tonumber( messageLenghtEditBox.text)
	if(string.len(message) == length) then
	  message = message .. message
	end
	length = 2 * length
	messageLenghtEditBox:SetText(tostring(length))
end


function listenerClickOnDoubleCount(self)
    local count = tonumber( messageCountEditBox.text)
	count = 2 * count
	messageCountEditBox:SetText( tostring(count))
end



function widget:RecvSkirmishAIMessage(aiTeam, message)
	-- Dont respond to other players AI
	if(aiTeam ~= Spring.GetLocalPlayerID()) then
		Logger.log("communication", "Message from AI received: aiTeam ~= Spring.GetLocalPlayerID()")
		return
	end
	-- Check if it starts with "BETS"
	if(message:len() <= 4 and message:sub(1,4):upper() ~= "BETS") then
		Logger.log("communication", "Message from AI received: beginning of message is not equal 'BETS', got: "..message:sub(1,4):upper())
		return
	end
	messageShorter = message:sub(6)
	indexOfFirstSpace = string.find(messageShorter, " ")
	messageType = messageShorter:sub(1, indexOfFirstSpace - 1):upper()	
	messageBody = messageShorter:sub(indexOfFirstSpace + 1)
	Logger.log("communication", "Message from AI received: message body: "..messageBody)
	if(messageType == "TMSGREPORT") then
		addToReceivedMSGTextBox("message received in: "..tostring(os.clock() - lastMessageSendTime) )
		Logger.log("communication", "Message from AI received: message type UPDATE_STATES")
		addToReceivedMSGTextBox(messageBody)
		--Spring.Echo("BtMessageTest, got message: "..messageBody )
	end
	--[[if(messageType == "UPDATE_STATES") then 
		Logger.log("communication", "Message from AI received: message type UPDATE_STATES")
		updateStatesMessage(messageBody)		
	elseif (messageType == "NODE_DEFINITIONS") then 
		Logger.log("communication", "Message from AI received: message type NODE_DEFINITIONS")
		generateNodePoolNodes(messageBody)
	elseif (messageType == "COMMAND") then
		return executeScript(messageBody)
	end]]--
end


function widget:Initialize()
		
  -- Get ready to use Chili
  Chili = WG.ChiliClone
  Screen0 = Chili.Screen0	
  -- we dont need JSON I guess
  --JSON = WG.JSON
  
  message = "Ahoj"
  
   -- Create the window
  windowMessageTest = Chili.Window:New{
    parent = Screen0,
    x = 300,
    y = 120,
    width  = 500,
    height = 250,	
		padding = {10,10,10,10},
		draggable=false,
		resizable=true,
		skinName='DarkGlass',
		backgroundColor = {1,1,1,1},
  }
  
  lengthTextBox = Chili.TextBox:New{
	parent = windowMessageTest, 
	x = 5,
	y = 5,
	height = 30,
	width =  150, 
	text = "How long messages:",
  }
  
  countTextBox = Chili.TextBox:New{
	parent = windowMessageTest, 
	x = 5,
	y = 35,
	height = 30,
	width =  150,
	text = "How many messages:",
  }
  
  sendMessagesButton = Chili.Button:New{
	parent = windowMessageTest,
	x = 10,
	y = 60,
	height = 40,
	width = 140,
	caption = "Send",
	OnClick = {listenerClickOnSend},
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
	}
	
  doubleMessageLengthButton = Chili.Button:New{
	parent = windowMessageTest,
	x = 150 ,
	y = 60,
	height = 40,
	width = 120,
	caption = "Double length",
	OnClick = {listenerClickOnDoubleLength},
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
	}
	
  doubleMessageCountButton = Chili.Button:New{
	parent = windowMessageTest,
	x = 270,
	y = 60,
	height = 40,
	width = 120,
	caption = "Double count",
	OnClick = {listenerClickOnDoubleCount},
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
	}
  
  messageCountEditBox = Chili.EditBox:New{
		parent = windowMessageTest,
		text = "1",
		width = 300,
		x = 150,
		y = 30,
		align = 'left',
		skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0.3,0.3,0.3,0.3},
		allowUnicode = false,
		editingText = true,
	}
	
  messageLenghtEditBox = Chili.EditBox:New{
		parent = windowMessageTest,
		text = "4",
		width = 300,
		x = 150,
		y = 5,
		align = 'left',
		skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0.3,0.3,0.3,0.3},
		allowUnicode = false,
		editingText = true,
	}

  scrollPanel = Chili.ScrollPanel:New{
		parent = windowMessageTest,
		y = 100,
		x = 5,
		width  = 470,
		height = 125,
		skinName='DarkGlass',
	}
	
  receivedMSGTextBox = Chili.TextBox:New{
  parent = scrollPanel,
  x = 10,
  y = 10,
  text = "no message received yet",
  }	
  nomessage = 1
end


