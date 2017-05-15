--- .
-- @module program


if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end;

local Utils = BtUtils

return Utils:Assign("program", function()
	local Debug = Utils.Debug
	local Logger = Debug.Logger
	local getWidgetCaller = Debug.getWidgetCaller
	local rawTable = Debug.rawTable

	local Surrogate = Utils.Surrogate
	
	local program

	--- Normalizes the path to use regular slashes only
	local function normalizePath(path)
		return path:gsub("\\", "/")
	end

	local rootPath = LUAUI_DIRNAME .. "Widgets/"
	
	function program(name, context)
		if(not context)then
			context = getWidgetCaller()
		end
		
		local programEnvironment = setmetatable({}, {
			__index = context,
		})

		local require;
		local function makeFileEnvironment(path)
			return setmetatable({
				_G = programEnvironment,
				PATH = path,
				Utils = Utils,
				require = function(name) return require(path, name) end,
			}, {
				__index = programEnvironment,
				__newindex = programEnvironment,
			})
		end
		
		local storedResults = {}
		local processingResults = {}
		function require(currentPath, name)
			local cacheIndex = type(name) == "string" and currentPath .. name or name
		
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
			local environment = makeFileEnvironment(path)
			local result 
			if(type(name) == "string")then
				local path = normalizePath(currentPath .. name):match("(.*/)")
				local file = currentPath .. name .. ((name == "" or name:match("/$")) and "main" or "") .. ".lua"
				if(not VFS.FileExists(file))then
					error("require('" .. name .. "') at '" .. currentPath .. "' couldn't find '" .. file .. "'", 2)
				end
				-- TODO: do explicit LoadFile and loadstring to report errors in a nicer way (similarly to non-existancy)
				result = VFS.Include(file, makeFileEnvironment(path), VFS.RAW_FIRST)
			else
				local oldenv = getfenv(name)
				setfenv(name, makeFileEnvironment(currentPath))
				result = name()
				setfenv(name, oldenv) -- if the function spawned any functions, they capture the current environment at the time, so this switch back shouldn't be a problem
			end
			storedResults[cacheIndex] = result
			return result
		end

		return require(rootPath, name), rawTable(programEnvironment)
	end
	
	return program
end)
