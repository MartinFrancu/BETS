--- The main entry point of the library, through which one can access anything else.
-- The @{Locator} class, which @{BtUtils} is an instance of, is itself defined within this module, in order to not creator another dependency that needs to be handled through something other than a @{Locator}.
-- @locator BtUtils

WG = WG or {}
WG.BtUtils = WG.BtUtils or (function()
	--- Locatable modules and classes.
	-- @table BtUtils.
	local locators = {
		Sentry = "sentry", -- @{Sentry}
		JSON = "JSON", -- @{JSON}
		Dependency = "dependency", -- @{Dependency}
		BehaviourTree = "behaviour-tree", -- @{BehaviourTree}
		dirList = "dir-list", -- @{dirList}
		Debug = "debug_utils/", -- @{BtUtils.Debug}
		UnitCategories = "categories",
		metanext = { "meta-iteration", 1 }, -- @{metanext}
		metapairs = { "meta-iteration", 2 }, -- @{metapairs}
		Vec3 = "Vector3",
		Sanitizer = "sanitizer", -- @{Sanitizer}
	}
	
	local LOCAL_PATH = LUAUI_DIRNAME .. "Widgets/BtUtils/"
	local function include(name)
		if(name:sub(name:len()) == "/")then
			name = name .. "root"
		end
		
		return VFS.Include(LOCAL_PATH .. name .. ".lua", nil, VFS.RAW_FIRST)
	end

	
	-- creating Locator, which is the only object that needs to be created directly, as it's a bootstrapper
	
	--- Instances of this class have a specified set of key-path pairs, so called locators.
	-- The keys are accessible as regular fields of a table, however their value is retrieved by reading and evaluating a lua file defined by the locator. This process is done only once, when the key is first accessed, as the resulting module/class is stored directly on the instance as a regular field.
	-- @type Locator
	local Locator = {};
	
	local locatorPrototype = {}
	--- Assigns a value to the specified key if it is still `nil`.
	-- @string   key   the key to assign under
	-- @func   creator   closure which creates the module/class that belongs to the key
	-- @return   the newly creator module/class if the key was not assigned to, current occupant of the key otherwise
	-- @remark This method is supplied in order to support the idiom `l.key = l.key or ...` in the located modules that intend to directly place themselves into specific a @{Locator}. This idiom would not work as it would recursively invoke the file execution, resulting in an error. 
	-- @usage 
	-- locator:Assign("myModule", function() 
	--     ... 
	--     return myModule
	--   end)
	-- @todo Maybe the idioms recursive problem could be solved by first placing a value `false` under the key, so that it is located the next time and then overwritten.
	function locatorPrototype:Assign(key, creator)
		local location = rawget(self, key)
		if(not location)then
			location = creator(self, key)
			self[key] = location
		end
		return location
	end
	--- Removes currently located modules and classes.
	-- That causes them to be reloaded when accessed again, hence the name. 
	function locatorPrototype:Reload()
		for k, _ in pairs(locators) do
			self[k] = nil
		end
	end
	
	--- Creates a new @{Locator}.
	-- @constructor
	-- @tab t preexisting table to convert into a @{Locator} or `nil`
	-- @tparam {[string]=string} locators table mapping keys to relative paths (without the extension `.lua`) where to look for lua scripts defining the modules/classes or `nil`
	-- @string prefix directory prefix to where the path of the Locator is supposed to be with respect to the BtUtils root directory or `nil`
	-- @treturn Locator
	-- @treturn {[string]=string} `locators` parameter if specified or a new empty table that is used as the mapping
	-- @remark The `locators` mapping is a live table, so any changes to it end up affecting @{Locator}s functionality. That also relates to the possiblity of not defining it at the time of creating the @{Locator}, but by adding entries to the table returned as a second return value.
	function Locator:New(t, locators, prefix)
		prefix = prefix or ""
		locators = locators or {}
		return setmetatable(t or {}, {
			__index = function(self, key)
				-- prototype functions are lookup up first, so that the key doesn't even go towards the locating code
				-- (which could lead to recursion)
				local prototypeValue = locatorPrototype[key]
				if(prototypeValue ~= nil)then
					return prototypeValue
				end
			
				local locator = locators[key]
				if(locator)then
					local result = type(locator) == "string" and include(prefix .. locator) or select(locator[2], include(prefix .. locator[1]))
					rawset(self, key, result)
					return result
				else
					return nil
				end
			end
			-- newindex is left out, so that other scripts can hang their objects on the table even when evaluated from outside
		}), locators
	end

	-- BtUtils is an instance of a Locator
	-- the return value is in brackets as we do not want to return our locators map
	return (Locator:New({ Locator = Locator }, locators));
end)()

-- export the BtUtils into the global space, although users are expected to capture the return value
BtUtils = WG.BtUtils

--[[

 scripts that depend on being created only once (e.g. it works with a specific file) or when it needs to access
 other utils should  enforce that they are only loaded through BtUtils by starting with the following line:
 
	 if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end
	 
]]

return WG.BtUtils