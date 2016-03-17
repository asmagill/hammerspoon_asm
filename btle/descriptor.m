#include "btle.h"

static int refTable   = LUA_NOREF;

#pragma mark - Descriptor Methods

static int descriptorUUID(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    CBDescriptor *theDescriptor = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
    BOOL raw = (lua_gettop(L) == 2) ? (BOOL)lua_toboolean(L, 2) : NO ;
    NSString *answer = [theDescriptor.UUID UUIDString] ;
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

static int descriptorValue(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TBREAK] ;
    CBDescriptor *theDescriptor = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
    [skin pushNSObject:theDescriptor.value] ;
    return 1 ;
}

static int descriptorCharacteristic(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TBREAK] ;
    CBDescriptor *theDescriptor = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
    [skin pushNSObject:theDescriptor.characteristic] ;
    return 1 ;
}

static int peripheralReadValueForDescriptor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TBREAK] ;
    CBDescriptor *theDescriptor = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
    CBPeripheral *thePeripheral = [[[theDescriptor characteristic] service] peripheral] ;
    [thePeripheral readValueForDescriptor:theDescriptor] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

// TODO: - (void)writeValue:(NSData *)data forDescriptor:(CBDescriptor *)descriptor

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
    LuaSkin *skin = [LuaSkin shared] ;
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
    LuaSkin *skin = [LuaSkin shared] ;
    CBDescriptor *obj = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
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
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_DESCRIPTOR_TAG,
                                                                  label,
                                                                  lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    LuaSkin *skin = [LuaSkin shared] ;
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

    {"__tostring",     userdata_tostring},
    {"__eq",           userdata_eq},
    {"__gc",           userdata_gc},
    {NULL,             NULL}
};

int luaopen_hs__asm_btle_descriptor(__unused lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:UD_DESCRIPTOR_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:descriptor_metaLib];

    [skin registerPushNSHelper:pushCBDescriptorAsUD           forClass:"CBDescriptor"] ;
    [skin registerLuaObjectHelper:toCBDescriptorFromLuaUD     forClass:"CBDescriptor"];

    return 1;
}
