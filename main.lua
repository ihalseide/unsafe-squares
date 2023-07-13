-- Bomp-Scanner, a game like minesweeper
-- Written for Love2d


require "queue"


CHEATS = true
theFieldTileSize = 32

	
function love.load()
	love.math.setRandomSeed(1)

	sheet = love.graphics.newImage("sheet.png")
	
	tiles = {
		unknown = newGridQuad(0, 0, sheet),
		known = newGridQuad(1, 0, sheet),
		mine = newGridQuad(0, 1, sheet),
    flag = newGridQuad(1, 1, sheet),
    ['1'] = newGridQuad(0, 2, sheet),
    ['2'] = newGridQuad(1, 2, sheet),
    ['3'] = newGridQuad(2, 2, sheet),
    ['4'] = newGridQuad(3, 2, sheet),
    ['5'] = newGridQuad(0, 3, sheet),
    ['6'] = newGridQuad(1, 3, sheet),
    ['7'] = newGridQuad(2, 3, sheet),
    ['8'] = newGridQuad(3, 3, sheet),
	}
	
	theShowQueue = List.new()
  showTimer = 0
  
  gameOver = false
  gameWin = false
	
	theField = makeBlankField(12, 12)
	addBombs(theField, 1)
	addFieldNumbers(theField)
	
	theFieldX, theFieldY = getCenterField()
end


function love.keypressed(key, scancode)
	if CHEATS and key == "r" then
		love.load()
	elseif CHEATS and key == "f5" then
		-- Quick reload for development
		love.event.quit('restart')
	elseif CHEATS and key == "escape" then
		-- Quick quit for development
		love.event.quit()
	end
end


function love.mousepressed(x, y, button)
  if gameOver or gameWin then return end
  
	local col, row = screenToTile(x, y)
	if isOnField(row, col, theField) then
    if button == 1 then
      if not getFlag(theField, row, col) then
        List.pushright(theShowQueue, {row, col})
      end
    else
      toggleFlag(theField, row, col)
    end
	end
end


function love.update(dt)
  showTimer = showTimer + dt
  if true then --showTimer >= 0 then
    showTimer = 0
    if not List.empty(theShowQueue) then
      stepShowQueue(theField, theShowQueue)
    elseif isGameWon() then
      gameWin = true
    end
  end
end


function love.draw()
  if gameOver then
    love.graphics.setBackgroundColor(0.7, 0, 0)
    drawField(theField)
    love.graphics.setColor(1,1,1)
    love.graphics.print("GAME OVER", 100, 100)
  elseif gameWin then
    love.graphics.setBackgroundColor(0, 0.7, 0)
    drawField(theField)
    love.graphics.setColor(1,1,1)
    love.graphics.print("YOU WIN", 100, 100)
  else
    love.graphics.setBackgroundColor(0.1, 0.1, 0.5)
    drawField(theField)
  end
	--[[
	local mx, my = love.mouse.getPosition()
	local tx, ty = screenToTile(mx, my)
	if isOnField(tx, ty, theField) then
		local x, y = tileToScreen(tx, ty)
		local dy = 15
		local coord = {ty, tx}
		love.graphics.rectangle("line", x, y, theFieldTileSize, theFieldTileSize)
		mx, my = mx + 20, my + dy
		love.graphics.print("tx: "..tx.." ty: "..ty, mx, my)
		my = my + dy
		love.graphics.print("bombs[]: "..(theField.bombs[coord] or 'nil'), mx, my)
		my = my + dy
		love.graphics.print("numbers[]: "..(theField.numbers[coord] or 'nil'), mx, my)
		my = my + dy
	end
	--]]
  --[[
  for i, pos in ipairs(theShowQueue) do
    local row, col = unpack(pos)
    love.graphics.print(row..", "..col, 10, 5+i*14)
    local x, y = tileToScreen(col, row)
    love.graphics.rectangle("line", x, y, theFieldTileSize, theFieldTileSize)
  end
  --]]
end


-- <Array2>
-- Array2 is a sparse 2D array that supports indexing with a table of {x, y}
Array2 = {}
Array2.mt = {}

function Array2.new(x)
	return setmetatable(x, Array2.mt)
end


function Array2.packKey(key)
	if type(key) ~= 'table' then
		error("Array2 unpacked key is not a table", 2)
	end
	
	local row = key[1]
	local col = key[2]
	return row..";"..col
end


function Array2.unpackKey(packed)
	if type(packed) ~= 'string' then
		error("Array2 packed key is not a string", 2)
	end
	
	local _, _, row, col = string.find(packed, '(%d+);(%d+)')
	return tonumber(row), tonumber(col)
end


Array2.mt.__index = function (table, key)
	if type(key) ~= 'table' then
    error("Array2 index key is not a table", 2)
  end
  
	if #key ~= 2 then
    error("Array2 key index does not have length 2", 2)
  end
  
	local composedKey = Array2.packKey(key)
	return rawget(table, composedKey)
end


Array2.mt.__newindex = function (table, key, value)
	if type(key) ~= 'table' then
    error("Array2 index key is not a table", 2)
  end
  
	if #key ~= 2 then
    error("Array2 key index does not have length 2", 2)
  end
  
	local composedKey = Array2.packKey(key)
	rawset(table, composedKey, value)
end
-- </Array2>


function getFlag(aField, row, col)
  return aField.flags[{row,col}]
end


function toggleFlag(aField, row, col)
  if aField.flags[{row,col}] then
    aField.flags[{row,col}] = nil
  else
    aField.flags[{row,col}] = true
  end
end


