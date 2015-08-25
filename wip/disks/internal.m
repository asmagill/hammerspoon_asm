#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#define USERDATA_TAG        "hs._asm.disks"
int refTable ;

@interface HSDiskWatcherClass : NSObject
    @property int fn;
@end

@implementation HSDiskWatcherClass
    - (void) _heard:(id)note {
// make sure we perform this on the main thread... Hammerspoon crashes when lua code
// executes on any other thread.
        [self performSelectorOnMainThread:@selector(heard:)
                                            withObject:note
                                            waitUntilDone:YES];
    }

    - (void) heard:(NSNotification*)note {
        if (self.fn != LUA_NOREF) {
            lua_State *_L = [[LuaSkin shared] L];
            lua_rawgeti(_L, LUA_REGISTRYINDEX, self.fn);
            lua_pushstring(_L, [[note name] UTF8String]);

            [[LuaSkin shared] pushNSObject:note.userInfo] ;

            if (![[LuaSkin shared] protectedCallAndTraceback:2 nresults:0]) {
                const char *errorMsg = lua_tostring(_L, -1);
                showError(_L, (char *)errorMsg);
            }
        }
    }
@end

static int newObserver(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);

    HSDiskWatcherClass* listener = [[HSDiskWatcherClass alloc] init];

    lua_pushvalue(L, 1);
    listener.fn               = luaL_ref(L, LUA_REGISTRYINDEX) ;

    void** ud = lua_newuserdata(L, sizeof(id*)) ;
    *ud = (__bridge_retained void*)listener ;

    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;

    return 1;
}

static int startObserver(lua_State* L) {
    HSDiskWatcherClass* listener = (__bridge HSDiskWatcherClass*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter] ;

    [center addObserver:listener
               selector:@selector(_heard:)
                   name:NSWorkspaceDidMountNotification
                 object:nil];
    [center addObserver:listener
               selector:@selector(_heard:)
                   name:NSWorkspaceWillUnmountNotification
                 object:nil];
    [center addObserver:listener
               selector:@selector(_heard:)
                   name:NSWorkspaceDidUnmountNotification
                 object:nil];
    lua_settop(L,1);
    return 1;
}

static int stopObserver(lua_State* L) {
    HSDiskWatcherClass* listener = (__bridge HSDiskWatcherClass*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter] ;

    [center removeObserver:listener
                      name:NSWorkspaceDidMountNotification
                    object:nil];
    [center removeObserver:listener
                      name:NSWorkspaceWillUnmountNotification
                    object:nil];
    [center removeObserver:listener
                      name:NSWorkspaceDidUnmountNotification
                    object:nil];
    lua_settop(L,1);
    return 1;
}

// Not that useful, but at least we know what type of userdata it is, instead of just "userdata".
static int userdata_tostring(lua_State* L) {
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    // stop observer, if running, and clean up after ourselves.

    stopObserver(L) ;
    HSDiskWatcherClass* listener = (__bridge_transfer HSDiskWatcherClass*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    listener.fn = [[LuaSkin shared] luaUnref:refTable ref:listener.fn];
    listener = nil ;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     [hsimageReferences removeAllIndexes];
//     hsimageReferences = nil;
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"start",      startObserver},
    {"stop",       stopObserver},
    {"__tostring", userdata_tostring},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", newObserver},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_disks_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil // nil or module_metaLib
                               objectFunctions:userdata_metaLib ]; // nil or userdata_metaLib

    return 1;
}
