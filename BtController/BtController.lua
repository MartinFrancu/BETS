--local BtSquadControlPath = LUAUI_DIRNAME .. "Widgets/BtController/BtSquadControl.lua"

--------------------------------------------------------------------------------
local BehavioursDirectory = "LuaUI/Widgets/BtBehaviours"
--------------------------------------------------------------------------------

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

local Chili, Screen0
local BtController = widget


local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)

local JSON = Utils.JSON

local Debug = Utils.Debug;
local Logger = Debug.Logger


 
local windowBtController
--local treeTabPanels
--local scrollPanel
local squadAssignemntButton
local controllerLabel
local squadName
local selectTreeButton


local windowTreeSelection
local treeSelectionLabel
local selectedTreeEditBox
local treeSelectionComboBox
local treeSelectionDoneButton

local showTreeSelectionWindow 


function listenerClickOnAssign(self)
	Spring.Echo("BETS CREATE_TREE SENDING UNITS")
	SendStringToBtEvaluator("ASSIGN_UNITS")
end

function showHideTreeSelectionWindow(self)
	if(windowTreeSelection.visible == false)then
		windowTreeSelection:Show()
	else
		windowTreeSelection:Hide()
	end
end

function SendStringToBtEvaluator(message)
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), "BETS " .. message)
end



  

  function setUpTreeSelectionWindow()
    treeSelectionLabel = Chili.Label:New{
		--parent = windowTreeSelection,
		x = '1%',
		y = '5%',
		width  = '40%',
		height = '10%',
		caption = "Write in name of tree:",
		skinName='DarkGlass',
   }
   local folderContent = VFS.DirList(BehavioursDirectory)
   -- Remove the directory..
   for i,v in ipairs(folderContent)do
	folderContent[i] = string.sub(v, string.len( BehavioursDirectory)+2 )
   end
   
   Logger.log("save-and-load", folderContent)
   
    
  --[[ treeName = Chili.EditBox:New{
		--parent = windowTreeSelection,
		text = "Patrol tree (not changebla yet)",
		width = '60%',
		x = '35%',
		y = '-1%',
		align = 'left',
		skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0.3,0.3,0.3,0.3},
		allowUnicode = false,
		editingText = false,
	} ]]--
	
	
	
	treeSelectionComboBox = Chili.ComboBox:New{
		items = folderContent,
		width = '60%',
		x = '35%',
		y = '-1%',
		align = 'left',
		skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0.3,0.3,0.3,0.3},
	}
	
	
	treeSelectionDoneButton = Chili.Button:New{
		x = '20%',
		y = '50%',
		width  = '40%',
		height = 30,
		caption = "Done",
		skinName='DarkGlass',
		OnClick = {showHideTreeSelectionWindow},
    }
  
	windowTreeSelection = Chili.Window:New{
		parent = Screen0,
		x = '20%',
		y = '11%',
		width = '25%',
		height = '8%',
		padding = {10,10,10,10},
		draggable=false,
		resizable=true,
		skinName='DarkGlass',
		backgroundColor = {1,1,1,1},
		visible =false,
		children = {treeSelectionLabel, treeSelectionDoneButton, treeSelectionComboBox}
   }
   

end

function widget:Initialize()	
  -- Get ready to use Chili
  Chili = WG.ChiliClone
  Screen0 = Chili.Screen0	
  
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
  
  selectTreeButton = Chili.Button:New{
    parent = windowBtController,
	x = 50,
	y = 15,
    width  = '20%',
    height = 30,
    caption = "Select tree",
	OnClick = {showHideTreeSelectionWindow},
		skinName='DarkGlass',
  }
  
  

  
  squadAssignemntButton = Chili.Button:New{
	parent = windowBtController,
	x = 50 ,
	y = 45,
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
	y = 54,
	height = 30,
	width =  50, --'50%',
	minWidth = 50,
	text = "Patrol:",
	--skinName = "DarkGlass",
	--focusColor = {0.5,0.5,0.5,0.5},
  }
  
  setUpTreeSelectionWindow()
  windowTreeSelection:Hide()
  --windowTreeSelection.visible = false
  
  Spring.Echo("BtController reports for duty!")
  

  
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