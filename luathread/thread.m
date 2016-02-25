#import "luathread.h"

#pragma mark - Support Functions and Classes

static void pushHSASMLuaThreadMetatable(lua_State *L) ;
static int pushHSASMLuaThread(lua_State *L, id obj) ;
static id toHSASMLuaThreadFromLua(lua_State *L, int idx) ;

@implementation HSASMLuaThread
-(instancetype)initWithPort:(NSPort *)outPort {
    self = [super init] ;
    if (self) {
        _runStringRef    = LUA_NOREF ;
        _outPort         = outPort ;
        _performLuaClose = YES ;
        _dictionaryLock  = NO ;
        _idle            = NO ;
        _cachedOutput    = [[NSMutableArray alloc] init] ;

        // go ahead and define it now, even though we're not threaded yet, because we want
        // the manager to be able to get it from our properties
        _inPort          = [NSMachPort port] ;
        [_inPort setDelegate:self] ;
    }
    return self ;
}

-(BOOL)startLuaInstance {
    _skin = [LuaSkin performSelector:@selector(thread)] ;
    _L = _skin.L ;

    lua_pushglobaltable(_L) ;

    pushHSASMLuaThreadMetatable(_L) ;
    pushHSASMLuaThread(_L, self) ;
    lua_setfield(_L, -2, "_instance") ;

    [_skin setDelegate:self] ;

    NSString *threadInitFile = [assignmentsFromParent objectForKey:@"initfile"] ;
    if (threadInitFile) {
        int loadresult = luaL_loadfile(_L, [threadInitFile fileSystemRepresentation]);
        if (loadresult != 0) {
            NSString *message = [NSString stringWithFormat:@"unable to load init file %@: %s",
                                                           threadInitFile,
                                                           lua_tostring(_L, -1)] ;
            ERROR(message) ;
            return NO ;
        }
        lua_pushstring(_L, [_thread.name UTF8String]) ;
        [_skin pushNSObject:assignmentsFromParent] ;
        if (lua_pcall(_L, 2, 1, 0) != LUA_OK) {
            NSString *message = [NSString stringWithFormat:@"unable to execute init file %@: %s",
                                                           threadInitFile,
                                                           lua_tostring(_L, -1)] ;
            ERROR(message) ;
            return NO ;
        }
        if (lua_type(_L, -1) == LUA_TFUNCTION) {
            _runStringRef = luaL_ref(_L, LUA_REGISTRYINDEX) ;
        } else {
            NSString *message = [NSString stringWithFormat:@"init file %@ did not return a function, found %s",
                                                           threadInitFile,
                                                           luaL_tolstring(_L, -1, NULL)] ;
            ERROR(message) ;
            lua_pop(_L, 1) ;
            return NO ;
        }
    } else {
        ERROR(@"no init file defined") ;
        return NO ;
    }
    return YES ;
}

-(void)launchThreadWithName:(id)name {
    @autoreleasepool {
        _thread = [NSThread currentThread] ;
        _thread.name = name ;
        [[NSRunLoop currentRunLoop] addPort:_inPort forMode:NSDefaultRunLoopMode] ;

        if ([self startLuaInstance]) {
            while (![_thread isCancelled]) {
                _idle = YES ;
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
            }
            DEBUG(@"exited while-runloop") ;

            luaL_unref(_L, LUA_REGISTRYINDEX, _runStringRef) ;
            _runStringRef = LUA_NOREF ;
            if (_performLuaClose) [_skin destroyLuaState] ;
        }
        _finalDictionary = [_thread threadDictionary] ;

    // in case lua_close isn't called...
        [[NSRunLoop currentRunLoop] removePort:_inPort forMode:NSDefaultRunLoopMode] ;
        [_inPort setDelegate:nil] ;
        [_inPort invalidate] ;
        _inPort  = nil ;
        _outPort = nil ;
        [_skin setDelegate:nil] ;
        _skin    = nil ;
    }
}

