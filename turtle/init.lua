--- === hs.canvas.turtle ===
---
--- Stuff about the module

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

-- Hide the internals from accidental usage
local _wrappedCommands  = module._wrappedCommands
-- module._wrappedCommands = nil

local _unwrappedSynonyms = {
--     xcor        = { "xCor" },
--     ycor        = { "yCor" },
--     clearscreen = { "cs", "clearScreen" },
--     showturtle  = { "st", "showTurtle" },
--     hideturtle  = { "ht", "hideTurtle" },
--     shownp      = { "isTurtleVisible" },
--     pendownp    = { "penDownP" },
--     labelfont   = { "labelFont" },
--     labelsize   = { "labelSize" },
    clearscreen = { "cs" },
    showturtle  = { "st" },
    hideturtle  = { "ht" },
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

-- methods with visual impact call this to allow for yields when we're running in a coroutine
local coroutineFriendlyCheck = function(self)
    if not self:_neverYield() then
        local thread, isMain = coroutine.running()
        if not isMain and (self:_cmdCount() % self:_yieldRatio()) == 0 then
            coroutine.applicationYield()
        end
    end
end

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

local _labelsize = turtleMT.labelsize
turtleMT.labelsize = function(...)
    local result = _labelsize(...)
    return setmetatable(result, {
        __tostring = function(_) return string.format("{ %.2f, %.2f }", _[1], _[2]) end
    })
end

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

turtleMT.towards = function(self, x, y)
    local pos = self:pos()
    return (90 - math.atan(y - pos[2],x - pos[1]) * 180 / math.pi) % 360
end

turtleMT.screenmode = function(self, ...) return "FULLSCREEN" end

turtleMT.turtlemode = function(self, ...) return "WINDOW" end

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

    turtleMT[details[1]:lower()](self)          -- penup or pendown
    turtleMT["pen" .. details[2]:lower()](self) -- penpaint, penerase, or penreverse
    self:setpensize(details[3])
    self:setpencolor(details[4])
    self:setpenpattern(details[5])              -- its a nop currently, but we're supressing it's output message
    return self
end


turtleMT._background = function(self, func, ...)
    if not (type(func) == "function" or (getmetatable(func) or {}).__call) then
        error("expected function for argument 1", 2)
    end

    coroutine.wrap(fnutils.partial(func, self, ...))()

    return self
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
        log.f("%s:delete - not a known turtle only canvas; apply delete method to parent canvas, or pass in `true` as argument to this method")
    end
end

turtleMT.show = function(self, doItNoMatterWhat)
    local c = self:_canvas()
    doItNoMatterWhat = doItNoMatterWhat or (c[#c].canvas == self and c[#c].id == "turtleView")
    if doItNoMatterWhat then
        c:show()
    else
        log.f("%s:show - not a known turtle only canvas; apply show method to parent canvas, or pass in `true` as argument to this method")
    end
    return self
end

turtleMT.hide = function(self, doItNoMatterWhat)
    local c = self:_canvas()
    doItNoMatterWhat = doItNoMatterWhat or (c[#c].canvas == self and c[#c].id == "turtleView")
    if doItNoMatterWhat then
        c:hide()
    else
        log.f("%s:hide - not a known turtle only canvas; apply hide method to parent canvas, or pass in `true` as argument to this method")
    end
    return self
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
--   setscrunch
--   setlabelheight
--   setlabelfont
--   label
--   setpencolor
--   setbackground
--   setpalette

for i, v in ipairs(_wrappedCommands) do
    local cmdLabel, cmdNumber = v[1], i - 1
--     local synonyms = v[2] or {}

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
        log.wf("%s:%s - method already defined; can't wrap", USERDATA_TAG, cmdLabel)
    end
end

for k, v in pairs(_nops) do
    if not turtleMT[k] then
        turtleMT[k] = function(self, ...)
            if not _nops[k] then
                log.wf("%s:%s - method is a nop and has no effect for this implemntation", USERDATA_TAG, k)
                _nops[k] = true
            end
            return self
        end
    else
        log.wf("%s:%s - method already defined; can't assign as nop", USERDATA_TAG, k)
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
