--- Runs a file in an environment, in which a polyfill for the standard @{require} function exists.
-- Essentially allows writing widgets over multiple files.
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
		path = path:gsub("\\", "/")
		repeat
			local indexFrom, indexTo, name = path:find("([^/]-)/%.%.")
			if(name == nil or name == '..')then
				break
			end
			path = path:sub(1, indexFrom - 1) .. path:sub(indexTo + 2)
		until(false)
		return path
	end

	local rootPath = LUAUI_DIRNAME .. "Widgets/"
	
	--- Runs the specified file inside a new clean environment with access to `require`.
	-- 
	-- The `require` can be given a string corresponding to a relative path to the location of the file that uses it, without extension, and the specified file gets evaluated as well. If the same file would be evaluated two times, it is evaluated only the first time and the same result is returned the next time.
	-- 
	-- It is also capable of resolving cyclic references by utilizing @{Surrogate}s.
	-- @string name Relative path from `LuaUI/Widgets` to the file that is the root of the "program"
	-- @tab[opt] context Optional parameter; the environment, that should be available within the files, it uses @{widget} otherwise
	-- @treturn tab @{rawTable} view of the environment in which the files ran
	-- @remark Even when an environment is given, the files run in a clean environment, that just allows them to access the given one. Names given as `name` parameter to `program` and `require` can point to a directory, ending in "`/`", which is equivalent to point to the `main.lua` file inside that directory.
	function program(name, context)
		if(not context)then
			context = getWidgetCaller()
		end
		
		local programEnvironment = setmetatable({}, {
			__index = context,
		})

		local function locatePath(currentPath, name)
			local protofile = normalizePath(currentPath .. name)
			local path = protofile:match("(.*/)")
			local file = protofile .. ((name == "" or name:match("/$")) and "main" or "") .. ".lua"
			return path, file
		end
		
		local require;
		local function makeFileEnvironment(path)
			return setmetatable({
				_G = programEnvironment,
				PATH = path,
				Utils = Utils,
				exists = function(name) return VFS.FileExists(select(2, locatePath(path, name))) end,
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
				local path, file = locatePath(currentPath, name)
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
