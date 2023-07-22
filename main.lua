-- Bomp-Scanner, a game like minesweeper
-- Written for Love2d
-- TODO: implement game setup/config menu, for choosing size and bomb count


require "mountain-inh"


CHEATS = true
theFieldTileSize = 32
GAME_STATES = { 'config', 'ready', 'play', 'lose', 'win' }
MIN_ROWS, MIN_COLS = 9, 9
MAX_ROWS, MAX_COLS = 16, 23
  

function love.load()
  -- Load sprites/images
  sheet = love.graphics.newImage("sheet.png")
  tiles = {
    unknown = newGridQuad(0, 0, sheet),
    known = newGridQuad(1, 0, sheet),
    mine = newGridQuad(0, 1, sheet),
    flag1 = newGridQuad(2, 1, sheet),
    flag2 = newGridQuad(3, 1, sheet),
    fatal = newGridQuad(2, 0, sheet),
    border = newGridQuad(3, 0, sheet),
    panel = newGridQuad(1, 1, sheet),
    ['1'] = newGridQuad(0, 2, sheet),
    ['2'] = newGridQuad(1, 2, sheet),
    ['3'] = newGridQuad(2, 2, sheet),
    ['4'] = newGridQuad(3, 2, sheet),
    ['5'] = newGridQuad(0, 3, sheet),
    ['6'] = newGridQuad(1, 3, sheet),
    ['7'] = newGridQuad(2, 3, sheet),
    ['8'] = newGridQuad(3, 3, sheet),
  }
  digits = {
    [0] = love.graphics.newQuad(0, 128, 12, 17, sheet),
    [1] = love.graphics.newQuad(12, 128, 9, 17, sheet),
    [2] = love.graphics.newQuad(23, 128, 11, 17, sheet),
    [3] = love.graphics.newQuad(34, 128, 9, 17, sheet),
    [4] = love.graphics.newQuad(45, 128, 13, 17, sheet),
    [5] = love.graphics.newQuad(58, 128, 13, 16, sheet),
    [6] = love.graphics.newQuad(71, 128, 12, 17, sheet),
    [7] = love.graphics.newQuad(83, 128, 12, 16, sheet),
    [8] = love.graphics.newQuad(95, 128, 13, 16, sheet),
    [9] = love.graphics.newQuad(108, 128, 11, 18, sheet),
    [':'] = love.graphics.newQuad(120, 128, 6, 16, sheet),
  }
  
  -- Load sounds
  sounds = {
    click = love.audio.newSource('click.wav', 'static'),
    bang = love.audio.newSource('bang.wav', 'static'),
    win = love.audio.newSource('win.wav', 'static'),
    pop = love.audio.newSource('pop.wav', 'static'),
  }
  sounds.bang:setVolume(0.4)
  sounds.pop:setVolume(0.5)
  
  -- love.math.setRandomSeed(1)
  theGame = {}
  switchGameStateTo('play')
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
    if not Queue.isEmpty(theGame.showQueue) then
      stepShowQueue(theGame.field, theGame.showQueue)
    end
  --]]
  end
end


function love.mousepressed(x, y, button)
  if theGame.state == 'play' then
    thePressedTileCol, thePressedTileRow = screenToTile(x, y)
  end
end


function love.mousereleased(x, y, button)
  if theGame.state == 'play' then
    if gameOver or gameWin then return end
    
    local col, row = screenToTile(x, y)
    if isOnField(row, col, theGame.field) and col == thePressedTileCol and row == thePressedTileRow then
      if button == 1 then
        -- Reveal
        shouldCheckWin = true
        if not gameStarted then
          startGame(theGame.configBombCount, row, col)
        end
        if not getFlag(theGame.field, row, col) then
          Queue.put(theGame.showQueue, {row, col})
          if not theGame.field.revealed[{row, col}] then
            sounds.click:play()
          end
        end
      elseif not theGame.field.revealed[{row,col}] then
        -- Flag
        toggleFlag(theGame.field, row, col)
        shouldCheckWin = true
      end
    end
  end
end


function love.update(dt)
  if theGame.state == 'config' then
    -- Setting up game
  elseif theGame.state == 'play' then
    -- Playing game
    if gameStarted then
      processTheShowQueue(20 + math.floor(1000 * dt))
      
      if not gameOver and checkWin() then
        setGameWin()
      end
    end
    
    if gameWin then
      local now = love.timer.getTime()
      if now - lastBlinkTime > 0.5 then
        lastBlinkTime = now
        showFlags = not showFlags
      end
    end
  end
end


function love.draw()
  love.graphics.setBackgroundColor(0.2, 0.2, 0.5)
  
  drawBorder()
  
  if theGame.state == 'play' then
    drawField(theGame.field)
  elseif theGame.state == 'lose' then
    drawField(theGame.field)
    love.graphics.setColor(1,1,1)
    love.graphics.print("GAME OVER", 120, 20)
  elseif theGame.state == 'win' then
    drawField(theGame.field)
    love.graphics.setColor(1,1,1)
    love.graphics.print("YOU WIN", 120, 20)
  end
  
  drawInfo()
