local TreeHandle

local Chili = Utils.Chili
local BehaviourTree = Utils.BehaviourTree
local Debug = Utils.Debug;
local Logger = Debug.Logger
local dump = Debug.dump
local sanitizer = Utils.Sanitizer.forCurrentWidget()

local variableCommandName = "Variable"

--- Instances of TreeHandle keeps record of units assinged to roles and given 
-- input parameters of given tree instance. Record of all units assingment is kept
-- in TreeHandle table itself (singleton). TreeHandle instance contains the following records:
--			name = instance name. 
--			treeType = tree type name. 
--			instanceId = instance identifier. 
--			Tree = tree loaded by BehaviourTree. 
--			ChiliComponentsGeneral = General Chili components (list): Tree type lable, instance name, status and remove button, unit lock.
--			ChiliComponentsRoles = Chili components regarding roles: Role name label, assign button and unit count button.  
--			ChiliComponentsInputs = Chili components regarding input parameters: Buttons for selecting input.
--			Roles = Unist assigned to given roles are kept here. 
--			RequireUnits = True if tree should be removed if he is not controlling any unit. 
--			AssignedUnitsCount = How many units are assigned under control of this tree.
--			InputButtons = List of input buttons.
--			Ready = Is this tree ready for being evaluated in BtEvaluator. 
--			Created = Was instance corresponding to this tree handle created in BtEvaluator.
--			Inputs = Data provided by user for input parameters.
--			unitsLocked = Are units currently locked?
TreeHandle = {}
--- This table is used to keep record of units assignments. It is indexed by unitId
-- and contains structures:
-- {instanceId = "", Role = "", TreeHandle = treehandle} 
TreeHandle.unitsToTreesMap = {}
--[[
TreeHandle = {
			name = "no_name", 
			treeType = "no_tree_type", 
			instanceId = "default", 
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
			unitsLocked,
			} 
--]]			
--[[-----------------------------------------------------------------------------------
--	Contains	name = "name of tree"
--				treeType = loaded tree into table
-- 				instanceId = id of this given instance 
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


--- The following funtion creates string which summarize state of this tree. 
function TreeHandle:UpdateTreeStatus()
	if self.error then -- there is error and it should remain in this state
		self.treeStatus:SetCaption("Error: " .. self.error)
		return 
	end
	-- check invalid inputs: 
	for _,input in ipairs(self.Tree.inputs) do
		if(input.command == variableCommandName) then
			-- this input is not supported
			self:SwitchToErrorState("Input " .. input.name .. " is of type Variable, use this tree only as subtree.")
			return
		end
	end


	local result
	if(self.Created) then
		result = "running"
	else
		result = "not running"
	end
	

	
	local soFarOk = true
	local missingInputs = ""
	for _,input in ipairs(self.Tree.inputs) do
		if(input.command == variableCommandName) then
			-- this input is not supported
			
		end
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
	self.treeStatus:SetCaption(result) 
end

--- this function will check if all required inputs are given. 
function TreeHandle:CheckReady()
	local allOkSoFar = true
	if self.error then
		allOkSoFar = false
	end
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

--- Listener for select units in given role.
function TreeHandle.selectUnitsInRolesListener(button, ...) 
	local unitsInThisRole = TreeHandle.unitsInTreeRole(button.TreeHandle.instanceId, button.Role)
	Spring.SelectUnitArray(unitsInThisRole)
end

--- Disposes all Chili components corresponding to given TreeHandle. 
function TreeHandle:DisposeAllChiliComponents()
	self:DisposeGeneralComponents()
	self:DisposeRolesComponents()
	self:DisposeInputComponents()
end
--- Disposes Chili components corresponding to tree name and state of given TreeHandle. 
function TreeHandle:DisposeGeneralComponents()
	for _,chiliComponent in pairs(self.ChiliComponentsGeneral) do
		chiliComponent:Dispose()
	end
	self.ChiliComponentsGeneral = {}
end
--- Disposes Chili components corresponding to roles of given TreeHandle. 
function TreeHandle:DisposeRolesComponents()
	for _,chiliComponent in pairs(self.ChiliComponentsRoles) do
		chiliComponent:Dispose()
	end
	self.ChiliComponentsRoles = {}
end
--- Disposes Chili components corresponding to input parameteres of given TreeHandle. 
function TreeHandle:DisposeInputComponents()
	for _,chiliComponent in pairs(self.ChiliComponentsInputs) do
		chiliComponent:Dispose()
	end
	self.ChiliComponentsInputs = {}
end

--- This function removes all GUI components and shows just error message.
-- And releases all units. It is called when an error was encountered 
-- (wrong tree file format, unreachable or variable input.)
-- @tparam String message Message descripting occurred error. 
function TreeHandle:SwitchToErrorState(message)
	self.error = message
	 -- release units
	TreeHandle.removeUnitsFromTree(self.instanceId)
	self:DisposeRolesComponents()
	
	-- remove input buttons:
	self:DisposeInputComponents()

	--[[if self.Created then
		
	end]]

	self:UpdateTreeStatus()
	self.treeStatus.parent:RequestUpdate()
end

--- This method will set up and load in all chili components corresponding to 
-- roles in given tree. Created Chili components will be added to childs of given
-- parent object. 
-- Function returns maximal x-coordinate these components are using.
-- @param obj Chili parent component. 
-- @param xOffSet Starting offset.
-- @param xOffSet Starting offset.
-- @return Maximal x-coordinate used. 
local function createChiliComponentsRoles(obj,xOffSet,yOffSet)
	local rolesEndX
	local roleInd = 0 
	local roleCount = #obj.Tree.roles
	
	for _,roleData in pairs(obj.Tree.roles) do
		local roleName = roleData.name
		local roleNameLabel = Chili.Label:New{
			x = xOffSet ,
			y = yOffSet + CONSTANTS.labelToButtonYModifier  + ( CONSTANTS.buttonHeight ) * roleInd,
			height = (roleCount == 1 and CONSTANTS.buttonHeight + CONSTANTS.singleButtonModifier or CONSTANTS.buttonHeight),
			width = 100,
			minWidth = CONSTANTS.minRoleLabelWidth,
			caption = roleName,
			skinName = "DarkGlass",
			focusColor = {0.5,0.5,0.5,0.5},
			tooltip = "Role name",
		}
		table.insert(obj.ChiliComponentsRoles, roleNameLabel)
		
		local roleAssignmentButton = Chili.Button:New{
			x = roleNameLabel.x + roleNameLabel.width + CONSTANTS.roleGap,
			y = yOffSet  + ( CONSTANTS.buttonHeight ) * roleInd,
			height = roleCount == 1 and CONSTANTS.buttonHeight + CONSTANTS.singleButtonModifier or CONSTANTS.buttonHeight,
			width = 50,
			minWidth = CONSTANTS.minRoleAssingWidth,
			caption = "Assign",
			OnClick = {obj.AssignUnitListener}, 
			skinName = "DarkGlass",
			focusColor = {1.0,0.5,0.0,0.5},
			TreeHandle = obj,
			Role = roleName,
			roleIndex = roleInd,
			instanceId = obj.instanceId,
			tooltip = "Assigns currently selected units to this role",
		}
		table.insert(obj.ChiliComponentsRoles, roleAssignmentButton)
		
		local unitCountButton = Chili.Button:New{
			x = roleAssignmentButton.x + roleAssignmentButton.width ,
			y = yOffSet  + ( CONSTANTS.buttonHeight ) * roleInd,
			height = roleCount == 1 and CONSTANTS.buttonHeight + CONSTANTS.singleButtonModifier or CONSTANTS.buttonHeight,
			width = 50,
			minWidth = CONSTANTS.minUnitCountWidth,
			caption = 0, 
			skinName = "DarkGlass",
			focusColor = {1.0,0.5,0.0,0.5},
			instanceId = obj.instanceId,
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
			if unitTypes then
				for _,unitType in pairs(unitTypes) do
					roleUnitTypes[unitType.name] = 1
				end
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

--- This method will set up and load in all chili components corresponding to 
-- inputs of given tree. They are added as childs in provided parent object.
-- It returns maximal x-coordinate used up by components.
-- @param obj Chili parent component. 
-- @param xOffSet Starting offset.
-- @param xOffSet Starting offset.
-- @return Maximal x-coordinate used. 
local function createChiliComponentsInput(obj, xOffSet, yOffSet)
	local inputXOffset = xOffSet 
	local inputYOffset = yOffSet
	local inputInd = 0
	local inputCount = table.getn(obj.Tree.inputs)
	
	for _,input in pairs(obj.Tree.inputs) do
		local inputName = input.name
		local command = input.command
		Logger.log("commands", "tree handle: " .. dump(BtCommands.commandNameToHumanName))
		local inputButton = Chili.Button:New{
				x = inputXOffset,
				y = inputYOffset + CONSTANTS.buttonHeight * inputInd,
				height = inputCount == 1 and CONSTANTS.buttonHeight +  CONSTANTS.singleButtonModifier or CONSTANTS.buttonHeight,
				width = 180,
				minWidth = CONSTANTS.minInputButtonWidth,
				caption =" " .. inputName .. " (" .. (BtCommands.commandNameToHumanName[command]or"N/A").. ")",
				OnClick = {obj.InputButtonListener}, 
				skinName = "DarkGlass",
				focusColor = {0.5,0.5,0.5,0.5},
				TreeHandle = obj,
				InputName = inputName,
				CommandName = command,
				instanceId = obj.instanceId,
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
	lockImageListener
--]]
--- Constructor of Treehandle instances. Provided object is expected to contain
-- name (String, instance name), treeType (String), RequireUnits (Boolean) and  
-- following listeners: AssignUnitListener, InputButtonListener, lockImageListener 
-- which will be attached on corresponding buttons. 
-- Required Chili components are created and stored in ChiliComponentsGeneral, 
-- ChiliComponentsRoles and ChiliComponentsInputs lists. Actual connection of these
-- components ancestors needs to be done outside of this constructor. 
-- If tree could not be created, nil value is returned. 
-- Tree is not check if it is able to run or reported to BtEvaluator. 
-- @param obj Proto tree handle containing treeType, name, RequireUnits, AssignUnitListener, InputButtonListener and  lockImageListener.
function TreeHandle:New(obj)
	setmetatable(obj, self)
	self.__index = self
	obj.instanceId = generateID()
	obj.ChiliComponentsGeneral = {}
	obj.ChiliComponentsRoles = {}
	obj.ChiliComponentsInputs = {}
	obj.Roles = {}
	obj.InputButtons = {}
	obj.AssignedUnitsCount = 0
	obj.Created = false
	obj.Inputs = {}
	
	local treeTypeLabel = Chili.Label:New{
		x = 7,
		y = 7,
		height = 30,
		width =  100,
		minWidth = 50,
		caption =  obj.treeType,
		skinName = "DarkGlass",
		tooltip = "Name of tree type",
		OnMouseOver = { sanitizer:AsHandler( 
			function(self)
				if(BtCreator)then
					self.font.color = {1,0.5,0,1}
				end
			end
		) },
		OnMouseOut = { sanitizer:AsHandler( 
			function(self)
				self.font.color = {1,1,1,1}
			end
		) },
		OnMouseDown = { function(self) return self end },
		OnMouseUp = { sanitizer:AsHandler( 
			function(self)
				if(BtCreator)then
					BtCreator.showTree(obj.treeType)
				end
			end
		) },
	}

	
	table.insert(obj.ChiliComponentsGeneral, treeTypeLabel)
	
	local deletionButton = Chili.Button:New{
		parent = nodeWindow,
		x = 7,
		y = 28,
		caption = 'x',
		width = 20,
		tooltip = "Closes this instance.",
		backgroundColor = {1,0.1,0,1},
		OnClick = { sanitizer:AsHandler(
			function(self)
				if(obj.OnDeleteClick)then
					obj.OnDeleteClick()
				end
			end
		) },
	}
	table.insert(obj.ChiliComponentsGeneral, deletionButton)
	
	local treeStatusLabel = Chili.Label:New{
		x = 32,
		y = 30,
		maxWidth = 370,
		autosize = true,
		minWidth = 50,
		caption =  "initialized",
		skinName = "DarkGlass",
		tooltip = "Current state of the tree",
	}
	table.insert(obj.ChiliComponentsGeneral, treeStatusLabel)
	obj.treeStatus = treeStatusLabel
	
	local lockImage = Chili.Image:New{
		x = 420,
		y = 5,
		width = 50,
		height = 50,
		file = CONSTANTS.unlockedIconPath,
		skinName = "DarkGlass",
		tooltip = "Are units assigned to this tree selectable",
		OnClick = {obj.lockImageListener},
	}
	lockImage.TreeHandle = obj
	obj.unitsLocked = false
	table.insert(obj.ChiliComponentsGeneral, lockImage)
	
	local tree, treeMSG = BehaviourTree.load(obj.treeType)
	obj.Tree = tree
	
	if(not obj.Tree) then
		-- tree was not loaded
		-- treeHandle not ready yet - instead create an error dialog in BtController
		--TreeHandle.SwitchToErrorState(obj, treeMSG) 
		return nil
	end
	
	-- Order of these childs is sort of IMPORTANT as other entities needs to access children
	
	local roleInd = 0 
	local roleCount = #obj.Tree.roles
	local rolesEndX = createChiliComponentsRoles(obj,CONSTANTS.rolesXOffset,CONSTANTS.rolesYOffset )
	
	local inputOffSetX = rolesEndX + CONSTANTS.inputGap
	local inputOffSetY = CONSTANTS.rolesYOffset
	
	createChiliComponentsInput(obj, rolesEndX, inputOffSetY)
	return obj
end

---Method for decreasing unit count in given role by one. 
-- This function does not change the actual unit assignment records.
-- @tparam String whichRole Name of role.
function TreeHandle:DecreaseUnitCount(whichRole)
	local roleData = self.Roles[whichRole]
	-- this is the current role and tree
	local currentCount = tonumber(roleData.unitCountButton.caption)
	currentCount = currentCount - 1
	-- test for <0 ?
	roleData.unitCountButton:SetCaption(currentCount)
	self.AssignedUnitsCount = self.AssignedUnitsCount -1
end
---Method for increasing unit count in given role by one.
-- This function does not change the actual unit assignment records.
-- @tparam String whichRole Name of role. 
function TreeHandle:IncreaseUnitCount(whichRole)	
	local roleData = self.Roles[whichRole]
	-- this is the current role and tree
	currentCount = tonumber(roleData.unitCountButton.caption)
	currentCount = currentCount + 1
	-- test for <0 ?
	roleData.unitCountButton:SetCaption(currentCount)
	self.AssignedUnitsCount = self.AssignedUnitsCount +1
end
---Method for setting unit count of given role to given number.
-- This function does not change the actual unit assignment records.
-- @tparam String whichRole Name of role.
-- @param number New unit count.  
function TreeHandle:SetUnitCount(whichRole, number)
	local roleData = self.Roles[whichRole]
	local previouslyAssigned = tonumber(roleData.unitCountButton.caption) 
	self.AssignedUnitsCount = self.AssignedUnitsCount  - previouslyAssigned
	roleData.unitCountButton:SetCaption(number)
	self.AssignedUnitsCount = self.AssignedUnitsCount + number
end

--- Sets input parameter to be given and records data to field TreeHandle:Inputs.
-- Changes appearance of the button and cheks if tree is ready and updates tree status.  
-- @tparam String inputName Name of inpu tto b given.
-- @param data Specified input.
function TreeHandle:FillInInput(inputName, data)
	-- I should change color of input
	for _,inputButton in pairs(self.InputButtons) do
		if(inputButton.InputName == inputName) then
			inputButton.backgroundColor = CONSTANTS.SUCCESS_COLOR
			self.Inputs[inputName] = data
			inputButton:Invalidate()
			inputButton:RequestUpdate()	
		end
	end	
	self:CheckReady()
	self:UpdateTreeStatus()	
end

--- this will unassign (in TreeHandle table record) all units from given tree 
-- and adjust gui componnets
-- @param instanceId Instance ID. 
function TreeHandle.removeUnitsFromTree(instanceId)
	for unitId, unitData in pairs(TreeHandle.unitsToTreesMap) do
		if(unitData.instanceId == instanceId) then
			unitData.TreeHandle:DecreaseUnitCount(unitData.Role)
			TreeHandle.unitsToTreesMap[unitId] = nil
		end
	end
end

--- Removes given unit (assignment) from its current tree and adjust
-- gui components of that tree.
-- @param unitId In-game ID the unit.  
function TreeHandle.removeUnitFromCurrentTree(unitId)	
	if(TreeHandle.unitsToTreesMap[unitId] == nil) then return end
	-- unit is assigned to some tree:
	-- decrease count of given tree:
	
	local treeHandle = TreeHandle.unitsToTreesMap[unitId].TreeHandle
	role = TreeHandle.unitsToTreesMap[unitId].Role
	treeHandle:DecreaseUnitCount(role)
	TreeHandle.unitsToTreesMap[unitId] = nil
	return treeHandle
end

--- Returns all units that are assigned to given role in given tree according to 
-- record in TreeHandle table.
-- @param instanceId Instace identification.
-- @tparam String roleName Name of corresponding role. 
-- @return Array of unit IDs. 
function TreeHandle.unitsInTreeRole(instanceId,roleName)
	local unitsInThisTree = {}
	for unitId, unitEntry in pairs(TreeHandle.unitsToTreesMap) do
		if( (unitEntry.instanceId == instanceId) and (unitEntry.Role == roleName)) then
			table.insert(unitsInThisTree, unitId)
		end
	end
	return unitsInThisTree
end

---  Takes note of assignment of a unit to given tree and adjust gui componnets.
-- @param unitId ID of unit. 
-- @tparam TreeHandle treeHandle Tree handle to which units need to be assigned.
-- @tparam String roleName Name of role into which unit is assigned. 
function TreeHandle.assignUnitToTree(unitId, treeHandle, roleName)
	if(TreeHandle.unitsToTreesMap[unitId] ~= nil) then
		-- unit is currently assigned elsewhere, need to remove it first
		TreeHandle.removeUnitFromCurrentTree(unitId)
	end
	TreeHandle.unitsToTreesMap[unitId] = {
		instanceId = treeHandle.instanceId, 
		Role = roleName,
		TreeHandle = treeHandle
		}
	treeHandle:IncreaseUnitCount(roleName)
end

--- This will return name ID of all units in given tree.
-- @param instanceId Instance identifier. 
function TreeHandle.unitsInTree(instanceId)
	local unitsInThisTree = {}
	for unitId, unitEntry in pairs(TreeHandle.unitsToTreesMap) do
		if(unitEntry.instanceId == instanceId) then
			table.insert(unitsInThisTree, unitId)
		end
	end
	return unitsInThisTree
end

--- This function reload tree again from file, but keeps user input if possible.
-- Assigned units are kept if role has the same name. Input values are kept if
-- input name and type is preserved.  
function TreeHandle:ReloadTree()
	self.error = nil -- remove any previous error
	-- remember all units assigned in this tree
	local assignedUnits = {}
	for _,roleData in pairs(self.Tree.roles) do		
		local unitsInRole = TreeHandle.unitsInTreeRole(self.instanceId, roleData.name)
		if( table.getn(unitsInRole) > 0) then
			assignedUnits[roleData.name] = unitsInRole
		end
	end
	-- free all units
	 TreeHandle.removeUnitsFromTree(self.instanceId)
	
	-- inputs:
	-- collect cmd corresponding to inputs:
	local oldInputsCmd = {}
	for _,inputSpec in pairs (self.Tree.inputs) do
		oldInputsCmd[inputSpec.name] = inputSpec.command
	end
	
	local oldInputs = self.Inputs	
	
	self.Inputs = {}
			
	-- getting a new tree:
	self.Tree = BehaviourTree.load(self.treeType)
	-- reload UI:---------------------------------------------------------------
	
	-- remove old components 
	-- TD: USE DISPOSE:
	self:DisposeRolesComponents()
	self:DisposeInputComponents()
	-- add new components: roles
	local xOffSet = createChiliComponentsRoles(self, CONSTANTS.rolesXOffset,CONSTANTS.rolesYOffset)
	-- add new components: inputs
	createChiliComponentsInput(self, xOffSet, CONSTANTS.rolesYOffset)
	
	-- transfering user given data: 
	
	-- units assignment: -------------------------------------------------------
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
				self:FillInInput(inputName, givenInput)
			end
		end 
	end
	self:UpdateTreeStatus()

end
return TreeHandle
