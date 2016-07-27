-- DO NOT USE YET

--- === hs._asm.canvas.drawing ===
---
--- An experimental wrapper, still in very early stages, to replace `hs.drawing` with `hs._asm.canvas`.
---
--- This submodule is not loaded as part of the `hs._asm.canvas` module and has to be loaded explicitly. You can test the use of this wrapper with your Hammerspoon configuration by adding the following to the ***top*** of `~/.hammerspoon/init.lua` -- this needs to be executed before any other code has a chance to load `hs.drawing` first.
---
--- ~~~lua
--- local R, M = pcall(require,"hs._asm.canvas.drawing")
--- if R then
---    print()
---    print("**** Replacing internal hs.drawing with experimental wrapper.")
---    print()
---    hs.drawing = M
---    package.loaded["hs.drawing"] = M   -- make sure require("hs.drawing") returns us
---    package.loaded["hs/drawing"] = M   -- make sure require("hs/drawing") returns us
--- else
---    print()
---    print("**** Error with experimental hs.drawing wrapper: "..tostring(M))
---    print()
--- end
--- ~~~
---
--- The intention is for this wrapper to provide all of the same functionality that `hs.drawing` does without requiring any additional changes to your currently existing code.
---
--- To return to using the officially included version of `hs.drawing`, remove or comment out the code that was added to your `init.lua` file.

local USERDATA_TAG = "hs._asm.canvas.drawing"
local canvas       = require("hs.canvas")
local canvasMT     = hs.getObjectMetatable("hs.canvas")
local drawingMT    = {}

local styledtext   = require("hs.styledtext")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- functions/tables from hs.drawing

module._image = function(frame, imageObject)
    local drawingObject = {
        canvas = canvas.new(frame),
    }
    drawingObject.canvas[1] = {
        type             = "image",
        padding          = 0,
        absolutePosition = false,
        absoluteSize     = false,
        image            = imageObject,
    }
    return setmetatable(drawingObject, drawingMT)
end

module.appImage = function(frame, bundleID)
    local image = require("hs.image")
    local tmpImage = image.imageFromAppBundle(bundleID)
    if tmpImage then
        return module._image(frame, tmpImage)
    else
        return nil
    end
end

module.arc = function(centerPoint, radius, startAngle, endAngle)
    local frame = {
        x = centerPoint.x - radius,
        y = centerPoint.y - radius,
        h = radius * 2,
        w = radius * 2
    }
    return module.ellipticalArc(frame, startAngle, endAngle)
end

module.circle = function(frame)
    local drawingObject = {
        canvas = canvas.new(frame),
    }
    drawingObject.canvas[1] = {
        type               = "oval",
        padding            = 0,
        absolutePosition   = false,
        absoluteSize       = false,
    }
    return setmetatable(drawingObject, drawingMT)
end

module.ellipticalArc = function(frame, startAngle, endAngle)
    local drawingObject = {
        canvas = canvas.new(frame),
    }
    drawingObject.canvas[1] = {
        type             = "ellipticalArc",
        padding          = 0,
        absolutePosition = false,
        absoluteSize     = false,
        startAngle       = startAngle,
        endAngle         = endAngle,
    }
    return setmetatable(drawingObject, drawingMT)
end

module.image = function(frame, imageObject)
    local image = require("hs.image")
    if type(imageObject) == "string" then
        if string.sub(imageObject, 1, 6) == "ASCII:" then
            imageObject = image.imageFromASCII(imageObject)
        else
            imageObject = image.imageFromPath(imageObject)
        end
    end

    if imageObject then
        return module._image(frame, imageObject)
    else
        return nil
    end
end

module.line = function(originPoint, endingPoint)
    local frame = {
        x = math.min(originPoint.x, endingPoint.x),
        y = math.min(originPoint.y, endingPoint.y),
        w = math.max(originPoint.x, endingPoint.x) - math.min(originPoint.x, endingPoint.x),
        h = math.max(originPoint.y, endingPoint.y) - math.min(originPoint.y, endingPoint.y),
    }
    originPoint.x, originPoint.y = originPoint.x - frame.x, originPoint.y - frame.y
    endingPoint.x, endingPoint.y = endingPoint.x - frame.x, endingPoint.y - frame.y
    local drawingObject = {
        canvas = canvas.new(frame),
    }
    drawingObject.canvas[1] = {
        type             = "segments",
        padding          = 0,
        absolutePosition = false,
        absoluteSize     = false,
        coordinates      = { originPoint, endingPoint },
        action           = "stroke",
    }
    return setmetatable(drawingObject, drawingMT)
