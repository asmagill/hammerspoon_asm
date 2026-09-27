@import Cocoa ;
@import LuaSkin ;
@import CoreBluetooth;

#import "libbtle.h"

static LSRefTable refTable = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

static NSMapTable *descriptor_internals ;

@interface CBDescriptor (HammerspoonAdditions2)
@property (nonatomic) int selfRefCount ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation CBDescriptor (HammerspoonAdditions)

- (void)setCallbackRef:(int)value {
    NSMutableDictionary *internals = [descriptor_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [descriptor_internals setObject:internals forKey:self] ;
    }
    internals[@"callback"] = @(value) ;
}

- (int)callbackRef {
    NSMutableDictionary *internals = [descriptor_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [descriptor_internals setObject:internals forKey:self] ;
    }
    NSNumber *value = internals[@"callback"] ;
    return value.intValue ;
}

- (void)setSelfRefCount:(int)value {
    NSMutableDictionary *internals = [descriptor_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [descriptor_internals setObject:internals forKey:self] ;
    }
    internals[@"selfRef"] = @(value) ;
}

- (int)selfRefCount {
    NSMutableDictionary *internals = [descriptor_internals objectForKey:self] ;
    if (!internals) {
        internals = [NSMutableDictionary dictionary] ;
        internals[@"callback"] = @(LUA_NOREF) ;
        internals[@"selfRef"] = @(0) ;
        [descriptor_internals setObject:internals forKey:self] ;
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

static int descriptor_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    CBDescriptor *descriptor = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        descriptor.callbackRef = [skin luaUnref:refTable ref:descriptor.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            descriptor.callbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (descriptor.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:descriptor.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int descriptor_characteristic(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TBREAK] ;
    CBDescriptor *descriptor = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:descriptor.characteristic] ;
    return 1 ;
}

static int descriptor_value(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TBREAK] ;
    CBDescriptor *descriptor = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:descriptor.value withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

static int descriptor_uuid(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TBREAK] ;
    CBDescriptor *descriptor = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:descriptor.UUID.UUIDString] ;
    return 1 ;
}

static int peripheral_readValueForDescriptor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TBREAK] ;
    CBDescriptor *descriptor = [skin toNSObjectAtIndex:1] ;
    CBPeripheral *peripheral = descriptor.characteristic.service.peripheral ;
    [peripheral readValueForDescriptor:descriptor] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int peripheral_writeValueForDescriptor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TSTRING, LS_TBREAK] ;
    CBDescriptor *descriptor = [skin toNSObjectAtIndex:1] ;
    CBPeripheral *peripheral = descriptor.characteristic.service.peripheral ;
    NSData       *data       = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] ;
    [peripheral writeValue:data forDescriptor:descriptor] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants -

static int descriptor_predefinedDescriptors(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:@{
        @"extendedProperties"  : CBUUIDCharacteristicExtendedPropertiesString,
        @"userDescription"     : CBUUIDCharacteristicUserDescriptionString,
        @"clientConfiguration" : CBUUIDClientCharacteristicConfigurationString,
        @"serverConfiguration" : CBUUIDServerCharacteristicConfigurationString,
        @"format"              : CBUUIDCharacteristicFormatString,
        @"aggregateFormate"    : CBUUIDCharacteristicAggregateFormatString,
        @"validRange"          : CBUUIDCharacteristicValidRangeString,
        @"observationSchedule" : CBUUIDCharacteristicObservationScheduleString,
        @"L2CAPPSM"            : CBUUIDL2CAPPSMCharacteristicString,
    }] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushCBDescriptor(lua_State *L, id obj) {
    CBDescriptor *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(CBDescriptor *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_DESCRIPTOR_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toCBDescriptorFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    CBDescriptor *value ;
    if (luaL_testudata(L, idx, UD_DESCRIPTOR_TAG)) {
        value = get_objectFromUserdata(__bridge CBDescriptor, L, idx, UD_DESCRIPTOR_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_DESCRIPTOR_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    CBDescriptor *obj = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
    NSString *title = obj.UUID.UUIDString ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_DESCRIPTOR_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, UD_DESCRIPTOR_TAG) && luaL_testudata(L, 2, UD_DESCRIPTOR_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        CBDescriptor *obj1 = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
        CBDescriptor *obj2 = [skin luaObjectAtIndex:2 toClass:"CBDescriptor"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    CBDescriptor *obj = get_objectFromUserdata(__bridge_transfer CBDescriptor, L, 1, UD_DESCRIPTOR_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin     = [LuaSkin sharedWithState:L] ;
            obj.callbackRef   = [skin luaUnref:refTable ref:obj.callbackRef] ;
            [descriptor_internals removeObjectForKey:obj] ;
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
    {"callback",       descriptor_callback},
    {"characteristic", descriptor_characteristic},
    {"value",          descriptor_value},
    {"uuid",           descriptor_uuid},

    {"readValue",      peripheral_readValueForDescriptor},
    {"writeValue",     peripheral_writeValueForDescriptor},

    {"__tostring",     userdata_tostring},
    {"__eq",           userdata_eq},
    {"__gc",           userdata_gc},
    {NULL,             NULL}
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

int luaopen_hs__asm_libbtle_descriptor(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:UD_DESCRIPTOR_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushCBDescriptor         forClass:"CBDescriptor"];
    [skin registerLuaObjectHelper:toCBDescriptorFromLua forClass:"CBDescriptor"
                                          withUserdataMapping:UD_DESCRIPTOR_TAG];

    descriptor_predefinedDescriptors(L) ; lua_setfield(L, -2, "predefined") ;

    descriptor_internals = [NSMapTable weakToStrongObjectsMapTable] ;

    return 1;
}
