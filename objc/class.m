/// === hs._asm.objc.class ===
///
/// The submodule for hs._asm.objc which provides methods for working with and examining Objective-C classes.

#import "objc.h"

static LSRefTable refTable = LUA_NOREF;

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

/// hs._asm.objc.class.fromString(name) -> classObject
/// Constructor
/// Returns a class object for the named class
///
/// Parameters:
///  * name - a string containing the name of the desired class
///
/// Returns:
///  * the class object for the name specified or nil if a class with the specified name does not exist
///
/// Notes:
///  * This constructor has also been assigned to the __call metamethod of the `hs._asm.objc.class` sub-module so that it can be invoked as `hs._asm.objc.class(name)` as a shortcut.
static int objc_classFromString(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    Class cls = (Class)objc_lookUpClass(luaL_checkstring(L, 1)) ;

    push_class(L, cls) ;
    return 1 ;
}

/// hs._asm.objc.class.list() -> table
/// Constructor
/// Returns a list of all currently available classes
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table of all currently available classes as key-value pairs.  The key is the class name as a string and the value for each key is the classObject for the named class.
static int objc_classList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    lua_newtable(L) ;
      UInt  count ;
      Class *classList = objc_copyClassList(&count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_class(L, classList[i]) ;
          lua_setfield(L, -2, class_getName(classList[i])) ;
      }
      if (classList) free(classList) ;
    return 1 ;
}

#pragma mark - Module Methods

/// hs._asm.objc.class:metaClass() -> classObject
/// Method
/// Returns the metaclass definition of a specified class.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the classObject for the metaClass of the class
///
/// Notes:
///  * Most of the time, you want the class object itself instead of the Meta class.  However, the meta class is useful when you need to work specifically with class methods as opposed to instance methods of the class.
static int objc_class_getMetaClass(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;

    Class meta = (Class)objc_getMetaClass(class_getName(cls)) ;
    push_class(L, meta) ;
    return 1 ;
}

/// hs._asm.objc.class:methodList() -> table
/// Method
/// Returns a table containing the methods defined for the class.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table of key-value pairs where the key is a string of the method's name (technically the method selector's name) and the value is the methodObject for the specified selector name.
///
/// Notes:
///  * This method returns the instance methods for the class.  To get a table of the class methods for the class, invoke this method on the meta class of the class, e.g. `hs._asm.objc.class("className"):metaClass():methodList()`.
static int objc_class_getMethodList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;

    lua_newtable(L) ;
      UInt   count ;
      Method *methodList = class_copyMethodList(cls, &count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_method(L, methodList[i]) ;
          lua_setfield(L, -2, sel_getName(method_getName(methodList[i]))) ;
      }
      if (methodList) free(methodList) ;
    return 1 ;
}

/// hs._asm.objc.class:respondsToSelector(selector) -> boolean
/// Method
/// Returns true if the class responds to the specified selector, otherwise false.
///
/// Parameters:
///  * selector - the selectorObject to check for in the class
///
/// Returns:
///  * true, if the selector is recognized by the class, otherwise false
///
/// Notes:
///  * this method will determine if the class recognizes the selector as an instance method of the class.  To check to see if it recognizes the selector as a class method, use this method on the class meta class, e.g. `hs._asm.objc.class("className"):metaClass():responseToSelector(selector)`.
static int objc_class_respondsToSelector(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG,
                                LS_TUSERDATA, SEL_USERDATA_TAG,
                                LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    SEL sel = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;

    lua_pushboolean(L, class_respondsToSelector(cls, sel)) ;
    return 1 ;
}

/// hs._asm.objc.class:instanceMethod(selector) -> methodObject
/// Method
/// Returns the methodObject for the specified selector, if the class supports it as an instance method.
///
/// Parameters:
///  * selector - the selectorObject to get the methodObject for
///
/// Returns:
///  * the methodObject, if the selector represents an instance method of the class, otherwise nil.
///
/// Notes:
///  * see also [hs._asm.objc.class:classMethod](#classMethod)
static int objc_class_getInstanceMethod(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG,
                                LS_TUSERDATA, SEL_USERDATA_TAG,
                                LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    SEL sel = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;

    push_method(L, class_getInstanceMethod(cls, sel)) ;
    return 1 ;
}

