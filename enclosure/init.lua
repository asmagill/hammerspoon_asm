
local USERDATA_TAG = "hs._asm.enclosure"
local module       = require(USERDATA_TAG..".internal")
module.toolbar     = require(USERDATA_TAG..".toolbar")

local windowMT = hs.getObjectMetatable(USERDATA_TAG)

local submodules = {
    avplayer   = USERDATA_TAG .. ".avplayer",
    button     = USERDATA_TAG .. ".button",
    canvas     = USERDATA_TAG .. ".canvas",
    progress   = USERDATA_TAG .. ".progress",
    scrollview = USERDATA_TAG .. ".scrollview",
    textview   = USERDATA_TAG .. ".textview",
    toolbar    = USERDATA_TAG .. ".toolbar", -- included for completeness, but explicitly included above
    webview    = USERDATA_TAG .. ".webview",
}

require("hs.drawing.color")
require("hs.image")

-- don't load until needed as some of them can be required directly without requiring
-- that this module actually be loaded
module = setmetatable(module, {
    __index = function(self, key)
        if not rawget(self, key) and submodules[key] then
            rawset(self, key, require(submodules[key]))
        end
        return rawget(self, key)
    end,
})

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

windowMT._styleMask = windowMT.styleMask -- save raw version
windowMT.styleMask = function(self, ...) -- add nice wrapper version
    local arg = table.pack(...)
    local theMask = windowMT._styleMask(self)

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
        return windowMT._styleMask(self, theMask)
    else
        return theMask
    end
end

windowMT._collectionBehavior = windowMT.collectionBehavior -- save raw version
windowMT.collectionBehavior = function(self, ...)          -- add nice wrapper version
    local arg = table.pack(...)
    local theBehavior = windowMT._collectionBehavior(self)

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
        return windowMT._collectionBehavior(self, theBehavior)
    else
        return theBehavior
    end
end

windowMT._level = windowMT.level     -- save raw version
windowMT.level = function(self, ...) -- add nice wrapper version
    local arg = table.pack(...)
    local theLevel = windowMT._level(self)

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
        return windowMT._level(self, theLevel)
    else
        return theLevel
    end
end

-- windowMT.frame = function(self, ...)
--     local args = table.pack(...)
--
--     if args.n == 0 then
--         local topLeft = self:topLeft()
--         local size    = self:size()
--         return {
--             __luaSkinType = "NSRect",
--             x = topLeft.x,
--             y = topLeft.y,
--             h = size.h,
--             w = size.w,
--         }
--     elseif args.n == 1 and type(args[1]) == "table" then
--         self:size(args[1])
--         self:topLeft(args[1])
--         return self
--     elseif args.n > 1 then
--         error("frame method expects 0 or 1 arguments", 2)
--     else
--         error("frame method argument must be a table", 2)
--     end
-- end

windowMT.bringToFront = function(self, ...)
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

windowMT.sendToBack = function(self, ...)
    local args = table.pack(...)

    if args.n == 0 then
        return self:level(module.levels.desktopIcon - 1)
    else
        error("sendToBack method expects 0 arguments", 2)
    end
end

windowMT.isVisible = function(self, ...) return not self:isOccluded(...) end
windowMT.toolbar   = module.toolbar.attachToolbar

windowMT.forwardMethods = function(self, ...)
    local userTable = debug.getuservalue(self)
    if not userTable then
        userTable = { forwardMethods = false }
        debug.setuservalue(self, userTable)
    end
    local args = table.pack(...)
    if args.n == 0 then
        return userTable.forwardMethods
    elseif args.n == 1 and type(args[1]) == "boolean" then
        userTable.forwardMethods = args[1]
        debug.setuservalue(self, userTable)
    else
        error("expected an optional boolean", 2)
    end
    return self
end

windowMT.__index = function(self, key)
    if windowMT[key] then
        return windowMT[key]
    else
        local userTable = debug.getuservalue(self) or {}
        if userTable.forwardMethods then
            local cv = self:contentView()
            if type(cv) == "userdata" then
                return function(_, ...) return cv[key](cv, ...) end
            end
        end
    end
    return nil
end

module.behaviors     = _makeConstantsTable(module.behaviors)
module.levels        = _makeConstantsTable(module.levels)
module.masks         = _makeConstantsTable(module.masks)
module.notifications = _makeConstantsTable(module.notifications)

-- Return Module Object --------------------------------------------------

return module
