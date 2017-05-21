local BtCheat = {}

local sanitizer = Utils.Sanitizer.forCurrentWidget()
local Chili = Utils.Chili

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

local expectedCommand


local CONSTANTS = {
	pauseCMD = "Pause",
	speedUpCMD = "SpeedUp",
	slowDownCMD = "SlowDown",
	giveCMD = "give",
	ffButton = {
		whenSlow = ">>>>>",
		whenFast = "Stop",
	},
	defaultFFSpeed = 5,
	normalSpeed = 1,
	cheatInputCMDName = "BETS_CHEAT_POSITION",
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


-- this returns one ally unit. 
local function getDummyAllyUnit()
	local allUnits = Spring.GetTeamUnits(Spring.GetMyTeamID())
	return allUnits[1]
end

function giveListener(self)

	local inputCommandsTable = BtCommands.inputCommands
	local f = function()
		local ret = spSetActiveCommand(  spGetCmdDescIndex(inputCommandsTable[ CONSTANTS.cheatInputCMDName ]) ) 
		if(ret == false ) then 
			Logger.log("commands", "BtCheats: Unable to set command active: " , CONSTANTS.cheatInputCMDNamee) 
		end
	end
	
	-- if there are no units selected, ...
	if(not spGetSelectedUnits()[1])then
		-- select one
		spSelectUnits({ getDummyAllyUnit() })
		-- wait until return to Spring to execute f
		Timer.delay(f)
	else
		f() -- execute synchronously
	end
--[[	
	expectedCommand = {
		unitName = "armpw",
		countStr = "10",
		teamStr = "0",
	}
	--]]
end

function BtCheat.onFrame()	
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

function BtCheat.gamePaused()
	local userSpFac,spFac, paused = Spring.GetGameSpeed()
	Spring.Echo("paused: " .. tostring(userSpFac) .. ", " .. tostring(spFac) .. ", ".. tostring(paused) )
end

function BtCheat.show()
	cheatWindow:Show()
end
function BtCheat.hide()
	cheatWindow:Hide()
end

function BtCheat.commandNotify(cmdID,cmdParams)
	local inputCommandsTable = BtCommands.inputCommands 
	Logger.log("commands", "cheat", dump(inputCommandsTable[cmdID],2 ) ) 
	if(inputCommandsTable[cmdID] and inputCommandsTable[cmdID] == CONSTANTS.cheatInputCMDName) then
		--- spawn units
		local positionStr = "@"..cmdParams[1]..","..cmdParams[2]..","..cmdParams[3]
		local unitNameStr =  "armpw"
		local countStr = "10"
		local teamStr = "0"
		local commandAll = CONSTANTS.giveCMD .. " "
			.. countStr ..  " " 
			.. unitNameStr .." "
			..teamStr.." "
			..  positionStr
		Logger.log("commands", "cheat: " , commandAll)
		spSendCommand(commandAll)
		return true
	end
	return false
end

function BtCheat.init()
	local Screen0 = Chili.Screen0	
	speed = CONSTANTS.defaultFFSpeed
	
	cheatWindow = Chili.Window:New{
		parent = Screen0,
		x = Screen0.width - 150,
		y = '30%',
		width  = 150 ,
		height = 150,	
			padding = {10,10,10,10},
			draggable=true,
			resizable=false,
			skinName='DarkGlass',
	}
	cheatWindow:Hide()
	
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
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		tooltip = "Give units (ARMPW) on specified position.",
		OnClick = { sanitizer:AsHandler(giveListener)},
	}
--[[	
	giveEnemyButton  = Chili.Button:New{
		parent = cheatWindow ,
		caption = "Give enemy",
		x = 5,
		y = 75,
		width = 120,
		skinName='DarkGlass',
		focusColor = {1.0,0.5,0.0,0.5},
		tooltip = "Give enemy unit (ARMPW) on specified position.",
		OnClick = { sanitizer:AsHandler(giveListener)},
	}
	--]]
	
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