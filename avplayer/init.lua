--- === hs._asm.avplayer ===
---
--- Provides an AudioVisual player For Hammerspoon.
---
--- Playback of remote or streaming content has not been thoroughly tested; it's not something I do very often.  However, it has been tested against http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8, which is a sample URL provided in the Apple documentation at https://developer.apple.com/library/prerelease/content/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/02_Playback.html#//apple_ref/doc/uid/TP40010188-CH3-SW4

local USERDATA_TAG = "hs._asm.avplayer"
local module       = require(USERDATA_TAG..".internal")
local objectMT     = hs.getObjectMetatable(USERDATA_TAG)

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

-- private variables and methods -----------------------------------------

local canvas  = require"hs.canvas"
local webview = require"hs.webview"

-- Public interface ------------------------------------------------------

--- hs._asm.avplayer:frame([rect]) -> avplayerObject | currentValue
--- Method
--- Get or set the frame of the avplayer window.
---
--- Parameters:
---  * rect - An optional rect-table containing the co-ordinates and size the avplayer window should be moved and set to
---
--- Returns:
---  * If an argument is provided, the avplayer object; otherwise the current value.
---
--- Notes:
---  * a rect-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the avplayer window (keys `x`  and `y`) and the new size (keys `h` and `w`).  The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
objectMT.frame = function(obj, ...)
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

--- hs._asm.avplayer:windowStyle(mask) -> avplayerObject | currentMask
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
---  * if a mask is provided, then the avplayerObject is returned; otherwise the current mask value is returned.
objectMT._windowStyle = objectMT.windowStyle -- save raw version
objectMT.windowStyle = function(self, ...) -- add nice wrapper version
    local arg = table.pack(...)
    local theMask = self:_windowStyle()

    if arg.n ~= 0 then
        if type(arg[1]) == "number" then
            theMask = arg[1]
        elseif type(arg[1]) == "string" then
            if webview.windowMasks[arg[1]] then
                theMask = theMask ~ webview.windowMasks[arg[1]]
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
        return self:_windowStyle(theMask)
    else
        return theMask
    end
end

--- hs._asm.avplayer:level([theLevel]) -> drawingObject | currentValue
--- Method
--- Get or set the window level
---
--- Parameters:
---  * `theLevel` - an optional parameter specifying the desired level as an integer or string. If it is a string, it must match one of the keys in `hs.canvas.windowLevels`.
---
--- Returns:
---  * if a parameter is specified, returns the avplayer object, otherwise the current value
---
--- Notes:
---  * see the notes for `hs.drawing.windowLevels`
objectMT._level = objectMT.level -- save raw version
objectMT.level = function(self, ...) -- add nice wrapper version
    local arg = table.pack(...)
    local theLevel = self:_level()

    if arg.n ~= 0 then
        if math.type(arg[1]) == "integer" then
            theLevel = arg[1]
        elseif type(arg[1]) == "string" then
            if canvas.windowLevels[arg[1]] then
                theLevel = canvas.windowLevels[arg[1]]
            else
                return error("unrecognized level specified: "..arg[1])
            end
        else
            return error("integer or string expected, got "..type(arg[1]))
        end
        return self:_level(theLevel)
    else
        return theLevel
    end
end

--- hs._asm.avplayer:behavior([behavior]) -> avplayerObject | currentValue
--- Method
--- Get or set the window behavior settings for the avplayer object using labels defined in `hs.canvas.windowBehaviors`.
---
--- Parameters:
---  * `behavior` - if present, the behavior should be a combination of values found in `hs.canvas.windowBehaviors` describing the window behavior.  The behavior should be specified as one of the following:
---    * integer - a number representing the behavior which can be created by combining values found in `hs.canvas.windowBehaviors` with the logical or operator.
---    * string  - a single key from `hs.canvas.windowBehaviors` which will be toggled in the current window behavior.
---    * table   - a list of keys from `hs.canvas.windowBehaviors` which will be combined to make the final behavior by combining their values with the logical or operator.
---
--- Returns:
---  * if an argument is provided, then the avplayerObject is returned; otherwise the current behavior value is returned.
objectMT._behavior = objectMT.behavior -- save raw version
objectMT.behavior = function(self, ...) -- add nice wrapper version
    local arg = table.pack(...)
    local theBehavior = self:_behavior()

    if arg.n ~= 0 then
        if math.type(arg[1]) == "integer" then
            theBehavior = arg[1]
        elseif type(arg[1]) == "string" then
            if canvas.windowBehaviors[arg[1]] then
                theBehavior = theBehavior ~ canvas.windowBehaviors[arg[1]]
            else
                return error("unrecognized behavior specified: "..arg[1])
            end
        elseif type(arg[1]) == "table" then
            theBehavior = 0
            for i,v in ipairs(arg[1]) do
                if canvas.windowBehaviors[v] then
                    theBehavior = theBehavior | ((type(v) == "string") and canvas.windowBehaviors[v] or v)
                else
                    return error("unrecognized behavior specified: "..v)
                end
            end
        else
            return error("integer, string, or table expected, got "..type(arg[1]))
        end
        return self:_behavior(theBehavior)
    else
        return theBehavior
    end
end

--- hs._asm.avplayer:behaviorAsLabels(behaviorTable) -> avplayerObject | currentValue
--- Method
--- Get or set the window behavior settings for the avplayer object using labels defined in `hs.canvas.windowBehaviors`.
---
--- Parameters:
---  * behaviorTable - an optional table of strings and/or numbers specifying the desired window behavior for the avplayer object.
---
--- Returns:
---  * If an argument is provided, the avplayer object; otherwise the current value.
---
--- Notes:
---  * Window behaviors determine how the avplayer object is handled by Spaces and Exposé. See `hs.canvas.windowBehaviors` for more information.
objectMT.behaviorAsLabels = function(obj, ...)
    local args = table.pack(...)

    if args.n == 0 then
        local results = {}
        local behaviorNumber = obj:behavior()

        if behaviorNumber ~= 0 then
            for i, v in pairs(canvas.windowBehaviors) do
                if type(i) == "string" then
                    if (behaviorNumber & v) > 0 then table.insert(results, i) end
                end
            end
        else
            table.insert(results, canvas.windowBehaviors[0])
        end
        return setmetatable(results, { __tostring = function(_)
            table.sort(_)
            return "{ "..table.concat(_, ", ").." }"
        end})
    elseif args.n == 1 and type(args[1]) == "table" then
        local newBehavior = 0
        for i,v in ipairs(args[1]) do
            local flag = tonumber(v) or canvas.windowBehaviors[v]
            if flag then newBehavior = newBehavior | flag end
        end
        return obj:behavior(newBehavior)
    elseif args.n > 1 then
        error("behaviorAsLabels method expects 0 or 1 arguments", 2)
    else
        error("behaviorAsLabels method argument must be a table", 2)
    end
end

-- Return Module Object --------------------------------------------------

return module
