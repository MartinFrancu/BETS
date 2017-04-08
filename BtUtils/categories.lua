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
	
	-- This function load categories from given file and returns them as a table
	local function loadCategories(projectNameIn)
		local projectName
		if(projectNameIn ~= nil) then
			projectName = projectNameIn
		else
			projectName = "Common"
		end
		local unitCategories = {}
		
		local categoryFiles = ProjectManager.listProject(projectName, contentType)
		Logger.log("categories", "files: ", dump(categoryFiles,2) )
		for _,catFile in pairs(categoryFiles) do
			local path = catFile.path
			local file = io.open(path, "r")
			if(not file)then
				Logger.log("categories", "Unable to read category definition file: ", path )
				return unitCategories
			end
			local text = file:read("*all")
			file:close()
			local data = JSON:decode(text)
			-- should I check the category name??
			--local catName = fileName:sub(UNIT_CATEGORIES_PREFIX:len()+1, fileName:len() - UNIT_CATEGORIES_SUFFIX:len())
			table.insert(unitCategories, data)
		end
		--[[
		local folderContent = Utils.dirList(UNIT_CATEGORIES_DIRNAME, "*".. UNIT_CATEGORIES_SUFFIX)
		for _,fileName in pairs(folderContent) do
			local file = io.open(UNIT_CATEGORIES_DIRNAME .. fileName, "r")
			if(not file)then
				return unitCategories
			end
			local text = file:read("*all")
			file:close()
			local data = JSON:decode(text)
			-- should I check the category name??
			--local catName = fileName:sub(UNIT_CATEGORIES_PREFIX:len()+1, fileName:len() - UNIT_CATEGORIES_SUFFIX:len())
			table.insert(unitCategories, data)
		end
		]]
		return unitCategories
	end
	
	UnitCategories.categories = loadCategories()
	
	-- This function saves given table into file fo unit categories
	local function saveCategories(projectNameIn)
		-- DEBUG: use default project name
		local projectName
		if(projectNameIn ~= nil) then
			projectName = projectNameIn
		else
			projectName = "Common"
		end
		-------------------------------------------
		
		Spring.CreateDir(UNIT_CATEGORIES_DIRNAME) -- REMOVE LATER 
		for _,catData in ipairs(UnitCategories.categories) do
			local text = JSON:encode(catData, nil, { pretty = true, indent = "\t"})
			
			local path,params = ProjectManager.findFile(contentType, projectName, catData.name)
			Logger.log("categories", "path: " , path, " params: ", params)
			-- TODO check if i can write in this file
			local file = io.open(path, "w")
			if(not file)then
				Logger.log("categories", "saveCategories: unable to write in file: ", path)
				return nil
			end
			file:write(text)
			file:close()
			
			--[[ OLD save
			local fileName = UNIT_CATEGORIES_DIRNAME .. UNIT_CATEGORIES_PREFIX .. catData.name .. UNIT_CATEGORIES_SUFFIX 
			local file = io.open(fileName, "w")
			if(not file)then
				Logger.log("categories", "saveCategories: unable to write in file: ", fileName)
				return nil
			end
			file:write(text)
			file:close()
			]]
		end
		return true
	end
	
	-- Returns table of categories
	function UnitCategories.getCategories()
		return UnitCategories.categories
	end 
	-- Returns entry corresponding to given category:
	function UnitCategories.getCategoryTypes(categoryName)
		for _,catData in pairs(UnitCategories.categories) do
			if (catData.name == categoryName) then
				return catData.types
			end
		end
	end
	-- returns array of names of availible categories.
	function UnitCategories.getAllCategoryNames() 
		local result = {}
		for _,catData in pairs(UnitCategories.categories) do
			table.insert(result, catData.name)
		end
		return result
	end
	
	function UnitCategories.redefineCategories(newCategory)
		-- here would be a good moment for check if it makes sense?
		local alreadyKnown = false 
		for index,catData in pairs(UnitCategories.categories) do
			if(catData.name == newCategory.name) then
				alreadyKnown = true
				UnitCategories.categories[index] = newCategory
			end
		end
		if(alreadyKnown == false) then
			table.insert(UnitCategories.categories, newCategory)
		end
		saveCategories()
	end
	return UnitCategories
end)