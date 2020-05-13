--- === hs.canvas.turtle ===
---
--- Stuff about the module

local USERDATA_TAG = "hs.canvas.turtle"
local module       = require(USERDATA_TAG..".internal")
local turtleMT     = hs.getObjectMetatable(USERDATA_TAG)

local image        = require("hs.image")
local color        = require("hs.drawing.color")
local inspect      = require("hs.inspect")
local fnutils      = require("hs.fnutils")

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

-- local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

local _internalLuaSideVars = setmetatable({}, { __mode = "k" })

-- Hide the internals from accidental usage
local _wrappedCommands  = module._wrappedCommands
-- module._wrappedCommands = nil

local _unwrappedSynonyms = {
    xcor        = { "xCor" },
    ycor        = { "yCor" },
    clearscreen = { "cs", "clearScreen" },
    showturtle  = { "st", "showTurtle" },
    hideturtle  = { "ht", "hideTurtle" },
    shownp      = { "turtleVisible" },
}

local penColors = {
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

module._shareColors(penColors)
module._shareColors = nil

local finspect = function(obj)
    return inspect(obj, { newline = " ", indent = "" })
end

-- methods with visual impact call this to allow for yields when we're running in a coroutine
local coroutineFriendlyCheck = function(self)
    if not _internalLuaSideVars[self].neverYield then
        local thread, isMain = coroutine.running()
        if not isMain and (self:_cmdCount() % self:_yieldRatio()) == 0 then
            coroutine.applicationYield()
        end
    end
end

-- Public interface ------------------------------------------------------

--   forward
--   back
--   left
--   right
--   setpos
--   setxy
--   setx
--   sety
--   setheading
--   home
--   arc
--   showturtle
--   hideturtle
--   clean
--   clearscreen
--   pendown
--   penup

for i, v in ipairs(_wrappedCommands) do
    local cmdLabel, cmdNumber = v[1], i - 1
    local synonyms = v[2] or {}

    if not turtleMT[cmdLabel] then
        turtleMT[cmdLabel] = function(self, ...)
            local result = self:_insertCmdAtIdx(cmdNumber, nil, ...)
            if type(result) == "string" then
                error(result, 2) ;
            end
            coroutineFriendlyCheck(self)
            return result
        end

        for i2, v2 in ipairs(synonyms) do
            if not turtleMT[v2] then
                turtleMT[v2] = turtleMT[cmdLabel]
            else
                hs.luaSkinLog.wf("%s:%s - method already defined; can't assign as synonym for %s", USERDATA_TAG, v2, cmdLabel)
            end
        end
    else
        hs.luaSkinLog.wf("%s:%s - method already defined; can't wrap", USERDATA_TAG, cmdLabel)
    end
end

local _pos = turtleMT.pos
turtleMT.pos = function(...)
    local result = _pos(...)
    return setmetatable(result, {
        __tostring = function(_) return string.format("{ %.2f, %.2f }", _[1], _[2]) end
    })
end

turtleMT._yieldRatio = function(self, ...)
    local args = table.pack(...)
    local retV = self

    if args.n == 0 then
        retV = _internalLuaSideVars[self].yieldRatio
    else
        local newValue = args[1]
        if math.type(newValue) == "integer" then
            _internalLuaSideVars[self].yieldRatio = newValue > 0 and newValue or 1
        else
            error("expected integer for yieldRatio", 2)
        end
    end
    return retV
end

turtleMT._neverYield = function(self, ...)
    local args = table.pack(...)
    local retV = self

    if args.n == 0 then
        retV = _internalLuaSideVars[self].neverYield
    else
        if args[1] then
            _internalLuaSideVars[self].neverYield = true
        else
            _internalLuaSideVars[self].neverYield = false
        end
    end
    return retV
end

turtleMT._background = function(self, func, ...)
    if not (type(func) == "function" or (getmetatable(func) or {}).__call) then
        error("expected function for argument 1", 2)
    end

    coroutine.wrap(fnutils.partial(func, self, ...))()

    return self
end

for k, v in pairs(_unwrappedSynonyms) do
    if turtleMT[k] then
        for i, v2 in ipairs(v) do
            if not turtleMT[v2] then
                turtleMT[v2] = turtleMT[k]
            else
                hs.luaSkinLog.wf("%s:%s - method already defined; can't assign as synonym for %s", USERDATA_TAG, v2, k)
            end
        end
    else
        hs.luaSkinLog.wf("%s:%s - method not defined; can't assign synonyms %s", USERDATA_TAG, k, finspect(v))
    end
end

local _new = module.new
module.new = function(...)
    local self = _new(...)
    if self then
        _internalLuaSideVars[self] = {
            yieldRatio = 500,
            neverYield = false,
        }
    end
    return self
end

module.turtleCanvas = function(...)
    local screen   = require("hs.screen")
    local canvas   = require("hs.canvas")
    local eventtap = require("hs.eventtap")
    local mouse    = require("hs.mouse")

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

            nC.turtle.frame = {
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

    nC[#nC + 1] = {
        id     = "turtle",
        type   = "canvas",
        canvas = module.new(),
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
                                      local pos = mouse.getAbsolutePosition()
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
                                      local pos = mouse.getAbsolutePosition()
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

    return nC.turtle.canvas
end

-- Return Module Object --------------------------------------------------

return module
