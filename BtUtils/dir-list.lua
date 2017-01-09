--- Function to list the content of a directory.
-- Opossed to the VFS.DirList function, this one returns the actual names/relative paths.
-- @module dirList

local dirList

--- Returns the files from the specified directory.
-- @string path The directory to list.
-- @string mask The mask of the files to be returned.
-- @treturn [string] The names of the files within the directory
function dirList(path, mask)
	path = path:gsub("\\", "/") -- normalization of the path to use regular slashes only
	local pathLen = path:len();
	
	local maskPattern = "^" .. mask:gsub("([-+.])", "%%%1"):gsub("*", ".-"):gsub("?", ".") .. "$"
	
	local result = VFS.DirList(path)
	local count = #result;
	local j = 1;
	for i = 1, count do
		local file = result[i]
		file = file:gsub("\\", "/");
		if(file:sub(1, pathLen) == path)then
			file = file:sub(pathLen + 1)
			if(file:sub(1,1) == "/")then
				file = file:sub(2)
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

return dirList