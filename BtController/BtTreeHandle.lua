local TreeHandle

local BehaviourTree = Utils.BehaviourTree
local Debug = Utils.Debug;
local Logger = Debug.Logger
local dump = Debug.dump

CONSTANTS = {
	rolesXOffset = 10,
	rolesYOffset = 30,
	buttonHeight = 22,
	singleButtonModifier = 10,
	labelToButtonYModifier = 5, -- chili feature/bug
	minRoleLabelWidth = 70,
	minRoleAssingWidth = 100,
	minUnitCountWidth = 50,
	inputGap = 30,
	SUCCESS_COLOR = {0.5,1,0.5,0.6},
	FAILURE_COLOR = {1,0.25,0.25,0.6},
	minInputButtonWidth = 150,
}



TreeHandle = {}
TreeHandle.unitsToTreesMap = {}
--[[
TreeHandle = {
			Name = "no_name", 
			TreeType = "no_tree_type", 
			InstanceId = "default", 
			Tree = "no_tree", 
			ChiliComponentsGeneral = {},
			ChiliComponentsRoles = {},
			ChiliComponentsInputs = {},
			Roles = {},
			RequireUnits = true,
			AssignedUnitsCount = 0,
			InputButtons = {},
			Ready = false,
			Created = false,
			Inputs = {},
			} 
--]]			
--[[-----------------------------------------------------------------------------------
--	Contains	Name = "name of tree"
--				TreeType = loaded tree into table
-- 				InstanceId = id of this given instance 
--				chiliComponents = array ofchili components corresponding to this tree
--				Roles = table indexed by roleName containing reference to 
--					chili components and other stuff: {assignButton = , unitCountButton =, roleIndex =, unitTypes  }
-- 				RequireUnits - should this tree be removed when it does not have any unit assigned?
--				AssignedUnits = table of records of a following shape: {name = unit ID, 	
--				InputButtons = List of chili buttons which are responsible for collecting
--				Ready = indicator if this tree is ready to be send to BtEvaluator
--				Created = indicator if BtEvalutor is told about this tree
--				Inputs =

-----------------------------------------------------------------------------------]]--

-- The following funtion creates string which summarize state of this tree. 
function TreeHandle:UpdateTreeStatus()
	local result
	if(self.Created) then
		result = "running"
	else
		result = "not running"
	end
	local soFarOk = true
	local missingInputs = ""
	for _,input in ipairs(self.Tree.inputs) do
		if(self.Inputs[input.name] == nil)then
			if(soFarOk) then
				soFarOk = false
				missingInputs = input.name
			else
				missingInputs = missingInputs .. ", ".. input.name
			end
		end
	end
	if(soFarOk == false) then
	result = result .. ", missing input: " .. missingInputs
	end
	self.ChiliComponentsGeneral[1]:SetCaption(self.TreeType .. " (" .. result .. ")") 
end

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

-- Function responsible for selecting units in given role.
function TreeHandle.selectUnitsInRolesListener(button, ...) 
	local unitsInThisRole = TreeHandle.unitsInTreeRole(button.TreeHandle.InstanceId, button.Role)
	Spring.SelectUnitArray(unitsInThisRole)
end

-- This method will set up and load in all chili components corresponding to 
-- roles in given tree. It returns maximal x-coordinate of components
function createChiliComponentsRoles(obj)
	local rolesEndX
	local roleInd = 0 
	local roleCount = #obj.Tree.roles
	
	for _,roleData in pairs(obj.Tree.roles) do
		local roleName = roleData.name
		local roleNameLabel = Chili.Label:New{
			x = CONSTANTS.rolesXOffset ,
			y = CONSTANTS.rolesYOffset + CONSTANTS.labelToButtonYModifier  + ( CONSTANTS.buttonHeight ) * roleInd,
			height = (roleCount == 1 and CONSTANTS.buttonHeight + CONSTANTS.singleButtonModifier or CONSTANTS.buttonHeight),
			width = '20%',
			minWidth = CONSTANTS.minRoleLabelWidth,
			caption = roleName,
			skinName = "DarkGlass",
			focusColor = {0.5,0.5,0.5,0.5},
			tooltip = "Role name",
		}
		table.insert(obj.ChiliComponentsRoles, roleNameLabel)
		
		local roleAssignmentButton = Chili.Button:New{
			x = CONSTANTS.rolesXOffset + roleNameLabel.width + 50,
			y = CONSTANTS.rolesYOffset + CONSTANTS.buttonHeight * roleInd,
			height = roleCount == 1 and CONSTANTS.buttonHeight + CONSTANTS.singleButtonModifier or CONSTANTS.buttonHeight,
			width = '10%',
			minWidth = CONSTANTS.minRoleAssingWidth,
			caption = "Assign",
			OnClick = {obj.AssignUnitListener}, 
			skinName = "DarkGlass",
			focusColor = {0.5,0.5,0.5,0.5},
			TreeHandle = obj,
			Role = roleName,
			roleIndex = roleInd,
			instanceId = obj.InstanceId,
			tooltip = "Assigns currently selected units to this role",
		}
		table.insert(obj.ChiliComponentsRoles, roleAssignmentButton)
		
		local unitCountButton = Chili.Button:New{
			x = roleAssignmentButton.x + roleAssignmentButton.width ,
			y = CONSTANTS.rolesYOffset + CONSTANTS.buttonHeight * roleInd,
			height = roleCount == 1 and CONSTANTS.buttonHeight + CONSTANTS.singleButtonModifier or CONSTANTS.buttonHeight,
			width = '10%',
			minWidth = CONSTANTS.minUnitCountWidth,
			caption = 0, 
			skinName = "DarkGlass",
			focusColor = {0.5,0.5,0.5,0.5},
			instanceId = obj.InstanceId,
			tooltip = "How many units are in tree currently, click selects them.",
			TreeHandle = obj,
			Role = roleName,
			OnClick = {TreeHandle.selectUnitsInRolesListener},
		}
		table.insert(obj.ChiliComponentsRoles, unitCountButton)
		
		rolesEndX = unitCountButton.x + unitCountButton.width 
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
			unitCountButton = unitCountButton,
			roleIndex = roleInd,
			unitTypes = roleUnitTypes
		}
		roleInd = roleInd +1
	end
	return rolesEndX
