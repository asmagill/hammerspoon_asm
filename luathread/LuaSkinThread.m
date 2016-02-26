// Create a LuaSkin subclass which can be unique per thread
//
// This is not quite a drop-in replacement for LuaSkin in modules which use LuaSkin...
// At a minimum, all references to [LuaSkin shared] need to be replaced with
//                                 [LuaSkin performSelector:@selector(thread)].
// If you wish for a module to work in more than one luathread instance at the same time,
//    you should also store refTable values in the thread dictionary as demonstrated in
//    the modules included in the luathread modules/ sub-directory.
//
// Modules might also need additional changes if they dispatch blocks to the main queue or
//    explicitly call selectors on the main thread... some examples of changes that work can
//    be found in the modules/ sub-directory of the luathread repository and an example of a
//    third-party module which is written to be compatible with both core Hammerspoon and
//    luathreads can be seen in hs._asm.notificationcenter
//
// Currently all of these referenced modules/repositories are subdirectories of
//    https://github.com/asmagill/hammerspoon_asm.  If this change, I will try to keep
//    these notes up-to-date

@import LuaSkin ;
#import <objc/runtime.h>

// I don't remember why the tracking dictionarys were added as local static variables in
// LuaSkin rather than as properties of the object itself, but they were, so we have to use
// our own properties and override any method which uses them to keep our conversion
// functions safe with a LuaSkin subclass...

@interface LuaSkinThread : LuaSkin
@property NSMutableDictionary *registeredNSHelperFunctions ;
@property NSMutableDictionary *registeredNSHelperLocations ;
@property NSMutableDictionary *registeredLuaObjectHelperFunctions ;
@property NSMutableDictionary *registeredLuaObjectHelperLocations ;
@property NSMutableDictionary *registeredLuaObjectHelperUserdataMappings ;

+(BOOL)inject ;
+(id)thread ;
@end

// Since the overridden methods reference these, we need the interface available here as well,
// since it isn't included in the stock LuaSkin.h

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

// Inject a new class method for use as a replacement for [LuaSkin shared] in a threaded instance.
// We do this, rather than swizzle shared itself because LuaSkin isn't the only component of a module
// that needs to be thread-aware/thread-safe, so we still want modules which haven't been explicitly
// looked at and tested to fail to load within the luathread... by leaving the shared class method
// alone, an exception is still thrown for untested modules and we don't potentially introduce new
// unintended side-effects in to the core LuaSkin and Hammerspoon modules

+(BOOL)inject {
    static dispatch_once_t onceToken ;
    static BOOL            injected = NO ;

    dispatch_once(&onceToken, ^{

        // since we're adding a class method, we need to get LuaSkin's metaclass... this is the
        // easiest way to do so...
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
    // if we're on the main thread, go ahead and act normally
    if ([NSThread isMainThread]) return [LuaSkin shared] ;

    // otherwise, we're storing the LuaSkin instance in the thread's dictionary
    NSThread      *thisThread = [NSThread currentThread] ;

    LuaSkinThread *thisSkin   = [thisThread.threadDictionary objectForKey:@"_LuaSkin"] ;
    if (!thisSkin) {
        thisSkin = [[LuaSkinThread alloc] init] ;
        [thisThread.threadDictionary setObject:thisSkin forKey:@"_LuaSkin"];
        [thisThread.threadDictionary setObject:[[NSMutableDictionary alloc] init] forKey:@"_refTables"] ;
    }
    return thisSkin ;
}

// the following methods override the LuaSkin methods we need to make this work

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
    NSLog(@"LuaSkinThread destroyLuaState");
    NSAssert((_L != NULL), @"LuaSkinThread destroyLuaState called with no Lua environment", nil);
    if (_L) {
        lua_close(_L);
        [_registeredNSHelperFunctions removeAllObjects] ;
        [_registeredNSHelperLocations removeAllObjects] ;
        [_registeredLuaObjectHelperFunctions removeAllObjects] ;
        [_registeredLuaObjectHelperLocations removeAllObjects] ;
        [_registeredLuaObjectHelperUserdataMappings removeAllObjects];
        NSThread      *thisThread = [NSThread currentThread] ;
        [thisThread.threadDictionary removeObjectForKey:@"_LuaSkin"] ;
        [thisThread.threadDictionary removeObjectForKey:@"_refTables"] ;
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