--- === hs._asm.module ===
---
--- Functions for module
---
--- A description of module.

local module = require("hs._asm.axuielement.internal")
local log    = require("hs.logger").new("axuielement","warning")
module.log   = log
module._registerLogForC(log)
module._registerLogForC = nil

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

local examine_axuielement
examine_axuielement = function(element, depth, seen)
    seen = seen or {}
    depth = depth or 1
    local result

    if getmetatable(element) == hs.getObjectMetatable("hs._asm.axuielement") then
        for i,v in pairs(seen) do
            if i == element then return v end
        end
    end

    if depth > 0 and getmetatable(element) == hs.getObjectMetatable("hs._asm.axuielement") then
        result = {
            actions = {},
            attributes = {},
            parameterizedAttributes = {},
            pid = element:pid()
        }
        seen[element] = result

    -- actions

        if element:actionNames() then
            for i,v in ipairs(element:actionNames()) do
                result.actions[v] = element:actionDescription(v)
            end
        end

    -- attributes

        if element:attributeNames() then
            for i,v in ipairs(element:attributeNames()) do
                local value = examine_axuielement(element:attributeValue(v), depth - 1, seen)
                if element:isAttributeSettable(v) == true then
                    result.attributes[v] = {
                        settable = true,
                        value    = value
                    }
                else
                    result.attributes[v] = value
                end
            end
        end

    -- parameterizedAttributes

        if element:parameterizedAttributeNames() then
            for i,v in ipairs(element:parameterizedAttributeNames()) do
                -- for now, stick in the name until I have a better idea about what to do with them,
                -- since the AXUIElement.h Reference doesn't appear to offer a way to enumerate the
                -- parameters
                table.insert(result.parameterizedAttributes, v)
            end
        end

    elseif depth > 0 and type(element) == "table" then
        result = {}
        for k,v in pairs(element) do
            result[k] = examine_axuielement(v, depth - 1, seen)
        end
    else
        if type(element) == "table" then
            result = "table:max-depth-reached"
        elseif getmetatable(element) == hs.getObjectMetatable("hs._asm.axuielement") then
            result = "axuielement:max-depth-reached"
        else
            result = element
        end
    end
    return result
end

-- Public interface ------------------------------------------------------

-- module.types = _makeConstantsTable(module.types)
module.roles                   = _makeConstantsTable(module.roles)
module.subroles                = _makeConstantsTable(module.subroles)
module.parameterizedAttributes = _makeConstantsTable(module.parameterizedAttributes)
module.actions                 = _makeConstantsTable(module.actions)
module.attributes              = _makeConstantsTable(module.attributes)
module.notifications           = _makeConstantsTable(module.notifications)
module.directions              = _makeConstantsTable(module.directions)

module.browse = function(xyzzy, depth)
    local theElement
    -- seems deep enough for most apps and keeps us from a potential loop, though there
    -- are protections against loops built in, so... maybe I'll remove it later
    depth = depth or 100
    if type(xyzzy) == "nil" then
        theElement = axuielement.systemWideElement()
    elseif getmetatable(xyzzy) == hs.getObjectMetatable("hs._asm.axuielement") then
        theElement = xyzzy
    elseif getmetatable(xyzzy) == hs.getObjectMetatable("hs.window") then
        theElement = axuielement.windowElement(xyzzy)
    elseif getmetatable(xyzzy) == hs.getObjectMetatable("hs.application") then
        theElement = axuielement.applicationElement(xyzzy)
    else
        error("nil, hs._asm.axuielement, hs.window, or hs.application object expected", 2)
    end

    return examine_axuielement(theElement, depth, {})
end

module.systemElementAtPosition = function(...)
    return module.systemWideElement():elementAtPosition(...)
end

-- Return Module Object --------------------------------------------------

return module
