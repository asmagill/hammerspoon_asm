--- === hs._asm.module ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.cifilter"
require("hs.image")
require("hs.drawing")
require("hs._asm.canvas") -- for NSAffineTransform conversions

local module       = require(USERDATA_TAG..".internal")
local IKUIInternal = hs.getObjectMetatable("hs._asm.ikfilteruiview")

local imgInternal  = hs.getObjectMetatable("hs.image")
local drawingMT    = hs.getObjectMetatable("hs.drawing")

-- private variables and methods -----------------------------------------

local _kMetaTable = {}
-- planning to experiment with using this with responses to functional queries... and I
-- don't want to keep loose generated data hanging around
_kMetaTable._k = setmetatable({}, {__mode = "k"})
_kMetaTable._t = setmetatable({}, {__mode = "k"})
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
_kMetaTable.__len = function(obj) return #_kMetaTable._k[obj] end
_kMetaTable.__tostring = function(obj)
        local result = ""
        if _kMetaTable._k[obj] then
            local width = 0
            for k,v in pairs(_kMetaTable._k[obj]) do width = width < #tostring(k) and #tostring(k) or width end
            for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                if _kMetaTable._t[obj] == "table" then
                    result = result..string.format("%-"..tostring(width).."s %s\n", tostring(k),
                        ((type(v) == "table") and "{ table }" or tostring(v)))
                else
                    result = result..((type(v) == "table") and "{ table }" or tostring(v)).."\n"
                end
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

local _makeConstantsTable
_makeConstantsTable = function(theTable)
    if type(theTable) ~= "table" then
        local dbg = debug.getinfo(2)
        local msg = dbg.short_src..":"..dbg.currentline..": attempting to make a '"..type(theTable).."' into a constant table"
        if module.log then module.log.ef(msg) else print(msg) end
        return theTable
    end
    for k,v in pairs(theTable) do
        if type(v) == "table" then
            local count = 0
            for a,b in pairs(v) do count = count + 1 end
            local results = _makeConstantsTable(v)
            if #v > 0 and #v == count then
                _kMetaTable._t[results] = "array"
            else
                _kMetaTable._t[results] = "table"
            end
            theTable[k] = results
        end
    end
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    local count = 0
    for a,b in pairs(theTable) do count = count + 1 end
    if #theTable > 0 and #theTable == count then
        _kMetaTable._t[results] = "array"
    else
        _kMetaTable._t[results] = "table"
    end
    return results
end

local hsdWrapper = function(self, fn, ...)
    local result = fn(_hsdrawing(self), ...)
    if type(result) == "userdata" then
        return self
    else
        return result
    end
end

-- Public interface ------------------------------------------------------

module.categories       = _makeConstantsTable(module.categories)
-- module.attributes       = _makeConstantsTable(module.attributes)
-- module.numericTypes     = _makeConstantsTable(module.numericTypes)
-- module.vectorTypes      = _makeConstantsTable(module.vectorTypes)
-- module.colorTypes       = _makeConstantsTable(module.colorTypes)
-- module.imageTypes       = _makeConstantsTable(module.imageTypes)
-- module.applyOptions     = _makeConstantsTable(module.applyOptions)
module.parameterKeys    = _makeConstantsTable(module.parameterKeys)
-- module.rawParameterKeys = _makeConstantsTable(module.rawParameterKeys)

imgInternal.asCIImage = function(...) return module.imageFromHSImage(...) end

-- The following are wrapped to use hs.drawing -- saves us from duplicating code

IKUIInternal.frame = function(self, ...) return hsdWrapper(self, drawingMT.frame, ...) end
IKUIInternal.setFrame = function(self, ...) return hsdWrapper(self, drawingMT.setFrame, ...) end
IKUIInternal.setTopLeft = function(self, ...) return hsdWrapper(self, drawingMT.setTopLeft, ...) end
IKUIInternal.setSize = function(self, ...) return hsdWrapper(self, drawingMT.setSize, ...) end

--- hs._asm.ikuifilterview:alpha() -> number
--- Method
--- Get the alpha level of the window containing the filter configuration UI object.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The current alpha level for the filter configuration UI object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
IKUIInternal.alpha = function(self, ...) return hsdWrapper(self, drawingMT.alpha, ...) end

--- hs._asm.ikuifilterview:setAlpha(level) -> object
--- Method
--- Sets the alpha level of the window containing the filter configuration UI object.
---
--- Parameters:
---  * level - the alpha level (0.0 - 1.0) to set the object to
---
--- Returns:
---  * the filter configuration UI object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
IKUIInternal.setAlpha = function(self, ...) return hsdWrapper(self, drawingMT.setAlpha, ...) end

--- hs._asm.ikuifilterview:behavior() -> number
--- Method
--- Returns the current behavior of the filter configuration UI object with respect to Spaces and Exposé for the object.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The numeric representation of the current behaviors for the filter configuration UI object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
IKUIInternal.behavior = function(self, ...) return hsdWrapper(self, drawingMT.behavior, ...) end

--- hs._asm.ikuifilterview:behaviorAsLabels() -> table
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
IKUIInternal.behaviorAsLabels = function(self, ...) return hsdWrapper(self, drawingMT.behaviorAsLabels, ...) end

