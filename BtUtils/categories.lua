--- This part of BtUtils is supposed to take care of unit categories definitions. 
-- @module UnitCategories


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
		
	--- Returns entry corresponding to a given category.
	-- @string qualifiedName Qualified name of the category.
	-- @treturn tab Table containing a list of tables in `types` that describe the `name` of units in the category.
	function UnitCategories.loadCategory(qualifiedName)
		local path = ProjectManager.findFile(contentType, qualifiedName)
		if(not path)then
			Logger.log("categories", "Could not localize cateogry file: ", qualifiedName )
			return false,  "Could not localize cateogry file: " .. qualifiedName 
		end
		
		local file = VFS.LoadFile(path)
		if(not file)then
			Logger.log("categories", "Unable to read category definition file: ", path )
			return false, "Unable to read category definition file: " .. path
		end
		local data = JSON:decode(file)
		return data
	end
	--- Get types in given category.
	-- @string qualifiedName Qualified name of the category.
	-- @treturn {tab} List of tables with `name` of units in the category.
	function UnitCategories.getCategoryTypes(qualifiedName)
		local data, message = UnitCategories.loadCategory(qualifiedName)
		if(not data) then
			Logger.log("categories", "UnitCategories: Incorrect file.")
			return false, message
		end
		return data.types
	end
	--- Returns array of names of available categories.
	-- @treturn {string}
	function UnitCategories.getAllCategoryNames() 
		local result = {}
		local categories = ProjectManager.listAll(contentType)
		
		for i,catData in pairs(categories) do
			result[i] = catData.qualifiedName
		end
		return result
	end
	
	--- Saves a category.
	-- @tab catDefinition Category definition containing `project` name, category `name` and `types` containing list of `name`s of the units.
	function UnitCategories.saveCategory(catDefinition)
		if(not ProjectManager.isProject(catDefinition.project))then
			-- if new project I should create it 
			ProjectManager.createProject(catDefinition.project)
		end
		
		-- should save category data:
		local path,params = ProjectManager.findFile(contentType, catDefinition.project, catDefinition.name)
		
		if(params.readonly)then
			return false, "Category file " .. 
				tostring(catDefinition.project).. "."..tostring(catDefinition.name) .. " is read-only."
		end
		
		Spring.CreateDir(path:match("^(.+)/"))
		local text = JSON:encode( {types = catDefinition.types}, nil, { pretty = true, indent = "\t"})
		local file = io.open(path, "w")
		if(not file)then
			Logger.log("categories", "saveCategories: unable to write in file: ", path)
			return false, "saveCategories: unable to write in file: " .. path
		end
		file:write(text)
		file:close()
		return true
	end
	return UnitCategories
end)