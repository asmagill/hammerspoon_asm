#import <Cocoa/Cocoa.h>
// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"
#import "objc.h"

static int refTable ;

#pragma mark - Module Functions

#pragma mark - Module Methods

static int objc_ivar_getName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, IVAR_USERDATA_TAG, LS_TBREAK] ;
    Ivar iv = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
    lua_pushstring(L, ivar_getName(iv)) ;
    return 1 ;
}

static int objc_ivar_getTypeEncoding(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, IVAR_USERDATA_TAG, LS_TBREAK] ;
    Ivar iv = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
    lua_pushstring(L, ivar_getTypeEncoding(iv)) ;
    return 1 ;
}

static int objc_ivar_getOffset(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, IVAR_USERDATA_TAG, LS_TBREAK] ;
    Ivar iv = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
    lua_pushinteger(L, ivar_getOffset(iv)) ;
    return 1 ;
}

#pragma mark - Lua Framework

static int userdata_tostring(lua_State* L) {
    Ivar iv = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", IVAR_USERDATA_TAG, ivar_getName(iv), iv) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    Ivar iv1 = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
    Ivar iv2 = get_objectFromUserdata(Ivar, L, 2, IVAR_USERDATA_TAG) ;
    lua_pushboolean(L, (iv1 == iv2)) ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    __unused Ivar iv = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;

// Clear the pointer so it's no longer dangling
    void** thePtr = lua_touserdata(L, 1);
    *thePtr = nil ;

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"name",         objc_ivar_getName},
    {"typeEncoding", objc_ivar_getTypeEncoding},
    {"offset",       objc_ivar_getOffset},

    {"__tostring",   userdata_tostring},
    {"__eq",         userdata_eq},
    {"__gc",         userdata_gc},
    {NULL,           NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_objc_ivar(lua_State* __unused L) {
// Use this if your module doesn't have a module specific object that it returns.
//    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [[LuaSkin shared] registerLibraryWithObject:IVAR_USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

    return 1;
}
