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

local BtEvaluator
 
local windowBtCreator
local nodePoolLabel
local nodePoolPanel
local loadTreeButton
local saveTreeButton
local treeName

--- Contains all the TreeNodes on the editable area - windowBtCreator aka canvas. 
WG.nodeList = {}
local nodePoolList = {}
--- Key into the nodeList. 
local rootID = nil

-- Include debug functions, copyTable() and dump()
--VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCreator/debug_utils.lua", nil, VFS.RAW_FIRST)
local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)

local JSON = Utils.JSON
local BehaviourTree = Utils.BehaviourTree
local Dependency = Utils.Dependency

local Debug = Utils.Debug;
local Logger, dump, copyTable, fileTable = Debug.Logger, Debug.dump, Debug.copyTable, Debug.fileTable


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
		WG.RemoveConnectionLine(node.attachedLines[i])
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
	startCopyingLocation.y = y + node.y
	return true
end

function listenerEndCopyingNode(self, x , y)
	--y = y + startCopyingLocation.y
	if(copyTreeNode and x - nodePoolPanel.width - startCopyingLocation.x > -20) then
		-- Spring.Echo("listener end Copy Object. x:"..x..", y="..y)
		addNodeToCanvas(Chili.TreeNode:New{
				parent = windowBtCreator,
				nodeType = copyTreeNode.nodeType,
				x = x - nodePoolPanel.width - startCopyingLocation.x,
				y = y + startCopyingLocation.y - 70,
				connectable = true,
				draggable = true,
				hasConnectionIn = copyTreeNode.hasConnectionIn,
				hasConnectionOut = copyTreeNode.hasConnectionOut,
				-- OnMouseUp = { listenerEndSelectingNodes },
			})
		copyTreeNode = nil
	end
end

local SerializeForest
local DeserializeForest

local clearCanvas, loadBehaviourTree, formBehaviourTree

function listenerClickOnSaveTree(self)
	Logger.log("save-and-load", "Save Tree clicked on. ")
	formBehaviourTree():Save(treeName.text)
	SerializeForest()
end

function listenerClickOnLoadTree(self)
	Logger.log("save-and-load", "Load Tree clicked on. ")
	local bt = BehaviourTree.load(treeName.text)
	if(bt)then
		clearCanvas()
		loadBehaviourTree(bt)
	else
		DeserializeForest()
	end
end

function listenerClickOnTest(self)
	Logger.log("assign-tree", "Assign Tree")
	local fieldsToSerialize = {
		'id',
		'nodeType',
		'text',
		'parameters'
	}
	local bt = formBehaviourTree()
	
	BtEvaluator.createTree(bt)
	
	-- old approach, TODO: remove
	-- local stringTree = JSON:encode(bt.root) --TreeToStringJSON(WG.nodeList[rootID], fieldsToSerialize )
	-- Logger.log("create-tree", "BETS CREATE_TREE ", stringTree)
	-- SendStringToBtEvaluator("CREATE_TREE " .. stringTree)
end

-- //////////////////////////////////////////////////////////////////////
-- Messages from BtEvaluator
-- //////////////////////////////////////////////////////////////////////

local DEFAULT_COLOR = {1,1,1,0.6}
local RUNNING_COLOR = {1,0.5,0,0.6}
local SUCCESS_COLOR = {0.5,1,0.5,0.6}
local FAILURE_COLOR = {1,0.25,0.25,0.6}

local function updateStatesMessage(messageBody)
	Logger.log("communication", "Message from AI received: message type UPDATE_STATES")
	states = JSON:decode(messageBody)
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

local function generateNodePoolNodes(messageBody)
	-- messageBody = '[{ "name": "name 1", "children": null, "defaultWidth": 70, "defaultHeight": 100 }, {"name":"Sequence","children":[]}]'
	nodes = JSON:decode(messageBody)
	Logger.log("communication", "NODES DECODED:  ", nodes)
	local heightSum = 30 -- skip NodePoolLabel
	for i=1,#nodes do
		Logger.log("communication", "NODES DECODED i-th node:  ", nodes[i])
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
		}
		if(nodes[i].defaultWidth) then
			nodeParams.width = math.max(110, nodes[i].defaultWidth)
		end
		if(nodes[i].defaultHeight) then
			nodeParams.height = math.max(50, nodes[i].defaultHeight)
		end
		heightSum = heightSum + (nodeParams.height or 60)
		table.insert(nodePoolList, Chili.TreeNode:New(nodeParams))
	end
	nodePoolPanel:RequestUpdate()
