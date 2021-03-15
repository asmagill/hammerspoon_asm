/// === hs._asm.objc.protocol ===
///
/// The submodule for hs._asm.objc which provides methods for working with and examining Objective-C protocols.

#import "objc.h"

static LSRefTable refTable = LUA_NOREF;

#pragma mark - Module Functions

/// hs._asm.objc.protocol.fromString(name) -> protocolObject
/// Constructor
/// Returns a protocol object for the named protocol
///
/// Parameters:
///  * name - a string containing the name of the desired protocol
///
/// Returns:
///  * the protocol object for the name specified or nil if a protocol with the specified name does not exist
///
/// Notes:
///  * This constructor has also been assigned to the __call metamethod of the `hs._asm.objc.protocol` sub-module so that it can be invoked as `hs._asm.objc.protocol(name)` as a shortcut.
static int objc_protocolFromString(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    Protocol *prot = objc_getProtocol(luaL_checkstring(L, 1)) ;

    push_protocol(L, prot) ;
    return 1 ;
}

/// hs._asm.objc.protocol.list() -> table
/// Constructor
/// Returns a list of all currently available protocols
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table of all currently available protocols as key-value pairs.  The key is the protocol name as a string and the value for each key is the protocolObject for the named protocol.
static int objc_protocolList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    lua_newtable(L) ;
      UInt  count ;
      Protocol * __unsafe_unretained *protocolList = objc_copyProtocolList(&count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_protocol(L, protocolList[i]) ;
          lua_setfield(L, -2, protocol_getName(protocolList[i])) ;
      }
      if (protocolList) free(protocolList) ;
    return 1 ;
}

#pragma mark - Module Methods

/// hs._asm.objc.protocol:name() -> string
/// Method
/// Returns the name of the protocol
///
/// Parameters:
///  * None
///
/// Returns:
///  * the name of the protocol as a string
static int objc_protocol_getName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    lua_pushstring(L, protocol_getName(prot)) ;
    return 1 ;
}

/// hs._asm.objc.protocol:propertyList() -> table
/// Method
/// Returns a table of the properties declared by the protocol.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table of the properties declared by the protocol as key-value pairs.  The key is a property name as a string, and the value is the propertyObject for the named property.
static int objc_protocol_getPropertyList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;

    lua_newtable(L) ;
      UInt            count ;
      objc_property_t *propertyList = protocol_copyPropertyList(prot, &count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_property(L, propertyList[i]) ;
          lua_setfield(L, -2, property_getName(propertyList[i])) ;
      }
      if (propertyList) free(propertyList) ;
    return 1 ;
}

/// hs._asm.objc.protocol:property(name, required, instance) -> propertyObject
/// Method
/// Returns the property object for the property specified in the protocol.
///
/// Parameters:
///  * name     - a string containing the name of the property
///  * required - a boolean value indicating whether or not the property is a required property of the protocol.
///  * instance - a boolean value indicating whether or not the property is an instance property of the protocol.
///
/// Returns:
///  * the propertyObject or nil if a property with the specified name, required, and instance parameters does not exist.
static int objc_protocol_getProperty(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG,
                    LS_TSTRING,
                    LS_TBOOLEAN,
                    LS_TBOOLEAN, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    push_property(L, protocol_getProperty(prot, luaL_checkstring(L, 2),
                                             (BOOL)(lua_toboolean(L, 3)),
                                             (BOOL)(lua_toboolean(L, 4)))) ;
    return 1 ;
}

/// hs._asm.objc.protocol:adoptedProtocols() -> table
/// Method
/// Returns a table of the protocols adopted by the protocol.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table of the protocols adopted by this protocol as key-value pairs.  The key is the protocol name as a string and the value for each key is the protocolObject for the named protocol.
static int objc_protocol_getAdoptedProtocols(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;

    lua_newtable(L) ;
      UInt  count ;
      Protocol * __unsafe_unretained *protocolList = protocol_copyProtocolList(prot, &count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_protocol(L, protocolList[i]) ;
          lua_setfield(L, -2, protocol_getName(protocolList[i])) ;
      }
      if (protocolList) free(protocolList) ;
    return 1 ;
}

/// hs._asm.objc.protocol:conformsToProtocol(protocol) -> boolean
/// Method
/// Returns whether or not the protocol conforms to the specified protocol.
///
/// Parameters:
///  * protocol - the protocolObject to test if the target object conforms to.
///
/// Returns:
///  * true if the target object conforms to the specified protocol; otherwise false.
static int objc_protocol_conformsToProtocol(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG,
                    LS_TUSERDATA, PROTOCOL_USERDATA_TAG, LS_TBREAK] ;
    Protocol *prot1 = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    Protocol *prot2 = get_objectFromUserdata(__bridge Protocol *, L, 2, PROTOCOL_USERDATA_TAG) ;
    lua_pushboolean(L, protocol_conformsToProtocol(prot1, prot2)) ;
    return 1 ;
}

