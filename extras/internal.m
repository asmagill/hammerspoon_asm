// Start adding comments about what spawned some of these ideas -- I have *NO* idea now
// why I ever started some of these...


@import Cocoa ;
@import Carbon ;
@import LuaSkin ;
@import AVFoundation;
@import OSAKit ;
@import Darwin.POSIX.dlfcn ;

static LSRefTable refTable = LUA_NOREF ;

static NSMutableSet *backgroundCallbacks ;

@import AddressBook ;
@import SystemConfiguration ;

// @import QuartzCore.CATransform3D; // for NSValue conversion of CATransform3D
// @import SceneKit;   // for NSValue conversion of SCNVector3, SCNVector4, SCNMatrix4
// @import AVFoundation.AVTime;      // for NSValue conversion of CMTime, CMTimeRange, CMTimeMapping
// @import MapKit.MKGeometry;        // for NSValue conversion of CLLocationCoordinate2D, MKCoordinateSpan

@import IOKit.pwr_mgt ;

@import Darwin.POSIX.netdb ;
@import Darwin.Mach ;

@interface ASM_RETAIN_TEST : NSObject
@end

// curious if ARC recognizes ID type since retain/relase are part of NSObject protocol
// it seems to based on this basic test... when sent to obj class, count = 5 for both
@implementation ASM_RETAIN_TEST
- (void)withString:(NSString *)sender withState:(lua_State *)L {
    NSUInteger c ;
    NSMethodSignature *signature  = [NSNumber instanceMethodSignatureForSelector:NSSelectorFromString(@"unsignedIntegerValue")] ;
    NSInvocation      *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:sender];
    [invocation setSelector:NSSelectorFromString(@"retainCount")];
    [invocation invoke];
    [invocation getReturnValue:&c];
    lua_pushinteger(L, (lua_Integer)c) ;
}

- (void)withId:(id)sender withState:(lua_State *)L {
    NSUInteger c ;
    NSMethodSignature *signature  = [NSNumber instanceMethodSignatureForSelector:NSSelectorFromString(@"unsignedIntegerValue")] ;
    NSInvocation      *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:sender];
    [invocation setSelector:NSSelectorFromString(@"retainCount")];
    [invocation invoke];
    [invocation getReturnValue:&c];
    lua_pushinteger(L, (lua_Integer)c) ;
}

@end

static int testARCandID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *holder = [skin toNSObjectAtIndex:1] ;
    id       hold2   = [skin toNSObjectAtIndex:1] ;

    ASM_RETAIN_TEST *obj = [[ASM_RETAIN_TEST alloc] init] ;
    [obj withString:holder withState:L] ;
    [obj withId:hold2      withState:L] ;

// when invoked directly on stored variables, count = 4
    NSUInteger c ;
    NSMethodSignature *signature  = [NSNumber instanceMethodSignatureForSelector:NSSelectorFromString(@"unsignedIntegerValue")] ;
    NSInvocation      *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:holder];
    [invocation setSelector:NSSelectorFromString(@"retainCount")];
    [invocation invoke];
    [invocation getReturnValue:&c];
    lua_pushinteger(L, (lua_Integer)c) ;

    invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:hold2];
    [invocation setSelector:NSSelectorFromString(@"retainCount")];
    [invocation invoke];
    [invocation getReturnValue:&c];
    lua_pushinteger(L, (lua_Integer)c) ;

// and here count = 3
    invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:[skin toNSObjectAtIndex:1]];
    [invocation setSelector:NSSelectorFromString(@"retainCount")];
    [invocation invoke];
    [invocation getReturnValue:&c];
    lua_pushinteger(L, (lua_Integer)c) ;

    return 5 ;
}

/// hs._asm.extras.NSLog(luavalue)
/// Function
/// Send a representation of the lua value passed in to the Console application via NSLog.
static int extras_nslog(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    id val = [skin toNSObjectAtIndex:1] ;
    NSLog(@"%@", val);
    return 0;
}

/// hs._asm.extras.listWindows([includeDesktopElements])
/// Function
/// Returns an array containing information about all available windows, even those ignored by hs.window
///
/// Parameters:
///  * includeDesktopElements - defaults to false; if true, includes windows which that are elements of the desktop, including the background picture and desktop icons.
///
/// Returns:
///  * An array of windows in the order in which CGWindowListCopyWindowInfo returns them.  Each window entry is a table that contains the information returned by the CoreGraphics CGWindowListCopyWindowInfo function for that window.
///
/// Notes:
///  * The companion function, hs._asm.extras.windowsByName, groups windows a little more usefully and utilizes metatables to allow an easier browsing experience of the data from the console.
///  * The results of this function are of dubious value at the moment... while it should be possible to determine what windows are on other spaces (though probably not which space -- just "this space" or "not this space") there is at present no way to positively distinguish "real" windows from "virtual" windows used for internal application purposes.
///  * This may also provide a mechanism for determine when Mission Control or other System displays are active, but this is untested at present.
static int listWindows(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
//     CFArrayRef windowInfosRef = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID) ;

    CFArrayRef windowInfosRef = CGWindowListCopyWindowInfo(kCGWindowListOptionAll | (lua_toboolean(L,1) ? 0 : kCGWindowListExcludeDesktopElements), kCGNullWindowID) ;
    // CGWindowID(0) is equal to kCGNullWindowID
    NSArray *windowList = CFBridgingRelease(windowInfosRef) ;  // same as __bridge_transfer
    [skin pushNSObject:windowList] ;
    return 1 ;
}

static int extras_defaults(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    NSString *newBundle = [[NSBundle mainBundle] bundleIdentifier] ;
    if (newBundle) {
        NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:newBundle] ;
        [skin pushNSObject:defaults] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}

