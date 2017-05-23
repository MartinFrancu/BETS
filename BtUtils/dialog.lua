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
	
	local BUTTON_NAMES = {
		YES = "Yes",
		NO = "No",
		CANCEL = "Cancel",
		OK = "OK",
	}
	
	Dialog.YES_NO_CANCEL_TYPE = "YES_NO"
	Dialog.OK_CANCEL_TYPE = "OK_CANCEL"
	
	local ERROR_TYPE = "ERROR"
	
	local function hideWindow(window) 
		if window.visible then
			window:Hide()
		end
		window:Dispose()
	end
	
	local function createButtons(dialogWindow, visibilityHandler, callbackFunction, dialogType, buttonNames)
		buttonNames = buttonNames or BUTTON_NAMES
		
		local sanitizer = Sanitizer.forCurrentWidget()
		
		local buttonWidth = 100
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
				OnClick = {sanitizer:AsHandler(function() visibilityHandler(false); hideWindow(dialogWindow) end)}
			}
		end
	
		if dialogType == ERROR_TYPE then
			buttons[1].caption = buttonNames.OK or BUTTON_NAMES.OK
			return
		end
		
		if dialogType == Dialog.OK_CANCEL_TYPE then
			buttons[1].caption = buttonNames.OK or BUTTON_NAMES.OK
			buttons[1].OnClick[2] = sanitizer:AsHandler(callbackFunction)
			
			buttons[2].caption = buttonNames.CANCEL or BUTTON_NAMES.CANCEL
			return
		end
	
		if dialogType == Dialog.YES_NO_CANCEL_TYPE then
			buttons[1].caption = buttonNames.YES or BUTTON_NAMES.YES
			buttons[1].OnClick[2] = sanitizer:AsHandler(function() callbackFunction(true) end)
			
			buttons[2].caption = buttonNames.NO or BUTTON_NAMES.NO
			buttons[2].OnClick[2] = sanitizer:AsHandler(function() callbackFunction(false) end)
			
			buttons[3].caption = buttonNames.CANCEL or BUTTON_NAMES.CANCEL
		end
	end
		
	
	local function setUpDialog(visibilityHandler, callbackFunction, title, message, dialogType, buttonNames, x, y)
		visibilityHandler = visibilityHandler and Sanitizer.sanitize(visibilityHandler) or function() end
		callbackFunction = callbackFunction and Sanitizer.sanitize(callbackFunction) or function() end 
	
		local width = 400
		local height = 100
		
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
			maxWidth = 0.9 * dialogWindow.width,
			caption = title,
			skinName = 'DarkGlass',
			autosize = true,
		}
		
		local messageLabel = Chili.Label:New{
			parent = dialogWindow,
			x = 20,
			y = titleLabel.y + titleLabel.height + 15,
			maxWidth = 0.9 * dialogWindow.width,
			caption = message,
			skinName = 'DarkGlass',
			autosize = true,
		}
		
		local newheight = messageLabel.y + messageLabel.height + 75
		if(height < newheight)then
			dialogWindow:SetPos(nil, nil, nil, newheight)
		end
		Spring.Echo(newheight)
		
		if dialogType == ERROR_TYPE then
			dialogWindow.backgroundColor = {1,0,0,1}
		else
			dialogWindow.backgroundColor = {1,1,1,1}
		end
		WG.dialogWindow = dialogWindow
		
		createButtons(dialogWindow, visibilityHandler, callbackFunction, dialogType, buttonNames)
		visibilityHandler(true)
	end
	
	function Dialog.showDialog(params, callbackFunction)
		setUpDialog(params.visibilityHandler, callbackFunction, params.title, params.message, params.dialogType, params.buttonNames, params.x, params.y)
	end
	
	function Dialog.showErrorDialog(params, callbackFunction)
		setUpDialog(params.visibilityHandler, callbackFunction, params.title, params.message, ERROR_TYPE, params.buttonNames, params.x, params.y)
	end
	
	return Dialog
end)