/// hs._asm.objc.class:classMethod(selector) -> methodObject
/// Method
/// Returns the methodObject for the specified selector, if the class supports it as a class method.
///
/// Parameters:
///  * selector - the selectorObject to get the methodObject for
///
/// Returns:
///  * the methodObject, if the selector represents a class method of the class, otherwise nil.
///
/// Notes:
///  * see also [hs._asm.objc.class:instanceMethod](#instanceMethod)
static int objc_class_getClassMethod(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG,
                                LS_TUSERDATA, SEL_USERDATA_TAG,
                                LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    SEL sel = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;

    push_method(L, class_getClassMethod(cls, sel)) ;
    return 1 ;
}

/// hs._asm.objc.class:instanceSize() -> bytes
/// Method
/// Returns the size in bytes on an instance of the class.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the size in bytes on an instance of the class
///
/// Notes:
///  * this is provided for informational purposes only.  At present, there are no methods or plans for methods allowing direct access to the class internal memory structures.
static int objc_class_getInstanceSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushinteger(L, (lua_Integer)class_getInstanceSize(cls)) ;
    return 1 ;
}

/// hs._asm.objc.class:name() -> string
/// Method
/// Returns the name of the class as a string
///
/// Parameters:
///  * None
///
/// Returns:
///  * the class name as a string
static int objc_class_getName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushstring(L, class_getName(cls)) ;
    return 1 ;
}

/// hs._asm.objc.class:ivarLayout() -> string | nil
/// Method
/// Returns a description of the Ivar layout for the class.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string specifying the ivar layout for the class
///
/// Notes:
///  * this is provided for informational purposes only.  At present, there are no methods or plans for methods allowing direct access to the class internal memory structures.
static int objc_class_getIvarLayout(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushstring(L, (const char *)class_getIvarLayout(cls)) ;
    return 1 ;
}

/// hs._asm.objc.class:weakIvarLayout() -> string | nil
/// Method
/// Returns a description of the layout of the weak Ivar's for the class.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string specifying the ivar layout for the class
///
/// Notes:
///  * this is provided for informational purposes only.  At present, there are no methods or plans for methods allowing direct access to the class internal memory structures.
static int objc_class_getWeakIvarLayout(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushstring(L, (const char *)class_getWeakIvarLayout(cls)) ;
    return 1 ;
}

/// hs._asm.objc.class:imageName() -> string
/// Method
/// The path to the framework or library which defines the class.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string containing the path to the library or framework which defines the class.
static int objc_class_getImageName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushstring(L, class_getImageName(cls)) ;
    return 1 ;
}

/// hs._asm.objc.class:isMetaClass() -> boolean
/// Method
/// Returns a boolean specifying whether or not the classObject refers to a meta class.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true, if the classObject is a meta class, otherwise false.
///
/// Notes:
///  * A meta-class is basically the class an Objective-C Class object belongs to.  For most purposes outside of creating a class at runtime, the only real importance of a meta class is that it contains information about the class methods, as opposed to the instance methods, of the class.
static int objc_class_isMetaClass(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushboolean(L, class_isMetaClass(cls)) ;
    return 1 ;
}

/// hs._asm.objc.class:superclass() -> classObject
/// Method
/// Returns the superclass classObject for the class
///
/// Parameters:
///  * None
///
/// Returns:
///  * the classObject for the superclass of the class
static int objc_class_getSuperClass(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    push_class(L, class_getSuperclass(cls)) ;
    return 1 ;
}

/// hs._asm.objc.class:version() -> integer
/// Method
/// Returns the version number of the class definition
///
/// Parameters:
///  * None
///
/// Returns:
///  * the version number of the class definition
///
/// Notes:
///  * This is provided for informational purposes only.  While the version number does provide a method for identifying changes which might affect whether or not your code can use a given class, it is usually better to verify that the support you require is available with `respondsToSelector` and such since most use cases do not care about internal or instance variable layout changes.
static int objc_class_getVersion(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushinteger(L, (lua_Integer)class_getVersion(cls)) ;
    return 1 ;
}

