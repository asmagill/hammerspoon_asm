#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <SystemConfiguration/SCDynamicStoreCopyDHCPInfo.h>

#define USERDATA_TAG "hs._asm.dynamicstore"
static int           refTable = LUA_NOREF;

// #define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_cfobjectFromUserdata(objType, L, idx) *((objType*)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

static SCDynamicStoreRef createTheStore(lua_State *L) {
    SCDynamicStoreContext context = { 0, NULL, NULL, NULL, NULL };
    SCDynamicStoreRef theStore = SCDynamicStoreCreate(kCFAllocatorDefault, (CFStringRef)@"Hammerspoon", NULL, &context );
    if (!theStore) {
        luaL_error(L, "unable to get dynamicStore contents:%s", SCErrorString(SCError())) ;
        return nil ;
    }
    return theStore ;
}

#pragma mark - Module Functions

static int dynamicStoreContents(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSArray *keys ;
    BOOL keysIsPattern = NO ;
    if (lua_gettop(L) == 0) {
        keys = @[ @".*" ] ;
        keysIsPattern = YES ;
    } else if (lua_gettop(L) == 1) {
        [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
        keys = [skin toNSObjectAtIndex:1] ;
    } else {
        keys = [skin toNSObjectAtIndex:1] ;
        keysIsPattern = (BOOL)lua_toboolean(L, 2) ;
    }

    SCDynamicStoreRef theStore = createTheStore(L) ;
    CFDictionaryRef results ;
    if (keysIsPattern) {
        results = SCDynamicStoreCopyMultiple (theStore, NULL, (__bridge CFArrayRef)keys);
    } else {
        results = SCDynamicStoreCopyMultiple (theStore, (__bridge CFArrayRef)keys, NULL);
    }
    if (results) {
        [skin pushNSObject:(__bridge NSDictionary *)results withOptions:(LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits)] ;
        CFRelease(results) ;
    } else {
        return luaL_error(L, "unable to get dynamicStore contents:%s", SCErrorString(SCError())) ;
    }
    CFRelease(theStore) ;
    return 1 ;
}

static int dynamicStoreDHCPInfo(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *serviceID ;
    if (lua_gettop(L) == 1) {
        luaL_checkstring(L, 1) ;
        serviceID = [skin toNSObjectAtIndex:1] ;
    }
    SCDynamicStoreRef theStore = createTheStore(L) ;
    CFDictionaryRef results = SCDynamicStoreCopyDHCPInfo(theStore, (__bridge CFStringRef)serviceID);
    if (results) {
        [skin pushNSObject:(__bridge NSDictionary *)results withOptions:(LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits)] ;
        CFRelease(results) ;
    } else {
        return luaL_error(L, "unable to get DHCP info:%s", SCErrorString(SCError())) ;
    }
    CFRelease(theStore) ;
    return 1 ;
}

static int dynamicStoreComputerName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    SCDynamicStoreRef theStore = createTheStore(L) ;
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
        CFRelease(theStore) ;
        return luaL_error(L, "** error retrieving computer name:%s", SCErrorString(SCError())) ;
    }
    CFRelease(theStore) ;
    return 2 ;
}

static int dynamicStoreConsoleUser(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    SCDynamicStoreRef theStore = createTheStore(L) ;
    uid_t uid ;
    gid_t gid ;
    CFStringRef consoleUser = SCDynamicStoreCopyConsoleUser(theStore, &uid, &gid);
    if (consoleUser) {
        [skin pushNSObject:(__bridge NSString *)consoleUser] ;
        lua_pushinteger(L, uid) ;
        lua_pushinteger(L, gid) ;
        CFRelease(consoleUser) ;
    } else {
        CFRelease(theStore) ;
        return luaL_error(L, "** error retrieving console user:%s", SCErrorString(SCError())) ;
    }
    CFRelease(theStore) ;
    return 3 ;
}

static int dynamicStoreLocalHostName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    SCDynamicStoreRef theStore = createTheStore(L) ;
    CFStringRef localHostName = SCDynamicStoreCopyLocalHostName(theStore);
    if (localHostName) {
        [skin pushNSObject:(__bridge NSString *)localHostName] ;
        CFRelease(localHostName) ;
    } else {
        CFRelease(theStore) ;
        return luaL_error(L, "** error retrieving local host name:%s", SCErrorString(SCError())) ;
    }
    CFRelease(theStore) ;
    return 1 ;
}

