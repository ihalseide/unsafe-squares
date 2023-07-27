-- Bomp-Scanner, a game like minesweeper
-- Written for Love2d
-- TODO: implement game setup/config menu, for choosing size and bomb count


require "mountain-inh"


CHEATS = true
theFieldTileSize = 32
GAME_STATES = { 'menu', 'config', 'ready', 'play', 'lose', 'win' }
MIN_ROWS, MIN_COLS = 9, 9
MAX_ROWS, MAX_COLS = 15, 23
MIN_BOMBS = 2
MENU_WAIT_SECONDS = 3


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
    col = newGridQuad(0, 5, sheet),
    row = newGridQuad(1, 5, sheet),
    check = newGridQuad(2, 5, sheet),
    ['1'] = newGridQuad(0, 2, sheet),
    ['2'] = newGridQuad(1, 2, sheet),
    ['3'] = newGridQuad(2, 2, sheet),
    ['4'] = newGridQuad(3, 2, sheet),
    ['5'] = newGridQuad(0, 3, sheet),
    ['6'] = newGridQuad(1, 3, sheet),
    ['7'] = newGridQuad(2, 3, sheet),
    ['8'] = newGridQuad(3, 3, sheet),
    ['+'] = love.graphics.newQuad(0, 145, 16, 15, sheet),
    ['-'] = love.graphics.newQuad(16, 145, 16, 15, sheet),
  }
  digits = {
    [0] = love.graphics.newQuad(0, 128, 12, 17, sheet),
    [1] = love.graphics.newQuad(12, 128, 9, 17, sheet),
    [2] = love.graphics.newQuad(23, 128, 11, 17, sheet),
    [3] = love.graphics.newQuad(34, 128, 9, 17, sheet),
    [4] = love.graphics.newQuad(45, 128, 13, 17, sheet),
    [5] = love.graphics.newQuad(58, 128, 13, 17, sheet),
    [6] = love.graphics.newQuad(71, 128, 12, 17, sheet),
    [7] = love.graphics.newQuad(83, 128, 12, 17, sheet),
    [8] = love.graphics.newQuad(95, 128, 13, 17, sheet),
    [9] = love.graphics.newQuad(108, 128, 11, 18, sheet),
    [':'] = love.graphics.newQuad(120, 128, 6, 16, sheet),
  }
  
  -- Load sounds
  music = love.audio.newSource("awesomeness.wav", "stream")
  sounds = {
    click = love.audio.newSource('click.wav', 'static'),
    bang = love.audio.newSource('bang1.wav', 'static'),
    bang2 = love.audio.newSource('bang2.wav', 'static'),
    win = love.audio.newSource('win.wav', 'static'),
    pop = love.audio.newSource('pop.wav', 'static'),
  }
  sounds.bang:setVolume(0.4)
  sounds.pop:setVolume(0.5)
  
  font1 = love.graphics.newFont(18)
  
  -- love.math.setRandomSeed(1)
  theGame = {}
  switchGameStateTo('menu')
end

  
function love.keypressed(key, scancode)
  if CHEATS and key == 'r' then
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
  if (theGame.state == 'play') or (theGame.state == 'ready') then
    theGame.pressedTileCol, theGame.pressedTileRow = screenToTile(x, y)
  elseif theGame.state == 'config' then
    -- Process button presses
    processWidgetClick(theGame.widgetBombs, x, y)
    processWidgetClick(theGame.widgetRows, x, y)
    processWidgetClick(theGame.widgetCols, x, y)
    if isPointInsideRect(x, y, theGame.okButton.x, theGame.okButton.y, 32, 32) then
      sounds.click:play()
      switchGameStateTo('ready')
    end
  elseif theGame.state == 'win' then
    if isPointInsideRect(x, y, theGame.retryMenu.x, theGame.retryMenu.y, 32, 32) then
      sounds.click:play()
      switchGameStateTo('config')
    end
  elseif theGame.state == 'lose' then
    if isPointInsideRect(x, y, theGame.retryMenu.x, theGame.retryMenu.y, 32, 32) then
      sounds.click:play()
      switchGameStateTo('config')
    end
  elseif theGame.state == 'menu' then
    switchGameStateTo('config')
  end
