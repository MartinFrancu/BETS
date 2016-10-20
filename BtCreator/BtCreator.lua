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

--//=============================================================================
-- DEBUG functions
--//=============================================================================
function dump(o, maxDepth)
	maxDepth = maxDepth or 1
  if type(o) == 'table' then
		if (maxDepth == 0) then 
			return "..." 
		end
		if (o.name ~= nil) then -- For outputing chili objects
			return o.name
		end
		local s = '{ '
		for k,v in pairs(o) do
			 if type(k) ~= 'number' then k = '"'..k..'"' end
			 s = s .. '['..k..'] = ' .. dump(v, maxDepth-1) .. ','
		end
		return s .. '} '
 else
		return tostring(o)
 end
end
--//=============================================================================
 
local Chili, Screen0
 
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
local root

local function GetNodeFromID(id)
	return nodeList[nodeIndexFromID[id]]
end

-- //////////////////////////////////////////////////////////////////////
-- Listeners
-- //////////////////////////////////////////////////////////////////////

local selectionStart = {}

--- Either start moving or selecting nodes -  
function listenerStartSelectingNodes(self, x , y)
	Spring.Echo("listener start selecting nodes. ")
	selectionStart.x = x
	selectionStart.y = y
	return true
end

function listenerEndSelectingNodes(self, x , y)
	Spring.Echo("listener end selecting nodes. ")
	return true
end

