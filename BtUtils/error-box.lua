---
-- @module ErrorBox

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils
return Utils:Assign("ErrorBox", function()
	local ErrorBox = {}
	
	local ProjectManager = Utils.ProjectManager
	
	local Debug = Utils.Debug
	local Logger = Debug.Logger
	
	local execute = os.execute -- this is inaccesible in Spring, its substitute can be set through ErrorBox.setExecuteFunction
	
	local function extractLine(text)
		local result = { text = text }
		result.source, result.line = text:match("^[ \t]*%[string \"([^]]*)\"%]:(%d+): (.*)$")
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
	
	local function showFile(path)
		execute("start notepad \"" .. path .. "\"")
	end
	
	local function createStackLine(params, file)
		params.autosize = true
		params.x = params.x or 0
		local path, p = nil, {} -- = ProjectManager.findFile(file)
		if(not p.exists)then path = file end
		if(path)then
			local previousFontColor
			params.OnMouseOver = { function(self)
				if(not previousFontColor)then
					previousFontColor = self.font.color
				end
				self.font.color = {1,1,0,1}
				self:Invalidate()
				return self
			end }
			params.OnMouseOut = { function(self)
				if(previousFontColor)then
					self.font.color = previousFontColor
					previousFontColor = nil
				end
				self:Invalidate()
				return self
			end }
			params.OnMouseDown = { function(self) return self end }
			params.OnMouseUp = { function(self)
				showFile(path)
			end }
		end
		local label = Utils.Chili.Label:New(params)
		label:UpdateLayout()
		return label
	end
	
	function ErrorBox.create(err, parameters)
		parameters = parameters or {}
		if(type(err) == "string")then
			err = {
				message = err:match("(.*)\nstack traceback:"),
				stack = extractTraceback(err),
			}
		end
		
		local errorPanel = Utils.Chili.Panel:New{
			parent = parameters.parent,
			width = 500,
			skinName = 'DarkGlass',
			OnMouseDown = { function(self) self:BringToFront() end }
		}
		local w, y = 0, 0
		local message = createStackLine{
			parent = errorPanel,
			y = y,
			caption = err.message,
		}
		WG.w = {}
		w = math.max(w, message.width)
		table.insert(WG.w, w)
		y = y + message.height
		for i, v in ipairs(err.stack) do
			local message = createStackLine({
				parent = errorPanel,
				y = y,
				caption = v.text,
			}, v.source)
			w = math.max(w, message.width)
		table.insert(WG.w, w)
			y = y + message.height
		end
		errorPanel:SetPos(nil, nil, w, y)
		
		return errorPanel
	end
	
	function ErrorBox.setExecuteFunction(f)
		execute = f
	end
	function ErrorBox.removeExecuteFunction(f)
		if(execute == f)then
			execute = nil
		end
	end
	
	return ErrorBox
end)
