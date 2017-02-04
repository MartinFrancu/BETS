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
local dump = Debug.dump

--------------------------------------------------------------------------------
VFS.Include("LuaRules/Configs/customcmds.h.lua")
--------------------------------------------------------------------------------


local treeControlWindow
local controllerLabel
local selectTreeButton
local treeTabPanel
local showTreeCheckbox
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
-- This table is indexed by unitId and contains structures:
-- {InstanceId = "", Role = "", TreeHandle = treehandle} 
local unitsToTreesMap

------------------------------------------------------------------------------------- 
function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function string.ends(String,End)
   return End=='' or string.sub(String,-string.len(End))==End
end

local function isInTable(value, t)
	for i=1,#t do
		if(t[i] == value) then
			return true
		end
	end
	return false
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


-- The following function will find tabBarItem with such name and add to atributs under this name given data.
function addFieldToBarItem(tabs, tabName, atributName, atribut)
	item = getBarItemByName(tabs,tabName)
	item[atributName] = atribut
end
-- The following function will find tabBarItem witch such name and add to atributs under this name given data. 
-- It expects a list, so if it is empty it will add a list containing given value. 
function addFieldToBarItemList(tabs, tabName, atributName, atribut)
	item = getBarItemByName(tabs,tabName)
	if item[atributName] == nil then
				item[atributName] = {atribut}
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
	addFieldToBarItem(treeTabPanel, newTab.name, "MouseDown", tabBarItemMouseDownBETS)
	addFieldToBarItemList(treeTabPanel, newTab.name, "OnClick", listenerBarItemClick )
	addFieldToBarItem(treeTabPanel, newTab.name, "TreeHandle", treeHandle)
	
	moveToEndAddTab(treeTabPanel)
end







TreeHandle = {
			Name = "no_name", 
			TreeType = "no_tree_type", 
			InstanceId = "default", 
			Tree = "no_tree", 
			ChiliComponents = {},
			Roles = {},
			} 
			
-------------------------------------------------------------------------------------
--	Contains	.Name = "name of tree"
--				.TreeType = loaded tree into table
-- 				.InstanceId = id of this given instance 
--				chiliComponents = array ofchili components corresponding to this tree
--				Roles = table indexed by roleName containing reference to 
--					chili components and other stuff: {assignButton = , unitCountLabel =, roleIndex =, unitTypes  }
	
-------------------------------------------------------------------------------------

