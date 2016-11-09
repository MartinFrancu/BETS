local dump = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/debug_utils/root.lua", nil, VFS.RAW_FIRST).dump

local cmd = {}

function cmd.runCommand(unitIds)
	Spring.Echo("Lua command run, unitIds: " .. dump(unitIds))
end

function cmd.resetCommand()
	Spring.Echo("Lua command reset")
end

return cmd