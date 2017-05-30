function getInfo()
	return {
		period = 60, -- it is expected that we would not need completely up-to-date information
	}
end
 
return function()
	local teamID = Spring.GetLocalTeamID() -- extract the teamID of the current player
	if(not teamID)then
		return nil
	end
	
	return Spring.GetTeamUnitCount(0)
end
