@import Cocoa ;
@import LuaSkin ;

@import Darwin.POSIX.netdb ;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wauto-import"
#include "SimplePing.h"
#pragma clang diagnostic pop

#define USERDATA_TAG "hs.network.ping"
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#define ADDRESS_STYLES @{ \
    @"any"  : @(SimplePingAddressStyleAny), \
    @"IPv4" : @(SimplePingAddressStyleICMPv4), \
    @"IPv6" : @(SimplePingAddressStyleICMPv6), \
}

#pragma mark - Support Functions and Classes

static int pushParsedAddress(NSData *addressData) {
    LuaSkin *skin = [LuaSkin shared] ;
    int  err;
    char addrStr[NI_MAXHOST];
    err = getnameinfo([addressData bytes], (unsigned int)[addressData length], addrStr, sizeof(addrStr), NULL, 0, NI_NUMERICHOST | NI_WITHSCOPEID | NI_NUMERICSERV);
    if (err == 0) {
        [skin pushNSObject:[NSString stringWithFormat:@"%s", addrStr]] ;
    } else {
        [skin pushNSObject:[NSString stringWithFormat:@"** address parse error:%s **", gai_strerror(err)]] ;
    }
    return 1;
}

static int pushParsedICMPPayload(NSData *payloadData) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_State *L = [skin L] ;
    size_t packetLength = [payloadData length] ;

    lua_newtable(L) ;
    size_t headerSize = sizeof(ICMPHeader) ;
    if (packetLength >= headerSize) {
        ICMPHeader payloadHeader ;
        [payloadData getBytes:&payloadHeader length:headerSize] ;
        lua_pushinteger(L, payloadHeader.type) ;           lua_setfield(L, -2, "type") ;
        lua_pushinteger(L, payloadHeader.code) ;           lua_setfield(L, -2, "code") ;
        lua_pushinteger(L, OSSwapHostToBigInt16(payloadHeader.checksum)) ;
        lua_setfield(L, -2, "checksum") ;
        lua_pushinteger(L, OSSwapHostToBigInt16(payloadHeader.identifier)) ;
        lua_setfield(L, -2, "identifier") ;
        lua_pushinteger(L, OSSwapHostToBigInt16(payloadHeader.sequenceNumber)) ;
        lua_setfield(L, -2, "sequenceNumber") ;
        if (packetLength > headerSize) {
            [skin pushNSObject:[payloadData subdataWithRange:NSMakeRange(headerSize, packetLength - headerSize)]] ;
            lua_setfield(L, -2, "payload") ;
        }
    } else {
        [skin logDebug:[NSString stringWithFormat:@"malformed ICMP data:%@", payloadData]] ;
        lua_pushstring(L, "ICMP header is too short -- malformed ICMP packet") ;
        lua_setfield(L, -2, "error") ;
    }
    [skin pushNSObject:payloadData] ;
    lua_setfield(L, -2, "_raw") ;

    return 1 ;
}

@interface PingableObject : SimplePing <SimplePingDelegate>
@property int  callbackRef ;
@property int  selfRef ;
@end

@implementation PingableObject

- (instancetype)initWithHostName:(NSString *)hostName {
    if (!hostName) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:initWithHostName, hostname cannot be nil", USERDATA_TAG]] ;
        return nil ;
    }

    self = [super initWithHostName:hostName] ;
    if (self) {
        _callbackRef  = LUA_NOREF ;
        _selfRef      = LUA_NOREF ;

        self.delegate = self ;
    }
    return self ;
}

#pragma mark * SimplePingDelegate Methods

- (void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:pinger] ;
        [skin pushNSObject:@"didStart"] ;
        pushParsedAddress(address) ;
        if (![skin protectedCallAndTraceback:3 nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:didStartWithAddress callback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    }
}

