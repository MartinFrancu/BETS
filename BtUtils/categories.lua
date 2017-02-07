-- This part of BtUtils is supposed to take care of unit categories definitions. 


if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end;

local Utils = BtUtils
local Logger = Utils.Debug.Logger

return Utils:Assign("UnitCategories", function()
	local UnitCategories = {}
	
	local UNIT_CATHEGORIES_DIRNAME = LUAUI_DIRNAME .. "Widgets/BtCreator/"
	local UNIT_CATHEGORIES_FILE = "BtUnitCategories.json"
	
	local JSON = Utils.JSON
	
	-- This function load categories from given file and returns them as a table
	local function loadCategories()
		local unitCategories = {}
		local file = io.open(UNIT_CATHEGORIES_DIRNAME .. UNIT_CATHEGORIES_FILE , "r")
		if(not file)then
			unitCategories = {}
		end
		local text = file:read("*all")
		unitCategories = JSON:decode(text)
		file:close()
		return unitCategories
	end
	-- This function saves given table into file fo unit categories
	local function saveCategories(categories)
		if(unitCategories == nil) then
			Logger.log("roles", "BtUtils:SaveUnitCategories: categories = nill")
			unitCategories = {}
		end
	
		local text = JSON:encode(unitCategories, nil, { pretty = true, indent = "\t" })
		Spring.CreateDir(UNIT_CATHEGORIES_DIRNAME)
		local file = io.open(UNIT_CATHEGORIES_DIRNAME .. UNIT_CATHEGORIES_FILE, "w")
		if(not file)then
			return nil
		end
		file:write(text)
		file:close()	
		return true
	end
	
	local function initCategories()
		if(UnitCategories.categories == nil) then
			UnitCategories.categories = loadCategories()
		end 
	end
	-- Returns table of categories
	function UnitCategories.getCategories()
		initCategories()
		return UnitCategories.categories
	end 
	-- Returns entry corresponding to given category:
	function UnitCategories.getCategoryTypes(categoryName)
		initCategories()
		for _,catData in pairs(UnitCategories.categories) do
			if (catData.name == categoryName) then
				return catData.types
			end
		end
	end
	-- returns array of names of availible categories.
	function UnitCategories.getAllCategoryNames() 
		initCategories()
		local result = {}
		for _,catData in pairs(UnitCategories.categories) do
			table.insert(result, catData.name)
		end
		return result
	end
	
	function UnitCategories.redefineCategories(newCategory) 
		initCategories()
		-- here would be a good moment for check if it makes sense?
		table.insert(UnitCatheogires.categories, newCategory)
		saveCategories()
	end
	return UnitCategories
end)