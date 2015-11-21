#import <Cocoa/Cocoa.h>
// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#define USERDATA_TAG        "hs._asm.nstask"
int refTable ;

#define get_objectFromUserdata(objType, L, idx) (__bridge objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

static int nstask_new(lua_State *L) {
    NSTask *theTask = [[NSTask alloc] init] ;

    [theTask setEnvironment:[[[NSProcessInfo processInfo] environment] copy]] ;

    void** taskPtr = lua_newuserdata(L, sizeof(NSTask *));
    *taskPtr = (__bridge_retained void *)theTask;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1 ;
}

static int nstask_arguments(lua_State *L) {
    NSTask *theTask = get_objectFromUserdata(NSTask, L, 1) ;

    return [[LuaSkin shared] pushNSObject:[theTask arguments]] ;
}

static int nstask_currentDirectoryPath(lua_State *L) {
    NSTask *theTask = get_objectFromUserdata(NSTask, L, 1) ;

    return [[LuaSkin shared] pushNSObject:[theTask currentDirectoryPath]] ;
}

static int nstask_environment(lua_State *L) {
    NSTask *theTask = get_objectFromUserdata(NSTask, L, 1) ;

    return [[LuaSkin shared] pushNSObject:[theTask environment]] ;
}

static int nstask_launchPath(lua_State *L) {
    NSTask *theTask = get_objectFromUserdata(NSTask, L, 1) ;

    return [[LuaSkin shared] pushNSObject:[theTask launchPath]] ;
}

static int nstask_processIdentifier(lua_State *L) {
    NSTask *theTask = get_objectFromUserdata(NSTask, L, 1) ;
    lua_pushinteger(L, [theTask processIdentifier]) ;
    return 1 ;
}

static int nstask_standardError(lua_State *L) {
    NSTask *theTask = get_objectFromUserdata(NSTask, L, 1) ;

    return [[LuaSkin shared] pushNSObject:[theTask standardError]] ;
}

static int nstask_standardInput(lua_State *L) {
    NSTask *theTask = get_objectFromUserdata(NSTask, L, 1) ;

    return [[LuaSkin shared] pushNSObject:[theTask standardInput]] ;
}

static int nstask_standardOutput(lua_State *L) {
    NSTask *theTask = get_objectFromUserdata(NSTask, L, 1) ;

    return [[LuaSkin shared] pushNSObject:[theTask standardOutput]] ;
}


static int userdata_tostring(lua_State* L) {
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

// static int userdata_eq(lua_State* L) {
// }

static int userdata_gc(lua_State* L) {
    NSTask *theTask = (__bridge_transfer NSTask*)*((void**)luaL_checkudata(L, 1, USERDATA_TAG)) ;
    if ([theTask isRunning]) {
        [theTask terminate] ;
    }
    theTask = nil ;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     [hsimageReferences removeAllIndexes];
//     hsimageReferences = nil;
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"arguments",            nstask_arguments},
    {"currentDirectoryPath", nstask_currentDirectoryPath},
    {"environment",          nstask_environment},
    {"launchPath",           nstask_launchPath},
    {"processIdentifier",    nstask_processIdentifier},
    {"standardError",        nstask_standardError},
    {"standardInput",        nstask_standardInput},
    {"standardOutput",       nstask_standardOutput},
    {"__tostring",           userdata_tostring},
//     {"__eq",                userdata_eq},
    {"__gc",                 userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", nstask_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_nstask_internal(lua_State* __unused L) {
// Use this if your module doesn't have a module specific object that it returns.
//    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [[LuaSkin shared] registerLibraryWithObject:USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

    return 1;
}
