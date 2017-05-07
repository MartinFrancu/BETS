local rootNode = {}

local addInputButton
local addOutputButton

local inputsLabel
local outputsLabel

--//=============================================================================
--// Listeners - input buttons
--//=============================================================================

local function updateOutputsLayout(treeNode)
	local inputs = treeNode.inputs or {}
	local i = #inputs
	local y = 48+i*20
	outputsLabel:SetPos(nil,y)
	addOutputButton:SetPos(nil,y)
	local outputs = treeNode.outputs or {}
	for k=1,#outputs do
		y = outputsLabel.y + k*20
		outputs[k].editBox:SetPos(nil,y)
		outputs[k].button:SetPos(nil,y)
		outputs[k].button.i = k
	end
end

local function listenerAddInput(button)
	local inputs = button.parent.treeNode.inputs or {}
	button.parent.treeNode.inputs = inputs
	local i = #inputs
	local y = 45 +i*20 
	local button = Button:New{
		parent = button.parent,
		x = 16,
		y = y,
		caption = 'x',
		width = 20,
		tooltip = "Removes this saved parameter with its value. ",
		backgroundColor = {1,0.1,0,1},
		OnClick = { listenerRemoveInput },
		tooltip = "Removes the selected input parameter. ",
		i = i+1,
	}
	local comboBox = ComboBox:New{
		caption = "",
		parent = button.parent,
		x = button.x + button.width + 3,
		y = y,
		width = 80,
		align = 'left',
		borderThickness = 0,
		--skinName = 'DarkGlass',
		items = {"Variable","Position", "Area", "UnitID"},
		tooltip = "Choose input parameter type. ",
	}
	local editBox = EditBox:New{
		parent = button.parent,
		text = "input"..i,
		minWidth = 60,
		x = comboBox.x + comboBox.width + 7,
		y = y,
		align = 'left',
		--skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0,0,0,0},
		autosize = true,
	}
	table.insert(inputs, { ["button"]=button, ["comboBox"]=comboBox, ["editBox"]=editBox })
	updateOutputsLayout(button.parent.treeNode)
	button.parent.treeNode:UpdateDimensions()
	button.parent:Invalidate()
	return true
end

local function listenerAddOutput(button)
	local outputs = button.parent.treeNode.outputs or {}
	button.parent.treeNode.outputs = outputs
	local i = #outputs
	local y = outputsLabel.y + 20 + i*20
	local button = Button:New{
		parent = button.parent,
		x = 16,
		y = y,
		caption = 'x',
		width = 20,
		tooltip = "Removes this saved parameter with its value. ",
		backgroundColor = {1,0.1,0,1},
		OnClick = { listenerRemoveOutput },
		tooltip = "Removes the selected input parameter. ",
		i = i+1,
	}
	local editBox = EditBox:New{
		parent = button.parent,
		text = "output"..i,
		minWidth = 60,
		x = 40,
		y = y,
		align = 'left',
		--skinName = 'DarkGlass',
		borderThickness = 0,
		backgroundColor = {0,0,0,0},
		autosize = true,
	}
	table.insert(outputs, { ["editBox"]=editBox,["button"]=button })
	button.parent.treeNode:UpdateDimensions()
	button.parent:Invalidate()
	return true
end

local function updateInputsLayout(treeNode)
	local inputs = treeNode.inputs or {}
	for i=1,#inputs do
		local y = 25 + i*20
		inputs[i].button:SetPos(nil, y)
		inputs[i].button.i = i
		inputs[i].editBox:SetPos(nil, y)
		inputs[i].comboBox:SetPos(nil, y)
	end
end

function listenerRemoveInput(self)
	local inputs = self.parent.treeNode.inputs or {}
	local i = self.i
	-- Spring.Echo("i: "..i)
	if(i <= 0) then
		return
	end 
	inputs[i].comboBox:Dispose()
	inputs[i].editBox:Dispose()
	table.remove(inputs, i)
	updateInputsLayout(self.parent.treeNode)
	updateOutputsLayout(self.parent.treeNode)
	self:Dispose() 
	return true
end

function listenerRemoveOutput(self)
	local outputs = self.parent.treeNode.outputs or {}
	local i = self.i
	if(i <= 0) then
		return
	end
	outputs[i].editBox:Dispose()
	table.remove(outputs, i)
	updateOutputsLayout(self.parent.treeNode)
	self:Dispose()
	return true
end

function rootNode.addChildComponents(treenode)
	inputsLabel = Label:New{
		name = "Inputs",
		parent = treenode.nodeWindow,
		x = 18,
		y = 24,
		width  = treenode.nodeWindow.font:GetTextWidth("Inputs"),
		height = 20,
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
	outputsLabel = Label:New{
		name = "Outputs",
		parent = treenode.nodeWindow,
		x = 18,
		y = 48,
		width  = treenode.nodeWindow.font:GetTextWidth("Outputs"),
		height = 20,
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
end

return rootNode