/// hs._asm.objc.class:propertyList() -> table
/// Method
/// Returns a table containing the properties defined for the class
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table of key-value pairs in which each key is a string of a property name provided by the class and the value is the propertyObject for the named property.
static int objc_class_getPropertyList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;

    lua_newtable(L) ;
      UInt            count ;
      objc_property_t *propertyList = class_copyPropertyList(cls, &count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_property(L, propertyList[i]) ;
          lua_setfield(L, -2, property_getName(propertyList[i])) ;
      }
      if (propertyList) free(propertyList) ;
    return 1 ;
}

/// hs._asm.objc.class:property(name) -> propertyObject
/// Method
/// Returns the propertyObject for the specified property of the class
///
/// Parameters:
///  * name - a string containing the name of the property
///
/// Returns:
///  * the propertyObject for the named property
static int objc_class_getProperty(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    push_property(L, class_getProperty(cls, luaL_checkstring(L, 2))) ;
    return 1 ;
}

/// hs._asm.objc.class:ivarList() -> table
/// Method
/// Returns a table containing the instance variables for the class
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table of key-value pairs in which the key is a string containing the name of an instance variable of the class and the value is the ivarObject for the specified instance variable.
static int objc_class_getIvarList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;

    lua_newtable(L) ;
      UInt count ;
      Ivar *ivarList = class_copyIvarList(cls, &count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_ivar(L, ivarList[i]) ;
          lua_setfield(L, -2, ivar_getName(ivarList[i])) ;
      }
      if (ivarList) free(ivarList) ;
    return 1 ;
}

/// hs._asm.objc.class:instanceVariable(name) -> ivarObject
/// Method
/// Returns the ivarObject for the specified instance variable of the class
///
/// Parameters:
///  * name - a string containing the name of the instance variable to return for the class
///
/// Returns:
///  * the ivarObject for the specified instance variable named.
static int objc_class_getInstanceVariable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    push_ivar(L, class_getInstanceVariable(cls, luaL_checkstring(L, 2))) ;
    return 1 ;
}

// Googling suggests that this was added early in the specification defining days, but
// never actually removed when the decision was made to not support class variables in
// Objective-C.  At any rate, unless someone comes up with a reason for it, it's just
// confusing and useless here.
// It's been suggested that using objc_get/setAssociatedObject is a better way to store
// class data if static variables don't cut it, and tbh, since this module only "looks at"
// stuff right now with limited to no ability to "set" things...
//
// static int objc_class_getClassVariable(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
//     Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
//     push_ivar(L, class_getClassVariable(cls, luaL_checkstring(L, 2))) ;
//     return 1 ;
// }

/// hs._asm.objc.class:adoptedProtocols() -> table
/// Method
/// Returns a table of the protocols adopted by this class.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table of key-value pairs in which each key is a string containing the name of a protocol adopted by this class and the value is the protocolObject for the named protocol
static int objc_class_getAdoptedProtocols(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;

    lua_newtable(L) ;
      UInt  count ;
      Protocol * __unsafe_unretained *protocolList = class_copyProtocolList(cls, &count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_protocol(L, protocolList[i]) ;
          lua_setfield(L, -2, protocol_getName(protocolList[i])) ;
      }
      if (protocolList) free(protocolList) ;
    return 1 ;
}

/// hs._asm.objc.class:conformsToProtocol(protocol) -> boolean
/// Method
/// Returns true or false indicating whether the class conforms to the specified protocol or not.
///
/// Parameters:
///  * protocol - the protocolObject of the protocol to test for class conformity
///
/// Returns:
///  * true, if the class conforms to the specified protocol, otherwise false
static int objc_class_conformsToProtocol(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG,
                                LS_TUSERDATA, PROTOCOL_USERDATA_TAG, LS_TBREAK] ;
    Class    cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 2, PROTOCOL_USERDATA_TAG) ;

    lua_pushboolean(L, class_conformsToProtocol(cls, prot)) ;
    return 1 ;
}

