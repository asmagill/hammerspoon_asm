--- === hs._asm.module ===
---
--- Functions for module
---
--- A description of module.

local USERDATA_TAG = "hs._asm.axuielement"
local module       = require(USERDATA_TAG..".internal")
local log          = require("hs.logger").new("axuielement","warning")
module.log         = log
module._registerLogForC(log)
module._registerLogForC = nil

require("hs.styledtext")

local object = hs.getObjectMetatable(USERDATA_TAG)

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
examine_axuielement = function(element, showParent, depth, seen)
    seen = seen or {}
    depth = depth or 1
    local result

    if getmetatable(element) == hs.getObjectMetatable(USERDATA_TAG) then
        for i,v in pairs(seen) do
            if i == element then return v end
        end
    end

    if depth > 0 and getmetatable(element) == hs.getObjectMetatable(USERDATA_TAG) then
        result = {
            actions = {},
            attributes = {},
            parameterizedAttributes = {},
            pid = object.pid(element)
        }
        seen[element] = result

    -- actions

        if object.actionNames(element) then
            for i,v in ipairs(object.actionNames(element)) do
                result.actions[v] = object.actionDescription(element, v)
            end
        end

    -- attributes

        if object.attributeNames(element) then
            for i,v in ipairs(object.attributeNames(element)) do
                local value
                if (v ~= module.attributes.general.parent and v ~= module.attributes.general.topLevelUIElement) or showParent then
                    value = examine_axuielement(object.attributeValue(element, v), showParent, depth - 1, seen)
                else
                    value = "--parent:skipped"
                end
                if object.isAttributeSettable(element, v) == true then
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

        if object.parameterizedAttributeNames(element) then
            for i,v in ipairs(object.parameterizedAttributeNames(element)) do
                -- for now, stick in the name until I have a better idea about what to do with them,
                -- since the AXUIElement.h Reference doesn't appear to offer a way to enumerate the
                -- parameters
                table.insert(result.parameterizedAttributes, v)
            end
        end

    elseif depth > 0 and type(element) == "table" then
        result = {}
        for k,v in pairs(element) do
            result[k] = examine_axuielement(v, showParent, depth - 1, seen)
        end
    else
        if type(element) == "table" then
            result = "--table:max-depth-reached"
        elseif getmetatable(element) == hs.getObjectMetatable(USERDATA_TAG) then
            result = "--axuielement:max-depth-reached"
        else
            result = element
        end
    end
    return result
end

local elementSearchHamster
elementSearchHamster = function(element, searchParameters, isPattern, includeParents, seen)
    seen = seen or {}
    local results = {}

-- check an AXUIElement and its attributes

    if getmetatable(element) == hs.getObjectMetatable(USERDATA_TAG) then
        for k, v in pairs(seen) do
            if k == element then return results end
        end
        seen[element] = true

    -- first check if this element itself belongs in the result set
        if object.matches(element, searchParameters, isPattern) then
            table.insert(results, element)
        end

    -- now check any of it's attributes and if they are a userdata, check them
        for i, v in ipairs(object.attributeNames(element) or {}) do
            if (v ~= module.attributes.general.parent and v ~= module.attributes.general.topLevelUIElement) or includeParents then
                local value = object.attributeValue(element, v)
                if  type(value) == "table" or getmetatable(value) == hs.getObjectMetatable(USERDATA_TAG) then
                    local tempResults = elementSearchHamster(value, searchParameters, isPattern, includeParents, seen)
                    if #tempResults > 0 then
                        for i2, v2 in ipairs(tempResults) do -- flatten; we'll cull duplicates later
                            table.insert(results, v2)
                        end
                    end
                end
            end
        end

-- iterate over any table that has been passed in
    elseif type(element) == "table" then
        for i, v in ipairs(element) do
            if  type(v) == "table" or getmetatable(v) == hs.getObjectMetatable(USERDATA_TAG) then
                local tempResults = elementSearchHamster(v, searchParameters, isPattern, includeParents, seen)
                if #tempResults > 0 then
                    for i2, v2 in ipairs(tempResults) do -- flatten; we'll cull duplicates later
                        table.insert(results, v2)
                    end
                end
            end
        end

