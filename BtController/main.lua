--- BtController is widget allowing user to control BETS behaviours. 
-- It main graphical component is BtController window. It is tightly connected 
-- to TreeHandle class which is used to keep track of instance related data, 
-- together with updating corresponind Chili components. The line is drawn at 
-- communication with other components. TreeHandle also keeps track of units 
-- assigned to unit instances. BtController is then communicating with other 
-- entities and player. 


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
	betsCheatCommandName = "BETS_CHEAT_POSITION",
	addTreeTabName = "+",
	tabBarChildIndex = 1,
}


local Chili, Screen0
local BtController = widget


--local BtEvaluator, BtCreator

local JSON = Utils.JSON
local BehaviourTree = Utils.BehaviourTree
local Dependency = Utils.Dependency
local sanitizer = Utils.Sanitizer.forWidget(widget)
local Timer = Utils.Timer;
local Dialog = Utils.Dialog

local Debug = Utils.Debug;
local Logger = Debug.Logger
local dump = Debug.dump

--local BtCommands
--local inputCommandsTable -- = WG.BtCommands.inputCommands
--local treeCommandsTable --= WG.BtCommands.behavour


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


--------------------------------------------------------------------------------
--- Marker: Visualize units in trees:
-- get madatory module operators
VFS.Include("LuaRules/modules.lua") -- modules table
VFS.Include(modules.attach.data.path .. modules.attach.data.head) -- attach lib module

-- get other madatory dependencies
attach.Module(modules, "message") -- communication backend

--- Sends given message to Marker module
-- @param msg Message to be send (table). 
local function sendMessageToMarker(msg)
	Logger.log("selection", "msg to marker: ", dump(msg,2) )
	message.SendUI(msg)
end

--- This function send propriate message to Marker module based on input.
-- @param units Array of unit IDs to be shown with locked/unlocked icon.
local function addMarks(units, locked)
	local newMsg = {
		subject = "AddUnitAIMarkers",
		units = units,
		locked = locked
	}
	sendMessageToMarker(newMsg)
end

--- This function removes (sends corresponding message) all icons markes for given units.
-- @param units Array of unit IDs.
local function removeMarks(units)
	local newMsg = {
		subject = "RemoveUnitAIMarkers",
		units = units,
	}
	sendMessageToMarker(newMsg)
end

