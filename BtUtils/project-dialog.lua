--- Module in charge of loading/saving GUI dialogs. 
--[[ INTERNAL - original specification from skype conversation:
Mělo by to být v BtUtils. Jméno asi ProjectDialog. Mít statickou metodu show(parameters, callback).
V parameters by asi mělo být parent, čímž by šlo specifikovat rodiče pro ten dialog, jinak by to měl být Chili.Screen0. 
Pak contentType, což je to, co se dává jako první argument do metod ProjectManageru.
 A pak asi type což by mohlo být buď ProjectDialog.LOAD nebo ProjectDialog.SAVE, což by byly nějaké konstanty, které by určovaly, zda má dialog dovolovat specifikovat nové projekty/soubory.
A jakmile ten dialog skončí, tak by se zavolal callback, nejspíš tedy s tím qualifiedName a možná i nějakými dalšími věcmi, pokud by se hodily. To se třeba ještě ukáže.
A zapomněl jsem zmínit, že k tomu, aby jsi mohl použít Chili v BtUtils k němu musíš přistupovat přes BtUtils.Chili (nebo Utils.Chili pokud se inspiruješ v jiných kódech, které jsem psal, 
kde lokalizuju BtUtils jako Utils). Ale přistupovat k němu vždy stejně -- konkrétně není moc dobře možné vzít BtUtils.Chili a uložit si ho někdy při inicializaci do lokální proměnné,
 protože tam v tu dobu nejspíš ještě není.
]]
-- @module ProjectDialog

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils
	
return Utils:Assign("ProjectDialog", function()
	
	local ProjectDialog = {}
	
	local Debug = Utils.Debug;
	local Logger = Debug.Logger
	local dump = Debug.dump
	
	local ProjectManager = Utils.ProjectManager
	local Sanitizer = Utils.Sanitizer
	local Debug = Utils.Debug
	local Logger = Debug.Logger
	
	local NEW_ITEM_STRING = "--NEW ITEM--"
	local NEW_PROJECT_STRING = "--NEW PROJECT--"
	
	local dialogWindow
	
	function onSelectItem(self)
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
	
	function onSelectProject(self)
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
			local newItems = {}
			for i,data in ipairs(listProject)do
				Logger.log("dialogs", "data: ", dump(data,2) ) 
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
	
	
	function doneButtonListener(self)
		local selectedProject = self.projectSelection.items[self.projectSelection.selected]
		if(selectedProject == self.newProjectString) then
			selectedProject = self.newProjectEditBox.text
		end
		
		local selectedItem  = self.itemSelection.items[self.itemSelection.selected]
		if(selectedItem == self.newItemString) then
			selectedItem = self.newItemEditBox.text
		end
		
		local result = selectedProject .. "." .. selectedItem
		
		Logger.log("dialogs", "result: " , result)
		self.callback(self.callbackObject, selectedProject, selectedItem)
	end
	
	function cancelButtonListener(self)
		self.callback(self.callbackObject)
	end
	
	function hideWindowAndCall(window, ...) 
		if window.visible then
			window:Hide()
		end
		window.callback(...)
	end
	
	function ProjectDialog.showDialogWindow(parent, contentType, canSpecifyNew, callbackFunction, title)
		local Chili = Utils.Chili
		
		local dialogWindow = Chili.Window:New{
			parent = parent,
			x = 300,
			y = 500,
			width = 400,
			height = 185,
			padding = {10,10,10,10},
			draggable = true,
			resizable = true,
			skinName = 'DarkGlass',
		}
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
		ProjectDialog.setUpDialog(panel, contentType, canSpecifyNew, dialogWindow, hideWindowAndCall)	
	end
	
	--- This will attach corresponding chili components to
	function ProjectDialog.setUpDialog(parent, contentType, creatingEnabled, callbackObject, callbackFunction)
		local Chili = Utils.Chili
		-- get project manager
		local pM =  Utils.ProjectManager
		
		local newProjectEditBox = Chili.EditBox:New{
			parent = parent,
			text = "--PLEASE FILL IN--",
			x = 15,
			y = 60,
			width = 120,
			height = 20,
			
		}
		
		local newItemEditBox = Chili.EditBox:New{
			parent = parent,
			text = "--PLEASE FILL IN--",
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
			OnSelect = {onSelectItem},
			newItemEditBox = newItemEditBox,
			newItemString = NEW_ITEM_STRING,
			newItemLabel = newLabel,
		}

		
		local projects = pM.getProjects()
		
		local projectNames = {}
		for i,data in ipairs(projects) do
			projectNames[i] = data.name
		end
		if creatingEnabled then
			projectNames[#projectNames+1] = NEW_PROJECT_STRING
		end
		
		local projectSelection = Chili.ComboBox:New{
			parent = parent,
			x = 15,
			y = 20,
			width = 120,
			height = 35,
			items = projectNames,
			OnSelect = {onSelectProject},
			newProjectEditBox = newProjectEditBox,
			newProjectString = NEW_PROJECT_STRING,
			newItemString = NEW_ITEM_STRING,
			itemComboBox = itemSelection,
			projectManager = pM,
			contentType = contentType,
			creatingEnabled = creatingEnabled
		}
		
		
		local doneButton = Chili.Button:New{
			parent = parent,
			x = 50,
			y = 80,
			width = 100,
			height = 30,
			caption = "DONE",
			OnClick = {doneButtonListener},
			skinName = 'DarkGlass',
		}
		doneButton.callback = callbackFunction
		doneButton.callbackObject = callbackObject
		doneButton.projectSelection = projectSelection
		doneButton.itemSelection = itemSelection
		doneButton.newItemEditBox = newItemEditBox
		doneButton.newItemString = NEW_ITEM_STRING
		doneButton.newProjectEditBox = newProjectEditBox
		doneButton.newProjectString = NEW_PROJECT_STRING
		
		local cancelButton = Chili.Button:New{
			parent = parent,
			x = 150,
			y = 80,
			width = 100,
			height = 30,
			caption = "CANCEL",
			OnClick = {cancelButtonListener},
			skinName = 'DarkGlass',
		}
		cancelButton.callback = callbackFunction
		cancelButton.callbackObject = callbackObject
	end
	
	return ProjectDialog
end)