function TreeHandle:New(obj)
	obj = obj -- or TreeHandle
	setmetatable(obj, self)
	self.__index = self
	obj.InstanceId = GenerateID()
	obj.Tree = BehaviourTree.load(obj.TreeType)
	
	obj.ChiliComponents = {}
	obj.Roles = {}
	
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
	
	if (obj.Tree.roles ~= nil) then
		-- THERE ARE ROLE DATA ASSIGNED:
		local roleInd = 0 
		roleCount = #obj.Tree.roles
		for _,roleData in pairs(obj.Tree.roles) do
			roleName = roleData.name
			local unitsCountLabel = Chili.Label:New{
				x = 150+200 ,
				y = 43 + 22 * roleInd,
				height = roleCount == 1 and 30 or 20,
				width = '25%',
				minWidth = 150,
				caption = 0, 
				skinName = "DarkGlass",
				focusColor = {0.5,0.5,0.5,0.5},
				instanceId = obj.InstanceId
			}
			table.insert(obj.ChiliComponents, unitsCountLabel)
			local roleAssignmentButton = Chili.Button:New{
				x = 150 ,
				y = 40 + 22 * roleInd,
				height = roleCount == 1 and 30 or 20,
				width = '25%',
				minWidth = 150,
				caption = roleName,
				OnClick = {listenerAssignUnitsButton}, 
				skinName = "DarkGlass",
				focusColor = {0.5,0.5,0.5,0.5},
				TreeHandle = obj,
				Role = roleName,
				roleIndex = roleInd,
				unitsCountLabel = unitsCountLabel,
				instanceId = obj.InstanceId
			}
			table.insert(obj.ChiliComponents, roleAssignmentButton)
			-- get the role unit types:
			local roleUnitTypes = {}
			for _,catName in pairs(roleData.cathegories) do
				 local unitTypes = BtUtils.UnitCathegories.getCathegoryTypes(catName)
				 for _,unitType in pairs(unitTypes) do
					roleUnitTypes[unitType] = 1
				 end
			end
			Logger.log("roles", "unitTypes ", roleUnitTypes)
			obj.Roles[roleName]={
					assignButton = roleAssignmentButton,
					unitCountLabel = unitsCountLabel,
					roleIndex = roleInd,
					unitTypes = roleUnitTypes
				}
			roleInd = roleInd +1
		end
	else -- no role data, doing the default roles:
	-- this should be removed later
		
		local roleCount = 1
		local function visit(node)
			if(node.nodeType == "roleSplit" and roleCount < #node.children)then
				roleCount = #node.children
			end
			for _, child in ipairs(node.children) do
				visit(child)
			end
		end
		visit(obj.Tree.root)
	
	
		for roleIndex = 0, roleCount - 1 do
			roleName = roleCount == 1 and "Default role" or "Role " .. tostring(roleIndex)
			local unitsCountLabel = Chili.Label:New{
				x = 150+200 ,
				y = 43 + 22 * roleIndex,
				height = roleCount == 1 and 30 or 20,
				width = '25%',
				minWidth = 150,
				caption = 0, 
				skinName = "DarkGlass",
				focusColor = {0.5,0.5,0.5,0.5},
				instanceId = obj.InstanceId
			}
			table.insert(obj.ChiliComponents, unitsCountLabel)
			local roleAssignmentButton = Chili.Button:New{
				x = 150 ,
				y = 40 + 22 * roleIndex,
				height = roleCount == 1 and 30 or 20,
				width = '25%',
				minWidth = 150,
				caption = roleName,
				OnClick = {listenerAssignUnitsButton}, 
				skinName = "DarkGlass",
				focusColor = {0.5,0.5,0.5,0.5},
				TreeHandle = obj,
				Role = roleName,
				roleIndex = roleIndex,
				unitsCountLabel = unitsCountLabel,
				instanceId = obj.InstanceId
			}
		
			table.insert(obj.ChiliComponents, roleAssignmentButton)
			obj.Roles[roleName]={
					assignButton = roleAssignmentButton,
					unitCountLabel = unitsCountLabel,
					roleIndex = roleInd,
					unitTypes = {}
				}
		end
	end
	return obj
end

-- Following three methods are shortcut for increasing and decreassing role counts.
function TreeHandle:DecreaseUnitCount(whichRole)
	roleData = self.Roles[whichRole]
	-- this is the current role and tree
	currentCount = tonumber(roleData.unitCountLabel.caption)
	currentCount = currentCount - 1
	-- test for <0 ?
	roleData.unitCountLabel:SetCaption(currentCount)
end
function TreeHandle:IncreaseUnitCount(whichRole)	
	roleData = self.Roles[whichRole]
	-- this is the current role and tree
	currentCount = tonumber(roleData.unitCountLabel.caption)
	currentCount = currentCount + 1
	-- test for <0 ?
	roleData.unitCountLabel:SetCaption(currentCount)
end
function TreeHandle:SetUnitCount(whichRole, number)
	roleData = self.Roles[whichRole]
	roleData.unitCountLabel:SetCaption(number)
end

function SendStringToBtEvaluator(message)
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), "BETS " .. message)
end


function removeTreeBtController(tabs,treeHandle)
	-- remove the bar item
	local tabBarChildIndex = 1
	-- get tabBar
	local tabBar = tabs.children[tabBarChildIndex]
	
	if treeHandle.Name == tabBar.selected_obj.caption then
		BtCreator.hide()
	end
	
	tabBar:Remove(treeHandle.Name)
	-- remove chili elements ?
	local deleteFrame = tabs.tabIndexMapping[treeHandle.Name]
	tabs.currentTab:RemoveChild(deleteFrame)
	-- remove from tabPanel name-frame map
	tabs.tabIndexMapping[treeHandle.Name] = nil
	-- make sure addtab is in right place
	moveToEndAddTab(tabs)
	
	-- remove records of unit assignment:
	removeUnitsFromTree(treeHandle.InstanceId)
	
	-- remove send message to BtEvaluator
	BtEvaluator.removeTree(treeHandle.InstanceId)
