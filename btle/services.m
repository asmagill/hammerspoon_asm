#include "btle.h"

static int refTable   = LUA_NOREF;

#pragma mark - Service Methods

static int serviceUUID(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    CBService *theService = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    BOOL raw = (lua_gettop(L) == 2) ? (BOOL)lua_toboolean(L, 2) : NO ;
    NSString *answer = [theService.UUID UUIDString] ;
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

static int servicePeripheral(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *theService = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    [skin pushNSObject:theService.peripheral] ;
    return 1 ;
}

static int serviceCharacteristics(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *theService = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    [skin pushNSObject:theService.characteristics] ;
    return 1 ;
}

static int serviceIncludedServices(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *theService = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    [skin pushNSObject:theService.includedServices] ;
    return 1 ;
}

static int servicePrimary(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *theService = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    lua_pushboolean(L, theService.isPrimary) ;
    return 1 ;
}

//FIXME: currently searches for all -- add support for limiting by CBService array
static int peripheralDiscoverIncludedServices(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService    *theService    = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    CBPeripheral *thePeripheral = [theService peripheral] ;
    [thePeripheral discoverIncludedServices:nil forService:theService] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

//FIXME: currently searches for all -- add support for limiting by CBCharacteristic array
static int peripheralDiscoverCharacteristicsForService(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
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
    LuaSkin *skin = [LuaSkin shared] ;
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
    LuaSkin *skin = [LuaSkin shared] ;
    CBService *obj = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
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
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_SERVICE_TAG,
                                                                  label,
                                                                  lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    LuaSkin *skin = [LuaSkin shared] ;
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

int luaopen_hs__asm_btle_service(__unused lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:UD_SERVICE_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:service_metaLib];

    [skin registerPushNSHelper:pushCBServiceAsUD              forClass:"CBService"] ;
    [skin registerLuaObjectHelper:toCBServiceFromLuaUD        forClass:"CBService"];

    return 1;
}