--- Removes (sends corresponding message) all marks from all units which are under
-- control of any tree instance in @{TreeHandle} table.
local function removeAllMarks()
	local allUnits = {}
	for unitId, record in pairs(TreeHandle.unitsToTreesMap) do
		allUnits[#allUnits+1] = unitId
	end
	removeMarks(allUnits)
end

--- Unmarks units assigned in given role in given tree instance.
-- @tparam TreeHandle treeHandle Tree handle which units should be unmarked.
-- @tparam String role Role name. 
local function unmarkUnits(treeHandle,role)
	local units = TreeHandle.unitsInTreeRole(treeHandle.instanceId, role)
	removeMarks(units)	
end

--- Marks units assigned in given role in given tree instance according to tree state.
-- @tparam TreeHandle treeHandle Tree handle which units should be marked.
-- @tparam String role Role name.
local function markUnits(treeHandle, role)
	local locked = treeHandle.unitsLocked
	local units = TreeHandle.unitsInTreeRole(treeHandle.instanceId, role)
	addMarks(units, locked)
end

--- Marks units assigned under control of given tree instance according to tree state.
-- @tparam TreeHandle treeHandle Tree handle which units should be marked.
local function markAllUnitsInTree(treeHandle)
	for _,roleSpec in pairs(treeHandle.Tree.roles) do
		markUnits(treeHandle, roleSpec.name)
	end
end
--- Unmarks units assigned under control of given tree instance.
-- @tparam TreeHandle treeHandle Tree handle which units should be unmarked.
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

--- Generates random string.Used for instance ID generation.
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

--- Highlights tab of given name in @{BtController} tab panel.
-- @tparam String tabName Name of tab to be selected.
function highlightTab(tabName)
	-- first child should be the TabBar:
	treeTabPanel:ChangeTab(tabName)
	treeTabPanel.children[CONSTANTS.tabBarChildIndex]:Select(tabName)
end

--- Returns tabBarItem in given tabs with with given name. 
--TabBarItem is a bookmark for tab. See @{Chili.TabBarItem} in chili.
-- @tparam Chili.TabPanel tabs Tab panel.
-- @tparam String tabName Name of tab whose TabBarItem is required.
-- @return Desired TabBarItem.
function getBarItemByName(tabs, tabName)
	-- get tabBar
	local tabBar = tabs.children[CONSTANTS.tabBarChildIndex]
	-- find corresponding tabBarItem: 
	local barItems = tabBar.children
	for index,item in ipairs(barItems) do
		if(item.caption == tabName) then
			return item
		end
	end
end


--- The following function will find tabBarItem with given name 
-- and add to it atributs with given name containing given data.
-- @tparam Chili.TabPanel tabs Tab panel.
-- @tparam String tabName Name of required TabBarItem.
-- @tparam String atributName Name of assigned atribut. 
-- @param atribut Data to be added.
function addFieldToBarItem(tabs, tabName, atributName, atribut)
	item = getBarItemByName(tabs,tabName)
	item[atributName] = atribut
end

--- The following function will find tabBarItem witch 
-- such name and add to atributs under this name given data. 
-- It expects a list of entries. If specified atribut is not empty, provided entries
-- will be added to preexisting list.  
-- @tparam Chili.TabPanel tabs Tab panel.
-- @tparam String tabName Name of required TabBarItem.
-- @tparam String atributName Name of assigned atribut. 
-- @param atribut List of entries to be added.
function addFieldToBarItemList(tabs, tabName, atributName, atribut)
	item = getBarItemByName(tabs,tabName)
	if item[atributName] == nil then
		item[atributName] = {atribut}
	else
		local currentAtt = item[atributName]
		table.insert(currentAtt, atribut)
	end
end

--- Add new tab representing given TreeHandle into BtController's tab panel.
-- @tparam TreeHandle treeHandle Tree handle to have representation.

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

	
	local newTab =  {name = treeHandle.name, children = chiliComponents}
	treeTabPanel:AddTab(newTab)
	highlightTab(newTab.name)
	
	-- add all required properties:	
	addFieldToBarItem(treeTabPanel, newTab.name, "MouseDown", sanitizer:AsHandler(tabBarItemMouseDownBETS) )
	addFieldToBarItemList(treeTabPanel, newTab.name, "OnClick", sanitizer:AsHandler(listenerBarItemClick) )
	addFieldToBarItem(treeTabPanel, newTab.name, "TreeHandle", treeHandle)
	addFieldToBarItem(treeTabPanel, newTab.name, "tooltip", treeHandle.name .. " is an instance of the behaviour tree ".. treeHandle.treeType .. ". Can be closed on middle mouse button click. ")
	treeHandle.OnDeleteClick = function() listenerBarItemClick({ TreeHandle = treeHandle }, 0, 0, 2) end
	
	moveToEndAddTab(treeTabPanel)
end

--- This function sends given string message to BtEvaluator.
-- @tparam String message Message.
function sendStringToBtEvaluator(message)
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), "BETS " .. message)
end

--- Removes tree from BtContoller. It removes panel corresponding to provided TreeHandle.
-- Unmarks all units assigned to corresponding tree handle. 
-- Removes record of their assignmend in TreeHandle table and sends message to BtEvaluator 
-- to remove it. This functio should be used for removing tree instances. 
-- @tparam TreeHandle treeHandle Tree handle of removed instance. 
function removeTreeBtController(treeHandle)
	local tabs = treeTabPanel
	-- remove the bar item
	-- get tabBar
	local tabBar = tabs.children[CONSTANTS.tabBarChildIndex]
	
	-- is it currently shown?
	if treeHandle.name == tabBar.selected_obj.caption and BtCreator then
		-- hiding disabled as the tabs are no longer linked to each other
		--BtCreator.hide()
	end
	
	tabBar:Remove(treeHandle.name)
	-- remove chili elements ?
	local deleteFrame = tabs.tabIndexMapping[treeHandle.name]
	tabs.currentTab:RemoveChild(deleteFrame)
	-- remove from tabPanel name-frame map
	tabs.tabIndexMapping[treeHandle.name] = nil
	-- make sure addtab is in right place
	moveToEndAddTab(tabs)
	
	-- remove markes above units
	unmarkAllUnitsInTree(treeHandle)
	-- remove records of unit assignment:
	TreeHandle.removeUnitsFromTree(treeHandle.instanceId)
	
	if(treeHandle.Created) then
		-- remove send message to BtEvaluator
		BtEvaluator.removeTree(treeHandle.instanceId)
	end
	
	treeHandle:DisposeAllChiliComponents()
end


