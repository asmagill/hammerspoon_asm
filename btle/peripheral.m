#include "btle.h"

static int refTable   = LUA_NOREF;

#pragma mark - Peripheral Methods

static int peripheralIdentifier(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [skin pushNSObject:[thePeripheral.identifier UUIDString]] ;
    return 1 ;
}

static int peripheralName(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [skin pushNSObject:thePeripheral.name] ;
    return 1 ;
}

static int peripheralServices(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [skin pushNSObject:thePeripheral.services] ;
    return 1 ;
}

//FIXME: currently searches for all -- add support for limiting by CBService array
static int peripheralDiscoverServices(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [thePeripheral discoverServices:nil] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int peripheralState(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    CBPeripheralState theState = thePeripheral.state ;
    switch(theState) {
        case CBPeripheralStateDisconnected: lua_pushstring(L, "disconnected") ; break ;
        case CBPeripheralStateConnecting:   lua_pushstring(L, "connecting") ; break ;
        case CBPeripheralStateConnected:    lua_pushstring(L, "connected") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized state: %ld", theState]] ;
            break ;
    }
    return 1 ;
}

static int peripheralRSSI(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [skin pushNSObject:thePeripheral.RSSI] ;
    return 1 ;
}

static int peripheralReadRSSI(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [thePeripheral readRSSI] ;
    lua_pushvalue(L, 1) ;
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
    LuaSkin *skin = [LuaSkin shared] ;
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
    LuaSkin *skin = [LuaSkin shared] ;
    CBPeripheral *obj = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_PERIPHERAL_TAG,
                                                                  [obj name],
                                                                  lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    LuaSkin *skin = [LuaSkin shared] ;
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
    if (obj) {
        obj.delegate = nil ;
        obj          = nil ;
    }

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
    {"identifier",                        peripheralIdentifier},
    {"name",                              peripheralName},
    {"state",                             peripheralState},

    {"discoverServices",                  peripheralDiscoverServices},
    {"services",                          peripheralServices},

    {"RSSI",                              peripheralRSSI},
    {"readRSSI",                          peripheralReadRSSI},

    {"__tostring",                        userdata_tostring},
    {"__eq",                              userdata_eq},
    {"__gc",                              userdata_gc},
    {NULL,                                NULL}
};

int luaopen_hs__asm_btle_peripheral(__unused lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:UD_PERIPHERAL_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:peripheral_metaLib];

    [skin registerPushNSHelper:pushCBPeripheralAsUD           forClass:"CBPeripheral"] ;
    [skin registerLuaObjectHelper:toCBPeripheralFromLuaUD     forClass:"CBPeripheral"];

    return 1;
}
