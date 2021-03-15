/// === hs._asm.objc.property ===
///
/// The submodule for hs._asm.objc which provides methods for working with and examining Objective-C class and protocol properties.

#import "objc.h"

static LSRefTable refTable = LUA_NOREF;

#pragma mark - Module Functions

#pragma mark - Module Methods

/// hs._asm.objc.property:name() -> string
/// Method
/// Returns the name of the property
///
/// Parameters:
///  * None
///
/// Returns:
///  * the name of the property as a string
///
/// Notes:
///  * this may differ from the property's getter method
static int objc_property_getName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, PROPERTY_USERDATA_TAG, LS_TBREAK] ;
    objc_property_t prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
    lua_pushstring(L, property_getName(prop)) ;
    return 1 ;
}

/// hs._asm.objc.property:attributes() -> string
/// Method
/// Returns the attributes of the property as a string
///
/// Parameters:
///  * None
///
/// Returns:
///  * the property attributes as a string
///
/// Notes:
///  * The format of property attributes string can be found at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html#//apple_ref/doc/uid/TP40008048-CH101-SW6.
static int objc_property_getAttributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, PROPERTY_USERDATA_TAG, LS_TBREAK] ;
    objc_property_t prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
    lua_pushstring(L, property_getAttributes(prop)) ;
    return 1 ;
}

/// hs._asm.objc.property:attributeValue(attribute) -> string
/// Method
/// Returns the value of the specified attribute for the property
///
/// Parameters:
///  * attribute - a string containing the property code to get the value of
///
/// Returns:
///  * the value of the property attribute for the property
///
/// Notes:
///  * Property codes and their meanings can be found at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html#//apple_ref/doc/uid/TP40008048-CH101-SW6.
static int objc_property_getAttributeValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, PROPERTY_USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    objc_property_t prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
    const char      *result = property_copyAttributeValue(prop, luaL_checkstring(L, 2)) ;

    lua_pushstring(L, result) ;
    free((void *)(size_t)result) ;
    return 1 ;
}

/// hs._asm.objc.property:attributeList() -> table
/// Method
/// Returns the attributes for the property in a table
///
/// Parameters:
///  * None
///
/// Returns:
///  * the attributes of the property in a table of key-value pairs where the key is a property code applied to the property and the value is the codes value for the property.
///
/// Notes:
///  * Property codes and their meanings can be found at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html#//apple_ref/doc/uid/TP40008048-CH101-SW6.
static int objc_property_getAttributeList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, PROPERTY_USERDATA_TAG, LS_TBREAK] ;
    objc_property_t prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;

    lua_newtable(L) ;
      UInt                      count ;
      objc_property_attribute_t *attributeList = property_copyAttributeList(prop, &count) ;
      for(UInt i = 0 ; i < count ; i++) {
//           lua_newtable(L) ;
//             lua_pushstring(L, attributeList[i].name) ;  lua_setfield(L, -2, "name") ;
//             lua_pushstring(L, attributeList[i].value) ; lua_setfield(L, -2, "value") ;
//           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushstring(L, attributeList[i].value) ; lua_setfield(L, -2, attributeList[i].name) ;
      }
      free(attributeList) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions

int push_property(lua_State *L, objc_property_t prop) {
#if defined(DEBUG_GC)
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin logDebug:[NSString stringWithFormat:@"property: create %s (%p)", property_getName(prop), prop]] ;
#endif
    if (prop) {
        void** thePtr = lua_newuserdata(L, sizeof(objc_property_t)) ;
        *thePtr = (void *)prop ;
        luaL_getmetatable(L, PROPERTY_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int property_userdata_tostring(lua_State* L) {
    objc_property_t prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s {%s} (%p)", PROPERTY_USERDATA_TAG, property_getName(prop), property_getAttributes(prop), prop) ;
    return 1 ;
}

static int property_userdata_eq(lua_State* L) {
    objc_property_t prop1 = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
    objc_property_t prop2 = get_objectFromUserdata(objc_property_t, L, 2, PROPERTY_USERDATA_TAG) ;
    lua_pushboolean(L, (prop1 == prop2)) ;
    return 1 ;
}

static int property_userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    objc_property_t __unused prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
#if defined(DEBUG_GC)
    [LuaSkin logDebug:[NSString stringWithFormat:@"property: remove %s (%p)", property_getName(prop), prop]] ;
#endif

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int property_meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg property_userdata_metaLib[] = {
    {"attributeValue", objc_property_getAttributeValue},
    {"attributes",     objc_property_getAttributes},
    {"name",           objc_property_getName},
    {"attributeList",  objc_property_getAttributeList},

    {"__tostring",     property_userdata_tostring},
    {"__eq",           property_userdata_eq},
    {"__gc",           property_userdata_gc},
    {NULL,             NULL}
};

// Functions for returned object when module loads
static luaL_Reg property_moduleLib[] = {
    {NULL, NULL}
};

// Metatable for module, if needed
// static const luaL_Reg property_module_metaLib[] = {
//     {"__gc", property_meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_property(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:PROPERTY_USERDATA_TAG
                                     functions:property_moduleLib
                                 metaFunctions:nil // property_module_metaLib
                               objectFunctions:property_userdata_metaLib];

    return 1;
}
