--- Function to remove an extension from a filename.
-- @module removeExtension

local removeExtension

--- Removes extension from the filename
-- @string path filename
-- @treturn string Filename without the extension
function removeExtension(path)
	return path:match("^(.+)%..+$")
end

return removeExtension

