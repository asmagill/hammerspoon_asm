--- === hs.canvas.turtle ===
---
--- Creates a view which can be assigned to an `hs.canvas` object of type "canvas" which displays graphical images rendered in a style similar to that of the Logo language, sometimes referred to as "Turtle Graphics".
---
--- Briefly, turtle graphics are vector graphics using a relative cursor (the "turtle") upon a Cartesian plane. The view created by this module has its origin in the center of the display area. The Y axis grows positively as you move up and negatively as you move down from this origin (this is the opposite of the internal coordinates of other `hs.canvas` objects); similarly, movement left is positive movement along the X axis, while movement right is negative.
---
--- The turtle is initially visible with a heading of 0 degrees (pointing straight up), and the pen (the drawing element of the turtle) is down with a black color in paint mode. All of these can be adjusted by methods within this module.
---
---
--- Some of the code included in this module was influenced by or written to mimic behaviors described at:
---  * https://people.eecs.berkeley.edu/~bh/docs/html/usermanual_6.html#GRAPHICS
---  * https://www.calormen.com/jslogo/#
---  * https://github.com/inexorabletash/jslogo

local USERDATA_TAG = "hs.canvas.turtle"
local module       = require(USERDATA_TAG..".internal")
local turtleMT     = hs.getObjectMetatable(USERDATA_TAG)

local color    = require("hs.drawing.color")
local inspect  = require("hs.inspect")
local fnutils  = require("hs.fnutils")
local canvas   = require("hs.canvas")
local screen   = require("hs.screen")
local eventtap = require("hs.eventtap")
local mouse    = require("hs.mouse")

-- don't need these directly, just their helpers
require("hs.image")

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- borrowed and (very) slightly modified from https://www.calormen.com/jslogo/#; specifically
-- https://github.com/inexorabletash/jslogo/blob/02482525925e399020f23339a0991d98c4f088ff/turtle.js#L129-L152
local betterTurtle = canvas.new{ x = 100, y = 100, h = 45, w = 45 }:appendElements{
    {
        type           = "segments",
        action         = "strokeAndFill",
        strokeColor    = { green = 1 },
        fillColor      = { green = .75, alpha = .25 },
        frame          = { x = 0, y = 0, h = 40, w = 40 },
        strokeWidth    = 2,
        transformation = canvas.matrix.translate(22.5, 24.5),
        coordinates    = {
            { x =    0, y =  -20 },
            { x =  2.5, y =  -17 },
            { x =    3, y =  -12 },
            { x =    6, y =  -10 },
            { x =    9, y =  -13 },
            { x =   13, y =  -12 },
            { x =   18, y =   -4 },
            { x =   18, y =    0 },
            { x =   14, y =   -1 },
            { x =   10, y =   -7 },
            { x =    8, y =   -6 },
            { x =   10, y =   -2 },
            { x =    9, y =    3 },
            { x =    6, y =   10 },
            { x =    9, y =   13 },
            { x =    6, y =   15 },
            { x =    3, y =   12 },
            { x =    0, y =   13 },
            { x =   -3, y =   12 },
            { x =   -6, y =   15 },
            { x =   -9, y =   13 },
            { x =   -6, y =   10 },
            { x =   -9, y =    3 },
            { x =  -10, y =   -2 },
            { x =   -8, y =   -6 },
            { x =  -10, y =   -7 },
            { x =  -14, y =   -1 },
            { x =  -18, y =    0 },
            { x =  -18, y =   -4 },
            { x =  -13, y =  -12 },
            { x =   -9, y =  -13 },
            { x =   -6, y =  -10 },
            { x =   -3, y =  -12 },
            { x = -2.5, y =  -17 },
            { x =    0, y =  -20 },
        },
    },
}:imageFromCanvas()

-- Hide the internals from accidental usage
local _wrappedCommands  = module._wrappedCommands
-- module._wrappedCommands = nil

local _unwrappedSynonyms = {
    clearscreen = { "cs" },
    showturtle  = { "st" },
    hideturtle  = { "ht" },
    background  = { "bg" },
    textscreen  = { "ts" },
    fullscreen  = { "fs" },
    splitscreen = { "ss" },
    pencolor    = { "pc" },
--    shownp      = { "shown?" }, -- not a legal lua method name, so will need to catch when converter written
--    pendownp    = { "pendown?" },
}

-- in case I ever write something to import turtle code directly, don't want these to cause it to break immediately
local _nops = {
    wrap          = false, -- boolean indicates whether or not warning has been issued; don't want to spam console
    window        = false,
    fence         = false,
    textscreen    = false,
    fullscreen    = false,
    splitscreen   = false,
    refresh       = false,
    norefresh     = false,
    setpenpattern = true,  -- used in setpen, in case I ever actually implement it, so skip warning
}

local defaultPalette = {
    { "black",   { __luaSkinType = "NSColor", list = "Apple",   name = "Black" }},
    { "blue",    { __luaSkinType = "NSColor", list = "Apple",   name = "Blue" }},
    { "green",   { __luaSkinType = "NSColor", list = "Apple",   name = "Green" }},
    { "cyan",    { __luaSkinType = "NSColor", list = "Apple",   name = "Cyan" }},
    { "red",     { __luaSkinType = "NSColor", list = "Apple",   name = "Red" }},
    { "magenta", { __luaSkinType = "NSColor", list = "Apple",   name = "Magenta" }},
    { "yellow",  { __luaSkinType = "NSColor", list = "Apple",   name = "Yellow" }},
    { "white",   { __luaSkinType = "NSColor", list = "Apple",   name = "White" }},
    { "brown",   { __luaSkinType = "NSColor", list = "Apple",   name = "Brown" }},
    { "tan",     { __luaSkinType = "NSColor", list = "x11",     name = "tan" }},
    { "forest",  { __luaSkinType = "NSColor", list = "x11",     name = "forestgreen" }},
    { "aqua",    { __luaSkinType = "NSColor", list = "Crayons", name = "Aqua" }},
    { "salmon",  { __luaSkinType = "NSColor", list = "Crayons", name = "Salmon" }},
    { "purple",  { __luaSkinType = "NSColor", list = "Apple",   name = "Purple" }},
    { "orange",  { __luaSkinType = "NSColor", list = "Apple",   name = "Orange" }},
    { "gray",    { __luaSkinType = "NSColor", list = "x11",     name = "gray" }},
}

