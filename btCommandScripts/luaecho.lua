VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCreator/debug_utils.lua", nil, VFS.RAW_FIRST)

local cmd = {}

function cmd.runCommand(unitIds)
	Spring.Echo("Lua command run, unitIds: " .. dump(unitIds))
end

function cmd.resetCommand()
	Spring.Echo("Lua command reset")
end

return cmd