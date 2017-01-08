--- TreeNode module

--- TreeNode fields.
-- Inherits from Control.
-- @see control.Control
-- @table TreeNode
TreeNode = Control:Inherit{
  classname = 'TreeNode',
	resizable = true,
	draggable = true,
	width  = 110,
	height = 60,
	minWidth  = 90,
	minHeight = 50,
	defaultWidth  = 110,
	defaultHeight = 60,
	dragGripSize = {4,4},
	padding = {0,0,0,0},
	borderThickness = 0.5,
	skinName = 'DarkGlass',
	tooltip = "BT NODE TOOLTIP. ",
	
	id,
	nodeType = "",
	connectable = nil,
	nodeWindow = nil,
	hasConnectionIn = true,
	connectionIn = nil,
	hasConnectionOut = true,
	connectionOut = nil,
	nameEditBox = nil,
	
	parameters = {},
	parameterObjects = {},
	
	--- List of all connected connectionLines. 
	attachedLines = {}
}

local this = TreeNode
local inherited = this.inherited

local listenerNodeResize
local listenerStartConnection
local listenerEndConnection
local listenerMouseOver
local listenerMouseOut

-- connection line functions
local connectionLine = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCreator/connection_line.lua", nil, VFS.RAW_FIRST)

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
local Debug = Utils.Debug;
local Logger, dump, copyTable, fileTable = Debug.Logger, Debug.dump, Debug.copyTable, Debug.fileTable

local generateID
local usedIDs = {}

-- ////////////////////////////////////////////////////////////////////////////
-- Member functions
-- ////////////////////////////////////////////////////////////////////////////

function TreeNode:New(obj)
  obj = inherited.New(self,obj)
	if(not obj.id) then
		obj.id = generateID()
	else
		-- to not generate the same ID twice, save loaded ID to usedIDs
		usedIDs[obj.id] = true
	end
	local nodeWindowOptions = {
		parent = obj.parent,
		classname = 'TreeNodeWindow',
		x = obj.x,
    y = obj.y,
		resizable = obj.resizable,
		draggable = obj.draggable,
		width  = obj.width,
		height = obj.height,
		minWidth  = obj.minWidth,
		minHeight = obj.minHeight,
		defaultWidth  = obj.defaultWidth,
		defaultHeight = obj.defaultHeight,
		dragGripSize = obj.dragGripSize,
		padding = obj.padding,
		borderThickness = obj.borderThickness,
		backgroundColor = {1,1,1,0.6},
		skinName = 'DarkGlass',
		OnResize = { listenerNodeResize },
		treeNode = obj,
		connectable = obj.connectable,
		disableChildrenHitTest = true,
	}
	if ( obj.connectable ) then
		nodeWindowOptions.OnMouseDown = { listenerOnMouseDownMoveNode }
		nodeWindowOptions.OnMouseUp = { listenerOnMouseUpMoveNode }
		nodeWindowOptions.disableChildrenHitTest = false
	end
	
	obj.nodeWindow = Window:New(copyTable(nodeWindowOptions))
	local connectionOptions = {
		parent = obj.nodeWindow,
		x = obj.nodeWindow.width-18,
    y = '35%',
    width  = 15,
    height = 15,
		minWidth = 15,
		minHeight = 15,
		padding = {0,0,0,0},
		draggable=false,
		resizable=false,
		tooltip="BT Node connection",
		OnMouseDown = {},
		borderThickness = 0,
		skinName = 'DarkGlass',
		treeNode = obj,
	}
	if (obj.connectable) then
		connectionOptions.OnMouseDown = { listenerClickOnConnectionPanel }
		connectionOptions.OnMouseOver = { listenerOverConnectionPanel }
		connectionOptions.OnMouseOut = { listenerOutOfConnectionPanel }
	end
	if( obj.hasConnectionOut ) then
		obj.connectionOut = Panel:New(copyTable(connectionOptions))
	end
	connectionOptions.x = 2
	if( obj.hasConnectionIn ) then
		obj.connectionIn = Panel:New(copyTable(connectionOptions))
	end
	obj.nameEditBox = EditBox:New{
		parent = obj.nodeWindow,
		text = obj.nodeType,
		defaultWidth = '80%',
		x = '10%',
		y = 6,
		align = 'center',
		skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0,0,0,0},
	}
	obj.nodeWindow.minWidth = math.max(obj.nodeWindow.minWidth, obj.nameEditBox.font:GetTextWidth(obj.nameEditBox.text) + 33)
	obj.nodeWindow.minHeight = obj.nodeWindow.height
	
	for i=1,#obj.parameters do
		local param = obj.parameters[i]
		-- Every parameter expects four fields on creation: name, value, componentType, variableType. 
		if(param["name"] == nil or param["value"] == nil or param["componentType"] == nil or param["variableType"] == nil) then
			error("TreeNode expects following fields in parameters: name, value, componentType, variableType, got "..dump(param).."\n"..debug.traceback())
		end
		
		if (param["componentType"] and param["componentType"]:lower() == "editbox") then
			obj.parameterObjects[i] = {}
			obj.parameterObjects[i]["label"] = Label:New{
				parent = obj.nodeWindow,
				x = 18,
				y = 10 + i*20,
				width  = obj.nodeWindow.font:GetTextWidth(param["name"]),
				height = '10%',
				caption = param["name"],
				--skinName='DarkGlass',
			}
			obj.parameterObjects[i]["editBox"] = EditBox:New{
				parent = obj.nodeWindow,
				text = tostring(param["value"]),
				validatedText = tostring(param["value"]),
				width = math.max(obj.nodeWindow.font:GetTextWidth(param["value"])+10, 35),
				x = obj.nodeWindow.font:GetTextWidth(param["name"]) + 25,
				y = 10 + i*20,
				align = 'left',
				--skinName = 'DarkGlass',
				borderThickness = 0,
				backgroundColor = {0,0,0,0},
				variableType = param["variableType"],
			}
			obj.nodeWindow.minWidth = math.max(obj.nodeWindow.minWidth, obj.nodeWindow.font:GetTextWidth(param["value"])+ 48 + obj.nodeWindow.font:GetTextWidth(param["name"]))
		end
		-- Do not serialize unnecessary(dependent on nodeType) parameter fields, those are stored in nodeDefinitionInfo
		param["variableType"] = nil
		param["componentType"] = nil
	end
	
  return obj