-- other types we just silently ignore; shouldn't happen anyways with the above checks before recursion
--    else
    end

    -- cull duplicates
    if #results > 0 then
        local holding, realResults = {}, {}
        for i,v in ipairs(results) do
            local found = false
            for k1, v1 in pairs(holding) do
                if v == v1 then found = true ; break end
            end
            if not found then
                holding[v] = true
                table.insert(realResults, v)
            end
        end
        results = realResults
    end

    return results
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

module.browse = function(xyzzy, showParent, depth)
    if type(showParent) == "number" then showParent, depth = nil, showParent end
    showParent = showParent or false
    local theElement
    -- seems deep enough for most apps and keeps us from a potential loop, though there
    -- are protections against loops built in, so... maybe I'll remove it later
    depth = depth or 100
    if type(xyzzy) == "nil" then
        theElement = module.systemWideElement()
    elseif getmetatable(xyzzy) == hs.getObjectMetatable(USERDATA_TAG) then
        theElement = xyzzy
    elseif getmetatable(xyzzy) == hs.getObjectMetatable("hs.window") then
        theElement = module.windowElement(xyzzy)
    elseif getmetatable(xyzzy) == hs.getObjectMetatable("hs.application") then
        theElement = module.applicationElement(xyzzy)
    else
        error("nil, "..USERDATA_TAG..", hs.window, or hs.application object expected", 2)
    end

    return examine_axuielement(theElement, showParent, depth, {})
end

module.systemElementAtPosition = function(...)
    return module.systemWideElement():elementAtPosition(...)
end

object.__index = function(self, _)
    if type(_) == "string" then
        -- take care of the internally defined items first so we can get out of here quickly if its one of them
        for k, v in pairs(object) do if _ == k then return v end end

        -- Now for the dynamically generated methods...

        local matchName = _:match("^set(.+)$")
        if not matchName then matchName = _:match("^do(.+)$") end
        if not matchName then matchName = _:match("^(.+)WithParameter$") end
        if not matchName then matchName = _ end
        local formalName = matchName:match("^AX[%w%d_]+$") and matchName or "AX"..matchName:sub(1,1):upper()..matchName:sub(2)

        -- check for setters
        if _:match("^set") then

             -- check attributes
             for i, v in ipairs(object.attributeNames(self) or {}) do
                if v == formalName and object.isAttributeSettable(self, formalName) then
                    return function(self, ...) return object.setAttributeValue(self, formalName, ...) end
                end
            end

        -- check for doers
        elseif _:match("^do") then

            -- check actions
            for i, v in pairs(object.actionNames(self) or {}) do
                if v == formalName then
                    return function(self, ...) return object.performAction(self, formalName, ...) end
                end
            end

        -- getter or bust
        else

            -- check attributes
            for i, v in ipairs(object.attributeNames(self) or {}) do
                if v == formalName then
                    return function(self, ...) return object.attributeValue(self, formalName, ...) end
                end
            end

            -- check paramaterizedAttributes
            for i, v in ipairs(object.parameterizedAttributeNames(self) or {}) do
                if v == formalName then
                    return function(self, ...) return object.parameterizedAttributeValue(self, formalName, ...) end
                end
            end
        end

        -- guess it doesn't exist
        return nil
    elseif type(_) == "number" then
        local children = object.attributeValue(self, "AXChildren")
        if children then
            return children[_]
        else
            return nil
        end
    else
        return nil
    end
end

object.__len = function(self)
    local children = object.attributeValue(self, "AXChildren")
    if children then
        return #children
    else
        return 0
    end
end

