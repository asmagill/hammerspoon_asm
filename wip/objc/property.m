#import <Cocoa/Cocoa.h>
// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"
#import "objc.h"

static int refTable ;

#pragma mark - Module Functions

#pragma mark - Module Methods

static int objc_property_getName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROPERTY_USERDATA_TAG, LS_TBREAK] ;
    objc_property_t prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
    lua_pushstring(L, property_getName(prop)) ;
    return 1 ;
}

static int objc_property_getAttributes(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROPERTY_USERDATA_TAG, LS_TBREAK] ;
    objc_property_t prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
    lua_pushstring(L, property_getAttributes(prop)) ;
    return 1 ;
}

static int objc_property_getAttributeValue(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROPERTY_USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    objc_property_t prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
    const char      *result = property_copyAttributeValue(prop, luaL_checkstring(L, 2)) ;

    lua_pushstring(L, result) ;
    free((void *)result) ;
    return 1 ;
}

static int objc_property_getAttributeList(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROPERTY_USERDATA_TAG, LS_TBREAK] ;
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

#pragma mark - Lua Framework

static int userdata_tostring(lua_State* L) {
    objc_property_t prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", PROPERTY_USERDATA_TAG, property_getName(prop), prop) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    objc_property_t prop1 = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
    objc_property_t prop2 = get_objectFromUserdata(objc_property_t, L, 2, PROPERTY_USERDATA_TAG) ;
    lua_pushboolean(L, (prop1 == prop2)) ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    __unused objc_property_t prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;

// Clear the pointer so its not pointing at anything
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
    {"attributeValue", objc_property_getAttributeValue},
    {"attributes",     objc_property_getAttributes},
    {"name",           objc_property_getName},
    {"attributeList",  objc_property_getAttributeList},

    {"__tostring",     userdata_tostring},
    {"__eq",           userdata_eq},
    {"__gc",           userdata_gc},
    {NULL,             NULL}
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
int luaopen_hs__asm_objc_property(lua_State* __unused L) {
// Use this if your module doesn't have a module specific object that it returns.
//    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [[LuaSkin shared] registerLibraryWithObject:PROPERTY_USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

    return 1;
}