/// hs._asm.extras.userDataToString(userdata) -> string
/// Function
/// Returns the userdata object as a binary string. Usually userdata is pretty boring -- containing c pointers, etc.  However, for some of the more complex userdata blobs for callbacks and such this can be useful with hs._asm.extras.hexdump for debugging to see what parts of the structure are actually getting set, etc.
static int ud_tostring (lua_State *L) {
    void *data = lua_touserdata(L,1);
    size_t sz;
    if (data == NULL) {
        lua_pushnil(L);
        lua_pushstring(L,"not a userdata type");
        return 2;
    } else {
        sz = lua_rawlen(L,1);
        lua_pushlstring(L,data,sz);
        return 1;
    }
}

static int threadInfo(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    lua_newtable(L) ;
      lua_pushboolean(L, [NSThread isMainThread]) ; lua_setfield(L, -2, "isMainThread") ;
      lua_pushboolean(L, [NSThread isMultiThreaded]) ; lua_setfield(L, -2, "isMultiThreaded") ;
      [skin pushNSObject:[[NSThread currentThread] threadDictionary]] ;
        lua_setfield(L, -2, "threadDictionary") ;
      [skin pushNSObject:[[NSThread currentThread] name]] ;
        lua_setfield(L, -2, "name") ;
      lua_pushinteger(L, (lua_Integer)[[NSThread currentThread] stackSize]) ; lua_setfield(L, -2, "stackSize") ;
      lua_pushnumber(L, [[NSThread currentThread] threadPriority]) ; lua_setfield(L, -2, "threadPriority") ;
    return 1 ;
}

static int addressbookGroups(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin pushNSObject:[[ABAddressBook sharedAddressBook] groups] withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

static int addressParserTesting(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *input = [skin toNSObjectAtIndex:1] ;
//     struct addrinfo {
//         int ai_flags;           /* input flags */
//         int ai_family;          /* protocol family for socket */
//         int ai_socktype;        /* socket type */
//         int ai_protocol;        /* protocol for socket */
//         socklen_t ai_addrlen;   /* length of socket-address */
//         struct sockaddr *ai_addr; /* socket-address for socket */
//         char *ai_canonname;     /* canonical name for service location */
//         struct addrinfo *ai_next; /* pointer to next in list */
//     };
    struct addrinfo *results = NULL ;
    struct addrinfo hints = { AI_NUMERICHOST | AI_NUMERICSERV | AI_V4MAPPED_CFG, PF_UNSPEC, 0, 0, 0, NULL, NULL, NULL } ;
    int ecode = getaddrinfo([input UTF8String], NULL, &hints, &results);
    if (ecode == 0) {
        struct addrinfo *current = results ;
        lua_newtable(L) ;
        while(current) {
            switch(current->ai_family) {
                case PF_INET:  lua_pushstring(L, "IPv4") ; break ;
                case PF_INET6: lua_pushstring(L, "IPv6") ; break ;
                default: lua_pushfstring(L, "unknown family: %d", current->ai_family) ; break ;
            }
            lua_setfield(L, -2, "family") ;
            switch(current->ai_socktype) {
                case SOCK_STREAM: lua_pushstring(L, "stream") ; break ;
                case SOCK_DGRAM:  lua_pushstring(L, "datagram") ; break ;
                case SOCK_RAW:    lua_pushstring(L, "raw") ; break ;
                default: lua_pushfstring(L, "unknown socket type: %d", current->ai_socktype) ; break ;
            }
            lua_setfield(L, -2, "socktype") ;
            switch(current->ai_protocol) {
                case IPPROTO_TCP: lua_pushstring(L, "tcp") ; break ;
                case IPPROTO_UDP: lua_pushstring(L, "udp") ; break ;
                default: lua_pushfstring(L, "unknown protocol type: %d", current->ai_protocol) ; break ;
            }
            lua_setfield(L, -2, "protocol") ;

            lua_pushinteger(L, current->ai_addrlen) ; lua_setfield(L, -2, "length") ;
            [skin pushNSObject:[NSData dataWithBytes:current->ai_addr length:current->ai_addrlen]] ;
            lua_setfield(L, -2, "rawData") ;

            int  err;
            char addrStr[NI_MAXHOST];
            err = getnameinfo(current->ai_addr, current->ai_addrlen, addrStr, sizeof(addrStr), NULL, 0, NI_NUMERICHOST | NI_WITHSCOPEID | NI_NUMERICSERV);
            if (err == 0) {
                lua_pushstring(L, addrStr) ;
            } else {
                lua_pushfstring(L, "** error:%s", gai_strerror(err)) ;
            }
            lua_setfield(L, -2, "addressAsString") ;

            lua_pushstring(L, current->ai_canonname) ; lua_setfield(L, -2, "canonname") ;
            current = current->ai_next ;
        }
    }
    if (results) freeaddrinfo(results) ;
    if (ecode != 0) return luaL_error(L, "address parse error: %s", gai_strerror(ecode)) ;
    return 1 ;
}

static int getSCPreferencesKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *prefName = (lua_gettop(L) == 0) ? nil : [skin toNSObjectAtIndex:1] ;
    NSString *theName = [[NSUUID UUID] UUIDString] ;
    SCPreferencesRef thePrefs = SCPreferencesCreate(kCFAllocatorDefault, (__bridge CFStringRef)theName, (__bridge CFStringRef)prefName);
    CFArrayRef keys = SCPreferencesCopyKeyList(thePrefs);
    [skin pushNSObject:(__bridge NSArray *)keys] ;
    CFRelease(keys) ;
    CFRelease(thePrefs) ;
    return 1 ;
}

