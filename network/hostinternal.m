#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import <CFNetwork/CFNetwork.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import <netinet/in.h>
#import <netdb.h>

#define USERDATA_TAG    "hs.network.host"
static int              refTable          = LUA_NOREF;

#define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

typedef struct _hshost_t {
    CFHostRef      theHostObj ;
    int            callbackRef ;
    CFHostInfoType resolveType ;
    int            selfRef ;
    BOOL           running ;
} hshost_t;

static int pushCFHost(lua_State *L, CFHostRef theHost, CFHostInfoType resolveType) {
    LuaSkin   *skin    = [LuaSkin shared] ;
    hshost_t* thePtr = lua_newuserdata(L, sizeof(hshost_t)) ;
    memset(thePtr, 0, sizeof(hshost_t)) ;

    thePtr->theHostObj  = (CFHostRef)CFRetain(theHost) ;
    thePtr->callbackRef = LUA_NOREF ;
    thePtr->resolveType = resolveType ;
    thePtr->selfRef     = LUA_NOREF ;
    thePtr->running     = NO ;

    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;
    lua_pushvalue(L, -1) ;
    thePtr->selfRef = [skin luaRef:refTable] ;
    return 1 ;
}

static NSString *expandCFStreamError(CFStreamErrorDomain domain, SInt32 errorNum) {
    NSString *ErrorString ;
    if (domain == kCFStreamErrorDomainNetDB) {
        ErrorString = [NSString stringWithFormat:@"Error domain:NetDB, message:%s", gai_strerror(errorNum)] ;
    } else if (domain == kCFStreamErrorDomainNetServices) {
        ErrorString = [NSString stringWithFormat:@"Error domain:NetServices, code:%d (see CFNetServices.h)", errorNum] ;
    } else if (domain == kCFStreamErrorDomainMach) {
        ErrorString = [NSString stringWithFormat:@"Error domain:Mach, code:%d (see mach/error.h)", errorNum] ;
    } else if (domain == kCFStreamErrorDomainFTP) {
        ErrorString = [NSString stringWithFormat:@"Error domain:FTP, code:%d", errorNum] ;
    } else if (domain == kCFStreamErrorDomainHTTP) {
        ErrorString = [NSString stringWithFormat:@"Error domain:HTTP, code:%d", errorNum] ;
    } else if (domain == kCFStreamErrorDomainSOCKS) {
        ErrorString = [NSString stringWithFormat:@"Error domain:SOCKS, code:%d", errorNum] ;
    } else if (domain == kCFStreamErrorDomainSystemConfiguration) {
        ErrorString = [NSString stringWithFormat:@"Error domain:SystemConfiguration, code:%d (see SystemConfiguration.h)", errorNum] ;
    } else if (domain == kCFStreamErrorDomainSSL) {
        ErrorString = [NSString stringWithFormat:@"Error domain:SSL, code:%d (see SecureTransport.h)", errorNum] ;
    } else if (domain == kCFStreamErrorDomainWinSock) {
        ErrorString = [NSString stringWithFormat:@"Error domain:WinSock, code:%d (see winsock2.h)", errorNum] ;
    } else if (domain == kCFStreamErrorDomainCustom) {
        ErrorString = [NSString stringWithFormat:@"Error domain:Custom, code:%d", errorNum] ;
    } else if (domain == kCFStreamErrorDomainPOSIX) {
        ErrorString = [NSString stringWithFormat:@"Error domain:POSIX, code:%d (see errno.h)", errorNum] ;
    } else if (domain == kCFStreamErrorDomainMacOSStatus) {
        ErrorString = [NSString stringWithFormat:@"Error domain:MacOSStatus, code:%d (see MacErrors.h)", errorNum] ;
    } else {
        ErrorString = [NSString stringWithFormat:@"Unknown domain:%ld, code:%d", domain, errorNum] ;
    }
    return ErrorString ;
}