end


function showErrorWindow(errorDecription)
	errorLabel.caption = errorDecription
	errorWindow:Show()
end


function logUnitsToTreesMap(cathegory)
	Logger.log(cathegory, " ***** unitsToTreesMapLog: *****" )
	for unitId, unitData in pairs(unitsToTreesMap) do
		Logger.log(cathegory, "unitId ", unitId, " instId ", unitData.InstanceId, " label inst: ", unitData.TreeHandle.Roles[unitData.Role].unitCountLabel.instanceId, " treeHandleId: ", unitData.TreeHandle.InstanceId, " button insId: ", unitData.TreeHandle.Roles[unitData.Role].assignButton.instanceId, " treeHandleName ", unitData.TreeHandle.Name )
	end
	Logger.log(cathegory, "***** end *****" )
end

-- This will return name id of all units in given tree
function unitsInTree(instanceId)
	local unitsInThisTree = {}
	for unitId, unitEntry in pairs(unitsToTreesMap) do
		if(unitEntry.InstanceId == instanceId) then
			table.insert(unitsInThisTree, unitId)
		end
	end
	return unitsInThisTree
end

function unitsInTreeRole(instanceId,roleName)
	local unitsInThisTree = {}
	for unitId, unitEntry in pairs(unitsToTreesMap) do
		if( (unitEntry.InstanceId == instanceId) and (unitEntry.Role == roleName)) then
			table.insert(unitsInThisTree, unitId)
		end
	end
	return unitsInThisTree
end

-- this function assigns currently selected units to preset roles in newly created tree. 
function automaticRoleAssignment(treeHandle, selectedUnits)
	------------------------------------------
	if treeHandle.Roles == nil then 
		Logger.log("roles", "no roles data, no autoassignment.")
		return
	end
	------------------------------------------

	for i,unitId in pairs(selectedUnits) do
		-- put each unit to its role:
		local unitAssigned  = false
		local unitDefId = Spring.GetUnitDefID(unitId)
		if(UnitDefs[unitDefId] ~= nil)then  
			hn = UnitDefs[unitDefId].humanName
			for _,roleData in pairs(treeHandle.Roles) do
				if (roleData.unitTypes[hn] ~= nil) then
					--Logger.log("roles", "assigned")
					unitAssigned = true
					assignUnitToTree(unitId, treeHandle, roleData.roleAssignmentButton.caption)
				end
			end	
		else
			Logger.log("roles", "could not find UnitDefs entry for: ",  unitId )
		end
		if(unitAssigned == false) then
			assignUnitToTree(unitId, treeHandle, treeHandle.Tree.defaultRole)
		end
	end
	for name,roleData in pairs(treeHandle.Roles) do
	-- now I need to share information with the BtEvaluator
		local unitsInThisRole = unitsInTreeRole(treeHandle.InstanceId, name)
		Spring.SelectUnitArray(unitsInThisRole)
		BtEvaluator.assignUnits(nil, treeHandle.InstanceId,roleData.roleIndex)
	end
end

-- this will remove given unit from its current tree and adjust the gui componnets
function removeUnitFromCurrentTree(unitId)	
	if(unitsToTreesMap[unitId] == nil) then return end
	-- unit is assigned to some tree:
	-- decrease count of given tree:
	
	treeHandle = unitsToTreesMap[unitId].TreeHandle
	role = unitsToTreesMap[unitId].Role
	treeHandle:DecreaseUnitCount(role)
	unitsToTreesMap[unitId] = nil
end
-- this will remove all units from given tree and adjust gui componnets
function removeUnitsFromTree(instanceId)
	for unitId, unitData in pairs(unitsToTreesMap) do
		if(unitData.InstanceId == instanceId) then
			unitData.TreeHandle:DecreaseUnitCount(unitData.Role)
			unitsToTreesMap[unitId] = nil
		end
	end
