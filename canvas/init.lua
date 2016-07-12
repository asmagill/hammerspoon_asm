--- === hs._asm.canvas ===
---
--- A different approach to drawing in Hammerspoon
---
--- `hs.drawing` approaches graphical images and independant primitives, each "shape" being an independant drawing object based on the core primitives: ellipse, rectangle, point, line, text, etc.  This model works well with graphical elements that are expected to be managed individually and don't have complex clipping interactions, but does not scale well when more complex combinations or groups of drawing elements need to be moved or manipulated as a group, and only allows for simple inclusionary clipping regions.
---
--- This module works by designating a canvas and then assigning a series of graphical primitives to the canvas.  Included in this assignment list are rules about how the individual elements interact with each other within the canvas (compositing and clipping rules), and direct modification of the canvas itself (move, resize, etc.) causes all of the assigned elements to be adjusted as a group.
---
--- This is an experimental work in progress, so we'll see how it goes...
---
--- ### Overview
---
--- The canvas elements are defined in an array, and each entry of the array is a table of key-value pairs describing the element at that position.  Elements are rendered in the order in which they are assigned to the array (i.e. element 1 is drawn before element 2, etc.).
---
--- All canvas elements require the `type` field; all other attributes have default values.  Defaults are first looked for in the canvas level defaults, and then in the module's built in defaults.
---
--- #### Element Attributes
---
--- * `type` - specifies the type of canvas element the table represents. This attribute has no default and must be specified for each element in the canvas array. Valid type strings are:
---   * `arc`           - an arc inscribed on a circle, defined by `radius`, `center`, `startAngle`, and `endAngle`.
---   * `circle`        - a circle, defined by `radius` and `center`.
---   * `ellipticalArc` - an arc inscribed on an oval, defined by `frame`, `startAngle`, and `endAngle`.
---   * `image`         - an image as defined by one of the `hs.image` constructors.
---   * `oval`          - an oval, defined by `frame`
---   * `points`        - a list of points defined in `coordinates`.
---   * `rectangle`     - a rectangle, optionally with rounded corners, defined by `frame`.
---   * `resetClip`     - a special type -- indicates that the current clipping shape should be reset to the canvas default (the full canvas area).  See `Clipping Example`.
---   * `segments`      - a list of line segments or bezier curves with control points, defined in `coordinates`.
---   * `text`          - a string or `hs.styledtext` object, defined by `text` and `frame`.
---
--- * The following is a list of all valid attributes.  Not all attributes apply to every type, but you can set them for any type.
---   * `action`              - Default `strokeAndFill`. A string specifying the action to take for the element in the array.  The following actions are recognized:
---     * `clip`          - append the shape to the current clipping region for the canvas. Ignored for `image` and `text` types.
---     * `build`         - do not render the element -- it's shape is preserved and the next element in the canvas array is appended to it.  This can be used to create complex shapes or clipping regions. Ignored for `image` and `text` types.
---     * `fill`          - fill the canvas element, if it is a shape, or display it normally if it is an `image` or `text`.  Ignored for `resetClip`.
---     * `skip`          - ignore this element or its effects.  Can be used to temporarily "remove" an object from the canvas.
---     * `stroke`        - stroke (outline) the canvas element, if it is a shape, or display it normally if it is an `image` or `text`.  Ignored for `resetClip`.
---     * `strokeAndFill` - stroke and fill the canvas element, if it is a shape, or display it normally if it is an `image` or `text`.  Ignored for `resetClip`.
---   * `absolutePosition`    - Default `true`. If false, non-string location/size attributes (`frame`, `center`, `radius`, and `coordinates`) will be automatically adjusted when the canvas is resized with [hs._asm.canvas:size](#size) or [hs._asm.canvas:frame](#frame) so that the element remains in the same "relative" position in the canvas.
---   * `absoluteSize`        - Default `true`. If false, non-string location/size attributes (`frame`, `center`, `radius`, and `coordinates`) will be automatically adjusted when the canvas is resized with [hs._asm.canvas:size](#size) or [hs._asm.canvas:frame](#frame) so that the element maintains the same "relative" size in the canvas.
---   * `antialias`           - Default `true`.  Indicates whether or not antialiasing should be enabled for the element.
---   * `arcRadii`            - Default `true`. Used by the `arc` and `ellipticalArc` types to specify whether or not line segments from the elements center to the start and end angles should be included in the elements visible portion.  This affects whether the objects stroke is a pie-shape or an arc with a chord from the start angle to the end angle.
---   * `arcClockwise`        - Default `true`.  Used by the `arc` and `ellipticalArc` types to specify whether the arc should be drawn from the start angle to the end angle in a clockwise (true) direction or in a counter-clockwise (false) direction.
---   * `compositeRule`
---   * `center`              - Default `{ x = "50%", y = "50%" }`.  Used by the `circle` and `arc` types to specify the center of the canvas element.  The `x` and `y` fields can be specified as numbers or as a string. When specified as a string, the value is treated as a percentage of the canvas size.  See the section on percentages for more information.
---   * `closed`              - Default `false`.  Used by the `segments` type to specify whether or not the shape defined by the lines and curves defined should be closed (true) or open (false).  When an object is closed, an implicit line is stroked from the final point back to the initial point of the coordinates listed.
---   * `coordinates`         - An array containing coordinates used by the `segments` and `points` types to define the lines and curves or points that make up the canvas element.  The following keys are recognized and may be specified as numbers or strings (see the section on percentages).
---     * `x`   - required for `segments` and `points`, specifying the x coordinate of a point.
---     * `y`   - required for `segments` and `points`, specifying the y coordinate of a point.
---     * `c1x` - optional for `segments, specifying the x coordinate of the first control point used to draw a bezier curve between this point and the previous point.  Ignored for `points` and if present in the first coordinate in the `coordinates` array.
---     * `c1y` - optional for `segments, specifying the y coordinate of the first control point used to draw a bezier curve between this point and the previous point.  Ignored for `points` and if present in the first coordinate in the `coordinates` array.
---     * `c2x` - optional for `segments, specifying the x coordinate of the second control point used to draw a bezier curve between this point and the previous point.  Ignored for `points` and if present in the first coordinate in the `coordinates` array.
---     * `c2y` - optional for `segments, specifying the y coordinate of the second control point used to draw a bezier curve between this point and the previous point.  Ignored for `points` and if present in the first coordinate in the `coordinates` array.
---   * `endAngle`            - Default `360.0`. Used by the `arc` and `ellipticalArc` to specify the ending angle for the inscribed arc.
---   * `fillColor`           - Default `{ red = 1.0 }`.  Specifies the color used to fill the canvas element when the `action` is set to `fill` or `strokeAndFill` and `fillGradient` is equal to `none`.  Ignored for the `image` and `text` types.
---   * `fillGradient`        - Default `none`.  A string specifying whether a fill gradient should be used instead of the fill color when the action is `fill` or `strokeAndFill`.  May be `none`, `linear`, or `radial`.
---   * `fillGradientAngle`   - Default 0.0.  Specifies the direction of a linear gradient when `fillGradient` is linear.
---   * `fillGradientCenter`  - Default `{ x = 0.0, y = 0.0 }`. Specifies the relative center point within the elements bounds of a radial gradient when `fillGradient` is `radial`.  The `x` and `y` fields must both be between -1.0 and 1.0 inclusive.
---   * `fillGradientColors`  - Default `{ startColor = { white = 0.0 }, endColor = { white = 1.0 } }`.  Specifies the beginning and ending colors for a gradient when `fillGradient` is not `none`.
---   * `flatness`            -
---   * `flattenPath`         -
---   * `frame`               -
---   * `id`                  -
---   * `image`               -
---   * `miterLimit`          -
---   * `padding`             -
---   * `radius`              -
---   * `reversePath`         -
---   * `roundedRectRadii`    -
---   * `shadow`              -
---   * `startAngle`          -
---   * `strokeCapStyle`      -
---   * `strokeColor`         -
---   * `strokeDashPattern`   -
---   * `strokeDashPhase`     -
---   * `strokeJoinStyle`     - Default `miter`.  A string which specifies the shape of the joints between connected segments of a stroked path.  Valid values for this attribute are "miter", "round", and "bevel".  Ignored for element types of `image` and `text`.
---   * `strokeWidth`         - Default `1.0`.  Specifies the width of stroked lines when an element's action is set to `stroke` or `strokeAndFill`.  Ignored for the `image` and `text` element types.
---   * `text`                - Default `""`.  Specifies the text to display for a `text` element.  This may be specified as a string, or as an `hs.styledtext` object.
---   * `textColor`           - Default `{ white = 1.0 }`.  Specifies the color to use when displaying the `text` element type, if the text is specified as a string.  This field is ignored if the text is specified as an `hs.styledtext` object.
---   * `textFont`            - Defaults to the default system font.  A string specifying the name of thefont to use when displaying the `text` element type, if the text is specified as a string.  This field is ignored if the text is specified as an `hs.styledtext` object.
---   * `textSize`            - Default `27.0`.  Specifies the sont size to use when displaying the `text` element type, if the text is specified as a string.  This field is ignored if the text is specified as an `hs.styledtext` object.
---   * `trackMouseEnterExit` - Default `false`.  Generates a callback when the mouse enters or exits the visible portion of the canvas element.  For `text` and `image` types, the `frame` of the element defines the boundaries of the tracking area.
---   * `trackMouseDown`      - Default `false`.  Generates a callback when mouse button is clicked down while the cursor is within the visible portion of the canvas element.  For `text` and `image` types, the `frame` of the element defines the boundaries of the tracking area.
---   * `trackMouseUp`        - Default `false`.  Generates a callback when mouse button is released while the cursor is within the visible portion of the canvas element.  For `text` and `image` types, the `frame` of the element defines the boundaries of the tracking area.
---   * `trackMouseMove`      - Default `false`.  Generates a callback when the mouse cursor moves within the visible portion of the canvas element.  For `text` and `image` types, the `frame` of the element defines the boundaries of the tracking area.
---   * `transformation`      - Default `{ m11 = 1.0, m12 = 0.0, m21 = 0.0, m22 = 1.0, tX = 0.0, tY = 0.0 }`. Specifies a matrix transformation to apply to the element before displaying it.  Transformations may include rotation, translation, scaling, skewing, etc.
---   * `windingRule`         - Default `nonZero`.  A string specifying the winding rule in effect for the canvas element. May be "nonZero" or "evenOdd".  The winding rule determines which portions of an element to fill. This setting will only have a visible effect on compound elements (built with the `build` action) or elements of type `segments` when the object is made from lines which cross.
---   * `withShadow`          - Default `false`. Specifies whether a shadow effect should be applied to the canvas element.  Ignored for the `text` type.


local USERDATA_TAG = "hs._asm.canvas"
local module       = require(USERDATA_TAG..".internal")
module.matrix      = require(USERDATA_TAG..".matrix")
local canvasMT     = hs.getObjectMetatable(USERDATA_TAG)

-- private variables and methods -----------------------------------------

local _kMetaTable = {}
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

-- Public interface ------------------------------------------------------

module.compositeTypes = _makeConstantsTable(module.compositeTypes)

--- hs._asm.canvas:behaviorAsLabels(behaviorTable) -> canvasObject | currentValue
--- Method
--- Get or set the window behavior settings for the canvas object using labels defined in `hs.drawing.windowBehaviors`.
---
--- Parameters:
---  * behaviorTable - an optional table of strings and/or numbers specifying the desired window behavior for the canvas object.
---
--- Returns:
---  * If an argument is provided, the canvas object; otherwise the current value.
---
--- Notes:
---  * Window behaviors determine how the canvas object is handled by Spaces and Exposé. See `hs.drawing.windowBehaviors` for more information.
canvasMT.behaviorAsLabels = function(obj, ...)
    local drawing = require"hs.drawing"
    local args = table.pack(...)

    if args.n == 0 then
        local results = {}
        local behaviorNumber = obj:behavior()

        if behaviorNumber ~= 0 then
            for i, v in pairs(drawing.windowBehaviors) do
                if type(i) == "string" then
                    if (behaviorNumber & v) > 0 then table.insert(results, i) end
                end
            end
        else
            table.insert(results, drawing.windowBehaviors[0])
        end
        return setmetatable(results, { __tostring = function(_)
            table.sort(_)
            return "{ "..table.concat(_, ", ").." }"
        end})
    elseif args.n == 1 and type(args[1]) == "table" then
        local newBehavior = 0
        for i,v in ipairs(args[1]) do
            local flag = tonumber(v) or drawing.windowBehaviors[v]
            if flag then newBehavior = newBehavior | flag end
        end
        return obj:behavior(newBehavior)
    elseif args.n > 1 then
        error("behaviorByLabels method expects 0 or 1 arguments", 2)
    else
        error("behaviorByLabels method argument must be a table", 2)
    end
end

--- hs._asm.canvas:frame([rect]) -> canvasObject | currentValue
--- Method
--- Get or set the frame of the canvasObject.
---
--- Parameters:
---  * rect - An optional rect-table containing the co-ordinates and size the canvas object should be moved and set to
---
--- Returns:
---  * If an argument is provided, the canvas object; otherwise the current value.
---
--- Notes:
---  * a rect-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the canvas (keys `x  and `y`) and the new size (keys `h` and `w`).  The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
---
---  * elements in the canvas that do not have the `absolutePosition` attribute set will be moved so that their relative position within the canvas remains the same with respect to the new size.
---  * elements in the canvas that do not have the `absoluteSize` attribute set will be resized so that their size relative to the canvas remains the same with respect to the new size.
canvasMT.frame = function(obj, ...)
    local args = table.pack(...)

    if args.n == 0 then
        local topLeft = obj:topLeft()
        local size    = obj:size()
        return {
            __luaSkinType = "NSRect",
            x = topLeft.x,
            y = topLeft.y,
            h = size.h,
            w = size.w,
        }
    elseif args.n == 1 and type(args[1]) == "table" then
        obj:size(args[1])
        obj:topLeft(args[1])
        return obj
    elseif args.n > 1 then
        error("frame method expects 0 or 1 arguments", 2)
    else
        error("frame method argument must be a table", 2)
    end
end

--- hs._asm.canvas:bringToFront([aboveEverything]) -> canvasObject
--- Method
--- Places the canvas object on top of normal windows
---
--- Parameters:
---  * aboveEverything - An optional boolean value that controls how far to the front the canvas should be placed. Defaults to false.
---    * if true, place the canvas on top of all windows (including the dock and menubar and fullscreen windows).
---    * if false, place the canvas above normal windows, but below the dock, menubar and fullscreen windows.
---
--- Returns:
---  * The canvas object
canvasMT.bringToFront = function(obj, ...)
    local drawing = require"hs.drawing"
    local args = table.pack(...)

    if args.n == 0 then
        return obj:level(drawing.windowLevels.floating)
    elseif args.n == 1 and type(args[1]) == "boolean" then
        return obj:level(drawing.windowLevels[(args[1] and "screenSaver" or "floating")])
    elseif args.n > 1 then
        error("bringToFront method expects 0 or 1 arguments", 2)
    else
        error("bringToFront method argument must be boolean", 2)
    end
end

--- hs._asm.canvas:sendToBack() -> canvasObject
--- Method
--- Places the canvas object behind normal windows, between the desktop wallpaper and desktop icons
---
--- Parameters:
---  * None
---
--- Returns:
---  * The canvas object
canvasMT.sendToBack = function(obj, ...)
    local drawing = require"hs.drawing"
    local args = table.pack(...)

    if args.n == 0 then
        return obj:level(drawing.windowLevels.desktopIcon - 1)
    else
        error("sendToBack method expects 0", 2)
    end
end

--- hs._asm.canvas:isVisible() -> boolean
--- Method
--- Returns whether or not the canvas is currently showing and is (at least partially) visible on screen.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a boolean indicating whether or not the canvas is currently visible.
---
--- Notes:
---  * This is syntactic sugar for `not hs._asm.canvas:isOccluded()`.
---  * See (hs._asm.canvas:isOccluded)[#isOccluded] for more details.
canvasMT.isVisible = function(obj, ...) return not obj:isOccluded(...) end

canvasMT.appendElements = function(obj, elementsArray)
    for i,v in ipairs(elementsArray) do obj:insertElement(v) end
    return obj
end

canvasMT.replaceElements = function(obj, elementsArray)
    for i,v in ipairs(elementsArray) do obj:assignElement(v, i) end
    while (#obj > #elementArray) do obj:removeElement() end
    return obj
end

canvasMT.rotateElement = function(obj, index, angle, point, append)
    local bounds = obj:elementBounds(index)
    if type(point) == "boolean" then
        append, point = point, nil
    end
    if not point then
        point = {
            x = bounds.x + bounds.w / 2,
            y = bounds.y + bounds.h / 2,
        }
    end

    local currentTransform = obj:elementAttribute(index, "transformation")
    if append then
        obj[index].transformation = obj[index].transformation:translate(point.x, point.y)
                                                             :rotate(angle)
                                                             :translate(-point.x, -point.y)
    else
        obj[index].transformation = module.matrix.translate(point.x, point.y):rotate(angle)
                                                                             :translate(-point.x, -point.y)
    end
    return obj
end

local elementMT = {
    __e = setmetatable({}, { __mode="k" }),
}

elementMT.__index = function(_, k)
    local obj = elementMT.__e[_]
    if obj.field then
        return obj.value[obj.field][k]
    elseif obj.key then
        if type(obj.value[k]) == "table" then
            local newTable = {}
            elementMT.__e[newTable] = { self = obj.self, index = obj.index, key = obj.key, value = obj.value, field = k }
            return setmetatable(newTable, elementMT)
        else
            return obj.value[k]
        end
    else
        local value
        if obj.index == "_default" then
            value = obj.self:canvasDefaultFor(k)
        else
            value = obj.self:elementAttribute(obj.index, k)
        end
        if type(value) == "table" then
            local newTable = {}
            elementMT.__e[newTable] = { self = obj.self, index = obj.index, key = k, value = value }
            return setmetatable(newTable, elementMT)
        else
            return value
        end
    end
end

elementMT.__newindex = function(_, k, v)
    local obj = elementMT.__e[_]
    local key, value
    if obj.field then
        key = obj.key
        obj.value[obj.field][k] = v
        value = obj.value
    elseif obj.key then
        key = obj.key
        obj.value[k] = v
        value = obj.value
    else
        key = k
        value = v
    end
    if obj.index == "_default" then
        return obj.self:canvasDefaultFor(key, value)
    else
        return obj.self:elementAttribute(obj.index, key, value)
    end
end

elementMT.__pairs = function(_)
    local obj = elementMT.__e[_]
    local keys = {}
    if obj.field then
        keys = obj.value[obj.field]
    elseif obj.key then
        keys = obj.value
    else
        if obj.index == "_default" then
            for i, k in ipairs(obj.self:canvasDefaultKeys()) do keys[k] = _[k] end
        else
            for i, k in ipairs(obj.self:elementKeys(obj.index)) do keys[k] = _[k] end
        end
    end
    return function(_, k)
            local v
            k, v = next(keys, k)
            return k, v
        end, _, nil
end

elementMT.__len = function(_)
    local obj = elementMT.__e[_]
    local value
    if obj.field then
        value = obj.value[obj.field]
    elseif obj.key then
        value = obj.value
    else
        value = {}
    end
    return #value
end

local dump_table
dump_table = function(depth, value)
    local result = "{\n"
    for k,v in require("hs.fnutils").sortByKeys(value) do
        local displayValue = v
        if type(v) == "table" then
            displayValue = dump_table(depth + 2, v)
        elseif type(v) == "string" then
            displayValue = "\"" .. v .. "\""
        end
        local displayKey = k
        if type(k) == "number" then
            displayKey = "[" .. tostring(k) .. "]"
        end
        result = result .. string.rep(" ", depth + 2) .. string.format("%s = %s,\n", tostring(displayKey), tostring(displayValue))
    end
    result = result .. string.rep(" ", depth) .. "}"
    return result
end

elementMT.__tostring = function(_)
    local obj = elementMT.__e[_]
    local value
    if obj.field then
        value = obj.value[obj.field]
    elseif obj.key then
        value = obj.value
    else
        value = _
    end
    if type(value) == "table" then
        return dump_table(0, value)
    else
        return tostring(value)
    end
end

canvasMT.__index = function(self, key)
    if type(key) == "string" then
        if key == "_default" then
            local newTable = {}
            elementMT.__e[newTable] = { self = self, index = "_default" }
            return setmetatable(newTable, elementMT)
        else
            return canvasMT[key]
        end
    elseif type(key) == "number" and key > 0 and key <= self:elementCount() and math.tointeger(key) then
        local newTable = {}
        elementMT.__e[newTable] = { self = self, index = math.tointeger(key) }
        return setmetatable(newTable, elementMT)
    else
        return nil
    end
end

canvasMT.__newindex = function(self, key, value)
    if type(key) == "number" and key > 0 and key <= (self:elementCount() + 1) and math.tointeger(key) then
        if type(value) == "table" or type(value) == "nil" then
            return self:assignElement(value, math.tointeger(key))
        else
            error("element definition must be a table", 2)
        end
    else
        error("index invalid or out of bounds", 2)
    end
end

canvasMT.__len = function(self)
    return self:elementCount()
end

canvasMT.__pairs = function(self)
    local keys = {}
    for i = 1, self:elementCount(), 1 do keys[i] = self[i] end
    return function(_, k)
            local v
            k, v = next(keys, k)
            return k, v
        end, self, nil
end

-- Return Module Object --------------------------------------------------

return module
