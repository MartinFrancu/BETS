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
local treeSelectionPanel
local treeSelectionLabel
local treeNameEditBox
local treeSelectionComboBox
local treeSelectionDoneButton
--------------------------------------------------------------------------------
local errorWindow
local errorLabel
local errorOkButton
--------------------------------------------------------------------------------

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
local instanceIdCount = 0

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
	instanceIdCount = instanceIdCount + 1
	return str	
end
-- //////////////////////////////////////////////////////////////////////////////////////////////////////





-- To show in treeTabPanel tab with given name:
-- Here should be probably moved also a 
function highlightTab(tabName)
	-- first child should be the TabBar:
	local tabBarChildIndex = 1
	treeTabPanel:ChangeTab(tabName)
	treeTabPanel.children[tabBarChildIndex]:Select(tabName)
end


function getBarItemByName(tabs, tabName)
	local tabBarChildIndex = 1
	-- get tabBar
	local tabBar = tabs.children[tabBarChildIndex]
	-- find corresponding tabBarItem: 
	local barItems = tabBar.children
	for index,item in ipairs(barItems) do
		if(item.caption == tabName) then
			return item
		end
	end
end

-- The following function will find tabBarItem witch such name and add to atributs under this name given data.
function addFieldToBarItem(tabs, tabName, atributName, atribut)
	item = getBarItemByName(tabs,tabName)
	if item[atributName] == nil then
				item[atributName] = atribut
			else
				local currentAtt = item[atributName]
				table.insert(currentAtt, atribut)
			end
end






function addTreeToTreeTabPanel(treeHandle)
	local newTab =  {name = treeHandle.Name, children = treeHandle.ChiliComponents }
	-- if TabPanel is not inialized I have to initalize it:
	treeTabPanel:AddTab(newTab)
	highlightTab(newTab.name)
	
	-- Now I should add a listener to show proper tree:
	-- get tabBar		
	addFieldToBarItem(treeTabPanel, newTab.name, "OnClick",listenerBarItemClick)
	addFieldToBarItem(treeTabPanel, newTab.name, "TreeHandle", treeHandle)
	
	moveToEndAddTab(treeTabPanel)
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



function SendStringToBtEvaluator(message)
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), "BETS " .. message)
end


function removeTreeBtController(tabs,treeHandle)
	-- remove the bar item
	local tabBarChildIndex = 1
	-- get tabBar
	local tabBar = tabs.children[tabBarChildIndex]
	tabBar:Remove(treeHandle.Name)
	-- remove chili elements ?
	local deleteFrame = tabs.tabIndexMapping[treeHandle.Name]
	tabs.currentTab:RemoveChild(deleteFrame)
	-- remove from tabPanel name-frame map
	tabs.tabIndexMapping[treeHandle.Name] = nil
	-- make sure addtab is in right place
	moveToEndAddTab(tabs)
	-- remove send message to BtEvaluator
	BtEvaluator.removeTree(treeHandle.InstanceId)
end


function showErrorWindow(errorDecription)
	errorLabel.caption = errorDecription
	errorWindow:Show()
end
---------------------------------------LISTENERS
local function listenerRefreshTreeSelectionPanel(self)
	names = getNamesInDirectory(BehavioursDirectory, ".json")
	treeSelectionComboBox.items = names 
	treeSelectionComboBox:RequestUpdate()
	treeNameEditBox.text = "Instance"..instanceIdCount
end


function listenerBarItemClick(self, x, y, button)
	if button == 1 then
		--left click
		if(not BtCreator)then return end
	
		BtEvaluator.reportTree(self.TreeHandle.InstanceId)
		BtCreator.show(self.TreeHandle.TreeType)
	end
	if button == 2 then
		--middle click
		removeTreeBtController(treeTabPanel, self.TreeHandle)
	end
end 



function listenerCreateTreeMessageButton(self)	
	-- self = button
	Logger.log("communication", "TreeHandle send a messsage. " )
	BtEvaluator.createTree(self.TreeHandle.InstanceId, self.TreeHandle.Tree)
	BtEvaluator.reportTree(self.TreeHandle.InstanceId)
end


function listenerErrorOk(self)
	errorWindow:Hide()
end





local function listenerClickOnSelectedTreeDoneButton(self, x, y, button)
	if button == 1 then
		-- we react only on leftclicks
		
		-- check if instance name is not being used:
		
		if(treeTabPanel.tabIndexMapping[treeNameEditBox.text] == nil ) then
			-- instance with such name is not used
			local selectedTreeType = treeSelectionComboBox.items[treeSelectionComboBox.selected]
			--should not be needed anymore: name = name:sub(1,name:len()-5)
			--reloadTree(name)
			local newTreeHandle = TreeHandle:New{
				Name = treeNameEditBox.text,
				TreeType = selectedTreeType,
			}
			-- show the tree
	
			addTreeToTreeTabPanel(newTreeHandle)
	
			listenerBarItemClick({TreeHandle = newTreeHandle},0,0,1)
		else
			-- if such instance name exits show error window
			showErrorWindow("Duplicate instance name.")
		end
	end
