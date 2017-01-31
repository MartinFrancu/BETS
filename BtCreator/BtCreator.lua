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
local showSensorsButton
local minimizeButton
local roleManagerButton
local newTreeButton


local treeNameEditbox

local rolesOfCurrentTree

local rolesWindow
local showRoleManagementWindow
local roleManagementDoneButton
local newCathegoryButton

local cathegoryDefinitionWindow
local showCathegoryDefinitionWindow
local doneCathegoryDefinition
local cancelCathegoryDefinition

-- This table takes record of defined cathegories and saves them in file.
-- Format is an array of records of style:
	-- {}
local unitsCathegories
local UNIT_CATHEGORIES_DIRNAME = LUAUI_DIRNAME .. "Widgets/BtBehaviours/"
local UNIT_CATHEGORIES_FILE = "BtUnitCathegories"

--- Keys are node IDs, values are Treenode objects.  
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
local isScript = {}

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
	treeNameEditbox:SetText(tree)
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
		Logger.log("tree-editing", "BtCreator: Setting u of new of rootID: ", rootID, " script: ", node.luaScript)
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
	local resultTree = formBehaviourTree()
	--showRoleManagementWindow(resultTree)
	if( (rolesOfCurrentTree ~= nil ) ) then
		resultTree.roles = rolesOfCurrentTree
		resultTree.defaultRole = rolesOfCurrentTree[1].name
	end
	resultTree:Save(treeNameEditbox.text)
	WG.clearSelection()
end

local sensorsWindow
local bgrColor = {0.8,0.5,0.2,0.6}
local focusColor = {0.8,0.5,0.2,0.3}

