return function(toWhat)
	local center = (Sensors.groupExtents() or {}).center
	if(not center)then
		return nil;
	end
	return math.sqrt((center.x - toWhat.posX) * (center.x - toWhat.posX) + (center.z - toWhat.posZ) * (center.z - toWhat.posZ))
end