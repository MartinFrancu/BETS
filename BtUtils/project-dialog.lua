--- Module in charge of new/load/save GUI dialogs.
-- @module ProjectDialog

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils
	
return Utils:Assign("ProjectDialog", function()
	
	local ProjectDialog = {}
	
	local Debug = Utils.Debug;
	local Logger = Debug.Logger
	local dump = Debug.dump
	local Chili = Utils.Chili
	
	local ProjectManager = Utils.ProjectManager
	local Sanitizer = Utils.Sanitizer
	local Debug = Utils.Debug
	local Logger = Debug.Logger
	
	local NEW_ITEM_STRING = "--NEW ITEM--"
	local NEW_PROJECT_STRING = "--NEW PROJECT--"
	
	
	ProjectDialog.LOAD_DIALOG = "LOAD"
	ProjectDialog.SAVE_DIALOG = "SAVE"
	ProjectDialog.NEW_DIALOG = "NEW"
	
	
	local PATH = LUAUI_DIRNAME.."Widgets/BtUtils/"
	local BACKGROUND_IMAGE_NAME = "black.png"

	
	local dialogWindow
	
	local function sortItems(items)
		table.sort(items, function(x,y) return x.name:lower() < y.name:lower() end)
	end
	
	local function onSelectItem(self)
		if(self.items[self.selected] == self.newItemString) then
			if(not self.newItemEditBox.visible ) then
				self.newItemEditBox:Show()
			end
		else
			if(self.newItemEditBox.visible)then
				self.newItemEditBox:Hide()
			end
		end
	end
	
	local function onSelectProject(self)
		local selected = self.items[self.selected]
		if( selected == self.newProjectString) then
			if(not self.newProjectEditBox.visible ) then
				self.newProjectEditBox:Show()
			end
			-- add possible new item
			self.itemComboBox.items = {self.newItemString}
			self.itemComboBox:Select(1)
		else
			if( self.newProjectEditBox.visible ) then
				self.newProjectEditBox:Hide()
			end
			-- i should update item combo box:
			-- new items:
			local listProject = self.projectManager.listProject(selected, self.contentType)
			sortItems(listProject)
			local newItems = {}
			for i,data in ipairs(listProject)do
				newItems[i] = data.name
			end
			-- add possible new item
			if self.creatingEnabled then
				newItems[#newItems+1] = self.newItemString
			end
			self.itemComboBox.items = newItems
			self.itemComboBox:Select(1)
		end	
	end
	
	local function doneButtonListener(self)
		local selectedProject = self.projectSelection.items[self.projectSelection.selected]
		if(selectedProject == self.newProjectString) then
			selectedProject = self.newProjectEditBox.text
		end
		
		local selectedItem
		if(self.itemSelection) then
			-- the new button
			selectedItem = self.itemSelection.items[self.itemSelection.selected]
			if(selectedItem == self.newItemString) then
				selectedItem = self.newItemEditBox.text
			end
		else
			selectedItem = self.newItemEditBox.text
		end
		
		if(string.len(selectedProject ) > 0 and string.len(selectedItem)> 0 ) then
			-- selected project and item are not empty strings
			self.callback(self.callbackObject, selectedProject, selectedItem)
			self.showDialogHandler(false)
		end
		-- else do nothing
	end
	
	local function cancelButtonListener(self)
		self.callback(self.callbackObject)
		self.showDialogHandler(false)
	end
	
	local function hideWindowAndCall(window, ...) 
		if window.visible then
			window:Hide()
		end
		window.callback(...)
		window:Dispose()
	end
	
	-- This will attach corresponding chili components of save/load dialog to a given parent.
	function ProjectDialog.setUpDialog(parent, contentType, creatingEnabled, callbackObject, callbackFunction, showDialogHandler, defaultProject, defaultName)
		callbackFunction = Sanitizer.sanitize(callbackFunction)
		
		local sanitizer = Utils.Sanitizer.forCurrentWidget()

		local selectedProject = nil
		local projects = ProjectManager.getProjects()
		sortItems(projects)
		local projectNames = {}
		for i,data in ipairs(projects) do
			projectNames[i] = data.name
			if(data.name == defaultProject)then
				selectedProject = i
				defaultProject = nil
			end
		end
		if creatingEnabled then
			if(not selectedProject and defaultProject)then
				selectedProject = #projectNames+1
			end
			projectNames[#projectNames+1] = NEW_PROJECT_STRING
		end
		
		local newProjectEditBox = Chili.EditBox:New{
			parent = parent,
			text = defaultProject or "Unknown",
			x = 15,
			y = 60,
			width = 120,
			height = 20,
			
		}
		
		local newItemEditBox = Chili.EditBox:New{
			parent = parent,
			text = defaultName or "untitled",
			x = 150,
			y = 60,
			width = 140,
			height = 20,
			
		}
		
		local itemSelection = Chili.ComboBox:New{
			parent = parent,
			x = 135,
			y = 20,
			width = 200,
			height = 35,
			items = {"noItem"},
			OnSelect = {sanitizer:AsHandler(onSelectItem)},
			newItemEditBox = newItemEditBox,
			newItemString = NEW_ITEM_STRING,
			newItemLabel = newLabel,
		}

		local projectSelection = Chili.ComboBox:New{
			parent = parent,
			x = 15,
			y = 20,
			width = 120,
			height = 35,
			items = projectNames,
			selected = selectedProject,
			OnSelect = {sanitizer:AsHandler(onSelectProject)},
			newProjectEditBox = newProjectEditBox,
			newProjectString = NEW_PROJECT_STRING,
			newItemString = NEW_ITEM_STRING,
			itemComboBox = itemSelection,
			projectManager = ProjectManager,
			contentType = contentType,
			creatingEnabled = creatingEnabled
		}
		
		for i, name in ipairs(itemSelection.items) do
			if(name == defaultName)then
				itemSelection:Select(i)
				newItemEditBox:SetText("untitled")
				break
			end
		end
		
		local doneButton = Chili.Button:New{
			parent = parent,
			x = 50,
			y = 80,
			width = 100,
			height = 30,
			caption = "DONE",
			OnClick = {sanitizer:AsHandler(doneButtonListener)},
			skinName = 'DarkGlass',
			focusColor = {1,0.5,0,0.5},
		}
		doneButton.callback = callbackFunction
		doneButton.callbackObject = callbackObject
		doneButton.projectSelection = projectSelection
		doneButton.itemSelection = itemSelection
		doneButton.newItemEditBox = newItemEditBox
		doneButton.newItemString = NEW_ITEM_STRING
		doneButton.newProjectEditBox = newProjectEditBox
		doneButton.newProjectString = NEW_PROJECT_STRING
		doneButton.showDialogHandler = showDialogHandler
		
		local cancelButton = Chili.Button:New{
			parent = parent,
			x = 150,
			y = 80,
			width = 100,
			height = 30,
			caption = "CANCEL",
			OnClick = {sanitizer:AsHandler(cancelButtonListener)},
			skinName = 'DarkGlass',
			focusColor = {1,0.5,0,0.5},
		}
		cancelButton.callback = callbackFunction
		cancelButton.callbackObject = callbackObject
		cancelButton.showDialogHandler = showDialogHandler
	end
	

	
	local function onSelectProjectNew(self)
		local selected = self.items[self.selected]
		if( selected == self.newProjectString) then
			if(not self.newProjectEditBox.visible ) then
				self.newProjectEditBox:Show()
			end
		else
			if( self.newProjectEditBox.visible ) then
				self.newProjectEditBox:Hide()
			end
		end	
	end
		
	
	-- This will attach corresponding chili components of new item dialog to a given parent.
	function ProjectDialog.setUpDialogNewItem(parent, contentType, callbackObject, callbackFunction, showDialogHandler, defaultProject, defaultName)
		callbackFunction = Sanitizer.sanitize(callbackFunction)
		
		local sanitizer = Utils.Sanitizer.forCurrentWidget()
		local firstLineY = 20
		local secondLineY = 60
		local thirdLineY = 80
		
		local selectedProject = nil
		local projects = ProjectManager.getProjects()
		sortItems(projects)
		local projectNames = {}
		for i,data in ipairs(projects) do
			projectNames[i] = data.name
			if(data.name == defaultProject)then
				selectedProject = i
				defaultProject = nil
			end
		end
		if(not selectedProject)then
			selectedProject = #projectNames+1
		end
		projectNames[#projectNames+1] = NEW_PROJECT_STRING
		
		local newProjectEditBox = Chili.EditBox:New{
			parent = parent,
			text = defaultProject or "Untitled",
			x = 15,
			y = secondLineY,
			width = 120,
			height = 20,
			
		}
		
		local newItemEditBox = Chili.EditBox:New{
			parent = parent,
			text = defaultName or "unknown",
			x = 150,
			y = firstLineY,
			width = 140,
			height = 20,
			
		}
		
		local projectSelection = Chili.ComboBox:New{
			parent = parent,
			x = 15,
			y = 20,
			width = 120,
			height = 35,
			items = projectNames,
			selected = selectedProject,
			OnSelect = {sanitizer:AsHandler(onSelectProjectNew)},
			newProjectEditBox = newProjectEditBox,
			newProjectString = NEW_PROJECT_STRING,
			projectManager = ProjectManager,
			contentType = contentType,
		}
		
		
		local doneButton = Chili.Button:New{
			parent = parent,
			x = 50,
			y = thirdLineY,
			width = 100,
			height = 30,
			caption = "DONE",
			OnClick = {sanitizer:AsHandler(doneButtonListener)},
			skinName = 'DarkGlass',
		}
		doneButton.callback = callbackFunction
		doneButton.callbackObject = callbackObject
		doneButton.projectSelection = projectSelection
		doneButton.newItemEditBox = newItemEditBox
		doneButton.newProjectEditBox = newProjectEditBox
		doneButton.newProjectString = NEW_PROJECT_STRING
		doneButton.showDialogHandler = showDialogHandler
		
		local cancelButton = Chili.Button:New{
			parent = parent,
			x = 150,
			y = 80,
			width = 100,
			height = 30,
			caption = "CANCEL",
			OnClick = {sanitizer:AsHandler(cancelButtonListener)},
			skinName = 'DarkGlass',
		}
		cancelButton.callback = callbackFunction
		cancelButton.callbackObject = callbackObject
		cancelButton.showDialogHandler = showDialogHandler
	end
	
	local function showDialogWindow(visibilityHandler, contentType, dialogFlag, callbackFunction, title, xIn, yIn, defaultProject, defaultName)
		visibilityHandler = visibilityHandler and Sanitizer.sanitize(visibilityHandler) or function() end
		callbackFunction = callbackFunction and Sanitizer.sanitize(callbackFunction) or function() end 
		local sanitizer = Utils.Sanitizer.forCurrentWidget()
		
		local winWidth = 400
		local winHeight = 185
		
		local dialogWindow = Chili.Window:New{
			parent = Chili.Screen0,
			x = xIn or 300,
			y = yIn or 500,
			width =  winWidth,
			height = winHeight,
			padding = {10,10,10,10},
			draggable = true,
			resizable = true,
			skinName = 'DarkGlass',
		}
		dialogWindow.backgroundColor = {1,1,1,1}
		dialogWindow.TileImage = PATH .. BACKGROUND_IMAGE_NAME
		dialogWindow:Invalidate()

		
		dialogWindow.callback = callbackFunction
		
		local label = Chili.Label:New{
			parent = dialogWindow,
			x = 5,
			y = 5,
			height = 30,
			width = '90%',
			caption = title,
			skinName = 'DarkGlass',
		}
		local panel = Chili.Control:New{
			parent = dialogWindow,
			x = 0,
			y = 30,
			height = 150,
			width = 400,
			skinName = 'DarkGlass',
		}
		
		local sanitizedHideWindowAndCall = sanitizer:Sanitize(hideWindowAndCall)
		
		if(dialogFlag == ProjectDialog.LOAD_DIALOG) then
			ProjectDialog.setUpDialog(panel, contentType, false, dialogWindow, sanitizedHideWindowAndCall, visibilityHandler, defaultProject, defaultName)
		end
		if(dialogFlag == ProjectDialog.SAVE_DIALOG) then
			ProjectDialog.setUpDialog(panel, contentType, true, dialogWindow, sanitizedHideWindowAndCall, visibilityHandler, defaultProject, defaultName)
		end
		if(dialogFlag == ProjectDialog.NEW_DIALOG) then
			ProjectDialog.setUpDialogNewItem(panel, contentType, dialogWindow, sanitizedHideWindowAndCall, visibilityHandler, defaultProject, defaultName)
		end
		
		visibilityHandler(true)
	end
	
	--- Shows a dialog that allows the user to select a project and a name of a content.
	-- @tab params Table of parameters tha can contain the following slots.
	--
	-- - `visibilityHandler` - function that is called with `true` when dialog is shown and with `false` when it is hidden, can be used to disable other components while the dialog is shown
	-- - `contentType` - @{ProjectManager.ContentType} that the dialog handles
	-- - `dialogType` - one of the following
	--     - `ProjectDialog.LOAD_DIALOG`
	--     - `ProjectDialog.SAVE_DIALOG`
	--     - `ProjectDialog.NEW_DIALOG`
	-- - `title` - title of the dialog
	-- - `x`, `y` - position where to show the dialog
	-- - `project`, `name` - initial selected items in the dialog
	-- @func callbackFunction Function that gets called after the dialog concludes.
	function ProjectDialog.showDialog(params, callbackFunction)
		showDialogWindow(params.visibilityHandler, params.contentType, params.dialogType, callbackFunction, params.title, params.x, params.y, params.project, params.name)
	end
	
	return ProjectDialog
end)
