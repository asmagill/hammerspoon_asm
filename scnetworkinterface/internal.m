#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import <SystemConfiguration/SystemConfiguration.h>

#define USERDATA_TAG "hs._asm.scnetworkinterface"
static int refTable = LUA_NOREF;

// #define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))
#define get_cfobjectFromUserdata(objType, L, idx) *((objType*)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

static int pushSCNetworkInterface(lua_State *L, SCNetworkInterfaceRef theInterface) ;

#pragma mark - Module Functions

static int getInterfaces(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_newtable(L) ;
    CFArrayRef theNetworks = SCNetworkInterfaceCopyAll();
    if (theNetworks) {
        CFIndex interfaceCount = CFArrayGetCount(theNetworks) ;
        for (CFIndex i = 0 ; i < interfaceCount ; i++) {
            CFTypeRef value = CFArrayGetValueAtIndex(theNetworks, i) ;
            CFTypeID valueType = CFGetTypeID(value) ;
            if (valueType == SCNetworkInterfaceGetTypeID()) {
                pushSCNetworkInterface(L, value) ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:wrong interface element type, found %ld",
                                                          USERDATA_TAG, valueType]] ;
            }
        }
        CFRelease(theNetworks) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int interfaceMPU(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNetworkInterfaceRef theInterface = get_cfobjectFromUserdata(SCNetworkInterfaceRef, L, 1) ;

    int mtu_cur = 0, mtu_min = 0, mtu_max = 0 ;
    Boolean valid = SCNetworkInterfaceCopyMTU(theInterface, &mtu_cur, &mtu_min, &mtu_max);
    if (valid) {
        lua_newtable(L) ;
        lua_pushinteger(L, mtu_cur) ; lua_setfield(L, -2, "current") ;
        lua_pushinteger(L, mtu_min) ; lua_setfield(L, -2, "min") ;
        lua_pushinteger(L, mtu_max) ; lua_setfield(L, -2, "max") ;
    } else {
        return luaL_error(L, "unable to get MTU information for interface:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

static int interfaceBSDName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNetworkInterfaceRef theInterface = get_cfobjectFromUserdata(SCNetworkInterfaceRef, L, 1) ;
    CFStringRef name = SCNetworkInterfaceGetBSDName(theInterface);
    if (name) {
        [skin pushNSObject:(__bridge NSString *)name] ;
//         CFRelease(name) ; // Get rule, not copy rule... I hope
    } else {
        return luaL_error(L, "unable to get bsdName for interface:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

static int interfaceHardwareAddress(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNetworkInterfaceRef theInterface = get_cfobjectFromUserdata(SCNetworkInterfaceRef, L, 1) ;
    CFStringRef address = SCNetworkInterfaceGetHardwareAddressString(theInterface);
    if (address) {
        [skin pushNSObject:(__bridge NSString *)address] ;
//         CFRelease(address) ; // Get rule, not copy rule... I hope
    } else {
        return luaL_error(L, "unable to get hardware address for interface:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

static int interfaceType(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNetworkInterfaceRef theInterface = get_cfobjectFromUserdata(SCNetworkInterfaceRef, L, 1) ;
    CFStringRef type = SCNetworkInterfaceGetInterfaceType(theInterface);
    if (type) {
        [skin pushNSObject:(__bridge NSString *)type] ;
//         CFRelease(type) ; // Get rule, not copy rule... I hope
    } else {
        return luaL_error(L, "unable to get interface type for interface:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

static int interfaceDisplayName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNetworkInterfaceRef theInterface = get_cfobjectFromUserdata(SCNetworkInterfaceRef, L, 1) ;
    CFStringRef name = SCNetworkInterfaceGetLocalizedDisplayName(theInterface);
    if (name) {
        [skin pushNSObject:(__bridge NSString *)name] ;
//         CFRelease(name) ; // Get rule, not copy rule... I hope
    } else {
        return luaL_error(L, "unable to get display name for interface:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

static int interfaceSubInterface(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNetworkInterfaceRef theInterface = get_cfobjectFromUserdata(SCNetworkInterfaceRef, L, 1) ;
    SCNetworkInterfaceRef subInterface = SCNetworkInterfaceGetInterface(theInterface) ;
    if (subInterface) {
        pushSCNetworkInterface(L, subInterface) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int interfaceSupportedTypes(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNetworkInterfaceRef theInterface = get_cfobjectFromUserdata(SCNetworkInterfaceRef, L, 1) ;
    CFArrayRef types = SCNetworkInterfaceGetSupportedInterfaceTypes(theInterface) ;
    [skin pushNSObject:(__bridge NSArray *)types withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

static int interfaceSupportedProtocols(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNetworkInterfaceRef theInterface = get_cfobjectFromUserdata(SCNetworkInterfaceRef, L, 1) ;
    CFArrayRef protocols = SCNetworkInterfaceGetSupportedProtocolTypes(theInterface) ;
    [skin pushNSObject:(__bridge NSArray *)protocols withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

static int interfaceConfiguration(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNetworkInterfaceRef theInterface = get_cfobjectFromUserdata(SCNetworkInterfaceRef, L, 1) ;
    CFDictionaryRef configuration = SCNetworkInterfaceGetConfiguration(theInterface) ;
    [skin logVerbose:[NSString stringWithFormat:@"configuration: %@", configuration]] ;
    [skin pushNSObject:(__bridge NSDictionary *)configuration withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

static int interfaceMediaOptions(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNetworkInterfaceRef theInterface = get_cfobjectFromUserdata(SCNetworkInterfaceRef, L, 1) ;
    Boolean filter = true ;
    if (lua_gettop(L) == 2) filter = (Boolean)lua_toboolean(L, 2) ;
    CFDictionaryRef current = NULL ;
    CFDictionaryRef active = NULL ;
    CFArrayRef      available = NULL ;
    Boolean valid = SCNetworkInterfaceCopyMediaOptions(theInterface, &current, &active, &available, filter);
    if (valid) {
        lua_newtable(L) ;
        if (current) {
            [skin pushNSObject:(__bridge NSDictionary *)current withOptions:LS_NSDescribeUnknownTypes] ;
            lua_setfield(L, -2, "current") ;
        }
        if (active) {
            [skin pushNSObject:(__bridge NSDictionary *)active withOptions:LS_NSDescribeUnknownTypes] ;
            lua_setfield(L, -2, "active") ;
        }
        if (available) {
            [skin pushNSObject:(__bridge NSArray *)available withOptions:LS_NSDescribeUnknownTypes] ;
            lua_setfield(L, -2, "available") ;
        }
    } else {
        return luaL_error(L, "unable to get configuration information for interface:%s", SCErrorString(SCError())) ;
    }
    if (current) CFRelease(current) ;
    if (active) CFRelease(active) ;
    if (available) CFRelease(available) ;
    return 1 ;
}

static int interfaceExtendedMediaOptions(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    SCNetworkInterfaceRef theInterface = get_cfobjectFromUserdata(SCNetworkInterfaceRef, L, 1) ;
    CFDictionaryRef options = SCNetworkInterfaceGetExtendedConfiguration(theInterface, (__bridge CFStringRef)[skin toNSObjectAtIndex:2]);
    if (options) {
        [skin pushNSObject:(__bridge NSDictionary *)options] ;
        CFRelease(options) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

// *   CFArrayRef SCNetworkInterfaceCopyAll ( void );
// *   Boolean SCNetworkInterfaceCopyMTU ( SCNetworkInterfaceRef interface, int *mtu_cur, int *mtu_min, int *mtu_max );
// *   CFStringRef SCNetworkInterfaceGetBSDName ( SCNetworkInterfaceRef interface );
// *   CFStringRef SCNetworkInterfaceGetHardwareAddressString ( SCNetworkInterfaceRef interface );
// *   CFStringRef SCNetworkInterfaceGetInterfaceType ( SCNetworkInterfaceRef interface );
// *   CFStringRef SCNetworkInterfaceGetLocalizedDisplayName ( SCNetworkInterfaceRef interface );
// *   CFTypeID SCNetworkInterfaceGetTypeID ( void );
// *   SCNetworkInterfaceRef SCNetworkInterfaceGetInterface ( SCNetworkInterfaceRef interface );
// *   CFArrayRef SCNetworkInterfaceGetSupportedInterfaceTypes ( SCNetworkInterfaceRef interface );
// *   CFArrayRef SCNetworkInterfaceGetSupportedProtocolTypes ( SCNetworkInterfaceRef interface );
// *   CFDictionaryRef SCNetworkInterfaceGetConfiguration ( SCNetworkInterfaceRef interface );
// *   Boolean SCNetworkInterfaceCopyMediaOptions ( SCNetworkInterfaceRef interface, CFDictionaryRef _Nullable *current, CFDictionaryRef _Nullable *active, CFArrayRef _Nullable *available, Boolean filter );

// *   CFDictionaryRef SCNetworkInterfaceGetExtendedConfiguration ( SCNetworkInterfaceRef interface, CFStringRef extendedType );

// ?   Boolean SCNetworkInterfaceForceConfigurationRefresh ( SCNetworkInterfaceRef interface );
// ?   SCNetworkInterfaceRef SCNetworkInterfaceCreateWithInterface ( SCNetworkInterfaceRef interface, CFStringRef interfaceType );
// ?   CFArrayRef SCNetworkInterfaceCopyMediaSubTypeOptions ( CFArrayRef available, CFStringRef subType );
// ?   CFArrayRef SCNetworkInterfaceCopyMediaSubTypes ( CFArrayRef available );

// -   Boolean SCNetworkInterfaceSetConfiguration ( SCNetworkInterfaceRef interface, CFDictionaryRef config );
// -   Boolean SCNetworkInterfaceSetExtendedConfiguration ( SCNetworkInterfaceRef interface, CFStringRef extendedType, CFDictionaryRef config );
// -   Boolean SCNetworkInterfaceSetMTU ( SCNetworkInterfaceRef interface, int mtu );
// -   Boolean SCNetworkInterfaceSetMediaOptions ( SCNetworkInterfaceRef interface, CFStringRef subtype, CFArrayRef options );

#pragma mark - Module Constants

static int pushInterfaceTypes(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceType6to4] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceTypeBluetooth] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceTypeBond] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceTypeEthernet] ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceTypeFireWire] ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceTypeIEEE80211] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceTypeIPSec] ;     lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceTypeIrDA] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceTypeL2TP] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceTypeModem] ;     lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceTypePPP] ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceTypePPTP] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceTypeSerial] ;    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceTypeVLAN] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceTypeWWAN] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkInterfaceTypeIPv4] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    return 1 ;
}

static int pushProtocolTypes(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [skin pushNSObject:(__bridge NSString *)kSCNetworkProtocolTypeAppleTalk] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
#pragma clang diagnostic pop
    [skin pushNSObject:(__bridge NSString *)kSCNetworkProtocolTypeDNS] ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkProtocolTypeIPv4] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkProtocolTypeIPv6] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkProtocolTypeProxies] ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kSCNetworkProtocolTypeSMB] ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    return 1 ;
}

#pragma mark - Lua<->CFObject Conversion Functions

static int pushSCNetworkInterface(lua_State *L, SCNetworkInterfaceRef theInterface) {
    SCNetworkInterfaceRef* thePtr = lua_newuserdata(L, sizeof(SCNetworkInterfaceRef)) ;
    *thePtr = CFRetain(theInterface) ;

    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    SCNetworkInterfaceRef theInterface = get_cfobjectFromUserdata(SCNetworkInterfaceRef, L, 1) ;
    CFStringRef bsdName = SCNetworkInterfaceGetBSDName(theInterface) ;
    NSString *title = @"*unable to get bsdName property*" ;
    if (bsdName) {
        title = (__bridge NSString *)bsdName ;
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, theInterface]] ;
    if (bsdName) CFRelease(bsdName) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        SCNetworkInterfaceRef theRef1 = get_cfobjectFromUserdata(SCNetworkInterfaceRef, L, 1) ;
        SCNetworkInterfaceRef theRef2 = get_cfobjectFromUserdata(SCNetworkInterfaceRef, L, 2) ;
        lua_pushboolean(L, CFEqual(theRef1, theRef2)) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    SCNetworkInterfaceRef theInterface = get_cfobjectFromUserdata(SCNetworkInterfaceRef, L, 1) ;
    CFRelease(theInterface) ;
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"mpu",                  interfaceMPU},
    {"bsdName",              interfaceBSDName},
    {"hardwareAddress",      interfaceHardwareAddress},
    {"type",                 interfaceType},
    {"displayName",          interfaceDisplayName},
    {"subInterface",         interfaceSubInterface},
    {"supportedTypes",       interfaceSupportedTypes},
    {"supportedProtocols",   interfaceSupportedProtocols},
    {"configuration",        interfaceConfiguration},
    {"mediaOptions",         interfaceMediaOptions},
    {"extendedMediaOptions", interfaceExtendedMediaOptions},

    {"__tostring",           userdata_tostring},
    {"__eq",                 userdata_eq},
    {"__gc",                 userdata_gc},
    {NULL,                   NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"getInterfaces", getInterfaces},

    {NULL,            NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_scnetworkinterface_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    pushInterfaceTypes(L) ; lua_setfield(L, -2, "types") ;
    pushProtocolTypes(L) ;  lua_setfield(L, -2, "protocols") ;

    return 1;
}
