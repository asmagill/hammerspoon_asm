// *  @try/@catch to catch luaskin NSAsserts?
//        can LuaSkin be made thread safe?  I kind of doubt it, so how much of it should be replicated?
//        maybe... each thread has its own instance, stored in the the threadDictionary
//                 how to ensure the right thread gets callback?  compare luaskin's?
//                 would be significant change in core LuaSkin, but not as much (any?) in modules
//                 still have to ensure UI only on main thread
// *  transfer base data types directly?
// *      meta methods so thread dictionary can be treated like a regular lua table?
//        other types (non-c functions)?
//        NSObject based userdata?
// +  check if thread is running in some (all?) methods
//    method argument checking since we can't always use LuaSkin
//    locks need timeout/fallback (reset?) (dictionary lock is only one still in use)
//    document
#import "luathread.h"

static int refTable = LUA_NOREF;

#pragma mark - Support Functions and Classes

@implementation HSASMLuaThreadManager
-(instancetype)initWithName:(NSString *)name {
    self = [super init] ;
    if (self) {
        _callbackRef    = LUA_NOREF ;
        _selfRef        = LUA_NOREF ;
        _name           = name ;
        _output         = [[NSMutableArray alloc] init] ;

        _inPort         = [NSMachPort port] ;
        [_inPort setDelegate:self] ;
        [[NSRunLoop currentRunLoop] addPort:_inPort forMode:NSDefaultRunLoopMode] ;
        _threadObj      = [[HSASMLuaThread alloc] initWithPort:_inPort] ;
        _outPort        = _threadObj.inPort ;

        [NSThread detachNewThreadSelector:@selector(launchThreadWithName:)
                                 toTarget:_threadObj
                               withObject:name] ;
    }
    return self ;
}

-(void)removeCommunicationPorts {
    [[NSRunLoop currentRunLoop] removePort:_inPort forMode:NSDefaultRunLoopMode] ;
    [_inPort setDelegate:nil] ;
    [_inPort invalidate] ;
    _inPort    = nil ;
    _outPort   = nil ;
    _threadObj = nil ;
}

-(void)handlePortMessage:(NSPortMessage *)portMessage {
    DEBUG(([NSString stringWithFormat:@"handlePortMessage:%d", portMessage.msgid])) ;
    switch(portMessage.msgid) {
        case MSGID_RESULT:
        case MSGID_PRINTFLUSH: {
            [_output addObjectsFromArray:portMessage.components] ;
            if (_callbackRef != LUA_NOREF) {
                NSMutableData *outputCopy = [[NSMutableData alloc] init] ;
                for (NSData *obj in _output) [outputCopy appendData:obj] ;
                [_output removeAllObjects] ;
                dispatch_async(dispatch_get_main_queue(), ^{
                    LuaSkin   *skin  = [LuaSkin shared] ;
                    lua_State *L     = [skin L] ;
                    [skin pushLuaRef:refTable ref:_callbackRef] ;
                    [skin pushNSObject:self] ;
                    [skin pushNSObject:outputCopy] ;
                    if (![skin protectedCallAndTraceback:2 nresults:0]) {
                        [skin logError:[NSString stringWithFormat:@"%s: callback error: %s",
                                                                  USERDATA_TAG,
                                                                  lua_tostring(L, -1)]] ;
                        lua_pop(L, 1) ;
                    }
                }) ;
            }
        }   break ;
        default:
            INFORMATION(([NSString stringWithFormat:@"unhandled message id:%d", portMessage.msgid])) ;
            break ;
    }
}

@end

#pragma mark - Module Functions

static int newLuaThreadWithName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *name = (lua_gettop(L) == 1) ? [skin toNSObjectAtIndex:1] : [[NSUUID UUID] UUIDString] ;
    HSASMLuaThreadManager *luaThread = [[HSASMLuaThreadManager alloc] initWithName:name] ;
    [skin pushNSObject:luaThread] ;
    return 1 ;
}

static int assignments(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    assignmentsFromParent = [skin toNSObjectAtIndex:1] ;
    return 0 ;
}

#pragma mark - Module Methods

static int threadIsExecuting(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, luaThread.threadObj.thread.executing) ;
    return 1 ;
}

static int threadIsIdle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, luaThread.threadObj.idle) ;
    return 1 ;
}

