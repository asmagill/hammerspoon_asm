@import Cocoa ;
@import Carbon ;
@import LuaSkin ;
@import AddressBook ;
@import SystemConfiguration ;
#import "LuaSkinThread.h"

#import <netdb.h>


/// hs._asm.extras.NSLog(luavalue)
/// Function
/// Send a representation of the lua value passed in to the Console application via NSLog.
static int extras_nslog(__unused lua_State* L) {
    LuaSkin *skin = LST_getLuaSkin(); //[LuaSkin shared] ;
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
    LuaSkin *skin = LST_getLuaSkin(); //[LuaSkin shared] ;
//     CFArrayRef windowInfosRef = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID) ;

    CFArrayRef windowInfosRef = CGWindowListCopyWindowInfo(kCGWindowListOptionAll | (lua_toboolean(L,1) ? 0 : kCGWindowListExcludeDesktopElements), kCGNullWindowID) ;
    // CGWindowID(0) is equal to kCGNullWindowID
    NSArray *windowList = CFBridgingRelease(windowInfosRef) ;  // same as __bridge_transfer
    [skin pushNSObject:windowList] ;
    return 1 ;
}

static int extras_defaults(__unused lua_State* L) {
    LuaSkin *skin = LST_getLuaSkin(); //[LuaSkin shared] ;
    NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] ;
    [skin pushNSObject:defaults] ;
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
    LuaSkin *skin = LST_getLuaSkin(); //[LuaSkin shared] ;
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

static int addressbookGroups(__unused lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin(); //[LuaSkin shared] ;
    [skin pushNSObject:[[ABAddressBook sharedAddressBook] groups]] ;
    return 1 ;
}

static int testNSValueEncodings(lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin(); //[LuaSkin shared] ;
    NSValue *theRect  = [NSValue valueWithRect:NSMakeRect(0,1,2,3)] ;
    NSValue *thePoint = [NSValue valueWithPoint:NSMakePoint(4,5)] ;
    NSValue *theSize  = [NSValue valueWithSize:NSMakeSize(6,7)] ;
    NSValue *theRange = [NSValue valueWithRange:NSMakeRange(8,9)] ;

    lua_newtable(L) ;
    lua_newtable(L) ;
    [skin pushNSObject:theRect withOptions:LS_NSDescribeUnknownTypes] ;  lua_setfield(L, -2, "rect") ;
    [skin pushNSObject:thePoint withOptions:LS_NSDescribeUnknownTypes] ; lua_setfield(L, -2, "point") ;
    [skin pushNSObject:theSize withOptions:LS_NSDescribeUnknownTypes] ;  lua_setfield(L, -2, "size") ;
    [skin pushNSObject:theRange withOptions:LS_NSDescribeUnknownTypes] ; lua_setfield(L, -2, "range") ;
    lua_setfield(L, -2, "raw") ;
    lua_newtable(L) ;
    lua_pushstring(L, [theRect objCType]) ;  lua_setfield(L, -2, "rect") ;
    lua_pushstring(L, [thePoint objCType]) ; lua_setfield(L, -2, "point") ;
    lua_pushstring(L, [theSize objCType]) ;  lua_setfield(L, -2, "size") ;
    lua_pushstring(L, [theRange objCType]) ; lua_setfield(L, -2, "range") ;
    lua_setfield(L, -2, "objCType") ;
    return 1 ;
}

