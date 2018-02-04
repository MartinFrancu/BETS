moduleInfo = {
	name = "Orders",
	desc = "Currently issued orders",
	author = "PepeAmpere",
	date = "2017-11-03",
	license = "notAlicense",
	layer = -1,
	enabled = true
}

function widget:GetInfo()
	return moduleInfo
end


-- get madatory module operators
VFS.Include("modules.lua") -- modules table
VFS.Include(modules.attach.data.path .. modules.attach.data.head) -- attach lib module

-- get other madatory dependencies
attach.Module(modules, "stringExt")
Vec3 = attach.Module(modules, "vec3")

local spEcho = Spring.Echo
local spAssignMouseCursor = Spring.AssignMouseCursor
local spSetMouseCursor = Spring.SetMouseCursor
local spGetGroundHeight = Spring.GetGroundHeight
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitPosition = Spring.GetUnitPosition
local glColor = gl.Color
local glRect = gl.Rect
local glTexture	= gl.Texture
local glDepthTest = gl.DepthTest
local glBeginEnd = gl.BeginEnd
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glText = gl.Text
local glLineWidth = gl.LineWidth
local glLineStipple = gl.LineStipple
local glVertex = gl.Vertex
local GL_LINE_STRIP = GL.LINE_STRIP
local TextDraw = fontHandler.Draw
local max = math.max
local min = math.min

local vsx, vsy = gl.GetViewSizes()
local px = 3*vsx/4
local py = 3*vsy/4
local sizex = 140
local sizey = 24
local th = 14

local instances = {}

local function FindFirstAliveUnit(units)
	for i=1, #units do
		local thisUnitID = units[i]
		local newDead = Spring.GetUnitIsDead(thisUnitID)
		if (not newDead) then
			return thisUnitID
		end
	end
end

local function CreateInstance(instanceID, inputs, project, tree)		
	local orderPosition
	
	-- 1) take one named target position
	for k,v in pairs(inputs) do
		--Spring.Echo(k,v)
		if (type(v) == "table") then
			--Spring.Echo(k,v)
			if k == "targetPosition" then
				orderPosition = v	
				break
			end
		end
	end
	
	if (orderPosition == nil) then
		-- 2 take any vector
		for k,v in pairs(inputs) do
			if (type(v) == "table") then
				if v.x ~= nil then
					orderPosition = v
					break
				end
			end
		end
		
		if (orderPosition == nil) then
			-- 3 take position of first unit
			-- if (instances[instanceID] ~= nil and instances[instanceID].units ~= nil) then
				-- local firstUnit = FindFirstAliveUnit(instances[instanceID].units)
				-- local x,y,z = spGetUnitPosition(lastPointUnitID)
				-- orderPosition = Vec3(x,y,z)
			-- end
			
			-- 4 take position from any area
			-- TBD
		end
	end
	
	-- make new
	local treeNameWithoutProject = string.gsub(tree, project .. ".", "")
	if instances[instanceID] == nil then		
		instances[instanceID] = {
			orderPosition = orderPosition,
			project = project,
			tree = treeNameWithoutProject,
		}
	else
		if (orderPosition ~= nil) then
			instances[instanceID].orderPosition = orderPosition
		end
		instances[instanceID].namespaces = treeNameWithoutProject
	end
	
	-- Spring.Echo("instanceID", instanceID)
	-- Spring.Echo("inputs", inputs)
	-- Spring.Echo("project + tree", project, treeNameWithoutProject)
	-- for k,v in pairs(tree) do
		-- Spring.Echo(k,v)
		-- for o,p in pairs (v) do
			-- Spring.Echo(o,p)
		-- end
	-- end
end

local function UpdateUnits(instanceID, units)
	if instances[instanceID] == nil then
		instances[instanceID] = {
			units = units,
		}
	else
		instances[instanceID].units = units
	end
end

local function RemoveInstance(instanceID)
	instances[instanceID] = nil
end

function widget:Initialize()
	widgetHandler:RegisterGlobal('groupOrder_create', CreateInstance)
	widgetHandler:RegisterGlobal('groupOrder_updateUnits', UpdateUnits)
	widgetHandler:RegisterGlobal('groupOrder_remove', RemoveInstance)
end

function widget:GameFrame(n)
end

function widget:DrawWorld()
	for instanceKey, instanceData in pairs(instances) do
		local lastPointUnitID = instanceData.lastPointUnitID
		if (lastPointUnitID == nil) then
			if (instanceData.units ~= nil) then
				instanceData.lastPointUnitID = FindFirstAliveUnit(instanceData.units)
			end
		else
			local pointUnitDead = Spring.GetUnitIsDead(lastPointUnitID)
			--Spring.Echo(pointUnitDead)
			if (pointUnitDead == nil or pointUnitDead) then
				lastPointUnitID = FindFirstAliveUnit(instanceData.units)
				instanceData.lastPointUnitID = lastPointUnitID
			else				
				local x,y,z = spGetUnitPosition(lastPointUnitID)
				
				local currentOrderPosition
				
				if (instanceData.orderPosition == nil and lastPointUnitID ~= nil) then
					currentOrderPosition = Vec3(x,y,z)
				else
					currentOrderPosition = instanceData.orderPosition
				end
				
				if (currentOrderPosition ~= nil) then
					local function Line(a, b)
						glVertex(a[1], a[2], a[3])
						glVertex(b[1], b[2], b[3])
					end
					
					local function DrawLine(a, b)
						glLineStipple(false)
						glLineWidth(5)
						glBeginEnd(GL_LINE_STRIP, Line, a, b)
						glLineStipple(false)
					end
					
					glColor(1, 0, 0, 0.2)
					
					DrawLine({x,y,z}, currentOrderPosition:AsSpringVector())
				end
				
				function DrawIcon(name, orderX, orderY, orderZ, sizeX, sizeZ)
					gl.PushMatrix()
					gl.Texture(":n:LuaUI/BETS/Projects/" .. name)
					gl.Translate(orderX-sizeX/2, orderY+10, orderZ+sizeZ/2)
					gl.Billboard()			
					gl.TexRect(sizeX, sizeZ, 0, 0, true, true)
					gl.PopMatrix()
				end
				
				glColor(1, 0, 0, 0.6)	
				
				local orderX, orderY, orderZ = currentOrderPosition.x, currentOrderPosition.y, currentOrderPosition.z
				DrawIcon(instanceData.project .. "/Behaviours/".. instanceData.tree ..".png", orderX, orderY, orderZ, 64, 64)
				
			end			
		end
	end
	glColor(1, 0, 0, 1)
end