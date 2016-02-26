//    Move this to it's own repo -- getting large enough that it would be annoying for someone who
//        wanted to clone repo for something else, but didn't care about/want this...
//
// +  Document LuaSkinThread, what it does, why, and how
//
// *  LuaSkin support now possible -- does require change to modules, but no change to core Application or LuaSkin framework
// *  Need to work out proper delegate for threaded LuaSkin's to allow log messages to go somewhere useful
// +  Module conversion in progress for modules I care about... may take requests afterwards...
//        module changes require [LuaSkin performSelector:@selector(thread)] instead of [LuaSkin shared],
//        store refTable in threadDictionary, and making sure that they don't explicitly schedule anything on
//        main loop, etc.
//    Modify thread.m to use thread supported LuaSkin for argument checking, etc.
// +  Modify get/set to use LuaSkin? gives us easier userdata support, but have to think how this affects
//        refs within the object...
//
// *  transfer base data types directly?
// *      meta methods so thread dictionary can be treated like a regular lua table?
//        other types (non-c functions, NSObject based userdata)? struct userdata would require NSValue... maybe?
// +  check if thread is running in some (all?) methods
//    locks need timeout/fallback (reset?) (dictionary lock is only one still in use) -- use NSLock?
//
// ?  add support for thread to initiate lua on main thread (i.e. core Hammerspoon) other than through
//       properly (and intentionally) created callback function?  would allow hand-off for things which
//       may not be possible/easy on the threaded side (hs.drawing, etc.) but at risk of thread blocking
//       Hammerspoon (the reason for this in the first place) or even worse -- a deadlock between the two

#import "luathread.h"

@interface LuaSkinThread : LuaSkin
+(BOOL)inject ;
+(id)thread ;
@end

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
    LuaSkin *skin = [LuaSkin shared];
    [skin logVerbose:[NSString stringWithFormat:@"main handlePortMessage:%d", portMessage.msgid]] ;
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
            [skin logInfo:[NSString stringWithFormat:@"main unhandled message id:%d", portMessage.msgid]] ;
            break ;
    }
}

@end

#pragma mark - Module Functions

/// hs._asm.luathread.new([name]) -> threadObj
/// Constructor
/// Create a new lua thread instance.
///
/// Parameters:
///  * name - an optional name for the thread instance.  If no name is provided, a randomly generated one is used.
///
/// Returns:
///  * the thread object
///
/// Notes:
///  * the name does not have to be unique.  If a file with the name `_init.*name*.lua` is located in the users Hammerspoon configuration directory (`~/.hammerspoon` by default), then it will be executed at thread startup.
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

/// hs._asm.luathread:isExecuting() -> boolean
/// Method
/// Determines whether or not the thread is executing or if execution has ended.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean indicating whether or not the thread is still active.
static int threadIsExecuting(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, luaThread.threadObj.thread.executing) ;
    return 1 ;
}

/// hs._asm.luathread:isIdle() -> boolean
/// Method
/// Determines whether or not the thread is currently busy executing Lua code.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean indicating whether or not the thread is executing Lua code.
///
/// Notes:
///  * if you are not using a callback function, you can periodically check this value to determine if submitted lua code has completed so you know when to check the results or output with [hs._asm.luathread:getOutput](#getOutput).
static int threadIsIdle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, luaThread.threadObj.idle) ;
    return 1 ;
}

/// hs._asm.luathread:setCallback(function | nil) -> threadObject
/// Method
/// Set or remove a callback function to be invoked when the thread has completed executing lua code.
///
/// Parameters:
///  * a function, to set or change the callback function, or nil to remove the callback function.
///
/// Returns:
///  * the thread object
///
/// Notes:
///  * The callback function will be invoked whenever the lua thread goes idle (i.e. is not executing lua code) or when [hs._asm.luathread._instance:flush](#flush2) is invoked from within executing lua code in the thread.
///  * the callback function should expect two arguments and return none: the thread object and a string containing all output cached since the callback function was last invoked or the output queue was last cleared with [hs._asm.luathread:flush](#flush).
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

/// hs._asm.luathread:get([key]) -> value
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
///  * This method is used in conjunction with [hs._asm.luathread:set](#set) to pass data back and forth between the thread and Hammerspoon.
///  * see also [hs._asm.luathread:sharedTable](#sharedTable)
static int getItemFromDictionary(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
    id key = [skin toNSObjectAtIndex:2 withOptions:LS_NSUnsignedLongLongPreserveBits |
                                                   LS_NSDescribeUnknownTypes         |
                                                   LS_NSPreserveLuaStringExactly     |
                                                   LS_NSAllowsSelfReference] ;
    if (luaThread.threadObj.thread.executing) {
        while(luaThread.threadObj.dictionaryLock) {} ;
        luaThread.threadObj.dictionaryLock = YES ;
        NSDictionary *holding = luaThread.threadObj.thread.threadDictionary ;
        luaThread.threadObj.dictionaryLock = NO ;
        id obj = (lua_gettop(L) == 1) ? holding : [holding objectForKey:key] ;
        [skin pushNSObject:obj withOptions:LS_NSUnsignedLongLongPreserveBits |
                                           LS_NSDescribeUnknownTypes         |
                                           LS_NSPreserveLuaStringExactly     |
                                           LS_NSAllowsSelfReference] ;

    } else if (luaThread.threadObj.finalDictionary) {
        id obj = (lua_gettop(L) == 1) ? luaThread.threadObj.finalDictionary :
                                        [luaThread.threadObj.finalDictionary objectForKey:key] ;
        [skin pushNSObject:obj withOptions:LS_NSUnsignedLongLongPreserveBits |
                                           LS_NSDescribeUnknownTypes         |
                                           LS_NSPreserveLuaStringExactly     |
                                           LS_NSAllowsSelfReference] ;
    } else {
        return luaL_error(L, "thread inactive and no final dictionary captured") ;
    }
    return 1 ;
}