static int getSCPreferencesValueForKey(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *keyName = [skin toNSObjectAtIndex:1] ;
    NSString *theName = [[NSUUID UUID] UUIDString] ;
    SCPreferencesRef thePrefs  = SCPreferencesCreate(kCFAllocatorDefault, (__bridge CFStringRef)theName, NULL);
    SCPreferencesLock(thePrefs, true) ;
    CFPropertyListRef theValue = SCPreferencesGetValue(thePrefs, (__bridge CFStringRef)keyName);
    SCPreferencesUnlock(thePrefs) ;
    CFTypeID theType = CFGetTypeID(theValue) ;
    if (theType == CFDataGetTypeID())            { [skin pushNSObject:(__bridge NSData *)theValue] ; }
    else if (theType == CFStringGetTypeID())     { [skin pushNSObject:(__bridge NSString *)theValue] ; }
    else if (theType == CFArrayGetTypeID())      { [skin pushNSObject:(__bridge NSArray *)theValue] ; }
    else if (theType == CFDictionaryGetTypeID()) { [skin pushNSObject:(__bridge NSDictionary *)theValue] ; }
    else if (theType == CFDateGetTypeID())       { [skin pushNSObject:(__bridge NSDate *)theValue] ; }
    else if (theType == CFBooleanGetTypeID())    { [skin pushNSObject:(__bridge NSNumber *)theValue] ; }
    else if (theType == CFNumberGetTypeID())     { [skin pushNSObject:(__bridge NSNumber *)theValue] ; }
    else { [skin pushNSObject:[NSString stringWithFormat:@"** invalid CF type %lu", theType]] ; }
    CFRelease(thePrefs) ;
    return 1 ;
}

static int networkUserPreferences(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK] ;

    CFStringRef     serviceID ;
    CFDictionaryRef userOptions ;

    Boolean results = SCNetworkConnectionCopyUserPreferences(NULL, &serviceID, &userOptions);
    if (results) {
        lua_newtable(L) ;
        [skin pushNSObject:(__bridge NSString *)serviceID] ;       lua_setfield(L, -2, "serviceID") ;
        [skin pushNSObject:(__bridge NSDictionary *)userOptions] ; lua_setfield(L, -2, "userOptions") ;
//         CFRelease(serviceID) ;   // I know the function says "copy", but it's returning a reference, and
//         CFRelease(userOptions) ; // including these causes a crash, so...
    } else {
        lua_pushnil(L) ; // no dial-able (i.e. PPP or PPPOE) service
    }
    return 1 ;
}

// // http://stackoverflow.com/questions/1976520/lock-screen-by-api-in-mac-os-x/26492632#26492632
// extern int SACLockScreenImmediate();
// static int lockscreen(lua_State* L)
// {
//   lua_pushinteger(L, SACLockScreenImmediate()) ;
//   return 1 ;
// }

// I like this better... cleaner IMO, and doesn't require linking against a private framework
// https://gist.github.com/cardi/3e2b527a2ec819d51916604528986e93
// http://apple.stackexchange.com/questions/80058/lock-screen-command-one-liner

static int lockscreen(__unused lua_State* L) {
    NSBundle *bundle = [NSBundle bundleWithPath:@"/Applications/Utilities/Keychain Access.app/Contents/Resources/Keychain.menu"];
    Class principalClass = [bundle principalClass];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Wobjc-messaging-id"
    id instance = [[principalClass alloc] init];
    [instance performSelector:@selector(_lockScreenMenuHit:) withObject:nil];
#pragma clang diagnostic pop

    return 0;
}

static int nsvalueTest2(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    id obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:obj withOptions:LS_NSUnsignedLongLongPreserveBits |
                                       LS_NSDescribeUnknownTypes         |
                                       LS_NSPreserveLuaStringExactly] ;
    if (lua_type(L, -1) == LUA_TTABLE) {
        [skin pushNSObject:[(NSObject *)obj className]] ; lua_setfield(L, -2, "__className") ;
    }
    return 1 ;
}

static int sizeAndAlignment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    const char *objCType = lua_tostring(L, 1) ;

    lua_newtable(L) ;
    while(*objCType) {
        NSUInteger actualSize, alignedSize ;
        const char *next ;
        @try {
            next = NSGetSizeAndAlignment(objCType, &actualSize, &alignedSize) ;
        } @catch (NSException *theException) {
            [skin logError:[NSString stringWithFormat:@"%@:%@", [theException name], [theException reason]]] ;
            return 0 ;
        }
        lua_newtable(L) ;
        char *tmp = calloc(1, (size_t)(next - objCType) + 1) ;
        strncpy(tmp, objCType, (size_t)(next - objCType)) ;
        lua_pushstring(L, tmp) ; free(tmp) ;           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushinteger(L, (lua_Integer)actualSize) ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushinteger(L, (lua_Integer)alignedSize) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        objCType = next ;
    }
    if (luaL_len(L, -1) == 1) {
        lua_rawgeti(L, -1, 1) ;
        lua_remove(L, -2) ;
    }
    return 1 ;
}

static int lookup(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *word = [skin toNSObjectAtIndex:1] ;
    CFRange  range = CFRangeMake(0, (CFIndex)[word length]) ;

    [skin pushNSObject:(__bridge_transfer NSString *)DCSCopyTextDefinition(NULL,
                                                                           (__bridge CFStringRef)word,
                                                                           range)] ;
    return 1 ;
}

static int testLabeledTable1(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TTYPEDTABLE, "NSRect", LS_TBREAK] ;
    lua_pushboolean(L, YES) ;
    return 1;
}

static int testLabeledTable2(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TTYPEDTABLE, LS_TBREAK] ;
    lua_pushboolean(L, YES) ;
    return 1;
}

