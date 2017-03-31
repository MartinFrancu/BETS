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
local sanitizer = Utils.Sanitizer.forWidget(widget)

local Debug = Utils.Debug;
local Logger = Debug.Logger
local dump = Debug.dump

local TreeHandle --= VFS.Include(LUAUI_DIRNAME .. "Widgets/BtController/BtTreeHandle.lua", BtController, VFS.RAW_FIRST)

--------------------------------------------------------------------------------
local treeControlWindow
local controllerLabel
local treeTabPanel
local showTreeCheckbox
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
-- This table is indexed by unitId and contains structures:
-- {InstanceId = "", Role = "", TreeHandle = treehandle} 
-- local unitsToTreesMap

-- If we are in state of expecting input we will make store this information here
local expectedInput 
--------------------------------------------------------------------------------
local spGetCmdDescIndex = Spring.GetCmdDescIndex
local spSetActiveCommand = Spring.SetActiveCommand
local spGetSelectedUnits = Spring.GetSelectedUnits

local function getTreeNamesInDirectory(directoryName)
   local ending = ".json"
   local folderContent = Utils.dirList(directoryName, "*"..ending) --VFS.DirList(directoryName)
   -- get just names .json files
   local treeNames = {}
   for _,treeName in ipairs(folderContent) do
	table.insert(treeNames, treeName:sub(1, treeName:len() - ending:len()) ) 
	--folderContent = getStringsWithoutSuffix(folderContent, ".json")
   end 
  --[[ -- Remove the path prefix of folder:
   for i,v in ipairs(folderContent)do
	folderContent[i] = string.sub(v, string.len( directoryName)+2 ) 
	--THIS WILL MAKE TROUBLES WHEN DIRECTORY IS DIFFERENT: the slashes are sometimes counted once, sometimes twice!!!\\
   end
   --]]
   return  treeNames
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
	local chiliComponents = treeHandle.ChiliComponentsGeneral
	for _,component in pairs (treeHandle.ChiliComponentsRoles) do
		table.insert(chiliComponents,component)
	end
	for _,component in pairs (treeHandle.ChiliComponentsInputs) do
		table.insert(chiliComponents,component)
	end
	local newTab =  {name = treeHandle.Name, children = chiliComponents}
	-- if TabPanel is not inialized I have to initalize it:
	treeTabPanel:AddTab(newTab)
	highlightTab(newTab.name)
	
	-- get tabBar		
	addFieldToBarItem(treeTabPanel, newTab.name, "MouseDown", sanitizer:AsHandler(tabBarItemMouseDownBETS) )
	addFieldToBarItemList(treeTabPanel, newTab.name, "OnClick", sanitizer:AsHandler(listenerBarItemClick) )
	addFieldToBarItem(treeTabPanel, newTab.name, "TreeHandle", treeHandle)
	addFieldToBarItem(treeTabPanel, newTab.name, "tooltip", "Panel of ".. treeHandle.Name .. " tree")
	
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
		Logger.loggedCall("Call", "BtController", 
			"hiding BtController which is showing removed tree", BtCreator.hide)
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
	
	if(treeHandle.Created) then
		-- remove send message to BtEvaluator
		Logger.loggedCall("Errors", "BtController", "removing tree fromBbtEvaluator", 
			BtEvaluator.removeTree, treeHandle.InstanceId)
	end
end


local instantiateTree

function reloadTree(tabs, treeHandle)
	-- remove tree instance in BtEvaluator if it is created:
	if(treeHandle.Created) then
		-- remove send message to BtEvaluator
		Logger.loggedCall("Errors", "BtController", "removing tree fromBbtEvaluator", 
			BtEvaluator.removeTree, treeHandle.InstanceId)
	end
	
	-- get the new tree specification and GUI components:
	treeHandle:ReloadTree()
	
	-- GUI components:
	local tabFrame = tabs.tabIndexMapping[treeHandle.Name]
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
	
	-- if tree is ready, initialize it in BtEvaluator
	if(treeHandle:CheckReady()) then
		createTreeInBtEvaluator(treeHandle)
		treeHandle.Created = true
		reportAssignedUnits(treeHandle)
	end
	
	treeHandle:UpdateTreeStatus()
	
	-- I need to find 