end

local scripts = {}

local function getCommandClass(name) 
	c = scripts[name] 
	if not c then 
		c = VFS.Include(LUAUI_DIRNAME .. "Widgets/btCommandScripts/" .. name, nil, VFS.RAW_FIRST)
		scripts[name] = c
	end
	return c
end

local function executeScript(messageBody)
	params = JSON:decode(messageBody)
	command = getCommandClass(params.name):New()

	if (params.func == "RUN") then
		res = command.run(params.units, params.parameter)
		Logger.log("luacommand", "Result: ", res)
		return res
	elseif (params.func == "RESET") then
		command.reset()
		return nil
	end
end

function widget:RecvSkirmishAIMessage(aiTeam, message)
	-- Dont respond to other players AI
	if(aiTeam ~= Spring.GetLocalPlayerID()) then
		Logger.log("communication", "Message from AI received: aiTeam ~= Spring.GetLocalPlayerID()")
		return
	end
	-- Check if it starts with "BETS"
	if(message:len() <= 4 and message:sub(1,4):upper() ~= "BETS") then
		Logger.log("communication", "Message from AI received: beginning of message is not equal 'BETS', got: ", message:sub(1,4):upper())
		return
	end
	messageShorter = message:sub(6)
	indexOfFirstSpace = string.find(messageShorter, " ")
	messageType = messageShorter:sub(1, indexOfFirstSpace - 1):upper()	
	messageBody = messageShorter:sub(indexOfFirstSpace + 1)
	Logger.log("communication", "Message from AI received: message body: ", messageBody)
	if(messageType == "UPDATE_STATES") then 
		Logger.log("communication", "Message from AI received: message type UPDATE_STATES")
		updateStatesMessage(messageBody)		
	elseif (messageType == "NODE_DEFINITIONS") then 
		Logger.log("communication", "Message from AI received: message type NODE_DEFINITIONS")
		generateNodePoolNodes(messageBody)
	elseif (messageType == "COMMAND") then
		return executeScript(messageBody)
	end
end

-- ///////////////////////////////////////////////////////////////////
-- it adds the prefix BETS and sends the string through Spring
function SendStringToBtEvaluator(message)
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), "BETS " .. message)
end

