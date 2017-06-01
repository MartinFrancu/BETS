--- Allows scheduling of functions to be executed after an amount of time passes.
-- The timing is based on the `Update` call-in of widgets.
-- @module Timer
-- @pragma nostrip

-- tag @pragma makes it so that the name of the module is not stripped from the function names

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils
return Utils:Assign("Timer", function()
	local Timer = {}
	
	local Sanitizer = Utils.Sanitizer
	
	local Debug = Utils.Debug
	local Logger = Debug.Logger

	local function addItem(list, item)
		list.length = (list.length or 0) + 1
		list[list.length] = item
	end
	local function removeItem(list, item)
		for i = 1, (list.length or 0) do
			if(item == list[i])then
				list[i] = list[list.length]
				list[list.length] = nil
				list.length = list.length - 1
				return
			end
		end
	end
	
	local delayed = {}

	--- Delays the invocation of the function by one rendering frame.
	-- @func f Function to delay.
	function Timer.delay(f)
		addItem(delayed, Sanitizer.sanitize(f));
	end
	
	local activeInjectionList = {}
	
	local function updateInvocation(injectionId)
		-- only invoke the delayed function from one of the injected widgets
		if(activeInjectionList[1] == injectionId)then
			for i = 1, (delayed.length or 0) do
				delayed[i]()
			end
			delayed = {}
		end
	end

	local injectionIdCounter = 0;
	--- Injects a widget, allowing Timer to utilize its call-in for its functionality.
	-- At least one widget has to be injected in order for the rest of @{Timer} to work.
	-- @tparam widget widget The widget to inject.
	-- @remark If the user intends to utilize @{Timer} in any way, it should inject itself.
	function Timer.injectWidget(widget)
		local oldUpdate = widget.Update;
		local injectionId = injectionIdCounter
		injectionIdCounter = injectionIdCounter + 1
		addItem(activeInjectionList, injectionId)
		if(oldUpdate)then
			function widget:Update()
				updateInvocation(injectionId)
				
				return oldUpdate()
			end
		else
			function widget:Update()
				updateInvocation(injectionId)
			end
		end
		
		local oldShutdown = widget.Shutdown
		function widget:Shutdown()
			removeItem(activeInjectionList, injectionId)
		
			if(oldShutdown)then
				return oldShutdown(self)
			end
		end
	end
	
	return Timer
end)