- (void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error {
    LuaSkin *skin = [LuaSkin shared] ;
    NSString *errorReason = [error localizedDescription] ;
    [skin logWarn:[NSString stringWithFormat:@"%s:didFailWithError pinger stopped, %@.", USERDATA_TAG, errorReason]] ;
    if (_callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:pinger] ;
        [skin pushNSObject:@"didFail"] ;
        [skin pushNSObject:errorReason] ;
        if (![skin protectedCallAndTraceback:3 nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:didFailWithError callback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    }

    // by the time this method is invoked, SimplePing has already stopped us, so let's make sure
    // we reflect that.
    _selfRef = [skin luaUnref:refTable ref:_selfRef] ;
}

- (void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet
                                       sequenceNumber:(uint16_t)sequenceNumber {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:pinger] ;
        [skin pushNSObject:@"sendPacket"] ;
        pushParsedICMPPayload(packet) ;
        lua_pushinteger([skin L], sequenceNumber) ;
        if (![skin protectedCallAndTraceback:4 nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:didSendPacket callback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    }
}

- (void)simplePing:(SimplePing *)pinger didFailToSendPacket:(NSData *)packet
                                             sequenceNumber:(uint16_t)sequenceNumber
                                                      error:(NSError *)error {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:pinger] ;
        [skin pushNSObject:@"sendPacketFailed"] ;
        pushParsedICMPPayload(packet) ;
        lua_pushinteger([skin L], sequenceNumber) ;
        [skin pushNSObject:[error localizedDescription]] ;
        if (![skin protectedCallAndTraceback:5 nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:didFailToSendPacket callback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    }
}

- (void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet
                                                      sequenceNumber:(uint16_t)sequenceNumber {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:pinger] ;
        [skin pushNSObject:@"receivedPacket"] ;
        pushParsedICMPPayload(packet) ;
        lua_pushinteger([skin L], sequenceNumber) ;
        if (![skin protectedCallAndTraceback:4 nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:didReceivePingResponsePacket callback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    }
}

- (void)simplePing:(SimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet {
    BOOL notifyCallback = YES ;

    size_t packetLength = [packet length] ;
    size_t headerSize   = sizeof(ICMPHeader) ;
    if (packetLength >= headerSize) {
        ICMPHeader payloadHeader ;
        [packet getBytes:&payloadHeader length:headerSize] ;
        if (OSSwapHostToBigInt16(payloadHeader.identifier) != self.identifier) notifyCallback = NO ;
      /*

        Until we want to try parsing and understanding ICMPv6 neighbor solicitation and advertising
        protocols, let's just ignore any packet that doesn't have our identifier... because if it
        does and we still got here, then either the network is in need of diagnostics due to data
        corruption, or someone is trying to do something funny on the network... or we just got
        unlucky and our identifier got reused on the same network -- there are only 65536
        possibilities after all...

        Note that we're also invoking the callback when the header is so mangled we can't get an
        identifier... that also suggests data corruption or malfeasance afoot.

    */
    }

    if (notifyCallback && _callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:pinger] ;
        [skin pushNSObject:@"receivedUnexpectedPacket"] ;
        pushParsedICMPPayload(packet) ;
        if (![skin protectedCallAndTraceback:3 nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:didReceiveUnexpectedPacket callback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    }
}

@end

#pragma mark - Module Functions

static int ping_new(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    PingableObject *pinger = [[PingableObject alloc] initWithHostName:[skin toNSObjectAtIndex:1]] ;
    [skin pushNSObject:pinger] ;
    return 1 ;
}

#pragma mark - Module Methods

static int ping_setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;

    // We're either removing a callback, or setting a new one. Either way, remove existing.
    pinger.callbackRef = [skin luaUnref:refTable ref:pinger.callbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        pinger.callbackRef = [skin luaRef:refTable] ;
    }
    lua_pushvalue(L, 1);
    return 1;
}

static int ping_hostName(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:pinger.hostName] ;
    return 1 ;
}

static int ping_identifier(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, pinger.identifier) ;
    return 1 ;
}

static int ping_nextSequenceNumber(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, pinger.nextSequenceNumber) ;
    return 1 ;
}

static int ping_addressStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *addressStyle = @(pinger.addressStyle) ;
        NSArray *temp = [ADDRESS_STYLES allKeysForObject:addressStyle];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logError:[NSString stringWithFormat:@"%s:unrecognized address style %@ -- notify developers", USERDATA_TAG, addressStyle]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *addressStyle = ADDRESS_STYLES[key] ;
        if (addressStyle) {
            pinger.addressStyle = [addressStyle integerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[ADDRESS_STYLES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int ping_start(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;

    if (pinger.selfRef != LUA_NOREF) {
        [skin logDebug:[NSString stringWithFormat:@"%s:start - pinger already started, ignoring.", USERDATA_TAG]] ;
    } else {
        [pinger start] ;

        // assign a self ref to keep __gc from stopping us inadvertantly
        lua_pushvalue(L, 1) ;
        pinger.selfRef = [skin luaRef:refTable] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int ping_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;

    if (pinger.selfRef != LUA_NOREF) {
        [pinger stop] ;

        // we no longer need a self ref to keep __gc from stopping us inadvertantly
        pinger.selfRef = [skin luaUnref:refTable ref:pinger.selfRef] ;
    } else {
        [skin logDebug:[NSString stringWithFormat:@"%s:stop - pinger has not been started, ignoring.", USERDATA_TAG]] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int ping_isRunning(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;

    // we only have a self ref when we've been started
    lua_pushboolean(L, (pinger.selfRef != LUA_NOREF)) ;
    return 1 ;
}

static int ping_hostAddress(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;
    if (pinger.hostAddress) {
        pushParsedAddress(pinger.hostAddress) ;
    } else {
        [skin logDebug:[NSString stringWithFormat:@"%s:hostAddress - %@", USERDATA_TAG,
            ((pinger.selfRef != LUA_NOREF) ? @"address resolution has not completed yet"
                                           : @"pinger is not running")]] ;
        lua_pushboolean(L, (pinger.selfRef != LUA_NOREF)) ;
    }
    return 1 ;
}

static int ping_sendPayload(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;
    NSData *payload = (lua_gettop(L) == 2) ?
        [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] : nil ;

    if (!payload) {
        payload = [[NSString stringWithFormat:@"Hammerspoon %s payload.%*s0x%04x 0x%04x", USERDATA_TAG, (int)(56 - 34 - strlen(USERDATA_TAG)), " ", pinger.identifier, pinger.nextSequenceNumber] dataUsingEncoding:NSASCIIStringEncoding] ;
    }

    if (pinger.hostAddress) {
        [pinger sendPingWithData:payload] ;
        lua_pushvalue(L, 1) ;
    } else {
        [skin logDebug:[NSString stringWithFormat:@"%s:sendPayload - %@", USERDATA_TAG,
            ((pinger.selfRef != LUA_NOREF) ? @"address resolution has not completed yet"
                                           : @"pinger is not running")]] ;
        lua_pushboolean(L, (pinger.selfRef != LUA_NOREF)) ;
    }
    return 1 ;
}

static int ping_addressFamily(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;

    switch (pinger.hostAddressFamily) {
        case AF_INET:
            [skin pushNSObject:@"IPv4"] ;
            break ;
        case AF_INET6:
            [skin pushNSObject:@"IPv4"] ;
            break ;
        case AF_UNSPEC:
            [skin pushNSObject:@"unresolved"] ;
            break ;
        default:
            [skin logError:[NSString stringWithFormat:@"%s:unrecognized address family %d -- notify developers", USERDATA_TAG, pinger.hostAddressFamily]] ;
            lua_pushnil(L) ;
            break ;
    }
    return 1 ;
}

// @property (nonatomic, assign, readonly) sa_family_t hostAddressFamily;

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushPingableObject(lua_State *L, id obj) {
    PingableObject *value = obj;

    // honor selfRef if it's been assigned
    if (value.selfRef != LUA_NOREF) {
        [[LuaSkin shared] pushLuaRef:refTable ref:value.selfRef] ;

    // otherwise, treat this like any other NSObject -> lua userdata
    } else {
        void** valuePtr = lua_newuserdata(L, sizeof(PingableObject *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
    }
    return 1;
}

id toPingableObjectFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    PingableObject *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge PingableObject, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    PingableObject *obj = [skin luaObjectAtIndex:1 toClass:"PingableObject"] ;
    NSString *title = obj.hostName ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        PingableObject *obj1 = [skin luaObjectAtIndex:1 toClass:"PingableObject"] ;
        PingableObject *obj2 = [skin luaObjectAtIndex:2 toClass:"PingableObject"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    PingableObject *obj = get_objectFromUserdata(__bridge_transfer PingableObject, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;

        // because the self ref means we have a reference in the registry, the only way we should ever
        // actually have to do this is during a reload/quit... and even then, it's not guaranteed
        // depending upon purge ordering and possible object resurrection, but lets be "correct" if we can
        if (obj.selfRef != LUA_NOREF) {
            [obj stop] ;
            obj.selfRef = [skin luaUnref:refTable ref:obj.selfRef] ;
        }
        obj = nil ;
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"hostName",            ping_hostName},
    {"identifier",          ping_identifier},
    {"nextSequenceNumber",  ping_nextSequenceNumber},
    {"setCallback",         ping_setCallback},
    {"acceptAddressFamily", ping_addressStyle},
    {"start",               ping_start},
    {"stop",                ping_stop},
    {"isRunning",           ping_isRunning},
    {"hostAddress",         ping_hostAddress},
    {"hostAddressFamily",   ping_addressFamily},
    {"sendPayload",         ping_sendPayload},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", ping_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_network_ping_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushPingableObject         forClass:"PingableObject"];
    [skin registerLuaObjectHelper:toPingableObjectFromLua forClass:"PingableObject"
                                             withUserdataMapping:USERDATA_TAG];

    return 1;
}
