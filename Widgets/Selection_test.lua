function widget:GetInfo ()
	return {
		name = "BETS - Unit selection detector",
		desc = "Prints number of selected units.",
		author = "Oskar Hybl",
		date = "today",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true
	}
end


function widget:Initialize ()
	Spring.Echo ("Selection test initialized.")
end

function UnitSelectionChange (units)
	Spring.Echo ("Number of selected units: " .. #units)
	selectedUnitsStr = ""
	for i=1, #units do
		if i ~= 1 then
			selectedUnitsStr = selectedUnitsStr .. ", "
		end
		selectedUnitsStr = selectedUnitsStr .. units[i]
	end
	Spring.Echo ("IDs: " .. selectedUnitsStr)
end

-- compare value by value
function equal (fst, snd)
	if #fst ~= #snd then
		return false
	end

	for i=1, #fst do
		if fst[i] ~= snd[i] then
			return false
		end
	end

	return true
end

local oldUnits = {}

function widget:Update (dt)
	newUnits = Spring.GetSelectedUnits()
	if not equal (oldUnits, newUnits) then 
		oldUnits = newUnits
		UnitSelectionChange (newUnits)
	end
end



