--- === hs._asm.progress ===
---
--- A Hammerspoon module which allows the creation and manipulation of progress indicators.

local module = require("hs._asm.progress.internal")
local log    = require("hs.logger").new("progress","warning")
module.log   = log
module._registerLogForC(log)
module._registerLogForC = nil

local object = hs.getObjectMetatable("hs._asm.progress")

-- hide a potentially dangerous method
local _hsdrawing = object._asHSDrawing
object._asHSDrawing = nil

-- we require these for their helper functions and metatable, but we don't need to save them
require("hs.drawing")
require("hs.drawing.color")

-- private variables and methods -----------------------------------------

local drawingMT = hs.getObjectMetatable("hs.drawing")
local hsdWrapper = function(self, fn, ...)
    local result = fn(_hsdrawing(self), ...)
    if type(result) == "userdata" then
        return self
    else
        return result
    end
end

local _kMetaTable = {}
_kMetaTable._k = {}
_kMetaTable._t = {}
_kMetaTable.__index = function(obj, key)
        if _kMetaTable._k[obj] then
            if _kMetaTable._k[obj][key] then
                return _kMetaTable._k[obj][key]
            else
                for k,v in pairs(_kMetaTable._k[obj]) do
                    if v == key then return k end
                end
            end
        end
        return nil
    end
_kMetaTable.__newindex = function(obj, key, value)
        error("attempt to modify a table of constants",2)
        return nil
    end
_kMetaTable.__pairs = function(obj) return pairs(_kMetaTable._k[obj]) end
_kMetaTable.__tostring = function(obj)
        local result = ""
        if _kMetaTable._k[obj] then
            if _kMetaTable._t[obj] == "table" then
                local width = 0
                for k,v in pairs(_kMetaTable._k[obj]) do width = width < #k and #k or width end
                for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                    result = result..string.format("%-"..tostring(width).."s %s\n", k, tostring(v))
                end
            else
                for k,v in ipairs(_kMetaTable._k[obj]) do
                    result = result..v.."\n"
                end
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

local _makeConstantsTable = function(theTable)
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    _kMetaTable._t[results] = "table"
    return results
end

local _makeConstantsArray = function(theTable)
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    _kMetaTable._t[results] = "array"
    return results
end

-- Public interface ------------------------------------------------------

module.size = _makeConstantsTable(module.size)
module.tint = _makeConstantsTable(module.tint)

