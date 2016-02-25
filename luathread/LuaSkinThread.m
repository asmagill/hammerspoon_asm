@import LuaSkin ;
#import <objc/runtime.h>

@interface LuaSkinThread : LuaSkin
@property NSMutableDictionary *registeredNSHelperFunctions ;
@property NSMutableDictionary *registeredNSHelperLocations ;
@property NSMutableDictionary *registeredLuaObjectHelperFunctions ;
@property NSMutableDictionary *registeredLuaObjectHelperLocations ;
@property NSMutableDictionary *registeredLuaObjectHelperUserdataMappings ;

+(BOOL)inject ;
+(id)thread ;
@end

@interface LuaSkin (conversionSupport)

// internal methods for pushNSObject
- (int)pushNSObject:(id)obj     withOptions:(LS_NSConversionOptions)options
                         alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSNumber:(id)obj     withOptions:(LS_NSConversionOptions)options ;
- (int)pushNSArray:(id)obj      withOptions:(LS_NSConversionOptions)options
                         alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSSet:(id)obj        withOptions:(LS_NSConversionOptions)options
                         alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSDictionary:(id)obj withOptions:(LS_NSConversionOptions)options
                         alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;

// internal methods for toNSObjectAtIndex
- (id)toNSObjectAtIndex:(int)idx withOptions:(LS_NSConversionOptions)options
                          alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (id)tableAtIndex:(int)idx      withOptions:(LS_NSConversionOptions)options
                          alreadySeenObjects:(NSMutableDictionary *)alreadySeen;
@end

@implementation LuaSkinThread

+(BOOL)inject {
    static dispatch_once_t onceToken ;
    static BOOL            injected = NO ;

    dispatch_once(&onceToken, ^{
        Class  oldClass = object_getClass([LuaSkin class]) ;
        Class  newClass = [LuaSkinThread class] ;
        SEL    selector = @selector(thread) ;
        Method method   = class_getClassMethod(newClass, selector) ;

        BOOL wasAdded = class_addMethod(oldClass,
                                        selector,
                                        method_getImplementation(method),
                                        method_getTypeEncoding(method)) ;
        if (wasAdded) {
            injected = YES ;
        } else {
            [[LuaSkin shared] logError:@"Unable to inject thread method into LuaSkin"] ;
        }
    });
    return injected ;
}

