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
local treeControlWindow
local controllerLabel
local selectTreeButton
local treeTabPanel
local showTreeCheckbox
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
local unitsToTreesMap

-- If we are in state of expecting input we will make store this information here
local expectedInput 
--------------------------------------------------------------------------------
local spGetCmdDescIndex = Spring.GetCmdDescIndex
local spSetActiveCommand = Spring.SetActiveCommand
local spGetSelectedUnits = Spring.GetSelectedUnits

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





TreeHandle = {}
--[[
TreeHandle = {
			Name = "no_name", 
			TreeType = "no_tree_type", 
			InstanceId = "default", 
			Tree = "no_tree", 
			ChiliComponents = {},
			Roles = {},
			RequireUnits = true,
			AssignedUnitsCount = 0,
			InputButtons = {},
			Ready = false,
			Reported = false,
			Inputs = {}
			} 
--]]			
--[[-----------------------------------------------------------------------------------
--	Contains	Name = "name of tree"
--				TreeType = loaded tree into table
-- 				InstanceId = id of this given instance 
--				chiliComponents = array ofchili components corresponding to this tree
--				Roles = table indexed by roleName containing reference to 
--					chili components and other stuff: {assignButton = , unitCountLabel =, roleIndex =, unitTypes  }
-- 				RequireUnits - should this tree be removed when it does not have any unit assigned?
--				AssignedUnits = table of records of a following shape: {name = unit ID, 	
--				InputButtons = List of chili buttons which are responsible for collecting
--				Ready = indicator if this tree is ready to be send to BtEvaluator

-----------------------------------------------------------------------------------]]--
-- this function will check if all required inputs are given. 
function TreeHandle:CheckReady()
	local allOkSoFar = true
	for _,input in pairs(self.Tree.inputs) do
		if(self.Inputs[input.name] == nil) then
			allOkSoFar = false
		end
	end
	if(allOkSoFar == true) then
		self.Ready = true	
		return true
	else
		self.Ready = false
		return false
	end
end

function TreeHandle:New(obj)
	--obj = obj -- or TreeHandle
	setmetatable(obj, self)
	self.__index = self
	obj.InstanceId = GenerateID()
	obj.Tree = BehaviourTree.load(obj.TreeType)
	
	obj.ChiliComponents = {}
	obj.Roles = {}
	obj.InputButtons = {}
	obj.RequireUnits = true
	obj.AssignedUnitsCount = 0
	obj.Reported = false
	obj.Inputs = {}
	
	local treeTypeLabel = Chili.Label:New{
		x = 50,
		y = 7,
		height = 30,
		width =  200,
		minWidth = 50,
		caption =  obj.TreeType,
		skinName = "DarkGlass",
		--focusColor = {0.5,0.5,0.5,0.5},
	}
	-- Order of these childs is sort of IMPORTANT as other entities needs to access children
	table.insert(obj.ChiliComponents, treeTypeLabel)
	local resetTreeButton = Chili.Button:New{
		x = 150,
		y = 0,
		height = 30,
		width =  100,
		minWidth = 50,
		caption =  "Restart tree",
		OnClick = {restartTreeListener}, 
		TreeHandle = obj,
		skinName = "DarkGlass",
	}
	table.insert(obj.ChiliComponents, resetTreeButton)
	
	local roleInd = 0 
	local roleCount = #obj.Tree.roles
	
	local rolesXOffset = 10
	local rolesYOffset = 30
	local roleButtonWidth = 200
	for _,roleData in pairs(obj.Tree.roles) do
		local roleName = roleData.name
		local unitsCountLabel = Chili.Label:New{
			x = rolesXOffset + roleButtonWidth ,
			y = rolesYOffset + 5 + 22 * roleInd,
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
			x = rolesXOffset ,
			y = rolesYOffset + 22 * roleInd,
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
		for _,catName in pairs(roleData.categories) do
			local unitTypes = BtUtils.UnitCategories.getCategoryTypes(catName)		
			for _,unitType in pairs(unitTypes) do
				roleUnitTypes[unitType.name] = 1
			end
		end
		
		obj.Roles[roleName]={
				assignButton = roleAssignmentButton,
				unitCountLabel = unitsCountLabel,
				roleIndex = roleInd,
				unitTypes = roleUnitTypes
			}
		roleInd = roleInd +1
	end
	
	local inputXOffset = 300
	local inputYOffset = 50
	local inputInd = 0 
	

	local notGivenColor = {0.8,0.1,0.1,1}
	for _,input in pairs(obj.Tree.inputs) do
		local inputName = input.name
		local inputButton = Chili.Button:New{
			x = inputXOffset,
			y = rolesYOffset + 22 * inputInd,
			height = inputCount == 1 and 30 or 20,
			width = '25%',
			minWidth = 150,
			caption = inputName,
			OnClick = { listenerInputButton}, 
			skinName = "DarkGlass",
			focusColor = {0.5,0.5,0.5,0.5},
			TreeHandle = obj,
			InputName = inputName,
			CommandName = input.command,
			InstanceId = obj.InstanceId,
			backgroundColor = notGivenColor,
		}
		inputInd = inputInd + 1
		table.insert(obj.ChiliComponents, inputButton )
		table.insert(obj.InputButtons, inputButton) 
	end
	-- check if this tree is ready from start, probably not, maybe we want to finalize it first:
	--TreeHandle.CheckReady(obj)
	return obj
end

-- Following three methods are shortcut for increasing and decreassing role counts.
function TreeHandle:DecreaseUnitCount(whichRole)
	local roleData = self.Roles[whichRole]
	-- this is the current role and tree
	local currentCount = tonumber(roleData.unitCountLabel.caption)
	currentCount = currentCount - 1
	-- test for <0 ?
	roleData.unitCountLabel:SetCaption(currentCount)
	self.AssignedUnitsCount = self.AssignedUnitsCount -1
end
function TreeHandle:IncreaseUnitCount(whichRole)	
	local roleData = self.Roles[whichRole]
	-- this is the current role and tree
	currentCount = tonumber(roleData.unitCountLabel.caption)
	currentCount = currentCount + 1
	-- test for <0 ?
	roleData.unitCountLabel:SetCaption(currentCount)
	self.AssignedUnitsCount = self.AssignedUnitsCount +1
end
function TreeHandle:SetUnitCount(whichRole, number)
	local roleData = self.Roles[whichRole]
	local previouslyAssigned = tonumber(roleData.unitCountLabel.caption) 
	self.AssignedUnitsCount = self.AssignedUnitsCount  - previouslyAssigned
	roleData.unitCountLabel:SetCaption(number)
	self.AssignedUnitsCount = self.AssignedUnitsCount + number
end
function TreeHandle:FillInInput(inputName, data)
	-- I should change color of input
	for _,inputButton in pairs(self.InputButtons) do
		if(inputButton.InputName == inputName) then
			inputButton.backgroundColor = {0.1,0.6,0.1,1}
			inputButton:Invalidate()
			inputButton:RequestUpdate()
		end
	end
	---!!! here put storing input in proper place
	--[[for _,input in pairs(self.Tree.inputs) do
		if(input.name == inputName) then
			input["value"] = data
		end
	end]]--
	self.Inputs[inputName] = data
	self:CheckReady() 
end

-----TREE HANDLE LISTENERS------------------------------------------------------
--[[

function TreeHandle:InputButtonListener(x,y,button, ...)


	if(not WG.InputCommands or not WG.BtCommands) then
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
	--
	local ret = spSetActiveCommand(  spGetCmdDescIndex(WG.InputCommands[ expectedInput.CommandName ]) ) --  spGetCmdDescIndex( WG.InputCommands[ expectedInput.CommandName ] ))
	if(ret == false ) then 
		Logger.log("commands", "Unable to set command active: " , expectedInput.CommandName) 
	end
end
--]]
--------------------------------------------------------------------------------

function SendStringToBtEvaluator(message)
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), "BETS " .. message)
end


