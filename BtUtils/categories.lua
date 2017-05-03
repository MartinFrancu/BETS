-- This part of BtUtils is supposed to take care of unit categories definitions. 


if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end;

local Utils = BtUtils
local Logger = Utils.Debug.Logger
local dump = Utils.Debug.dump



return Utils:Assign("UnitCategories", function()
	local UnitCategories = {}
	
	local UNIT_CATEGORIES_DIRNAME = LUAUI_DIRNAME .. "Widgets/BtCreator/Categories/"
	local UNIT_CATEGORIES_PREFIX = "BtUnitCategory_"
	local UNIT_CATEGORIES_SUFFIX = ".json"
	local UNIT_CATEGORIES_FILE = "BtUnitCategories.json"
	
	
	local JSON = Utils.JSON
	local ProjectManager = Utils.ProjectManager
	
	local contentType =  ProjectManager.makeRegularContentType("UnitCategories", "json")
	UnitCategories.contentType = contentType
		
	-- Returns entry corresponding to given category:
	function UnitCategories.loadCategory(qualifiedName)
		Logger.log("categories", "ct:", dump(contentType), " qN: ", dump(qualifiedName) )
		local path = ProjectManager.findFile(contentType, qualifiedName)
		if(not path)then
			Logger.log("categories", "Could not localize cateogry file: ", qualifiedName )
		end
		local file = io.open(path, "r")
		if(not file)then
			Logger.log("categories", "Unable to read category definition file: ", path )
			return nil
		end
		local text = file:read("*all")
		file:close()
		local data = JSON:decode(text)
		return data
	end
	-- Get types in given category:
	function UnitCategories.getCategoryTypes(qualifiedName)
		local data = UnitCategories.loadCategory(qualifiedName)
		if(data.types == nil) then
			Logger.log("categories", "UnitCategories: Incorrect file.")
			return nil
		end
		return data.types
	end
	-- returns array of names of availible categories.
	function UnitCategories.getAllCategoryNames() 
		local result = {}
		local categories = ProjectManager.listAll(contentType)
		
		for i,catData in pairs(categories) do
			result[i] = catData.qualifiedName
		end
		return result
	end
	
	function UnitCategories.saveCategory(catDefinition)
		if(not ProjectManager.isProject(catDefinition.project))then
			-- if new project I should create it 
			ProjectManager.createProject(catDefinition.project)
		end
		
		-- should save category data:
		local path,params = ProjectManager.findFile(contentType, catDefinition.project, catDefinition.name)
		
		if(params.readonly)then
			return nil, "Category file " .. 
				tostring(catDefinition.project).. "."..tostring(catDefinition.name) .. " is read-only."
		end
		
		Spring.CreateDir(path:match("^(.+)/"))
		local text = JSON:encode(catDefinition, nil, { pretty = true, indent = "\t"})
		local file = io.open(path, "w")
		if(not file)then
			Logger.log("categories", "saveCategories: unable to write in file: ", path)
			return nil
		end
		file:write(text)
		file:close()
		return true
	end
	return UnitCategories
end)