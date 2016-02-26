#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

static int core_getObjectMetatable(lua_State *L) {
    LuaSkin *skin = [LuaSkin performSelector:@selector(thread)]; //[LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK];
    luaL_getmetatable(L, lua_tostring(L,1));
    return 1;
}

static int core_cleanUTF8(lua_State *L) {
    LuaSkin *skin = [LuaSkin performSelector:@selector(thread)]; //[LuaSkin shared] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    [skin pushNSObject:[skin getValidUTF8AtIndex:1]] ;
    return 1 ;
}


#pragma mark - Module Methods

#pragma mark - Hammerspoon/Lua Infrastructure

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
//     {"openConsole",                  core_openconsole},
//     {"consoleOnTop",                 core_consoleontop},
//     {"openAbout",                    core_openabout},
//     {"menuIcon",                     core_menuicon},
//     {"openPreferences",              core_openpreferences},
//     {"autoLaunch",                   core_autolaunch},
//     {"automaticallyCheckForUpdates", automaticallyChecksForUpdates},
//     {"checkForUpdates",              checkForUpdates},
//     {"reload",                    // handled by _instance:reload()
//     {"focus",                        core_focus},
//     {"accessibilityState",           core_accessibilityState},
    {"getObjectMetatable",           core_getObjectMetatable},
    {"cleanUTF8forConsole",          core_cleanUTF8},
//     {"_exit",                     // handled by _instance:cancel()
//     {"_logmessage",               // not needed for luathread implementation of print
//     {"_notify",                      core_notify},
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__luathreadcoreadditions_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin performSelector:@selector(thread)]; //[LuaSkin shared] ;
    [skin registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib

    return 1;
}
