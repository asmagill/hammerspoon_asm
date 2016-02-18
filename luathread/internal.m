//    use runloop to better handle idle time
//    see https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html#//apple_ref/doc/uid/10000057i-CH16-SW1
// *  switch input (and output?) to array
//    switch input and output to NSData
// *  allow init file additions by name
// *  debug.sethook to detect cancelled?
// *  separate metatables?
// *  @try/@catch to catch luaskin NSAsserts?
//        can LuaSkin be made thread safe?  I kind of doubt it, so how much of it should be replicated?
// *  flag to callback for output, result, error
// *  transfer base data types directly?
//        meta methods so thread dictionary can be treated like a regular lua table?
//        other types?
//    check if thread is running in methods
//    method argument checking since we can't always use LuaSkin
//    locks need timeout/fallback (reset?)
//    document
#import "luathread.h"

#pragma mark - Support Functions and Classes

@interface HSASMBooleanType : NSObject
@property (readonly) BOOL value ;
@end

@implementation HSASMBooleanType
-(instancetype)initWithValue:(BOOL)value {
    self = [super init] ;
    if (self) {
        _value = value ;
    }
    return self ;
}

+(instancetype)withTrueValue { return [[HSASMBooleanType alloc] initWithValue:YES] ; }
+(instancetype)withFalseValue { return [[HSASMBooleanType alloc] initWithValue:NO] ; }

@end

@interface HSASMLuaThread : NSThread
@property            int            callbackRef ;
@property            int            selfRef ;
@property (readonly) int            runStringRef ;
@property (readonly) BOOL           idle ;
@property (readonly) lua_State      *L ;
@property            BOOL           outputLock ;
@property (readonly) NSMutableArray *output ;
@property            BOOL           inputLock ;
@property (readonly) NSMutableArray *input ;
@property            BOOL           dictionaryLock ;
@end

@implementation HSASMLuaThread
-(instancetype)initWithName:(NSString *)instanceName {
    LuaSkin *skin = [LuaSkin shared] ;
    self = [super init] ;
    if (self) {
        self.name       = instanceName ;
        _callbackRef    = LUA_NOREF ;
        _runStringRef   = LUA_NOREF ;
        _selfRef        = LUA_NOREF ;
        _output         = [[NSMutableArray alloc] init] ;
        _input          = [[NSMutableArray alloc] init] ;
        _outputLock     = NO ;
        _inputLock      = NO ;
        _dictionaryLock = NO ;
        _idle           = NO ;
        _L              = luaL_newstate() ;
        luaL_openlibs(_L) ;
        lua_pushglobaltable(_L) ;

        luaL_newlib(_L, thread_userdata_metaLib);
        lua_pushvalue(_L, -1);
        lua_setfield(_L, -2, "__index");
        lua_pushstring(_L, USERDATA_TAG);
        lua_setfield(_L, -2, "__type");
        lua_setfield(_L, LUA_REGISTRYINDEX, USERDATA_TAG);

        void** valuePtr = lua_newuserdata(_L, sizeof(HSASMLuaThread *));
        *valuePtr = (__bridge void *)self; // don't need to retain, only exists when thread active
        luaL_getmetatable(_L, USERDATA_TAG);
        lua_setmetatable(_L, -2);

        lua_setfield(_L, -2, "_instance") ;
        NSString *threadInitFile = [assignmentsFromParent objectForKey:@"initfile"] ;
        if (threadInitFile) {
            int loadresult = luaL_loadfile(_L, [threadInitFile fileSystemRepresentation]);
            if (loadresult != 0) {
                [self cancel] ;
                [skin logError:[NSString stringWithFormat:@"%s:unable to load init file %@: %s",
                                                          USERDATA_TAG,
                                                          threadInitFile,
                                                          lua_tostring(_L, -1)]] ;
                return nil ;
            }
            lua_pushstring(_L, [instanceName UTF8String]) ;
            lua_pushstring(_L, [[assignmentsFromParent objectForKey:@"configdir"] UTF8String]) ;
            lua_pushstring(_L, [[assignmentsFromParent objectForKey:@"path"] UTF8String]) ;
            lua_pushstring(_L, [[assignmentsFromParent objectForKey:@"cpath"] UTF8String]) ;
            if (lua_pcall(_L, 4, 1, 0) != LUA_OK) {
                [self cancel] ;
                [skin logError:[NSString stringWithFormat:@"%s:unable to execute init file %@: %s",
                                                          USERDATA_TAG,
                                                          threadInitFile,
                                                          lua_tostring(_L, -1)]] ;
                return nil ;
            }
            if (lua_type(_L, -1) == LUA_TFUNCTION) {
                _runStringRef = luaL_ref(_L, LUA_REGISTRYINDEX) ;
            } else {
                [self cancel] ;
                [skin logError:[NSString stringWithFormat:@"%s:init file %@ did not return a function: %s",
                                                          USERDATA_TAG,
                                                          threadInitFile,
                                                          luaL_tolstring(_L, -1, NULL)]] ;
                return nil ;
            }
        }
        _idle         = YES ;
    }
    return self ;
}

