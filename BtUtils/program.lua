--- .
-- @module program


if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end;

local Utils = BtUtils

return Utils:Assign("program", function()
	local Debug = Utils.Debug
	local Logger = Debug.Logger
	local getWidgetCaller = Debug.getWidgetCaller

	local Surrogate = Utils.Surrogate
	
	local program

	--- Normalizes the path to use regular slashes only
	local function normalizePath(path)
		return path:gsub("\\", "/")
	end

	function program(f, context)
		local path = LUAUI_DIRNAME .. "Widgets/"
		
		if(not context)then
			context = getWidgetCaller()
		end
		
		local environment
		
		local storedResults = {}
		local processingResults = {}
		local function require(name)
			local cacheIndex = type(name) == "string" and path .. name or name
		
			local stored = storedResults[cacheIndex]
			if(stored)then
				return stored
			end
			
			local processing = processingResults[cacheIndex]
			if(processing)then -- cyclic dependancy
				if(processing == true)then -- Surrogate already created
					return processing
				else
					processing = Surrogate:New(function() return storedResults[cacheIndex] end)
					processingResults[cacheIndex] = processing
					return processing
				end
			end
			
			processingResults[cacheIndex] = true
			local result 
			if(type(name) == "string")then
				local orig = name
				local dir, filename = normalizePath(name):match("(.*)/(.*)")
				local oldPath = path
				if(dir)then
					path = path .. dir .. "/"
				else
					filename = name
				end
				name = filename == "" and "main" or name
				local file = path .. name .. ".lua"
				if(not VFS.FileExists(file))then
					error("require('" .. orig .. "') at '" .. oldPath .. "' couldn't find '" .. file .. "'", 2)
				end
				-- TODO: do explicit LoadFile and loadstring to report errors in a nicer way (similarly to non-existancy)
				result = VFS.Include(file, environment, VFS.RAW_FIRST)
				path = oldPath
			else
				local oldenv = getfenv(name)
				setfenv(name, environment)
				result = name()
				setfenv(name, oldenv)
			end
			storedResults[cacheIndex] = result
			return result
		end

		environment = setmetatable({
			Utils = Utils,
			require = require,
		}, {
			__index = context,
		})
				
		-- TODO: expose envrionment to the outside, so it can be inspected
		return require(f)
	end
	
	return program
end)
