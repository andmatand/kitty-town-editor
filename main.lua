WINDOW_W = 640
WINDOW_H = 480
FULLSCREEN_W = 1600
FULLSCREEN_H = 900
MIN_ZOOM = 1
MAX_ZOOM = 8
CURSOR_SCALE = 2

function love.load()
    SetGraphicsMode(false)
    love.graphics.setCaption('kitty-town editor')
    love.mouse.setVisible(false)
    love.graphics.setDefaultImageFilter('nearest', 'nearest')

    -- Load the cursors
    cursorImages = {}
    for _, name in pairs({'erase', 'grab'}) do
        cursorImages[name] = love.graphics.newImage('res/img/cursor-' ..
                                                    name .. '.png')
    end

    -- Load all images in the images folder
    IMAGES_PATH = 'images'
    palette = {tiles = {}}
    local index = 1
    for _, file in pairs(love.filesystem.enumerate(IMAGES_PATH)) do
        if file:sub(-4) == '.png' or file:sub(-4) == '.bmp' then
            local extensionStart = file:find('%..+$')
            local name = file:sub(0, extensionStart - 1)

            local image = love.graphics.newImage(IMAGES_PATH .. '/' .. file)
            
            if image then
                print(name)
                palette.tiles[index] = {index = index,
                                        name = name,
                                        image = image}
                index = index + 1
            end
        end
    end

    if #palette.tiles == 0 then
        print('In order to use this program, you must add images to the ' ..
              'images directory here.')
        love.event.quit()
    end

    zoom = 1
    canvas = {position = {x = 0, y = 0},
              tiles = {}}
    cursor = {focus = 'canvas',
              position = {x = 0, y = 0},
              state = 'draw'}
    currentTile = palette.tiles[1]
    undoTable = {canvasStates = {}}
end

function ShowPalette()
    cursor.state = 'point'
    cursor.focus = 'palette'
end

function HidePalette()
    cursor.state = 'point'
    cusor.focus = 'canvas'
end

function SaveStateForUndo()
    local tiles = {}
    for i, tile in pairs(canvas.tiles) do
        tiles[i] = tile
    end

    table.insert(undoTable.canvasStates, tiles)
end

function Undo()
    if #undoTable.canvasStates > 0 then
        canvas.tiles = table.remove(undoTable.canvasStates)
    end
end

function love.keypressed(key)
    local ctrl, shift
    if love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl') then
        ctrl = true
    else
        ctrl = false
    end
    if love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift') then
        shift = true
    else
        shift = false
    end

    movedCursorWithKeyboard = false

    if cursor.focus == 'canvas' then
        if key == 'left' then
            local moveAmount = 1
            if ctrl then moveAmount = currentTile.image:getWidth() end
            cursor.position.x = cursor.position.x - moveAmount
            movedCursorWithKeyboard = true
        elseif key == 'right' then
            local moveAmount = 1
            if ctrl then moveAmount = currentTile.image:getWidth() end
            cursor.position.x = cursor.position.x + moveAmount
            movedCursorWithKeyboard = true
        elseif key == 'up' then
            local moveAmount = 1
            if ctrl then moveAmount = currentTile.image:getHeight() end
            cursor.position.y = cursor.position.y - moveAmount
            movedCursorWithKeyboard = true
        elseif key == 'down' then
            local moveAmount = 1
            if ctrl then moveAmount = currentTile.image:getHeight() end
            cursor.position.y = cursor.position.y + moveAmount
            movedCursorWithKeyboard = true
        end
    end

    if movedCursorWithKeyboard then
        MoveMouseToCursor()
    end

    if ctrl then
        if key == '-' then
            SetZoom(zoom - 1)
        elseif key == '=' then
            SetZoom(zoom + 1)
        end
    end

    if cursor.focus == 'canvas' and cursor.state == 'draw' then
        if key == 'tab' then
            local nextIndex
            if shift then
                nextIndex = currentTile.index - 1
            else
                nextIndex = currentTile.index + 1
            end

            if nextIndex > #palette.tiles then nextIndex = 1 end
            if nextIndex < 1 then nextIndex = #palette.tiles end
            currentTile = palette.tiles[nextIndex]
        end
    end

    if cursor.focus == 'canvas' then
        if ctrl then
            if key == 'z' then
                Undo()
            elseif key == 's' then
                SaveRoom('testroom')
            elseif key == 'o' then
                LoadRoom('testroom')
            end
        end

        if (not ctrl) and (not shift) then
            if key == 'd' then
                cursor.state = 'draw'
            elseif key == 'e' then
                cursor.state = 'erase'
            elseif key == 'v' then
                currentTile.flipVertical = not currentTile.flipVertical
            elseif key == 'h' then
                currentTile.flipHorizontal = not currentTile.flipHorizontal
            elseif key == 'f11' then
                local _, _, fullscreen = love.graphics.getMode()
                SetGraphicsMode(not fullscreen)
            elseif key == 'space' then
                ShowPalette()
            end

            if key == 'return' then
                if cursor.state == 'draw' then
                    PlaceTileUnderCursor(currentTile)
                elseif cursor.state == 'erase' then
                    EraseTileUnderCursor()
                end
            end
        end
    end

    if cursor.focus == 'palette' then
        if (not ctrl) and (not shift) then
            if key == 'space' then
                HidePalette()
            end
        end
    end
