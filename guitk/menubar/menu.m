@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.guitk.menubar.menu" ;
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSMenu : NSMenu <NSMenuDelegate>
@property int callbackRef ;
@property int selfRefCount ;
@end

@implementation HSMenu

- (instancetype)initWithTitle:(NSString *)title {
    self = [super initWithTitle:title] ;
    if (self) {
        _callbackRef  = LUA_NOREF ;
        _selfRefCount = 0 ;

        self.autoenablesItems = NO ;
    }
    return self ;
}

// - (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel;
// - (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id  _Nullable *)target action:(SEL  _Nullable *)action;
// - (NSInteger)numberOfItemsInMenu:(NSMenu *)menu;
// - (NSRect)confinementRectForMenu:(NSMenu *)menu onScreen:(NSScreen *)screen;
// - (void)menu:(NSMenu *)menu willHighlightItem:(NSMenuItem *)item;
// - (void)menuDidClose:(NSMenu *)menu;
// - (void)menuNeedsUpdate:(NSMenu *)menu;
// - (void)menuWillOpen:(NSMenu *)menu;

@end

#pragma mark - Module Functions

#pragma mark - Module Methods

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSMenu(lua_State *L, id obj) {
    HSMenu *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSMenu *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toHSMenuFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSMenu *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSMenu, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSMenu *obj = [skin luaObjectAtIndex:1 toClass:"HSMenu"] ;
    NSString *title = obj.title ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSMenu *obj1 = [skin luaObjectAtIndex:1 toClass:"HSMenu"] ;
        HSMenu *obj2 = [skin luaObjectAtIndex:2 toClass:"HSMenu"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSMenu *obj = get_objectFromUserdata(__bridge_transfer HSMenu, L, 1, USERDATA_TAG) ;
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

int luaopen_hs__asm_guitk_menubar_menu(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSMenu         forClass:"HSMenu"];
    [skin registerLuaObjectHelper:toHSMenuFromLua forClass:"HSMenu"
                                             withUserdataMapping:USERDATA_TAG];

    return 1;
}
