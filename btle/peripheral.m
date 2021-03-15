@import Cocoa;
@import LuaSkin;
@import CoreBluetooth;

static const char * const UD_PERIPHERAL_TAG = "hs._asm.btle.peripheral" ;
static LSRefTable refTable = LUA_NOREF;

/// === hs._asm.btle.peripheral ===
///
/// Provides support for objects which represent remote BTLE peripheral devices that have been discovered or can be connected to.
///
///  Peripherals are identified by universally unique identifiers (UUIDs) and may contain one or more services or provide useful information about their connected signal strength.

#define get_objectFromUserdata(objType, L, idx, TAG) (objType*)*((void**)luaL_checkudata(L, idx, TAG))

#pragma mark - Peripheral Methods

static int peripheralIdentifier(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [skin pushNSObject:[thePeripheral.identifier UUIDString]] ;
    return 1 ;
}

static int peripheralName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [skin pushNSObject:thePeripheral.name] ;
    return 1 ;
}

static int peripheralServices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [skin pushNSObject:thePeripheral.services] ;
    return 1 ;
}

//FIXME: currently searches for all -- add support for limiting by CBService array
static int peripheralDiscoverServices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [thePeripheral discoverServices:nil] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int peripheralState(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    CBPeripheralState theState = thePeripheral.state ;
    switch(theState) {
        case CBPeripheralStateDisconnected:  lua_pushstring(L, "disconnected") ; break ;
        case CBPeripheralStateConnecting:    lua_pushstring(L, "connecting") ; break ;
        case CBPeripheralStateConnected:     lua_pushstring(L, "connected") ; break ;
        case CBPeripheralStateDisconnecting: lua_pushstring(L, "disconnecting") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized state: %ld", theState]] ;
            break ;
    }
    return 1 ;
}

static int peripheralReadRSSI(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [thePeripheral readRSSI] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.btle.peripheral:maximumWriteSize([withResponse]) -> integer
/// Method
/// Returns the maximum amount of data, in bytes, that can be sent to a characteristic in a single write. (Only valid in macOS 10.12 and later)
///
/// Parameters:
///  * withResponse - an optional boolean, default false, indicating whether or not the write will be performed as expecting a response (true) or without expecting a response (false).
///
/// Returns:
///  * an integer specifying the maximum byte size for the data to be written.
///
/// Notes:
///  * this method is only supported for macOS 10.12 and later; for earlier macOS versions, this method will return -1.
static int peripheralMaximumWriteValueLength(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    CBCharacteristicWriteType writeType = (lua_gettop(L) == 2 && lua_toboolean(L, 2)) ? CBCharacteristicWriteWithResponse : CBCharacteristicWriteWithoutResponse ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
    if ([thePeripheral respondsToSelector:@selector(maximumWriteValueLengthForType:)]) {
        lua_pushinteger(L, (lua_Integer)[thePeripheral maximumWriteValueLengthForType:writeType]) ;
    } else {
        lua_pushinteger(L, -1) ;
    }
#pragma clang diagnostic pop

    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushCBPeripheralAsUD(lua_State *L, id obj) {
    CBPeripheral *theCBPeripheral = obj ;
    void** peripheralPtr = lua_newuserdata(L, sizeof(CBPeripheral *)) ;
    *peripheralPtr = (__bridge_retained void *)theCBPeripheral ;

    luaL_getmetatable(L, UD_PERIPHERAL_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static id toCBPeripheralFromLuaUD(lua_State *L, int idx) {
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

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    CBPeripheral *obj = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_PERIPHERAL_TAG,
                                                                  [obj name],
                                                                  lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if (luaL_testudata(L, 1, UD_PERIPHERAL_TAG) && luaL_testudata(L, 2, UD_PERIPHERAL_TAG)) {
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
    if (obj) obj = nil ; // delegate is weak, so we don't run into the problem of a userdata needing to clear it
                         // while another userdata for the same object might still be hangning around somewhere.

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {NULL,  NULL}
};

// static int meta_gc(lua_State* L) {
//     return 0 ;
// }

// // Metatable for userdata objects
static const luaL_Reg peripheral_metaLib[] = {
    {"identifier",       peripheralIdentifier},
    {"name",             peripheralName},
    {"state",            peripheralState},
    {"maximumWriteSize", peripheralMaximumWriteValueLength},
    {"discoverServices", peripheralDiscoverServices},
    {"services",         peripheralServices},

    {"readRSSI",         peripheralReadRSSI},

    {"__tostring",       userdata_tostring},
    {"__eq",             userdata_eq},
    {"__gc",             userdata_gc},
    {NULL,               NULL}
};

int luaopen_hs__asm_btle_peripheral(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:UD_PERIPHERAL_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:peripheral_metaLib];

    [skin registerPushNSHelper:pushCBPeripheralAsUD           forClass:"CBPeripheral"] ;
    [skin registerLuaObjectHelper:toCBPeripheralFromLuaUD     forClass:"CBPeripheral"];

    return 1;
}
