local Logger = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/debug_utils/logger.lua", nil, VFS.RAW_FIRST)
--local baseCommand = VFS.Include(LUAUI_DIRNAME .. "Widgets/btCommandScripts/command.lua", nil, VFS.RAW_FIRST)

local cmd = VFS.Include(LUAUI_DIRNAME .. "Widgets/btCommandScripts/command.lua", nil, VFS.RAW_FIRST)

cmd.targets = {}

cmd.n = 0

-- Spring.Echo("---------------------  LOADING ---------------------")

function cmd:Run(unitIds, parameter)
	if #unitIds == 0 then
		return "F"
	end
	
	dx = parameter.x
	dz = parameter.y
	
	Logger.log("move-command", "Lua MOVE command run, unitIds: ", unitIds, ", dx: " .. dx .. ", dz: " .. dz .. ", tick: "..self.n)
	self.n = self.n + 1
	done = true
	
	x,y,z = 0,0,0
	for i = 1, #unitIds do
		x, y, z = Spring.GetUnitPosition(unitIds[i])
		
		tarX = x + dx
		tarZ = z + dz
		
		if not self.targets[unitIds[i]] then
			self.targets[unitIds[i]] = {tarX,y,tarZ}
			Spring.GiveOrderToUnit(unitIds[i], CMD.MOVE, self.targets[unitIds[i]], {})  
		end
		
		Logger.log("move-command", "AtX: " .. x .. ", TargetX: " .. self.targets[unitIds[i]][1] .. " AtZ: " .. z .. ", TargetZ: " .. self.targets[unitIds[i]][2])
		if math.abs(x - self.targets[unitIds[i]][1]) > 10 or math.abs(z - self.targets[unitIds[i]][3]) > 10 then
			done = false
		end
 	end
	if done then
		return "S"
	else
		return "R"
	end
	
	-- TODO implement failure (return "F")
end

function cmd:Reset()
	Logger.log("move-command", "Lua command reset")

	self.targets = {}
	self.n = 0
end

return cmd