end


function love.mousereleased(x, y, button)
  if (theGame.state == 'play') or (theGame.state == 'ready') then
    -- Playing, so try to click on a tile (if it was the one the mouse originally pressed down on)
    local col, row = screenToTile(x, y)
    if isOnField(row, col, theGame.field) and (col == theGame.pressedTileCol) and (row == theGame.pressedTileRow) then
      if button == 1 then
        -- Reveal
        theGame.shouldCheckWin = true
        if (theGame.state == 'ready') then
          switchGameStateTo('play')
          addBombsExcept(theGame.field, theGame.configBombCount, row, col)
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
        theGame.shouldCheckWin = true
      end
    end
  end
end


function love.update(dt)
  if theGame.state == 'config' then
    -- Setting up game
    widgetUpdate(theGame.widgetBombs)
    widgetUpdate(theGame.widgetRows)
    widgetUpdate(theGame.widgetCols)
  elseif theGame.state == 'play' then
    -- Playing game
    processTheShowQueue(20 + math.floor(1000 * dt))
    if checkWin() then
      setGameWin()
    end
  elseif theGame.state == 'win' then
    updateBlinkingFlags()
    updateMenuVisibility()
  elseif theGame.state == 'lose' then
    updateBlinkingFlags()
    updateBombShowing()
    updateMenuVisibility()
  elseif theGame.state == 'menu' then
    theGame.menuParticles:update(dt)
    if theGame.playMusic then
      if not music:isPlaying() then
        music:play()
      end
    end
  end
end


function love.draw()
  if theGame.state == 'menu' then
    -- Menu state
    love.graphics.setBackgroundColor(0.2, 0.2, 0.5)
    love.graphics.draw(theGame.menuParticles)
    drawActionMenu()
  elseif theGame.state == 'config' then
    -- Config state
    love.graphics.setBackgroundColor(0.2, 0.2, 0.5)
    local x1, y1 = getCenterField(theGame.configRows, theGame.configCols)
    local w, h = theGame.configCols * theFieldTileSize, theGame.configRows * theFieldTileSize
    
    love.graphics.setColor(1,1,1)
    drawField({rows = theGame.configRows, cols = theGame.configCols}, x1, y1, true)
    
    love.graphics.setColor(0.8,0.8,0.8)
    local cx, cy = love.graphics.getWidth()/2 - 80, love.graphics.getHeight()/2 - 80
    local cw, ch = 180, 200
    love.graphics.rectangle('fill', cx, cy, cw, ch)
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle('line', cx, cy, cw, ch)
    
    love.graphics.setColor(1,1,1)
    drawWidget(theGame.widgetBombs)
    drawWidget(theGame.widgetRows)
    drawWidget(theGame.widgetCols)
    
    updateOkButton()
    local mouseX, mouseY = love.mouse.getPosition()
    if isPointInsideRect(mouseX, mouseY, theGame.okButton.x, theGame.okButton.y, 32, 32) then
      love.graphics.setColor(1, 1, 1)
    else
      love.graphics.setColor(0.8, 0.8, 0.8)
    end
    love.graphics.draw(sheet, tiles.check, theGame.okButton.x, theGame.okButton.y)
    love.graphics.setColor(1,1,1)
    
  elseif theGame.state == 'ready' then
    -- Ready state
    love.graphics.setBackgroundColor(0.2, 0.2, 0.5)
    drawBorder()
    drawField(theGame.field)
    drawInfo(0)
    
  elseif theGame.state == 'play' then
    love.graphics.setBackgroundColor(0.2, 0.2, 0.5)
    drawBorder()
    drawField(theGame.field)
    drawInfo(getPlayTime())
    
  elseif theGame.state == 'lose' then
    love.graphics.setBackgroundColor(0.2, 0.2, 0.5)
    drawBorder()
    drawField(theGame.field)
    drawInfo(getPlayTime())
    if theGame.showMenu then
      drawRetryMenu()
    end
    
  elseif theGame.state == 'win' then
    love.graphics.setBackgroundColor(0.2, 0.2, 0.5)
    drawBorder()
    drawField(theGame.field)
    drawInfo(getPlayTime())
    if theGame.showMenu then
      drawRetryMenu()
    end
    
  end
  
  --love.graphics.print(theGame.state, 10, 10)