-- pulled from webkit/Source/WebKit/Shared/WebPreferencesDefaultValues.h 2020-05-17
module._fontMap = {
    serif          = "Times",
    ["sans-serif"] = "Helvetica",
    cursive        = "Apple Chancery",
    fantasy        = "Papyrus",
    monospace      = "Courier",
--     pictograph     = "Apple Color Emoji",
}

module._registerDefaultPalette(defaultPalette)
module._registerDefaultPalette = nil
module._registerFontMap(module._fontMap)
module._registerFontMap = nil

local finspect = function(obj)
    return inspect(obj, { newline = " ", indent = "" })
end

local _backgroundQueues = setmetatable({}, {
    __mode = "k",

    -- work around for the fact that we're using selfRefCount to allow for auto-clean on __gc
    -- relies on the fact that these are only called if the key *doesn't* exist already in the
    -- table

    -- the following assume [<userdata>] = { table } in weak-key table; if you're not
    --     saving a table of values keyed to the userdata, all bets are off and you'll
    --     need to write something else

    __index = function(self, key)
        for k,v in pairs(self) do
            if k == key then
                -- put *this* key in with the same table so changes to the table affect all
                -- "keys" pointing to this table
                rawset(self, key, v)
                return v
            end
        end
        return nil
    end,

    __newindex = function(self, key, value)
        local haslogged = false
        -- only called for a complete re-assignment of the table if __index wasn't
        -- invoked first...
        for k,v in pairs(self) do
            if k == key then
                if type(value) == "table" and type(v) == "table" then
                    -- do this to keep the target table for existing useradata the same
                    -- because it may have multiple other userdatas pointing to it
                    for k2, v2 in pairs(v) do v[k2] = nil end
                    -- shallow copy -- can't have everything or this will get insane
                    for k2, v2 in pairs(value) do v[k2] = v2 end
                    rawset(self, key, v)
                    return
                else
                    -- we'll try... replace *all* existing matches (i.e. don't return after 1st)
                    -- but since this will never get called if __index was invoked first, log
                    -- warning anyways because this *isn't* what these additions are for...
                    if not haslogged then
                        hs.luaSkinLog.wf("%s - weak table indexing only works when value is a table; behavior is undefined for value type %s", USERDATA_TAG, type(value))
                        haslogged = true
                    end
                    rawset(self, k, value)
                end
            end
        end
        rawset(self, key, value)
    end,
})

-- Public interface ------------------------------------------------------

local _new = module.new
module.new = function(...) return _new(...):_turtleImage(betterTurtle) end

