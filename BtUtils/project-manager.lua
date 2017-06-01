--- Provides methods that allow to create and otherwise work with BETS projects.
-- There are two location in which projects can exist:
-- 
--   - `LuaUI/BETS/Projects`
--   - `LuaUI/Widgets/BtProjects` - for internal purposes
--
-- Project can also exist in two forms, a directory or an archive containing the SpringData directory structure.
-- @module ProjectManager
-- @pragma nostrip

-- tag @pragma makes it so that the name of the module is not stripped from the function names

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils
return Utils:Assign("ProjectManager", function()
	local ProjectManager = {}

	local Debug = Utils.Debug
	local Logger = Debug.Logger
	
	local dirList, subDirs = Utils.dirList, Utils.subDirs
	
	local PROJECT_PATH = LUAUI_DIRNAME .. "BETS/Projects/"
	local INTERNAL_PROJECT_PATH = LUAUI_DIRNAME .. "Widgets/BtProjects/"
	
	local TMP_DIR = PROJECT_PATH .. ".bets/"
	local CAPITALIZATION_FILE = ".capitalization"
	
	local projects = {}
	local archives = {}
	
	local function loadArchives()
		for _, projectsRoot in ipairs({ PROJECT_PATH, INTERNAL_PROJECT_PATH }) do
			for i, archiveName in ipairs(dirList(projectsRoot, "*.sdz")) do
				local path = projectsRoot .. archiveName
				VFS.MapArchive(path)
				archives[archiveName] = {
					name = archiveName,
					path = path,
				}
			end
		end
	end
	local function unloadArchives()
		for name, archive in pairs(archives) do
			VFS.UnmapArchive(archive.path)
		end
		archives = {}
	end

	local function loadProjects()
		for _, projectsRoot in ipairs({ PROJECT_PATH, INTERNAL_PROJECT_PATH }) do
			for i, projectName in ipairs(subDirs(projectsRoot)) do
				if(projectName:sub(1,1) ~= ".")then
					local path = projectsRoot .. projectName .. "/"
					local capitalization = VFS.LoadFile(path .. CAPITALIZATION_FILE)
					if(capitalization and capitalization:lower() == projectName:lower())then
						projectName = capitalization
					end
					if(not projects[projectName])then
						projects[projectName] = {
							name = projectName,
							path = path,
							isArchive = not subDirs(projectsRoot, projectName, VFS.RAW)[1], -- check whether the subdirectory exists outside of an archive
						}
					end
				end
			end
		end
	end
	
	--- Unloads all projects.
	-- @remark Useful when working with archives, that you would like to manipule on the drive, but they are locked. Calling this should load to their unlocking (except it doesn't, because unmapping archives doesn't actually work in SpringRTS).
	function ProjectManager.unload()
		projects = {}
		unloadArchives()
	end
	--- Reloads the list of projects.
	function ProjectManager.reload()
		ProjectManager.unload()
		ProjectManager.load()
	end
	--- Loads all project information from disk.
	function ProjectManager.load()
		loadArchives()
		loadProjects()
	end
	
	-- checks that the specified folder is empty
	local function checkEmptyDirectory(path)
		if(dirList(path)[1])then
			return false
		end
		
		for i, subdir in ipairs(subDirs(path)) do
			if(not checkEmptyDirectory(path .. subdir .. "/"))then
				return false
			end
		end
		return true
	end
	
	--- Produces an archive out of a project with the given name.
	-- The archive can then be e.g. send to other users of BETS.
	-- @tparam string projectName Name of the project to produce the archive from.
	-- @return `true` if successful, `false` otherwise
	function ProjectManager.archivate(projectName)
		local project = projects[projectName]
		if(not project)then
			return nil, "Project " .. tostring(projectName) .. " could not be found."
		end
		if(project.isArchive)then
			return nil, "Project " .. tostring(projectName) .. " is already in an archive."
		end
		
		Spring.CreateDir(TMP_DIR .. PROJECT_PATH)
		if(not checkEmptyDirectory(TMP_DIR))then
			error("The " .. TMP_DIR .. " directory is not empty. There may be some leftover files from previous archivations. Manual intervention necessary.")
		end
		
		os.rename(project.path, TMP_DIR .. PROJECT_PATH .. projectName) -- move to the archivation directory
		local success, msg = pcall(function()
			local capitalizationFile = io.open(TMP_DIR .. PROJECT_PATH .. projectName .. "/" .. CAPITALIZATION_FILE, "w")
			capitalizationFile:write(projectName)
			capitalizationFile:close()
			return VFS.CompressFolder(TMP_DIR, "zip", PROJECT_PATH .. "/" .. projectName .. ".sdz", false, VFS.RAW)
		end)
		os.remove(TMP_DIR .. PROJECT_PATH .. projectName .. "/" .. CAPITALIZATION_FILE)
		os.rename(TMP_DIR .. PROJECT_PATH .. projectName, project.path) -- move back
		
		return success, msg
	end
	--- Returns a list of all projects.
	-- @treturn {tab} List of project paramters, such as their `name`, their `path` and whether the specific project `isArchive`
	function ProjectManager.getProjects()
		local result, i = {}, 1
		for projectName, project in pairs(projects) do
			result[i] = project
			i = i + 1
		end
		return result
	end
	--- Checks whether the given value is a name of a loaded project.
	-- @string projectName The name of the project to be checked.
	function ProjectManager.isProject(projectName)
		return not not projects[projectName]
	end
	--- Forms a qualified name out of the project name and content name.
	-- @string projectName Project name.
	-- @string name Content name.
	-- @treturn string Qualified name, as in `<project>.<name>`.
	function ProjectManager.asQualifiedName(projectName, name)
		if(not name)then
			return nil
		end
		if(not projectName)then
			return name
		end
		
		return projectName .. "." .. name
	end
	--- Parse the given qualified name and outputs project and content names.
	-- @string qualifiedName Qualified name.
	-- @treturn[1] string Project name.
	-- @treturn[1] string Content name.
	-- @return[2] `nil`, if the given name is not a valid qualifiedName
	function ProjectManager.fromQualifiedName(qualifiedName)
		return qualifiedName:match("^(.-)%.(.+)$")
	end
	
	--- Creates a new project.
	-- Fails if a project with the same name already exists.
	-- @string projectName The name of the new project.
	-- @return `true`
	function ProjectManager.createProject(projectName)
		if(projects[projectName])then
			return nil, "Project " .. projectName .. " already exists"
		end
		
		local path = PROJECT_PATH .. projectName .. "/"
		Spring.CreateDir(path)
		projects[projectName] = {
			name = projectName,
			path = path,
			isArchive = false
		}
		
		return true
	end
	
	--- Locates the position of a file based on its type and name.
	-- The file doesn't necesarily need to exist, thus allowing to use this method even when finding where to store a file.
	-- @tparam ContentType contentType 
	-- @string qualifiedName Full qualified name or only a name of a project, with name specified by parameter `name`.
	-- @string[opt] name The name of the content.
	-- @treturn string Path to the file.
	-- @treturn tab Parameters of the file, such as `project` name, content `name`, whether the file `exists` and whether the project is `readonly`.
	function ProjectManager.findFile(contentType, qualifiedName, name)
		local projectName
		if(name)then
			projectName = qualifiedName
			name = name
		else
			projectName, name = qualifiedName:match("^(.-)%.(.+)$")
		end
		
		local project = projects[projectName]
		if(not project)then
			return nil, "Project " .. tostring(projectName) .. " could not be found."
		end
		
		local path = project.path .. (contentType.directoryName and (contentType.directoryName .. "/") or "") .. contentType.nameToFile(name)

		return path, {
			project = projectName,
			name = name,
			qualifiedName = ProjectManager.asQualifiedName(projectName, name),
			exists = VFS.FileExists(path),
			readonly = project.isArchive
		}
	end
	
	local function listProjectInternal(result, i, project, contentType)
		for j, v in ipairs(dirList(project.path .. (contentType.directoryName or ""), contentType.fileMask)) do
			local name = contentType.fileToName(v)
			result[i] = {
				project = project.name,
				name = name,
				qualifiedName = ProjectManager.asQualifiedName(project.name, name),
				filename = v,
				path = project.path .. (contentType.directoryName and (contentType.directoryName .. "/") or "") .. v,
			}
			i = i + 1
		end
		return result, i
	end
	
	--- Lists all files in a project of the specific @{ContentType}.
	-- @string projectName Name of a project.
	-- @tparam ContentType contentType
	-- @treturn {tab} List of table describing the parameters of the files, such as their `name` and `path`.
	function ProjectManager.listProject(projectName, contentType)
		local project = projects[projectName]
		if(not project)then
			return nil, "Project " .. tostring(projectName) .. " could not be found."
		end
		
		local result, i = {}, 1
		return (listProjectInternal({}, 1, project, contentType))
	end
	--- Lists all files in all loaded projects of the specific @{ContentType}.
	-- @tparam ContentType contentType
	-- @treturn {tab} List of table describing the parameters of the files, such as their `name` and `path`.
	function ProjectManager.listAll(contentType)
		local result, i = {}, 1
		for projectName, project in pairs(projects) do
			result, i = listProjectInternal(result, i, project, contentType)
		end
		return result
	end

	--- Creates a content type using the specified directory name and extension.
	-- @string subdirectory The directory name in which the content exists within a project.
	-- @string extension Extension that is used for the file of that content.
	-- @treturn ContentType
	function ProjectManager.makeRegularContentType(subdirectory, extension)
		return {
			directoryName = subdirectory,
			fileMask = "*." .. extension,
			nameToFile = function(name) return name .. "." .. extension end,
			fileToName = Utils.removeExtension,
		}
	end
	
	--- 
	-- @type ContentType
	
	--- Specifies where content can be found inside the project directory.
	-- @table ContentType.
	-- @tfield string directoryName In what directory is the content.
	-- @tfield string fileMask What filter should be used to find the list of files of that content.
	-- @tfield func nameToFile Transformation from name of the content to filename.
	-- @tfield func fileToName Transofmration from filename to the name of the content.
	
	ProjectManager.load()
	return ProjectManager
end)