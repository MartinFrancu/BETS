if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils
return Utils:Assign("BehaviourTree", function()
	local BehaviourTree = {}
	
	local BEHAVIOURS_DIRNAME = LUAUI_DIRNAME .. "Widgets/BtBehaviours/"
	
	local JSON = Utils.JSON

	local function removeItem(t, item)
		for i, v in ipairs(t) do
			if(v == item)then
				table.remove(t, i)
				return true
			end
		end
		return false
	end
	
	local function makeNodeMetatable(tree, properties)
		local nodePrototype = {}
		function nodePrototype:Remove(toNode)
			if(not removeItem(tree.additionalNodes, self))then error("Only disconnected nodes can be removed.") end

			for _, child in ipairs(self.children) do
				table.insert(tree.additionalNodes, child)
			end
			tree.properties[self.id] = nil
		end

		function nodePrototype:Connect(toNode)
			self.children = self.children or {}
			if(not removeItem(tree.additionalNodes, toNode))then error("Cannot connect to a node that is already a child of another node.") end
			table.insert(self.children, toNode)
		end

		function nodePrototype:Disconnect(fromNode)
			if(not removeItem(self.children, fromNode))then error("Attempt to disconnect from a node that is not a child") end
			table.insert(tree.additionalNodes, fromNode)
		end

		local nodeMetatable = {
			__index = function(self, key)
				return nodePrototype[key] or properties[key]
			end,
			__newindex = properties,
		}
		
		return nodeMetatable
	end
	
	local treePrototype = {}
	local treeMetatable = { __index = treePrototype }
	
	function BehaviourTree:New()
		local bt = {}
		bt.additionalNodes = {}
		bt.properties = {}
		return setmetatable(bt, treeMetatable)
	end
	
	function treePrototype:NewNode(params)
		local node = setmetatable({
			id = params.id,
			type = params.type,
			parameters = params.parameters or {},
			children = {},
		}, makeNodeMetatable(self, params))
		
		if(params.children)then
			for _, child in ipairs(params.children) do
				node:Connect(child)
			end
		end

		for k, _ in pairs(node) do
			params[k] = nil
		end
		self.properties[node.id] = params

		table.insert(self.additionalNodes, node)
		
		return node
	end
	
	function treePrototype:SetRoot(root)
		if(self.root)then
			table.insert(self.additionalNodes, self.root)
		end
		if(root)then
			removeItem(self.additionalNodes, root)
		end
		self.root = root
	end

	
	-- loading
	local function load_setupNode(tree, node)
		if(not node)then return end

		node.parameters = node.parameters or {}
		node.children = node.children or {}
		local properties = tree.properties[node.id]
		setmetatable(node, makeNodeMetatable(tree, properties))
		
		for _, child in ipairs(node.children) do
			load_setupNode(tree, child)
		end
	end
	function BehaviourTree.load(name)
		local file = io.open(BEHAVIOURS_DIRNAME .. name .. ".json", "r")
		if(not file)then
			return nil
		end
		local bt = JSON:decode(file:read("*all"))
		file:close()
		
		bt.additionalNodes = bt.additionalNodes or {}
		bt.properties = bt.properties or {}
		setmetatable(bt, treeMetatable)
		
		load_setupNode(bt, bt.root)
		for _, node in ipairs(bt.additionalNodes) do
			load_setupNode(bt, node)
		end
		
		return bt
	end

	
	-- saving
	function BehaviourTree.save(bt, name)
		local file = io.open(BEHAVIOURS_DIRNAME .. name .. ".json", "w")
		if(not file)then
			return nil
		end
		file:write(JSON:encode(bt, nil, { pretty = true, indent = "\t" }))
		file:close()
	end
	treePrototype.Save = BehaviourTree.save
	
	return BehaviourTree
end)
