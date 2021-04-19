// TODO: See addCursorRect:cursor: for NSView... probably have to modify canvas for this to work

@import Cocoa ;
@import LuaSkin ;

// TODO:
//    test (so far, I've just tested that it will compile)
//    document
//    add canvas integration for mouseEnter/exit

static const char * const USERDATA_TAG    = "hs.mouse.cursor" ;
static int                refTable        = LUA_NOREF;
static BOOL               cursorHidden    = NO ;
static NSMutableSet       *createdCursors ;
static NSDictionary       *systemCursors  ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSCursorObject : NSObject
@property int      selfRefCount ;
@property NSCursor *cursor ;
@end

@implementation HSCursorObject
- (instancetype)initWithCursor:(NSCursor *)cursor {
    self = [super init] ;
    if (self) {
        _selfRefCount = 0 ;
        _cursor       = cursor ;

        [createdCursors addObject:self] ;
    }
    return self ;
}
@end

#pragma mark - Module Functions

static int cursor_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, "hs.image", LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    NSImage *image  = [skin toNSObjectAtIndex:1] ;
    NSPoint hotSpot = NSMakePoint(image.size.width / 2, image.size.height / 2) ;
    if (lua_gettop(L) == 2) hotSpot = [skin tableToPointAtIndex:2] ;
    NSCursor *cursor = [[NSCursor alloc] initWithImage:image hotSpot:hotSpot] ;
    if (cursor) {
        HSCursorObject *cursorObject = [[HSCursorObject alloc] initWithCursor:cursor] ;
        [skin pushNSObject:cursorObject] ;
    } else {
        return luaL_argerror(L, 1, "unable to create cursor from image") ;
    }
    return 1 ;
}

static int cursor_systemCursor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *cursorName = [skin toNSObjectAtIndex:1] ;
    NSCursor *cursor = systemCursors[cursorName] ;
    if (cursor) {
        [skin pushNSObject:cursor] ;
    } else {
        return luaL_argerror(L, 1, "unrecognized predefined cursor name specified") ;
    }
    return 1 ;
}

static int cursor_hide(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 1) {
        BOOL flag = lua_toboolean(L, 1) ;
        [NSCursor setHiddenUntilMouseMoves:flag] ;
    } else {
        if (!cursorHidden) {
            [NSCursor hide] ;
            cursorHidden = YES ;
        }
    }
    return 0 ;
}

static int cursor_unhide(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    if (cursorHidden) {
        [NSCursor unhide] ;
        cursorHidden = YES ;
    }
    return 0 ;
}

static int cursor_visible(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushboolean(L, cursorHidden) ;
    return 1 ;
}

static int cursor_pop(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    [NSCursor pop] ;
    return 0 ;
}

static int cursor_currentCursor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    BOOL system = (lua_gettop(L) == 1) ? lua_toboolean(L, 1) : NO ;
    NSCursor *cursor = system ? [NSCursor currentSystemCursor] : [NSCursor currentCursor] ;
    if (cursor) {
        [skin pushNSObject:cursor] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int cursor_canvas_enableRects(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, "hs.canvas", LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSView   *canvasView   = [skin toNSObjectAtIndex:1] ;
    NSWindow *canvasWindow = canvasView.window ;

//    // so we can build without having to link against canvas module itself
//     NSWindow          *canvasWindow ;
//     SEL               selector    = NSSelectorFromString(@"window") ;
//     NSMethodSignature *signature  = [NSView instanceMethodSignatureForSelector:selector] ;
//     NSInvocation      *invocation = [NSInvocation invocationWithMethodSignature:signature] ;
//     [invocation setTarget:canvasView] ;
//     [invocation setSelector:selector] ;
//     [invocation invoke] ;
//     [invocation getReturnValue:&canvasWindow] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, canvasWindow.areCursorRectsEnabled) ;
    } else {
        if (lua_toboolean(L, 2)) {
            [canvasWindow enableCursorRects] ;
        } else {
            [canvasWindow disableCursorRects] ;
        }
        [skin pushNSObject:canvasView] ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int cursor_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCursorObject *cursorObject = [skin toNSObjectAtIndex:1] ;
    NSCursor       *cursor       = cursorObject.cursor ;

    __block NSString *cursorName = @"custom" ;
    [systemCursors enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSCursor *obj, BOOL *stop) {
        if ([obj isEqualTo:cursor]) {
            cursorName = key ;
            *stop = YES ;
        }
    }] ;
    [skin pushNSObject:cursorName] ;
    return 1 ;
}

static int cursor_image(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCursorObject *cursorObject = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:cursorObject.cursor.image] ;
    return 1 ;
}

static int cursor_hotSpot(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCursorObject *cursorObject = [skin toNSObjectAtIndex:1] ;
    [skin pushNSPoint:cursorObject.cursor.hotSpot] ;
    return 1 ;
}

