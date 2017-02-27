local Logger = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/debug_utils/logger.lua", nil, VFS.RAW_FIRST)

local dump = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST).Debug.dump

local COMMAND_DIRNAME = LUAUI_DIRNAME .. "Widgets/BtCommandScripts/"

Command = {
	Spring = Spring,
	CMD = CMD,
	VFS = VFS, -- to be removed
	Logger = Logger,
	dump = dump,
	math = math,
	select = select,
	pairs = pairs,
	ipairs = ipairs,
	UnitDefNames = UnitDefNames,
	COMMAND_DIRNAME = COMMAND_DIRNAME,
	
	SUCCESS = "S",
	FAILURE = "F",
	RUNNING = "R"
}
Command_mt = { __index = Command }

local methodSignatures = {
	New = "New(self)",
	Run = "Run(self, unitIds, parameters)",
	Reset = "Reset(self)"
}

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
			self.Run = function() return FAILURE end
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
		newinst.issuesOrders = info.issuesOrders or false
		newinst.onNoUnits = info.onNoUnits or "S"

		success,res = pcall(newinst.New, newinst)
		if not success then
			Logger.log("command", "Error in script ", scriptName, ", method " .. methodSignatures.New, ": ", res)
		end
        return newinst
    end
    setmetatable( new_class, { __index = self } )

	
	new_class:loadMethods()

    return new_class
end

function Command:BaseRun(unitIDs, parameters)
	if unitIDs.length == 0 and self.onNoUnits ~= self.RUNNING then
		return self.onNoUnits
	end

	self.unitsAssigned = unitIDs
	if(self.issuesOrders)then
		unitIDs[orderIssueingCommand] = self -- store a reference to ourselves so that we can properly reset only if there was not another order issued by another command
	end

	success,res,retVal = pcall(self.Run, self, unitIDs, parameters)
	if success then
		return res, retVal
	else
		Logger.log("command", "Error in script ", self.scriptName, ", method ", methodSignatures.Run, ": ", res)
	end
end

function Command:BaseReset()
	Logger.log("command", self.scriptName, " Reset()")

	if(self.issuesOrders)then
		-- TODO: this handles only commands issued to the same roles, it doesn't work when a command is given to a subset, as in ALL_UNITS vs. role
		-- possible solution: alter the group object in such a way that it can call GiveOrderToUnit itself and as such handle the resetting properly (as in check with the macrogroup)
	
		local unitIDs = self.unitsAssigned
		if(unitIDs[orderIssueingCommand] == self)then -- check that there was not another node that issued a command to the group
			Logger.log("command", self.scripName, " resetting orders")
			unitIDs[orderIssueingCommand] = nil
			
			for i = 1, unitIDs.length do
				unitID = unitIDs[i]
				-- hack to clear the unit's command queue (adding order without "shift" clears the queue)
				Spring.GiveOrderToUnit(unitID, CMD.STOP, {},{})
			end
		else
			Logger.log("command", self.scripName, " not resetting orders, as they have already been overwritten")
		end
	end

	self.unitsAssigned = {}
	
	self.idleUnits = {}
	

	success,res = pcall(self.Reset, self)
	if not success then
		Logger.log("command", "Error in script ", self.scriptName, ", method ", methodSignatures.Reset, ": ", res)
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