static int hs_volumeInformation(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableDictionary *volumeInfo = [[NSMutableDictionary alloc] init];

    NSArray *urlResourceKeys = @[
                                    NSURLVolumeLocalizedFormatDescriptionKey,
                                    NSURLVolumeTotalCapacityKey,
                                    NSURLVolumeAvailableCapacityKey,
                                    NSURLVolumeResourceCountKey,
                                    NSURLVolumeSupportsPersistentIDsKey,
                                    NSURLVolumeSupportsSymbolicLinksKey,
                                    NSURLVolumeSupportsHardLinksKey,
                                    NSURLVolumeSupportsJournalingKey,
                                    NSURLVolumeIsJournalingKey,
                                    NSURLVolumeSupportsSparseFilesKey,
                                    NSURLVolumeSupportsZeroRunsKey,
                                    NSURLVolumeSupportsCaseSensitiveNamesKey,
                                    NSURLVolumeSupportsCasePreservedNamesKey,
                                    NSURLVolumeSupportsRootDirectoryDatesKey,
                                    NSURLVolumeSupportsVolumeSizesKey,
                                    NSURLVolumeSupportsRenamingKey,
                                    NSURLVolumeSupportsAdvisoryFileLockingKey,
                                    NSURLVolumeSupportsExtendedSecurityKey,
                                    NSURLVolumeIsBrowsableKey,
                                    NSURLVolumeMaximumFileSizeKey,
                                    NSURLVolumeIsEjectableKey,
                                    NSURLVolumeIsRemovableKey,
                                    NSURLVolumeIsInternalKey,
                                    NSURLVolumeIsAutomountedKey,
                                    NSURLVolumeIsLocalKey,
                                    NSURLVolumeIsReadOnlyKey,
                                    NSURLVolumeCreationDateKey,
                                    NSURLVolumeURLForRemountingKey,
                                    NSURLVolumeUUIDStringKey,
                                    NSURLVolumeNameKey,
                                    NSURLVolumeLocalizedNameKey,
                                ];

    NSVolumeEnumerationOptions options = NSVolumeEnumerationSkipHiddenVolumes;

    if (lua_type(L, 1) == LUA_TBOOLEAN && lua_toboolean(L, 1)) {
        options = (NSVolumeEnumerationOptions)0;
    }

    NSArray *URLs = [fileManager mountedVolumeURLsIncludingResourceValuesForKeys:urlResourceKeys options:options];

    for (NSURL *url in URLs) {
        id result = [url resourceValuesForKeys:urlResourceKeys error:nil] ;
        NSString *path = [url path] ;
        if (path) {
            if (result) [volumeInfo setObject:result forKey:path];
            NSDictionary *dict = [url resourceValuesForKeys:urlResourceKeys error:nil] ;
            if (dict) [volumeInfo setObject:dict forKey:path];
        }
    }

    [skin pushNSObject:volumeInfo];

    return 1;
}

static int boolTest(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    lua_pushboolean(L, YES) ;
    NSObject *yesObject = [skin toNSObjectAtIndex:-1] ;
    lua_pushboolean(L, NO) ;
    NSObject *noObject = [skin toNSObjectAtIndex:-1] ;
    lua_pop(L, 2) ;

    NSDictionary *testDictionary = @{ @"yes" : @(YES), @"no" : @(NO), } ;
    NSNumber *yesObjFromDict = [testDictionary objectForKey:@"yes"] ;
    NSNumber *noObjFromDict  = [testDictionary objectForKey:@"no"] ;
    lua_newtable(L) ;
    [skin pushNSObject:testDictionary] ; lua_setfield(L, -2, "dictionary") ;
    [skin pushNSObject:[yesObjFromDict className]] ; lua_setfield(L, -2, "yesClassName") ;
    [skin pushNSObject:[noObjFromDict className]] ;  lua_setfield(L, -2, "noClassName") ;
    lua_pushstring(L, [yesObjFromDict objCType]) ;   lua_setfield(L, -2, "yesObjCType") ;
    lua_pushstring(L, [noObjFromDict objCType]) ;    lua_setfield(L, -2, "noObjCType") ;

    [skin pushNSObject:[yesObject className]] ; lua_setfield(L, -2, "yesObjectClassName") ;
    [skin pushNSObject:[noObject className]] ;  lua_setfield(L, -2, "noObjectClassName") ;
    lua_pushstring(L, [(NSNumber *)yesObject objCType]) ;   lua_setfield(L, -2, "yesObjectObjCType") ;
    lua_pushstring(L, [(NSNumber *)noObject objCType]) ;    lua_setfield(L, -2, "noObjectObjCType") ;

    return 1 ;
}

static int avcapturedevices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_newtable(L) ;
    for (AVCaptureDevice *dev in [AVCaptureDevice devices]) {
        [skin pushNSObject:[dev localizedName]] ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    return 1 ;
}

static int absoluteTime(lua_State *L) {
    lua_pushinteger(L, (lua_Integer)mach_absolute_time()) ;
    return 1 ;
}

static int mach_stuff(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, (lua_Integer)mach_absolute_time()) ;
    lua_setfield(L, -2, "absolute") ;
    lua_pushinteger(L, (lua_Integer)mach_approximate_time()) ;
    lua_setfield(L, -2, "approximate") ;
    mach_timebase_info_data_t holding ;
    mach_timebase_info(&holding) ;
    lua_pushinteger(L, (lua_Integer)holding.numer) ;
    lua_setfield(L, -2, "numerator") ;
    lua_pushinteger(L, (lua_Integer)holding.denom) ;
    lua_setfield(L, -2, "denominator") ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
    if (&mach_continuous_time != NULL) {
        lua_pushinteger(L, (lua_Integer)mach_continuous_time()) ;
        lua_setfield(L, -2, "continuous") ;
    }
    if (&mach_continuous_approximate_time != NULL) {
        lua_pushinteger(L, (lua_Integer)mach_continuous_approximate_time()) ;
        lua_setfield(L, -2, "continuousApproximate") ;
    }
#pragma clang diagnostic pop

    return 1 ;
}

