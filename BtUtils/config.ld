--[[
  This file serves as a configuration for generating the documentation of BtUtils.
  
  To generate the documentation, use "ldoc .". You can find ldoc at http://stevedonovan.github.io/ldoc/
  
  -- Works In Progress --
]]

project = "BETS"

file = "."
title = "BETS documentation"
description = "Behaviour Editing Toolkit for SpringRTS"

-- custom handler to have methods, that start with a non-capital letter, not include colon but a dot,
-- as to correspond to the way they are supposed to be invoked
custom_display_name_handler = function(item, default_handler)
  if item.type == 'function' then
    item.name = item.name:gsub(":([a-z])", ".%1")
  end
  return default_handler(item)
end