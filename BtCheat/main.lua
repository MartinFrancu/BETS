local BtCheat = {}

local sanitizer = Utils.Sanitizer.forCurrentWidget()
local Chili = Utils.Chili


local JSON = Utils.JSON
local Timer = Utils.Timer;
local Debug = Utils.Debug;
local Logger = Debug.Logger
local dump = Debug.dump
local Dependency = Utils.Dependency

local cheatWindow
local nameLabel
local pauseButton
local fastForwardButton
local speedLabel
local upSpeedButton
local downSpeedButton
local ffState -- nill - nothing, not fastforwargin, acc = accelerrating, ff when fast forwarding, stop = slowing down
local speed

local giveButton
local unitEditBox --unitCombobox
local teamCombobox
local godModeCheckbox

local expectedCommand



local CONSTANTS = {
	pauseCMD = "Pause",
	speedUpCMD = "SpeedUp",
	slowDownCMD = "SlowDown",
	giveCMD = "give",
	godmodeCMD = "godmode",
	ffButton = {
		whenSlow = ">>>>>",
		whenFast = "Stop",
	},
	defaultFFSpeed = 5,
	normalSpeed = 1,
	cheatInputCMDName = "BETS_CHEAT_POSITION",
	giveHowMany = 5,
}

local spSendCommand = Spring.SendCommands
--local spGetTimer = Spring.GetTimer
---local spDiffTimes = Spring.DiffTimers
local spGetCmdDescIndex = Spring.GetCmdDescIndex
local spSetActiveCommand = Spring.SetActiveCommand
local spGetSelectedUnits = Spring.GetSelectedUnits
local spSelectUnits = Spring.SelectUnitArray


function pauseGameListener()
	spSendCommand(CONSTANTS.pauseCMD)
end

function upSpeedListener(self) 
	speed = speed + 1
	local spStr = tostring(speed) .. "x" 
	self.speedLabel:SetCaption(spStr)
end
function downSpeedListener(self) 
	speed = speed - 1
	if(speed < 1) then 
		speed = 1
	end
	local spStr = tostring(speed) .. "x" 
	self.speedLabel:SetCaption(spStr)
end

function fastForwardButtonListener(self)
	if( ffState == nil or ffState == "stop" ) then 
		-- we should speed up, button was hit in calm state or when already stopping
		ffState = "acc"
		self:SetCaption(CONSTANTS.ffButton.whenFast)
	else -- button was hit when something was already happening - user probably want to slow it down
		ffState = "stop"
		self:SetCaption(CONSTANTS.ffButton.whenSlow)
	end
end

local function spawnUnits(unitName, howMany, team, position)
	local positionStr = "@"..position[1]..","..position[2]..",".. position[3]
	
	local commandAll = CONSTANTS.giveCMD .. " "
			.. tostring(howMany) ..  " " 
			.. unitName .." "
			.. tostring(team) .." "
			..  positionStr
	spSendCommand(commandAll)
end 
local function positionSpecifiedCallback(data) 
	spawnUnits( 
		unitEditBox.text,
		CONSTANTS.giveHowMany, 
		teamCombobox.items[teamCombobox.selected], 
		data)
end  


function giveListener(self)
	BtCommands.getInput(CONSTANTS.cheatInputCMDName,  positionSpecifiedCallback)
end

function widget:GameFrame()
	local userSpFac,spFac, paused = Spring.GetGameSpeed()
	
	if ffState ~= nil then -- something is happening
		if(ffState == "acc") then
			if(userSpFac < speed) then
				spSendCommand(CONSTANTS.speedUpCMD)
			else
				ffState = "ff"
			end
		end
		if(ffState == "stop") then 
			if(userSpFac > CONSTANTS.normalSpeed) then
				spSendCommand(CONSTANTS.slowDownCMD)
			else
				ffState = nil
			end
		end
	end
end

function widget:GamePaused()
	local userSpFac,spFac, paused = Spring.GetGameSpeed()
	Spring.Echo("paused: " .. tostring(userSpFac) .. ", " .. tostring(spFac) .. ", ".. tostring(paused) )
end