static int hotkeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    CFArrayRef hotkeys = NULL ;
    OSStatus status = CopySymbolicHotKeys(&hotkeys) ;
    if (status != noErr) {
        lua_pushinteger(L, status) ;
    } else if (hotkeys) {
        [skin pushNSObject:(__bridge_transfer NSArray *)hotkeys withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int keybdType(lua_State *L) {
    lua_pushinteger(L, LMGetKbdType()) ;
    return 1 ;
}

static int uptime(lua_State *L) {
    lua_pushnumber(L, [[NSProcessInfo processInfo] systemUptime]) ;
    return 1;
}

static int assertions(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    CFDictionaryRef assertions = NULL ;
    IOPMCopyAssertionsByProcess(&assertions) ;
    if (assertions) {
        [skin pushNSObject:(__bridge_transfer NSDictionary *)assertions] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int CmathNumbers(lua_State *L) {
    lua_newtable(L) ;
    lua_pushnumber(L, M_E) ; lua_setfield(L, -2, "M_E") ;
    lua_pushnumber(L, M_LOG2E) ; lua_setfield(L, -2, "M_LOG2E") ;
    lua_pushnumber(L, M_LOG10E) ; lua_setfield(L, -2, "M_LOG10E") ;
    lua_pushnumber(L, M_LN2) ; lua_setfield(L, -2, "M_LN2") ;
    lua_pushnumber(L, M_LN10) ; lua_setfield(L, -2, "M_LN10") ;
    lua_pushnumber(L, M_PI) ; lua_setfield(L, -2, "M_PI") ;
    lua_pushnumber(L, M_PI_2) ; lua_setfield(L, -2, "M_PI_2") ;
    lua_pushnumber(L, M_PI_4) ; lua_setfield(L, -2, "M_PI_4") ;
    lua_pushnumber(L, M_1_PI) ; lua_setfield(L, -2, "M_1_PI") ;
    lua_pushnumber(L, M_2_PI) ; lua_setfield(L, -2, "M_2_PI") ;
    lua_pushnumber(L, M_2_SQRTPI) ; lua_setfield(L, -2, "M_2_SQRTPI") ;
    lua_pushnumber(L, M_SQRT2) ; lua_setfield(L, -2, "M_SQRT2") ;
    lua_pushnumber(L, M_SQRT1_2) ; lua_setfield(L, -2, "M_SQRT1_2") ;
    return 1 ;
}

// https://stackoverflow.com/questions/5868567/unique-identifier-of-a-mac
// Note a refurbished/repaired mac may not have a serial number
static int macSerialNumber(lua_State *L) {
    io_service_t    platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice")) ;
    CFStringRef serialNumberAsCFString = NULL;

    if (platformExpert) {
        serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, CFSTR(kIOPlatformSerialNumberKey), kCFAllocatorDefault, 0) ;
        IOObjectRelease(platformExpert);
    }

    NSString *serialNumberAsNSString = @"<undefined>" ;
    if (serialNumberAsCFString) {
        serialNumberAsNSString = [NSString stringWithString:(__bridge NSString *)serialNumberAsCFString] ;
        CFRelease(serialNumberAsCFString) ;
    }

    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:serialNumberAsNSString] ;

    return 1 ;
}

// Note that LD marks edits as deletion, insertion, or substitution -- each counts as 1
// Meyer doesn't recognize substitution; to it it's a deletion followed by an insertion
// (thus counting 2), so the numbers won't match exactly
//
// And Meyers is *way* faster
static size_t LevenshteinDistance(NSData *s1, NSData *s2) {
    // see https://en.wikipedia.org/wiki/Levenshtein_distance

    size_t        n  = s1.length ;
    const uint8_t *s = s1.bytes ;
    size_t        m  = s2.length ;
    const uint8_t *t = s2.bytes ;

    size_t *v0 = malloc((n + 1) * sizeof(size_t)) ;
    size_t *v1 = malloc((n + 1) * sizeof(size_t)) ;
    for (NSUInteger i = 0 ; i <= n ; i++) v0[i] = i ;

    for (NSUInteger i = 0 ; i < m ; i++) {
        v1[0] = i + 1 ;
        for (NSUInteger j = 0 ; j < n ; j++) {
            size_t deletion     = v1[j] + 1 ;
            size_t insertion    = v0[j + 1] + 1 ;
            size_t substitution = v0[j] + ((s[i] == t[j]) ? 0 : 1) ;

            size_t newValue = (deletion < insertion) ? deletion : insertion ;
            if (substitution < newValue) newValue = substitution ;
            v1[j + 1] = newValue ;
        }
        size_t *tmp = v0 ;
        v0 = v1 ;
        v1 = tmp ;
    }
    size_t distance = v0[n] ;
    free(v1) ;
    free(v0) ;
    return distance ;
}

static NSInteger meyersShortestEdit(NSData *s1, NSData *s2) {
    // see https://blog.jcoglan.com/2017/02/15/the-myers-diff-algorithm-part-2/

    NSInteger     n  = (NSInteger)s1.length ;
    const uint8_t *s = s1.bytes ;
    NSInteger     m  = (NSInteger)s2.length ;
    const uint8_t *t = s2.bytes ;

    // if beginning/end are the same, skip them
    while(n > 0 && m > 0 && s[0] == t[0]) {
        s++ ; n-- ; t++ ; m-- ;
    }
    while(n > 0 && m > 0 && s[n - 1] == t[m - 1]) {
        n-- ; m-- ;
    }

    NSInteger max = n + m ;
    NSInteger *v  = malloc(sizeof(NSInteger) * (2 * (size_t)max + 1)) ;
    v[max + 1] = 0 ;
    NSInteger x, y ;
    for (NSInteger d = 0 ; d <= max ; d++) {
        for (NSInteger k = -d ; k <= d ; k += 2) {
            if (k == -d || (k != d && v[max + k - 1] < v[max + k + 1])) {
                x = v[max + k + 1] ;
            } else {
                x = v[max + k - 1] + 1 ;
            }
            y = x - k ;
            while (x < n && y < m && s[x] == t[y]) {
                x++ ;
                y++ ;
            }
            v[max + k] = x ;
            if (x >= n && y >= m) {
                free(v) ;
                return d ;
            }
        }
    }
    free(v) ;
    return -1 ;
}

static int lua_LevenshteinDistance(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TFUNCTION | LS_TOPTIONAL, LS_TBREAK] ;
    NSData *s1 = [skin toNSObjectAtIndex:1 withOptions:LS_NSLuaStringAsDataOnly] ;
    NSData *s2 = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] ;

    if (lua_gettop(L) == 2) {
        lua_pushinteger(L, (lua_Integer)LevenshteinDistance(s1, s2)) ;
        return 1 ;
    } else {
        lua_pushvalue(L, 3) ;
        int fnRef = [skin luaRef:refTable] ;
        [backgroundCallbacks addObject:@(fnRef)] ;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            size_t results = LevenshteinDistance(s1, s2) ;
            dispatch_sync(dispatch_get_main_queue(), ^{
                if ([backgroundCallbacks containsObject:@(fnRef)]) {
                    LuaSkin   *_skin = [LuaSkin sharedWithState:NULL] ;
                    [_skin pushLuaRef:refTable ref:fnRef] ;
                    lua_pushinteger(_skin.L, (lua_Integer)results) ;
                    if (![_skin protectedCallAndTraceback:1 nresults:0]) {
                        [_skin logError:[NSString stringWithFormat:@"levenshteinDistance callback error:%s", lua_tostring(_skin.L, -1)]] ;
                        lua_pop(_skin.L, 1) ;
                    }
                    [_skin luaUnref:refTable ref:fnRef] ;
                    [backgroundCallbacks removeObject:@(fnRef)] ;
                }
            }) ;
        }) ;
        return 0 ;
    }
}