--[[	local instanceName = treeHandle.Name
	local treeType = treeHandle.TreeType
	local requireUnits = treeHandle.RequireUnits
	local assignedUnits = {}
	for _,roleData in pairs(treeHandle.Tree.roles) do		
		local unitsInRole = TreeHandle.unitsInTreeRole(treeHandle.InstanceId, roleData.name)
		if( table.getn(unitsInRole) >= 1) then
			assignedUnits[roleData.name] = unitsInRole
		end
		Logger.log("roles", "reload tree, role name : ", roleData.name, " units in role: ",table.getn(unitsInRole) )
	end


	removeTreeBtController(tabs, treeHandle)
	-- getting a new tree, but no reporting it:
	
	local newTreeHandle = TreeHandle:New{
		Name = instanceName,
		TreeType = treeType,
		AssignUnitListener = sanitizer:AsHandler(listenerAssignUnitsButton),
		InputButtonListener = sanitizer:AsHandler(listenerInputButton),
		RestartTreeListener =  sanitizer:AsHandler(restartTreeListener),
	}
	
	addTreeToTreeTabPanel(newTreeHandle)
	
	newTreeHandle.RequireUnits = requireUnits
	
	-- transfering user given data: 
	
	-- units assignment:
	for _,roleData in pairs(newTreeHandle.Tree.roles) do
		-- if the name is same, assign units in this role:
		if( assignedUnits[roleData.name] ~= nil) then
			for _,unitId in pairs(assignedUnits[roleData.name]) do
				TreeHandle.assignUnitToTree(unitId, newTreeHandle, roleData.name)
			end
		end
	end
	
	
	
	-- inputs:
	local oldInputsCmd = {}
	for _,inputSpec in pairs (treeHandle.Tree.inputs) do
		oldInputsCmd[inputSpec.name] = inputSpec.command
	end
	-- collect old input command names:
	for _, inputSpec in pairs (newTreeHandle.Tree.inputs) do
		local inputName = inputSpec.name
		if (oldInputsCmd[inputName] ~= nil) then		
			local givenInput = treeHandle.Inputs[inputName]
			local oldCommand = oldInputsCmd[inputName]
			local newCommand = inputSpec.command
			-- if input was given and it has the same type (colecting command name) then fill the data in
			if (givenInput ~= nil) and (oldCommand == newCommand) then  
				newTreeHandle:FillInInput(inputName, treeHandle.Inputs[inputName])
			end
		end 
	end
	
	-- if tree is ready, initialize it in BtEvaluator
	if(newTreeHandle:CheckReady()) then
		createTreeInBtEvaluator(newTreeHandle)
		newTreeHandle.Created = true
		reportAssignedUnits(newTreeHandle)
	end
	
	newTreeHandle:UpdateTreeStatus()
	--listenerBarItemClick({TreeHandle = treeHandle}, 0, 0, 1)
	--]]
end

function BtController.reloadTreeType(treeTypeName)

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
			BtController.reloadTree(treeTabPanel, item.TreeHandle)
		end
	end

	--[[
	for _,treeHandle in pairs(toReload) do
		reloadTree(treeTabPanel, treeHandle)
	end
	
	local currentTabName = tabBar.selected_obj.caption
	local currentTreeHandle =  tabBar.selected_obj.TreeHandle
	--local currentTab = treeTabPanel.tabIndexMapping[currentTabName]
	local currentTreeHandle
	for index,tabBarItem in pairs(tabBar.children) do
		if(tabBarItem.caption == currentTabName) then
			currentTreeHandle = tabBarItem.TreeHandle
		end
	end
	
	-- if tree with this type is shown show BtCreator
	Logger.log("roles", "tree type:" ,treeTypeName, " and " , currentTreeHandle.TreeType )
	if treeTypeName == currentTreeHandle.TreeType then
		
		listenerBarItemClick({TreeHandle =  currentTreeHandle}, 0, 0, 1)
	end
	--]]
end