module.turtleCanvas = function(...)
    local decorateSize      = 16
    local recalcDecorations = function(nC, decorate)
        if decorate then
            local frame = nC:frame()
            nC.moveBar.frame = {
                x = 0,
                y = 0,
                h = decorateSize,
                w = frame.w
            }
            nC.resizeX.frame = {
                x = frame.w - decorateSize,
                y = decorateSize,
                h = frame.h - decorateSize * 2,
                w = decorateSize
            }
            nC.resizeY.frame = {
                x = 0,
                y = frame.h - decorateSize,
                h = decorateSize,
                w = frame.w - decorateSize,
            }
            nC.resizeXY.frame = {
                x = frame.w - decorateSize,
                y = frame.h - decorateSize,
                h = decorateSize,
                w = decorateSize
            }

            nC.turtleView.frame = {
                x = 0,
                y = decorateSize,
                h = frame.h - decorateSize * 2,
                w = frame.w - decorateSize,
            }
        end
    end

    local args = table.pack(...)
    local frame, decorate = {}, true
    local decorateIdx = 2
    if type(args[1]) == "table" then
        frame, decorateIdx = args[1], 2
    end
    if args.n >= decorateIdx then decorate = args[decorateIdx] end

    frame = frame or {}
    local screenFrame = screen.mainScreen():fullFrame()
    local defaultFrame = {
        x = screenFrame.x + screenFrame.w / 4,
        y = screenFrame.y + screenFrame.h / 4,
        h = screenFrame.h / 2,
        w = screenFrame.w / 2,
    }
    frame.x = frame.x or defaultFrame.x
    frame.y = frame.y or defaultFrame.y
    frame.w = frame.w or defaultFrame.w
    frame.h = frame.h or defaultFrame.h

    local _cMouseAction -- make local here so it's an upvalue in mouseCallback

    local nC = canvas.new(frame):show()
    if decorate then
        nC[#nC + 1] = {
            id          = "moveBar",
            type        = "rectangle",
            action      = "strokeAndFill",
            strokeColor = { white = 0 },
            fillColor   = { white = 1 },
            strokeWidth = 1,
        }
        nC[#nC + 1] = {
            id          = "resizeX",
            type        = "rectangle",
            action      = "strokeAndFill",
            strokeColor = { white = 0 },
            fillColor   = { white = 1 },
            strokeWidth = 1,
        }
        nC[#nC + 1] = {
            id          = "resizeY",
            type        = "rectangle",
            action      = "strokeAndFill",
            strokeColor = { white = 0 },
            fillColor   = { white = 1 },
            strokeWidth = 1,
        }
        nC[#nC + 1] = {
            id          = "resizeXY",
            type        = "rectangle",
            action      = "strokeAndFill",
            strokeColor = { white = 0 },
            fillColor   = { white = 1 },
            strokeWidth = 1,
        }
        nC[#nC + 1] = {
            id            = "label",
            type          = "text",
            action        = "strokeAndFill",
            textSize      = decorateSize - 2,
            textAlignment = "center",
            text          = "TurtleCanvas",
            textColor     = { white = 0 },
            frame         = { x = 0, y = 0, h = decorateSize, w = "100%" },
        }
    end

    local turtleViewObject = module.new()
    nC[#nC + 1] = {
        id     = "turtleView",
        type   = "canvas",
        canvas = turtleViewObject,
    }

    recalcDecorations(nC, decorate)

    if decorate ~= nil then
        nC:clickActivating(false)
          :canvasMouseEvents(true, true)
          :mouseCallback(function(_c, _m, _i, _x, _y)
              if _i == "_canvas_" then
                  if _m == "mouseDown" then
                      local buttons = eventtap.checkMouseButtons()
                      if buttons.left then
                          local cframe     = _c:frame()
                          local inMoveArea = (_y < decorateSize)
                          local inResizeX  = (_x > (cframe.w - decorateSize))
                          local inResizeY  = (_y > (cframe.h - decorateSize))

                          if inMoveArea then
                              _cMouseAction = coroutine.wrap(function()
                                  while _cMouseAction do
                                      local pos = mouse.absolutePosition()
                                      local frame = _c:frame()
                                      frame.x = pos.x - _x
                                      frame.y = pos.y - _y
                                      _c:frame(frame)
                                      recalcDecorations(_c, decorate)
                                      coroutine.applicationYield()
                                  end
                              end)
                              _cMouseAction()
                          elseif inResizeX or inResizeY then

                              _cMouseAction = coroutine.wrap(function()
                                  while _cMouseAction do
                                      local pos = mouse.absolutePosition()
                                      local frame = _c:frame()
                                      if inResizeX then
                                          local newW = pos.x + cframe.w - _x - frame.x
                                          if newW < decorateSize then newW = decorateSize end
                                          frame.w = newW
                                      end
                                      if inResizeY then
                                          local newY = pos.y + cframe.h - _y - frame.y
                                          if newY < (decorateSize * 2) then newY = (decorateSize * 2) end
                                          frame.h = newY
                                      end
                                      _c:frame(frame)
                                      recalcDecorations(_c, decorate)
                                      coroutine.applicationYield()
                                  end
                              end)
                              _cMouseAction()
                          end
                      elseif buttons.right then
                          local modifiers = eventtap.checkKeyboardModifiers()
                          if modifiers.shift then _c:hide() end
                      end
                  elseif _m == "mouseUp" then
                      _cMouseAction = nil
                  end
              end
          end)
    end

    return turtleViewObject
end

-- methods with visual impact call this to allow for yields when we're running in a coroutine
local coroutineFriendlyCheck = function(self)
    -- don't get tripped up by other coroutines
    if _backgroundQueues[self] and _backgroundQueues[self].ourCoroutine then
        if not self:_neverYield() then
            local thread, isMain = coroutine.running()
            if not isMain and (self:_cmdCount() % self:_yieldRatio()) == 0 then
                coroutine.applicationYield()
            end
        end
    end
end

--- hs.canvas.turtle:pos() -> table
--- Method
--- Returns the turtle’s current position, as a table containing two numbers, the X and Y coordinates.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing the X and Y coordinates of the turtle.
local _pos = turtleMT.pos
turtleMT.pos = function(...)
    local result = _pos(...)
    return setmetatable(result, {
        __tostring = function(_) return string.format("{ %.2f, %.2f }", _[1], _[2]) end
    })
end

--- hs.canvas.turtle:pensize() -> turtleViewObject
--- Method
--- Returns a table of two positive integers, specifying the horizontal and vertical thickness of the turtle pen.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table specifying the horizontal and vertical thickness of the turtle pen.
---
--- Notes:
---  * in this implementation the two numbers will always be equal as the macOS uses a single width for determining stroke size.
local _pensize = turtleMT.pensize
turtleMT.pensize = function(...)
    local result = _pensize(...)
    return setmetatable(result, {
        __tostring = function(_) return string.format("{ %.2f, %.2f }", _[1], _[2]) end
    })
end

--- hs.canvas.turtle:scrunch() -> table
--- Method
--- Returns a table containing the current X and Y scrunch factors.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing the X and Y scrunch factors for the turtle view
local _scrunch = turtleMT.scrunch
turtleMT.scrunch = function(...)
    local result = _scrunch(...)
    return setmetatable(result, {
        __tostring = function(_) return string.format("{ %.2f, %.2f }", _[1], _[2]) end
    })
end

