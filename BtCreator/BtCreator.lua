function widget:GetInfo()
	return {
		name    = "BtCreator",
		desc    = "Behaviour Tree Editor for creating complex behaviours of groups of units. ",
		author  = "BETS Team",
		date    = "2016-09-01",
		license = "GNU GPL v2",
		layer   = 0,
		enabled = true
	}
end

local Chili, Screen0

local BtEvaluator

local btCreatorWindow
local nodePoolLabel
local nodePoolPanel
local buttonPanel
local loadTreeButton
local saveTreeButton
local showSensorsButton
local showBlackboardButton
local breakpointButton
local continueButton
local minimizeButton
local roleManagerButton
local newTreeButton

local treeNameEditbox

local rolesOfCurrentTree

local rolesWindow
local showRoleManagementWindow
local roleManagementDoneButton
local newCategoryButton

local categoryDefinitionWindow
local showCategoryDefinitionWindow
local doneCategoryDefinition
local cancelCategoryDefinition

--- Keys are node IDs, values are Treenode objects.
WG.nodeList = {}
local nodePoolList = {}
--- Key into the nodeList.
local rootID = nil

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)

-- local JSON = Utils.JSON
local BehaviourTree = Utils.BehaviourTree
local Dependency = Utils.Dependency
local sanitizer = Utils.Sanitizer.forWidget(widget)

local Debug = Utils.Debug;
local Logger, dump, copyTable, fileTable = Debug.Logger, Debug.dump, Debug.copyTable, Debug.fileTable

local nodeDefinitionInfo = {}
local isScript = {}

-- BtEvaluator interface definitions
local BtCreator = {} -- if we need events, change to Sentry:New()

-- connection lines functions
local connectionLine = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCreator/connection_line.lua", nil, VFS.RAW_FIRST)
-- blackboard window
local blackboard

local treeInstanceId

local moveAllNodes
local moveFrom
local moveCanvasImg

function BtCreator.show(tree, instanceId)
	if(not btCreatorWindow.visible) then
		btCreatorWindow:Show()
	end
	if(not nodePoolPanel.visible) then
		nodePoolPanel:Show()
	end
	if(not buttonPanel.visible) then
		buttonPanel:Show()
	end
	treeNameEditbox:SetText(tree)
	treeInstanceId = instanceId
	listenerClickOnLoadTree()
end

function BtCreator.showNewTree()
	if(not btCreatorWindow.visible) then
		btCreatorWindow:Show()
	end
	if(not nodePoolPanel.visible) then
		nodePoolPanel:Show()
	end
	if(not buttonPanel.visible) then
		buttonPanel:Show()
	end
	listenerClickOnNewTree()
end

function BtCreator.hide()
	if(rolesWindow and rolesWindow.visible) then
		rolesWindow:Hide()
	end
	if(sensorsWindow and sensorsWindow.visible) then
		sensorsWindow:Hide()
	end
	if(categoryDefinitionWindow and categoryDefinitionWindow.visible) then
		categoryDefinitionWindow:Hide()
	end
	if(blackboardWindowState and blackboardWindowState.visible) then
		blackboardWindowState:Hide()
	end
	if(btCreatorWindow.visible) then
		btCreatorWindow:Hide()
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
	btCreatorWindow:Invalidate()
	btCreatorWindow:RequestUpdate()
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