static int lua_meyersShortestEdit(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TFUNCTION | LS_TOPTIONAL, LS_TBREAK] ;
    NSData *s1 = [skin toNSObjectAtIndex:1 withOptions:LS_NSLuaStringAsDataOnly] ;
    NSData *s2 = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] ;

    if (lua_gettop(L) == 2) {
        lua_pushinteger(L, (lua_Integer)meyersShortestEdit(s1, s2)) ;
        return 1 ;
    } else {
        lua_pushvalue(L, 3) ;
        int fnRef = [skin luaRef:refTable] ;
        [backgroundCallbacks addObject:@(fnRef)] ;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSInteger results = meyersShortestEdit(s1, s2) ;
            dispatch_sync(dispatch_get_main_queue(), ^{
                if ([backgroundCallbacks containsObject:@(fnRef)]) {
                    LuaSkin   *_skin = [LuaSkin sharedWithState:NULL] ;
                    [_skin pushLuaRef:refTable ref:fnRef] ;
                    lua_pushinteger(_skin.L, (lua_Integer)results) ;
                    if (![_skin protectedCallAndTraceback:1 nresults:0]) {
                        [_skin logError:[NSString stringWithFormat:@"meyersShortestEdit callback error:%s", lua_tostring(_skin.L, -1)]] ;
                        lua_pop(_skin.L, 1) ;
                    }
                    [_skin luaUnref:refTable ref:fnRef] ;
                    [backgroundCallbacks removeObject:@(fnRef)] ;
                }
            }) ;
        }) ;
        return 0 ;
    }
}

// added to test better random number generation per HS issue #2260
static int extras_random(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    lua_pushinteger(L, (lua_Integer)arc4random_uniform((uint32_t)lua_tointeger(L, 1))) ;
    return 1 ;
}

// added to test hair brained idea that spawned HS issue #2304
static int extras_isMainThreadForState(lua_State *L) {
    int isMainThread = lua_pushthread(L) ;
    lua_pop(L, 1) ; // remove thread we just pushed onto the stack
    lua_pushboolean(L, isMainThread) ;
    return 1 ;
}

// added to test hair brained idea that spawned HS issue #2304

static int extras_yield(lua_State *L) {
    // if argument is 0, only 1 queued event will execute before resuming. Ok, if yield is called
    // often, but not as friendly if yield only called infrequently.
    NSTimeInterval interval = (lua_type(L, 1) == LUA_TNUMBER) ? lua_tonumber(L, 1) : 0.000001 ;
    NSDate         *date    = [[NSDate date] dateByAddingTimeInterval:interval] ;

    // a melding of code from gnustep's implementation of NSApplication's run and NSRunLoop's runUntilDate:
    // methods. Also similar to NSTask's waitUntilExit in gnustep
    //
    // FWIW, using Hopper to disassemble 10.15.4 Foundation and Appkit, this looks similar to the
    // code Apple is using as well (though it's hard to be 100% certain).
    //
    // this allows acting on events (hs.eventtap) and keys (hs.hotkey) as well as timers, etc.
    BOOL   mayDoMore = YES ;
    while (mayDoMore) {
        NSEvent *e = [NSApp nextEventMatchingMask:NSEventMaskAny
                                        untilDate:date
                                           inMode:NSDefaultRunLoopMode
                                          dequeue:YES] ;
        if (e) [NSApp sendEvent:e] ;

        mayDoMore = !([date timeIntervalSinceNow] <= 0.0) ;
    }
    // since callbcaks use the initial lua_State, return it to ours, just in case we're invoked from
    // within a co-routine
    [LuaSkin sharedWithState:L] ;

    return 0 ;
}