/// hs._asm.luathread:set(key, value) -> threadObject
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
///  * This method is used in conjunction with [hs._asm.luathread:get](#get) to pass data back and forth between the thread and Hammerspoon.
///  * see also [hs._asm.luathread:sharedTable](#sharedTable)
static int setItemInDictionary(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TANY, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
    if (luaThread.threadObj.thread.executing) {
        id key = [skin toNSObjectAtIndex:2 withOptions:LS_NSUnsignedLongLongPreserveBits |
                                                       LS_NSDescribeUnknownTypes         |
                                                       LS_NSPreserveLuaStringExactly     |
                                                       LS_NSAllowsSelfReference] ;
        id obj = [skin toNSObjectAtIndex:3 withOptions:LS_NSUnsignedLongLongPreserveBits |
                                                       LS_NSDescribeUnknownTypes         |
                                                       LS_NSPreserveLuaStringExactly     |
                                                       LS_NSAllowsSelfReference] ;
        if ([key isKindOfClass:[NSString class]] && ([key isEqualToString:@"_LuaSkin"] ||
                                                     [key isEqualToString:@"_refTables"])) {
            return luaL_error(L, "you cannot modify an internally managed variable") ;
        }
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

/// hs._asm.luathread:keys() -> table
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
///  * see also [hs._asm.luathread:get](#get) and [hs._asm.luathread:set](#set)
static int itemDictionaryKeys(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
    while(luaThread.threadObj.dictionaryLock) {} ;
    luaThread.threadObj.dictionaryLock = YES ;
    NSArray *theKeys = [luaThread.threadObj.thread.threadDictionary allKeys] ;
    luaThread.threadObj.dictionaryLock = NO ;
    [skin pushNSObject:theKeys withOptions:LS_NSUnsignedLongLongPreserveBits |
                                           LS_NSDescribeUnknownTypes         |
                                           LS_NSPreserveLuaStringExactly     |
                                           LS_NSAllowsSelfReference] ;
    return 1 ;
}

/// hs._asm.luathread:cancel([_, close]) -> threadObject
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
///  * the two argument format specified above is included to follow the format of the lua builtin `os.exit` function.
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

/// hs._asm.luathread:name() -> string
/// Method
/// Returns the name assigned to the lua thread.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the name specified or dynamically assigned at the time of the thread's creation.
static int threadName(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:luaThread.name] ;
    return 1 ;
}

/// hs._asm.luathread:getOutput([cached]) -> string
/// Method
/// Returns the output currently available from the last submission to the lua thread.
///
/// Parameters:
///  * cached - a boolean value, defaulting to false, indicating whether the function should return the output currently cached by the thread but not yet submitted because the lua code is still executing (true) or whether the function should return the output currently in the completed output buffer.
///
/// Returns:
///  * a string containing the output specified
///
/// Notes:
///  * this method does not clear the output buffer; see [hs._asm.luathread:flush](#flush).
///  * if you are using a callback function, this method will return an empty string when `cached` is not set or is false.  You can still set `cached` to true to check on the output of a long running lua process, however.
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
    }
    [skin pushNSObject:outputCopy] ;
    return 1 ;
}

/// hs._asm.luathread:flush() -> threadObject
/// Method
/// Clears the output buffer.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the thread object
static int flushOutput(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;

    [luaThread.output removeAllObjects] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}


static int dumpDictionary(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:luaThread.threadObj.thread.threadDictionary
           withOptions:LS_NSUnsignedLongLongPreserveBits |
                       LS_NSLuaStringAsDataOnly |
                       LS_NSDescribeUnknownTypes |
                       LS_NSAllowsSelfReference] ;
    return 1 ;
}

/// hs._asm.luathread:submit(code) -> threadObject
/// Method
/// Submits the specified lua code for execution in the lua thread.
///
/// Parameters:
///  * code - a string containing the lua code to execute in the thread.
///
/// Returns:
///  * the thread object
static int submitInput(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    HSASMLuaThreadManager *luaThread = [skin toNSObjectAtIndex:1] ;

    if (luaThread.threadObj.thread.executing) {
        NSData *input = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] ;

        NSPortMessage* messageObj = [[NSPortMessage alloc] initWithSendPort:luaThread.outPort
                                                                receivePort:luaThread.inPort
                                                                 components:@[input]];
        [messageObj setMsgid:MSGID_INPUT];
        [messageObj sendBeforeDate:[NSDate date]];
        lua_pushvalue(L, 1) ;
    } else {
        return luaL_error(L, "thread inactive") ;
    }
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
    LuaSkin *skin = [LuaSkin shared];
    HSASMLuaThreadManager *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSASMLuaThreadManager, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                  lua_typename(L, lua_type(L, idx))]] ;
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
    LuaSkin *skin = [LuaSkin shared];
    HSASMLuaThreadManager *obj = get_objectFromUserdata(__bridge_transfer HSASMLuaThreadManager, L, 1, USERDATA_TAG) ;
    [skin logVerbose:[NSString stringWithFormat:@"__gc for thread manager:%@", obj.threadObj.thread.name]] ;
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

    {"dumpDictionary",    dumpDictionary},

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

    [LuaSkinThread inject] ;

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
