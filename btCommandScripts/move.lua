local logger, dump, copyTable, fileTable = VFS.Include(LUAUI_DIRNAME .. "Widgets/debug_utils/root.lua", nil, VFS.RAW_FIRST)

local cmd = {}

cmd.targets = {}

cmd.n = 0

function cmd.run(unitIds, parameter)
	cmd.indexOfComma = string.find(parameter, ",")
	
	dx = parameter:sub(1, cmd.indexOfComma - 1)
	dz = parameter:sub(cmd.indexOfComma + 1)
	
	logger.Log("move-command", "Lua MOVE command run, unitIds: " .. dump(unitIds) .. ", parameter: " .. parameter .. ", dx: " .. dx .. ", dz: " .. dz .. ", tick: "..cmd.n)
	cmd.n = cmd.n + 1
	done = true
	
	x,y,z = 0,0,0
	for i = 1, #unitIds do
		x, y, z = Spring.GetUnitPosition(unitIds[i])
		
		tarX = x + dx
		tarZ = z + dz
		
		if not cmd.targets[unitIds[i]] then
			cmd.targets[unitIds[i]] = {tarX,y,tarZ}
			Spring.GiveOrderToUnit(unitIds[i], CMD.MOVE, cmd.targets[unitIds[i]], {})  
		end
		
		logger.Log("move-command", "AtX: " .. x .. ", TargetX: " .. cmd.targets[unitIds[i]][1] .. " AtZ: " .. z .. ", TargetZ: " .. cmd.targets[unitIds[i]][2])
		if math.abs(x - cmd.targets[unitIds[i]][1]) > 10 or math.abs(z - cmd.targets[unitIds[i]][3]) > 10 then
			done = false
		end
 	end
	if done then
		cmd.reset() -- reusing the same object for all move commands, so need to reset on success (TODO - 1 object per command instance)
		return "S"
	else
		return "R"
	end
	
	-- TODO implement failure (return "F")
end

function cmd.reset()
	logger.Log("move-command", "Lua command reset")

	cmd.targets = {}
	cmd.n = 0
end

return cmd