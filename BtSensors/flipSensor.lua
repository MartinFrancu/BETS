local current = true;
return function()
	current = not current
	return current
end