function removeTreeBtController(tabs,treeHandle)
	-- remove the bar item
	local tabBarChildIndex = 1
	-- get tabBar
	local tabBar = tabs.children[tabBarChildIndex]
	
	if treeHandle.Name == tabBar.selected_obj.caption then
		Logger.loggedCall("Call", "BtController", "hiding BtController which is showing removed tree", BtCreator.hide)
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
	
	if( treeHandle.Reported) then
		-- remove send message to BtEvaluator
		Logger.loggedCall("Errors", "BtController", "removing tree fromBbtEvaluator", 
			BtEvaluator.removeTree, treeHandle.InstanceId)
	end
end


function showErrorWindow(errorDecription)
	errorLabel.caption = errorDecription
	errorWindow:Show()
end


function logUnitsToTreesMap(category)
	Logger.log(category, " ***** unitsToTreesMapLog: *****" )
	for unitId, unitData in pairs(unitsToTreesMap) do
		Logger.log(category, "unitId ", unitId, " instId ", unitData.InstanceId, " label inst: ", unitData.TreeHandle.Roles[unitData.Role].unitCountLabel.instanceId, " treeHandleId: ", unitData.TreeHandle.InstanceId, " button insId: ", unitData.TreeHandle.Roles[unitData.Role].assignButton.instanceId, " treeHandleName ", unitData.TreeHandle.Name )
	end
	Logger.log(category, "***** end *****" )