static int setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;

    // in either case, we need to remove an existing callback, so...
    luaThread.callbackRef = [skin luaUnref:refTable ref:luaThread.callbackRef] ;
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2) ;
        luaThread.callbackRef = [skin luaRef:refTable] ;
        if (luaThread.selfRef == LUA_NOREF) {
            lua_pushvalue(L, 1) ;
            luaThread.selfRef = [skin luaRef:refTable] ;
        }
    } else {
        if (luaThread.selfRef != LUA_NOREF) {
            luaThread.selfRef = [skin luaUnref:refTable ref:luaThread.selfRef] ;
        }
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int getItemFromDictionary(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
    id key = setHamster(L, 2, [[NSMutableDictionary alloc] init]) ;
    if (luaThread.threadObj.thread.executing) {
        while(luaThread.threadObj.dictionaryLock) {} ;
        luaThread.threadObj.dictionaryLock = YES ;
        id obj = (lua_gettop(L) == 1) ? luaThread.threadObj.thread.threadDictionary :
                                        [luaThread.threadObj.thread.threadDictionary objectForKey:key] ;
        getHamster(L, obj, [[NSMutableDictionary alloc] init]) ;
        luaThread.threadObj.dictionaryLock = NO ;
    } else if (luaThread.threadObj.finalDictionary) {
        id obj = (lua_gettop(L) == 1) ? luaThread.threadObj.finalDictionary :
                                        [luaThread.threadObj.finalDictionary objectForKey:key] ;
        getHamster(L, obj, [[NSMutableDictionary alloc] init]) ;
    } else {
        return luaL_error(L, "thread inactive and no final dictionary captured") ;
    }
    return 1 ;
}

static int setItemInDictionary(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TANY, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
    if (luaThread.threadObj.thread.executing) {
        id key = setHamster(L, 2, [[NSMutableDictionary alloc] init]) ;
        id obj = setHamster(L, 3, [[NSMutableDictionary alloc] init]) ;
        while(luaThread.threadObj.dictionaryLock) {} ;
        luaThread.threadObj.dictionaryLock = YES ;
        [luaThread.threadObj.thread.threadDictionary setValue:obj forKey:key] ;
        luaThread.threadObj.dictionaryLock = NO ;
        lua_pushvalue(L, 1) ;
    } else {
        return luaL_error(L, "thread inactive") ;
    }
    return 1 ;
}

static int itemDictionaryKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
    while(luaThread.threadObj.dictionaryLock) {} ;
    luaThread.threadObj.dictionaryLock = YES ;
    NSArray *theKeys = [luaThread.threadObj.thread.threadDictionary allKeys] ;
    luaThread.threadObj.dictionaryLock = NO ;
    getHamster(L, theKeys, [[NSMutableDictionary alloc] init]) ;
    return 1 ;
}

static int cancelThread(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
    if (luaThread.threadObj.thread.executing) {
        if (lua_type(L, 3) != LUA_TNONE) {
            luaThread.threadObj.performLuaClose = (BOOL)lua_toboolean(L, 3) ;
        }
        [luaThread.threadObj.thread cancel] ;
        NSPortMessage* messageObj = [[NSPortMessage alloc] initWithSendPort:luaThread.outPort
                                                        receivePort:luaThread.inPort
                                                         components:nil];
        [messageObj setMsgid:MSGID_CANCEL];
        [messageObj sendBeforeDate:[NSDate date]];
        lua_pushvalue(L, 1) ;
    } else {
        return luaL_error(L, "thread inactive") ;
    }
    return 1 ;
}

static int threadName(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:luaThread.name] ;
    return 1 ;
}

static int getOutput(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;

    NSMutableData *outputCopy = [[NSMutableData alloc] init] ;

    if ((lua_gettop(L) == 2) && lua_toboolean(L, 2) && luaThread.threadObj.thread.executing) {
        for (NSData *obj in luaThread.threadObj.cachedOutput) [outputCopy appendData:obj] ;
    } else if ((lua_gettop(L) == 2) && lua_toboolean(L, 2)) {
        return luaL_error(L, "thread inactive") ;
    } else {
        for (NSData *obj in luaThread.output) [outputCopy appendData:obj] ;
//         [luaThread.output removeAllObjects] ;
    }
    [skin pushNSObject:outputCopy] ;
    return 1 ;
}

