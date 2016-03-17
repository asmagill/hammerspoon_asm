#include "btle.h"

static int refTable   = LUA_NOREF;

#pragma mark - Characteristic Methods

static int characteristicUUID(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    BOOL raw = (lua_gettop(L) == 2) ? (BOOL)lua_toboolean(L, 2) : NO ;
    NSString *answer = [theCharacteristic.UUID UUIDString] ;
    if (!raw) {
        if (btleGattLookupTable != LUA_NOREF && btleRefTable != LUA_NOREF) {
            [skin pushLuaRef:btleRefTable ref:btleGattLookupTable] ;
            if (lua_getfield(L, -1, [answer UTF8String]) == LUA_TTABLE) {
                if (lua_getfield(L, -1, "name") == LUA_TSTRING) {
                    answer = [skin toNSObjectAtIndex:-1] ;
                }
                lua_pop(L, 1); // name field
            }
            lua_pop(L, 2); // UUID lookup and gattLookup Table
        }
    }
    [skin pushNSObject:answer] ;
    return 1 ;
}

static int characteristicService(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    [skin pushNSObject:theCharacteristic.service] ;
    return 1 ;
}

static int characteristicValue(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    [skin pushNSObject:theCharacteristic.value] ;
    return 1 ;
}

static int characteristicDescriptors(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    [skin pushNSObject:theCharacteristic.descriptors] ;
    return 1 ;
}

static int characteristicProperties(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    CBCharacteristicProperties properties = theCharacteristic.properties ;
    lua_newtable(L) ;
    lua_pushinteger(L, properties) ; lua_setfield(L, -2, "_raw") ;
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
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "authenticateSignedWrites") ;
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
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    lua_pushboolean(L, theCharacteristic.isNotifying) ;
    return 1 ;
}

static int characteristicIsBroadcasted(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    lua_pushboolean(L, theCharacteristic.isBroadcasted) ;
    return 1 ;
}

static int peripheralDiscoverDescriptorsForCharacteristic(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    CBPeripheral     *thePeripheral     = [[theCharacteristic service] peripheral] ;
    [thePeripheral discoverDescriptorsForCharacteristic:theCharacteristic] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int peripheralReadValueForCharacteristic(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    CBPeripheral     *thePeripheral     = [[theCharacteristic service] peripheral] ;
    [thePeripheral readValueForCharacteristic:theCharacteristic] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

// TODO: - (void)writeValue:(NSData *)data forCharacteristic:(CBCharacteristic *)characteristic type:(CBCharacteristicWriteType)type

static int peripheralSetNotifyForCharacteristic(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBOOLEAN, LS_TBREAK] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
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
    LuaSkin *skin = [LuaSkin shared] ;
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
    LuaSkin *skin = [LuaSkin shared] ;
    CBCharacteristic *obj = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    NSString *label = [[obj UUID] UUIDString] ; // default to the UUID itself
    if (btleGattLookupTable != LUA_NOREF && btleRefTable != LUA_NOREF) {
        [skin pushLuaRef:btleRefTable ref:btleGattLookupTable] ;
        if (lua_getfield(L, -1, [label UTF8String]) == LUA_TTABLE) {
            if (lua_getfield(L, -1, "name") == LUA_TSTRING) {
                label = [skin toNSObjectAtIndex:-1] ;
            }
            lua_pop(L, 1); // name field
        }
        lua_pop(L, 2); // UUID lookup and gattLookup Table
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_CHARACTERISTIC_TAG,
                                                                  label,
                                                                  lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    LuaSkin *skin = [LuaSkin shared] ;
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
    {"isBroadcasted",       characteristicIsBroadcasted},

    {"discoverDescriptors", peripheralDiscoverDescriptorsForCharacteristic},
    {"readValue",           peripheralReadValueForCharacteristic},
    {"watch",               peripheralSetNotifyForCharacteristic},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

int luaopen_hs__asm_btle_characteristic(__unused lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:UD_CHARACTERISTIC_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:characteristic_metaLib];

    [skin registerPushNSHelper:pushCBCharacteristicAsUD       forClass:"CBCharacteristic"] ;
    [skin registerLuaObjectHelper:toCBCharacteristicFromLuaUD forClass:"CBCharacteristic"];

    return 1;
}