+(id)thread {
    if ([NSThread isMainThread]) return [LuaSkin shared] ;
    NSThread      *thisThread = [NSThread currentThread] ;
    LuaSkinThread *thisSkin   = [thisThread.threadDictionary objectForKey:[@"_LuaSkin" dataUsingEncoding:NSUTF8StringEncoding]] ;
    if (!thisSkin) {
        thisSkin = [[LuaSkinThread alloc] init] ;
        [thisThread.threadDictionary setObject:thisSkin forKey:[@"_LuaSkin" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    return thisSkin ;
}

- (id)init {
    self = [super init];
    if (self) {
        if (_L == NULL) [self createLuaState] ;
        _registeredNSHelperFunctions               = [[NSMutableDictionary alloc] init] ;
        _registeredNSHelperLocations               = [[NSMutableDictionary alloc] init] ;
        _registeredLuaObjectHelperFunctions        = [[NSMutableDictionary alloc] init] ;
        _registeredLuaObjectHelperLocations        = [[NSMutableDictionary alloc] init] ;
        _registeredLuaObjectHelperUserdataMappings = [[NSMutableDictionary alloc] init] ;
    }
    return self;
}

- (void)destroyLuaState {
    NSLog(@"destroyLuaState");
    NSAssert((_L != NULL), @"destroyLuaState called with no Lua environment", nil);
    if (_L) {
        lua_close(_L);
        [_registeredNSHelperFunctions removeAllObjects] ;
        [_registeredNSHelperLocations removeAllObjects] ;
        [_registeredLuaObjectHelperFunctions removeAllObjects] ;
        [_registeredLuaObjectHelperLocations removeAllObjects] ;
        [_registeredLuaObjectHelperUserdataMappings removeAllObjects];
    }
    _L = NULL;
}

- (BOOL)registerPushNSHelper:(pushNSHelperFunction)helperFN forClass:(char*)className {
    BOOL allGood = NO ;
// this hackery assumes that this method is only called from within the luaopen_* function of a module and
// attempts to compensate for a wrapper to "require"... I doubt anyone is actually using it anymore.
    int level = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"HSLuaSkinRegisterRequireLevel"];
    if (level == 0) level = 3 ;

    if (className && helperFN) {
        if ([_registeredNSHelperFunctions objectForKey:[NSString stringWithUTF8String:className]]) {
            [self logAtLevel:LS_LOG_WARN
                 withMessage:[NSString stringWithFormat:@"registerPushNSHelper:forClass:%s already defined at %@",
                                                        className,
                                                        [_registeredNSHelperLocations objectForKey:[NSString stringWithUTF8String:className]]]
                fromStackPos:level] ;
        } else {
            luaL_where(_L, level) ;
            NSString *locationString = [NSString stringWithFormat:@"%s", lua_tostring(_L, -1)] ;
            [_registeredNSHelperLocations setObject:locationString
                                             forKey:[NSString stringWithUTF8String:className]] ;
            [_registeredNSHelperFunctions setObject:[NSValue valueWithPointer:(void *)helperFN]
                                             forKey:[NSString stringWithUTF8String:className]] ;
            lua_pop(_L, 1) ;
            allGood = YES ;
        }
    } else {
        [self logAtLevel:LS_LOG_WARN
             withMessage:@"registerPushNSHelper:forClass: requires both helperFN and className"
             fromStackPos:level] ;
    }
    return allGood ;
}

- (id)luaObjectAtIndex:(int)idx toClass:(char *)className {
    NSString *theClass = [NSString stringWithUTF8String:(const char *)className] ;

    for (id key in _registeredLuaObjectHelperFunctions) {
        if ([theClass isEqualToString:key]) {
            luaObjectHelperFunction theFunc = (luaObjectHelperFunction)[[_registeredLuaObjectHelperFunctions objectForKey:key] pointerValue] ;
            return theFunc(_L, lua_absindex(_L, idx)) ;
        }
    }
    return nil ;
}

- (BOOL)registerLuaObjectHelper:(luaObjectHelperFunction)helperFN forClass:(char*)className {
    BOOL allGood = NO ;
// this hackery assumes that this method is only called from within the luaopen_* function of a module and
// attempts to compensate for a wrapper to "require"... I doubt anyone is actually using it anymore.
    int level = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"HSLuaSkinRegisterRequireLevel"];
    if (level == 0) level = 3 ;

    if (className && helperFN) {
        if ([_registeredLuaObjectHelperFunctions objectForKey:[NSString stringWithUTF8String:className]]) {
            [self logAtLevel:LS_LOG_WARN
                 withMessage:[NSString stringWithFormat:@"registerLuaObjectHelper:forClass:%s already defined at %@",
                                                        className,
                                                        [_registeredLuaObjectHelperFunctions objectForKey:[NSString stringWithUTF8String:className]]]
                fromStackPos:level] ;
        } else {
            luaL_where(_L, level) ;
            NSString *locationString = [NSString stringWithFormat:@"%s", lua_tostring(_L, -1)] ;
            [_registeredLuaObjectHelperLocations setObject:locationString
                                                forKey:[NSString stringWithUTF8String:className]] ;
            [_registeredLuaObjectHelperFunctions setObject:[NSValue valueWithPointer:(void *)helperFN]
                                                forKey:[NSString stringWithUTF8String:className]] ;
            lua_pop(_L, 1) ;
            allGood = YES ;
        }
    } else {
        [self logAtLevel:LS_LOG_WARN
             withMessage:@"registerLuaObjectHelper:forClass: requires both helperFN and className"
            fromStackPos:level] ;
    }
    return allGood ;
}

- (BOOL)registerLuaObjectHelper:(luaObjectHelperFunction)helperFN forClass:(char *)className withUserdataMapping:(char *)userdataTag {
    BOOL allGood = [self registerLuaObjectHelper:helperFN forClass:className];
    if (allGood)
        [_registeredLuaObjectHelperUserdataMappings setObject:[NSString stringWithUTF8String:className] forKey:[NSString stringWithUTF8String:userdataTag]];
    return allGood ;
}

- (int)pushNSObject:(id)obj withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    if (obj) {
// NOTE: We catch self-referential loops, do we also need a recursive depth?  Will crash at depth of 512...
        if ([alreadySeen objectForKey:obj]) {
            lua_rawgeti(_L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ;
            return 1 ;
        }

        // check for registered helpers

        for (id key in _registeredNSHelperFunctions) {
            if ([obj isKindOfClass: NSClassFromString(key)]) {
                pushNSHelperFunction theFunc = (pushNSHelperFunction)[[_registeredNSHelperFunctions objectForKey:key] pointerValue] ;
                return theFunc(_L, obj) ;
            }
        }

        // Check for built-in classes

        if ([obj isKindOfClass:[NSNull class]]) {
            lua_pushnil(_L) ;
        } else if ([obj isKindOfClass:[NSNumber class]]) {
            [self pushNSNumber:obj withOptions:options] ;
        } else if ([obj isKindOfClass:[NSString class]]) {
                size_t size = [(NSString *)obj lengthOfBytesUsingEncoding:NSUTF8StringEncoding] ;
                lua_pushlstring(_L, [(NSString *)obj UTF8String], size) ;
        } else if ([obj isKindOfClass:[NSData class]]) {
            lua_pushlstring(_L, [(NSData *)obj bytes], [(NSData *)obj length]) ;
        } else if ([obj isKindOfClass:[NSDate class]]) {
            lua_pushinteger(_L, lround([(NSDate *)obj timeIntervalSince1970])) ;
        } else if ([obj isKindOfClass:[NSArray class]]) {
            [self pushNSArray:obj withOptions:options alreadySeenObjects:alreadySeen] ;
        } else if ([obj isKindOfClass:[NSSet class]]) {
            [self pushNSSet:obj withOptions:options alreadySeenObjects:alreadySeen] ;
        } else if ([obj isKindOfClass:[NSDictionary class]]) {
            [self pushNSDictionary:obj withOptions:options alreadySeenObjects:alreadySeen] ;
        } else if ([obj isKindOfClass:[NSURL class]]) {
// normally I'd make a class a helper registered as part of a module; however, NSURL is common enough
// and 99% of the time we just want it stringified... by putting it in here, if someone needs it to do
// more later, they can register a helper to catch the object before it reaches here.
            lua_pushstring(_L, [[obj absoluteString] UTF8String]) ;
        } else {
            if ((options & LS_NSDescribeUnknownTypes) == LS_NSDescribeUnknownTypes) {
                [self logDebug:[NSString stringWithFormat:@"unrecognized type %@; converting to '%@'", NSStringFromClass([obj class]), [obj debugDescription]]] ;
                lua_pushstring(_L, [[NSString stringWithFormat:@"%@", [obj debugDescription]] UTF8String]) ;
            } else if ((options & LS_NSIgnoreUnknownTypes) == LS_NSIgnoreUnknownTypes) {
                [self logDebug:[NSString stringWithFormat:@"unrecognized type %@; ignoring", NSStringFromClass([obj class])]] ;
                return 0 ;
            }else {
                [self logDebug:[NSString stringWithFormat:@"unrecognized type %@; returning nil", NSStringFromClass([obj class])]] ;
                lua_pushnil(_L) ;
            }
        }
    } else {
        lua_pushnil(_L) ;
    }
    return 1 ;
}

@end