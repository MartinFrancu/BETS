
local roleManager = {}


local showRoleManagementWindow
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
	local nameEditBox = Chili.EditBox:New{
			parent = roleManager.categoryDefinitionWindow,
			x = 0,
			y = 0,
			text = "New unit category",
			width = 150
	}
	local categoryDoneButton = Chili.Button:New{
		parent =  roleManager.categoryDefinitionWindow,
		x = nameEditBox.x + nameEditBox.width,
		y = 0,
		caption = "DONE",
		OnClick = {sanitizer:AsHandler(roleManager.doneCategoryDefinition)},
	}
	categoryDoneButton.categoryNameEditBox = nameEditBox
	categoryDoneButton.window = roleManager.categoryDefinitionWindow
	categoryDoneButton.returnFunction = showRoleManagementWindow
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
	local typesCheckboxes = {}
	local xLocalOffSet = 0
	local unitsD = {}
	for _,unitDef in pairs(UnitDefs) do
		if(unitDef.isFeature == false) then -- exclude walls and roads...
			table.insert(unitsD, unitDef)
		end
	end 
	
	local humanNameOrder  = function (a,b)
		return a.humanName < b.humanName
	end
	table.sort(unitsD, humanNameOrder)
	
	for _,unitDef in ipairs(unitsD) do
		local typeCheckBox = Chili.Checkbox:New{
			parent = categoryScrollPanel,
			x = xOffSet + (xLocalOffSet * 250),
			y = yOffSet,
			caption = unitDef.humanName,
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
		table.insert(typesCheckboxes, typeCheckBox)
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

function roleManager.doneCategoryDefinition(self)
	-- add new category to unitCategories
	local unitTypes = {}
	for _,unitTypeCheckBox in pairs(self.Checkboxes) do
		if(unitTypeCheckBox.checked == true) then
			local typeRecord = {id = unitTypeCheckBox.unitId, name = unitTypeCheckBox.unitName, humanName = unitTypeCheckBox.unitHumanName}
			table.insert(unitTypes, typeRecord)
		end
	end
	-- add check for category name?
	local newCategory = {
		name = self.categoryNameEditBox.text,
		types = unitTypes,
	}
	Utils.UnitCategories.redefineCategories(newCategory)

	roleManager.categoryDefinitionWindow:Hide()
	self.returnFunction()
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
	self.returnFunction(result)
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

local parent, tree, rolesOfCurrentTree, returnFunction

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
	}
	roleManagementDoneButton.window = roleManager.rolesWindow

	newCategoryButton = Chili.Button:New{
		parent = window,
		x = 150,
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
	local xOffSet = 10
	local yOffSet = 10
	local xCheckBoxOffSet = 180
	-- set up checkboxes for all roles and categories
	
	local roleCount = maxRoleSplit(tree)

	for roleIndex=0, roleCount -1 do
		local nameEditBox = Chili.EditBox:New{
			parent = rolesScrollPanel,
			x = xOffSet,
			y = yOffSet,
			text = "Role ".. roleIndex,
			width = 150
		}
		local checkedCategories = {}
		if(rolesOfCurrentTree[roleIndex+1]) then
			nameEditBox:SetText(rolesOfCurrentTree[roleIndex+1].name)
			for _,catName in pairs(rolesOfCurrentTree[roleIndex+1].categories) do
				checkedCategories[catName] = 1
			end
		end

		local categoryNames = Utils.UnitCategories.getAllCategoryNames()
		local categoryCheckBoxes = {}
		local xLocalOffSet = 0
		for _,categoryName in pairs(categoryNames) do
			local categoryCheckBox = Chili.Checkbox:New{
				parent = rolesScrollPanel,
				x = xOffSet + xCheckBoxOffSet + (xLocalOffSet * 250),
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
		table.insert(rolesCategoriesCB,roleCategories)
	end
	roleManagementDoneButton.rolesData = rolesCategoriesCB

	roleManager.rolesWindow:Show()
end


-- This shows the role manager window, returnFunction is used to export specified roles data after user clicked "done". (returnFunction(rolesData))
function roleManager.showRolesManagement(parentIn, treeIn, rolesOfCurrentTreeIn, returnFunctionIn)	
	parent, tree, rolesOfCurrentTree, returnFunction  = parentIn, treeIn, rolesOfCurrentTreeIn, returnFunctionIn
	showRoleManagementWindow()
end

return roleManager