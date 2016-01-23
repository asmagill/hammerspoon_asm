#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <SystemConfiguration/SCDynamicStoreCopyDHCPInfo.h>

#define USERDATA_TAG    "hs.network.configuration"
static int              refTable          = LUA_NOREF;
static dispatch_queue_t dynamicStoreQueue = nil ;

#define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

typedef struct _dynamicstore_t {
    SCDynamicStoreRef storeObject;
    int               callbackRef ;
    int               selfRef ;
    BOOL              watcherEnabled ;
} dynamicstore_t;

static void doDynamicStoreCallback(__unused SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
    dynamicstore_t *thePtr = (dynamicstore_t *)info ;
    if (thePtr->callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            [skin pushLuaRef:refTable ref:thePtr->callbackRef] ;
            [skin pushLuaRef:refTable ref:thePtr->selfRef] ;
            if (changedKeys) {
                [skin pushNSObject:(__bridge NSArray *)changedKeys] ;
            } else {
                lua_pushnil(L) ;
            }
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s:error in Lua callback:%@",
                                                            USERDATA_TAG,
                                                            [skin toNSObjectAtIndex:-1]]] ;
                lua_pop(L, 1) ; // error string from pcall
            }
        }) ;
    }
}

#pragma mark - Module Functions

static int newStoreObject(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    NSString *theName = [[NSUUID UUID] UUIDString] ;
    dynamicstore_t *thePtr = lua_newuserdata(L, sizeof(dynamicstore_t)) ;
    memset(thePtr, 0, sizeof(dynamicstore_t)) ;

    SCDynamicStoreContext context = { 0, NULL, NULL, NULL, NULL };
    context.info = (void *)thePtr;
    SCDynamicStoreRef theStore = SCDynamicStoreCreate(kCFAllocatorDefault, (__bridge CFStringRef)theName, doDynamicStoreCallback, &context );
    if (theStore) {
        thePtr->storeObject    = CFRetain(theStore) ;
        thePtr->callbackRef    = LUA_NOREF ;
        thePtr->selfRef        = LUA_NOREF ;
        thePtr->watcherEnabled = NO ;

        luaL_getmetatable(L, USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
//         SCDynamicStoreSetDispatchQueue(thePtr->storeObject, dynamicStoreQueue);
        CFRelease(theStore) ; // we retained it in the structure, so release it here
    } else {
        return luaL_error(L, "** unable to get dynamicStore reference:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int dynamicStoreContents(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING | LS_TTABLE | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    NSArray *keys ;
    BOOL keysIsPattern = NO ;
    if (lua_gettop(L) == 1) {
        keys = @[ @".*" ] ;
        keysIsPattern = YES ;
    } else {
        if (lua_type(L, 2) == LUA_TTABLE) {
            keys = [skin toNSObjectAtIndex:2] ;
        } else {
            keys = [NSArray arrayWithObject:[skin toNSObjectAtIndex:2]] ;
        }
        if (lua_gettop(L) == 3) keysIsPattern = (BOOL)lua_toboolean(L, 3) ;
    }

    CFDictionaryRef results ;
    if (keysIsPattern) {
        results = SCDynamicStoreCopyMultiple(theStore, NULL, (__bridge CFArrayRef)keys);
    } else {
        results = SCDynamicStoreCopyMultiple(theStore, (__bridge CFArrayRef)keys, NULL);
    }
    if (results) {
        [skin pushNSObject:(__bridge NSDictionary *)results withOptions:(LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits)] ;
        CFRelease(results) ;
    } else {
        return luaL_error(L, "** unable to get dynamicStore contents:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

static int dynamicStoreKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    NSString *keys = (lua_gettop(L) == 1) ? @".*" : [skin toNSObjectAtIndex:2] ;
    CFArrayRef results ;
    results = SCDynamicStoreCopyKeyList(theStore, (__bridge CFStringRef)keys);
    if (results) {
        [skin pushNSObject:(__bridge NSArray *)results withOptions:(LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits)] ;
        CFRelease(results) ;
    } else {
        return luaL_error(L, "** unable to get dynamicStore keys:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

static int dynamicStoreDHCPInfo(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    NSString *serviceID ;
    if (lua_gettop(L) == 2) {
        serviceID = [skin toNSObjectAtIndex:2] ;
    }

    CFDictionaryRef results = SCDynamicStoreCopyDHCPInfo(theStore, (__bridge CFStringRef)serviceID);
    if (results) {
        [skin pushNSObject:(__bridge NSDictionary *)results withOptions:(LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits)] ;
        CFRelease(results) ;
    } else {
        return luaL_error(L, "** unable to get DHCP info:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

static int dynamicStoreComputerName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    CFStringEncoding encoding ;
    CFStringRef computerName = SCDynamicStoreCopyComputerName(theStore, &encoding);
    if (computerName) {
        [skin pushNSObject:(__bridge NSString *)computerName] ;
        switch(encoding) {
            case kCFStringEncodingMacRoman:      [skin pushNSObject:@"MacRoman"] ; break ;
            case kCFStringEncodingWindowsLatin1: [skin pushNSObject:@"WindowsLatin1"] ; break ;
            case kCFStringEncodingISOLatin1:     [skin pushNSObject:@"ISOLatin1"] ; break ;
            case kCFStringEncodingNextStepLatin: [skin pushNSObject:@"NextStepLatin"] ; break ;
            case kCFStringEncodingASCII:         [skin pushNSObject:@"ASCII"] ; break ;
// alias for kCFStringEncodingUTF16; choose UTF16, since Unicode is not one specific encoding - all UTF
// types are more accurately a way to encode Unicode
//             case kCFStringEncodingUnicode:       [skin pushNSObject:@"Unicode"] ; break ;
            case kCFStringEncodingUTF8:          [skin pushNSObject:@"UTF8"] ; break ;
            case kCFStringEncodingNonLossyASCII: [skin pushNSObject:@"NonLossyASCII"] ; break ;
            case kCFStringEncodingUTF16:         [skin pushNSObject:@"UTF16"] ; break ;
            case kCFStringEncodingUTF16BE:       [skin pushNSObject:@"UTF16BE"] ; break ;
            case kCFStringEncodingUTF16LE:       [skin pushNSObject:@"UTF16LE"] ; break ;
            case kCFStringEncodingUTF32:         [skin pushNSObject:@"UTF32"] ; break ;
            case kCFStringEncodingUTF32BE:       [skin pushNSObject:@"UTF32BE"] ; break ;
            case kCFStringEncodingUTF32LE:       [skin pushNSObject:@"UTF32LE"] ; break ;
            case kCFStringEncodingInvalidId:     [skin pushNSObject:@"InvalidId"] ; break ;
            default:
                [skin pushNSObject:[NSString stringWithFormat:@"** unrecognized encoding:%d", encoding]] ;
                break ;
        }
        CFRelease(computerName) ;
    } else {
        return luaL_error(L, "** error retrieving computer name:%s", SCErrorString(SCError())) ;
    }
    return 2 ;
}

static int dynamicStoreConsoleUser(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    uid_t uid ;
    gid_t gid ;
    CFStringRef consoleUser = SCDynamicStoreCopyConsoleUser(theStore, &uid, &gid);
    if (consoleUser) {
        [skin pushNSObject:(__bridge NSString *)consoleUser] ;
        lua_pushinteger(L, uid) ;
        lua_pushinteger(L, gid) ;
        CFRelease(consoleUser) ;
    } else {
        return luaL_error(L, "** error retrieving console user:%s", SCErrorString(SCError())) ;
    }
    return 3 ;
}

static int dynamicStoreLocalHostName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    CFStringRef localHostName = SCDynamicStoreCopyLocalHostName(theStore);
    if (localHostName) {
        [skin pushNSObject:(__bridge NSString *)localHostName] ;
        CFRelease(localHostName) ;
    } else {
        return luaL_error(L, "** error retrieving local host name:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

static int dynamicStoreLocation(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    CFStringRef location = SCDynamicStoreCopyLocation(theStore);
    if (location) {
        [skin pushNSObject:(__bridge NSString *)location] ;
        CFRelease(location) ;
    } else {
        return luaL_error(L, "** error retrieving location:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

static int dynamicStoreProxies(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    CFDictionaryRef proxies = SCDynamicStoreCopyProxies(theStore);
    if (proxies) {
        [skin pushNSObject:(__bridge NSDictionary *)proxies] ;
        CFRelease(proxies) ;
    } else {
        return luaL_error(L, "** error retrieving proxies:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

static int dynamicStoreSetCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];
    dynamicstore_t* thePtr = get_structFromUserdata(dynamicstore_t, L, 1) ;

    // in either case, we need to remove an existing callback, so...
    thePtr->callbackRef = [skin luaUnref:refTable ref:thePtr->callbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        thePtr->callbackRef = [skin luaRef:refTable];
        if (thePtr->selfRef == LUA_NOREF) {               // make sure that we won't be __gc'd if a callback exists
            lua_pushvalue(L, 1) ;                         // but the user doesn't save us somewhere
            thePtr->selfRef = [skin luaRef:refTable];
        }
    } else {
        thePtr->selfRef = [skin luaUnref:refTable ref:thePtr->selfRef] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

static int dynamicStoreStartWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    dynamicstore_t* thePtr = get_structFromUserdata(dynamicstore_t, L, 1) ;
    if (!thePtr->watcherEnabled) {
        if (SCDynamicStoreSetDispatchQueue(thePtr->storeObject, dynamicStoreQueue)) {
            thePtr->watcherEnabled = YES ;
        } else {
            return luaL_error(L, "unable to set watcher dispatch queue:%s", SCErrorString(SCError())) ;
        }
    }
    lua_pushvalue(L, 1);
    return 1;
}

static int dynamicStoreStopWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    dynamicstore_t* thePtr = get_structFromUserdata(dynamicstore_t, L, 1) ;
    if (!SCDynamicStoreSetDispatchQueue(thePtr->storeObject, NULL)) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"%s:stop, error removing watcher from dispatch queue:%s",
                                                USERDATA_TAG, SCErrorString(SCError())]] ;
    }
    thePtr->watcherEnabled = NO ;
    lua_pushvalue(L, 1);
    return 1;
}

static int dynamicStoreMonitorKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING | LS_TTABLE | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    NSArray *keys ;
    BOOL keysIsPattern = NO ;
    if (lua_gettop(L) == 1) {
        keys = @[ @".*" ] ;
        keysIsPattern = YES ;
    } else {
        if (lua_type(L, 2) == LUA_TTABLE) {
            keys = [skin toNSObjectAtIndex:2] ;
        } else {
            keys = [NSArray arrayWithObject:[skin toNSObjectAtIndex:2]] ;
        }
        if (lua_gettop(L) == 3) keysIsPattern = (BOOL)lua_toboolean(L, 3) ;
    }

    Boolean result ;
    if (keysIsPattern) {
        result = SCDynamicStoreSetNotificationKeys(theStore, NULL, (__bridge CFArrayRef)keys);
    } else {
        result = SCDynamicStoreSetNotificationKeys(theStore, (__bridge CFArrayRef)keys, NULL);
    }
    if (result) {
        lua_pushvalue(L, 1) ;
    } else {
        return luaL_error(L, "** unable to set keys to monitor:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, theStore]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        SCDynamicStoreRef theStore1 = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;
        SCDynamicStoreRef theStore2 = get_structFromUserdata(dynamicstore_t, L, 2)->storeObject ;
        lua_pushboolean(L, CFEqual(theStore1, theStore2)) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
//     [skin logDebug:@"dynamicstore GC"] ;
    dynamicstore_t* thePtr = get_structFromUserdata(dynamicstore_t, L, 1) ;
    if (thePtr->callbackRef != LUA_NOREF) {
        thePtr->callbackRef = [skin luaUnref:refTable ref:thePtr->callbackRef] ;
        if (!SCDynamicStoreSetDispatchQueue(thePtr->storeObject, NULL)) {
            [skin logBreadcrumb:[NSString stringWithFormat:@"%s:__gc, error removing watcher from dispatch queue:%s",
                                                            USERDATA_TAG, SCErrorString(SCError())]] ;
        }
    }
    thePtr->selfRef = [skin luaUnref:refTable ref:thePtr->selfRef] ;

    CFRelease(thePtr->storeObject) ;
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    dynamicStoreQueue = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"contents",     dynamicStoreContents},
    {"keys",         dynamicStoreKeys},
    {"dhcpInfo",     dynamicStoreDHCPInfo},
    {"computerName", dynamicStoreComputerName},
    {"consoleUser",  dynamicStoreConsoleUser},
    {"hostName",     dynamicStoreLocalHostName},
    {"location",     dynamicStoreLocation},
    {"proxies",      dynamicStoreProxies},
    {"monitorKeys",  dynamicStoreMonitorKeys},
    {"setCallback",  dynamicStoreSetCallback},
    {"start",        dynamicStoreStartWatcher},
    {"stop",         dynamicStoreStopWatcher},

    {"__tostring",   userdata_tostring},
    {"__eq",         userdata_eq},
    {"__gc",         userdata_gc},
    {NULL,           NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"newStore", newStoreObject},
    {NULL,       NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_network_configurationinternal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    dynamicStoreQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);

    return 1;
}