end

-- This will return name id of all units in given tree
local function unitsInTree(instanceId)
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
			local name = UnitDefs[unitDefId].name
			for _,roleData in pairs(treeHandle.Roles) do
				if (roleData.unitTypes[name] ~= nil) then
					unitAssigned = true
					assignUnitToTree(unitId, treeHandle, roleData.assignButton.caption)
				end
			end	
		else
			Logger.log("roles", "could not find UnitDefs entry for: ",  unitId )
		end
		if(unitAssigned == false) then
			assignUnitToTree(unitId, treeHandle, treeHandle.Tree.defaultRole)
		end
	end
	--[[
	for name,roleData in pairs(treeHandle.Roles) do
	-- now I need to share information with the BtEvaluator
		local unitsInThisRole = unitsInTreeRole(treeHandle.InstanceId, name)
		Spring.SelectUnitArray(unitsInThisRole)
		Logger.loggedCall("Errors", "BtController", "reporting automatic role assignment to BtEvaluator", 
			BtEvaluator.assignUnits, unitsInThisRole, treeHandle.InstanceId, roleData.roleIndex)
	end
	--]]
end



function reportTreeToBtEvaluator(treeHandle) 
		-- create the tree immediately when the tab is created
		--- CHANGE this to proper tree reporting
	Logger.log("commands", "reporting tree")
	Logger.loggedCall("Errors", "BtController", "instantiating new tree in BtEvaluator", 
		BtEvaluator.createTree, treeHandle.InstanceId, treeHandle.Tree, treeHandle.Inputs)
end

function reportAssignedUnits(treeHandle)
	-- change this to proper tree report
	local originallySelectedUnits = spGetSelectedUnits()
	for name,roleData in pairs(treeHandle.Roles) do
		-- now I need to share information with the BtEvaluator
		local unitsInThisRole = unitsInTreeRole(treeHandle.InstanceId, name)
		Spring.SelectUnitArray(unitsInThisRole)
		Logger.loggedCall("Errors", "BtController", "reporting assigned units, reporting role: ".. name, 
			BtEvaluator.assignUnits, unitsInThisRole, treeHandle.InstanceId, roleData.roleIndex)
	end
	Spring.SelectUnitArray(originallySelectedUnits)
end


function reportTreeAndUnitsBtEval(treeHandle)
--- change this
	reportTreeToBtEvaluator(treeHandle)
	reportAssignedUnits(treeHandle)
end

function reportInputToBtEval(treeHandle, inputName)
	Logger.loggedCall("Errors", "BtController", "reporting changed input", 
		BtEvaluator.setInput, treeHandle.InstanceId , inputName, treeHandle.Inputs[inputName]) 
end 
-- this will remove given unit from its current tree and adjust the gui componnets
function removeUnitFromCurrentTree(unitId)	
	if(unitsToTreesMap[unitId] == nil) then return end
	-- unit is assigned to some tree:
	-- decrease count of given tree:
	
	local treeHandle = unitsToTreesMap[unitId].TreeHandle
	role = unitsToTreesMap[unitId].Role
	treeHandle:DecreaseUnitCount(role)
	unitsToTreesMap[unitId] = nil
	
	-- if the tree has no more units:
	if (treeHandle.AssignedUnitsCount < 1) and (treeHandle.RequireUnits) then
		-- remove this tree
		removeTreeBtController(treeTabPanel, treeHandle)
	end
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
	-- it will create the instance,
	-- create new tree tab
	-- (removed) notify BtEvaluator
