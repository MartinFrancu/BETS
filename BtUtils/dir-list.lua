--- Function to list the content of a directory.
-- Opossed to the VFS.DirList and VFS.SubDirs functions, this one returns the actual names/relative paths.
-- @module directoryListing

--- Normalizes the path to use regular slashes only
local function normalizePath(path)
	return path:gsub("\\", "/")
end

local function directoryListing(path, mask, listingFunction)
	path = normalizePath(path)
	local pathLen = path:len();
	
	local maskPattern = mask and "^" .. mask:gsub("([-+.])", "%%%1"):gsub("*", ".-"):gsub("?", ".") .. "$" or ".-"
	
	local result = listingFunction(path)
	local count = #result;
	local j = 1;
	for i = 1, count do
		local file = result[i]
		file = normalizePath(file);
		if(file:sub(1, pathLen) == path)then
			file = file:sub(pathLen + 1)
			if(file:sub(1,1) == "/")then
				file = file:sub(2)
			end
			if(file:sub(file:len()) == "/")then
				file = file:sub(1, file:len() - 1)
			end
			
			if(file:match(maskPattern))then
				result[j] = file
				j = j + 1
			end
		end
	end
	for i = j, count do
		result[i] = nil
	end
	
	return result
end


local dirList
--- Returns the files from the specified directory.
-- @string path The directory to list.
-- @string mask The mask of the files to be returned.
-- @treturn [string] The names of the files within the directory
function dirList(path, mask)
	return directoryListing(path, mask, VFS.DirList)
end

local subDirs
--- Returns the subdirectories from the specified directory.
-- @string path The directory to list.
-- @string mask The mask of the subdirectories to be returned.
-- @treturn [string] The names of the subdirectories within the directory
function subDirs(path, mask)
	return directoryListing(path, mask, VFS.SubDirs)

end

return dirList, subDirs