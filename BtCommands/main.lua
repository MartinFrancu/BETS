--[[README: BtCommands provides functionality of custom orders to BETS family of widgets. 
 Functions of special importance:
 BtCommands.tryRegisterCommandForTree: 
	Used to register behaviour orders, if required: Only behaviours equipped with icon should have orders.
CustomCommandRegistered
	Callback when new custom command is registered. 
 BtCommands.getInput
	Function providing BtController and BtCheat with functionality of user specifying in-game object.
widget.CommandNotify
	Used to catch commands with specified parameters. In particular our dummy commands. 
--]]
local ProjectManager = Utils.ProjectManager
local BehaviourTree = Utils.BehaviourTree
local Debug = Utils.Debug;
local Logger = Debug.Logger
local dump = Debug.dump
local Dependency = Utils.Dependency
local sanitizer = Utils.Sanitizer.forWidget(widget)
local Timer = Utils.Timer;
local Vec3 = Utils.Vec3
local UnitCategories = Utils.UnitCategories

-- If we are in state of expecting input we will make store this information here
local expectedInput 
--------------------------------------------------------------------------------
local spGetCmdDescIndex = Spring.GetCmdDescIndex
local spSetActiveCommand = Spring.SetActiveCommand
local spGetSelectedUnits = Spring.GetSelectedUnits
local spSelectUnits = Spring.SelectUnitArray

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

-- returns all unit types referenced in categories of given tree:
local function allUnitTypesReferenced(qTreeName)
	local tree,msg = BehaviourTree.load(qTreeName)
	if(not tree) then
		return false, msg
	end
	local roles = tree.roles
	-------------------------------------------------------------------
	-- compute all units for which it will be visible:
	local mentionedUnits = {}
	for _,roleData in ipairs(roles) do
		-- for each role:
		if(not roleData.categories ) then
			return false, "Invalid format of tree: missing record 'categories' in role data."
		end
		for _,catName in ipairs(roleData.categories) do
			-- for each mentioned category:
			-- get units in this category
			local unitList, msg = UnitCategories.getCategoryTypes(catName)
			Logger.log("commands", "category: ", catName, " units ",  dump(unitList, 3) , " msg ", msg )
			if (not unitList) then
				-- I should probably through error
				Logger.log("error", "Category file: " .. msg)
				return false, msg
			end
			for _, unitData in ipairs(unitList) do
				mentionedUnits[unitData.name] = true
			end
		end
	end
	local whitelist = {}
	local i = 1
	for unitName, _ in pairs(mentionedUnits) do
		whitelist[i] = unitName
		i = i+1
	end
	return whitelist
end

local BehaviourImageContentType = ProjectManager.makeRegularContentType(BehaviourTree.contentType.directoryName, "png")

--- This method register command for tree if it has an icon
function BtCommands.tryRegisterCommandForTree(treeName)
	-- is there icon:
	local iconFileName = ProjectManager.findFile(BehaviourImageContentType, treeName)
	local gotIcon = VFS.FileExists(iconFileName)
	
	if gotIcon then

		-- now I should find out for which units this command should be registered.
		local whitelist, msg = allUnitTypesReferenced(treeName)
		if(not whitelist) then
			return false, msg
		end 
		-- when there is no unit in whitelist it should be nil = to be added to all units
		if #whitelist <1 then
			whitelist = nil
		end
		
		local commandName =  "BT_" ..  treeName
		local description = {
			type = CMDTYPE.ICON,
			name = commandName,
			cursor = 'Attack',
			action = 'Attack',
			tooltip = "Behaviour " .. treeName,
			hidden = false,
			UIoverride = {texture = iconFileName },
			whitelist = whitelist,
		}
		registerCommand(description) 

		return true, "All went ok."
	end
	
	return nil, "Tree does not have icon"
end

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

-- this returns one ally unit. 
local function getDummyAllyUnit()
	local allUnits = Spring.GetTeamUnits(Spring.GetMyTeamID())
	return allUnits[1]
end

--- This function will be used by BtCreator and BtCheat to get input from player through invocation of command which is then catched in widget:CommandNotify
function BtCommands.getInput(commandName, callback)

	-- I need to store record what we are expecting
	expectedInput = {
		commandName = commandName,
		callback = sanitizer:Sanitize(callback),
	}
	Logger.log("commands", dump(callback) )
	Logger.log("commands", dump(expectedInput.callback) )
	
	local f = function()
		cmdId = BtCommands.inputCommands[ expectedInput.commandName ]
		local ret = spSetActiveCommand(  spGetCmdDescIndex(cmdId) ) 
		if(ret == false ) then 
			Logger.log("commands", "Unable to set command active: " , expectedInput.commandName) 
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
	
end

function widget.CommandNotify(self, cmdID, cmdParams, cmdOptions)
	-- Check for custom commands, first input commands
	local inputCommandsTable = BtCommands.inputCommands
	if(inputCommandsTable[cmdID]) then
		if(expectedInput ~= nil) then
			-- I should insert given input to tree:
			local commandType = expectedInput.commandName
			-- I should check if the the command type is same, with expected?
			if(inputCommandsTable[cmdID] ~= commandType)then
				Logger.log("Error", "BtCommands.CommandNotify : Unexpected input command type.", 
							" Expected: ", commandType, 
							", got: ",inputCommandsTable[cmdID] )
				return false
			end
			
			transformedData = BtCommands.transformCommandData(cmdParams, commandType)
			
			expectedInput.callback(transformedData)
			
			expectedInput = nil
		else
			Logger.log("commands", "BtCommands: Received input command while not expecting one!!!")
		end
		return true -- true is for deleting command and not sending it further according to documentation		
	end
	--[[
	-- check for custom commands - Bt behaviour assignments
	local treeCommandsTable = BtCommands.behaviourCommands
	if(treeCommandsTable[cmdID]) then
		-- setting up a behaviour tree :
		local treeHandle = instantiateTree(treeCommandsTable[cmdID].treeName, "Instance"..instanceIdCount , true)
		
		listenerBarItemClick({TreeHandle = treeHandle}, x, y, 1)
		
		-- click on first input:
		if(table.getn(treeHandle.InputButtons) >= 1) then -- there are inputs
			listenerInputButton(treeHandle.InputButtons[1])
		end
		return true
	end
	]]
	Logger.log("commands", "received unknown command (probably normal case): " , cmdID)
	return false
end 


Timer.injectWidget(widget)
sanitizer:SanitizeWidget()
--Dependency.deferWidget(widget)