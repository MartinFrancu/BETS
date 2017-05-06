CONSTANTS = {
	rolesXOffset = 10,
	rolesYOffset = 60,
	buttonHeight = 22,
	singleButtonModifier = 10,
	labelToButtonYModifier = 5, -- chili feature/bug
	minRoleLabelWidth = 70,
	minRoleAssingWidth = 100,
	minUnitCountWidth = 50,
	inputGap = 30,
	roleGap = 20,
	SUCCESS_COLOR = {0.5,1,0.5,0.6},
	FAILURE_COLOR = {1,0.25,0.25,0.6},
	minInputButtonWidth = 150,
	lockedIconPath = PATH .. "locked32.png",
	unlockedIconPath = PATH .. "unlocked32.png",
	labelHeight = 30,
	windowFrameGap = 20,
}




local Chili, Screen0
local BtController = widget


local BtEvaluator, BtCreator

local JSON = Utils.JSON
local BehaviourTree = Utils.BehaviourTree
local Dependency = Utils.Dependency
local sanitizer = Utils.Sanitizer.forWidget(widget)
local Timer = Utils.Timer;

local Debug = Utils.Debug;
local Logger = Debug.Logger
local dump = Debug.dump

local TreeHandle = require("BtTreeHandle")


local treeControlWindow
local controllerLabel
local treeTabPanel
local showBtCreatorButton
local reloadAllButton
--------------------------------------------------------------------------------
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

-- If we are in state of expecting input we will make store this information here
local expectedInput 
--------------------------------------------------------------------------------
local spGetCmdDescIndex = Spring.GetCmdDescIndex
local spSetActiveCommand = Spring.SetActiveCommand
local spGetSelectedUnits = Spring.GetSelectedUnits
local spSelectUnits = Spring.SelectUnitArray

local inputCommandsTable = WG.InputCommands
local treeCommandsTable = WG.BtCommands

--------------------------------------------------------------------------------
--- Marker: Visualize units in trees:
-- get madatory module operators
VFS.Include("LuaRules/modules.lua") -- modules table
VFS.Include(modules.attach.data.path .. modules.attach.data.head) -- attach lib module

-- get other madatory dependencies
attach.Module(modules, "message") -- communication backend

local function sendMessageToMarker(msg)
	Logger.log("selection", "msg to marker: ", dump(msg,2) )
	message.SendUI(msg)
end

local function addMarks(units, locked)
	local newMsg = {
		subject = "AddUnitAIMarkers",
		units = units,
		locked = locked
	}
	sendMessageToMarker(newMsg)
end

local function removeMarks(units)
	local newMsg = {
		subject = "RemoveUnitAIMarkers",
		units = units,
	}
	sendMessageToMarker(newMsg)
end

