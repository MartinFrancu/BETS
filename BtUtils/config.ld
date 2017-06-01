--[[
  This file serves as a configuration for generating the documentation of BtUtils.
  
  To generate the documentation, use "ldoc .". You can install ldoc from http://stevedonovan.github.io/ldoc/
]]

project = "BETS"
package = "BtUtils"

file = "."
title = "BETS documentation"
description = "Behaviour Editing Toolkit for SpringRTS"

-- included so that nested locators are shown in a logical order
sort = true

-- allows usage of Markdown, especially the use of backticks for <code> blocks
format = 'markdown'

local prototypePattern = "(%w+)Prototype([.:])"

-- custom handler to have the generated documentation comply with our coding style
-- and also allows some hackish solutions for the generated documentation to have the names we want
-- it also removes a trailing dot when specifying fields of an inner class
custom_display_name_handler = function(item, default_handler)
	if item.type == 'function' then
    -- according to our convention:
    -- functions starting with capital letter are supposed to be invoked as a method (with ':')
    -- while functions starting with non-capital letter are supposed to be invoked as a regular function
		item.name = item.name:gsub(":([a-z])", ".%1"):gsub("%.([A-Z])", ":%1")
	elseif item.type == 'table' then
    -- removes the trailing dot, so that we can specify the fields of a class as field of a specifically named table
    -- (if the trailing dot is not specified, LDoc includes the module/class name, even though it shouldn't be there)
		item.name = item.name:gsub("%.$", "")
	end
  
  -- allows the usage of namePrototype alongside class Name for storing methods,
  -- where the methods namePrototype end up appearing as belonging to Name itself
  item.name = item.name:gsub(prototypePattern, function(name, separator) return name:sub(1, 1):upper() .. name:sub(2) .. separator end)
	
	return default_handler(item)
end

-- custom see handler to properly reference external libraries
custom_see_handler('JSON', function()
  return 'JSON', 'http://regex.info/blog/lua/json'
end)
custom_see_handler('Chili', function()
  return 'Chili', 'https://gajop.github.io/chiliui/index.html'
end)
custom_see_handler('VFS', function()
  return 'VFS', 'https://springrts.com/wiki/Lua_VFS'
end)
custom_see_handler('VFS.DirList', function()
  return 'VFS.DirList', 'https://springrts.com/wiki/Lua_VFS#Files'
end)
custom_see_handler('VFS.SubDirs', function()
  return 'VFS.SubDirs', 'https://springrts.com/wiki/Lua_VFS#Files'
end)
custom_see_handler('widget', function()
  return 'widget', 'https://en.wikibooks.org/wiki/Lua_in_SpringRTS/Widgets'
end)

-- adds the Remarks section to methods, functions etc.
custom_tags = { { "remark", title = "Remarks" } }

-- allows BtUtils and the likes to be called Locators and not be called modules -- that way, 'singleton classes' like Logger can be properly called Module
new_type("locator", "Locators", true)

-- allows specifying typed fields
alias('tfield',{'field',modifiers={type="$1"}})