end

function SetGraphicsMode(fullscreen)
    if fullscreen then
        love.graphics.setMode(FULLSCREEN_W, FULLSCREEN_H, true, true)
    else
        love.graphics.setMode(WINDOW_W, WINDOW_H, false, true)
    end
end

function SetZoom(newZoom)
    if newZoom >= MIN_ZOOM and newZoom <= MAX_ZOOM then
        local recenterDelta = {
            x = (love.graphics.getWidth() / 2),
            y = (love.graphics.getHeight() / 2)}
        if newZoom > zoom then
            recenterDelta.x = -recenterDelta.x
            recenterDelta.y = -recenterDelta.y
        elseif newZoom == zoom then
            recenterDelta.x = 0
            recenterDelta.y = 0
        end

        canvas.position.x = math.floor(canvas.position.x + recenterDelta.x)
        canvas.position.y = math.floor(canvas.position.y + recenterDelta.y)

        zoom = newZoom
    end
end

function DrawTile(tile, position, origin)
    local x, y, sx, sy

    if position then
        x = position.x
        y = position.y
    elseif tile.position then
        x = tile.position.x
        y = tile.position.y
    end
    sx = 1
    sy = 1

    if tile.flipHorizontal then
        sx = -1
        if not origin then x = x + tile.image:getWidth() end
    end
    if tile.flipVertical then
        sy = -1
        if not origin then y = y + tile.image:getHeight() end
    end

    if not origin then
        origin = {x = 0, y = 0}
    end

    love.graphics.draw(tile.image, x, y, 0, sx, sy, origin.x, origin.y)
end

function StartCanvasMovement()
    canvasMovement = {}
    canvasMovement.cursorOrigin = {x = cursor.position.x,
                                  y = cursor.position.y}
    canvasMovement.canvasOrigin = {x = canvas.position.x,
                                   y = canvas.position.y}
    canvasMovement.oldCursorState = cursor.state
    cursor.state = 'grab'
end

function EndCanvasMovement()
    cursor.state = canvasMovement.oldCursorState
    canvasMovement = nil
end

function RectangleOverlap(x1, y1, w1, h1, x2, y2, w2, h2)
    if x1 + (w1 - 1) >= x2 and
       x1 <= x2 + (w2 - 1) and
       y1 + (h1 - 1) >= y2 and
       y1 <= y2 + (h2 - 1) then
        return true
    else
        return false
    end
end

function GetTileIndexUnderCursor()
    local highestTileIndex
 
    -- Find the tile under the cursor that is closest to the "front" in regards
    -- to drawing order
    for i, tile in pairs(canvas.tiles) do
        local cursorPos = GetCursorPositionOnCanvas()
        if RectangleOverlap(cursorPos.x, cursorPos.y,
                            CURSOR_SCALE, CURSOR_SCALE,
                            tile.position.x, tile.position.y,
                            tile.image:getWidth(), tile.image:getHeight()) then
            highestTileIndex = i
        end
    end

    return highestTileIndex
end

function EraseTileUnderCursor()
    local tile = GetTileIndexUnderCursor()

    if tile then
        SaveStateForUndo()
        table.remove(canvas.tiles, tile)
    end
end

function love.mousepressed(x, y, button)
    -- If ctrl is pressed
    if love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl') then
        if button == 'wd' then
            SetZoom(zoom - 1)
        elseif button == 'wu' then
            SetZoom(zoom + 1)
        end

        if button == 'l' then
            StartCanvasMovement()
        end

    -- If no modifier keys are pressed
    else
        if button == 'l' then
            if cursor.focus == 'canvas' then
                if cursor.state == 'draw' then
                    PlaceTileUnderCursor(currentTile)
                elseif cursor.state == 'erase' then
                    EraseTileUnderCursor()
                end
            end
        elseif button == 'm' then
            StartCanvasMovement()
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 'l' or button == 'm' then
        if canvasMovement then
            EndCanvasMovement()
        end
    end
end

function GetCursorPositionOnCanvas()
    return {x = cursor.position.x - (canvas.position.x / zoom),
            y = cursor.position.y - (canvas.position.y / zoom)}
end

function PlaceTileUnderCursor(tile) 
    local position = GetCursorPositionOnCanvas()
    position.x = position.x - math.floor(tile.image:getWidth() / 2)
    position.y = position.y - math.floor(tile.image:getHeight() / 2)

    PlaceTile(tile, position)
end

function PlaceTile(tile, position)
    local newTile = {}
    for k, v in pairs(tile) do
        newTile[k] = v
    end
    newTile.position = {x = position.x, y = position.y}

    SaveStateForUndo()
    table.insert(canvas.tiles, newTile)
end

function AlignToGrid(position)
    position.x = math.floor(position.x / zoom) * zoom
    position.y = math.floor(position.y / zoom) * zoom
end

