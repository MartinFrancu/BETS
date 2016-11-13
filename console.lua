local _G = loadstring("return _G")()

local console = WG.Console or WG.console or {}
WG.Console = console; WG.console = console

if (widget and not widget.GetInfo) then
	function widget:GetInfo()
		return {
			name    = "Lua Console",
			desc    = "Widget for executing arbitrary Lua commands and for customizable logging and reporting of events and errors of other widgets.",
			author  = "Michal Mojzík",
			date    = "2016-11-02",
			license = "GNU GPL v2",
			layer   = 0,
			enabled = true
		}
	end
	 
	local KEYSYMS = _G.KEYSYMS --[[{
		ESCAPE   = 27,
		RETURN   = 13,
		KP_ENTER = 271,

		UP       = 273,
		DOWN     = 274,
		RIGHT    = 275,
		LEFT     = 276,
		
		F8       = 289,
		F9       = 290,
	}]]
	 
	local RELOAD_KEY = KEYSYMS.F8
	local TOGGLE_VISIBILITY_KEY = KEYSYMS.F9;
	
	local Chili, ChiliRoot
	 
	local history = {}
	local commandCount = 0
	local currentCommand = 1
	 
	local consolePanel, commandInput, consoleLog
	 
	local CONSOLE_SETTINGS = LUAUI_DIRNAME .. "Config/console.lua"
	 
	-- Include debug functions, copyTable() and dump()
	local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
	
	local Debug = Utils.Debug
	local Logger, dump = Debug.Logger, Debug.dump
	
	local function loadSettings()
		if(VFS.FileExists(CONSOLE_SETTINGS))then
			local settings = VFS.Include(CONSOLE_SETTINGS, {}, VFS.RAW_FIRST)
			history = settings.history
			commandCount = #history
			currentCommand = commandCount + 1
		end
	end
	
	local function storeSettings()
		local settingsFile = io.open(CONSOLE_SETTINGS, "w")
		if(settingsFile == nil)then return end
		
		settingsFile:write("return {\n")
		settingsFile:write("  history = {\n")
		for i,v in ipairs(history) do
			settingsFile:write("    " .. string.format("%q", v) .. ",\n")
		end
		settingsFile:write("  },\n")
		settingsFile:write("}\n")
		
		settingsFile:close()
	end
	
	local function addLine(command, resultType, value)
		if(consoleLog.justCleared)then
			consoleLog.justCleared = false
			return
		end
	
		local commandLabel = Chili.Label:New{
			autosize = true,
			x = 0, y = 0,
			font = { size = 16, color = {1,1,1,1} },
			caption = _G.YellowStr .. "> " .. command
		}
		local valueLabel
		
		if(value)then
			valueLabel = Chili.Label:New{
				autosize = true,
				x = 0,
				y = commandLabel.height,
				font = { size = 16, color = {1,1,1,1} },
				caption = ((resultType == "error") and _G.RedStr or "") .. tostring(dump(value))
			}
		end

		Chili.Control:New{
			parent = consoleLog,
			x = 0,
			y = 0,
			padding = {0,0,0,0},
			autosize = true,
			children = {
				commandLabel,
				valueLabel
			}
		}:UpdateLayout()
		
		local childrenCount = #consoleLog.children
		local totalHeight = 0
		for i = childrenCount, 1, -1 do
			local v = consoleLog.children[i]
			v:SetPos(0, totalHeight)
			totalHeight = totalHeight + v.height
		end
	end
	
	local function memorizeCommand(commit)
		local text = commandInput.text
		if(text == "")then
			currentCommand = commandCount + 1
		else
			if(history[currentCommand] ~= text and currentCommand <= commandCount)then
				currentCommand = commandCount + 1
			end
			history[currentCommand] = text
			if(commit)then
				commandCount = math.max(currentCommand, commandCount)
				
				storeSettings()
			end
		end
	end
	
	local function resetCommand()
		memorizeCommand(true)
		commandInput:SetText("")
	end
	
	local function stepCommand(direction)
		memorizeCommand(false)
		if(history[currentCommand + direction])then
			currentCommand = currentCommand + direction
			commandInput:SetText(history[currentCommand])
			commandInput.cursor = history[currentCommand]:len() + 1
		elseif(direction > 0 and currentCommand <= commandCount)then
			commandInput:SetText("")
		end
	end
	
	local consoleContext = { }
	consoleContext._G = consoleContext
	consoleContext.history = history
	consoleContext.Logger = Logger
	consoleContext.widget = widget
	function consoleContext.clear()
		consoleLog:ClearChildren()
		consoleLog.justCleared = true
		history = {}
		commandCount = 0
		currentCommand = 1
		storeSettings()
		commandInput:SetText("")
	end
	setmetatable(consoleContext, { __index = function(t, key)
			local value = WG[key]
			if(value ~= nil)then
				return value
			else
				return _G[key]
			end
		end })
	local function runCommand(text)
		-- attempt to compile te chunk as an epxression
		local isExpression, command, msg = true, loadstring("return ("..text..")")
		if(not command)then -- if that fails, compile it regularly (which doesn't provide as with a result value, only nil)
			isExpression, command, msg = false, loadstring(text)
		end
		
		if(command)then
			setfenv(command, consoleContext)
			local success, result = pcall(command)
			if(success)then
				if(isExpression or result ~= nil)then
					addLine(text, "result", result)
				else
					addLine(text, "result", nil)
				end
				return nil
			else
				msg = result
			end
		end

		-- error occured
		addLine(text, "error", msg)
	end
	
	local function handleGlobalHotkey(element, key, modifiers, isRepeat)
		if (not isRepeat) then
			if (key == TOGGLE_VISIBILITY_KEY) then
				consolePanel:ToggleVisibility()
				if (commandInput.visible) then
					ChiliRoot:FocusControl(commandInput)
				else
					ChiliRoot:FocusControl(nil)
				end
				return true;
			elseif (key == RELOAD_KEY) then
				Spring.SendCommands("luaui reload")
			end
		end
	end

	local function injectConsole()
	end
	
	local function restoreConsole()
	end
	
	function widget:Initialize()	
		if (not WG.ChiliClone) then
			-- don't run if we can't find Chili
			widgetHandler:RemoveWidget()
			return
		end
	 
		loadSettings()
	 
		-- Get ready to use Chili
		Chili = WG.ChiliClone
		ChiliRoot = Chili.Screen0	
		
		consolePanel = Chili.Panel:New{
			parent = ChiliRoot,
			x = '20%',
			y = '12%',
			width = '30%',
			height = '40%',
			padding = {5, 5, 5, 5},
			backgroundColor = {0,0,0,0},
		}
		
		commandInput = Chili.EditBox:New{
			parent = consolePanel,
			width = '100%',
			height = 30,
			padding = {5, 2, 5, 2},
			skinName = 'DarkGlass',
			backgroundColor = { 0, 0, 0, 1 },
			focusColor = { 1, 1, 1, 1 },
			cursorColor = { 1, 1, 1, 0.5 },
			borderColor = { 0.5, 0.5, 0.5, 1 },
			borderColor2 = { 0.5, 0.5, 0.5, 1 },
			font = { size = 20 },
			OnKeyPress = {
				function(element, key, modifiers, isRepeat)
					-- Spring.Echo(dump(element) .. ", " .. tostring(key) .. ", " .. dump(modifiers))
					if(key == KEYSYMS.RETURN or key == KEYSYMS.KP_ENTER)then
						runCommand(commandInput.text)
						resetCommand()
					elseif(key == KEYSYMS.UP)then
						stepCommand(-1)
					elseif(key == KEYSYMS.DOWN)then
						stepCommand(1)
					else
						return handleGlobalHotkey(element, key, modifiers, isRepeat)
					end
					return true;
				end
			}
		}
		consoleContext.self = commandInput
		
		consoleLog = Chili.ScrollPanel:New{
			parent = consolePanel,
			x = '5%',
			y = '0',
			width = '90%',
			height = '100%',
			padding = {7, 35, 7, 7},
			backgroundColor = {0, 0, 0, 1},
		}
		
		consolePanel:Hide()
		
		injectConsole()
	end
	
	function widget:Shutdown()
		restoreConsole()
	end

	widget.KeyPress = handleGlobalHotkey
else
end

return console