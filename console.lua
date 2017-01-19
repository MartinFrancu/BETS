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
	 
	local KEYSYMS = _G.KEYSYMS
	 
	local RELOAD_KEY = KEYSYMS.F8
	local TOGGLE_VISIBILITY_KEY = KEYSYMS.F9;
	
	local Chili, ChiliRoot
	 
	local history = {}
	local commandCount = 0
	local currentCommand = 1
	 
	local consolePanel, commandInput, consoleLog
	 
	local CONSOLE_SETTINGS = LUAUI_DIRNAME .. "Config/console.lua"
	 
	-- using BtUtils
	local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
	
	local Debug = Utils.Debug
	local Logger, dump = Debug.Logger, Debug.dump
	
	--- Iterates not only through the regular pairs, but also over the pairs of a metatable
	local function metanext(state, key)
		local k, v = next(state.current, key)
		if(k ~= nil)then
			return k, v
		else
			local mt = getmetatable(state.current)
			if(not mt or type(mt) ~= "table" or type(mt.__index) ~= "table")then
				return nil
			end
			state.current = mt.__index;
			return metanext(state, nil)
		end
	end
	local function metapairs(t)
		if(type(t) == "userdata")then
			local mt = getmetatable(t)
			if(not mt or type(mt.__index) ~= "table")then
				return function() return nil end
			end
			t = mt.__index;
		end
		return metanext, { current = t }, nil
	end
	
	local consoleContext
	local contextNext, contextPairs
	
	local function loadSettings()
		if(VFS.FileExists(CONSOLE_SETTINGS))then
			local settings = VFS.Include(CONSOLE_SETTINGS, {}, VFS.RAW_FIRST)
			history = settings.history
			commandCount = #history
			currentCommand = commandCount + 1
			if(consoleContext)then
				consoleContext.history = history
			end
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
	
	local function addResult(command, resultType, value)
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
		local y = commandLabel.height
		local children = { commandLabel }
		
		if(value or resultType ~= "command")then
			local function makeLine(color, text, indentation, onClick)
				indentation = type(indentation) == "number" and string.rep("  ", indentation or 0) or tostring(indentation or "")
				if(type(color) == "table")then
					color = string.char(color[3], color[2], color[1], color[0])
				else
					color = tostring(string.gsub(tostring(color or ""), "^(%a)(%a*)$", function(a,b) return _G[string.upper(a) .. b .. "Str"] end) or "")
				end
				
				local line = Chili.Label:New{
					autosize = true,
					x = 0,
					y = y,
					font = { size = 16, color = {1,1,1,1} },
					caption = indentation .. color .. text,
					OnMouseOver = onClick and { function(self) self.font.color = {1,1,0,1} self:Invalidate() return self end } or nil,
					OnMouseOut = onClick and { function(self) self.font.color = {1,1,1,1} self:Invalidate() return self end } or nil,
					OnMouseDown = onClick and { function(self) return self end } or nil,
					OnMouseUp = onClick and { onClick } or nil
				}
				table.insert(children, line)
				y = y + line.height
				return line
			end
			
			if(resultType == "error")then
				makeLine("red", value)
			elseif(type(value) == "table" or type(value) == "userdata")then
				local keyList = (value == consoleContext) and contextPairs or metapairs
				local isArray, arraySize, isEmpty = true, 0, true
				for k, _ in keyList(value) do if(type(k) ~= "number" or k < 1)then isArray = false elseif(arraySize < k)then arraySize = k end isEmpty = false end
				if(isArray)then
					keyList = function(t)
						return function(_, x)
							if(x < arraySize)then
								return x + 1, t[x + 1]
							else
								return nil
							end
						end, nil, 0
					end
				end
				if(isEmpty)then
					makeLine("", (type(value) == "userdata") and "<userdata> {}" or "{}")
				else
					makeLine("", (type(value) == "userdata") and "<userdata> {" or (resultType == "multiresult") and "results:" or "{")
					
					local oldCommand = command:gsub(_G.YellowStr, "")
					if(resultType == "multiresult")then
						oldCommand = "{" .. oldCommand .. "}"
					end
					
					for k, v in keyList(value) do
						local text, keyAccess = (type(v) == "table") and "{...}" or dump(v) .. ","
						if(not isArray)then
							if(type(k) == "string" and k:match("^[%a_][%w_]*$"))then
								text = k .. " = " .. text
								keyAccess = ".".. _G.YellowStr .. k
							else
								text = "[" .. dump(k) .. "] = " .. text
								keyAccess = _G.YellowStr .. "[" .. k .. "]"
							end
						else
							keyAccess = _G.YellowStr .. "[" .. k .. "]"
						end
						
						local valueLine = makeLine("", text, 1,
							(type(v) == "table" or type(v) == "function" or type(v) == "userdata") and function(self)
								addResult(_G.GreyStr .. oldCommand .. keyAccess, "info", v)
								ChiliRoot:FocusControl(commandInput)
								return self
							end)
							--[[
							valueLine.evaluationCode = command .. "." .. k
							valueLine.evaluatedObject = v
							]]
					end
					if(resultType ~= "multiresult")then
						makeLine("", "}")
					end
				end
			elseif(type(value) == "function")then
				local success, result = pcall(string.dump, value)
				makeLine("", success and ("<function>" .. result:gsub("[^ -~]", "")) or "<native function>")
			else
				makeLine("", dump(value))
			end
			--[[
			table.insert(children, Chili.Label:New{
				autosize = true,
				x = 0,
				y = y,
				font = { size = 16, color = {1,1,1,1} },
				caption = ((resultType == "error") and _G.RedStr or "") .. tostring(dump(value))
			})
			]]
		end

		Chili.Control:New{
			parent = consoleLog,
			x = 0,
			y = 0,
			padding = {0,0,0,0},
			autosize = true,
			children = children,
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
	
	-- sets up the context that is used as the environment in the console
	consoleContext = { }
	consoleContext._G = consoleContext
	consoleContext.history = history
	consoleContext.Logger = Logger
	consoleContext.widget = widget
	consoleContext.clear = function()
		consoleLog:ClearChildren()
		consoleLog.justCleared = true
		history = {}
		commandCount = 0
		currentCommand = 1
		storeSettings()
		commandInput:SetText("")
		consoleContext.history = history
	end
	consoleContext.Units = {
		armpw = "armpw",
		Peewee = "armpw",
		armrock = "armrock",
		Rocko = "armrock",
		avtr = "avtr",
		Avatar = "avtr",
	}
	consoleContext.spawn = function(unit, count)
		count = count or 1
		Spring.SendCommands("give " .. tostring(count) .. " " .. unit .. " " .. tostring(Spring.GetLocalPlayerID()))
	end
	if(not Spring.IsCheatingEnabled())then
		Spring.SendCommands("cheat")
	end
	setmetatable(consoleContext, { __index = function(t, key)
			local value = WG[key]
			if(value ~= nil)then
				return value
			else
				return _G[key]
			end
		end })
	function contextNext(state, key)
		local k, v = next(state.current, key)
		if(k ~= nil)then
			return k, v
		else
			if(state.current == consoleContext)then
				state.current = WG
			elseif(state.current == WG)then
				state.current = _G
			elseif(state.current == _G)then
				return nil
			end
			return contextNext(state, nil)
		end
	end
	function contextPairs(_)
		return contextNext, { current = consoleContext }, nil
	end
	
	local function runCommand(text)
		-- attempt to compile te chunk as an epxression
		local isExpression, command, msg = true, loadstring("return "..text.."")
		if(not command)then -- if that fails, compile it regularly (which doesn't provide as with a result value, only nil)
			isExpression, command, msg = false, loadstring(text)
		end
		
		if(command)then
			setfenv(command, consoleContext)
			local results = { pcall(command) }
			if(results[1])then
				table.remove(results, 1)
				local resultCount = 0
				for k in pairs(results) do if(resultCount < k)then resultCount = k end end
				if(--[[isExpression or ]]resultCount > 0)then
					if(resultCount > 1)then
						addResult(text, "multiresult", results)
					else
						addResult(text, "result", results[1])
					end
				else
					addResult(text, "command")
				end
				return nil
			else
				msg = results[2]
			end
		end

		-- error occured
		addResult(text, "error", msg)
	end
	
	local function fillInCommand()
		local cursor = commandInput.cursor
		local beforeCursor = commandInput.text:sub(1, cursor - 1)
		local partialProperty = beforeCursor:match("[_%w%.:]+$") or ""
		
		local container = consoleContext
		local keyList = contextPairs
		local get = function(t, key) return t[key] end
		local lastSeparator = "."
		for key, separator in partialProperty:gmatch("([_%w]+)([%.:])") do
			container = get(container, key) --:sub(1, key:len() - 1)
			if(not container or (type(container) ~= "table" and type(container) ~= "userdata"))then
				return false
			end
			get = rawget
			keyList = metapairs
			lastSeparator = separator
		end
		
		local partialKey = string.lower(partialProperty:match("[_%w]*$") or "")
		local partialLength = partialKey:len()
		local candidates, candidateSet, candidateCount = {}, {}, 0
		for k, v in keyList(container) do
			if(type(k) == "string" and string.lower(k:sub(1, partialLength)) == partialKey and not candidateSet[k] and (lastSeparator ~= ":" or type(v) == "function"))then
				table.insert(candidates, k)
				candidateSet[k] = true
				candidateCount = candidateCount + 1
			end
		end
		if(candidateCount == 0)then
			return false
		elseif(candidateCount > 1)then
			addResult(partialProperty .. ".*", "info", candidates)
		else
			local afterCursor = commandInput.text:sub(cursor)
			commandInput:SetText(beforeCursor:sub(1, -partialLength - 1) .. candidates[1] .. afterCursor)
			commandInput.cursor = cursor + candidates[1]:len() - partialLength
		end
		--commandInput:SetText(history[currentCommand])
		--commandInput.cursor = history[currentCommand]:len() + 1
	end
	
	local function handleGlobalHotkey(element, key, modifiers, isRepeat)
		if (not isRepeat) then
			if (key == TOGGLE_VISIBILITY_KEY) then
				consolePanel:ToggleVisibility()
				if (consolePanel.visible) then
					consolePanel:BringToFront()
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
					elseif(key == KEYSYMS.TAB)then
						fillInCommand()
					elseif(key == KEYSYMS.UP)then
						stepCommand(-1)
					elseif(key == KEYSYMS.DOWN)then
						stepCommand(1)
					else
						return handleGlobalHotkey(element, key, modifiers, isRepeat)
					end
					return true;
				end
			},
			editingText = true
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