function popList(t)
	local val = t[#t]
	t[#t] = nil
	return val
end


-- Expects showQueue to be a list of {row,col} pairs
function stepShowQueue(aField, showQueue)
	local pos = List.popleft(showQueue)
  assert(pos)
  
  -- Do not process an already shown tile again
	if theField.revealed[pos] then
		return
	end
  
  local row, col = unpack(pos)
  showTile(aField, row, col)
  
  -- A bomb has been revealed, so the game is over
  if theField.bombs[pos] then
    setGameOver()
    return
  end
	
	local n = theField.numbers[pos]
	if n then
		return
	end
	
  -- Iterate the tile's 4 neighbors
	for _, dpos in ipairs({ {1,0}, {-1,0}, {0,1}, {0,-1} }) do
		local nrow, ncol = row + dpos[1], col + dpos[2]
    local npos = {nrow, ncol}
    if isOnField(nrow, ncol, aField) and (not theField.revealed[npos]) and not containsPos(showQueue, npos) then
      List.pushright(showQueue, npos)
    end
	end
end


function showAllBombs(aField)
  for k, v in pairs(aField.bombs) do
      showTile(aField, Array2.unpackKey(k))
  end
end


function setGameOver()
  gameOver = true
  showAllBombs(theField)
end


function containsPos(list, pos)
  assert(type(list) == 'table')
  assert(type(pos) == 'table')
  for _, val in ipairs(list) do
    if val[1] == pos[1] and val[2] == pos[2] then
      return true
    end
  end
  return false
end


function showTile(aField, row, col)
  local pos = {row,col}
	aField.revealed[pos] = true
  aField.flags[pos] = nil
end


-- Populate the field's numbers with proper values
function addFieldNumbers(aField)
	-- Iterate the field's bombs
	for k, v in pairs(aField.bombs) do
		local centerRow, centerCol = Array2.unpackKey(k)
		
		-- Iterate over the 8 neighbors of the bomb and increment the bomb count
		for row = centerRow-1, centerRow+1 do
			for col = centerCol-1, centerCol+1 do
				if isOnField(row, col, aField) and (row ~= centerRow or col ~= centerCol) then
					local pos = {row,col}
					local prevVal = aField.numbers[pos]
					if prevVal then
						aField.numbers[pos] = 1 + prevVal
					else
						aField.numbers[pos] = 1
					end
				end
			end
		end					
	end
end


function isOnField(row, col, field)
	return (1 <= col) and (col <= field.cols) and (1 <= row) and (row <= field.rows)
end


function makeBlankField(rows, cols)
	return {
		bombs = Array2.new{},    -- bomb/mine locations
		revealed = Array2.new{}, -- shown spots
		numbers = Array2.new{},  -- locations to show the number of nearby bombs
    flags = Array2.new{},    -- flagged/marked tiles
		rows = rows,
		cols = cols,
	}
end


function screenToTile(x, y)
	local x2 = 1 + math.floor((x - theFieldX) / theFieldTileSize)
	local y2 = 1 + math.floor((y - theFieldY) / theFieldTileSize)
	return x2, y2
end


function tileToScreen(tx, ty)
	local x = theFieldX + (tx - 1) * theFieldTileSize
	local y = theFieldY + (ty - 1) * theFieldTileSize
	return x, y
end


function drawField(aField)
	love.graphics.setColor(1, 1, 1)
	for r = 1, aField.rows do
    local y = theFieldY + (r - 1) * theFieldTileSize
		for c = 1, aField.cols do
			local x = theFieldX + (c - 1) * theFieldTileSize
      drawFieldTile(aField, r, c, x, y)
		end
	end
end


function drawFieldTile(aField, r, c, x, y)
  local coord = {r, c}
  if aField.revealed[coord] then
    -- Revealed tile
    love.graphics.draw(sheet, tiles.known, x, y)
    if aField.bombs[coord] then
      love.graphics.draw(sheet, tiles.mine, x, y)
    else
      local n = aField.numbers[coord]
      if n then
        --love.graphics.print(tostring(n), -6+x+theFieldTileSize/2, -6+y+theFieldTileSize/2)
        love.graphics.draw(sheet, tiles[tostring(n)], x, y)
      end
    end
  else
    -- Unrevealed tile
    love.graphics.draw(sheet, tiles.unknown, x, y)
    if aField.flags[coord] then
      love.graphics.draw(sheet, tiles.flag, x, y)
    end
  end
end


function getCenterField()
	local x = (love.graphics.getWidth()  / 2) - (theField.cols * theFieldTileSize)/2
	local y = (love.graphics.getHeight() / 2) - (theField.rows * theFieldTileSize)/2
	return x, y
end


function newGridQuad(x, y, img)
	local w = theFieldTileSize
	return love.graphics.newQuad(x*w, y*w, w, w, img)
end


function addBombs(aField, count)
	local fieldSpots = aField.rows * aField.cols
	assert(count < fieldSpots, "not enough room for adding some bombs")
	
	-- Returns bomb spot upon success
	local function addBomb()
		local r, c
		local loopCount = 0
		repeat
			r = love.math.random(aField.rows)
			c = love.math.random(aField.cols)
		until ((aField.bombs[{r,c}] ~= 'mine') or (loopCount > fieldSpots))
		
		if loopCount > fieldSpots then
			return
		end
		
		local k = {r,c}
		aField.bombs[k] = 'mine'
		return k
	end
	
	for i = 1, count do
		if not addBomb() then
			break
		end
	end
end


function isGameWon()
  for k, _ in pairs(theField.bombs) do
    if not theField.flags[{Array2.unpackKey(k)}] then
      return false
    end
  end
  
  for k, _ in pairs(theField.flags) do
    if not theField.bombs[{Array2.unpackKey(k)}] then
      return false
    end
  end
  
  return true
end
