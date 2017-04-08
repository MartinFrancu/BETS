--- Function to remove an extension from a filename.
-- @module removeExtension

local removeExtension

--- Removes extension from the filename
function removeExtension(path)
	return path:match("^(.+)%..+$")
end

return removeExtension

