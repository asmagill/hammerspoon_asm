#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG "hs._asm.luaskinpokeytool"
// Modules which support luathread have to store refTable in the threadDictionary rather than a static
// static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes
extern NSMutableDictionary *registeredNSHelperFunctions ;
extern NSMutableDictionary *registeredNSHelperLocations ;
extern NSMutableDictionary *registeredLuaObjectHelperFunctions ;
extern NSMutableDictionary *registeredLuaObjectHelperLocations ;
extern NSMutableDictionary *registeredLuaObjectHelperUserdataMappings;

#pragma mark - Module Functions

static int getLuaSkinObject(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:skin] ;
    return 1 ;
}

#pragma mark - Module Methods

static int getRegisteredNSHelperFunctions(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    LuaSkin *theSkinInQuestion = [skin toNSObjectAtIndex:1] ;

    BOOL isThreadVersion = [theSkinInQuestion isKindOfClass:NSClassFromString(@"LuaSkinThread")] ;
    if (isThreadVersion) {
        [skin pushNSObject:[theSkinInQuestion performSelector:@selector(registeredNSHelperFunctions)] withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    } else {
        [skin pushNSObject:registeredNSHelperFunctions withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    }
    return 1 ;
}
static int getRegisteredNSHelperLocations(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    LuaSkin *theSkinInQuestion = [skin toNSObjectAtIndex:1] ;

    BOOL isThreadVersion = [theSkinInQuestion isKindOfClass:NSClassFromString(@"LuaSkinThread")] ;
    if (isThreadVersion) {
        [skin pushNSObject:[theSkinInQuestion performSelector:@selector(registeredNSHelperLocations)] withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    } else {
        [skin pushNSObject:registeredNSHelperLocations withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    }
    return 1 ;
}
static int getRegisteredLuaObjectHelperFunctions(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    LuaSkin *theSkinInQuestion = [skin toNSObjectAtIndex:1] ;

    BOOL isThreadVersion = [theSkinInQuestion isKindOfClass:NSClassFromString(@"LuaSkinThread")] ;
    if (isThreadVersion) {
        [skin pushNSObject:[theSkinInQuestion performSelector:@selector(registeredLuaObjectHelperFunctions)] withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    } else {
        [skin pushNSObject:registeredLuaObjectHelperFunctions withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    }
    return 1 ;
}
static int getRegisteredLuaObjectHelperLocations(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    LuaSkin *theSkinInQuestion = [skin toNSObjectAtIndex:1] ;

    BOOL isThreadVersion = [theSkinInQuestion isKindOfClass:NSClassFromString(@"LuaSkinThread")] ;
    if (isThreadVersion) {
        [skin pushNSObject:[theSkinInQuestion performSelector:@selector(registeredLuaObjectHelperLocations)] withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    } else {
        [skin pushNSObject:registeredLuaObjectHelperLocations withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    }
    return 1 ;
}
static int getRegisteredLuaObjectHelperUserdataMappings(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    LuaSkin *theSkinInQuestion = [skin toNSObjectAtIndex:1] ;

    BOOL isThreadVersion = [theSkinInQuestion isKindOfClass:NSClassFromString(@"LuaSkinThread")] ;
    if (isThreadVersion) {
        [skin pushNSObject:[theSkinInQuestion performSelector:@selector(registeredLuaObjectHelperUserdataMappings)] withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    } else {
        [skin pushNSObject:registeredLuaObjectHelperUserdataMappings withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    }
    return 1 ;
}

#pragma mark - Module Constants

static int pushLogLevels(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, LS_LOG_BREADCRUMB) ; lua_setfield(L, -2, "breadcrumb") ;
    lua_pushinteger(L, LS_LOG_VERBOSE) ;    lua_setfield(L, -2, "verbose") ;
    lua_pushinteger(L, LS_LOG_DEBUG) ;      lua_setfield(L, -2, "debug") ;
    lua_pushinteger(L, LS_LOG_INFO) ;       lua_setfield(L, -2, "info") ;
    lua_pushinteger(L, LS_LOG_WARN) ;       lua_setfield(L, -2, "warn") ;
    lua_pushinteger(L, LS_LOG_ERROR) ;      lua_setfield(L, -2, "error") ;
    return 1 ;
}

static int pushCheckArgumentTypes(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, LS_TBREAK) ;    lua_setfield(L, -2, "break") ;
    lua_pushinteger(L, LS_TOPTIONAL) ; lua_setfield(L, -2, "optional") ;
    lua_pushinteger(L, LS_TNIL) ;      lua_setfield(L, -2, "nil") ;
    lua_pushinteger(L, LS_TBOOLEAN) ;  lua_setfield(L, -2, "boolean") ;
    lua_pushinteger(L, LS_TNUMBER) ;   lua_setfield(L, -2, "number") ;
    lua_pushinteger(L, LS_TSTRING) ;   lua_setfield(L, -2, "string") ;
    lua_pushinteger(L, LS_TTABLE) ;    lua_setfield(L, -2, "table") ;
    lua_pushinteger(L, LS_TFUNCTION) ; lua_setfield(L, -2, "function") ;
    lua_pushinteger(L, LS_TUSERDATA) ; lua_setfield(L, -2, "userdata") ;
    lua_pushinteger(L, LS_TNONE) ;     lua_setfield(L, -2, "none") ;
    lua_pushinteger(L, LS_TANY) ;      lua_setfield(L, -2, "optional") ;
    return 1 ;
}

static int pushConversionOptions(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, LS_NSNone) ;                         lua_setfield(L, -2, "none") ;
    lua_pushinteger(L, LS_NSUnsignedLongLongPreserveBits) ; lua_setfield(L, -2, "unsignedLongLongPreserveBits") ;
    lua_pushinteger(L, LS_NSDescribeUnknownTypes) ;         lua_setfield(L, -2, "describeUnknownTypes") ;
    lua_pushinteger(L, LS_NSIgnoreUnknownTypes) ;           lua_setfield(L, -2, "ignoreUnknownTypes") ;
    lua_pushinteger(L, LS_NSPreserveLuaStringExactly) ;     lua_setfield(L, -2, "preserveLuaStringExactly") ;
    lua_pushinteger(L, LS_NSLuaStringAsDataOnly) ;          lua_setfield(L, -2, "luaStringAsDataOnly") ;
    lua_pushinteger(L, LS_NSAllowsSelfReference) ;          lua_setfield(L, -2, "allowsSelfReference") ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushLuaSkin(lua_State *L, id obj) {
    LuaSkin *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(LuaSkin *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toLuaSkinFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    LuaSkin *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge LuaSkin, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    LuaSkin *obj = [skin luaObjectAtIndex:1 toClass:"LuaSkin"] ;
    NSString *title = [obj isKindOfClass:NSClassFromString(@"LuaSkinThread")] ? @"LuaSkinThread" : @"LuaSkin" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                           [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
        LuaSkin *obj1 = [skin luaObjectAtIndex:1 toClass:"LuaSkin"] ;
        LuaSkin *obj2 = [skin luaObjectAtIndex:2 toClass:"LuaSkin"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *obj = get_objectFromUserdata(__bridge_transfer LuaSkin, L, 1, USERDATA_TAG) ;
    if (obj) obj = nil ;
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
    {"NSHelperFunctions",   getRegisteredNSHelperFunctions},
    {"NSHelperLocations",   getRegisteredNSHelperLocations},
    {"luaHelperFunctions",  getRegisteredLuaObjectHelperFunctions},
    {"luaHelperLocations",  getRegisteredLuaObjectHelperLocations},
    {"luaUserdataMappings", getRegisteredLuaObjectHelperUserdataMappings},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"get", getLuaSkinObject},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_luaskinpokeytool_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;

    // Necessary only for modules which are written to work in either Hammerspoon or luathread.
    // For luathread only modules (i.e. those included with hs._asm.luathread), this is taken care
    // of during thread initialization
    if ([NSThread isMainThread] && ![[[NSThread currentThread] threadDictionary] objectForKey:@"_refTables"]) {
        [[[NSThread currentThread] threadDictionary] setObject:[[NSMutableDictionary alloc] init]
                                                        forKey:@"_refTables"] ;
    }

    // This is necessary for any module which is to be used within luathread to ensure each module
    // has a unique refTable value for each thread it may be running in
    [[[[NSThread currentThread] threadDictionary] objectForKey:@"_refTables"]
        setObject:@([skin registerLibraryWithObject:USERDATA_TAG
                                          functions:moduleLib
                                      metaFunctions:nil
                                    objectFunctions:userdata_metaLib])
           forKey:[NSString stringWithFormat:@"%s", USERDATA_TAG]] ;

    [skin registerPushNSHelper:pushLuaSkin         forClass:"LuaSkin"];
    [skin registerLuaObjectHelper:toLuaSkinFromLua forClass:"LuaSkin"
                                        withUserdataMapping:USERDATA_TAG];

    pushLogLevels(L) ;          lua_setfield(L, -2, "logLevels") ;
    pushCheckArgumentTypes(L) ; lua_setfield(L, -2, "checkArgumentTypes") ;
    pushConversionOptions(L) ;  lua_setfield(L, -2, "conversionOptions") ;

    return 1;
}
