-- "Unsafe Squares" is a game like Minesweeper.
-- Game code written in Lua for use with the Love2d "engine"

require 'mountain-inh'

ALLOW_CHEATS = true
theFieldTileSize = 32
GAME_STATES = { 'menu', 'config', 'play', 'done' }
MIN_ROWS, MIN_COLS = 9, 9
MAX_ROWS, MAX_COLS = 15, 23
MIN_BOMBS = 2
MENU_WAIT_SECONDS = 3
TITLE_COPYRIGHT = 'Copyright 2023 DivZero'

function love.load()
  love.window.setTitle('Unsafe Squares')
  love.graphics.setDefaultFilter('nearest','nearest')
  sheet = love.graphics.newImage('sheet.png')
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
  sounds = {
    click = requireAudio('click.wav', 'static'),
    bang = requireAudio('bang1.wav', 'static'),
    bang2 = requireAudio('bang2.wav', 'static'),
    win = requireAudio('win.wav', 'static'),
    pop = requireAudio('pop.wav', 'static'),
    accept = requireAudio('accept.mp3', 'static'),
    selection = requireAudio('selection.wav', 'static'),
    reject = requireAudio('reject.wav', 'static'),
    info = requireAudio('info.wav', 'static'),
  }
  sounds.bang:setVolume(0.4)
  sounds.pop:setVolume(0.5)
  font1 = love.graphics.newFont(12)
  font2 = love.graphics.newFont(28)
  love.math.setRandomSeed(1)
  theGame = {}
  theGame.overlays = {}
  theGame.overlays.menuInfo = {
    title = 'Info (menu)',
    x = (love.graphics.getWidth()-300)/2,
    y = 40,
    width = 300,
    height = 400,
    bodyText =
[[Welcome to the "Unsafe Squares" menu.
You may proceed to the game or change
settings by clicking on the menu buttons
which show up at the bottom in the
"action menu" or by pressing the
matching shortcut keys. When you
proceed, additional information pages
will be available to you.

Close this help info by clicking the "Help"
button again or by pressing [H].]],
    bodyTextSpacing = 2,
    extraText = { {x=5, y=love.graphics.getHeight()-36, text='This down here is the "actions menu"!'} },
  }
  theGame.overlays.creditsInfo = {
    title = 'Credits',
    x = (love.graphics.getWidth()-300)/2,
    y = 40,
    width = 300,
    height = 400,
    bodyText = love.filesystem.read('credits.txt'),
  }
  switchGameStateTo('menu')
end

function love.keypressed(key, scancode)
  -- action menu
  for _, action in ipairs(theGame.actions) do
    if type(action.key) == 'string' and key == action.key then
      sounds.selection:stop()
      sounds.selection:play()
      action.callback(action, key)
    end
  end
  -- cheat code
  if ALLOW_CHEATS then
    local code = {'right','down','up','up','up'}
    if theGame.nextCodeIndex then
      if key == code[theGame.nextCodeIndex] then
        -- correct --> next or done
        theGame.nextCodeIndex = theGame.nextCodeIndex + 1
        if theGame.nextCodeIndex > #code then
          theGame.nextCodeIndex = nil
          theGame.cheats = true
          sounds.win:play()
          switchGameStateTo('menu') -- to regenerate the action menu
        end
      else
        -- incorrect --> reset
        theGame.nextCodeIndex = 1
      end
    end
  end
end

function love.mousepressed(x, y, button)
  if theGame.state == 'play' then
    theGame.pressedTileCol, theGame.pressedTileRow = screenToTile(x, y)
  end
  -- Check for clicking on action menu items
  for _, action in ipairs(theGame.actions) do
    if action.rectX and action.rectY and action.rectW and action.rectH then
      if isPointInsideRect(x, y, action.rectX, action.rectY, action.rectW, action.rectH) then
        sounds.selection:stop()
        sounds.selection:play()
        action.callback(action)
      end
    end
  end
end

function love.mousereleased(x, y, button)
  if theGame.state == 'play' then
    -- Playing, so try to click on a tile (if it was the one the mouse originally pressed down on)
    local col, row = screenToTile(x, y)
    if isOnField(row, col, theGame.field) and (col == theGame.pressedTileCol) and (row == theGame.pressedTileRow) then
      if button == 1 then
        -- Reveal
        theGame.shouldCheckWin = true
        if not theGame.timerHasStarted then
          theGame.timerHasStarted = true
          theGame.startTime = love.timer.getTime()
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

