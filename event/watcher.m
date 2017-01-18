@import Cocoa ;
@import LuaSkin ;

@class HSEventThreadManager ;

#define USERDATA_TAG "hs.events.watcher"
static int refTable = LUA_NOREF;
static HSEventThreadManager *threadManager ;

// #define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSEventThreadManager : NSObject
@property NSMutableDictionary *eventWatchers ;
@property NSThread            *watcherThread ;
@property NSRunLoop           *threadRunLoop ;
@property NSTimer             *keepAliveTimer ;
@end

@implementation HSEventThreadManager

- (instancetype)init {
    self = [super init] ;
    if (self) {
        _eventWatchers  = [[NSMutableDictionary alloc] init] ;
        _threadRunLoop  = nil ;
        _keepAliveTimer = nil ;

        _watcherThread  = [[NSThread alloc] initWithTarget:self
                                                  selector:@selector(backgroundThread:)
                                                    object:nil] ;
        [_watcherThread start] ;
    }
    return self ;
}

- (void)backgroundKeepAlive:(__unused NSTimer *)timer {
    NSAssert((![NSThread isMainThread]), @"%s:backgroundKeepAlive: method should not be invoked on main thread", USERDATA_TAG) ;
    // twiddle thumbs
    // we're just along for the ride so the runloop in the background thread can actually run
}

- (void)backgroundThread:(__unused id)object {
    NSAssert((![NSThread isMainThread]), @"%s:backgroundThread: method should not be invoked on main thread", USERDATA_TAG) ;

    @autoreleasepool {
        _threadRunLoop = [NSRunLoop currentRunLoop] ;

        // a run loop needs an input source or a timer to be runable, so...
        _keepAliveTimer = [NSTimer timerWithTimeInterval:60.0
                                                  target:self
                                                selector:@selector(backgroundKeepAlive:)
                                                userInfo:nil
                                                 repeats:YES] ;
        [_threadRunLoop addTimer:_keepAliveTimer forMode:NSDefaultRunLoopMode] ;
        BOOL runLoopValid = YES ;
        while (!_watcherThread.cancelled && runLoopValid) {
            runLoopValid = [_threadRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]] ;
        }
        if (!runLoopValid) {
            [LuaSkin logError:[NSString stringWithFormat:@"%s:backgroundThread: runloop failed to start", USERDATA_TAG]] ;
        }
        if (_keepAliveTimer && _keepAliveTimer.valid) [_keepAliveTimer invalidate] ;
        _keepAliveTimer = nil ;
        _threadRunLoop = nil ;
    }
}

- (void)cancelThread:(__unused id)sender {
    if ([NSThread currentThread] == _watcherThread) {
        if (_keepAliveTimer && _keepAliveTimer.valid) [_keepAliveTimer invalidate] ;
        _keepAliveTimer = nil ;
        [_watcherThread cancel] ;
    } else if (_watcherThread) {
        [self performSelector:@selector(cancelThread:)
                     onThread:_watcherThread
                   withObject:nil
                waitUntilDone:YES] ;
    }
}

@end

#pragma mark - Module Functions

static int watcher_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TFUNCTION, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
}

#pragma mark - Module Methods

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

// static int push<moduleType>(lua_State *L, id obj) {
//     <moduleType> *value = obj;
//     void** valuePtr = lua_newuserdata(L, sizeof(<moduleType> *));
//     *valuePtr = (__bridge_retained void *)value;
//     luaL_getmetatable(L, USERDATA_TAG);
//     lua_setmetatable(L, -2);
//     return 1;
// }
//
// id to<moduleType>FromLua(lua_State *L, int idx) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     <moduleType> *value ;
//     if (luaL_testudata(L, idx, USERDATA_TAG)) {
//         value = get_objectFromUserdata(__bridge <moduleType>, L, idx, USERDATA_TAG) ;
//     } else {
//         [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
//                                                    lua_typename(L, lua_type(L, idx))]] ;
//     }
//     return value ;
// }

#pragma mark - Hammerspoon/Lua Infrastructure

// static int userdata_tostring(lua_State* L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     <moduleType> *obj = [skin luaObjectAtIndex:1 toClass:"<moduleType>"] ;
//     NSString *title = ... ;
//     [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
//     return 1 ;
// }

// static int userdata_eq(lua_State* L) {
// // can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// // so use luaL_testudata before the macro causes a lua error
//     if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
//         LuaSkin *skin = [LuaSkin shared] ;
//         <moduleType> *obj1 = [skin luaObjectAtIndex:1 toClass:"<moduleType>"] ;
//         <moduleType> *obj2 = [skin luaObjectAtIndex:2 toClass:"<moduleType>"] ;
//         lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
//     } else {
//         lua_pushboolean(L, NO) ;
//     }
//     return 1 ;
// }

// static int userdata_gc(lua_State* L) {
//     <moduleType> *obj = get_objectFromUserdata(__bridge_transfer <moduleType>, L, 1, USERDATA_TAG) ;
//     if (obj) obj = nil ;
//     // Remove the Metatable so future use of the variable in Lua won't think its valid
//     lua_pushnil(L) ;
//     lua_setmetatable(L, 1) ;
//     return 0 ;
// }

static int meta_gc(lua_State* __unused L) {
    if (threadManager) [threadManager cancelThread:nil];
    threadManager = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
//     {"__tostring", userdata_tostring},
//     {"__eq",       userdata_eq},
//     {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {NULL, NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs_events_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    threadManager = [[HSEventThreadManager alloc] init] ;
//     [skin registerPushNSHelper:push<moduleType>         forClass:"<moduleType>"];

// // one, but not both, of...
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"
//                                              withUserdataMapping:USERDATA_TAG];
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"];

    return 1;
}
