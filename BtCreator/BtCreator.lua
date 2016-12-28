function widget:GetInfo()
	return {
		name    = "Behaviour Tree Editor",
		desc    = "Behaviour Tree Editor for creating complex behaviours of groups of units. ",
		author  = "Jakub Stasta",
		date    = "today",
		license = "GNU GPL v2",
		layer   = 0,
		enabled = true
	}
end
 
local Chili, Screen0

local BtEvaluator, BtCreator

local windowBtCreator
local nodePoolLabel
local nodePoolPanel
local buttonPanel
local loadTreeButton
local saveTreeButton
local minimizeButton

local treeName

--- Contains all the TreeNodes on the editable area - windowBtCreator aka canvas. 
WG.nodeList = {}
local nodePoolList = {}
--- Key into the nodeList. 
local rootID = nil

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)

local JSON = Utils.JSON
local BehaviourTree = Utils.BehaviourTree
local Dependency = Utils.Dependency

local Debug = Utils.Debug;
local Logger, dump, copyTable, fileTable = Debug.Logger, Debug.dump, Debug.copyTable, Debug.fileTable

local nodeDefinitionInfo = {}

-- BtEvaluator interface definitions
local BtCreator = {} -- if we need events, change to Sentry:New()

-- connection lines functions
local connectionLine = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCreator/connection_line.lua", nil, VFS.RAW_FIRST)


function BtCreator.show(tree)
	if(not windowBtCreator.visible) then
		windowBtCreator:Show()
	end
	if(not nodePoolPanel.visible) then
		nodePoolPanel:Show()
	end
	if(not buttonPanel.visible) then
		buttonPanel:Show()
	end
	treeName:SetText(tree)
	listenerClickOnLoadTree()
end

function BtCreator.hide()
	if(windowBtCreator.visible) then
		windowBtCreator:Hide()
	end
	if(nodePoolLabel.visible) then
		nodePoolPanel:Hide()
	end
	if(buttonPanel.visible) then
		buttonPanel:Hide()
	end
end

--- Adds Treenode to canvas, and also selects it. 
local function addNodeToCanvas(node)
	if next(WG.nodeList) == nil then
		rootID = node.id
		Logger.log("tree-editing", "BtCreator: Setting u of new of rootID: ", rootID)
	end
	WG.nodeList[node.id] = node
	WG.clearSelection()
	WG.addNodeToSelection(WG.nodeList[node.id].nodeWindow)
end

local function removeNodeFromCanvas(id)
	local node = WG.nodeList[id]
	for i=#node.attachedLines,1,-1 do
		connectionLine.remove(node.attachedLines[i])
	end
	WG.selectedNodes[id] = nil
	node:Dispose()
	node = nil
	WG.nodeList[id] = nil
	windowBtCreator:Invalidate()
	windowBtCreator:RequestUpdate()
end

-- //////////////////////////////////////////////////////////////////////
-- Listeners
-- //////////////////////////////////////////////////////////////////////

local copyTreeNode = nil
--- In coordinates of nodePool(origin in top left corner of nodePool)
local startCopyingLocation = {}

function listenerStartCopyingNode(node, x , y)
	Logger.log("tree-editing", "listener start Copy Object. x:", x + node.x, ", y=", y + node.y)
	copyTreeNode = node
	startCopyingLocation.x = x + node.x
	startCopyingLocation.y = y + node.y - nodePoolPanel.scrollPosY
	return node
end

function listenerEndCopyingNode(self, x , y)
	--y = y + startCopyingLocation.y
	if(copyTreeNode and x - nodePoolPanel.width - startCopyingLocation.x > -20) then
		local params = {
			parent = windowBtCreator,
			nodeType = copyTreeNode.nodeType,
			x = x - nodePoolPanel.width - startCopyingLocation.x,
			y = y + startCopyingLocation.y - 70,
			width = copyTreeNode.width,
			height = copyTreeNode.height,
			connectable = true,
			draggable = true,
			hasConnectionIn = true,
			hasConnectionOut = nodeDefinitionInfo[copyTreeNode.nodeType].hasConnectionOut,
			parameters = copyTable(nodeDefinitionInfo[copyTreeNode.nodeType].parameters)
		}
		addNodeToCanvas(Chili.TreeNode:New(params))
		copyTreeNode = nil
	end