end

---------------------------------------LISTENERS
function moveTabItemToEndWithListeners(tabs,tabName)
	-- Trouble is that we add listeners on barItems, now I have to move them with me. 
	-- do we have such tab
	----[[
	if tabs.tabIndexMapping[tabName] == nil then
		-- Or should I report it:
		Logger.log("Error", "Trying to move tab and it is not there.")
		return
	end
	--]]
	local tabBarChildIndex = 1
	-- get tabBar
	local tabBar = tabs.children[tabBarChildIndex]
	-- find corresponding tabBarItem: 
	local onClickListeners
	local barItems = tabBar.children
	for index,item in ipairs(barItems) do
		if(item.caption == tabName) then
			-- get listeners
			onClickListeners = item.OnMouseDown
		end
	end
	

	tabBar:Remove(tabName)
	local newTabBarItem = Chili.TabBarItem:New{caption = tabName, defaultWidth = tabBar.minItemWidth, defaultHeight = tabBar.minItemHeight}
	newTabBarItem.OnMouseDown = onClickListeners
	tabBar:AddChild(
        newTabBarItem
    )
end

function moveToEndAddTab(tabs)
	-- do we have such tab
	----[[
	if tabs.tabIndexMapping["+"] == nil then
		-- Or should I report it:
		Logger.log("Error", "Trying to move + tab and it is not there.")
		return
	end
	--]]
	
	listenerRefreshTreeSelectionPanel()
	
	local tabBarChildIndex = 1
	-- get tabBar
	local tabBar = tabs.children[tabBarChildIndex]
	if (#(tabBar.children) >= 2) then
		-- if tabBar.children < 2 then Remove wont do anything.. and we hope that "+" is the only and last tab
		tabBar:Remove("+")
		local newTabBarItem = Chili.TabBarItem:New{
			caption = "+", 
			defaultWidth = tabBar.minItemWidth, 
			defaultHeight = tabBar.minItemHeight
		}
		tabBar:AddChild(
			newTabBarItem
		)
		finalizeAddTreeBarItem(tabs)
	end
end


  
function finalizeAddTreeBarItem(tabs)
	local item = getBarItemByName(tabs, "+")
	item.focusColor = {0.2, 1.0, 0.2, 0.6}
	local listeners = item.OnMouseDown
	table.insert(listeners,listenerRefreshTreeSelectionPanel)
end

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
		text = "Instance"..instanceIdCount,
		skinName='DarkGlass',
		--align = 'center',
		borderThickness = 0,
		backgroundColor = {0.1,0.1,0.1,0},
		editingText = true,
	}

   	treeSelectionDoneButton = Chili.Button:New{
		x = 50,
		y = 60,
		width  = 60,
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
    caption = "BtController",
		skinName='DarkGlass',
	}

	setUpTreeSelectionTab()
	
	local newTab = {name = "+", children = {treeSelectionPanel} }
	
	treeTabPanel = Chili.TabPanel:New{
		parent = treeControlWindow,
		x = 0,
		y = 10,
		height = 570,
		width = '100%',
		tabs = {newTab}
	}
	
	finalizeAddTreeBarItem(treeTabPanel)
	
end

function setUpErroWindow()
	errorWindow = 	Chili.Window:New{
		parent = treeSelectionPanel,
		x = 50,
		y = 20,
		width  = 200 ,
		height = 80,--'10%',	
		padding = {10,10,10,10},
		draggable=false,
		resizable=true,
		skinName='DarkGlass',
		backgroundColor = {1,1,1,1},
	}

	errorLabel = Chili.Label:New{
		parent = errorWindow,
		x = '3%',
		y = 10,
		width  = '80%',
		height = 80,
		caption = "BtController Error",
		skinName='DarkGlass',
	}
	errorOkButton = Chili.Button:New{
		parent = errorWindow,
		x = 20,
		y = 40,
		width  = 60,
		height = 20,
		caption = "Ok",
		skinName='DarkGlass',
		OnClick = {listenerErrorOk},
    }	
	errorWindow:Hide()
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
  
	setUpErroWindow()
	Spring.Echo("BtController reports for duty!")
 
 	Dependency.fill(Dependency.BtController)
end
  
Dependency.deferWidget(widget, Dependency.BtEvaluator)