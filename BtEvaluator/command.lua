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
		newinst.onNoUnits = self.getInfo().onNoUnits or "S"

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
	if #unitIDs == 0 and self.onNoUnits ~= self.RUNNING then
		return self.onNoUnits
	end
	--if #unitIDs == 0 and self.scriptName ~= "store.lua" then -- hack as store.lua does not need access to units and can be run even when there are none
	--	return "S" -- succeeding when no units are available
	--end

	self.unitsAssigned = unitIDs

	success,res,retVal = pcall(self.Run, self, unitIDs, parameters)
	if success then
		return res, retVal
	else
		Logger.log("command", "Error in script ", self.scriptName, ", method ", methodSignatures.Run, ": ", res)
	end
end

function Command:BaseReset()
	Logger.log("command", self.scriptName, " Reset()")
	-- TODO may mark units as idle in other commands, which break them
	--[[
	for i = 1, #self.unitsAssigned do
		unitID = self.unitsAssigned[i]
		-- hack to clear the unit's command queue (adding order without "shift" clears the queue)
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {},{})
	end
	--]]
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
