@import Cocoa ;
@import LuaSkin ;
@import CoreBluetooth;

#import "libbtle.h"

static LSRefTable refTable = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

static NSMapTable *service_internals ;

@interface CBService (HammerspoonAdditions2)
@property (nonatomic) int selfRefCount ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation CBService (HammerspoonAdditions)

- (void)setCallbackRef:(int)value {
    NSMutableDictionary *internals = [service_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [service_internals setObject:internals forKey:self] ;
    }
    internals[@"callback"] = @(value) ;
}

- (int)callbackRef {
    NSMutableDictionary *internals = [service_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [service_internals setObject:internals forKey:self] ;
    }
    NSNumber *value = internals[@"callback"] ;
    return value.intValue ;
}

- (void)setSelfRefCount:(int)value {
    NSMutableDictionary *internals = [service_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [service_internals setObject:internals forKey:self] ;
    }
    internals[@"selfRef"] = @(value) ;
}

- (int)selfRefCount {
    NSMutableDictionary *internals = [service_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [service_internals setObject:internals forKey:self] ;
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

static int service_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    CBService *service = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        service.callbackRef = [skin luaUnref:refTable ref:service.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            service.callbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (service.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:service.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int service_isPrimary(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *service = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, service.isPrimary) ;
    return 1 ;
}

static int service_peripheral(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *service = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:service.peripheral] ;
    return 1 ;
}

static int service_characteristics(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *service = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:service.characteristics] ;
    return 1 ;
}

static int service_includedServices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *service = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:service.includedServices] ;
    return 1 ;
}

static int service_uuid(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *service = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:service.UUID.UUIDString] ;
    return 1 ;
}

static int peripheral_discoverCharacteristics(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TSTRING | LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    CBService    *service    = [skin toNSObjectAtIndex:1] ;
    CBPeripheral *peripheral = service.peripheral ;

    NSArray *characteristicUUIDs = nil ;
    if (lua_gettop(L) > 1) {
        NSArray *list       = [skin toNSObjectAtIndex:2] ;
        NSError *error      = nil ;
        characteristicUUIDs = validateAndConvertUUIDs(list, YES, &error) ;

        if (error) return luaL_argerror(L, 2, error.localizedDescription.UTF8String) ;
    }

    [peripheral discoverCharacteristics:characteristicUUIDs forService:service] ;
    lua_pushvalue(L, 1);
    return 1;
}

static int peripheral_discoverIncludedServices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TSTRING | LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    CBService    *service    = [skin toNSObjectAtIndex:1] ;
    CBPeripheral *peripheral = service.peripheral ;

    NSArray *includedServiceUUIDs = nil ;
    if (lua_gettop(L) > 1) {
        NSArray *list        = [skin toNSObjectAtIndex:2] ;
        NSError *error       = nil ;
        includedServiceUUIDs = validateAndConvertUUIDs(list, YES, &error) ;

        if (error) return luaL_argerror(L, 2, error.localizedDescription.UTF8String) ;
    }

    [peripheral discoverIncludedServices:includedServiceUUIDs forService:service] ;
    lua_pushvalue(L, 1);
    return 1;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushCBService(lua_State *L, id obj) {
    CBService *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(CBService *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_SERVICE_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toCBServiceFromLua(lua_State *L, int idx) {
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

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    CBService *obj = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    NSString *title = obj.UUID.UUIDString ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_SERVICE_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, UD_SERVICE_TAG) && luaL_testudata(L, 2, UD_SERVICE_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin     = [LuaSkin sharedWithState:L] ;
            obj.callbackRef   = [skin luaUnref:refTable ref:obj.callbackRef] ;
            [service_internals removeObjectForKey:obj] ;
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
    {"callback",                 service_callback},
    {"primary",                  service_isPrimary},
    {"peripheral",               service_peripheral},
    {"characteristics",          service_characteristics},
    {"includedServices",         service_includedServices},
    {"uuid",                     service_uuid},

    {"discoverCharacteristics",  peripheral_discoverCharacteristics},
    {"discoverIncludedServices", peripheral_discoverIncludedServices},

    {"__tostring",               userdata_tostring},
    {"__eq",                     userdata_eq},
    {"__gc",                     userdata_gc},
    {NULL,                       NULL}
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

int luaopen_hs__asm_libbtle_service(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:UD_SERVICE_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushCBService         forClass:"CBService"];
    [skin registerLuaObjectHelper:toCBServiceFromLua forClass:"CBService"
                                          withUserdataMapping:UD_SERVICE_TAG];

    service_internals = [NSMapTable weakToStrongObjectsMapTable] ;

    return 1;
}
