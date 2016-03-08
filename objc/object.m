#import "objc.h"

static int refTable = LUA_NOREF;

#pragma mark - Module Functions

#pragma mark - Module Methods

static int objc_object_getClassName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, ID_USERDATA_TAG, LS_TBREAK] ;
    id obj = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    lua_pushstring(L, object_getClassName(obj)) ;
    return 1 ;
}

static int objc_object_getClass(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, ID_USERDATA_TAG, LS_TBREAK] ;
    id obj = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    push_class(L, object_getClass(obj)) ;
    return 1 ;
}

static int object_value(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, ID_USERDATA_TAG, LS_TBREAK] ;
    id obj = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    [skin pushNSObject:obj withOptions:LS_NSUnsignedLongLongPreserveBits |
                                       LS_NSDescribeUnknownTypes         |
                                       LS_NSPreserveLuaStringExactly] ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions

int push_object(lua_State *L, id obj) {
#if defined(DEBUG_GC) || defined(DEBUG_GC_OBJONLY)
    [[LuaSkin shared] logDebug:[NSString stringWithFormat:@"object: create %@ (%p)", [obj class], obj]] ;
#endif
    if (obj) {
        void** thePtr = lua_newuserdata(L, sizeof(id)) ;
        *thePtr = (__bridge_retained void *)obj ;
        luaL_getmetatable(L, ID_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int object_userdata_tostring(lua_State* L) {
    id obj = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", ID_USERDATA_TAG, object_getClassName(obj), obj) ;
    return 1 ;
}

static int object_userdata_eq(lua_State* L) {
    id obj1 = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    id obj2 = get_objectFromUserdata(__bridge id, L, 2, ID_USERDATA_TAG) ;
    lua_pushboolean(L, [obj1 isEqual:obj2]) ;
    return 1 ;
}

static int object_userdata_gc(lua_State* L) {
    id __unused obj = get_objectFromUserdata(__bridge_transfer id, L, 1, ID_USERDATA_TAG) ;
#if defined(DEBUG_GC) || defined(DEBUG_GC_OBJONLY)
    [[LuaSkin shared] logDebug:[NSString stringWithFormat:@"object: remove %@ (%p)", [obj class], obj]] ;
#endif

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int object_meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg object_userdata_metaLib[] = {
    {"class",      objc_object_getClass},
    {"className",  objc_object_getClassName},
    {"value",      object_value},

    {"__tostring", object_userdata_tostring},
    {"__eq",       object_userdata_eq},
    {"__gc",       object_userdata_gc},
    {NULL,         NULL}
};

// Functions for returned obj when module loads
static luaL_Reg object_moduleLib[] = {
    {NULL, NULL}
};

// Metatable for module, if needed
// static const luaL_Reg object_module_metaLib[] = {
//     {"__gc", object_meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_object(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:ID_USERDATA_TAG
                                     functions:object_moduleLib
                                 metaFunctions:nil // object_module_metaLib
                               objectFunctions:object_userdata_metaLib];

    return 1;
}