end

-- This method will set up and load in all chili components corresponding to 
-- inputs of given tree. It returns maximal x-coordinate of components.
function createChiliComponentsInput(obj, xOffSet)
	local inputXOffset = xOffSet + CONSTANTS.inputGap
	local inputYOffset =  CONSTANTS.rolesYOffset
	local inputInd = 0
	local inputCount = table.getn(obj.Tree.inputs)
	
	for _,input in pairs(obj.Tree.inputs) do
		local inputName = input.name
		local inputButton = Chili.Button:New{
			x = inputXOffset,
			y = inputYOffset + CONSTANTS.buttonHeight * inputInd,
			height = inputCount == 1 and CONSTANTS.buttonHeight +  CONSTANTS.singleButtonModifier or CONSTANTS.buttonHeight,
			width = '25%',
			minWidth = CONSTANTS.minInputButtonWidth,
			caption =" " .. inputName .. " (" .. WG.BtCommandsInputHumanNames[input.command].. ")",
			OnClick = {obj.InputButtonListener}, 
			skinName = "DarkGlass",
			focusColor = {0.5,0.5,0.5,0.5},
			TreeHandle = obj,
			InputName = inputName,
			CommandName = input.command,
			InstanceId = obj.InstanceId,
			backgroundColor = CONSTANTS.FAILURE_COLOR,
			tooltip = "Give required input (red = not given yet, green = given)",
		}
		inputInd = inputInd + 1
		table.insert(obj.ChiliComponentsInputs, inputButton )
		table.insert(obj.InputButtons, inputButton) 
	end
