-- A 3D Vector Library.
-- By Gordon MacPherson with the assistance of google and sir divran! :L

-- changes by: Michal Mojz�k
--   - adapted to be compatible BtUtils by
--   - fixed methods to belong into the __index lookup table rather than the metatable itself
--   - added LengthSqr
--   - changed Normalize to alter the current instance
--   - added return self to the various arithemtic operations

local type = type

-- Meta table.
local vector_prototype = {}
local vector_mt = { __index = vector_prototype }

-- Divran's idea.
local function new(x,y,z)
	return setmetatable( {x = x or 0, y = y or 0, z = z or 0} , vector_mt) 
end

local Vector3 = new

function vector_mt:__add( vector )
	return new( 
		self.x + vector.x,
		self.y + vector.y,
		self.z + vector.z 
	)
end

function vector_mt:__sub( vector )
	return new(
		self.x - vector.x,
		self.y - vector.y,
		self.z - vector.z 
	)
end

function vector_mt:__mul( vector )
	if type(vector) == "number" then
		return new(
			self.x * vector,
			self.y * vector,
			self.z * vector
		)
	else
		return new(
			self.x * vector.x,
			self.y * vector.y,
			self.z * vector.z 
		)
	end
end

function vector_mt:__div( vector )
	if type(vector) == "number" then
		return new(
			self.x / vector,
			self.y / vector,
			self.z / vector
		)
	else
		return new(
			self.x / vector.x,
			self.y / vector.y,
			self.z / vector.z 
		)
	end
end

--
-- Boolean operators
--

function vector_mt:__eq( vector )
	return self.x == vector.x and self.y == vector.y and self.z == vector.z
end

function vector_mt:__unm()
	return new(-self.x,-self.y,-self.z)
end

-- 
-- String Operators.
--

function vector_mt:__tostring()
	return "[" .. self.x .. "," .. self.y .. "," .. self.z .. "]"
end        

--
-- Vector operator functions.
--

-- TODO: this doesn't change the current instance (self is a private variable), fix
function vector_prototype:Add( vector )
	self = self + vector
	return self
end

-- TODO: this doesn't change the current instance (self is a private variable), fix
function vector_prototype:Sub( vector )
	self = self - vector
	return self
end

function vector_prototype:Mul( n )
	self.x = self.x * n
	self.y = self.y * n
	self.z = self.z * n
	return self
end

function vector_prototype:Zero()
	self.x = 0
	self.y = 0
	self.z = 0
	return self
end

function vector_prototype:LengthSqr()
	return ( ( self.x * self.x ) + ( self.y * self.y ) + ( self.z * self.z ) )
end

function vector_prototype:Length()
	return self:LengthSqr() ^ 0.5
end

-- This should really be named get normalised copy.
function vector_prototype:GetNormal()
	local length = self:Length()
	return new( self.x / length, self.y / length, self.z / length )
end

-- Redirect for people doing it wrong.
function vector_prototype:GetNormalized()
	return self:GetNormal()
end

function vector_prototype:Normalize()
	local length = self:Length()
	return self:Mul(1 / length)
end

function vector_prototype:DotProduct( vector )
	return (self.x  * vector.x) + (self.y * vector.y) + (self.z * vector.z)
end

-- Redirect for people doing it wrong.
function vector_prototype:Dot( vector )
	return self:DotProduct( vector )
end

-- Cross Product.
function vector_prototype:Cross( vector )
	local vec = new(0,0,0)
	vec.x = ( self.y * vector.z ) - ( vector.y * self.z )
	vec.y = ( self.z * vector.x ) - ( vector.z * self.x )
	vec.z = ( self.x * vector.y ) - ( vector.x * self.y )
	return vec
end

-- Returns the distance between two vectors.
function vector_prototype:Distance( vector )
	local vec = self - vector
	return vec:Length()
end

--[[
-- Returns a garry vector for his functions.
function vector_mt:Garry()
	return Vector( self.x, self.y, self.z )
end
]]

-- If by any chance my vector library doesn't have a specific function
-- you can simply uncomment this and use garrys!
--local garry = FindMetaTable( "Vector" )
--function vector_mt:__index( key ) 
--	if vector_prototype[key] ~= nil then 
--		return vector_prototype[key] 
--	else
--		return garry[key] 
--	end
--end


--[[
	To be added if I want this as a direct replacement.
	However I feel 2D vectors should be made as there own type.

	Vector:Length2D -- Will be Vector2:Length2D()
	Vector:Length2DSqr -- Not Added.
	Vector:LengthSqr -- Not Added.
	Vector:Rotate -- Should exist when angle and quaternions are done.
]]


function vector_prototype:AsSpringVector()
	return { self.x, self.y, self.z }
end
  

return Vector3