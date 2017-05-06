local referenceNode = {}

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
local ProjectDialog = Utils.ProjectDialog
local BehaviourTree = Utils.BehaviourTree
local dump = Utils.Debug.dump

local dialogWindow

-- Stores nodeWindow component corresponding to last clicked chooseTreeButton
local nodeWindow

local function disposePreviousInputOutputComponents()
	if(not nodeWindow) then
		return
	end
	local treeNode = nodeWindow.treeNode
	if(treeNode.referenceInputsLabel) then
		treeNode.referenceInputsLabel:Dispose() 
	end
	if(treeNode.referenceOutputsLabel) then 
		treeNode.referenceOutputsLabel:Dispose()
	end
	if(not treeNode.referenceInputObjects or not treeNode.referenceOutputObjects) then
		return
	end
	for i=1,#treeNode.referenceInputObjects do
		treeNode.referenceInputObjects[i].label:Dispose()
		treeNode.referenceInputObjects[i].editBox:Dispose()
	end
		for i=1,#treeNode.referenceOutputObjects do
		treeNode.referenceOutputObjects[i].label:Dispose()
		treeNode.referenceOutputObjects[i].editBox:Dispose()
	end
end

local function addLabelEditboxPair(nodeWindow, components, i, y, label, text)
	components[i] = {}
	components[i].label = Label:New{
		parent = nodeWindow,
		x = 25,
		y = y,
		caption = label,
	}
	components[i].editBox = EditBox:New{
		parent = nodeWindow,
		x = 25 + nodeWindow.font:GetTextWidth(label) + 10,
		y = y,
		autosize = true,
		minWidth = 70,
		text = text or "",
	}
end

function referenceNode.addInputOutputComponents(nodeWindow,treeName)
	local bt = BehaviourTree.load(treeName)
	local inputs = bt.inputs
	local outputs = bt.outputs or {}
	local positiony = 68
	nodeWindow.treeNode.referenceInputsLabel = Label:New{
		parent = nodeWindow,
			x = 18,
			y = positiony,
			caption = "Inputs: ",
	}
	nodeWindow.treeNode.referenceInputs = nodeWindow.treeNode.referenceInputs or {}
	nodeWindow.treeNode.referenceInputObjects = {}
	for i=1,#inputs do
		positiony = positiony + 21
		local value = nodeWindow.treeNode.referenceInputs[i].value or ''
		addLabelEditboxPair(nodeWindow, nodeWindow.treeNode.referenceInputObjects, i, positiony, inputs[i].name, value)
	end
	positiony = positiony + 21
	nodeWindow.treeNode.referenceOutputsLabel = Label:New{
		parent = nodeWindow,
			x = 18,
			y = positiony,
			caption = "Outputs: "
	}
	nodeWindow.treeNode.referenceOutputs = nodeWindow.treeNode.referenceOutputs or {}
	nodeWindow.treeNode.referenceOutputObjects = {}
	for i=1,#outputs do
		positiony = positiony + 21
		local value = nodeWindow.treeNode.referenceOutputs[i].value or ''
		addLabelEditboxPair(nodeWindow, nodeWindow.treeNode.referenceOutputObjects, i, positiony, outputs[i].name, value)
	end
end

local function setTreeCallback(window, projectName, behaviour)
	if(projectName and behaviour) then
		local treeName = projectName.."."..behaviour
		nodeWindow.treeNode.parameterObjects[1].label:SetCaption(treeName)
		-- remove older components if any
		disposePreviousInputOutputComponents()
		referenceNode.addInputOutputComponents(nodeWindow,treeName)
	end
	window:Dispose()
	nodeWindow = nil
end

function referenceNode.listenerChooseTree(button)
	local treeContentType = Utils.ProjectManager.makeRegularContentType("Behaviours", "json")
	nodeWindow = button.parent
	dialogWindow = Window:New{
		parent = Screen0,
		x = 300,
		y = 800,
		width = 400,
		height = 150,
		padding = {10,10,10,10},
		draggable = true,
		resizable = true,
		skinName = 'DarkGlass',
	}
	ProjectDialog.setUpDialog(dialogWindow, treeContentType, false, dialogWindow, setTreeCallback)
	return true
end

return referenceNode