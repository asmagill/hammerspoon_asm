#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import <netinet/in.h>

// TODO:
//    IPv6 support
//    This just tests for a "route to"... do we need a test that it's actually up?
//    OpenVPN interface not managed by SCNetworkInterface, so its network is seen as direct;
//       however, checking for the interfaces IP address will specify whether its local or not

#define USERDATA_TAG    "hs._asm.reachability"
static int              refTable          = LUA_NOREF;
static dispatch_queue_t reachabilityQueue = nil ;

// #define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
#define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_cfobjectFromUserdata(objType, L, idx) *((objType*)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

typedef struct _reachability_t {
    SCNetworkReachabilityRef reachabilityObj;
    int                      callbackRef ;
    BOOL                     watcherEnabled ;
} reachability_t;

static int pushSCNetworkReachability(lua_State *L, SCNetworkReachabilityRef theRef) {
    reachability_t* thePtr = lua_newuserdata(L, sizeof(reachability_t)) ;
    memset(thePtr, 0, sizeof(reachability_t)) ;

    thePtr->reachabilityObj = CFRetain(theRef) ;
    thePtr->callbackRef     = LUA_NOREF ;
    thePtr->watcherEnabled  = NO ;

    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static void doReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    reachability_t *theRef = (reachability_t *)info ;
    if (theRef->callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            [skin pushLuaRef:refTable ref:theRef->callbackRef] ;
            pushSCNetworkReachability(L, target) ;
            lua_pushinteger(L, (lua_Integer)flags) ;
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s:error in Lua callback:%@",
                                                            USERDATA_TAG,
                                                            [skin toNSObjectAtIndex:-1]]] ;
                lua_pop(L, 1) ; // error string from pcall
            }
        }) ;
    }
}

