@import Cocoa;
@import LuaSkin;
@import CoreBluetooth;

/// === hs._asm.btle.characteristic ===
///
/// Provides support for objects which represent the characteristics of a remote BTLE peripheral’s service.
///
/// A characteristic contains a single value and any number of descriptors describing that value. The properties of a characteristic determine how the value of the characteristic can be used and how the descriptors can be accessed.

static const char * const UD_CHARACTERISTIC_TAG = "hs._asm.btle.characteristic" ;
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, TAG) (objType*)*((void**)luaL_checkudata(L, idx, TAG))

#pragma mark - Characteristic Methods

static int characteristicUUID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    NSString *answer = [theCharacteristic.UUID UUIDString] ;
    [skin pushNSObject:answer] ;
    return 1 ;
}

static int characteristicService(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    [skin pushNSObject:theCharacteristic.service] ;
    return 1 ;
}

static int characteristicValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    [skin pushNSObject:theCharacteristic.value] ;
    return 1 ;
}

static int characteristicDescriptors(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    [skin pushNSObject:theCharacteristic.descriptors] ;
    return 1 ;
}

static int characteristicProperties(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    CBCharacteristicProperties properties = theCharacteristic.properties ;
    lua_newtable(L) ;
    lua_pushinteger(L, (lua_Integer)properties) ; lua_setfield(L, -2, "_raw") ;
    if (properties & CBCharacteristicPropertyBroadcast) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "broadcast") ;
    }
    if (properties & CBCharacteristicPropertyRead) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "read") ;
    }
    if (properties & CBCharacteristicPropertyWriteWithoutResponse) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "writeWithoutResponse") ;
    }
    if (properties & CBCharacteristicPropertyWrite) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "write") ;
    }
    if (properties & CBCharacteristicPropertyNotify) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "notify") ;
    }
    if (properties & CBCharacteristicPropertyIndicate) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "indicate") ;
    }
    if (properties & CBCharacteristicPropertyAuthenticatedSignedWrites) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "authenticatedSignedWrites") ;
    }
    if (properties & CBCharacteristicPropertyExtendedProperties) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "extendedProperties") ;
    }
    if (properties & CBCharacteristicPropertyNotifyEncryptionRequired) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "notifyEncryptionRequired") ;
    }
    if (properties & CBCharacteristicPropertyIndicateEncryptionRequired) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "indicateEncryptionRequired") ;
    }
    return 1 ;
}

static int characteristicIsNotifying(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    lua_pushboolean(L, theCharacteristic.isNotifying) ;
    return 1 ;
}

static int peripheralDiscoverDescriptorsForCharacteristic(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    CBPeripheral     *thePeripheral     = [[theCharacteristic service] peripheral] ;
    [thePeripheral discoverDescriptorsForCharacteristic:theCharacteristic] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int peripheralReadValueForCharacteristic(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    CBPeripheral     *thePeripheral     = [[theCharacteristic service] peripheral] ;
    [thePeripheral readValueForCharacteristic:theCharacteristic] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int peripheralWriteValueForCharacteristic(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    CBPeripheral     *thePeripheral     = [[theCharacteristic service] peripheral] ;
    NSData           *theData           = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] ;
    CBCharacteristicWriteType writeType = (lua_gettop(L) == 3 && lua_toboolean(L, 3)) ? CBCharacteristicWriteWithResponse : CBCharacteristicWriteWithoutResponse ;
    [thePeripheral writeValue:theData forCharacteristic:theCharacteristic type:writeType] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int peripheralSetNotifyForCharacteristic(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBOOLEAN, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    CBPeripheral     *thePeripheral     = [[theCharacteristic service] peripheral] ;
    [thePeripheral setNotifyValue:(BOOL)lua_toboolean(L, 2) forCharacteristic:theCharacteristic] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushCBCharacteristicAsUD(lua_State *L, id obj) {
    CBCharacteristic *theCBCharacteristic = obj ;
    void** characteristicPtr = lua_newuserdata(L, sizeof(CBCharacteristic *)) ;
    *characteristicPtr = (__bridge_retained void *)theCBCharacteristic ;

    luaL_getmetatable(L, UD_CHARACTERISTIC_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static id toCBCharacteristicFromLuaUD(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    CBCharacteristic *value ;
    if (luaL_testudata(L, idx, UD_CHARACTERISTIC_TAG)) {
        value = get_objectFromUserdata(__bridge CBCharacteristic, L, idx, UD_CHARACTERISTIC_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_CHARACTERISTIC_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    CBCharacteristic *obj = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    NSString *label = [[obj UUID] UUIDString] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_CHARACTERISTIC_TAG,
                                                                  label,
                                                                  lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if (luaL_testudata(L, 1, UD_CHARACTERISTIC_TAG) && luaL_testudata(L, 2, UD_CHARACTERISTIC_TAG)) {
        CBCharacteristic *obj1 = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
        CBCharacteristic *obj2 = [skin luaObjectAtIndex:2 toClass:"CBCharacteristic"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    CBCharacteristic *obj = get_objectFromUserdata(__bridge_transfer CBCharacteristic, L, 1, UD_CHARACTERISTIC_TAG) ;
    if (obj) obj = nil ;

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
static const luaL_Reg characteristic_metaLib[] = {
    {"UUID",                characteristicUUID},
    {"service",             characteristicService},
    {"value",               characteristicValue},
    {"descriptors",         characteristicDescriptors},
    {"properties",          characteristicProperties},
    {"isNotifying",         characteristicIsNotifying},

    {"discoverDescriptors", peripheralDiscoverDescriptorsForCharacteristic},
    {"readValue",           peripheralReadValueForCharacteristic},
    {"writeValue",          peripheralWriteValueForCharacteristic},
    {"watch",               peripheralSetNotifyForCharacteristic},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

int luaopen_hs__asm_btle_characteristic(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:UD_CHARACTERISTIC_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:characteristic_metaLib];

    [skin registerPushNSHelper:pushCBCharacteristicAsUD       forClass:"CBCharacteristic"] ;
    [skin registerLuaObjectHelper:toCBCharacteristicFromLuaUD forClass:"CBCharacteristic"];

    return 1;
}