static int cursor_set(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCursorObject *cursorObject = [skin toNSObjectAtIndex:1] ;
    [cursorObject.cursor set] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int cursor_push(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCursorObject *cursorObject = [skin toNSObjectAtIndex:1] ;
    [cursorObject.cursor push] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int cursor_canvas_cursorRect(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TUSERDATA, "hs.canvas",
                    LS_TTABLE,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSCursorObject *cursorObject = [skin toNSObjectAtIndex:1] ;
    NSCursor       *cursor       = cursorObject.cursor ;
    NSView         *canvasView   = [skin toNSObjectAtIndex:2] ;
    NSRect         cursorRect    = [skin tableToRectAtIndex:3] ;
    BOOL           add           = (lua_gettop(L) > 3) ? lua_toboolean(L, 4) : YES ;

    if (add) {
        [canvasView addCursorRect:cursorRect cursor:cursor] ;
        [cursor setOnMouseEntered:YES] ;
    } else {
        [canvasView removeCursorRect:cursorRect cursor:cursor] ;
        [cursor setOnMouseEntered:NO] ;
    }

    [skin pushNSObject:canvasView] ;
    return 1 ;
}

#pragma mark - Module Constants

static int cursor_pushSystemCursorNames(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    systemCursors = @{
        @"arrow"               : [NSCursor arrowCursor],
        @"contextualMenu"      : [NSCursor contextualMenuCursor],
        @"closedHand"          : [NSCursor closedHandCursor],
        @"crosshair"           : [NSCursor crosshairCursor],
        @"disappearingItem"    : [NSCursor disappearingItemCursor],
        @"dragCopy"            : [NSCursor dragCopyCursor],
        @"dragLink"            : [NSCursor dragLinkCursor],
        @"IBeam"               : [NSCursor IBeamCursor],
        @"openHand"            : [NSCursor openHandCursor],
        @"operationNotAllowed" : [NSCursor operationNotAllowedCursor],
        @"pointingHand"        : [NSCursor pointingHandCursor],
        @"resizeDown"          : [NSCursor resizeDownCursor],
        @"resizeLeft"          : [NSCursor resizeLeftCursor],
        @"resizeLeftRight"     : [NSCursor resizeLeftRightCursor],
        @"resizeRight"         : [NSCursor resizeRightCursor],
        @"resizeUp"            : [NSCursor resizeUpCursor],
        @"resizeUpDown"        : [NSCursor resizeUpDownCursor],
        @"verticalLayoutIBeam" : [NSCursor IBeamCursorForVerticalLayout]
    } ;

    [skin pushNSObject:[systemCursors allKeys]] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushNSCursor(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSCursor *cursor = obj ;
    __block HSCursorObject *value = nil ;
    [createdCursors enumerateObjectsUsingBlock:^(HSCursorObject *member, BOOL *stop) {
        if ([member.cursor isEqualTo:cursor]) {
            value = member ;
            *stop = YES ;
        }
    }] ;
    if (!value) value = [[HSCursorObject alloc] initWithCursor:cursor] ;
    [skin pushNSObject:value] ;
    return 1 ;
}

static int pushHSCursorObject(lua_State *L, id obj) {
    HSCursorObject *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSCursorObject *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSCursorObjectFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSCursorObject *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSCursorObject, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSCursorObject *obj    = [skin luaObjectAtIndex:1 toClass:"HSCursorObject"] ;
    NSCursor       *cursor = obj.cursor ;

    __block NSString *title = @"*custom*" ;
    [systemCursors enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSCursor *object, BOOL *stop) {
        if ([object isEqualTo:cursor]) {
            title = key ;
            *stop = YES ;
        }
    }] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSCursorObject *obj1 = [skin luaObjectAtIndex:1 toClass:"HSCursorObject"] ;
        HSCursorObject *obj2 = [skin luaObjectAtIndex:2 toClass:"HSCursorObject"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSCursorObject *obj = get_objectFromUserdata(__bridge_transfer HSCursorObject, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            [createdCursors removeObject:obj] ;
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    if (cursorHidden) [NSCursor unhide] ;
    cursorHidden = NO ;
    [createdCursors removeAllObjects] ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"image",               cursor_image},
    {"hotSpot",             cursor_hotSpot},
    {"set",                 cursor_set},
    {"push",                cursor_push},
    {"name",                cursor_name},

    {"cursorRectForCanvas", cursor_canvas_cursorRect},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",               cursor_new},
    {"systemCursor",      cursor_systemCursor},
    {"show",              cursor_unhide},
    {"hide",              cursor_hide},
    {"visible",           cursor_visible},
    {"pop",               cursor_pop},
    {"currentCursor",     cursor_currentCursor},

    {"canvasCursorRects", cursor_canvas_enableRects},

    {NULL,                NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_mouse_cursor_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    createdCursors = [NSMutableSet set] ;
    cursorHidden   = NO ;

    cursor_pushSystemCursorNames(L) ; lua_setfield(L, -2, "systemCursorNames") ;

    [skin registerPushNSHelper:pushHSCursorObject         forClass:"HSCursorObject"];
    [skin registerLuaObjectHelper:toHSCursorObjectFromLua forClass:"HSCursorObject"
                                               withUserdataMapping:USERDATA_TAG];

    [skin registerPushNSHelper:pushNSCursor               forClass:"NSCursor"];

    return 1;
}
