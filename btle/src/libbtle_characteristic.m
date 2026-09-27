@import Cocoa ;
@import LuaSkin ;
@import CoreBluetooth;

#import "libbtle.h"

static LSRefTable refTable = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

static NSMapTable *characteristic_internals ;

@interface CBCharacteristic (HammerspoonAdditions2)
@property (nonatomic) int selfRefCount ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation CBCharacteristic (HammerspoonAdditions)

- (void)setCallbackRef:(int)value {
    NSMutableDictionary *internals = [characteristic_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [characteristic_internals setObject:internals forKey:self] ;
    }
    internals[@"callback"] = @(value) ;
}

- (int)callbackRef {
    NSMutableDictionary *internals = [characteristic_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [characteristic_internals setObject:internals forKey:self] ;
    }
    NSNumber *value = internals[@"callback"] ;
    return value.intValue ;
}

- (void)setSelfRefCount:(int)value {
    NSMutableDictionary *internals = [characteristic_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [characteristic_internals setObject:internals forKey:self] ;
    }
    internals[@"selfRef"] = @(value) ;
}

- (int)selfRefCount {
    NSMutableDictionary *internals = [characteristic_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [characteristic_internals setObject:internals forKey:self] ;
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

static int characteristic_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    CBCharacteristic *characteristic = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        characteristic.callbackRef = [skin luaUnref:refTable ref:characteristic.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            characteristic.callbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (characteristic.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:characteristic.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int characteristic_service(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *characteristic = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:characteristic.service] ;
    return 1 ;
}

static int characteristic_value(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *characteristic = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:characteristic.value] ;
    return 1 ;
}

static int characteristic_descriptors(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *characteristic = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:characteristic.descriptors] ;
    return 1 ;
}

static int characteristic_properties(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *characteristic = [skin toNSObjectAtIndex:1] ;
    CBCharacteristicProperties properties = characteristic.properties ;
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

// static int characteristic_isNotifying(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
//     CBCharacteristic *characteristic = [skin toNSObjectAtIndex:1] ;
//     lua_pushboolean(L, characteristic.isNotifying) ;
//     return 1 ;
// }

static int characteristic_uuid(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *characteristic = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:characteristic.UUID.UUIDString] ;
    return 1 ;
}

static int peripheral_setNotifyValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    CBCharacteristic *characteristic = [skin toNSObjectAtIndex:1] ;
    CBPeripheral     *peripheral     = characteristic.service.peripheral ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, characteristic.isNotifying) ;
    } else {
        BOOL notify = (BOOL)(lua_toboolean(L, 2)) ;
        [peripheral setNotifyValue:notify forCharacteristic:characteristic] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int peripheral_discoverDescriptorsForCharacteristic(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *characteristic = [skin toNSObjectAtIndex:1] ;
    CBPeripheral     *peripheral     = characteristic.service.peripheral ;
    [peripheral discoverDescriptorsForCharacteristic:characteristic] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int peripheral_writeValueForCharacteristic(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    CBCharacteristic          *characteristic = [skin toNSObjectAtIndex:1] ;
    CBPeripheral              *peripheral     = characteristic.service.peripheral ;
    NSData                    *data           = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] ;
    BOOL                      withResponse    = (lua_gettop(L) > 2) ? (BOOL)(lua_toboolean(L, 3)) : YES ;
    CBCharacteristicWriteType writeType       = withResponse ? CBCharacteristicWriteWithResponse :
                                                               CBCharacteristicWriteWithoutResponse ;

    [peripheral writeValue:data forCharacteristic:characteristic type:writeType] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int peripheral_readValueForCharacteristic(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *characteristic = [skin toNSObjectAtIndex:1] ;
    CBPeripheral     *peripheral     = characteristic.service.peripheral ;
    [peripheral readValueForCharacteristic:characteristic] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushCBCharacteristic(lua_State *L, id obj) {
    CBCharacteristic *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(CBCharacteristic *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_CHARACTERISTIC_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toCBCharacteristicFromLua(lua_State *L, int idx) {
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

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    CBCharacteristic *obj = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    NSString *title = obj.UUID.UUIDString ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_CHARACTERISTIC_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, UD_CHARACTERISTIC_TAG) && luaL_testudata(L, 2, UD_CHARACTERISTIC_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin     = [LuaSkin sharedWithState:L] ;
            obj.callbackRef   = [skin luaUnref:refTable ref:obj.callbackRef] ;
            [characteristic_internals removeObjectForKey:obj] ;
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
    {"callback",            characteristic_callback},
    {"service",             characteristic_service},
    {"value",               characteristic_value},
    {"descriptors",         characteristic_descriptors},
    {"properties",          characteristic_properties},
//     {"notifying",           characteristic_isNotifying},
    {"uuid",                characteristic_uuid},

    {"notify",              peripheral_setNotifyValue},
    {"discoverDescriptors", peripheral_discoverDescriptorsForCharacteristic},
    {"writeValue",          peripheral_writeValueForCharacteristic},
    {"readValue",           peripheral_readValueForCharacteristic},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
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

int luaopen_hs__asm_libbtle_characteristic(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:UD_CHARACTERISTIC_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushCBCharacteristic         forClass:"CBCharacteristic"];
    [skin registerLuaObjectHelper:toCBCharacteristicFromLua forClass:"CBCharacteristic"
                                                 withUserdataMapping:UD_CHARACTERISTIC_TAG];

    characteristic_internals = [NSMapTable weakToStrongObjectsMapTable] ;

    return 1;
}
