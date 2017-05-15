---   Blackboard showing module

local blackboard = {}

local sanitizer = Utils.Sanitizer.forWidget(widget)

local Chili = Utils.Chili
local Screen0 = Chili.Screen0

local blackboardWindowState
local createRows, rowsMetatable
do
	local TEXT_HEIGHT = 20
	local metapairs = Utils.metapairs

	local function makeCaption(k, v)
		local strKey = tostring(k)
		local strValue = tostring(v)
		return strKey .. " = " .. (strValue == "<table>" and "{...}" or strValue)
	end
	local rowsPrototype = {}
	function rowsPrototype:SetTable(t)
		local keyMap = self.keyMap
		if(not keyMap)then
			keyMap = {}
			self.keyMap = keyMap
		end

		local length = self.length or 0
		local oldLength = length
		local offset = 0
		local top = 0
		for i = 1, length do
			local row = self[i]
			if(t[row.key] == nil)then
				row.control:Dispose()
				keyMap[row.key] = nil
				offset = offset + 1
			else
				self[i - offset] = row
				row.index = i - offset
				row.control:SetPos(0, top)
				local v = t[row.key]
				row.currentValue = v
				row.control.children[1]:SetCaption(makeCaption(row.key, v))
				if(row.subrows)then
					row.subrows:SetTable(v)
				end
				top = top + row.height
			end
		end
		length = length - offset
		for k, v in metapairs(t) do
			if(not keyMap[k])then
				local row; row = {
					key = k,
					currentValue = v,
					control = Chili.Control:New{
						parent = self.wrapper,
						x = 0,
						y = top,
						padding = {0,0,0,0},
						width = '100%',
						height = TEXT_HEIGHT*4,
						children = { Chili.Label:New{
							x = 0,
							y = 0,
							caption = makeCaption(k, v),
							OnMouseUp = (type(v) == "table" and { sanitizer:AsHandler(function(control)
								if(row.panel)then
									row:Contract()
								else
									row:Expand()
								end
								self:Realign()
								return control
							end) }) or nil,
						}, },
					},
					height = TEXT_HEIGHT,
					Contract = function(row)
						if(not row.panel)then return end

						self.expandTable[k] = nil
						row.panel:Dispose()
						row.panel = nil
						row.subrows = nil
						row.height = TEXT_HEIGHT
					end,
					Expand = function(row)
						if(row.panel)then return end

						row.panel = Chili.Control:New{
							parent = row.control,
							x = 0,
							y = TEXT_HEIGHT,
							width = '100%',
							padding = {10,0,0,0},
						}
						local innerExpandTable = self.expandTable[k]
						if(not innerExpandTable)then
							innerExpandTable = {}
							self.expandTable[k] = innerExpandTable
						end
						row.subrows = createRows(row.panel, innerExpandTable, function(rows, height)
							row.panel:SetPos(nil, nil, nil, height)
							row.height = TEXT_HEIGHT + height
							row.control:SetPos(nil, nil, nil, row.height)
						end)
						row.subrows:SetTable(row.currentValue)
					end,
				}
				if(self.expandTable[k])then
					row:Expand()
				end
				top = top + row.height
				keyMap[k] = row
				length = length + 1
				self[length] = row
				row.index = length
			end
		end
		for i = length + 1, oldLength do
			self[i] = nil
		end
		self.length = length

		self.height = top
		if(self.sizeChangedCallback)then
			self.sizeChangedCallback(self, top)
		end
	end
	function rowsPrototype:Realign()
		local top = 0
		for i = 1, self.length do
			row = self[i]
			row.control:SetPos(0, top)
			top = top + row.height
		end

		self.height = top
		if(self.sizeChangedCallback)then
			self.sizeChangedCallback(self, top)
		end
	end

	rowsMetatable = {
		__index = rowsPrototype
	}

	function createRows(wrapper, expandTable, sizeChangedCallback)
		return setmetatable({
			length = 0,
			wrapper = wrapper,
			sizeChangedCallback = sizeChangedCallback,
			expandTable = expandTable,
		}, rowsMetatable)
	end
end
local expandedVariablesMap = {}

local function showCurrentBlackboard(blackboardState)
	currentBlackboardState = blackboardState
	if(not blackboardWindowState)then
		return
	end

	blackboardWindowState.rows:SetTable(blackboardState)
end
local function listenerClickOnShowBlackboard()
	if(blackboardWindowState)then
		blackboard.window:Dispose()
		blackboardWindowState = nil
		return
	end

	blackboardWindowState = {}

	local height = 60+10*20
	local window = Chili.Window:New{
		parent = Screen0,
		name = "BlackboardWindow",
		x = blackboard.x,
		y = blackboard.y,
		width = 400,
		height = height,
		skinName = 'DarkGlass',
		caption = "Blackboard:",
	}
	blackboard.window = window

	blackboardWindowState.contentWrapper = Chili.ScrollPanel:New{
		parent = window,
		x = 0,
		y = 0,
		width = '100%',
		height = '100%',
	}

	blackboardWindowState.rows = createRows(blackboardWindowState.contentWrapper, expandedVariablesMap)

	if(currentBlackboardState)then
		showCurrentBlackboard(currentBlackboardState)
	end
end

local function setWindowPosition(x, y)
	blackboard.x = x
	blackboard.y = y
end

blackboard.setWindowPosition = setWindowPosition
blackboard.listenerClickOnShowBlackboard = listenerClickOnShowBlackboard
blackboard.showCurrentBlackboard = showCurrentBlackboard

return blackboard