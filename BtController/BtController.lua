--local BtSquadControlPath = LUAUI_DIRNAME .. "Widgets/BtController/BtSquadControl.lua"



function widget:GetInfo()
  return {
    name    = "BtController",
    desc    = "Widget to intermediate players commands to Behaviour Tree Evaluator. ",
    author  = "BETS team",
    date    = "today",
    license = "GNU GPL v2",
    layer   = 0,
    enabled = true
  }
end

local Chili, Screen0, JSON
local BtController = widget

local windowBtController
local treeTabPanels
local scrollPanel
local squadAssignemntButton
local controllerLabel
local squadName


function listenerClickOnAssign(self)
	Spring.Echo("BETS CREATE_TREE SENDING UNITS")
	SendStringToBtEvaluator("ASSIGN_UNITS")
end

function SendStringToBtEvaluator(message)
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), "BETS " .. message)
end



function widget:Initialize()	
  --[[if (not WG.ChiliClone) or (not WG.JSON) or (not WG.BtEvaluatorIsLoaded) then
    -- don't run if we can't find Chili, or JSON, or BtEvaluatorLoader
    widgetHandler:RemoveWidget()
    return
  end]]--
 
  -- Get ready to use Chili
  Chili = WG.ChiliClone
  Screen0 = Chili.Screen0	
  JSON = WG.JSON
  
   -- Create the window
  windowBtController = Chili.Window:New{
    parent = Screen0,
    x = '15%',
    y = '1%',
    width  = '35%' ,
    height = '10%',	
		padding = {10,10,10,10},
		draggable=false,
		resizable=true,
		skinName='DarkGlass',
		backgroundColor = {1,1,1,1},
		-- OnMouseDown = { listenerStartSelectingNodes },
		-- OnMouseUp = { listenerEndSelectingNodes },
  }
  
  controllerLabel = Chili.Label:New{
    parent = windowBtController,
	x = '1%',
	y = '1%',
    width  = '10%',
    height = '100%',
    caption = "BtController - Patrol tree",
		skinName='DarkGlass',
  }
  

  
  squadAssignemntButton = Chili.Button:New{
	parent = windowBtController,
	x = '10%' ,
	y = 30,
	height = 30,
	width = '20%',
	minWidth = 150,
	caption = "Assign selected units",
	OnClick = {listenerClickOnAssign},
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
	
	}
	
  squadName = Chili.TextBox:New{
	parent = windowBtController, 
	x = '2%',
	y = 38,
	height = 30,
	width =  50, --'50%',
	minWidth = 50,
	text = "Patrol:",
	--skinName = "DarkGlass",
	--focusColor = {0.5,0.5,0.5,0.5},
  }
  
  Spring.Echo("BtController report for duty!")
  
  
 -------------------------------------------------------------------------------
 ----------------------UNUSED PARTS (stupid thinqs i was messing around):-------
 -------------------------------------------------------------------------------
 -------------------------------------------------------------------------------
 
 
  --VFS.Include(BtSquadControlPath, BtController, VFS.RAW_FIRST )
  --dofile(BtSquadControlPath)
  
 --[[ BtSquadControl = Chili.Control:Inherit{
  classname= "BtSquadControl",
  caption  = 'SquadControl', 
  defaultWidth  = 70,
  defaultHeight = 20,
}--]]
  
--[[	
	BtControllerPanel = Chili.ScrollPanel:New{
		parent = Screen0,
		y = '0%',
		x = '35%',
		width  = 125,
		minWidth = 50,
		height = 50,
		skinName='DarkGlass',
	}]]--

  
	
 --[[ squadControlBasic = Chili.Button:New{
	parent = windowBtController,
	x = '10%',
    y = '10%' }]]--
  
  
--[[    squadControlBasic = BtController.BtSquadControl:New{
	parent = windowBtController,
	x = '10%',
    y = '10%' } ]]--

  
  --[[scrollPanel = Chili.ScrollPanel:New{
		parent = windowBtController,
		x = '1%',
		y = '1%',
		width ='100%',
		height = '100%'
		}]]--

	
 --[[ treeTabPanels = Chili.TabPanel:New{
	parent = windowBtController,
	x = '0%',
	y = '0%',
	width = '100%',
	height = '100%',
	tabs = {{name = "Patrol tree", child = scrollPanel}},
	currentTab = scrollPanel
  } ]]--
 -- scrollPanel:SetParent(treeTabPanels)

--[[	BtControllerLabel = Chili.Label:New{
    parent = windowBtController,
		x = '20%',
		y = '3%',
    width  = '10%',
    height = '10%',
    caption = "BtController",
		skinName='DarkGlass',
  }  
	]]--

	
end