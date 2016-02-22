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
    _L = luaL_newstate() ;
    luaL_openlibs(_L) ;
    lua_pushglobaltable(_L) ;

    pushHSASMLuaThreadMetatable(_L) ;
    pushHSASMLuaThread(_L, self) ;
    lua_setfield(_L, -2, "_instance") ;

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
        lua_pushstring(_L, [[assignmentsFromParent objectForKey:@"configdir"] UTF8String]) ;
        lua_pushstring(_L, [[assignmentsFromParent objectForKey:@"path"] UTF8String]) ;
        lua_pushstring(_L, [[assignmentsFromParent objectForKey:@"cpath"] UTF8String]) ;
        if (lua_pcall(_L, 4, 1, 0) != LUA_OK) {
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
            if (_performLuaClose) lua_close(_L) ;
        }
        _finalDictionary = [_thread threadDictionary] ;

    // in case lua_close isn't called...
        [[NSRunLoop currentRunLoop] removePort:_inPort forMode:NSDefaultRunLoopMode] ;
        [_inPort setDelegate:nil] ;
        [_inPort invalidate] ;
        _inPort  = nil ;
        _outPort = nil ;
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
    DEBUG(([NSString stringWithFormat:@"handlePortMessage:%d", portMessage.msgid])) ;
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
                        ERROR(error) ;
                }
            } else {
                ERROR(@"exiting thread; missing runstring function") ;
                [_thread cancel] ;
            }
        }   break ;
        case MSGID_CANCEL: // do nothing, this was just to break out of the run loop
            break ;
        default:
            INFORMATION(([NSString stringWithFormat:@"unhandled message id:%d", portMessage.msgid])) ;
            break ;
    }
}

@end

#pragma mark - Module Functions

#pragma mark - Module Methods

static int timestamp(lua_State *L) {
    lua_pushnumber(L, [[NSDate date] timeIntervalSince1970]) ;
    return 1 ;
}

static int threadIsCancelled(lua_State *L) {
    HSASMLuaThread *luaThread = toHSASMLuaThreadFromLua(L, 1) ;
    lua_pushboolean(L, luaThread.thread.cancelled) ;
    return 1 ;
}

static int threadName(lua_State *L) {
    HSASMLuaThread *luaThread = toHSASMLuaThreadFromLua(L, 1) ;
    lua_pushstring(L, [luaThread.thread.name UTF8String]) ;
    return 1 ;
}

static int getItemFromDictionary(lua_State *L) {
    HSASMLuaThread *luaThread = toHSASMLuaThreadFromLua(L, 1) ;
    id key = setHamster(L, 2, [[NSMutableDictionary alloc] init]) ;
    while(luaThread.dictionaryLock) {} ;
    luaThread.dictionaryLock = YES ;
    id obj = (lua_gettop(L) == 1) ? luaThread.thread.threadDictionary :
                                    [luaThread.thread.threadDictionary objectForKey:key] ;
    getHamster(L, obj, [[NSMutableDictionary alloc] init]) ;
    luaThread.dictionaryLock = NO ;
    return 1 ;
}

static int setItemInDictionary(lua_State *L) {
    HSASMLuaThread *luaThread = toHSASMLuaThreadFromLua(L, 1) ;
    id key = setHamster(L, 2, [[NSMutableDictionary alloc] init]) ;
    id obj = setHamster(L, 3, [[NSMutableDictionary alloc] init]) ;
    while(luaThread.dictionaryLock) {} ;
    luaThread.dictionaryLock = YES ;
    [luaThread.thread.threadDictionary setValue:obj forKey:key] ;
    luaThread.dictionaryLock = NO ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int itemDictionaryKeys(lua_State *L) {
    HSASMLuaThread *luaThread = toHSASMLuaThreadFromLua(L, 1) ;
    while(luaThread.dictionaryLock) {} ;
    luaThread.dictionaryLock = YES ;
    NSArray *theKeys = [luaThread.thread.threadDictionary allKeys] ;
    luaThread.dictionaryLock = NO ;
    getHamster(L, theKeys, [[NSMutableDictionary alloc] init]) ;
    return 1 ;
}

static int cancelThread(lua_State *L) {
    HSASMLuaThread *luaThread = toHSASMLuaThreadFromLua(L, 1) ;
    if (lua_type(L, 3) != LUA_TNONE) {
        luaThread.performLuaClose = (BOOL)lua_toboolean(L, 3) ;
    }
    [luaThread.thread cancel] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

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

static int flushOutput(lua_State *L) {
    HSASMLuaThread *luaThread = toHSASMLuaThreadFromLua(L, 1) ;
    BOOL skipPush = NO ;
    if (lua_gettop(L) == 2) skipPush = (BOOL)lua_toboolean(L, 2) ;
    if (!skipPush) {
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
    HSASMLuaThread *value ;
    if (luaL_testudata(L, idx, THREAD_UD_TAG)) {
        value = get_objectFromUserdata(__bridge HSASMLuaThread, L, idx, THREAD_UD_TAG) ;
    } else {
        NSString *message = [NSString stringWithFormat:@"expected %s object, found %s",
                                                       THREAD_UD_TAG,
                                                       lua_typename(L, lua_type(L, idx))] ;
        ERROR(message) ;
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
    HSASMLuaThread *obj = get_objectFromUserdata(__bridge_transfer HSASMLuaThread, L, 1, THREAD_UD_TAG) ;
    DEBUG(([NSString stringWithFormat:@"__gc for thread:%@", obj.thread.name])) ;
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