function listenerEndCopyingNode(_, x , y)
	--y = y + startCopyingLocation.y
	if(copyTreeNode and x - nodePoolPanel.width - startCopyingLocation.x > -20) then
		local params = {
			parent = btCreatorWindow,
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
local inputTypeMap = {
	["Position"] = "BETS_POSITION",
	["Area"]     = "BETS_AREA",
	["UnitID"]   = "BETS_UNIT",
	["BETS_POSITION"] = "Position",
	["BETS_AREA"]			= "Area",
	["BETS_UNIT"]			= "UnitID",
}

local function maxRoleSplit(tree)
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
	return roleCount
end


--- Contains IDs of nodes as keys - stores IDs of serialized tree, the one with name serializedTree
-- To be able to update duplicit IDs on tree save - so the loaded and saved trees ids does not colide.
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

function listenerClickOnSaveTree()
	Logger.log("save-and-load", "Save Tree clicked on. ")
		-- on tree Save() regenerate IDs of nodes already present in loaded tree
	
	local  treeName = treeNameEditbox.text
	
	if(serializedTreeName and serializedTreeName ~= treeName) then
		--regenerate all IDs from loaded Tree
		for id,_ in pairs(serializedIDs) do
			if(WG.nodeList[id]) then
				reGenerateTreenodeID(id)
			end
		end
		updateSerializedIDs()
	end
	local resultTree = formBehaviourTree()
	-- are there enough roles?
	local maxSplit = maxRoleSplit(resultTree)
	local rolesCount = 0
	for _,role in pairs(rolesOfCurrentTree) do
		rolesCount = rolesCount + 1
	end
	if((maxSplit == rolesCount) and (rolesCount > 0) ) then --roles are plausible
		resultTree.roles = rolesOfCurrentTree
		resultTree.defaultRole = rolesOfCurrentTree[1].name
		resultTree.inputs = {}

		local inputs = WG.nodeList[rootID].inputs
		if(inputs ~= nil) then
			for i=1,#inputs do
				if (inputTypeMap[ inputs[i][2].items[ inputs[i][2].selected ] ] == nil) then
					error("Uknown tree input type detected in BtCreator tree serialization. "..debug.traceback())
				end
				table.insert(resultTree.inputs, {["name"] = inputs[i][1].text, ["command"] = inputTypeMap[ inputs[i][2].items[ inputs[i][2].selected ] ],})
			end
		end
		resultTree:Save(treeName)
		WG.clearSelection()
		
		Logger.loggedCall("Errors", "BtCreator", 
			"asking BtController to reload instances of saved tree type",
			WG.BtControllerReloadTreeType,
			treeName)
			
		Logger.loggedCall("Errors", "BtCreator",
			"registering command for new tree",
			WG.BtRegisterCommandForTree,
			treeName)
	else
		-- we need to get user to define roles first:
		showRoleManagementWindow("save")
	end
end

local sensorsWindow
local bgrColor = {0.8,0.5,0.2,0.6}
local focusColor = {0.8,0.5,0.2,0.3}

function listenerClickOnShowSensors()
	showSensorsButton.backgroundColor , bgrColor = bgrColor, showSensorsButton.backgroundColor
	showSensorsButton.focusColor, focusColor = focusColor, showSensorsButton.focusColor
	local sensors = WG.SensorManager.getAvailableSensors()
	local minWidth = 200
	for i=1,#sensors do
		minWidth = math.max(minWidth, showSensorsButton.font:GetTextWidth(sensors[i]) + 60)
	end
	if(sensorsWindow) then
		sensorsWindow:Dispose()
		sensorsWindow = nil
		return
	end
	sensorsWindow = Chili.Window:New{
		parent = Screen0,
		name = "SensorsWindow",
		x = buttonPanel.x + showSensorsButton.x - 10,
		y = buttonPanel.y + showSensorsButton.y - (#sensors*20 + 60) + 5,
		width = minWidth,
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
	rolesOfCurrentTree = {}
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
end

function listenerClickOnMinimize()
	Logger.log("tree-editing", "Minimize BtCreator. ")
	BtCreator.hide()
end

-- //////////////////////////////////////////////////////////////////////
-- Messages from/to BtEvaluator
-- //////////////////////////////////////////////////////////////////////

local DEFAULT_COLOR = {1,1,1,0.6}
local RUNNING_COLOR = {1,0.5,0,0.6}
local SUCCESS_COLOR = {0.5,1,0.5,0.6}
local FAILURE_COLOR = {1,0.25,0.25,0.6}
local STOPPED_COLOR = {0.2,0.6,1,1}
local BREAKPOINT_COLOR = {0,0,1,0.6}

local breakpoints = {}

local function setBackgroundColor(nodeWindow, color)
	local alpha = nodeWindow.backgroundColor[4]
	nodeWindow.backgroundColor = copyTable(color)
	nodeWindow.backgroundColor[4] = alpha
	nodeWindow:Invalidate()
end

local function listenerClickOnBreakpoint()
	for nodeId,_ in pairs(WG.selectedNodes) do
		local color
		if(breakpoints[nodeId] == nil and nodeId ~= rootID) then
			breakpoints[nodeId] = true
			BtEvaluator.setBreakpoint(treeInstanceId, nodeId)
			color = BREAKPOINT_COLOR
		else
			breakpoints[nodeId] = nil
			BtEvaluator.removeBreakpoint(treeInstanceId, nodeId)
			color = DEFAULT_COLOR
		end
		if(nodeId ~= rootID) then
			setBackgroundColor(WG.nodeList[nodeId].nodeWindow, color)
		end
	end
	-- Spring.Echo("Breakpoints: "..dump(breakpoints))
end

local pausedByBtCreator = false
local function listenerClickOnContinue()
	BtEvaluator.tickTree(treeInstanceId)
	if(not pausedByBtCreator)then
		Spring.SendCommands("pause")
	end
end

local function updateStatesMessage(params)
	local states = params.states
	local shouldPause
	for id, node in pairs(WG.nodeList) do
		local color = DEFAULT_COLOR;
		-- set breakpoint color to all breakpoints, independent from current state
		if(breakpoints[id]) then  --and ((states[id] and states[id]:upper() ~= "STOPPED") or states[id]==nil)) then
			 color = BREAKPOINT_COLOR
		end
		if(states[id] ~= nil) then
			if(states[id]:upper() == "RUNNING") then
				color = RUNNING_COLOR
			elseif(states[id]:upper() == "SUCCESS") then
				color = SUCCESS_COLOR
			elseif(states[id]:upper() == "FAILURE") then
				color = FAILURE_COLOR
			elseif(states[id]:upper() == "STOPPED") then
				color = STOPPED_COLOR
				shouldPause = true
			else
				Logger.error("communication", "Uknown state received from AI, for node id: ", id)
			end
		end
		setBackgroundColor(node.nodeWindow, color)
	end
	local children = WG.nodeList[rootID]:GetChildren()
	if(#children > 0) then
		setBackgroundColor(WG.nodeList[rootID].nodeWindow, children[1].nodeWindow.backgroundColor)
	end
	blackboard.showCurrentBlackboard(params.blackboard)
	if(shouldPause) then
		if(not pausedByBtCreator)then
			Spring.SendCommands("pause")
			pausedByBtCreator = true
		end
	else
		pausedByBtCreator = false
	end
end

-- Renames the field 'defaultValue' to 'value' if it present, for all the parameters,
-- also saves parameters, hasConnectionIn, hasConnectionOut into 'nodeDefinitionInfo'.
local function processTreenodeParameters(nodeType, parameters, hasConnectionIn, hasConnectionOut)
	for i=1,#parameters do
		if(parameters[i]["defaultValue"]) then
			parameters[i]["value"] = parameters[i]["defaultValue"]
			parameters[i]["defaultValue"] = nil
		end
	end
	nodeDefinitionInfo[nodeType] = {}
	nodeDefinitionInfo[nodeType]["parameters"] = copyTable(parameters)
	nodeDefinitionInfo[nodeType]["hasConnectionIn"]  = hasConnectionIn
	nodeDefinitionInfo[nodeType]["hasConnectionOut"] = hasConnectionOut
end

local function addNodeIntoNodepool(treenodeParams)
	if(nodePoolPanel:GetChildByName(treenodeParams.name)) then
		local treenode = nodePoolPanel:GetChildByName(treenodeParams.name)
		nodePoolPanel:RemoveChild(treenode)
	end
	table.insert(nodePoolList, Chili.TreeNode:New(treenodeParams))
end

local function populateNodePoolWithTreeNodes(heightSum, nodes)
	table.sort(nodes, function(a, b) return a.name < b.name end)
	for i=1,#nodes do
		if (nodes[i].nodeType ~= "luaCommand") then
			local nodeParams = {
				name = nodes[i].name,
				hasConnectionOut = (nodes[i].children == nil) or (type(nodes[i].children) == "table" and #nodes[i].children ~= 0),
				nodeType = nodes[i].name, -- TODO use name parameter instead of nodeType
				parent = nodePoolPanel,
				y = heightSum,
				tooltip = nodes[i].tooltip or "",
				draggable = false,
				resizable = false,
				connectable = false,
				onMouseDown = { listenerStartCopyingNode },
				onMouseUp = { listenerEndCopyingNode },
				parameters = copyTable(nodes[i]["parameters"]),
			}
			-- Make value field from defaultValue.
			processTreenodeParameters(nodeParams.nodeType, nodeParams.parameters, nodeParams.hasConnectionIn, nodeParams.hasConnectionOut)

			if(nodes[i].defaultHeight) then
				nodeParams.height = math.max(50 + #nodeParams["parameters"]*20, nodes[i].defaultHeight)
			end
			heightSum = heightSum + (nodeParams.height or 60)

			addNodeIntoNodepool(nodeParams)
		end
	end
	return heightSum
end

local function getFileExtension(filename)
  return filename:match("^.+(%..+)$")
end

local function getParameterDefinitionsForLuaCommands()
	local directoryName = LUAUI_DIRNAME .. "Widgets/BtCommandScripts"
	local folderContent = VFS.DirList(directoryName)
	local paramsDefs = {}
	
	local nameList = {}
	
	for _,scriptName in ipairs(folderContent)do
		nameList[#nameList] = scriptName
	end

	for _,scriptName in ipairs(folderContent)do
		if getFileExtension(scriptName) == ".lua" then
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
				error("script-load".. "Script ".. scriptName.. " is missing the getInfo() function or it contains an error: ".. info)
			end
		end
	end
	return paramsDefs
end

local function sortedKeyList(t)
	local keys = {}
	local n = 0
	for k,v in pairs(t) do
	  n = n + 1
	  keys[n] = k
	end
	table.sort(keys)
	return keys
end

local function fillNodePoolWithNodes(nodes)
	nodePoolList = {}
	nodeDefinitionInfo = {}
	local heightSum = 30 -- skip NodePoolLabel
	heightSum = populateNodePoolWithTreeNodes(heightSum, nodes) -- others than lua script commands
	-- load lua commands
	local paramDefs = getParameterDefinitionsForLuaCommands()
	local scriptList = sortedKeyList(paramDefs)
	
	for _, scriptName in ipairs(scriptList) do
		local params = paramDefs[scriptName]
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
			parameters = copyTable(params),
		}
		processTreenodeParameters(nodeParams.nodeType, nodeParams.parameters, nodeParams.hasConnectionIn, nodeParams.hasConnectionOut)
		isScript[scriptName] = true
		nodeParams.width = 110
		nodeParams.height = 50 + #nodeParams.parameters * 20
		heightSum = heightSum + (nodeParams.height or 60)
		addNodeIntoNodepool(nodeParams)
	end

	nodePoolPanel:RequestUpdate()
end

function listenerOnClickOnCanvas()
	WG.clearSelection()
	for _,node in pairs(WG.nodeList) do
		node:UpdateParameterValues()
	end
end

function listenerOnResizeBtCreator(self)
	if(nodePoolPanel) then
		nodePoolPanel:SetPos(self.x - nodePoolPanel.width, self.y, nil, self.height)
	end
	if(buttonPanel) then
		buttonPanel:SetPos(self.x, self.y - 30, self.width)
	end
	if(minimizeButton) then
		minimizeButton:SetPos(self.width - 45)
	end
end

function createRoot()
	return Chili.TreeNode:New{
		parent = btCreatorWindow,
		nodeType = "Root",
		y = btCreatorWindow.height*0.5 - 40,
		x = 5,
		width = 210,
		height = 80,
		draggable = true,
		resizable = true,
		connectable = true,
		hasConnectionIn = false,
		hasConnectionOut = true,
		id = false,
	}
end

function widget:Initialize()
	Logger.log("reloading", "BtCreator widget:Initialize start. ")

	if (not WG.ChiliClone) then
		-- don't run if we can't find Chili
		widgetHandler:RemoveWidget()
		return
	end

	BtEvaluator = sanitizer:Import(WG.BtEvaluator)

	BtEvaluator.OnNodeDefinitions = fillNodePoolWithNodes
	BtEvaluator.OnUpdateStates = updateStatesMessage

	-- Get ready to use Chili
	Chili = WG.ChiliClone
	Screen0 = Chili.Screen0

	connectionLine.initialize()
	blackboard = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCreator/blackboard.lua", nil, VFS.RAW_FIRST)

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


	Logger.log("reloading", "BtCreator widget:Initialize after requestNodeDefinitions. nodeDefinitionInfo: "..dump(nodeDefinitionInfo, 3))

	local maxNodeWidth = 125
	for i=1,#nodePoolList do
		if(nodePoolList[i].width + 21 > maxNodeWidth) then
			maxNodeWidth = nodePoolList[i].width + 21
		end
	end
	nodePoolPanel.width = maxNodeWidth
	nodePoolPanel:RequestUpdate()
	 -- Create the window
	btCreatorWindow = Chili.Window:New{
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
		OnClick = { sanitizer:AsHandler(listenerOnClickOnCanvas) },
		OnResize = { sanitizer:AsHandler(listenerOnResizeBtCreator) },
		-- OnMouseDown = { listenerStartSelectingNodes },
		-- OnMouseUp = { listenerEndSelectingNodes },
		onMouseWheel = {
			function(self, x, y, a)
				Spring.Echo("mouse wheel: "..dump(a))
				return self
			end,
		},
	}

	addNodeToCanvas( createRoot() )

	buttonPanel = Chili.Control:New{
		parent = Screen0,
		x = btCreatorWindow.x,
		y = btCreatorWindow.y - 30,
		width = btCreatorWindow.width,
		height = 40,
		--children = { newTreeButton, saveTreeButton, loadTreeButton, roleManagerButton, showSensorsButton, showBlackboardButton, breakpointButton, continueButton }
	}
	newTreeButton = Chili.Button:New{
		parent = buttonPanel,
		x = 0,
		y = 0,
		width = 90,
		height = 30,
		caption = "New Tree",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { sanitizer:AsHandler(listenerClickOnNewTree) },
	}
	saveTreeButton = Chili.Button:New{
		parent = buttonPanel,
		x = newTreeButton.x + newTreeButton.width,
		y = 0,
		width = 90,
		height = 30,
		caption = "Save Tree",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { sanitizer:AsHandler(listenerClickOnSaveTree) },
	}
	loadTreeButton = Chili.Button:New{
		parent = buttonPanel,
		x = saveTreeButton.x + saveTreeButton.width,
		y = 0,
		width = 90,
		height = 30,
		caption = "Load Tree",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { sanitizer:AsHandler(listenerClickOnLoadTree) },
	}
	roleManagerButton = Chili.Button:New{
		parent = buttonPanel,
		x = loadTreeButton.x + loadTreeButton.width,
		y = 0,
		width = 130,
		height = 30,
		caption = "Role manager",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { sanitizer:AsHandler(listenerClickOnRoleManager) },
	}
	showSensorsButton = Chili.Button:New{
		parent = buttonPanel,
		x = roleManagerButton.x + roleManagerButton.width,
		y = 0,
		width = 90,
		height = 30,
		caption = "Sensors",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { sanitizer:AsHandler(listenerClickOnShowSensors) },
	}
	showBlackboardButton = Chili.Button:New{
		parent = buttonPanel,
		x = showSensorsButton.x + showSensorsButton.width,
		y = 0,
		width = 110,
		height = 30,
		caption = "Blackboard",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { sanitizer:AsHandler(
			function()
				blackboard.setWindowPosition(
					buttonPanel.x + showSensorsButton.x + showSensorsButton.width - 5 - 130,
					buttonPanel.y - (60+10*20) + 5
				)
				blackboard.listenerClickOnShowBlackboard()
			end )
			},
	}
	breakpointButton = Chili.Button:New{
		parent = buttonPanel,
		x = showBlackboardButton.x + showBlackboardButton.width,
		y = 0,
		width = 140,
		height = 30,
		caption = "Toggle Breakpoint",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { sanitizer:AsHandler(listenerClickOnBreakpoint) },
	}
	continueButton = Chili.Button:New{
		parent = buttonPanel,
		x = breakpointButton.x + breakpointButton.width,
		y = 0,
		width = 110,
		height = 30,
		caption = "Continue",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { sanitizer:AsHandler(listenerClickOnContinue) },
	}

	minimizeButton = Chili.Button:New{
		parent = buttonPanel,
		x = btCreatorWindow.width - 45,
		y = loadTreeButton.y,
		width = 35,
		height = 30,
		caption = "_",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { sanitizer:AsHandler(listenerClickOnMinimize) },
	}

	treeNameEditbox = Chili.EditBox:New{
		parent = btCreatorWindow,
		text = "02-flipEcho",
		width = 70,
		x = '40%',
		y = 5,
		align = 'left',
		skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0,0,0,0},
		autosize = true,
	}
	moveCanvasImg = Chili.Image:New{
		parent = btCreatorWindow,
		x = 20,
		y = 7,
		width = 30,
		height = 30,
		file = LUAUI_DIRNAME.."Widgets/BtCreator/move_orange.png",
		onMouseDown = { 
			function(self, x, y)
				moveTimer = os.clock()
				self.file = LUAUI_DIRNAME.."Widgets/BtCreator/move_grey.png"
				moveAllNodes = true
				moveFrom = {x, y}
				self:Invalidate()
				return self
			end,
			},
		onClick = { 
			function(self)
				return self
			end,
			},
		onMouseUp = {
			function(self, x, y)
				self.file = LUAUI_DIRNAME.."Widgets/BtCreator/move_orange.png"
				moveAllNodes = false
				self:Invalidate()
				return self
			end,
			},
		onMouseMove = {
			function(self, x, y)
				if(moveAllNodes) then
					local diffx = - x + moveFrom[1]
					local diffy = - y + moveFrom[2]
					for id,node in pairs(WG.nodeList) do
						node.x = node.x + diffx
						node.y = node.y + diffy
						node.nodeWindow:SetPos(node.x + diffx, node.y + diffy)
					end
					moveFrom = {x, y}
					btCreatorWindow:Invalidate()
				end
			end,
		},
	}	
	
	-- treeNameEditbox.font.size = 16
	listenerClickOnMinimize()

	WG.BtCreator = sanitizer:Export(BtCreator)
	Dependency.fill(Dependency.BtCreator)
	Logger.log("reloading", "BtCreator widget:Initialize end. ")
end

function widget:Shutdown()
	Logger.log("reloading", "BtCreator widget:Shutdown start. ")
	if(btCreatorWindow) then
		btCreatorWindow:Dispose()
	end
	for _,node in pairs(nodePoolList) do
		node:Dispose()
	end
	if(nodePoolPanel) then
		nodePoolPanel:ClearChildren()
		nodePoolPanel:Dispose()
	end
	if(buttonPanel) then
		buttonPanel:Dispose()
	end
	WG.clearSelection()
	clearCanvas()
	Dependency.clear(Dependency.BtCreator)
	Logger.log("reloading", "BtCreator widget:shutdown end. ")
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

function formBehaviourTree()
	-- Validate every treenode - when editing editBox parameter and immediately serialize,
	-- the last edited parameter doesnt have to be updated
	for _,node in pairs(WG.nodeList) do
		node:UpdateParameterValues()
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
		addNodeToCanvas( createRoot() )
	end
end

local function loadBehaviourNode(bt, btNode)
	if(not btNode or btNode.nodeType == "empty_tree")then return nil end
	local params = {}
	local info

	Logger.log("save-and-load", "loadBehaviourNode - nodeType: ", btNode.nodeType, " scriptName: ", btNode.scriptName, " info: ", dump(nodeDefinitionInfo[btNode.nodeType],2))
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
					if(params.parameters[i].name ~= v[i].name)then
						Logger.error("save-and-load", "Parameter names do not match: ", params.parameters[i].name, " != ", v[i].name)
					end

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
	params.parent = btCreatorWindow
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
	-- deserialize tree inputs
	local addButton = WG.nodeList[rootID].addButton
	for i=1,#bt.inputs do
		-- Add inputs and sets them to saved values
		addButton:CallListeners( addButton.OnClick )
		WG.nodeList[rootID].inputs[i][1].text = bt.inputs[i].name
		local inputType = inputTypeMap[ bt.inputs[i]["command"] ]
		local inputComboBox = WG.nodeList[rootID].inputs[i][2]
		for k=1,#inputComboBox.items do
			if(inputComboBox.items[k] == inputType) then
				WG.nodeList[rootID].inputs[i][2]:Select( k )
			end
		end
	end
end

function showCategoryDefinitionWindow()
	rolesWindow:Hide()
	categoryDefinitionWindow = Chili.Window:New{
		parent = Screen0,
		x = 150,
		y = 300,
		width = 1250,
		height = 600,
		skinName = 'DarkGlass'
	}
	local nameEditBox = Chili.EditBox:New{
			parent = categoryDefinitionWindow,
			x = 0,
			y = 0,
			text = "New unit category",
			width = 150
	}
	local categoryDoneButton = Chili.Button:New{
		parent =  categoryDefinitionWindow,
		x = nameEditBox.x + nameEditBox.width,
		y = 0,
		caption = "DONE",
		OnClick = {sanitizer:AsHandler(doneCategoryDefinition)},
	}

	local categoryCancelButton = Chili.Button:New{
		parent =  categoryDefinitionWindow,
		x = categoryDoneButton.x + categoryDoneButton.width,
		y = 0,
		caption = "CANCEL",
		OnClick = {sanitizer:AsHandler(cancelCategoryDefinition)},
	}
	local categoryScrollPanel = Chili.ScrollPanel:New{
		parent = categoryDefinitionWindow,
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
	local unitsD = {}
	for _,unitDef in pairs(UnitDefs) do
		if(unitDef.isFeature == false) then -- exclude walls and roads...
			table.insert(unitsD, unitDef)
		end
	end 
	
	local humanNameOrder  = function (a,b)
		return a.humanName < b.humanName
	end
	table.sort(unitsD, humanNameOrder)
	
	for _,unitDef in ipairs(unitsD) do
		local typeCheckBox = Chili.Checkbox:New{
			parent = categoryScrollPanel,
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
	-- add small placeholder at end:
	local placeholder = Chili.Label:New{
		parent = categoryScrollPanel,
		x = xOffSet,
		y = yOffSet + 50,
		caption = "=== end ===",
		skinName='DarkGlass',
	}
	-- check old checked checkboxes:
	categoryDoneButton.Checkboxes = typesCheckboxes
	categoryDoneButton.CategoryNameEditBox = nameEditBox
	categoryDoneButton.Window = categoryDefinitionWindow
end



function doneCategoryDefinition(self)
	-- add new category to unitCategories
	local unitTypes = {}
	for _,unitTypeCheckBox in pairs(self.Checkboxes) do
		if(unitTypeCheckBox.checked == true) then
			local typeRecord = {id = unitTypeCheckBox.unitId, name = unitTypeCheckBox.unitName, humanName = unitTypeCheckBox.unitHumanName}
			table.insert(unitTypes, typeRecord)
		end
	end
	-- add check for category name?
	local newCategory = {
		name = self.CategoryNameEditBox.text,
		types = unitTypes,
	}
	Utils.UnitCategories.redefineCategories(newCategory)

	categoryDefinitionWindow:Hide()
	showRoleManagementWindow()
end
function cancelCategoryDefinition(self)
	categoryDefinitionWindow:Hide()
	showRoleManagementWindow()
end
--[[
local function findCategoryData(categoryName)
	for _,catData in pairs(unitCategories) do
		if(catData.name == categoryName) then
			return catData
		end
	end
end
--]]

function doneRoleManagerWindow(self)
	self.Window:Hide()
	local result = {}
	for _,roleRecord in pairs(self.RolesData) do
		local roleName = roleRecord.NameEditBox.text
		local checkedCategories = {}
		for _, categoryCB in pairs(roleRecord.CheckBoxes) do
			if(categoryCB.checked) then
				local catName = categoryCB.caption
				table.insert(checkedCategories, catName)
			end
		end
		local roleResult = {name = roleName, categories = checkedCategories}
		table.insert(result, roleResult)
	end
	rolesOfCurrentTree = result

	if((self.Mode ~= nil)  and (self.Mode == "save")) then
		listenerClickOnSaveTree()
	end
end
-- This shows the role manager window, mode is used to determine if tree should be saved on clicking "done"
function showRoleManagementWindow(mode)
	local tree = formBehaviourTree()
	-- find out how many roles we need:
	local roleCount = maxRoleSplit(tree)
	--[[local function visit(node)
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
	--]]

	--[[ RESET UNIT CATHEGORIES
	loadStandardCategories()
	saveUnitCategories()
	--]]

	--unitCategories = BtUtils.UnitCategories.getCategories()


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
		OnClick = {sanitizer:AsHandler(doneRoleManagerWindow)},
	}
	roleManagementDoneButton.Mode = mode

	newCategoryButton = Chili.Button:New{
		parent = rolesWindow,
		x = 150,
		y = 0,
		width = 150,
		caption = "Define new Category",
		OnClick = {sanitizer:AsHandler(showCategoryDefinitionWindow)},
	}


	local rolesScrollPanel = Chili.ScrollPanel:New{
		parent = rolesWindow,
		x = 0,
		y = 30,
		width  = '100%',
		height = '100%',
		skinName='DarkGlass'
	}
	local rolesCategoriesCB = {}
	local xOffSet = 10
	local yOffSet = 10
	local xCheckBoxOffSet = 180
	-- set up checkboxes for all roles and categories

	for roleIndex=0, roleCount -1 do
		local nameEditBox = Chili.EditBox:New{
			parent = rolesScrollPanel,
			x = xOffSet,
			y = yOffSet,
			text = "Role ".. tostring(roleIndex),
			width = 150
		}
		local checkedCategories = {}
		if(rolesOfCurrentTree[roleIndex+1]) then
			nameEditBox:SetText(rolesOfCurrentTree[roleIndex+1].name)
			for _,catName in pairs(rolesOfCurrentTree[roleIndex+1].categories) do
				checkedCategories[catName] = 1
			end
		end

		local categoryNames = Utils.UnitCategories.getAllCategoryNames()
		local categoryCheckBoxes = {}
		local xLocalOffSet = 0
		for _,categoryName in pairs(categoryNames) do
			local categoryCheckBox = Chili.Checkbox:New{
				parent = rolesScrollPanel,
				x = xOffSet + xCheckBoxOffSet + (xLocalOffSet * 250),
				y = yOffSet,
				caption = categoryName,
				checked = false,
				width = 200,
			}
			if(checkedCategories[categoryName] ~= nil) then
				categoryCheckBox:Toggle()
			end
			xLocalOffSet = xLocalOffSet + 1
			if(xLocalOffSet == 4) then
				xLocalOffSet = 0
				yOffSet = yOffSet + 20
			end

			table.insert(categoryCheckBoxes, categoryCheckBox)
		end


		yOffSet = yOffSet + 50
		local roleCategories = {}
		roleCategories["NameEditBox"] = nameEditBox
		roleCategories["CheckBoxes"] = categoryCheckBoxes
		table.insert(rolesCategoriesCB,roleCategories)
	end
	roleManagementDoneButton.RolesData = rolesCategoriesCB
	roleManagementDoneButton.Window = rolesWindow
end

--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------

sanitizer:SanitizeWidget()
return Dependency.deferWidget(widget, Dependency.BtEvaluator)