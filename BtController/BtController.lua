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
local BtEvaluator, BtCreator

local JSON = Utils.JSON
local BehaviourTree = Utils.BehaviourTree
local Dependency = Utils.Dependency

local Debug = Utils.Debug;
local Logger = Debug.Logger

-------------------------------------------------------------------------------------
local treeControlWindow
local controllerLabel
local selectTreeButton
local treeTabPanel
local treeHandles = {}
-------------------------------------------------------------------------------------
local treeSelectionWindow
local treeSelectionLabel
local treeNameEditBox
local treeSelectionComboBox
local treeSelectionDoneButton
local showBtCreatorButton

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

-- //////////////////////////////////////////////////////////////////////////////////////////////////////
-- Id Generation
local alphanum = {
	"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
	"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
	"0","1","2","3","4","5","6","7","8","9"
	}

local usedIDs = {}
	
function GenerateID()
	local length = 32
	local str = ""
	for i = 1, length do
		str = str..alphanum[math.random(#alphanum)]
	end
	if(usedIDs[str] ~= nil) then
		return GenerateID()
	end
	usedIDs[str] = true
	return str	
end
-- //////////////////////////////////////////////////////////////////////////////////////////////////////

function addTreeToTreeTabPanel(treeHandle)
	local newTab =  {name = treeHandle.Name, children = treeHandle.ChiliComponents }
	-- if TabPanel is not inialized I have to initalize it:
	if(treeTabPanel == nil)then
		treeTabPanel = Chili.TabPanel:New{
		parent = treeControlWindow,
		x = 0,
		y = 50,
		height = 570,
		width = '100%',
		tabs = {newTab}
	}
	else
	-- no treeTabPanel is initialized
	treeTabPanel:AddTab(newTab)
	end
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
	if(not BtCreator)then return end
	
	BtEvaluator.reportTree(self.TreeHandle.InstanceId)
	BtCreator.show(self.TreeHandle.TreeType)
end 



TreeHandle = {
			Name = "no_name", 
			TreeType = "no_tree_type", 
			InstanceId = "default", 
			Tree = "no_tree", 
			ChiliComponents = {},
			} 

function TreeHandle:New(obj)
	obj = obj or TreeHandle
	setmetatable(obj, self)
	self.__index = self
	obj.InstanceId = GenerateID()
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


---------------------------------------LISTENERS
function listenerCreateTreeMessageButton(self)	
	-- self = button
	Logger.log("communication", "TreeHandle send a messsage. " )
	BtEvaluator.createTree(self.TreeHandle.InstanceId, self.TreeHandle.Tree)
	BtEvaluator.reportTree(self.TreeHandle.InstanceId)
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
	treeControlWindow:Show()
	treeSelectionWindow:Hide()

end



---------------------------------------LISTENERS
  

function setUpTreeSelectionWindow()
 
   treeSelectionLabel = Chili.Label:New{
		--parent = treeSelectionWindow,
		x = 5,
		y = 5,
		width  = 70,
		height = 20,
		caption = "Select tree type:",
		skinName='DarkGlass',
   }
   --[[local folderContent = VFS.DirList(BehavioursDirectory)
   -- Remove the path prefix
   for i,v in ipairs(folderContent)do
	folderContent[i] = string.sub(v, string.len( BehavioursDirectory)+2 )
   end
   
   folderContent = getStringsWithoutSuffix(folderContent, ".json")]]--
	local availibleTreeTypes = getNamesInDirectory(BehavioursDirectory, ".json")
	
	treeSelectionComboBox = Chili.ComboBox:New{
		items = availibleTreeTypes,
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
		text = "CHANGE_ME",
		skinName='DarkGlass',
		--align = 'center',
		borderThickness = 0,
		backgroundColor = {0.1,0.1,0.1,0},
		editingText = true,
	}

   	treeSelectionDoneButton = Chili.Button:New{
		x = 50,
		y = 60,
		width  = '40%',
		height = 30,
		caption = "Done",
		skinName='DarkGlass',
		OnClick = {listenerClickOnSelectedTreeDoneButton},
    }	
	
  
	treeSelectionWindow = Chili.Window:New{
		parent = Screen0,
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
    caption = "BtController",
		skinName='DarkGlass',
	}
  
  
  
	selectTreeButton = Chili.Button:New{
    parent = treeControlWindow,
	x = 5,
	y = 15,
    width  = 150,
    height = 30,
    caption = "Add tree instance",
	OnClick = {listenerClickOnSelectTreeButton},
		skinName='DarkGlass',
	}
	
--[[	showBtCreatorButton = Chili.Button:New{
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
--]]
--[[
	currentTreeData.chiliComponents
	  
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
  
	newTab = {name = "Start tab", children = {currentTreeData.chiliComponents.labelAssignemntButton, currentTreeData.chiliComponents.labelNameTextBox } }
	
	treeTabPanel = Chili.TabPanel:New{
		parent = treeControlWindow,
		x = 0,
		y = 35,
		height = 570,
		width = '100%',
	}
	treeTabPanel:AddTab(newTab) 
	--]]
end

function widget:Initialize()	
  -- Get ready to use Chili
  Chili = WG.ChiliClone
  Screen0 = Chili.Screen0	
  
  BtEvaluator = WG.BtEvaluator 
	-- extract BtCreator into a local variable once available
	Dependency.defer(function() BtCreator = WG.BtCreator end, Dependency.BtCreator)
  
   -- Create the window
   
  setUpTreeControlWindow()
  treeControlWindow:Hide()
  
  setUpTreeSelectionWindow()
  treeSelectionWindow:Show()
  
 
  
  Spring.Echo("BtController reports for duty!")
 
 	Dependency.fill(Dependency.BtController)
end
  
Dependency.deferWidget(widget, Dependency.BtEvaluator)