--[[
function widget:MousePress()
	Spring.Echo("listener start selecting nodes. ")
	selectionStart.x = x
	selectionStart.y = y
	return true
end

function widget:MouseRelease()
	Spring.Echo("listener end selecting nodes. ")
	return true
end 
]]--

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
		Spring.Echo("listener end Copy Object. x:"..x..", y="..y)
		table.insert(nodeList, Chili.TreeNode:New{
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
		nodeIndexFromID[nodeList[#nodeList].id] = #nodeList
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
	Spring.Echo("TEST")
	local fieldsToSerialize = {
		'id',
		'nodeType',
		'text',
		'parameters'
	}
	local stringTree = TreeToStringJSON(nodeList[root], fieldsToSerialize )
	Spring.Echo(stringTree)
	SendStringToBtEvaluator(stringTree)
end

-- //////////////////////////////////////////////////////////////////////

function widget:RecvSkirmishAIMessage(aiTeam, message)
	-- Dont respond to other players AI
	if(aiTeam ~= Spring.GetLocalPlayerID()) then
		Spring.Echo("Message from AI received: aiTeam ~= Spring.GetLocalPlayerID()")
		return
	end
	-- Check if it starts with "BETS"
	if(message:len() <= 4 and message:sub(1,4):upper() ~= "BETS") then
		Spring.Echo("Message from AI received: beginnigng of message is not equal 'BETS', got: "..message:sub(1,4):upper())
		return
	end
	messageShorter = message:sub(5)
	indexOfFirstSpace = messageShorter:pattern("")
	messageType = messageShorter:sub(1, indexOfFirstSpace-1):upper()	
	messageBody = messageShorter:sub(indexOfFirstSpace)
	Spring.Echo("Message from AI received: message body: "..messageBody)
	if(messageType == "UPDATE_STATES") then 
		Spring.Echo("Message from AI received: message type UPDATE_STATES")
		states = JSON:decode(messageBody)
		for i=1,#nodeList do
			local id = nodeList[i].id
			local color = {1,1,1,0.7}
			if(states[id] ~= nil) then
				if(states[id]:upper() == "RUNNING") then
					color = {1,0.5,0,0.7}
				elseif(states[id]:upper() == "SUCCES") then
					color = {0.5,1,0.5,0.7}
				elseif(states[id]:upper() == "FAILURE") then
					color = {1,0,0,0.7}
				else
					Spring.Echo("Uknown state received from AI, for node id: "..id)
				end
			end
			nodeList[i].nodeWindow.backgroundColor = color
		end
	elseif (messageType == "CREATE_TREE") then 
		Spring.Echo("Message from AI received: message type CREATE_TREE")
		
	elseif (messageType == "NODE_DEFINITIONS") then 
		Spring.Echo("Message from AI received: message type NODE_DEFINITIONS")
		
	end
end

-- ///////////////////////////////////////////////////////////////////
-- it adds the prefix BETS and sends the string throught Spring
function SendStringToBtEvaluator(message)
	Spring.SendSkirmishAIMessage(Spring.GetLocalPlayerID(), "BETS" .. message)
end

function widget:Initialize()	
  if (not WG.ChiliClone) then
    -- don't run if we can't find Chili
    widgetHandler:RemoveWidget()
    return
  end
 
  -- Get ready to use Chili
  Chili = WG.ChiliClone
  Screen0 = Chili.Screen0	
	
  -- Create the window
  windowBtCreator = Chili.Window:New{
    parent = Screen0,
    x = 135,
    y = '56%',
    width  = Screen0.width - 135 - 25,
    height = '42%',	
		padding = {10,10,10,10},
		draggable=false,
		resizable=true,
		skinName='DarkGlass',
		backgroundColor = {1,1,1,1},
		-- OnMouseDown = { listenerStartSelectingNodes },
		-- OnMouseUp = { listenerEndSelectingNodes },
  }	
	
	nodePoolPanel = Chili.ScrollPanel:New{
		parent = Screen0,
		y = '56%',
		x = 25,
		width  = 115,
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
	
	Spring.SendSkirmishAIMessage (Spring.GetLocalPlayerID (), "BETS REQUEST_NODE_DEFINITIONS")
	
	table.insert(nodePoolList, Chili.TreeNode:New{
		parent = nodePoolPanel,
		nodeType = "Condition",
		y = 30,
		draggable = false,
		resizable = false,
		connectable = false,
		onMouseDown = { listenerStartCopyingNode },
		onMouseUp = { listenerEndCopyingNode },
	})
	table.insert(nodePoolList, Chili.TreeNode:New{
		parent = nodePoolPanel,
		nodeType = "Sequence",
		y = 30+#nodePoolList*60,
		draggable = false,
		resizable = false,
		connectable = false,
		onMouseDown = { listenerStartCopyingNode },
		onMouseUp = { listenerEndCopyingNode },
	})	
	table.insert(nodePoolList, Chili.TreeNode:New{
		parent = nodePoolPanel,
		nodeType = "MemSequence",
		y = 30+#nodePoolList*60,
		draggable = false,
		resizable = false,
		connectable = false,
		onMouseDown = { listenerStartCopyingNode },
		onMouseUp = { listenerEndCopyingNode },
	})	
	table.insert(nodePoolList, Chili.TreeNode:New{
		parent = nodePoolPanel,
		nodeType = "Wait",
		y = 30+#nodePoolList*60,
		draggable = false,
		resizable = false,
		connectable = false,
		onMouseDown = { listenerStartCopyingNode },
		onMouseUp = { listenerEndCopyingNode },
		hasConnectionOut = false,
	})
	table.insert(nodePoolList, Chili.TreeNode:New{
		parent = nodePoolPanel,
		nodeType = "Invertor",
		y = 30+#nodePoolList*60,
		draggable = false,
		resizable = false,
		connectable = false,
		onMouseDown = { listenerStartCopyingNode },
		onMouseUp = { listenerEndCopyingNode },
	})
	root = 1
	table.insert(nodeList, Chili.TreeNode:New{
		parent = windowBtCreator,
		nodeType = "Root",
		y = '35%',
		x = 5,
		draggable = true,
		resizable = true,
		connectable = true,
		hasConnectionIn = false,
		hasConnectionOut = true,
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
	SerializeTree(nodeList[root], "", outputFile)
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
	table.insert(nodeList, root)
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
	--root:Dispose()
	root = 1
	
	if(not VFS.FileExists("LuaUI/Widgets/behaviour_trees/01-test.txt", "r")) then
		Spring.Echo("BtCrator.lua: DeserializeForest(): File to deserialize not found in LuaUI/Widgets/behaviour_trees/01-test.txt ")
		return
	end	
	local inputFile = io.open("LuaUI/Widgets/behaviour_trees/01-test.txt", "r")
	root = ReadTreeNode(inputFile)
	--table.remove(nodeList, 1)	
	inputFile:close()
end