function love.draw()
  update(love.timer.getDelta())
end

function update(dt)
  if theGame.state == 'play' then
    local nSteps = 20 + math.floor(1000 * dt)
    processTheShowQueue(nSteps)
    if checkWin() then
      theGame.isWin = true
      switchGameStateTo('done')
    end
  elseif theGame.state == 'done' then
    updateBlinkingFlags()
    updateBombShowing()
  end
  
  if theGame.state == 'menu' then
    -- Menu state
    love.graphics.setBackgroundColor(1,1,1)
    local extent1, extent2 = 12, 15
    if math.floor(love.timer.getTime()*3 - theGame.stateStartTime) % 2 == 1 then
      extent1, extent2 = extent2, extent1
    end
    local bombSize = 3*32
    local bombX = (love.graphics.getWidth()-bombSize)/2
    local bombY = love.graphics.getHeight()/2 - 90 - bombSize
    love.graphics.setColor(0, 0.5, 1)
    love.graphics.circle('line', bombX+bombSize/2, bombY+bombSize/2, bombSize/2+extent1)
    love.graphics.setColor(0, 0.9, 1)
    love.graphics.circle('line', bombX+bombSize/2, bombY+bombSize/2, bombSize/2+extent2)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(sheet, tiles.mine, bombX, bombY, 0, math.floor(bombSize/32))
    love.graphics.setFont(font2)
    love.graphics.setColor(0,0,0)
    local text, w, h = textMeasured('Unsafe Squares')
    love.graphics.print(text, math.floor((love.graphics.getWidth()-w)/2), math.floor((love.graphics.getHeight()-h)/2 - h))
    love.graphics.setFont(font1)
    text, w, h = textMeasured('Press [Space] to begin')
    love.graphics.print(text, (love.graphics.getWidth()-w)/2, 30+(love.graphics.getHeight()-h)/2)
    text, w, h = textMeasured('Press [H] for help/information')
    love.graphics.print(text, (love.graphics.getWidth()-w)/2, 36+h+(love.graphics.getHeight()-h)/2)
    drawActionMenu()
    text, w, h = textMeasured(TITLE_COPYRIGHT)
    love.graphics.setColor(0,0,0)
    love.graphics.print(text, love.graphics.getWidth()-w-5, love.graphics.getHeight()-h-5)
    drawOverlays()
  elseif theGame.state == 'config' then
    -- Config state
    love.graphics.setBackgroundColor(0.2, 0.2, 0.5)
    love.graphics.setColor(1,1,1)
    local x1, y1 = getCenterField(theGame.configRows, theGame.configCols)
    local w, h = theGame.configCols * theFieldTileSize, theGame.configRows * theFieldTileSize
    love.graphics.setColor(1,1,1)
    drawField({rows = theGame.configRows, cols = theGame.configCols}, x1, y1, true)
    drawActionMenu()
  elseif theGame.state == 'play' then
    love.graphics.setBackgroundColor(0.2, 0.2, 0.5)
    love.graphics.setColor(1, 1, 1)
    drawBorder()
    drawField(theGame.field)
    drawInfo(getPlayTime())
    drawActionMenu()
  elseif theGame.state == 'done' then
    love.graphics.setColor(1, 1, 1)
    love.graphics.setBackgroundColor(0.2, 0.2, 0.5)
    drawBorder()
    drawField(theGame.field)
    drawInfo(getPlayTime())
    drawActionMenu()
  end
  -- love.graphics.setColor(0,0,1)
  -- love.graphics.print(quote(theGame.overlays), 1, 1)
  -- love.graphics.setColor(1,1,1); love.graphics.print(theGame.state..' '..(love.timer.getTime()-theGame.stateStartTime), 10, 10)
end