end

module.rectangle = function(frame)
    local drawingObject = {
        canvas = canvas.new(frame),
    }
    drawingObject.canvas[1] = {
        type             = "rectangle",
        padding          = 0,
        absolutePosition = false,
        absoluteSize     = false,
    }
    return setmetatable(drawingObject, drawingMT)
end

module.text = function(frame, message)
    local styledtext = require("hs.styledtext")
    if type(message) == "table" then
        message = styledtext.new(message)
    elseif type(message) ~= "string" and getmetatable(message) ~= hs.getObjectMetatable("hs.styledtext") then
        message = tostring(message)
    end
    local drawingObject = {
        canvas = canvas.new(frame),
    }
    drawingObject.canvas[1] = {
        type             = "text",
        padding          = 0,
        absolutePosition = false,
        absoluteSize     = false,
        text             = message,
    }
    return setmetatable(drawingObject, drawingMT)
end

module.getTextDrawingSize = function(message, textStyle)
    textStyle = textStyle or {}
    local drawingObject = {
        canvas = canvas.new(frame),
    }
    if textStyle.font      then drawingObject._default.textFont      = textStyle.font end
    if textStyle.size      then drawingObject._default.textSize      = textStyle.size end
    if textStyle.color     then drawingObject._default.textColor     = textStyle.color end
    if textStyle.alignment then drawingObject._default.textAlignment = textStyle.alignment end
    if textStyle.lineBreak then drawingObject._default.textLineBreak = textStyle.lineBreak end
    local frameSize = a:minimumTextSize(message)
    a:delete()
    return frameSize
end

module.color                = require("hs.drawing.color")
module.defaultTextStyle     = canvas.defaultTextStyle
module.disableScreenUpdates = canvas.disableScreenUpdates
module.enableScreenUpdates  = canvas.enableScreenUpdates
module.fontNames            = styledtext.fontNames
module.fontNamesWithTraits  = styledtext.fontNamesWithTraits
module.fontTraits           = styledtext.fontTraits
module.windowBehaviors      = canvas.windowBehaviors
module.windowLevels         = canvas.windowLevels

-- methods from hs.drawing

drawingMT.clippingRectangle = function(self, ...)
    local args = table.pack(...)
    if args.n ~= 1 then
        error(string.format("ERROR: incorrect number of arguments. Expected 2, got %d", args.n), 2)
    elseif type(args[1]) ~= "table" and type(args[1]) ~= "nil" then
        error(string.format("ERROR: incorrect type '%s' for argument 2 (expected table)", type(args[1])), 2)
    else
        if args[1] and #self.canvas == 1 then
            self.canvas:insertElement({
                type = "rectangle",
                action = "clip",
                frame = args[1]
            }, 1)
        elseif args[1] then
            self.canvas[1].frame = args[1]
        elseif #self.canvas == 2 then
            self.canvas:removeElement(1)
        end
        return self
    end
end

drawingMT.delete = function(self)
    self.canvas = self.canvas:delete()
    setmetatable(self, nil)
end

-- drawingMT.getStyledText = <function 10>,
-- drawingMT.setStyledText = <function 38>,

-- drawingMT.setArcAngles = <function 21>,
-- drawingMT.setClickCallback = <function 24>,

