local groupExtents
if(COMMAND_DIRNAME)then
	VFS.Include(COMMAND_DIRNAME .. "move.lua", nil, VFS.RAW_FIRST)
	groupExtents = VFS.Include("LuaUI/Widgets/BtSensors/groupExtents.lua", nil, VFS.RAW_FIRST)
end

local oldRun = Run
function getInfo()
	return {
		onNoUnits = SUCCESS,
		parameterDefs = {
			{ 
				name = "dist",
				variableType = "expression",
				componentType = "editBox",
				defaultValue = "{x = 0, z = 0}",
			},
			{ 
				name = "fight",
				variableType = "expression",
				componentType = "checkBox",
				defaultValue = "false",
			}
		}
	}
end

function Run(self, unitIds, parameter)
	units = unitIds
	units.length = #unitIds
	local center = (groupExtents() or {}).center
	if(not center)then
		return FAILURE
	end
	
	local absParam = { 
		pos = { 
			x = parameter.dist.x + center.x,
			z = parameter.dist.z + center.z
		},
		fight = parameter.fight
	}
	
	return oldRun(self, unitIds, absParam)
end