-(void)main {
    while (![self isCancelled]) {
        while(_inputLock) {} ;
        _inputLock = YES ;
        if ([_input count] > 0) {
            _idle = NO ;
            NSString *inputLine = [_input firstObject] ;
            [_input removeObjectAtIndex:0] ;
            _inputLock = NO ;

            if (_runStringRef != LUA_NOREF) {
                lua_rawgeti(_L, LUA_REGISTRYINDEX, _runStringRef);
                lua_pushstring(_L, [inputLine UTF8String]) ;
                @try {
                    if (lua_pcall(_L, 1, 1, 0) != LUA_OK) {
                        NSString *error = [NSString stringWithFormat:@"%s", lua_tostring(_L, -1)] ;
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            LuaSkin   *skin  = [LuaSkin shared] ;
                            [skin logError:[NSString stringWithFormat:@"%s:exiting thread; error in runstring:%@",
                                                                      USERDATA_TAG,
                                                                      error]] ;
                        }) ;
                        [self cancel] ;
                    } else {
                        while(_outputLock) {} ;
                        _outputLock = YES ;
                        [_output addObject:[NSString stringWithFormat:@"%s", lua_tostring(_L, -1)]] ;
                        _outputLock = NO ;
                    }
                    lua_pop(_L, 1) ;
                } @catch (NSException *theException) {
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            LuaSkin   *skin  = [LuaSkin shared] ;
                            [skin logError:[NSString stringWithFormat:@"%s:exception %@:%@",
                                                                      USERDATA_TAG,
                                                                      theException.name,
                                                                      theException.reason]] ;
                        }) ;
                }
            } else {
                // raw; should we allow it? only output will be by invoking _instance:print directly...
                luaL_dostring(_L, [inputLine UTF8String]) ;
            }
            _idle = YES ;
        } else {
            _inputLock = NO ; // in case the count was = 0 and we miss the unlock inside the if/then
            [NSThread sleepForTimeInterval:1.0] ;
        }
        if ([_output count] > 0) [self performCallback] ;
    }
    if (_runStringRef != LUA_NOREF) {
        luaL_unref(_L, LUA_REGISTRYINDEX, _runStringRef) ;
        _runStringRef = LUA_NOREF ;
    }
    lua_close(_L) ;
}

-(void)performCallback {
    if (_callbackRef != LUA_NOREF) {
        while(_outputLock) {} ;
        _outputLock          = YES ;
        NSString *outputCopy = [_output componentsJoinedByString:@""] ;
        [_output removeAllObjects] ;
        _outputLock          = NO ;
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin  = [LuaSkin shared] ;
            lua_State *L     = [skin L] ;
            [skin pushLuaRef:refTable ref:_callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:outputCopy] ;
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s: callback error: %s",
                                                          USERDATA_TAG,
                                                          lua_tolstring(L, -1, NULL)]] ;
                lua_pop(L, 1) ;
            }
        }) ;
    }
}

@end

#pragma mark - Module Functions