drawingMT.setFill = function(self, ...)
    local args = table.pack(...)
    if ({ rectangle = 1, oval = 1, ellipticalArc = 1, segments = 1 })[self.canvas[#self.canvas].type] then
        local currentAction = self.canvas[#self.canvas].action
        if args[1] then
            self.canvas[#self.canvas].fillGradient = "none"
            if currentAction == "stroke" then
                self.canvas[#self.canvas].action = "strokeAndFill"
            elseif currentAction == "skip" then
                self.canvas[#self.canvas].action = "fill"
            end
        else
            if currentAction == "strokeAndFill" then
                self.canvas[#self.canvas].action = "stroke"
            elseif currentAction == "fill" then
                self.canvas[#self.canvas].action = "skip"
            end
        end
    else
        error(string.format("%s:setFill() can only be called on %s.rectangle(), %s.circle(), %s.line() or %s.arc() objects, not: %s", USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setFillColor = function(self, ...)
    local args = table.pack(...)
    if ({ rectangle = 1, oval = 1, ellipticalArc = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].fillColor = args[1]
    else
        error(string.format("%s:setFillColor() can only be called on %s.rectangle(), %s.circle(), or %s.arc() objects, not: %s", USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setFillGradient = function(self, ...)
    local args = table.pack(...)
    if ({ rectangle = 1, oval = 1, ellipticalArc = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].fillGradientColors = { args[1], args[2] }
        self.canvas[#self.canvas].fillGradientAngle  = args[3]
        self.canvas[#self.canvas].fillGradient       = "linear"
    else
        error(string.format("%s:setFillGradient() can only be called on %s.rectangle(), %s.circle(), or %s.arc() objects, not: %s", USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setImage = function(self, ...)
    local args = table.pack(...)
    if ({ image = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].image = args[1]
    else
        error(string.format("%s:setImage() can only be called on %s.image() objects, not: %s", USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setImageFromASCII = function(self, ...)
    local args = table.pack(...)
    local imageObject = args[1]
    local image = require("hs.image")
    if type(imageObject) == "string" then
        if string.sub(imageObject, 1, 6) == "ASCII:" then
            imageObject = image.imageFromASCII(imageObject)
        else
            imageObject = image.imageFromPath(imageObject)
        end
    end
    return self:setImage(imageObject)
end
drawingMT.setImageFromPath = drawingMT.setImageFromASCII
drawingMT.setImagePath     = drawingMT.setImagePath

drawingMT.setRoundedRectRadii = function(self, ...)
    local args = table.pack(...)
    if ({ rectangle = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].roundedRectRadii = { xRadius = args[1], yRadius = args[2] }
    else
        error(string.format("%s:setRoundedRectRadii() can only be called on %s.rectangle() objects, not: %s", USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setStroke = function(self, ...)
    local args = table.pack(...)
    if ({ rectangle = 1, oval = 1, ellipticalArc = 1, segments = 1 })[self.canvas[#self.canvas].type] then
        local currentAction = self.canvas[#self.canvas].action
        if args[1] then
            if currentAction == "fill" then
                self.canvas[#self.canvas].action = "strokeAndFill"
            elseif currentAction == "skip" then
                self.canvas[#self.canvas].action = "stroke"
            end
        else
            if currentAction == "strokeAndFill" then
                self.canvas[#self.canvas].action = "fill"
            elseif currentAction == "stroke" then
                self.canvas[#self.canvas].action = "skip"
            end
        end
    else
        error(string.format("%s:setStroke() can only be called on %s.rectangle(), %s.circle(), %s.line() or %s.arc() objects, not: %s", USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setStrokeColor = function(self, ...)
    local args = table.pack(...)
    if ({ rectangle = 1, oval = 1, ellipticalArc = 1, segments = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].strokeColor = args[1]
    else
        error(string.format("%s:setStrokeColor() can only be called on %s.rectangle(), %s.circle(), %s.line() or %s.arc() objects, not: %s", USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setStrokeWidth = function(self, ...)
    local args = table.pack(...)
    if ({ rectangle = 1, oval = 1, ellipticalArc = 1, segments = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].strokeWidth = args[1]
    else
        error(string.format("%s:setStrokeWidth() can only be called on %s.rectangle(), %s.circle(), %s.line() or %s.arc() objects, not: %s", USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setText = function(self, ...)
    local args = table.pack(...)
    if ({ text = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].text = tostring(args[1])
    else
        hs.luaSkinLog.ef("%s:setText() can only be called on %s.text() objects, not: %s", USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type)
    end
    return self
end

drawingMT.setTextColor = function(self, ...)
    local args = table.pack(...)
    if ({ text = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].textColor = args[1]
    else
        error(string.format("%s:setTextColor() can only be called on %s.text() objects, not: %s", USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setTextFont = function(self, ...)
    local args = table.pack(...)
    if ({ text = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].textFont = args[1]
    else
        error(string.format("%s:setTextFont() can only be called on %s.text() objects, not: %s", USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setTextSize = function(self, ...)
    local args = table.pack(...)
    if ({ text = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].textFont = args[1]
    else
        error(string.format("%s:setTextSize() can only be called on %s.text() objects, not: %s", USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setTextStyle = function(self, ...)
    local args = table.pack(...)
    if type(args[1]) ~= "table" and type(args[1]) ~= "nil" then
        error(string.format("invalid textStyle type specified: %s", type(args[1])), 2)
    else
        if ({ text = 1 })[self.canvas[#self.canvas].type] then
            local style = args[1]
            if (style) then
                if style.font      then self.canvas[#self.canvas].textFont      = style.font end
                if style.size      then self.canvas[#self.canvas].textSize      = style.size end
                if style.color     then self.canvas[#self.canvas].textColor     = style.color end
                if style.alignment then self.canvas[#self.canvas].textAlignment = style.alignment end
                if style.lineBreak then self.canvas[#self.canvas].textLineBreak = style.lineBreak end
            else
                self.canvas[#self.canvas].textFont      = nil
                self.canvas[#self.canvas].textSize      = nil
                self.canvas[#self.canvas].textColor     = nil
                self.canvas[#self.canvas].textAlignment = nil
                self.canvas[#self.canvas].textLineBreak = nil
            end
        else
            error(string.format("%s:setTextStyle() can only be called on %s.text() objects, not: %s", USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
        end
    end
    return self
end

-- Not sure what to do about these...
-- drawingMT.imageAlignment = <function 12>,
-- drawingMT.imageAnimates = <function 13>,
-- drawingMT.imageFrame = <function 14>,
-- drawingMT.imageScaling = <function 15>,
-- drawingMT.rotateImage = <function 18>,

drawingMT.alpha                   = function(self, ...) return self.canvas:alpha(...) end
drawingMT.setAlpha                = function(self, ...) self.canvas:alpha(...) ; return self end
drawingMT.behavior                = function(self, ...) return self.canvas:behavior(...) end
drawingMT.setBehavior             = function(self, ...) self.canvas:behavior(...) ; return self end
drawingMT.behaviorAsLabels        = function(self, ...) return self.canvas:setBehaviorByLabels(...) end
drawingMT.setBehaviorByLabels     = function(self, ...) self.canvas:setBehaviorByLabels(...) ; return self end
drawingMT.bringToFront            = function(self, ...) self.canvas:bringToFront(...) ; return self end
drawingMT.clickCallbackActivating = function(self, ...) self.canvas:clickActivating(...) ; return self end
drawingMT.frame                   = function(self, ...) return self.canvas:frame(...) end
drawingMT.setFrame                = function(self, ...) self.canvas:frame(...) ; return self end
drawingMT.hide                    = function(self, ...) self.canvas:hide(...) ; return self end
drawingMT.orderAbove              = function(self, ...) self.canvas:orderAbove(...) ; return self end
drawingMT.orderBelow              = function(self, ...) self.canvas:orderBelow(...) ; return self end
drawingMT.sendToBack              = function(self, ...) self.canvas:sendToBack(...) ; return self end
drawingMT.setLevel                = function(self, ...) self.canvas:level(...) ; return self end
drawingMT.setSize                 = function(self, ...) self.canvas:size(...) ; return self end
drawingMT.setTopLeft              = function(self, ...) self.canvas:topLeft(...) ; return self end
drawingMT.show                    = function(self, ...) self.canvas:show(...) ; return self end
drawingMT.wantsLayer              = function(self, ...) self.canvas:wantsLayer(...) ; return self end

-- assign to the registry in case we ever need to access the metatable from the C side

debug.getregistry()[USERDATA_TAG] = {
    __type  = USERDATA_TAG,
    __index = drawingMT,
    __tostring = function(_)
        return USERDATA_TAG .. ": " .. _.canvas[1].type .. tostring(_)
    end,
}

-- Return Module Object --------------------------------------------------

return module