function listenerClickOnShowSensors()
	showSensorsButton.backgroundColor , bgrColor = bgrColor, showSensorsButton.backgroundColor
	showSensorsButton.focusColor, focusColor = focusColor, showSensorsButton.focusColor
	local sensors = WG.SensorManager.getAvailableSensors()
	if(sensorsWindow) then
		sensorsWindow:Dispose()
		sensorsWindow = nil
		return
	end
	sensorsWindow = Chili.Window:New{
		parent = Screen0,
		name = "SensorsWindow",
		x = showSensorsButton.x - 5,
		y = showSensorsButton.y - (#sensors*20 + 60) + 5,
		width = 200,
		height = #sensors*20 + 60,
		skinName='DarkGlass',
	}
	Chili.Label:New{
			parent = sensorsWindow,
			x = 10,
			y = 0,
			width = 50,
			height = 20,
			caption = "Available Sensors: ",
			skinName='DarkGlass',
		}
	for i=1,#sensors do
		Chili.Label:New{
			parent = sensorsWindow,
			x = 10,
			y = i*20,
			width = 50,
			height = 20,
			caption = sensors[i] .. "()",
			skinName='DarkGlass',
			name = "Sensor"..i,
		}
		sensorsWindow:GetChildByName("Sensor"..i).font.color = {0.7,0.7,0.7,1}
	end
end

function listenerClickOnNewTree()
	local i = 0
	local newTreeName = "New Tree " .. i
	while(VFS.FileExists(LUAUI_DIRNAME .. "Widgets/BtBehaviours/" .. newTreeName .. ".json")) do
		i = i + 1
		newTreeName = "New Tree " .. i
	end
	treeNameEditbox:SetText(newTreeName)
	clearCanvas()
end

local serializedTreeName

function listenerClickOnLoadTree()
	Logger.log("save-and-load", "Load Tree clicked on. ")
	local bt = BehaviourTree.load(treeNameEditbox.text)
	if(bt)then
		clearCanvas()
		loadBehaviourTree(bt)
		rolesOfCurrentTree = bt.roles or {}
	else
		error("BehaviourTree " .. treeNameEditbox.text .. " instance not found. " .. debug.traceback())
	end
end

function listenerClickOnRoleManager()
	showRoleManagementWindow()
	--[[Logger.log("tree-editing", "Adding new role. ")
	local rootNode = WG.nodeList[rootID]
	table.insert(rootNode.parameters, {
		name = "Role "..#rootNode.parameters + 1, 
		value = "Role Name",
		componentType = "editBox",
		variableType = "string",
	})
	rootNode:CreateNextParameterObject()
	--]]
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

local function generateScriptNodes(heightSum, nodes) 
	for i=1,#nodes do
		if (nodes[i].nodeType ~= "luaCommand") then
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
	end
	return heightSum
end

local function getParameterDefinitions()
	local directoryName = LUAUI_DIRNAME .. "Widgets/BtCommandScripts" 
	local folderContent = VFS.DirList(directoryName)
	local paramsDefs = {}

	for _,scriptName in ipairs(folderContent)do
		Logger.log("script-load", "Loading definition from file: ", scriptName)
		local nameComment = "--[[" .. scriptName .. "]] "
		local code = nameComment .. VFS.LoadFile(scriptName) .. "; return getInfo()"
		local shortName = string.sub(scriptName, string.len(directoryName) + 2)
		local script = assert(loadstring(code))
	
		local success, info = pcall(script)

		if success then
			Logger.log("script-load", "Script: ", shortName, ", Definitions loaded: ", info.parameterDefs)
			paramsDefs[shortName] = info.parameterDefs or {}
		else
			error("script-load".. "Script ".. scriptName.. " is missing the getParameterDefs() function or it contains an error: ".. info)
		end
	end
	return paramsDefs
end

local function generateNodePoolNodes(nodes)
	Logger.log("communication", "NODES DECODED:  ", nodes)
	local heightSum = 30 -- skip NodePoolLabel
    heightSum = generateScriptNodes(heightSum, nodes)
	
	-- load lua commands
	local paramDefs = getParameterDefinitions()
	
	for scriptName, params in pairs(paramDefs) do
		local nodeParams = {
			name = scriptName,
			hasConnectionOut = false,
			nodeType = scriptName,
			parent = nodePoolPanel,
			y = heightSum,
			tooltip = "",
			draggable = false,
			resizable = false,
			connectable = false,
			onMouseDown = { listenerStartCopyingNode },
			onMouseUp = { listenerEndCopyingNode },
			parameters = params,
		}
		-- Make value field from defaultValue. 
		for i=1,#nodeParams.parameters do
			if(nodeParams.parameters[i]["defaultValue"]) then
				nodeParams.parameters[i]["value"] = nodeParams.parameters[i]["defaultValue"]
				nodeParams.parameters[i]["defaultValue"] = nil
			end
		end
		nodeDefinitionInfo[scriptName] = {}
		nodeDefinitionInfo[scriptName]["parameters"] = copyTable(nodeParams.parameters)
		nodeDefinitionInfo[scriptName]["hasConnectionIn"]  = nodeParams.hasConnectionIn
		nodeDefinitionInfo[scriptName]["hasConnectionOut"] = nodeParams.hasConnectionOut
		
		isScript[scriptName] = true

		nodeParams.width = 110
		nodeParams.height = 50 + #nodeParams.parameters * 20
		heightSum = heightSum + (nodeParams.height or 60)
		table.insert(nodePoolList, Chili.TreeNode:New(nodeParams))
	end
	
	nodePoolPanel:RequestUpdate()
end

function listenerOnClickOnCanvas()
	WG.clearSelection()
	for _,node in pairs(WG.nodeList) do
		node:ValidateEditBoxes()
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
		OnClick = { listenerOnClickOnCanvas }
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
	
	newTreeButton = Chili.Button:New{
		parent = buttonPanel,
		x = windowBtCreator.x,
		y = windowBtCreator.y - 30,
		width = 90,
		height = 30,
		caption = "New Tree",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { listenerClickOnNewTree },
	}
	saveTreeButton = Chili.Button:New{
		parent = buttonPanel,
		x = newTreeButton.x + newTreeButton.width,
		y = newTreeButton.y,
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
	roleManagerButton = Chili.Button:New{
		parent = buttonPanel,
		x = loadTreeButton.x + loadTreeButton.width,
		y = saveTreeButton.y,
		width = 90,
		height = 30,
		caption = "Role manager",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { listenerClickOnRoleManager },
	}
	showSensorsButton = Chili.Button:New{
		parent = buttonPanel,
		x = roleManagerButton.x + roleManagerButton.width,
		y = saveTreeButton.y,
		width = 90,
		height = 30,
		caption = "Sensors",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { listenerClickOnShowSensors },
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
	
	treeNameEditbox = Chili.EditBox:New{
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
	-- treeNameEditbox.font.size = 16
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
	'scriptName',
	'text',
	'x',
	'y',
	'width',
	'height',
	'parameters',
}

--- Contains IDs of nodes as keys - stores IDs of serialized tree, the one with name serializedTree
local serializedIDs = {}

local function updateSerializedIDs()
	serializedIDs = {}
	for id,_ in pairs(WG.nodeList) do
		serializedIDs[id] = true
	end
end

--- Assumes that id is present in WG.nodeList
local function reGenerateTreenodeID(id)
	if(WG.nodeList[id]) then
		WG.nodeList[id]:ReGenerateID()
	end
	local newID = WG.nodeList[id].id
	if(id == rootID) then
		rootID = newID
	end
	WG.nodeList[newID] = WG.nodeList[id]
	WG.nodeList[id] = nil
end

function formBehaviourTree()
	-- on tree Save() regenerate IDs of nodes already present in loaded tree
	if(serializedTreeName and serializedTreeName ~= treeNameEditbox.text) then
		--regenerate all IDs from loaded Tree
		for id,_ in pairs(serializedIDs) do
			if(WG.nodeList[id]) then
				reGenerateTreenodeID(id)
			end
		end
		updateSerializedIDs()
	end
	-- Validate every treenode - when editing editBox parameter and immediately serialize, 
	-- the last edited parameter doesnt have to be updated
	for _,node in pairs(WG.nodeList) do
		node:ValidateEditBoxes()
	end
	
	local bt = BehaviourTree:New()
	local nodeMap = {}
	for id,node in pairs(WG.nodeList) do
		if(node.id ~= rootID)then
			local params = {}
			for _, key in ipairs(fieldsToSerialize) do
				params[key] = node[key]
			end
			local info = nodeDefinitionInfo[node.nodeType]
			local hasScriptName = false
			for i=1,#node.parameters do
				if (node.parameters[i].name == "scriptName") then
					hasScriptName = true
				end
			end
			-- change luaScript node format to fit btEvaluator/controller
			local scriptName = node.nodeType
			if (isScript[scriptName]) then
				Logger.log("save-and-load", "scriptName: " ,scriptName)
				if (not hasScriptName) then
					local scriptParam = {
						name = "scriptName",
						value = scriptName,
					}
					params.parameters[#params.parameters + 1] = scriptParam
				end
				params.nodeType = "luaCommand"
				params.scriptName = scriptName
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
	local info
	
	Logger.log("save-and-load", "loadBehaviourNode - nodeType: ", btNode.nodeType, " scriptName: ", btNode.scriptName, " info: ", nodeDefinitionInfo)
	if (btNode.scriptName ~= nil) then
		info = nodeDefinitionInfo[btNode.scriptName]
	else
		info = nodeDefinitionInfo[btNode.nodeType]
	end
	
	for k,v in pairs(info) do
		if(type(v) == "table") then
			params[k] = copyTable(v)
		else
			params[k] = v
		end
	end
	for k, v in pairs(btNode) do
		if(k=="parameters") then
		
			Logger.log("save-and-load", "params: ", params, ", params.parameters: ", params.parameters, "v[3]: ", v[3])
			for i=1,#v do
				if (v[i].name ~= "scriptName") then
					Logger.log("save-and-load", "params.parameters[i]: ", params.parameters[i], ", v[i]: ", v[i])
					params.parameters[i].value = v[i].value
				end
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
	
	if (btNode.scriptName ~= nil) then
		params.nodeType = btNode.scriptName
	end
	
	local node = Chili.TreeNode:New(params)
	addNodeToCanvas(node)
	for _, btChild in ipairs(btNode.children) do
		local child = loadBehaviourNode(bt, btChild)
		connectionLine.add(node.connectionOut, child.connectionIn)
	end
	return node
end

function loadBehaviourTree(bt)
	serializedTreeName = treeNameEditbox.text -- to be able to regenerate ids of deserialized nodes, when saved with different name
	local root = loadBehaviourNode(bt, bt.root)
	if(root)then
		connectionLine.add(WG.nodeList[rootID].connectionOut, root.connectionIn)
	end
	
	for _, node in ipairs(bt.additionalNodes) do
		loadBehaviourNode(bt, node)
	end
	WG.clearSelection()
	updateSerializedIDs()
end                

--------------------------------------------------------------------------------------------------------------------------
--- ROLE MANAGEMENT ------------------------------------------------------------------------------------------------------

local function loadStandardCathegories()	
	unitCathegories = {}
	local transports = {}
	local immobile = {}
	local buildings = {}
	local builders = {}
	local mobileBuilders = {}
	local groundUnits = {}
	local airUnits = {}
	local airFighters = {}
	local airBombers = {}
	
	for _,unitDef in pairs(UnitDefs) do
		if(unitDef.isTransport ) then
			table.insert(transports, { id = unitDef.id, name = unitDef.name, humanName = unitDef.humanName})
		end
		if(unitDef.isImmobile ) then
			table.insert(immobile, { id = unitDef.id, name = unitDef.name, humanName = unitDef.humanName})
		end
		if(unitDef.isBuilding ) then
			table.insert(buildings, { id = unitDef.id, name = unitDef.name, humanName = unitDef.humanName})
		end
		if(unitDef.isBuilder ) then
			table.insert(builders, { id = unitDef.id, name = unitDef.name, humanName = unitDef.humanName})
		end
		if(unitDef.isMobileBuilder ) then
			table.insert(mobileBuilders, { id = unitDef.id, name = unitDef.name, humanName = unitDef.humanName})
		end
		if(unitDef.isGroundUnit ) then
			table.insert(groundUnits, { id = unitDef.id, name = unitDef.name, humanName = unitDef.humanName})
		end
		if(unitDef.isAirUnit ) then
			table.insert(airUnits, { id = unitDef.id, name = unitDef.name, humanName = unitDef.humanName})
		end
		if(unitDef.isFighterAirUnit ) then
			table.insert(airFighters, { id = unitDef.id, name = unitDef.name, humanName = unitDef.humanName})
		end
		if(unitDef.isBomberAirUnit ) then
			table.insert(airBombers, { id = unitDef.id, name = unitDef.name, humanName = unitDef.humanName})
		end
	end
	table.insert(unitCathegories, {Name = "transports", Types = transports})
	table.insert(unitCathegories, {Name = "immobile", Types = immobile})
	table.insert(unitCathegories, {Name = "buildings", Types = buildings})
	table.insert(unitCathegories, {Name = "builders", Types = builders})
	table.insert(unitCathegories, {Name = "mobileBuilders", Types = mobileBuilders})
	table.insert(unitCathegories, {Name = "groundUnits", Types = groundUnits})
	table.insert(unitCathegories, {Name = "airUnits", Types = airUnits})
	table.insert(unitCathegories, {Name = "fighterAirUnits", Types = airFighters})
	table.insert(unitCathegories, {Name = "bomberAirUnits", Types = airBombers})
end


-- This method will load unit cathegories into one object. 
local function loadUnitCathegories()
	unitCathegories = {}
	----[[
	local file = io.open(UNIT_CATHEGORIES_DIRNAME .. UNIT_CATHEGORIES_FILE , "r")
	if(not file)then
			unitCathegories = {}
	end
	local text = file:read("*all")
	unitCathegories = JSON:decode(text)
	file:close()
	--]]
end

local function saveUnitCathegories()
	if(unitCathegories == nil) then
		Logger.log("roles", "unitCathegories = nill")
		unitCathegories = {}
	end
	
	local text = JSON:encode(unitCathegories, nil, { pretty = true, indent = "\t" })
	Spring.CreateDir(UNIT_CATHEGORIES_DIRNAME)
	local file = io.open(UNIT_CATHEGORIES_DIRNAME .. UNIT_CATHEGORIES_FILE, "w")
	if(not file)then
		return nil
	end
	file:write(text)
	file:close()	
	return true
end
-- This method returns unitTypes in given role in  rolesOfCurrentTree.
function getRoleData(roleName)
	for _,roleData in pairs(rolesOfCurrentTree) do 
			if(roleData.name == roleName) then
				return roleData
			end
	end
end



function showCathegoryDefinitionWindow()
	loadStandardCathegories()
	rolesWindow:Hide()
	cathegoryDefinitionWindow = Chili.Window:New{
		parent = Screen0,
		x = 150,
		y = 300,
		width = 1250,
		height = 600,
		skinName = 'DarkGlass'
	}
	local nameEditBox = Chili.EditBox:New{
			parent = cathegoryDefinitionWindow,
			x = 0,
			y = 0,
			text = "New unit cathegory",
			width = 150
	}
	local cathegoryDoneButton = Chili.Button:New{
		parent =  cathegoryDefinitionWindow,
		x = nameEditBox.x + nameEditBox.width,
		y = 0,
		caption = "DONE",
		OnClick = {doneCathegoryDefinition}, 
	}
	cathegoryDoneButton.UnitCathegories = unitCathegories
	
	local cathegoryCancelButton = Chili.Button:New{
		parent =  cathegoryDefinitionWindow,
		x = cathegoryDoneButton.x + cathegoryDoneButton.width,
		y = 0,
		caption = "CANCEL",
		OnClick = {cancelCathegoryDefinition}, 
	} 
	local cathegoryScrollPanel = Chili.ScrollPanel:New{
		parent = cathegoryDefinitionWindow,
		x = 0,
		y = 30,
		width  = '100%',
		height = '100%',
		skinName='DarkGlass'
	}
	xOffSet = 5
	yOffSet = 30
	local typesCheckboxes = {}
	local xLocalOffSet = 0
	for _,unitDef in pairs(UnitDefs) do
		local typeCheckBox = Chili.Checkbox:New{
			parent = cathegoryScrollPanel,
			x = xOffSet + (xLocalOffSet * 250),
			y = yOffSet,
			caption = unitDef.humanName,
			checked = false,
			width = 200,
		}
		typeCheckBox.unitId = unitDef.id
		typeCheckBox.unitName = unitDef.name
		typeCheckBox.unitHumanName = unitDef.humanName
		xLocalOffSet = xLocalOffSet + 1
		if(xLocalOffSet == 5) then 
			xLocalOffSet = 0
			yOffSet = yOffSet + 20
		end
		table.insert(typesCheckboxes, typeCheckBox)
	end
	-- check old checked checkboxes:
	cathegoryDoneButton.Checkboxes = typesCheckboxes
	cathegoryDoneButton.CathegoryNameEditBox = nameEditBox
	cathegoryDoneButton.Window = cathegoryDefinitionWindow
end



function doneCathegoryDefinition(self)	
	-- add new cathegory to unitCathegories
	local unitTypes = {}
	for _,unitTypeCheckBox in pairs(self.Checkboxes) do
		if(unitTypeCheckBox.checked == true) then
			local typeRecord = {id = unitTypeCheckBox.unitId, name = unitTypeCheckBox.unitName, humanName = unitTypeCheckBox.unitHumanName}
			table.insert(unitTypes, typeRecord)
		end
	end
	-- add check for cathegory name?
	local newCathegory = {
		Name = self.CathegoryNameEditBox.text,
		Types = unitTypes,
	}
	table.insert(unitCathegories, newCathegory)
	saveUnitCathegories()
	cathegoryDefinitionWindow:Hide()
	showRoleManagementWindow()
end
function cancelCathegoryDefinition(self)
	cathegoryDefinitionWindow:Hide()
	showRoleManagementWindow()
end

local function findCathegoryData(cathegoryName)
	for _,catData in pairs(unitCathegories) do 
		if(catData.Name == cathegoryName) then
			return catData
		end
	end
end


local function isInTable(value, t)
	for i=1,#t do
		if(t[i] == value) then
			return true
		end
	end
	return false
end

function doneRoleManagerWindow(self)
	self.Window:Hide()
	local result = {}
	for _,roleRecord in pairs(self.RolesData) do
		local roleName = roleRecord.NameEditBox.text
		local usedTypes = {}
		if(self.OldUnitTypes ~= nil) and (self.OldUnitTypes.checked == true) then
			for _,unitType in pairs(OldUnitTypes.Types) do
				usedTypes[unitType.humanName] = true
			end
		end
		for _, cathegoryCB in pairs(roleRecord.CheckBoxes) do
			if(cathegoryCB.checked) then
				local catData = findCathegoryData(cathegoryCB.caption)
				if(catData == nil) then
					Logger.log("error", "RoleManager, doneRoleManagerWindow: unknown cathegory encountered.")
				else
					for _,unitType in pairs(catData.Types) do
						usedTypes[unitType.humanName] = true
					end
				end
			end
		end
		local typesData = {}
		for humanName,used in pairs(usedTypes) do
			if(used == true) then
				table.insert(typesData, humanName)
			end
		end
		local roleResult = {name = roleName, types = typesData}
		table.insert(result, roleResult)
	end
	
	rolesOfCurrentTree = result
end

function showRoleManagementWindow() 	
	local tree = formBehaviourTree()
	-- find out how many roles we need:
	local roleCount = 1
	local function visit(node)
		if(not node) then
			return
		end
		if(node.nodeType == "roleSplit" and roleCount < #node.children)then
				roleCount = #node.children
		end
		for _, child in ipairs(node.children) do
				visit(child)
		end
	end
	visit(tree.root)
	
	
	--[[ RESET UNIT CATHEGORIES
	loadStandardCathegories()
	saveUnitCathegories()
	--]]
	loadUnitCathegories()
	
	rolesWindow = Chili.Window:New{
		parent = Screen0,
		x = 150,
		y = 300,
		width = 1200,
		height = 600,
		skinName = 'DarkGlass'
	}
	
	-- now I just need to save it
	roleManagementDoneButton = Chili.Button:New{
		parent =  rolesWindow,
		x = 0,
		y = 0,
		caption = "DONE",
		OnClick = {doneRoleManagerWindow}, 
	}
	
	newCathegoryButton = Chili.Button:New{
		parent = rolesWindow,
		x = 150,
		y = 0,
		width = 150,
		caption = "Define new Cathegory",
		OnClick = {showCathegoryDefinitionWindow},
	}

	
	local rolesScrollPanel = Chili.ScrollPanel:New{
		parent = rolesWindow,
		x = 0,
		y = 30,
		width  = '100%',
		height = '100%',
		skinName='DarkGlass'
	}
	local rolesCathegoriesCB = {}
	local xOffSet = 10
	local yOffSet = 10
	local xCheckBoxOffSet = 180
	-- set up array for all
	
	for roleIndex=0, roleCount -1 do
		local nameEditBox = Chili.EditBox:New{
			parent = rolesScrollPanel,
			x = xOffSet,
			y = yOffSet,
			text = "Role ".. tostring(roleIndex),
			width = 150
		}
		local keepOldAssingment
		if(rolesOfCurrentTree[roleIndex+1]) then
			nameEditBox:SetText(rolesOfCurrentTree[roleIndex+1].name)
			-- also add a checkbox:
			keepOldAssignment = Chili.Checkbox:New{
				parent = rolesScrollPanel,
				x = xOffSet,
				y = yOffSet + 20,
				caption= "Old unit types",
				checked = true,
				width = 150
			}
			keepOldAssignment.Types = rolesOfCurrentTree[roleIndex+1].types
		end
		
		local cathegoryCheckBoxes = {}
		local xLocalOffSet = 0
		for _,cathegory in pairs(unitCathegories) do
			local cathegoryCheckBox = Chili.Checkbox:New{
				parent = rolesScrollPanel,
				x = xOffSet + xCheckBoxOffSet + (xLocalOffSet * 250),
				y = yOffSet,
				caption = cathegory.Name,
				checked = false,
				width = 200,
			}
			xLocalOffSet = xLocalOffSet + 1
			if(xLocalOffSet == 4) then 
				xLocalOffSet = 0
				yOffSet = yOffSet + 20
			end
			table.insert(cathegoryCheckBoxes, cathegoryCheckBox)
		end
		yOffSet = yOffSet + 50
		local roleCathegories = {}
		roleCathegories["NameEditBox"] = nameEditBox
		roleCathegories["CheckBoxes"] = cathegoryCheckBoxes
		if(keepOldAssignment ~= nil) then
			roleCathegories["OldUnitTypes"] = keepOldAssignment
		end
		table.insert(rolesCathegoriesCB,roleCathegories)
	end	
	roleManagementDoneButton.RolesData = rolesCathegoriesCB
	roleManagementDoneButton.Window = rolesWindow	
end

--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------

Dependency.deferWidget(widget, Dependency.BtEvaluator)