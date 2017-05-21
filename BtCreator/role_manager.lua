local sanitizer = Utils.Sanitizer.forCurrentWidget()
local Chili = Utils.Chili

local Logger = Utils.Debug.Logger
local dump = Utils.Debug.dump

local roleManager = {}


local showRoleManagementWindow
local categoryCheckBoxes
local unitCheckBoxes
local returnFunction

local xOffBasic = 10
local yOffBasic = 10
local xCheckBoxOffSet = 180
local xLocOffsetMod = 250 

function roleManager.showCategoryDefinitionWindow()
	roleManager.rolesWindow:Hide()
	roleManager.categoryDefinitionWindow = Chili.Window:New{
		parent = roleManager.rolesWindow.parent,
		x = 150,
		y = 300,
		width = 1250,
		height = 600,
		skinName = 'DarkGlass'
	}
	
	local categoryDoneButton = Chili.Button:New{
		parent =  roleManager.categoryDefinitionWindow,
		x = 0,
		y = 0,
		caption = "SAVE AS",
		OnClick = {sanitizer:AsHandler(roleManager.doneCategoryDefinition)},
	}

	
	--categoryDoneButton.categoryNameEditBox = nameEditBox
	categoryDoneButton.window = roleManager.categoryDefinitionWindow
	returnFunction = showRoleManagementWindow
	-- plus checkboxes added later in categoryDoneButton
	
	local categoryCancelButton = Chili.Button:New{
		parent =  roleManager.categoryDefinitionWindow,
		x = categoryDoneButton.x + categoryDoneButton.width,
		y = 0,
		caption = "CANCEL",
		OnClick = {sanitizer:AsHandler(roleManager.cancelCategoryDefinition)},
	}
	categoryCancelButton.window = roleManager.categoryDefinitionWindow
	categoryCancelButton.returnFunction = showRoleManagementWindow
	
	local categoryScrollPanel = Chili.ScrollPanel:New{
		parent = roleManager.categoryDefinitionWindow,
		x = 0,
		y = 30,
		width  = '100%',
		height = '100%',
		skinName='DarkGlass'
	}
	xOffSet = 5
	yOffSet = 30

	local xLocalOffSet = 0
	local unitsD = {}
	for _,unitDef in pairs(UnitDefs) do
		if(unitDef.isFeature == false) then -- exclude walls and roads...
			table.insert(unitsD, unitDef)
		end
	end 
	--[[
	local humanNameOrder  = function (a,b)
		return a.humanName < b.humanName
	end
	--]]
	local nameOrder  = function (a,b)
		return a.name < b.name
	end
	
	table.sort(unitsD, nameOrder)
	
	unitCheckBoxes = {}
	for i,unitDef in ipairs(unitsD) do
		local typeCheckBox = Chili.Checkbox:New{
			parent = categoryScrollPanel,
			x = xOffSet + (xLocalOffSet * 250),
			y = yOffSet,
			caption = unitDef.name .. "(" .. unitDef.humanName .. ")",
			checked = false,
			width = 200,
		}
		typeCheckBox.unitId = unitDef.id
		typeCheckBox.unitName = unitDef.name
		typeCheckBox.unitHumanName = unitDef.humanName
		xLocalOffSet = xLocalOffSet + 1
		if(xLocalOffSet == 5) then
			xLocalOffSet = 0
			yOffSet = yOffSet + 20
		end
		unitCheckBoxes[i] = typeCheckBox
	end
	-- add small placeholder at end:
	local placeholder = Chili.Label:New{
		parent = categoryScrollPanel,
		x = xOffSet,
		y = yOffSet + 50,
		caption = "=== end ===",
		skinName='DarkGlass',
	}
	-- check old checked checkboxes:
	categoryDoneButton.Checkboxes = typesCheckboxes
end