local function godMode()	
	Logger.log("cheat", "here we are")
	spSendCommand(CONSTANTS.godmodeCMD)
end

function widget:Initialize()
	local Screen0 = Chili.Screen0	
	speed = CONSTANTS.defaultFFSpeed
	
	cheatWindow = Chili.Window:New{
		parent = Screen0,
		x = Screen0.width - 150,
		y = '30%',
		width  = 150 ,
		height = 200,	
			padding = {10,10,10,10},
			draggable=true,
			resizable=false,
			skinName='DarkGlass',
	}
	
	pauseButton =  Chili.Button:New{
		parent = cheatWindow ,
		caption = "Pause/Unpause",
		x = 5,
		y = 5,
		width = 120,
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		tooltip = "Pause/Unpause game",
		OnClick = {sanitizer:AsHandler(pauseGameListener)}
	}
	
	fastForwardButton =  Chili.Button:New{
		parent = cheatWindow ,
		caption = CONSTANTS.ffButton.whenSlow,
		x = 5,
		y = 25,
		width = 120,
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		tooltip = "Start/stop fast forward",
		OnClick = { sanitizer:AsHandler(fastForwardButtonListener)}
	}
	
	speedLabel = Chili.Label:New{
		parent = cheatWindow ,
		caption = tostring(speed) .. "x",
		x = 20,
		y = 50,
		width = 40,
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		tooltip = "Set speed multiplier",
	}

	upSpeedButton  = Chili.Button:New{
		parent = cheatWindow ,
		caption = "+",
		x = 50,
		y = 45,
		width = 30,
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		tooltip = "Increase fast-forward speed",
		OnClick = { sanitizer:AsHandler(upSpeedListener)},
		speedLabel = speedLabel,
	}
	downSpeedButton  = Chili.Button:New{
		parent = cheatWindow ,
		caption = "-",
		x = 80,
		y = 45,
		width = 30,
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		tooltip = "Decrease fast-forward speed",
		OnClick = { sanitizer:AsHandler(downSpeedListener)},
		speedLabel = speedLabel,
	}
	
	giveButton  = Chili.Button:New{
		parent = cheatWindow ,
		caption = "Give",
		x = 5,
		y = 75,
		width = 120,
		height = 35,
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		tooltip = "Give units (ARMPW) on specified position.",
		OnClick = { sanitizer:AsHandler(giveListener)},
	}
	
	local unitLabel = Chili.Label:New{
		parent = cheatWindow,
		x = giveButton.x + 5 ,
		y = giveButton.y + giveButton.height + 3,
		width = 60,
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		caption = "Unit:",
	}
	
	
	unitEditBox = Chili.EditBox:New{	
		parent = cheatWindow,
		x = unitLabel.x + unitLabel.width,
		y = unitLabel.y - 2,
		width = 80,
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		tooltip = "Select unit type to be given",
		text = "armpw"
	}
	local teamLabel = Chili.Label:New{
		parent = cheatWindow,
		x = unitLabel.x,
		y = unitLabel.y + unitLabel.height+ 15,
		width = 60,
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		caption = "Team:",
	}
	
	local teams = Spring.GetTeamList()
	local teamItems = {}
	for _,teamId in ipairs(teams) do
		table.insert(teamItems, tostring(teamId) )
	end	
	
	teamCombobox = Chili.ComboBox:New{	
		parent = cheatWindow,
		x = teamLabel.x + teamLabel.width,
		y = teamLabel.y-3,
		width = 60,
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		tooltip = "Select unit type to be given",
		items = teamItems
	}
	
	godModeCheckbox = Chili.Checkbox:New{
		parent = cheatWindow,
		x = teamLabel.x,
		y = teamLabel.y + teamLabel.height + 5,
		width = 100,
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		tooltip = "Godmode allows you to command enemy units.",
		checked = false,
		caption = "Godmode",
		OnChange = {sanitizer:AsHandler(godMode)}
	}

	
	Dependency.defer(
		function() 
			BtCommands = sanitizer:Import(WG.BtCommands) 
		end, 
		function() 
			BtCommands = nil 
		end,
		Dependency.BtCommands)
	
end


return BtCheat