end


function switchGameStateTo(newState)
  if not member(newState, GAME_STATES) then
    error("switchGameStateTo: invalid new state: "..newState)
  end
  
  -- Note: do not add early returns to this code because the state variable
  -- is changed at the end.
  if (not theGame.state) and (newState == 'play') then
    -- Start in the play state
    theGame.configRows = 10
    theGame.configCols = 10
    theGame.configBombCount = 30
    theGame.showQueue = Queue.new()
    theGame.shouldCheckWin = false
    theGame.showFlags = true
    theGame.lastBlinkTime = 0
    theGame.pressedTileCol = 0
    theGame.pressedTileRow = 0
    theGame.field = makeBlankField(theGame.configRows, theGame.configCols)
    theGame.fieldX, theGame.fieldY = getCenterField()
    theGame.startTime = love.timer.getTime()
    theGame.flagCount = 0
  elseif (theGame.state == 'play') and (newState == 'lose') then
    -- Play --> lose
    gameOver = true
    endTime = love.timer.getTime()
    showAllBombs(theGame.field)
    sounds.click:stop()
    sounds.bang:play()
  elseif (theGame.state == 'play') and (newState == 'win') then
    -- Play --> win
    gameWin = true
    endTime = love.timer.getTime()
    showAllBombs(theGame.field)
    sounds.click:stop()
    sounds.win:play()
  else
    -- Invalid transition
    error("switchGameStateTo: invalid transition from state "..theGame.state.." to "..newState)
  end
  
  -- Now finally switch the state value
  theGame.state = newState
end


function drawInfo()
  local x1, y1 = getCenterField()
  y1 = y1 - 2 * theFieldTileSize
  drawTimeBox(x1 - theFieldTileSize + 1, y1, getPlayTime())
  local x2 = theGame.fieldX + theFieldTileSize * theGame.field.cols - 30
  drawBombCount(theGame.configBombCount, x2, y1)
  local x3 = x2 - 96
  drawFlagCount(theGame.flagCount, x3, y1)
end


function getPlayTime()
  if gameStarted then
    if theGame.state == 'lose' or theGame.state == 'win' then
      return endTime - startTime
    else
      return math.floor(love.timer.getTime() - startTime)
    end
  else
    return 0
  end
end


function drawTimeBox(x, y, seconds)
  --love.graphics.draw(sheet, tiles.panel, x, y)
  --love.graphics.draw(sheet, tiles.panel, x+30, y)
  drawTime(x+4, y+8, seconds)
end


function drawTime(x, y, seconds)
  assert(seconds >= 0)
  
  local m = math.floor(seconds / 60)
  local s = seconds - m*60
  
  local m1 = math.floor(m / 10)
  local m2 = math.floor(m % 10)
  
  local s1 = math.floor(s / 10)
  local s2 = math.floor(s % 10)
  
  drawDigit(m1, x, y)
  drawDigit(m2, x+12, y)
  drawDigit(':', x+24, y)
  drawDigit(s1, x+31, y)
  drawDigit(s2, x+44, y)
end


-- Draw a double digit count with an icon following it
function drawACount(count, x, y, quad)
  assert(count and (count < 100))
  
  local b1 = math.floor(count / 10)
  local b2 = count - b1 * 10
  
  --love.graphics.draw(sheet, tiles.panel, x, y)
  --love.graphics.draw(sheet, tiles.panel, x + 30, y)
  
  drawDigit(b1, x+4, y+8)
  drawDigit(b2, x+16, y+8)
  love.graphics.draw(sheet, quad, x+28, y)
end


function getFlagQuad(n)
  if n == 1 then
    return tiles.flag1
  elseif n == 2 then
    return tiles.flag2
  end
end


function drawFlagCount(count, x, y)
  drawACount(count, x, y, tiles.flag2)
end


function drawBombCount(count, x, y)
  drawACount(count, x, y, tiles.mine)
end


function drawDigit(digit, x, y)
  local quad = digits[digit]
  love.graphics.draw(sheet, quad, x, y)
end


function drawBorder()
  local x, y

  for r = 0, theGame.field.rows + 1 do
    x, y = tileToScreen(0, r)
    love.graphics.draw(sheet, tiles.border, x, y)
    x, y = tileToScreen(theGame.field.cols + 1, r)
    love.graphics.draw(sheet, tiles.border, x, y)
  end
  
  for c = 1, theGame.field.cols do
    x, y = tileToScreen(c, 0)
    love.graphics.draw(sheet, tiles.border, x, y)
    x, y = tileToScreen(c, theGame.field.rows + 1)
    love.graphics.draw(sheet, tiles.border, x, y)
  end
  
  for c = 0, theGame.field.cols + 1 do
    x, y = tileToScreen(c, -1)
    love.graphics.draw(sheet, tiles.panel, x, y)
  end
end


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
    if Queue.isEmpty(theGame.showQueue) then
      break
    end
    stepShowQueue(theGame.field, theGame.showQueue)
  end
end


