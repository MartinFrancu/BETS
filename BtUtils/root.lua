WG = WG or {}
WG.BtUtils = WG.BtUtils or (function()
	local locators = {
		Sentry = "sentry",
		JSON = "JSON",
		Dependency = "dependency",
		BehaviourTree = "behaviour-tree",
		Debug = "debug_utils/",
	}
	
	local LOCAL_PATH = LUAUI_DIRNAME .. "Widgets/BtUtils/"
	local function include(name)
		if(name:sub(name:len()) == "/")then
			name = name .. "root"
		end
		
		return VFS.Include(LOCAL_PATH .. name .. ".lua", nil, VFS.RAW_FIRST)
	end

	-- creating Locator, which is the only object that needs to be created directly, as it's a bootstrapper
	local Locator = {};
	function Locator:New(t, locators, prefix) -- returns both altered parameters as a result
		prefix = prefix or ""
		locators = locators or {}
		return setmetatable(t or {}, {
			__index = function(self, key)
				-- special handling for setting the key if it doesn't exist yet without invoking the automatic include
				-- (which could lead to recursion)
				if(key == "Assign")then
					return function(self, key, creator)
						local location = rawget(self, key)
						if(not location)then
							location = creator(self, key)
							self[key] = location
						end
						return location
					end
				elseif(key == "Reload")then
					return function(self)
						for k, _ in pairs(locators) do
							self[k] = nil
						end
					end
				end
			
				local locator = locators[key]
				if(locator)then
					local result = include(prefix .. locator)
					rawset(self, key, result)
					return result
				else
					return nil
				end
			end
			-- newindex is left out, so that other scripts can hang their objects on the table even when evaluated from outside
		}), locators
	end

	return (Locator:New({ Locator = Locator }, locators));
end)()

-- export the BtUtils into the global space, although users are 
BtUtils = WG.BtUtils

--[[

 scripts that depend on being created only once (e.g. it works with a specific file) or when it needs to access
 other utils should  enforce that they are only loaded through BtUtils by starting with the following line:
 
	 if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end
	 
]]

return WG.BtUtils