local ProjectManager = Utils.ProjectManager
local BehaviourTree = Utils.BehaviourTree
local Debug = Utils.Debug;
local Logger = Debug.Logger
local dump = Debug.dump
local Dependency = Utils.Dependency
local sanitizer = Utils.Sanitizer.forWidget(widget)
local Vec3 = Utils.Vec3


BtCommands = {}
BtCommands.inputCommands = {}
BtCommands.behaviourCommands = {}
--------------------------------------------------------------------------------
-- get madatory module operators
VFS.Include("LuaRules/modules.lua") -- modules table
VFS.Include(modules.attach.data.path .. modules.attach.data.head) -- attach lib module

local BehavioursDirectory = "LuaUI/Widgets/BtBehaviours"
local DEFAULT_ICON_NAME = "default"

-- get other madatory dependencies
attach.Module(modules, "message")
attach.Module(modules, "customCommands") -- here you get reference e.g. for sendCustomMessage.registerCustomCommand

--------------------------------------------------------------------------------
--- COMMANDS FOR GETTING PLAYER INPUT ------------------------------------------
--------------------------------------------------------------------------------

local inputCommandDesc = {
	["BETS_POSITION"] = {
		type = CMDTYPE.ICON_MAP,
		name = 'BETS_POSITION',
		cursor = 'Attack',
		--action = 'Convoy',
		tooltip = 'Collects a position input from player.',
		hidden = true,
		humanName = "Position",
		--UIoverride = { texture = 'LuaUI/Images/commands/bold/sprint.png' },
	},
	["BETS_AREA"] = {
		type = CMDTYPE.ICON_AREA,
		name = 'BETS_AREA',
		cursor = 'Attack',
		--action = 'SAD',
		tooltip = 'Collects an area input from player.',
		hidden = true,
		humanName = "Area",
		--UIoverride = { texture = 'LuaUI/Images/commands/bold/sprint.png' },
		--UIoverride = { texture = 'LuaUI/Images/commands/bold/sad.png' },
	},
	["BETS_UNIT"] = {
		type = CMDTYPE.ICON_UNIT,
		name = 'BETS_UNIT',
		cursor = 'Attack',
		--action = 'SAD',
		tooltip = 'Collects unit input from player.',
		hidden = true,
		humanName = "Unit",
		--UIoverride = { texture = 'LuaUI/Images/commands/bold/sprint.png' },
		--UIoverride = { texture = 'LuaUI/Images/commands/bold/sad.png' },
	},
	["BETS_INPUT_END"] = {
		type = CMDTYPE.ICON,
		name = 'BETS_INPUT_END',
		cursor = 'Attack',
		--action = 'SAD',
		tooltip = 'Ends the user input.',
		hidden = true,
		humanName = "End",
		--UIoverride = { texture = 'LuaUI/Images/commands/bold/sprint.png' },
		--UIoverride = { texture = 'LuaUI/Images/commands/bold/sad.png' },
	},
	["BETS_CHEAT_POSITION"] = {
		type = CMDTYPE.ICON_MAP,
		name = 'BETS_CHEAT_POSITION',
		cursor = 'Attack',
		--action = 'Convoy',
		tooltip = 'Collects input where to spawn units',
		hidden = true,
		humanName = "Position",
		--UIoverride = { texture = 'LuaUI/Images/commands/bold/sprint.png' },
	},
}



local registeredCommands = {}

-- commandIDToName is used to identify command in command notify>
local commandIDToName
local commandNameToHumanName


local function registerCommand(cmdDesc)
	sendCustomMessage.RegisterCustomCommand(cmdDesc)
end

local function fillInCommandID(cmdName, cmdID)
	--[[
	if (BtCommands.inputCommands == nil) then 
		BtCommands.inputCommands = {}
	end
	
	if (BtCommands.behaviourCommands == nil) then 
		BtCommands.behaviourCommands = {}
	end
	]]
	-- if it is our command, we should remember its cmdID
	
	-- is it input command?
	for inputCmdName,_ in pairs(inputCommandDesc) do 
		if (inputCmdName == cmdName) then
			-- make the WG.InputCommands bidirectional
			BtCommands.inputCommands[ cmdID ] = cmdName
			BtCommands.inputCommands[ cmdName ] = cmdID
		end
	end
	
	-- is it input command?
	for inputCmdName,_ in pairs(inputCommandDesc) do 
		if (inputCmdName == cmdName) then
			-- make the WG.InputCommands bidirectional
			BtCommands.inputCommands[ cmdID ] = cmdName
			BtCommands.inputCommands[ cmdName ] = cmdID
		end
	end
	
	-- is it command corresponding to some behaviour?
	local qualifiedNames = BehaviourTree.list()
	for _,treeName in pairs(qualifiedNames) do
		local treeCmdName =  "BT_" ..  treeName
		if (treeCmdName == cmdName) then
			-- read serialized behaviour inputs
			local bt, msg = BehaviourTree.load(treeName)
			if(not bt)then
				Logger.error("save-and-load", msg)
			else
				BtCommands.behaviourCommands[ cmdID ] = {
					treeName = treeName,
					inputs = bt.inputs,
				}
			end
		end
	end
