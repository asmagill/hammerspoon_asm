local USERDATA_TAG = "hs._asm.enclosure.canvas"
local module       = require(USERDATA_TAG..".internal")
module.matrix      = require(USERDATA_TAG..".matrix")

-- include these so that their support functions are available to us
require("hs.image")
require("hs.styledtext")

local canvasMT = hs.getObjectMetatable(USERDATA_TAG)

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

module.compositeTypes  = _makeConstantsTable(module.compositeTypes)

canvasMT.appendElements = function(obj, ...)
    local elementsArray = table.pack(...)
    if elementsArray.n == 1 and #elementsArray[1] ~= 0 then elementsArray = elementsArray[1] end
    for i,v in ipairs(elementsArray) do obj:insertElement(v) end
    return obj
end

canvasMT.replaceElements = function(obj,  ...)
    local elementsArray = table.pack(...)
    if elementsArray.n == 1 and #elementsArray[1] ~= 0 then elementsArray = elementsArray[1] end
    for i,v in ipairs(elementsArray) do obj:assignElement(v, i) end
    while (#obj > #elementArray) do obj:removeElement() end
    return obj
end

canvasMT.rotateElement = function(obj, index, angle, point, append)
    if type(point) == "boolean" then
        append, point = point, nil
    end
    if not point then
        local bounds = obj:elementBounds(index)
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

canvasMT.copy = function(obj)
    local newObj = module.new(obj:frame()):alpha(obj:alpha())
                                 :behavior(obj:behavior())
                                 :canvasMouseEvents(obj:canvasMouseEvents())
                                 :clickActivating(obj:clickActivating())
                                 :level(obj:level())
                                 :transformation(obj:transformation())
                                 :wantsLayer(obj:wantsLayer())
    for i, v in ipairs(obj:canvasDefaultKeys()) do
      newObj:canvasDefaultFor(v, obj:canvasDefaultFor(v))
    end

    for i = 1, #obj, 1 do
      for i2, v2 in ipairs(obj:elementKeys(i)) do
          local value = obj:elementAttribute(i, v2)
          if v2 ~= "view" then
              newObj:elementAttribute(i, v2, value)
          else
              if getmetatable(value).copy then
                  newObj:elementAttribute(i, v2, value:copy())
              else
                  print(string.format("-- no copy method exists for %s object at index %d", tostring(value), i))
              end
          end
      end
    end
    return newObj
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

local help_table
help_table = function(depth, value)
    local result = "{\n"
    for k,v in require("hs.fnutils").sortByKeys(value) do
        if not ({class = 1, objCType = 1, memberClass = 1})[k] then
            local displayValue = v
            if type(v) == "table" then
                displayValue = help_table(depth + 2, v)
            elseif type(v) == "string" then
                displayValue = "\"" .. v .. "\""
            end
            local displayKey = k
            if type(k) == "number" then
                displayKey = "[" .. tostring(k) .. "]"
            end
            result = result .. string.rep(" ", depth + 2) .. string.format("%s = %s,\n", tostring(displayKey), tostring(displayValue))
        end
    end
    result = result .. string.rep(" ", depth) .. "}"
    return result
end

module.help = function(what)
    local help = module.elementSpec()
    if what and help[what] then what, help = nil, help[what] end
    if type(what) ~= "nil" then
        error("unrecognized argument `" .. tostring(what) .. "`", 2)
    end
    print(help_table(0, help))
end

-- Return Module Object --------------------------------------------------

return module
