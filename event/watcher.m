@import Cocoa ;
@import LuaSkin ;

@class HSEventThreadManager ;

static const char * const USERDATA_TAG = "hs.events.watcher" ;
static int refTable = LUA_NOREF;
static HSEventThreadManager *threadManager ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static NSString *CGErrorToString(CGError error) {
    NSString *message ;
    switch(error) {
        case kCGErrorSuccess:
            message = @"The requested operation was completed successfully." ;
            break ;
        case kCGErrorFailure:
            message = @"A general failure occurred." ;
            break ;
        case kCGErrorIllegalArgument:
            message = @"One or more of the parameters passed to a function are invalid. Check for NULL pointers." ;
            break ;
        case kCGErrorInvalidConnection:
            message = @"The parameter representing a connection to the window server is invalid." ;
            break ;
        case kCGErrorInvalidContext:
            message = @"The CPSProcessSerNum or context identifier parameter is not valid." ;
            break ;
        case kCGErrorCannotComplete:
            message = @"The requested operation is inappropriate for the parameters passed in, or the current system state." ;
            break ;
        case kCGErrorNotImplemented:
            message = @"Return value from obsolete function stubs present for binary compatibility, but not normally called." ;
            break ;
        case kCGErrorRangeCheck:
            message = @"A parameter passed in has a value that is inappropriate, or which does not map to a useful operation or value." ;
            break ;
        case kCGErrorTypeCheck:
            message = @"A data type or token was encountered that did not match the expected type or token." ;
            break ;
        case kCGErrorInvalidOperation:
            message = @"The requested operation is not valid for the parameters passed in, or the current system state." ;
            break ;
        case kCGErrorNoneAvailable:
            message = @"The requested operation could not be completed as the indicated resources were not found." ;
            break ;
        default:
            message = [NSString stringWithFormat:@"Unrecognized CoreGraphics error:%d", error] ;
    }
    return message ;
}

@interface HSEventThreadManager : NSObject
@property NSMutableDictionary *eventWatchers ;
@property NSThread            *watcherThread ;
@property NSRunLoop           *threadRunLoop ;
@property NSTimer             *keepAliveTimer ;
@end

@interface HSEventWatcherObject : NSObject
@property int  fnRef ;
@property BOOL passive ;
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

@implementation HSEventWatcherObject

- (instancetype)init {
    self = [super init] ;
    if (self) {
        _fnRef   = LUA_NOREF ;
        _passive = YES ;
    }
    return self ;
}

- (instancetype)initWithFunction:(int)fnRef passive:(BOOL)passive {
    self = [self init] ;
    if (self) {
        _fnRef   = fnRef ;
        _passive = passive ;
    }
    return self ;
}

@end

#pragma mark - Module Functions

static int watcher_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TFUNCTION | LS_TNIL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    BOOL passive = (lua_gettop(L) == 2) ? (BOOL)lua_toboolean(L, 2) : YES ;
    int fnRef = LUA_NOREF ;
    if (lua_type(L, 1) == LUA_TFUNCTION) {
        lua_pushvalue(L, 1) ;
        fnRef = [skin luaRef:refTable] ;
    }

    [skin pushNSObject:[[HSEventWatcherObject alloc] initWithFunction:fnRef passive:passive]] ;
    return 1 ;
}

