@import Cocoa ;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wauto-import"
@import LuaSkin ;
#pragma clang diagnostic pop

#define USERDATA_TAG "hs._asm.canvas.button"
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#define BUTTON_STYLES @{ \
    @"momentaryLight"        : @(NSMomentaryLightButton), \
    @"pushOnPushOff"         : @(NSPushOnPushOffButton), \
    @"toggle"                : @(NSToggleButton), \
    @"switch"                : @(NSSwitchButton), \
    @"radio"                 : @(NSRadioButton), \
    @"momentaryChange"       : @(NSMomentaryChangeButton), \
    @"onOff"                 : @(NSOnOffButton), \
    @"momentaryPushIn"       : @(NSMomentaryPushInButton), \
    @"accelerator"           : @(NSAcceleratorButton), \
    @"multiLevelAccelerator" : @(NSMultiLevelAcceleratorButton), \
}

#define BEZEL_STYLES @{ \
    @"rounded"           : @(NSRoundedBezelStyle), \
    @"regularSquare"     : @(NSRegularSquareBezelStyle), \
    @"thickSquare"       : @(NSThickSquareBezelStyle), \
    @"thickerSquare"     : @(NSThickerSquareBezelStyle), \
    @"disclosure"        : @(NSDisclosureBezelStyle), \
    @"shadowlessSquare"  : @(NSShadowlessSquareBezelStyle), \
    @"circular"          : @(NSCircularBezelStyle), \
    @"texturedSquare"    : @(NSTexturedSquareBezelStyle), \
    @"helpButton"        : @(NSHelpButtonBezelStyle), \
    @"smallSquare"       : @(NSSmallSquareBezelStyle), \
    @"texturedRounded"   : @(NSTexturedRoundedBezelStyle), \
    @"roundRect"         : @(NSRoundRectBezelStyle), \
    @"recessed"          : @(NSRecessedBezelStyle), \
    @"roundedDisclosure" : @(NSRoundedDisclosureBezelStyle), \
    @"inline"            : @(NSInlineBezelStyle), \
}

#pragma mark - Support Functions and Classes

@interface ASMButton : NSButton
@property int callbackRef ;
@end

@implementation ASMButton
- (instancetype)initWithFrame:(NSRect)frameRect {
    if (!(isfinite(frameRect.origin.x)    && isfinite(frameRect.origin.y) &&
          isfinite(frameRect.size.height) && isfinite(frameRect.size.width))) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:frame must be specified in finite numbers", USERDATA_TAG]];
        return nil;
    }

    self = [super initWithFrame:frameRect];
    if (self) {
        _callbackRef = LUA_NOREF ;

        self.target = self ;
        self.action = @selector(buttonCallback:) ;
    }
    return self ;
}

- (void) buttonCallback:(NSButton*)button {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        lua_State *L  = [skin L] ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:button] ;
        if (![skin protectedCallAndTraceback:1 nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:buttonCallback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    }
}

@end

#pragma mark - Module Functions

static int button_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSString *key = [skin toNSObjectAtIndex:1] ;
    NSNumber *buttonStyle = BUTTON_STYLES[key] ;
    if (buttonStyle) {
        NSRect frameRect = (lua_gettop(L) == 2) ? [skin tableToRectAtIndex:2] : NSZeroRect ;
        ASMButton *buttonView = [[ASMButton alloc] initWithFrame:frameRect];
        [buttonView setButtonType:[buttonStyle unsignedIntegerValue]] ;
        [skin pushNSObject:buttonView] ;
    } else {
        return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[BUTTON_STYLES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int button_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    ASMButton *buttonView = [skin toNSObjectAtIndex:1] ;

    // We're either removing a callback, or setting a new one. Either way, remove existing.
    buttonView.callbackRef = [skin luaUnref:refTable ref:buttonView.callbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        buttonView.callbackRef = [skin luaRef:refTable] ;
    }
    lua_pushvalue(L, 1);
    return 1;
}

static int button_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    ASMButton *buttonView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSString *title = buttonView.title ;
        [skin pushNSObject:(([title isEqualToString:@""]) ? [buttonView.attributedTitle string] : title)] ;
    } else {
        if (lua_type(L, 2) == LUA_TUSERDATA && luaL_testudata(L, 2, "hs.styledtext")) {
            buttonView.attributedTitle = [skin toNSObjectAtIndex:2] ;
        } else {
            luaL_tolstring(L, 2, NULL) ;
            buttonView.title = [skin toNSObjectAtIndex:-1] ;
            lua_pop(L, 1) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int button_alternateTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    ASMButton *buttonView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSString *alternateTitle = buttonView.alternateTitle ;
        [skin pushNSObject:(([alternateTitle isEqualToString:@""]) ? [buttonView.attributedAlternateTitle string] : alternateTitle)] ;
    } else {
        if (lua_type(L, 2) == LUA_TUSERDATA && luaL_testudata(L, 2, "hs.styledtext")) {
            buttonView.attributedAlternateTitle = [skin toNSObjectAtIndex:2] ;
        } else {
            luaL_tolstring(L, 2, NULL) ;
            buttonView.alternateTitle = [skin toNSObjectAtIndex:-1] ;
            lua_pop(L, 1) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int button_bordered(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMButton *buttonView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, buttonView.bordered) ;
    } else {
        buttonView.bordered = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int button_transparent(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMButton *buttonView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, buttonView.transparent) ;
    } else {
        buttonView.transparent = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int button_borderOnHover(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMButton *buttonView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, buttonView.showsBorderOnlyWhileMouseInside) ;
    } else {
        buttonView.showsBorderOnlyWhileMouseInside = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int button_allowsMixedState(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMButton *buttonView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, buttonView.allowsMixedState) ;
    } else {
        buttonView.allowsMixedState = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int button_bezelStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMButton *buttonView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *bezelStyle = @(buttonView.bezelStyle) ;
        NSArray *temp = [BEZEL_STYLES allKeysForObject:bezelStyle];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized bezel style %@ -- notify developers", USERDATA_TAG, bezelStyle]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *bezelStyle = BEZEL_STYLES[key] ;
        if (bezelStyle) {
            buttonView.bezelStyle = [bezelStyle unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[BEZEL_STYLES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMButton(lua_State *L, id obj) {
    ASMButton *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMButton *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toASMButtonFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMButton *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMButton, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMButton *obj = [skin luaObjectAtIndex:1 toClass:"ASMButton"] ;
    NSString *title = NSStringFromRect(obj.frame) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMButton *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMButton"] ;
        ASMButton *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMButton"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMButton *obj = get_objectFromUserdata(__bridge_transfer ASMButton, L, 1, USERDATA_TAG) ;
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
    {"title",            button_title},
    {"alternateTitle",   button_alternateTitle},
    {"callback",         button_callback},
    {"bordered",         button_bordered},
    {"transparent",      button_transparent},
    {"borderOnHover",    button_borderOnHover},
    {"allowsMixedState", button_allowsMixedState},
    {"bezelStyle",       button_bezelStyle},

    {"__tostring",       userdata_tostring},
    {"__eq",             userdata_eq},
    {"__gc",             userdata_gc},
    {NULL,               NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", button_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_canvas_button_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASMButton         forClass:"ASMButton"];
    [skin registerLuaObjectHelper:toASMButtonFromLua forClass:"ASMButton"
                                             withUserdataMapping:USERDATA_TAG];

    return 1;
}