end


function switchGameStateTo(newState)
  if not member(newState, GAME_STATES) then
    error("switchGameStateTo: invalid new state: "..newState)
  end
  
  -- Always reset the actions list
  theGame.actions = {}
  
  -- Note: do not add early returns to this code because the state variable
  -- is changed at the end.
  if (theGame.state == 'menu') and (newState == 'config') then
    -- Menu --> config
    music:stop()
    theGame.configRows = 10
    theGame.configCols = 10
    theGame.configBombCount = 15
    addConfigWidgets(theGame)
    theGame.okButton = {}
    updateOkButton()
    addAction(theGame,
      newAction {
        text='Toggle music',
        key='m',
        callback=function ()
            theGame.playMusic = not theGame.playMusic
          end
      })
  elseif newState == 'menu' then
    -- ? --> menu
    if theGame.state == nil then 
      theGame.playMusic = true
    end
    theGame.menuParticles = love.graphics.newParticleSystem(sheet, 50)
    theGame.menuParticles:setPosition(love.graphics.getWidth()/2, -10)
    theGame.menuParticles:setQuads(tiles.mine)
    theGame.menuParticles:setParticleLifetime(6, 6)
    theGame.menuParticles:setEmissionRate(7)
    theGame.menuParticles:setSizeVariation(1)
    theGame.menuParticles:setLinearAcceleration(0, 40, 0, 45)
    theGame.menuParticles:setEmissionArea('uniform', -32+love.graphics.getWidth()/2, 0)
  elseif (not theGame.state) and (newState == 'ready') then
    -- Start in ready
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
    theGame.flagCount = 0
    theGame.endTime = nil
  elseif (theGame.state == 'config') and (newState == 'ready') then
    -- Config --> ready
    assert(theGame.configRows)
    assert(theGame.configCols)
    assert(theGame.configBombCount)
    theGame.showQueue = Queue.new()
    theGame.shouldCheckWin = false
    theGame.showFlags = true
    theGame.lastBlinkTime = 0
    theGame.pressedTileCol = 0
    theGame.pressedTileRow = 0
    theGame.field = makeBlankField(theGame.configRows, theGame.configCols)
    theGame.fieldX, theGame.fieldY = getCenterField()
    theGame.flagCount = 0
    theGame.endTime = nil
  elseif (theGame.state == 'ready') and (newState == 'play') then
    -- Ready --> Play
    theGame.startTime = love.timer.getTime()
    theGame.endTime = nil
  elseif (theGame.state == 'play') and (newState == 'lose') then
    -- Play --> lose
    theGame.endTime = love.timer.getTime()
    sounds.click:stop()
    sounds.bang:play()
    theGame.showMenu = false
    addRetryMenu(theGame)
  elseif (theGame.state == 'play') and (newState == 'win') then
    -- Play --> win
    theGame.endTime = love.timer.getTime()
    showAllBombs(theGame.field)
    sounds.click:stop()
    sounds.win:play()
    theGame.showMenu = false
    addRetryMenu(theGame)
  elseif (theGame.state == 'lose') and (newState == 'config') then
    -- Lose --> config
    theGame.endTime = nil
    theGame.lastBombTime = nil
    theGame.isShowingBombs = nil
  elseif (theGame.state == 'win') and (newState == 'config') then
    -- Win --> config
    theGame.endTime = nil
  else
    -- Invalid transition
    error("switchGameStateTo: invalid transition from state "..tostring(theGame.state).." to "..tostring(newState))
  end
  
  -- Now finally switch the state value
  theGame.state = newState
end


function drawActionMenu()
  love.graphics.setColor(1,1,1)
  
