--- === hs._asm.spotlight ===
---
--- Stuff about the module

--- === hs._asm.spotlight.group ===
---
--- Stuff about the module

--- === hs._asm.spotlight.item ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.spotlight"
local module       = require(USERDATA_TAG..".internal")
local objectMT     = hs.getObjectMetatable(USERDATA_TAG)
local itemObjMT    = hs.getObjectMetatable(USERDATA_TAG .. ".item")
local groupObjMT   = hs.getObjectMetatable(USERDATA_TAG .. ".group")

require("hs.sharing") -- get NSURL helper

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

module.searchScopes = _makeConstantsTable(module.searchScopes)
table.sort(module.commonAttributeKeys)
module.commonAttributeKeys = _makeConstantsTable(module.commonAttributeKeys)

local searchScopes = objectMT.searchScopes
objectMT.searchScopes = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return searchScopes(self)
    elseif args.n == 1 then
        return searchScopes(self, ...)
    else
        return searchScopes(self, args)
    end
end

local callbackMessages = objectMT.callbackMessages
objectMT.callbackMessages = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return callbackMessages(self)
    elseif args.n == 1 then
        return callbackMessages(self, ...)
    else
        return callbackMessages(self, args)
    end
end

local groupingAttributes = objectMT.groupingAttributes
objectMT.groupingAttributes = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return groupingAttributes(self)
    elseif args.n == 1 then
        return groupingAttributes(self, ...)
    else
        return groupingAttributes(self, args)
    end
end

local valueListAttributes = objectMT.valueListAttributes
objectMT.valueListAttributes = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return valueListAttributes(self)
    elseif args.n == 1 then
        return valueListAttributes(self, ...)
    else
        return valueListAttributes(self, args)
    end
end

local sortDescriptors = objectMT.sortDescriptors
objectMT.sortDescriptors = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return sortDescriptors(self)
    elseif args.n == 1 then
        return sortDescriptors(self, ...)
    else
        return sortDescriptors(self, args)
    end
end

objectMT.__index = function(self, key)
    if objectMT[key] then return objectMT[key] end
    if math.type(key) == "integer" and key > 0 and key <= self:resultCount() then
        return self:resultAtIndex(key)
    else
        return nil
    end
end

objectMT.__call = function(self, cmd, ...)
    local currentlyRunning = self:isRunning()
    if table.pack(...).n > 0 then
        self:searchScopes(...):queryString(cmd)
    else
        self:queryString(cmd)
    end
    if not currentlyRunning then self:start() end
    return self
end

objectMT.__pairs = function(self)
    return function(_, k)
              if k == nil then
                  k = 1
              else
                  k = k + 1
              end
              local v = _[k]
              if v == nil then
                  return nil
              else
                  return k, v
              end
           end, self, nil
end

objectMT.__len = function(self)
    return self:resultCount()
end

itemObjMT.__index = function(self, key)
    if itemObjMT[key] then return itemObjMT[key] end
    return self:valueForAttribute(key)
end

itemObjMT.__pairs = function(self)
    local keys = self:attributes()
    return function(_, k)
              k = table.remove(keys)
              if k then
                  return k, self:valueForAttribute(k)
              else
                  return nil
              end
           end, self, nil
end

-- no numeric indexes, so...
-- itemObjMT.__len = function(self) return 0 end

groupObjMT.__index = function(self, key)
    if groupObjMT[key] then return groupObjMT[key] end
    if math.type(key) == "integer" and key > 0 and key <= self:resultCount() then
        return self:resultAtIndex(key)
    else
        return nil
    end
end

groupObjMT.__pairs = function(self)
    return function(_, k)
              if k == nil then
                  k = 1
              else
                  k = k + 1
              end
              local v = _[k]
              if v == nil then
                  return nil
              else
                  return k, v
              end
           end, self, nil
end

groupObjMT.__len = function(self)
    return self:resultCount()
end

-- Return Module Object --------------------------------------------------

return module