-(void)removeCommunicationPorts {
    [[NSRunLoop currentRunLoop] removePort:_inPort forMode:NSDefaultRunLoopMode] ;
    [_inPort setDelegate:nil] ;
    [_inPort invalidate] ;
    _inPort  = nil ;
    _outPort = nil ;
}

-(void)handlePortMessage:(NSPortMessage *)portMessage {
    [_skin logVerbose:[NSString stringWithFormat:@"thread handlePortMessage:%d", portMessage.msgid]] ;
    _idle = NO ;
    switch(portMessage.msgid) {
        case MSGID_INPUT: {
            NSData *input = [portMessage.components firstObject] ;
            if (_runStringRef != LUA_NOREF) {
                lua_rawgeti(_L, LUA_REGISTRYINDEX, _runStringRef);
                lua_pushlstring(_L, [input bytes], [input length]) ;
                @try {
                    if (lua_pcall(_L, 1, 1, 0) != LUA_OK) {
                        NSString *error = [NSString stringWithFormat:@"exiting thread; error in runstring:%s",
                                                                     lua_tostring(_L, -1)] ;
                        ERROR(error) ;
                        [_thread cancel] ;
                    } else {
                        size_t size ;
                        const void *junk = luaL_tolstring(_L, -1, &size) ;
                        [_cachedOutput addObject:[NSData dataWithBytes:junk length:size]] ;
                        NSPortMessage* messageObj = [[NSPortMessage alloc] initWithSendPort:_outPort
                                                                                receivePort:_inPort
                                                                                 components:_cachedOutput];
                        lua_pop(_L, 1) ; // for luaL_tolstring
                        [messageObj setMsgid:MSGID_RESULT];
                        [messageObj sendBeforeDate:[NSDate date]];
                        [_cachedOutput removeAllObjects] ;
                    }
                    lua_pop(_L, 1) ;
                } @catch (NSException *theException) {
                    NSString *error = [NSString stringWithFormat:@"exception %@:%@",
                                                                  theException.name,
                                                                  theException.reason] ;
                    [_skin logError:error] ; // log in thread
                    ERROR(error) ;           // log in main
                }
            } else {
                ERROR(@"exiting thread; missing runstring function") ;
                [_thread cancel] ;
            }
        }   break ;
        case MSGID_CANCEL: // do nothing, this was just to break out of the run loop
            break ;
        default: {
            NSString *msg = [NSString stringWithFormat:@"thread unhandled message id:%d", portMessage.msgid] ;
            [_skin logInfo:msg] ; // log in thread
            INFORMATION(msg) ;    // log in main
        }   break ;
    }
}

- (void) logForLuaSkinAtLevel:(int)level withMessage:(NSString *)theMessage {
    // Send logs to the appropriate location, depending on their level
    // Note that hs.handleLogMessage also does this kind of filtering. We are special casing here for LS_LOG_BREADCRUMB to entirely bypass calling into Lua
    // (because such logs don't need to be shown to the user, just stored in our crashlog in case we crash)
    switch (level) {
        case LS_LOG_BREADCRUMB:
            NSLog(@"%@", theMessage);
            break;

        default:
            lua_getglobal(_L, "hs") ; lua_getfield(_L, -1, "handleLogMessage") ; lua_remove(_L, -2) ;
            lua_pushinteger(_L, level) ;
            lua_pushstring(_L, [theMessage UTF8String]) ;
            int errState = lua_pcall(_L, 2, 0, 0) ;
            if (errState != LUA_OK) {
                NSArray *stateLabels = @[ @"OK", @"YIELD", @"ERRRUN", @"ERRSYNTAX", @"ERRMEM", @"ERRGCMM", @"ERRERR" ] ;
                NSLog(@"logForLuaSkin: error, state %@: %s", [stateLabels objectAtIndex:(NSUInteger)errState],
                          luaL_tolstring(_L, -1, NULL)) ;
                lua_pop(_L, 2) ; // lua_pcall result + converted version from luaL_tolstring
            }
            break;
    }
}

