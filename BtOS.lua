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
local Dependency
local function localizeUtils()
	Dependency = Utils.Dependency
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
			visualiser.window:SetPos(screenWidth - visualiser.window.width, 50)
			
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
			label.font.color = state[widgetName] and {0,1,0,1} or (widgetHandler.knownWidgets[widgetName].active and {1,1,0,1} or {1,0,0,1})
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