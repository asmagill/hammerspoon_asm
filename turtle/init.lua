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
local canvas       = require("hs.canvas")

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

-- local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- borrowed and (very) slightly modified from https://www.calormen.com/jslogo/#; specifically
-- https://github.com/inexorabletash/jslogo/blob/02482525925e399020f23339a0991d98c4f088ff/turtle.js#L129-L152
local betterTurtle = canvas.new{ x = 100, y = 100, h = 40, w = 40 }:appendElements{
    {
        type           = "segments",
        action         = "strokeAndFill",
        strokeColor    = { green = 1 },
        fillColor      = { green = .75, alpha = .25 },
        frame          = { x = 0, y = 0, h = 40, w = 40 },
        strokeWidth    = 2,
        transformation = canvas.matrix.translate(20, 22),
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

local _internalLuaSideVars = setmetatable({}, {
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

module._internalLuaSideVars = _internalLuaSideVars

-- Hide the internals from accidental usage
local _wrappedCommands  = module._wrappedCommands
-- module._wrappedCommands = nil

local _unwrappedSynonyms = {
    xcor        = { "xCor" },
    ycor        = { "yCor" },
    clearscreen = { "cs", "clearScreen" },
    showturtle  = { "st", "showTurtle" },
    hideturtle  = { "ht", "hideTurtle" },
    shownp      = { "isTurtleVisible" },
    pendownp    = { "penDownP", "isPenDown" },
}

-- in case I ever write something to import turtle code directly, don't want these to cause it to break immediately
local _nops = {
    wrap        = false, -- boolean indicates whether or not warning has been issued; don't want to spam console
    window      = false,
    fence       = false,
    textscreen  = false,
    fullscreen  = false,
    splitscreen = false,
    refresh     = false,
    norefresh   = false,
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

local _pos = turtleMT.pos
turtleMT.pos = function(...)
    local result = _pos(...)
    return setmetatable(result, {
        __tostring = function(_) return string.format("{ %.2f, %.2f }", _[1], _[2]) end
    })
end

local _pensize = turtleMT.pensize
turtleMT.pensize = function(...)
    local result = _pensize(...)
    return setmetatable(result, {
        __tostring = function(_) return string.format("{ %.2f, %.2f }", _[1], _[2]) end
    })
end

local _scrunch = turtleMT.scrunch
turtleMT.scrunch = function(...)
    local result = _scrunch(...)
    return setmetatable(result, {
        __tostring = function(_) return string.format("{ %.2f, %.2f }", _[1], _[2]) end
    })
end

turtleMT.towards = function(self, x, y)
    local pos = self:pos()
    return (90 - math.atan(y - pos[2],x - pos[1]) * 180 / math.pi) % 360
end

turtleMT.screenmode = function(self, ...) return "FULLSCREEN" end

turtleMT.turtlemode = function(self, ...) return "WINDOW" end

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

local _new = module.new
module.new = function(...)
    local self = _new(...)
    if self then
        _internalLuaSideVars[self] = {
            yieldRatio = 500,
            neverYield = false,
        }
    end
    return self:_turtleImage(betterTurtle)
end

turtleMT.bye = function(self, doItNoMatterWhat)
    local c = self:_canvas()
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
        hs.luaSkinLog.f("%s:delete - not a known turtle only canvas; apply delete method to parent canvas, or pass in `true` as argument to this method")
    end
end

turtleMT.show = function(self, doItNoMatterWhat)
    local c = self:_canvas()
    doItNoMatterWhat = doItNoMatterWhat or (c[#c].canvas == self and c[#c].id == "turtleView")
    if doItNoMatterWhat then
        c:show()
    else
        hs.luaSkinLog.f("%s:show - not a known turtle only canvas; apply show method to parent canvas, or pass in `true` as argument to this method")
    end
    return self
end

turtleMT.hide = function(self, doItNoMatterWhat)
    local c = self:_canvas()
    doItNoMatterWhat = doItNoMatterWhat or (c[#c].canvas == self and c[#c].id == "turtleView")
    if doItNoMatterWhat then
        c:hide()
    else
        hs.luaSkinLog.f("%s:hide - not a known turtle only canvas; apply hide method to parent canvas, or pass in `true` as argument to this method")
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

    return turtleViewObject
end

-- reminders for docs
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
--   pendown
--   penup
--   penpaint
--   penerase
--   penreverse
--   setpensize
--   setpenwidth
--   arc

for i, v in ipairs(_wrappedCommands) do
    local cmdLabel, cmdNumber = v[1], i - 1
    local synonyms = v[2] or {}

    if not turtleMT[cmdLabel] then
        turtleMT[cmdLabel] = function(self, ...)
            local result = self:_appendCommand(cmdNumber, ...)
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

-- We can do this for actions; queries imply some decision or calculation based on return, so those will just have to
-- break since we're not implementing the full logo command structure. Really, this will only be useful if I ever write
-- something to convert turtle code into the lua method approach used by this module and it's just raw turtle orders.
for k, v in pairs(_nops) do
    if not turtleMT[k] then
        turtleMT[k] = function(self, ...)
            if not _nops[k] then
                hs.luaSkinLog.wf("%s:%s - method is a nop and has no effect for this implemntation; please remove from source", USERDATA_TAG, k)
                _nops[k] = true
            end
            return self
        end
    else
        hs.luaSkinLog.wf("%s:%s - method already defined; can't assign as nop", USERDATA_TAG, k)
    end
end

-- Return Module Object --------------------------------------------------

return module