function roleManager.createNewCategoryCallback(projectName, categoryName)	
	local pM = Utils.ProjectManager
	
	if(projectName and categoryName)then
		-- user selected a project and category name, lets save it
 
		if(not pM.isProject(projectName))then
			-- if new project I should create it 
			pM.createProject(projectName)
		end
		local qualifiedName = projectName .. "." .. categoryName
		--create project if necessary
		-- add new category to unitCategories
		local unitTypes = {}
		for _,unitTypeCheckBox in pairs(unitCheckBoxes) do
			if(unitTypeCheckBox.checked == true) then
				local typeRecord = {id = unitTypeCheckBox.unitId, name = unitTypeCheckBox.unitName, humanName = unitTypeCheckBox.unitHumanName}
				table.insert(unitTypes, typeRecord)
			end
		end
		-- add check for category name?
		local newCategory = {
			project = projectName,
			name = 	categoryName,
			types = unitTypes,
		}
		Utils.UnitCategories.saveCategory(newCategory)		
		-- return after
		returnFunction()
	else
		-- user hit cancel, lets return to category definition
		roleManager.categoryDefinitionWindow:Show()	
	end
end

function roleManager.doneCategoryDefinition(self)
	local ProjectDialog = Utils.ProjectDialog
	local ProjectManager = Utils.ProjectManager
	-- show save dialog:
	roleManager.categoryDefinitionWindow:Hide()	
	
	local contentType =  ProjectManager.makeRegularContentType("UnitCategories", "json")
	ProjectDialog.showDialog({
		visibilityHandler = BtCreator.setDisableChildrenHitTest,
		contentType = contentType,
		dialogType = ProjectDialog.NEW_DIALOG,
		title = "Save category as:",
	}, roleManager.createNewCategoryCallback)
end

function roleManager.cancelCategoryDefinition(self)
	self.window:Hide()
	self.returnFunction()
end

function doneRoleManagerWindow(self)
	self.window:Hide()
	local result = {}
	for _,roleRecord in pairs(self.rolesData) do
		local roleName = roleRecord.nameEditBox.text
		local checkedCategories = {}
		for _, categoryCB in pairs(roleRecord.CheckBoxes) do
			if(categoryCB.checked) then
				local catName = categoryCB.caption
				table.insert(checkedCategories, catName)
			end
		end
		local roleResult = {name = roleName, categories = checkedCategories}
		table.insert(result, roleResult)
	end
	
	-- call return function
	self.returnFunction(callbackObject, result)
end