@end

#pragma mark - Module Functions

#pragma mark - Module Methods

/// hs._asm.luathread._instance:timestamp() -> number
/// Method
/// Returns the current time as the number of seconds since Jan 1, 1970 (one of the conventional computer "Epochs" used for representing time).
///
/// Parameters:
///  * None
///
/// Returns:
///  * the number of seconds, including fractions of a second as the decimal portion of the number
///
/// Notes:
///  * this differs from the built in lua `os.time` function in that it returns fractions of a second as the decimal portion of the number.
///  * this is used when generating the `_sharedTable._results.start` and `_sharedTable._results.stop` values
///  * the time values returned by this method can be used to calculate execution times in terms of clock time (i.e. other activity on the computer can cause wide fluctuations in the actual time a specific process takes).  To get a better idea of actual cpu time used by a process, check out the lua builtin `os.clock`.
static int timestamp(lua_State *L) {
    lua_pushnumber(L, [[NSDate date] timeIntervalSince1970]) ;
    return 1 ;
}

/// hs._asm.luathread._instance:isCancelled() -> boolean
/// Method
/// Returns true if the thread has been marked for cancellation.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true or false specifying whether or not the thread has been marked for cancellation.
///
/// Notes:
///  * this method is used by a handler set with `debug.sethook` to determine if lua code execution should be terminated so that the thread can be formally closed.
static int threadIsCancelled(lua_State *L) {
    HSASMLuaThread *luaThread = toHSASMLuaThreadFromLua(L, 1) ;
    lua_pushboolean(L, luaThread.thread.cancelled) ;
    return 1 ;
}

/// hs._asm.luathread._instance:name() -> string
/// Method
/// Returns the name assigned to the lua thread.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the name specified or dynamically assigned at the time of the thread's creation.
static int threadName(lua_State *L) {
    HSASMLuaThread *luaThread = toHSASMLuaThreadFromLua(L, 1) ;
    lua_pushstring(L, [luaThread.thread.name UTF8String]) ;
    return 1 ;
}

/// hs._asm.luathread._instance:get([key]) -> value
/// Method
/// Get the value for a keyed entry from the shared thread dictionary for the lua thread.
///
/// Parameters:
///  * key - an optional key specifying the specific entry in the shared dictionary to return a value for.  If no key is specified, returns the entire shared dictionary as a table.
///
/// Returns:
///  * the value of the specified key.
///
/// Notes:
///  * If the key does not exist, then this method returns nil.
///  * This method is used in conjunction with [hs._asm.luathread._instance:set](#set2) to pass data back and forth between the thread and Hammerspoon.
///  * see also [hs._asm.luathread:sharedTable](#sharedTable) and the description of the global `_sharedTable` in this sub-module's description.
static int getItemFromDictionary(lua_State *L) {
    HSASMLuaThread *luaThread = toHSASMLuaThreadFromLua(L, 1) ;
    id key = setHamster(L, 2, [[NSMutableDictionary alloc] init]) ;
    while(luaThread.dictionaryLock) {} ;
    luaThread.dictionaryLock = YES ;
    NSDictionary *holding = luaThread.thread.threadDictionary ;
    luaThread.dictionaryLock = NO ;
    id obj = (lua_gettop(L) == 1) ? holding : [holding objectForKey:key] ;
    getHamster(L, obj, [[NSMutableDictionary alloc] init]) ;
    return 1 ;
}

