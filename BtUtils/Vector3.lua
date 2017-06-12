--- Rudimentary 3D vector implementation with some 2D functionality.
-- Altered (as in functional) version of a library @{Vector3}.
-- @author Gordon MacPherson
-- @classmod Vec3
-- @alias vector_prototype

-- A 3D Vector Library.
-- By Gordon MacPherson with the assistance of google and sir divran! :L
-- Licence: CC-SA 3.0

-- changes by: Michal Mojzík
--   - adapted to be compatible BtUtils by
--   - fixed methods to belong into the __index lookup table rather than the metatable itself
--   - added LengthSqr
--   - changed Normalize to alter the current instance
--   - added return self to the various arithemtic operations
--   - disabled querying of the metatable from the outside

local type = type
local sin = math.sin
local cos = math.cos
local atan2 = math.atan2
local deg = math.deg
local rad = math.rad

-- Meta table.
local vector_prototype = {}
local vector_mt = { __index = vector_prototype }
vector_mt.__metatable = false -- disable accessing of the metatable

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

--- Multiplies the vector by the given number in-place.
-- @return `self`
function vector_prototype:Mul( n )
	self.x = self.x * n
	self.y = self.y * n
	self.z = self.z * n
	return self
end

--- Sets the current instance to zeros.
-- @return `self`
function vector_prototype:Zero()
	self.x = 0
	self.y = 0
	self.z = 0
	return self
end

--- Computes the square length of the vector.
function vector_prototype:LengthSqr()
	return ( ( self.x * self.x ) + ( self.y * self.y ) + ( self.z * self.z ) )
end

--- Computes the length of the vector.
function vector_prototype:Length()
	return self:LengthSqr() ^ 0.5
end

-- This should really be named get normalised copy.
--- Returns normalized copy of the vector.
-- @treturn Vec3
function vector_prototype:GetNormal()
	local length = self:Length()
	return new( self.x / length, self.y / length, self.z / length )
end

-- Redirect for people doing it wrong.
--- Alias to @{Vector:GetNormal}
function vector_prototype:GetNormalized()
	return self:GetNormal()
end

--- Normalizes the vector in-place.
-- @return `self`
function vector_prototype:Normalize()
	local length = self:Length()
	return self:Mul(1 / length)
end

--- Computes a dot product with another vector.
-- @tparam Vec3 vector The other vector.
function vector_prototype:DotProduct( vector )
	return (self.x  * vector.x) + (self.y * vector.y) + (self.z * vector.z)
end

-- Redirect for people doing it wrong.
--- Alias to @{Vector:DotProduct}
-- @param See @{Vector:DotProduct}
function vector_prototype:Dot( vector )
	return self:DotProduct( vector )
end

--- Computes the cross product with another vector.
-- @tparam Vec3 vector The other vector.
-- @treturn Vec3 The cross product.
function vector_prototype:Cross( vector )
	local vec = new(0,0,0)
	vec.x = ( self.y * vector.z ) - ( vector.y * self.z )
	vec.y = ( self.z * vector.x ) - ( vector.z * self.x )
	vec.z = ( self.x * vector.y ) - ( vector.x * self.y )
	return vec
end

--- Computes the distance between two vectors.
-- @tparam Vec3 vector The other vector.
function vector_prototype:Distance( vector )
	local vec = self - vector
	return vec:Length()
end

--- Convert vector in 2D heading in degrees between 0-360
-- @treturn number Angle in X-Z plane.
function vector_prototype:ToHeading() -- azimuth
	local angleInRads = atan2(self.x, self.z)
	-- angleInRads
	-- N (north) = PI
	-- E (east)  = 0.5PI
	-- S (south) = 0
	-- W (west)  = 1.5PI
	return ((deg(-angleInRads) + 180) % 360) -- correction to azimuth values = so 0 degrees is on north and positive increment is clockwise
	-- returned angle
	-- N (north) = 0
	-- E (east)  = 90
	-- S (south) = 180
	-- W (west)  = 270
end

--- Rotates vector around Y axis by given angle in degrees in-place.
-- A mathematically correct variant = negative angle values implies clockwise rotation.
-- @tparam number angle Angle in X-Z plane.
-- @return `self`
function vector_prototype:Rotate2D(angle)
	local angleInRads = rad(-angle) -- inverted Z axis (it increases in "south" direction in Spring map notation
	local vec = new(0,0,0)
	vec.x = self.x * cos(angleInRads) - self.z * sin(angleInRads)
	vec.y = self.y
	vec.z = self.x * sin(angleInRads) + self.z * cos(angleInRads)
	return vec
end

--- Rotates vector around Y axis by given azimuth
function vector_prototype:RotateByHeading(angle)
	return self:Rotate2D(-angle) -- just rotation in opoosite direction than mathematic Rotate2D
end


--- Returns vector in the form that Spring expects.
-- @treturn {number} List of X, Y, Z coordinates
function vector_prototype:AsSpringVector()
	return { self.x, self.y, self.z }
end
  

return Vector3