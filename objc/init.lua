--- === hs._asm.objc ===
---
--- Playing with a simplistic lua-objc bridge.
---
--- Very experimental.  Don't use or trust.  Probably forget you ever saw this.
---
--- In fact, burn any computer it has come in contact with.  When (not if) you crash Hammerspoon, it's on your own head.

package.loadlib("/usr/lib/libffi.dylib", "*")

local module       = require("hs._asm.objc.internal")
local log          = require("hs.logger").new("objc","warning")
module.log = log
module.registerLogForC(log)
module.registerLogForC = nil

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

local class         = hs.getObjectMetatable("hs._asm.objc.class")
local object        = hs.getObjectMetatable("hs._asm.objc.id")
local protocol      = hs.getObjectMetatable("hs._asm.objc.protocol")
local selector      = hs.getObjectMetatable("hs._asm.objc.selector")

local sendToSuper   = 1
local allocFirst    = 2

local msgSendWrapper = function(fn, flags)
    return function(self, selector, ...)
        local sel = selector
        if type(selector) == "string" then
            if self._class then
                sel = self:_selector(selector)
            else
                sel = self:selector(selector)
            end
            if not sel then error(selector.." is not a"..(self._class and "n instance" or " class").." method for "..self:_className(), 2) end
        end
        if flags then
            return fn(flags, self, sel, ...)
        else
            return fn(self, sel, ...)
        end
    end
end

-- Public interface ------------------------------------------------------

-- shortcuts for class and object message sending
-- class.msgSend              = msgSendWrapper(module.objc_msgSend)
-- class.msgSendSuper         = msgSendWrapper(module.objc_msgSendSuper)
-- object.msgSend             = msgSendWrapper(module.objc_msgSend)
-- object.msgSendSuper        = msgSendWrapper(module.objc_msgSendSuper)
-- class.allocAndMsgSend      = msgSendWrapper(module.objc_allocAndMsgSend)
-- class.allocAndMsgSendSuper = msgSendWrapper(module.objc_allocAndMsgSendSuper)

class.msgSend              = msgSendWrapper(module.objc_msgSend)
class.msgSendSuper         = msgSendWrapper(module.objc_msgSend, sendToSuper)
object._msgSend            = msgSendWrapper(module.objc_msgSend)
object._msgSendSuper       = msgSendWrapper(module.objc_msgSend, sendToSuper)
class.allocAndMsgSend      = msgSendWrapper(module.objc_msgSend, allocFirst)
class.allocAndMsgSendSuper = msgSendWrapper(module.objc_msgSend, sendToSuper | allocFirst)

class.className = class.name

class.selector = function(self, sel)
    local alreadySeen = {}

    local myClass = self

    while(myClass) do

    -- search class
        if myClass:methodList()[sel] then return myClass:methodList()[sel]:selector() end

    -- search adopted protocols
        for k,v in pairs(myClass:adoptedProtocols()) do
            if not alreadySeen[v] then
                local result = protocol.selector(v, sel, alreadySeen)
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

protocol.selector = function(self, sel, alreadySeen)
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

object._selector = function(self, sel)
    return class.selector(self:_class(), sel)
end

object._propertyList = function(self, includeNSObject)
    -- defaults to false, self *is* NSObject
    includeNSObject = includeNSObject or (self:_className() == "NSObject") or false

    local properties, alreadySeen = {}, {}

    local myClass = self:_class()

    while(myClass) do
    -- search class
        for k, v in pairs(myClass:propertyList()) do
            if not properties[k] then
                properties[k] = v
                log.vf("property: adding %s from class %s", k, myClass:name())
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
                        log.vf("property: adding %s from class %s", k, topProtocol:name())
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
                log.vf("property: adding %s from metaclass %s", k, myClass:metaClass():name())
            end
        end

    -- loop and try superclass
        myClass = myClass:superclass()
        if myClass and myClass:name() == "NSObject" and not includeNSObject then myClass = myClass:superclass() end
    end

    return properties
end

object._propertyValues = function(self, includeNSObject)
    local properties, values = object._propertyList(self, includeNSObject), {}

    for k,v in pairs(properties) do
        local getter = v:attributeList().G or k
        values[k] = self:_msgSend(self:_selector(getter))
    end
    return values
end

object._property = function(self, name)
    local properties = object._propertyList(self, true)

    if properties[name] then
        return self:_msgSend(self:_selector(properties[name]:attributeList().G or name))
    else
        log.wf("%s is not a property for class %s", name, self:_className())
        return nil
    end
end


-- allow unrecognized method calls to be translated into object-c messages for objects
object.__index = function(obj, key)
--     module.nslog("object call to "..tostring(key))
    if object[key] then
        return object[key]
    else
        return function(_, ...) return object._msgSend(_, key, ...) end
    end
end

-- probably overkill, but the Lua Manual section 2.4 (help.lua._man._2_4) suggests that adding to a metatable that already has a __gc method is "a bad thing"(TM)... so we remove the table first and add to it before applying the changed table as the brand new metatable.
-- definitely overkill since module metatables have been removed, but they may need to come back at some point, and its good practice for when I need it in the future, so...

local tempMetatable

tempMetatable = getmetatable(module.class) or {}
module.class = setmetatable(module.class, nil)
tempMetatable["__call"] = function(_, ...) return module.class.fromString(...) end
module.class = setmetatable(module.class, tempMetatable)

tempMetatable = getmetatable(module.protocol) or {}
module.protocol = setmetatable(module.protocol, nil)
tempMetatable["__call"] = function(_, ...) return module.protocol.fromString(...) end
module.protocol = setmetatable(module.protocol, tempMetatable)

tempMetatable = getmetatable(module.selector) or {}
module.selector = setmetatable(module.selector, nil)
tempMetatable["__call"] = function(_, ...) return module.selector.fromString(...) end
module.selector = setmetatable(module.selector, tempMetatable)

tempMetatable = nil

-- Return Module Object --------------------------------------------------

return module
