hs._asm.objc
============

A minimal and very basic Objective-C bridge for Hammerspoon

This module provides a way to craft Objective-C messages and create or manipulate native Objective-C objects from within Hammerspoon.  It is very experimental, very limited, and probably not safe for you or your computer.

This module is not intended to replace a properly written and targeted module coded in Objective-C, or another language.  For one, it will never be as efficient or as fast, since everything is evaluated and crafted at run-time.  This module can however be used as a testing ground and a "proof-of-concept" environment when deciding if a particular module is worth developing.  And there may be the occasional one-off that seems useful, but doesn't quite justify a full module in it's own right.

Standard disclaimers apply, including but not limited to, do not use this in production, what part of "experimental" didn't you understand?, and I am not responsible for anything this module does or does not do to or for you, your computer, your data, your dog, or anything else.

If you want safe, then do not use this module.  If you're curious and like to poke at things that might poke back, then I hope that this module can provide you with as much entertainment and amusement, and the occasional insight, as developing it has for me.

You probably want to look at [some examples](EXAMPLES.md), but come back here for reference and to really understand what this module can and cannot do.

**Known limitations, unsupported features/data-types (for arguments and return values), and things being considered:**

  * Methods with a variable number of arguments (vararg) -- this is not supported by NSInvocation, so is not likely to ever be supported without a substantial (and very non-trivial) re-write.
  * C style union arguments -- this is not supported by NSInvocation, so is not likely to ever be supported without a substantial (and very non-trivial) re-write.
  * C style array arguments and return types are not currently supported (NSArray objects as arguments and return types are supported, however).  This is likely to be added for fixed-size array's in the future.
  * C style bitfields -- if the encoding type of a method signature specifies the flags as bitfields, this is currently not supported.  If the flags are specified as one or more integer types in the encoding, they are.  I have not come across an actual bitfield designation in a method encoding yet; however the specification defined at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html does allow for them.  This will be considered if and when it becomes necessary.
  * objects and data types referred to by reference (pointer) as arguments or a return type -- except for C style character arrays, which have their own designated encoding type, these are not currently supported.  Where it is possible to determine the pointers destination size and/or type, this may be added (for example, specifying an NSError object by reference in an argument list to a method).  However, where the destination type and/or size cannot be precisely determined, this is likely to never be supported because it would create a very fragile and crash prone environment.
  * unknown objects (those specified with a type encoding of ?) are not likely to ever be supported for similar reasons to those stated for objects by reference above.

  * Structure support is currently limited to those recognized by LuaSkin (currently a WIP, pull #825) or that can be fully stored as an NSValue with a static objC encoding type and stored in a packed format.  Lua 5.3's `string.pack` appears to recognize most of the type encoding specifiers and the internal storage of this data, so it is likely that a more robust and seamless solution will be added in the near future. Structures with pointers to data not fully contained within the packed data are not likely to ever be supported.

* Property qualifiers as specified in the Encoding specification provided by Apple at the URL above -- these include specifiers for: const, in, inout, out, bycopy, byref, and oneway.  Currently these are just ignored.
  * Any value which can be presented as a basic lua data type (boolean, numeric, string, table) is "copied" into the Lua environment -- the value available to Hammerspoon/Lua is a copy of what the value was when it was queried.
  * Objective-C objects (id instances) are represented in Lua as userdata, and the Objective-C retain count is adjusted indicating that Hammerspoon has a strong reference to the object.  While this has not posed a problem in early testing (except perhaps in the form of memory leaks when an object has lost all references except for the Hammerspoon userdata strong reference), this really should be fixed at some point so that property attributes and qualifiers are honored.

* Accessing ivar values directly -- currently not supported.  Most instance variables are just the backing for a property and you should access them as property objects or with class getter and setter methods.  Most "best practices" for Objective-C coding generally recommend against using instance variables directly, especially in an ARC environment; however some older frameworks and specific coding situations still use instance variables without the supporting property structures.  Support for direct examination and manipulation of ivar's may be added if a compelling reason occurs -- I just haven't found anything worth examining yet that justifies the testing and troubleshooting!

* Creating an Objective-C class at run-time with Hammerspoon/Lua as the language/environment of the class methods.  An interesting idea, but not one I have had the time to play with yet.  I don't know if this will be added or not because even if it is feasible to do so, it will still be significantly slower than anything coded directly in Objective-C or Swift.  Still, since this module is for playing around, who knows if the bug will bite hard enough to make a go at it :-]


### Installation

A precompiled version of this module can be found in this directory with a name along the lines of `objc-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/objc-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything else) is to download `init.lua`, `internal.m`, `class.m`, `ivar.m`, `method.m`, `object.m`, `property.m`, `protocol.m`, `selector.m`, `obj.h` and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make docs install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make docs install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

### Usage
~~~lua
objc = require("hs._asm.objc")
~~~

### Contents


##### Module Functions
* <a href="#classNamesForImage">objc.classNamesForImage(imageName) -> table</a>
* <a href="#imageNames">objc.imageNames() -> table</a>
* <a href="#objc_msgSend">objc.objc_msgSend([flags], target, selector, ...) -> result</a>

- - -

### Module Functions

<a name="classNamesForImage"></a>
~~~lua
objc.classNamesForImage(imageName) -> table
~~~
Returns a list of the classes within the specified library or framework.

Parameters:
 * imageName - the full path of the library or framework image to return the list of classes from.

Returns:
 * an array of the class names defined within the specified image.

Notes:
 * You can load a framework which is not currently loaded by using the lua builtin `package.loadlib`.  E.g. `package.loadlib("/System/Library/Frameworks/MapKit.framework/Versions/Current/MapKit","*")`
 * the `imageName` must match the actual path (without symbolic links) that was loaded.  For the example given above, the proper path name (as of OS X 10.11.3) would be "/System/Library/Frameworks/MapKit.framework/Versions/A/MapKit".  You can determine this path by looking at the results from [hs._asm.objc.imageNames](#imageNames).

- - -

<a name="imageNames"></a>
~~~lua
objc.imageNames() -> table
~~~
Returns a list of the names of all the loaded Objective-C frameworks and dynamic libraries.

Parameters:
 * None

Returns:
 * an array of the currently loaded frameworks and dynamic libraries.  Each entry is the complete path to the framework or library.

Notes:
 * You can load a framework which is not currently loaded by using the lua builtin `package.loadlib`.  E.g. `package.loadlib("/System/Library/Frameworks/MapKit.framework/Versions/Current/MapKit","*")`

- - -

<a name="objc_msgSend"></a>
~~~lua
objc.objc_msgSend([flags], target, selector, ...) -> result
~~~
The core Objective-C message sending interface.  There are a variety of method wrappers described elsewhere which are probably more clear in context, but they all reduce down to this function.

Parameters:
 * flags    - an optional integer used as a bit flag to alter the message being sent:
   * 0x01 - if bit 1 is set, the message should actually be sent to the class or object's superclass.  This is equivalent to `[[target super] selector]`
   * 0x02 - if bit 2 is set, and the `target` is a class, then the selector is sent to `[target alloc]` and the result is returned.  This is a shorthand for allocating and initializing an object at the same time.
 * target   - a class object or an object instance to which the message should be sent.
 * selector - a selector (message) to send to the target.
 * optional additional arguments are passed to the target as arguments for the selector specified.

Returns:
 * the result (if any) of the message sent.  If an exception occurs during the sending of the message, this function returns nil as the first argument, and a second argument of a table containing the traceback information for the exception.

Notes:
 * In general, it will probably be clearer in most contexts to use one of the wrapper methods to this function.  They are described in the appropriate places in the [hs._asm.objc.class](#class) and [hs._asm.objc.object](#object) sections of this documentation.

 * The following example shows the most basic form for sending the messages necessary to create a newly initialized NSObject.
 * In it's most raw form, a newly initialized NSObject is created as follows:
   *
   ~~~lua
     hs._asm.objc.objc_msgSend(
         hs._asm.objc.objc_msgSend(
             hs._asm.objc.class.fromString("NSObject"),
             hs._asm.objc.selector.fromString("alloc")
         ), hs._asm.objc.selector.fromString("init")
     )
   ~~~

 * Using the optional bit-flag, this can be shortened to:
   *
   ~~~lua
     hs._asm.objc.objc_msgSend(0x02,
         hs._asm.objc.class.fromString("NSObject"),
         hs._asm.objc.selector.fromString("init")
     )
   ~~~

 * Note that `.fromString` is optional for the [hs._asm.objc.class.fromString](#fromString) and [hs._asm.objc.selector.fromString](#fromString3) functions as described in the documentation for each -- they are provided here for completeness and clarity of exactly what is being done.
 * Even shorter variants are possible and will be documented where appropriate.

 * Note that an alloc'd but not initialized object is generally an unsafe object to access in any fashion -- it is why almost every programming guide for Objective-C tells you to **always** combine the two into one statement.  This is for two very important reasons that also apply when using this module:
   * allocating an object just sets aside the memory for the object -- it does not set any defaults and there is no way of telling what may be in the memory space provided... at best garbage; more likely something that will crash your program if you try to examine or use it assuming that it conforms to the object class or it's properties.
   * the `init` method does not always return the same object that the message was passed to.  If you do the equivalent of the following: `a = [someClass alloc] ; [a init] ;`, you cannot be certain that `a` is the initialized object.  Only by performing the equivalent of `a = [[someClass alloc] init]` can you be certain of what `a` contains.
   * some classes with an initializer that takes no arguments (e.g. NSObject) provide `new` as a shortcut: `a = [someClass new]` as the equivalent to `a = [[someClass alloc] init]`.  I'm not sure why this seems to be unpopular in some circles, though.
   * other classes provide their own shortcuts (e.g. NSString allows `a = [NSString stringWithUTF8String:"c-string"]` as a shortcut for `a = [[NSString alloc] initWithUTF8String:"c-string"]`).
 * Whatever style you use, make sure that you're working with a properly allocated **AND** initialized object; otherwise you're gonna get an earth-shattering kaboom.

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.objc.class
==================

The submodule for hs._asm.objc which provides methods for working with and examining Objective-C classes.

### Usage
~~~lua
class = require("hs._asm.objc").class
~~~

### Contents


##### Module Constructors
* <a href="#fromString">class.fromString(name) -> classObject</a>
* <a href="#list">class.list() -> table</a>

##### Module Methods
* <a href="#adoptedProtocols">class:adoptedProtocols() -> table</a>
* <a href="#classMethod">class:classMethod(selector) -> methodObject</a>
* <a href="#classMethodList">class:classMethodList() -> table</a>
* <a href="#conformsToProtocol">class:conformsToProtocol(protocol) -> boolean</a>
* <a href="#imageName">class:imageName() -> string</a>
* <a href="#instanceMethod">class:instanceMethod(selector) -> methodObject</a>
* <a href="#instanceSize">class:instanceSize() -> bytes</a>
* <a href="#instanceVariable">class:instanceVariable(name) -> ivarObject</a>
* <a href="#isMetaClass">class:isMetaClass() -> boolean</a>
* <a href="#ivarLayout">class:ivarLayout() -> string | nil</a>
* <a href="#ivarList">class:ivarList() -> table</a>
* <a href="#metaClass">class:metaClass() -> classObject</a>
* <a href="#methodList">class:methodList() -> table</a>
* <a href="#msgSend">class:msgSend(selector, [...]) -> return value</a>
* <a href="#name">class:name() -> string</a>
* <a href="#property">class:property(name) -> propertyObject</a>
* <a href="#propertyList">class:propertyList() -> table</a>
* <a href="#respondsToSelector">class:respondsToSelector(selector) -> boolean</a>
* <a href="#selector">class:selector(string) -> selectorObject</a>
* <a href="#signatureForMethod">class:signatureForMethod(selector) -> table</a>
* <a href="#superclass">class:superclass() -> classObject</a>
* <a href="#version">class:version() -> integer</a>
* <a href="#weakIvarLayout">class:weakIvarLayout() -> string | nil</a>

- - -

### Module Constructors

<a name="fromString"></a>
~~~lua
class.fromString(name) -> classObject
~~~
Returns a class object for the named class

Parameters:
 * name - a string containing the name of the desired class

Returns:
 * the class object for the name specified or nil if a class with the specified name does not exist

Notes:
 * This constructor has also been assigned to the __call metamethod of the `hs._asm.objc.class` sub-module so that it can be invoked as `hs._asm.objc.class(name)` as a shortcut.

- - -

<a name="list"></a>
~~~lua
class.list() -> table
~~~
Returns a list of all currently available classes

Parameters:
 * None

Returns:
 * a table of all currently available classes as key-value pairs.  The key is the class name as a string and the value for each key is the classObject for the named class.

### Module Methods

<a name="adoptedProtocols"></a>
~~~lua
class:adoptedProtocols() -> table
~~~
Returns a table of the protocols adopted by this class.

Parameters:
 * None

Returns:
 * a table of key-value pairs in which each key is a string containing the name of a protocol adopted by this class and the value is the protocolObject for the named protocol

- - -

<a name="classMethod"></a>
~~~lua
class:classMethod(selector) -> methodObject
~~~
Returns the methodObject for the specified selector, if the class supports it as a class method.

Parameters:
 * selector - the selectorObject to get the methodObject for

Returns:
 * the methodObject, if the selector represents a class method of the class, otherwise nil.

Notes:
 * see also [hs._asm.objc.class:instanceMethod](#instanceMethod)

- - -

<a name="classMethodList"></a>
~~~lua
class:classMethodList() -> table
~~~
Returns a table containing the class methods defined for the class.

Parameters:
 * None

Returns:
 * a table of key-value pairs where the key is a string of the method's name (technically the method selector's name) and the value is the methodObject for the specified selector name.

Notes:
 * This is syntactic sugar for `hs._asm.objc.class("className"):metaClass():methodList()`.

- - -

<a name="conformsToProtocol"></a>
~~~lua
class:conformsToProtocol(protocol) -> boolean
~~~
Returns true or false indicating whether the class conforms to the specified protocol or not.

Parameters:
 * protocol - the protocolObject of the protocol to test for class conformity

Returns:
 * true, if the class conforms to the specified protocol, otherwise false

- - -

<a name="imageName"></a>
~~~lua
class:imageName() -> string
~~~
The path to the framework or library which defines the class.

Parameters:
 * None

Returns:
 * a string containing the path to the library or framework which defines the class.

- - -

<a name="instanceMethod"></a>
~~~lua
class:instanceMethod(selector) -> methodObject
~~~
Returns the methodObject for the specified selector, if the class supports it as an instance method.

Parameters:
 * selector - the selectorObject to get the methodObject for

Returns:
 * the methodObject, if the selector represents an instance method of the class, otherwise nil.

Notes:
 * see also [hs._asm.objc.class:classMethod](#classMethod)

- - -

<a name="instanceSize"></a>
~~~lua
class:instanceSize() -> bytes
~~~
Returns the size in bytes on an instance of the class.

Parameters:
 * None

Returns:
 * the size in bytes on an instance of the class

Notes:
 * this is provided for informational purposes only.  At present, there are no methods or plans for methods allowing direct access to the class internal memory structures.

- - -

<a name="instanceVariable"></a>
~~~lua
class:instanceVariable(name) -> ivarObject
~~~
Returns the ivarObject for the specified instance variable of the class

Parameters:
 * name - a string containing the name of the instance variable to return for the class

Returns:
 * the ivarObject for the specified instance variable named.

- - -

<a name="isMetaClass"></a>
~~~lua
class:isMetaClass() -> boolean
~~~
Returns a boolean specifying whether or not the classObject refers to a meta class.

Parameters:
 * None

Returns:
 * true, if the classObject is a meta class, otherwise false.

Notes:
 * A meta-class is basically the class an Objective-C Class object belongs to.  For most purposes outside of creating a class at runtime, the only real importance of a meta class is that it contains information about the class methods, as opposed to the instance methods, of the class.

- - -

<a name="ivarLayout"></a>
~~~lua
class:ivarLayout() -> string | nil
~~~
Returns a description of the Ivar layout for the class.

Parameters:
 * None

Returns:
 * a string specifying the ivar layout for the class

Notes:
 * this is provided for informational purposes only.  At present, there are no methods or plans for methods allowing direct access to the class internal memory structures.

- - -

<a name="ivarList"></a>
~~~lua
class:ivarList() -> table
~~~
Returns a table containing the instance variables for the class

Parameters:
 * None

Returns:
 * a table of key-value pairs in which the key is a string containing the name of an instance variable of the class and the value is the ivarObject for the specified instance variable.

- - -

<a name="metaClass"></a>
~~~lua
class:metaClass() -> classObject
~~~
Returns the metaclass definition of a specified class.

Parameters:
 * None

Returns:
 * the classObject for the metaClass of the class

Notes:
 * Most of the time, you want the class object itself instead of the Meta class.  However, the meta class is useful when you need to work specifically with class methods as opposed to instance methods of the class.

- - -

<a name="methodList"></a>
~~~lua
class:methodList() -> table
~~~
Returns a table containing the methods defined for the class.

Parameters:
 * None

Returns:
 * a table of key-value pairs where the key is a string of the method's name (technically the method selector's name) and the value is the methodObject for the specified selector name.

Notes:
 * This method returns the instance methods for the class.  To get a table of the class methods for the class, invoke this method on the meta class of the class, e.g. `hs._asm.objc.class("className"):metaClass():methodList()`.

- - -

<a name="msgSend"></a>
~~~lua
class:msgSend(selector, [...]) -> return value
~~~
Sends the specified selector (message) to the class and returns the result, if any.

Parameters:
 * selector - a selectorObject or string (message) to send to the class.  If this is a string, the corresponding selector for the class will be looked up for you.
 * optional additional arguments are passed to the target as arguments for the selector specified.

Returns:
 * the results of sending the message to the class, if any.  If an exception occurs during the sending of the message, this method returns nil as the first argument, and a second argument of a table containing the traceback information for the exception.

Notes:
 * this method is a convenience wrapper to the [hs._asm.objc.objc_msgSend](#objc_msgSend) function provided for sending a message to a class object.

 * the `__call` metamethods for classObjects and idObjects (an object instance) have been provided as further shortcuts, allowing you to initialize a newly allocated NSObject as:
   * `hs._asm.objc.class("NSObject")("alloc")("init")`

 * any additional arguments to the selector should be specified as additional arguments, e.g.
   * `string = hs._asm.objc.class("NSString")("stringWithUTF8String:", "the value of the new NSString")`
     or
   * `string = hs._asm.objc.class("NSString")("alloc")("initWithUTF8String:", "the value of the new NSString")`

- - -

<a name="name"></a>
~~~lua
class:name() -> string
~~~
Returns the name of the class as a string

Parameters:
 * None

Returns:
 * the class name as a string

- - -

<a name="property"></a>
~~~lua
class:property(name) -> propertyObject
~~~
Returns the propertyObject for the specified property of the class

Parameters:
 * name - a string containing the name of the property

Returns:
 * the propertyObject for the named property

- - -

<a name="propertyList"></a>
~~~lua
class:propertyList() -> table
~~~
Returns a table containing the properties defined for the class

Parameters:
 * None

Returns:
 * a table of key-value pairs in which each key is a string of a property name provided by the class and the value is the propertyObject for the named property.

- - -

<a name="respondsToSelector"></a>
~~~lua
class:respondsToSelector(selector) -> boolean
~~~
Returns true if the class responds to the specified selector, otherwise false.

Parameters:
 * selector - the selectorObject to check for in the class

Returns:
 * true, if the selector is recognized by the class, otherwise false

Notes:
 * this method will determine if the class recognizes the selector as an instance method of the class.  To check to see if it recognizes the selector as a class method, use this method on the class meta class, e.g. `hs._asm.objc.class("className"):metaClass():responseToSelector(selector)`.

- - -

<a name="selector"></a>
~~~lua
class:selector(string) -> selectorObject
~~~
Returns the selector object with the specified name, if one exists, for the class.

Parameters:
 * string - the selector name as a string to look up for the class.

Returns:
 * the selectorObject or nil, if no selector with that name exists for the class, its adopted protocols, or one of it's super classes (or their adopted protocols).

- - -

<a name="signatureForMethod"></a>
~~~lua
class:signatureForMethod(selector) -> table
~~~
Returns the method signature for the specified selector of the class.

Paramters:
 * selector - a selectorObject specifying the selector to get the method signature for

Returns:
 * a table containing the method signature for the specified selector.  The table will contain the following keys:
   * arguments          - A table containing an array of encoding types for each argument, including the target and selector, required when invoking this method.
   * frameLength        - The number of bytes that the arguments, taken together, occupy on the stack.
   * methodReturnLength - The number of bytes required for the return value
   * methodReturnType   - string encoding the return type of the method in Objective-C type encoding
   * numberOfArguments  - The number of arguments, including the target (object) and selector, required when invoking this method

Notes:
 * this method returns the signature of an instance method of the class.  To determine the signature for a class method of the class, use this method on the class meta class, e.g.  `hs._asm.objc.class("className"):metaClass():signatureForMethod(selector)`.
 * Method signatures are

- - -

<a name="superclass"></a>
~~~lua
class:superclass() -> classObject
~~~
Returns the superclass classObject for the class

Parameters:
 * None

Returns:
 * the classObject for the superclass of the class

- - -

<a name="version"></a>
~~~lua
class:version() -> integer
~~~
Returns the version number of the class definition

Parameters:
 * None

Returns:
 * the version number of the class definition

Notes:
 * This is provided for informational purposes only.  While the version number does provide a method for identifying changes which might affect whether or not your code can use a given class, it is usually better to verify that the support you require is available with `respondsToSelector` and such since most use cases do not care about internal or instance variable layout changes.

- - -

<a name="weakIvarLayout"></a>
~~~lua
class:weakIvarLayout() -> string | nil
~~~
Returns a description of the layout of the weak Ivar's for the class.

Parameters:
 * None

Returns:
 * a string specifying the ivar layout for the class

Notes:
 * this is provided for informational purposes only.  At present, there are no methods or plans for methods allowing direct access to the class internal memory structures.

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.objc.ivar
=================

The submodule for hs._asm.objc which provides methods for working with and examining Objective-C object instance variables.

Except in rare cases, instance variables back properties and should generally be accessed only as properties or with the getter and setter methods provided.  This module is provided for informational purposes only.

### Usage
~~~lua
ivar = require("hs._asm.objc").ivar
~~~

### Contents


##### Module Methods
* <a href="#name">ivar:name() -> string</a>
* <a href="#offset">ivar:offset() -> integer</a>
* <a href="#typeEncoding">ivar:typeEncoding() -> string</a>

- - -

### Module Methods

<a name="name"></a>
~~~lua
ivar:name() -> string
~~~
Returns the name of an instance variable.

Parameters:
 * None

Returns:
 * the name of the instance variable

- - -

<a name="offset"></a>
~~~lua
ivar:offset() -> integer
~~~
Returns the offset of an instance variable.

Parameters:
 * None

Returns:
 * the offset of an instance variable.

- - -

<a name="typeEncoding"></a>
~~~lua
ivar:typeEncoding() -> string
~~~
Returns the type string of an instance variable.

Parameters:
 * None

Returns:
 * the instance variable's type encoding

Notes:
 * Type encoding strings are encoded as described at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.objc.method
===================

The submodule for hs._asm.objc which provides methods for working with and examining Objective-C class and protocol methods.

The terms `selector` and `method` are often used interchangeably in this documentation and in many books and tutorials about Objective-C.  Strictly speaking this is lazy; for most purposes, I find that the easiest way to think of them is as follows: A selector is the name or label for a method, and a method is the actual implementation or function (code) for a selector.  Usually the specific intention is clear from context, but I hope to clean up this documentation to be more precise as time allows.

### Usage
~~~lua
method = require("hs._asm.objc").method
~~~

### Contents


##### Module Methods
* <a href="#argumentType">method:argumentType(index) -> string | nil</a>
* <a href="#description">method:description() -> table</a>
* <a href="#numberOfArguments">method:numberOfArguments() -> integer</a>
* <a href="#returnType">method:returnType() -> string</a>
* <a href="#selector2">method:selector() -> selectorObject</a>
* <a href="#typeEncoding">method:typeEncoding() -> string</a>

- - -

### Module Methods

<a name="argumentType"></a>
~~~lua
method:argumentType(index) -> string | nil
~~~
Returns a string describing a single parameter type of a method.

Parameters:
 * index - the index of the parameter in the method to return the type for.  Note that the index starts at 0, and all methods have 2 internal arguments at index positions 0 and 1: The object or class receiving the message, and the selector representing the message being sent.

Returns:
 * the type for the parameter specified, or nil if there is no parameter at the specified index.

Notes:
 * Encoding types are described at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html

- - -

<a name="description"></a>
~~~lua
method:description() -> table
~~~
Returns a table containing the selector for this method and the type encoding for the method.

Parameters:
 * None

Returns:
 * a table with two keys: `selector`, whose value is the selector for this method, and `types` whose value contains the type encoding for the method.

Notes:
 * Encoding types are described at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html

 * See also the notes for [hs._asm.objc.method:typeEncoding](#typeEncoding) concerning the type encoding value returned by this method.

- - -

<a name="numberOfArguments"></a>
~~~lua
method:numberOfArguments() -> integer
~~~
Returns the number of arguments accepted by a method.

Parameters:
 * None

Returns:
 * the number of arguments accepted by the method.  Note that all methods have two internal arguments: the object or class receiving the message, and the selector representing the message being sent.  A method which takes additional user provided arguments will return a number greater than 2 for this method.

Notes:
 * Note that all methods have two internal arguments: the object or class receiving the message, and the selector representing the message being sent.  A method which takes additional user provided arguments will return a number greater than 2 for this method.

- - -

<a name="returnType"></a>
~~~lua
method:returnType() -> string
~~~
Returns a string describing a method's return type.

Parameters:
 * None

Returns:
 * the return type as a string for the method.

Notes:
 * Encoding types are described at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html

- - -

<a name="selector2"></a>
~~~lua
method:selector() -> selectorObject
~~~
Returns the selector for the method

Parameters:
 * None

Returns:
 * the selectorObject for the method

- - -

<a name="typeEncoding"></a>
~~~lua
method:typeEncoding() -> string
~~~
Returns a string describing a method's parameter and return types.

Parameters:
 * None

Returns:
 * the type encoding for the method as a string

Notes:
 * Encoding types are described at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html

 * The numerical value between the return type (first character) and the arguments represents an idealized stack size for the method's argument list.  The numbers between arguments specify offsets within that idealized space.  These numbers should not be trusted as they ignore register usage and other optimizations that may be in effect for a given architecture.
 * Since our implementation of Objective-C message sending utilizes the NSInvocation Objective-C class, we do not have to concern ourselves with the stack space -- it is handled for us; this method is generally not necessary and is provided for informational purposes only.

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.objc.object
===================

The submodule for hs._asm.objc which provides methods for working with and examining Objective-C objects.

Most of the methods of this sub-module concentrate on the object as an Objective-C class instance (as an object of type `id`), but there are also methods for examining property values and for converting (some) Objective-C objects to and from a format usable directly by Hammerspoon or Lua.

### Usage
~~~lua
object = require("hs._asm.objc").object
~~~

### Contents


##### Module Constructors
* <a href="#fromLuaObject">object.fromLuaObject(value) -> idObject | nil</a>

##### Module Methods
* <a href="#allocAndMsgSend">object:allocAndMsgSend(selector, [...]) -> return value</a>
* <a href="#class">object:class() -> classObject</a>
* <a href="#className">object:className() -> string</a>
* <a href="#methodList2">object:methodList() -> table</a>
* <a href="#msgSend">object:msgSend(selector, [...]) -> return value</a>
* <a href="#msgSendSuper">object:msgSendSuper(selector, [...]) -> return value</a>
* <a href="#property">object:property(propertyName) -> value</a>
* <a href="#propertyList">object:propertyList([includeNSObject]) -> table</a>
* <a href="#propertyValues">object:propertyValues([includeNSObject]) -> table</a>
* <a href="#selector3">object:selector(string) -> selectorObject</a>
* <a href="#value">object:value() -> any</a>

- - -

### Module Constructors

<a name="fromLuaObject"></a>
~~~lua
object.fromLuaObject(value) -> idObject | nil
~~~
Converts a Hammerspoon/Lua value or userdata object into the corresponding Objective-C object.

Parameters:
 * value - the Hammerspoon or Lua value or userdata object to return an Objective-C object for.

Returns:
 * an idObject (Objective-C class instance) or nil, if no reasonable Objective-C representation exists for the value.

Notes:
 * The primary Lua variable types supported are as follows:
   * number  - will convert to an NSNumber
   * string  - will convert to an NSString or NSData, if the string does not contain properly formated UTF8 byte-code sequences
   * table   - will convert to an NSArray, if the table contains only non-sparse, numeric integer indexes starting at 1, or NSDictionary otherwise.
   * boolean - will convert to an NSNumber
   * other lua basic types are not supported and will return nil
 * Many userdata objects which have converters registered by their modules can also be converted to an appropriate type.  An incomplete list of examples follows:
   * hs.application   - will convert to an NSRunningApplication, if the `hs.application` module has been loaded
   * hs.styledtext    - will convert to an NSAttributedString, if the `hs.styledtext` module has been loaded
   * hs.image         - will convert to an NSImage, if the `hs.image` module has been loaded
 * Some tables with the appropriate __luaSkinType tag can also be converted.  An incomplete list of examples follows:
   * hs.drawing.color table - will convert to an NSColor, if the `hs.drawing.color` module has been loaded
   * a Rect table           - will convert to an NSValue containing an NSRect; the hs.geometry equivalent is not yet supported, but this is expected to be a temporary limitation.
   * a Point table          - will convert to an NSValue containing an NSPoint; the hs.geometry equivalent is not yet supported, but this is expected to be a temporary limitation.
   * a Size table           - will convert to an NSValue containing an NSSize; the hs.geometry equivalent is not yet supported, but this is expected to be a temporary limitation.

### Module Methods

<a name="allocAndMsgSend"></a>
~~~lua
object:allocAndMsgSend(selector, [...]) -> return value
~~~
Allocates an instance of the class and sends the specified selector (message) to the allocated object and returns the result, if any.

Parameters:
 * selector - a selectorObject or string (message) to send to the newly allocated object, usually an initializer of some sort.  If this is a string, the corresponding selector for the class will be looked up for you.
 * optional additional arguments are passed to the target as arguments for the selector specified.

Returns:
 * the results of sending the message to the object, if any.  If an exception occurs during the sending of the message, this method returns nil as the first argument, and a second argument of a table containing the traceback information for the exception.

Notes:
 * this method is a convenience wrapper to the [hs._asm.objc.objc_msgSend](#objc_msgSend) function provided for sending a message to an object instance.

 * Continuing the example provided in the [hs._asm.objc.objc_msgSend](#objc_msgSend) function of creating a newly initialized NSObject instance, the following additional shortcut is made possible with this method:
   * `hs._asm.objc.class("NSObject"):allocAndMsgSend("init")`  (`fromString` is optional -- see [hs._asm.objc.class.fromString](#fromString))

- - -

<a name="class"></a>
~~~lua
object:class() -> classObject
~~~
Returns the classObject of the object

Parameters:
 * None

Returns:
 * the classObject (hs._asm.objc.class) of the object.

- - -

<a name="className"></a>
~~~lua
object:className() -> string
~~~
Returns the class name of the object as a string

Parameters:
 * None

Returns:
 * the name of the object's class as a string

- - -

<a name="methodList2"></a>
~~~lua
object:methodList() -> table
~~~
Returns a table containing the methods defined for the object's class.

Parameters:
 * None

Returns:
 * a table of key-value pairs where the key is a string of the method's name (technically the method selector's name) and the value is the methodObject for the specified selector name.

Notes:
 * This method returns the instance methods for the object's class and is syntatic sugar for `hs._asm.objc.object:class():methodList()`.
 * To get a table of the class methods for the object's class, invoke this method on the meta class of the object's class, e.g. `hs._asm.objc.object:class():metaClass():methodList()`.

- - -

<a name="msgSend"></a>
~~~lua
object:msgSend(selector, [...]) -> return value
~~~
Sends the specified selector (message) to the object and returns the result, if any.

Parameters:
 * selector - a selector (message) to send to the object.
 * optional additional arguments are passed to the target as arguments for the selector specified.

Returns:
 * the results of sending the message to the object, if any.  If an exception occurs during the sending of the message, this method returns nil as the first argument, and a second argument of a table containing the traceback information for the exception.

Notes:
 * this method is a convenience wrapper to the [hs._asm.objc.objc_msgSend](#objc_msgSend) function provided for sending a message to an object instance.

 * the `__call` metamethods for classObjects and idObjects (an object instance) have been provided as further shortcuts, allowing you to initialize a newly allocated NSObject as:
   * `hs._asm.objc.class("NSObject")("alloc")("init")`

 * any additional arguments to the selector should be specified as additional arguments, e.g.
   * `string = hs._asm.objc.class("NSString")("stringWithUTF8String:", "the value of the new NSString")`
     or
   * `string = hs._asm.objc.class("NSString")("alloc")("initWithUTF8String:", "the value of the new NSString")`

- - -

<a name="msgSendSuper"></a>
~~~lua
object:msgSendSuper(selector, [...]) -> return value
~~~
Sends the specified selector (message) to the object's superclass and returns the result, if any.

Parameters:
 * selector - a selector (message) to send to the object's superclass.
 * optional additional arguments are passed to the target as arguments for the selector specified.

Returns:
 * the results of sending the message to the object, if any.  If an exception occurs during the sending of the message, this method returns nil as the first argument, and a second argument of a table containing the traceback information for the exception.

Notes:
 * this method is a convenience wrapper to the [hs._asm.objc.objc_msgSend](#objc_msgSend) function provided for sending a message to an object instance.

- - -

<a name="property"></a>
~~~lua
object:property(propertyName) -> value
~~~
Returns the value of the specified property for the object.

Parameters:
 * propertyName - the name of the property to retrieve the Hammerspoon/Lua representation of the value of.

Returns:
 * the Hammerspoon/Lua representation of the property specified for the object, or the Objective-C `debugDescription` of the object if a proper representation is not possible.

Notes:
 * a property which contains an Objective-C object will actually return the `hs._asm.objc.object` userdata for the object.  You can get it's Hammerspoon/Lua representation, if available, by calling the [hs._asm.objc.object:value](#value) method on the object returned.

- - -

<a name="propertyList"></a>
~~~lua
object:propertyList([includeNSObject]) -> table
~~~
Returns a table containing the properties of the object and their propertyObjects.  Includes all inherited properties from the object's superclass or any adopted protocols of the object's class.

Parameters:
 * includesNSObject - an optional boolean, defaulting to false unless the object is an instance of `NSObject`, indicating whether or not the property list should include properties defined for the base NSObject class that almost all objects inherit from.

Returns:
 * a table of key-value pairs, where each key represents a property of the object and the value is the propertyObject for the property named in the key.

- - -

<a name="propertyValues"></a>
~~~lua
object:propertyValues([includeNSObject]) -> table
~~~
Returns a table containing the properties of the object and the Hammerspoon/Lua representation of their value, if possible.  Includes all inherited properties from the object's superclass or any adopted protocols of the object's class.

Parameters:
 * includesNSObject - an optional boolean, defaulting to false unless the object is an instance of `NSObject`, indicating whether or not the property list should include properties defined for the base NSObject class that almost all objects inherit from.

Returns:
 * a table of key-value pairs, where each key represents a property of the object and the value is the Hammerspoon/Lua representation of the value, or the Objective-C `debugDescription` for the value if a proper representation is not possible, for the property named in the key.

Notes:
 * a property which contains an Objective-C object will actually return the `hs._asm.objc.object` userdata for the object.  You can get it's Hammerspoon/Lua representation, if available, by calling the [hs._asm.objc.object:value](#value) method on the object returned.

- - -

<a name="selector3"></a>
~~~lua
object:selector(string) -> selectorObject
~~~
Returns the selector object with the specified name, if one exists, for the object.

Parameters:
 * string - the selector name as a string to look up for the object.

Returns:
 * the selectorObject or nil, if no selector with that name exists for the object instance, its class's adopted protocols, or one of it's super classes (or their adopted protocols).

- - -

<a name="value"></a>
~~~lua
object:value() -> any
~~~
Returns the Hammerspoon or Lua equivalent value of the object

Parameters:
 * None

Returns:
 * the value of the object as its closest Hammerspoon or Lua equivalent.  Where modules have registered helper functions for handling Objective-C types directly, the appropriate userdata object is returned.  Where no such convertor exists, and if the object does not match a basic Lua data type (string, boolean, number, table), the Objective-C `debugDescription` method of the object is used to return a string describing the object.

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.objc.property
=====================

The submodule for hs._asm.objc which provides methods for working with and examining Objective-C class and protocol properties.

### Usage
~~~lua
property = require("hs._asm.objc").property
~~~

### Contents


##### Module Methods
* <a href="#attributeList">property:attributeList() -> table</a>
* <a href="#attributeValue">property:attributeValue(attribute) -> string</a>
* <a href="#attributes">property:attributes() -> string</a>
* <a href="#name">property:name() -> string</a>

- - -

### Module Methods

<a name="attributeList"></a>
~~~lua
property:attributeList() -> table
~~~
Returns the attributes for the property in a table

Parameters:
 * None

Returns:
 * the attributes of the property in a table of key-value pairs where the key is a property code applied to the property and the value is the codes value for the property.

Notes:
 * Property codes and their meanings can be found at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html#//apple_ref/doc/uid/TP40008048-CH101-SW6.

- - -

<a name="attributeValue"></a>
~~~lua
property:attributeValue(attribute) -> string
~~~
Returns the value of the specified attribute for the property

Parameters:
 * attribute - a string containing the property code to get the value of

Returns:
 * the value of the property attribute for the property

Notes:
 * Property codes and their meanings can be found at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html#//apple_ref/doc/uid/TP40008048-CH101-SW6.

- - -

<a name="attributes"></a>
~~~lua
property:attributes() -> string
~~~
Returns the attributes of the property as a string

Parameters:
 * None

Returns:
 * the property attributes as a string

Notes:
 * The format of property attributes string can be found at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html#//apple_ref/doc/uid/TP40008048-CH101-SW6.

- - -

<a name="name"></a>
~~~lua
property:name() -> string
~~~
Returns the name of the property

Parameters:
 * None

Returns:
 * the name of the property as a string

Notes:
 * this may differ from the property's getter method

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.objc.protocol
=====================

The submodule for hs._asm.objc which provides methods for working with and examining Objective-C protocols.

### Usage
~~~lua
protocol = require("hs._asm.objc").protocol
~~~

### Contents


##### Module Constructors
* <a href="#fromString2">protocol.fromString(name) -> protocolObject</a>
* <a href="#list">protocol.list() -> table</a>

##### Module Methods
* <a href="#adoptedProtocols">protocol:adoptedProtocols() -> table</a>
* <a href="#conformsToProtocol">protocol:conformsToProtocol(protocol) -> boolean</a>
* <a href="#methodDescription">protocol:methodDescription(selector, required, instance) -> table</a>
* <a href="#methodDescriptionList">protocol:methodDescriptionList(required, instance) -> table</a>
* <a href="#name">protocol:name() -> string</a>
* <a href="#property">protocol:property(name, required, instance) -> propertyObject</a>
* <a href="#propertyList">protocol:propertyList() -> table</a>
* <a href="#selector4">protocol:selector(string) -> selectorObject</a>

- - -

### Module Constructors

<a name="fromString2"></a>
~~~lua
protocol.fromString(name) -> protocolObject
~~~
Returns a protocol object for the named protocol

Parameters:
 * name - a string containing the name of the desired protocol

Returns:
 * the protocol object for the name specified or nil if a protocol with the specified name does not exist

Notes:
 * This constructor has also been assigned to the __call metamethod of the `hs._asm.objc.protocol` sub-module so that it can be invoked as `hs._asm.objc.protocol(name)` as a shortcut.

- - -

<a name="list"></a>
~~~lua
protocol.list() -> table
~~~
Returns a list of all currently available protocols

Parameters:
 * None

Returns:
 * a table of all currently available protocols as key-value pairs.  The key is the protocol name as a string and the value for each key is the protocolObject for the named protocol.

### Module Methods

<a name="adoptedProtocols"></a>
~~~lua
protocol:adoptedProtocols() -> table
~~~
Returns a table of the protocols adopted by the protocol.

Parameters:
 * None

Returns:
 * a table of the protocols adopted by this protocol as key-value pairs.  The key is the protocol name as a string and the value for each key is the protocolObject for the named protocol.

- - -

<a name="conformsToProtocol"></a>
~~~lua
protocol:conformsToProtocol(protocol) -> boolean
~~~
Returns whether or not the protocol conforms to the specified protocol.

Parameters:
 * protocol - the protocolObject to test if the target object conforms to.

Returns:
 * true if the target object conforms to the specified protocol; otherwise false.

- - -

<a name="methodDescription"></a>
~~~lua
protocol:methodDescription(selector, required, instance) -> table
~~~
Returns a table containing the method description of the selector specified for this protocol.

Parameters:
 * selector - a selector object for a method within this protocol
 * required - a boolean value indicating whether or not the selector specifies a required method for the protocol.
 * instance - a boolean value indicating whether or not the selector specifies an instance method for the protocol.

Returns:
 * a table of key-value pairs containing the method's selector name keyed to its object and its encoding type.

- - -

<a name="methodDescriptionList"></a>
~~~lua
protocol:methodDescriptionList(required, instance) -> table
~~~
Returns a table containing the methods and their description provided by this protocol.

Parameters:
 * required - a boolean value indicating whether or not the methods are required for the protocol.
 * instance - a boolean value indicating whether or not the methods are instance methods of the protocol.

Returns:
 * a table of key-value pairs where the key is the name of the method and the value is a table containing the method's selector object and encoding type.

- - -

<a name="name"></a>
~~~lua
protocol:name() -> string
~~~
Returns the name of the protocol

Parameters:
 * None

Returns:
 * the name of the protocol as a string

- - -

<a name="property"></a>
~~~lua
protocol:property(name, required, instance) -> propertyObject
~~~
Returns the property object for the property specified in the protocol.

Parameters:
 * name     - a string containing the name of the property
 * required - a boolean value indicating whether or not the property is a required property of the protocol.
 * instance - a boolean value indicating whether or not the property is an instance property of the protocol.

Returns:
 * the propertyObject or nil if a property with the specified name, required, and instance parameters does not exist.

- - -

<a name="propertyList"></a>
~~~lua
protocol:propertyList() -> table
~~~
Returns a table of the properties declared by the protocol.

Parameters:
 * None

Returns:
 * a table of the properties declared by the protocol as key-value pairs.  The key is a property name as a string, and the value is the propertyObject for the named property.

- - -

<a name="selector4"></a>
~~~lua
protocol:selector(string) -> selectorObject
~~~
Returns the selector object with the specified name, if one exists, for the protocol.

Parameters:
 * string - the selector name as a string to look up for the protocol.

Returns:
 * the selectorObject or nil, if no selector with that name exists for the protocol or its adopted protocols (or their adopted protocols).

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.objc.selector
=====================

The submodule for hs._asm.objc which provides methods for working with and examining Objective-C selectors.

The terms `selector` and `method` are often used interchangeably in this documentation and in many books and tutorials about Objective-C.  Strictly speaking this is lazy; for most purposes, I find that the easiest way to think of them is as follows: A selector is the name or label for a method, and a method is the actual implementation or function (code) for a selector.  Usually the specific intention is clear from context, but I hope to clean up this documentation to be more precise as time allows.

### Usage
~~~lua
selector = require("hs._asm.objc").selector
~~~

### Contents


##### Module Constructors
* <a href="#fromString3">selector.fromString(name) -> selectorObject</a>

##### Module Methods
* <a href="#name">selector:name() -> string</a>

- - -

### Module Constructors

<a name="fromString3"></a>
~~~lua
selector.fromString(name) -> selectorObject
~~~
Returns a selector object for the named selector

Parameters:
 * name - a string containing the name of the desired selector

Returns:
 * the selector object for the name specified

Notes:
 * This constructor has also been assigned to the __call metamethod of the `hs._asm.objc.selector` sub-module so that it can be invoked as `hs._asm.objc.selector(name)` as a shortcut.

 * This constructor should not generally be used; instead use [hs._asm.objc.class:selector](#selector), [hs._asm.objc.object:selector](#selector3), or [hs._asm.objc.protocol:selector](#selector4), as they first verify that the named selector is actually valid for the class, object, or protocol in question.

 * This constructor works by attempting to create the specified selector and returning the created selector object.  If the selector already exists (i.e. is defined as a valid selector in a class or protocol somewhere), then the already existing selector is returned instead of a new one.  Because there is no built in facility for determining if a selector is valid without also creating it if it does not already exist, use of this constructor is not preferred.

### Module Methods

<a name="name"></a>
~~~lua
selector:name() -> string
~~~
Returns the name of the selector as a string

Parameters:
 * None

Returns:
 * the selector's name as a string.

- - -

### License

> The MIT License (MIT)
>
> Copyright (c) 2017 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
>The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
>


