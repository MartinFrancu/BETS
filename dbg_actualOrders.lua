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

--[[
-- get madatory module operators
VFS.Include("LuaRules/modules.lua") -- modules table
VFS.Include(modules.attach.data.path .. modules.attach.data.head) -- attach lib module

-- get other madatory dependencies
attach.Module(modules, "tableExt")
]]--

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

local function CreateInstance(instanceID, inputs, units)		
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
			-- 3 take position from any area
			-- TBD
		end
	end
	
	
	
	-- make new
	if instances[instanceID] == nil then
		instances[instanceID] = {
			orderPosition = orderPosition,
		}
	else
		instances[instanceID].units = units
		if (orderPosition ~= nil) then
			instances[instanceID].orderPosition = orderPosition
		end
	end
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

local function FindFirstAliveUnit(units)
	for i=1, #units do
		local thisUnitID = units[i]
		local newDead = Spring.GetUnitIsDead(thisUnitID)
		if (not newDead) then
			return thisUnitID
		end
	end
end

function widget:Initialize()
	widgetHandler:RegisterGlobal('groupOrder_create', CreateInstance)
	widgetHandler:RegisterGlobal('groupOrder_updateUnits', UpdateUnits)
	widgetHandler:RegisterGlobal('groupOrder_updateInputs', CreateInstance)
	widgetHandler:RegisterGlobal('groupOrder_remove', RemoveInstance)
end

function widget:GameFrame(n)
end

function widget:DrawWorld()
	glColor(1, 0, 0, 0.2)
	for instanceKey, instanceData in pairs(instances) do
		if instanceData.orderPosition ~= nil then
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
			
			local lastPointUnitID = instanceData.lastPointUnitID
			if (lastPointUnitID == nil) then
				instances[instanceKey].lastPointUnitID = FindFirstAliveUnit(instanceData.units)
			else
				local pointUnitDead = Spring.GetUnitIsDead(lastPointUnitID)
				--Spring.Echo(pointUnitDead)
				if (pointUnitDead == nil or pointUnitDead) then
					lastPointUnitID = FindFirstAliveUnit(instanceData.units)
					instances[instanceKey].lastPointUnitID = lastPointUnitID
				end
				
				local x,y,z = spGetUnitPosition(lastPointUnitID)
					
				DrawLine({x,y,z}, instanceData.orderPosition:AsSpringVector())
			end
		end
	end
	glColor(1, 1, 1, 1)
end