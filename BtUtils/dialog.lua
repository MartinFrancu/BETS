--- Module in charge of general purpose GUI dialogs. 

-- @module Dialog

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils

return Utils:Assign("Dialog", function()
	local Dialog = {}

	local Debug = Utils.Debug;
	local Logger = Debug.Logger
	local dump = Debug.dump
	local Chili = Utils.Chili
	local Sanitizer = Utils.Sanitizer
	

	Dialog.YES_NO_CANCEL_TYPE = "YES_NO"
	Dialog.OK_CANCEL_TYPE = "OK_CANCEL"
	
	local ERROR_TYPE = "ERROR"
	
	local function hideWindow(window) 
		if window.visible then
			window:Hide()
		end
		window:Dispose()
	end
	
	local function createButtons(dialogWindow, parentHandler, callbackFunction, dialogType)
		local sanitizer = Sanitizer.forCurrentWidget()
		
		local buttonWidth = 80
		local buttonHeight = 30
		local spaceWidth = 5
		
		local n
		if dialogType == Dialog.YES_NO_CANCEL_TYPE then
			n = 3
		elseif dialogType == Dialog.OK_CANCEL_TYPE then
			n = 2
		else
			n = 1
		end
		
		local x0 = (dialogWindow.width - buttonWidth * n - (n-1) * spaceWidth) / 2
		
		local buttons = {}
		
		for i = 1,n do
			buttons[i] = Chili.Button:New{
				parent = dialogWindow,
				x = x0 + (i - 1) * (buttonWidth + spaceWidth),
				y = dialogWindow.height - buttonHeight - 30,
				width = buttonWidth,
				height = buttonHeight,
				skinName = 'DarkGlass',
				focusColor = {1,0.5,0,0.5},
				OnClick = {sanitizer:AsHandler(function() parentHandler(false); hideWindow(dialogWindow) end)}
			}
		end
	
		if dialogType == ERROR_TYPE then
			buttons[1].caption = "OK"
			return
		end
		
		if dialogType == Dialog.OK_CANCEL_TYPE then
			buttons[1].caption = "OK"
			buttons[1].OnClick[2] = sanitizer:AsHandler(callbackFunction)
			
			buttons[2].caption = "Cancel"
			return
		end
	
		if dialogType == Dialog.YES_NO_CANCEL_TYPE then
			buttons[1].caption = "Yes"
			buttons[1].OnClick[2] = sanitizer:AsHandler(function() callbackFunction(true) end)
			
			buttons[2].caption = "No"
			buttons[2].OnClick[2] = sanitizer:AsHandler(function() callbackFunction(false) end)
			
			buttons[3].caption = "Cancel"
		end
	end
		
	
	local function setUpDialog(parentHandler, callbackFunction, title, message, dialogType, x, y)
		local width = 400
		local height = 185
		
		local dialogWindow = Chili.Window:New{
			parent = Chili.Screen0,
			x = x or 300,
			y = y or 500,
			width = width,
			height = height,
			padding = {10,10,10,10},
			draggable = true,
			resizable = false,
			skinName = 'DarkGlass',
		}
		
		local titleLabel = Chili.Label:New{
			parent = dialogWindow,
			x = 20,
			y = 5,
			height = 30,
			width = '90%',
			caption = title,
			skinName = 'DarkGlass',
		}
		
		local messageLabel = Chili.Label:New{
			parent = dialogWindow,
			x = 20,
			y = 40,
			height = 30,
			width = '90%',
			caption = message,
			skinName = 'DarkGlass',
		}
		
		if dialogType == ERROR_TYPE then
			dialogWindow.backgroundColor = {1,0,0,1}
		else
			dialogWindow.backgroundColor = {1,1,1,1}
		end
		
		createButtons(dialogWindow, parentHandler, callbackFunction, dialogType)
		parentHandler(true)
	end
	
	function Dialog.showDialog(parentHandler, callbackFunction, title, message, dialogType, x, y)
		local callbackFunction = Sanitizer.sanitize(callbackFunction)
		setUpDialog(parentHandler, callbackFunction, title, message, dialogType, x, y)
	end
	
	function Dialog.showErrorDialog(parentHandler, title, message, x, y)
		setUpDialog(parentHandler, nil, title, message, ERROR_TYPE, x, y)
	end
	
	return Dialog
end)