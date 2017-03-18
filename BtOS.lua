function widget:GetInfo()
	return {
		name    = "BtOS",
		desc    = "TODO",
		author  = "BETS Team",
		date    = "2016-09-01",
		license = "GNU GPL v2",
		layer   = 0,
		handler = true,
		enabled = true
	}
end

local _G = loadstring("return _G")()
local KEYSYMS = _G.KEYSYMS
local DISABLE_KEY = KEYSYMS.F10

local Chili, ChiliRoot
local getFrame = Spring.GetGameFrame
 
local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
local Dependency, Logger
local function localizeUtils()
	Dependency = Utils.Dependency
	Logger = BtUtils.Debug.Logger
end
localizeUtils()

local widgets = {
	BtEvaluator = true,
	BtCommands = true,
	BtController = true,
	BtCreator = true,
}
local widgetCount = 0
for _ in pairs(widgets) do widgetCount = widgetCount + 1 end

local state = {}
WG.state = state
local TEXT_HEIGHT = 20

local initializeDependencyHooks

local visualiser;
local function updateVisualiser()
	local show = false
	for widgetName in pairs(widgets) do
		if(state[widgetName] == false)then
			show = true
		end
	end
	
	if(show)then
		if(not visualiser)then
			local screenWidth, screenHeight = gl.GetViewSizes()
			visualiser = {}
			visualiser.window = Chili.Window:New{
				parent = ChiliRoot,
				width = 200,
				height = widgetCount * TEXT_HEIGHT + 7*TEXT_HEIGHT/2,
				caption = "BtOS",
				skinName = 'DarkGlass',
				backgroundColor = {0,0,0,1},
			}
			visualiser.window:SetPos(screenWidth - visualiser.window.width, 200)
			
			local top = 0
			for widgetName in pairs(widgets) do
				local label = Chili.Label:New{
					parent = visualiser.window,
					x = 10,
					y = top,
					caption = widgetName,
					OnMouseDown = { function(self)
						if(state[widgetName])then
							widgetHandler:DisableWidget(widgetName)
						else
							widgetHandler:EnableWidget(widgetName)
						end
						updateVisualiser()
						return self
					end },
				}
				visualiser[widgetName] = label
				top = top + TEXT_HEIGHT
			end
			
			visualiser.button = Chili.Button:New{
				parent = visualiser.window,
				x = '25%',
				y = top + TEXT_HEIGHT / 2,
				width = '50%',
				caption = "Reload",
				OnClick = { function(self)
					for widgetName in pairs(widgets) do
						widgetHandler:DisableWidget(widgetName)
					end
					
					-- reload stuff
					BtUtils:Reload()
					localizeUtils()
					initializeDependencyHooks()
					initializedAt = getFrame()
					
					for widgetName in pairs(widgets) do
						widgetHandler:EnableWidget(widgetName)
					end
					return self
				end }
			}
		end
		
		for widgetName in pairs(widgets) do
			local label = visualiser[widgetName]
			label.font.color = state[widgetName] and {0,1,0,1} or (((widgetHandler.knownWidgets or {})[widgetName] or {}).active and {1,1,0,1} or {1,0,0,1})
			label:Invalidate()
		end
	elseif(visualiser)then
		visualiser.window:Dispose()
		visualiser = nil
	end
end

function initializeDependencyHooks()
	for widgetName in pairs(widgets) do
		Dependency.defer(function()
				state[widgetName] = true
				updateVisualiser()
			end, function()
				state[widgetName] = false
				updateVisualiser()
				return true
			end, Dependency[widgetName]
		)
	end
end


-- ============ Error reporting

