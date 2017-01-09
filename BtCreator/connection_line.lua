
local connectionLine

WG.BtConnectionLine = WG.BtConnectionLine or (function()
	if(not connectionLine) then 
		local Chili
		
		local connectionLines = {}
		
		local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
		local Debug = Utils.Debug;
		local Logger, dump, copyTable, fileTable = Debug.Logger, Debug.dump, Debug.copyTable, Debug.fileTable
		
		local arrowWhite				 	= LUAUI_DIRNAME .. "Widgets/BtCreator/arrow_white.png"
		local arrowWhiteFlipped		= LUAUI_DIRNAME .. "Widgets/BtCreator/arrow_white_flipped.png"
		local arrowOrange				 	= LUAUI_DIRNAME .. "Widgets/BtCreator/arrow_orange.png"
		local arrowOrangeFlipped	= LUAUI_DIRNAME .. "Widgets/BtCreator/arrow_orange_flipped.png"
		
		Logger.log("connection-lines", "connection_line.lua Singleton creation. ")
		
		connectionLine = {
		
			initialize = function()
				Chili = WG.ChiliClone
				Logger.log("connection-lines", "connectionLine.initialize()")
			end,
			
			--- Removes all the connection lines from canvas. connectionLines table is empty afterwards.
			clear = function()
				for i=#connectionLines,1,-1 do
					for k=2,5 do
						connectionLines[i][k]:Dispose()
					end
					table.remove(connectionLines, i)
				end
			end,
			
			computeCoordinates = function(connectionOut, connectionIn)
				local transparentBorderWidth = 5
				local lineOutx = connectionOut.parent.x + connectionOut.x + 2
				local lineOuty = connectionOut.parent.y + connectionOut.y
				local halfDistance = math.ceil(math.abs(connectionIn.parent.x - connectionOut.parent.x - connectionOut.x)*0.5)
				local lineVx   = lineOutx+halfDistance - transparentBorderWidth
				local lineInx  = connectionIn.parent.x - halfDistance + transparentBorderWidth - 2
				local lineIny  = connectionIn.parent.y + connectionIn.y
				if(connectionOut.x+connectionOut.parent.x > connectionIn.parent.x) then
					lineOutx = connectionOut.parent.x + connectionOut.x + 1 - halfDistance
					lineInx  = connectionIn.parent.x + transparentBorderWidth - 1
					lineVx   = lineOutx - transparentBorderWidth + 1
				end
				return lineOutx, lineOuty, halfDistance, lineVx, lineInx, lineIny, transparentBorderWidth
			end,
			
			--- Returns local table connectionLines, should be immutable! so beware, do not change it.
			getAll = function()
				Logger.log("connection-lines", "connectionLines.getAll(), connectionLines:"..dump(connectionLines, 2))
				return connectionLines
			end,
			
			add = function(connectionOut, connectionIn)
				if (connectionOut.treeNode.connectionIn and connectionOut.name == connectionOut.treeNode.connectionIn.name) then
					connectionLine.add(connectionIn, connectionOut)
					return
				end
				-- if root node is to be connected, then remove all the existing connections, so there is only one connectionLine going from root
				if (connectionOut.treeNode.nodeType == "Root") then
					for i=1,#connectionLines do
						if (connectionLines[i][1].treeNode.nodeType == "Root") then
							connectionLine.remove(i)
							break
						end
					end
				end
				
				local lineIndex = (#connectionLines + 1)
				local lineOutx,lineOuty,halfDistance,lineVx,lineInx,lineIny,transparentBorderWidth = connectionLine.computeCoordinates(connectionOut, connectionIn)
				local lineOut = Chili.Line:New{ 
					parent = connectionOut.parent.parent,
					width = halfDistance,
					height = 1,
					x = lineOutx,
					y = lineOuty,
					skinName = 'default',
					borderColor = {0.6,0.6,0.6,1},
					borderColor2 = {0.4,0.4,0.4,1},
					borderThickness = 2,
					padding = {0, 0, 0, 0},
					onMouseDown = { connectionLine.listenerClickOnConnectionLine },
					onMouseOver = { connectionLine.listenerOverConnectionLine },
					onMouseOut = { connectionLine.listenerOutOfConnectionLine },
					lineIndex = lineIndex,
				}
				local lineIn = Chili.Line:New{
					parent = connectionOut.parent.parent,
					width = halfDistance,
					height = 1,
					x = lineInx,
					y = lineIny,
					skinName = 'default',
					borderColor = {0.6,0.6,0.6,1},
					borderColor2 = {0.4,0.4,0.4,1},
					borderThickness = 2,
					padding = {0, 0, 0, 0},
					onMouseDown = { connectionLine.listenerClickOnConnectionLine },
					onMouseOver = { connectionLine.listenerOverConnectionLine },
					onMouseOut = { connectionLine.listenerOutOfConnectionLine },
					lineIndex = lineIndex,
				}
				local lineV = Chili.Line:New{
					parent = connectionOut.parent.parent,
					width = 5,
					height = math.abs(lineOuty-lineIny),
					minHeight = 0,
					x = lineVx,
					y = math.min(lineOuty,lineIny)+transparentBorderWidth,
					style = "vertical",
					skinName = 'default',
					borderColor = {0.6,0.6,0.6,1},
					borderColor2 = {0.4,0.4,0.4,1},
					borderThickness = 2,
					padding = {0, 0, 0, 0},
					onMouseDown = { connectionLine.listenerClickOnConnectionLine },
					onMouseOver = { connectionLine.listenerOverConnectionLine },
					onMouseOut = { connectionLine.listenerOutOfConnectionLine },
					lineIndex = lineIndex,
				}
				local arrow = Chili.Image:New{
					parent = connectionOut.parent.parent,
					x = lineInx + halfDistance - 8,
					y = lineIny + 1,
					file = arrowWhite,
					width = 5,
					height = 8,
					lineIndex = lineIndex,
					onMouseDown = { connectionLine.listenerClickOnConnectionLine },
					onMouseOver = { connectionLine.listenerOverConnectionLine },
					onMouseOut = { connectionLine.listenerOutOfConnectionLine },
				}
				if(lineVx > lineInx) then
					arrow.x = math.min(lineInx + 8, lineInx + halfDistance - 8)
					arrow.file = arrowWhiteFlipped
					arrow.flip = true
				else
					arrow.file = arrowWhite
					arrow.x = lineInx + halfDistance - 8
					arrow.flip = false
				end
				table.insert( connectionLines, {connectionOut, lineOut, lineV, lineIn, arrow, connectionIn} )
				table.insert( connectionIn.treeNode.attachedLines,  lineIndex )
				table.insert( connectionOut.treeNode.attachedLines, lineIndex )
				
				Logger.log("connection-lines", "connectionLines.add(), #connectionLines="..#connectionLines..", connectionLines after:"..dump(connectionLines, 2))
			end,
			
			exists = function(connection1, connection2)
				for i=1,#connectionLines do
					if(connectionLines[i][1].name == connection1.name and connectionLines[i][6].name == connection2.name) then
						return true
					end
					if(connectionLines[i][6].name == connection1.name and connectionLines[i][1].name == connection2.name) then
						return true
					end
				end
				return false
			end,
			
			--- Updates location of connectionLine on given index. 
			update = function(index)
				--Logger.log("connection-lines", "connectionLine.update(index="..index.."), #connectionLines:"..#connectionLines..", connectionLines="..dump(connectionLines, 2))
				if(#connectionLines < index) then
					error("connectionLine.update(index) called with index="..index..", which is larger than #connectionLines="..#connectionLines.."\n"..debug.traceback())
				end
				local connectionOut = connectionLines[index][1]
				local connectionIn = connectionLines[index][#connectionLines[index]]
				local lineOutx,lineOuty,halfDistance,lineVx,lineInx,lineIny,transparentBorderWidth = connectionLine.computeCoordinates(connectionOut, connectionIn)
				local lineOut = connectionLines[index][2]
				local lineV = connectionLines[index][3]
				local lineIn = connectionLines[index][4]
				local arrow = connectionLines[index][5]
				lineOut.width = halfDistance
				lineOut.x = lineOutx
				lineOut.y = lineOuty
				lineIn.width = halfDistance
				lineIn.x = lineInx
				lineIn.y = lineIny
				lineV.height = math.abs(lineOuty-lineIny)
				lineV.x = lineVx
				lineV.y = math.min(lineOuty,lineIny)+transparentBorderWidth
				if(lineVx > lineInx) then
					arrow.x = math.min(lineInx + 8, lineInx + halfDistance - 8)
					arrow.file = arrowWhiteFlipped
					arrow.flip = true
				else
					arrow.file = arrowWhite
					arrow.x = lineInx + halfDistance - 8
					arrow.flip = false
				end
				arrow.y = lineIny + 1
				for i=2,5 do
					connectionLines[index][i]:RequestUpdate()
				end
			end,
			
			--- Remove connectionLine with given index from global connectionLines table. All the connectionLines with larger
			-- indexes decrements its index by one, so the indexes in attachedLines field and lineIndex are decremented by one. 
			remove = function(index)
				for i=2,5 do
					connectionLines[index][i]:Dispose()
				end
				local found = false
				local foundIndex
				for j=1,#connectionLines[index][1].treeNode.attachedLines do
					if (connectionLines[index][1].treeNode.attachedLines[j] == index) then
						found = true
						foundIndex = j
						break
					end
				end
				if (found) then
					table.remove(connectionLines[index][1].treeNode.attachedLines, foundIndex)
				else
					error("connectionLine.remove(index="..index.."), Line index not found in connectionOut panel, in removeConnectionLine(). "..debug.traceback())
				end
				
				found = false
				foundIndex = nil
				for k=1,#connectionLines[index][6].treeNode.attachedLines do
					if (connectionLines[index][6].treeNode.attachedLines[k] == index) then
						found = true
						foundIndex = k
						break
					end
				end
				if (found) then  
					table.remove(connectionLines[index][6].treeNode.attachedLines, foundIndex)
				else
					error("connectionLine.remove(index="..index.."), Line index not found in connectionOut panel, in removeConnectionLine(). "..debug.traceback())
				end
				table.remove(connectionLines, index)
				-- We deleted an entry from connectionLines. So all the indices which are after the lineIndex
				-- needs to be decremented by one. Also the lineIndex field in Chili.Line needs to be updated. 
				for i=index,#connectionLines do
					local attachedLines1 = connectionLines[i][1].treeNode.attachedLines
					local attachedLines2 = connectionLines[i][6].treeNode.attachedLines
					for k=1,#attachedLines1 do
						if (attachedLines1[k] == i+1) then 
							attachedLines1[k] = i
						end
					end
					for k=1,#attachedLines2 do
						if (attachedLines2[k] == i+1) then 
							attachedLines2[k] = i
						end
					end
					for k=2,4 do
						connectionLines[i][k].lineIndex = i
					end
				end
				Logger.log("connection-lines", "connectionLine.remove(), connectionLines after:"..dump(connectionLines, 2))
				return true
			end,
			
			--//=============================================================================
			--// Listeners on Connection lines
			--//=============================================================================
			listenerOverConnectionLine = function(self)
				local lineIndex = self.lineIndex
				for i=2,4 do
					connectionLines[lineIndex][i].borderColor = {1,0.6,0.2,0.8}
					connectionLines[lineIndex][i].borderColor2 = {1,0.6,0.2,0.8}
					connectionLines[lineIndex][i]:Invalidate()
					connectionLines[lineIndex][i]:RequestUpdate()
				end
				local oldArrow = connectionLines[lineIndex][5]
				local arrow = Chili.Image:New{
					parent = oldArrow.parent,
					x = oldArrow.x,
					y = oldArrow.y,
					flip = oldArrow.flip,
					file = arrowOrange,
					width = oldArrow.width,
					height = oldArrow.height,
					lineIndex = oldArrow.lineIndex,
					onMouseDown = { listenerClickOnConnectionLine },
					onMouseOver = { listenerOverConnectionLine },
					onMouseOut = { listenerOutOfConnectionLine },
				}
				if(arrow.flip) then
					arrow.file = arrowOrangeFlipped
				end
				connectionLines[lineIndex][5]:Dispose()
				connectionLines[lineIndex][5] = arrow
				return self
			end,
			
			listenerOutOfConnectionLine = function(self)
				lineIndex = self.lineIndex
				for i=2,4 do
					connectionLines[lineIndex][i].borderColor = {0.6,0.6,0.6,1} 
					connectionLines[lineIndex][i].borderColor2 = {0.4,0.4,0.4,1}
					connectionLines[lineIndex][i]:Invalidate()
					connectionLines[lineIndex][i]:RequestUpdate()
				end
				local oldArrow = connectionLines[lineIndex][5]
				local arrow = Chili.Image:New{
					parent = oldArrow.parent,
					x = oldArrow.x,
					y = oldArrow.y,
					file = arrowWhite,
					flip = oldArrow.flip,
					width = oldArrow.width,
					height = oldArrow.height,
					lineIndex = oldArrow.lineIndex,
					onMouseDown = { listenerClickOnConnectionLine },
					onMouseOver = { listenerOverConnectionLine },
					onMouseOut = { listenerOutOfConnectionLine },
				}
				if(arrow.flip) then
					arrow.file = arrowWhiteFlipped
				end
				connectionLines[lineIndex][5]:Dispose()
				connectionLines[lineIndex][5] = arrow
			end,
			
			listenerClickOnConnectionLine = function(self)
				if(connectionLine.remove(self.lineIndex)) then
					return self
				end
				return
			end,
		}
	end
	return connectionLine
end)()

return WG.BtConnectionLine