end

local function registerInputCommands()
	-- we need to register our custom commands
	for _, cmdDesc in pairs(inputCommandDesc) do
		registerCommand(cmdDesc) --sendCustomMessage.RegisterCustomCommand(cmdDesc)
	end
end


local function createCommandHumanNameTable()
	BtCommands.commandNameToHumanName = {}
	for name,data in pairs(inputCommandDesc) do
		BtCommands.commandNameToHumanName[name] = data.humanName
	end
end

--[[ 
The following function is used to tranform spring-based representation of 
command parameters into our representation based on name of "input command" 
associated to given data type.
--]]
function BtCommands.transformCommandData(data, commandName)
	if(commandName == inputCommandDesc["BETS_UNIT"].name) then
		return data
	end
	if(commandName == inputCommandDesc["BETS_AREA"].name) then
		local a,b,c,d = unpack(data)
		local area = {}
		area["center"] = Vec3(a,b,c)
		area["radius"] = d
		return area
	end
	if(commandName == inputCommandDesc["BETS_POSITION"].name) then
		return Vec3(unpack(data))
	end
	Logger.log("Error", "Encountered unknown command name.")
	return data 
end

--WG.BtCommandsTransformData = BtCommands.transformCommandData

local BehaviourImageContentType = ProjectManager.makeRegularContentType(BehaviourTree.contentType.directoryName, "png")

--- This method register command for tree if it has an icon
function BtCommands.tryRegisterCommandForTree(treeName, unitsWhitelist)
	-- is there icon:
	local iconFileName = ProjectManager.findFile(BehaviourImageContentType, treeName)
	local gotIcon = VFS.FileExists(iconFileName)
	
	if gotIcon then
		local allUnits = {}
		local commandName =  "BT_" ..  treeName
		local description = {
			type = CMDTYPE.ICON,
			name = commandName,
			cursor = 'Attack',
			action = 'Attack',
			tooltip = "Behaviour " .. treeName,
			hidden = false,
			UIoverride = {texture = iconFileName },
			whitelist = unitsWhitelist,
		}
		registerCommand(description) 
	end
	

end

--WG.BtTryRegisterCommandForTree = BtCommands.tryRegisterCommandForTree

local function registerCommandsForBehaviours()
	local qualifiedNames = BehaviourTree.list()
	for _,treeName in pairs(qualifiedNames) do
		BtCommands.tryRegisterCommandForTree(treeName)
	end
end

--Event handler
function CustomCommandRegistered(cmdName, cmdID)
	fillInCommandID(cmdName, cmdID)
end

function widget:Initialize()
	registerInputCommands()
	BtCommands.inputCommands = {}
	BtCommands.behaviourCommands = {}
	createCommandHumanNameTable()
	-- register command for ready available trees:
	registerCommandsForBehaviours()
	-- register event handler..
	widgetHandler:RegisterGlobal('CustomCommandRegistered', CustomCommandRegistered)
	
	WG.BtCommands = sanitizer:Export(BtCommands)
	Dependency.fill(Dependency.BtCommands)
end

function widget:Shutdown()
	-- deregister our custom commands
	for _, cmdDesc in pairs(inputCommandDesc) do
		sendCustomMessage.DeregisterCustomCommand(cmdDesc.name)
	end
	-- I guess there is missing deregistration of trees we have registered:
	
	if(BtCommands.behaviourCommands)then
		for cmdName, cmdData in pairs(BtCommands.behaviourCommands) do
			sendCustomMessage.DeregisterCustomCommand(cmdName)
		end
	end
	
	--[[
	WG.fillCustomCommandIDs = nil
	WG.BtCommandsInputHumanNames = nil
	WG.BtCommandsTransformData = nil
	WG.InputCommands = nil
	WG.BtCommands = nil
	--]]
	WG.BtCommands.inputCommands = nil
	WG.BtCommands.behaviourCommands = nil
	Dependency.clear(Dependency.BtCommands)
end


sanitizer:SanitizeWidget()
--Dependency.deferWidget(widget)