void handleCallback(__unused CFHostRef theHost, __unused CFHostInfoType typeInfo, const CFStreamError *error, void *info) {
    hshost_t *theRef = (hshost_t *)info ;
    CFStreamErrorDomain domain = 0 ;
    SInt32              errorNum = 0 ;
    if (error) {
        domain   = error->domain ;
        errorNum = error->error ;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (theRef->callbackRef != LUA_NOREF) {
            LuaSkin   *skin    = [LuaSkin shared] ;
            lua_State *L       = [skin L] ;
            int       argCount = 3 ;
            [skin pushLuaRef:refTable ref:theRef->callbackRef] ;
            if ((domain == 0) && (errorNum == 0)) {
                Boolean available = false ;
                switch(theRef->resolveType) {
                    case kCFHostAddresses:
                        lua_pushstring(L, "addresses") ;
                        CFArrayRef theAddresses = CFHostGetAddressing(theRef->theHostObj, &available);
                        lua_pushboolean(L, available) ;
                        if (theAddresses) {
                            lua_newtable(L) ;
                            for (CFIndex i = 0 ; i < CFArrayGetCount(theAddresses) ; i++) {
                                NSData *thisAddr = (__bridge NSData *)CFArrayGetValueAtIndex(theAddresses, i) ;
                                int  err;
                                char addrStr[NI_MAXHOST];
                                err = getnameinfo((const struct sockaddr *) [thisAddr bytes], (socklen_t) [thisAddr length], addrStr, sizeof(addrStr), NULL, 0, NI_NUMERICHOST | NI_WITHSCOPEID | NI_NUMERICSERV);
                                if (err == 0) {
                                    lua_pushstring(L, addrStr) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
                                } else {
                                    lua_pushfstring(L, "** error:%s", gai_strerror(err)) ;
                                }
                            }
                        } else {
                            lua_pushnil(L) ;
                        }
                        break ;
                    case kCFHostNames:
                        lua_pushstring(L, "names") ;
                        CFArrayRef theNames = CFHostGetNames(theRef->theHostObj, &available);
                        lua_pushboolean(L, available) ;
                        if (theNames) {
                            [skin pushNSObject:(__bridge NSArray *)theNames] ;
                        } else {
                            lua_pushnil(L) ;
                        }
                        break ;
                    case kCFHostReachability:
                        lua_pushstring(L, "reachability") ;
                        CFDataRef theAvailability = CFHostGetReachability(theRef->theHostObj, &available);
                        lua_pushboolean(L, available) ;
                        if (theAvailability) {
                            SCNetworkConnectionFlags *flags = (SCNetworkConnectionFlags *)CFDataGetBytePtr(theAvailability) ;
                            lua_pushinteger(L, *flags) ;
                        } else {
                            lua_pushnil(L) ;
                        }
                        break ;
                    default:
                        lua_pushfstring(L, "** unknown:%d", theRef->resolveType) ;
                        argCount = 1 ;
                        break ;
                }
            } else {
                [skin pushNSObject:[NSString stringWithFormat:@"resolution error:%@", expandCFStreamError(domain, errorNum)]] ;
                argCount = 1 ;
            }
            if (![skin protectedCallAndTraceback:argCount nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s:error in Lua callback:%@",
                                                            USERDATA_TAG,
                                                            [skin toNSObjectAtIndex:-1]]] ;
                lua_pop(L, 1) ; // error string from pcall
            }
        }
        CFHostSetClient(theRef->theHostObj, NULL, NULL );
        CFHostUnscheduleFromRunLoop(theRef->theHostObj, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        CFHostCancelInfoResolution(theRef->theHostObj, theRef->resolveType);
        theRef->running = NO ;
        // allow __gc when their stored version goes away
        theRef->selfRef = [[LuaSkin shared] luaUnref:refTable ref:theRef->selfRef] ;
    }) ;
}

static int commonConstructor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION, LS_TBREAK] ;

    hshost_t* theRef = get_structFromUserdata(hshost_t, L, 1) ;
    lua_pushvalue(L, 2);
    theRef->callbackRef = [skin luaRef:refTable];
    CFHostClientContext context = { 0, NULL, NULL, NULL, NULL };
    context.info = (void *)theRef;
    if (CFHostSetClient(theRef->theHostObj, handleCallback, &context)) {
        CFHostScheduleWithRunLoop(theRef->theHostObj, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        CFStreamError streamError ;
        if (CFHostStartInfoResolution(theRef->theHostObj, theRef->resolveType, &streamError)) {
            theRef->running = YES;
            lua_pushvalue(L, 1) ;
        } else {
            CFHostUnscheduleFromRunLoop(theRef->theHostObj, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
            theRef->selfRef = [skin luaUnref:refTable ref:theRef->selfRef] ;
            return luaL_error(L, [[NSString stringWithFormat:@"resolution error:%@", expandCFStreamError(streamError.domain, streamError.error)] UTF8String]) ;
        }
    } else {
        // capture reference so __gc doesn't accidentally collect before callback if they don't save a reference to the object
        theRef->selfRef = [skin luaUnref:refTable ref:theRef->selfRef] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int commonForHostName(lua_State *L, CFHostInfoType resolveType) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TFUNCTION, LS_TBREAK] ;

    CFHostRef theHost = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)[skin toNSObjectAtIndex:1]);

    lua_pushcfunction(L, commonConstructor) ;
    pushCFHost(L, theHost, resolveType) ;
    CFRelease(theHost) ;
    lua_pushvalue(L, 2) ;
    lua_call(L, 2, 1) ; // error as if the error occurred here
    return 1 ;
}

