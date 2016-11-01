VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCreator/debug_utils.lua", nil, VFS.RAW_FIRST)

function runCommand(unitIds)
	Spring.Echo("Lua command run, unitIds: " .. dump(unitIds))
end

function resetCommand()
	Spring.Echo("Lua command reset")
end