static int watcher_watchers(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;

    uint32_t count ;
// Resets latency counters reducing the usefulness of this function, so we'll pick an arbitrary max since
// we don't need the array for long.
//     CGError status = CGGetEventTapList(0, NULL, &count) ;
    CGError status = kCGErrorSuccess ;
    count = 128 ; // honestly, if you have this many, you're doing *way* more than I want to deal with right now

//     if (status == kCGErrorSuccess) {
        CGEventTapInformation *tapList = malloc(sizeof(CGEventTapInformation) * count) ;
        uint32_t newCount ;
        status = CGGetEventTapList(count, tapList, &newCount) ;
        if (status == kCGErrorSuccess) {
//             if (count != newCount) {
//                 [skin logWarn:[NSString stringWithFormat:@"%s:watchers - count changed between calls to CGEventTapList: was %d, now %d", USERDATA_TAG, count, newCount]] ;
//             }
            if (count == newCount) {
// FIXME: make this adjustable with maxTaps function if we end up leaving this in
                CGGetEventTapList(0, NULL, &count) ;
                [skin logWarn:[NSString stringWithFormat:@"%s:watchers - CGEventTapList : only returning %d of %d eventtaps.  Adjust source and recompile if this needs to be adjusted.", USERDATA_TAG, newCount, count]] ;
            }
            lua_newtable(L) ;
            for(uint32_t i = 0 ; i < newCount ; i++) {
                lua_newtable(L) ;
                lua_pushinteger(L, tapList[i].eventTapID) ; lua_setfield(L, -2, "eventTapID") ;
                switch(tapList[i].tapPoint) {
                    case kCGHIDEventTap:
                        lua_pushstring(L, "HID") ;
                        break ;
                    case kCGSessionEventTap:
                        lua_pushstring(L, "session") ;
                        break ;
                    case kCGAnnotatedSessionEventTap:
                        lua_pushstring(L, "annotatedSession") ;
                        break ;
                    default:
                        lua_pushfstring(L, "unknown CGEventTapLocation: %d", tapList[i].tapPoint) ;
                }
                lua_setfield(L, -2, "tapPoint") ;
                switch(tapList[i].options) {
                    case kCGEventTapOptionDefault:
                        lua_pushstring(L, "active") ;
                        break ;
                    case kCGEventTapOptionListenOnly:
                        lua_pushstring(L, "passive") ;
                        break ;
                    default:
                        lua_pushfstring(L, "unknown CGEventTapOptions: %d", tapList[i].options) ;
                }
                lua_setfield(L, -2, "options") ;

                lua_pushinteger(L, (lua_Integer)tapList[i].eventsOfInterest) ;  lua_setfield(L, -2, "eventsOfInterest") ;
                lua_pushinteger(L, tapList[i].tappingProcess) ; lua_setfield(L, -2, "tappingProcess") ;
                lua_pushinteger(L, tapList[i].processBeingTapped) ; lua_setfield(L, -2, "processBeingTapped") ;
                lua_pushboolean(L, tapList[i].enabled) ; lua_setfield(L, -2, "enabled") ;
                lua_pushnumber(L, (lua_Number)tapList[i].minUsecLatency) ; lua_setfield(L, -2, "minUsecLatency") ;
                lua_pushnumber(L, (lua_Number)tapList[i].avgUsecLatency) ; lua_setfield(L, -2, "avgUsecLatency") ;
                lua_pushnumber(L, (lua_Number)tapList[i].maxUsecLatency) ; lua_setfield(L, -2, "maxUsecLatency") ;

                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
        }
        if (tapList) free(tapList) ;
//     }

    if (status != kCGErrorSuccess) {
        return luaL_error(L, [CGErrorToString(status) UTF8String]) ;
    }

    return 1 ;
}

#pragma mark - Module Methods

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSEventWatcherObject(lua_State *L, id obj) {
    HSEventWatcherObject *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(HSEventWatcherObject *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toHSEventWatcherObjectFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSEventWatcherObject *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSEventWatcherObject, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSEventWatcherObject *obj = [skin luaObjectAtIndex:1 toClass:"HSEventWatcherObject"] ;
    NSString *title = obj.passive ? @"passive" : @"active" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSEventWatcherObject *obj1 = [skin luaObjectAtIndex:1 toClass:"HSEventWatcherObject"] ;
        HSEventWatcherObject *obj2 = [skin luaObjectAtIndex:2 toClass:"HSEventWatcherObject"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSEventWatcherObject *obj = get_objectFromUserdata(__bridge_transfer HSEventWatcherObject, L, 1, USERDATA_TAG) ;
    if (obj) {
        LuaSkin *skin = [LuaSkin shared] ;
        obj.fnRef = [skin luaUnref:refTable ref:obj.fnRef] ;
        obj = nil ;
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    if (threadManager) [threadManager cancelThread:nil];
    threadManager = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",      watcher_new},
    {"watchers", watcher_watchers},
    {NULL,       NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_event_watcher(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    threadManager = [[HSEventThreadManager alloc] init] ;

    [skin registerPushNSHelper:pushHSEventWatcherObject         forClass:"HSEventWatcherObject"];
    [skin registerLuaObjectHelper:toHSEventWatcherObjectFromLua forClass:"HSEventWatcherObject"
                                             withUserdataMapping:USERDATA_TAG];

    return 1;
}
