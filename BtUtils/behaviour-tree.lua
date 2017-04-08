--- Representation of behaviour trees (or forests) with separated important and additional data.
-- The main advantage of this structure is that all properties of @{Node}s are stored directly, while additional data needed for other purposes, eg. editing in BtCreator, are stored in a separate table.
-- However, for a user, it is possible to store any properties on the nodes themselves and they get assigned to the appropriate table.
-- @classmod BehaviourTree
-- @alias treePrototype

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end;



local Utils = BtUtils
local Logger = Utils.Debug.Logger

return Utils:Assign("BehaviourTree", function()
	local BehaviourTree = {}
	
	local BEHAVIOURS_DIRNAME = LUAUI_DIRNAME .. "Widgets/BtBehaviours/"
	
	local JSON = Utils.JSON
	local ProjectManager = Utils.ProjectManager
	
	local behavioursContentType = {
		directoryName = "Behaviours",
		fileMask = "*.json",
		nameToFile = function(name) return name .. ".json" end,
		fileToName = Utils.removeExtension,
	}
	
	BehaviourTree.ContentType = behavioursContentType
	
	
	local function removeItem(t, item)
		for i, v in ipairs(t) do
			if(v == item)then
				table.remove(t, i)
				return true
			end
		end
		return false
	end
	
	local makeNodeMetatable -- defined at the end, so that the LDoc generates the Node class after BehaviourTree methods

	local treePrototype = {}
	local treeMetatable = { __index = treePrototype }
	
	--- Stored fields.
	-- @table BehaviourTree.
	-- @tfield Node root main tree or `nil`
	-- @tfield {Node,...} additionalNodes list of subtrees that are not connected to the root
	-- @tfield {[string]=tab} properties additional data of nodes, accessed through their @{Node}`.id`
	
	--- Creates a new instance of @{BehaviourTree}
	-- @constructor
	-- @treturn BehaviourTree
	function BehaviourTree:New()
		local bt = {}
		bt.additionalNodes = {}
		bt.properties = {}
		return setmetatable(bt, treeMetatable)
	end

	--- Creates a new @{Node} that belongs to the tree.
	-- @treturn Node the created node
	-- @remark The `children` field of the `params` is a list of already created nodes (and not only their own `params`).
	function treePrototype:NewNode(
			params -- parameters of the node, such as `id`, `nodeType`, `parameters` and `children`
		)
		local properties = {}
		local node = setmetatable({
			id = params.id,
			nodeType = params.nodeType,
			scriptName = params.scriptName,
			parameters = params.parameters or {},
			children = {},
		}, makeNodeMetatable(self, properties))
		
		if(params.children)then
			for _, child in ipairs(params.children) do
				node:Connect(child)
			end
		end

		for k, v in pairs(params) do
			if(not node[k])then
				properties[k] = v
			end
		end
		self.properties[node.id] = properties

		table.insert(self.additionalNodes, node)
		
		return node
	end
	
	--- Roots the behaviour tree on the specified, already created node.
	-- @tparam Node root Node that becomes the new root.
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
	
	--- Lists all available BehaviourTrees.
	-- @static
	-- @treturn {string} Array of behaviour tree names
	function BehaviourTree.list(project)
		local list
		if(project)then
			list = ProjectManager.listProject(project, behavioursContentType)
		else
			list = ProjectManager.listAll(behavioursContentType)
		end

		local result, i = {}, 1
		for i, data in ipairs(list) do
			result[i] = data.qualifiedName
			i = i + 1
		end
		return result
	end
	
	--- Loads a previously saved tree.
	-- @static
	-- @treturn BehaviourTree loaded tree if found, `nil` otherwise
	function BehaviourTree.load(
			name -- name under which to look for the tree
		)
		
		local path, msg = ProjectManager.findFile(behavioursContentType, name)
		if(not path)then
			return nil, msg
		end
		
		local file = io.open(path, "r")
		if(not file)then
			return nil
		end
		local bt = JSON:decode(file:read("*all"))
		file:close()
		
		bt.additionalNodes = bt.additionalNodes or {}
		bt.properties = bt.properties or {}
		setmetatable(bt, treeMetatable)
		
		if not bt.root then
			local root = bt:NewNode({id = "rootId", nodeType = "empty_tree"})
			bt:SetRoot(root)
		end
		load_setupNode(bt, bt.root)
		for _, node in ipairs(bt.additionalNodes) do
			load_setupNode(bt, node)
		end
		
		return bt
	end

	--- Saves the tree under the specified name.
	-- @static
	-- @return `true` if successful, `nil` otherwise
	function BehaviourTree.save(
			bt, -- the tree which to save
			name -- name under which to save, must not contain path-illegal characters
		)
		local text = JSON:encode(bt, nil, { pretty = true, indent = "\t" })
		
		local path, msg = ProjectManager.findFile(behavioursContentType, name)
		if(not path)then
			return nil, msg
		end
		
		Spring.CreateDir(path:match("^(.+)/"))
		local file = io.open(path, "w")
		if(not file)then
			return nil
		end
		file:write(text)
		file:close()
		
		return true
	end
	--- Alias to @{BehaviourTree.save}
	-- @function Save
	-- @param name See @{BehaviourTree.save}
	-- @set no_return_or_parms=false -- unfortunately doesn't work
	treePrototype.Save = BehaviourTree.save

	
	makeNodeMetatable = function(tree, properties)
		--- Represents a single node of @{BehaviourTree}
		-- @type Node
		-- @static
		local nodePrototype = {}
		
		--- Removes the node from its tree.
		-- Any nodes below this node get added to the `additionalNodes` list.
		function nodePrototype:Remove()
			if(not removeItem(tree.additionalNodes, self))then error("Only disconnected nodes can be removed.") end

			for _, child in ipairs(self.children) do
				table.insert(tree.additionalNodes, child)
			end
			tree.properties[self.id] = nil
		end

		--- Connect the node to another, making it its child
		function nodePrototype:Connect(
				toNode -- node to which to connect
			)
			self.children = self.children or {}
			if(not removeItem(tree.additionalNodes, toNode))then error("Cannot connect to a node that is already a child of another node.") end
			table.insert(self.children, toNode)
		end

		--- Disconnects the node from its child.
		function nodePrototype:Disconnect(
				fromNode -- the child node from which to disconnect
			)
			if(not removeItem(self.children, fromNode))then error("Attempt to disconnect from a node that is not a child") end
			table.insert(tree.additionalNodes, fromNode)
		end

		local nodeMetatable = {
			__index = function(self, key)
				return nodePrototype[key] or properties[key]
			end,
			__newindex = properties,
		}
		
		--- Directly stored fields.
		-- 
		-- Whenever any other name is accessed (get or set), it is routed to the `properties` field of @{BehaviourTree} under the `id` of the current node.
		--
		-- @table Node.
		-- @tfield string id ID of the node
		-- @tfield string nodeType specifies the type of the @{Node}.
		-- @tfield {Parameter,...} parameters list of parameters containing their `name`s and `value`s.
		-- @tfield {Node,...} children list of current children of the node
		
		return nodeMetatable
	end
	
	return BehaviourTree
end)
