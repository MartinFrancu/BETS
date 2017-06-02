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
	local function disposeObjects(objects)
		if(objects) then
			for i=#objects,1,-1 do
				objects[i]:SaveData()
				if(objects[i].button) then 
					objects[i].button:Dispose()
				end
				objects[i].label:Dispose()
				objects[i].editBox:Dispose()
			end
		end
	end
	disposeObjects(treeNode.referenceInputObjects)
	disposeObjects(treeNode.referenceOutputObjects)
end

local function addLabelEditboxPair(nodeWindow, components, y, data, dataList, invalid)
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
					self:Dispose()
					data.value = nil
					
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
		caption = data.name,
	}
	components.editBox = EditBox:New{
		parent = nodeWindow,
		x = x + components.label.width + 10,  --nodeWindow.font:GetTextWidth(data.label) + 10,
		y = y - 3,
		autosize = true,
		minWidth = 70,
		text = data.value or "",
		validatedValue = data.value or "",
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
	function components:SaveData()
		if(components.editBox and not components.editBox.disposed)then
			data.value = components.editBox.text
		end

		local position = nil
		for i, d in ipairs(dataList) do
			if(d.name == data.name)then
				position = i
				break
			end
		end
		
		if(data.value == nil or data.value == "")then
			if(position)then
				table.remove(dataList, position)
			end
		elseif(not position)then
			table.insert(dataList, 1, data)
		end
	end
	if(invalid) then
		components.label.font.color = {1,0.1,0,1}
		components.editBox.font.color = {1,0.1,0,1}
	end
end

--- Function which takes care of populationg referenceNode with selected trees inputs and outputs. 
--- Is called both from treenode.lua - in treenode constructor - and on clicking 'Choose tree' button.
function referenceNode.addInputOutputComponents(nodeWindow,treeNameLabel, treeName)
	nodeWindow.treeName = treeName;
	local bt, message = BehaviourTree.load(treeName)
	local inputs = (bt or {}).inputs or {}
	local outputs = (bt or {}).outputs or {}
	local positiony = 50
	local yoffset = 21
	-- First update label with treeName, make it clickthrough
	treeNameLabel:SetCaption(treeName)
	if(bt)then
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
					WG.BtCreator.Get().onTreeReferenceClick(treeName, referenceID)
				end
			)
		}
	else
		treeNameLabel.font.color = {1,0,0,1}
		treeNameLabel.OnMouseOver, treeNameLabel.OnMouseOut, treeNameLabel.OnMouseDown, treeNameLabel.OnMouseUp = {}, {}, {}, {}
		treeNameLabel.tooltip = message
	end
	
	local treeNode = nodeWindow.treeNode
	local function createComponents(parameterDefinitions, parameterValues, objectsStorage)
		storageI = #objectsStorage
		local function makeObject()
			local object = {}
			storageI = storageI + 1
			objectsStorage[storageI] = object
			return object
		end
		
		local unfilledMap = {}
		for _,data in pairs(parameterValues) do
			unfilledMap[data.name] = data
		end
		for i, def in ipairs(parameterDefinitions) do
			local data = unfilledMap[def.name] or { name = def.name }
			unfilledMap[def.name] = nil
			addLabelEditboxPair(nodeWindow, makeObject(), positiony, data, parameterValues)
			positiony = positiony + yoffset
		end
		for _, data in pairs(parameterValues) do
			if(unfilledMap[data.name])then
				addLabelEditboxPair(nodeWindow, makeObject(), positiony, data, parameterValues, true)
				positiony = positiony + yoffset
			end
		end
	end
	
	treeNode.referenceInputsLabel = Label:New{
		parent = nodeWindow,
			x = 18,
			y = positiony,
			caption = "Inputs: ",
	}
	positiony = positiony + yoffset
	
	treeNode.referenceInputs = treeNode.referenceInputs or {}
	treeNode.referenceInputObjects = {}
	createComponents(inputs, treeNode.referenceInputs, treeNode.referenceInputObjects)
	
	treeNode.referenceOutputsLabel = Label:New{
		parent = nodeWindow,
			x = 18,
			y = positiony,
			caption = "Outputs: "
	}
	positiony = positiony + yoffset
	
	treeNode.referenceOutputs = treeNode.referenceOutputs or {}
	treeNode.referenceOutputObjects = {}
	createComponents(outputs, treeNode.referenceOutputs, treeNode.referenceOutputObjects)
	
	WG.BtCreator.Get().markTreeAsChanged()
end

-- Stores nodeWindow component corresponding to last clicked chooseTreeButton
local nodeWindow
local treeName

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
	local treeContentType = BehaviourTree.contentType
	nodeWindow = button.parent

	local screenX,screenY = button:LocalToScreen(0,0)
	nodeWindow = button.parent
	
	local project, name = Utils.ProjectManager.fromQualifiedName(nodeWindow.treeName or "")
	if(not project)then
		project = Utils.ProjectManager.fromQualifiedName(WG.BtCreator.Get().getCurrentTreeName())
	end
	ProjectDialog.showDialog({
		visibilityHandler = WG.BtCreator.Get().setDisableChildrenHitTest,
		contentType = BehaviourTree.contentType,
		dialogType = ProjectDialog.LOAD_DIALOG, 
		title = "Select tree to be loaded:",
		x = screenX,
		y = screenY,
		project = project,
		name = name,
	}, setTreeCallback)
	return true
end

return referenceNode