end

local clearCanvas, loadBehaviourTree, formBehaviourTree

function listenerClickOnSaveTree()
	Logger.log("save-and-load", "Save Tree clicked on. ")
	formBehaviourTree():Save(treeName.text)
end

function listenerClickOnLoadTree()
	Logger.log("save-and-load", "Load Tree clicked on. ")
	local bt = BehaviourTree.load(treeName.text)
	if(bt)then
		clearCanvas()
		loadBehaviourTree(bt)
	else
		error("BehaviourTree " .. treeName.text .. " instance not found. " .. debug.traceback())
	end
end

function listenerClickOnMinimize()
	Logger.log("tree-editing", "Minimize BtCreator. ")
	BtCreator.hide()
end

-- //////////////////////////////////////////////////////////////////////
-- Messages from BtEvaluator
-- //////////////////////////////////////////////////////////////////////

local DEFAULT_COLOR = {1,1,1,0.6}
local RUNNING_COLOR = {1,0.5,0,0.6}
local SUCCESS_COLOR = {0.5,1,0.5,0.6}
local FAILURE_COLOR = {1,0.25,0.25,0.6}

local function updateStatesMessage(states)
	for id, node in pairs(WG.nodeList) do
		local color = copyTable(DEFAULT_COLOR);
		if(states[id] ~= nil) then
			if(states[id]:upper() == "RUNNING") then
				color = copyTable(RUNNING_COLOR)
			elseif(states[id]:upper() == "SUCCESS") then
				color = copyTable(SUCCESS_COLOR)
			elseif(states[id]:upper() == "FAILURE") then
				color = copyTable(FAILURE_COLOR)
			else
				Logger.log("communication", "Uknown state received from AI, for node id: ", id)
			end
		end
		-- Do not change color alpha
		local alpha = node.nodeWindow.backgroundColor[4]
		node.nodeWindow.backgroundColor = color
		node.nodeWindow.backgroundColor[4] = alpha
		node.nodeWindow:Invalidate()
	end
	local children = WG.nodeList[rootID]:GetChildren()
	if(#children > 0) then
		local alpha = WG.nodeList[rootID].nodeWindow.backgroundColor[4]
		WG.nodeList[rootID].nodeWindow.backgroundColor = copyTable(children[1].nodeWindow.backgroundColor)
		WG.nodeList[rootID].nodeWindow.backgroundColor[4] = alpha
		WG.nodeList[rootID].nodeWindow:Invalidate()
	end
end

local function generateNodePoolNodes(nodes)
	Logger.log("communication", "NODES DECODED:  ", nodes)
	local heightSum = 30 -- skip NodePoolLabel
	for i=1,#nodes do
		local nodeParams = {
			name = nodes[i].name,
			hasConnectionOut = (nodes[i].children == null) or (type(nodes[i].children) == "table" and #nodes[i].children ~= 0),
			nodeType = nodes[i].name, -- TODO use name parameter instead of nodeType
			parent = nodePoolPanel,
			y = heightSum,
			tooltip = nodes[i].tooltip or "",
			draggable = false,
			resizable = false,
			connectable = false,
			onMouseDown = { listenerStartCopyingNode },
			onMouseUp = { listenerEndCopyingNode },
			parameters = nodes[i]["parameters"],
		}
		-- Make value field from defaultValue. 
		for i=1,#nodeParams.parameters do
			if(nodeParams.parameters[i]["defaultValue"]) then
				nodeParams.parameters[i]["value"] = nodeParams.parameters[i]["defaultValue"]
				nodeParams.parameters[i]["defaultValue"] = nil
			end
		end
		nodeDefinitionInfo[nodeParams.nodeType] = {}
		nodeDefinitionInfo[nodeParams.nodeType]["parameters"] = copyTable(nodeParams.parameters)
		nodeDefinitionInfo[nodeParams.nodeType]["hasConnectionIn"]  = nodeParams.hasConnectionIn
		nodeDefinitionInfo[nodeParams.nodeType]["hasConnectionOut"] = nodeParams.hasConnectionOut
		if(nodes[i].defaultWidth) then
			local minWidth = 110
			if(#nodes[i]["parameters"] > 0) then
				for k=1,#nodes[i]["parameters"] do
					minWidth = math.max(minWidth, nodePoolPanel.font:GetTextWidth(nodes[i]["parameters"][k]["value"]) + nodePoolPanel.font:GetTextWidth(nodes[i]["parameters"][k]["name"]) + 40)
					--nodes[i]["parameters"][k]["defaultValue"]:len()
				end
				
			end
			nodeParams.width = math.max(minWidth, nodes[i].defaultWidth)
		end
		if(nodes[i].defaultHeight) then
			nodeParams.height = math.max(50 + #nodes[i]["parameters"]*20, nodes[i].defaultHeight)
		end
		heightSum = heightSum + (nodeParams.height or 60)
		table.insert(nodePoolList, Chili.TreeNode:New(nodeParams))
	end
	nodePoolPanel:RequestUpdate()
end

local scripts = {}
local commands = {}

local function getCommandClass(name) 
	c = scripts[name] 
	if not c then 
		c = VFS.Include(LUAUI_DIRNAME .. "Widgets/btCommandScripts/" .. name, nil, VFS.RAW_FIRST)
		scripts[name] = c
	end
	return c
end

local function getCommand(name, id, treeId)
	commandMap = commands[name]
	if not commandMap then
		commandMap = {}
		commands[name] = commandMap
	end
	
	cmdsForInstance = commandMap[treeId]
	if not cmdsForInstance then
		cmdsForInstance = {}
		commandMap[treeId] = cmdsForInstance
	end
	
	cmd = cmdsForInstance[id]
	if not cmd then
		cmd = getCommandClass(name):BaseNew()
		cmdsForInstance[id] = cmd
	end
	return cmd
end

local blackboardsForInstance = {}
local commandsForUnits = {}-- map(unitId,command)

local function executeScript(params)
	command = getCommand(params.name, params.id, params.treeId)
	local blackboard = blackboardsForInstance[params.treeId]
	if(not blackboard)then
		blackboard = {}
		blackboardsForInstance[params.treeId] = blackboard
	end

	if (params.func == "RUN") then
		for i = 1, #params.units do
			commandsForUnits[params.units[i]] = command
		end
		
		local parameters = {}
		for k, v in pairs(params.parameter) do
			local value = v
			if(type(value) == "string" and value:match("^%$"))then
				Logger.log("blackboard", "Extracting ", value, " from blackboard and inputting it into ", k, " parameter in node ", params.name)
				value = blackboard[value]
			end
			parameters[k] = value
		end
		
		local result, output = command:BaseRun(params.units, parameters)
		if(output)then
			for k, v in pairs(output) do
				local originalValue = params.parameter[k]
				if(type(originalValue) == "string" and originalValue:match("^%$"))then
					Logger.log("blackboard", "Saving to ", value, " blackboard with value ", v, " in node ", params.name)
					blackboard[originalValue] = v
				else
					Logger.log("blackboard", "A constant value '", originalValue, "' was given to an output or input-output parameter '", k, "' of a command '", params.name, "' in instance ", params.treeId, ".", params.id)
				end
			end
		end
		Logger.log("luacommand", "Result: ", result)
		return result
	elseif (params.func == "RESET") then
		command:BaseReset()
		return nil
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag) 
	Logger.log("command", "----UnitCommand---")
	cmd = commandsForUnits[unitID]
	if cmd  then
		cmd:AddActiveCommand(unitID,cmdID,cmdTag)
	end
end

function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	Logger.log("command", "----UnitCmdDone---")
	cmd = commandsForUnits[unitID]
	if cmd then
		cmd:CommandDone(unitID,cmdID,cmdTag)
	end
end

function widget:UnitIdle(unitID, unitDefID, unitTeam)
	Logger.log("command", "----UnitIdle---")
	cmd = commandsForUnits[unitID]
	if cmd then
		cmd:SetUnitIdle(unitID)
	end
end


function widget:Initialize()	
	if (not WG.ChiliClone) then
		-- don't run if we can't find Chili
		widgetHandler:RemoveWidget()
		return
	end
	
	BtEvaluator = WG.BtEvaluator
	
	BtEvaluator.OnNodeDefinitions = generateNodePoolNodes
	BtEvaluator.OnUpdateStates = updateStatesMessage
	BtEvaluator.OnCommand = executeScript
	
	-- Get ready to use Chili
	Chili = WG.ChiliClone
	Screen0 = Chili.Screen0	
	
	connectionLine.initialize()
	
	nodePoolPanel = Chili.ScrollPanel:New{
		parent = Screen0,
		y = '56%',
		x = 25,
		width  = 125,
		minWidth = 115,
		height = '41.5%',
		skinName='DarkGlass',
	}
	nodePoolLabel = Chili.Label:New{
		parent = nodePoolPanel,
		x = '20%',
		y = '3%',
		width  = '10%',
		height = '10%',
		caption = "Node Pool",
		skinName='DarkGlass',
	} 
	
	BtEvaluator.requestNodeDefinitions()
	local maxNodeWidth = 125
	for i=1,#nodePoolList do
		if(nodePoolList[i].width + 21 > maxNodeWidth) then
			maxNodeWidth = nodePoolList[i].width + 21
		end
	end
	nodePoolPanel.width = maxNodeWidth
	nodePoolPanel:RequestUpdate()
	 -- Create the window
	windowBtCreator = Chili.Window:New{
		parent = Screen0,
		x = nodePoolPanel.width + 22,
		y = '56%',
		width  = Screen0.width - nodePoolPanel.width - 25,
		height = '42%',	
		padding = {10,10,10,10},
		draggable=true,
		resizable=true,
		skinName='DarkGlass',
		backgroundColor = {1,1,1,1},
		OnClick = { WG.clearSelection },
		-- OnMouseDown = { listenerStartSelectingNodes },
		-- OnMouseUp = { listenerEndSelectingNodes },
	}	
	
	addNodeToCanvas(Chili.TreeNode:New{
		parent = windowBtCreator,
		nodeType = "Root",
		y = '35%',
		x = 5,
		draggable = true,
		resizable = true,
		connectable = true,
		hasConnectionIn = false,
		hasConnectionOut = true,
		id = false,
	})
	
	buttonPanel = Chili.Control:New{
		parent = Screen0,
		x = 0,
		y = 0,
		width = '100%',
		height = '100%',
	}
	
	saveTreeButton = Chili.Button:New{
		parent = buttonPanel,
		x = windowBtCreator.x,
		y = windowBtCreator.y - 30,
		width = 90,
		height = 30,
		caption = "Save Tree",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { listenerClickOnSaveTree },
	}
	loadTreeButton = Chili.Button:New{
		parent = buttonPanel,
		x = saveTreeButton.x + saveTreeButton.width,
		y = saveTreeButton.y,
		width = 90,
		height = 30,
		caption = "Load Tree",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { listenerClickOnLoadTree },
	}
	
	minimizeButton = Chili.Button:New{
		parent = buttonPanel,
		x = buttonPanel.width - 50,
		y = loadTreeButton.y,
		width = 35,
		height = 30,
		caption = "_",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { listenerClickOnMinimize },
	}
	
	treeName = Chili.EditBox:New{
		parent = windowBtCreator,
		text = "02-flipEcho",
		width = '33%',
		x = '40%',
		y = 5,
		align = 'left',
		skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0,0,0,0},
		editingText = true,
	}
	-- treeName.font.size = 16
	listenerClickOnMinimize()
	
	WG.BtCreator = BtCreator
	Dependency.fill(Dependency.BtCreator)
end 

function widget:KeyPress(key)
	if(Spring.GetKeySymbol(key) == "delete") then -- Delete was pressed
		for id,_ in pairs(WG.selectedNodes) do
			if(id ~= rootID) then
				removeNodeFromCanvas(id)
			end
		end
		return true;
	end
	
end


local fieldsToSerialize = {
	'id',
	'nodeType',
	'text',
	'x',
	'y',
	'width',
	'height',
	'parameters',
}

function formBehaviourTree()
	local bt = BehaviourTree:New()
	local nodeMap = {}
	for id,node in pairs(WG.nodeList) do
		if(node.id ~= rootID)then
			local params = {}
			for i, key in ipairs(fieldsToSerialize) do
				params[key] = node[key]
			end
			-- get the string value from editbox
			for i=1,#node.parameters do
				if(nodeDefinitionInfo[node.nodeType].parameters[i]["componentType"]=="editBox") then
					if(nodeDefinitionInfo[node.nodeType].parameters[i]["variableType"] == "number" and not node.parameterObjects[i]["editBox"].text:match("^%$")) then
						params.parameters[i].value = tonumber(node.parameterObjects[i]["editBox"].text)
					else
						params.parameters[i].value = node.parameterObjects[i]["editBox"].text
					end
				end
			end
			nodeMap[node] = bt:NewNode(params)
		end
	end
	
	for id,node in pairs(WG.nodeList) do
		local btNode = nodeMap[node]
		local children = node:GetChildren()
		for i, childNode in ipairs(children) do
			local btChild = nodeMap[childNode]
			if(btNode)then
				btNode:Connect(btChild)
			else
				bt:SetRoot(btChild)
			end
		end
	end
	
	return bt
end

function clearCanvas(omitRoot)
	connectionLine.clear()
	for id,node in pairs(WG.nodeList) do
		node:Dispose()
	end
	WG.nodeList = {}
	WG.selectedNodes = {}
	
	if(not omitRoot)then
		addNodeToCanvas(Chili.TreeNode:New{
			parent = windowBtCreator,
			nodeType = "Root",
			y = '35%',
			x = 5,
			draggable = true,
			resizable = true,
			connectable = true,
			hasConnectionIn = false,
			hasConnectionOut = true,
			id = false,
		})
	end
end

local function loadBehaviourNode(bt, btNode)
	if(not btNode)then return nil end
	local params = {}
	for k,v in pairs(nodeDefinitionInfo[btNode.nodeType]) do
		if(type(v) == "table") then
			params[k] = copyTable(v)
		else
			params[k] = v
		end
	end
	for k, v in pairs(btNode) do
		if(k=="parameters") then
			for i=1,#v do
				params.parameters[i].value = v[i].value
			end
		else
			params[k] = v
		end
	end
	for k, v in pairs(bt.properties[btNode.id]) do
		params[k] = v
	end
	params.children = nil
	params.name = nil
	params.parent = windowBtCreator
	params.connectable = true
	params.draggable = true
	local node = Chili.TreeNode:New(params)
	addNodeToCanvas(node)
	for _, btChild in ipairs(btNode.children) do
		local child = loadBehaviourNode(bt, btChild)
		connectionLine.add(node.connectionOut, child.connectionIn)
	end
	return node
end

function loadBehaviourTree(bt)
	local root = loadBehaviourNode(bt, bt.root)
	if(root)then
		connectionLine.add(WG.nodeList[rootID].connectionOut, root.connectionIn)
	end
	
	for _, node in ipairs(bt.additionalNodes) do
		loadBehaviourNode(bt, node)
	end
	WG.clearSelection()
end

Dependency.deferWidget(widget, Dependency.BtEvaluator)