local instantiateTree
--- Reloads given treehandle from given tabs. 
-- Removes old Chili components from given tabs and set up new ones. 
-- Old tree was created in BtEvaluator, it is removed. If new tree is ready, 
-- message to create given instance in BtEvaluator is send. Assignments in roles are kept
-- if corresponding role keeps its name. 
-- User specified inputs are also kept, provided input name and type is preserved. 
-- If error occured, tree is switched to error state. 
-- @tparam Chili.TabPanel tabs Tab panel where Chili components corresponding to treeHandle are kept. 
-- @tparam TreeHandle treeHandle Tree handle of reloaded instance. 
function reloadTree(tabs, treeHandle)
	-- remove tree instance in BtEvaluator if it is created:
	treeHandle:UpdateTreeStatus()
	if(treeHandle.Created) then
		-- remove send message to BtEvaluator
		BtEvaluator.removeTree(treeHandle.instanceId)
		treeHandle.Created = false
	end
	-- get the new tree specification and GUI components:
	treeHandle:ReloadTree()
	-- GUI components:
	local tabFrame = tabs.tabIndexMapping[treeHandle.name]
	-- remove old GUI components:
	tabFrame:ClearChildren()
	
	-- now attach new ones:	
	for _,component in pairs(treeHandle.ChiliComponentsGeneral)do
		tabFrame:AddChild(component)
	end
	for _,component in pairs(treeHandle.ChiliComponentsRoles)do
		tabFrame:AddChild(component)
	end
	for _,component in pairs(treeHandle.ChiliComponentsInputs)do
		tabFrame:AddChild(component)
	end
	tabFrame:RequestUpdate()

	-- if tree is ready, initialize it in BtEvaluator
	if(treeHandle:CheckReady()) then
		treeHandle.Created = true
		createTreeInBtEvaluator(treeHandle)
	end
	if(treeHandle.Created) then
		reportAssignedUnits(treeHandle)
	end
	treeHandle:UpdateTreeStatus()
	
end


local referencesForTrees = {}

--- Reloads all instances of given tree type in given tab panel.
-- @tparam String treeTypeName Name of tree type to be reloaded.
function BtController.reloadTreeType(treeTypeName)
	-- refresh tree selection:
	refreshTreeSelectionPanel()
	
	-- I should iterate over all tab bar items:
	-- get tabBar
	local tabBar = treeTabPanel.children[CONSTANTS.tabBarChildIndex]
	-- find corresponding tabBarItems: 
	local barItems = tabBar.children
	for index,item in ipairs(barItems) do
		-- if there is TreeHandle in this item and the tree type is right one:
		local hasHandle = item.TreeHandle ~= nil
		local needsReload = hasHandle and (item.TreeHandle.treeType == treeTypeName)
		
		if hasHandle and not needsReload then
			local refs = referencesForTrees[item.TreeHandle.treeType]
			if refs then
				for _, refTypeName in ipairs(refs) do
					if refTypeName == treeTypeName then
						needsReload = true
						break
					end
				end
			end
		end
		if needsReload then
			reloadTree(treeTabPanel, item.TreeHandle)
		end
	end
	-- get selected tab:
	local barItem = tabBar.selected_obj
	-- if it is not + then:
	if(barItem.caption ~= CONSTANTS.addTreeTabName) then
		local tH = barItem.TreeHandle
		-- I should show selected tree:
		if(tH.Created) then 
			BtEvaluator.reportTree(tH.instanceId)
		end
		if(BtCreator) then
			BtCreator.focusTree(tH.treeType, tH.name, tH.instanceId)
		else
			Logger.log("Error", "BtControler - reloadTreeType: no BtCreator.")
		end
	end
	
	local success, msg = BtCommands.tryRegisterCommandForTree(treeTypeName)
	if not success then
		Logger.log("commands", "Tree command not registered: ", msg)
	end
end

--- This method will reload all tree instances currently present in BtController
-- Sensor pool and node pool in BtCreator are reloaded as well.
function reloadAll()
	-- reload cache in BtEvaluator:
	BtUtils.ProjectManager.reload()
	BtEvaluator.reloadCaches()
	-- I should iterate over all tab bar items:
	-- get tabBar
	local tabBar = treeTabPanel.children[CONSTANTS.tabBarChildIndex]
	-- find corresponding tabBarItems: 
	local barItems = tabBar.children
	for index,item in ipairs(barItems) do
		if(item.caption ~= CONSTANTS.addTreeTabName)then -- exclude addtab item from reloading...
			reloadTree(treeTabPanel, item.TreeHandle)
		end
	end
	
	resetMarkers()
	if(BtCreator)then
		BtCreator.reloadSensorPool()
		BtCreator.reloadNodePool()
	end
