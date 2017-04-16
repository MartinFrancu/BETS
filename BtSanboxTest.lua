function widget:GetInfo()
  return {
    name    = "BtSandboxTest",
    desc    = "Widget to aid user with sandbox features during debugging.",
    author  = "BETS team",
    date    = "today",
    license = "GNU GPL v2",
    layer   = 0,
    enabled = true
  }
end

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
local Chili, Screen0

local Debug = Utils.Debug;
local Logger = Debug.Logger
local dump = Debug.dump

local cheatWindow
local nameLabel
local pauseButton

function widget:Initialize()	
	-- Get ready to use Chili
	Chili = WG.ChiliClone
	Screen0 = Chili.Screen0	
	
	cheatWindow = Chili.Window:New{
		parent = Screen0,
		x = Screen0.width - 150,
		y = '30%',
		width  = 150 ,
		height = 100,	
			padding = {10,10,10,10},
			draggable=true,
			resizable=false,
			skinName='DarkGlass',
		}
	--[[
	nameLabel = Chili.Label:New{
    parent = treeControlWindow,
	x = CONSTANTS.windowFrameGap ,
	y = 0 ,
    width  = 50,
    height = CONSTANTS.labelHeight,
    caption = "BtController",
		skinName='DarkGlass',
	}
	--]]
	
	pauseButton =  Chili.Button:New{
		parent = cheatWindow ,
		caption = "Pause/Unpause",
		x = 10,
		y = 5,
		width = 120,
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		tooltip = "Pause/Unpause button",
	}
	-- Create the window
end