// trying to figure out where c-code source is from within Lua
//    for deprecation warnings with [LuaSkin shared]
//    useful errors about re-declaration of helper functions

    static int extras_luaL_where(lua_State *L) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        [skin checkArgs:LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
        int lvl = (lua_gettop(L) == 1) ? (int)lua_tointeger(L, 1) : 0 ;

        lua_Debug ar ;

        lua_pushboolean(L, lua_getstack(L, lvl, &ar)) ;
        if (lua_toboolean(L, -1)) {
            lua_getinfo(L, "Sn", &ar) ;
            lua_pushstring(L, ar.name) ;
            lua_pushstring(L, ar.namewhat) ;
            lua_pushstring(L, ar.what) ;
            lua_pushstring(L, ar.source) ;
            lua_pushstring(L, ar.short_src) ;

            return 6 ;
        } else {
            return 1 ;
        }
    }

    static int extras_callStackSymbols(lua_State *L) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        [skin pushNSObject:[NSThread callStackSymbols]] ;
        return 1 ;
    }

    static int extras_callStackSymbols2(lua_State *L) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        [skin pushNSObject:[[NSThread callStackSymbols] componentsJoinedByString:@"\r"]] ;
        return 1 ;
    }

    static int extras_callStackReturnAddresses(lua_State *L) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        [skin pushNSObject:[NSThread callStackReturnAddresses]] ;
        return 1 ;
    }

    static int extras_dladdr(lua_State *L) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        [skin checkArgs:LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
        uintptr_t addr = (uintptr_t)lua_tointeger(L, 1) ;

        Dl_info info ;
        if (dladdr((const void *)addr, &info) != 0) {
            lua_newtable(L) ;
            lua_pushstring(L, info.dli_fname) ; lua_setfield(L, -2, "fname") ;
            lua_pushfstring(L, "%p", info.dli_fbase) ; lua_setfield(L, -2, "fbase") ;
            lua_pushstring(L, info.dli_sname) ; lua_setfield(L, -2, "sname") ;
            lua_pushfstring(L, "%p", info.dli_saddr) ; lua_setfield(L, -2, "saddr") ;


        } else {
            lua_pushnil(L) ;
        }
        return 1 ;
    }

    static int extras_callstackPaths(lua_State *L) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        [skin checkArgs:LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;

        NSUInteger startAt = (lua_gettop(L) > 0) ? (NSUInteger)lua_tointeger(L, 1) : 0 ;
        lua_newtable(L) ;

        NSArray   *csa   = [NSThread callStackReturnAddresses] ;
        if (startAt >= csa.count) startAt = csa.count - 1 ;
        for (NSUInteger i = startAt ; i < csa.count ; i++) {
            NSNumber   *address = csa[i] ;
            uintptr_t  add      = address ? address.unsignedLongValue : 0ul ;
            Dl_info    libraryInfo ;
            const char *fname   = (address && dladdr((const void *)add, &libraryInfo) != 0) ?
                                libraryInfo.dli_fname : "** unknown **" ;
            lua_pushstring(L, fname) ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }

        return 1 ;
    }


CG_EXTERN bool CGDisplayUsesInvertedPolarity(void);
CG_EXTERN void CGDisplaySetInvertedPolarity(bool invertedPolarity);
CG_EXTERN bool CGDisplayUsesForceToGray(void);
CG_EXTERN void CGDisplayForceToGray(bool forceToGray);

static int extras_invert(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) == 1) {
        CGDisplaySetInvertedPolarity(lua_toboolean(L, 1)) ;
    }
    lua_pushboolean(L, CGDisplayUsesInvertedPolarity()) ;
    return 1 ;
}

static int extras_gray(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) == 1) {
        CGDisplayForceToGray(lua_toboolean(L, 1)) ;
    }
    lua_pushboolean(L, CGDisplayUsesForceToGray()) ;
    return 1 ;
}

static int extras_finderSearch(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    CFStringRef inSearchString = (lua_gettop(L) > 0) ? (__bridge_retained CFStringRef)[skin toNSObjectAtIndex:1] : NULL ;
    lua_pushinteger(L, HISearchWindowShow(inSearchString, kNilOptions)) ;
    if (inSearchString) CFRelease(inSearchString) ;
    return 1 ;
}

// Not working... maybe because we're not calling from context menu? Since we're not passing in a view
// not sure how it would know, but whatever...
//
// static int extras_dictionaryWindow(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TSTRING, LS_TTABLE | LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
//     NSString  *textString    = [skin toNSObjectAtIndex:1] ;
//     CFRange   selectionRange = DCSGetTermRangeInString(NULL, (__bridge CFStringRef)textString, 0) ;
//     NSFont    *systemFont    = [NSFont systemFontOfSize:0.0] ;
//     CTFontRef textFont       = CTFontCreateWithName((__bridge CFStringRef)systemFont.fontName, systemFont.pointSize, NULL) ;
//     CGPoint   textOrigin     = (lua_type(L, 2) == LUA_TTABLE) ? NSPointToCGPoint([skin tableToPointAtIndex:2]) : CGPointZero ;
//     Boolean   verticalText   = (lua_type(L, lua_gettop(L)) == LUA_TBOOLEAN) ? (Boolean)(lua_toboolean(L, lua_gettop(L))) : false ;
//
//     HIDictionaryWindowShow(NULL, (__bridge CFStringRef)textString, selectionRange, textFont, textOrigin, verticalText, NULL) ;
//
//     CFRelease(textFont) ;
//     return 0 ;
// }

static int extras_fontTag(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *fontName = [skin toNSObjectAtIndex:1] ;
    NSString *tag      = (lua_gettop(L) > 1) ? [skin toNSObjectAtIndex:2] : nil ;

    CGFontRef font = CGFontCreateWithFontName((__bridge CFStringRef)fontName) ;
    NSString  *errString = nil ;

// crap; forgot mac is little-endian, so the tags are backwards when pulled/pushed from lua...
// if I go back to this, replace memcpy in both places... guess we have to build it byte-by-byte?
    if (font) {
        if (tag) {
            const char *tagCString = tag.UTF8String ;
            if (strnlen(tagCString, 5) == 4) {
                uint32_t tagUInt32 ;
                tagUInt32 = (uint32_t) tagCString[3]        +
                            (uint32_t)(tagCString[2] <<  8) +
                            (uint32_t)(tagCString[1] << 16) +
                            (uint32_t)(tagCString[0] << 24) ;
//                 memcpy(&tagUInt32, tagCString, 4) ;
                CFDataRef data = CGFontCopyTableForTag(font, tagUInt32) ;
                if (data) {
                    [skin pushNSObject:(__bridge_transfer NSData *)data] ;
                } else {
                    errString = [NSString stringWithFormat:@"table %@ not found in font %@", tag, font] ;
                }
            } else {
                errString = @"tag must be 4 characters long" ;
            }
        } else {
            CFArrayRef tags = CGFontCopyTableTags(font) ;
            if (tags) {
                lua_newtable(L) ;
                CFIndex count = CFArrayGetCount(tags) ;
                for (CFIndex i = 0 ; i < count ; i++) {
                    uint32_t entry = (uint32_t)(uintptr_t)(CFArrayGetValueAtIndex(tags, i)) ;
                    char entryC[4] ;
                    entryC[0] = (char)((entry >> 24) & 0xff) ;
                    entryC[1] = (char)((entry >> 16) & 0xff) ;
                    entryC[2] = (char)((entry >>  8) & 0xff) ;
                    entryC[3] = (char)( entry        & 0xff) ;
//                     memcpy(entryC, &entry, 4) ;
                    lua_pushlstring(L, entryC, 4) ;
                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
                }
                CFRelease(tags) ;
            } else {
                errString = [NSString stringWithFormat:@"unable to get tags for font %@", fontName] ;
            }
        }

        CGFontRelease(font) ;
    } else {
        errString = [NSString stringWithFormat:@"unrecognized font name %@", fontName] ;
    }

    if (errString) {
        lua_pushnil(L) ;
        [skin pushNSObject:errString] ;
        return 2 ;
    } else {
        return 1 ;
    }
}

