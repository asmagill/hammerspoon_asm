#import <Cocoa/Cocoa.h>
// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"
#import "objc.h"

static int refTable ;

#pragma mark - Module Functions

#pragma mark - Module Methods

static int objc_method_getName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    push_selector(L, method_getName(meth)) ;
    return 1 ;
}

static int objc_method_getTypeEncoding(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    lua_pushstring(L, method_getTypeEncoding(meth)) ;
    return 1 ;
}

static int objc_method_getReturnType(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    const char      *result = method_copyReturnType(meth) ;

    lua_pushstring(L, result) ;
    free((void *)result) ;
    return 1 ;
}

static int objc_method_getArgumentType(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TNUMBER, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    const char      *result = method_copyArgumentType(meth, (UInt)luaL_checkinteger(L, 2)) ;

    lua_pushstring(L, result) ;
    free((void *)result) ;
    return 1 ;
}

static int objc_method_getNumberOfArguments(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    lua_pushinteger(L, method_getNumberOfArguments(meth)) ;
    return 1 ;
}

static int objc_method_getDescription(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;

    struct objc_method_description *result = method_getDescription(meth) ;
    lua_newtable(L) ;
      lua_pushstring(L, result->types) ; lua_setfield(L, -2, "types") ;
      push_selector(L, result->name)   ; lua_setfield(L, -2, "selector") ;
    return 1 ;
}

#pragma mark - Lua Framework

static int userdata_tostring(lua_State* L) {
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", METHOD_USERDATA_TAG, method_getName(meth), meth) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    Method meth1 = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    Method meth2 = get_objectFromUserdata(Method, L, 2, METHOD_USERDATA_TAG) ;
    lua_pushboolean(L, (meth1 == meth2)) ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    __unused Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;

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
    {"selector",          objc_method_getName},
    {"typeEncoding",      objc_method_getTypeEncoding},
    {"returnType",        objc_method_getReturnType},
    {"argumentType",      objc_method_getArgumentType},
    {"numberOfArguments", objc_method_getNumberOfArguments},
    {"description",       objc_method_getDescription},

    {"__tostring",        userdata_tostring},
    {"__eq",              userdata_eq},
    {"__gc",              userdata_gc},
    {NULL,                NULL}
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
int luaopen_hs__asm_objc_method(lua_State* __unused L) {
// Use this if your module doesn't have a module specific object that it returns.
//    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [[LuaSkin shared] registerLibraryWithObject:METHOD_USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

    return 1;
}