/// hs._asm.objc.protocol:methodDescriptionList(required, instance) -> table
/// Method
/// Returns a table containing the methods and their description provided by this protocol.
///
/// Parameters:
///  * required - a boolean value indicating whether or not the methods are required for the protocol.
///  * instance - a boolean value indicating whether or not the methods are instance methods of the protocol.
///
/// Returns:
///  * a table of key-value pairs where the key is the name of the method and the value is a table containing the method's selector object and encoding type.
static int objc_protocol_getMethodDescriptionList(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG,
                    LS_TBOOLEAN,
                    LS_TBOOLEAN, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    UInt count ;
    struct objc_method_description *results = protocol_copyMethodDescriptionList(prot,
                                                                (BOOL)(lua_toboolean(L, 2)),
                                                                (BOOL)(lua_toboolean(L, 3)),
                                                                      &count) ;
    lua_newtable(L) ;
    for(UInt i = 0 ; i < count ; i++) {
        SEL selectorName = results[i].name ;
        if (selectorName) {
            lua_newtable(L) ;
              lua_pushstring(L, results[i].types) ; lua_setfield(L, -2, "types") ;
              push_selector(L, selectorName)      ; lua_setfield(L, -2, "selector") ;
    //         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            lua_setfield(L, -2, sel_getName(selectorName)) ;
        }
    }
    if (results) free(results) ;
    return 1 ;
}

/// hs._asm.objc.protocol:methodDescription(selector, required, instance) -> table
/// Method
/// Returns a table containing the method description of the selector specified for this protocol.
///
/// Parameters:
///  * selector - a selector object for a method within this protocol
///  * required - a boolean value indicating whether or not the selector specifies a required method for the protocol.
///  * instance - a boolean value indicating whether or not the selector specifies an instance method for the protocol.
///
/// Returns:
///  * a table of key-value pairs containing the method's selector name keyed to its object and its encoding type.
static int objc_protocol_getMethodDescription(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG,
                    LS_TUSERDATA, SEL_USERDATA_TAG,
                    LS_TBOOLEAN,
                    LS_TBOOLEAN, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    SEL      sel   = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;

    struct objc_method_description  result = protocol_getMethodDescription(prot, sel,
                                                                (BOOL)(lua_toboolean(L, 3)),
                                                                (BOOL)(lua_toboolean(L, 4))) ;
    if (result.types == NULL || result.name == NULL) {
        lua_pushnil(L) ;
    } else {
        lua_newtable(L) ;
          lua_pushstring(L, result.types) ; lua_setfield(L, -2, "types") ;
          push_selector(L, result.name)   ; lua_setfield(L, -2, "selector") ;
    }
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions

int push_protocol(lua_State *L, Protocol *prot) {
#if defined(DEBUG_GC)
    [LuaSkin logDebug:[NSString stringWithFormat:@"protocol: create %@ (%p)", NSStringFromProtocol(prot), prot]] ;
#endif
    if (prot) {
        void** thePtr = lua_newuserdata(L, sizeof(Protocol *)) ;
// Don't alter retain count for Protocol objects
        *thePtr = (__bridge void *)prot ;
        luaL_getmetatable(L, PROTOCOL_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int protocol_userdata_tostring(lua_State* L) {
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", PROTOCOL_USERDATA_TAG, protocol_getName(prot), prot) ;
    return 1 ;
}

static int protocol_userdata_eq(lua_State* L) {
    Protocol *prot1 = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    Protocol *prot2 = get_objectFromUserdata(__bridge Protocol *, L, 2, PROTOCOL_USERDATA_TAG) ;
    lua_pushboolean(L, protocol_isEqual(prot1, prot2)) ;
    return 1 ;
}

static int protocol_userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    Protocol * __unused prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
#if defined(DEBUG_GC)
    [LuaSkin logDebug:[NSString stringWithFormat:@"protocol: remove %@ (%p)", NSStringFromProtocol(prot), prot]] ;
#endif

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int protocol_meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg protocol_userdata_metaLib[] = {
    {"name",                  objc_protocol_getName},
    {"propertyList",          objc_protocol_getPropertyList},
    {"property",              objc_protocol_getProperty},
    {"adoptedProtocols",      objc_protocol_getAdoptedProtocols},
    {"conformsToProtocol",    objc_protocol_conformsToProtocol},
    {"methodDescriptionList", objc_protocol_getMethodDescriptionList},
    {"methodDescription",     objc_protocol_getMethodDescription},

    {"__tostring",            protocol_userdata_tostring},
    {"__eq",                  protocol_userdata_eq},
    {"__gc",                  protocol_userdata_gc},
    {NULL,                    NULL}
};

// Functions for returned object when module loads
static luaL_Reg protocol_moduleLib[] = {
    {"fromString", objc_protocolFromString},
    {"list",       objc_protocolList},

    {NULL,         NULL}
};

// Metatable for module, if needed
// static const luaL_Reg protocol_module_metaLib[] = {
//     {"__gc", protocol_meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_protocol(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:PROTOCOL_USERDATA_TAG
                                     functions:protocol_moduleLib
                                 metaFunctions:nil // protocol_module_metaLib
                               objectFunctions:protocol_userdata_metaLib];

    return 1;
}
