--- Loads and allows to work with BETS projects.
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
				if(projectName:sub(1,1) ~= "." and not projects[projectName])then
					local path = projectsRoot .. projectName .. "/"
					projects[projectName] = {
						name = projectName,
						path = path,
						isArchive = not subDirs(projectsRoot, projectName, VFS.RAW)[1], -- check whether the subdirectory exists outside of an archive
					}
				end
			end
		end
	end
	
	function ProjectManager.unload()
		projects = {}
		unloadArchives()
	end
	function ProjectManager.reload()
		ProjectManager.unload()
		ProjectManager.load()
	end
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
	
	function ProjectManager.archivate(projectName)
		local project = projects[projectName]
		if(not project)then
			return nil, "Project " .. tostring(projectName) .. " could not be found."
		end
		
		Spring.CreateDir(TMP_DIR .. PROJECT_PATH)
		if(not checkEmptyDirectory(TMP_DIR))then
			error("The " .. TMP_DIR .. " directory is not empty. There may be some leftover files from previous archivations. Manual intervention necessary.")
		end
		
		os.rename(project.path, TMP_DIR .. PROJECT_PATH .. projectName) -- move to the archivation directory
		local success, msg = pcall(VFS.CompressFolder, TMP_DIR, "zip", PROJECT_PATH .. "/" .. projectName .. ".sdz", false, VFS.RAW)
		os.rename(TMP_DIR .. PROJECT_PATH .. projectName, project.path) -- move back
		
		return success, msg
	end
	function ProjectManager.getProjects()
		local result, i = {}, 1
		for projectName, project in pairs(projects) do
			result[i] = project
			i = i + 1
		end
		return result
	end
	
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
		--[[
		if(not VFS.FileExists(path))then
			return nil, "File " .. path .. " does not exist."
		end
		]]

		return path, {
			project = projectName,
			name = name,
			qualifiedName = projectName .. "." .. name,
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
				qualifiedName = project.name .. "." .. name,
				filename = v,
				path = project.path .. (contentType.directoryName and (contentType.directoryName .. "/") or "") .. v,
			}
			i = i + 1
		end
		return result, i
	end
	
	function ProjectManager.listProject(projectName, contentType)
		local project = projects[projectName]
		if(not project)then
			return nil, "Project " .. tostring(projectName) .. " could not be found."
		end
		
		local result, i = {}, 1
		return (listProjectInternal({}, 1, project, contentType))
	end
	function ProjectManager.listAll(contentType)
		local result, i = {}, 1
		for projectName, project in pairs(projects) do
			result, i = listProjectInternal(result, i, project, contentType)
		end
		return result
	end

	function ProjectManager.makeRegularContentType(subdirectory, extension)
		return {
			directoryName = subdirectory,
			fileMask = "*." .. extension,
			nameToFile = function(name) return name .. "." .. extension end,
			fileToName = Utils.removeExtension,
		}
	end
	
	ProjectManager.load()
	return ProjectManager
end)