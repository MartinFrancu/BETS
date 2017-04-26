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
	
	--[[ProjectDialog.LOAD = "loading dialog"
	ProjectDialog.SAVE = "saving dialog"]]
	--[[
	function onSelectCombobox(self)
		if(self.items[self.selected] == self.newItemString) then
			self.newItemEditBox:Show()
			self.newItemLabel:Show()
		else
			self.newItemEditBox:Hide()
			self.newItemLabel:Hide()
		end
	end]]
	
	function onSelectItem(self)
		if(self.items[self.selected] == self.newItemString) then
			self.newItemEditBox:Show()
		else
			self.newItemEditBox:Hide()
		end
	end
	
	function onSelectProject(self)
		local selected = self.items[self.selected]
		if( selected == self.newProjectString) then
			self.newProjectEditBox:Show()
			-- add possible new item
			self.itemComboBox.items = {self.newItemString}
			self.itemComboBox:Select(1)
		else
			self.newProjectEditBox:Hide()
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
		self.callback(self.callbackObject, result)
	end
	
	function cancelButtonListener(self)
		self.callback(self.callbackObject)
	end
--[[	
	function ProjectDialog.showWindow(contentType, dialogType, callback, parent, windowParams)
		local Chili = Utils.Chili
		-- prepare window with default params if necessary
		local par = parent or Chili.Screen0
		local defaultParams = {
			parent = par,
			x = 400,
			y = 400,
			width = 600,
			height = 200,
			padding = {10,10,10,10},
			draggable = true,
			resizable = true,
			skinName = 'DarkGlass',
		}
		local winPar 
		if(windowParams) then
			winPar = setmetatable(windowParams ,{__index = defaultParams})
		else
			winPar = defaultParams
		end
		local window = Chili.Window:New(winPar)
		
		ProjectDialog.setUpDialog(window, contentType, dialogType, callback)

	end]]
	
	--- This will attach corresponding chili components to
	function ProjectDialog.setUpDialog(parent, contentType, creatingEnabled, callbackObject, callbackFunction)
		local Chili = Utils.Chili
		-- get project manager
		local pM =  Utils.ProjectManager
		--[[ 
		local contents = pM.listAll(contentType)
		local items = {}
		for i,data in ipairs(contents) do
			items[i] = data["qualifiedName"]
			Logger.log("dialogs", "qualifiedName = ", dump(data,2))
			Logger.log("dialogs", "qualifiedName = ", data["qualifiedName"] )
		end
		
		if creatingEnabled then
			items[#items+1] = NEW_ITEM_STRING
		end
		]]
		--[[local newLabel = Chili.Label:New{
			parent = parent,
			caption = "New:",
			x = 25,
			y = 60,
			width = 40,
			height = 35,
		}
		newLabel:Hide()]]
		
		
		local newProjectEditBox = Chili.EditBox:New{
			parent = parent,
			text = "--PLEASE FILL IN--",
			x = 15,
			y = 60,
			width = 120,
			height = 20,
			
		}
		newProjectEditBox:Hide()
		
		local newItemEditBox = Chili.EditBox:New{
			parent = parent,
			text = "--PLEASE FILL IN--",
			x = 150,
			y = 60,
			width = 140,
			height = 20,
			
		}
		newItemEditBox:Hide()
		
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
		--itemSelection:Hide()
		
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
