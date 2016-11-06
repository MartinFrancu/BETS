local function dump(o, maxDepth)
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
  elseif type(o) == 'string' then
    return string.format("%q", o)
  else
		return tostring(o)
  end
end

return dump