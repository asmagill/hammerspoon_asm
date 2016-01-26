#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import <netinet/in.h>
#import <netdb.h>

// TODO:
//    This just tests for a "route to"... do we need a test that it's actually up?
//    OpenVPN interface not managed by SCNetworkInterface, so its network is seen as direct;
//       however, checking for the interfaces IP address will specify whether its local or not

#define USERDATA_TAG    "hs.network.reachability"
static int              refTable          = LUA_NOREF;
static dispatch_queue_t reachabilityQueue = nil ;

#define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

typedef struct _reachability_t {
    SCNetworkReachabilityRef reachabilityObj;
    int                      callbackRef ;
    int                      selfRef ;
    BOOL                     watcherEnabled ;
} reachability_t;

static int pushSCNetworkReachability(lua_State *L, SCNetworkReachabilityRef theRef) {
    reachability_t* thePtr = lua_newuserdata(L, sizeof(reachability_t)) ;
    memset(thePtr, 0, sizeof(reachability_t)) ;

    thePtr->reachabilityObj = CFRetain(theRef) ;
    thePtr->callbackRef     = LUA_NOREF ;
    thePtr->selfRef         = LUA_NOREF ;
    thePtr->watcherEnabled  = NO ;

    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static void doReachabilityCallback(__unused SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    reachability_t *theRef = (reachability_t *)info ;
    if (theRef->callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            [skin pushLuaRef:refTable ref:theRef->callbackRef] ;
            [skin pushLuaRef:refTable ref:theRef->selfRef] ;
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

static int reachabilityForAddress(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;

    luaL_checkstring(L, 1) ; // force number to be a string
    struct addrinfo *results = NULL ;
    struct addrinfo hints = { AI_NUMERICHOST | AI_NUMERICSERV, PF_UNSPEC, 0, 0, 0, NULL, NULL, NULL } ;
    int ecode = getaddrinfo([[skin toNSObjectAtIndex:1] UTF8String], NULL, &hints, &results);
    if (ecode != 0) {
        if (results) freeaddrinfo(results) ;
        return luaL_error(L, "address parse error: %s", gai_strerror(ecode)) ;
    }
    SCNetworkReachabilityRef theRef = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (void *)results->ai_addr);
    pushSCNetworkReachability(L, theRef) ;
    CFRelease(theRef) ;
    if (results) freeaddrinfo(results) ;
    return 1 ;
}

static int reachabilityForAddressPair(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;

    luaL_checkstring(L, 1) ; // force number to be a string
    struct addrinfo *results1 = NULL ;
    struct addrinfo hints = { AI_NUMERICHOST | AI_NUMERICSERV, PF_UNSPEC, 0, 0, 0, NULL, NULL, NULL } ;
    int ecode1 = getaddrinfo([[skin toNSObjectAtIndex:1] UTF8String], NULL, &hints, &results1);
    if (ecode1 != 0) {
        if (results1) freeaddrinfo(results1) ;
        return luaL_error(L, "local address parse error: %s", gai_strerror(ecode1)) ;
    }

    luaL_checkstring(L, 2) ; // force number to be a string
    struct addrinfo *results2 = NULL ;
    int ecode2 = getaddrinfo([[skin toNSObjectAtIndex:2] UTF8String], NULL, &hints, &results2);
    if (ecode2 != 0) {
        if (results1) freeaddrinfo(results1) ;
        if (results2) freeaddrinfo(results2) ;
        return luaL_error(L, "remote address parse error: %s", gai_strerror(ecode2)) ;
    }

    SCNetworkReachabilityRef theRef = SCNetworkReachabilityCreateWithAddressPair(kCFAllocatorDefault, results1->ai_addr, results2->ai_addr);
    pushSCNetworkReachability(L, theRef) ;
    CFRelease(theRef) ;

    if (results1) freeaddrinfo(results1) ;
    if (results2) freeaddrinfo(results2) ;
    return 1 ;
}

static int reachabilityForHostName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    SCNetworkReachabilityRef theRef = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [[skin toNSObjectAtIndex:1] UTF8String]);
    pushSCNetworkReachability(L, theRef) ;
    CFRelease(theRef) ;
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
        if (theRef->selfRef == LUA_NOREF) {               // make sure that we won't be __gc'd if a callback exists
            lua_pushvalue(L, 1) ;                         // but the user doesn't save us somewhere
            theRef->selfRef = [skin luaRef:refTable];
        }
    } else {
        theRef->selfRef = [skin luaUnref:refTable ref:theRef->selfRef] ;
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
    NSString *flagString = @"** unable to get reachability flags*" ;
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
//     [skin logVerbose:@"Reachability GC"] ;
    reachability_t* theRef = get_structFromUserdata(reachability_t, L, 1) ;
    if (theRef->callbackRef != LUA_NOREF) {
        theRef->callbackRef = [skin luaUnref:refTable ref:theRef->callbackRef] ;
        SCNetworkReachabilitySetCallback(theRef->reachabilityObj, NULL, NULL);
        SCNetworkReachabilitySetDispatchQueue(theRef->reachabilityObj, NULL);
    }
    theRef->selfRef = [skin luaUnref:refTable ref:theRef->selfRef] ;

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
    {"forAddressPair", reachabilityForAddressPair},
    {"forAddress",     reachabilityForAddress},
    {"forHostName",    reachabilityForHostName},
    {NULL,             NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_network_reachabilityinternal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
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