function getFlag(aField, row, col)
  return aField.flags[{row,col}]
end


function toggleFlag(aField, row, col)
  local val = aField.flags[{row,col}]
  if not val then
    theGame.flagCount = theGame.flagCount + 1
    sounds.pop:play()
    aField.flags[{row,col}] = 2
  elseif val == 2 then
    sounds.pop:play()
    aField.flags[{row,col}] = 1
  elseif val == 1 then
    theGame.flagCount = theGame.flagCount - 1
    sounds.pop:play()
    aField.flags[{row,col}] = nil
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
  if theGame.field.revealed[pos] then
    return
  end
  
  -- Do not process a flagged tile
  if theGame.field.flags[pos] then
    return
  end
  
  local row, col = unpack(pos)
  showTile(aField, row, col)
  
  -- A bomb has been revealed, so the game is over
  if theGame.field.bombs[pos] then
    setGameOver(row, col)
    return
  end
  
  local n = theGame.field.numbers[pos]
  if n then
    return
  end
  
  -- Iterate the tile's 4 neighbors
  for _, dpos in ipairs({ {1,0}, {-1,0}, {0,1}, {0,-1} }) do
    local nrow, ncol = row + dpos[1], col + dpos[2]
    local npos = {nrow, ncol}
    if isOnField(nrow, ncol, aField) and (not theGame.field.revealed[npos]) and not queueContainsPos(showQueue, npos) then
      Queue.put(showQueue, npos)
    end
  end
end


function showAllBombs(aField)
  for pos, v in pairs(aField.bombs) do
      showTile(aField, pos)
  end
end


function setGameOver(fatalRow, fatalCol)
  theGame.field.fatalRow = fatalRow
  theGame.field.fatalCol = fatalCol
  switchGameStateTo('lose')
end


function setGameWin()
  switchGameStateTo('win')
end


function startGame(bombCount, safeRow, safeCol)
  gameStarted = true
  addBombsExcept(theGame.field, bombCount, safeRow, safeCol)
  startTime = love.timer.getTime()
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
  --aField.flags[pos] = nil
end


-- Populate the field's numbers with proper values
function addFieldNumbers(aField)
  aField.numbers = Sparse2D.new()
  
  -- Iterate the field's bombs
  for k, v in pairs(aField.bombs) do
    local centerRow, centerCol = unpack(k)
    
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
    bombs = Sparse2D.new{},    -- bomb/mine locations
    revealed = Sparse2D.new{}, -- shown spots
    numbers = Sparse2D.new{},  -- locations to show the number of nearby bombs
    flags = Sparse2D.new{},    -- flagged/marked tiles
    rows = rows,
    cols = cols,
  }
end


function screenToTile(x, y)
  local x2 = 1 + math.floor((x - theGame.fieldX) / theFieldTileSize)
  local y2 = 1 + math.floor((y - theGame.fieldY) / theFieldTileSize)
  return x2, y2
end


function tileToScreen(tx, ty)
  local x = theGame.fieldX + (tx - 1) * theFieldTileSize
  local y = theGame.fieldY + (ty - 1) * theFieldTileSize
  return x, y
end


function drawField(aField)
  for r = 1, aField.rows do
    local y = theGame.fieldY + (r - 1) * theFieldTileSize
    for c = 1, aField.cols do
      local x = theGame.fieldX + (c - 1) * theFieldTileSize
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
        love.graphics.draw(sheet, tiles[tostring(n)], x, y)
      end
    end
    
  else
    -- Unrevealed tile
    love.graphics.draw(sheet, tiles.unknown, x, y)
  end
  
  if showFlags then
    local flagVal = aField.flags[coord]
    if flagVal then
      love.graphics.draw(sheet, getFlagQuad(flagVal), x, y)
    end
  end
end


function getCenterField()
  local x = (love.graphics.getWidth()  / 2) - (theGame.field.cols * theFieldTileSize)/2
  local y = (love.graphics.getHeight() / 2) - (theGame.field.rows * theFieldTileSize)/2
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
      r = love.math.random(2, aField.rows - 1)
      c = love.math.random(2, aField.cols - 1)
    until (r ~= safeRow or c ~= safeCol) and (aField.bombs[{r,c}] ~= 'mine')
    aField.bombs[{r,c}] = 'mine'
  end
  
  aField.bombs = Sparse2D.new()
  
  for i = 1, count do
    addBomb()
  end
  
  addFieldNumbers(aField)
end


function isGameWon()
  if gameOver then
    return false
  end
  
  -- Any unflagged bomb -> not win
  for pos, _ in pairs(theGame.field.bombs) do
    if not theGame.field.flags[pos] then
      --offendingRow, offendingCol = unpack(pos)
      --offendingType = 'unflagged bomb'
      return false
    end
  end
  
  -- Any flagged non-bomb -> not win
  for pos, _ in pairs(theGame.field.flags) do
    if not theGame.field.bombs[pos] then
      --offendingRow, offendingCol = unpack(pos)
      --offendingType = 'false flag'
      return false
    end
  end
  
  --offendingType = nil
  return true
end
