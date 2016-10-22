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

local Chili
local Screen0

local testbutton
local msgCommandButton
local moveCommandButton

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
  if (not WG.Chili) then
    -- don't run if we can't find Chili
    widgetHandler:RemoveWidget()
    return
  end
 
  -- Get ready to use Chili
  Chili = WG.Chili
  Screen0 = Chili.Screen0
	
	testbutton = Chili.Button:New{
		parent = Screen0,
		caption = "Send Message to AI",
		x = '80%',
		y = '90%',
		OnClick = { listenerOnTestButtonClick },
		width = 150,
		height = 60,
	}

	nodeDefinitionRequestButton = Chili.Button:New{
		parent = Screen0,
		caption = "Retrieve node definitions",
		x = '70%',
		y = '90%',
		OnClick = { listenerOnNodeDefinitionButtonClick },
		width = 150,
		height = 60,
	}

	createTreeCommandButton = Chili.Button:New {
		parent = Screen0,
		caption = "Create tree",
		x = '60%',
		y = '90%',
		OnClick = { listenerOnMoveButtonClick },
		width = 150,
		height = 60,
	}

	-- Add control of my units also to our BtEvaluator -> Cpp AI
	Spring.SendCommands("AIControl "..Spring.GetLocalPlayerID().." BtEvaluator")
	-- Spring.Echo("GetLocalPlayerID(): "..Spring.GetLocalPlayerID())
end

function widget:RecvSkirmishAIMessage(aiTeam, aiMessage)
	Spring.Echo("Message from AI received: "..aiMessage)
end