end


function updateBlinkingFlags()
  local now = love.timer.getTime()
  if now - theGame.lastBlinkTime > 0.5 then
    theGame.lastBlinkTime = now
    theGame.showFlags = not theGame.showFlags
  end
end


function updateOkButton()
  local cx, cy = love.graphics.getWidth()/2, love.graphics.getHeight()/2
  theGame.okButton.x = cx - 4
  theGame.okButton.y = cy + 75
end


function processWidgetClick(w, x, y)
  if isPointInsideRect(x, y, widgetGetBounds(w, '-')) then
    w.callback('-')
  elseif isPointInsideRect(x, y, widgetGetBounds(w, '+')) then
    w.callback('+')
  end
end


function isPointInsideRect(px, py, rx, ry, rw, rh)
  return rx <= px and px <= rx + rw and ry <= py and py <= ry + rh
end


function addConfigWidgets(t)
  t.widgetBombs = {
    quad = 'mine',
    index = 1,
    callback = function (direction)
        if direction == '+' then theGame.configBombCount = theGame.configBombCount + 1
        elseif direction == '-' then theGame.configBombCount = theGame.configBombCount - 1 end
        gameClampBombs(theGame)
        return theGame.configBombCount
      end
  }
  widgetUpdate(t.widgetBombs)
  
  t.widgetRows = {
    quad = 'row',
    index = 2,
    callback = function (direction)
        if direction == '+' then theGame.configRows = theGame.configRows + 1
        elseif direction == '-' then theGame.configRows = theGame.configRows - 1 end
        theGame.configRows = clamp(theGame.configRows, MIN_ROWS, MAX_ROWS)
        gameClampBombs(theGame)
        return theGame.configRows
      end
  }
  widgetUpdate(t.widgetRows)
  
  t.widgetCols = {
    quad = 'col',
    index = 3,
    callback = function (direction)
        if direction == '+' then theGame.configCols = theGame.configCols + 1
        elseif direction == '-' then theGame.configCols = theGame.configCols - 1 end
        theGame.configCols = clamp(theGame.configCols, MIN_COLS, MAX_COLS)
        gameClampBombs(theGame)
        return theGame.configCols
      end
  }
  widgetUpdate(t.widgetCols)
end


function widgetUpdate(w)
  local cx, cy = love.graphics.getWidth()/2, love.graphics.getHeight()/2
  w.x = cx - 32 * 2
  w.y = cy - 96 + (40 * w.index)
end


function gameClampBombs(game)
  local rows, cols = game.configRows, game.configCols
  local maxBombs = (rows * cols * 2) / 3
  game.configBombCount = clamp(game.configBombCount, MIN_BOMBS, maxBombs)
end


-- Get (x,y,w,h) bounds for a specified button ('+' or '-') for a widget with an origin at (x1, y1)
function widgetGetBounds(w, button)
  if button == '+' then
    return 6 + 16 + w.x + 32 * 3, w.y, 32, 32
  elseif button == '-' then
    return 6+ w.x + 32 * 1, w.y, 32, 32
  end
end


function drawWidget(widget)
  local x1, y2 = widget.x, widget.y
  
  local value = widget.callback()
  
  drawTile(widget.quad, x1, y2)
  
  local mouseX, mouseY = love.mouse.getPosition()
  local x, y, w, h
  
  x, y, w, h = widgetGetBounds(widget, '-')
  if isPointInsideRect(mouseX, mouseY, x, y, w, h) then
    love.graphics.setColor(0.6,0.6,0.6)
  else
    love.graphics.setColor(0.4,0.4,0.4)
  end
  love.graphics.rectangle('fill', x, y, w, h)
  love.graphics.setColor(1,1,1)
  drawTile('-', x + 8, y + 9)

  x, y, w, h = widgetGetBounds(widget, '+')
  if isPointInsideRect(mouseX, mouseY, x, y, w, h) then
    love.graphics.setColor(0.6,0.6,0.6)
  else
    love.graphics.setColor(0.4,0.4,0.4)
  end
  love.graphics.rectangle('fill', x, y, w, h)
  
  love.graphics.setColor(1,1,1)
  drawTile('+', x + 8, y + 9)
  
  local b0 = math.floor(value / 100)
  value = math.floor(value - (100 * b0))
  local b1 = math.floor(value / 10)
  value = math.floor(value - (10 * b1))
  local b2 = value
  local x2 = x1 + 10 + 32 * 2
  local y3 = y2 + 6
  if b0 > 0 then drawDigit(b0, x2 + 12 * 0, y3) end
  if b0 > 0 or b1 > 0 then drawDigit(b1, x2 + 12 * 1, y3) end
  drawDigit(b2, x2 + 12 * 2, y3)