function MoveCursorWithMouse()
    local mouseCursorPosition = {x = math.floor(love.mouse.getX() / zoom),
                                 y = math.floor(love.mouse.getY() / zoom)}

    -- If the mouse moved
    if mouseCursorPosition.x ~= cursor.position.x or
       mouseCursorPosition.y ~= cursor.position.y then
        -- Use the mouse position as the position of the cursor
        cursor.position.x = mouseCursorPosition.x
        cursor.position.y = mouseCursorPosition.y
    end
end

function love.update()
    -- Make sure the canvas is aligned to the grid
    AlignToGrid(canvas.position)
    
    MoveCursorWithMouse()

    if canvasMovement then
        if love.mouse.isDown('m') or
           ((love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl'))
            and love.mouse.isDown('l')) then
            MoveCanvasWithCursor()
        end
    end
end

function MoveCanvasWithCursor()
    local diff = {x = cursor.position.x - canvasMovement.cursorOrigin.x,
                  y = cursor.position.y - canvasMovement.cursorOrigin.y}

    canvas.position.x = canvasMovement.canvasOrigin.x + (diff.x * zoom);
    canvas.position.y = canvasMovement.canvasOrigin.y + (diff.y * zoom);
end

function MoveMouseToCursor()
    love.mouse.setPosition(cursor.position.x * zoom, cursor.position.y * zoom)
end

function DrawCanvas()
    for _, tile in pairs(canvas.tiles) do
        DrawTile(tile)
    end
end

function DrawCursor()
    if cursor.state == 'draw' then
        love.graphics.push()
        love.graphics.scale(zoom, zoom)

        local origin = {x = math.floor(currentTile.image:getWidth() / 2),
                        y = math.floor(currentTile.image:getHeight() / 2)}

        DrawTile(currentTile, cursor.position, origin)

        love.graphics.pop()
        return
    end

    local cursorImage
    local cursorOrigin = {}
    if cursor.state == 'erase' then
        cursorImage = cursorImages['erase']
    elseif cursor.state == 'grab' then
        cursorImage = cursorImages['grab']
    end

    -- If the cursor origin has not been specifically set
    if #cursorOrigin == 0 then
        -- Use the center as the default origin
        cursorOrigin.x = math.floor(cursorImage:getWidth() / 2)
        cursorOrigin.y = math.floor(cursorImage:getHeight() / 2)
    end

    love.graphics.draw(cursorImage,
                       cursor.position.x * zoom, cursor.position.y * zoom,
                       0, CURSOR_SCALE, CURSOR_SCALE,
                       cursorOrigin.x, cursorOrigin.y)
end

function love.draw()
    love.graphics.setColor(255, 255, 255)

    love.graphics.push()
    love.graphics.translate(canvas.position.x, canvas.position.y)
    love.graphics.scale(zoom, zoom)
    DrawCanvas()
    love.graphics.pop()

    DrawCursor()

    --local cursorPos = GetCursorPositionOnCanvas()
    --love.graphics.setColor(255, 0, 0)
    --love.graphics.rectangle('line', cursorPos.x, cursorPos.y,
    --                        CURSOR_SCALE, CURSOR_SCALE)

    --if #canvas.tiles > 0 then
    --    local tile = canvas.tiles[1]
    --    love.graphics.setColor(0, 255, 0)
    --    love.graphics.rectangle('line', tile.position.x, tile.position.y,
    --                            tile.image:getWidth(), tile.image:getHeight())
    --end
end

function SaveRoom(filename)
    local file = love.filesystem.newFile(filename)
    file:open('w')

    for _, tile in pairs(canvas.tiles) do
        local line = ''
        line = line .. tile.name .. ','
        line = line .. tile.position.x .. ','
        line = line .. tile.position.y .. ','

        local flipHorizontal = (tile.flipHorizontal and '1' or '0')
        line = line .. flipHorizontal .. ','

        local flipVertical = (tile.flipVertical and '1' or '0')
        line = line .. flipVertical
        line = line .. '\n'

        file:write(line)
    end

    file:close()
end

function LoadRoom(filename)
    local file = love.filesystem.newFile(filename)
    file:open('r')

    local tiles = {}
    local i = 1
    for line in file:lines() do
        local tile = {position = {}}

        local j = 1
        for value in line:gmatch("[^,\n]+") do
            if j == 1 then
                tile.name = value

                -- Find the palette tile that has this name
                for _, paletteTile in pairs(palette.tiles) do
                    if paletteTile.name == tile.name then
                        tile.image = paletteTile.image
                        break
                    end
                end

                if not tile.image then
                    print('error loading tile "' .. tile.name .. '": ' ..
                          'name not found in palette')
                    break
                end
            elseif j == 2 then
                tile.position.x = tonumber(value)
            elseif j == 3 then
                tile.position.y = tonumber(value)
            elseif j == 4 then
                tile.flipHorizontal = (value == '1' and true or false)
            elseif j == 5 then
                tile.flipVertical = (value == '1' and true or false)
            end

            j = j + 1
        end

        tiles[i] = tile
        i = i + 1
    end

    SaveStateForUndo()
    canvas.tiles = tiles

    file:close()
end