function switchGameStateTo(newState)
  if not member(newState, GAME_STATES) then error('switchGameStateTo: invalid new state: '..newState) end
  -- Note: do not add early returns to this function because the state variable is finally changed at the end.
  -- Reset the actions list first so it can be appended to
  theGame.actions = {}
  if theGame.cheats then
    addAction { text='Reload', key='f1', color={0.8,0.4,0}, callback=function() love.event.quit('restart') end }
    addAction { text='ESCAPE', key='escape', color={0.8,0.4,0}, callback=function() love.event.quit() end }
  end
  if newState == 'menu' then
    addAction { text='Quit program', key='q', callback=function() actionQuit() end }
  else
    addAction { text='Quit to menu', key='q', callback=function() actionQuit() end }
  end
  addAction { text='Turn music off', key='m', isActive=true, callback=function(s) toggleMusic(s) end }
  -- State transitions
  if newState == 'menu' then
    --> Menu
    addAction { text='Play', key='space', callback=function() menuPlayButton() end }
    addAction { text='Help', key='h', callback=function() showHelp() end }
    addAction { text='Credits', key='c', callback=function() showCredits() end }
    if ALLOW_CHEATS and not theGame.cheats then
      theGame.nextCodeIndex = 1
    end
  elseif (theGame.state == 'menu') and (newState == 'config') then
    -- Menu --> config
    theGame.configRows = 10
    theGame.configCols = 10
    theGame.configBombCount = 12
    addAction { text='Start game', key='space', callback=function () configPlayButton() end }
  elseif (theGame.state == 'config') and (newState == 'play') then
    -- Config --> play
    theGame.showQueue = Queue.new()
    theGame.shouldCheckWin = false
    theGame.showFlags = true
    theGame.lastBlinkTime = 0
    theGame.pressedTileCol = 0
    theGame.pressedTileRow = 0
    theGame.field = {
        bombs = Sparse2D.new(),    -- bomb/mine locations
        revealed = Sparse2D.new(), -- shown spots
        numbers = Sparse2D.new(),  -- locations to show the number of nearby bombs
        flags = Sparse2D.new(),    -- flagged/marked tiles
        rows = theGame.configRows,
        cols = theGame.configCols,
      }
    theGame.fieldX, theGame.fieldY = getCenterField()
    theGame.flagCount = 0
    theGame.timerHasStarted = false
    theGame.startTime = nil
    theGame.endTime = nil
  elseif (theGame.state == 'play') and (newState == 'done') then
    -- Play --> done
    theGame.endTime = love.timer.getTime()
    if theGame.isWin then
      sounds.win:play()
    else
      sounds.bang:play()
    end
  elseif (theGame.state == 'done') and (newState == 'config') then
    -- Done --> config
    theGame.endTime = nil
    theGame.lastBombTime = nil
    theGame.isShowingBombs = nil
    addAction { text='Toggle music', key='m', callback=function(s) toggleMusic(s) end }
  else
    -- Invalid
    error('switchGameStateTo: invalid transition from state '..tostring(theGame.state)..' to '..tostring(newState))
  end
  -- Now finally switch the state value
  theGame.state = newState
  theGame.stateStartTime = love.timer.getTime()
end

function drawActionMenu()
  local gapX = 5
  local textMarginX = 4
  local height, rectH = 18, 17
  local drawStartX, drawStartY = 3, love.graphics.getHeight() - height
  local drawX = drawStartX
  love.graphics.setFont(font1)
  for _, action in ipairs(theGame.actions) do
    local rectW = 0
    local text1, text1W = textMeasured(action.text)
    local text2, text2W = textMeasured(keyDisplayName(action.key))
    rectW = textMarginX + text1W + gapX + text2W + textMarginX
    -- save rectangle bounds to the action's table
    action.rectX, action.rectY = drawX, drawStartY
    action.rectW, action.rectH = rectW, rectH
    -- check if mouse hovers over the button
    if isPointInsideRect(love.mouse.getX(),love.mouse.getY(),action.rectX,action.rectY,action.rectW,action.rectH) then
      love.graphics.setColor(0.9, 0.9, 1)
    else
      love.graphics.setColor(1,1,1)
    end
    love.graphics.rectangle('fill', drawX, drawStartY, rectW, rectH)
    if action.color then
      love.graphics.setColor(unpack(action.color))
    else
      love.graphics.setColor(0,0,0)
    end
    love.graphics.rectangle('line', drawX, drawStartY, rectW, rectH)
    love.graphics.print(text1, drawX + textMarginX, drawStartY)
    love.graphics.setColor(0.09,0.09,0.8)
    love.graphics.print(text2, drawX + textMarginX + text1W + gapX, drawStartY)
    drawX = drawX + rectW + gapX
  end
  return drawX
