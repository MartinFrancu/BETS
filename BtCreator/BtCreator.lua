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
 
local Chili, Screen0, JSON
 
local windowBtCreator
local nodePoolLabel
local nodePoolPanel
local loadTreeButton
local saveTreeButton

--- Contains all the TreeNodes on the editable area - windowBtCreator aka canvas. 
local nodeList = {}
local nodePoolList = {}
local nodeIndexFromID = {}
--- Index into the nodeList, root should always be 1. 
local rootIndex = 1

-- Include debug functions, copyTable() and dump()
VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCreator/debug_utils.lua", nil, VFS.RAW_FIRST)

function GetNodeFromID(id)
	return nodeList[nodeIndexFromID[id]]
end

WG.GetNodeFromID = GetNodeFromID

local function addNodeToCanvas(node)
	table.insert(nodeList, node)
	nodeIndexFromID[nodeList[#nodeList].id] = #nodeList
end

-- //////////////////////////////////////////////////////////////////////
-- Listeners
-- //////////////////////////////////////////////////////////////////////

local copyTreeNode = nil
--- In coordinates of nodePool(origin in top left corner of nodePool)
local startCopyingLocation = {}

function listenerStartCopyingNode(node, x , y)
	Spring.Echo("listener start Copy Object. x:"..x + node.x..", y="..y + node.y)
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

function listenerClickOnSaveTree(self)
	Spring.Echo("Save Tree clicked on. ")
	SerializeForest()
end

function listenerClickOnLoadTree(self)
	Spring.Echo("Load Tree clicked on. ")
	DeserializeForest()
end

function listenerClickOnTest(self)
	Spring.Echo("Assign Tree")
	local fieldsToSerialize = {
		'id',
		'nodeType',
		'text',
		'parameters'
	}
	-- Spring.Echo("ROOT: "..dump(root))
	local stringTree = TreeToStringJSON(nodeList[rootIndex], fieldsToSerialize )
	Spring.Echo("BETS CREATE_TREE "..stringTree)
	SendStringToBtEvaluator("CREATE_TREE "..stringTree)
end

-- //////////////////////////////////////////////////////////////////////
-- Messages from BtEvaluator
-- //////////////////////////////////////////////////////////////////////

local DEFAULT_COLOR = {1,1,1,0.6}
local RUNNING_COLOR = {1,0.5,0,0.6}
local SUCCESS_COLOR = {0.5,1,0.5,0.6}
local FAILURE_COLOR = {1,0.25,0.25,0.6}

local function updateStatesMessage(messageBody)
	Spring.Echo("Message from AI received: message type UPDATE_STATES")
	states = JSON:decode(messageBody)
	for i=2,#nodeList do
		local id = nodeList[i].id
		local color = copyTable(DEFAULT_COLOR);
		if(states[id] ~= nil) then
			if(states[id]:upper() == "RUNNING") then
				color = copyTable(RUNNING_COLOR)
			elseif(states[id]:upper() == "SUCCESS") then
				color = copyTable(SUCCESS_COLOR)
			elseif(states[id]:upper() == "FAILURE") then
				color = copyTable(FAILURE_COLOR)
			else
				Spring.Echo("Uknown state received from AI, for node id: "..id)
			end
		end
		-- Do not change color alpha
		local alpha = nodeList[i].nodeWindow.backgroundColor[4]
		nodeList[i].nodeWindow.backgroundColor = color
		nodeList[i].nodeWindow.backgroundColor[4] = alpha
		nodeList[i].nodeWindow:Invalidate()
	end
	local children = nodeList[1]:GetChildren()
	if(#children > 0) then
		local alpha = nodeList[1].nodeWindow.backgroundColor[4]
		nodeList[1].nodeWindow.backgroundColor = copyTable(children[1].nodeWindow.backgroundColor)
		nodeList[1].nodeWindow.backgroundColor[4] = alpha
		nodeList[1].nodeWindow:Invalidate()
	end
end

local function generateNodePoolNodes(messageBody)
	-- messageBody = '[{ "name": "name 1", "children": null, "defaultWidth": 70, "defaultHeight": 100 }, {"name":"Sequence","children":[]}]'
	nodes = JSON:decode(messageBody)
	Spring.Echo("NODES DECODED:  "..dump(nodes))
	local heightSum = 30 -- skip NodePoolLabel
	for i=1,#nodes do
		Spring.Echo("NODES DECODED i-th node:  "..dump(nodes[i]))
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

local function executeScript(messageBody)
	params = JSON:decode(messageBody)
	
	c = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCreator/commandScripts/"..params.name, nil, VFS.RAW_FIRST)
	if (params.func == "RUN") then
		c.runCommand(params.units)
	elseif (params.func == "RESET") then
		c.resetCommand()
	end
end

function widget:RecvSkirmishAIMessage(aiTeam, message)
	-- Dont respond to other players AI
	if(aiTeam ~= Spring.GetLocalPlayerID()) then
		Spring.Echo("Message from AI received: aiTeam ~= Spring.GetLocalPlayerID()")
		return
	end
	-- Check if it starts with "BETS"
	if(message:len() <= 4 and message:sub(1,4):upper() ~= "BETS") then
		Spring.Echo("Message from AI received: beginning of message is not equal 'BETS', got: "..message:sub(1,4):upper())
		return
	end
	messageShorter = message:sub(6)
	indexOfFirstSpace = string.find(messageShorter, " ")
	messageType = messageShorter:sub(1, indexOfFirstSpace - 1):upper()	
	messageBody = messageShorter:sub(indexOfFirstSpace + 1)
	Spring.Echo("Message from AI received: message body: "..messageBody)
	if(messageType == "UPDATE_STATES") then 
		Spring.Echo("Message from AI received: message type UPDATE_STATES")
		updateStatesMessage(messageBody)		
	elseif (messageType == "NODE_DEFINITIONS") then 
		Spring.Echo("Message from AI received: message type NODE_DEFINITIONS")
		generateNodePoolNodes(messageBody)
	elseif (messageType == "COMMAND") then
		executeScript(messageBody)
	end
end

-- ///////////////////////////////////////////////////////////////////
-- it adds the prefix BETS and sends the string through Spring
function SendStringToBtEvaluator(message)
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), "BETS " .. message)
end

function widget:Initialize()	
  if (not WG.ChiliClone) and (not WG.JSON) and (not WG.BtEvaluatorIsLoaded) then
    -- don't run if we can't find Chili, or JSON, or BtEvaluatorLoader
    widgetHandler:RemoveWidget()
    return
  end
 
  -- Get ready to use Chili
  Chili = WG.ChiliClone
  Screen0 = Chili.Screen0	
  JSON = WG.JSON
	
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
		draggable=false,
		resizable=true,
		skinName='DarkGlass',
		backgroundColor = {1,1,1,1},
		-- OnMouseDown = { listenerStartSelectingNodes },
		-- OnMouseUp = { listenerEndSelectingNodes },
  }	
	
	Spring.Echo("BETS REQUEST_NODE_DEFINITIONS")
	Spring.SendSkirmishAIMessage (Spring.GetLocalPlayerID (), "BETS REQUEST_NODE_DEFINITIONS")
	
	rootIndex = 1
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
end

