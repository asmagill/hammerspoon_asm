@import Cocoa ;
@import Carbon ;
@import LuaSkin ;
@import AVFoundation;
@import OSAKit ;

// @import AddressBook ;
@import SystemConfiguration ;

// @import QuartzCore.CATransform3D; // for NSValue conversion of CATransform3D
// @import SceneKit;   // for NSValue conversion of SCNVector3, SCNVector4, SCNMatrix4
// @import AVFoundation.AVTime;      // for NSValue conversion of CMTime, CMTimeRange, CMTimeMapping
// @import MapKit.MKGeometry;        // for NSValue conversion of CLLocationCoordinate2D, MKCoordinateSpan

@import IOKit.pwr_mgt ;

@import Darwin.POSIX.netdb ;
@import Darwin.Mach ;


/// hs._asm.extras.NSLog(luavalue)
/// Function
/// Send a representation of the lua value passed in to the Console application via NSLog.
static int extras_nslog(__unused lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
//     CFArrayRef windowInfosRef = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID) ;

    CFArrayRef windowInfosRef = CGWindowListCopyWindowInfo(kCGWindowListOptionAll | (lua_toboolean(L,1) ? 0 : kCGWindowListExcludeDesktopElements), kCGNullWindowID) ;
    // CGWindowID(0) is equal to kCGNullWindowID
    NSArray *windowList = CFBridgingRelease(windowInfosRef) ;  // same as __bridge_transfer
    [skin pushNSObject:windowList] ;
    return 1 ;
}

static int extras_defaults(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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

// static int addressbookGroups(__unused lua_State *L) {
//     LuaSkin *skin = [LuaSkin shared];
//     [skin pushNSObject:[[ABAddressBook sharedAddressBook] groups] withOptions:LS_NSDescribeUnknownTypes] ;
//     return 1 ;
// }

static int addressParserTesting(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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

static int getSCPreferencesValueForKey(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    id instance = [[principalClass alloc] init];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    [instance performSelector:@selector(_lockScreenMenuHit:) withObject:nil];
#pragma clang diagnostic pop

    return 0;
}

static int nsvalueTest2(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    id obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:obj withOptions:LS_NSUnsignedLongLongPreserveBits |
                                       LS_NSDescribeUnknownTypes         |
                                       LS_NSPreserveLuaStringExactly] ;
    if (lua_type(L, -1) == LUA_TTABLE) {
        [skin pushNSObject:[obj className]] ; lua_setfield(L, -2, "__className") ;
    }
    return 1 ;
}

static int sizeAndAlignment(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
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

static int lookup(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *word = [skin toNSObjectAtIndex:1] ;
    CFRange  range = CFRangeMake(0, (CFIndex)[word length]) ;

    [skin pushNSObject:(__bridge_transfer NSString *)DCSCopyTextDefinition(NULL,
                                                                           (__bridge CFStringRef)word,
                                                                           range)] ;
    return 1 ;
}

static int testLabeledTable1(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TTYPEDTABLE, "NSRect", LS_TBREAK] ;
    lua_pushboolean(L, YES) ;
    return 1;
}

static int testLabeledTable2(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TTYPEDTABLE, LS_TBREAK] ;
    lua_pushboolean(L, YES) ;
    return 1;
}

static int hs_volumeInformation(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];

    lua_pushboolean(L, YES) ;
    NSObject *yesObject = [skin toNSObjectAtIndex:-1] ;
    lua_pushboolean(L, NO) ;
    NSObject *noObject = [skin toNSObjectAtIndex:-1] ;
    lua_pop(L, 2) ;

    NSDictionary *testDictionary = @{ @"yes" : @(YES), @"no" : @(NO), } ;
    lua_newtable(L) ;
    [skin pushNSObject:testDictionary] ; lua_setfield(L, -2, "dictionary") ;
    [skin pushNSObject:[[testDictionary objectForKey:@"yes"] className]] ; lua_setfield(L, -2, "yesClassName") ;
    [skin pushNSObject:[[testDictionary objectForKey:@"no"] className]] ;  lua_setfield(L, -2, "noClassName") ;
    lua_pushstring(L, [[testDictionary objectForKey:@"yes"] objCType]) ;   lua_setfield(L, -2, "yesObjCType") ;
    lua_pushstring(L, [[testDictionary objectForKey:@"no"] objCType]) ;    lua_setfield(L, -2, "noObjCType") ;

    [skin pushNSObject:[yesObject className]] ; lua_setfield(L, -2, "yesObjectClassName") ;
    [skin pushNSObject:[noObject className]] ;  lua_setfield(L, -2, "noObjectClassName") ;
    lua_pushstring(L, [(NSNumber *)yesObject objCType]) ;   lua_setfield(L, -2, "yesObjectObjCType") ;
    lua_pushstring(L, [(NSNumber *)noObject objCType]) ;    lua_setfield(L, -2, "noObjectObjCType") ;

    return 1 ;
}

static int avcapturedevices(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
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
    LuaSkin *skin = [LuaSkin shared] ;
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

static int thermalState(lua_State *L) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
    if ([[NSProcessInfo processInfo] respondsToSelector:@selector(thermalState)]) {
        NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState] ;
#pragma clang diagnostic pop
        switch(state) {
            case NSProcessInfoThermalStateNominal:
                lua_pushstring(L, "nominal") ;
                break ;
            case NSProcessInfoThermalStateFair:
                lua_pushstring(L, "fair") ;
                break ;
            case NSProcessInfoThermalStateSerious:
                lua_pushstring(L, "serious") ;
                break ;
            case NSProcessInfoThermalStateCritical:
                lua_pushstring(L, "critical") ;
                break ;
            default:
                lua_pushfstring(L, "** unrecognized thermal state: %d **", state) ;
                break ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int assertions(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
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


static const luaL_Reg extrasLib[] = {
    {"avcapturedevices",    avcapturedevices},
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
//     {"addressbookGroups",    addressbookGroups},

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
    {"thermalState",         thermalState},

    {"mach",                 mach_stuff},
    {"assertions",           assertions},
    {NULL,                   NULL}
};

int luaopen_hs__asm_extras_internal(lua_State* L) {
    luaL_newlib(L, extrasLib);

    return 1;
}
