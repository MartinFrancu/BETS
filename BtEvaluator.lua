function widget:GetInfo()
	return {
		name      = "BtEvaluator",
		desc      = "BtEvaluator implementation.",
		author    = "Michal Mojzik",
		date      = "2017-09-21",
		license   = "MIT",
		layer     = 0,
		enabled   = true, --  loaded by default?
		version   = version,
	}
end

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
local Sanitizer = Utils.Sanitizer
local program = Utils.program

program(function()
	local Debug = Utils.Debug
	local Logger = Debug.Logger

	NOTA_MODULE_PATH = "../../../LuaRules/modules/btEvaluator/data/"
	
	local nativeLibraryPresent = require("BtEvaluatorProxy/findAI")
	local gadgetModulePresent = exists("BtEvaluatorLua/" .. NOTA_MODULE_PATH .. "init")
	local nativeSelected = nativeLibraryPresent
	
	if(nativeLibraryPresent and gadgetModulePresent)then
		function WG.BtEvaluatorSwitch()
			nativeSelected = not nativeSelected
			widgetHandler:RemoveWidget(widget)
		end
	end
	
	local loadImplementation
	function loadImplementation()
		loadImplementation = function() end
		if(not nativeLibraryPresent and not gadgetModulePresent)then
			Logger.error("BtEvaluator", "No BtEvaluator implementation is present (neither BtEvaluator C++ AI, nor a gadget module).")
			widgetHandler:RemoveWidget()
			return
		end
		
		if(nativeSelected)then
			require("BtEvaluatorProxy/")
		else
			require("BtEvaluatorLua/")
		end
		Sanitizer.sanitizeWidget(widget)
		return true
	end
	
	function widget:SetConfigData(data)
		if(data.selected == "library")then
			nativeSelected = true
		elseif(data.selected == "module")then
			nativeSelected = false
		end
		loadImplementation()
	end
	function widget:GetConfigData()
		return { selected = nativeSelected and "library" or "module" }
	end
	function widget:Initialize()
		if(loadImplementation())then
			widget:Initialize()
		end
	end
end)

Sanitizer.sanitizeWidget(widget)