if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils
return Utils:Assign("BehaviourTree", function()
	local BehaviourTree = {}
	
	local JSON = Utils.JSON
	
	function BehaviourTree.loadFromFile(path)
		local file = io.open(path, "r")
		local result = JSON:decode(file:read("*all"))
		file:close()
		
		return result
	end

	function BehaviourTree.saveToFile(bt, path)
		local file = io.open(path, "w")
		file:write(JSON:encode_pretty(bt))
		file:close()
	end
	
	return BehaviourTree
end)