end
--- This method pop up simple error window. Currently used if user tries 
-- to create instance with already used instance name. This window just display givne string 
-- and is hidden after user clicks on "Done" button.
--@tparam String errorDecription Error message displayed in error window. 
function showErrorWindow(errorDecription)
	errorLabel.caption = errorDecription
	errorWindow:Show()
end

--- Logs unit assignments records from TreeHandle table. Parameter sets log category (e.g."Error", "Warning")
--@tparam String category Log category.
function logUnitsToTreesMap(category)
	Logger.log(category, " ***** unitsToTreesMapLog: *****" )
	for unitId, unitData in pairs(TreeHandle.unitsToTreesMap) do
		Logger.log(category, "unitId ", unitId, " instId ", unitData.instanceId, " label inst: ", unitData.TreeHandle.Roles[unitData.Role].unitCountButton.instanceId, " treeHandleId: ", unitData.TreeHandle.instanceId, " button insId: ", unitData.TreeHandle.Roles[unitData.Role].assignButton.instanceId, " treeHandleName ", unitData.TreeHandle.name )
	end
	Logger.log(category, "***** end *****" )
end



--- This function realizes Automatic roles assignment. Based on categories added to 
-- tree roles units are assigned to corresponding roles based on their unit type.
-- If unit type belong to no roles, it is assigned to first role. 
-- If it is in multiple roles, they are chosen alternatively.
-- Assigned units are reported to BtEvaluator - it is expected that this instance
-- is already created there. 
-- @tparam TreeHandle treehandle Tree handle of new instance.
-- @param selectedUnits Array of unit IDs.  
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
			treeHandlesWithRemovedUnits[thWithRemovedUnit.instanceId] = thWithRemovedUnit
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


--- Calls required functions to create tree in BtEvaluator, if error occurred, 
-- tree handle switches to error state. 
-- @tparam TreeHandle treeHandle Tree handle to have its instance created in BtEvaluator.
function createTreeInBtEvaluator(treeHandle)
	local result, message
	result, message = BtEvaluator.dereferenceTree(treeHandle.Tree)
	referencesForTrees[treeHandle.treeType] = result or {}
	
	if(not result) then
		treeHandle:SwitchToErrorState("deferenceTree error: " .. message)
		treeHandle.Created = false
		return
	end
	result,message = BtEvaluator.createTree(treeHandle.instanceId, treeHandle.Tree, treeHandle.Inputs)
	if(not result) then
		-- error state
		treeHandle:SwitchToErrorState("createTree error: " ..message)
		treeHandle.Created = false
		return
	end
end

--- Reports units assigned to all roles in given tree instance to BtEvaluator.
-- @tparam TreeHandle treeHandle Units of which instance should be reported.
function reportAssignedUnits(treeHandle)
	if(treeHandle.Created == false or treeHandle.error) then 
		-- nothing to report
		return
	end
	local originallySelectedUnits = spGetSelectedUnits()
	for name,roleData in pairs(treeHandle.Roles) do
		-- now I need to share information with the BtEvaluator
		local unitsInThisRole = TreeHandle.unitsInTreeRole(treeHandle.instanceId, name)
		spSelectUnits(unitsInThisRole)
		BtEvaluator.assignUnits(unitsInThisRole, treeHandle.instanceId, roleData.roleIndex)
	end
	spSelectUnits(originallySelectedUnits)
end

--- Reports users input for given input slot to BtEvaluator.
-- @tparam Treehandle treeHandle Corresponding tree handle.
-- @tparam String inputName Name of corresponding input. 
function reportInputToBtEval(treeHandle, inputName)
	BtEvaluator.setInput(treeHandle.instanceId , inputName, treeHandle.Inputs[inputName]) 
end 

--- Remove tree instances in BtController tab panel which require 
-- units to be assigned to them and they don't have any units assigned. 
function removeTreesWithoutUnitsRequiringUnits()
	local tabBar = treeTabPanel.children[CONSTANTS.tabBarChildIndex]
	local barItems = tabBar.children
	-- get trees to remove
	local treesToRemove = {}
	for index,item in ipairs(barItems) do
		if  (item.caption ~= CONSTANTS.addTreeTabName) then-- exclude add tree tab
			
			if (item.TreeHandle.RequireUnits) and  (item.TreeHandle.AssignedUnitsCount < 1) then
				-- if there are no units, remove this tree:
				table.insert(treesToRemove,  item.TreeHandle)
			end
		end
	end
	
	-- remove all trees without units which require units
	for _,treeHandle in ipairs(treesToRemove) do 
		removeTreeBtController( treeHandle)
	end
