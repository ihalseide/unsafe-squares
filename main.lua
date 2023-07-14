-- Bomp-Scanner, a game like minesweeper
-- Written for Love2d


require "mountain-inh"


CHEATS = true
theFieldTileSize = 32

	
function love.load()
	-- love.math.setRandomSeed(1)

	sheet = love.graphics.newImage("sheet.png")
	
	tiles = {
		unknown = newGridQuad(0, 0, sheet),
		known = newGridQuad(1, 0, sheet),
		mine = newGridQuad(0, 1, sheet),
    flag = newGridQuad(1, 1, sheet),
    fatal = newGridQuad(2, 1, sheet),
    select = newGridQuad(2, 0, sheet),
    ['1'] = newGridQuad(0, 2, sheet),
    ['2'] = newGridQuad(1, 2, sheet),
    ['3'] = newGridQuad(2, 2, sheet),
    ['4'] = newGridQuad(3, 2, sheet),
    ['5'] = newGridQuad(0, 3, sheet),
    ['6'] = newGridQuad(1, 3, sheet),
    ['7'] = newGridQuad(2, 3, sheet),
    ['8'] = newGridQuad(3, 3, sheet),
	}
  
  sounds = {
    click = love.audio.newSource('click.wav', 'static'),
    bang = love.audio.newSource('bang.wav', 'static'),
    win = love.audio.newSource('win.wav', 'static'),
  }
  
  theConfigBombCount = 18
	
	theShowQueue = Queue.new()
  
  shouldCheckWin = false
  gameStarted = false
  gameOver = false
  gameWin = false
  
  thePressedTileCol, thePressedTileRow = 0, 0
	
	theField = makeBlankField(12, 12)
	
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
  --[[
	elseif key == 'space' then
    if not Queue.isEmpty(theShowQueue) then
      stepShowQueue(theField, theShowQueue)
    end
  --]]
  end
end


function love.mousepressed(x, y, button)
  thePressedTileCol, thePressedTileRow = screenToTile(x, y)
end


function love.mousereleased(x, y, button)
  if gameOver or gameWin then return end
  
	local col, row = screenToTile(x, y)
	if isOnField(row, col, theField) and col == thePressedTileCol and row == thePressedTileRow then
    if button == 1 then
      -- Reveal
      shouldCheckWin = true
      if not gameStarted then
        startGame(theConfigBombCount, row, col)
      end
      if not getFlag(theField, row, col) then
        Queue.put(theShowQueue, {row, col})
        if not theField.revealed[{row, col}] then
          sounds.click:play()
        end
      end
    else
      -- Flag
      toggleFlag(theField, row, col)
    end
	end
end


function love.update(dt)
  if gameStarted then
    processTheShowQueue(12)
    if checkWin() then
      setGameWin()
    end
  end
end


function love.draw()
  love.graphics.setBackgroundColor(0.2, 0.2, 0.5)
  if gameOver then
    drawField(theField)
    love.graphics.setColor(1,1,1)
    love.graphics.print("GAME OVER", 100, 100)
  elseif gameWin then
    drawField(theField)
    love.graphics.setColor(1,1,1)
    love.graphics.print("YOU WIN", 100, 100)
  else
    drawField(theField)
  end

	local mx, my = love.mouse.getPosition()
	local tx, ty = screenToTile(mx, my)
	if isOnField(tx, ty, theField) then
		local x, y = tileToScreen(tx, ty)
		love.graphics.draw(sheet, tiles.select, x, y)
	end
  
  --[[
  local lineY = 10
  for k, v in pairs(theShowQueue) do
    if type(k) == 'number' then
      local row, col = unpack(v)
      love.graphics.print(k.." = "..row..", "..col, 10, lineY)
      local x, y = tileToScreen(col, row)
      love.graphics.rectangle("line", x, y, theFieldTileSize, theFieldTileSize)
      lineY = lineY + 14
    else
      love.graphics.print(k.." = "..v, 10, lineY)
      lineY = lineY + 14
    end
  end
  --]]

  love.graphics.print("Current FPS: "..love.timer.getFPS(), 10, 10)
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


function checkWin()
  if shouldCheckWin then
    shouldCheckWin = false
    if not gameOver and isGameWon() then
      return true
    end
  end
  return false
end


function processTheShowQueue(steps)
  for i = 1, steps do
    if Queue.isEmpty(theShowQueue) then
      break
    end
    stepShowQueue(theField, theShowQueue)
  end
end


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
	local pos = Queue.pop(showQueue)
  assert(pos)
  
  -- Do not process an already shown tile again
	if theField.revealed[pos] then
		return
	end
  
  -- Do not process a flagged tile
	if theField.flags[pos] then
		return
	end
  
  local row, col = unpack(pos)
  showTile(aField, row, col)
  
  -- A bomb has been revealed, so the game is over
  if theField.bombs[pos] then
    setGameOver(row, col)
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
    if isOnField(nrow, ncol, aField) and (not theField.revealed[npos]) and not queueContainsPos(showQueue, npos) then
      Queue.put(showQueue, npos)
    end
	end
end


function showAllBombs(aField)
  for k, v in pairs(aField.bombs) do
      showTile(aField, Array2.unpackKey(k))
  end
end


function setGameOver(fatalRow, fatalCol)
  gameOver = true
  showAllBombs(theField)
  theField.fatalRow = fatalRow
  theField.fatalCol = fatalCol
  sounds.click:stop()
  sounds.bang:play()
end


function setGameWin()
  gameWin = true
  showAllBombs(theField)
  sounds.click:stop()
  sounds.win:play()
end


function startGame(bombCount, safeRow, safeCol)
  gameStarted = true
  addBombsExcept(theField, bombCount, safeRow, safeCol)
end


function queueContainsPos(list, pos)
  assert(type(list) == 'table')
  assert(type(pos) == 'table')
  for i = list.first, list.last do
    local val = list[i]
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
  aField.numbers = Array2.new{}
  
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
    --Choose background
    if aField.fatalRow == r and aField.fatalCol == c then
      love.graphics.draw(sheet, tiles.fatal, x, y)
    else
      love.graphics.draw(sheet, tiles.known, x, y)
    end
    
    -- Choose foreground
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


-- Add bombs anywhere except at {safeRow, safeCol}
function addBombsExcept(aField, count, safeRow, safeCol)
	local fieldSpots = aField.rows * aField.cols
	assert(count < fieldSpots, "not enough room for adding some bombs")
	
	-- Returns bomb spot upon success
	local function addBomb()
		local r, c
		repeat
			r = love.math.random(aField.rows)
			c = love.math.random(aField.cols)
		until (r ~= safeRow or c ~= safeCol) and (aField.bombs[{r,c}] ~= 'mine')
		aField.bombs[{r,c}] = 'mine'
	end
	
  aField.bombs = Array2.new{}
  
	for i = 1, count do
		addBomb()
	end
  
  addFieldNumbers(aField)
end


function isGameWon()
  if gameOver then return false end
  local totalCount = theField.rows * theField.cols
  local revealCount = keyCount(theField.revealed)
  local bombCount = keyCount(theField.bombs)
  return totalCount == revealCount + bombCount
end
