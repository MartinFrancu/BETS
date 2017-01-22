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
	local center = (groupExtents() or {}).center
	if(not center)then
		return FAILURE
	end
	
	return oldRun(self, unitIds, {
		x = parameter.pos.x - center.x,
		y = parameter.pos.z - center.z,
	})
end