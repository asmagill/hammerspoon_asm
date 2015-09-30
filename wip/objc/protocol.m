#import <Cocoa/Cocoa.h>
// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"
#import "objc.h"

static int refTable ;

#pragma mark - Module Functions

static int objc_protocolFromString(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TSTRING, LS_TBREAK] ;
    Protocol *prot = objc_getProtocol(luaL_checkstring(L, 1)) ;

    push_protocol(L, prot) ;
    return 1 ;
}

static int objc_protocolList(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;

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

static int objc_protocol_getName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    lua_pushstring(L, protocol_getName(prot)) ;
    return 1 ;
}

static int objc_protocol_getPropertyList(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG, LS_TBREAK] ;
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

static int objc_protocol_getProperty(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG,
                                LS_TSTRING,
                                LS_TBOOLEAN,
                                LS_TBOOLEAN, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    push_property(L, protocol_getProperty(prot, luaL_checkstring(L, 2),
                                             (BOOL)lua_toboolean(L, 3),
                                             (BOOL)lua_toboolean(L, 4))) ;
    return 1 ;
}


static int objc_protocol_getAdoptedProtocols(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG, LS_TBREAK] ;
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

static int objc_protocol_conformsToProtocol(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG,
                                LS_TUSERDATA, PROTOCOL_USERDATA_TAG, LS_TBREAK] ;
    Protocol *prot1 = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    Protocol *prot2 = get_objectFromUserdata(__bridge Protocol *, L, 2, PROTOCOL_USERDATA_TAG) ;
    lua_pushboolean(L, protocol_conformsToProtocol(prot1, prot2)) ;
    return 1 ;
}

static int objc_protocol_getMethodDescriptionList(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG,
                                LS_TBOOLEAN,
                                LS_TBOOLEAN, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    UInt count ;
    struct objc_method_description *results = protocol_copyMethodDescriptionList(prot,
                                                                (BOOL)lua_toboolean(L, 2),
                                                                (BOOL)lua_toboolean(L, 3),
                                                                      &count) ;
    lua_newtable(L) ;
    for(UInt i = 0 ; i < count ; i++) {
        lua_newtable(L) ;
          lua_pushstring(L, results[i].types) ; lua_setfield(L, -2, "types") ;
          push_selector(L, results[i].name)   ; lua_setfield(L, -2, "selector") ;
//         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_setfield(L, -2, sel_getName(results[i].name)) ;
    }
    if (results) free(results) ;
    return 1 ;
}

static int objc_protocol_getMethodDescription(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG,
                                LS_TUSERDATA, SEL_USERDATA_TAG,
                                LS_TBOOLEAN,
                                LS_TBOOLEAN, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    SEL      sel   = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;

    struct objc_method_description  result = protocol_getMethodDescription(prot, sel,
                                                                (BOOL)lua_toboolean(L, 3),
                                                                (BOOL)lua_toboolean(L, 4)) ;
    if (result.types == NULL || result.name == NULL) {
        lua_pushnil(L) ;
    } else {
        lua_newtable(L) ;
          lua_pushstring(L, result.types) ; lua_setfield(L, -2, "types") ;
          push_selector(L, result.name)   ; lua_setfield(L, -2, "selector") ;
    }
    return 1 ;
}

#pragma mark - Lua Framework

static int userdata_tostring(lua_State* L) {
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", PROTOCOL_USERDATA_TAG, protocol_getName(prot), prot) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    Protocol *prot1 = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    Protocol *prot2 = get_objectFromUserdata(__bridge Protocol *, L, 2, PROTOCOL_USERDATA_TAG) ;
    lua_pushboolean(L, protocol_isEqual(prot1, prot2)) ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
// since we don't retain, we don't need to transfer, but this does check to make sure we're
// not called with the wrong type for some reason...
    __unused Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;

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
    {"name",                  objc_protocol_getName},
    {"propertyList",          objc_protocol_getPropertyList},
    {"property",              objc_protocol_getProperty},
    {"adoptedProtocols",      objc_protocol_getAdoptedProtocols},
    {"conformsToProtocol",    objc_protocol_conformsToProtocol},
    {"methodDescriptionList", objc_protocol_getMethodDescriptionList},
    {"methodDescription",     objc_protocol_getMethodDescription},

    {"__tostring",            userdata_tostring},
    {"__eq",                  userdata_eq},
    {"__gc",                  userdata_gc},
    {NULL,                    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"fromString", objc_protocolFromString},
    {"list",       objc_protocolList},

    {NULL,         NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_objc_protocol(lua_State* __unused L) {
// Use this if your module doesn't have a module specific object that it returns.
//    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [[LuaSkin shared] registerLibraryWithObject:PROTOCOL_USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

    return 1;
}
