@import Cocoa;
@import LuaSkin;
@import CoreBluetooth;

/// === hs._asm.btle.service ===
///
/// Provides support for objects which represent a BTLE peripheral’s service — a collection of data and associated behaviors for accomplishing a function or feature of a device (or portions of that device).
///
/// Services are either primary or secondary and may contain a number of characteristics or included services (references to other services).

static const char * const UD_SERVICE_TAG = "hs._asm.btle.service" ;
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, TAG) (objType*)*((void**)luaL_checkudata(L, idx, TAG))

#pragma mark - Service Methods

static int serviceUUID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *theService = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    NSString *answer = [theService.UUID UUIDString] ;
    [skin pushNSObject:answer] ;
    return 1 ;
}

static int servicePeripheral(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *theService = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    [skin pushNSObject:theService.peripheral] ;
    return 1 ;
}

static int serviceCharacteristics(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *theService = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    [skin pushNSObject:theService.characteristics] ;
    return 1 ;
}

static int serviceIncludedServices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *theService = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    [skin pushNSObject:theService.includedServices] ;
    return 1 ;
}

static int servicePrimary(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *theService = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    lua_pushboolean(L, theService.isPrimary) ;
    return 1 ;
}

//FIXME: currently searches for all -- add support for limiting by CBService array
static int peripheralDiscoverIncludedServices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService    *theService    = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    CBPeripheral *thePeripheral = [theService peripheral] ;
    [thePeripheral discoverIncludedServices:nil forService:theService] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

//FIXME: currently searches for all -- add support for limiting by CBCharacteristic array
static int peripheralDiscoverCharacteristicsForService(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService    *theService    = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    CBPeripheral *thePeripheral = [theService peripheral] ;
    [thePeripheral discoverCharacteristics:nil forService:theService] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushCBServiceAsUD(lua_State *L, id obj) {
    CBService *theCBService = obj ;
    void** servicePtr = lua_newuserdata(L, sizeof(CBService *)) ;
    *servicePtr = (__bridge_retained void *)theCBService ;

    luaL_getmetatable(L, UD_SERVICE_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static id toCBServiceFromLuaUD(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    CBService *value ;
    if (luaL_testudata(L, idx, UD_SERVICE_TAG)) {
        value = get_objectFromUserdata(__bridge CBService, L, idx, UD_SERVICE_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_SERVICE_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    CBService *obj = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    NSString *label = [[obj UUID] UUIDString] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_SERVICE_TAG,
                                                                  label,
                                                                  lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if (luaL_testudata(L, 1, UD_SERVICE_TAG) && luaL_testudata(L, 2, UD_SERVICE_TAG)) {
        CBService *obj1 = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
        CBService *obj2 = [skin luaObjectAtIndex:2 toClass:"CBService"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    CBService *obj = get_objectFromUserdata(__bridge_transfer CBService, L, 1, UD_SERVICE_TAG) ;
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
static const luaL_Reg service_metaLib[] = {
    {"UUID",                     serviceUUID},
    {"peripheral",               servicePeripheral},
    {"primary",                  servicePrimary},

    {"discoverIncludedServices", peripheralDiscoverIncludedServices},
    {"includedServices",         serviceIncludedServices},
    {"discoverCharacteristics",  peripheralDiscoverCharacteristicsForService},
    {"characteristics",          serviceCharacteristics},

    {"__tostring",               userdata_tostring},
    {"__eq",                     userdata_eq},
    {"__gc",                     userdata_gc},
    {NULL,                       NULL}
};

int luaopen_hs__asm_btle_service(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:UD_SERVICE_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:service_metaLib];

    [skin registerPushNSHelper:pushCBServiceAsUD              forClass:"CBService"] ;
    [skin registerLuaObjectHelper:toCBServiceFromLuaUD        forClass:"CBService"];

    return 1;
}
