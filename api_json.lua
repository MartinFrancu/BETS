function widget:GetInfo()
  return {
    name      = "JSON",
    desc      = "JSON",
    author    = "Jeffrey Friedl",
    date      = "Sep 20, 2016",
    license   = "BY",
    version   = "0.1",
    layer     = -1000,
    enabled   = true, --  loaded by default?
		handler   = true,
		api       = true,
		hidden    = true,
  }
end

local JSON;

JSON_DIRNAME = LUAUI_DIRNAME .. "Widgets/json/"

function widget:Initialize()
	--Spring.Echo("-------------MY Chili_clone_dirname: "..CHILI_CLONE_DIRNAME)
	JSON = VFS.Include(JSON_DIRNAME .. "JSON.lua", nil, VFS.RAW_FIRST)

	--// Export Widget Globals
	WG.JSON = JSON
end

function widget:Shutdown()
	WG.JSON = nil
end

function widget:Dispose()
end