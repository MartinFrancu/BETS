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

-------------------------------------------------------------------------------------
local treeControlWindow
local controllerLabel
local treeTabPanel
local treeHandles = {}
-------------------------------------------------------------------------------------

local treeSelectionPanel
local treeSelectionLabel
local treeNameEditBox
local treeSelectionComboBox
local treeSelectionDoneButton

-------------------------------------------------------------------------------------

------------------------------------------------------------------------------------- 
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


-- To show in treeTabPanel tab with given name:
-- Here should be probably moved also a 
function highlightTab(tabName)
	-- first child should be the TabBar:
	local tabBarChildIndex = 1
	treeTabPanel:ChangeTab(tabName)
	treeTabPanel.children[tabBarChildIndex]:Select(tabName)
end


function addTreeToTreeTabPanel(treeHandle)
	local newTab =  {name = treeHandle.Name, children = treeHandle.ChiliComponents }
	-- no treeTabPanel is initialized
	treeTabPanel:AddTab(newTab)
	
	highlightTab(newTab.name)
	
	-- Now I should add a listener to show proper tree:
	-- get tabBar
	local tabBar = treeTabPanel.children[1]
	-- find corresponding tabBarItem: 
	local barItems = tabBar.children
	for index,item in ipairs(barItems) do
		if(item.caption == newTab.name) then
			-- add the listener
			local currentListeners  = item.OnMouseDown
			table.insert(currentListeners,listenerBtCreatorShowTreeButton)
			item.TreeHandle = treeHandle
		end
	end

end


function listenerBtCreatorShowTreeButton(self)
	Logger.log("communication", "Message to BtCreator send: message type SHOW_BTCREATOR tree type: " .. self.TreeHandle.TreeType)	
	Spring.SendLuaUIMsg("BETS SHOW_BTCREATOR ".. self.TreeHandle.TreeType )
end 



TreeHandle = {	
			Name = "no_name", 
			TreeType = "no_tree_type", 
			InstanceCode = "default", 
			Tree = "no_tree", 
			ChiliComponents = {},
			} 

function TreeHandle:New(obj)
	obj = obj or TreeHandle
	setmetatable(obj, self)
	self.__index = self
	obj.InstanceCode = "random_code" --TD
	obj.Tree = BehaviourTree.load(obj.TreeType)
	
	obj.ChiliComponents = {}
	
	
	treeTypeLabel = Chili.Label:New{
	x = 50,
	y = 15,
	height = 30,
	width =  200,
	minWidth = 50,
	caption =  obj.TreeType,
		skinName = "DarkGlass",
		--focusColor = {0.5,0.5,0.5,0.5},
	}
	-- Order of these childs is sort of IMPORTANT as other entities needs to access children
	table.insert(obj.ChiliComponents, treeTypeLabel)
	

	showTreeButton = Chili.Button:New{
		x = 150,
		y = 10,
		height = 30,
		width = 100,
		caption = "Show tree",
		OnClick = {listenerBtCreatorShowTreeButton},
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		--TreeHandle = obj,
	}

	showTreeButton.TreeHandle = obj 
	
	table.insert(obj.ChiliComponents, showTreeButton)
	
		
	labelNameTextBox = Chili.TextBox:New{
		x = 5,
		y = 50,
		height = 30,
		width =  150,
		minWidth = 50,
		text = "Assign selected units:",
		skinName = "DarkGlass",
		--focusColor = {0.5,0.5,0.5,0.5},
	}
	table.insert(obj.ChiliComponents, labelNameTextBox)
	
	
	labelAssignmentButton = Chili.Button:New{
		x = 150 ,
		y = 40,
		height = 30,
		width = '25%',
		minWidth = 150,
		caption = "Default role",
		OnClick = {listenerCreateTreeMessageButton}, 
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		TreeHandle = obj,
	}
	table.insert(obj.ChiliComponents, labelAssignmentButton)
	
	return obj
end

-------------------------------------------------------------------------------------
--	Contains	.name = "name of tree"
--				.tree = loaded tree into table
-- 				chiliComponents.labelAssignemntButton = button to assign currently selected units to this label
--				chiliComponents.labelNameTextBox = text box for assignment:
-- 				chiliComponents.showBtCreatorButton = button to show current tree in bt creator
-------------------------------------------------------------------------------------


