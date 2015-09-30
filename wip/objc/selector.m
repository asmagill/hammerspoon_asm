#import <Cocoa/Cocoa.h>
// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"
#import "objc.h"

static int refTable ;

#pragma mark - Module Functions

// sel_registerName (which is what NSSelectorFromString uses) creates the selector, even if it doesn't
// exist yet... so, no fromString function here.  See init.lua which adds selector methods to class,
// protocol, and object which check for the selector string in the "current" context without creating
// anything that doesn't already exist yet.

#pragma mark - Module Methods

static int objc_sel_getName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, SEL_USERDATA_TAG, LS_TBREAK] ;
    SEL sel = get_objectFromUserdata(SEL, L, 1, SEL_USERDATA_TAG) ;
    lua_pushstring(L, sel_getName(sel)) ;
    return 1 ;
}

#pragma mark - Lua Framework

static int userdata_tostring(lua_State* L) {
    SEL sel = get_objectFromUserdata(SEL, L, 1, SEL_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", SEL_USERDATA_TAG, sel_getName(sel), sel) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    SEL sel1 = get_objectFromUserdata(SEL, L, 1, SEL_USERDATA_TAG) ;
    SEL sel2 = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;
    lua_pushboolean(L, sel_isEqual(sel1, sel2)) ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    __unused SEL sel = get_objectFromUserdata(SEL, L, 1, SEL_USERDATA_TAG) ;

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
    {"name",       objc_sel_getName},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
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
int luaopen_hs__asm_objc_selector(lua_State* __unused L) {
// Use this if your module doesn't have a module specific object that it returns.
//    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [[LuaSkin shared] registerLibraryWithObject:SEL_USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

    return 1;
}
