local Logger = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/debug_utils/logger.lua", nil, VFS.RAW_FIRST)

local dump = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST).Debug.dump

Command = {
	Spring = Spring,
	CMD = CMD,
	Logger = Logger,
	dump = dump,
	math = math,
	select = select,
	UnitDefNames = UnitDefNames,
	
	SUCCESS = "S",
	FAILURE = "F",
	RUNNING = "R"
}
Command_mt = { __index = Command }

local COMMAND_DIRNAME = LUAUI_DIRNAME .. "Widgets/BtCommandScripts/"

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

		for methodName,sig in pairs(methodSignatures) do
			local codeStr = scriptStr .. " ; return " .. methodName
			local methodGetter = assert(loadstring(codeStr))
			local method = methodGetter()
			if not method then
				Logger.log("script-load",  scriptName, " doesn't contain method ", sig)
				method = function() end
			else
				setfenv(method, self)
			end
			self[methodName] = method
			Logger.log("script-load", "Loaded method ", methodName, " into ", scriptName)
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
	if #unitIDs == 0 then
		return "F"
	end

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