static int newLuaWithName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *name = (lua_gettop(L) == 1) ? [skin toNSObjectAtIndex:1] : [[NSUUID UUID] UUIDString] ;
    HSASMLuaThread *thread = [[HSASMLuaThread alloc] initWithName:name] ;
    if (thread) {
        [thread start] ;
        pushHSASMLuaThread(L, thread) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int assignments(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    assignmentsFromParent = [skin toNSObjectAtIndex:1] ;
    return 0 ;
}

#pragma mark - Hammerspoon Module Methods

static int threadIdle(lua_State *L) {
    HSASMLuaThread *thread = toHSASMLuaThreadFromLua(L, 1) ;
    lua_pushboolean(L, thread.idle) ;
    return 1 ;
}

static int threadExecuting(lua_State *L) {
    HSASMLuaThread *thread = toHSASMLuaThreadFromLua(L, 1) ;
    lua_pushboolean(L, thread.executing) ;
    return 1 ;
}

static int getOutput(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMLuaThread *thread = toHSASMLuaThreadFromLua(L, 1) ;
    while(thread.outputLock) {} ;
    thread.outputLock = YES ;
    [skin pushNSObject:[thread.output componentsJoinedByString:@"\n"]] ;
    [thread.output removeAllObjects] ;
    thread.outputLock = NO ;
    return 1 ;
}

static int inputQueue(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMLuaThread *thread = toHSASMLuaThreadFromLua(L, 1) ;
    while(thread.inputLock) {} ;
    thread.inputLock = YES ;
    [skin pushNSObject:thread.input] ;
    thread.inputLock = NO ;
    return 1 ;
}

static int flushOutput(lua_State *L) {
    HSASMLuaThread *thread = toHSASMLuaThreadFromLua(L, 1) ;
    while(thread.outputLock) {} ;
    thread.outputLock = YES ;
    [thread.output removeAllObjects] ;
    thread.outputLock = NO ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int flushInput(lua_State *L) {
    HSASMLuaThread *thread = toHSASMLuaThreadFromLua(L, 1) ;
    while(thread.inputLock) {} ;
    thread.inputLock = YES ;
    [thread.input removeAllObjects] ;
    thread.inputLock = NO ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int setCallback(lua_State *L) {
    if ([NSThread isMainThread]) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
        HSASMLuaThread *thread = toHSASMLuaThreadFromLua(L, 1) ;

        // in either case, we need to remove an existing callback, so...
        thread.callbackRef = [skin luaUnref:refTable ref:thread.callbackRef] ;
        if (lua_type(L, 2) == LUA_TFUNCTION) {
            lua_pushvalue(L, 2) ;
            thread.callbackRef = [skin luaRef:refTable] ;
            if (thread.selfRef == LUA_NOREF) {
                lua_pushvalue(L, 1) ;
                thread.selfRef = [skin luaRef:refTable] ;
            }
        } else {
            if (thread.selfRef != LUA_NOREF) {
                thread.selfRef = [skin luaUnref:refTable ref:thread.selfRef] ;
            }
        }
        lua_pushvalue(L, 1) ;
    } else {
        return luaL_error(L, "only available on the main thread") ;
    }
    return 1 ;
}

static int dumpDictionary(lua_State *L) {
    if ([NSThread isMainThread]) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
        HSASMLuaThread *thread = toHSASMLuaThreadFromLua(L, 1) ;
        [skin pushNSObject:[thread threadDictionary] withOptions:LS_NSUnsignedLongLongPreserveBits |
                                                                 LS_NSLuaStringAsDataOnly |
                                                                 LS_NSDescribeUnknownTypes |
                                                                 LS_NSAllowsSelfReference] ;
    } else {
        return luaL_error(L, "only available on the main thread") ;
    }
    return 1 ;
}

#pragma mark - Thread Methods

static int returnString(lua_State *L) {
    HSASMLuaThread *thread = toHSASMLuaThreadFromLua(L, 1) ;
    while(thread.outputLock) {} ;
    thread.outputLock = YES ;
    [thread.output addObject:[NSString stringWithFormat:@"%s", lua_tostring(L, 2)]] ;
    thread.outputLock = NO ;
    return 0 ;
}

static int threadCancelled(lua_State *L) {
    HSASMLuaThread *thread = toHSASMLuaThreadFromLua(L, 1) ;
    lua_pushboolean(L, thread.cancelled) ;
    return 1 ;
}

#pragma mark - Methods used by both

static int cancelThread(lua_State *L) {
    HSASMLuaThread *thread = toHSASMLuaThreadFromLua(L, 1) ;
    [thread cancel] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int threadName(lua_State *L) {
    HSASMLuaThread *thread = toHSASMLuaThreadFromLua(L, 1) ;
    lua_pushstring(L, [thread.name UTF8String]) ;
    return 1 ;
}

static int submitString(lua_State *L) {
    HSASMLuaThread *thread = toHSASMLuaThreadFromLua(L, 1) ;
    while(thread.inputLock) {} ;
    thread.inputLock = YES ;
    [thread.input addObject:[NSString stringWithFormat:@"%s", lua_tostring(L, 2)]] ;
    thread.inputLock = NO ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

// simplified version of what the LuaSkin push/to methods do, since we have more control over the
// types of data being shared
static int getHamster(lua_State *L, id obj, NSMutableDictionary *alreadySeen) {
    if ([alreadySeen objectForKey:obj]) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ;
    } else {
        if (!obj || [obj isKindOfClass:[NSNull class]]) {
            lua_pushnil(L) ;
        } else if ([obj isKindOfClass:[NSData class]]) {
            lua_pushlstring(L, [(NSData *)obj bytes], [(NSData *)obj length]) ;
        } else if ([obj isKindOfClass:[NSNumber class]]) {
            NSNumber *number = obj ;
            switch([number objCType][0]) {
                case 'c': lua_pushinteger(L, [number charValue]) ; break ;
                case 'C': lua_pushinteger(L, [number unsignedCharValue]) ; break ;
                case 'i': lua_pushinteger(L, [number intValue]) ; break ;
                case 'I': lua_pushinteger(L, [number unsignedIntValue]) ; break ;
                case 's': lua_pushinteger(L, [number shortValue]) ; break ;
                case 'S': lua_pushinteger(L, [number unsignedShortValue]) ; break ;
                case 'l': lua_pushinteger(L, [number longValue]) ; break ;
                case 'L': lua_pushinteger(L, (long long)[number unsignedLongValue]) ; break ;
                case 'q': lua_pushinteger(L, [number longLongValue]) ; break ;
                case 'Q': lua_pushinteger(L, (long long)[number unsignedLongLongValue]) ; break ;
                case 'f': lua_pushnumber(L,  [number floatValue]) ; break ;
                case 'd':
                default:  lua_pushnumber(L,  [number doubleValue]) ; break ;
            }
        } else if ([obj isKindOfClass:[NSDictionary class]]) {
            NSArray *keys = [obj allKeys];
            NSArray *values = [obj allValues];
            lua_newtable(L);
            [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(L, LUA_REGISTRYINDEX)] forKey:obj] ;
            lua_rawgeti(L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ;
            for (unsigned long i = 0; i < [keys count]; i++) {
                getHamster(L, [keys objectAtIndex:i], alreadySeen) ;
                getHamster(L, [values objectAtIndex:i], alreadySeen) ;
                lua_settable(L, -3);
            }
        } else if ([obj isKindOfClass:[HSASMBooleanType class]]) {
// Wrapping boolean like this only works here because we know the source and destination are both
// Lua... LuaSkin translates between languages with differing treatments of boolean, so it can't use
// this wrapper.
            lua_pushboolean(L, [(HSASMBooleanType *)obj value]) ;
        } else {
            lua_pushfstring(L, "** unknown:%s", [obj description]) ;
        }
    }
    return 1 ;
}

static int getItemFromDictionary(lua_State *L) {
    HSASMLuaThread *thread = toHSASMLuaThreadFromLua(L, 1) ;
    id obj ;
    luaL_checkstring(L, 2) ;
    while(thread.dictionaryLock) {} ;
    thread.dictionaryLock = YES ;
    obj = [[thread threadDictionary] objectForKey:[NSString stringWithFormat:@"%s", lua_tostring(L, 2)]] ;
    getHamster(L, obj, [[NSMutableDictionary alloc] init]) ;
    thread.dictionaryLock = NO ;
    return 1 ;
}

id setHamster(lua_State *L, int idx, NSMutableDictionary *alreadySeen) {
    idx = lua_absindex(L, idx) ;
    if ([alreadySeen objectForKey:[NSValue valueWithPointer:lua_topointer(L, idx)]]) {
        return [alreadySeen objectForKey:[NSValue valueWithPointer:lua_topointer(L, idx)]] ;
    }
    id obj ;
    if (lua_type(L, idx) == LUA_TNIL) {
        obj = nil ;
    } else if (lua_type(L, idx) == LUA_TSTRING) {
        size_t size ;
        unsigned char *junk = (unsigned char *)lua_tolstring(L, idx, &size) ;
        obj = [NSData dataWithBytes:(void *)junk length:size] ;
    } else if (lua_type(L, idx) == LUA_TNUMBER) {
        obj = lua_isinteger(L, idx) ? [NSNumber numberWithLongLong:lua_tointeger(L, idx)] :
                                      [NSNumber numberWithDouble:lua_tonumber(L, idx)] ;
    } else if (lua_type(L, idx) == LUA_TBOOLEAN) {
// Wrapping boolean like this only works here because we know the source and destination are both
// Lua... LuaSkin translates between languages with differing treatments of boolean, so it can't use
// this wrapper.
        obj = lua_toboolean(L, idx) ? [HSASMBooleanType withTrueValue] :
                                      [HSASMBooleanType withFalseValue] ;
    } else if (lua_type(L, idx) == LUA_TTABLE) {
        obj = [[NSMutableDictionary alloc] init] ;
        [alreadySeen setObject:obj forKey:[NSValue valueWithPointer:lua_topointer(L, idx)]] ;

        lua_pushnil(L);
        while (lua_next(L, idx) != 0) {
            id key = setHamster(L, -2, alreadySeen) ;
            id val = setHamster(L, -1, alreadySeen) ;
            if (key) {
                [obj setValue:val forKey:key];
                lua_pop(L, 1);
            } else {
                NSString *errMsg = [NSString stringWithFormat:@"table key (%s) cannot be converted",
                                                             luaL_tolstring(L, -2, NULL)] ;
                lua_pop(L, 3) ; // luaL_tolstring result, lua_next value, and lua_next key
                luaL_error(L, [errMsg UTF8String]) ;
                return nil ;
            }
        }
    } else {
        obj = [NSString stringWithFormat:@"** unsupported type:%s", lua_typename(L, lua_type(L, idx))] ;
    }
    return obj ;
}

static int setItemInDictionary(lua_State *L) {
    HSASMLuaThread *thread = toHSASMLuaThreadFromLua(L, 1) ;
    id obj = setHamster(L, 3, [[NSMutableDictionary alloc] init]) ;
    luaL_checkstring(L, 2) ;
    while(thread.dictionaryLock) {} ;
    thread.dictionaryLock = YES ;
    [[thread threadDictionary] setValue:obj forKey:[NSString stringWithFormat:@"%s", lua_tostring(L, 2)]] ;
    thread.dictionaryLock = NO ;
    return 0 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSASMLuaThread(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMLuaThread *value = obj;
    if (value.selfRef == LUA_NOREF) {
        void** valuePtr = lua_newuserdata(L, sizeof(HSASMLuaThread *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
    } else {
        [skin pushLuaRef:refTable ref:value.selfRef] ;
    }
    return 1;
}

static id toHSASMLuaThreadFromLua(lua_State *L, int idx) {
    HSASMLuaThread *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSASMLuaThread, L, idx, USERDATA_TAG) ;
    } else if ([NSThread isMainThread]) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                  lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushHSASMBooleanType(lua_State *L, id obj) {
    HSASMBooleanType *value = obj ;
    lua_pushboolean(L, value.value) ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    HSASMLuaThread *obj = get_objectFromUserdata(__bridge HSASMLuaThread, L, 1, USERDATA_TAG) ;
    NSString *title = [obj name] ;
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        HSASMLuaThread *obj1 = get_objectFromUserdata(__bridge HSASMLuaThread, L, 1, USERDATA_TAG) ;
        HSASMLuaThread *obj2 = get_objectFromUserdata(__bridge HSASMLuaThread, L, 2, USERDATA_TAG) ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSASMLuaThread *obj ;
    if ([NSThread isMainThread]) {
        obj = get_objectFromUserdata(__bridge_transfer HSASMLuaThread, L, 1, USERDATA_TAG) ;
        NSLog(@"%s:__gc main thread for %@", USERDATA_TAG, obj.name) ;
    } else {
        obj = get_objectFromUserdata(__bridge HSASMLuaThread, L, 1, USERDATA_TAG) ;
        NSLog(@"%s:__gc child thread for %@", USERDATA_TAG, obj.name) ;
    }
    if (obj) {
        if ([NSThread isMainThread]) {
            LuaSkin *skin = [LuaSkin shared] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.selfRef = [skin luaUnref:refTable ref:obj.selfRef] ;
            [obj cancel] ;
        }
        obj = nil ;
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
    {"cancel",      cancelThread},
    {"name",        threadName},
    {"idle",        threadIdle},
    {"executing",   threadExecuting},
    {"submit",      submitString},
    {"setCallback", setCallback},
    {"flushInput",  flushInput},
    {"flushOutput", flushOutput},
    {"getOutput",   getOutput},
    {"inputQueue",  inputQueue},
    {"get",         getItemFromDictionary},
    {"set",         setItemInDictionary},

    {"dump",         dumpDictionary},

    {"__tostring",  userdata_tostring},
    {"__eq",        userdata_eq},
    {"__gc",        userdata_gc},
    {NULL,          NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",          newLuaWithName},
    {"_assignments", assignments},

    {NULL,                NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_luathread_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    assignmentsFromParent = nil ;

    [skin registerPushNSHelper:pushHSASMLuaThread         forClass:"HSASMLuaThread"];
    [skin registerLuaObjectHelper:toHSASMLuaThreadFromLua forClass:"HSASMLuaThread"
                                               withUserdataMapping:USERDATA_TAG];

    [skin registerPushNSHelper:pushHSASMBooleanType       forClass:"HSASMBooleanType"];

    return 1;
}