local function maxRoleSplit(tree)
	local roleCount = 1
	local function visit(node)
		if(not node) then
			return
		end
		if(node.nodeType == "roleSplit" and roleCount < #node.children)then
				roleCount = #node.children
		end
		for _, child in ipairs(node.children) do
				visit(child)
		end
	end
	visit(tree.root)
	return roleCount
end

local parent, tree, rolesOfCurrentTree, returnFunction, callbackObject

-- set up checkboxes and name edit box for role, index and roles is used to prefill if applicable..
local function setUpRoleChiliComponents(parent, xOff, yOff, index, roles)
	local xOffSet = xOff
	local yOffSet = yOff
	local nameEditBox = Chili.EditBox:New{
			parent = parent,
			x = xOffSet,
			y = yOffSet,
			text = "Role ".. index,
			width = 150
	}
	local checkedCategories = {}
	if(roles[index]) then
		nameEditBox:SetText(roles[index].name)
		for _,catName in pairs(roles[index].categories) do
			checkedCategories[catName] = true
		end
	end

	local categoryNames = Utils.UnitCategories.getAllCategoryNames()
	categoryCheckBoxes = {}
	local xLocalOffSet = 0
	for _,categoryName in pairs(categoryNames) do
		local categoryCheckBox = Chili.Checkbox:New{
			parent = parent,
			x = xOffSet + xCheckBoxOffSet + (xLocalOffSet * xLocOffsetMod),
			y = yOffSet,
			caption = categoryName,
			checked = false,
			width = 200,
		}
		if(checkedCategories[categoryName] ~= nil) then
			categoryCheckBox:Toggle()
		end
		xLocalOffSet = xLocalOffSet + 1
		if(xLocalOffSet == 4) then
			xLocalOffSet = 0
			yOffSet = yOffSet + 20
		end

		table.insert(categoryCheckBoxes, categoryCheckBox)
	end


	yOffSet = yOffSet + 50
	local roleCategories = {}
	roleCategories["nameEditBox"] = nameEditBox
	roleCategories["CheckBoxes"] = categoryCheckBoxes
	roleCategories["yEnd"] = yOffSet
	return roleCategories
end

-- this should try to add new role record
local function  listenerPlusButton(self)
	local rolesData = self.doneButton.rolesData
	local newUI = setUpRoleChiliComponents(rolesScrollPanel, xOffBasic , rolesData[#rolesData].yEnd, #rolesData+1, rolesOfCurrentTree)
	rolesData[#rolesData+1] = newUI
end

local function listenerMinusButton(self)
	local rolesData = self.doneButton.rolesData
	if #rolesData < 2 then 
		return -- at least one role should be there 
	else
		local data = rolesData[#rolesData]
		--Logger.log("roles", dump(data) )
		local parent = data["nameEditBox"].parent
		data["nameEditBox"]:Dispose()
		for _,checkBox in ipairs(data["CheckBoxes"]) do
			checkBox:Dispose()
		end
		parent:Invalidate()
		rolesData[#rolesData]= nil
	end
end

showRoleManagementWindow = function()
-- remove old children:
	if( roleManager.rolesWindow) then
		parent:RemoveChild(roleManager.rolesWindow)
	end
	
	
	roleManager.rolesWindow = Chili.Window:New{
		parent = parent,
		x = 150,
		y = 300,
		width = 1200,
		height = 600,
		skinName = 'DarkGlass'
	}
	local window = roleManager.rolesWindow
	
	-- now I just need to save it
	roleManagementDoneButton = Chili.Button:New{
		parent = window,
		x = 0,
		y = 0,
		caption = "DONE",
		OnClick = {sanitizer:AsHandler(doneRoleManagerWindow)},
		returnFunction = returnFunction,
		callbackObject = callbackObject,
	}
	roleManagementDoneButton.window = roleManager.rolesWindow

	local plusButton = Chili.Button:New{
		parent = window,
		x = roleManagementDoneButton.x + roleManagementDoneButton.width,
		y = roleManagementDoneButton.y,
		caption = "+",
		width = 40,
		OnClick = {sanitizer:AsHandler(listenerPlusButton)}, --sanitizer:AsHandler(roleManager.doneCategoryDefinition)},
		doneButton = roleManagementDoneButton,
	}
	
	local minusButton = Chili.Button:New{
		parent =  window,
		x = plusButton.x + plusButton.width,
		y = plusButton.y,
		caption = "-",
		width = 40,
		OnClick = {sanitizer:AsHandler(listenerMinusButton)},--sanitizer:AsHandler(roleManager.doneCategoryDefinition)},
		doneButton = roleManagementDoneButton,
	}
	
	
	local categoryDoneButton = Chili.Button:New{
		parent =  roleManager.categoryDefinitionWindow,
		x = 0,
		y = 0,
		caption = "SAVE AS",
		OnClick = {sanitizer:AsHandler(roleManager.doneCategoryDefinition)},
	} 
	
	newCategoryButton = Chili.Button:New{
		parent = window,
		x = minusButton.x + minusButton.width,
		y = 0,
		width = 150,
		caption = "Define new Category",
		OnClick = {sanitizer:AsHandler(roleManager.showCategoryDefinitionWindow)},
	}


	rolesScrollPanel = Chili.ScrollPanel:New{
		parent = window,
		x = 0,
		y = 30,
		width  = '100%',
		height = '100%',
		skinName='DarkGlass'
	}
	local rolesCategoriesCB = {}
	local xOffSet = xOffBasic
	local yOffSet = yOffBasic
	

	-- set up checkboxes for all roles and categories
	
	local roleCount = maxRoleSplit(tree)
	if(roleCount < #rolesOfCurrentTree) then
		roleCount = #rolesOfCurrentTree
	end

	for roleIndex=1, roleCount do
		local newRoleUI
		newRoleUI =  setUpRoleChiliComponents( rolesScrollPanel, xOffSet, yOffSet, roleIndex, rolesOfCurrentTree)
		yOffSet = newRoleUI.yEnd
		table.insert(rolesCategoriesCB, newRoleUI)
	end
	roleManagementDoneButton.rolesData = rolesCategoriesCB
end


-- This shows the role manager window, returnFunction is used to export specified roles data after user clicked "done". (returnFunction(rolesData))
function roleManager.showRolesManagement(parentIn, treeIn, rolesOfCurrentTreeIn, callbackObjectIn, callbackFunction)	
	parent, tree, rolesOfCurrentTree, callbackObject, returnFunction  = parentIn, treeIn, rolesOfCurrentTreeIn, callbackObjectIn, callbackFunction
	showRoleManagementWindow()
end

return roleManager