--- hs.canvas.turtle:labelsize() -> table
--- Method
--- Returns a table containing the height and width of characters rendered by [hs.canvas.turtle:label](#label).
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing the width and height of characters.
---
--- Notes:
---  * On most modern machines, font widths are variable for most fonts; as this is not easily calculated unless the specific text to be rendered is known, the height, as specified with [hs.canvas.turtle:setlabelheight](#setlabelheight) is returned for both values by this method.
local _labelsize = turtleMT.labelsize
turtleMT.labelsize = function(...)
    local result = _labelsize(...)
    return setmetatable(result, {
        __tostring = function(_) return string.format("{ %.2f, %.2f }", _[1], _[2]) end
    })
end

local __visibleAxes = turtleMT._visibleAxes
turtleMT._visibleAxes = function(...)
    local result = __visibleAxes(...)
    return setmetatable(result, {
        __tostring = function(_)
            return string.format("{ { %.2f, %.2f }, { %.2f, %.2f } }", _[1][1], _[1][2], _[2][1], _[2][2])
        end
    })
end

--- hs.canvas.turtle:pencolor() -> int | table
--- Method
--- Get the current pen color, either as a palette index number or as an RGB(A) list, whichever way it was most recently set.
---
--- Parameters:
---  * None
---
--- Returns:
---  * if the background color was most recently set by palette index, returns the integer specifying the index; if it was set as a 3 or 4 value table representing RGB(A) values, the table is returned; otherwise returns a color table as defined in `hs.drawing.color`.
---
--- Notes:
---  * Synonym: `hs.canvas.turtle:pc()`
local _pencolor = turtleMT.pencolor
turtleMT.pencolor = function(...)
    local result = _pencolor(...)
    if type(result) == "number" then return result end

    local defaultToString = finspect(result)
    return setmetatable(result, {
        __tostring = function(_)
            if #_ == 3 then
                return string.format("{ %.2f, %.2f, %.2f }", _[1], _[2], _[3])
            elseif #_ == 4 then
                return string.format("{ %.2f, %.2f, %.2f, %.2f }", _[1], _[2], _[3], _[4])
            else
                return defaultToString
            end
        end
    })
end

--- hs.canvas.turtle:background() -> int | table
--- Method
--- Get the background color, either as a palette index number or as an RGB(A) list, whichever way it was most recently set.
---
--- Parameters:
---  * None
---
--- Returns:
---  * if the background color was most recently set by palette index, returns the integer specifying the index; if it was set as a 3 or 4 value table representing RGB(A) values, the table is returned; otherwise returns a color table as defined in `hs.drawing.color`.
---
--- Notes:
---  * Synonym: `hs.canvas.turtle:bg()`
local _background = turtleMT.background
turtleMT.background = function(...)
    local result = _background(...)
    if type(result) == "number" then return result end

    local defaultToString = finspect(result)
    return setmetatable(result, {
        __tostring = function(_)
            if #_ == 3 then
                return string.format("{ %.2f, %.2f, %.2f }", _[1], _[2], _[3])
            elseif #_ == 4 then
                return string.format("{ %.2f, %.2f, %.2f, %.2f }", _[1], _[2], _[3], _[4])
            else
                return defaultToString
            end
        end
    })
end

--- hs.canvas.turtle:palette(index) -> table
--- Method
--- Returns the color defined at the specified palette index.
---
--- Parameters:
---  * `index` - an integer between 0 and 255 specifying the index in the palette of the desired coloe
---
--- Returns:
---  * a table specifying the color as a list of 3 or 4 numbers representing the intensity of the red, green, blue, and optionally alpha channels as a number between 0.0 and 100.0. If the color cannot be represented in RGB(A) format, then a table as described in `hs.drawing.color` is returned.
local _palette = turtleMT.palette
turtleMT.palette = function(...)
    local result = _palette(...)
    local defaultToString = finspect(result)
    return setmetatable(result, {
        __tostring = function(_)
            if #_ == 3 then
                return string.format("{ %.2f, %.2f, %.2f }", _[1], _[2], _[3])
            elseif #_ == 4 then
                return string.format("{ %.2f, %.2f, %.2f, %.2f }", _[1], _[2], _[3], _[4])
            else
                return defaultToString
            end
        end
    })
end

--- hs.canvas.turtle:towards(pos) -> number
--- Method
--- Returns the heading at which the turtle should be facing so that it would point from its current position to the position specified.
---
--- Parameters:
---  * `pos` - a position table containing the x and y coordinates as described in [hs.canvas.turtle:pos](#pos) of the point the turtle should face.
---
--- Returns:
---  * a number representing the heading the turtle should face to point to the position specified in degrees clockwise from the positive Y axis.
turtleMT.towards = function(self, pos)
    local x, y = pos[1], pos[2]
    assert(type(x) == "number", "expected a number for the x coordinate")
    assert(type(y) == "number", "expected a number for the y coordinate")

    local cpos = self:pos()
    return (90 - math.atan(y - cpos[2],x - cpos[1]) * 180 / math.pi) % 360
end

--- hs.canvas.turtle:screenmode() -> string
--- Method
--- Returns a string describing the current screen mode for the turtle view.
---
--- Parameters:
---  * None
---
--- Returns:
---  * "FULLSCREEN"
---
--- Notes:
---  * This method always returns "FULLSCREEN" for compatibility with translated Logo code; since this module only implements `textscreen`, `fullscreen`, and `splitscreen` as no-op methods to simplify conversion, no other return value is possible.
turtleMT.screenmode = function(self, ...) return "FULLSCREEN" end

--- hs.canvas.turtle:turtlemode() -> string
--- Method
--- Returns a string describing the current turtle mode for the turtle view.
---
--- Parameters:
---  * None
---
--- Returns:
---  * "WINDOW"
---
--- Notes:
---  * This method always returns "WINDOW" for compatibility with translated Logo code; since this module only implements `window`, `wrap`, and `fence` as no-op methods to simplify conversion, no other return value is possible.
turtleMT.turtlemode = function(self, ...) return "WINDOW" end

--- hs.canvas.turtle:pen() -> table
--- Method
--- Returns a table containing the pen’s position, mode, thickness, and hardware-specific characteristics.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing the contents of the following as entries:
---    * [hs.canvas.turtle:pendownp()](#pendownp)
---    * [hs.canvas.turtle:penmode()](#penmode)
---    * [hs.canvas.turtle:pensize()](#pensize)
---    * [hs.canvas.turtle:pencolor()](#pencolor)
---    * [hs.canvas.turtle:penpattern()](#penpattern)
---
--- Notes:
---  * the resulting table is suitable to be used as input to [hs.canvas.turtle:setpen](#setpen).
turtleMT.pen = function(self, ...)
    local pendown    = self:pendownp() and "PENDOWN" or "PENUP"
    local penmode    = self:penmode()
    local pensize    = self:pensize()
    local pencolor   = self:pencolor()
    local penpattern = self:penpattern()

    return setmetatable({ pendown, penmode, pensize, pencolor, penpattern }, {
        __tostring = function(_)
            return string.format("{ %s, %s, %s, %s, %s }",
                pendown,
                penmode,
                tostring(pensize),
                tostring(pencolor),
                tostring(penpattern)
            )
        end
    })
end

turtleMT.penpattern = function(self, ...)
    return nil
end

--- hs.canvas.turtle:setpen(state) -> turtleViewObject
--- Method
--- Sets the pen’s position, mode, thickness, and hardware-dependent characteristics.
---
--- Parameters:
---  * `state` - a table containing the results of a previous invocation of [hs.canvas.turtle:pen](#pen).
---
--- Returns:
---  * the turtleViewObject
turtleMT.setpen = function(self, ...)
    local args = table.pack(...)
    assert(args.n == 1, "setpen: expected only one argument")
    assert(type(args[1]) == "table", "setpen: expected table of pen state values")
    local details = args[1]

    assert(({ penup = true, pendown = true })[details[1]:lower()],               "setpen: invalid penup/down state at index 1")
    assert(({ paint = true, erase = true, reverse = true })[details[2]:lower()], "setpen: invalid penmode state at index 2")
    assert((type(details[3]) == "table") and (#details[3] == 2)
                                         and (type(details[3][1]) == "number")
                                         and (type(details[3][2]) == "number"),  "setpen: invalid pensize table at index 3")
    assert(({ string = true, number = true, table = true })[type(details[4])],   "setpen: invalid pencolor at index 4")
    assert(true,                                                                 "setpen: invalid penpattern at index 5") -- in case I add it

    turtleMT["pen" .. details[2]:lower()](self) -- penpaint, penerase, or penreverse
    turtleMT[details[1]:lower()](self)          -- penup or pendown (has to come after mode since mode sets pendown)
    self:setpensize(details[3])
    self:setpencolor(details[4])
    self:setpenpattern(details[5])              -- its a nop currently, but we're supressing it's output message
    return self
end

--- hs.canvas.turtle:_background(func, ...) -> turtleViewObject
--- Method
--- Perform the specified function asynchronously as coroutine that yields after a certain number of turtle commands have been executed. This gives turtle drawing which involves many steps the appearance of being run in the background, allowing other functions within Hammerspoon the opportunity to handle callbacks, etc.
---
--- Parameters:
---  * `func` - the function which contains the turtle commands to be executed asynchronously. This function should expect at least 1 argument -- `self`, which will be the turtleViewObject itself, and any other arguments passed to this method.
---  * `...` - optional additional arguments to be passed to `func` when it is invoked.
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * If a background function is already being run on the turtle view, this method will queue the new function to be executed when the currently running function, and any previously queued functions, have completed.
---
---  * Backgrounding like this may take a little longer to complete the function, but will not block Hammerspoon from completing other tasks and will make your system significantly more responsive during long running tasks.
---    * See [hs.canvas.turtle:_yieldRatio](#_yieldRatio) to adjust how many turtle commands are executed before each yield. This can have an impact on the total time a function takes to complete by trading Hammerspoon responsiveness for function speed.
---    * See [hs.canvas.turtle:_neverYield](#_neverYield) to prevent this behavior and cause the queued function(s) to run to completion before returning. If a function has already been backgrounded, once it resumes, the function will continue (followed by any additionally queued background functions) without further yielding.
---
---  * As an example, consider this function which generates a fern frond:
---
---       ```
---       fern = function(self, size, sign)
---           print(size, sign)
---           if (size >= 1) then
---               self:forward(size):right(70 * sign)
---               fern(self, size * 0.5, sign * -1)
---               self:left(70 * sign):forward(size):left(70 * sign)
---               fern(self, size * 0.5, sign)
---               self:right(70 * sign):right(7 * sign)
---               fern(self, size - 1, sign)
---               self:left(7 * sign):back(size * 2)
---           end
---       end
---
---       tc = require("hs.canvas.turtle")
---
---       -- drawing the two fronds without backgrounding:
---           t = os.time()
---           tc1 = tc.turtleCanvas()
---           tc1:penup():back(150):pendown()
---           fern(tc1, 25, 1)
---           fern(tc1, 25, -1)
---           print("Blocked for", os.time() - t) -- 4 seconds on my machine
---
---       -- drawing the two fronds with backgrounding
---           -- note that if we don't hide this while its drawing, it will take significantly longer
---           -- as Hammerspoon has to update the view as it's being built. With the hiding, this
---           -- also took 4 seconds on my machine to complete; without, it took 24. In both cases,
---           -- however, it didn't block Hammerspoon and allowed for a more responsive experience.
---           t = os.time()
---           tc2 = tc.turtleCanvas()
---           tc2:hide():penup()
---                     :back(150)
---                     :pendown()
---                     :_background(fern, 25, 1)
---                     :_background(fern, 25, -1)
---                     :_background(function(self)
---                         self:show()
---                         print("Completed in", os.time() - t)
---                     end)
---           print("Blocked for", os.time() - t)
---       ```
turtleMT._background = function(self, func, ...)
    if not (type(func) == "function" or (getmetatable(func) or {}).__call) then
        error("expected function for argument 1", 2)
    end

    local runner = _backgroundQueues[self] or { queue = {} }
    table.insert(runner.queue, fnutils.partial(func, self, ...))

    if not runner.ourCoroutine then
        _backgroundQueues[self] = runner
        runner.ourCoroutine = coroutine.wrap(function()
            while #runner.queue ~= 0 do
                table.remove(runner.queue, 1)()
            end
            runner.ourCoroutine = nil
        end)
        runner.ourCoroutine()
    end

    return self
end

turtleMT.bye = function(self, doItNoMatterWhat)
    local c = self:_canvas()
    if c then
        doItNoMatterWhat = doItNoMatterWhat or (c[#c].canvas == self and c[#c].id == "turtleView")
        if doItNoMatterWhat then
            if c[#c].canvas == self then
                c[#c].canvas = nil
            else
                for i = 1, #c, 1 do
                    if c[i].canvas == self then
                        c[i].canvas = nil
                        break
                    end
                end
            end
            c:delete()
        else
            log.f("bye - not a known turtle only canvas; apply delete method to parent canvas, or pass in `true` as argument to this method")
        end
    else
        log.f("bye - not attached to a canvas")
    end
end

turtleMT.show = function(self, doItNoMatterWhat)
    local c = self:_canvas()
    if c then
        doItNoMatterWhat = doItNoMatterWhat or (c[#c].canvas == self and c[#c].id == "turtleView")
        if doItNoMatterWhat then
            c:show()
        else
            log.f("show - not a known turtle only canvas; apply show method to parent canvas, or pass in `true` as argument to this method")
        end
    else
        log.f("show - not attached to a canvas")
    end
    return self
end

turtleMT.hide = function(self, doItNoMatterWhat)
    local c = self:_canvas()
    if c then
        doItNoMatterWhat = doItNoMatterWhat or (c[#c].canvas == self and c[#c].id == "turtleView")
        if doItNoMatterWhat then
            c:hide()
        else
            log.f("hide - not a known turtle only canvas; apply hide method to parent canvas, or pass in `true` as argument to this method")
        end
    else
        log.f("hide - not attached to a canvas")
    end
    return self
end


-- 6.1 Turtle Motion

--- hs.canvas.turtle:forward(dist) -> turtleViewObject
--- Method
--- Moves the turtle forward in the direction that it’s facing, by the specified distance. The heading of the turtle does not change.
---
--- Parameters:
---  * `dist` -  the distance the turtle should move forwards.
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs.canvas.turtle:fd(dist)`

--- hs.canvas.turtle:back(dist) -> turtleViewObject
--- Method
--- Move the turtle backward, (i.e. opposite to the direction that it's facing) by the specified distance. The heading of the turtle does not change.
---
--- Parameters:
---  * `dist` - the distance the turtle should move backwards.
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs.canvas.turtle:bk(dist)`

--- hs.canvas.turtle:left(angle) -> turtleViewObject
--- Method
--- Turns the turtle counterclockwise by the specified angle, measured in degrees
---
--- Parameters:
---  * `angle` - the number of degrees to adjust the turtle's heading counterclockwise.
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs.canvas.turtle:lt(angle)`

--- hs.canvas.turtle:right(angle) -> turtleViewObject
--- Method
--- Turns the turtle clockwise by the specified angle, measured in degrees
---
--- Parameters:
---  * `angle` - the number of degrees to adjust the turtle's heading clockwise.
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs.canvas.turtle:rt(angle)`

--- hs.canvas.turtle:setpos(pos) -> turtleViewObject
--- Method
--- Moves the turtle to an absolute position in the graphics window. Does not change the turtle's heading.
---
--- Parameters:
---  * `pos` - a table containing two numbers specifying the `x` and the `y` position within the turtle view to move the turtle to. (Note that this is *not* a point table with key-value pairs).
---
--- Returns:
---  * the turtleViewObject

--- hs.canvas.turtle:setxy(x, y) -> turtleViewObject
--- Method
--- Moves the turtle to an absolute position in the graphics window. Does not change the turtle's heading.
---
--- Parameters:
---  * `x` - the x coordinate of the turtle's new position within the turtle view
---  * `y` - the y coordinate of the turtle's new position within the turtle view
---
--- Returns:
---  * the turtleViewObject

--- hs.canvas.turtle:setx(x) -> turtleViewObject
--- Method
--- Moves the turtle horizontally from its old position to a new absolute horizontal coordinate. Does not change the turtle's heading.
---
--- Parameters:
---  * `x` - the x coordinate of the turtle's new position within the turtle view
---
--- Returns:
---  * the turtleViewObject

--- hs.canvas.turtle:sety(y) -> turtleViewObject
--- Method
--- Moves the turtle vertically from its old position to a new absolute vertical coordinate. Does not change the turtle's heading.
---
--- Parameters:
---  * `y` - the y coordinate of the turtle's new position within the turtle view
---
--- Returns:
---  * the turtleViewObject

--- hs.canvas.turtle:setheading(angle) -> turtleViewObject
--- Method
--- Sets the heading of the turtle to a new absolute heading.
---
--- Parameters:
---  * `angle` - The heading, in degrees clockwise from the positive Y axis, of the new turtle heading.
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs.canvas.turtle:seth(angle)`

--- hs.canvas.turtle:home() -> turtleViewObject
--- Method
--- Moves the turtle to the center of the turtle view.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * this is equivalent to `hs.canvas.turtle:setxy(0, 0):setheading(0)`.
---    * this does not change the pen state, so if the pen is currently down, a line may be drawn from the previous position to the home position.

--- hs.canvas.turtle:arc(angle, radius) -> turtleViewObject
--- Method
--- Draws an arc of a circle, with the turtle at the center, with the specified radius, starting at the turtle’s heading and extending clockwise through the specified angle. The turtle does not move.
---
--- Parameters:
---  * `angle` - the number of degrees the arc should extend from the turtle's current heading. Positive numbers indicate that the arc should extend in a clockwise direction, negative numbers extend in a counter-clockwise direction.
---  * `radius` - the distance from the turtle's current position that the arc should be drawn.
---
--- Returns:
---  * the turtleViewObject


-- 6.2 Turtle Motion Queries

-- pos     - documented where defined
-- xcor    - documented where defined
-- ycor    - documented where defined
-- heading - documented where defined
-- towards - documented where defined
-- scrunch - documented where defined


-- 6.3 Turtle and Window Control

-- showturtle     - documented where defined
-- hideturtle     - documented where defined
-- clean          - documented where defined
-- clearscreen    - documented where defined
-- wrap           - no-op -- implemented, but does nothing to simplify conversion to/from logo
-- window         - no-op -- implemented, but does nothing to simplify conversion to/from logo
-- fence          - no-op -- implemented, but does nothing to simplify conversion to/from logo
-- fill           - not implemented at present
-- filled         - not implemented at present; a similar effect can be had with `:fillStart()` and `:fillEnd()`

--- hs.canvas.turtle:label(text) -> turtleViewObject
--- Method
--- Displays a string at the turtle’s position current position in the current pen mode and color.
---
--- Parameters:
---  * `text` -
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * does not move the turtle

--- hs.canvas.turtle:setlabelheight(height) -> turtleViewObject
--- Method
--- Sets the font size for text displayed with the [hs.canvas.turtle:label](#label) method.
---
--- Parameters:
---  * `height` - a number specifying the font size
---
--- Returns:
---  * the turtleViewObject

-- textscreen     - no-op -- implemented, but does nothing to simplify conversion to/from logo
-- fullscreen     - no-op -- implemented, but does nothing to simplify conversion to/from logo
-- splitscreen    - no-op -- implemented, but does nothing to simplify conversion to/from logo

--- hs.canvas.turtle:setscrunch(xscale, yscale) -> turtleViewObject
--- Method
--- Adjusts the aspect ratio and scaling within the turtle view. Further turtle motion will be adjusted by multiplying the horizontal and vertical extent of the motion by the two numbers given as inputs.
---
--- Parameters:
---  * `xscale` - a number specifying the horizontal scaling applied to the turtle position
---  * `yscale` - a number specifying the vertical scaling applied to the turtle position
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * On old CRT monitors, it was common that pixels were not exactly square and this method could be used to compensate. Now it is more commonly used to create scaling effects.

-- refresh        - no-op -- implemented, but does nothing to simplify conversion to/from logo
-- norefresh      - no-op -- implemented, but does nothing to simplify conversion to/from logo


-- 6.4 Turtle and Window Queries

-- shownp     - documented where defined
-- screenmode - documented where defined
-- turtlemode - documented where defined
-- labelsize  - documented where defined


-- 6.5 Pen and Background Control

--- hs.canvas.turtle:pendown() -> turtleViewObject
--- Method
--- Sets the pen’s position to down so that movement methods will draw lines in the turtle view.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs.canvas.turtle:pd()`

--- hs.canvas.turtle:penup() -> turtleViewObject
--- Method
--- Sets the pen’s position to up so that movement methods do not draw lines in the turtle view.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs.canvas.turtle:pu()`

--- hs.canvas.turtle:penpaint() -> turtleViewObject
--- Method
--- Sets the pen’s position to DOWN and mode to PAINT.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs.canvas.turtle:ppt()`
---
---  * this mode is equivalent to `hs.canvas.compositeTypes.sourceOver`

--- hs.canvas.turtle:penerase() -> turtleViewObject
--- Method
--- Sets the pen’s position to DOWN and mode to ERASE.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs.canvas.turtle:pe()`
---
---  * this mode is equivalent to `hs.canvas.compositeTypes.destinationOut`

--- hs.canvas.turtle:penreverse() -> turtleViewObject
--- Method
--- Sets the pen’s position to DOWN and mode to REVERSE.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs.canvas.turtle:px()`
---
---  * this mode is equivalent to `hs.canvas.compositeTypes.XOR`

--- hs.canvas.turtle:setpencolor(color) -> turtleViewObject
--- Method
--- Sets the pen color (the color the turtle draws when it moves and the pen is down).
---
--- Parameters:
---  * `color` - one of the following types:
---    * an integer greater than or equal to 0 specifying an entry in the color palette (see [hs.canvas.turtle:setpalette](#setpalette)). If the index is outside of the defined palette, defaults to black (index entry 0).
---    * a string matching one of the names of the predefined colors as described in [hs.canvas.turtle:setpalette](#setpalette).
---    * a string starting with "#" followed by 6 hexadecimal digits specifying a color in the HTML style.
---    * a table of 3 or 4 numbers between 0.0 and 100.0 specifying the percent saturation of red, green, blue, and optionally the alpha channel.
---    * a color as defined in `hs.drawing.color`
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs.canvas.turtle:setpc(color)`

--- hs.canvas.turtle:setpalette(index, color) -> turtleViewObject
--- Method
--- Assigns the color to the palette at the given index.
---
--- Parameters:
---  * `index` - an integer between 8 and 255 inclusive specifying the slot within the palette to assign the specified color.
---  * `color` - one of the following types:
---    * an integer greater than or equal to 0 specifying an entry in the color palette (see Notes). If the index is outside the range of the defined palette, defaults to black (index entry 0).
---    * a string matching one of the names of the predefined colors as described in the Notes.
---    * a string starting with "#" followed by 6 hexadecimal digits specifying a color in the HTML style.
---    * a table of 3 or 4 numbers between 0.0 and 100.0 specifying the percent saturation of red, green, blue, and optionally the alpha channel.
---    * a color as defined in `hs.drawing.color`
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Attempting to modify color with an index of 0-7 are silently ignored.
---
---  * An assigned color has no label for use when doing a string match with [hs.canvas.turtle:setpencolor](#setpencolor) or [hs.canvas.turtle:setbackground](#setbackground). Changing the assigned color to indexes 8-15 will clear the default label.
---
---  * The initial palette is defined as follows:
---    *  0 - "black"    1 - "blue"      2 - "green"    3 - "cyan"
---    *  4 - "red"      5 - "magenta"   6 - "yellow"   7 - "white"
---    *  8 - "brown"    9 - "tan"      10 - "forest"  11 - "aqua"
---    * 12 - "salmon"  13 - "purple"   14 - "orange"  15 - "gray"

--- hs.canvas.turtle:setpensize(size) -> turtleViewObject
--- Method
--- Sets the thickness of the pen.
---
--- Parameters:
---  * `size` - a number or table of two numbers (for horizontal and vertical thickness) specifying the size of the turtle's pen.
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
--- * this method accepts two numbers for compatibility reasons - macOS uses a square pen for drawing.

-- setpenpattern - no-op -- implemented, but does nothing to simplify conversion to/from logo
-- setpen        - documented where defined

--- hs.canvas.turtle:setbackground(color) -> turtleViewObject
--- Method
--- Sets the turtle view background color.
---
--- Parameters:
---  * `color` - one of the following types:
---    * an integer greater than or equal to 0 specifying an entry in the color palette (see [hs.canvas.turtle:setpalette](#setpalette)). If the index is outside of the defined palette, defaults to black (index entry 0).
---    * a string matching one of the names of the predefined colors as described in [hs.canvas.turtle:setpalette](#setpalette).
---    * a string starting with "#" followed by 6 hexadecimal digits specifying a color in the HTML style.
---    * a table of 3 or 4 numbers between 0.0 and 100.0 specifying the percent saturation of red, green, blue, and optionally the alpha channel.
---    * a color as defined in `hs.drawing.color`
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs.canvas.turtle:setbg(...)`


-- 6.6 Pen Queries

-- pendownp   - documented where defined
-- penmode    - documented where defined
-- pencolor   - documented where defined
-- palette    - documented where defined
-- pensize    - documented where defined
-- penpattern - no-op -- implemented to simplify pen and setpen, but returns nil
-- pen        - documented where defined
-- background - documented where defined


-- 6.7 Saving and Loading Pictures

-- savepict - not implemented at present
-- loadpict - not implemented at present
-- epspict  - not implemented at present; a similar function can be found with `:_image()`


-- 6.8 Mouse Queries

-- mousepos - not implemented at present
-- clickpos - not implemented at present
-- buttonp  - not implemented at present
-- button   - not implemented at present


-- Others (unique to this module)

-- _background - documented where defined
-- _neverYield - not implemented at present
-- _yieldRatio - not implemented at present
-- _pause      -

-- _image
-- _translate
-- _visibleAxes

-- _turtleImage
-- _turtleSize

-- bye
-- fillend
-- fillstart
-- hide
-- labelfont
-- setlabelfont
-- show

-- Internal use only, no need to fully document at present
--   _appendCommand
--   _canvas
--   _cmdCount
--   _commands
--   _palette


-- _fontMap = {...},
-- new
-- turtleCanvas

for i, v in ipairs(_wrappedCommands) do
    local cmdLabel, cmdNumber = v[1], i - 1
--     local synonyms = v[2] or {}

    if not cmdLabel:match("^_") then
        if not turtleMT[cmdLabel] then
            -- this needs "special" help not worth changing the validation code in internal.m for
            if cmdLabel == "setpensize" then
                turtleMT[cmdLabel] = function(self, ...)
                    local args = table.pack(...)
                    if type(args[1]) ~= "table" then args[1] = { args[1], args[1] } end
                    local result = self:_appendCommand(cmdNumber, table.unpack(args))
                    if type(result) == "string" then
                        error(result, 2) ;
                    end
                    coroutineFriendlyCheck(self)
                    return result
                end
            else
                turtleMT[cmdLabel] = function(self, ...)
                    local result = self:_appendCommand(cmdNumber, ...)
                    if type(result) == "string" then
                        error(result, 2) ;
                    end
                    coroutineFriendlyCheck(self)
                    return result
                end
            end
        else
            log.wf("%s - method already defined; can't wrap", cmdLabel)
        end
    end
end

for k, v in pairs(_nops) do
    if not turtleMT[k] then
        turtleMT[k] = function(self, ...)
            if not _nops[k] then
                log.f("%s - method is a nop and has no effect for this implemntation", k)
                _nops[k] = true
            end
            return self
        end
    else
        log.wf("%s - method already defined; can't assign as nop", k)
    end
end

-- Return Module Object --------------------------------------------------

turtleMT.__indexLookup = turtleMT.__index
turtleMT.__index = function(self, key)
    -- handle the methods as they are defined
    if turtleMT.__indexLookup[key] then return turtleMT.__indexLookup[key] end
    -- no "logo like" command will start with an underscore
    if key:match("^_") then return nil end

    -- all logo commands are defined as lowercase, so convert the passed in key to lower case and...
    local lcKey = key:lower()

    -- check against the defined logo methods again
    if turtleMT.__indexLookup[lcKey] then return turtleMT.__indexLookup[lcKey] end

    -- check against the synonyms for the defined logo methods that wrap _appendCommand
    for i,v in ipairs(_wrappedCommands) do
        if lcKey == v[1] then return turtleMT.__indexLookup[v[1]] end
        for i2, v2 in ipairs(v[2]) do
            if lcKey == v2 then return turtleMT.__indexLookup[v[1]] end
        end
    end

    -- check against the synonyms for the defined logo methods that are defined explicitly
    for k,v in pairs(_unwrappedSynonyms) do
        for i2, v2 in ipairs(v) do
            if lcKey == v2 then return turtleMT.__indexLookup[k] end
        end
    end

    return nil -- not really necessary as none is interpreted as nil, but I like to be explicit
end

return module
