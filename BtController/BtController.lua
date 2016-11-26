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
local BtEvaluator

local JSON = Utils.JSON
local BehaviourTree = Utils.BehaviourTree
local Dependency = Utils.Dependency

local Debug = Utils.Debug;
local Logger = Debug.Logger

 
--local windowBtController
local controllerLabel

-------------------------------------------------------------------------------------
local treeControlWindow
local selectTreeButton
-------------------------------------------------------------------------------------
local treeTabPanel
local treeSelectionWindow
local treeSelectionLabel
local selectedTreeEditBox
local treeSelectionComboBox
local treeSelectionDoneButton


-------------------------------------------------------------------------------------

local currentTreeData = {chiliComponents = {}} 

------------------------------------------------------------------------------------- 


TreeHandle = {	Name = "no_name", 
				TreeType = "no_tree_type", 
				InstanceCode = "default", 
				Tree = "no_tree", 
				ChiliComponents = {}} 


function TreeHandle:SendCreateTreeMessage()
	BtEvaluator.createTree(self.Tree)
end

--function TreeHandle:SendAssignTreeMessage()
--	-- TD send a message to BtEvaluator
--end

function TreeHandle:New(givenName, desiredTreeType)
	newHandle = TreeHandle
	newHandle.Name = givenName
	newHandle.TreeType = desiredTreeType
	newHandle.InstaceCode = "random_code" --TD
	newHandle.Tree =  BehaviourTree.load(self.TreeType)
	-- I should init the gui components
	
	labelNameTextBox = Chili.TextBox:New{
	x = 5,
	y = 54,
	height = 30,
	width =  100,
	minWidth = 50,
	text = "Assign selected units:",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
	}
	table.insert(newHandle.ChiliComponents, labelNameTextBox)
	
	
	labelAssignmentButton = Chili.Button:New{
	x = 100 ,
	y = 45,
	height = 30,
	width = '25%',
	minWidth = 150,
	caption = "Default role",
	OnClick = {TreeHandle:SendCreateTreeMessage()},
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
	}
	table.insert(newHandle.ChiliComponents, labelAssignmentButton)
	
	return newHandle
end

--	Contains	.name = "name of tree"
--				.tree = loaded tree into table
-- 				chiliComponents.labelAssignemntButton = button to assign currently selected units to this label
--				chiliComponents.labelNameTextBox = text box for assignment:
-- 				chiliComponents.showBtCreatorButton = button to show current tree in bt creator

-------------------------------------------------------------------------------------

--local showBtCreatorButton


local function changeLabel()
	controllerLabel:SetCaption("BtController ("..  currentTreeData.name .. ")")
end
local function reloadTree(treeName)
	currentTreeData.name = treeName
	currentTreeData.tree = BehaviourTree.load(currentTreeData.name)
	changeLabel()
end

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function string.ends(String,End)
   return End=='' or string.sub(String,-string.len(End))==End
end

local function getStringsWithoutSuffix(list, suff)
	-- returns list which contains only string without this suffix
	local result = {}
	for i,v in ipairs(list)do
		if(string.ends(v,suff)) then
		--vRes = v.sub(v, string.len( BehavioursDirectory)+2 )
		--table.insert(result,v.sub(1, v:len()))
		table.insert(result,v:sub(1,v:len()- suff:len()))
		end
   end
   return result
end


local function getNamesInDirectory(directoryName, suffix)
   local folderContent = VFS.DirList(directoryName)
   -- get just names .json files
   folderContent = getStringsWithoutSuffix(folderContent, ".json")
   -- Remove the path prefix of folder:
   for i,v in ipairs(folderContent)do
	folderContent[i] = string.sub(v, string.len( directoryName)+2 ) --THIS WILL MAKE TROUBLES WHEN DIRECTORY IS DIFFERENT: the slashes are sometimes counted once, sometimes twice!!!\\
   end
   return folderContent
end
---------------------------------------LISTENERS
local function listenerClickOnAssign(self)
	BtEvaluator.createTree(currentTreeData.tree)
	-- 
	-- SendStringToBtEvaluator("ASSIGN_UNITS")
end

local function listenerClickOnShowHideTree(self)
	WG.ShowBtCreator = not WG.ShowBtCreator
end

local function listenerClickOnSelectTreeButton(self)
	names = getNamesInDirectory(BehavioursDirectory, ".json")
	treeSelectionComboBox.items = names 
	treeSelectionComboBox:RequestUpdate()
	treeControlWindow:Hide()
	treeSelectionWindow:Show()
end