/// hs._asm.luathread._instance:set(key, value) -> threadObject
/// Method
/// Set the value for a keyed entry in the shared thread dictionary for the lua thread.
///
/// Parameters:
///  * key   - a key specifying the specific entry in the shared dictionary to set the value of.
///  * value - the value to set the key to.  May be `nil` to clear or remove a key from the shared dictionary.
///
/// Returns:
///  * the value of the specified key.
///
/// Notes:
///  * This method is used in conjunction with [hs._asm.luathread._instance:get](#get2) to pass data back and forth between the thread and Hammerspoon.
///  * see also [hs._asm.luathread:sharedTable](#sharedTable) and the description of the global `_sharedTable` in this sub-module's description.
static int setItemInDictionary(lua_State *L) {
    HSASMLuaThread *luaThread = toHSASMLuaThreadFromLua(L, 1) ;
    id key = setHamster(L, 2, [[NSMutableDictionary alloc] init]) ;
    id obj = setHamster(L, 3, [[NSMutableDictionary alloc] init]) ;
    if ([key isKindOfClass:[NSData class]] && [key isEqualTo:[@"_LuaSkin" dataUsingEncoding:NSUTF8StringEncoding]])
        return luaL_error(L, "you cannot modify an internally required variable") ;
    while(luaThread.dictionaryLock) {} ;
    luaThread.dictionaryLock = YES ;
    [luaThread.thread.threadDictionary setValue:obj forKey:key] ;
    luaThread.dictionaryLock = NO ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.luathread._instance:keys() -> table
/// Method
/// Returns the names of all keys that currently have values in the shared dictionary of the lua thread.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the names of the keys as an array
///
/// Notes:
///  * see also [hs._asm.luathread._instance:get](#get2) and [hs._asm.luathread._instance:set](#set2)
static int itemDictionaryKeys(lua_State *L) {
    HSASMLuaThread *luaThread = toHSASMLuaThreadFromLua(L, 1) ;
    while(luaThread.dictionaryLock) {} ;
    luaThread.dictionaryLock = YES ;
    NSArray *theKeys = [luaThread.thread.threadDictionary allKeys] ;
    luaThread.dictionaryLock = NO ;
    getHamster(L, theKeys, [[NSMutableDictionary alloc] init]) ;
    return 1 ;
}

/// hs._asm.luathread._instance:cancel([_, close]) -> threadObject
/// Method
/// Cancel the lua thread, interrupting any lua code currently executing on the thread.
///
/// Parameters:
///  * The first argument is always ignored
///  * if two arguments are specified, the true/false value of the second argument is used to indicate whether or not the lua thread should exit cleanly with a formal lua_close (i.e. `__gc` metamethods will be invoked) or if the thread should just stop with no formal close.  Defaults to true (i.e. perform the formal close).
///
/// Returns:
///  * the thread object
///
/// Notes:
///  * the two argument format specified above is included to follow the format of the lua builtin `os.exit`
static int cancelThread(lua_State *L) {
    HSASMLuaThread *luaThread = toHSASMLuaThreadFromLua(L, 1) ;
    if (lua_type(L, 3) != LUA_TNONE) {
        luaThread.performLuaClose = (BOOL)lua_toboolean(L, 3) ;
    }
    [luaThread.thread cancel] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.luathread._instance:print(...) -> threadObject
/// Method
/// Adds the specified values to the output cache for the thread.
///
/// Parameters:
///  * ... - zero or more values to be added to the output cache for the thread and ultimately returned to Hammerspoon with a lua processes results.
///
/// Returns:
///  * the thread object
///
/// Notes:
///  * this method is used to replace the lua built-in function `print` and mimics its behavior as closely as possible -- objects with a `__tostring` meta method are honored, arguments separated by comma's are concatenated with a tab in between them, the output line terminates with a `\\n`, etc.
static int printOutput(lua_State *L) {
    HSASMLuaThread *luaThread = toHSASMLuaThreadFromLua(L, 1) ;
    NSMutableData  *output = [[NSMutableData alloc] init] ;
    int            n       = lua_gettop(L);
    size_t         size ;
    for (int i = 2 ; i <= n ; i++) {
        const void *junk = luaL_tolstring(L, i, &size) ;
        if (i > 2) [output appendBytes:"\t" length:1] ;
        [output appendBytes:junk length:size] ;
        lua_pop(L, 1) ;
    }
    [output appendBytes:"\n" length:1] ;
    [luaThread.cachedOutput addObject:output] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.luathread._instance:flush([push]) -> threadObject
/// Method
/// Clears the cached output buffer.
///
/// Parameters:
///  * push - an optional boolean argument, defaults to true, specifying whether or not the output currently in the buffer should be pushed to Hammerspoon before clearing the local cache.
///
/// Returns:
///  * the thread object
///
/// Notes:
///  * if `push` is not specified or is true, the output will be sent to Hammerspoon and any callback function will be invoked with the current output.  This can be used to submit partial output for a long running process and invoke the function periodically rather than just once at the end of the process.
static int flushOutput(lua_State *L) {
    HSASMLuaThread *luaThread = toHSASMLuaThreadFromLua(L, 1) ;
    BOOL push = YES ;
    if (lua_gettop(L) == 2) push = (BOOL)lua_toboolean(L, 2) ;
    if (push) {
        NSPortMessage* messageObj = [[NSPortMessage alloc] initWithSendPort:luaThread.outPort
                                                                receivePort:luaThread.inPort
                                                                 components:luaThread.cachedOutput];
        [messageObj setMsgid:MSGID_PRINTFLUSH];
        [messageObj sendBeforeDate:[NSDate date]];
    }
    [luaThread.cachedOutput removeAllObjects] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions

static int pushHSASMLuaThread(lua_State *L, id obj) {
    HSASMLuaThread *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(HSASMLuaThread *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, THREAD_UD_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSASMLuaThreadFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin performSelector:@selector(thread)]; //[LuaSkin shared];
    HSASMLuaThread *value ;
    if (luaL_testudata(L, idx, THREAD_UD_TAG)) {
        value = get_objectFromUserdata(__bridge HSASMLuaThread, L, idx, THREAD_UD_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s",
                                                  THREAD_UD_TAG,
                                                  lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    HSASMLuaThread *obj = get_objectFromUserdata(__bridge HSASMLuaThread, L, 1, THREAD_UD_TAG) ;
    NSString *title = @"** unavailable" ;
    if (obj.thread) title = obj.thread.name ;
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)",
                                                  THREAD_UD_TAG,
                                                  title,
                                                  lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, THREAD_UD_TAG) && luaL_testudata(L, 2, THREAD_UD_TAG)) {
        HSASMLuaThread *obj1 = get_objectFromUserdata(__bridge HSASMLuaThread, L, 1, THREAD_UD_TAG) ;
        HSASMLuaThread *obj2 = get_objectFromUserdata(__bridge HSASMLuaThread, L, 2, THREAD_UD_TAG) ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin performSelector:@selector(thread)]; //[LuaSkin shared];
    HSASMLuaThread *obj = get_objectFromUserdata(__bridge_transfer HSASMLuaThread, L, 1, THREAD_UD_TAG) ;
    NSString *msg = [NSString stringWithFormat:@"__gc for thread:%@", obj.thread.name] ;
    [skin logVerbose:msg] ; // log in thread
    VERBOSE(msg) ;          // log in main
    if (obj) {
        [obj removeCommunicationPorts] ;
        [obj.thread cancel] ;
        obj         = nil ;
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg thread_userdata_metaLib[] = {
//     {"print",       returnString},
    {"cancel",      cancelThread},
    {"name",        threadName},
    {"isCancelled", threadIsCancelled},
    {"timestamp",   timestamp},
    {"get",         getItemFromDictionary},
    {"set",         setItemInDictionary},
    {"keys",        itemDictionaryKeys},
    {"print",       printOutput},
    {"flush",       flushOutput},

    {"__tostring",  userdata_tostring},
    {"__eq",        userdata_eq},
    {"__gc",        userdata_gc},
    {NULL,          NULL}
};

static void pushHSASMLuaThreadMetatable(lua_State *L) {
    luaL_newlib(L, thread_userdata_metaLib);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_pushstring(L, THREAD_UD_TAG);
    lua_setfield(L, -2, "__type");
    lua_setfield(L, LUA_REGISTRYINDEX, THREAD_UD_TAG);
}
