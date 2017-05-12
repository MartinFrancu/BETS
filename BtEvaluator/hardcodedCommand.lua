local dump = Utils.Debug.dump

local hardcodedCommandPrototype = {
	BaseRun = function(self, ...) return self.run(...) end,
	BaseReset = function(self, ...) if(self.reset)then return self.reset(...) end end,
	BaseNew = function(self) return setmetatable({}, { __index = self }) end,
	AddActiveCommand = function() end,
	CommandDone = function() end,
	SetUnitIdle = function() end,
	UnitIdle = function() end,
}
local hardcodedCommandMetatable = { __index = hardcodedCommandPrototype }
local hardcodedScripts = {
	store = {
		run = function(unitIDs, p) return Results.SUCCESS, { var = p.value } end,
		parameterDefs = {
			{ 
				name = "var",
				variableType = "expression",
				componentType = "editBox",
				defaultValue = "x",
			},
			{ 
				name = "value",
				variableType = "expression",
				componentType = "editBox",
				defaultValue = "nil",
			}
		},
		tooltip = "",
	},
	echo = {
		run = function(unitIDs, p) Spring.Echo(type(p.msg) == "string" and p.msg or dump(p.msg)) return Results.SUCCESS end,
		parameterDefs = {
			{ 
				name = "msg",
				variableType = "expression",
				componentType = "editBox",
				defaultValue = "",
			}
		},
	},
	waitUntil = {
		run = function(unitIDs, p) return p.condition and Results.SUCCESS or Results.RUNNING end,
		parameterDefs = {
			{ 
				name = "condition",
				variableType = "expression",
				componentType = "editBox",
				defaultValue = "true",
			}
		},
	},
}
for k, v in pairs(hardcodedScripts) do
	hardcodedScripts[k] = setmetatable(v, hardcodedCommandMetatable)
end


return hardcodedScripts