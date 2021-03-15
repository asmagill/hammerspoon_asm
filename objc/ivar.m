/// === hs._asm.objc.ivar ===
///
/// The submodule for hs._asm.objc which provides methods for working with and examining Objective-C object instance variables.
///
/// Except in rare cases, instance variables back properties and should generally be accessed only as properties or with the getter and setter methods provided.  This module is provided for informational purposes only.

#import "objc.h"

static LSRefTable refTable = LUA_NOREF;

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

#pragma mark - Module Methods

/// hs._asm.objc.ivar:name() -> string
/// Method
/// Returns the name of an instance variable.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the name of the instance variable
static int objc_ivar_getName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, IVAR_USERDATA_TAG, LS_TBREAK] ;
    Ivar iv = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
    lua_pushstring(L, ivar_getName(iv)) ;
    return 1 ;
}

/// hs._asm.objc.ivar:typeEncoding() -> string
/// Method
/// Returns the type string of an instance variable.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the instance variable's type encoding
///
/// Notes:
///  * Type encoding strings are encoded as described at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
static int objc_ivar_getTypeEncoding(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, IVAR_USERDATA_TAG, LS_TBREAK] ;
    Ivar iv = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
    lua_pushstring(L, ivar_getTypeEncoding(iv)) ;
    return 1 ;
}

/// hs._asm.objc.ivar:offset() -> integer
/// Method
/// Returns the offset of an instance variable.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the offset of an instance variable.
static int objc_ivar_getOffset(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, IVAR_USERDATA_TAG, LS_TBREAK] ;
    Ivar iv = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
    lua_pushinteger(L, ivar_getOffset(iv)) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions

int push_ivar(lua_State *L, Ivar iv) {
#if defined(DEBUG_GC)
    [LuaSkin logDebug:[NSString stringWithFormat:@"ivar: create %s (%p)", ivar_getName(iv), iv]] ;
#endif
    if (iv) {
        void** thePtr = lua_newuserdata(L, sizeof(Ivar)) ;
        *thePtr = (void *)iv ;
        luaL_getmetatable(L, IVAR_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int ivar_userdata_tostring(lua_State* L) {
    Ivar iv = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s {%s} (%p)", IVAR_USERDATA_TAG, ivar_getName(iv), ivar_getTypeEncoding(iv), iv) ;
    return 1 ;
}

static int ivar_userdata_eq(lua_State* L) {
    Ivar iv1 = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
    Ivar iv2 = get_objectFromUserdata(Ivar, L, 2, IVAR_USERDATA_TAG) ;
    lua_pushboolean(L, (iv1 == iv2)) ;
    return 1 ;
}

static int ivar_userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    Ivar __unused iv = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
#if defined(DEBUG_GC)
    [LuaSkin logDebug:[NSString stringWithFormat:@"ivar: remove %s (%p)", ivar_getName(iv), iv]] ;
#endif

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int ivar_meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg ivar_userdata_metaLib[] = {
    {"name",         objc_ivar_getName},
    {"typeEncoding", objc_ivar_getTypeEncoding},
    {"offset",       objc_ivar_getOffset},

    {"__tostring",   ivar_userdata_tostring},
    {"__eq",         ivar_userdata_eq},
    {"__gc",         ivar_userdata_gc},
    {NULL,           NULL}
};

// Functions for returned object when module loads
static luaL_Reg ivar_moduleLib[] = {
    {NULL, NULL}
};

// Metatable for module, if needed
// static const luaL_Reg ivar_module_metaLib[] = {
//     {"__gc", ivar_meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_ivar(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:IVAR_USERDATA_TAG
                                     functions:ivar_moduleLib
                                 metaFunctions:nil // ivar_module_metaLib
                               objectFunctions:ivar_userdata_metaLib];

    return 1;
}
