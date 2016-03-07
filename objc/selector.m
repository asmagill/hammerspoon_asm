#import "objc.h"

static int refTable = LUA_NOREF;

#pragma mark - Module Functions

// sel_registerName/sel_getUid (which is what NSSelectorFromString uses) creates the selector, even if it doesn't exist yet, so it can't be used to verify that a selector is a valid message for any, much less a specific, class. See init.lua which adds selector methods to class, protocol, and object which check for the selector string in the "current" context without creating anything that doesn't already exist yet.
static int objc_sel_selectorFromName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    push_selector(L, sel_getUid(luaL_checkstring(L, 1))) ;
    return 1 ;
}

#pragma mark - Module Methods

static int objc_sel_getName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, SEL_USERDATA_TAG, LS_TBREAK] ;
    SEL sel = get_objectFromUserdata(SEL, L, 1, SEL_USERDATA_TAG) ;
    lua_pushstring(L, sel_getName(sel)) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions

int push_selector(lua_State *L, SEL sel) {
#if defined(DEBUG_GC)
    [[LuaSkin shared] logDebug:[NSString stringWithFormat:@"selector: create %@ (%p)", NSStringForSelector(sel), sel]] ;
#endif
    if (sel) {
        void** thePtr = lua_newuserdata(L, sizeof(SEL)) ;
        *thePtr = (void *)sel ;
        luaL_getmetatable(L, SEL_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int selector_userdata_tostring(lua_State* L) {
    SEL sel = get_objectFromUserdata(SEL, L, 1, SEL_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", SEL_USERDATA_TAG, sel_getName(sel), sel) ;
    return 1 ;
}

static int selector_userdata_eq(lua_State* L) {
    SEL sel1 = get_objectFromUserdata(SEL, L, 1, SEL_USERDATA_TAG) ;
    SEL sel2 = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;
    lua_pushboolean(L, sel_isEqual(sel1, sel2)) ;
    return 1 ;
}

static int selector_userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    SEL __unused sel = get_objectFromUserdata(SEL, L, 1, SEL_USERDATA_TAG) ;
#if defined(DEBUG_GC)
    [[LuaSkin shared] logDebug:[NSString stringWithFormat:@"selector: remove %@ (%p)", NSStringForSelector(sel), sel]] ;
#endif

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int selector_meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg selector_userdata_metaLib[] = {
    {"name",       objc_sel_getName},

    {"__tostring", selector_userdata_tostring},
    {"__eq",       selector_userdata_eq},
    {"__gc",       selector_userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg selector_moduleLib[] = {
    {"fromString", objc_sel_selectorFromName},

    {NULL,         NULL}
};

// Metatable for module, if needed
// static const luaL_Reg selector_module_metaLib[] = {
//     {"__gc", selector_meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_selector(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:SEL_USERDATA_TAG
                                     functions:selector_moduleLib
                                 metaFunctions:nil // selector_module_metaLib
                               objectFunctions:selector_userdata_metaLib];

    return 1;
}
