--- Finds the appropriate version if it is available in WG, otherwise returns a surrogate

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils
return Utils:Assign("Chili", function()
	local Surrogate = Utils.Surrogate
	return WG.ChiliClone or Surrogate:New(function()
		if(WG.ChiliClone)then
			Utils.Chili = WG.ChiliClone
		end
		return WG.ChiliClone
	end)
end)