end

function keyDisplayName(key)
  if key == 'escape' then key = 'esc' end
  if key == 'return' then key = 'enter' end
  local capitalized = string.upper(string.sub(key,1,1))..string.sub(key,2)
  return '['..capitalized..']'
end

function measureText(text, font)
  local f = font or love.graphics.getFont()
  return math.ceil(f:getWidth(text)), math.ceil(f:getHeight())
end

function updateBlinkingFlags()
  local now = love.timer.getTime()
  if now - theGame.lastBlinkTime > 0.5 then
    theGame.lastBlinkTime = now
    theGame.showFlags = not theGame.showFlags
  end
end

function isPointInsideRect(px, py, rx, ry, rw, rh)
  return rx <= px and px <= rx + rw and ry <= py and py <= ry + rh
end

function gameClampBombs(game)
  local rows, cols = game.configRows, game.configCols
  local maxBombs = (rows * cols * 2) / 3
  game.configBombCount = clamp(game.configBombCount, MIN_BOMBS, maxBombs)
end

function drawInfo(timeSeconds)
  assert(type(timeSeconds) == 'number')
  local x1, y1 = getCenterField()
  y1 = y1 - 2 * theFieldTileSize
  drawTime(x1 - theFieldTileSize + 5, y1 + 8, timeSeconds)
  local x2 = theGame.fieldX + theFieldTileSize * theGame.field.cols - 30
  drawBombCount(theGame.configBombCount, x2, y1)
  local x3 = x2 - 96
  drawFlagCount(theGame.flagCount, x3, y1)
end

function getPlayTime()
  local now = love.timer.getTime()
  local startTime = theGame.startTime or now
  local lastTime = theGame.endTime or now
  return lastTime - startTime
end

function secondsToHMS(seconds)
  local h = math.floor(seconds / 3600)
  seconds = math.floor(seconds - h * 3600)
  assert(0 <= seconds and seconds < 3600)
  local m = math.floor(seconds / 60)
  seconds = math.floor(seconds - m * 60)
  assert(0 <= m and m < 60)
  local s = seconds
  assert(0 <= s and s < 60)
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
  assert(member(digit, {':',0,1,2,3,4,5,6,7,8,9}))
  local quad = digits[digit]
  assert(quad, 'cannot draw digit "'..digit..'"')
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
    error('unexpected flag value: '..tostring(val))
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
  theGame.isWin = false
  theGame.lastBombTime = nil
  switchGameStateTo('done')
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
    -- Iterate over the 8 neighbors of the bomb and increment the bomb count for each one
    for row = centerRow-1, centerRow+1 do
      for col = centerCol-1, centerCol+1 do
        if isOnField(row, col, aField) and (row ~= centerRow or col ~= centerCol) then
          local pos = {row,col}
          local prevVal = aField.numbers[pos]
          if prevVal then
            aField.numbers[pos] = prevVal + 1
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
  local coord = {r,c}
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
  assert(count < fieldSpots, 'not enough room for adding some bombs')
  aField.bombs = Sparse2D.new()
  for i = 1, count do
    local r, c
    repeat
      r = love.math.random(2, aField.rows - 1)
      c = love.math.random(2, aField.cols - 1)
    until (r ~= safeRow or c ~= safeCol) and (aField.bombs[{r,c}] ~= 'mine')
    aField.bombs[{r,c}] = 'mine'
  end
  arrangeBombsEasier(aField, safeRow, safeCol)
  addFieldNumbers(aField)
end