function widget:Initialize()	
	if (not WG.ChiliClone) then
		-- don't run if we can't find Chili
		widgetHandler:RemoveWidget()
		return
	end
	
	BtEvaluator = WG.BtEvaluator
 
	-- Get ready to use Chili
	Chili = WG.ChiliClone
	Screen0 = Chili.Screen0	
	
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
	 -- Create the window
	windowBtCreator = Chili.Window:New{
		parent = Screen0,
		x = nodePoolPanel.width + 15,
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
	
	BtEvaluator.requestNodeDefinitions()
	
	-- rootID = 1
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
	
	saveTreeButton = Chili.Button:New{
		parent = Screen0,
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
		parent = Screen0,
		x = saveTreeButton.x + saveTreeButton.width,
		y = saveTreeButton.y,
		width = 90,
		height = 30,
		caption = "Load Tree",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = { listenerClickOnLoadTree },
	}
	
	serializeTestButton = Chili.Button:New{
		parent = Screen0,
		x = loadTreeButton.x + loadTreeButton.width,
		y = loadTreeButton.y,
		width = 90,
		height = 30,
		caption = "TEST",
		skinName = "DarkGlass",
		focusColor = {0.5,0.5,0.5,0.5},
		OnClick = {listenerClickOnTest},
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
	'hasConnectionIn',
	'hasConnectionOut',
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
	for i=#WG.connectionLines,1,-1 do
		for k=2,5 do
			WG.connectionLines[i][k]:Dispose()
		end
		table.remove(WG.connectionLines, i)
	end
	--WG.connectionLines = {}
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
	local params = {}
	for k, v in pairs(btNode) do
		params[k] = v
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
		WG.AddConnectionLine(node.connectionOut, child.connectionIn)
	end
	return node
end

function loadBehaviourTree(bt)
	local root = loadBehaviourNode(bt, bt.root)
	WG.AddConnectionLine(WG.nodeList[rootID].connectionOut, root.connectionIn)
	for _, node in ipairs(bt.additionalNodes) do
		loadBehaviourNode(bt, node)
	end
end

function SerializeForest()
	Spring.CreateDir("LuaUI/Widgets/BtBehaviours")
	local outputFile = io.open("LuaUI/Widgets/BtBehaviours/"..treeName.text..".txt", "w")
	if outputFile == nil then 
		return 
	end
	-- find all the nodes with incoming connection lines; store them using their names as indexes
	local nodesWithIncomingConnections = {}
	SerializeTree(WG.nodeList[rootID], "", outputFile)
	for i=1,#WG.connectionLines do
		nodesWithIncomingConnections[WG.connectionLines[i][6].treeNode.name] = true
	end
	-- serialize all nodes(except root) without connectionIns and the one without incoming connection lines.
	for id,node in pairs(WG.nodeList) do
		if( (node.connectionIn == nil or nodesWithIncomingConnections[node.name] == nil) and id ~= rootID ) then 
			SerializeTree(node, "", outputFile)
		end
	end
	outputFile:close()
end


function SerializeTree(root, spaces, outputFile)
	local children = root:GetChildren()
	outputFile:write(spaces.."{\n" )
	root:Serialize(spaces.."  ", outputFile, fieldsToSerialize)
	outputFile:write(spaces.."  ".."children = {\n" )
	for i=1,#children do 
		SerializeTree(children[i], spaces.."    ", outputFile)
	end
	outputFile:write(spaces.."  ".."}\n" )
	outputFile:write(spaces.."},\n" )
end

-- Create a table with structure of given tree.
function LoadTreeInTableRecursive(root, fieldsToSerialize)

	local tree = {}
	
	for nameInd=1,#fieldsToSerialize do
		tree[fieldsToSerialize[nameInd]] = root[fieldsToSerialize[nameInd]]
	end
	
	
	tree.children = {}
	local children = root:GetChildren()
	for i=1,#children do 
		tree.children[i] = LoadTreeInTableRecursive(children[i], fieldsToSerialize)
	end
	return tree
end

-- ignores the initial root:
function TreeToStringJSON(root, fieldsToSerialize)
	local rootChildren = root:GetChildren()
	if table.getn(rootChildren) > 0 then
		local firstChild = rootChildren[1]
		local treeTable = LoadTreeInTableRecursive(firstChild, fieldsToSerialize)
		local treeString = JSON:encode(treeTable)
		return treeString
	else
		return "{}"
	end
end

--- Removes white spaces from the beginnign and from the end the string s.
local function trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end


function ReadTreeNode(inputFile)
	local input = inputFile:read()
	if(input == nil or input == "" or trim(input) == "}" or trim(input) == "},") then
		return nil
	end
	local line = trim(input)
	if(line ~= "{") then 
		
		Logger.log("save-and-load", "Unknown format of saved behaviour tree. ")
		Logger.log("save-and-load", "Found: '", line, "', expected {")
	end
	local paramsString = ""
	while line ~= "children = {" do
		paramsString = paramsString..line
		line = trim(inputFile:read())
	end
	--Spring.Echo("params: "..paramsString .. "}")
	local params = loadstring("return "..paramsString .."}")()
	params.name = nil
	params.parent = windowBtCreator
	params.connectable = true
	params.draggable = true
	local root = Chili.TreeNode:New(params)
	addNodeToCanvas(root)
	while true do
		local child = ReadTreeNode(inputFile)
		if (child == nil) then
			break
		end
		--Spring.Echo("Child OOOOO")
		WG.AddConnectionLine(root.connectionOut, child.connectionIn)
		--line = trim(inputFile:read())
	end
	line = trim(inputFile:read())
	if(line ~= "},") then
		Logger.log("save-and-load", "Uknown format of saved behaviour tree. ")
		Logger.log("save-and-load", "Found: '", line, "', expected {")
	end
	return root
end

--- First removes all TreeNodes and connectionLines from canvas, 
--  then deserialize all the nodes and connections from a file. 
function DeserializeForest()
	clearCanvas(true)

	 -- rootIndex = 1
	if(not VFS.FileExists("LuaUI/Widgets/BtBehaviours/01-test.txt", "r")) then
		Logger.log("save-and-load", "BtCreator.lua: DeserializeForest(): File to deserialize not found in LuaUI/Widgets/BtBehaviours/01-test.txt ")
		return
	end	
	local inputFile = io.open("LuaUI/Widgets/BtBehaviours/01-test.txt", "r")
	while(ReadTreeNode(inputFile)) do
	end
	inputFile:close()
	WG.clearSelection()
end

Dependency.deferWidget(widget, Dependency.BtEvaluator)