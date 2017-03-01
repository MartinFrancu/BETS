return function(toWhat)
	local center = (Sensors.groupExtents() or {}).center
	if(not center)then
		return nil;
	end
	return math.sqrt((center.x - toWhat.x) * (center.x - toWhat.x) + (center.z - toWhat.z) * (center.z - toWhat.z))
end