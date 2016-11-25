--[[
  This file serves as a configuration for generating the documentation of BtUtils.
  
  To generate the documentation, use "ldoc .". You can find ldoc at http://stevedonovan.github.io/ldoc/
  
  -- Work In Progress --
]]

project = "BETS"
package = "BtUtils"
sort = true

file = "."
title = "BETS documentation"
description = "Behaviour Editing Toolkit for SpringRTS"

format = 'markdown'

-- custom handler to have methods, that start with a non-capital letter, not include colon
-- but a dot, and vice-versa, as to correspond to the way they are supposed to be invoked,
-- (as our convention and function specifications differs from the one LDoc assumes)
-- it also removes a trailing dot when specifying fields of an inner class
custom_display_name_handler = function(item, default_handler)
	if item.type == 'function' then
		item.name = item.name:gsub(":([a-z])", ".%1"):gsub("%.([A-Z])", ":%1")
	elseif item.type == 'table' then
		item.name = item.name:gsub("%.$", "")
	end
	return default_handler(item)
end

custom_tags = { { "remark", title = "Remarks" } }
new_type("locator", "Locators", true)
alias('tfield',{'field',modifiers={type="$1"}})