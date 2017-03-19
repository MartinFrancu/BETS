local Logger = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/debug_utils/logger.lua", nil, VFS.RAW_FIRST)

local dump = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST).Debug.dump

local COMMAND_DIRNAME = LUAUI_DIRNAME .. "Widgets/BtCommandScripts/"

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)

local System = Utils.Debug.clone(loadstring("return _G")().System)

setmetatable(System, { 
	__index = {
		Logger = Logger,
		COMMAND_DIRNAME = COMMAND_DIRNAME,
		System = System,
		Command = Command,
		Vec3 = Utils.Vec3,
		
		SUCCESS = "S",
		FAILURE = "F",
		RUNNING = "R"
	}
})

Command = {}

local methodSignatures = {
	New = "New(self)",
	Run = "Run(self, unitIds, parameters)",
	Reset = "Reset(self)"
}

local currentlyExecutingCommand = nil
local unitToOrderIssueingCommandMap = {}
-- alters the certain tables that are available from within the instance
Command.Spring = setmetatable({
	GiveOrderToUnit = function(unitID, ...)
		unitToOrderIssueingCommandMap[unitID] = currentlyExecutingCommand
		
		return Spring.GiveOrderToUnit(unitID, ...)
	end,
	GiveOrderToUnitMap = function(unitMap, ...)
		for unitID in pairs(unitMap) do
			unitToOrderIssueingCommandMap[unitID] = currentlyExecutingCommand
		end
		
		return Spring.GiveOrderToUnitMap(unitMap, ...)
	end,
	GiveOrderToUnitArray = function(unitArray, ...)
		for _, unitID in ipairs(unitArray) do
			unitToOrderIssueingCommandMap[unitID] = currentlyExecutingCommand
		end
		
		return Spring.GiveOrderToUnitArray(unitArray, ...)
	end,
	GiveOrderArrayToUnitMap = function(unitMap, ...)
		for unitID in pairs(unitMap) do
			unitToOrderIssueingCommandMap[unitID] = currentlyExecutingCommand
		end
		
		return Spring.GiveOrderArrayToUnitMap(unitMap, ...)
	end,
	GiveOrderArrayToUnitArray = function(unitArray, ...)
		for _, unitID in ipairs(unitArray) do
			unitToOrderIssueingCommandMap[unitID] = currentlyExecutingCommand
		end
		
		return Spring.GiveOrderArrayToUnitArray(unitArray, ...)
	end,
}, {
	__index = Spring
})

local orderIssueingCommand = {} -- a reference used as a key in unit roles

function Command:Extend(scriptName)
	Logger.log("script-load", "Loading command from file " .. scriptName)
	function Command:loadMethods()
		--Logger.log("script-load", "Loading method ", methodName, " into ", scriptName)
		
		local nameComment = "--[[" .. scriptName .. "]] "
		local scriptStr = nameComment .. VFS.LoadFile(COMMAND_DIRNAME .. scriptName)
		local scriptChunk = assert(loadstring(scriptStr))
		setfenv(scriptChunk, self)
		scriptChunk()
		
		if not self.New then
			Logger.log("script-load", "Warning - scriptName: ", scriptName, ", Method ", methodSignatures.New, "  missing (note that this might be intentional)")
			self.New = function() end
		end
		
		if not self.Reset then
			Logger.log("script-load", "Warning - scriptName: ", scriptName, ", Method ", methodSignatures.Reset, "  missing (note that this might be intentional)")
			self.Reset = function() end
		end
		
		if not self.Run then
			Logger.error("script-load", "scriptName: ", scriptName, ", Method ", methodSignatures.Run, "  missing")
			self.Run = function() return Command.FAILURE end
		end
	end

	Logger.log("script-load", "scriptName: ", scriptName)
	local new_class = {	}
	local class_mt = { __index = new_class }
	
	function new_class:BaseNew()
		local newinst = {}
		setmetatable( newinst, class_mt )
		newinst.unitsAssigned = {}
		newinst.activeCommands = {} -- map(unitID, setOfCmdTags)
		newinst.idleUnits = {}
		newinst.scriptName = scriptName -- for debugging purposes
		
		local info = self.getInfo()
		newinst.onNoUnits = info.onNoUnits or Command.SUCCESS

		success,res = pcall(newinst.New, newinst)
		if not success then
			Logger.error("command", "Error in script ", scriptName, ", method " .. methodSignatures.New, ": ", res)
		end
		return newinst
	end

	setmetatable( new_class, { __index = self })
	setmetatable(self, { __index = System })	
	new_class:loadMethods()

	return new_class
end

function Command:BaseRun(unitIDs, parameters)
	if unitIDs.length == 0 and self.onNoUnits ~= self.RUNNING then
		Logger.loc("command", "No units assigned.")
		return self.onNoUnits
	end

	self.unitsAssigned = unitIDs

	currentlyExecutingCommand = self

	System.Sensors = self.Sensors
	success,res,retVal = pcall(self.Run, self, unitIDs, parameters)
	System.Sensors = nil
	
	if success then
		return res, retVal
	else
		Logger.error("command", "Error in script ", self.scriptName, ", method ", methodSignatures.Run, ": ", res)
	end
end

function Command:BaseReset()
	Logger.log("command", self.scriptName, " Reset()")

	local unitIDs = self.unitsAssigned
	if(unitIDs.length)then
		for i = 1, unitIDs.length do
			unitID = unitIDs[i]
			if(unitToOrderIssueingCommandMap[unitID] == self)then
				unitToOrderIssueingCommandMap[unitID] = nil
				-- hack to clear the unit's command queue (adding order without "shift" clears the queue)
				Spring.GiveOrderToUnit(unitID, CMD.STOP, {},{})
			end
		end
	end

	self.unitsAssigned = {}
	
	self.idleUnits = {}
	
	currentlyExecutingCommand = self

	success,res = pcall(self.Reset, self)
	if not success then
		Logger.error("command", "Error in script ", self.scriptName, ", method ", methodSignatures.Reset, ": ", res)
	end
end

-- TODO not working
function Command:GetActiveCommands(unitID)
	active = self.activeCommands[unitID]
	if not active then
		active = {}
		self.activeCommands[unitID] = active
	end
	return active
end

-- TODO cmdTag is always nil
function Command:AddActiveCommand(unitID, cmdID, cmdTag)
	if cmdID == CMD.STOP then
		return
	end

	active = self:GetActiveCommands(unitID)
	active.cmdTag = true
	Logger.log("command", "AddActiveCommand - Unit: ", unitID, " newCmd: ", dump(cmdTag), " QueueLen: ", #active)
	
	self.idleUnits[unitID] = false
end

-- TODO cmdTag is always nil
function Command:CommandDone(unitID, cmdID, cmdTag)
	active = self:GetActiveCommands(unitID)
	active.cmdTag = nil
	Logger.log("command", "CommandDone - Unit: ", unitID, " doneCmd: ", dump(cmdTag), " QueueLen: ", #active)
end

function Command:SetUnitIdle(unitID)
	Logger.log("command", "SetUnitIdle - Unit: ", unitID)
	self.idleUnits[unitID] = true
end

function Command:UnitIdle(unitID)

	Logger.log("command", "UnitIdle - Unit: ", unitID, " Idle: ", self.idleUnits[unitID])
	return self.idleUnits[unitID]
end

return Command