local function listenerClickOnSelectedTreeDoneButton(self)
	local name = treeSelectionComboBox.items[treeSelectionComboBox.selected]
	--should not be needed anymore: name = name:sub(1,name:len()-5)
	reloadTree(name)
	treeControlWindow:Show()
	treeSelectionWindow:Hide()
end

function listenerClickOnShowTreeButton(self)
	Logger.log("communication", "Message to BtCreator send: message type SHOW_BTCREATOR")
	Spring.SendLuaUIMsg("BETS SHOW_BTCREATOR ".. currentTreeData.name)
end

---------------------------------------LISTENERS

local function showHideTreeSelectionWindow()
	if(treeSelectionWindow.visible == false)then
		treeSelectionWindow:Show()
	else
		treeSelectionWindow:Hide()
	end
end



function SendStringToBtEvaluator(message)
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), "BETS " .. message)
end



  

function setUpTreeSelectionWindow()
   treeSelectionLabel = Chili.Label:New{
		--parent = treeSelectionWindow,
		x = '1%',
		y = '5%',
		width  = '40%',
		height = '10%',
		caption = "Select tree:",
		skinName='DarkGlass',
   }
   --[[local folderContent = VFS.DirList(BehavioursDirectory)
   -- Remove the path prefix
   for i,v in ipairs(folderContent)do
	folderContent[i] = string.sub(v, string.len( BehavioursDirectory)+2 )
   end
   
   folderContent = getStringsWithoutSuffix(folderContent, ".json")]]--
	names = getNamesInDirectory(BehavioursDirectory, ".json")
	
	treeSelectionComboBox = Chili.ComboBox:New{
		items = names,
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
		OnClick = {listenerClickOnSelectedTreeDoneButton},
    }
  
	treeSelectionWindow = Chili.Window:New{
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

function setUpTreeControlWindow()
	treeControlWindow = Chili.Window:New{
    parent = Screen0,
    x = '15%',
    y = '1%',
    width  = '35%' ,
    height = 600,--'10%',	
		padding = {10,10,10,10},
		draggable=false,
		resizable=true,
		skinName='DarkGlass',
		backgroundColor = {1,1,1,1},
	}
  
	controllerLabel = Chili.Label:New{
    parent = treeControlWindow,
	x = '1%',
	y = '1%',
    width  = '10%',
    height = '100%',
    caption = "BtController",
		skinName='DarkGlass',
	}
  
  
  
	selectTreeButton = Chili.Button:New{
    parent = treeControlWindow,
	x = 50,
	y = 15,
    width  = '20%',
    height = 30,
    caption = "Select tree",
	OnClick = {listenerClickOnSelectTreeButton},
		skinName='DarkGlass',
	}
	
	currentTreeData.chiliComponents.showBtCreatorButton = Chili.Button:New{
	parent = treeControlWindow,
	x = 200,
	y = 15,
	height = 30,
	width = '20%',
	minWidth = 150,
	caption = "Show tree",
	OnClick = {listenerClickOnShowTreeButton},
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
	}
	  
	currentTreeData.chiliComponents.labelAssignemntButton = Chili.Button:New{
	parent =  treeTabPanel,--treeControlWindow,
	x = 100 ,
	y = 45,
	height = 30,
	width = '25%',
	minWidth = 150,
	caption = "Default role",
	OnClick = {listenerClickOnAssign},
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
	}
	
	currentTreeData.chiliComponents.labelNameTextBox = Chili.TextBox:New{
	parent =  treeTabPanel, --parent = treeControlWindow, 
	x = 5,
	y = 54,
	height = 30,
	width =  100,
	minWidth = 50,
	text = "Assign selected units:",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
	}
  
	newTab = {name = "Start tab", children ={currentTreeData.chiliComponents.labelAssignemntButton, currentTreeData.chiliComponents.labelNameTextBox } }
	
	treeTabPanel = Chili.TabPanel:New{
		parent = treeControlWindow,
		x = 0,
		y = 35,
		height = 570,
		width = '100%',
		tabs = {newTab},
	}
	
	
	
	--treeTabPanel:AddTab(newTab)
end

function widget:Initialize()	
  -- Get ready to use Chili
  Chili = WG.ChiliClone
  Screen0 = Chili.Screen0	
  
  BtEvaluator = WG.BtEvaluator 
  
   -- Create the window
   
  setUpTreeControlWindow()
  treeControlWindow:Hide()
  
  setUpTreeSelectionWindow()
  treeSelectionWindow:Show()
  
 
  
  Spring.Echo("BtController reports for duty!")
  
end
  
Dependency.deferWidget(widget, Dependency.BtEvaluator)