static int extras_glyphForName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TNUMBER, LS_TSTRING, LS_TBREAK] ;

    NSString *fontName = [skin toNSObjectAtIndex:1] ;
    CGFloat  fontSize  = lua_tonumber(L, 2) ;
    NSString *tagName  = [skin toNSObjectAtIndex:3] ;

    NSFont *font = [NSFont fontWithName:fontName size:fontSize] ;

    if (!font) {
        lua_pushnil(L) ;
        lua_pushstring(L, "unrecognized font") ;
        return 2 ;
    }

    CGGlyph glyphNumber = CTFontGetGlyphWithName((__bridge CTFontRef)font, (__bridge CFStringRef)tagName) ;
    if (glyphNumber == 0) {
        lua_pushnil(L) ;
        lua_pushstring(L, "unrecognized glyph") ;
        return 2 ;
    }

    CGPathRef glyphPath   = CTFontCreatePathForGlyph((__bridge CTFontRef)font, glyphNumber, NULL) ;
    CGRect    glyphRect = CGPathGetBoundingBox(glyphPath) ;

    NSImage   *glyphImage = [[NSImage alloc] initWithSize:NSSizeFromCGSize(glyphRect.size)] ;
    [glyphImage lockFocus] ;
        NSGraphicsContext *gc = [NSGraphicsContext currentContext] ;
        [gc saveGraphicsState] ;
        [NSColor.blackColor setFill] ;
        [NSColor.blackColor setStroke] ;

        CGContextRef cgContext = gc.CGContext ;
        CGContextAddPath(cgContext, glyphPath) ;
        CGContextDrawPath(cgContext, kCGPathFillStroke) ;

        [gc restoreGraphicsState] ;
    [glyphImage unlockFocus] ;

    [skin pushNSObject:glyphImage] ;
    return 1 ;
}

#pragma mark - infrastructure stuffs

static int meta_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [backgroundCallbacks enumerateObjectsUsingBlock:^(NSNumber *ref, __unused BOOL *stop) {
        [skin luaUnref:refTable ref:ref.intValue] ;
    }] ;
    [backgroundCallbacks removeAllObjects] ;
    return 0 ;
}

static const luaL_Reg extrasLib[] = {
//     {"dictionaryWindow",     extras_dictionaryWindow},
    {"finderSearch",         extras_finderSearch},
    {"invertPolarity",       extras_invert},
    {"grayScale",            extras_gray},
    {"avcapturedevices",     avcapturedevices},
    {"boolTest",             boolTest},
    {"testLabeledTable1",    testLabeledTable1},
    {"testLabeledTable2",    testLabeledTable2},
    {"volumeInformation",    hs_volumeInformation},
    {"hotkeys",              hotkeys},
    {"lookup",               lookup},

    {"listWindows",          listWindows},
    {"NSLog",                extras_nslog },
    {"defaults",             extras_defaults},

    {"userDataToString",     ud_tostring},
    {"threadInfo",           threadInfo},
    {"addressbookGroups",    addressbookGroups},

    {"examineNSValue",       nsvalueTest2},

    {"SCPreferencesKeys",    getSCPreferencesKeys},
    {"SCPreferencesValueForKey", getSCPreferencesValueForKey},
    {"networkUserPreferences", networkUserPreferences},

    {"addressParserTesting", addressParserTesting},

    {"lockscreen",           lockscreen},
    {"sizeAndAlignment",     sizeAndAlignment},

    {"absoluteTime",         absoluteTime},
    {"keybdType",            keybdType},

    {"uptime",               uptime},

    {"mach",                 mach_stuff},
    {"assertions",           assertions},

    {"mathNumbers",          CmathNumbers},
    {"serialNumber",         macSerialNumber},

    {"levenshteinDistance",  lua_LevenshteinDistance},
    {"meyersShortestEdit",   lua_meyersShortestEdit},

    {"random",               extras_random},

    {"yield",                extras_yield},
    {"mainThreadForState",   extras_isMainThreadForState},

    {"whereLevel",           extras_luaL_where},
    {"css",                  extras_callStackSymbols},
    {"cssr",                 extras_callStackSymbols2},
    {"csa",                  extras_callStackReturnAddresses},
    {"dladdr",               extras_dladdr},
    {"stackPaths",           extras_callstackPaths},

    {"testARCandID",         testARCandID},
    {"fontTag",              extras_fontTag},
    {"glyphImage",           extras_glyphForName},

    {NULL,                   NULL}
};

static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs__asm_extras_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:"hs._asm.extras" functions:extrasLib metaFunctions:module_metaLib] ;
//     luaL_newlib(L, extrasLib);

    backgroundCallbacks = [NSMutableSet set] ;
    return 1;
}
