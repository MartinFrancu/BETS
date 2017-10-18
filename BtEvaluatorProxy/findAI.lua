local foundAI = false
for _, ai in ipairs(VFS.GetAvailableAIs()) do
	if(ai.shortName == "BtEvaluator")then
		foundAI = true
		break
	end
end

return foundAI