end


function drawInfo(time)
  assert(type(time) == 'number')
  
  local x1, y1 = getCenterField()
  y1 = y1 - 2 * theFieldTileSize
  drawTimeBox(x1 - theFieldTileSize + 1, y1, time)
  local x2 = theGame.fieldX + theFieldTileSize * theGame.field.cols - 30
  drawBombCount(theGame.configBombCount, x2, y1)
  local x3 = x2 - 96
  drawFlagCount(theGame.flagCount, x3, y1)
end


function getPlayTime()
  local lastTime = theGame.endTime or love.timer.getTime()
  return lastTime - theGame.startTime
end


function drawTimeBox(x, y, seconds)
  drawTime(x+4, y+8, seconds)
end


function secondsToHMS(seconds)
  local h = math.floor(seconds / 3600)
  seconds = math.floor(seconds - h * 3600)
  assert(seconds < 3600)
  local m = math.floor(seconds / 60)
  seconds = math.floor(seconds - m * 60)
  assert(0 <= m and m <= 59)
  local s = seconds
  assert(0 <= s and s <= 59)
  return h, m, s
end


function drawTime(x, y, seconds)
  assert(seconds >= 0)
  
  local h, m, s = secondsToHMS(seconds)
  
  local h1 = math.floor(h / 10)
  local h2 = math.floor(h % 10)
  
  local m1 = math.floor(m / 10)
  local m2 = math.floor(m % 10)
  
  local s1 = math.floor(s / 10)
  local s2 = math.floor(s % 10)
  
  drawDigit(h1, x, y)
  drawDigit(h2, x+12, y)
  drawDigit(':', x+24, y)
  drawDigit(m1, x+32, y)
  drawDigit(m2, x+44, y)
  drawDigit(':', x+56, y)
  drawDigit(s1, x+65, y)
  drawDigit(s2, x+77, y)
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
  assert(digit == ':' or member(digit, {0,1,2,3,4,5,6,7,8,9}))
  local quad = digits[digit]
  assert(quad, "cannot draw digit "..digit)
  love.graphics.draw(sheet, quad, x, y)
end


function drawBorder(rows, cols)
  local rows = rows or theGame.field.rows
  local cols = cols or theGame.field.cols
  
  local x, y

  for r = 0, rows + 1 do
    x, y = tileToScreen(0, r)
    love.graphics.draw(sheet, tiles.border, x, y)
    x, y = tileToScreen(theGame.field.cols + 1, r)
    love.graphics.draw(sheet, tiles.border, x, y)
  end
  
  for c = 1, cols do
    x, y = tileToScreen(c, 0)
    love.graphics.draw(sheet, tiles.border, x, y)
    x, y = tileToScreen(c, theGame.field.rows + 1)
    love.graphics.draw(sheet, tiles.border, x, y)
  end
  
  for c = 0, cols + 1 do
    x, y = tileToScreen(c, -1)
    love.graphics.draw(sheet, tiles.panel, x, y)
  end
end


