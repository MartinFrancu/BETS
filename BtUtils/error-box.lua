---
-- @module ErrorBox

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils
return Utils:Assign("ErrorBox", function()
	local ErrorBox = {}
	
	local Chili = Utils.Chili
	local ChiliRoot = Chili.Screen0
	
	local Debug = Utils.Debug
	local Logger = Debug.Logger
	
	local function extractLine(text)
		local result = { text = text }
		result.source, result.line = text:match("^%[string \"([^]]*)\"%]:(%d+): (.*)$")
		return result
	end
	local function extractTraceback(traceback)
		local result, i = {}, 1
		for line in traceback:gsub(".*stack traceback:\n", ""):gmatch("(.-)\n") do
			result[i] = extractLine(line)
			i = i + 1
		end
		return result
	end
	
	function ErrorBox.capture(err, level, cutoff)
		cutoff = cutoff or "ErrorBox.pcall"
		return {
			message = err,
			stack = extractTraceback(debug.traceback("", (level or 1) + 1)),
		}
	end
	
	function ErrorBox.pcall(f, ...)
		local args = {...}
		return xpcall(function()
			return f(unpack(args))
		end, ErrorBox.capture)
	end
	
	function ErrorBox.create(err, parameters)
		parameters = parameters or {}
		if(type(err) == "string")then
			err = {
				message = err:match("(.*)\nstack traceback:"),
				stack = extractTraceback(err),
			}
		end
		
		local errorPanel = Chili.Panel:New{
			parent = parameters.parent,
			width = 500,
			skinName = 'DarkGlass',
			OnMouseDown = { function(self) self:BringToFront() end }
		}
		local w, y = 0, 0
		local message = Chili.Label:New{
			parent = errorPanel,
			autosize = true,
			x = 0,
			y = y,
			caption = err.message,
		}
		WG.w = {}
		w = math.max(w, message.width)
		table.insert(WG.w, w)
		y = y + message.height
		for i, v in ipairs(err.stack) do
			local message = Chili.Label:New{
				parent = errorPanel,
				autosize = true,
				x = 0,
				y = y,
				caption = v.text,
			}
			message:UpdateLayout()
			w = math.max(w, message.width)
		table.insert(WG.w, w)
			y = y + message.height
		end
		errorPanel:SetPos(nil, nil, w, y)
		
		return errorPanel
	end
	
	return ErrorBox
end)
