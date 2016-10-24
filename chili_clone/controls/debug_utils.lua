--//=============================================================================
-- DEBUG functions
--//=============================================================================
function dump(o, maxDepth)
	maxDepth = maxDepth or 1
  if type(o) == 'table' then
		if (maxDepth == 0) then 
			return "..." 
		end
		if (o.name ~= nil) then -- For outputing chili objects
			return o.name
		end
		local s = '{ '
		for k,v in pairs(o) do
			 if type(k) ~= 'number' then k = '"'..k..'"' end
			 s = s .. '['..k..'] = ' .. dump(v, maxDepth-1) .. ','
		end
		return s .. '} '
 else
		return tostring(o)
 end
end

function copyTable(obj, seen)
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[copyTable(k, s)] = copyTable(v, s) end
  return res
end
--//=============================================================================