-- This method will reload all tree instances currently present in BtController.
-- Later should be added reload of sensorst etc..
function reloadAll()
	-- reload cache in BtEvaluator:
	Logger.loggedCall("Error", "BtController", "asking BtEvaluator to clear cache.",
		BtEvaluator.reloadCaches)
	-- I should iterate over all tab bar items:
	local tabBarChildIndex = 1
	-- get tabBar
	local tabBar = treeTabPanel.children[tabBarChildIndex]
	-- find corresponding tabBarItems: 
	local barItems = tabBar.children
	for index,item in ipairs(barItems) do
		BtController.reloadTree(treeTabPanel, item.TreeHandle)
	end
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
	
	for _,roleData in pairs(treeHandle.Roles) do
		for name,record in pairs(roleData.unitTypes) do
			if(unitIdRoleTable[name] == nil) then
				unitIdRoleTable[name] = {currentIndex = 1, roles = {}}
			end
			table.insert(unitIdRoleTable[name].roles, roleData)
		end
	end	
	
	for i,unitId in pairs(selectedUnits) do
		local unitDefId = Spring.GetUnitDefID(unitId)
		if(UnitDefs[unitDefId] ~= nil)then  
			local name = UnitDefs[unitDefId].name
			if(unitIdRoleTable[name] ~= nil) then
				local unitRoles = unitIdRoleTable[name]
				local currentRoleData = unitRoles.roles[unitRoles.currentIndex]
				Logger.log("roles", "assigning to role", currentRoleData)
				TreeHandle.assignUnitToTree(unitId, treeHandle, currentRoleData.assignButton.Role)
				-- now, I should shift the index:
				unitRoles.currentIndex = unitRoles.currentIndex + 1 
				if(unitRoles.currentIndex > table.getn(unitRoles.roles) ) then
					unitRoles.currentIndex = 1 -- reset the current index
				end
			else
				-- put into default role:
				TreeHandle.assignUnitToTree(unitId, treeHandle, treeHandle.Tree.defaultRole)
			end
		else
			Logger.log("roles", "could not find UnitDefs entry for: ",  unitId )
		end
	end
end


-- Calls required functions to create tree in BtEvaluator
function createTreeInBtEvaluator(treeHandle) 	
	Logger.loggedCall("Errors", "BtController", "instantiating new tree in BtEvaluator", 
		BtEvaluator.createTree, treeHandle.InstanceId, treeHandle.Tree, treeHandle.Inputs)
end

-- Reports units assigned to all roles to BtEvaluator
function reportAssignedUnits(treeHandle)
	local originallySelectedUnits = spGetSelectedUnits()
	for name,roleData in pairs(treeHandle.Roles) do
		-- now I need to share information with the BtEvaluator
		local unitsInThisRole = TreeHandle.unitsInTreeRole(treeHandle.InstanceId, name)
		Spring.SelectUnitArray(unitsInThisRole)
		Logger.loggedCall("Errors", "BtController", "reporting assigned units, reporting role: ".. name, 
			BtEvaluator.assignUnits, unitsInThisRole, treeHandle.InstanceId, roleData.roleIndex)
	end
	Spring.SelectUnitArray(originallySelectedUnits)
end

-- Reports users input for given input slot to BtEvaluator.
function reportInputToBtEval(treeHandle, inputName)
	Logger.loggedCall("Errors", "BtController", "reporting changed input", 
		BtEvaluator.setInput, treeHandle.InstanceId , inputName, treeHandle.Inputs[inputName]) 
end 

-- this will remove all units from given tree and adjust gui componnets
function removeUnitsFromTree(instanceId)
	for unitId, unitData in pairs(TreeHandle.unitsToTreesMap) do
		if(unitData.InstanceId == instanceId) then
			unitData.TreeHandle:DecreaseUnitCount(unitData.Role)
			TreeHandle.unitsToTreesMap[unitId] = nil
		end
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
local function refreshTreeSelectionPanel(self)
	names = getTreeNamesInDirectory(BehavioursDirectory) --Utils.dirList(BehavioursDirectory, "*.json") --getNamesInDirectory(BehavioursDirectory, ".json")
	treeSelectionComboBox.items = names 
	treeSelectionComboBox:RequestUpdate()
	treeNameEditBox.text = "Instance"..instanceIdCount
end