static NSString *statusString(SCNetworkReachabilityFlags flags) {
    return [NSString stringWithFormat:@"%c%c%c%c%c%c%c%c",
                (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
                (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',
                (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
                (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
                (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
                (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
                (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
                (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-'] ;
}

#pragma mark - Module Functions

static int reachabilityForIPv4Address(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE | LS_TNUMBER, LS_TBREAK] ;

    uint32_t ipv4number ;
    if (lua_type(L, 1) == LUA_TNUMBER) {
        ipv4number = (uint32_t)luaL_checkinteger(L, 1) ;
    } else if (lua_type(L, 1) == LUA_TTABLE) {
        lua_rawgeti(L, 1, 1) ; lua_rawgeti(L, 1, 2) ; lua_rawgeti(L, 1, 3) ; lua_rawgeti(L, 1, 4) ;
        ipv4number = ((uint32_t)luaL_checkinteger(L, -4) << 24) + ((uint32_t)luaL_checkinteger(L, -3) << 16) +
                     ((uint32_t)luaL_checkinteger(L, -2) << 8)  +  (uint32_t)luaL_checkinteger(L, -1) ;
        lua_pop(L, 4) ;
    } else {
        return luaL_argerror(L, 1, [[NSString stringWithFormat:@"number or table expected, found '%s'",
                                                                lua_typename(L, lua_type(L, 1))] UTF8String]) ;
    }
    struct sockaddr_in ipv4sockaddr ;
    bzero(&ipv4sockaddr, sizeof(ipv4sockaddr));
    ipv4sockaddr.sin_len         = sizeof(ipv4sockaddr);
    ipv4sockaddr.sin_family      = AF_INET;
    ipv4sockaddr.sin_addr.s_addr = htonl(ipv4number);
    SCNetworkReachabilityRef theRef = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (void *)&ipv4sockaddr);
    pushSCNetworkReachability(L, theRef) ;
    return 1 ;
}

static int reachabilityForIPv4AddressPair(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE | LS_TNUMBER, LS_TTABLE | LS_TNUMBER, LS_TBREAK] ;

    uint32_t Lipv4number ;
    if (lua_type(L, 1) == LUA_TNUMBER) {
        Lipv4number = (uint32_t)luaL_checkinteger(L, 1) ;
    } else if (lua_type(L, 1) == LUA_TTABLE) {
        lua_rawgeti(L, 1, 1) ; lua_rawgeti(L, 1, 2) ; lua_rawgeti(L, 1, 3) ; lua_rawgeti(L, 1, 4) ;
        Lipv4number = ((uint32_t)luaL_checkinteger(L, -4) << 24) + ((uint32_t)luaL_checkinteger(L, -3) << 16) +
                      ((uint32_t)luaL_checkinteger(L, -2) << 8)  +  (uint32_t)luaL_checkinteger(L, -1) ;
        lua_pop(L, 4) ;
    } else {
        return luaL_argerror(L, 1, [[NSString stringWithFormat:@"number or table expected, found '%s'",
                                                                lua_typename(L, lua_type(L, 1))] UTF8String]) ;
    }
    struct sockaddr_in Lipv4sockaddr ;
    bzero(&Lipv4sockaddr, sizeof(Lipv4sockaddr));
    Lipv4sockaddr.sin_len         = sizeof(Lipv4sockaddr);
    Lipv4sockaddr.sin_family      = AF_INET;
    Lipv4sockaddr.sin_addr.s_addr = htonl(Lipv4number);

    uint32_t Ripv4number ;
    if (lua_type(L, 2) == LUA_TNUMBER) {
        Ripv4number = (uint32_t)luaL_checkinteger(L, 2) ;
    } else if (lua_type(L, 2) == LUA_TTABLE) {
        lua_rawgeti(L, 2, 1) ; lua_rawgeti(L, 2, 2) ; lua_rawgeti(L, 2, 3) ; lua_rawgeti(L, 2, 4) ;
        Ripv4number = ((uint32_t)luaL_checkinteger(L, -4) << 24) + ((uint32_t)luaL_checkinteger(L, -3) << 16) +
                      ((uint32_t)luaL_checkinteger(L, -2) << 8)  +  (uint32_t)luaL_checkinteger(L, -1) ;
        lua_pop(L, 4) ;
    } else {
        return luaL_argerror(L, 1, [[NSString stringWithFormat:@"number or table expected, found '%s'",
                                                                lua_typename(L, lua_type(L, 1))] UTF8String]) ;
    }
    struct sockaddr_in Ripv4sockaddr ;
    bzero(&Ripv4sockaddr, sizeof(Ripv4sockaddr));
    Ripv4sockaddr.sin_len         = sizeof(Ripv4sockaddr);
    Ripv4sockaddr.sin_family      = AF_INET;
    Ripv4sockaddr.sin_addr.s_addr = htonl(Ripv4number);

    SCNetworkReachabilityRef theRef = SCNetworkReachabilityCreateWithAddressPair(kCFAllocatorDefault, (void *)&Lipv4sockaddr, (void *)&Ripv4sockaddr);
    pushSCNetworkReachability(L, theRef) ;
    return 1 ;
}

static int reachabilityForHostName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    SCNetworkReachabilityRef theRef = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [[skin toNSObjectAtIndex:1] UTF8String]);
    pushSCNetworkReachability(L, theRef) ;
    return 1 ;
}

#pragma mark - Module Methods

static int reachabilityStatus(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNetworkReachabilityRef theRef = get_structFromUserdata(reachability_t, L, 1)->reachabilityObj ;
    SCNetworkReachabilityFlags flags = 0 ;
    Boolean valid = SCNetworkReachabilityGetFlags(theRef, &flags);
    if (valid) {
        lua_pushinteger(L, flags) ;
    } else {
        return luaL_error(L, "unable to get reachability flags:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

static int reachabilityStatusString(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNetworkReachabilityRef theRef = get_structFromUserdata(reachability_t, L, 1)->reachabilityObj ;
    SCNetworkReachabilityFlags flags = 0 ;
    Boolean valid = SCNetworkReachabilityGetFlags(theRef, &flags);
    if (valid) {
        [skin pushNSObject:statusString(flags)] ;
    } else {
        return luaL_error(L, "unable to get reachability flags:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

static int reachabilityCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];
    reachability_t* theRef = get_structFromUserdata(reachability_t, L, 1) ;

    // in either case, we need to remove an existing callback, so...
    theRef->callbackRef = [skin luaUnref:refTable ref:theRef->callbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        theRef->callbackRef = [skin luaRef:refTable];
    }

    lua_pushvalue(L, 1);
    return 1;
}

static int reachabilityStartWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    reachability_t* theRef = get_structFromUserdata(reachability_t, L, 1) ;
    if (!theRef->watcherEnabled) {
        SCNetworkReachabilityContext    context = { 0, NULL, NULL, NULL, NULL };
        context.info = (void *)theRef;
        if(SCNetworkReachabilitySetCallback(theRef->reachabilityObj, doReachabilityCallback, &context)) {
            if (SCNetworkReachabilitySetDispatchQueue(theRef->reachabilityObj, reachabilityQueue)) {
                theRef->watcherEnabled = YES ;
            } else {
                SCNetworkReachabilitySetCallback(theRef->reachabilityObj, NULL, NULL);
                return luaL_error(L, "unable to set watcher dispatch queue:%s", SCErrorString(SCError())) ;
            }
        } else {
            return luaL_error(L, "unable to set watcher callback:%s", SCErrorString(SCError())) ;
        }
    }
    lua_pushvalue(L, 1);
    return 1;
}

static int reachabilityStopWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    reachability_t* theRef = get_structFromUserdata(reachability_t, L, 1) ;
    SCNetworkReachabilitySetCallback(theRef->reachabilityObj, NULL, NULL);
    SCNetworkReachabilitySetDispatchQueue(theRef->reachabilityObj, NULL);
    theRef->watcherEnabled = NO ;
    lua_pushvalue(L, 1);
    return 1;
}


#pragma mark - Module Constants

static int pushReachabilityFlags(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsTransientConnection) ;  lua_setfield(L, -2, "transientConnection") ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsReachable) ;            lua_setfield(L, -2, "reachable") ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsConnectionRequired) ;   lua_setfield(L, -2, "connectionRequired") ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsConnectionOnTraffic) ;  lua_setfield(L, -2, "connectionOnTraffic") ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsInterventionRequired) ; lua_setfield(L, -2, "interventionRequired") ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsConnectionOnDemand) ;   lua_setfield(L, -2, "connectionOnDemand") ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsIsLocalAddress) ;       lua_setfield(L, -2, "isLocalAddress") ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsIsDirect) ;             lua_setfield(L, -2, "isDirect") ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    SCNetworkReachabilityRef theRef = get_structFromUserdata(reachability_t, L, 1)->reachabilityObj ;
    SCNetworkReachabilityFlags flags = 0 ;
    Boolean valid = SCNetworkReachabilityGetFlags(theRef, &flags);
    NSString *flagString = @"*unable to get reachability flags*" ;
    if (valid)  flagString = statusString(flags) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, flagString, theRef]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        SCNetworkReachabilityRef theRef1 = get_structFromUserdata(reachability_t, L, 1)->reachabilityObj ;
        SCNetworkReachabilityRef theRef2 = get_structFromUserdata(reachability_t, L, 2)->reachabilityObj ;
        lua_pushboolean(L, CFEqual(theRef1, theRef2)) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    reachability_t* theRef = get_structFromUserdata(reachability_t, L, 1) ;
    [skin luaUnref:refTable ref:theRef->callbackRef] ;
    CFRelease(theRef->reachabilityObj) ;
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    reachabilityQueue = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"status",       reachabilityStatus},
    {"statusString", reachabilityStatusString},
    {"setCallback",  reachabilityCallback},
    {"start",        reachabilityStartWatcher},
    {"stop",         reachabilityStopWatcher},

    {"__tostring",   userdata_tostring},
    {"__eq",         userdata_eq},
    {"__gc",         userdata_gc},
    {NULL,           NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"_forIPv4Address",     reachabilityForIPv4Address},
    {"_forIPv4AddressPair", reachabilityForIPv4AddressPair},
//     {"forIPv6Address",      reachabilityForIPv6Address},
//     {"forIPv6AddressPair",  reachabilityForIPv6AddressPair},
    {"forHostName",         reachabilityForHostName},
    {NULL,                  NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs__asm_reachability_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    // unlike dispatch_get_main_queue, this is concurrent... make sure to invoke lua part of callback
    // on main queue, though...
    reachabilityQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    pushReachabilityFlags(L) ; lua_setfield(L, -2, "flags") ;

    return 1;
}
