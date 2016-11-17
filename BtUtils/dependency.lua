if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils

return Utils:Assign("Dependency", function()
	local Dependency = {}

	local Logger = Utils.Debug.Logger
	
	local dependencies = {}

	function Dependency.defer(f, ...)
		local unfulfilledCount = 0
		local unfulfilled = {}
	
		for i, v in ipairs({...}) do
			if(not v.filled)then
				unfulfilledCount = unfulfilledCount + 1
				table.insert(unfulfilled, v)
			end
		end

		if(unfulfilledCount == 0)then
			Logger.log("dependency", "Dependencies fulfilled already.")
			f()
		elseif(unfulfilledCount == 1)then
			Logger.log("dependency", "Single unfulfilled dependency.")
			table.insert(unfulfilled[1], f)
		else
			Logger.log("dependency", "Multiple unfulfilled dependencies.")
			local function deferer()
				unfulfilledCount = unfulfilledCount - 1
				if(unfulfilledCount == 0)then
					f()
				end
			end
			
			for i, v in ipairs(unfulfilled) do
				table.insert(v, deferer)
			end
		end
	end

	function Dependency.deferWidget(widget, ...)
		local dependenciesFulfilled = false
		local initializeTriggered = false
		local initialize = widget.Initialize
		function widget.Initialize(...)
			initializeTriggered = true
			if(dependenciesFulfilled)then
				initialize(...)
			end
		end
		local protectedMethods = { Initialize = true, GetInfo = true }
		for k, v in pairs(widget) do
			if(not protectedMethods[k] and type(v) == "function")then
				widget[k] = function(...)
					if(dependenciesFulfilled)then
						return v(...)
					end
				end
			end
		end
	
		Dependency.defer(function()
			dependenciesFulfilled = true
			if(initializeTriggered)then
				Logger.log("dependency", "Defered widget initialization due to dependency.")
				initialize(widget)
			else
				Logger.log("dependency", "Widget dependency fulfilled before initialization.")
			end
		end, ...)
	end
	
	function Dependency.fill(dependency)
		if(dependency.filled)then return end
		dependency.filled = true
		
		for i, v in ipairs(dependency) do
			v()
		end
	end
	
	setmetatable(Dependency, {
		__index = function(self, key)
			local firstCharacter = key:sub(1,1)
			if(firstCharacter:lower() == firstCharacter)then
				return nil
			end
			
			local result = {}
			self[key] = result
			return result
		end,
	})
	
	return Dependency
end)