end

--[[ It is expected from obj that ti contains following records:
	AssignUnitListener
	InputButtonListener
--]]
function TreeHandle:New(obj)
	setmetatable(obj, self)
	self.__index = self
	obj.InstanceId = generateID()
	obj.Tree = BehaviourTree.load(obj.TreeType)
	
	obj.ChiliComponentsGeneral = {}
	obj.ChiliComponentsRoles = {}
	obj.ChiliComponentsInputs = {}
	obj.Roles = {}
	obj.InputButtons = {}
	obj.RequireUnits = true
	obj.AssignedUnitsCount = 0
	obj.Created = false
	obj.Inputs = {}
	
	local treeTypeLabel = Chili.Label:New{
		x = 7,
		y = 7,
		height = 30,
		width =  '95%',
		minWidth = 50,
		caption =  obj.TreeType .. " (initializing)",
		skinName = "DarkGlass",
		tooltip = "Name of tree type",
	}
	
	-- Order of these childs is sort of IMPORTANT as other entities needs to access children
	table.insert(obj.ChiliComponentsGeneral, treeTypeLabel)
	
	local roleInd = 0 
	local roleCount = #obj.Tree.roles
	local rolesEndX = createChiliComponentsRoles(obj)
	createChiliComponentsInput(obj, rolesEndX)
	return obj
end

-- Following three methods are shortcut for increasing and decreassing role counts.
function TreeHandle:DecreaseUnitCount(whichRole)
	Logger.log("roles", "decrease: ")
	local roleData = self.Roles[whichRole]
	-- this is the current role and tree
	local currentCount = tonumber(roleData.unitCountButton.caption)
	currentCount = currentCount - 1
	-- test for <0 ?
	roleData.unitCountButton:SetCaption(currentCount)
	self.AssignedUnitsCount = self.AssignedUnitsCount -1
end
function TreeHandle:IncreaseUnitCount(whichRole)	
	local roleData = self.Roles[whichRole]
	-- this is the current role and tree
	currentCount = tonumber(roleData.unitCountButton.caption)
	currentCount = currentCount + 1
	-- test for <0 ?
	roleData.unitCountButton:SetCaption(currentCount)
	self.AssignedUnitsCount = self.AssignedUnitsCount +1
end
function TreeHandle:SetUnitCount(whichRole, number)
	local roleData = self.Roles[whichRole]
	local previouslyAssigned = tonumber(roleData.unitCountButton.caption) 
	self.AssignedUnitsCount = self.AssignedUnitsCount  - previouslyAssigned
	roleData.unitCountButton:SetCaption(number)
	self.AssignedUnitsCount = self.AssignedUnitsCount + number
end
function TreeHandle:FillInInput(inputName, data)
	-- I should change color of input
	for _,inputButton in pairs(self.InputButtons) do
		if(inputButton.InputName == inputName) then
			inputButton.backgroundColor = CONSTANTS.SUCCESS_COLOR
			
			local transformedData = Logger.loggedCall("Error", "BtController", 
					"fill in input value",
					WG.BtCommandsTransformData, 
					data,
					inputButton.CommandName)
			self.Inputs[inputName] = transformedData
			inputButton:Invalidate()
			inputButton:RequestUpdate()	
		end
	end	
	self:CheckReady()
	self:UpdateTreeStatus()	
end


-- this will remove given unit from its current tree and adjust the gui componnets
function TreeHandle.removeUnitFromCurrentTree(unitId)	
	if(TreeHandle.unitsToTreesMap[unitId] == nil) then return end
	-- unit is assigned to some tree:
	-- decrease count of given tree:
	
	local treeHandle = TreeHandle.unitsToTreesMap[unitId].TreeHandle
	role = TreeHandle.unitsToTreesMap[unitId].Role
	treeHandle:DecreaseUnitCount(role)
	TreeHandle.unitsToTreesMap[unitId] = nil
	
	-- if the tree has no more units:
	if (treeHandle.AssignedUnitsCount < 1) and (treeHandle.RequireUnits) then
		-- remove this tree
		removeTreeBtController(treeTabPanel, treeHandle)
	end
