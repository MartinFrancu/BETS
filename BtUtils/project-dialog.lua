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
	
	--[[ProjectDialog.LOAD = "loading dialog"
	ProjectDialog.SAVE = "saving dialog"]]
	
	function onSelectCombobox(self)
		if(self.items[self.selected] == self.newItemString) then
			self.newItemEditBox:Show()
			self.newItemLabel:Show()
		else
			self.newItemEditBox:Hide()
			self.newItemLabel:Hide()
		end
	end
	
	function doneButtonListener(self)
		local selectedName
		Logger.log("dialogs", "name: " , self.combobox.items[self.combobox.selected],
			" string: ",self.newItemString)
		if(self.combobox.items[self.combobox.selected] == self.newItemString) then
			selectedName = self.newItemEditBox.text
			Logger.log("dialogs", "selectedName :", selectedName)
		else
			selectedName = self.combobox.items[self.combobox.selected]
		end
		Logger.log("dialogs", "selected: " , selectedName )
		self.callback(self.callbackObject, selectedName )
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
		local contents = pM.listAll(contentType)
		local items = {}
		Logger.log("dialogs", "content = ", dump(contents, 2 ) )
		for i,data in ipairs(contents) do
			items[i] = data["qualifiedName"]
			Logger.log("dialogs", "qualifiedName = ", dump(data,2))
			Logger.log("dialogs", "qualifiedName = ", data["qualifiedName"] )
		end
		
		if creatingEnabled then
			items[#items+1] = NEW_ITEM_STRING
		end
		
		local newLabel = Chili.Label:New{
			parent = parent,
			caption = "New:",
			x = 25,
			y = 60,
			width = 40,
			height = 35,
		}
		newLabel:Hide()
		local newEditBox = Chili.EditBox:New{
			parent = parent,
			text = "-- NEW NAME --",
			x = 60,
			y = 60,
			width = 250,
			height = 20,
			
		}
		newEditBox:Hide()
		
		local selection = Chili.ComboBox:New{
			parent = parent,
			x = 15,
			y = 20,
			width = 300,
			height = 35,
			items = items,
			OnSelect = {onSelectCombobox},
			newItemEditBox = newEditBox,
			newItemString = NEW_ITEM_STRING,
			newItemLabel = newLabel,
		}
		--[[selection.newItemString = NEW_ITEM_STRING
		selection.newItemEditBox = newEditBox
		selection.newItemLabel = newLabel]]
		--[[local newEditBox
		if(creatingEnabled) then
			
		end]]
		
		
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
		doneButton.combobox = selection
		doneButton.callbackObject = callbackObject
		doneButton.newItemEditBox = newEditBox
		doneButton.newItemString = NEW_ITEM_STRING
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