end
-- this will take note of assignment of a unit to given tree and adjust gui componnets
function assignUnitToTree(unitId, treeHandle, roleName)
	if(unitsToTreesMap[unitId] ~= nill) then
		-- unit is currently assigned elsewhere, need to remove it first
		removeUnitFromCurrentTree(unitId)
	end
	unitsToTreesMap[unitId] = {
		InstanceId = treeHandle.InstanceId, 
		Role = roleName,
		TreeHandle = treeHandle
		}
	treeHandle:IncreaseUnitCount(roleName)
end

-- This is the method to create new tree instance, 
	--it will create the instance,
	--create new tree tab
	-- notify BtEvaluator
-- it return the new treeHandle
function instantiateTree(treeType, instanceName)
	--reloadTree(name)
	local newTreeHandle = TreeHandle:New{
		Name = instanceName,
		TreeType = treeType,
	}
	local selectedUnits = Spring.GetSelectedUnits()
			
	-- create tab
	addTreeToTreeTabPanel(newTreeHandle)
			
	-- create the tree immediately when the tab is created
	BtEvaluator.createTree(newTreeHandle.InstanceId, newTreeHandle.Tree)
			
	-- now, assign units to tree
	automaticRoleAssignment(newTreeHandle, selectedUnits)
	-- tree tab 
	--listenerBarItemClick({TreeHandle = newTreeHandle},0,0,1)
	return newTreeHandle
end

--//////////////////////////////////////////////////////////////////////////////
---------REWRITTEN CHILI FUNCTIONS:
function tabBarItemMouseDownBETS(self, ...)
  self.inherited.MouseDown(self, ...)
  return self
end 
--//////////////////////////////////////////////////////////////////////////////

---------------------------------------LISTENERS
-- This listener is called when AddTreeTab becomes active to update directory 
-- content and default instance name.
local function refreshTreeSelectionPanel(self)
	names = getNamesInDirectory(BehavioursDirectory, ".json")
	treeSelectionComboBox.items = names 
	treeSelectionComboBox:RequestUpdate()
	treeNameEditBox.text = "Instance"..instanceIdCount
end

-- This listener is called when user clicks on tabBar item in BtController. The 
-- original listener is replaced by this one.
function listenerBarItemClick(self, x, y, button, ...)
	if button == 1 then
		-- select assigned units, if any
		local unitsToSelect = unitsInTree(self.TreeHandle.InstanceId)
		Spring.SelectUnitArray(unitsToSelect)

		if(not BtCreator)then return end
	
		if(showTreeCheckbox.checked) then
			BtEvaluator.reportTree(self.TreeHandle.InstanceId)	
			BtCreator.show(self.TreeHandle.TreeType)
		end
		
		-- ORIGINAL LISTENER FORM BarItem:
		if not self.parent then return end
		self.parent:Select(self.caption)
		return self
		-- END OF ORIG. LISTENER
	end
	if button == 2 then
		--middle click
		removeTreeBtController(treeTabPanel, self.TreeHandle)
	end
end 

-- This is listener for AssignUnits buttons of given tree instance. 
-- The button should have TreeHandle and Role attached on it. 
function listenerAssignUnitsButton(self)
	-- self = button
	-- deselect units in current role
	for unitId,treeAndRole in pairs(unitsToTreesMap) do	
		if(treeAndRole.InstanceId == self.TreeHandle.InstanceId) and (treeAndRole.Role == self.Role) then
			removeUnitFromCurrentTree(unitId)
		end
	end --]]
	-- make note of assigment in our notebook (this should be possible moved somewhere else:)
	local selectedUnits = Spring.GetSelectedUnits()
	for _,Id in pairs(selectedUnits) do
		assignUnitToTree(Id, self.TreeHandle, self.Role)
	end
	
	BtEvaluator.assignUnits(nil, self.TreeHandle.InstanceId, self.roleIndex)
	--BtEvaluator.reportTree(self.TreeHandle.InstanceId)
end

-- Listener for closing error window.
function listenerErrorOk(self)
	errorWindow:Hide()
end




