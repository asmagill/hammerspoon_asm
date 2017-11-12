@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.guitk.menubar.menu.item" ;
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSMenuItem : NSMenuItem
@property int  callbackRef ;
@property int  selfRefCount ;
@end

@implementation HSMenuItem

- (instancetype)initWithTitle:(NSString *)title {
    self = [super initWithTitle:title action:@selector(itemSelected:) keyEquivalent:@""] ;
    if (self) {
        _callbackRef    = LUA_NOREF ;
        _selfRefCount   = 0 ;

        self.target     = self ;
    }
    return self ;
}

// requires the menu to have autoenableItems = YES and then enabled is ignored in preference of this
// for *every* item, so probably not going to implement this...
// - (BOOL)validateMenuItem:(NSMenuItem *)menuItem ;

- (void) itemSelected:(__unused id)sender { [self performCallbackMessage:@"select" with:nil] ; }

- (void)performCallbackMessage:(NSString *)message with:(id)data {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin shared] ;
        lua_State *L    = skin.L ;
        int       count = 2 ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:message] ;
        if (data) {
            count++ ;
            [skin pushNSObject:data] ;
        }
        if (![skin protectedCallAndTraceback:count nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:callback error - %s", USERDATA_TAG, lua_tostring(L, -1)]] ;
            lua_pop(L, 1) ;
        }
    }
}

@end

#pragma mark - Module Functions

#pragma mark - Module Methods

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSMenuItem(lua_State *L, id obj) {
    HSMenuItem *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSMenuItem *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toHSMenuItemFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSMenuItem *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSMenuItem, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSMenuItem *obj = [skin luaObjectAtIndex:1 toClass:"HSMenuItem"] ;
    NSString *title = obj.title ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSMenuItem *obj1 = [skin luaObjectAtIndex:1 toClass:"HSMenuItem"] ;
        HSMenuItem *obj2 = [skin luaObjectAtIndex:2 toClass:"HSMenuItem"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSMenuItem *obj = get_objectFromUserdata(__bridge_transfer HSMenuItem, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
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
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_guitk_menubar_menuItem(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSMenuItem         forClass:"HSMenuItem"];
    [skin registerLuaObjectHelper:toHSMenuItemFromLua forClass:"HSMenuItem"
                                             withUserdataMapping:USERDATA_TAG];

    return 1;
}
