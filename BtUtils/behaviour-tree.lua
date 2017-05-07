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
	
	local behavioursContentType = ProjectManager.makeRegularContentType("Behaviours", "json")
	BehaviourTree.contentType = behavioursContentType
	
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
		bt.roles = {}
		bt.inputs = {}
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
			referenceInputs = params.referenceInputs,
			referenceOutputs = params.referenceOutputs,
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

	--- Add all nodes from the other tree to the current one.
	-- @tparam BehaviourTree other The other tree.
	-- @func f Optional, function that is to be applied to each node of the other tree before it is combined, e.g. ID changes.
	-- @treturn Node The original root of the other tree.
	function treePrototype:Combine(other, f)
		if(f)then
			other:Visit(f)
		end
		
		local otherRoot = other.root
		local n = table.getn(self.additionalNodes) + 1
		self.additionalNodes[n] = otherRoot
		for i, v in ipairs(other.additionalNodes) do
			n = n + 1
			self.additionalNodes[n] = v
		end
		
		for k, v in pairs(other.properties) do
			self.properties[k] = v
		end
		
		other.root = nil
		other.additionalNodes = {}
		other.properties = {}
		
		return otherRoot
	end

	-- implementation of BehaviourTree:Visit
	local function visit(f, node)
		if(not node) then
			return
		end
		
		local results = { f(node) }
		if(results[1] ~= nil)then
			return results
		end
		
		for _, child in ipairs(node.children) do
			local results = visit(f, child)
			if(results and results[1] ~= nil)then
				return results
			end
		end
	end
	
	--- Invokes the given function on all nodes of the tree depth-first.
	-- The traversing of the tree is terminated early if the function returns something.
	-- @func f The function that is to be invoked for every node.
	-- @return Whatever the function `f` returned along the way, or `nil`
	function treePrototype:Visit(f)
		return unpack(visit(f, self.root) or {})
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
	
	local function validateRoles(roles)
		if(type(roles) ~= "table")then
			return false, "Slot 'roles' must be a table."
		end
	
		if(not roles[1])then
			return false, "At least one role must be defined."
		end
		for i, v in ipairs(roles) do
			if(type(v.categories) ~= "table")then
				return false, tostring(i) .. "-th role 'categories' slot is not a table."
			end
			if(type(v.name) ~= "string")then
				return false, tostring(i) .. "-th role 'name' slot is not a string."
			end
		end
		return true
	end
	local validCommandNames = {
		["BETS_POSITION"] = true,
		["BETS_UNIT"] = true,
		["BETS_AREA"] = true,
		["Variable"] = true,
	}
	local function validateInputs(inputs)
		if(type(inputs) ~= "table")then
			return false, "Slot 'inputs' must be a table."
		end
	
		for i, v in ipairs(inputs) do
			if(not validCommandNames[v.command])then
				return false, tostring(i) .. "-th input 'command' slot is not a valid value."
			end
			if(type(v.name) ~= "string")then
				return false, tostring(i) .. "-th input 'name' slot is not a string."
			end
		end
		return true
	end
	local function validateOutputs(outputs)
		if(type(outputs) ~= "table")then
			return false, "Slot 'outputs' must be a table."
		end
	
		for i, v in ipairs(outputs) do
			if(type(v.name) ~= "string")then
				return false, tostring(i) .. "-th output 'name' slot is not a string."
			end
		end
		return true
	end
	
	--- Loads a previously saved tree.
	-- @static
	-- @treturn BehaviourTree loaded tree if found, `nil` otherwise
	function BehaviourTree.load(
			name -- name under which to look for the tree
		)
		
		local path, parameters = ProjectManager.findFile(behavioursContentType, name)
		if(not path)then
			return nil, parameters
		end
		
		local data = VFS.LoadFile(path)
		if(not data)then
			return nil, "[BT:" .. name .. "] " .. "File '" .. path .. "' not found"
		end
		local bt = JSON:decode(data)
		
		bt.roles = bt.roles or {}
		bt.inputs = bt.inputs or {}
		bt.outputs = bt.outputs or {}
		bt.additionalNodes = bt.additionalNodes or {}
		bt.properties = bt.properties or {}
		setmetatable(bt, treeMetatable)

		local success, message = validateRoles(bt.roles)
		if(success)then
			success, message = validateInputs(bt.inputs)
		end
		if(success)then
			success, message = validateOutputs(bt.outputs)
		end
		if(not success)then
			return nil, "[BT:" .. name .. "] " .. tostring(message)
		end
		
		if not bt.root then
			local root = bt:NewNode({id = "rootId", nodeType = "empty_tree"})
			bt:SetRoot(root)
		end
		load_setupNode(bt, bt.root)
		for _, node in ipairs(bt.additionalNodes) do
			load_setupNode(bt, node)
		end
		bt.project = parameters.project
		
		return bt
	end

	--- Saves the tree under the specified name.
	-- @static
	-- @return `true` if successful, `nil` otherwise
	function BehaviourTree.save(
			bt, -- the tree which to save
			name -- name under which to save, must not contain path-illegal characters
		)
		local success, message = validateRoles(bt.roles)
		if(success)then
			success, message = validateInputs(bt.inputs)
		end
		if(success)then
			success, message = validateOutputs(bt.outputs)
		end
		if(not success)then
			return nil, "[BT:" .. name .. "] " .. tostring(message)
		end
		
		local temp = bt.project
		bt.project = nil
		local text = JSON:encode(bt, nil, { pretty = true, indent = "\t" })
		bt.project = temp
		
		local path, parameters = ProjectManager.findFile(behavioursContentType, name)
		if(not path)then
			return nil, parameters
		end
		
		if(parameters.readonly)then
			return nil, "Behaviour " .. tostring(name) .. " is read-only."
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

		--- Changes the ID of the node.
		-- This has to be used over simply changing the value of the `id` slot in order to properly transfer the additional properties of the node.
		function nodePrototype:ChangeID(newId)
			tree.properties[newId] = tree.properties[self.id]
			tree.properties[self.id] = nil
			self.id = newId
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