local function injectErrorReporter()
	local padding = 10
	local currentLogType
	local currentMessage
	local errorPanel = Chili.Panel:New{
		parent = ChiliRoot,
		x = '100%',
		y = '50%',
		width = 500,
		skinName = 'DarkGlass',
		OnMouseDown = { function(self) self:BringToFront() end }
	}
	_G.errorPanel = errorPanel
	local messageLabel = Chili.Label:New{
		parent = errorPanel,
		x = padding,
		y = padding,
		valign = "top",
		width = errorPanel.width - 2 * padding,
		autosize = false,
	}
	local additionalErrorsLabel = Chili.Label:New{
		parent = errorPanel,
		x = padding * 2,
		caption = "Additional errors:",
	}
	local additionalWarningsLabel = Chili.Label:New{
		parent = errorPanel,
		x = padding * 2,
		caption = "Additional warnings:",
	}
	local additionalErrors = {}
	local additionalWarnings = {}
	local confirmButton = Chili.Button:New{
		parent = errorPanel,
		caption = "OK",
		OnClick = { function()
			currentLogType = nil
			for _, d in ipairs(additionalErrors) do
				local l = d.label
				errorPanel:RemoveChild(l)
				l:Dispose()
			end
			for _, d in ipairs(additionalWarnings) do
				local l = d.label
				errorPanel:RemoveChild(l)
				l:Dispose()
			end
			additionalErrors = {}
			additionalWarnings = {}
			if(additionalErrorsLabel.visible)then
				additionalErrorsLabel:Hide()
			end
			if(additionalErrorsLabel.visible)then
				additionalWarningsLabel:Hide()
			end
			errorPanel:Hide()
		end },
	}
	local disabled = false;
	local disableButton = Chili.Button:New{
		parent = errorPanel,
		caption = "Disable reporting",
		width = confirmButton.font:GetTextWidth("Disable reporting") + 20,
		OnClick = { function()
			disabled = true
		end }
	}
	additionalErrorsLabel:Hide()
	additionalWarningsLabel:Hide()
	errorPanel:Hide()
	
	local function handler(logGroup, logType, message)
		if(disabled or logType == Logger.LOGTYPE_DEFAULT)then
			return
		end
		
		if(not errorPanel.visible or logType > (currentLogType or 0))then
			local lastLogType = currentLogType
			local lastLogGroup = currentLogGroup
			currentLogType = logType
			currentLogGroup = logGroup
			local screenWidth, screenHeight = gl.GetViewSizes()
			local color = logType == Logger.LOGTYPE_WARNING and {0.75, 0.5, 0, 1} or { 0.75, 0, 0, 1 }
			errorPanel.backgroundColor = color
			messageLabel:SetPos(messageLabel.x, messageLabel.y, messageLabel.width, 1000000)
			messageLabel:SetCaption(debug.traceback("[" .. logGroup .. "] " .. message .. "\n", 3))
			local h, d = messageLabel.font:GetTextHeight(messageLabel._caption)
			local height = h - d
			local y = padding
			messageLabel:SetPos(messageLabel.x, messageLabel.y, messageLabel.width, height + padding)
			y = y + padding + height
			confirmButton:SetPos(padding * 3, y)
			disableButton:SetPos(errorPanel.width - 3 * padding - disableButton.width, y)
			y = y + padding + confirmButton.height + padding
			errorPanel:SetPos(screenWidth - errorPanel.width, screenHeight - 100 - y --[[(screenHeight - y) / 2]], errorPanel.width, y)
			errorPanel:Show()
			
			if(lastLogType)then
				handler(lastLogGroup, lastLogType, "")
			end
		else
			local additionalLabel, additionals
			if(logType == Logger.LOGTYPE_ERROR)then
				additionalLabel = additionalErrorsLabel
				additionals = additionalErrors
			else
				additionalLabel = additionalWarningsLabel
				additionals = additionalWarnings
			end
			for _, d in ipairs(additionals) do
				if(d.logGroup == logGroup)then
					d.count = d.count + 1
					d.label:SetCaption(logGroup .. (d.count > 1 and (" x" .. tostring(d.count))))
					return
				end
			end
			
			local heightIncrease = 0
			if(not additionalLabel.visible)then
				additionalLabel:SetPos(padding * 2, confirmButton.y)
				additionalLabel:Show()
				heightIncrease = heightIncrease + additionalLabel.height + padding
			end
			local follow = additionals[#additionals] and additionals[#additionals].label or additionalLabel
			local newLabel = Chili.Label:New{
				parent = errorPanel,
				x = padding * 5,
				y = follow.y + follow.height,
				caption = logGroup
			}
			table.insert(additionals, { logGroup = logGroup, count = 1, label = newLabel })
			heightIncrease = heightIncrease + newLabel.height
			confirmButton:SetPos(confirmButton.x, confirmButton.y + heightIncrease)
			disableButton:SetPos(disableButton.x, disableButton.y + heightIncrease)
			errorPanel:SetPos(errorPanel.x, errorPanel.y - heightIncrease, errorPanel.width, errorPanel.height + heightIncrease)
		end
		errorPanel:BringToFront()
	end
	
	Logger.registerHandler(handler)
end
	
-- ============ /Error reporting


local initializedAt
function widget:Initialize()
	if (not WG.ChiliClone) then
		-- don't run if we can't find Chili
		widgetHandler:RemoveWidget()
		return
	end
 
	Chili = WG.ChiliClone
	ChiliRoot = Chili.Screen0
	
	initializedAt = getFrame()
	
	initializeDependencyHooks()
	injectErrorReporter()
	
	for widgetName in pairs(widgets) do
		widgetHandler:EnableWidget(widgetName)
	end
end


function widget:Update()
	if(initializedAt)then
		local frameNumber = getFrame()
		if(frameNumber - initializedAt > 50)then
			for widgetName in pairs(widgets) do
				state[widgetName] = state[widgetName] or false -- convert nils to false
			end
			updateVisualiser()
			initializedAt = nil
		end
	end
end

function widget:KeyPress(key, modifiers, isRepeat)
	if (not isRepeat) then
		if (key == DISABLE_KEY) then
			for widgetName in pairs(widgets) do
				widgetHandler:DisableWidget(widgetName)
			end
		end
	end
end

return widget