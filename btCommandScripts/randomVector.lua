local Logger = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/debug_utils/logger.lua", nil, VFS.RAW_FIRST)

local cmdClass = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCommandScripts/command.lua", nil, VFS.RAW_FIRST)

function cmdClass.getParameterDefs()
	return {
		{ 
			name = "x",
			variableType = "number",
			componentType = "editBox",
			defaultValue = "0",
		},
		{ 
			name = "y",
			variableType = "number",
			componentType = "editBox",
			defaultValue = "0",
		}
	}
end

function cmdClass:New()
end

function cmdClass:Run(unitIds, parameter)
	local angle = 2 * math.pi * math.random()
	local amplitude = 60 + math.random() * 40
	return "S", {
		x = math.cos(angle) * amplitude,
		y = math.sin(angle) * amplitude
	}
end

function cmdClass:Reset()
end

return cmdClass