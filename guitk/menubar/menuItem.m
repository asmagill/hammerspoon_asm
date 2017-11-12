@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.guitk.menubar.menu.item" ;
static int refTable = LUA_NOREF;

static NSDictionary *MENU_ITEM_STATES ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static void defineInternalDictionaryies() {
    MENU_ITEM_STATES = @{
        @"on"    : @(NSOnState),
        @"off"   : @(NSOffState),
        @"mixed" : @(NSMixedState),
    } ;
}

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

static int menuitem_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    HSMenuItem *item = [[HSMenuItem alloc] initWithTitle:[skin toNSObjectAtIndex:1]] ;
    if (item) {
        [skin pushNSObject:item] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int menuitem_state(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *state = @(item.state) ;
        NSArray *temp = [MENU_ITEM_STATES allKeysForObject:state];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized state %@ -- notify developers", USERDATA_TAG, state]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *state = MENU_ITEM_STATES[key] ;
        if (state) {
            item.state = [state integerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[MENU_ITEM_STATES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int menuitem_indentationLevel(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, item.indentationLevel) ;
    } else {
        NSInteger level = lua_tointeger(L, 2) ;
        item.indentationLevel = (level < 0) ? 0 : ((level > 15) ? 15 : level) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menuitem_toolTip(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.toolTip] ;
    } else {
        if (lua_type(L, 2) != LUA_TSTRING) {
            item.toolTip = nil ;
        } else {
            item.toolTip = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menuitem_image(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,  LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.image] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            item.image = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            item.image = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menuitem_mixedStateImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,  LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.mixedStateImage] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            item.mixedStateImage = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            item.mixedStateImage = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menuitem_offStateImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,  LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.offStateImage] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            item.offStateImage = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            item.offStateImage = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menuitem_onStateImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,  LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.onStateImage] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            item.onStateImage = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            item.onStateImage = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menuitem_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.title] ;
    } else if (lua_type(L, 1) == LUA_TBOOLEAN) {
        [skin pushNSObject:(lua_toboolean(L, 1) ? item.attributedTitle : item.title)] ;
    } else {
        if (lua_type(L, 2) == LUA_TUSERDATA) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.styledtext", LS_TBREAK] ;
            NSAttributedString *title = [skin toNSObjectAtIndex:2] ;
            item.attributedTitle = title ;
            item.title = title.string ;
        } else if (lua_type(L, 2) == LUA_TNIL) {
            item.attributedTitle = nil ;
            item.title = @"" ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
            item.attributedTitle = nil ;
            item.title = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menuitem_enabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, item.enabled) ;
    } else {
        item.enabled = (BOOL)lua_toboolean(L, 2) ;
    }
    return 1 ;
}

static int menuitem_hidden(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, item.hidden) ;
    } else {
        item.hidden = (BOOL)lua_toboolean(L, 2) ;
    }
    return 1 ;
}

static int menuitem_view(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (item.view && [skin canPushNSObject:item.view]) {
            [skin pushNSObject:item.view] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            if (item.view && [skin canPushNSObject:item.view]) [skin luaRelease:refTable forNSObject:item.view] ;
            item.view = nil ;
        } else {
            NSView *view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
            if (!view || ![view isKindOfClass:[NSView class]]) {
                return luaL_argerror(L, 2, "expected userdata representing a gui element (NSView subclass)") ;
            }
            if (item.view && [skin canPushNSObject:item.view]) [skin luaRelease:refTable forNSObject:item.view] ;
            [skin luaRetain:refTable forNSObject:view] ;
            item.view = view ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menuitem_submenu(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.submenu] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            if (item.submenu && [skin canPushNSObject:item.submenu]) [skin luaRelease:refTable forNSObject:item.submenu] ;
            item.menu = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs._asm.guitk.menubar.menu", LS_TBREAK] ;
            if (item.submenu && [skin canPushNSObject:item.submenu]) [skin luaRelease:refTable forNSObject:item.submenu] ;
            item.submenu = [skin toNSObjectAtIndex:2] ;
            [skin luaRetain:refTable forNSObject:item.submenu] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menuitem_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        item.callbackRef = [skin luaUnref:refTable ref:item.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            item.callbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (item.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:item.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

// not sure yet, still considering
//     @property NSInteger tag;
//     @property(strong) id representedObject;
//     @property BOOL allowsKeyEquivalentWhenHidden;
//     @property NSEventModifierFlags keyEquivalentModifierMask;
//     @property(copy) NSString *keyEquivalent;
//     @property(getter=isAlternate) BOOL alternate; -- see https://stackoverflow.com/questions/33764644/option-context-menu-in-cocoa

// may do getters for some of these
//     @property(assign) NSMenu *menu; -- treat as readonly; add or remove with menu object
//     @property(readonly, assign) NSMenuItem *parentItem;
//     @property(getter=isHiddenOrHasHiddenAncestor, readonly) BOOL hiddenOrHasHiddenAncestor;
//     @property(getter=isHighlighted, readonly) BOOL highlighted;

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
            LuaSkin *skin = [LuaSkin shared] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            if (obj.view) {
                if ([skin canPushNSObject:obj.view]) [skin luaRelease:refTable forNSObject:obj.view] ;
                obj.view = nil ;
            }
            if (obj.submenu) {
                if ([skin canPushNSObject:obj.submenu]) [skin luaRelease:refTable forNSObject:obj.submenu] ;
                obj.submenu = nil ;
            }
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
    {"state",            menuitem_state},
    {"indentationLevel", menuitem_indentationLevel},
    {"tooltip",          menuitem_toolTip},
    {"image",            menuitem_image},
    {"mixedStateImage",  menuitem_mixedStateImage},
    {"offStateImage",    menuitem_offStateImage},
    {"onStateImage",     menuitem_onStateImage},
    {"title",            menuitem_title},
    {"enabled",          menuitem_enabled},
    {"hidden",           menuitem_hidden},
    {"view",             menuitem_view},
    {"submenu",          menuitem_submenu},
    {"callback",         menuitem_callback},

    {"__tostring",       userdata_tostring},
    {"__eq",             userdata_eq},
    {"__gc",             userdata_gc},
    {NULL,               NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", menuitem_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_guitk_menubar_menuItem(lua_State* L) {
    defineInternalDictionaryies() ;

    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSMenuItem         forClass:"HSMenuItem"];
    [skin registerLuaObjectHelper:toHSMenuItemFromLua forClass:"HSMenuItem"
                                             withUserdataMapping:USERDATA_TAG];

    [skin pushNSObject:@[
        @"state",
        @"indentationLevel",
        @"tooltip",
        @"image",
        @"mixedStateImage",
        @"offStateImage",
        @"onStateImage",
        @"title",
        @"enabled",
        @"hidden",
        @"view",
        @"submenu",
        @"callback",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;

    return 1;
}
