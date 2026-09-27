@import Cocoa ;
@import LuaSkin ;
@import CoreBluetooth;

#import "libbtle.h"

/// === hs._asm.btle.peripheral ===
///
/// Provides support for objects which represent remote BTLE peripheral devices that have been discovered or can be connected to.
///
///  Peripherals are identified by universally unique identifiers (UUIDs) and may contain one or more services or provide useful information about their connected signal strength.

static LSRefTable refTable = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

static NSMapTable *peripheral_internals ;

@interface CBPeripheral (HammerspoonAdditions2)
@property (nonatomic) int selfRefCount ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation CBPeripheral (HammerspoonAdditions)

- (void)setCallbackRef:(int)value {
    NSMutableDictionary *internals = [peripheral_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [peripheral_internals setObject:internals forKey:self] ;
    }
    internals[@"callback"] = @(value) ;
}

- (int)callbackRef {
    NSMutableDictionary *internals = [peripheral_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [peripheral_internals setObject:internals forKey:self] ;
    }
    NSNumber *value = internals[@"callback"] ;
    return value.intValue ;
}

- (void)setSelfRefCount:(int)value {
    NSMutableDictionary *internals = [peripheral_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [peripheral_internals setObject:internals forKey:self] ;
    }
    internals[@"selfRef"] = @(value) ;
}

- (int)selfRefCount {
    NSMutableDictionary *internals = [peripheral_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [peripheral_internals setObject:internals forKey:self] ;
    }
    NSNumber *value = internals[@"selfRef"] ;
    return value.intValue ;
}

- (int)refTable {
    return refTable ;
}

@end

#pragma mark - Module Functions -

#pragma mark - Module Methods -

static int peripheral_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    CBPeripheral *peripheral = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        peripheral.callbackRef = [skin luaUnref:refTable ref:peripheral.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            peripheral.callbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (peripheral.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:peripheral.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int peripheral_manager(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *peripheral = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:peripheral.delegate] ;
    return 1 ;
}

static int peripheral_canSendWriteWithoutResponse(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *peripheral = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, peripheral.canSendWriteWithoutResponse) ;
    return 1 ;
}

static int peripheral_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *peripheral = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:peripheral.name] ;
    return 1 ;
}

static int peripheral_identifier(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *peripheral = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:peripheral.identifier.UUIDString] ;
    return 1 ;
}

static int peripheral_state(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *peripheral = [skin toNSObjectAtIndex:1] ;
    CBPeripheralState state = peripheral.state ;
    switch(state) {
        case CBPeripheralStateConnected:     lua_pushstring(L, "connected") ;     break ;
        case CBPeripheralStateConnecting:    lua_pushstring(L, "connecting") ;    break ;
        case CBPeripheralStateDisconnected:  lua_pushstring(L, "disconnected") ;  break ;
        case CBPeripheralStateDisconnecting: lua_pushstring(L, "disconnecting") ; break ;
        default:
            lua_pushfstring(L, "unrecognized state: %I", state) ;
    }
    return 1 ;
}

static int peripheral_services(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *peripheral = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:peripheral.services] ;
    return 1 ;
}

static int peripheral_maximumWriteValueLengthForType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    CBPeripheral              *peripheral  = [skin toNSObjectAtIndex:1] ;
    BOOL                      withResponse = (lua_gettop(L) > 1) ? (BOOL)(lua_toboolean(L, 2)) : NO ;
    CBCharacteristicWriteType writeType    = withResponse ? CBCharacteristicWriteWithResponse :
                                                            CBCharacteristicWriteWithoutResponse ;

    lua_pushinteger(L, (lua_Integer)[peripheral maximumWriteValueLengthForType:writeType]) ;
    return 1 ;
}

static int peripheral_discoverServices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TSTRING | LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    CBPeripheral *peripheral = [skin toNSObjectAtIndex:1] ;

    NSArray *servicesList = nil ;
    if (lua_gettop(L) == 2) {
        NSArray *list  = [skin toNSObjectAtIndex:2] ;
        NSError *error = nil ;
        servicesList   = validateAndConvertUUIDs(list, YES, &error) ;

        if (error) return luaL_argerror(L, 2, error.localizedDescription.UTF8String) ;
    }

    [peripheral discoverServices:servicesList] ;
    lua_pushvalue(L, 1);
    return 1;
}

static int peripheral_readRSSI(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *peripheral = [skin toNSObjectAtIndex:1] ;
    [peripheral readRSSI] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

// - (void) openL2CAPChannel:(CBL2CAPPSM) PSM;

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushCBPeripheral(lua_State *L, id obj) {
    CBPeripheral *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(CBPeripheral *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_PERIPHERAL_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toCBPeripheralFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    CBPeripheral *value ;
    if (luaL_testudata(L, idx, UD_PERIPHERAL_TAG)) {
        value = get_objectFromUserdata(__bridge CBPeripheral, L, idx, UD_PERIPHERAL_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_PERIPHERAL_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    CBPeripheral *obj = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    NSString *title = obj.name ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_PERIPHERAL_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, UD_PERIPHERAL_TAG) && luaL_testudata(L, 2, UD_PERIPHERAL_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        CBPeripheral *obj1 = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
        CBPeripheral *obj2 = [skin luaObjectAtIndex:2 toClass:"CBPeripheral"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    CBPeripheral *obj = get_objectFromUserdata(__bridge_transfer CBPeripheral, L, 1, UD_PERIPHERAL_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin     = [LuaSkin sharedWithState:L] ;
            obj.callbackRef   = [skin luaUnref:refTable ref:obj.callbackRef] ;
            [peripheral_internals removeObjectForKey:obj] ;
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
    {"callback",                peripheral_callback},
    {"manager",                 peripheral_manager},

    {"canWriteWithoutResponse", peripheral_canSendWriteWithoutResponse},
    {"name",                    peripheral_name},
    {"identifier",              peripheral_identifier},
    {"state",                   peripheral_state},
    {"services",                peripheral_services},

    {"writeLength",             peripheral_maximumWriteValueLengthForType},
    {"discoverServices",        peripheral_discoverServices},
    {"readRSSI",                peripheral_readRSSI},

    {"__tostring",              userdata_tostring},
    {"__eq",                    userdata_eq},
    {"__gc",                    userdata_gc},
    {NULL,                      NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_libbtle_peripheral(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:UD_PERIPHERAL_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushCBPeripheral         forClass:"CBPeripheral"];
    [skin registerLuaObjectHelper:toCBPeripheralFromLua forClass:"CBPeripheral"
                                             withUserdataMapping:UD_PERIPHERAL_TAG];

    peripheral_internals = [NSMapTable weakToStrongObjectsMapTable] ;

    return 1;
}
