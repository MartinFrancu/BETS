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
	icon = nil,
	iconPath = nil,

	parameters = {},
	parameterObjects = {},

	--- List of all connected connectionLines.
	attachedLines = {}
}

local _G = loadstring("return _G")()
local KEYSYMS = _G.KEYSYMS

local this = TreeNode
local inherited = this.inherited

local listenerNodeWindowOnResize
local listenerStartConnection
local listenerEndConnection
local listenerMouseOver
local listenerMouseOut

-- connection line functions
local connectionLine = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCreator/connection_line.lua", nil, VFS.RAW_FIRST)
local rootnode = VFS.Include(LUAUI_DIRNAME .. "Widgets/chili_clone/controls/treenode_rootnode.lua", nil, VFS.RAW_FIRST)
local referenceNode = VFS.Include(LUAUI_DIRNAME .. "Widgets/chili_clone/controls/treenode_reference.lua", nil, VFS.RAW_FIRST)

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
local Debug = Utils.Debug;
local Logger, dump, copyTable, fileTable = Debug.Logger, Debug.dump, Debug.copyTable, Debug.fileTable

local generateID
local usedIDs = {}
local autocompleteTable
local createNextParameterObject

-- ////////////////////////////////////////////////////////////////////////////
-- Member functions
-- ////////////////////////////////////////////////////////////////////////////