object.methods = function(self)
    local results = {}

    -- attributes
    for i,v in ipairs(object.attributeNames(self) or {}) do
        local shortName = v:match("^AX(.+)$")
        local camelCaseName = shortName:sub(1,1):lower()..shortName:sub(2)
        results[camelCaseName] = function(...) return object.attributeValue(self, v, ...) end
        if object.isAttributeSettable(self, v) then
            results["set"..shortName] = function(...) return object.setAttributeValue(self, v, ...) end
        end
    end

    -- parameterizedAttributes
    for i,v in ipairs(object.parameterizedAttributeNames(self) or {}) do
        local shortName = v:match("^AX(.+)$")
        local camelCaseName = shortName:sub(1,1):lower()..shortName:sub(2)
        results[camelCaseName.."WithParameter"] = function(...) return object.parameterizedAttributeValue(self, v, ...) end
    end

    -- actions
    for i,v in ipairs(object.actionNames(self) or {}) do
        local shortName = v:match("^AX(.+)$")
        local camelCaseName = shortName:sub(1,1):lower()..shortName:sub(2)
        results["do"..shortName] = function(...) return object.performAction(self, v, ...) end
    end

    return results
end

-- searchParameters = {
--    attr1 = string | number | boolean | hs._asm.axuielement
--    attr2 = { acceptedTypes, ... }
-- }
-- keys are anded together -- all must be true to meet the criteria
-- table values are or'ed -- match any entry in array for this key to match
object.matches = function(self, searchParameters, isPattern)
    isPattern = isPattern or false
    if type(searchParameters) == "string" or #searchParameters > 0 then searchParameters = { role = searchParameters } end
    local answer = nil
    if getmetatable(self) == hs.getObjectMetatable(USERDATA_TAG) then
        answer = true
        for k, v in pairs(searchParameters) do
            local testFn = nil
            if type(k) == "string" then
                local formalName = k:match("^AX[%w%d_]+$") and k or "AX"..k:sub(1,1):upper()..k:sub(2)
                testFn = function(self) return object.attributeValue(self, formalName) end
            elseif type(k) == "function" then
                testFn = k
            else
                local dbg = debug.getinfo(2)
                log.wf("%s:%d: type '%s' is not a valid key in searchParameters", dbg.short_src, dbg.currentline, type(k))
            end
            if testFn then
                local result = testFn(self)
                if type(v) ~= "table" then v = { v } end
                local partialAnswer = false
                for i2, v2 in ipairs(v) do
                    if type(v2) == "string" then
                        partialAnswer = partialAnswer or (not isPattern and result == v2) or (isPattern and result:match(v2))
                    elseif type(v2) == "number" or type(v2) == "boolean" or getmetatable(v2) == hs.getObjectMetatable(USERDATA_TAG) then
                        partialAnswer = partialAnswer or (result == v2)
                    else
                        local dbg = debug.getinfo(2)
                        log.wf("%s:%d: unable to compare type '%s' in searchParameters", dbg.short_src, dbg.currentline, type(v2))
                    end
                    if partialAnswer then break end
                end
                answer = partialAnswer
            else
                answer = false
            end
            if not answer then break end
        end
    end
    return answer
end

object.elementSearch = function(self, searchParameters, isPattern, includeParents)
    isPattern = isPattern or false
    includeParents = includeParents or false
    if type(searchParameters) == "string" or #searchParameters > 0 then searchParameters = { role = searchParameters } end

    -- reduce overhead slightly by pre-creating the necessary attribute query functions
    -- rather than have __init do it for *every* comparison
    local spHolder = {}
    for k, v in pairs(searchParameters) do
        local formalName = k:match("^AX[%w%d_]+$") and k or "AX"..k:sub(1,1):upper()..k:sub(2)
        spHolder[function(self) return object.attributeValue(self, formalName) end] = v
    end
    searchParameters = spHolder
    local results = {}
    if type(self) == "userdata" then
        results = elementSearchHamster(self, searchParameters, isPattern, includeParents)
    else
        for i,v in ipairs(self) do
            if object.matches(v, searchParameters, isPattern) then
                table.insert(results, v)
            end
        end
    end

    return setmetatable(results, {
        __index = {
            elementSearch = object.elementSearch
        }
    })
end

-- Return Module Object --------------------------------------------------

if module.types then module.types = _makeConstantsTable(module.types) end
return module
