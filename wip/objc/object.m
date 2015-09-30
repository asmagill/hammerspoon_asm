#import <Cocoa/Cocoa.h>
// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"
#import "objc.h"

static int refTable ;

#pragma mark - Module Functions

#pragma mark - Module Methods

static int objc_object_getClassName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, ID_USERDATA_TAG, LS_TBREAK] ;
    id obj = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    lua_pushstring(L, object_getClassName(obj)) ;
    return 1 ;
}

static int objc_object_getClass(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, ID_USERDATA_TAG, LS_TBREAK] ;
    id obj = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    push_class(L, object_getClass(obj)) ;
    return 1 ;
}

#pragma mark - Lua Framework

static int userdata_tostring(lua_State* L) {
    id obj = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", ID_USERDATA_TAG, object_getClassName(obj), obj) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    id obj1 = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    id obj2 = get_objectFromUserdata(__bridge id, L, 2, ID_USERDATA_TAG) ;
    lua_pushboolean(L, [obj1 isEqual:obj2]) ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    id obj = get_objectFromUserdata(__bridge_transfer id, L, 1, ID_USERDATA_TAG) ;
    obj = nil ;

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
    {"class",       objc_object_getClass},
    {"className",   objc_object_getClassName},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned obj when module loads
static luaL_Reg moduleLib[] = {
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_objc_object(lua_State* __unused L) {
// Use this if your module doesn't have a module specific obj that it returns.
//    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific obj unique to this module
    refTable = [[LuaSkin shared] registerLibraryWithObject:ID_USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

    return 1;
}