-- This listener is called when user clicks on tabBar item in BtController. The 
-- original listener is replaced by this one.
function listenerBarItemClick(self, x, y, button, ...)
	if button == 1 then
		-- select assigned units, if any
		local unitsToSelect = TreeHandle.unitsInTree(self.TreeHandle.InstanceId)
		Spring.SelectUnitArray(unitsToSelect)

		self.TreeHandle:UpdateTreeStatus()
		
		if((showTreeCheckbox.checked) and BtCreator) then
			if(self.TreeHandle.Created) then 
				Logger.loggedCall("Error", "BtController", 
					"reporting tree to BtEvaluator",
					BtEvaluator.reportTree, self.TreeHandle.InstanceId
				)
			end
			Logger.loggedCall("Error", "BtController", 
				"making BtCreator show selected tree",
				BtCreator.show, self.TreeHandle.TreeType, self.TreeHandle.InstanceId )
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
function listenerAssignUnitsButton(self,x,y, ...)
	-- self = chili:button
	-- deselect units in current role
	-- Here I am deassigning all units, that might destroy some tree:

	local requireUnitsOriginal = self.TreeHandle.RequireUnits
	Logger.log("roles", "orig require units: ", requireUnitsOriginal)
	self.TreeHandle.RequireUnits = false
	for unitId,treeAndRole in pairs(TreeHandle.unitsToTreesMap) do	
		if(treeAndRole.InstanceId == self.TreeHandle.InstanceId) and (treeAndRole.Role == self.Role) then
			TreeHandle.removeUnitFromCurrentTree(unitId)
		end
	end
	
	local selectedUnits = spGetSelectedUnits()
	for _,Id in pairs(selectedUnits) do
		TreeHandle.assignUnitToTree(Id, self.TreeHandle, self.Role)
	end
	-- check if tree is empty and if it require units
	if(self.TreeHandle:CheckReady() ) then
		Logger.log("roles", "tree is ready i guess, is it reported? ", self.TreeHandle.Created)
		Logger.loggedCall("Errors", "BtController", "assigning units to tree", 
		BtEvaluator.assignUnits, selectedUnits, self.TreeHandle.InstanceId, self.roleIndex)
	end
	self.TreeHandle.RequireUnits = requireUnitsOriginal
	-- now I should check if there are units in this tree
		-- if the tree has no more units:
	if (self.TreeHandle.AssignedUnitsCount < 1) and (self.TreeHandle.RequireUnits) then
		-- remove this tree
		removeTreeBtController(treeTabPanel, self.TreeHandle)
	end
end

function listenerInputButton(self,x,y,button, ...)
	if(not WG.InputCommands or not WG.BtCommands) then
		-- TODO Do a proper initialization, only once. 
		WG.fillCustomCommandIDs()
	end
	-- should I do something more when reseting the input que?
	-- I need to store record what we are expecting
	expectedInput = {
		TreeHandle = self.TreeHandle,
		InputName = self.InputName,
		CommandName = self.CommandName,
		InstanceId = self.InstanceId,
	}
	local ret = spSetActiveCommand(  spGetCmdDescIndex(WG.InputCommands[ expectedInput.CommandName ]) ) 
	if(ret == false ) then 
		Logger.log("commands", "Unable to set command active: " , expectedInput.CommandName) 
	end
end

-- Listener for closing error window.
function listenerErrorOk(self)
	errorWindow:Hide()
end

