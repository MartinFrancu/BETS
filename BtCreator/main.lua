local Chili, Screen0

local BtEvaluator

local rootPanel
local btCreatorWindow
local nodePoolLabel
local nodePoolPanel
local buttonPanel
local loadTreeButton
local saveTreeButton
local saveAsTreeButton
local showSensorsButton
local showBlackboardButton
local breakpointButton
local continueButton
local minimizeButton
local roleManagerButton
local newTreeButton
local showBtCheatButton

local saveTreeOncePossible

local treeNameLabel
local noNameString = "--NO NAME GIVEN--"

local rolesOfCurrentTree = {}

local roleManager = require("role_manager") -- make sure to have sanitizer and Utils there

local btCheat = require("cheat") -- make sure to have sanitizer and Utils there

--- Keys are node IDs, values are Treenode objects.
WG.nodeList = {}
local nodePoolList = {}
--- Key into the nodeList.
local rootID = nil

-- local JSON = Utils.JSON
local BehaviourTree = Utils.BehaviourTree
local Dependency = Utils.Dependency
local sanitizer = Utils.Sanitizer.forWidget(widget)

local Debug = Utils.Debug;
local ProjectManager = Utils.ProjectManager
local ProjectDialog = Utils.ProjectDialog
local Logger, dump, copyTable, fileTable = Debug.Logger, Debug.dump, Debug.copyTable, Debug.fileTable

local nodeDefinitionInfo = {}
local isScript = {}

-- BtEvaluator interface definitions
local BtCreator = {} -- if we need events, change to Sentry:New()

-- connection lines functions
local connectionLine = require("connection_line")
-- blackboard window
local blackboard = require("blackboard")


local treeInstanceId
--- When opening tree through reference node, the id of the reference node is stored here.
--- Needs to be nilled on any other type of tree loading. 
local referenceNodeID

local moveAllNodes
local moveFrom

local moveWindow
local moveWindowFrom
local moveWindowFromMouse
local moveCanvasImg

local rootDefaultX = 5
local rootDefaultY = 60

function BtCreator.show()
	if(not rootPanel.visible) then
		rootPanel:Show()
	end
end

function BtCreator.showTree(tree, instanceId)
	BtCreator.show()
	loadTree(tree)
	treeInstanceId = instanceId
end


function BtCreator.showReferencedTree(treeName, _referenceNodeID)
	-- loadTree() nillates the referenceNodeID so set it after loadTree() call
	loadTree(treeName)
	referenceNodeID = _referenceNodeID
end

function BtCreator.showNewTree()
	if(not rootPanel.visible) then
		rootPanel:Show()
	end
	listenerClickOnNewTree()
end

function BtCreator.setDisableChildrenHitTest(bool)
	rootPanel.disableChildrenHitTest = bool
end

function BtCreator.hide()
	if(sensorsWindow and sensorsWindow.visible) then
		sensorsWindow:Hide()
	end
	if(blackboardWindowState and blackboardWindowState.visible) then
		blackboardWindowState:Hide()
	end
	if(rootPanel.visible) then
		rootPanel:Hide()
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

--- x,y are the coordinates of top left corner where to place the node
function placeTreeNodeOnCanvas(nodeType, x, y)
	if btCreatorWindow.zoomedOut then
		Spring.Echo("Please zoom out to place new nodes. ")
		return
	end
	local newNode
	for i=1,#nodePoolList do
		if(nodeType == nodePoolList[i].nodeType) then
			newNode = nodePoolList[i]
			break
		end
	end
	if(not newNode) then
		Logger.error("A kurva..")
	end
	local halfwidth = 0.5*(nodePoolPanel.font:GetTextWidth(nodeType)+20+20)
	local params = {
		parent = btCreatorWindow,
		nodeType = nodeType,
		x = x-halfwidth,
		y = y-10,
		width = newNode.width,
		height = newNode.height,
		tooltip = newNode.tooltip,
		isReferenceNode = newNode.isReferenceNode,
		connectable = true,
		draggable = true,
		hasConnectionIn = true,
		hasConnectionOut = nodeDefinitionInfo[nodeType].hasConnectionOut,
		parameters = copyTable(nodeDefinitionInfo[nodeType].parameters)
	}
	if(newNode.icon) then
		params.iconPath = newNode.icon.file
	end
	addNodeToCanvas(Chili.TreeNode:New(params))
end

-- //////////////////////////////////////////////////////////////////////
-- Listeners
-- //////////////////////////////////////////////////////////////////////

