@import Cocoa ;
@import LuaSkin ;

@import dnssd ;
@import Darwin.POSIX.net ;

static const char * const USERDATA_TAG = "hs._asm.dnssd" ;
static int refTable = LUA_NOREF;

// #define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

static int dnssd_getApiVersion(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;

    uint32_t version ;
    uint32_t size = sizeof(uint32_t) ;
    DNSServiceErrorType err = DNSServiceGetProperty(kDNSServiceProperty_DaemonVersion, &version, &size) ;
    if (!err) {
        [skin pushNSObject:[NSString stringWithFormat:@"%d.%d.%d", version / 10000, version / 100 % 100, version % 100]] ;
        lua_pushinteger(L, version) ;
    } else {
        lua_pushnil(L) ;
        lua_pushinteger(L, err) ;
    }
    return 2 ;
}

static int dnssd_interfaces(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    NSDictionary *specialInterfaceIndexes = @{
        @"any"     : @(kDNSServiceInterfaceIndexAny),
        @"local"   : @(kDNSServiceInterfaceIndexLocalOnly),
        @"unicast" : @(kDNSServiceInterfaceIndexUnicast),
        @"P2P"     : @(kDNSServiceInterfaceIndexP2P),
        @"BLE"     : @(kDNSServiceInterfaceIndexBLE),
    } ;

    BOOL withIndexes = (lua_gettop(L) == 1) && lua_toboolean(L, 1) ;

    [skin pushNSObject:(withIndexes ? specialInterfaceIndexes : specialInterfaceIndexes.allKeys)] ;

    struct if_nameindex *knownInterfaces = if_nameindex() ;
    if (knownInterfaces) {
        for (struct if_nameindex *i = knownInterfaces; ! (i->if_index == 0 && i->if_name == NULL); i++) {
            if (withIndexes) {
                lua_pushinteger(L, i->if_index) ; lua_setfield(L, -2, i->if_name) ;
            } else {
                lua_pushstring(L, i->if_name) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
        }
        if_freenameindex(knownInterfaces) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"%s.interfaces - error enumerating available interfaces", USERDATA_TAG]] ;
    }
    return 1 ;
}

#pragma mark - Module Methods

#pragma mark - Module Constants

static int dnssd_errorList(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin pushNSObject:@{
        @(kDNSServiceErr_Unknown)                   : @"Unknown error",
        @(kDNSServiceErr_NoSuchName)                : @"No such name",
        @(kDNSServiceErr_NoMemory)                  : @"No memory",
        @(kDNSServiceErr_BadParam)                  : @"Bad parameter, has interface been removed?",
        @(kDNSServiceErr_BadReference)              : @"Bad reference",
        @(kDNSServiceErr_BadState)                  : @"Bad state",
        @(kDNSServiceErr_BadFlags)                  : @"Bad flags",
        @(kDNSServiceErr_Unsupported)               : @"Unsupported",
        @(kDNSServiceErr_NotInitialized)            : @"Not initialized",
        @(kDNSServiceErr_AlreadyRegistered)         : @"Already registered",
        @(kDNSServiceErr_NameConflict)              : @"Name conflict",
        @(kDNSServiceErr_Invalid)                   : @"Invalid",
        @(kDNSServiceErr_Firewall)                  : @"Firewall",
        @(kDNSServiceErr_Incompatible)              : @"Client library incompatible with mDNSResponder service",
        @(kDNSServiceErr_BadInterfaceIndex)         : @"Bad interface index, has interface been removed?",
        @(kDNSServiceErr_Refused)                   : @"Refused",
        @(kDNSServiceErr_NoSuchRecord)              : @"No such record",
        @(kDNSServiceErr_NoAuth)                    : @"No auth",
        @(kDNSServiceErr_NoSuchKey)                 : @"No such key",
        @(kDNSServiceErr_NATTraversal)              : @"NAT Traversal",
        @(kDNSServiceErr_DoubleNAT)                 : @"Double NAT",
        @(kDNSServiceErr_BadTime)                   : @"Bad time",
        @(kDNSServiceErr_BadSig)                    : @"Bad sig",
        @(kDNSServiceErr_BadKey)                    : @"Bad key",
        @(kDNSServiceErr_Transient)                 : @"Transient",
        @(kDNSServiceErr_ServiceNotRunning)         : @"mDNSResponder service not running",
        @(kDNSServiceErr_NATPortMappingUnsupported) : @"NAT port mapping unsupported",
        @(kDNSServiceErr_NATPortMappingDisabled)    : @"NAT port mapping disabled",
        @(kDNSServiceErr_NoRouter)                  : @"No router currently configured; network available?",
        @(kDNSServiceErr_PollingMode)               : @"Polling mode",
        @(kDNSServiceErr_Timeout)                   : @"Timeout",
    }] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

// static int push<moduleType>(lua_State *L, id obj) {
//     <moduleType> *value = obj;
//     value.selfRefCount++ ;
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
//         value = get_objectFromUserdata(__bridge <moduleType>, L, idx, USERDATA_TAG) ;
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
//     <moduleType> *obj = get_objectFromUserdata(__bridge_transfer <moduleType>, L, 1, USERDATA_TAG) ;
//     if (obj) {
//         obj.selfRefCount-- ;
//         if (obj.selfRefCount == 0) {
//             obj = nil ;
//         }
//     }
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
    {"apiVersion", dnssd_getApiVersion},
    {"interfaces", dnssd_interfaces},
    {NULL,         NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_dnssd_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib

    dnssd_errorList(L) ; lua_setfield(L, -2, "_errorList") ;

    return 1;
}
