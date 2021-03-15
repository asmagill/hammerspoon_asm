@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.test" ;
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface ASMTestObject : NSObject
@property NSString *name ;
@property int      selfRef ;
@property int      callbackRef ;
@property int      selfRefCount ;
@end

@implementation ASMTestObject
- (instancetype)initWithName:(NSString *)name {
    self = [super init] ;
    if (self) {
        _name         = name ;
        _selfRef      = LUA_NOREF ;
        _callbackRef  = LUA_NOREF ;
        _selfRefCount = 0 ;
    }
    return self ;
}
@end

#pragma mark - Module Functions

static int test_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    NSString *name = [skin toNSObjectAtIndex:1] ;
    ASMTestObject *newObj = [[ASMTestObject alloc] initWithName:name] ;
    if (newObj) {
        [skin pushNSObject:newObj] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int test_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTestObject *obj = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:obj.name] ;
    } else {
        NSString *newName = [skin toNSObjectAtIndex:2] ;
        obj.name = newName ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int test_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTestObject *obj = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (obj.callbackRef == LUA_NOREF) {
            lua_pushnil(L) ;
        } else {
            [skin pushLuaRef:refTable ref:obj.callbackRef] ;
        }
    } else {
        obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            obj.callbackRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int test_triggerCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMTestObject *obj = [skin toNSObjectAtIndex:1] ;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (obj.callbackRef != LUA_NOREF) {
            LuaSkin   *_skin = [LuaSkin sharedWithState:NULL] ;
            lua_State *_L    = _skin.L ;
            [_skin pushLuaRef:refTable ref:obj.callbackRef] ;
            [_skin pushNSObject:obj] ;
            if (![_skin protectedCallAndTraceback:1 nresults:0]) {
                [_skin logError:[NSString stringWithFormat:@"%s:callback - %s", USERDATA_TAG, lua_tostring(_L, -1)]] ;
                lua_pop(_L, 1) ;
            }
        }
    }) ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int test_selfRefCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMTestObject *obj = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, obj.selfRefCount) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMTestObject(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    ASMTestObject *value = obj;
    if (value.selfRef == LUA_NOREF) {
        void** valuePtr = lua_newuserdata(L, sizeof(ASMTestObject *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
        value.selfRef = [skin luaRef:refTable] ;
    }
    [skin pushLuaRef:refTable ref:value.selfRef] ;
    return 1;
}

id toASMTestObjectFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    ASMTestObject *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMTestObject, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    ASMTestObject *obj = [skin luaObjectAtIndex:1 toClass:"ASMTestObject"] ;
    NSString *title = obj.name ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        ASMTestObject *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMTestObject"] ;
        ASMTestObject *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMTestObject"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMTestObject *obj = get_objectFromUserdata(__bridge_transfer ASMTestObject, L, 1, USERDATA_TAG) ;
    [LuaSkin logInfo:[NSString stringWithFormat:@"%s:__gc with %@ (%d)", USERDATA_TAG, obj, obj.selfRefCount]] ;
    if (obj) {
        LuaSkin *skin   = [LuaSkin sharedWithState:L] ;
        obj.selfRef     = [skin luaUnref:refTable ref:obj.selfRef] ;
        obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
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
    {"selfRefCount", test_selfRefCount},
    {"name",         test_name},
    {"callback",     test_callback},
    {"trigger",      test_triggerCallback},

    {"__tostring",   userdata_tostring},
    {"__eq",         userdata_eq},
    {"__gc",         userdata_gc},
    {NULL,           NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", test_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_test_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASMTestObject         forClass:"ASMTestObject"];
    [skin registerLuaObjectHelper:toASMTestObjectFromLua forClass:"ASMTestObject"
                                              withUserdataMapping:USERDATA_TAG];

    return 1;
}
