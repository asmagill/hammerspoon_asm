@import Cocoa;
@import LuaSkin;
@import CoreBluetooth;

/// === hs._asm.btle.descriptor ===
///
/// Provides support for objects which represent the descriptors of a remote BTLE peripheral’s characteristic.
///
///  Descriptors provide further information about a characteristic’s value. For example, they may describe the value in human-readable form and describe how the value should be formatted for presentation purposes. Characteristic descriptors also indicate whether a characteristic’s value is configured on a server (a peripheral) to indicate or notify a client (a central) when the value of the characteristic changes.

static const char * const UD_DESCRIPTOR_TAG = "hs._asm.btle.descriptor" ;
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, TAG) (objType*)*((void**)luaL_checkudata(L, idx, TAG))

#pragma mark - Descriptor Methods

static int descriptorUUID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TBREAK] ;
    CBDescriptor *theDescriptor = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
    NSString *answer = [theDescriptor.UUID UUIDString] ;
    [skin pushNSObject:answer] ;
    return 1 ;
}

static int descriptorValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TBREAK] ;
    CBDescriptor *theDescriptor = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
    [skin pushNSObject:theDescriptor.value] ;
    return 1 ;
}

static int descriptorCharacteristic(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TBREAK] ;
    CBDescriptor *theDescriptor = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
    [skin pushNSObject:theDescriptor.characteristic] ;
    return 1 ;
}

static int peripheralReadValueForDescriptor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TBREAK] ;
    CBDescriptor *theDescriptor = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
    CBPeripheral *thePeripheral = [[[theDescriptor characteristic] service] peripheral] ;
    [thePeripheral readValueForDescriptor:theDescriptor] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int peripheralWriteValueForDescriptor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TSTRING, LS_TBREAK] ;
    CBDescriptor *theDescriptor = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
    CBPeripheral *thePeripheral = [[[theDescriptor characteristic] service] peripheral] ;
    NSData       *theData       = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] ;
    [thePeripheral writeValue:theData forDescriptor:theDescriptor] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushCBDescriptorAsUD(lua_State *L, id obj) {
    CBDescriptor *theCBDescriptor = obj ;
    void** descriptorPtr = lua_newuserdata(L, sizeof(CBDescriptor *)) ;
    *descriptorPtr = (__bridge_retained void *)theCBDescriptor ;

    luaL_getmetatable(L, UD_DESCRIPTOR_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static id toCBDescriptorFromLuaUD(lua_State *L, int idx) {
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

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    CBDescriptor *obj = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
    NSString *label = [[obj UUID] UUIDString] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_DESCRIPTOR_TAG,
                                                                  label,
                                                                  lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if (luaL_testudata(L, 1, UD_DESCRIPTOR_TAG) && luaL_testudata(L, 2, UD_DESCRIPTOR_TAG)) {
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
static const luaL_Reg descriptor_metaLib[] = {
    {"UUID",           descriptorUUID},
    {"value",          descriptorValue},
    {"characteristic", descriptorCharacteristic},

    {"readValue",      peripheralReadValueForDescriptor},
    {"writeValue",     peripheralWriteValueForDescriptor},

    {"__tostring",     userdata_tostring},
    {"__eq",           userdata_eq},
    {"__gc",           userdata_gc},
    {NULL,             NULL}
};

int luaopen_hs__asm_btle_descriptor(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:UD_DESCRIPTOR_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:descriptor_metaLib];

    [skin registerPushNSHelper:pushCBDescriptorAsUD           forClass:"CBDescriptor"] ;
    [skin registerLuaObjectHelper:toCBDescriptorFromLuaUD     forClass:"CBDescriptor"];

    return 1;
}
