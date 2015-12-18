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
_kMetaTable._k = {}
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
            local width = 0
            for k,v in pairs(_kMetaTable._k[obj]) do width = width < #k and #k or width end
            for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                result = result..string.format("%-"..tostring(width).."s %s\n", k, tostring(v))
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

        for i,v in ipairs(element:actionNames()) do
            result.actions[v] = element:actionDescription(v)
        end

    -- attributes

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

    -- parameterizedAttributes

        local pAN = element:parameterizedAttributeNames()
        if pAN then
            for i,v in ipairs(pAN) do
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

module.types = _makeConstantsTable(module.types)

module.browse = function(xyzzy, depth)
    local theElement
    -- seems deep enough for most apps and keeps us from a potential loop
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

-- Return Module Object --------------------------------------------------

return module
