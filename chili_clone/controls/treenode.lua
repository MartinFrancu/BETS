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

--- Stores all connection lines for the tree, one connectionLine is composed from a table from: 
-- connectionOut, horizontalLine, verticalLine, horizontalLine, connectionIn - In this order. 
WG.connectionLines = {}
local connectionLines = WG.connectionLines

local GenerateID

-- ////////////////////////////////////////////////////////////////////////////
-- Member functions
-- ////////////////////////////////////////////////////////////////////////////

function TreeNode:New(obj)
  obj = inherited.New(self,obj)
	if(not obj.id) then
		obj.id = GenerateID()
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
	}
	if ( obj.connectable ) then
		nodeWindowOptions.OnMouseDown = { listenerOnMouseDownMoveNode }
		nodeWindowOptions.OnMouseUp = { listenerOnMouseUpMoveNode }
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
		y = '10%',
		align = 'center',
		skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0,0,0,0},
		editingText = false,
	}
  return obj
end

function TreeNode:Serialize(spaces ,file, fieldToSerialize)
	for i=1,#fieldToSerialize do
		local name = fieldToSerialize[i]
		local value = self[fieldToSerialize[i]]
		if (name=="text") then
			file:write(spaces.."text".." = "..'"'..self.nameEditBox.text..'"'..",\n")
		elseif (type(value) == "boolean") then
			file:write(spaces..name.." = "..tostring(value)..",\n")
		elseif (type(value) == "number") then
			file:write(spaces..name.." = "..value..",\n")
		elseif (type(value) == "string") then
			file:write(spaces..name.." = "..'"'..value..'"'..",\n")
		else
			file:write(spaces..name.." = "..'"uknown type"'..",\n")
		end
	end
	--file:write(spaces..'TreeNode\n')
	--[[file:write(spaces..'name = '..self.name..",\n")
	file:write(spaces..'nodeType = '..self.nodeType..",\n")
	file:write(spaces..'text = '..self.nameEditBox.text..",\n")
	file:write(spaces..'x = '..self.nodeWindow.x..",\n")
	file:write(spaces..'y = '..self.nodeWindow.y..",\n")
	file:write(spaces..'width = '..self.nodeWindow.width..",\n")
	file:write(spaces..'height = '..self.nodeWindow.height..",\n")
	file:write(spaces..'visible = '..tostring(self.visible)..",\n")
	file:write(spaces..'hasConnectionIn = '..tostring(self.hasConnectionIn)..",\n")
	file:write(spaces..'hasConnectionOut = '..tostring(self.hasConnectionOut)..",\n")]]--
end

