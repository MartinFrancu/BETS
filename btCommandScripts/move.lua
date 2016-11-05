VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCreator/debug_utils.lua", nil, VFS.RAW_FIRST)

local cmd = {}

cmd.targets = {}

cmd.n = 0

function cmd.run(unitIds, parameter)
	cmd.indexOfComma = string.find(parameter, ",")
	
	dx = parameter:sub(1, cmd.indexOfComma - 1)
	dy = parameter:sub(cmd.indexOfComma + 1)
	
	Spring.Echo("Lua MOVE command run, unitIds: " .. dump(unitIds) .. ", parameter: " .. parameter .. ", dx: " .. dx .. ", dy: " .. dy .. ", tick: "..cmd.n)
	cmd.n = cmd.n + 1
	done = true
	x,y,z=0

	for i = 1, #unitIds do
		x, y, z = Spring.GetUnitPosition(unitIds[i])
		
		tarX = x + dx
		tarY = y + dy
		Spring.Echo("tar X - " .. tarX .. " tar Y - " .. tarY)
		
		if not cmd.targets[unitIds[i]] then
			cmd.targets[unitIds[i]] = {tarX,tarY,z}
			Spring.GiveOrderToUnit(unitIds[i], CMD.MOVE, cmd.targets[unitIds[i]], {})  
		end
		
		Spring.Echo("AtX: " .. x .. ", TargetX: " .. cmd.targets[unitIds[i]][1] .. " AtY: " .. y .. ", TargetY: " .. cmd.targets[unitIds[i]][2])
		if math.abs(x - cmd.targets[unitIds[i]][1]) > 10 or math.abs(y - cmd.targets[unitIds[i]][2]) > 10 then
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
	Spring.Echo("Lua command reset")

	cmd.targets = {}
	cmd.n = 0
end

return cmd