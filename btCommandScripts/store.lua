local cmdClass = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCommandScripts/command.lua", nil, VFS.RAW_FIRST)

function cmdClass.getParameterDefs()
	return {
		{ 
			name = "var",
			variableType = "expression",
			componentType = "editBox",
			defaultValue = "0",
		},
		{ 
			name = "value",
			variableType = "expression",
			componentType = "editBox",
			defaultValue = "0",
		}
	}
end

function cmdClass:New()
end

function cmdClass:Run(unitIds, parameter)
	return "S", {
		var = parameter.value
	}
end

function cmdClass:Reset()
end

return cmdClass