function SendStringToBtEvaluator(message)
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), "BETS " .. message)
end


---------------------------------------LISTENERS
function listenerCreateTreeMessageButton(self)	
	-- self = button
	Logger.log("communication", "TreeHandle send a messsage. " )
	BtEvaluator.createTree(self.TreeHandle.Tree)
end



local function listenerClickOnSelectTreeButton(self)
	names = getNamesInDirectory(BehavioursDirectory, ".json")
	treeSelectionComboBox.items = names 
	treeSelectionComboBox:RequestUpdate()
	treeNameEditBox.text = "CHANGE_ME"
	treeControlWindow:Hide()
	treeSelectionWindow:Show()
end

local function listenerClickOnSelectedTreeDoneButton(self)
	local selectedTreeType = treeSelectionComboBox.items[treeSelectionComboBox.selected]
	--should not be needed anymore: name = name:sub(1,name:len()-5)
	--reloadTree(name)
	local newTreeHandle = TreeHandle:New{
		Name = treeNameEditBox.text,
		TreeType = selectedTreeType,
	}
	-- show the tree	
	addTreeToTreeTabPanel(newTreeHandle)
	listenerBtCreatorShowTreeButton({TreeHandle = newTreeHandle})

end



---------------------------------------LISTENERS
  

function setUpTreeSelectionTab()
 
   treeSelectionLabel = Chili.Label:New{
		--parent = treeSelectionWindow,
		x = 5,
		y = 5,
		width  = 70,
		height = 20,
		caption = "Select tree type:",
		skinName='DarkGlass',
   }

	local availableTreeTypes = getNamesInDirectory(BehavioursDirectory, ".json")
	
	treeSelectionComboBox = Chili.ComboBox:New{
		items = availableTreeTypes,
		width = '60%',
		x = 110,
		y = 4,
		align = 'left',
		skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0.3,0.3,0.3,0.3},
	}
	
	treeNameLabel = Chili.Label:New{
		x = 5,
		y = 35,
		width  = 70,
		height = 20,
		caption = "Tree instance name:",
		skinName='DarkGlass',
	}
	
	treeNameEditBox = Chili.EditBox:New{
		x = 150,
		y = 30,
		width  = 200,
		height = 20,
		text = "Instance0",
		skinName='DarkGlass',
		--align = 'center',
		borderThickness = 0,
		backgroundColor = {0.1,0.1,0.1,0},
		editingText = true,
	}

   	treeSelectionDoneButton = Chili.Button:New{
		x = 50,
		y = 60,
		width  = 50,
		height = 30,
		caption = "Done",
		skinName='DarkGlass',
		OnClick = {listenerClickOnSelectedTreeDoneButton},
    }	
  
	treeSelectionPanel = Chili.Control:New{
		x = '20%',
		y = '2%',
		width = 400,
		height = 120,
		padding = {10,10,10,10},
		draggable=false,
		resizable=true,
		skinName='DarkGlass',
		backgroundColor = {1,1,1,1},
		visible =false,
		children = {treeSelectionLabel, treeSelectionDoneButton, treeSelectionComboBox, treeNameLabel, treeNameEditBox}
	}

end


function setUpTreeControlWindow()
	treeControlWindow = Chili.Window:New{
    parent = Screen0,
    x = '15%',
    y = '1%',
    width  = 500 ,
    height = 200,--'10%',	
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
    caption = "BETS tree controller",
		skinName='DarkGlass',
	}
	
	-- now I should get the tree selection tab there
	
	setUpTreeSelectionTab()
	
	local newTab =  {name = "+", children = {treeSelectionPanel} }
	-- if TabPanel is not inialized I have to initalize it:
	treeTabPanel = Chili.TabPanel:New{
		parent = treeControlWindow,
		x = 0,
		y = 10,
		height = 570,
		width = '100%',
		tabs = {newTab}
	}	
end

function widget:Initialize()	
  -- Get ready to use Chili
  Chili = WG.ChiliClone
  Screen0 = Chili.Screen0	
  
  BtEvaluator = WG.BtEvaluator 
  
   -- Create the window
   
  setUpTreeControlWindow() 
  
  Spring.Echo("BtController reports for duty!")
  
end
  
Dependency.deferWidget(widget, Dependency.BtEvaluator)