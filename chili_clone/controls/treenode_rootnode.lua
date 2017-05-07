local rootNode = {}

local addInputButton
local removeInputButton
local addOutputButton
local removeOutputButton

local inputsLabel
local outputsLabel

function rootNode.getMinimalDimensions(treeNode)
	local inputs = treeNode.inputs or {}
	local outputs = treeNode.outputs or {}
	local maxHeight = treeNode.nodeWindow.height
	maxHeight = math.max(maxHeight, #inputs * 20 + 55 + #outputs*20 + 28)
	local maxWidth = treeNode.nodeWindow.width
	for i=1,#inputs do
		maxWidth = math.max(maxWidth, math.max(inputs[i][1].minWidth,inputs[i][1].font:GetTextWidth(inputs[i][1].text)) + inputs[i][2].width + 56 )
		-- Spring.Echo("maxWidth: "..maxWidth, inputs[i][1].font:GetTextWidth(inputs[i][1].text) + inputs[i][2].width + 56 )
	end
	for i=1,#outputs do
		maxWidth = math.max(maxWidth,  math.max(outputs[i][1].minWidth,outputs[i][1].font:GetTextWidth(outputs[i][1].text)) + 40 )
	end
	-- Spring.Echo("maxWidth: "..maxWidth)
	return maxHeight,maxWidth
end

--//=============================================================================
--// Listeners - input buttons
--//=============================================================================

local function moveOutputs(treeNode)
	local inputs = treeNode.inputs or {}
	local i = #inputs
	local y = 48+i*20
	outputsLabel:SetPos(nil,y)
	addOutputButton:SetPos(nil,y)
	removeOutputButton:SetPos(nil,y)
	local outputs = treeNode.outputs or {}
	for k=1,#outputs do
		outputs[k][1]:SetPos(nil,outputsLabel.y + k*20)
	end
end

local function listenerAddInput(nodeWindow)
	local inputs = nodeWindow.parent.treeNode.inputs or {}
	nodeWindow.parent.treeNode.inputs = inputs
	local i = #inputs
	local comboBox = ComboBox:New{
			caption = "",
			parent = nodeWindow.parent,
			x = 18,
			y = 45 + i*20,
			width = 80,
			align = 'left',
			borderThickness = 0,
			--skinName = 'DarkGlass',
			items = {"Variable","Position", "Area", "UnitID"},
		}
	local editBox = EditBox:New{
		parent = nodeWindow.parent,
		text = "input"..i,
		defaultWidth = '40%',
		minWidth = 60,
		x = comboBox.x + comboBox.width + 10,
		y = 45 + i*20,
		align = 'left',
		--skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0,0,0,0},
		autosize = true,
	}
	table.insert(inputs, { editBox, comboBox })
	moveOutputs(nodeWindow.parent.treeNode)
	nodeWindow.parent.treeNode:UpdateDimensions()
	nodeWindow:Invalidate()
	return true
end

local function listenerAddOutput(nodeWindow)
	local outputs = nodeWindow.parent.treeNode.outputs or {}
	nodeWindow.parent.treeNode.outputs = outputs
	local i = #outputs
	local editBox = EditBox:New{
		parent = nodeWindow.parent,
		text = "output"..i,
		defaultWidth = '40%',
		minWidth = 60,
		x = 18,
		y = outputsLabel.y + 20 + i*20,
		align = 'left',
		--skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0,0,0,0},
		autosize = true,
	}
	table.insert(outputs, { editBox })
	nodeWindow.parent.treeNode:UpdateDimensions()
	nodeWindow:Invalidate()
	return true
end

local function listenerRemoveInput(nodeWindow)
	local inputs = nodeWindow.parent.treeNode.inputs or {}
	local i = #inputs
	if(i <= 0) then
		return
	end 
	inputs[i][1]:Dispose()
	inputs[i][2]:Dispose()
	table.remove(inputs, i)
	moveOutputs(nodeWindow.parent.treeNode)
	return true
end

local function listenerRemoveOutput(nodeWindow)
	local outputs = nodeWindow.parent.treeNode.outputs or {}
	local i = #outputs
	if(i <= 0) then
		return
	end
	outputs[i][1]:Dispose()
	table.remove(outputs, i)
	return true
end

function rootNode.addComponents(treenode)
	inputsLabel = Label:New{
		name = "Inputs",
		parent = treenode.nodeWindow,
		x = 18,
		y = 24,
		width  = treenode.nodeWindow.font:GetTextWidth("Inputs"),
		height = '10%',
		caption = "Inputs",
	}
	addInputButton = Button:New{
		name = "AddInput",
		parent = treenode.nodeWindow,
		x = inputsLabel.x + inputsLabel.width + 6,
		y = inputsLabel.y,
		caption = " + ",
		tooltip = "Adds new input parameter to the tree. ",
		width = 30,
		OnClick = { listenerAddInput },
	}
	removeInputButton = Button:New{
		name = "RemoveInput",
		parent = treenode.nodeWindow,
		x = addInputButton.x + addInputButton.width,
		y = inputsLabel.y,
		caption = "-",
		width = 30,
		tooltip = "Removes the last input parameter from the tree. ",
		OnClick = { listenerRemoveInput },
	}
	outputsLabel = Label:New{
		name = "Outputs",
		parent = treenode.nodeWindow,
		x = 18,
		y = 48,
		width  = treenode.nodeWindow.font:GetTextWidth("Outputs"),
		height = '10%',
		caption = "Outputs",
	}
	addOutputButton = Button:New{
		name = "AddOutput",
		parent = treenode.nodeWindow,
		x = outputsLabel.x + outputsLabel.width + 6,
		y = outputsLabel.y,
		caption = "+",
		tooltip = "Adds new output parameter to the tree. ",
		width = 30,
		OnClick = { listenerAddOutput },
	}
	removeOutputButton = Button:New{
		name = "RemoveOutput",
		parent = treenode.nodeWindow,
		x = addOutputButton.x + addOutputButton.width,
		y = outputsLabel.y,
		caption = "-",
		width = 30,
		tooltip = "Removes the last output parameter from the tree. ",
		OnClick = { listenerRemoveOutput },
	}
end

return rootNode