function SerializeForest()
	local outputFile = io.open("LuaUI/Widgets/behaviour_trees/01-test.txt", "w")
  if outputFile == nil then 
		return 
	end
	-- find all the nodes with incoming connection lines; store them using their names as indexes
	local nodesWithIncomingConnections = {}
	SerializeTree(nodeList[rootIndex], "", outputFile)
	for i=1,#WG.connectionLines do
		nodesWithIncomingConnections[WG.connectionLines[i][6].treeNode.name] = true
	end
	-- serialize all nodes(except root) without connectionIns and the one without incoming connection lines.
	for i=2,#nodeList do
		if( nodeList[i].connectionIn == nil or nodesWithIncomingConnections[nodeList[i].name] == nil ) then 
			SerializeTree(nodeList[i], "", outputFile)
		end
	end
	outputFile:close()
end


function SerializeTree(root, spaces, outputFile)
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
		local treeString = WG.JSON:encode(treeTable)
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
		
		Spring.Echo("Uknown format of saved behaviour tree. ")
		Spring.Echo("Found: '"..line.."', expected {")
	end
	local paramsString = ""
	while line ~= "children = {" do
		--[[
		-- Differentiate the types: numbers, boolean, strings
		if(value:match("^%d+$")) then
			local val = tonumber(value)
			if( val == nil ) then
				Spring.Echo("ReadTreeNode(): value is nil, should be number= "..value)
			end			
			params[name] = val
			Spring.Echo(name.."="..params[name])
			Spring.Echo(name.."="..val)
		elseif (value == "true") then
			params[name] = true
		elseif (value == "false") then
			params[name] = false
		else
			params[name] = value
		end
		]]--
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
		Spring.Echo("Uknown format of saved behaviour tree. ")
		Spring.Echo("Found: '"..line.."', expected {")
	end
	return root
end

--- First removes all TreeNodes and connectionLines from canvas, 
--  then deserialize all the nodes and connections from a file. 
function DeserializeForest()
	for i=#WG.connectionLines,1,-1 do
		for k=2,5 do
			WG.connectionLines[i][k]:Dispose()
		end
		table.remove(WG.connectionLines, i)
	end
	--WG.connectionLines = {}
	for i=1,#nodeList do
		nodeList[i]:Dispose()
	end
	nodeList = {}
	rootIndex = 1
	if(not VFS.FileExists("LuaUI/Widgets/behaviour_trees/01-test.txt", "r")) then
		Spring.Echo("BtCrator.lua: DeserializeForest(): File to deserialize not found in LuaUI/Widgets/behaviour_trees/01-test.txt ")
		return
	end	
	local inputFile = io.open("LuaUI/Widgets/behaviour_trees/01-test.txt", "r")
	while(ReadTreeNode(inputFile)) do
	end
	inputFile:close()
end