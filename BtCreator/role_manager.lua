local sanitizer = Utils.Sanitizer.forCurrentWidget()
local Chili = Utils.Chili

local Logger = Utils.Debug.Logger
local dump = Utils.Debug.dump

local roleManager = {}

local IMAGE_PATH = LUAUI_DIRNAME.."Widgets/BtUtils/"
local BACKGROUND_IMAGE_NAME = "black.png"
local CHECKED_COLOR = { 1,0.69999999,0.1,0.80000001} 
local NORMAL_COLOR = {1,1,1,1}

local showRoleManagementWindow
local categoryCheckBoxes
local unitCheckBoxes
local returnFunction

local xOffBasic = 10
local yOffBasic = 10
local xCheckBoxOffSet = 180
local xLocOffsetMod = 250 

local function trimStringToScreenSpace(str, font, limit)
	if(font:GetTextWidth(str) < limit) then
		-- it is ok as it is
		return str
	end
	local dots = "..."
	local trimmed = str
	local length
	repeat
	-- make it littlebit shorter
		trimmed = string.sub(trimmed, 1, -2)
		length = font:GetTextWidth(trimmed .. dots)
	until length < limit
	return trimmed .. dots
end

local function changeColor(checkBox)
	if(checkBox.checked)then -- it is called before the changed (checked -> unchecked)
		checkBox.font.color =  NORMAL_COLOR
	else
		checkBox.font.color =  CHECKED_COLOR
	end
	checkBox:Invalidate()
end

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
	roleManager.categoryDefinitionWindow.backgroundColor = {1,1,1,1}
	roleManager.categoryDefinitionWindow.TileImage = IMAGE_PATH .. BACKGROUND_IMAGE_NAME
	roleManager.categoryDefinitionWindow:Invalidate()
	
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
	yOffSet = 0

	local unitsD = {}
	for _,unitDef in pairs(UnitDefs) do
			unitsD[#unitsD+1] = unitDef
	end 
	local nameOrder  = function (a,b)
		return a.name < b.name
	end
	
	table.sort(unitsD, nameOrder)
	
	local xLocalOffSet = 0
	local columnHeight = #unitsD / 5
	local currentHeight = 0
	unitCheckBoxes = {}
	for i,unitDef in ipairs(unitsD) do
		local unitEntry = unitDef.name .. "(" .. unitDef.humanName .. ")"
		local typeCheckBox = Chili.Checkbox:New{
			parent = categoryScrollPanel,
			x = xOffSet + (xLocalOffSet * 250),
			y = yOffSet + currentHeight * 20,
			caption = "PLACEHOLDER",
			checked = false,
			width = 200,
			OnChange = {changeColor},
		}
		typeCheckBox.font.color = NORMAL_COLOR
		local font = typeCheckBox.font
		local trimmedName = trimStringToScreenSpace(unitEntry, font , typeCheckBox.width - 20)
		typeCheckBox.caption = trimmedName
		typeCheckBox:Invalidate()
		typeCheckBox.unitName = unitDef.name
		typeCheckBox.unitHumanName = unitDef.humanName
		
		currentHeight = currentHeight +1
		
		if(currentHeight > columnHeight) then
			xLocalOffSet = xLocalOffSet + 1
			currentHeight = 0
		end
		unitCheckBoxes[i] = typeCheckBox
	end
	-- add small placeholder at end:
	local placeholder = Chili.Label:New{
		parent = categoryScrollPanel,
		x = xOffSet,
		y = yOffSet + (columnHeight * 20)+80,
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
				local typeRecord = {name = unitTypeCheckBox.unitName}
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
		roleManager.categoryDefinitionWindow:Dispose()
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
	self.window:Dispose()
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
			OnChange = {changeColor},
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
	roleManager.rolesWindow.backgroundColor = {1,1,1,1}
	roleManager.rolesWindow.TileImage = IMAGE_PATH .. BACKGROUND_IMAGE_NAME
	roleManager.rolesWindow:Invalidate()
	
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