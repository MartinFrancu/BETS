local groupExtents
if(COMMAND_DIRNAME)then
	VFS.Include(COMMAND_DIRNAME .. "move.lua", nil, VFS.RAW_FIRST)
	groupExtents = VFS.Include("LuaUI/Widgets/BtSensors/groupExtents.lua", nil, VFS.RAW_FIRST)
end

local oldRun = Run
function getParameterDefs()
	return {
		{ 
			name = "pos",
			variableType = "expression",
			componentType = "editBox",
			defaultValue = "{posX = 0, posZ = 0}",
		},
	}
end

function Run(self, unitIds, parameter)
	units = unitIds
	units.length = #unitIds
	local center = groupExtents().center
	return oldRun(self, unitIds, {
		x = parameter.pos.posX - center.x,
		y = parameter.pos.posZ - center.z,
	})
end
