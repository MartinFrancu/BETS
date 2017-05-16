--- Provides the capability of constructing a custom environment separated from the widget infrastructure.
-- @classmod CustomEnvironment
-- @alias customEnvironmentPrototype
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
	
	-- use metapairs instead of pairs so that the users can use it on non-trivial tables and still get the result he expects
	common.pairs = Utils.metapairs
	-- TODO: suppply a reasonable next as well
	
	local commonMetatable = { __index = common }
	CustomEnvironment.Common = common
	
	local addedSlotDescriptions = {}

	local customEnvironmentPrototype = {}
	local customEnvironmentMetatable = { __index = customEnvironmentPrototype }

	--- Creates the environment with the specified parameters.
	-- You can optionally also specify the values for additional slot, which is equivalent to setting them after you receive the result.
	-- @usage
	-- local customEnvironment = CustomEnvironment:New({ mode = 2 })
	-- local environment = customEnvironment:Create({ name = "myEnvironment" })
	-- setfenv(myFunction, environment)
	-- return myFunction()
	function customEnvironmentPrototype:Create(parameters, additionalSlots)
		parameters = parameters or {}
		local result = setmetatable(additionalSlots and Debug.clone(additionalSlots) or {}, self.environmentMetatable)
		
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
		
		if(self.additionalCreators)then
			for k, v in pairs(self.additionalCreators) do
				result[k] = v(parameters)
			end
		end
		
		result._G = result
		return result
	end

	--- Creates a new instance of @{CustomEnvironment}
	-- @constructor
	-- @tparam {[string]=Any} additionalSlots Additional values that should be available in the final environment; or `nil`
	-- @tparam {[string]=func} additionalCreators Costructors of additional values that should be available in the final environment that utilize the parameters of @{CustomEnvironment:Create}; or `nil`
	-- @treturn CustomEnvironment
	function CustomEnvironment:New(additionalSlots, additionalCreators)
		return setmetatable({
			environmentMetatable = additionalSlots and { __index = setmetatable(Debug.clone(additionalSlots), commonMetatable) } or commonMetatable,
			additionalCreators = (type(additionalCreators) == "table" and next(additionalCreators)) and additionalCreators or nil,
		}, customEnvironmentMetatable)
	end

	--- Add a slot to all custom environments under certain conditions.
	-- The slot is added only to those custom environments, that have the specified parameters filled-in.
	-- @string slotName The name of the slot to populate
	-- @tparam {[string]=Any}|{string} requirements A map (or array) with parameter keys that are required; or `nil` if the slot should be available everywhere
	-- @tparam func|Any valueCreator The function that construct the value for given parameters or the value itself
	-- @remarks If the slots have any requirements, they do not get added to already created environments, only to future ones.
	-- @usage
	--   CustomEnvironment.add("MathEx", nil, MathEx)
	--   CustomEnvironment.add("error", { name = true }, function(p) return createCustomErrorHandler(p.name) end)
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