/// hs._asm.objc.class:signatureForMethod(selector) -> table
/// Method
/// Returns the method signature for the specified selector of the class.
///
/// Paramters:
///  * selector - a selectorObject specifying the selector to get the method signature for
///
/// Returns:
///  * a table containing the method signature for the specified selector.  The table will contain the following keys:
///    * arguments          - A table containing an array of encoding types for each argument, including the target and selector, required when invoking this method.
///    * frameLength        - The number of bytes that the arguments, taken together, occupy on the stack.
///    * methodReturnLength - The number of bytes required for the return value
///    * methodReturnType   - string encoding the return type of the method in Objective-C type encoding
///    * numberOfArguments  - The number of arguments, including the target (object) and selector, required when invoking this method
///
/// Notes:
///  * this method returns the signature of an instance method of the class.  To determine the signature for a class method of the class, use this method on the class meta class, e.g.  `hs._asm.objc.class("className"):metaClass():signatureForMethod(selector)`.
///  * Method signatures are
static int class_signatureForMethod(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG,
                    LS_TUSERDATA, SEL_USERDATA_TAG,
                    LS_TBREAK] ;
    Class    cls        = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    SEL      sel        = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;

    [skin pushNSObject:[cls instanceMethodSignatureForSelector:sel]] ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions

int push_class(lua_State *L, Class cls) {
#if defined(DEBUG_GC)
    [LuaSkin logDebug:[NSString stringWithFormat:@"class: create %@ (%p)", NSStringFromClass(cls), cls]] ;
#endif
    if (cls) {
        void** thePtr = lua_newuserdata(L, sizeof(Class)) ;
        *thePtr = (__bridge void *)cls ;
        luaL_getmetatable(L, CLASS_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int class_userdata_tostring(lua_State* L) {
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", CLASS_USERDATA_TAG, class_getName(cls), cls) ;
    return 1 ;
}

static int class_userdata_eq(lua_State* L) {
    Class cls1 = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    Class cls2 = get_objectFromUserdata(__bridge Class, L, 2, CLASS_USERDATA_TAG) ;
    lua_pushboolean(L, (cls1 == cls2)) ;
    return 1 ;
}

static int class_userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    Class __unused cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
#if defined(DEBUG_GC)
    [LuaSkin logDebug:[NSString stringWithFormat:@"class: remove %@ (%p)", NSStringFromClass(cls), cls]] ;
#endif

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int class_meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg class_userdata_metaLib[] = {
    {"imageName",          objc_class_getImageName},
    {"instanceSize",       objc_class_getInstanceSize},
    {"ivarLayout",         objc_class_getIvarLayout},
    {"name",               objc_class_getName},
    {"superclass",         objc_class_getSuperClass},
    {"weakIvarLayout",     objc_class_getWeakIvarLayout},
    {"isMetaClass",        objc_class_isMetaClass},
    {"version",            objc_class_getVersion},
    {"propertyList",       objc_class_getPropertyList},
    {"property",           objc_class_getProperty},
    {"ivarList",           objc_class_getIvarList},
    {"instanceVariable",   objc_class_getInstanceVariable},
//     {"classVariable",      objc_class_getClassVariable},
    {"adoptedProtocols",   objc_class_getAdoptedProtocols},
    {"conformsToProtocol", objc_class_conformsToProtocol},
    {"methodList",         objc_class_getMethodList},
    {"respondsToSelector", objc_class_respondsToSelector},
    {"instanceMethod",     objc_class_getInstanceMethod},
    {"classMethod",        objc_class_getClassMethod},
    {"metaClass",          objc_class_getMetaClass},
    {"signatureForMethod", class_signatureForMethod},

    {"__tostring",         class_userdata_tostring},
    {"__eq",               class_userdata_eq},
    {"__gc",               class_userdata_gc},
    {NULL,                 NULL}
};

// Functions for returned object when module loads
static luaL_Reg class_moduleLib[] = {
    {"fromString", objc_classFromString},
    {"list",       objc_classList},

    {NULL,         NULL}
};

// Metatable for module, if needed
// static const luaL_Reg class_module_metaLib[] = {
//     {"__gc", class_meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_class(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:CLASS_USERDATA_TAG
                                     functions:class_moduleLib
                                 metaFunctions:nil // class_module_metaLib
                               objectFunctions:class_userdata_metaLib];
    return 1;
}