end







--//////////////////////////////////////////////////////////////////////////////
-----REWRITTEN CHILI FUNCTIONS:
--- This function is a clone of regular tabBarItemListener from Chili. This is used
-- by our custom listener to restrict functionality of default listener to just left clicks. 
-- @tparam Chili.TabBartItem self Tab bar item which was clicked on.  
function tabBarItemMouseDownBETS(self, ...)
  self.inherited.MouseDown(self, ...)
  return self
end 
--//////////////////////////////////////////////////////////////////////////////

---------------------------------------LISTENERS
--- This listener is called when AddTreeTab becomes active to update directory 
-- content and default instance name.
function refreshTreeSelectionPanel()
	names = BehaviourTree.list()
	treeSelectionComboBox.items = names 
	treeSelectionComboBox:RequestUpdate()
	treeNameEditBox.text = "Instance"..instanceIdCount
end

--- Listener for click on lock icon. It changes icon appearnce and marks units 
-- under control of corresponding instance with proper icon. 
-- @tparam Chili.Button self Lick icon. 
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

--- This listener is called when user clicks on tabBar item in BtController. The 
-- original listener is replaced by this one (not added to it). Left button will
-- select the panel in usual way. But middle click will remove given instance from
-- BtController (and BtEvaluator if it was created).
-- @tparam Chili.TabBarItem self TabBarItem on which it was clicked.
-- @param x X coordinate of mouse.
-- @param y Y coordinate of mouse.
-- @param button Which mouse button is clicked. 
function listenerBarItemClick(self, x, y, button, ...)
	if button == 1 then
		-- select assigned units, if any
		local unitsToSelect = TreeHandle.unitsInTree(self.TreeHandle.instanceId)
		spSelectUnits(unitsToSelect)
		
		local tH = self.TreeHandle
		tH:UpdateTreeStatus()
		
		
		if(self.TreeHandle.Created) then 
			BtEvaluator.reportTree(tH.instanceId)
		end
		
		if(BtCreator) then
			BtCreator.focusTree(tH.treeType, tH.name, tH.instanceId)
		else
			Logger.log("Error", "BtControler - listenerBarItemClick: no BtCreator.")
		end
		-- ORIGINAL LISTENER FORM BarItem:
		if not self.parent then return end
		self.parent:Select(self.caption)
		return self
		-- END OF ORIG. LISTENER
	end
	if button == 2 then
		--middle click
		removeTreeBtController( self.TreeHandle)
		
		-- now new tree tab might be selected, in such case, btcreator should know about it:
		-- I need to find selected tabBarItem: 
		local tabBar = treeTabPanel.children[CONSTANTS.tabBarChildIndex]
		local selectedItem = tabBar.selected_obj
		-- call onclick item
		for _,listener in ipairs(selectedItem.OnClick) do
			listener(selectedItem, x,y, 1)
		end
	end
end 

