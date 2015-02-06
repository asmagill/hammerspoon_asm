#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>

// Common Code

#define USERDATA_TAG    "{PATH}.{MODULE}"

static int store_udhandler(lua_State* L, NSMutableIndexSet* theHandler, int idx) {
    lua_pushvalue(L, idx);
    int x = luaL_ref(L, LUA_REGISTRYINDEX);
    [theHandler addIndex: x];
    return x;
}

static void remove_udhandler(lua_State* L, NSMutableIndexSet* theHandler, int x) {
    luaL_unref(L, LUA_REGISTRYINDEX, x);
    [theHandler removeIndex: x];
}

// static void* push_udhandler(lua_State* L, int x) {
//     lua_rawgeti(L, LUA_REGISTRYINDEX, x);
//     return lua_touserdata(L, -1);
// }

// Not so common code

static NSMutableIndexSet* <name>Handlers;


/// {PATH}.{MODULE}.function() -> return
/// Function
///
static int function(lua_State* __unused L) {

    return 0;
}

// Metatable for created objects when _new invoked
static const luaL_Reg <name>_metalib[] = {
    {NULL,                          NULL}
};

// Functions for returned object when module loads
static const luaL_Reg {MODULE}Lib[] = {
    {NULL,              NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_{F_PATH}_{MODULE}_internal(lua_State* L) {
    notification_delegate_setup(L);

// Metatable for created objects
    luaL_newlib(L, <name>_metalib);
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        lua_setfield(L, LUA_REGISTRYINDEX, USERDATA_TAG);

// Create table for luaopen
    luaL_newlib(L, {MODULE}Lib);
        luaL_newlib(L, meta_gcLib);
        lua_setmetatable(L, -2);

    return 1;
}