--- hs._asm.ikuifilterview:setBehavior(behavior) -> object
--- Method
--- Sets the window behaviors represented by the number provided for the window containing the filter configuration UI object.
---
--- Parameters:
---  * behavior - the numeric representation of the behaviors to set for the window of the object
---
--- Returns:
---  * the filter configuration UI object
---
--- Notes:
---  * see the notes for `hs.drawing.windowBehaviors`
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
IKUIInternal.setBehavior = function(self, ...) return hsdWrapper(self, drawingMT.setBehavior, ...) end

--- hs._asm.ikuifilterview:setBehaviorByLabels(table) -> object
--- Method
--- Sets the window behaviors based upon the labels specified in the table provided.
---
--- Parameters:
---  * a table of label strings or numbers.  Recognized values can be found in `hs.drawing.windowBehaviors`.
---
--- Returns:
---  * the filter configuration UI object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
IKUIInternal.setBehaviorByLabels = function(self, ...) return hsdWrapper(self, drawingMT.setBehaviorByLabels, ...) end

--- hs._asm.ikuifilterview:orderAbove([object2]) -> object
--- Method
--- Moves drawing object above drawing object2, or all drawing objects in the same presentation level, if object2 is not provided.
---
--- Parameters:
---  * Optional drawing object to place the drawing object above.
---
--- Returns:
---  * the filter configuration UI object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
IKUIInternal.orderAbove = function(self, ...) return hsdWrapper(self, drawingMT.orderAbove, ...) end

--- hs._asm.ikuifilterview:orderBelow([object2]) -> object1
--- Method
--- Moves drawing object below drawing object2, or all drawing objects in the same presentation level, if object2 is not provided.
---
--- Parameters:
---  * Optional drawing object to place the drawing object below.
---
--- Returns:
---  * the filter configuration UI object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
IKUIInternal.orderBelow = function(self, ...) return hsdWrapper(self, drawingMT.orderBelow, ...) end

--- hs._asm.ikuifilterview:bringToFront([aboveEverything]) -> object
--- Method
--- Places the drawing object on top of normal windows
---
--- Parameters:
---  * aboveEverything - An optional boolean value that controls how far to the front the drawing should be placed. True to place the drawing on top of all windows (including the dock and menubar and fullscreen windows), false to place the drawing above normal windows, but below the dock, menubar and fullscreen windows. Defaults to false.
---
--- Returns:
---  * the filter configuration UI object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
IKUIInternal.bringToFront = function(self, ...)
    return IKUIInternal.setLevel(self, drawing.windowLevels.screenSaver, ...)
end

--- hs._asm.ikuifilterview:sendToBack() -> object
--- Method
--- Places the drawing object behind normal windows, between the desktop wallpaper and desktop icons
---
--- Parameters:
---  * None
---
--- Returns:
---  * the filter configuration UI object
---
--- Notes:
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
IKUIInternal.sendToBack = function(self, ...)
    return IKUIInternal.setLevel(self, drawing.windowLevels.desktopIcon - 1, ...)
end

--- hs._asm.ikuifilterview:setLevel(theLevel) -> object
--- Method
--- Sets the window level more precisely than sendToBack and bringToFront.
---
--- Parameters:
---  * theLevel - the level specified as a number or as a string where this object should be drawn.  If it is a string, it must match one of the keys in `hs.drawing.windowLevels`.
---
--- Returns:
---  * the filter configuration UI object
---
--- Notes:
---  * see the notes for `hs.drawing.windowLevels`
---  * this is actually a wrapper for compatibility with tools which wish to treat this object like an `hs.drawing` object.
IKUIInternal.setLevel = function(self, ...) return hsdWrapper(self, drawingMT.setLevel, ...) end

--- hs._asm.ikuifilterview:windowStyle(mask) -> object | currentMask
--- Method
--- Get or set the window display style
---
--- Parameters:
---  * mask - if present, this mask should be a combination of values found in `hs.webview.windowMasks` describing the window style.  The mask should be provided as one of the following:
---    * integer - a number representing the style which can be created by combining values found in `hs.webview.windowMasks` with the logical or operator.
---    * string  - a single key from `hs.webview.windowMasks` which will be toggled in the current window style.
---    * table   - a list of keys from `hs.webview.windowMasks` which will be combined to make the final style by combining their values with the logical or operator.
---
--- Returns:
---  * if a mask is provided, then the object is returned; otherwise the current mask value is returned.
IKUIInternal.windowStyle = function(self, ...)
    local arg = table.pack(...)
    local theMask = IKUIInternal._windowStyle(self)
    local webview = require("hs.webview")

    if arg.n ~= 0 then
        if type(arg[1]) == "number" then
            theMask = arg[1]
        elseif type(arg[1]) == "string" then
            if webview.windowMasks[arg[1]] then
                theMask = theMask | webview.windowMasks[arg[1]]
            else
                return error("unrecognized style specified: "..arg[1])
            end
        elseif type(arg[1]) == "table" then
            theMask = 0
            for i,v in ipairs(arg[1]) do
                if webview.windowMasks[v] then
                    theMask = theMask | webview.windowMasks[v]
                else
                    return error("unrecognized style specified: "..v)
                end
            end
        else
            return error("invalid type: number, string, or table expected, got "..type(arg[1]))
        end
        return IKUIInternal._windowStyle(self, theMask)
    else
        return theMask
    end
end

-- Return Module Object --------------------------------------------------

return module
