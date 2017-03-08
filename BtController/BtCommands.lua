
function widget:GetInfo()
  return {
    name    = "BtCommands",
    desc    = "Custom unit commands definitions. ",
    author  = "BETS team",
    date    = "02-19-2017",
    license = "GNU GPL v2",
    layer   = 0,
    enabled = true
  }
end


local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)

local BehaviourTree = Utils.BehaviourTree
local Debug = Utils.Debug;
local Logger = Debug.Logger
local dump = Debug.dump
local Dependency = Utils.Dependency

--------------------------------------------------------------------------------
VFS.Include("LuaRules/Configs/customcmds.h.lua")
-- get madatory module operators
VFS.Include("LuaRules/modules.lua") -- modules table
VFS.Include(modules.attach.data.path .. modules.attach.data.head) -- attach lib module

local BehavioursDirectory = "LuaUI/Widgets/BtBehaviours"

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
		buttonName = "Position",
		--UIoverride = { texture = 'LuaUI/Images/commands/bold/sprint.png' },
	},
	["BETS_AREA"] = {
		type = CMDTYPE.ICON_AREA,
		name = 'BETS_AREA',
		cursor = 'Attack',
		--action = 'SAD',
		tooltip = 'Collects an area input from player.',
		hidden = true,
		buttonName = "Area",
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
		buttonName = "Unit",
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
		buttonName = "End",
		--UIoverride = { texture = 'LuaUI/Images/commands/bold/sprint.png' },
		--UIoverride = { texture = 'LuaUI/Images/commands/bold/sad.png' },
	},
}

-- commandIDToName is used to identify command in command notify>
local commandIDToName
local commandNameToHumanName

local function registerInputCommands()
	-- we need to register our custom commands
	for _, cmdDesc in pairs(inputCommandDesc) do
		sendCustomMessage.RegisterCustomCommand(cmdDesc)
	end
end


local function createCommandHumanNameTable()
	commandNameToHumanName = {}
	for name,data in pairs(inputCommandDesc) do
		commandNameToHumanName[name] = data.buttonName
	end
end

--- Fills WG.InputCommands, WG.BtCommands tables with custom commands IDs and othe needed data. Like behaviour inputs. 
local function fillCustomCommandIDs()
	local rawCommandsNameToID = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "CustomCommandsNameToID")
	if (rawCommandsNameToID ~= nil) then
		WG.InputCommands = {}
		WG.BtCommands = {}
		local commandsNameToID = message.Decode(rawCommandsNameToID)
		for cmdName,_ in pairs(inputCommandDesc) do 
			local cmdID = commandsNameToID[cmdName]
			if (cmdID ~= nil) then
				-- make the WG.InputCommands bidirectional
				WG.InputCommands[ cmdID ] = true
				WG.InputCommands[ cmdName ] = cmdID
			else
				Logger.log("commands", tostring(name) .. "command ID is not available")
			end
		end
		
		local fileNames = BtUtils.dirList(BehavioursDirectory, "*.json")--".+%.json$")
		for _,fileName in pairs(fileNames) do
			local treeName = fileName:gsub("%.json","")
			local cmdName =  "BT_" ..  treeName
			local cmdID = commandsNameToID[cmdName]
			if (cmdID ~= nil) then
				-- read serialized behaviour inputs
				local bt = BehaviourTree.load(treeName)
				WG.BtCommands[ cmdID ] = {
					treeName = treeName,
					inputs = bt.inputs,
				}
			else
				Logger.log("commands", tostring(cmdName) .. "command ID is not available")
			end
		end
		
		
	else	
		Logger.log("commands", "rawCommandsNameToID is not availible.")
		-- should I add
	end
end

WG.fillCustomCommandIDs = fillCustomCommandIDs

local function registerCommandsForBehaviours()
	local fileNames = BtUtils.dirList(BehavioursDirectory, "*.json")--".+%.json$")
	for _,fileName in pairs(fileNames) do
		local treeName = fileName:gsub("%.json","")
		local commandName =  "BT_" ..  treeName
		local description = {
			type = CMDTYPE.ICON,
			name = commandName,
			cursor = 'Attack',
			action = 'Attack',
			tooltip = fileName,
			hidden = false,
			UIoverride = {caption = treeName, texture = 'LuaUI/Images/commands/guard.png' }
			--UIoverride = { texture = 'LuaUI/Images/commands/bold/sprint.png' },
		}
		sendCustomMessage.RegisterCustomCommand(description)
	end
end

function widget:Initialize()
	registerInputCommands()
	createCommandHumanNameTable()
	WG.BtCommandsInputHumanNames = commandNameToHumanName
	-- register release commands !note: maybe move them into another refreshTreeSelectionPanel?
	registerCommandsForBehaviours()
	Dependency.fill(Dependency.BtCommands)
end

-- local function getCommandIDsForBehaviours()
	-- local rawCommandsNameToID = Spring.GetGameRulesParam("customCommandsNameToID")
	-- if (rawCommandsNameToID ~= nil) then
		-- treeCommandNameToID = {}
		-- local commandsNameToID = message.Decode(rawCommandsNameToID)
		-- local fileNames = BtUtils.dirList(BehavioursDirectory, "*.json")--".+%.json$")
		-- for i,fileName in pairs(fileNames) do
			-- local treeName = fileName:gsub("%.json","")
			-- local commandName =  "BT_" ..  treeName 
			-- if (commandsNameToID[commandName] ~= nil) then
				-- treeCommandNameToID[commandName] = commandsNameToID[commandName]
			-- else
				-- Logger.log("commands", tostring(commandName) .. "command ID is not available")
			-- end
		-- end
	-- else	
		-- Logger.log("commands", "customCommandsNameToID is not available.")
	-- end
-- end

-- local function getCommandIDToName()
	-- -- do input commands: 
	-- local rawCommandsNameToID = Spring.GetGameRulesParam("customCommandsNameToID")
	-- if (rawCommandsNameToID ~= nil) then
		-- commandIDToName = {}
		-- local commandsNameToID = message.Decode(rawCommandsNameToID)
		-- -- input commands
		-- for name, record in pairs(inputCommandDesc) do 
			-- if (commandsNameToID[name] ~= nil) then
				-- commandIDToName[commandsNameToID[name] ] = {cmdName = name
				-- }
			-- else
				-- Logger.log("commands", tostring(name) .. "command ID is not available")
			-- end
		-- end
		-- -- tree commands
		-- local fileNames = BtUtils.dirList(BehavioursDirectory, "*.json")--".+%.json$")
		-- for i,fileName in pairs(fileNames) do
			-- local treeName = fileName:gsub("%.json","")
			-- local commandName =  "BETS_TREE_" ..  treeName 
			-- if (commandsNameToID[commandName] ~= nil) then
				-- commandIDToName[commandsNameToID[commandName] ] = {
					-- cmdName = commandName,
					-- name = treeName,
					-- }
			-- else
				-- Logger.log("commands", tostring(commandName) .. "command ID is not available")
			-- end
		-- end
	-- else	
		-- Logger.log("commands", "customCommandsNameToID is not available.")
	-- end
-- end

---------------------------------------COMMANDS-END-

--Dependency.deferWidget(widget)