local referenceNode = {}

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
local Debug = Utils.Debug;
local Logger = Debug.Logger
local ProjectDialog = Utils.ProjectDialog
local BehaviourTree = Utils.BehaviourTree
local dump = Utils.Debug.dump

local sanitizer = Utils.Sanitizer.forWidget(widget)
-- local BtCreator = sanitizer:Import(WG.BtCreator)

local dialogWindow

local function disposePreviousInputOutputComponents(nodeWindow)
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
	if(treeNode.referenceInputObjects) then
		for i=1,#treeNode.referenceInputObjects do
			if(treeNode.referenceInputObjects[i].button) then 
				treeNode.referenceInputObjects[i].button:Dispose()
			end
			treeNode.referenceInputObjects[i].label:Dispose()
			treeNode.referenceInputObjects[i].editBox:Dispose()
		end
	end
	if(treeNode.referenceOutputObjects) then
		for i=1,#treeNode.referenceOutputObjects do
			if(treeNode.referenceOutputObjects[i].button) then 
				treeNode.referenceOutputObjects[i].button:Dispose()
			end
			treeNode.referenceOutputObjects[i].label:Dispose()
			treeNode.referenceOutputObjects[i].editBox:Dispose()
		end
	end
end

local function addLabelEditboxPair(nodeWindow, components, y, label, text, invalid, serializedValues)
	local x = 25
	if(invalid) then
		components.button = Button:New{
			parent = nodeWindow,
			x = x,
			y = y,
			caption = 'x',
			width = 20,
			tooltip = "Removes this saved parameter with its value. ",
			backgroundColor = {1,0.1,0,1},
			components = components,
			OnClick = {
				function(self)
					components.editBox:Dispose()
					components.label:Dispose()
					for i,pair in ipairs(serializedValues) do
						if(pair.name == label) then
							serializedValues[i] = nil
						end
					end
					Spring.Echo(dump(nodeWindow.referenceInputs,2))
					self:Dispose()
					
					disposePreviousInputOutputComponents(nodeWindow)
					referenceNode.addInputOutputComponents(nodeWindow,nodeWindow.treeNode.parameterObjects[1].label,nodeWindow.treeName)
				end
			},
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
		OnKeyPress = {
			function(element, key)
				if(element.text ~= element.validatedValue)then
					WG.BtCreator.Get().markTreeAsChanged()
				end
				
				return true
			end
		},
		OnTextInput = {
			function()
				WG.BtCreator.Get().markTreeAsChanged()
			end
		},
	}
	if(invalid) then
		components.label.font.color = {1,0.1,0,1}
		components.editBox.font.color = {1,0.1,0,1}
	end
end

--- Function which takes care of populationg referenceNode with selected trees inputs and outputs. 
--- Is called both from treenode.lua - in treenode constructor - and on clicking 'Choose tree' button.
function referenceNode.addInputOutputComponents(nodeWindow,treeNameLabel, treeName)
	nodeWindow.treeName = treeName;
	local bt = BehaviourTree.load(treeName) or {}
	local inputs = bt.inputs or {}
	local outputs = bt.outputs or {}
	local positiony = 50
	local yoffset = 21
	-- First update label with treeName, make it clickthrough
	treeNameLabel:SetCaption(treeName)
	treeNameLabel.OnMouseOver = {
		sanitizer:AsHandler( 
			function(self)
				self.font.color = {1,0.5,0,1}
			end
		)
	}
	treeNameLabel.OnMouseOut = {
		sanitizer:AsHandler( 
			function(self)
				self.font.color = {1,1,1,1}
			end
		)
	}
	treeNameLabel.OnMouseDown = { function(self) return self end }
	treeNameLabel.OnMouseUp = {
		sanitizer:AsHandler( 
			function(self)
				local referenceID = nodeWindow.treeNode.id
				WG.BtCreator.Get().showReferencedTree(treeName, referenceID)
			end
		)
	}
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
		addLabelEditboxPair(nodeWindow, treeNode.referenceInputObjects[i], positiony, name, value, true, treeNode.referenceInputs)
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
		addLabelEditboxPair(nodeWindow, treeNode.referenceOutputObjects[i], positiony, name, value, true, treeNode.referenceOutputs)
	end
	positiony = positiony + yoffset
	WG.BtCreator.Get().markTreeAsChanged()
end

local function setTreeCallback(projectName, behaviour)
	if(projectName and behaviour) then
		treeName = projectName.."."..behaviour
		-- remove older components if any
		disposePreviousInputOutputComponents(nodeWindow)
		referenceNode.addInputOutputComponents(nodeWindow,nodeWindow.treeNode.parameterObjects[1].label,treeName)
	end
	local label = nodeWindow.treeNode.parameterObjects[1].label
	label:UpdateLayout()
	nodeWindow.treeNode.parameterObjects[1].button.x = label.x + label.width + 5
	nodeWindow.treeNode:UpdateDimensions()
	nodeWindow = nil
end


function referenceNode.listenerChooseTree(button)
	local treeContentType = Utils.ProjectManager.makeRegularContentType("Behaviours", "json")
	nodeWindow = button.parent

	local screenX,screenY = button:LocalToScreen(0,0)
	nodeWindow = button.parent
	ProjectDialog.showDialogWindow(WG.BtCreator.Get().setDisableChildrenHitTest, BehaviourTree.contentType, ProjectDialog.LOAD_DIALOG_FLAG, 
		setTreeCallback , "Select tree to be loaded:",screenX, screenY)
	return true
end

return referenceNode