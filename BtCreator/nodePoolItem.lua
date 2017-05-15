
nodePoolItem = {}

local sanitizer = Utils.Sanitizer.forWidget(widget)

--- NodeType of last clicked nodePoolItem
local selectedNodeType

local Chili = WG.ChiliClone
local Screen0 = Chili.Screen0

local btCreatorWindow
local placeNodeOnCanvas

local HOVER_COLOR = {1,0.5,0,1}
local DEFAULT_COLOR = {1,1,1,1}
local HOVER_ICON = {1,1,1,0.4}
local BTTREENODEICONS_FOLDER = LUAUI_DIRNAME .. "Widgets/BtTreeNodeIcons/"

local count = 0

local mouseDownCoordinates

function nodePoolItem.getSelectedNodeType()
	return selectedNodeType
end

function nodePoolItem.initialize(_btCreatorWindow, _placeNodeOnCanvas)
	btCreatorWindow = _btCreatorWindow
	placeNodeOnCanvas = _placeNodeOnCanvas
end

local function listenerOnMouseDown(self, x, y)
	mouseDownCoordinates = { x, y }
	-- Spring.Echo(self.nodeType)
	selectedNodeType = self.nodeType
	return self
end

local function listenerOnMouseUp(self, x, y)
	local sx, sy = self:LocalToScreen(x, y)
	-- Spring.Echo("sx:"..x..", sy:"..y)
	local component = Screen0:HitTest(sx, sy)
	if(not component) then
		Spring.Echo("Try to drag&drop node onto canvas. ")
		return self
	end
	if( (component.name and component.name == btCreatorWindow.name) or component:IsDescendantOf(btCreatorWindow)) then
		local canvasx, canvasy = btCreatorWindow:ScreenToLocal(sx, sy)
		placeNodeOnCanvas(selectedNodeType, canvasx-20, canvasy-20)
		return self
	end
	return self
end

function nodePoolItem.reset()
	count = 0
end

--- Create a nodePoolItem from given treenode
function nodePoolItem.new(treenode, nodePoolPanel)
	local iconPath = treenode.iconPath
	if(not iconPath or not (iconPath and VFS.FileExists(iconPath))) then
		iconPath = BTTREENODEICONS_FOLDER.."default.png"
	end
	count = count + 1
	local node = Chili.Control:New{
		parent = nodePoolPanel,
		width = '100%',
		height = 30,
		backgroundColor = {1,1,1,0.3},
		x = 0,
		y = 10 + count*20,
	}
	local icon = Chili.Image:New{
		nodeType = treenode.nodeType,
		parent = node,
		name = "icon",
		x = 0,
		y = 0,
		width = 20,
		height = 20,
		file = iconPath,
		tooltip = treenode.tooltip,
		OnMouseDown = { sanitizer:AsHandler(listenerOnMouseDown) },
		OnMouseUp = { sanitizer:AsHandler(listenerOnMouseUp) },
		OnMouseOver = { sanitizer:AsHandler(
			function(self)
				self.color = HOVER_ICON
				self:Invalidate()
				local label = self.parent:GetChildByName("label")
				label.font.color = HOVER_COLOR
				label:Invalidate()
			end)
		},
		OnMouseOut = { sanitizer:AsHandler(
			function(self)
				self.color = DEFAULT_COLOR
				self:Invalidate()
				local label = self.parent:GetChildByName("label")
				label.font.color = DEFAULT_COLOR
				label:Invalidate()
			end)
		},
		OnClick={ function() end },
	}
	local label = Chili.Label:New{
		parent = node,
		name = "label",
		caption = treenode.nodeType,
		nodeType = treenode.nodeType,
		x = 25,
		y = 0,
		width = 90,
		height = 20,
		autosize = true,
		tooltip = treenode.tooltip,
		OnMouseDown = { listenerOnMouseDown },
		OnMouseUp = { listenerOnMouseUp },
		OnMouseOver = { sanitizer:AsHandler(
			function(self)
				self.font.color = HOVER_COLOR
				self:Invalidate()
				local icon = self.parent:GetChildByName("icon")
				icon.color = HOVER_ICON
			end)
		},
		OnMouseOut = { sanitizer:AsHandler(
			function(self)
				self.font.color = DEFAULT_COLOR
				self:Invalidate()
				local icon = self.parent:GetChildByName("icon")
				icon.color = DEFAULT_COLOR
			end)
		},
		OnClick = {},
	}
	
end

return nodePoolItem