function checkWin()
  if not theGame.shouldCheckWin then
    return false
  end
  
  theGame.shouldCheckWin = false
  return isGameWon()
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
  sounds.pop:play()
  local val = aField.flags[{row,col}]
  if not val then
    -- No flag --> flag #2
    theGame.flagCount = theGame.flagCount + 1
    aField.flags[{row,col}] = 2
  elseif val == 2 then
    -- Flag #2 --> flag #1
    aField.flags[{row,col}] = 1
  elseif val == 1 then
    -- Flag #1 --> no flag
    theGame.flagCount = theGame.flagCount - 1
    aField.flags[{row,col}] = nil
  else
    error("unexpected flag value: "..tostring(val))
  end
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
  for k, v in pairs(aField.bombs) do
      showTile(aField, unpack(k))
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
    bombs = Sparse2D.new(),    -- bomb/mine locations
    revealed = Sparse2D.new(), -- shown spots
    numbers = Sparse2D.new(),  -- locations to show the number of nearby bombs
    flags = Sparse2D.new(),    -- flagged/marked tiles
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


function drawField(aField, fieldX, fieldY, isFake)
  local fieldX = fieldX or theGame.fieldX
  local fieldY = fieldY or theGame.fieldY
  for r = 1, aField.rows do
    local y = fieldY + (r - 1) * theFieldTileSize
    for c = 1, aField.cols do
      local x = fieldX + (c - 1) * theFieldTileSize
      if isFake then
        drawTile('unknown', x, y)
      else
        drawFieldTile(aField, r, c, x, y)
      end
    end
  end
end


function drawTile(t, x, y)
  love.graphics.draw(sheet, tiles[t], x, y)
end


function drawFieldTile(aField, r, c, x, y)
  local coord = {r, c}
  
  if aField.revealed[coord] then
    -- Revealed tile
    --Choose background
    if (aField.fatalRow == r) and (aField.fatalCol == c) then
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
        drawTile(tostring(n), x, y)
      end
    end
    
  else
    -- Unrevealed tile
    drawTile('unknown', x, y)
  end
  
  -- Maybe draw flag on top
  if theGame.showFlags then
    local flagVal = aField.flags[coord]
    if flagVal then
      love.graphics.draw(sheet, getFlagQuad(flagVal), x, y)
    end
  end
end


function getCenterField(numRows, numCols)
  local numRows = numRows or theGame.field.rows
  local numCols = numCols or theGame.field.cols
  local x = (love.graphics.getWidth()  / 2) - (numCols * theFieldTileSize)/2
  local y = (love.graphics.getHeight() / 2) - (numRows * theFieldTileSize)/2
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


function updateMenuVisibility()
  local now = love.timer.getTime()
  if (now - theGame.endTime >= MENU_WAIT_SECONDS) and not theGame.isShowingBombs then
    theGame.showMenu = true
  end
end


function drawRetryMenu()
  local x, y = theGame.retryMenu.x, theGame.retryMenu.y
  local mouseX, mouseY = love.mouse.getPosition()
    if isPointInsideRect(mouseX, mouseY, x, y, 32, 32) then
      love.graphics.setColor(1, 1, 1)
    else
      love.graphics.setColor(0.8, 0.8, 0.8)
    end
    love.graphics.draw(sheet, tiles.check, x, y)
    love.graphics.setColor(1,1,1)
end


function addRetryMenu(t)
  t.retryMenu = {
    x = love.graphics.getWidth()/2 - 16,
    y = love.graphics.getHeight()/2 - 16,
  }
end


function updateBombShowing()  
  local now = love.timer.getTime()
  
  if not theGame.lastBombTime then
    theGame.lastBombTime = now
    theGame.bombDelay = 0.5
    theGame.isShowingBombs = true
    return
  end
  
  if not theGame.isShowingBombs then
    return
  end
  
  if now - theGame.lastBombTime > theGame.bombDelay then
    theGame.lastBombTime = now
    if theGame.bombDelay > 0.2 then
      theGame.bombDelay = theGame.bombDelay * 0.90
    end
    
    -- reveal one bomb
    for k, v in pairs(theGame.field.bombs) do
      if not theGame.field.revealed[k] then
        sounds.bang2:stop()
        sounds.bang2:play()
        showTile(theGame.field, unpack(k))
        return
      end
    end
    
    -- if this point is reached, then all bombs are shown
    theGame.isShowingBombs = false
  end
end