static int dynamicStoreLocation(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    SCDynamicStoreRef theStore = createTheStore(L) ;
    CFStringRef location = SCDynamicStoreCopyLocation(theStore);
    if (location) {
        [skin pushNSObject:(__bridge NSString *)location] ;
        CFRelease(location) ;
    } else {
        CFRelease(theStore) ;
        return luaL_error(L, "** error retrieving location:%s", SCErrorString(SCError())) ;
    }
    CFRelease(theStore) ;
    return 1 ;
}

static int dynamicStoreProxies(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    SCDynamicStoreRef theStore = createTheStore(L) ;
    CFDictionaryRef proxies = SCDynamicStoreCopyProxies(theStore);
    if (proxies) {
        [skin pushNSObject:(__bridge NSDictionary *)proxies] ;
        CFRelease(proxies) ;
    } else {
        CFRelease(theStore) ;
        return luaL_error(L, "** error retrieving proxies:%s", SCErrorString(SCError())) ;
    }
    CFRelease(theStore) ;
    return 1 ;
}

#pragma mark - Module Methods

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

// static int push<moduleType>(lua_State *L, id obj) {
//     <moduleType> *value = obj;
//     void** valuePtr = lua_newuserdata(L, sizeof(<moduleType> *));
//     *valuePtr = (__bridge_retained void *)value;
//     luaL_getmetatable(L, USERDATA_TAG);
//     lua_setmetatable(L, -2);
//     return 1;
// }
//
// id to<moduleType>FromLua(lua_State *L, int idx) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     <moduleType> *value ;
//     if (luaL_testudata(L, idx, USERDATA_TAG)) {
//         value = get_objectFromUserdata(__bridge <moduleType>, L, idx) ;
//     } else {
//         [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
//                                                    lua_typename(L, lua_type(L, idx))]] ;
//     }
//     return value ;
// }

#pragma mark - Hammerspoon/Lua Infrastructure

// static int userdata_tostring(lua_State* L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     <moduleType> *obj = [skin luaObjectAtIndex:1 toClass:"<moduleType>"] ;
//     NSString *title = ... ;
//     [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
//     return 1 ;
// }

// static int userdata_eq(lua_State* L) {
// // can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// // so use luaL_testudata before the macro causes a lua error
//     if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
//         LuaSkin *skin = [LuaSkin shared] ;
//         <moduleType> *obj1 = [skin luaObjectAtIndex:1 toClass:"<moduleType>"] ;
//         <moduleType> *obj2 = [skin luaObjectAtIndex:2 toClass:"<moduleType>"] ;
//         lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
//     } else {
//         lua_pushboolean(L, NO) ;
//     }
//     return 1 ;
// }

// static int userdata_gc(lua_State* L) {
//     <moduleType> *obj = get_objectFromUserdata(__bridge_transfer <moduleType>, L, 1) ;
//     if (obj) obj = nil ;
//     // Remove the Metatable so future use of the variable in Lua won't think its valid
//     lua_pushnil(L) ;
//     lua_setmetatable(L, 1) ;
//     return 0 ;
// }

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// // Metatable for userdata objects
// static const luaL_Reg userdata_metaLib[] = {
//     {"__tostring", userdata_tostring},
//     {"__eq",       userdata_eq},
//     {"__gc",       userdata_gc},
//     {NULL,         NULL}
// };

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"contents",     dynamicStoreContents},
    {"DHCPInfo",     dynamicStoreDHCPInfo},
    {"computerName", dynamicStoreComputerName},
    {"consoleUser",  dynamicStoreConsoleUser},
    {"hostName",     dynamicStoreLocalHostName},
    {"location",     dynamicStoreLocation},
    {"proxies",      dynamicStoreProxies},
    {NULL,           NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_dynamicstore_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
// Use this if your module doesn't have a module specific object that it returns.
   refTable = [skin registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
//     refTable = [skin registerLibraryWithObject:USERDATA_TAG
//                                      functions:moduleLib
//                                  metaFunctions:nil    // or module_metaLib
//                                objectFunctions:userdata_metaLib];

    return 1;
}
