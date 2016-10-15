local includes = {
  --"headers/autolocalizer_clone.lua",
  "headers/util_clone.lua",
  "headers/links_clone.lua",
  "headers/backwardcompability_clone.lua",
  "headers/unicode_clone.lua",

  "handlers/debughandler_clone.lua",
  "handlers/taskhandler_clone.lua",
  "handlers/skinhandler_clone.lua",
  "handlers/themehandler_clone.lua",
  "handlers/fonthandler_clone.lua",
  "handlers/texturehandler_clone.lua",

  "controls/object_clone.lua",
  "controls/font_clone.lua",
  "controls/control_clone.lua",
  "controls/screen_clone.lua",
  "controls/window_clone.lua",
  "controls/label_clone.lua",
  "controls/button_clone.lua",
  "controls/textbox_clone.lua",
  "controls/checkbox_clone.lua",
  "controls/trackbar_clone.lua",
  "controls/colorbars_clone.lua",
  "controls/scrollpanel_clone.lua",
  "controls/image_clone.lua",
  "controls/textbox_clone.lua",
  "controls/layoutpanel_clone.lua",
  "controls/grid_clone.lua",
  "controls/stackpanel_clone.lua",
  "controls/imagelistview_clone.lua",
  "controls/progressbar_clone.lua",
  "controls/multiprogressbar_clone.lua",
  "controls/scale_clone.lua",
  "controls/panel_clone.lua",
  "controls/treeviewnode_clone.lua",
  "controls/treeview_clone.lua",
  "controls/editbox_clone.lua",
  "controls/line_clone.lua",
  "controls/combobox_clone.lua",
  "controls/tabbaritem_clone.lua",
  "controls/tabbar_clone.lua",
  "controls/tabpanel_clone.lua",
	"controls/treenode.lua"
}

local Chili = widget

Chili.CHILI_CLONE_DIRNAME = CHILI_CLONE_DIRNAME or (LUAUI_DIRNAME .. "Widgets/chili_clone/")
Chili.SKIN_DIRNAME  =  SKIN_DIRNAME or (CHILI_CLONE_DIRNAME .. "skins/")

if (-1>0) then
  Chili = {}
  -- make the table strict
  VFS.Include(Chili.CHILI_CLONE_DIRNAME .. "headers/strict_clone.lua")(Chili, widget)
end

for _, file in ipairs(includes) do
  VFS.Include(Chili.CHILI_CLONE_DIRNAME .. file, Chili, VFS.RAW_FIRST)
end


return Chili