local clearCanvas, loadBehaviourTree, formBehaviourTree
local inputTypeMap = {
	["Position"] = "BETS_POSITION",
	["Area"]     = "BETS_AREA",
	["UnitID"]   = "BETS_UNIT",
	["BETS_POSITION"] = "Position",
	["BETS_AREA"]			= "Area",
	["BETS_UNIT"]			= "UnitID",
	["Variable"] = "Variable",
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

local afterRoleManagement

-- does not check if tree makes sense
local function saveTree(treeName)
	local zoomedOut = btCreatorWindow.zoomedOut
	local w = btCreatorWindow.width
	local h = btCreatorWindow.height
	if zoomedOut then
		zoomCanvasIn(btCreatorWindow, w/2, h/2)
	end
	local protoTree = formBehaviourTree()
	
	if(serializedTreeName and serializedTreeName ~= treeName) then
		--regenerate all IDs from loaded Tree
		for id,_ in pairs(serializedIDs) do
			if(WG.nodeList[id]) then
				reGenerateTreenodeID(id)
			end
		end
		updateSerializedIDs()
	end
	protoTree.roles = rolesOfCurrentTree
	protoTree.inputs = {}
	protoTree.outputs = {}
	local r = WG.nodeList[rootID]
	protoTree.additionalParameters = { root = { width = r.width, height = r.height } }

	local inputs = WG.nodeList[rootID].inputs
	if(inputs ~= nil) then
		for i=1,#inputs do
			if (inputTypeMap[ inputs[i].comboBox.items[ inputs[i].comboBox.selected ] ] == nil) then
				error("Uknown tree input type detected in BtCreator tree serialization. "..debug.traceback())
			end
			table.insert(protoTree.inputs, {["name"] = inputs[i].editBox.text, ["command"] = inputTypeMap[ inputs[i].comboBox.items[ inputs[i].comboBox.selected ] ],})
		end
	end
	local outputs = WG.nodeList[rootID].outputs
	if(outputs ~= nil) then
		for i=1,#outputs do
			table.insert(protoTree.outputs, {["name"] = outputs[i].editBox.text,})
		end
	end
	Logger.assert("save-and-load", protoTree:Save(treeName))
	WG.clearSelection()
	
	Logger.loggedCall("Errors", "BtCreator", 
		"asking BtController to reload instances of saved tree type",
		WG.BtControllerReloadTreeType,
		treeName)
		
	Logger.loggedCall("Errors", "BtCreator",
		"registering command for new tree",
		WG.BtRegisterCommandForTree,
		treeName)
		
	if zoomedOut then
		zoomCanvasOut(btCreatorWindow, w/2, h/2)
	end
end 

function saveAsTreeDialogCallback(project, tree)
	if project and tree then 
		-- we have treetree name
		-- now we need to check if roles are plausible:
		
		local resultTree = formBehaviourTree()
		-- are there enough roles?
		local maxSplit = maxRoleSplit(resultTree)
		local rolesCount = 0
		for _,role in pairs(rolesOfCurrentTree) do
			rolesCount = rolesCount + 1
		end
		local qualifiedName = project .. "." .. tree
		treeNameLabel:SetCaption(qualifiedName)
		if((maxSplit == rolesCount) and (rolesCount > 0) ) then --roles are plausible:
			-- if new project I should create it  
			if(not ProjectManager.isProject(project))then
				ProjectManager.createProject(project)
			end
			saveTree(qualifiedName)	
		else
			-- we need to get user to define roles first:
			saveTreeOncePossible = true
			roleManager.showRolesManagement(Screen0, resultTree, rolesOfCurrentTree, self, afterRoleManagement)
		end
			
	end
end

function listenerClickOnSaveTree()
	local qualifiedName = treeNameLabel.caption
	local length = string.len(qualifiedName)
	local position = string.find(qualifiedName, '%.')
	if(position or position == length or position == 1) then
		local project = string.sub(qualifiedName, 1, position-1)
		local name = string.sub(qualifiedName, position+1,length )
		saveAsTreeDialogCallback(project, name)
	else
		listenerClickOnSaveAsTree()
	end
end

-- local function onModalDialog(show)
	-- rootPanel.disableChildrenHitTest = show
-- end

local function onHidingDialog(show)
	if show then
		BtCreator.hide()
	else
		BtCreator.show()
	end
end

function listenerClickOnSaveAsTree()
	local treeContentType = Utils.ProjectManager.makeRegularContentType("Behaviours", "json")
	ProjectDialog.showDialogWindow(BtCreator.setDisableChildrenHitTest, treeContentType, 
		ProjectDialog.SAVE_DIALOG_FLAG, saveAsTreeDialogCallback, "Save tree as:")
end

afterRoleManagement = function (self, rolesData)
	rolesOfCurrentTree = rolesData
	if(saveTreeOncePossible) then
		listenerClickOnSaveTree()
		saveTreeOncePossible = false 
	end
end


local sensorsWindow
local bgrColor = {0.8,0.5,0.2,0.6}
local focusColor = {0.8,0.5,0.2,0.3}

function listenerClickOnShowSensors()
	showSensorsButton.backgroundColor , bgrColor = bgrColor, showSensorsButton.backgroundColor
	showSensorsButton.focusColor, focusColor = focusColor, showSensorsButton.focusColor
	local sensors = BtEvaluator.SensorManager.getAvailableSensors()
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
		y = rootPanel.y + buttonPanel.y + showSensorsButton.y - (#sensors*20 + 60) + 5,
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

function newTreeDialogCallback(projectName,treeName)
	BtCreator.show()
	if(projectName and treeName) then -- user selected 
		treeNameLabel:SetCaption(projectName .. "." .. treeName)
		rolesOfCurrentTree = {}
		clearCanvas()
	end
end

function listenerClickOnNewTree()
	local treeContentType = Utils.ProjectManager.makeRegularContentType("Behaviours", "json")
	ProjectDialog.showDialogWindow(onHidingDialog, treeContentType, 
			ProjectDialog.NEW_DIALOG_FLAG, newTreeDialogCallback, "Name the new tree:")	
end

local serializedTreeName

function getBehaviourTree(treeName)
	local bt = BehaviourTree.load(treeName)
	if(bt)then
		clearCanvas()
		loadBehaviourTree(bt)
		rolesOfCurrentTree = bt.roles or {}
	else
		error("BehaviourTree " .. treeName .. " instance not found. " .. debug.traceback())
	end
end 

function loadTree(treeName)
	referenceNodeID = ""
	getBehaviourTree(treeName)
	treeNameLabel:SetCaption(treeName)
end

function loadTreeDialogCallback(project, tree)
	BtCreator.show()
	if project and tree then -- tree was selected
		local qualifiedName = project .. "." .. tree
		loadTree(qualifiedName)
	end
end

function listenerClickOnLoadTree(self)
	local treeContentType = Utils.ProjectManager.makeRegularContentType("Behaviours", "json")
	ProjectDialog.showDialogWindow(onHidingDialog, treeContentType, ProjectDialog.LOAD_DIALOG_FLAG, 
		loadTreeDialogCallback, "Select tree to be loaded:")
end

function listenerClickOnRoleManager(self)
	local currentTree = formBehaviourTree()
	self.hideFunction()
	roleManager.showRolesManagement(Screen0, currentTree, rolesOfCurrentTree, self, afterRoleManagement)
end

function listenerClickOnCheat(self)
	if(self.showing)then
		btCheat.hide()
	else
		btCheat.show()
	end
	self.showing = not self.showing
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

--- Called after every tick from BtEvaluator, it changes node background/border colors according to the
--- node states. When referenced tree is opened, it has ids in the form 
--- [referenceNodeID]-[internalNodeIDs].
local function updateStatesMessage(params)
	local states = params.states
	local shouldPause
	for id, node in pairs(WG.nodeList) do
		local color = DEFAULT_COLOR;
		if(referenceNodeID ~= '') then
			id = referenceNodeID..'-'..id
		end
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
				Logger.error("communication", "Unknown state received from AI, for node id: ", id)
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
local function processTreenodeParameters(nodeType, parameters, hasConnectionIn, hasConnectionOut, tooltip, iconPath, isReferenceNode)
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
	nodeDefinitionInfo[nodeType]["tooltip"] = tooltip or ""
	nodeDefinitionInfo[nodeType].iconPath = iconPath
	nodeDefinitionInfo[nodeType].isReferenceNode = isReferenceNode
end

local function addNodeIntoNodepool(treenodeParams)
	-- if(nodePoolPanel:GetChildByName(treenodeParams.name)) then
		-- local treenode = nodePoolPanel:GetChildByName(treenodeParams.name)
		-- nodePoolPanel:RemoveChild(treenode)
	-- end
	table.insert(nodePoolList, Chili.TreeNode:New(treenodeParams))
end

local function populateNodePoolWithTreeNodes(heightSum, nodes)
	table.sort(nodes, function(a, b) return a.name < b.name end)
	for i=1,#nodes do
		if (nodes[i].nodeType ~= "luaCommand") then
			Logger.log("icons", LUAUI_DIRNAME .. "Widgets/BtTreenodeIcons/"..nodes[i].name..".png____", "nodeType: ",nodes[i].nodeType)
			local nodeParams = {
				name = nodes[i].name,
				hasConnectionOut = (nodes[i].children == nil) or (type(nodes[i].children) == "table" and #nodes[i].children ~= 0),
				nodeType = nodes[i].name, -- TODO use name parameter instead of nodeType
				-- parent = nodePoolPanel,
				y = heightSum,
				iconPath = LUAUI_DIRNAME .. "Widgets/BtTreenodeIcons/"..nodes[i].name..".png",
				tooltip = nodes[i].tooltip or "",
				draggable = false,
				resizable = false,
				connectable = false,
				parameters = copyTable(nodes[i]["parameters"]),
				isReferenceNode = nodes[i].isReferenceNode
			}
			-- Make value field from defaultValue.
			processTreenodeParameters(nodeParams.nodeType, nodeParams.parameters, nodeParams.hasConnectionIn, nodeParams.hasConnectionOut, nodeParams.tooltip, nodeParams.iconPath, nodeParams.isReferenceNode)

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

local function getAvailableCommandScriptsIcons()
	local commandList = ProjectManager.listAll(ProjectManager.makeRegularContentType("Commands", "png"))
	local iconList = {}
	for _,data in ipairs(commandList)do
		iconList[data.qualifiedName] = data.path
	end
	return iconList
end

local function fillNodeListWithNodes(nodes)
	nodePoolList = {}
	nodeDefinitionInfo = {}
	local heightSum = 30 -- skip NodePoolLabel
	heightSum = populateNodePoolWithTreeNodes(heightSum, nodes) -- others than lua script commands
	-- load lua commands
	local paramDefs, tooltips = BtEvaluator.CommandManager.getAvailableCommandScripts()
	local scriptIcons = getAvailableCommandScriptsIcons()
	local scriptList = sortedKeyList(paramDefs)
	for _, scriptName in ipairs(scriptList) do
		local params = paramDefs[scriptName]
		local nodeParams = {
			name = scriptName,
			hasConnectionOut = false,
			nodeType = scriptName,
			-- parent = nodePoolPanel,
			y = heightSum,
			iconPath = scriptIcons[scriptName],
			tooltip = tooltips[scriptName],
			draggable = false,
			resizable = false,
			connectable = false,
			parameters = copyTable(params),
		}
		processTreenodeParameters(nodeParams.nodeType, nodeParams.parameters, nodeParams.hasConnectionIn, nodeParams.hasConnectionOut, nodeParams.tooltip, nodeParams.iconPath, nodeParams.isReferenceNode)
		isScript[scriptName] = true
		nodeParams.width = 110
		nodeParams.height = 50 + #nodeParams.parameters * 20
		heightSum = heightSum + (nodeParams.height or 60)
		addNodeIntoNodepool(nodeParams)
	end
end

local LEFT_BUTTON = 1
local RIGHT_BUTTON = 3

function listenerOnMouseDownCanvas(self, x, y, button)
	if button == RIGHT_BUTTON then
		moveTimer = os.clock()
		moveAllNodes = true
		moveFrom = {x, y}
		return self
	elseif button == LEFT_BUTTON then
		local child = self:HitTest(x, y)
		if child and (child.name == btCreatorWindow.name or child.classname == 'TreeNode') then 
			WG.clearSelection()
			for _,node in pairs(WG.nodeList) do
				node:UpdateParameterValues()
			end
		end
	end
end

function listenerOnMouseUpCanvas(self, x, y, button)
	if button == RIGHT_BUTTON then
		moveAllNodes = false
		return self
	end
end

function moveCanvas(diffx, diffy)
	for id,node in pairs(WG.nodeList) do
		node.x = node.x + diffx
		node.y = node.y + diffy
		node.nodeWindow:SetPos(node.nodeWindow.x + diffx, node.nodeWindow.y + diffy)
	end
	btCreatorWindow:Invalidate()
end

function listenerOnMouseMoveCanvas(self, x, y)
	if(moveAllNodes) then
		local diffx = x - moveFrom[1]
		local diffy = y - moveFrom[2]
		moveCanvas(diffx, diffy)
		moveFrom = {x, y}
	end
	return self
end


function listenerOnResizeBtCreator(self)
	if(nodePoolPanel) then
		nodePoolPanel:SetPos(self.x - nodePoolPanel.width, self.y, nil, self.height - 10)
	end
	if(buttonPanel) then
		buttonPanel:SetPos(self.x, self.y - 30, self.width)
	end
	if(minimizeButton) then
		minimizeButton:SetPos(self.width - 45)
	end
	if btCreatorWindow then
		rootPanel:Resize(btCreatorWindow.x + btCreatorWindow.width, btCreatorWindow.y + btCreatorWindow.height)
	end
end

local scale = 2

function zoomCanvasIn(self, x, y)
	self.zoomedOut = false
	for _,node in pairs(WG.nodeList) do
		local nodeWindow = node.nodeWindow
		local nodeName = node.nameEditBox
		local icon = node.icon
			node:ShowChildren()
		nodeWindow.font.size = nodeWindow.font.size * scale
		nodeName.font.size = nodeName.font.size * scale
		local nameX = 15
		if(icon) then
			nameX = nameX + 20
			icon:SetPos(icon.x + 3,icon.y + 3,icon.width * scale,icon.height * scale)
		end
		nodeName:SetPos(nameX,6)
		nodeWindow.minWidth = nodeWindow.minWidth * scale
		nodeWindow.minHeight = nodeWindow.minHeight * scale
		local translatedX = x + (nodeWindow.x - x)*scale
		local translatedY = y + (nodeWindow.y - y)*scale
		nodeWindow:SetPos(translatedX, translatedY, nodeWindow.width*scale, nodeWindow.height*scale)
		node.width = nodeWindow.width*scale
		node.height = nodeWindow.height*scale
		node.x = translatedX
		node.y = translatedY
		nodeWindow.resizable = true
		nodeWindow:Invalidate()
		nodeWindow:CallListeners( nodeWindow.OnResize )
	end
end

function zoomCanvasOut(self, x, y)
	self.zoomedOut = true
	for _,node in pairs(WG.nodeList) do
		local nodeWindow = node.nodeWindow
		local nodeName = node.nameEditBox
		local icon = node.icon
			node:HideChildren()
		nodeWindow.font.size = nodeWindow.font.size / scale
		nodeName.font.size = nodeName.font.size / scale
		local nameX = 10
		if(icon) then
			nameX = nameX + 10
			icon:SetPos(icon.x - 3,icon.y - 3,icon.width / scale,icon.height / scale)
		end
		nodeName:SetPos(nameX,-1)
		nodeWindow.minWidth = nodeWindow.minWidth / scale
		nodeWindow.minHeight = nodeWindow.minHeight / scale
		local translatedX = x + (nodeWindow.x - x)/scale
		local translatedY = y + (nodeWindow.y - y)/scale
		nodeWindow:SetPos(translatedX, translatedY, nodeWindow.width/scale, nodeWindow.height/scale)
		node.width = nodeWindow.width*scale
		node.height = nodeWindow.height*scale
		node.x = translatedX
		node.y = translatedY
		nodeWindow.resizable = false
		nodeWindow:Invalidate()
		nodeWindow:CallListeners( nodeWindow.OnResize )
	end
end

function listenerMouseWheelScroll(self, x, y, zoomIn)
	if(zoomIn and self.zoomedOut) then
		zoomCanvasIn(self, x, y)
	elseif(not zoomIn and not self.zoomedOut) then
		zoomCanvasOut(self, x, y)
	end
	return self
end

		
function createRoot(center)
	local rootX, rootY = 0, 0
	if center then
		rootX = 5
		rootY = btCreatorWindow.height / 2 - 40
	end
	
	return Chili.TreeNode:New{
		parent = btCreatorWindow,
		nodeType = "Root",
		y = rootY,
		x = rootX,
		width = 180,
		height = 80,
		draggable = true,
		resizable = true,
		connectable = true,
		hasConnectionIn = false,
		hasConnectionOut = true,
		id = false,
		tooltip = "Root node of the tree. Can have only one child node. ",
	}
end

function widget:IsAbove(x,y)
	y = Screen0.height - y
	if (btCreatorWindow.visible and
			x > rootPanel.x and x < rootPanel.x + rootPanel.width and 
			y > rootPanel.y and y < rootPanel.y + rootPanel.height) then
			return true
	end
	return false
end

function widget:GetTooltip(x, y)
	local component = Screen0:HitTest(x, Screen0.height - y)
	if (component and component.classname ~= 'TreeNode') then
		--Spring.Echo("component: "..dump(component.name))
		return component.tooltip
	end
end

function widget:Initialize()
	Logger.log("reloading", "BtCreator widget:Initialize start. ")

	if (not WG.ChiliClone) then
		-- don't run if we can't find Chili
		widgetHandler:RemoveWidget()
		return
	end
	
	-- Get ready to use Chili
	Chili = WG.ChiliClone
	Screen0 = Chili.Screen0
	rootPanel = Chili.Control:New{
		parent = Screen0,
		y = '56%',
		x = 0,
		width  = Screen0.width,
		height = '41.5%',
	}

	BtEvaluator = sanitizer:Import(WG.BtEvaluator)

	BtEvaluator.OnNodeDefinitions = fillNodeListWithNodes
	BtEvaluator.OnUpdateStates = updateStatesMessage

	loadSensorAutocompleteTable()
	

	connectionLine.initialize()

	BtEvaluator.requestNodeDefinitions()
	nodePoolPanel = Chili.ScrollPanel:New{
		parent = rootPanel,
		y = 30,
		x = 25,
		width  = 125,
		minWidth = 115,
		height = '41.5%',
		borderColor = {0.3,0.3,0.3,1},
		borderColor2 = {0.3,0.3,0.3,1},
		backgroundColor = {0,0,0,1},
		skinName='Robocracy',
		tooltip = "The Node Pool \nDrag&drop individual nodes from Node Pool onto Canvas and start creating a behaviour. ",
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
	Logger.log("reloading", "BtCreator widget:Initialize after requestNodeDefinitions. nodeDefinitionInfo: "..dump(nodeDefinitionInfo, 3))

	local maxNodeWidth = 110
	for i=1,#nodePoolList do
		maxNodeWidth = math.max(maxNodeWidth, nodePoolPanel.font:GetTextWidth(nodePoolList[i].nodeType) + 20 + 30)
	end
	nodePoolPanel:SetPos(nil,nil,maxNodeWidth,nil,true)
	
	 -- Create the window
	btCreatorWindow = Chili.Window:New{
		parent = rootPanel,
		x = nodePoolPanel.width + 22,
		y = 30,
		width  = Screen0.width - nodePoolPanel.width - 25,
		height = rootPanel.height - 30,
		padding = {10,10,10,10},
		draggable=false,
		resizable=true,
		skinName='DarkGlass',
		backgroundColor = {0.1,0.1,0.1,1},
		zoomedOut = false,
		OnResize = { sanitizer:AsHandler(listenerOnResizeBtCreator) },
		OnMouseWheel = { sanitizer:AsHandler(listenerMouseWheelScroll) },
		OnMouseDown = { sanitizer:AsHandler(listenerOnMouseDownCanvas) },
		OnMouseUp = { sanitizer:AsHandler(listenerOnMouseUpCanvas) },
		OnMouseMove = { sanitizer:AsHandler(listenerOnMouseMoveCanvas) },
	}
	local nodePoolItem = require("nodePoolItem")
	nodePoolItem.initialize(btCreatorWindow, placeTreeNodeOnCanvas)
	for i,treenode in pairs(nodePoolList) do
		nodePoolItem.new(treenode, nodePoolPanel)
	end

	addNodeToCanvas(createRoot(true))

	buttonPanel = Chili.Control:New{
		parent = rootPanel,
		x = btCreatorWindow.x,
		y = 0,
		width = btCreatorWindow.width,
		height = 40,
	}
	newTreeButton = Chili.Button:New{
		parent = buttonPanel,
		x = 0,
		y = 0,
		width = 90,
		height = 30,
		caption = "New",
		skinName = "DarkGlass",
		focusColor = {1.0,0.5,0.0,0.5},
		OnClick = { sanitizer:AsHandler(listenerClickOnNewTree) },
	}
	saveTreeButton = Chili.Button:New{
		parent = buttonPanel,
		x = newTreeButton.x + newTreeButton.width,
		y = 0,
		width = 90,
		height = 30,
		caption = "Save",
		skinName = "DarkGlass",
		focusColor = {1.0,0.5,0.0,0.5},
		OnClick = { sanitizer:AsHandler(listenerClickOnSaveTree) },
	}
	
	saveAsTreeButton = Chili.Button:New{
		parent = buttonPanel,
		x = saveTreeButton.x + saveTreeButton.width,
		y = 0,
		width = 100,
		height = 30,
		caption = "Save as",
		skinName = "DarkGlass",
		focusColor = {1.0,0.5,0.0,0.5},
		OnClick = { sanitizer:AsHandler(listenerClickOnSaveAsTree) },
	}
	
	
	loadTreeButton = Chili.Button:New{
		parent = buttonPanel,
		x = saveAsTreeButton.x + saveAsTreeButton.width,
		y = 0,
		width = 90,
		height = 30,
		caption = "Load",
		skinName = "DarkGlass",
		focusColor = {1.0,0.5,0.0,0.5},
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
		focusColor = {1.0,0.5,0.0,0.5},
		OnClick = { sanitizer:AsHandler(listenerClickOnRoleManager) },
	}
	roleManagerButton.hideFunction = BtCreator.hide
	
	showSensorsButton = Chili.Button:New{
		parent = buttonPanel,
		x = roleManagerButton.x + roleManagerButton.width,
		y = 0,
		width = 90,
		height = 30,
		caption = "Sensors",
		skinName = "DarkGlass",
		focusColor = {1.0,0.5,0.0,0.5},
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
		focusColor = {1.0,0.5,0.0,0.5},
		OnClick = { sanitizer:AsHandler(
			function()
				blackboard.setWindowPosition(
					buttonPanel.x + showSensorsButton.x + showSensorsButton.width - 5 - 130,
					rootPanel.y - (60+10*20) + 5
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
		focusColor = {1.0,0.5,0.0,0.5},
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
		focusColor = {1.0,0.5,0.0,0.5},
		OnClick = { sanitizer:AsHandler(listenerClickOnContinue) },
	}

	showBtCheatButton = Chili.Button:New{
		parent = buttonPanel,
		x = continueButton.x + continueButton.width,
		y = 0,
		width = 110,
		height = 30,
		caption = "Cheat",
		skinName = "DarkGlass",
		focusColor = {1.0,0.5,0.0,0.5},
		OnClick = { sanitizer:AsHandler(listenerClickOnCheat) },
	}
	showBtCheatButton.showing = false
	
	minimizeButton = Chili.Button:New{
		parent = buttonPanel,
		x = btCreatorWindow.width - 45,
		y = loadTreeButton.y,
		width = 35,
		height = 30,
		caption = "_",
		skinName = "DarkGlass",
		focusColor = {1.0,0.5,0.0,0.5},
		OnClick = { sanitizer:AsHandler(listenerClickOnMinimize) },
	}

	treeNameLabel = Chili.Label:New{
		parent = btCreatorWindow,
		caption = noNameString,
		width = 70,
		x = '40%',
		y = 5,
		align = 'left',
		-- skinName = 'DarkGlass',
		borderColor = {1,1,1,0.2},
		borderColor2 = {1,1,1,0.2},
		borderThickness = 0,
		backgroundColor = {0,0,0,0},
		minWidth = 120,
		autosize = true,
		tooltip = "The name of current behavior tree. ",
	}
	treeNameLabel.font.size = 16
	treeNameLabel:RequestUpdate()
	
	moveCanvasImg = Chili.Image:New{
		parent = btCreatorWindow,
		x = 20,
		y = 7,
		width = 30,
		height = 30,
		file = PATH .. "move_orange.png",
		tooltip = "When dragged around it moves with whole BtCreator windows. ",
		onMouseDown = { sanitizer:AsHandler(
			function(self, x, y)
				self.file = PATH .. "move_grey.png"
				moveWindow = true
				moveWindowFrom = {btCreatorWindow.x, btCreatorWindow.y}
				moveWindowFromMouse = {x, y}
				self:Invalidate()
				return self
			end),
			},
		onClick = { sanitizer:AsHandler(
			function(self)
				return self
			end),
			},
		onMouseUp = { sanitizer:AsHandler(
			function(self, x, y)
				self.file = PATH .. "move_orange.png"
				moveWindow = false
				self:Invalidate()
				return self
			end),
			},
		onMouseMove = { sanitizer:AsHandler(
			function(self, x, y)
				if(moveWindow) then
					local diffx = x - moveWindowFromMouse[1]
					local diffy = y - moveWindowFromMouse[2]
					rootPanel:SetPos(rootPanel.x + diffx, rootPanel.y + diffy)
					rootPanel:Invalidate()
				end
			end),
		},
	}	
	
	
	-- treeNameLabel.font.size = 16
	listenerClickOnMinimize()
	WG.BtCreator = sanitizer:Export(BtCreator)
	
	local newEntries = {}
	newEntries["Chili"] = Chili
	newEntries["sanitizer"] = sanitizer
	newEntries["Utils"] = Utils
	local environment = setmetatable(newEntries ,{__index = widget})
	
	btCheat.init()
	
	Dependency.fill(Dependency.BtCreator)
	Logger.log("reloading", "BtCreator widget:Initialize end. ")
end

function widget:Shutdown()
	Logger.log("reloading", "BtCreator widget:Shutdown start. ")
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
	if(WG.clearSelection) then
		WG.clearSelection()
	end
	clearCanvas()
	if(btCreatorWindow) then
		btCreatorWindow:Dispose()
	end
	if rootPanel then
		rootPanel:Dispose()
	end
	Dependency.clear(Dependency.BtCreator)
	Logger.log("reloading", "BtCreator widget:shutdown end. ")
end

function widget:GameFrame()
	btCheat.onFrame()
end

function widget:GamePaused()
	btCheat.gamePaused()
end

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	local result = btCheat.commandNotify(cmdID,cmdParams)
	return result
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
	'title',
	'x',
	'y',
	'width',
	'height',
	'parameters',
	'referenceInputs',
	'referenceOutputs',
}

function formBehaviourTree()
	-- Validate every treenode - when editing editBox parameter and immediately serialize,
	-- the last edited parameter doesnt have to be updated
	for _,node in pairs(WG.nodeList) do
		node:UpdateParameterValues()
	end

	local bt = BehaviourTree:New()
	local nodeMap = {}
	local root = WG.nodeList[rootID]
	
	for id,node in pairs(WG.nodeList) do
		if(node.id ~= rootID)then
			local params = {}
			
			for _, key in ipairs(fieldsToSerialize) do
				if(node[key]) then
					if key == 'x' or key == 'y' then
						params[key] = node[key] - root[key]
					elseif(type(node[key]=="table")) then
						params[key] = copyTable(node[key])
					else
						params[key] = node[key]
					end
				end
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
	if(btCreatorWindow) then
		btCreatorWindow.zoomedOut = false
	end
	connectionLine.clear()
	for id,node in pairs(WG.nodeList) do
		node:Dispose()
	end
	WG.nodeList = {}
	WG.selectedNodes = {}

	if(not omitRoot)then
		addNodeToCanvas( createRoot(true) )
	end
end

function loadSensorAutocompleteTable()
	if WG.sensorAutocompleteTable then
		return
	end
	WG.sensorAutocompleteTable = {}
	local sensors = BtEvaluator.SensorManager.getAvailableSensors()
	
	-- Logger.log("save-and-load", "Sensor info - ", info)
	for _, name in ipairs(sensors) do
		local file, res = ProjectManager.findFile(BtEvaluator.SensorManager.contentType, name)
		if res.exists then
			local projectName = res.project
			local key = res.name .. "()"
			
			local fieldTable = {}
			
			local sensorCode = VFS.LoadFile(file)
			sensorCode = sensorCode:match("function +getInfo.-end") 
			--Logger.log("save-and-load", "Sensor - ", name,"; getInfo code - ", sensorCode)
			
			if sensorCode ~= nil then
				local getInfo = loadstring("--[[" .. name .. "]] " .. sensorCode .. "; return getInfo")()
				local info = getInfo()
				Logger.log("save-and-load", "Sensor getInfo - ", info)
				
				if info.fields then
					for _,v in ipairs(info.fields) do
						fieldTable[v] = {}
					end
				end
			end
			
			local projectTable = WG.sensorAutocompleteTable[projectName]
			if not projectTable then
				projectTable = {}
				WG.sensorAutocompleteTable[projectName] = projectTable
			end
			
			projectTable[key] = fieldTable
		end
	end
end

local function loadBehaviourNode(bt, btNode)
	if(not btNode or btNode.nodeType == "empty_tree")then return nil end
	local params = {}
	local info

	Logger.log("save-and-load", "loadBehaviourNode - nodeType: ", btNode.nodeType, " scriptName: ", btNode.scriptName, " info: ", dump(nodeDefinitionInfo[btNode.nodeType],2))
	if (btNode.scriptName ~= nil) then
		info = nodeDefinitionInfo[btNode.scriptName]
		if(not info) then
			error("Trying to load unknown node: ".. btNode.scriptName)
		end
	else
		info = nodeDefinitionInfo[btNode.nodeType]
		if(not info) then
			error("Trying to load unknown lua script node: ".. btNode.nodeType)
		end
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

			Logger.log("save-and-load", "params: ", params, ", params.parameters: ", params.parameters)
			for i=1,#v do
				if (v[i].name ~= "scriptName") then
					if(not params.parameters[i])then
						Logger.error("save-and-load", "Parameter names do not match: N/A != ", v[i].name, " of node "..btNode.nodeType or btNode.scriptName)
					end
				
					if(params.parameters[i].name ~= v[i].name)then
						Logger.error("save-and-load", "Parameter names do not match: ", params.parameters[i].name, " != ", v[i].name, " of node "..btNode.nodeType or btNode.scriptName)
					end

					Logger.log("save-and-load", "params.parameters[i]: ", params.parameters[i], ", v[i]: ", v[i])
					params.parameters[i].value = v[i].value
				end
			end
		elseif(k == 'referenceInputs' or k == 'referenceOutputs')then
			for i=#v,1,-1 do
				if(v[i].value == "") then
					table.remove(v, i)
				end
			end
			params[k] = copyTable(v)
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
	serializedTreeName = treeNameLabel.caption -- to be able to regenerate ids of deserialized nodes, when saved with different name
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
	local addInputButton = WG.nodeList[rootID].nodeWindow:GetChildByName("AddInput")
	for i=1,#bt.inputs do
		-- Add inputs and sets them to saved values
		addInputButton:CallListeners( addInputButton.OnClick )
		WG.nodeList[rootID].inputs[i].editBox:SetText(bt.inputs[i].name)
		local inputType = inputTypeMap[ bt.inputs[i]["command"] ]
		local inputComboBox = WG.nodeList[rootID].inputs[i].comboBox
		for k=1,#inputComboBox.items do
			if(inputComboBox.items[k] == inputType) then
				WG.nodeList[rootID].inputs[i].comboBox:Select( k )
			end
		end
	end
	-- deserialize tree outputs
	local addOutputButton = WG.nodeList[rootID].nodeWindow:GetChildByName("AddOutput")
	bt.outputs = bt.outputs or {}
	for i=1,#bt.outputs do
		addOutputButton:CallListeners( addOutputButton.OnClick )
		WG.nodeList[rootID].outputs[i].editBox:SetText(bt.outputs[i].name)
	end
	
	-- load root node position and size
	local serRoot = (bt.additionalParameters or { root = nil }).root
	local root = WG.nodeList[rootID]
	if serRoot then
		root.x = serRoot.x or 0
		root.y = serRoot.y or 0
		root.width = serRoot.width
		root.height = serRoot.height
		root.nodeWindow:SetPos(root.x, root.y, root.width, root.height)
		root.nodeWindow:Invalidate()
	end
	
	moveCanvas(5, btCreatorWindow.height / 2 - root.height / 2)
end


--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------

Dependency.deferWidget(widget, Dependency.BtEvaluator)