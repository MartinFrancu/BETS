local Logger = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/debug_utils/logger.lua", nil, VFS.RAW_FIRST)

local dump = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST).Debug.dump

Command = {}
Command_mt = { __index = Command }



function Command:Extend()
    local new_class = {}
    local class_mt = { __index = new_class }

    function new_class:BaseNew()
        local newinst = {}
        setmetatable( newinst, class_mt )
		
		newinst.unitsAssigned = {}

		newinst.activeCommands = {} -- map(unitID, setOfCmdTags)

		newinst.idleUnits = {}
		newinst:New()
        return newinst
    end
    setmetatable( new_class, { __index = self } )
    return new_class
end

function Command:BaseRun(unitIDs, parameters)
	if #unitIDs == 0 then
		return "F"
	end
	self.unitsAssigned = unitIDs
	return self:Run(unitIDs, parameters)
end

function Command:BaseReset()
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
	self:Reset()
	
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

return Command:Extend()