-- Listener for button in treeSelectionTab which creates new tree.
local function listenerClickOnSelectedTreeDoneButton(self, x, y, button)
	if button == 1 then
		-- we react only on leftclicks
		-- check if instance name is not being used:
		if(treeTabPanel.tabIndexMapping[treeNameEditBox.text] == nil ) then
			local selectedTreeType = treeSelectionComboBox.items[treeSelectionComboBox.selected]
			local instanceName = treeNameEditBox.text
			local newTreeHandle = instantiateTree(selectedTreeType, instanceName)
			--[[
			-- instance with such name is not used
			local selectedTreeType = treeSelectionComboBox.items[treeSelectionComboBox.selected]
			--should not be needed anymore: name = name:sub(1,name:len()-5)
				
			--reloadTree(name)
			local newTreeHandle = TreeHandle:New{
				Name = treeNameEditBox.text,
				TreeType = selectedTreeType,
			}
			local selectedUnits = Spring.GetSelectedUnits()
			
			-- create tab
			addTreeToTreeTabPanel(newTreeHandle)
			
			-- create the tree immediately when the tab is created
			BtEvaluator.createTree(newTreeHandle.InstanceId, newTreeHandle.Tree)
			
			-- now, assign units to tree
			automaticRoleAssignment(newTreeHandle, selectedUnits)
			
			
			--]]
			
			listenerBarItemClick({TreeHandle = newTreeHandle},x ,y ,button)	
		else
			-- if such instance name exits show error window
			showErrorWindow("Duplicate instance name.")
		end
	end
end

---------------------------------------LISTENERS END

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
	
	refreshTreeSelectionPanel()
	
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
	table.insert(listeners,refreshTreeSelectionPanel)
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
	showTreeCheckbox = Chili.Checkbox:New{
	parent = treeControlWindow,
	caption = "show tree",
	checked = false,
	x = '80%',
	y = 0,
	width = 80,
		skinName='DarkGlass'
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

function setUpErrorWindow()
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

local saveAllUnitDefs

function widget:Initialize()	
	-- Get ready to use Chili
	Chili = WG.ChiliClone
	Screen0 = Chili.Screen0	
  
	BtEvaluator = WG.BtEvaluator 
	-- extract BtCreator into a local variable once available
	Dependency.defer(function() BtCreator = WG.BtCreator end, Dependency.BtCreator)
  
	-- Create the window
	
	unitsToTreesMap = {}
   
	setUpTreeControlWindow()
  
	setUpErrorWindow()
	Spring.Echo("BtController reports for duty!")
	
	local configPath = LUAUI_DIRNAME .. "Config/btcontroller_config.lua"
	if(VFS.FileExists(configPath)) then
		local f = assert(VFS.LoadFile(configPath))
		local config = loadstring(f)()
		if(config.showTree == "true") then
			if(not showTreeCheckbox.checked) then
				showTreeCheckbox:Toggle()
			end
		end
		if(config.treeType) then
			for i=1,#treeSelectionComboBox.items do
				if(treeSelectionComboBox.items[i] == config.treeType) then
					treeSelectionComboBox:Select(i)
				end
			end
		end
		listenerClickOnSelectedTreeDoneButton(self, treeSelectionDoneButton.x, treeSelectionDoneButton.y, 1)
	end
	
	Dependency.fill(Dependency.BtController)
end

--//////////////////////////////////////////////////////////////////////////////
-- Callins

function widget:UnitDestroyed(unitId)
	if(unitsToTreesMap[unitId] ~= nil) then
		removeUnitFromCurrentTree(unitId)
	end
end

function widget.CommandNotify(self, cmdID, cmdParams, cmdOptions)
	if(cmdID == CMD_CONVOY) then
		local treeType = "mex-builders"
		local instanceName= "Instance"..instanceIdCount
		instantiateTree(treeType, instanceName)
	end
end 
  
-- this function saves UnitDefs tables into UnitDefs folder - to be able to see what can be used.
function saveAllUnitDefs()
	for id,unitDef in pairs(UnitDefs) do
		local t = {}
		for k,v in unitDef:pairs() do
			t[k] = v
		end
		table.save(t, "UnitDefs/"..unitDef.humanName .. ".txt", "-- generated by table.save")
	end
end

Dependency.deferWidget(widget, Dependency.BtEvaluator)