function TreeNode:New(obj)
	-- To create a treenode on negative coordinates, first create it on nonnegative ones,
	-- and then move it to negative coordinates. 
	local negativeX = 0
	local negativeY = 0
	if(obj.x and obj.x < 0) then
		negativeX, obj.x = obj.x, negativeX
	end
	if(obj.y and obj.y < 0) then
		negativeY, obj.y = obj.y, negativeY
	end
	obj = inherited.New(self,obj)
	autocompleteTable = WG.sensorAutocompleteTable or {}
	
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
		OnResize = { listenerNodeWindowOnResize },
		treeNode = obj,
		connectable = obj.connectable,
		disableChildrenHitTest = true,
		tooltip = obj.tooltip,
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
    y = obj.nodeWindow.height * 0.35,
    width  = 15,
    height = 15,
		minWidth = 15,
		minHeight = 15,
		padding = {0,0,0,0},
		draggable=false,
		resizable=false,
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
		text = obj.title or obj.nodeType,
		defaultWidth = '80%',
		x = 15,
		y = 6,
		align = 'left',
		-- skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0,0,0,0},
		autosize = true,
		minWidth = 50,
		borderColor = {0,0,0,0},
	}
	if(obj.iconPath and VFS.FileExists(obj.iconPath)) then
		obj.icon = Image:New{
			parent = obj.nodeWindow,
			x = 15,
			y = 10,
			width = 20,
			height = 20,
			file = obj.iconPath,
		}
		obj.nameEditBox:SetPos(obj.nameEditBox.x+20)
	end
	--[[
	-- in order to enable this, an error with autogrowing nodes after zooming in and out has be resolved (most likely in the portion of BtCreator that zooms in again)
	obj.logImage = Image:New{
		parent = obj.nodeWindow,
		x = obj.nodeWindow.width - 15 - 20,
		y = 10,
		width = 20,
		height = 20,
		file = LUAUI_DIRNAME .. "Widgets/BtTreenodeIcons/error.png",
	}
	]]--
	if(obj.nodeType:lower() == "root") then
		rootnode.addChildComponents(obj)
	end

	obj.parameterObjects = {}
	for i=1,#obj.parameters do
		obj.parameterObjects[i] = createNextParameterObject(obj)
		-- Do not serialize unnecessary(dependent on nodeType) parameter fields, those are stored in nodeDefinitionInfo
		obj.parameters[i]["variableType"] = nil
		obj.parameters[i]["componentType"] = nil
	end
	if(#obj.parameters ~= #obj.parameterObjects) then
		error("#obj.parameters="..#obj.parameters.."  ~= #obj.parameterObjects="..#obj.parameterObjects)
	end
	-- If coordinates of treenode were negative before creation, transform it there now
	if(negativeX < 0) then
		obj.x = negativeX
	end
	if(negativeY < 0) then
		obj.y = negativeY
	end
	obj.nodeWindow:SetPos(obj.x, obj.y)
	obj.nodeWindow:Invalidate()
	obj:UpdateDimensions()
  return obj
end

function TreeNode:UpdateDimensions()
	local nodeWindow = self.nodeWindow
	-- connectionOut and logImage are on the boundary of the nodeWindow and messes up the GetChildrenMinimumExtends() call,
	-- so hide it 
	if(self.connectionOut) then
		self.connectionOut:Hide()
	end
	local restoreLogImage = nil
	if(self.logImage and self.logImage.visible)then
		self.logImage:Hide()
		restoreLogImage = true
	end
	local max = math.max
	local w,h = nodeWindow:GetChildrenMinimumExtents()
	if(self.connectionOut) then
		self.connectionOut:Show()
	end
	if(restoreLogImage)then
		self.logImage:Show()
	end
	self.nameEditBox:UpdateLayout()
	local nameWidth = self.nameEditBox.width + 35 + 20
	if(self.icon) then
		nameWidth = nameWidth + 20
	end
	local maxWidth = max(nodeWindow.width, nameWidth)
	local maxHeight = nodeWindow.height
	-- Spring.Echo("minimum extents w,h: "..math.ceil(w)..","..math.ceil(h))
	-- Spring.Echo("current extents w,h: "..math.ceil(maxWidth)..","..math.ceil(maxHeight))
	maxWidth = math.ceil(max(maxWidth, w+20))
	maxHeight = math.ceil(max(maxHeight, h+20))
	if(nodeWindow and nodeWindow.parent and not nodeWindow.parent.zoomedOut) then
		local x = math.ceil(nodeWindow.x)
		local y = math.ceil(nodeWindow.y)
		nodeWindow:SetPos(x, y, maxWidth, maxHeight)
		self.x = x
		self.y = y
		self.width = maxWidth
		self.height = maxHeight
	end
	self.nodeWindow:CallListeners( self.nodeWindow.OnResize )
end

-- === Textbox autocomplete ===
local function resolveAutocompleteCandidates(textBox)
	local cursor = textBox.cursor
	local beforeCursor = textBox.text:sub(1, cursor - 1)
	local partialProperty = beforeCursor:match("[_%w%.%(%)]+$") or ""
	
	local container = autocompleteTable
	for key, separator in partialProperty:gmatch("([_%w%(%)]+)([%.])") do
		key = key:gsub("(%([_%w]*%))$", "()")
		Logger.log("treeNode", "Key - ", key)
		container = container[key]
		if not container then
			return false
		end
	end
	
	local partialKey = string.lower(partialProperty:match("[_%w%(%)]*$") or "")
	local partialLength = partialKey:len()
	textBox.autocompleteCandidates = {}
	local candidateSet, candidateCount = {}, 0
	for k, v in pairs(container) do
		if (type(k) == "string" and string.lower(k:sub(1, partialLength)) == partialKey and not candidateSet[k]) then
			table.insert(textBox.autocompleteCandidates, k)
			candidateSet[k] = true
			candidateCount = candidateCount + 1
		end
	end
end

local function fillInSensor(textBox)
	if not textBox.autocompleteCandidates then
		resolveAutocompleteCandidates(textBox)
		textBox.nextAutocompleteIndex = 1
	end
	
	local cursor = textBox.cursor
	local beforeCursor = textBox.text:sub(1, cursor - 1)
	local partialProperty = beforeCursor:match("[_%w%.%(%)]+$") or ""
	local partialKey = string.lower(partialProperty:match("[_%w%(%)]*$") or "")
	local partialLength = partialKey:len()
	
	local candidates = textBox.autocompleteCandidates or {}
	local index = textBox.nextAutocompleteIndex or 1
	
	--Logger.log("treeNode", "beforeCursor - ", beforeCursor, "; candidates - ", candidates)
	if(#candidates == 0)then
		return false
	else
		local afterCursor = textBox.text:sub(cursor)
		textBox:SetText(beforeCursor:sub(1, -partialLength - 1) .. candidates[index] .. afterCursor)
		textBox.cursor = cursor + candidates[index]:len() - partialLength
		textBox.nextAutocompleteIndex = index + 1
		if textBox.nextAutocompleteIndex > #textBox.autocompleteCandidates then
			textBox.nextAutocompleteIndex = 1
		end
	end
end

local function resetAutocomplete(textBox)
	textBox.autocompleteCandidates = nil
	textBox.nextAutocompleteIndex = nil
end

-- =======

--- Transforms obj.parameters[i] into obj.parametersObjects[i]
-- Expects param to be a table with four values: name, value, variableType, componentType.
function createNextParameterObject(obj)
	local result = {}
	local i = #obj.parameterObjects + 1
	if(i > #obj.parameters) then
		error("Trying to generate parameterObject[i] without needed parameters[i]. "..debug.traceback())
	end
	local param = obj.parameters[i]
	if(param["name"] == nil or param["value"] == nil or param["componentType"] == nil or param["variableType"] == nil) then
			error("TreeNode expects following fields in parameters: name, value, componentType, variableType, got "..dump(param).."\n"..debug.traceback())
	end
	--- EditBox componentType
	if (param["componentType"] and param["componentType"]:lower() == "editbox") then
		result.componentType = "editBox"
		local showLabel = param.name ~= "expression" or param.variableType ~= "longString"
		local width, caption = 0, ""
		if showLabel then
			width = obj.nodeWindow.font:GetTextWidth(param["name"])
			caption = param["name"]
		end
		result.label = Label:New{
			parent = obj.nodeWindow,
			x = 18,
			y = 10 + i*20,
			width  = width,
			height = '10%',
			caption = caption
			--skinName='DarkGlass',
		}
		
		local minWidth = 40
		if param.variableType == "longString" then
			minWidth = 150
		end
		local componentX
		if showLabel then
			componentX = obj.nodeWindow.font:GetTextWidth(param["name"]) + 25
		else
			componentX = 18
		end
		
		result.editBox = EditBox:New{
			parent = obj.nodeWindow,
			text = tostring(param["value"]),
			validatedValue = tostring(param["value"]),
			-- width = math.max(obj.nodeWindow.font:GetTextWidth(param["value"])+10, 45),
			x = componentX,
			y = 10 + i*20,
			align = 'left',
			--skinName = 'DarkGlass',
			borderThickness = 0,
			backgroundColor = {0,0,0,0},
			variableType = param["variableType"],
			index = i, -- to be able to index editbox from treenode, to update treenode.parameters[i].value
			autosize = true,
			minWidth = minWidth,
			OnKeyPress = {
				function(element, key)
					if(key == KEYSYMS.TAB)then
						-- Logger.log("treeNode", "table - ", dump(autocompleteTable, 3))
						fillInSensor(element)
					else
						resetAutocomplete(element)
					end
					
					if(element.text ~= element.validatedValue)then
						WG.BtCreator.Get().markTreeAsChanged()
					end
					
					return true
				end
			},
			OnTextInput = {
				function()
					WG.BtCreator.Get().markTreeAsChanged()
				end
			},
		}
	--- CheckBox componentType
	elseif(param["componentType"] and param["componentType"]:lower() == "checkbox") then
		result.componentType = "checkBox"
		result.checkBox = Checkbox:New{
			parent = obj.nodeWindow,
			caption = param.name,
			checked = (param.value == "true"),
			width = obj.nodeWindow.font:GetTextWidth(param.name) + 20,
			x = 18,
			y = 10 + i*20,
			index = i, -- to be able to index editbox from treenode, to update treenode.parameters[i].value
		}
	elseif(param["componentType"] and param["componentType"]:lower() == "combobox") then
		local items = {}
		local defaultIndex = 0
		local k = 1
		local width = 70
		for word in param.variableType:gmatch('([^,]+)') do
			if(word == param.value) then
				defaultIndex = k
			end
			width = math.max(obj.nodeWindow.font:GetTextWidth(word)+5, width)
			k = k + 1
			table.insert(items, word)
		end
		if(defaultIndex == 0) then
			error("Treenode combobox default value not found in enumeration. defaultValue: "..dump(param.value).."\n"..debug.traceback())
		end
		result.componentType = "comboBox"
		result.label = Label:New{
			parent = obj.nodeWindow,
			x = 18,
			y = 10 + i*20,
			width  = obj.nodeWindow.font:GetTextWidth(param["name"]),
			height = '10%',
			caption = param["name"],
			--skinName='DarkGlass',
		}
		result.comboBox = ComboBox:New{
			caption = param.name,
			parent = obj.nodeWindow,
			x = 25 + obj.nodeWindow.font:GetTextWidth(param["name"]),
			y = 10 + i*20,
			width = width + 40,
			index = i, -- to be able to index editbox from treenode, to update treenode.parameters[i].value
			borderThickness = 0,
			items = items,
		}
		result.comboBox:Select(defaultIndex)
	elseif(param["componentType"] and param["componentType"]:lower() == "treepicker") then
		result.componentType = "treePicker"
		result.label = Label:New{
			parent = obj.nodeWindow,
			x = 18,
			y = 30,
			caption =  tostring(param["value"] or ""),
			tooltip = "Choose tree to be referenced, it will open tree selection dialog with all available trees. ",
			autosize = true,
		}
		result.label:UpdateLayout()
		local x = result.label.x + result.label.width + 5
		if(result.label.caption == "")then
			x = 18
		end
		result.button = Button:New{
			parent = obj.nodeWindow,
			x = x,
			y = result.label.y,
			caption = "...",
			tooltip = "Choose from available behaviour trees the one which should be referenced by this node. ",
			width = 30,
			height = 20,
			
			OnClick = { referenceNode.listenerChooseTree },
		}
		result.label.font.color = {1,1,1,0.8}
		if(obj.draggable and result.label.caption ~= "") then
			referenceNode.addInputOutputComponents(obj.nodeWindow, result.label, result.label.caption)
		end
	end
	if(result.editBox) then
		result.editBox:UpdateLayout()
	end
	return result
end

function TreeNode:ShowChildren()
	for child,_ in pairs(self.nodeWindow.children_hidden) do
		self.nodeWindow:ShowChild(child)
	end
end

function TreeNode:HideChildren()
	for i=#self.nodeWindow.children,1,-1 do
		self.nodeWindow.children[i]:SetVisibility(false)
	end
	self.nameEditBox:SetVisibility(true)
	if(self.connectionIn) then
		self.connectionIn:SetVisibility(true)
	end
	if(self.connectionOut) then
		self.connectionOut:SetVisibility(true)
	end
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

function TreeNode:UpdateConnectionLines()
	for i=1,#self.attachedLines do
		connectionLine.update(self.attachedLines[i])
	end
end

-- Dispose this treeNode without connection lines connected to it.
function TreeNode:Dispose()
	self.nodeWindow:ClearChildren()
	self.nodeWindow:Dispose()
	self:ClearChildren()
end

local clickedConnection

--- Returns whether creation of connectionLine between clickedConnection and obj is valid, both objects are connection panels.
function connectionLineCanBeCreated(obj)
	-- the same object cant be connected.
	if (clickedConnection.treeNode.name == obj.treeNode.name) then
		return false
	end
	
	if not obj.parent then
		Logger.log("treeNode", "Parent of obj is nil", debug.traceback())
		return false
	end
	
	if not clickedConnection.parent then
		Logger.log("treeNode", "Parent of clickedConnection is nil", debug.traceback())
		return false
	end
	
	if(connectionLine.exists(obj, clickedConnection)) then
		return false
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
			if(not children[i].connectionIn or (children[i].connectionIn.name ~= obj.name and children[i].connectionIn.name ~= clickedConnection.name))then
				table.insert(nodesToVisit, children[i])
			end
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
	return true, function()
		-- Locate the connectionLines connected to connectionIn so that we can remove them
		-- when obj is connectionIn panel
		local connectionLines = connectionLine.getAll()
		local linesToRemove = {}
		if (obj.treeNode.connectionIn and obj.treeNode.connectionIn.name == obj.name) then
			for i=#connectionLines,1,-1 do
				if (obj.name == connectionLines[i][6].name) then
					table.insert(linesToRemove, i)
				end
			end
		elseif (clickedConnection.treeNode.connectionIn and clickedConnection.treeNode.connectionIn.name == clickedConnection.name) then
			for i=#connectionLines,1,-1 do
				if (clickedConnection.name == connectionLines[i][6].name) then
					table.insert(linesToRemove, i)
				end
			end
		end
		
		-- remove the lines, which are in reverse order and as such should not produce problems
		for _, lineId in ipairs(linesToRemove) do
			connectionLine.remove(lineId)
		end
	end
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
	
	clickedConnection.backgroundColor = connectionPanelBackgroundColor
	self.backgroundColor = connectionPanelBackgroundColor
	local canBeCreated, remover = connectionLineCanBeCreated(self)
	if( canBeCreated ) then
		remover()
		connectionLine.add(clickedConnection, self)
	end
	clickedConnection:RequestUpdate()
	clickedConnection = nil
	self:RequestUpdate()
	return self
end


--//=============================================================================
--// Listeners for node selections and their helper functions
--//=============================================================================

local previousPosition = {}
local movingNodeID

--- Key is node id, value is true
WG.selectedNodes = {}
---local selectedNodes = WG.selectedNodes

local ALPHA_OF_SELECTED_NODES = 1
local ALPHA_OF_NOT_SELECTED_NODES = 0.6

-- called also after move!
function listenerNodeWindowOnResize(self)
	-- if (self.resizable) then
	if(self.treeNode.connectionIn) then
		self.treeNode.connectionIn:SetPos(nil, self.height*0.35)
		self.treeNode.connectionIn:Invalidate()
	end
	if(self.treeNode.connectionOut) then
		self.treeNode.connectionOut:SetPos(self.width-18, self.height*0.35)
		self.treeNode.connectionOut:Invalidate()
	end
	if(self.treeNode.logImage)then
		self.treeNode.logImage:SetPos(self.treeNode.width - 15 - self.treeNode.logImage.width)
	end
	
	self.treeNode.width = self.width
	self.treeNode.height = self.height
	self.treeNode:UpdateConnectionLines()
	-- move with all the selected nodes other than the dragged one
	if(movingNodes and self.treeNode.id == movingNodeID) then
		local diffx = self.x - previousPosition.x
		local diffy = self.y - previousPosition.y
		for id,_ in pairs(WG.selectedNodes) do
			if(id ~= movingNodeID) then
				-- Spring.Echo("movingNodes. diffx:"..diffx..", diffy:"..diffy)
				local node = WG.nodeList[id]
				node.x = node.x + diffx
				node.y = node.y + diffy
				node.nodeWindow:SetPos(node.x, node.y)
				node.nodeWindow:Invalidate()
				node:UpdateConnectionLines()
			end
		end
		previousPosition.x = self.x
		previousPosition.y = self.y
	end
	
	self:Invalidate()
end

local function validateEditBox(editBox)
	local variableType = editBox.variableType
	if(variableType == "expression") then
		-- TODO Perform lua validation/compilation check?
		editBox.parent.treeNode.parameters[editBox.index].value = editBox.text
		return
	end
	if(variableType == "number") then
		local numberNew = tonumber(editBox.text)
		if(numberNew) then
			-- valid number parameter
			editBox.validatedValue = numberNew
			editBox.parent.treeNode.parameters[editBox.index].value = numberNew
			return
		end
		local newText = editBox.text
		local length = #newText
		if(length >= 2 and ((newText:sub(1,1) == '"' and newText:sub(length,length) == '"') or (newText:sub(1,1)=="'" and newText:sub(length,length)=="'"))) then
			editBox:SetText(tostring(editBox.validatedValue))
			return
		end
	elseif(variableType == "string") then
		local newText = editBox.text
		local length = #newText
		if(length >= 2 and ((newText:sub(1,1) == '"' and newText:sub(length,length) == '"') or (newText:sub(1,1)=="'" and newText:sub(length,length)=="'"))) then
		 -- valid quoted text parameter
			editBox.validatedValue = newText
			editBox.parent.treeNode.parameters[editBox.index].value = newText
			return
		end
		if(tonumber(editBox.text)) then
			editBox:SetText(tostring(editBox.validatedValue))
			return
		end
	end
	-- context variable name
	editBox.validatedValue = editBox.text
	editBox.parent.treeNode.parameters[editBox.index].value = editBox.text
end

function TreeNode:UpdateParameterValues()
	if(not self.nodeWindow) then
		return
	end
	for i=1,#self.parameterObjects do
		local editBox = self.parameterObjects[i]["editBox"]
		if(editBox) then
			validateEditBox(editBox)
		end
		local checkBox = self.parameterObjects[i]["checkBox"]
		if(checkBox) then
			checkBox.parent.treeNode.parameters[checkBox.index].value = tostring(checkBox.checked)
		end
		local comboBox = self.parameterObjects[i]["comboBox"]
		if(comboBox) then
			comboBox.parent.treeNode.parameters[comboBox.index].value = tostring(comboBox.items[comboBox.selected])
		end
		if(self.parameterObjects[i].componentType == "treePicker") then
			self.parameterObjects[i].label.parent.treeNode.parameters[i].value = self.parameterObjects[i].label.caption
		end
	end
	self.title = self.nameEditBox.text
	-- Spring.Echo(self.isReferenceNode)
	if(self.isReferenceNode) then
		-- only if a referenced tree was set
		if(self.referenceOutputObjects) then
			local k = 1
			for i=1,#self.referenceOutputObjects do
				local name = self.referenceOutputObjects[i].label.caption
				local value = self.referenceOutputObjects[i].editBox.text
				if(value ~= "") then
					self.referenceOutputs[k] = {}
					self.referenceOutputs[k].name = name
					self.referenceOutputs[k].value = value
					k = k+1
					-- Spring.Echo("Setting referenceOutput "..name.." to value "..value)
				end
				 
			end
		end
		if(self.referenceInputObjects) then
			local k = 1
			for i=1,#self.referenceInputObjects do
				local name = self.referenceInputObjects[i].label.caption
				local value = self.referenceInputObjects[i].editBox.text
				if(value ~= "") then
					self.referenceInputs[k] = {}
					self.referenceInputs[k].name = name
					self.referenceInputs[k].value = value
					k = k+1
					-- Spring.Echo("Setting referenceInput "..name.." to value "..value)
				end
				 
			end
		end
	end
	self:UpdateDimensions()
end

local function removeNodeFromSelection(nodeWindow)
	nodeWindow.backgroundColor[4] = ALPHA_OF_NOT_SELECTED_NODES
	WG.selectedNodes[nodeWindow.treeNode.id] = nil
	if(not nodeWindow.disposed)then
		nodeWindow.treeNode:UpdateParameterValues()
		nodeWindow:Invalidate()
	end
end

local function addNodeToSelection(nodeWindow)
	nodeWindow.backgroundColor[4] = ALPHA_OF_SELECTED_NODES
	WG.selectedNodes[nodeWindow.treeNode.id] = true
	nodeWindow:Invalidate()
end

--- Removes all the nodes from WG.selectedNodes, but only if they still exist
local function clearSelection()
	for id,_ in pairs(WG.selectedNodes) do
		if(WG.nodeList[id]) then
			removeNodeFromSelection(WG.nodeList[id].nodeWindow)
		end
	end
	WG.selectedNodes = {}
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
local lastClickedName

function listenerOnMouseDownMoveNode(self, x ,y, button)
	local treeNode = self.treeNode
	local child = self:HitTest(x, y)
	local childName = child.name
	-- Check for any child component which reacts on mouse down event
	if(childName ~= self.name and 
		(#child.OnMouseDown > 0 or #child.OnClick > 0 or child.MouseDown ~= nil) and
		childName ~= treeNode.nameEditBox.name
		)then
		return
	end
	local now = Spring.GetTimer()
	if(childName == treeNode.nameEditBox.name) then
		if(lastClickedName and Spring.DiffTimers(now, lastClickedName) > 0.3) then
			return
		else
			lastClickedName = Spring.GetTimer()
		end
	else
		lastClickedName = nil
	end
	treeNode:UpdateParameterValues()
	local selectSubtree = false
	if(Spring.DiffTimers(now, lastClicked) < 0.3) then
		lastClicked = now
		selectSubtree = true
	end
	lastClicked = now
	local _, ctrl, _, shift = Spring.GetModKeyState()
	if((not selectSubtree) and (not WG.selectedNodes[treeNode.id]) and (not ctrl) and (not shift)) then
		WG.clearSelection()
		addNodeToSelection(self)
	end
	if((not selectSubtree) and WG.selectedNodes[treeNode.id] and (not ctrl) and (not shift)) then
		movingNodes = true
		movingNodeID = treeNode.id
		previousPosition.x = self.x
		previousPosition.y = self.y
		self:StartDragging(x, y)
		return self
	end
	if(movingNodes) then
		return self
	end

	if (shift or selectSubtree) then
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
				node.x = node.x + diffx
				node.y = node.y + diffy
				node.nodeWindow:SetPos(node.x, node.y)
				node.nodeWindow:Invalidate()
				node:UpdateConnectionLines()
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