--- This is listener for AssignUnits buttons of given tree instance. 
-- The button should have TreeHandle and Role attached on it. 
-- This listener is send to TreeHandle during its creation to be attached to
-- corresponding Chili component.
-- If given instance is running, it is restared. Units are marked.
-- @tparam Chili.Button Assign button. 
-- @param x X coordinate of mouse.
-- @param y Y coordinate of mouse.
function listenerAssignUnitsButton(self,x,y, ...)
	-- self = chili:button
	-- deselect units in current role
	-- Here I am deassigning all units, that might destroy some tree:
	
	local treeHandlesWithRemovedUnits = {}
	local removedUnits = {}
	for unitId,treeAndRole in pairs(TreeHandle.unitsToTreesMap) do	
		if(treeAndRole.instanceId == self.TreeHandle.instanceId) and (treeAndRole.Role == self.Role) then
			removedUnits[#removedUnits +1] = unitId
			local thWithRemovedUnit = TreeHandle.removeUnitFromCurrentTree(unitId)
			if thWithRemovedUnit then
				treeHandlesWithRemovedUnits[thWithRemovedUnit.instanceId] = thWithRemovedUnit
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
			self.TreeHandle.Created = true
			createTreeInBtEvaluator(self.TreeHandle)
			reportAssignedUnits(self.TreeHandle)
		end
		BtEvaluator.assignUnits(selectedUnits, self.TreeHandle.instanceId, self.roleIndex)
	end
	-- put markers over units in selection:
	markUnits(self.TreeHandle,  self.Role)
	
	-- now I should check if there are units in this tree
	-- if the tree has no more units:
	removeTreesWithoutUnitsRequiringUnits()
end

--- Returns one ally unit. First unit in unit list is returned. 
-- This is used for BETS custom commnads, because Spring command cannot work if 
-- no unit is selected. 
local function getDummyAllyUnit()
	local allUnits = Spring.GetTeamUnits(Spring.GetMyTeamID())
	return allUnits[1]
end

local fillInExpectedInput

--- Listener for input button. It is send during creation of new 
-- TreeHandle instance to be attached to corresponding buttons. It is expected to 
-- contain array CommandName with name of BETS custom  command which correponds to
-- type of input, corresponding instanceId, conrresnpoind TreeHandle and InputName.
-- It sends message to BtCommands to fill given input with user data once they arrive.
-- @tparam Chili.Button Assign button. 
-- @param x X coordinate of mouse.
-- @param y Y coordinate of mouse. 
function listenerInputButton(self,x,y,button, ...)
	-- should I do something more when reseting the input que?
	-- I need to store record what we are expecting
	expectedInput = {
		TreeHandle = self.TreeHandle,
		InputName = self.InputName,
		CommandName = self.CommandName,
		instanceId = self.instanceId,
	}
	BtCommands.getInput(self.CommandName,  fillInExpectedInput)
	--[[
	local f = function()
		cmdId = BtCommands.inputCommands[ expectedInput.CommandName ]
		local ret = spSetActiveCommand(  spGetCmdDescIndex(cmdId) ) 
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
	]]
end

--- Listener for reload all button, calls reloadAll function. 
function listenerReloadAll(self, x, y, ...)
	refreshTreeSelectionPanel()
	reloadAll()
end 
--- Listener for closing error window invoked through showErrorWindow function. 
function listenerErrorOk(self)
	errorWindow:Hide()
end

--- Listener for button in treeSelectionTab which creates new tree. 
-- If given instance name is already created, an error window pops up. Otherwise 
-- instantiateTree function is called to create corresponding treeHandle. 
-- @tparam Chili.TabBarItem self TabBarItem on which it was clicked.
-- @param x X coordinate of mouse.
-- @param y Y coordinate of mouse.
-- @param button Which mouse button is clicked. 
local function listenerClickOnSelectedTreeDoneButton(self, x, y, button)
	if button == 1 then
		-- we react only on leftclicks
		-- check if instance name is not being used:
		if(treeTabPanel.tabIndexMapping[treeNameEditBox.text] == nil ) then
			local selectedTreeType = treeSelectionComboBox.items[treeSelectionComboBox.selected]
			local instanceName = treeNameEditBox.text
			local newTreeHandle = instantiateTree(selectedTreeType, instanceName, false)
			if newTreeHandle then
				listenerBarItemClick({TreeHandle = newTreeHandle},x ,y ,button)
			end
		else
			-- if such instance name exits show error window
			showErrorWindow("Duplicate instance name.")
		end
	end
end



--- This function show currently selected tree in BtCreator.  
local function listenerClickBtCreator(self, x, y, button)
	-- get the selected tab from tabs:	
	tabBar = treeTabPanel.children[CONSTANTS.tabBarChildIndex]
	local barItem = tabBar.selected_obj
	-- if it is not + then show BtCreator (send him message)
	if(barItem.caption ~= CONSTANTS.addTreeTabName) then
		local tH = barItem.TreeHandle
		-- tree tab is selected (not add tree tab)
		if(barItem.TreeHandle.Created) then 
			BtEvaluator.reportTree(tH.instanceId)
		end
		BtCreator.showTree(tH.treeType, tH.name, tH.instanceId)
	else
		-- add tree tab is selected
		BtCreator.show()
	end
end

---------------------------------------LISTENERS END

--- This is the method to create new tree instance. 
-- It will create the instance,
-- create new tree tab in BtController's tab panel,
-- notify BtEvaluator if tree is ready for running and
-- returns the new treeHandle.
-- Require units is true for trees  created through UI command. 
-- @tparams String treeType Selected tree type.
-- @tparams String instanceName Name of new tree instance. 
-- @tparams Boolean requireUnits If tree require units.
function instantiateTree(treeType, instanceName, requireUnits)
	
	
	local newTreeHandle = TreeHandle:New{
		name = instanceName,
		treeType = treeType,
		AssignUnitListener = sanitizer:AsHandler(listenerAssignUnitsButton),
		InputButtonListener = sanitizer:AsHandler(listenerInputButton),
		lockImageListener = sanitizer:AsHandler(listenerLockImage),
		RequireUnits = requireUnits,
	}
	if not newTreeHandle then
		local x,y = treeControlWindow:LocalToScreen(100,100)
		Dialog.showErrorDialog({
			title = "Tree load error",
			message = "The tree '" .. treeType .. "' couldn't be loaded.\nThe file may be corrupted.",
			x = x,
			y = y,
			visibilityHandler = function(visible) 
				treeControlWindow.disableChildrenHitTest = visible
			end
		})
		return nil
	end
	
	local selectedUnits = spGetSelectedUnits()
	if ((table.getn(selectedUnits) < 1 ) and newTreeHandle.RequireUnits) then
		Logger.log("Errors", "BtController: instantiateTree: tree is requiring units and no unit is selected.")
		return newTreeHandle
	end
	
	
	-- create tab
	addTreeToTreeTabPanel(newTreeHandle)
		
	-- now, auto assign units to tree
	automaticRoleAssignment(newTreeHandle, selectedUnits)
	newTreeHandle:UpdateTreeStatus()
	
	-- mark units in tree:
	markAllUnitsInTree(newTreeHandle)
	
	
	if(newTreeHandle:CheckReady()) then
		newTreeHandle.Created = true
		createTreeInBtEvaluator(newTreeHandle)
		reportAssignedUnits(newTreeHandle)
	end

	return newTreeHandle
end

--- This method moves a tab with name specified as CONSTANTS.addTreeTabName to be the last
-- tab om given tab panel. 
-- @tparam Chili.TabPanel tabs Tab panel where to take place. 
function moveToEndAddTab(tabs)
	-- do we have such tab
	if tabs.tabIndexMapping[CONSTANTS.addTreeTabName] == nil then
		-- Or should I report it:
		Logger.log("Error", "Trying to move + tab and it is not there.")
		return
	end
	
	refreshTreeSelectionPanel()
	
	-- get tabBar
	local tabBar = tabs.children[CONSTANTS.tabBarChildIndex]
	if (#(tabBar.children) >= 2) then
		-- if tabBar.children < 2 then Remove wont do anything.. and we hope that CONSTANTS.addTreeTabName is the only and last tab
		tabBar:Remove(CONSTANTS.addTreeTabName)
		local newTabBarItem = Chili.TabBarItem:New{
			caption = CONSTANTS.addTreeTabName, 
			defaultWidth = tabBar.minItemWidth, 
			defaultHeight = tabBar.minItemHeight,
		}
		tabBar:AddChild(
			newTabBarItem
		)
		finalizeAddTreeBarItem(tabs)
	end
end


--- Finds propriate tab in provided Chili.TabPanel and adds to it listeners, tooltip to "addTreeTab",
-- focusColor.
-- @tparam Chili.TabPanel tabs Tab panel where to take place.   
function finalizeAddTreeBarItem(tabs)
	local item = getBarItemByName(tabs, CONSTANTS.addTreeTabName)
	item.focusColor = {0.2, 1.0, 0.2, 0.6}
	item.tooltip = "Add a new instance of the behaviour tree. "
	local listeners = item.OnMouseDown
	table.insert(listeners,refreshTreeSelectionPanel)
end

--- This function sets up Chili components of the "addTreeTab" in BtController TabPanel. 
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

--- Set up Chili components of the main BtController window - window itself,
--  label, "Editor" button, "Reload all" and tree tab panel.
-- "Editor" button is on showed if BtCreator is not present. 
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
		caption = "Editor",
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
	
	local newTab = {name = CONSTANTS.addTreeTabName, children = {treeSelectionPanel} }
	
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

--- This function prepares chili components of simple error window. 
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

--- This function removes all markers from units and then marks them correctly. 
-- called durin initalization and tree instances reloading.
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
--- Main initialization function. It is mostly used for creating GUI (Chili components).
-- BtController is dependent on BtCommandsm and BtCreator. BtConfig is loaded here as well.
function widget:Initialize()	
	-- Get ready to use Chili
	Chili = WG.ChiliClone
	Screen0 = Chili.Screen0	
	
	Dependency.defer(
		function() 
			BtCommands = sanitizer:Import(WG.BtCommands) 
		end, 
		function() 
			BtCommands = nil 
		end, Dependency.BtCommands)
	
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
	
	
	WG.BtControllerReloadTreeType = sanitizer:Sanitize(BtController.reloadTreeType)
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

--- When whidget is shutting down all Marks are removed.
function widget:Shutdown()
	removeAllMarks()
	
	WG.BtControllerReloadTreeType = nil
	
	Dependency.clear(Dependency.BtController)
end

--//////////////////////////////////////////////////////////////////////////////
-- Callins

--- Function used to identify if mouse is over BtController. It uses simple rectangular check. 
-- @param x X coordinate of mouse.
-- @param y Y coordinate of mouse.
function widget:IsAbove(x,y)
	y = Screen0.height - y
	if (x > treeControlWindow.x and x < treeControlWindow.x + treeControlWindow.width and 
			y > treeControlWindow.y and y < treeControlWindow.y + treeControlWindow.height) then
			return true
	end
	return false
end

--- Function used to retrieve tooltip. 
-- @param x X coordinate of mouse.
-- @param y Y coordinate of mouse.
function widget:GetTooltip(x, y)
	local component = Screen0:HitTest(x, Screen0.height - y)
	if (component) then
		return component.tooltip
	end
end

--- Callback when unit is destroyed, our case we need to remove corresponding records 
-- from TreeHandle table, update given instance of TreeHandle and remove marks for 
-- corresponding unit. Check if this was not last unit in given tree and 
-- it does not need to be removed (require units).
-- @param unitId ID of recently deceised unit. 
function widget:UnitDestroyed(unitId)
	if(TreeHandle.unitsToTreesMap[unitId] ~= nil) then
		local treeHandle =  TreeHandle.unitsToTreesMap[unitId].TreeHandle
		TreeHandle.removeUnitFromCurrentTree(unitId)
		removeMarks({unitId})
		-- if the tree has no more units:
		removeTreesWithoutUnitsRequiringUnits()
	end
end

--- Called screen update. Our widget needs to check selected units and, if needed, 
-- deselect units in locked trees.
function widget:Update() 
	local selectedUnits = spGetSelectedUnits()
	local assignedUnitsMap = TreeHandle.unitsToTreesMap
	local okUnits = {}
	local okUnitsCounter = 0
	local allUnitsOk = true
	for i=1, #selectedUnits do -- !! TIME CRITICAL
		local thisUnitID = selectedUnits[i]
		local thisUnitOk = true
		if (assignedUnitsMap[thisUnitID] ~= nil) then
			if (assignedUnitsMap[thisUnitID].TreeHandle.unitsLocked) then
				allUnitsOk = false
				thisUnitOk = false
			end
		end
		
		if (thisUnitOk == true) then
			okUnitsCounter = okUnitsCounter + 1
			okUnits[okUnitsCounter] = thisUnitID
		end
	end
	
	if (allUnitsOk == false) then -- ! only if necessary do re-selection
		spSelectUnits(okUnits)
	end
end

--- This function is call back from BtCommands in case user give input we asked for. 
-- Input collection is done by sending to Spring message to try issue a Spring 
-- command with a parameter. Spring collects input for us and this command is then
-- catched by BtCommands which then calls propriate callback (this one) with collected data
-- as a paramter.
-- @param data Input data.
fillInExpectedInput = function(data) 
	if expectedInput then
		local tH = expectedInput.TreeHandle 
		local inpName = expectedInput.InputName
		 
		tH:FillInInput(inpName, data)
		expectedInput = nil
		-- if tree is ready we should report it to BtEvaluator
		if(tH:CheckReady()) then 
			if(tH.Created == false) then
				tH.Created = true
				createTreeInBtEvaluator(tH)
				if(tH.Created) then
					-- tree might not be created because of error
					reportAssignedUnits(tH)
					tH:UpdateTreeStatus()
					BtEvaluator.reportTree(tH.instanceId)
				end
			else
				-- tree is ready, we can report just input
				reportInputToBtEval(tH, inpName)
			end	
		end
	else
			Logger.log("commands", "BtController: Received input command while not expecting one!!!")
	end
end

--- This callaback is called when there is issued command. BtController uses it 
-- to catch behaviour related custom commands and create corresponding instance. If it 
-- is behaviour related, then it is not send further and tree is created. 
function widget.CommandNotify(self, cmdID, cmdParams, cmdOptions)

	-- check for custom commands - Bt behaviour assignments
	local treeCommandsTable = BtCommands.behaviourCommands
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
	--Logger.log("commands", "received unknown command (probably normal case): " , cmdID)
	return false
end 
  
--- Saves UnitDefs tables into UnitDefs folder - to be able to see what can be used.
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