end

--- Returns a table of children in order of y-coordinate(first is the one with the smallest one)
function TreeNode:GetChildren()
	if( not self.hasConnectionOut ) then 
		return {}
	end
	local connectionOutName = self.connectionOut.name
	local connectionLines = connectionLine.getAll()
	local children = {}
	for i=1,#connectionLines do
		if( connectionLines[i][1].name == connectionOutName ) then
			table.insert(children, connectionLines[i][#connectionLines[i]].treeNode)
		end
	end
	table.sort(children, function(lhs, rhs) return lhs.y < rhs.y end)
	return children
end

function TreeNode:ReGenerateID()
	self.id = generateID()
end

-- Dispose this treeNode without connection lines connected to it. 
function TreeNode:Dispose()
	if(self.connectionIn) then
		self.connectionIn:Dispose()
	end
	if(self.connectionOut) then
		self.connectionOut:Dispose()
	end
	if(self.nodeWindow) then
		self.nodeWindow:Dispose()
	end
	if(self.nameEditBox) then
		self.nameEditBox:Dispose()
	end
	if(parameterObjects) then
		for i=1,#parameterObjects do
			if(parameterObjects[i]["label"]) then
				parameterObjects[i]["label"]:Dispose()
			end
			if(parameterObjects[i]["editBox"]) then
				parameterObjects[i]["editBox"]:Dispose()
			end
		end
	end
end

local clickedConnection

--- Returns whether creation of connectionLine between clickedConnection and obj is valid, both objects are connection panels. 
function connectionLineCanBeCreated(obj)
	-- the same object cant be connected. 
	if (clickedConnection.treeNode.name == obj.treeNode.name) then 
		return false
	end
	if(connectionLine.exists(obj, clickedConnection)) then
		return false
	end
	-- Check that connectionIn has no other connectionLine before Adding new one
	-- when obj is connectionIn panel
	local connectionLines = connectionLine.getAll()
	if (obj.treeNode.connectionIn and obj.treeNode.connectionIn.name == obj.name) then
		for i=1,#connectionLines do
			if (obj.name == connectionLines[i][6].name) then
				return false
			end
		end
	elseif (clickedConnection.treeNode.connectionIn and clickedConnection.treeNode.connectionIn.name == clickedConnection.name) then
		for i=1,#connectionLines do
			if (clickedConnection.name == connectionLines[i][6].name) then
				return false
			end
		end
	else 
		-- Spring.Echo("connectionLineCanBeCreated(): connectionIn not found!!! ")
	end
	-- Check for cycles
	local visitedTreeNodeNames = {}
	local nodesToVisit = { obj.treeNode, clickedConnection.treeNode }
	while #nodesToVisit > 0 do
		local node = nodesToVisit[#nodesToVisit]
		-- check if we already visited current node
		for i=1,#visitedTreeNodeNames do
			if ( visitedTreeNodeNames[i] == node.name ) then 
				return false
			end
		end
		-- Spring.Echo(dump(visitedTreeNodeNames))
		table.insert(visitedTreeNodeNames, node.name)
		table.remove(nodesToVisit, #nodesToVisit)
		local children = node:GetChildren()
		for i=1,#children do
			table.insert(nodesToVisit, children[i])
		end
	end
		
	-- One of the connection panels is connectionOut, the other connectionIn, or the other way around for the connectionLine to be valid. 
	if( not(
		 (clickedConnection.treeNode.connectionOut and clickedConnection.name == clickedConnection.treeNode.connectionOut.name and obj.treeNode.connectionIn and obj.name == obj.treeNode.connectionIn.name) 
			or
		 (clickedConnection.treeNode.connectionIn  and clickedConnection.name == clickedConnection.treeNode.connectionIn.name  and obj.treeNode.connectionOut and obj.name == obj.treeNode.connectionOut.name)
		) ) then
		return false
	end
	return true
end

--//=============================================================================
--// Listeners
--//=============================================================================

local connectionPanelBackgroundColor = {0.1,0.1,0.1,0.7}
local movingNodes = false

function listenerOverConnectionPanel(self)
	if (clickedConnection ~= nil and connectionLineCanBeCreated(self)) then
		self.backgroundColor = {1, 0.5, 0.0, 1}
	end
	self:RequestUpdate()
end

function listenerOutOfConnectionPanel(self)
	if (clickedConnection ~= nil and clickedConnection.name ~= self.name) then
		self.backgroundColor = connectionPanelBackgroundColor
	end
	self:RequestUpdate()
end

function listenerClickOnConnectionPanel(self)
	movingNodes = false
	if (clickedConnection == nil) then
		clickedConnection = self
		self.backgroundColor = {1, 0.5, 0.0, 1}
		self:RequestUpdate()
		return self
	end
	if (clickedConnection.name == self.name) then 
		self.backgroundColor = connectionPanelBackgroundColor
		clickedConnection = nil
		self:RequestUpdate()
		return self
	end
	if( connectionLineCanBeCreated(self) ) then
		clickedConnection.backgroundColor = connectionPanelBackgroundColor
		self.backgroundColor = connectionPanelBackgroundColor
		connectionLine.add(clickedConnection, self)
		clickedConnection:RequestUpdate()
		clickedConnection = nil
		self:RequestUpdate()
		return self
	end
	return false
end

-- called also after move!
function listenerNodeResize(self, x, y)
	-- Spring.Echo("Resizing treenode window.. ")
	-- Spring.Echo("x="..self.treeNode.x..", y="..self.treeNode.y)
	-- Update position of connectionOut
	if (self.resizable) then 
		if (self.treeNode.connectionOut and self.treeNode.nodeWindow) then
			self.treeNode.connectionOut.x = self.treeNode.nodeWindow.width-18
			self.treeNode.width = self.treeNode.nodeWindow.width
			self.treeNode.height = self.treeNode.nodeWindow.height
		end
		
		for i=1,#self.treeNode.attachedLines do
			lineIdx = self.treeNode.attachedLines[i]
			connectionLine.update(lineIdx)
		end
	end
	--return true
end


--//=============================================================================
--// Listeners for node selections and their helper functions
--//=============================================================================

local previousPosition = {}

--- Key is node id, value is true
WG.selectedNodes = {}
---local selectedNodes = WG.selectedNodes

local ALPHA_OF_SELECTED_NODES = 1
local ALPHA_OF_NOT_SELECTED_NODES = 0.6

local function validateEditBox(editBox)
	if(editBox.text == editBox.validatedText) then
		return
	end
	local variableType = editBox.variableType
	-- Test for context variable
	if(#editBox.text > 0 and editBox.text[1] == '$') then
		editBox.validatedText = editBox.text
		return
	end
	if(variableType == "number") then
		local numberNew = tonumber(editBox.validatedText)
		if(numberNew) then
			editBox.validatedText = editBox.text
		else
			editBox.text = editBox.validatedText
		end
	elseif(variableType == "string") then
		editBox.validatedText = editBox.text
	end
end

local function removeNodeFromSelection(nodeWindow)
	nodeWindow.backgroundColor[4] = ALPHA_OF_NOT_SELECTED_NODES
	WG.selectedNodes[nodeWindow.treeNode.id] = nil
	for i=1,#nodeWindow.treeNode.parameterObjects do
		local editbox = nodeWindow.treeNode.parameterObjects[i]["editBox"]
		if(editbox) then
			validateEditBox(editbox)
		end
	end	
	nodeWindow:Invalidate()
end

local function addNodeToSelection(nodeWindow)
	nodeWindow.backgroundColor[4] = ALPHA_OF_SELECTED_NODES
	WG.selectedNodes[nodeWindow.treeNode.id] = true
	nodeWindow:Invalidate()
end

local function clearSelection()
	for id,_ in pairs(WG.selectedNodes) do
		removeNodeFromSelection(WG.nodeList[id].nodeWindow)
	end
end

WG.addNodeToSelection = addNodeToSelection
WG.removeNodeFromSelection = removeNodeFromSelection
WG.clearSelection = clearSelection

local function shiftSelectNodes(nodeWindow, recursive)
	if(recursive) then
		local children = nodeWindow.treeNode:GetChildren()
		for i=1,#children do
			shiftSelectNodes(children[i].nodeWindow, true)
		end
	end
	addNodeToSelection(nodeWindow)
end

local function ctrlSelectNodes(nodeWindow, recursive)
	if(recursive) then
		local children = nodeWindow.treeNode:GetChildren()
		for i=1,#children do
			ctrlSelectNodes(children[i].nodeWindow, true)
		end
	end
	if(WG.selectedNodes[nodeWindow.treeNode.id]) then
			removeNodeFromSelection(nodeWindow)
		else
			addNodeToSelection(nodeWindow)
		end
end

local lastClicked = Spring.GetTimer()

function listenerOnMouseDownMoveNode(self, x ,y, button)
	if(clickedConnection) then -- check if we are connecting nodes
		return
	end
	local childName = self:HitTest(x, y).name
	-- Check if the connectionIn or connectionOut was clicked
	if((self.treeNode.connectionIn and childName == self.treeNode.connectionIn.name) or (self.treeNode.connectionOut and childName == self.treeNode.connectionOut.name)) then 
		return
	end
	-- Check if the parameters editbox text hasnt changed
	for i=1,#self.treeNode.parameterObjects do
		validateEditBox(self.treeNode.parameterObjects[i]["editBox"])
	end
	for i=1,#self.treeNode.parameterObjects do
		if(childName == self.treeNode.parameterObjects[i]["editBox"].name) then
			return
		end
	end
	local now = Spring.GetTimer()
	if(childName == self.treeNode.nameEditBox.name and Spring.DiffTimers(now, lastClicked) < 0.3) then
		lastClicked = now
		return
	end
	lastClicked = now
	local _, ctrl, _, shift = Spring.GetModKeyState()
	if(WG.selectedNodes[self.treeNode.id]==nil and (not ctrl) and (not shift) and button ~= 3) then
		WG.clearSelection()
		addNodeToSelection(self)
	end
	if(WG.selectedNodes[self.treeNode.id] and (not ctrl) and (not shift) and button ~= 3) then
		movingNodes = true
		previousPosition.x = self.x
		previousPosition.y = self.y
		self:StartDragging(x, y)
		return self
	end	
	if(movingNodes) then
		return self
	end
	
	local selectSubtree = false
	if(button == 3) then
		selectSubtree = true
	end
	if (shift) then
		shiftSelectNodes(self, selectSubtree)
	elseif (ctrl) then
		ctrlSelectNodes(self, selectSubtree)
	else
		for id,_ in pairs(WG.selectedNodes) do
			removeNodeFromSelection(WG.nodeList[id].nodeWindow)
		end
		WG.selectedNodes = {}
		shiftSelectNodes(self, selectSubtree)
	end
	return self
end

function listenerOnMouseUpMoveNode(self, x ,y)
	self.treeNode.x = self.x
	self.treeNode.y = self.y
	self:Invalidate()
	if(movingNodes) then 
		local diffx = self.x - previousPosition.x
		local diffy = self.y - previousPosition.y
		-- Spring.Echo("diffx="..diffx..", diffy="..diffy)
		for id,_ in pairs(WG.selectedNodes) do 
			if(id ~= self.treeNode.id) then
				local node = WG.nodeList[id]
				node.nodeWindow.x = node.nodeWindow.x + diffx
				node.nodeWindow.y = node.nodeWindow.y + diffy
				node.x = node.x + diffx
				node.y = node.y + diffy
				node.nodeWindow:StopDragging(x, y)
				node.nodeWindow:Invalidate()
				for i=1,#node.attachedLines do
					connectionLine.update(node.attachedLines[i])
				end
			end
		end
		movingNodes = false
	end
	return self
end

--//=============================================================================
-- ID generation functions
--//=============================================================================

local alphanum = {
	"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
	"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
	"0","1","2","3","4","5","6","7","8","9"
	}

function generateID()
	local length = 32
	local str = ""
	for i = 1, length do
		str = str..alphanum[math.random(#alphanum)]
	end
	if(usedIDs[str] ~= nil) then
		return generateID()
	end
	usedIDs[str] = true
	return str	
end