static int commonForAddress(lua_State *L, CFHostInfoType resolveType) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TFUNCTION, LS_TBREAK] ;

    luaL_checkstring(L, 1) ; // force number to be a string
    struct addrinfo *results = NULL ;
    struct addrinfo hints = { AI_NUMERICHOST | AI_NUMERICSERV | AI_V4MAPPED_CFG, PF_UNSPEC, 0, 0, 0, NULL, NULL, NULL } ;
    int ecode = getaddrinfo([[skin toNSObjectAtIndex:1] UTF8String], NULL, &hints, &results);
    if (ecode != 0) {
        if (results) freeaddrinfo(results) ;
        return luaL_error(L, "address parse error: %s", gai_strerror(ecode)) ;
    }

    CFDataRef theSocket =  CFDataCreate(kCFAllocatorDefault, (void *)results->ai_addr, results->ai_addrlen);
    CFHostRef theHost   = CFHostCreateWithAddress (kCFAllocatorDefault, theSocket);
    lua_pushcfunction(L, commonConstructor) ;
    pushCFHost(L, theHost, resolveType) ;
    CFRelease(theSocket) ;
    CFRelease(theHost) ;
    freeaddrinfo(results) ;
    lua_pushvalue(L, 2) ;
    lua_call(L, 2, 1) ; // error as if the error occurred here
    return 1 ;
}

#pragma mark - Module Functions

static int getAddressesForHostName(lua_State *L) {
    return commonForHostName(L, kCFHostAddresses) ;
}

static int getNamesForAddress(lua_State *L) {
    return commonForAddress(L, kCFHostNames) ;
}

static int getReachabilityForAddress(lua_State *L) {
    return commonForAddress(L, kCFHostReachability) ;
}

static int getReachabilityForHostName(lua_State *L) {
    return commonForHostName(L, kCFHostReachability) ;
}

#pragma mark - Module Methods

static int resolutionIsRunning(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    hshost_t* theRef = get_structFromUserdata(hshost_t, L, 1) ;
    lua_pushboolean(L, theRef->running) ;
    return 1 ;
}

static int cancelResolution(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    hshost_t* theRef = get_structFromUserdata(hshost_t, L, 1) ;
    if (theRef->running) {
        CFHostSetClient(theRef->theHostObj, NULL, NULL );
        CFHostCancelInfoResolution(theRef->theHostObj, theRef->resolveType);
        CFHostUnscheduleFromRunLoop(theRef->theHostObj, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        theRef->running = NO ;
    }
    // allow __gc when their stored version goes away
    theRef->selfRef = [skin luaUnref:refTable ref:theRef->selfRef] ;
    lua_settop(L, 1) ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    CFHostRef theHost = get_structFromUserdata(hshost_t, L, 1)->theHostObj ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, theHost]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        CFHostRef theHost1 = get_structFromUserdata(hshost_t, L, 1)->theHostObj ;
        CFHostRef theHost2 = get_structFromUserdata(hshost_t, L, 2)->theHostObj ;
        lua_pushboolean(L, CFEqual(theHost1, theHost2)) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
//     [skin logVerbose:@"in hosts __gc"] ;
    hshost_t* theRef = get_structFromUserdata(hshost_t, L, 1) ;
    theRef->callbackRef = [skin luaUnref:refTable ref:theRef->callbackRef] ;

    lua_pushcfunction(L, cancelResolution) ;
    lua_pushvalue(L, 1) ;
    lua_pcall(L, 1, 1, 0) ;
    lua_pop(L, 1) ;

    CFRelease(theRef->theHostObj) ;
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"isRunning",  resolutionIsRunning},
    {"cancel",     cancelResolution},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"addressesForHostname",    getAddressesForHostName},
    {"hostnamesForAddress",     getNamesForAddress},
    {"reachabilityForHostname", getReachabilityForHostName},
    {"reachabilityForAddress",  getReachabilityForAddress},

    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_network_hostinternal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    return 1;
}