static int testNewLuaSkinArgsCheck(lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin(); //[LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TNUMBER, LS_TNUMBER | LS_TINTEGER, LS_TSOFTBREAK] ;
    int argCount = lua_gettop(L) ;
    lua_newtable(L) ;
    [skin pushNSObject:[skin toNSObjectAtIndex:1]] ; lua_setfield(L, -2, "name") ;
    lua_pushnumber(L, lua_tonumber(L, 2)) ;          lua_setfield(L, -2, "rate") ;
    lua_pushinteger(L, lua_tointeger(L, 3)) ;        lua_setfield(L, -2, "age") ;
    lua_pushinteger(L, argCount) ;                   lua_setfield(L, -2, "argCount") ;
    if (argCount > 3) {
        lua_newtable(L) ;
        for (int i = 4 ; i <= argCount ; i++) {
            [skin pushNSObject:[skin toNSObjectAtIndex:i]] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        lua_setfield(L, -2, "otherStuff") ;
    }
    return 1 ;
}

static int testNewLuaSkinArgsCheck2(lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin(); //[LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TNUMBER, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    int argCount = lua_gettop(L) ;
    lua_newtable(L) ;
    [skin pushNSObject:[skin toNSObjectAtIndex:1]] ; lua_setfield(L, -2, "name") ;
    lua_pushnumber(L, lua_tonumber(L, 2)) ;          lua_setfield(L, -2, "rate") ;
    lua_pushinteger(L, lua_tointeger(L, 3)) ;        lua_setfield(L, -2, "age") ;
    lua_pushinteger(L, argCount) ;                   lua_setfield(L, -2, "argCount") ;
    if (argCount > 3) {
        lua_newtable(L) ;
        for (int i = 4 ; i <= argCount ; i++) {
            [skin pushNSObject:[skin toNSObjectAtIndex:i]] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        lua_setfield(L, -2, "otherStuff") ;
    }
    return 1 ;
}

static int lsIntTest(lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin(); //[LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_newtable(L) ;
    lua_newtable(L) ;
    [skin pushNSObject:[NSNumber numberWithUnsignedLongLong:0x7fffffffffffffff]] ;
    lua_setfield(L, -2, "below") ;
    [skin pushNSObject:[NSNumber numberWithUnsignedLongLong:0x8000000000000000]] ;
    lua_setfield(L, -2, "at") ;
    [skin pushNSObject:[NSNumber numberWithUnsignedLongLong:0x8000000000000001]] ;
    lua_setfield(L, -2, "above") ;
    lua_setfield(L, -2, "default") ;
    lua_newtable(L) ;
    [skin pushNSObject:[NSNumber numberWithUnsignedLongLong:0x7fffffffffffffff] withOptions:LS_NSUnsignedLongLongPreserveBits] ;
    lua_setfield(L, -2, "below") ;
    [skin pushNSObject:[NSNumber numberWithUnsignedLongLong:0x8000000000000000] withOptions:LS_NSUnsignedLongLongPreserveBits] ;
    lua_setfield(L, -2, "at") ;
    [skin pushNSObject:[NSNumber numberWithUnsignedLongLong:0x8000000000000001] withOptions:LS_NSUnsignedLongLongPreserveBits] ;
    lua_setfield(L, -2, "above") ;
    lua_setfield(L, -2, "withOptions") ;

    return 1 ;
}

static int addressParserTesting(lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin(); //[LuaSkin shared] ;
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
    LuaSkin *skin = LST_getLuaSkin(); //[LuaSkin shared] ;
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
    LuaSkin *skin = LST_getLuaSkin(); //[LuaSkin shared] ;
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
    LuaSkin *skin = LST_getLuaSkin(); //[LuaSkin shared] ;
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

// http://stackoverflow.com/questions/1976520/lock-screen-by-api-in-mac-os-x/26492632#26492632
extern int SACLockScreenImmediate();
static int lockscreen(lua_State* L)
{
  lua_pushinteger(L, SACLockScreenImmediate()) ;
  return 1 ;
}

static int classLoggerTest(__unused lua_State *L) {
    [LuaSkin      logError:@"no dispatch, logError"] ;
    [LuaSkin       logWarn:@"no dispatch, logWarn"] ;
    [LuaSkin       logInfo:@"no dispatch, logInfo"] ;
    [LuaSkin      logDebug:@"no dispatch, logDebug"] ;
    [LuaSkin    logVerbose:@"no dispatch, logVerbose"] ;
    [LuaSkin logBreadcrumb:@"no dispatch, logBreadcrumb"] ;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        [LuaSkin      logError:@"dispatch, logError"] ;
        [LuaSkin       logWarn:@"dispatch, logWarn"] ;
        [LuaSkin       logInfo:@"dispatch, logInfo"] ;
        [LuaSkin      logDebug:@"dispatch, logDebug"] ;
        [LuaSkin    logVerbose:@"dispatch, logVerbose"] ;
        [LuaSkin logBreadcrumb:@"dispatch, logBreadcrumb"] ;
    }) ;
    return 0 ;
}

static int integerTester(lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin(); //[LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER, LS_TBREAK] ;
    lua_pushinteger(L, lua_tointeger(L, 1)) ;
    lua_pushboolean(L, lua_isinteger(L, 1)) ;
    BOOL isInteger = NO ;
    lua_tointegerx(L, 1, (int *)&isInteger) ;
    lua_pushboolean(L, isInteger) ;

    return 3 ;
}

static const luaL_Reg extrasLib[] = {
    {"listWindows",          listWindows},
    {"NSLog",                extras_nslog },
    {"defaults",             extras_defaults},
    {"classLoggerTest",      classLoggerTest},

    {"integerTester",        integerTester},
    {"argTest",              testNewLuaSkinArgsCheck},
    {"argTest2",              testNewLuaSkinArgsCheck2},

    {"userDataToString",     ud_tostring},
    {"threadInfo",           threadInfo},
    {"addressbookGroups",    addressbookGroups},

    {"testNSValue",          testNSValueEncodings},
    {"SCPreferencesKeys",    getSCPreferencesKeys},
    {"SCPreferencesValueForKey", getSCPreferencesValueForKey},
    {"networkUserPreferences", networkUserPreferences},

    {"addressParserTesting", addressParserTesting},

    {"lsIntTest",            lsIntTest},

    {"lockscreen",           lockscreen},

    {NULL,                   NULL}
};

int luaopen_hs__asm_extras_internal(lua_State* L) {
    luaL_newlib(L, extrasLib);

    return 1;
}
