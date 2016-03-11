--- === hs._asm.objc ===
---
--- Playing with a simplistic lua-objc bridge, take two.
---
--- Very experimental.  Don't use or trust.  Probably forget you ever saw this.
---
--- In fact, burn any computer it has come in contact with.  When (not if) you crash Hammerspoon, it's on your own head.

local USERDATA_TAG = "hs._asm.objc"
local module       = require(USERDATA_TAG..".internal")

-- private variables and methods -----------------------------------------

-- local _kMetaTable = {}
-- -- planning to experiment with using this with responses to functional queries... and I
-- -- don't want to keep loose generated data hanging around
-- _kMetaTable._k = setmetatable({}, {__mode = "k"})
-- _kMetaTable._t = setmetatable({}, {__mode = "k"})
-- _kMetaTable.__index = function(obj, key)
--         if _kMetaTable._k[obj] then
--             if _kMetaTable._k[obj][key] then
--                 return _kMetaTable._k[obj][key]
--             else
--                 for k,v in pairs(_kMetaTable._k[obj]) do
--                     if v == key then return k end
--                 end
--             end
--         end
--         return nil
--     end
-- _kMetaTable.__newindex = function(obj, key, value)
--         error("attempt to modify a table of constants",2)
--         return nil
--     end
-- _kMetaTable.__pairs = function(obj) return pairs(_kMetaTable._k[obj]) end
-- _kMetaTable.__len = function(obj) return #_kMetaTable._k[obj] end
-- _kMetaTable.__tostring = function(obj)
--         local result = ""
--         if _kMetaTable._k[obj] then
--             local width = 0
--             for k,v in pairs(_kMetaTable._k[obj]) do width = width < #tostring(k) and #tostring(k) or width end
--             for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
--                 if _kMetaTable._t[obj] == "table" then
--                     result = result..string.format("%-"..tostring(width).."s %s\n", tostring(k),
--                         ((type(v) == "table") and "{ table }" or tostring(v)))
--                 else
--                     result = result..((type(v) == "table") and "{ table }" or tostring(v)).."\n"
--                 end
--             end
--         else
--             result = "constants table missing"
--         end
--         return result
--     end
-- _kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this
--
-- local _makeConstantsTable
-- _makeConstantsTable = function(theTable)
--     if type(theTable) ~= "table" then
--         local dbg = debug.getinfo(2)
--         local msg = dbg.short_src..":_"..dbg.currentline..":_ attempting to make a '"..type(theTable).."' into a constant table"
--         if module.log then module.log.ef(msg) else print(msg) end
--         return theTable
--     end
--     for k,v in pairs(theTable) do
--         if type(v) == "table" then
--             local count = 0
--             for a,b in pairs(v) do count = count + 1 end
--             local results = _makeConstantsTable(v)
--             if #v > 0 and #v == count then
--                 _kMetaTable._t[results] = "array"
--             else
--                 _kMetaTable._t[results] = "table"
--             end
--             theTable[k] = results
--         end
--     end
--     local results = setmetatable({}, _kMetaTable)
--     _kMetaTable._k[results] = theTable
--     local count = 0
--     for a,b in pairs(theTable) do count = count + 1 end
--     if #theTable > 0 and #theTable == count then
--         _kMetaTable._t[results] = "array"
--     else
--         _kMetaTable._t[results] = "table"
--     end
--     return results
-- end

local classMT         = hs.getObjectMetatable(USERDATA_TAG..".class")
local objectMT        = hs.getObjectMetatable(USERDATA_TAG..".id")
local protocolMT      = hs.getObjectMetatable(USERDATA_TAG..".protocol")
local selectorMT      = hs.getObjectMetatable(USERDATA_TAG..".selector")

local sendToSuper   = 1
local allocFirst    = 2

local msgSendWrapper = function(fn, flags)
    return function(self, selector, ...)
        local sel = selector
        if type(selector) == "string" then
            sel = self:selector(selector)
            if not sel then error(selector.." is not a"..(self.class and "n instance" or " class").." method for "..self:className(), 2) end
        end
        if flags then
            return fn(flags, self, sel, ...)
        else
            return fn(self, sel, ...)
        end
    end
end

-- Public interface ------------------------------------------------------

classMT.msgSend              = msgSendWrapper(module.objc_msgSend)
classMT.msgSendSuper         = msgSendWrapper(module.objc_msgSend, sendToSuper)
objectMT.msgSend             = msgSendWrapper(module.objc_msgSend)
objectMT.msgSendSuper        = msgSendWrapper(module.objc_msgSend, sendToSuper)
classMT.allocAndMsgSend      = msgSendWrapper(module.objc_msgSend, allocFirst)
classMT.allocAndMsgSendSuper = msgSendWrapper(module.objc_msgSend, sendToSuper | allocFirst)

