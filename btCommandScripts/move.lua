local Logger = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/debug_utils/logger.lua", nil, VFS.RAW_FIRST)
--local baseCommand = VFS.Include(LUAUI_DIRNAME .. "Widgets/btCommandScripts/command.lua", nil, VFS.RAW_FIRST)

local cmd = VFS.Include(LUAUI_DIRNAME .. "Widgets/btCommandScripts/command.lua", nil, VFS.RAW_FIRST)

cmd.targets = {}

cmd.n = 0

cmd.lastPositions = {}

function cmd:UnitMoved(unitID)
	x, _, z = Spring.GetUnitPosition(unitID)
	lastPos = self.lastPositions[unitID]
	
	if not lastPos then
		lastPos = {x,z}
		self.lastPositions[unitID] = lastPos
		Logger.log("move-command","unit:", unitID, "x: ", x ,", z: ", z)
		return true
	end
	
	Logger.log("move-command", "unit:", unitID, " x: ", x ,", lastX: ", lastPos[1], ", z: ", z, ", lastZ: ", lastPos[2])
	moved = x ~= lastPos[1] or z ~= lastPos[2]
	self.lastPositions[unitID] = {x,z}
	return moved
end

function cmd:Run(unitIds, parameter)
	dx = parameter.x
	dz = parameter.y
	
	Logger.log("move-command", "Lua MOVE command run, unitIds: ", unitIds, ", dx: " .. dx .. ", dz: " .. dz .. ", tick: "..self.n)
	self.n = self.n + 1
	done = true
	
	x,y,z = 0,0,0
	for i = 1, #unitIds do
		unitID = unitIds[i]
		x, y, z = Spring.GetUnitPosition(unitID)
		
		tarX = x + dx
		tarZ = z + dz
		
		if not self.targets[unitID] then
			self.targets[unitID] = {tarX,y,tarZ}
			Spring.GiveOrderToUnit(unitID, CMD.MOVE, self.targets[unitID], {})
			done = false
		else
			Logger.log("move-command", "AtX: " .. x .. ", TargetX: " .. self.targets[unitID][1] .. " AtZ: " .. z .. ", TargetZ: " .. self.targets[unitID][2])
			if not self:UnitIdle(unitID) then
				done = false
			end
			
			if not self:UnitMoved(unitID) then -- cannot get to target location
				return "F"
			end
		end
 	end
	
	if done then
		return "S"
	else
		return "R"
	end
end

function cmd:Reset()
	Logger.log("move-command", "Lua command reset")

	self.targets = {}
	self.n = 0
	self.lastPositions = {}
end

return cmd