static int flushOutput(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;

    [luaThread.output removeAllObjects] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}


// static int dumpDictionary(__unused lua_State *L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
//     HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
//     [skin pushNSObject:luaThread.threadObj.thread.threadDictionary
//            withOptions:LS_NSUnsignedLongLongPreserveBits |
//                        LS_NSLuaStringAsDataOnly |
//                        LS_NSDescribeUnknownTypes |
//                        LS_NSAllowsSelfReference] ;
//     return 1 ;
// }

static int submitInput(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
    NSData *input = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] ;

    NSPortMessage* messageObj = [[NSPortMessage alloc] initWithSendPort:luaThread.outPort
                                                            receivePort:luaThread.inPort
                                                             components:@[input]];
    [messageObj setMsgid:MSGID_INPUT];
    [messageObj sendBeforeDate:[NSDate date]];
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSASMLuaThreadManager(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMLuaThreadManager *value = obj;
    if (value.selfRef == LUA_NOREF) {
        void** valuePtr = lua_newuserdata(L, sizeof(HSASMLuaThreadManager *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
    } else {
        [skin pushLuaRef:refTable ref:value.selfRef] ;
    }
    return 1;
}

static int pushHSASMBooleanType(lua_State *L, id obj) {
    HSASMBooleanType *value = obj ;
    lua_pushboolean(L, value.value) ;
    return 1 ;
}

static id toHSASMLuaThreadManagerFromLua(lua_State *L, int idx) {
    HSASMLuaThreadManager *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSASMLuaThreadManager, L, idx, USERDATA_TAG) ;
    } else {
        NSString *message = [NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                  lua_typename(L, lua_type(L, idx))] ;
        ERROR(message) ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    HSASMLuaThreadManager *obj = get_objectFromUserdata(__bridge HSASMLuaThreadManager, L, 1, USERDATA_TAG) ;
    NSString *title = @"** unavailable" ;
    if (obj.threadObj && obj.threadObj.thread) title = obj.threadObj.thread.name ;
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)",
                                                  USERDATA_TAG,
                                                  title,
                                                  lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        HSASMLuaThreadManager *obj1 = get_objectFromUserdata(__bridge HSASMLuaThreadManager, L, 1, USERDATA_TAG) ;
        HSASMLuaThreadManager *obj2 = get_objectFromUserdata(__bridge HSASMLuaThreadManager, L, 2, USERDATA_TAG) ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSASMLuaThreadManager *obj = get_objectFromUserdata(__bridge_transfer HSASMLuaThreadManager, L, 1, USERDATA_TAG) ;
    DEBUG(([NSString stringWithFormat:@"__gc for thread manager:%@", obj.threadObj.thread.name])) ;
    if (obj) {
        LuaSkin *skin   = [LuaSkin shared] ;
        obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
        obj.selfRef     = [skin luaUnref:refTable ref:obj.selfRef] ;
        [obj removeCommunicationPorts] ;
        [obj.threadObj.thread cancel] ;
        obj             = nil ;
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
static const luaL_Reg userdata_metaLib[] = {
    {"name",              threadName},
    {"submit",            submitInput},
    {"isExecuting",       threadIsExecuting},
    {"isIdle",            threadIsIdle},
    {"getOutput",         getOutput},
    {"flushOutput",       flushOutput},
    {"setCallback",       setCallback},
    {"get",               getItemFromDictionary},
    {"set",               setItemInDictionary},
    {"keys",              itemDictionaryKeys},
    {"cancel",            cancelThread},

//     {"dumpDictionary",    dumpDictionary},

    {"__tostring",        userdata_tostring},
    {"__eq",              userdata_eq},
    {"__gc",              userdata_gc},
    {NULL,                NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",          newLuaThreadWithName},
    {"_assignments", assignments},

    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_luathread_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    assignmentsFromParent = nil ;

    [skin registerPushNSHelper:pushHSASMLuaThreadManager         forClass:"HSASMLuaThreadManager"];
    [skin registerLuaObjectHelper:toHSASMLuaThreadManagerFromLua forClass:"HSASMLuaThreadManager"
                                                      withUserdataMapping:USERDATA_TAG];

    [skin registerPushNSHelper:pushHSASMBooleanType              forClass:"HSASMBooleanType"];

    return 1;
}
