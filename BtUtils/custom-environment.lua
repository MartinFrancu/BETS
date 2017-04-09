--- Provides a custom environment.
-- @module CustomEnvironment
-- @pragma nostrip

-- tag @pragma makes it so that the name of the module is not stripped from the function names

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils
return Utils:Assign("CustomEnvironment", function()
	local CustomEnvironment = {}

	local Debug = Utils.Debug
	local Sanitizer = Utils.Sanitizer

	local common = Debug.clone(loadstring("return _G")().System)
	--common.VFS = nil -- disable VFS so that users may not break something
	common.dump = Debug.dump
	common.Logger = Debug.Logger
	common.Vec3 = Utils.Vec3
	local commonMetatable = { __index = common }
	CustomEnvironment.Common = common
	
	local addedSlotDescriptions = {}

	local customEnvironmentPrototype = {}
	local customEnvironmentMetatable = { __index = customEnvironmentPrototype }

	function customEnvironmentPrototype:Create(parameters, additionalSlots)
		parameters = parameters or {}
		local result = setmetatable(additionalSlots and Debug.clone(additionalSlots) or {}, self.environmentMetatable)
		
		if(self.additionalCreators)then
			for k, v in pairs(self.additionalCreators) do
				result[k] = v(parameters)
			end
		end
		
		for i, v in pairs(addedSlotDescriptions) do
			local fulfilled = true
			for k in pairs(v.requirements) do
				if(not parameters[k])then
					fulfilled = false
					break
				end
			end
			
			if(fulfilled)then
				result[v.slotName] = v.valueCreator(parameters)
			end
		end
		
		result._G = result
		return result
	end

	function CustomEnvironment:New(additionalSlots, additionalCreators)
		return setmetatable({
			environmentMetatable = additionalSlots and { __index = setmetatable(Debug.clone(additionalSlots), commonMetatable) } or commonMetatable,
			additionalCreators = (type(additionalCreators) == "table" and next(additionalCreators)) and additionalCreators or nil,
		}, customEnvironmentMetatable)
	end

	---
	-- @remarks If the slots have any requirements, they do not get added to already created environments -- those created by @{CustomEnvironment:Create}
	function CustomEnvironment.add(slotName, requirements, valueCreator)
		if(valueCreator == nil)then
			valueCreator = requirements
			requirements = nil
		end
		
		if(type(valueCreator) ~= "function")then
			valueCreator = function(_) return valueCreator end
		else
			valueCreator = Sanitizer.sanitize(valueCreator)
		end
		
		if(not requirements)then
			common[slotName] = valueCreator()
		else
			if(requirements[1])then
				for i, k in ipairs(requirements) do
					requirements[k] = true
					requirements[i] = nil
				end
			end
		
			table.insert(addedSlotDescriptions, {
				slotName = slotName,
				valueCreator = valueCreator,
				requirements = requirements,
			})
		end
	end

	return CustomEnvironment
end)