end

function TreeHandle.unitsInTreeRole(instanceId,roleName)
	local unitsInThisTree = {}
	for unitId, unitEntry in pairs(TreeHandle.unitsToTreesMap) do
		if( (unitEntry.InstanceId == instanceId) and (unitEntry.Role == roleName)) then
			table.insert(unitsInThisTree, unitId)
		end
	end
	return unitsInThisTree
end

-- this will take note of assignment of a unit to given tree and adjust gui componnets
function TreeHandle.assignUnitToTree(unitId, treeHandle, roleName)
	if(TreeHandle.unitsToTreesMap[unitId] ~= nill) then
		-- unit is currently assigned elsewhere, need to remove it first
		TreeHandle.removeUnitFromCurrentTree(unitId)
	end
	TreeHandle.unitsToTreesMap[unitId] = {
		InstanceId = treeHandle.InstanceId, 
		Role = roleName,
		TreeHandle = treeHandle
		}
	treeHandle:IncreaseUnitCount(roleName)
end

-- This will return name id of all units in given tree
function TreeHandle.unitsInTree(instanceId)
	local unitsInThisTree = {}
	for unitId, unitEntry in pairs(TreeHandle.unitsToTreesMap) do
		if(unitEntry.InstanceId == instanceId) then
			table.insert(unitsInThisTree, unitId)
		end
	end
	return unitsInThisTree
end

-- This function reload tree again from file, but keeps user input if possible. 
function TreeHandle:ReloadTree()
	-- remember all units assigned in this tree
	local assignedUnits = {}
	for _,roleData in pairs(self.Tree.roles) do		
		local unitsInRole = TreeHandle.unitsInTreeRole(self.InstanceId, roleData.name)
		if( table.getn(unitsInRole) >= 1) then
			assignedUnits[roleData.name] = unitsInRole
		end
		Logger.log("roles", "reload tree, role name : ", roleData.name, " units in role: ",table.getn(unitsInRole) )
	end
	
	-- inputs:
	-- collect cmd corresponding to inputs:
	local oldInputsCmd = {}
	for _,inputSpec in pairs (self.Tree.inputs) do
		oldInputsCmd[inputSpec.name] = inputSpec.command
	end
	
	local oldInputs = self.Inputs	
	self.Inputs = {}
			
	-- getting a new tree:
	self.Tree = BehaviourTree.load(self.TreeType)
	
	-- reload UI:---------------------------------------------------------------------
	
	-- remove old components 
	self.ChiliComponentsRoles = {}
	self.ChiliComponentsInputs = {}
	-- add new components: roles
	local xOffSet = createChiliComponentsRoles(self)
	-- add new components: inputs
	createChiliComponentsInput(self, xOffSet)
	
	-- transfering user given data: 
	
	-- units assignment:
	for _,roleData in pairs(self.Tree.roles) do
		-- if the name is same, assign units in this role:
		if(assignedUnits[roleData.name] ~= nil) then
			for _,unitId in pairs(assignedUnits[roleData.name]) do
				TreeHandle.assignUnitToTree(unitId, self, roleData.name)
			end
		end
	end
	
	
	-- collect old inputs:
	for _, inputSpec in pairs (self.Tree.inputs) do
		local inputName = inputSpec.name
		if (oldInputsCmd[inputName] ~= nil) then		
			local givenInput = oldInputs[inputName]
			local oldCommand = oldInputsCmd[inputName]
			local newCommand = inputSpec.command
			-- if input was given and it has the same type (colecting command name) then fill the data in
			if (givenInput ~= nil) and (oldCommand == newCommand) then  
				newTreeHandle:FillInInput(inputName, oldInputs[inputName])
			end
		end 
	end
	
	self:UpdateTreeStatus()

end
return TreeHandle