--- hs._asm.progress:setFrame(rect) -> progressObject
--- Method
--- Set the frame of the progress indicator and its background to the specified frame.
---
--- Parameters:
---  * rect - a table containing the rectangular coordinates for the progress indicator and its background.
---
--- Returns:
---  * the progress indicator object
---
--- Notes:
---  * this is actually a wrapper to [hs._asm.progress:frame](#frame) for compatibility with tools which wish to treat this object like an `hs.drawing` object.
object.setFrame            = function(self, rect, ...) return self:frame(rect, ...) end

-- The following are wrapped to use hs.drawing -- saves us from duplicating code
--    setFrame, frame, setTopLeft, and setSize do not use hs.drawing because we need to take
--    extra steps to keep the indicator centered.

--- hs._asm.progress:alpha() -> number
--- Method
--- Get the alpha level of the window containing the progress indicator object.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The current alpha level for the progress indicator object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
object.alpha               = function(self, ...) return hsdWrapper(self, drawingMT.alpha, ...) end

--- hs._asm.progress:setAlpha(level) -> object
--- Method
--- Sets the alpha level of the window containing the progress indicator object.
---
--- Parameters:
---  * level - the alpha level (0.0 - 1.0) to set the object to
---
--- Returns:
---  * the progress indicator object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
object.setAlpha            = function(self, ...) return hsdWrapper(self, drawingMT.setAlpha, ...) end

--- hs._asm.progress:behavior() -> number
--- Method
--- Returns the current behavior of the progress indicator object with respect to Spaces and Exposé for the object.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The numeric representation of the current behaviors for the progress indicator object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
object.behavior            = function(self, ...) return hsdWrapper(self, drawingMT.behavior, ...) end

--- hs._asm.progress:behaviorAsLabels() -> table
--- Method
--- Returns a table of the labels for the current behaviors of the object.
---
--- Parameters:
---  * None
---
--- Returns:
---  * Returns a table of the labels for the current behaviors with respect to Spaces and Exposé for the object.
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
object.behaviorAsLabels    = function(self, ...) return hsdWrapper(self, drawingMT.behaviorAsLabels, ...) end

--- hs._asm.progress:setBehavior(behavior) -> object
--- Method
--- Sets the window behaviors represented by the number provided for the window containing the progress indicator object.
---
--- Parameters:
---  * behavior - the numeric representation of the behaviors to set for the window of the object
---
--- Returns:
---  * the progress indicator object
---
--- Notes:
---  * see the notes for `hs.drawing.windowBehaviors`
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
object.setBehavior         = function(self, ...) return hsdWrapper(self, drawingMT.setBehavior, ...) end

--- hs._asm.progress:setBehaviorByLabels(table) -> object
--- Method
--- Sets the window behaviors based upon the labels specified in the table provided.
---
--- Parameters:
---  * a table of label strings or numbers.  Recognized values can be found in `hs.drawing.windowBehaviors`.
---
--- Returns:
---  * the progress indicator object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
object.setBehaviorByLabels = function(self, ...) return hsdWrapper(self, drawingMT.setBehaviorByLabels, ...) end

--- hs._asm.progress:orderAbove([object2]) -> object
--- Method
--- Moves drawing object above drawing object2, or all drawing objects in the same presentation level, if object2 is not provided.
---
--- Parameters:
---  * Optional drawing object to place the drawing object above.
---
--- Returns:
---  * the progress indicator object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
object.orderAbove          = function(self, ...) return hsdWrapper(self, drawingMT.orderAbove, ...) end

--- hs._asm.progress:orderBelow([object2]) -> object1
--- Method
--- Moves drawing object below drawing object2, or all drawing objects in the same presentation level, if object2 is not provided.
---
--- Parameters:
---  * Optional drawing object to place the drawing object below.
---
--- Returns:
---  * the progress indicator object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
object.orderBelow          = function(self, ...) return hsdWrapper(self, drawingMT.orderBelow, ...) end

--- hs._asm.progress:bringToFront([aboveEverything]) -> drawingObject
--- Method
--- Places the drawing object on top of normal windows
---
--- Parameters:
---  * aboveEverything - An optional boolean value that controls how far to the front the drawing should be placed. True to place the drawing on top of all windows (including the dock and menubar and fullscreen windows), false to place the drawing above normal windows, but below the dock, menubar and fullscreen windows. Defaults to false.
---
--- Returns:
---  * The drawing object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
object.bringToFront        = function(self, ...) return hsdWrapper(self, drawingMT.bringToFront, ...) end

--- hs._asm.progress:sendToBack() -> drawingObject
--- Method
--- Places the drawing object behind normal windows, between the desktop wallpaper and desktop icons
---
--- Parameters:
---  * None
---
--- Returns:
---  * The drawing object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
object.sendToBack          = function(self, ...) return hsdWrapper(self, drawingMT.sendToBack, ...) end

--- hs._asm.progress:setLevel(theLevel) -> drawingObject
--- Method
--- Sets the window level more precisely than sendToBack and bringToFront.
---
--- Parameters:
---  * theLevel - the level specified as a number or as a string where this object should be drawn.  If it is a string, it must match one of the keys in `hs.drawing.windowLevels`.
---
--- Returns:
---  * the drawing object
---
--- Notes:
---  * see the notes for `hs.drawing.windowLevels`
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
object.setLevel            = function(self, ...) return hsdWrapper(self, drawingMT.setLevel, ...) end

-- Return Module Object --------------------------------------------------

return module
