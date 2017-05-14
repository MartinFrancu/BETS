--- .
-- @module CategoryManager

local CustomEnvironment = Utils.CustomEnvironment
local Logger = Utils.Debug.Logger
local UnitCategories = Utils.UnitCategories
local ProjectManager = Utils.ProjectManager

local categories = {}
local CategoryManager = {}

function CategoryManager.loadCategory(...)
	local categoryData, message = UnitCategories.loadCategory(...)
	if(not categoryData)then
		return nil, message
	end
	
	local idToDataMap = {}
	local nameToDataMap = {}
	for i, data in ipairs(categoryData.types) do
		idToDataMap[data.id] = data
		nameToDataMap[data.name] = data
	end
	
	return setmetatable({}, {
		__index = setmetatable(idToDataMap, { __index = nameToDataMap }),
		__newindex = function() end -- disable modifications
	})
end

local managers
managers = setmetatable({
	Reload = function(self)
		local keys = {}
		for k, _ in pairs(self) do
			if(k ~= "Reload")then
				table.insert(keys, k)
			end
		end
		for _, k in ipairs(keys) do
			rawset(self, k, nil)
		end
		CategoryManager.reload()
	end
}, {
	__index = function(self, projectName)
		if(not ProjectManager.isProject(projectName))then
			return nil
		end
		
		local manager = setmetatable({ Reload = function() managers:Reload() end }, {
			__index = function(self, key)
				local qualifiedName = ProjectManager.asQualifiedName(projectName, key)
				local category = categories[qualifiedName]
				if(not category)then
					category = CategoryManager.loadCategory(qualifiedName)
					if(not category)then
						return managers[key]
					end
					categories[qualifiedName] = category
				end
				rawset(self, key, category)
				return category
			end,
		})
		rawset(self, projectName, manager)
		return manager
	end,
})
function CategoryManager.forProject(localProject)
	return managers[localProject] or managers
end

function CategoryManager.reload()
	categories = {}
	managers:Reload()
end

CustomEnvironment.add("Categories", { }, function(p)
	return CategoryManager.forProject(p.project)
end)

return CategoryManager