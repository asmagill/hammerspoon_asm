--- === hs._asm.objc ===
---
--- A minimal and very basic Objective-C bridge for Hammerspoon
---
--- This module provides a way to craft Objective-C messages and create or manipulate native Objective-C objects from within Hammerspoon.  It is very experimental, very limited, and probably not safe for you or your computer.
---
--- Standard disclaimers apply, including but not limited to, do not use this in production, what part of "experimental" didn't you understand?, and I am not responsible for anything this module does or does not do to or for you, your computer, your data, your dog, or anything else.
---
--- If you want safe, then do not use this module.  If you're curious and like to poke at things that might poke back, then I hope that this module can provide you with as much entertainment and amusement, and the occasional insight, as developing it has for me.

local USERDATA_TAG = "hs._asm.objc"
local module       = require(USERDATA_TAG..".internal")

-- private variables and methods -----------------------------------------

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
