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

local function addLabelEditboxPair(nodeWindow, components, y, label, text, invalid)
	local x = 15
	if(invalid) then
		components.button = Button:New{
			parent = nodeWindow,
			x = x,
			y = y,
			caption = 'x',
			width = 20,
			tooltip = "Removes this saved parameter with its value. ",
			backgroundColor = {1,0.1,0,1},
		}
		x = x + 25
	end
	components.label = Label:New{
		parent = nodeWindow,
		x = x,
		y = y,
		caption = label,
	}
	components.editBox = EditBox:New{
		parent = nodeWindow,
		x = x + nodeWindow.font:GetTextWidth(label) + 10,
		y = y - 3,
		autosize = true,
		minWidth = 70,
		text = text or "",
	}
	if(invalid) then
		components.label.font.color = {1,0.1,0,1}
		components.editBox.font.color = {1,0.1,0,1}
	end
end

function referenceNode.addInputOutputComponents(nodeWindow,treeName)
	local bt = BehaviourTree.load(treeName)
	local inputs = bt.inputs
	local outputs = bt.outputs or {}
	local positiony = 68
	local yoffset = 21
	local treeNode = nodeWindow.treeNode
	treeNode.referenceInputsLabel = Label:New{
		parent = nodeWindow,
			x = 18,
			y = positiony,
			caption = "Inputs: ",
	}
	treeNode.referenceInputs = treeNode.referenceInputs or {}
	treeNode.referenceInputObjects = {}
	local unfilledInputs = {}
	for _,input in pairs(treeNode.referenceInputs) do
		unfilledInputs[input.name] = input.value
	end
	for i=1,#inputs do
		positiony = positiony + yoffset
		local value = ''
		if(treeNode.referenceInputs
			and treeNode.referenceInputs[i] 
			and treeNode.referenceInputs[i].value
			) then
				if(unfilledInputs[ inputs[i].name ]) then
					value = treeNode.referenceInputs[i].value
					unfilledInputs[ inputs[i].name ] = nil
				end
		end
		treeNode.referenceInputObjects[i] = {}
		addLabelEditboxPair(nodeWindow, treeNode.referenceInputObjects[i], positiony, inputs[i].name, value)
	end
	for name,value in pairs(unfilledInputs) do
		positiony = positiony + yoffset
		local i = #treeNode.referenceInputObjects + 1
		treeNode.referenceInputObjects[i] = {}
		addLabelEditboxPair(nodeWindow, treeNode.referenceInputObjects[i], positiony, name, value, true)
	end
	positiony = positiony + yoffset
	treeNode.referenceOutputsLabel = Label:New{
		parent = nodeWindow,
			x = 18,
			y = positiony,
			caption = "Outputs: "
	}
	treeNode.referenceOutputs = nodeWindow.treeNode.referenceOutputs or {}
	treeNode.referenceOutputObjects = {}
	local unfilledOutputs = {}
	for _,output in pairs(treeNode.referenceOutputs) do
		unfilledOutputs[output.name] = output.value
	end
	for i=1,#outputs do
		positiony = positiony + yoffset
		local value = ''
		if(treeNode.referenceOutputs
			and treeNode.referenceOutputs[i] 
			and treeNode.referenceOutputs[i].value
			) then
				if(unfilledOutputs[ outputs[i].name ]) then
					unfilledOutputs[ outputs[i].name ] = nil
					value = treeNode.referenceOutputs[i].value
				end
		end
		treeNode.referenceOutputObjects[i] = {}
		addLabelEditboxPair(nodeWindow, treeNode.referenceOutputObjects[i], positiony, outputs[i].name, value)
	end
	for name,value in pairs(unfilledOutputs) do
		positiony = positiony + yoffset
		local i = #treeNode.referenceOutputObjects + 1
		treeNode.referenceOutputObjects[i] = {}
		addLabelEditboxPair(nodeWindow, treeNode.referenceOutputObjects[i], positiony, name, value, true)
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
	if(dialogWindow) then
		dialogWindow:Dispose()
	end
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