--[[
function restartTreeListener(self, x,y, button)
	if(button == 1) then
		if(self.TreeHandle:CheckReady()) then
			-- restart it only if it is ready
			Logger.loggedCall("Errors", "BtController", "reseting tree, reset button", 
			BtEvaluator.resetTree, self.TreeHandle.InstanceId)
		end
	end 
end 
]]

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
		RestartTreeListener =  sanitizer:AsHandler(restartTreeListener),
	}
	
	local selectedUnits = spGetSelectedUnits()
	if ((table.getn(selectedUnits) < 1 ) and requireUnits) then
		Logger.log("Errors", "BtController: instantiateTree: tree is requiring units and no unit is selected.")
		return newTreeHandle
	end
	
	-- create tab
	addTreeToTreeTabPanel(newTreeHandle)
			
	-- now, auto assign units to tree
	automaticRoleAssignment(newTreeHandle, selectedUnits)
	
	newTreeHandle.RequireUnits = requireUnits
	
	if(newTreeHandle:CheckReady()) then
		createTreeInBtEvaluator(newTreeHandle)
		--newTreeHandle.ReportTree(newTreeHandle)
		newTreeHandle.Created = true
		reportAssignedUnits(newTreeHandle)
		--newTreeHandle.ReportUnits(newTreeHandle)
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
	item.tooltip = "Adds new instance of a tree. "
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
	
	local availableTreeTypes = getTreeNamesInDirectory(BehavioursDirectory) 
	--Utils.dirList(BehavioursDirectory, "*.json") 
	-- getNamesInDirectory(BehavioursDirectory, ".json")
	
	treeSelectionComboBox = Chili.ComboBox:New{
		items = availableTreeTypes,
		width = '60%',
		x = 110,
		y = 4,
		align = 'left',
		skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0.3,0.3,0.3,0.3},
		tooltip = "Choose a tree type from available behaviours located in BtBehaviours folder. ",
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
		OnClick = {sanitizer:AsHandler(listenerClickOnSelectedTreeDoneButton)},
		tooltip = "Creates new instance of selected behaviour with given tree instance name. ",
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
		draggable=true,
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
		skinName='DarkGlass',
		tooltip = "Determines, whether BtCreator will be shown on instance assignment. ",
	}
	reloadAllButton = Chili.Button:New{
		parent = treeControlWindow,
		caption = "Reload All",
		x = '60%',
		y = 0,
		width = 90,
		skinName='DarkGlass',
		tooltip = "Reloads all trees from drive.",
		OnClick = {}
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

function widget:Initialize()	
	-- Get ready to use Chili
	Chili = WG.ChiliClone
	Screen0 = Chili.Screen0	
	
	local environmentTreeHandle = BtController
	environmentTreeHandle["Chili"] = Chili
	environmentTreeHandle["Utils"] = Utils
	
	Logger.log("separation", "utils", dump(environmentTreeHandle["Utils"],2 ))
	
	TreeHandle = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtController/BtTreeHandle.lua", environmentTreeHandle , VFS.RAW_FIRST)
	
	--TreeHandle.initialize()
  
	BtEvaluator = sanitizer:Import(WG.BtEvaluator)
	-- extract BtCreator into a local variable once available
	Dependency.defer(
		function() BtCreator = WG.BtCreator end,
		function() BtCreator = nil end,
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
		-- listenerClickOnSelectedTreeDoneButton(self, treeSelectionDoneButton.x, treeSelectionDoneButton.y, 1)
	end
	
	Dependency.fill(Dependency.BtController)
end
function widget:Shutdown()
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
		TreeHandle.removeUnitFromCurrentTree(unitId)
	end
end

function widget.CommandNotify(self, cmdID, cmdParams, cmdOptions)
	-- Check for custom commands, first input commands
	if(not WG.InputCommands or not WG.BtCommands) then
		-- TODO Do a proper initialization, only once. 
		WG.fillCustomCommandIDs()
		if(not WG.InputCommands)then
			return false -- if the problem persists, end
		end
	end
	if(WG.InputCommands[cmdID]) then
		if(expectedInput ~= nil) then
			-- I should insert given input to tree:
			local tH = expectedInput.TreeHandle 
			local inpName = expectedInput.InputName
			tH:FillInInput(inpName, cmdParams)
			expectedInput = nil
			-- if tree is ready we should report it to BtEvaluator
			if(tH:CheckReady()) then 
				if(tH.Created == false) then
					tH.Created = true
					createTreeInBtEvaluator(tH)
					reportAssignedUnits(tH)
					Logger.loggedCall("Error", "BtController", 
					"reporting tree to BtEvaluator - last input filled in",
					BtEvaluator.reportTree, tH.InstanceId
					)
					tH:UpdateTreeStatus()
				else
					-- tree is ready, we can report just input
					reportInputToBtEval(tH, inpName)
				end	
			end
		else
			Logger.log("commands", "Received input command while not expecting!!!")
		end
		return true -- true is for deleting command and not sending it further according to documentation		
	end
	-- check for custom commands - Bt behaviour assignments
	if(WG.BtCommands[cmdID]) then
		-- setting up a behaviour tree :
		local treeHandle = instantiateTree(WG.BtCommands[cmdID].treeName, "Instance"..instanceIdCount , true)
		
		listenerBarItemClick({TreeHandle = treeHandle}, x, y, 1)
		
		-- click on first input:
		if(table.getn(treeHandle.InputButtons) >= 1) then -- there are inputs
			listenerInputButton(treeHandle.InputButtons[1])
		end
		return true
	end
	Logger.log("commands", "received unknown command: " , cmdID)
	return false
	-- This is the way to issue an input command command!
	--local ret = Spring.SetActiveCommand(Spring.GetCmdDescIndex(WG.InputCommands[ "BETS_POSITION" ]))
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

sanitizer:SanitizeWidget()
return Dependency.deferWidget(widget, Dependency.BtEvaluator, Dependency.BtCommands)