-- it return the new treeHandle
function instantiateTree(treeType, instanceName, requireUnits)
	
	local newTreeHandle = TreeHandle:New{
		Name = instanceName,
		TreeType = treeType,
		ReportTree = reportTreeToBtEvaluator,
		ReportUnits = reportAssignedUnits,
		ReportInput = reportInputToBtEval,
		-- give here proper functions
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
		newTreeHandle.ReportTree(newTreeHandle)
		newTreeHandle.Reported = true
		newTreeHandle.ReportUnits(newTreeHandle)
	end
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
			Logger.loggedCall("Error", "BtController", 
				"reporting tree to BtEvaluator",
				BtEvaluator.reportTree, self.TreeHandle.InstanceId
			)
			Logger.loggedCall("Error", "BtController", 
				"making BtCreator show selected tree",
				BtCreator.show, self.TreeHandle.TreeType )
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
function listenerAssignUnitsButton(self,x,y, button, ...)
	-- self = chili:button
	if(button == 1 )then -- left mouse button
		
		-- deselect units in current role
		for unitId,treeAndRole in pairs(unitsToTreesMap) do	
			if(treeAndRole.InstanceId == self.TreeHandle.InstanceId) and (treeAndRole.Role == self.Role) then
				removeUnitFromCurrentTree(unitId)
			end
		end
		-- make note of assigment in our notebook (this should be possible moved somewhere else:)
		local selectedUnits = spGetSelectedUnits()
		for _,Id in pairs(selectedUnits) do
			assignUnitToTree(Id, self.TreeHandle, self.Role)
		end
		if(self.TreeHandle:CheckReady() ) then
			Logger.loggedCall("Errors", "BtController", "assigning units to tree", 
				BtEvaluator.assignUnits, selectedUnits, self.TreeHandle.InstanceId, self.roleIndex)
		end
	end
	if(button == 3) then 
		-- right-click: I should select given units:
		local unitsInThisRole = unitsInTreeRole(self.TreeHandle.InstanceId, self.Role)
		Spring.SelectUnitArray(unitsInThisRole)
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
	--
	local ret = spSetActiveCommand(  spGetCmdDescIndex(WG.InputCommands[ expectedInput.CommandName ]) ) --  spGetCmdDescIndex( WG.InputCommands[ expectedInput.CommandName ] ))
	if(ret == false ) then 
		Logger.log("commands", "Unable to set command active: " , expectedInput.CommandName) 
	end
end

-- Listener for closing error window.
function listenerErrorOk(self)
	errorWindow:Hide()
end


function restartTreeListener(self, x,y, button)
	if(button == 1) then
		if(self.TreeHandle:CheckReady()) then
			-- restart it only if it is ready
			Logger.loggedCall("Errors", "BtController", "reseting tree, reset button", 
			BtEvaluator.resetTree, self.TreeHandle.InstanceId)
		end
	end 
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
			defaultHeight = tabBar.minItemHeight,
			tooltip = "Add new instance of a tree. ",
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

	setUpTreeSelectionTab()
	
	local newTab = {name = "+", tooltip = "Add new instance of a tree. ", children = {treeSelectionPanel} }
	
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
		-- listenerClickOnSelectedTreeDoneButton(self, treeSelectionDoneButton.x, treeSelectionDoneButton.y, 1)
	end
	
	----[[
	if(not WG.InputCommands or not WG.BtCommands) then
		-- TODO Do a proper initialization, only once. 
		WG.fillCustomCommandIDs()
	end
	--]]
	
	Dependency.fill(Dependency.BtController)
end

--//////////////////////////////////////////////////////////////////////////////
-- Callins


function widget:IsAbove(x,y)
	-- TODO test whether x,y are above treeControlPanel, currently it would also show btcreators tooltips. 
		return true
end

function widget:GetTooltip(x, y)
	local component = Screen0:HitTest(x, Screen0.height - y)
	if (component) then
		return component.tooltip
	end
end

function widget:UnitDestroyed(unitId)
	if(unitsToTreesMap[unitId] ~= nil) then
		removeUnitFromCurrentTree(unitId)
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
		Logger.log("commands", "received input command: " , cmdID)

		if(expectedInput ~= nil) then
			-- I should insert given input to tree:
			local tH = expectedInput.TreeHandle 
			local inpName = expectedInput.InputName
			tH:FillInInput(inpName, cmdParams)
			expectedInput = nil
			if(tH:CheckReady()) then 
				if(tH.Reported == false) then
					tH.Reported = true
					tH.ReportTree(tH)
					tH.ReportUnits(tH)
				else
					-- tree is ready, we can report just input
					tH.ReportInput(tH, inpName)
				end
			end
		else
			Logger.log("commands", "Received input command while not expecting!!!")
		end
		return true -- true is for deleting command and not sending it further according to documentation		
	end
	-- check for custom commands - Bt behaviour assignments
	if(WG.BtCommands[cmdID]) then
		Logger.log("commands", "received tree command: " , cmdID)
		-- setting up a behaviour tree :
		local treeHandle = instantiateTree(WG.BtCommands[cmdID].treeName, "Instance"..instanceIdCount , true)
		
		listenerBarItemClick({TreeHandle = treeHandle}, x, y, 1)
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

Dependency.deferWidget(widget, Dependency.BtEvaluator, Dependency.BtCommands)