local function removeAllMarks()
	local allUnits = {}
	for unitId, record in pairs(TreeHandle.unitsToTreesMap) do
		allUnits[#allUnits+1] = unitId
	end
	removeMarks(allUnits)
end

local function unmarkUnits(treeHandle,role)
	local units = TreeHandle.unitsInTreeRole(treeHandle.InstanceId, role)
	removeMarks(units)	
end

local function markUnits(treeHandle, role)
	local locked = treeHandle.unitsLocked
	local units = TreeHandle.unitsInTreeRole(treeHandle.InstanceId, role)
	addMarks(units, locked)
end

local function markAllUnitsInTree(treeHandle)
	for _,roleSpec in pairs(treeHandle.Tree.roles) do
		markUnits(treeHandle, roleSpec.name)
	end
end

local function unmarkAllUnitsInTree(treeHandle)
	for _,roleSpec in pairs(treeHandle.Tree.roles) do
		unmarkUnits(treeHandle, roleSpec.name)
	end
end
--------------------------------------------------------------------------------



-- //////////////////////////////////////////////////////////////////////////////////////////////////////
-- Id Generation
local alphanum = {
	"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
	"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
	"0","1","2","3","4","5","6","7","8","9"
	}

local usedIDs = {}
local instanceIdCount = 0

function generateID()
	local length = 32
	local str = ""
	for i = 1, length do
		str = str..alphanum[math.random(#alphanum)]
	end
	if(usedIDs[str] ~= nil) then
		return generateID()
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
	-- collect all chili components corresponding to this tree
	local chiliComponents = {}
	for _,component in pairs (treeHandle.ChiliComponentsGeneral) do
		table.insert(chiliComponents,component)
	end
	for _,component in pairs (treeHandle.ChiliComponentsRoles) do
		table.insert(chiliComponents,component)
	end
	for _,component in pairs (treeHandle.ChiliComponentsInputs) do
		table.insert(chiliComponents,component)
	end

	
	local newTab =  {name = treeHandle.Name, children = chiliComponents}
	treeTabPanel:AddTab(newTab)
	highlightTab(newTab.name)
	
	-- add all required properties:	
	addFieldToBarItem(treeTabPanel, newTab.name, "MouseDown", sanitizer:AsHandler(tabBarItemMouseDownBETS) )
	addFieldToBarItemList(treeTabPanel, newTab.name, "OnClick", sanitizer:AsHandler(listenerBarItemClick) )
	addFieldToBarItem(treeTabPanel, newTab.name, "TreeHandle", treeHandle)
	addFieldToBarItem(treeTabPanel, newTab.name, "tooltip", treeHandle.Name .. " is an instance of the behaviour tree ".. treeHandle.TreeType .. ". Can be closed on middle mouse button click. ")
	
	moveToEndAddTab(treeTabPanel)
end

function sendStringToBtEvaluator(message)
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), "BETS " .. message)
end

function removeTreeBtController(tabs,treeHandle)
	-- remove the bar item
	local tabBarChildIndex = 1
	-- get tabBar
	local tabBar = tabs.children[tabBarChildIndex]
	
	-- is it currently shown?
	if treeHandle.Name == tabBar.selected_obj.caption and BtCreator then
		-- hiding disabled as the tabs are no longer linked to each other
		--BtCreator.hide()
	end
	
	tabBar:Remove(treeHandle.Name)
	-- remove chili elements ?
	local deleteFrame = tabs.tabIndexMapping[treeHandle.Name]
	tabs.currentTab:RemoveChild(deleteFrame)
	-- remove from tabPanel name-frame map
	tabs.tabIndexMapping[treeHandle.Name] = nil
	-- make sure addtab is in right place
	moveToEndAddTab(tabs)
	
	-- remove markes above units
	unmarkAllUnitsInTree(treeHandle)
	-- remove records of unit assignment:
	TreeHandle.removeUnitsFromTree(treeHandle.InstanceId)
	
	if(treeHandle.Created) then
		-- remove send message to BtEvaluator
		BtEvaluator.removeTree(treeHandle.InstanceId)
	end
end


local instantiateTree
-- reloads given treehandle from given tabs
function reloadTree(tabs, treeHandle)
	-- remove tree instance in BtEvaluator if it is created:
	if(treeHandle.Created) then
		-- remove send message to BtEvaluator
		BtEvaluator.removeTree(treeHandle.InstanceId)
	end
	-- get the new tree specification and GUI components:
	treeHandle:ReloadTree()
	-- GUI components:
	local tabFrame = tabs.tabIndexMapping[treeHandle.Name]
	-- remove old GUI components:
	tabFrame:ClearChildren()
	tabFrame:RequestUpdate()
	-- now attach new ones:
	----[[
	
	for _,component in pairs(treeHandle.ChiliComponentsGeneral)do
		tabFrame:AddChild(component)
	end
	for _,component in pairs(treeHandle.ChiliComponentsRoles)do
		tabFrame:AddChild(component)
	end
	for _,component in pairs(treeHandle.ChiliComponentsInputs)do
		tabFrame:AddChild(component)
	end
	--]]
	-- if tree is ready, initialize it in BtEvaluator
	if(treeHandle:CheckReady()) then
		createTreeInBtEvaluator(treeHandle)
		treeHandle.Created = true
		reportAssignedUnits(treeHandle)
	end
	
	treeHandle:UpdateTreeStatus()
end


-- reloads all instances of give tree type in given tabs
function BtController.reloadTreeType(treeTypeName)
	-- refresh tree selection:
	refreshTreeSelectionPanel()
	-- I should iterate over all tab bar items:
	local tabBarChildIndex = 1
	-- get tabBar
	local tabBar = treeTabPanel.children[tabBarChildIndex]
	-- find corresponding tabBarItems: 
	local barItems = tabBar.children
	for index,item in ipairs(barItems) do
		-- if there is TreeHandle in this item and the tree type is right one:
		if( (item.TreeHandle ~= nil) 
			and (item.TreeHandle.TreeType == treeTypeName) )
		then
			--table.insert(toReload, item.TreeHandle)
			reloadTree(treeTabPanel, item.TreeHandle)
		end
	end
end

-- This method will reload all tree instances currently present in BtController.
-- Later should be added reload of sensorst etc..
function reloadAll()
	-- reload cache in BtEvaluator:
	BtUtils.ProjectManager.reload()
	BtEvaluator.reloadCaches()
	-- I should iterate over all tab bar items:
	local tabBarChildIndex = 1
	-- get tabBar
	local tabBar = treeTabPanel.children[tabBarChildIndex]
	-- find corresponding tabBarItems: 
	local barItems = tabBar.children
	for index,item in ipairs(barItems) do
		if(item.caption ~= "+")then -- exclude addtab item from reloading...
			reloadTree(treeTabPanel, item.TreeHandle)
		end
	end
	
	resetMarkers()
end
--[[ This method pop up simple error window. Currently used if user tries 
to create tree with already used name.
]]
function showErrorWindow(errorDecription)
	errorLabel.caption = errorDecription
	errorWindow:Show()
end

--[[ Loggs assignment of units, for Debugging.
 Probably should be moved to TreeHandle. 
]]
function logUnitsToTreesMap(category)
	Logger.log(category, " ***** unitsToTreesMapLog: *****" )
	for unitId, unitData in pairs(TreeHandle.unitsToTreesMap) do
		Logger.log(category, "unitId ", unitId, " instId ", unitData.InstanceId, " label inst: ", unitData.TreeHandle.Roles[unitData.Role].unitCountButton.instanceId, " treeHandleId: ", unitData.TreeHandle.InstanceId, " button insId: ", unitData.TreeHandle.Roles[unitData.Role].assignButton.instanceId, " treeHandleName ", unitData.TreeHandle.Name )
	end
	Logger.log(category, "***** end *****" )
end



-- this function assigns currently selected units to preset roles in newly created tree. 
function automaticRoleAssignment(treeHandle, selectedUnits)
	------------------------------------------
	if treeHandle.Roles == nil then 
		Logger.log("roles", "no roles data, no autoassignment.")
		return
	end
	------------------------------------------
	
	local unitIdRoleTable = {}
	local defaultRoles
	
	for _,roleData in pairs(treeHandle.Roles) do
		if(not next(roleData.unitTypes))then -- if there are no units, it is the default role
			if(defaultRoles == nil)then
				defaultRoles = {currentIndex = 1, roles = {}}
			end
			table.insert(defaultRoles.roles, roleData)
		else
			for name,record in pairs(roleData.unitTypes) do
				if(unitIdRoleTable[name] == nil) then
					unitIdRoleTable[name] = {currentIndex = 1, roles = {}}
				end
				table.insert(unitIdRoleTable[name].roles, roleData)
			end
		end
	end	
	
	local treeHandlesWithRemovedUnits = {}
	
	local assignedUnitCount = 0
	for i,unitId in pairs(selectedUnits) do
		local unitDefId = Spring.GetUnitDefID(unitId)
		local thWithRemovedUnit = TreeHandle.removeUnitFromCurrentTree(unitId)
		if thWithRemovedUnit then
			treeHandlesWithRemovedUnits[thWithRemovedUnit.InstanceId] = thWithRemovedUnit
		end
		if(UnitDefs[unitDefId] ~= nil)then  
			local name = UnitDefs[unitDefId].name
			local unitRoles = unitIdRoleTable[name] or defaultRoles
			if(unitRoles) then
				assignedUnitCount = assignedUnitCount + 1
				local currentRoleData = unitRoles.roles[unitRoles.currentIndex]
				TreeHandle.assignUnitToTree(unitId, treeHandle,
					currentRoleData.assignButton.Role)
				-- now, I should shift the index:
				unitRoles.currentIndex = unitRoles.currentIndex + 1 
				if(unitRoles.currentIndex > table.getn(unitRoles.roles) ) then
					unitRoles.currentIndex = 1 -- reset the current index
				end
			else
				-- ignore the unit
			end
		else
			Logger.log("roles", "could not find UnitDefs entry for: ",  unitId )
		end
	end
	if(assignedUnitCount == 0)then
		for i,unitId in pairs(selectedUnits) do
			TreeHandle.assignUnitToTree(unitId, treeHandle, select(2, next(treeHandle.Roles)).assignButton.Role)
		end
	end
	
	-- notify BtEvaluator about removed units
	for _,handle in pairs(treeHandlesWithRemovedUnits) do
		reportAssignedUnits(handle)
	end
	removeTreesWithoutUnitsRequiringUnits()
end


-- Calls required functions to create tree in BtEvaluator
function createTreeInBtEvaluator(treeHandle)
	BtEvaluator.dereferenceTree(treeHandle.Tree)
	BtEvaluator.createTree(treeHandle.InstanceId, treeHandle.Tree, treeHandle.Inputs)
end

-- Reports units assigned to all roles to BtEvaluator
function reportAssignedUnits(treeHandle)
	if(treeHandle.Created == false) then 
		-- nothign to report
		return
	end
	local originallySelectedUnits = spGetSelectedUnits()
	for name,roleData in pairs(treeHandle.Roles) do
		-- now I need to share information with the BtEvaluator
		local unitsInThisRole = TreeHandle.unitsInTreeRole(treeHandle.InstanceId, name)
		spSelectUnits(unitsInThisRole)
		BtEvaluator.assignUnits(unitsInThisRole, treeHandle.InstanceId, roleData.roleIndex)
	end
	spSelectUnits(originallySelectedUnits)
end

-- Reports users input for given input slot to BtEvaluator.
function reportInputToBtEval(treeHandle, inputName)
	BtEvaluator.setInput(treeHandle.InstanceId , inputName, treeHandle.Inputs[inputName]) 
end 

-- Remove trees without units which require units.
function removeTreesWithoutUnitsRequiringUnits()
	local tabBarChildIndex = 1
	local tabBar = treeTabPanel.children[tabBarChildIndex]
	local barItems = tabBar.children
	-- get trees to remove
	local treesToRemove = {}
	for index,item in ipairs(barItems) do
		if  (item.caption ~= "+") then-- exclude add tree tab
			
			if (item.TreeHandle.RequireUnits) and  (item.TreeHandle.AssignedUnitsCount < 1) then
				-- if there are no units, remove this tree:
				table.insert(treesToRemove,  item.TreeHandle)
			end
		end
	end
	
	-- remove all trees without units which require units
	for _,treeHandle in ipairs(treesToRemove) do 
		removeTreeBtController(treeTabPanel, treeHandle)
	end
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
function refreshTreeSelectionPanel()
	names = BehaviourTree.list()
	treeSelectionComboBox.items = names 
	treeSelectionComboBox:RequestUpdate()
	treeNameEditBox.text = "Instance"..instanceIdCount
end

local function listenerLockImage(self)
	local tH = self.TreeHandle
	tH.unitsLocked = not tH.unitsLocked
	if(tH.unitsLocked) then
		self.file = CONSTANTS.lockedIconPath
	else
		self.file = CONSTANTS.unlockedIconPath
	end
	self:Invalidate()
	self:RequestUpdate()
	markAllUnitsInTree(tH)
end

-- This listener is called when user clicks on tabBar item in BtController. The 
-- original listener is replaced by this one.
function listenerBarItemClick(self, x, y, button, ...)
	if button == 1 then
		-- select assigned units, if any
		local unitsToSelect = TreeHandle.unitsInTree(self.TreeHandle.InstanceId)
		spSelectUnits(unitsToSelect)

		self.TreeHandle:UpdateTreeStatus()
		
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
function listenerAssignUnitsButton(self,x,y, ...)
	-- self = chili:button
	-- deselect units in current role
	-- Here I am deassigning all units, that might destroy some tree:
	
	local treeHandlesWithRemovedUnits = {}
	local removedUnits = {}
	for unitId,treeAndRole in pairs(TreeHandle.unitsToTreesMap) do	
		if(treeAndRole.InstanceId == self.TreeHandle.InstanceId) and (treeAndRole.Role == self.Role) then
			removedUnits[#removedUnits +1] = unitId
			local thWithRemovedUnit = TreeHandle.removeUnitFromCurrentTree(unitId)
			if thWithRemovedUnit then
				treeHandlesWithRemovedUnits[thWithRemovedUnit.InstanceId] = thWithRemovedUnit
			end
		end
	end
	-- remove markers:
	removeMarks(removedUnits)
	
	-- notify BtEvaluator about removed units
	for _,handle in pairs(treeHandlesWithRemovedUnits) do
		reportAssignedUnits(handle)
	end
	
	local selectedUnits = spGetSelectedUnits()
	for _,Id in pairs(selectedUnits) do	
		TreeHandle.assignUnitToTree(Id, self.TreeHandle, self.Role)
	end
	-- check if tree is empty and if it require units
	if(self.TreeHandle:CheckReady() ) then
		if(self.TreeHandle.Created == false) then
			createTreeInBtEvaluator(self.TreeHandle)
			self.TreeHandle.Created = true
			reportAssignedUnits(self.TreeHandle)
		end
		BtEvaluator.assignUnits(selectedUnits, self.TreeHandle.InstanceId, self.roleIndex)
	end
	-- put markers over units in selection:
	markUnits(self.TreeHandle,  self.Role)
	
	-- now I should check if there are units in this tree
	-- if the tree has no more units:
	removeTreesWithoutUnitsRequiringUnits()
end

-- this returns one ally unit. 
local function getDummyAllyUnit()
	local allUnits = Spring.GetTeamUnits(Spring.GetMyTeamID())
	return allUnits[1]
end


function listenerInputButton(self,x,y,button, ...)
	if(not inputCommandsTable or not treeCommandsTable) then		
		--WG.fillCustomCommandIDs()
		inputCommandsTable = WG.InputCommands
		treeCommandsTable = WG.BtCommands
	end
	-- should I do something more when reseting the input que?
	-- I need to store record what we are expecting
	expectedInput = {
		TreeHandle = self.TreeHandle,
		InputName = self.InputName,
		CommandName = self.CommandName,
		InstanceId = self.InstanceId,
	}
	
	local f = function()
		local ret = spSetActiveCommand(  spGetCmdDescIndex(inputCommandsTable[ expectedInput.CommandName ]) ) 
		if(ret == false ) then 
			Logger.log("commands", "Unable to set command active: " , expectedInput.CommandName) 
		end
	end
	
	-- if there are no units selected, ...
	if(not spGetSelectedUnits()[1])then
		-- select one
		spSelectUnits({ getDummyAllyUnit() })
		-- wait until return to Spring to execute f
		Timer.delay(f)
	else
		f() -- execute synchronously
	end
	
end

-- Listener for reload all button 
function listenerReloadAll(self, x, y, ...)
	refreshTreeSelectionPanel()
	reloadAll()
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
			local newTreeHandle = instantiateTree(selectedTreeType, instanceName, false)
			listenerBarItemClick({TreeHandle = newTreeHandle},x ,y ,button)	
		else
			-- if such instance name exits show error window
			showErrorWindow("Duplicate instance name.")
		end
	end
end



-- This function show currently selected tree in BtCreator. If add tree tab is selected
local function listenerClickBtCreator(self, x, y, button)
	-- get the selected tab from tabs:	
	local tabBarChildIndex = 1
	tabBar = treeTabPanel.children[tabBarChildIndex]
	local barItem = tabBar.selected_obj
	-- if it is not + then show BtCreator (send him message)
	if(barItem.caption ~= "+") then
		-- tree tab is selected (not add tree tab)
		if(barItem.TreeHandle.Created) then 
			BtEvaluator.reportTree(barItem.TreeHandle.InstanceId)
		end
		BtCreator.showTree(barItem.TreeHandle.TreeType, barItem.TreeHandle.InstanceId)
	else
		-- add tree tab is selected
		BtCreator.show()
	end
end

---------------------------------------LISTENERS END

-- This is the method to create new tree instance, 
	-- it will create the instance,
	-- create new tree tab
	-- (removed) notify BtEvaluator
-- it return the new treeHandle
function instantiateTree(treeType, instanceName, requireUnits)
	
	
	local newTreeHandle = TreeHandle:New{
		Name = instanceName,
		TreeType = treeType,
		AssignUnitListener = sanitizer:AsHandler(listenerAssignUnitsButton),
		InputButtonListener = sanitizer:AsHandler(listenerInputButton),
		lockImageListener = sanitizer:AsHandler(listenerLockImage),
		RequireUnits = requireUnits,
	}
	
	local selectedUnits = spGetSelectedUnits()
	if ((table.getn(selectedUnits) < 1 ) and newTreeHandle.RequireUnits) then
		Logger.log("Errors", "BtController: instantiateTree: tree is requiring units and no unit is selected.")
		return newTreeHandle
	end
	
	
	-- create tab
	addTreeToTreeTabPanel(newTreeHandle)
		
	-- now, auto assign units to tree
	automaticRoleAssignment(newTreeHandle, selectedUnits)
	
	-- mark units in tree:
	markAllUnitsInTree(newTreeHandle)
	
	
	if(newTreeHandle:CheckReady()) then
		createTreeInBtEvaluator(newTreeHandle)
		newTreeHandle.Created = true
		reportAssignedUnits(newTreeHandle)
	end
	return newTreeHandle
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
			defaultHeight = tabBar.minItemHeight,
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
	item.tooltip = "Add a new instance of the behaviour tree. "
	local listeners = item.OnMouseDown
	table.insert(listeners,refreshTreeSelectionPanel)
end

function setUpTreeSelectionTab()
	treeSelectionLabel = Chili.Label:New{
		x = 5,
		y = 5,
		width  = 70,
		height = 20,
		caption = "Select tree type:",
		skinName='DarkGlass',
	}
	
	local availableTreeTypes = BehaviourTree.list()
	
	treeSelectionComboBox = Chili.ComboBox:New{
		items = availableTreeTypes,
		width = '60%',
		x = 110,
		y = 4,
		align = 'left',
		skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0.3,0.3,0.3,0.3},
		focusColor = {1.0,0.5,0.0,0.5},
		tooltip = "Choose a tree type from available behaviour trees. ",
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
		tooltip = "Tree instance name, which will be visible on its instance tab. ",
	}

   	treeSelectionDoneButton = Chili.Button:New{
		x = 50,
		y = 60,
		width  = 60,
		height = 30,
		caption = "Done",
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		OnClick = {sanitizer:AsHandler(listenerClickOnSelectedTreeDoneButton)},
		tooltip = "Creates a new instance of selected behaviour tree with given name. ",
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
		name = "BtControllerTreeControlWindow",
    width  = 500 ,
    height = 200,--'10%',	
		padding = {10,10,10,10},
		draggable=true,
		resizable=true,
		skinName='DarkGlass',
		OnResize = { sanitizer:AsHandler(
			function(self)
				local btos = Screen0:GetChildByName("BtOS")
				if(btos) then
					btos:SetPos(self.x+self.width,self.y)
				end
			end
		)},
	}
  
	controllerLabel = Chili.Label:New{
    parent = treeControlWindow,
	x = CONSTANTS.windowFrameGap ,
	y = 0 ,
    width  = 50,
    height = CONSTANTS.labelHeight,
    caption = "BtController",
		skinName='DarkGlass',
	}
	showBtCreatorButton = Chili.Button:New{
		parent = treeControlWindow,
		caption = "BtCreator",
		checked = false,
		visible = false,
		x = treeControlWindow.width - 80 - CONSTANTS.windowFrameGap ,
		y = 0,
		width = 80,
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		tooltip = "Show currently selected tree in BtCreator. If there is no instance available, the new tree behaviour tree is shown. ",
		OnClick = {sanitizer:AsHandler(listenerClickBtCreator)}
	}
	if(not BtCreator)then
		showBtCreatorButton:Hide()
	end
	
	showBtCreatorButton.tabs = treeTabPanel
	
	reloadAllButton = Chili.Button:New{
		parent = treeControlWindow,
		caption = "Reload All",
		x =  treeControlWindow.width - 160 - CONSTANTS.windowFrameGap ,
		y = windowFrameGap ,
		width = 80,
		skinName='DarkGlass',
		tooltip = "Reloads all behavour trees from the disk. Also reloads available lua scripts nodes and sensors. ",
		focusColor = {1.0,0.5,0.0,0.5},
		OnClick = {sanitizer:AsHandler(listenerReloadAll)}
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
		OnClick = {sanitizer:AsHandler(listenerErrorOk)},
    }	
	errorWindow:Hide()
end

local saveAllUnitDefs

-- call durin initalize and reload trees
function resetMarkers()
	-- get players units
	local teamId = Spring.GetMyTeamID()
	local allUnits = Spring.GetTeamUnits(teamId)
	-- unmarks all units in this team
	removeMarks(allUnits)
	-- mark all units in our trees
	local unitsLocked = {}
	local unitsUnlocked = {}
	for id,data in pairs(TreeHandle.unitsToTreesMap) do
		if (data.TreeHandle.unitsLocked) then
			unitsLocked[#unitsLocked +1 ] = id
		else
			unitsUnlocked[#unitsUnlocked +1 ] = id
		end
	end
	addMarks(unitsLocked, true)
	addMarks(unitsUnlocked, false)
end
function widget:Initialize()	
	-- Get ready to use Chili
	Chili = WG.ChiliClone
	Screen0 = Chili.Screen0	
	
	BtEvaluator = sanitizer:Import(WG.BtEvaluator)
	-- extract BtCreator into a local variable once available
	Dependency.defer(
		function()
			BtCreator = sanitizer:Import(WG.BtCreator)
			if(showBtCreatorButton)then
				showBtCreatorButton:SetParent(treeControlWindow) -- workaround for a bug, showBtCreatorButton seems lose its parent somehow
				showBtCreatorButton:Show()
			end
		end,
		function()
			BtCreator = nil
			if(showBtCreatorButton)then
				showBtCreatorButton:SetParent(treeControlWindow) -- workaround for a bug, showBtCreatorButton seems lose its parent somehow
				showBtCreatorButton:Hide()
			end
		end,
		Dependency.BtCreator
	)
	
	WG.BtControllerReloadTreeType = BtController.reloadTreeType
	-- Create the window
   
	setUpTreeControlWindow()
  
	setUpErrorWindow()
	Spring.Echo("BtController reports for duty!")
	
	local configPath = LUAUI_DIRNAME .. "Config/btcontroller_config.lua"
	if(VFS.FileExists(configPath)) then
		local f = assert(VFS.LoadFile(configPath))
		local config = loadstring(f)()

		if(config.treeType) then
			for i=1,#treeSelectionComboBox.items do
				if(treeSelectionComboBox.items[i] == config.treeType) then
					treeSelectionComboBox:Select(i)
				end
			end
		end
	end
	resetMarkers()
	
	Dependency.fill(Dependency.BtController)
end
function widget:Shutdown()
	removeAllMarks()
	Dependency.clear(Dependency.BtController)
end

--//////////////////////////////////////////////////////////////////////////////
-- Callins


function widget:IsAbove(x,y)
	y = Screen0.height - y
	if (x > treeControlWindow.x and x < treeControlWindow.x + treeControlWindow.width and 
			y > treeControlWindow.y and y < treeControlWindow.y + treeControlWindow.height) then
			return true
	end
	return false
end

function widget:GetTooltip(x, y)
	local component = Screen0:HitTest(x, Screen0.height - y)
	if (component) then
		return component.tooltip
	end
end

function widget:UnitDestroyed(unitId)
	if(TreeHandle.unitsToTreesMap[unitId] ~= nil) then
		local treeHandle =  TreeHandle.unitsToTreesMap[unitId].TreeHandle
		TreeHandle.removeUnitFromCurrentTree(unitId)
		removeMarks({unitId})
		-- if the tree has no more units:
		removeTreesWithoutUnitsRequiringUnits()
	end
end

function widget:Update() 
	local selectedUnits = spGetSelectedUnits()
	local assignedUnitsMap = TreeHandle.unitsToTreesMap
	local okUnits = {}
	local okUnitsCounter = 0
	local allUnitsOK = true
	for i=1, #selectedUnits do -- !! TIME CRITICAL
		local thisUnitID = selectedUnits[i]
		local thisUnitOK = true
		if (assignedUnitsMap[thisUnitID] ~= nil) then
			if (assignedUnitsMap[thisUnitID].TreeHandle.unitsLocked) then
				allUnitsOk = false
				thisUnitOk = false
			end
		end
		
		if (thisUnitOK) then
			okUnitsCounter = okUnitsCounter + 1
			okUnits[okUnitsCounter] = thisUnitID
		end
	end
	
	if (not allUnitsOK) then -- ! only if necessary do re-selection
		spSelectUnits(okUnits)
	end
end

function widget.CommandNotify(self, cmdID, cmdParams, cmdOptions)
	-- Check for custom commands, first input commands
	if(not inputCommandsTable or not treeCommandsTable) then
		inputCommandsTable = WG.InputCommands
		treeCommandsTable = WG.BtCommands
		if(not inputCommandsTable)then
			return false -- if the problem persists, end
		end
	end
	Logger.log("commands", "cmd name: ", inputCommandsTable[cmdID])
	if(inputCommandsTable[cmdID] and (inputCommandsTable[cmdID] ~= "BETS_CHEAT_POSITION")) then
		if(expectedInput ~= nil) then
			-- I should insert given input to tree:
			local tH = expectedInput.TreeHandle 
			local inpName = expectedInput.InputName
			local commandType = expectedInput.CommandName
			-- I should check if the the command type is same, with expected?
			if(inputCommandsTable[cmdID] ~= commandType)then
				Logger.log("Error", "BtController.CommandNotify : Unexpected input command type.", 
							" Expected: ", commandType, 
							", got: ",inputCommandsTable[cmdID] )
				return false
			end
			
			local transformedData = Logger.loggedCall("Error", "BtController", 
					"fill in input value, tranforming data",
					WG.BtCommandsTransformData, 
					cmdParams,
					commandType)
			
			tH:FillInInput(inpName, transformedData)
			expectedInput = nil
			-- if tree is ready we should report it to BtEvaluator
			if(tH:CheckReady()) then 
				if(tH.Created == false) then
					tH.Created = true
					createTreeInBtEvaluator(tH)
					reportAssignedUnits(tH)
					BtEvaluator.reportTree(tH.InstanceId)
					tH:UpdateTreeStatus()
				else
					-- tree is ready, we can report just input
					reportInputToBtEval(tH, inpName)
				end	
			end
		else
			Logger.log("commands", "BtController: Received input command while not expecting one!!!")
		end
		return true -- true is for deleting command and not sending it further according to documentation		
	end
	-- check for custom commands - Bt behaviour assignments
	if(treeCommandsTable[cmdID]) then
		-- setting up a behaviour tree :
		local treeHandle = instantiateTree(treeCommandsTable[cmdID].treeName, "Instance"..instanceIdCount , true)
		
		listenerBarItemClick({TreeHandle = treeHandle}, x, y, 1)
		
		-- click on first input:
		if(table.getn(treeHandle.InputButtons) >= 1) then -- there are inputs
			listenerInputButton(treeHandle.InputButtons[1])
		end
		return true
	end
	Logger.log("commands", "received unknown command (probably normal case): " , cmdID)
	return false
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

Timer.injectWidget(widget)
Dependency.deferWidget(widget, Dependency.BtEvaluator, Dependency.BtCommands)