function arrangeBombsEasier(aField, safeRow, safeCol)
  -- If a non-mine tile has its 4-neighbors all as mines, then swap it with one of the mines.
  -- Do rows+cols number of iterations.
  -- swapCount = 0
  local dirs = { {1,0}, {-1,0}, {0,1}, {0,-1} }
  local iterations = aField.rows + aField.cols
  for bombPos, _ in pairs(aField.bombs) do
    local bombRow, bombCol = unpack(bombPos)
    for _, delta in ipairs(dirs) do
      local changeRow, changeCol = unpack(delta)
      local row, col = bombRow + changeRow, bombCol + changeCol
      if not aField.bombs[{row, col}] then
        local neighborCount = 0
        for _, change2 in ipairs(dirs) do
          local changeRow2, changeCol2 = unpack(change2)
          if aField.bombs[{row + changeRow2, col + changeCol2}] then
            neighborCount = neighborCount + 1
          end
        end
        if neighborCount == 4 then
          -- swap
          -- swapCount = swapCount + 1
          aField.bombs[bombPos] = nil
          aField[{row, col}] = 'mine'
        end
        break
      end
      iterations = iterations - 1
      if iterations == 0 then return end
    end
  end
end

function isGameWon()
  if gameOver then return false end
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
  return true
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
    if theGame.bombDelay > 0.12 then
      theGame.bombDelay = theGame.bombDelay * 0.90
    end
    -- reveal one bomb and return unless there were none revealed
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

function addAction(action)
  theGame.actions[1 + #theGame.actions] = action
end

function toggleMusic(actionObj)
  actionObj.isActive = not actionObj.isActive
  if actionObj.isActive then
    actionObj.text = 'Turn music off'
  else
    actionObj.text = 'Turn music on'
  end
end

function textMeasured(text, font)
  local f = font or love.graphics.getFont()
  return text, measureText(text, font)
end

function actionQuit()
  if theGame.state == 'menu' then
    love.event.quit()
  else
    love.audio.stop(sounds.accept, sounds.reject)
    sounds.reject:play()
    switchGameStateTo('menu')
  end
end

function showCredits()
  sounds.info:stop()
  sounds.info:play()
  toggleOnlyOverlay('creditsInfo')
end

function toggleOnlyOverlay(name)
  local target = theGame.overlays[name]
  assert(target)
  local newValue = not target.isActive
  for _, v in pairs(theGame.overlays) do
    v.isActive = false
  end
  theGame.overlays[name].isActive = newValue
  return newValue
end

function showHelp()
  love.audio.stop(sounds.accept, sounds.reject, sounds.win, sounds.bang, sounds.info)
  sounds.info:play()
  if theGame.state == 'menu' then
    toggleOnlyOverlay('menuInfo')
  elseif theGame.state == 'config' then
    toggleOnlyOverlay('configInfo')
  elseif theGame.state == 'play' or theGame.state == 'done' then
    toggleOnlyOverlay('playInfo')
  end
end

function menuPlayButton()
  sounds.accept:stop()
  sounds.accept:play()
  switchGameStateTo('config')
end

function configPlayButton()
  sounds.accept:stop()
  sounds.accept:play()
  switchGameStateTo('play')
end

function drawOverlays()
  local i = 0
  for _, overlay in pairs(theGame.overlays) do
    assert(type(overlay) == 'table')
    if overlay.isActive then
      love.graphics.setColor(0.9, 0.9, 0.9)
      love.graphics.rectangle('fill', overlay.x, overlay.y, overlay.width, overlay.height)
      love.graphics.setColor(0.76, 0.76, 0.76)
      love.graphics.rectangle('line', overlay.x, overlay.y, overlay.width, overlay.height)
      local text, textW, textH = textMeasured(overlay.title, font2)
      local titleX = overlay.x + math.floor((overlay.width - textW)/2)
      local titleY = overlay.y + 15
      love.graphics.setFont(font2)
      love.graphics.setColor(0,0,0)
      love.graphics.print(text, titleX, titleY)
      local textX = overlay.x + 20
      local textY = titleY + textH + 20
      love.graphics.setFont(font1)
      local factor = overlay.bodyTextSpacing or 1
      love.graphics.getFont():setLineHeight(factor)
      love.graphics.print(overlay.bodyText, textX, textY)
      if overlay.extraText then
        for _, extraText in ipairs(overlay.extraText) do
          love.graphics.print(extraText.text, extraText.x, extraText.y)
        end
      end
    end
  end
end

function requireAudio(name, kind)
  local result = love.audio.newSource('audio/'..name, kind)
  assert(result)
  return result
end