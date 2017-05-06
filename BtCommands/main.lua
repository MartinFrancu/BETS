local ProjectManager = Utils.ProjectManager
local BehaviourTree = Utils.BehaviourTree
local Debug = Utils.Debug;
local Logger = Debug.Logger
local dump = Debug.dump
local Dependency = Utils.Dependency
local sanitizer = Utils.Sanitizer.forWidget(widget)
local Vec3 = Utils.Vec3

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
	if (WG.InputCommands == nil) then 
		WG.InputCommands = {}
	end
	if (WG.BtCommands == nil) then 
		WG.BtCommands = {}
	end
	-- if it is our command, we should remember its cmdID
	
	-- is it input command?
	for inputCmdName,_ in pairs(inputCommandDesc) do 
		if (inputCmdName == cmdName) then
			-- make the WG.InputCommands bidirectional
			WG.InputCommands[ cmdID ] = cmdName
			WG.InputCommands[ cmdName ] = cmdID
		end
	end
	
	-- is it input command?
	for inputCmdName,_ in pairs(inputCommandDesc) do 
		if (inputCmdName == cmdName) then
			-- make the WG.InputCommands bidirectional
			WG.InputCommands[ cmdID ] = cmdName
			WG.InputCommands[ cmdName ] = cmdID
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
				WG.BtCommands[ cmdID ] = {
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
	commandNameToHumanName = {}
	for name,data in pairs(inputCommandDesc) do
		commandNameToHumanName[name] = data.humanName
	end
end

--[[ 
The following function is used to tranform spring-based representation of 
command parameters into our representation based on name of "input command" 
associated to given data type.
--]]
local function transformCommandData(data, commandName)
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
	Logger.log("commands", "Encountered unknown command name.")
end

WG.BtCommandsTransformData = transformCommandData

local BehaviourImageContentType = ProjectManager.makeRegularContentType(BehaviourTree.contentType.directoryName, "png")
------------CHANGE LATER:
local BehaviourDefaultImageContentType = ProjectManager.makeRegularContentType("Behaviours", "png")
------------CHANGE LATER END
local function registerCommandForTree(treeName)
	-- should I check if there is such file??
	
	-- is there icon:
	local iconFileName = ProjectManager.findFile(BehaviourImageContentType, treeName)
	local gotIcon = VFS.FileExists(iconFileName)
	
	local UIover
	if gotIcon then
		UIover = {texture = iconFileName }
	else
		local defaultIconPath = ProjectManager.findFile(BehaviourDefaultImageContentType, "Common", DEFAULT_ICON_NAME)
		UIover = {caption = treeName:gsub("%.", "\n"), texture = defaultIconPath} --'LuaUI/Images/commands/bold/restore.png' }
	end
	
	local commandName =  "BT_" ..  treeName
	local description = {
		type = CMDTYPE.ICON,
		name = commandName,
		cursor = 'Attack',
		action = 'Attack',
		tooltip = "Behaviour " .. treeName,
		hidden = false,
		UIoverride = UIover
	}
	registerCommand(description) 
end

WG.BtRegisterCommandForTree = registerCommandForTree

local function registerCommandsForBehaviours()
	local qualifiedNames = BehaviourTree.list()
	for _,treeName in pairs(qualifiedNames) do
		registerCommandForTree(treeName)
	end
end

--Event handler
function CustomCommandRegistered(cmdName, cmdID)
	Logger.log("commands", "Command [" .. cmdName .. "] was registered under ID [" .. cmdID .. "]")
	fillInCommandID(cmdName, cmdID)
end

function widget:Initialize()
	registerInputCommands()
	createCommandHumanNameTable()
	WG.BtCommandsInputHumanNames = commandNameToHumanName
	-- register release commands !note: maybe move them into another refreshTreeSelectionPanel?
	registerCommandsForBehaviours()
	-- register event handler..
	widgetHandler:RegisterGlobal('CustomCommandRegistered', CustomCommandRegistered)
	
	Dependency.fill(Dependency.BtCommands)
end

function widget:Shutdown()
	-- deregister our custom commands
	for _, cmdDesc in pairs(inputCommandDesc) do
		sendCustomMessage.DeregisterCustomCommand(cmdDesc.name)
	end
	-- I guess there is missing deregistration of trees we have registered..
	
	if(WG.BtCommands)then
		for cmdName, cmdData in pairs(WG.BtCommands) do
			sendCustomMessage.DeregisterCustomCommand(cmdName)
		end
	end
	
	WG.fillCustomCommandIDs = nil
	WG.BtCommandsInputHumanNames = nil
	WG.BtCommandsTransformData = nil
	WG.InputCommands = nil
	WG.BtCommands = nil
	Dependency.clear(Dependency.BtCommands)
end


sanitizer:SanitizeWidget()
--Dependency.deferWidget(widget)