classMT.className = classMT.name

classMT.selector = function(self, sel)
    local alreadySeen = {}

    local myClass = self

    while(myClass) do

    -- search class
        if myClass:methodList()[sel] then return myClass:methodList()[sel]:selector() end

    -- search adopted protocols
        for k,v in pairs(myClass:adoptedProtocols()) do
            if not alreadySeen[v] then
                local result = protocolMT.selector(v, sel, alreadySeen)
                if result then return result end
                alreadySeen[v] = true
            end
        end

    -- search metaClass
        if myClass:metaClass():methodList()[sel] then return myClass:metaClass():methodList()[sel]:selector() end

    -- loop and try superclass
        myClass = myClass:superclass()
    end
    return nil
end

protocolMT.selector = function(self, sel, alreadySeen)
    local alreadySeen = alreadySeen or {}
    if alreadySeen[self] then return nil end

    -- build initial protocol search list with ourself
    local protocolList = { self }

    local topProtocol = table.remove(protocolList, 1)
    while (topProtocol) do
        if not alreadySeen[topProtocol] then
            alreadySeen[topProtocol] = true

    -- check to see if selector defined for this protocol
            local entry = topProtocol:methodDescriptionList(true,true)[sel]  or -- check required and instance methods
                          topProtocol:methodDescriptionList(false,true)[sel] or -- check not-required and instance methods
                          topProtocol:methodDescriptionList(true,false)[sel] or -- check required and class methods
                          topProtocol:methodDescriptionList(false,false)[sel]   -- check not-required and class methods
            if entry then return entry.selector end

    -- add current protocols adoptees to the list
            for _, v in pairs(topProtocol:adoptedProtocols()) do
                if not alreadySeen[v] then table.insert(protocolList, v) end
            end
        end

    -- loop through unchecked protocols in the list
        topProtocol = table.remove(protocolList, 1)
    end

    return nil
end

objectMT.selector = function(self, sel)
    return classMT.selector(self:class(), sel)
end

objectMT.propertyList = function(self, includeNSObject)
    -- defaults to false, self *is* NSObject
    includeNSObject = includeNSObject or (self:className() == "NSObject") or false

    local properties, alreadySeen = {}, {}

    local myClass = self:class()

    while(myClass) do
    -- search class
        for k, v in pairs(myClass:propertyList()) do
            if not properties[k] then
                properties[k] = v
            end
        end

    -- search protocols we adopt
        local protocolList = {}
        for _, v in pairs(myClass:adoptedProtocols()) do
            if not alreadySeen[v] then table.insert(protocolList, v) end
        end
        local topProtocol = table.remove(protocolList, 1)
        while (topProtocol) do
            if not alreadySeen[topProtocol] then
                alreadySeen[topProtocol] = true
                for k, v in pairs(topProtocol:propertyList()) do
                    if not properties[k] then
                        properties[k] = v
                    end
                end
                for _, v in pairs(topProtocol:adoptedProtocols()) do
                    if not alreadySeen[v] then table.insert(protocolList, v) end
                end
            end
            topProtocol = table.remove(protocolList, 1)
        end

    -- search metaClass
        for k,v in pairs(myClass:metaClass():propertyList()) do
            if not properties[k] then
                properties[k] = v
            end
        end

    -- loop and try superclass
        myClass = myClass:superclass()
        if myClass and myClass:name() == "NSObject" and not includeNSObject then myClass = myClass:superclass() end
    end

    return properties
end

objectMT.propertyValues = function(self, includeNSObject)
    local properties, values = objectMT.propertyList(self, includeNSObject), {}

    for k,v in pairs(properties) do
        local getter = v:attributeList().G or k
        values[k] = self:msgSend(self:selector(getter))
    end
    return values
end

objectMT.property = function(self, name)
    local properties = objectMT.propertyList(self, true)

    if properties[name] then
        return self:msgSend(self:selector(properties[name]:attributeList().G or name))
    else
        return nil
    end
end

objectMT.__call = function(obj, ...) return objectMT.msgSend(obj, ...) end
classMT.__call  = function(obj, ...) return classMT.msgSend(obj, ...) end

module.class    = setmetatable(module.class,    { __call = function(_, ...) return module.class.fromString(...) end})
module.protocol = setmetatable(module.protocol, { __call = function(_, ...) return module.protocol.fromString(...) end})
module.selector = setmetatable(module.selector, { __call = function(_, ...) return module.selector.fromString(...) end})

-- Return Module Object --------------------------------------------------

return module
