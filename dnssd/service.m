@import Cocoa ;
@import LuaSkin ;

@import dnssd ;

static const char * const USERDATA_TAG = "hs._asm.dnssd.service" ;
static int refTable   = LUA_NOREF;
static int helpersRef = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static int dnssd_registerHelpers(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;

    lua_pushvalue(L, 1) ;
    helpersRef = [skin luaRef:refTable] ;
    [skin logInfo:[NSString stringWithFormat:@"registered helpers as %d in %d", helpersRef, refTable]] ;
    return 0 ;
}

static int dnssd_error_stringToLuaStack(lua_State *L, DNSServiceErrorType err) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin pushLuaRef:refTable ref:helpersRef] ;
    lua_getfield(L, -1, "_errorList") ;
    lua_remove(L, -2) ;                             // remove helpersRef
    lua_pushinteger(L, err) ;
    if (lua_gettable(L, -2) == LUA_TNIL) {          // eats err, so no remove necessary
        lua_pop(L, 1) ;                             // remove nil and replace with...
        lua_pushfstring(L, "unrecognized error code: %d", err) ;
    }
    lua_remove(L, -2) ;                             // remove _errorList
    return 1 ;
}

static int dnssd_interfaceName_stringToLuaStack(lua_State *L, uint32_t iidx) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin pushLuaRef:refTable ref:helpersRef] ;
    lua_getfield(L, -1, "if_indexToName") ;
    lua_remove(L, -2) ;
    lua_pushinteger(L, iidx) ;
    if (![skin protectedCallAndTraceback:1 nresults:1]) {
        NSString *errStr = [skin toNSObjectAtIndex:-1] ;
        [skin logError:[NSString stringWithFormat:@"%s:interface - error looking up interface name from index: %s", USERDATA_TAG, errStr.UTF8String]] ;
        lua_pop(L, 1) ;
        lua_pushnil(L) ;
    } else {
        if (lua_isnil(L, -1)) {
            [skin logInfo:[NSString stringWithFormat:@"%s:interface - interface index %u not valid (interface removed?)", USERDATA_TAG, iidx]] ;
            lua_pop(L, 1) ;
            lua_pushnil(L) ;
        } // otherwise it's a string and we want to keep it at the stack top, so no lua_pop
    }
    return 1 ;
}

static int dnssd_interfaceIndex_toLuaStack(lua_State *L, const char *name) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin pushLuaRef:refTable ref:helpersRef] ;
    lua_getfield(L, -1, "if_nameToIndex") ;
    lua_remove(L, -2) ;
    lua_pushstring(L, name) ;
    if (![skin protectedCallAndTraceback:1 nresults:1]) {
        [skin logError:[NSString stringWithFormat:@"%s:interface - error looking up interface index from name: %s", USERDATA_TAG, lua_tostring(L, -1)]] ;
        lua_pop(L, 1) ;
        lua_pushnil(L) ;
    } else {
        if (lua_isnil(L, -1)) {
            [skin logInfo:[NSString stringWithFormat:@"%s:interface - interface name %s not found", USERDATA_TAG, name]] ;
            lua_pop(L, 1) ;
            lua_pushnil(L) ;
        } // otherwise it's an integer and we want to keep it at the stack top, so no lua_pop
    }
    return 1 ;
}

@interface ASMDNSSDService : NSObject
@property (readonly) DNSServiceRef   serviceRef ;
@property            int             selfRefCount ;
@property            int             callbackRef ;
@property            DNSServiceFlags flags ;
@property            uint32_t        interfaceIdx ;
@end

@implementation ASMDNSSDService
- (instancetype)init {
    self = [super init] ;
    if (self) {
        _serviceRef   = NULL ;
        _callbackRef  = LUA_NOREF ;
        _selfRefCount = 0 ;
        _flags        = 0 ;
        _interfaceIdx = kDNSServiceInterfaceIndexAny ;
    }
    return self ;
}

- (void)stop {
    if (_serviceRef) {
        LuaSkin *skin = [LuaSkin shared] ;
        CFRelease(_serviceRef) ;
        DNSServiceRefDeallocate(_serviceRef) ;
        _serviceRef  = NULL ;
        _callbackRef = [skin luaUnref:refTable ref:_callbackRef] ;
    }
}
@end

#pragma mark - Module Functions

#pragma mark - Module Methods

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMDNSSDService(lua_State *L, id obj) {
    ASMDNSSDService *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMDNSSDService *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toASMDNSSDServiceFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMDNSSDService *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMDNSSDService, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
//     ASMDNSSDService *obj = [skin luaObjectAtIndex:1 toClass:"ASMDNSSDService"] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMDNSSDService *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMDNSSDService"] ;
        ASMDNSSDService *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMDNSSDService"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMDNSSDService *obj = get_objectFromUserdata(__bridge_transfer ASMDNSSDService, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            [obj stop] ;
            obj = nil ;
        }
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
    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {

    {"_registerHelpers", dnssd_registerHelpers},
    {NULL,               NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_dnssd_service(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASMDNSSDService         forClass:"ASMDNSSDService"];
    [skin registerLuaObjectHelper:toASMDNSSDServiceFromLua forClass:"ASMDNSSDService"
                                                withUserdataMapping:USERDATA_TAG];

    return 1;
}