--- Returns a table of children in order of y-coordinate(first is the one with the smallest one)
function TreeNode:GetChildren()
	if( not self.hasConnectionOut ) then 
		return {}
	end
	local connectionOutName = self.connectionOut.name
	local children = {}
	for i=1,#connectionLines do
		if( connectionLines[i][1].name == connectionOutName ) then
			table.insert(children, connectionLines[i][#connectionLines[i]].treeNode)
		end
	end
	table.sort(children, function(lhs, rhs) return lhs.y < rhs.y end)
	return children
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
end

--//=============================================================================
--// Connection lines
--//=============================================================================

function ComputeConnectionLineCoordinates(connectionOut, connectionIn)
	local transparentBorderWidth = 5
	local lineOutx = connectionOut.parent.x + connectionOut.x + 2
	local lineOuty = connectionOut.parent.y + connectionOut.y
	local halfDistance = math.ceil(math.abs(connectionIn.parent.x - connectionOut.parent.x - connectionOut.x)*0.5)
	local lineVx   = lineOutx+halfDistance - transparentBorderWidth
	local lineInx  = connectionIn.parent.x - halfDistance + transparentBorderWidth - 2
	local lineIny  = connectionIn.parent.y + connectionIn.y
	if(connectionOut.x+connectionOut.parent.x > connectionIn.parent.x) then
		lineOutx = connectionOut.parent.x + connectionOut.x + 1 - halfDistance
		lineInx  = connectionIn.parent.x + transparentBorderWidth - 1
		lineVx   = lineOutx - transparentBorderWidth + 1
	end
	return lineOutx, lineOuty, halfDistance, lineVx, lineInx, lineIny, transparentBorderWidth
end



function AddConnectionLine(connectionOut, connectionIn)
	if (connectionOut.treeNode.connectionIn and connectionOut.name == connectionOut.treeNode.connectionIn.name) then
		AddConnectionLine(connectionIn, connectionOut)
		return
	end
	-- if root node is to be connected, then remove all the existing connections, so there is only one connectionLine going from root
	if (connectionOut.treeNode.nodeType == "Root") then
		for i=1,#connectionLines do
			if (connectionLines[i][1].treeNode.nodeType == "Root") then
				WG.RemoveConnectionLine(i)
				break
			end
		end
	end
	
	local lineIndex = (#connectionLines + 1)
	local lineOutx,lineOuty,halfDistance,lineVx,lineInx,lineIny,transparentBorderWidth = ComputeConnectionLineCoordinates(connectionOut, connectionIn)
	local lineOut = Line:New{ 
		parent = connectionOut.parent.parent,
		width = halfDistance,
		height = 1,
		x = lineOutx,
		y = lineOuty,
		skinName = 'default',
		borderColor = {0.6,0.6,0.6,1},
		borderColor2 = {0.4,0.4,0.4,1},
		borderThickness = 2,
		padding = {0, 0, 0, 0},
		onMouseDown = { listenerClickOnConnectionLine },
		onMouseOver = { listenerOverConnectionLine },
		onMouseOut = { listenerOutOfConnectionLine },
		lineIndex = lineIndex,
	}
	local lineIn = Line:New{
		parent = connectionOut.parent.parent,
		width = halfDistance,
		height = 1,
		x = lineInx,
		y = lineIny,
		skinName = 'default',
		borderColor = {0.6,0.6,0.6,1},
		borderColor2 = {0.4,0.4,0.4,1},
		borderThickness = 2,
		padding = {0, 0, 0, 0},
		onMouseDown = { listenerClickOnConnectionLine },
		onMouseOver = { listenerOverConnectionLine },
		onMouseOut = { listenerOutOfConnectionLine },
		lineIndex = lineIndex,
	}
	local lineV = Line:New{
		parent = connectionOut.parent.parent,
		width = 5,
		height = math.abs(lineOuty-lineIny),
		minHeight = 0,
		x = lineVx,
		y = math.min(lineOuty,lineIny)+transparentBorderWidth,
		style = "vertical",
		skinName = 'default',
		borderColor = {0.6,0.6,0.6,1},
		borderColor2 = {0.4,0.4,0.4,1},
		borderThickness = 2,
		padding = {0, 0, 0, 0},
		onMouseDown = { listenerClickOnConnectionLine },
		onMouseOver = { listenerOverConnectionLine },
		onMouseOut = { listenerOutOfConnectionLine },
		lineIndex = lineIndex,
	}
	local arrow = Image:New{
		parent = connectionOut.parent.parent,
		x = lineInx + halfDistance - 8,
		y = lineIny + 1,
		file = LUAUI_DIRNAME .. "Widgets/BtCreator/arrow_white.png",
		--file2 = LUAUI_DIRNAME .. "Widgets/BtCreator/arrow_orange.png",
		width = 5,
		height = 8,
		lineIndex = lineIndex,
		onMouseDown = { listenerClickOnConnectionLine },
		onMouseOver = { listenerOverConnectionLine },
		onMouseOut = { listenerOutOfConnectionLine },
	}
	table.insert( connectionLines, {connectionOut, lineOut, lineV, lineIn, arrow, connectionIn} )
	table.insert( connectionIn.treeNode.attachedLines,  lineIndex )
	table.insert( connectionOut.treeNode.attachedLines, lineIndex )
	
	--Spring.Echo("lineV.lineIndex: "..lineIndex)
end

WG.AddConnectionLine = AddConnectionLine

function ConnectionLineExists(connection1, connection2)
	for i=1,#connectionLines do
		if(connectionLines[i][1].name == connection1.name and connectionLines[i][6].name == connection2.name) then
			return true
		end
		if(connectionLines[i][6].name == connection1.name and connectionLines[i][1].name == connection2.name) then
			return true
		end
	end
	return false
end

--- Updates location of connectionLine on given index. 
function UpdateConnectionLine(index)
	local connectionOut = connectionLines[index][1]
	local connectionIn = connectionLines[index][#connectionLines[index]]
	local lineOutx,lineOuty,halfDistance,lineVx,lineInx,lineIny,transparentBorderWidth = ComputeConnectionLineCoordinates(connectionOut, connectionIn)
	local lineOut = connectionLines[index][2]
	local lineV = connectionLines[index][3]
	local lineIn = connectionLines[index][4]
	local arrow = connectionLines[index][5]
	lineOut.width = halfDistance
	lineOut.x = lineOutx
	lineOut.y = lineOuty
	lineIn.width = halfDistance
	lineIn.x = lineInx
	lineIn.y = lineIny
	lineV.height = math.abs(lineOuty-lineIny)
	lineV.x = lineVx
	lineV.y = math.min(lineOuty,lineIny)+transparentBorderWidth
	arrow.x = lineInx + halfDistance - 8
	arrow.y = lineIny + 1
	for i=2,5 do
		connectionLines[index][i]:RequestUpdate()
	end
end

--- Remove connectionLine with given index from global connectionLines table. All the connectionLines with larger
-- indexes decrements its index by one, so the indexes in attachedLines field and lineIndex are decremented by one. 
function RemoveConnectionLine(index)
	for i=2,5 do
		connectionLines[index][i]:Dispose()
	end
	local found = false
	local foundIndex
	for j=1,#connectionLines[index][1].treeNode.attachedLines do
		if (connectionLines[index][1].treeNode.attachedLines[j] == index) then
			found = true
			foundIndex = j
			break
		end
	end
	if (found) then
		--Spring.Echo("attachedLines before delete: "..dump(connectionLines[index][1].treeNode.attachedLines))
		--Spring.Echo("foundIndex: "..foundIndex)
		table.remove(connectionLines[index][1].treeNode.attachedLines, foundIndex)
		--Spring.Echo("attachedLines after delete: "..dump(connectionLines[index][1].treeNode.attachedLines))
	else	
		Spring.Echo("ERROR: Line index not found in connectionOut panel, in RemoveConnectionLine(). ")
	end
	
	found = false
	foundIndex = nil
	for k=1,#connectionLines[index][6].treeNode.attachedLines do
		if (connectionLines[index][6].treeNode.attachedLines[k] == index) then
			found = true
			foundIndex = k
			break
		end
	end
	if (found) then  
		table.remove(connectionLines[index][6].treeNode.attachedLines, foundIndex)
	else
		Spring.Echo("ERROR: Line index not found in connectionIn panel, in RemoveConnectionLine(). ")
	end
	table.remove(connectionLines, index)
	-- We deleted an entry from connectionLines. So all the indices which are after the lineIndex
	-- needs to be decremented by one. Also the lineIndex field in Chili.Line needs to be updated. 
	for i=index,#connectionLines do
		local attachedLines1 = connectionLines[i][1].treeNode.attachedLines
		local attachedLines2 = connectionLines[i][6].treeNode.attachedLines
		for k=1,#attachedLines1 do
			if (attachedLines1[k] == i+1) then 
				attachedLines1[k] = i
			end
		end
		for k=1,#attachedLines2 do
			if (attachedLines2[k] == i+1) then 
				attachedLines2[k] = i
			end
		end
		-- Spring.Echo("connectionIn attachedLines: "..dump(attachedLines1))
		-- Spring.Echo("connectionOut attachedLines: "..dump(attachedLines2))
		for k=2,4 do
			connectionLines[i][k].lineIndex = i
		end
	end
	-- Spring.Echo("State after the connectionLine index"..index.." was deleted: "..dump(connectionLines))
	
	return true
end

WG.RemoveConnectionLine = RemoveConnectionLine

local clickedConnection

--- Returns whether creation of connectionLine between clickedConnection and obj is valid, both objects are connection panels. 
function connectionLineCanBeCreated(obj)
	-- the same object cant be connected. 
	if (clickedConnection.treeNode.name == obj.treeNode.name) then 
		return false
	end
	if(ConnectionLineExists(obj, clickedConnection)) then
		return false
	end
	-- Check that connectionIn has no other connectionLine before Adding new one
	-- when obj is connectionIn panel
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
WG.movingNodes = false

function listenerOverConnectionPanel(self)
	if (clickedConnection ~= nil and connectionLineCanBeCreated(self)) then
		self.backgroundColor = {1, 0.5, 0.0, 1}
	end
end

function listenerOutOfConnectionPanel(self)
	if (clickedConnection ~= nil and clickedConnection.name ~= self.name) then
		self.backgroundColor = connectionPanelBackgroundColor
	end
end

function listenerClickOnConnectionPanel(self)
	Spring.Echo("clicked on Connection panel. ")
	WG.movingNodes = false
	if (clickedConnection == nil) then
		clickedConnection = self
		self.backgroundColor = {1, 0.5, 0.0, 1}
		return self
	end
	if (clickedConnection.name == self.name) then 
		self.backgroundColor = connectionPanelBackgroundColor
		clickedConnection = nil
		return self
	end
	if( connectionLineCanBeCreated(self) ) then
		clickedConnection.backgroundColor = connectionPanelBackgroundColor
		self.backgroundColor = connectionPanelBackgroundColor
		AddConnectionLine(clickedConnection, self)
		-- Spring.Echo("Connection line added: "..dump(connectionLines))
		clickedConnection = nil
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
			UpdateConnectionLine(lineIdx)
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


ALPHA_OF_SELECTED_NODES = 1
ALPHA_OF_NOT_SELECTED_NODES = 0.6

local function removeNodeFromSelection(nodeWindow)
	nodeWindow.backgroundColor[4] = ALPHA_OF_NOT_SELECTED_NODES
	WG.selectedNodes[nodeWindow.treeNode.id] = nil
	nodeWindow.treeNode.nameEditBox.editingText = false
	nodeWindow:Invalidate()
end

local function addNodeToSelection(nodeWindow)
	nodeWindow.backgroundColor[4] = ALPHA_OF_SELECTED_NODES
	WG.selectedNodes[nodeWindow.treeNode.id] = true
	nodeWindow.treeNode.nameEditBox.editingText = true
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


function listenerOnMouseDownMoveNode(self, x ,y, button)
	if(clickedConnection) then -- connecting lines
		return false
	end
	local cin = self.treeNode.connectionIn
	if(cin and x > cin.x and x < cin.x + cin.width and y > cin.y and y < cin.y+cin.height) then
		return false
	end
	local cout = self.treeNode.connectionOut
	if(cout and x > cout.x and x < cout.x + cout.width and y > cout.y and y < cout.y+cout.height) then
		return false
	end
	Spring.Echo("listenerOnMouseDownMoveNode")
	local alt, ctrl, _, shift = Spring.GetModKeyState()
	if(WG.selectedNodes[self.treeNode.id] and (not ctrl) and (not shift) and button ~= 3) then
		Spring.Echo("Start moving")
		WG.movingNodes = true
		previousPosition.x = self.x
		previousPosition.y = self.y
	end
	if(WG.movingNodes) then
		return
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
	self.treeNode.width = self.width
	self.treeNode.height = self.height
	self.treeNode.x = self.x 
	self.treeNode.y = self.y 
	self:Invalidate()
	if(WG.movingNodes) then 
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
				node.nodeWindow:Invalidate()
				for i=1,#node.attachedLines do
					UpdateConnectionLine(node.attachedLines[i])
				end
			end
		end
		WG.movingNodes = false
	end
	Spring.Echo("listenerOnMouseUpMoveNode")
	-- return true
end


--//=============================================================================
--// Listeners on Connection lines
--//=============================================================================


function listenerOverConnectionLine(self)	
	lineIndex = self.lineIndex
	for i=2,4 do
		connectionLines[lineIndex][i].borderColor = {1,0.6,0.2,0.8}
		connectionLines[lineIndex][i].borderColor2 = {1,0.6,0.2,0.8}
		connectionLines[lineIndex][i]:Invalidate()
		connectionLines[lineIndex][i]:RequestUpdate()
	end
	local oldArrow = connectionLines[lineIndex][5]
	local arrow = Image:New{
		parent = oldArrow.parent,
		x = oldArrow.x,
		y = oldArrow.y,
		file = LUAUI_DIRNAME .. "Widgets/BtCreator/arrow_orange.png",
		width = oldArrow.width,
		height = oldArrow.height,
		lineIndex = oldArrow.lineIndex,
		onMouseDown = { listenerClickOnConnectionLine },
		onMouseOver = { listenerOverConnectionLine },
		onMouseOut = { listenerOutOfConnectionLine },
	}
	connectionLines[lineIndex][5]:Dispose()
	connectionLines[lineIndex][5] = arrow
end

function listenerOutOfConnectionLine(self)
	lineIndex = self.lineIndex
	for i=2,4 do
		connectionLines[lineIndex][i].borderColor = {0.6,0.6,0.6,1} 
		connectionLines[lineIndex][i].borderColor2 = {0.4,0.4,0.4,1}
		connectionLines[lineIndex][i]:Invalidate()
		connectionLines[lineIndex][i]:RequestUpdate()
	end
	local oldArrow = connectionLines[lineIndex][5]
	local arrow = Image:New{
		parent = oldArrow.parent,
		x = oldArrow.x,
		y = oldArrow.y,
		file = LUAUI_DIRNAME .. "Widgets/BtCreator/arrow_white.png",
		width = oldArrow.width,
		height = oldArrow.height,
		lineIndex = oldArrow.lineIndex,
		onMouseDown = { listenerClickOnConnectionLine },
		onMouseOver = { listenerOverConnectionLine },
		onMouseOut = { listenerOutOfConnectionLine },
	}
	connectionLines[lineIndex][5]:Dispose()
	connectionLines[lineIndex][5] = arrow
end

function listenerClickOnConnectionLine(self)
	return RemoveConnectionLine(self.lineIndex)
end



-- Include debug functions, copyTable() and dump()
VFS.Include(LUAUI_DIRNAME .. "Widgets/chili_clone/controls/debug_utils.lua", nil, VFS.RAW_FIRST)

--//=============================================================================
-- ID generation functions
--//=============================================================================

local alphanum = {
	"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
	"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
	"0","1","2","3","4","5","6","7","8","9"
	}

local usedIDs = {}
	
function GenerateID()
	local length = 32
	local str = ""
	for i = 1, length do
		str = str..alphanum[math.random(#alphanum)]
	end
	if(usedIDs[str] ~= nil) then
		return GenerateID()
	end
	usedIDs[str] = true
	return str	
end

