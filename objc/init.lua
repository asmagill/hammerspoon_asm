-- maybe save some pain, if the shim is installed; otherwise, expect an objc dump to console when this loads on stock Hammerspoon without pull #2308 applied

--- === hs._asm.objc ===
---
--- A minimal and very basic Objective-C bridge for Hammerspoon
---
--- This module provides a way to craft Objective-C messages and create or manipulate native Objective-C objects from within Hammerspoon.  It is very experimental, very limited, and probably not safe for you or your computer.
---
--- This module is not intended to replace a properly written and targeted module coded in Objective-C, or another language.  For one, it will never be as efficient or as fast, since everything is evaluated and crafted at run-time.  This module can however be used as a testing ground and a "proof-of-concept" environment when deciding if a particular module is worth developing.  And there may be the occasional one-off that seems useful, but doesn't quite justify a full module in it's own right.
---
--- Standard disclaimers apply, including but not limited to, do not use this in production, what part of "experimental" didn't you understand?, and I am not responsible for anything this module does or does not do to or for you, your computer, your data, your dog, or anything else.
---
--- If you want safe, then do not use this module.  If you're curious and like to poke at things that might poke back, then I hope that this module can provide you with as much entertainment and amusement, and the occasional insight, as developing it has for me.
---
---
---
--- **Known limitations, unsupported features and data types (for arguments and return values), and things being considered:**
---
---   * Methods with a variable number of arguments (vararg) -- this is not supported by NSInvocation, so is not likely to ever be supported without a substantial (and very non-trivial) re-write.
---   * C style union arguments -- this is not supported by NSInvocation, so is not likely to ever be supported without a substantial (and very non-trivial) re-write.
---   * C style array arguments and return types are not currently supported (NSArray objects as arguments and return types are supported, however).  This is likely to be added for fixed-size array's in the future.
---   * C style bitfields -- if the encoding type of a method signature specifies the flags as bitfields, this is currently not supported.  If the flags are specified as one or more integer types in the encoding, they are.  I have not come across an actual bitfield designation in a method encoding yet; however the specification defined at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html does allow for them.  This will be considered if and when it becomes necessary.
---   * objects and data types referred to by reference (pointer) as arguments or a return type -- except for C style character arrays, which have their own designated encoding type, these are not currently supported.  Where it is possible to determine the pointers destination size and/or type, this may be added (for example, specifying an NSError object by reference in an argument list to a method).  However, where the destination type and/or size cannot be precisely determined, this is likely to never be supported because it would create a very fragile and crash prone environment.
---   * unknown objects (those specified with a type encoding of ?) are not likely to ever be supported for similar reasons to those stated for objects by reference above.
---
---   * Structure support is currently limited to those recognized by LuaSkin (currently a WIP, pull #825) or that can be fully stored as an NSValue with a static objC encoding type and stored in a packed format.  Lua 5.3's `string.pack` appears to recognize most of the type encoding specifiers and the internal storage of this data, so it is likely that a more robust and seamless solution will be added in the near future. Structures with pointers to data not fully contained within the packed data are not likely to ever be supported.
---
--- * Property qualifiers as specified in the Encoding specification provided by Apple at the URL above -- these include specifiers for: const, in, inout, out, bycopy, byref, and oneway.  Currently these are just ignored.
---   * Any value which can be presented as a basic lua data type (boolean, numeric, string, table) is "copied" into the Lua environment -- the value available to Hammerspoon/Lua is a copy of what the value was when it was queried.
---   * Objective-C objects (id instances) are represented in Lua as userdata, and the Objective-C retain count is adjusted indicating that Hammerspoon has a strong reference to the object.  While this has not posed a problem in early testing (except perhaps in the form of memory leaks when an object has lost all references except for the Hammerspoon userdata strong reference), this really should be fixed at some point so that property attributes and qualifiers are honored.
---
---   * Accessing ivar values directly -- currently not supported.  Most instance variables are just the backing for a property and you should access them as property objects or with class getter and setter methods.  Most "best practices" for Objective-C coding generally recommend against using instance variables directly, especially in an ARC environment; however some older frameworks and specific coding situations still use instance variables without the supporting property structures.  Support for direct examination and manipulation of ivar's may be added if a compelling reason occurs -- I just haven't found anything worth examining yet that justifies the testing and troubleshooting!
---
---   * Creating an Objective-C class at run-time with Hammerspoon/Lua as the language/environment of the class methods.  An interesting idea, but not one I have had the time to play with yet.  I don't know if this will be added or not because even if it is feasible to do so, it will still be significantly slower than anything coded directly in Objective-C or Swift.  Still, since this module is for playing around, who knows if the bug will bite hard enough to make a go at it :-]

local USERDATA_TAG = "hs._asm.objc"
local module       = require(USERDATA_TAG..".internal")

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

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

--- hs._asm.objc.class:msgSend(selector, [...]) -> return value
--- Method
--- Sends the specified selector (message) to the class and returns the result, if any.
---
--- Parameters:
---  * selector - a selectorObject or string (message) to send to the class.  If this is a string, the corresponding selector for the class will be looked up for you.
---  * optional additional arguments are passed to the target as arguments for the selector specified.
---
--- Returns:
---  * the results of sending the message to the class, if any.  If an exception occurs during the sending of the message, this method returns nil as the first argument, and a second argument of a table containing the traceback information for the exception.
---
--- Notes:
---  * this method is a convenience wrapper to the [hs._asm.objc.objc_msgSend](#objc_msgSend) function provided for sending a message to a class object.
---
---  * the `__call` metamethods for classObjects and idObjects (an object instance) have been provided as further shortcuts, allowing you to initialize a newly allocated NSObject as:
---    * `hs._asm.objc.class("NSObject")("alloc")("init")`
---
---  * any additional arguments to the selector should be specified as additional arguments, e.g.
---    * `string = hs._asm.objc.class("NSString")("stringWithUTF8String:", "the value of the new NSString")`
---      or
---    * `string = hs._asm.objc.class("NSString")("alloc")("initWithUTF8String:", "the value of the new NSString")`
classMT.msgSend              = msgSendWrapper(module.objc_msgSend)

--- hs._asm.objc.object:allocAndMsgSend(selector, [...]) -> return value
--- Method
--- Allocates an instance of the class and sends the specified selector (message) to the allocated object and returns the result, if any.
---
--- Parameters:
---  * selector - a selectorObject or string (message) to send to the newly allocated object, usually an initializer of some sort.  If this is a string, the corresponding selector for the class will be looked up for you.
---  * optional additional arguments are passed to the target as arguments for the selector specified.
---
--- Returns:
---  * the results of sending the message to the object, if any.  If an exception occurs during the sending of the message, this method returns nil as the first argument, and a second argument of a table containing the traceback information for the exception.
---
--- Notes:
---  * this method is a convenience wrapper to the [hs._asm.objc.objc_msgSend](#objc_msgSend) function provided for sending a message to an object instance.
---
---  * Continuing the example provided in the [hs._asm.objc.objc_msgSend](#objc_msgSend) function of creating a newly initialized NSObject instance, the following additional shortcut is made possible with this method:
---    * `hs._asm.objc.class("NSObject"):allocAndMsgSend("init")`  (`fromString` is optional -- see [hs._asm.objc.class.fromString](#fromString))
classMT.allocAndMsgSend      = msgSendWrapper(module.objc_msgSend, allocFirst)

--- hs._asm.objc.object:msgSend(selector, [...]) -> return value
--- Method
--- Sends the specified selector (message) to the object and returns the result, if any.
---
--- Parameters:
---  * selector - a selector (message) to send to the object.
---  * optional additional arguments are passed to the target as arguments for the selector specified.
---
--- Returns:
---  * the results of sending the message to the object, if any.  If an exception occurs during the sending of the message, this method returns nil as the first argument, and a second argument of a table containing the traceback information for the exception.
---
--- Notes:
---  * this method is a convenience wrapper to the [hs._asm.objc.objc_msgSend](#objc_msgSend) function provided for sending a message to an object instance.
---
---  * the `__call` metamethods for classObjects and idObjects (an object instance) have been provided as further shortcuts, allowing you to initialize a newly allocated NSObject as:
---    * `hs._asm.objc.class("NSObject")("alloc")("init")`
---
---  * any additional arguments to the selector should be specified as additional arguments, e.g.
---    * `string = hs._asm.objc.class("NSString")("stringWithUTF8String:", "the value of the new NSString")`
---      or
---    * `string = hs._asm.objc.class("NSString")("alloc")("initWithUTF8String:", "the value of the new NSString")`
objectMT.msgSend             = msgSendWrapper(module.objc_msgSend)

--- hs._asm.objc.object:msgSendSuper(selector, [...]) -> return value
--- Method
--- Sends the specified selector (message) to the object's superclass and returns the result, if any.
---
--- Parameters:
---  * selector - a selector (message) to send to the object's superclass.
---  * optional additional arguments are passed to the target as arguments for the selector specified.
---
--- Returns:
---  * the results of sending the message to the object, if any.  If an exception occurs during the sending of the message, this method returns nil as the first argument, and a second argument of a table containing the traceback information for the exception.
---
--- Notes:
---  * this method is a convenience wrapper to the [hs._asm.objc.objc_msgSend](#objc_msgSend) function provided for sending a message to an object instance.
objectMT.msgSendSuper        = msgSendWrapper(module.objc_msgSend, sendToSuper)

-- this simplifies the selector validation code below, but doesn't really provide any new interface
-- to the object, so pass on documentation
classMT.className = classMT.name

--- hs._asm.objc.class:selector(string) -> selectorObject
--- Method
--- Returns the selector object with the specified name, if one exists, for the class.
---
--- Parameters:
---  * string - the selector name as a string to look up for the class.
---
--- Returns:
---  * the selectorObject or nil, if no selector with that name exists for the class, its adopted protocols, or one of it's super classes (or their adopted protocols).
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

--- hs._asm.objc.protocol:selector(string) -> selectorObject
--- Method
--- Returns the selector object with the specified name, if one exists, for the protocol.
---
--- Parameters:
---  * string - the selector name as a string to look up for the protocol.
---
--- Returns:
---  * the selectorObject or nil, if no selector with that name exists for the protocol or its adopted protocols (or their adopted protocols).
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

--- hs._asm.objc.object:selector(string) -> selectorObject
--- Method
--- Returns the selector object with the specified name, if one exists, for the object.
---
--- Parameters:
---  * string - the selector name as a string to look up for the object.
---
--- Returns:
---  * the selectorObject or nil, if no selector with that name exists for the object instance, its class's adopted protocols, or one of it's super classes (or their adopted protocols).
objectMT.selector = function(self, sel)
    return classMT.selector(self:class(), sel)
end

--- hs._asm.objc.object:propertyList([includeNSObject]) -> table
--- Method
--- Returns a table containing the properties of the object and their propertyObjects.  Includes all inherited properties from the object's superclass or any adopted protocols of the object's class.
---
--- Parameters:
---  * includesNSObject - an optional boolean, defaulting to false unless the object is an instance of `NSObject`, indicating whether or not the property list should include properties defined for the base NSObject class that almost all objects inherit from.
---
--- Returns:
---  * a table of key-value pairs, where each key represents a property of the object and the value is the propertyObject for the property named in the key.
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

--     -- search metaClass
--         for k,v in pairs(myClass:metaClass():propertyList()) do
--             if not properties[k] then
--                 properties[k] = v
--             end
--         end

    -- loop and try superclass
        myClass = myClass:superclass()
        if myClass and myClass:name() == "NSObject" and not includeNSObject then myClass = myClass:superclass() end
    end

    return properties
end

--- hs._asm.objc.object:propertyValues([includeNSObject]) -> table
--- Method
--- Returns a table containing the properties of the object and the Hammerspoon/Lua representation of their value, if possible.  Includes all inherited properties from the object's superclass or any adopted protocols of the object's class.
---
--- Parameters:
---  * includesNSObject - an optional boolean, defaulting to false unless the object is an instance of `NSObject`, indicating whether or not the property list should include properties defined for the base NSObject class that almost all objects inherit from.
---
--- Returns:
---  * a table of key-value pairs, where each key represents a property of the object and the value is the Hammerspoon/Lua representation of the value, or the Objective-C `debugDescription` for the value if a proper representation is not possible, for the property named in the key.
---
--- Notes:
---  * a property which contains an Objective-C object will actually return the `hs._asm.objc.object` userdata for the object.  You can get it's Hammerspoon/Lua representation, if available, by calling the [hs._asm.objc.object:value](#value) method on the object returned.
objectMT.propertyValues = function(self, includeNSObject)
    local properties, values = objectMT.propertyList(self, includeNSObject), {}

    for k,v in pairs(properties) do
        local getter = v:attributeList().G or k
        values[k] = self:msgSend(self:selector(getter))
    end
    return values
end

--- hs._asm.objc.object:property(propertyName) -> value
--- Method
--- Returns the value of the specified property for the object.
---
--- Parameters:
---  * propertyName - the name of the property to retrieve the Hammerspoon/Lua representation of the value of.
---
--- Returns:
---  * the Hammerspoon/Lua representation of the property specified for the object, or the Objective-C `debugDescription` of the object if a proper representation is not possible.
---
--- Notes:
---  * a property which contains an Objective-C object will actually return the `hs._asm.objc.object` userdata for the object.  You can get it's Hammerspoon/Lua representation, if available, by calling the [hs._asm.objc.object:value](#value) method on the object returned.
objectMT.property = function(self, name)
    local properties = objectMT.propertyList(self, true)

    if properties[name] then
        return self:msgSend(self:selector(properties[name]:attributeList().G or name))
    else
        return nil
    end
end

--- hs._asm.objc.class:classMethodList() -> table
--- Method
--- Returns a table containing the class methods defined for the class.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table of key-value pairs where the key is a string of the method's name (technically the method selector's name) and the value is the methodObject for the specified selector name.
---
--- Notes:
---  * This is syntactic sugar for `hs._asm.objc.class("className"):metaClass():methodList()`.
classMT.classMethodList = function(self, ...) return self:metaClass():methodList() end

--- hs._asm.objc.object:methodList() -> table
--- Method
--- Returns a table containing the methods defined for the object's class.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table of key-value pairs where the key is a string of the method's name (technically the method selector's name) and the value is the methodObject for the specified selector name.
---
--- Notes:
---  * This method returns the instance methods for the object's class and is syntatic sugar for `hs._asm.objc.object:class():methodList()`.
---  * To get a table of the class methods for the object's class, invoke this method on the meta class of the object's class, e.g. `hs._asm.objc.object:class():metaClass():methodList()`.
objectMT.methodList = function(self, ...) return self:class():methodList(...) end

objectMT.__call = function(obj, ...) return objectMT.msgSend(obj, ...) end
classMT.__call  = function(obj, ...) return classMT.msgSend(obj, ...) end

module.class    = setmetatable(module.class,    { __call = function(_, ...) return module.class.fromString(...) end})
module.protocol = setmetatable(module.protocol, { __call = function(_, ...) return module.protocol.fromString(...) end})
module.selector = setmetatable(module.selector, { __call = function(_, ...) return module.selector.fromString(...) end})

-- Return Module Object --------------------------------------------------

return module
