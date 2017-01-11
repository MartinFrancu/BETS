local dump = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/debug_utils/root.lua", nil, VFS.RAW_FIRST).dump

local cmdClass = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCommandScripts/command.lua", nil, VFS.RAW_FIRST)


function cmdClass.getParameterDefs()
	return {
		{ 
			name = "msg",
			variableType = "string",
			componentType = "editBox",
			defaultValue = "0",
		}
	}
end


function cmdClass:New()
end


function cmdClass:Run(unitIds, p)
	Spring.Echo(dump(p.msg))
	return "S"
end

function cmdClass:Reset()
end

return cmdClass