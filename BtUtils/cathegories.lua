-- This part of BtUtils is supposed to take care of unit cathegories definitions. 


if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end;

local Utils = BtUtils
local Logger = Utils.Debug.Logger

return Utils:Assign("UnitCathegories", function()
	local UnitCathegories = {}
	
	local UNIT_CATHEGORIES_DIRNAME = LUAUI_DIRNAME .. "Widgets/BtCreator/"
	local UNIT_CATHEGORIES_FILE = "BtUnitCathegories.json"
	
	local JSON = Utils.JSON
	
	-- This function load cathegories from given file and returns them as a table
	local function loadCathegories()
		local unitCathegories = {}
		local file = io.open(UNIT_CATHEGORIES_DIRNAME .. UNIT_CATHEGORIES_FILE , "r")
		if(not file)then
			unitCathegories = {}
		end
		local text = file:read("*all")
		unitCathegories = JSON:decode(text)
		file:close()
		return unitCathegories
	end
	-- This function saves given table into file fo unit cathegories
	local function saveCatheogires(cathegories)
		if(unitCathegories == nil) then
			Logger.log("roles", "BtUtils:SaveUnitCathegories: cathegories = nill")
			unitCathegories = {}
		end
	
		local text = JSON:encode(unitCathegories, nil, { pretty = true, indent = "\t" })
		Spring.CreateDir(UNIT_CATHEGORIES_DIRNAME)
		local file = io.open(UNIT_CATHEGORIES_DIRNAME .. UNIT_CATHEGORIES_FILE, "w")
		if(not file)then
			return nil
		end
		file:write(text)
		file:close()	
		return true
	end
	
	local function initCathegories()
		if(UnitCathegories.cathegories == nil) then
			UnitCathegories.cathegories = loadCathegories()
		end 
	end
	-- Returns table of cathegories
	function UnitCathegories.getCathegories()
		initCathegories()
		return UnitCathegories.cathegories
	end 
	-- Returns entry corresponding to given cathegory:
	function UnitCathegories.getCathegoryTypes(cathegoryName)
		initCathegories()
		for _,catData in pairs(UnitCathegories.cathegories) do
			if (catData.name == cathegoryName) then
				return catData.types
			end
		end
	end
	
	return UnitCathegories
end)