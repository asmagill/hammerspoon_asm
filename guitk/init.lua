--- === hs._asm.guitk ===
---
--- This module allows you to build gui elements for a variety of types of user input within Hammerspoon.  It is very much a work in progress and will probably change a lot before it approaches something near true usefulness.
---
--- The design methodology and approach taken is expected to be heavily influenced by Python's tkinter module because:
---  * it gives me an excuse to finally get around to learning python
---  * I know some users of Hammerspoon already know python and so similarities should reduce the learning curve
---  * it seemed like a good idea at the time
---
--- That said, it will likely differ in a lot of ways as well to take advantage of existing Hammerspoon modules and because the macOS has a rich variety of GUI elements available through Objective-C and Swift, some of which may not translate quite exactly to tkinter and Hammerspoon is first and foremost a macOS application.

local USERDATA_TAG = "hs._asm.guitk"
local module       = require(USERDATA_TAG..".internal")

local guitkMT = hs.getObjectMetatable(USERDATA_TAG)

-- make sure support functions registered
require("hs.drawing.color")
require("hs.image")
require("hs.window")

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

guitkMT._styleMask = guitkMT.styleMask -- save raw version
guitkMT.styleMask = function(self, ...) -- add nice wrapper version
    local arg = table.pack(...)
    local theMask = guitkMT._styleMask(self)

    if arg.n ~= 0 then
        if math.type(arg[1]) == "integer" then
            theMask = arg[1]
        elseif type(arg[1]) == "string" then
            if module.masks[arg[1]] then
                theMask = theMask ~ module.masks[arg[1]]
            else
                return error("unrecognized style specified: "..arg[1])
            end
        elseif type(arg[1]) == "table" then
            theMask = 0
            for i,v in ipairs(arg[1]) do
                if module.masks[v] then
                    theMask = theMask | module.masks[v]
                else
                    return error("unrecognized style specified: "..v)
                end
            end
        else
            return error("integer, string, or table expected, got "..type(arg[1]))
        end
        return guitkMT._styleMask(self, theMask)
    else
        return theMask
    end
end

guitkMT._collectionBehavior = guitkMT.collectionBehavior -- save raw version
guitkMT.collectionBehavior = function(self, ...)          -- add nice wrapper version
    local arg = table.pack(...)
    local theBehavior = guitkMT._collectionBehavior(self)

    if arg.n ~= 0 then
        if math.type(arg[1]) == "integer" then
            theBehavior = arg[1]
        elseif type(arg[1]) == "string" then
            if module.behaviors[arg[1]] then
                theBehavior = theBehavior ~ module.behaviors[arg[1]]
            else
                return error("unrecognized behavior specified: "..arg[1])
            end
        elseif type(arg[1]) == "table" then
            theBehavior = 0
            for i,v in ipairs(arg[1]) do
                if module.behaviors[v] then
                    theBehavior = theBehavior | ((type(v) == "string") and module.behaviors[v] or v)
                else
                    return error("unrecognized behavior specified: "..v)
                end
            end
        else
            return error("integer, string, or table expected, got "..type(arg[1]))
        end
        return guitkMT._collectionBehavior(self, theBehavior)
    else
        return theBehavior
    end
end

guitkMT._level = guitkMT.level     -- save raw version
guitkMT.level = function(self, ...) -- add nice wrapper version
    local arg = table.pack(...)
    local theLevel = guitkMT._level(self)

    if arg.n ~= 0 then
        if math.type(arg[1]) == "integer" then
            theLevel = arg[1]
        elseif type(arg[1]) == "string" then
            if module.levels[arg[1]] then
                theLevel = module.levels[arg[1]]
            else
                return error("unrecognized level specified: "..arg[1])
            end
        else
            return error("integer or string expected, got "..type(arg[1]))
        end
        return guitkMT._level(self, theLevel)
    else
        return theLevel
    end
end

guitkMT.bringToFront = function(self, ...)
    local args = table.pack(...)

    if args.n == 0 then
        return self:level(module.levels.floating)
    elseif args.n == 1 and type(args[1]) == "boolean" then
        return self:level(module.levels[(args[1] and "screenSaver" or "floating")])
    elseif args.n > 1 then
        error("bringToFront method expects 0 or 1 arguments", 2)
    else
        error("bringToFront method argument must be boolean", 2)
    end
end

guitkMT.sendToBack = function(self, ...)
    local args = table.pack(...)

    if args.n == 0 then
        return self:level(module.levels.desktopIcon - 1)
    else
        error("sendToBack method expects 0 arguments", 2)
    end
end

guitkMT.isVisible = function(self, ...) return not self:isOccluded(...) end

module.behaviors     = ls.makeConstantsTable(module.behaviors)
module.levels        = ls.makeConstantsTable(module.levels)
module.masks         = ls.makeConstantsTable(module.masks)
module.notifications = ls.makeConstantsTable(module.notifications)

-- Return Module Object --------------------------------------------------

return module
