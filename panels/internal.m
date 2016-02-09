#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG  "hs._asm.panels"
static int refTable = LUA_NOREF ;

// #define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSColorPanel : NSObject
@property int callbackRef ;
@end

@implementation HSColorPanel
- (instancetype)init {
    self = [super init] ;
    if (self) {
        _callbackRef = LUA_NOREF ;
        NSColorPanel *cp = [NSColorPanel sharedColorPanel];
        [cp setTarget:self];
        [cp setAction:@selector(colorUpdate:)];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(colorClose:)
                                                     name:NSWindowWillCloseNotification
                                                   object:cp] ;
    }
    return self ;
}

- (void)colorClose:(__unused NSNotification*)note {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            NSColorPanel *cp = [NSColorPanel sharedColorPanel];
            [skin pushLuaRef:refTable ref:_callbackRef] ;
            [skin pushNSObject:cp.color] ;
            lua_pushboolean(L, YES) ;
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s: color callback error, %s",
                                                          USERDATA_TAG,
                                                          lua_tostring(L, -1)]] ;
                lua_pop(L, 1) ;
            }
        }) ;
    }
}

- (void)colorUpdate:(NSColorPanel*)colorPanel {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            [skin pushLuaRef:refTable ref:_callbackRef] ;
            [skin pushNSObject:colorPanel.color] ;
            lua_pushboolean(L, NO) ;
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s: color callback error, %s",
                                                          USERDATA_TAG,
                                                          lua_tostring(L, -1)]] ;
                lua_pop(L, 1) ;
            }
        }) ;
    }
}
@end

#pragma mark - Color Panel Functions

static HSColorPanel *panelReceiverObject ;

static int colorPanelCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;

    if (panelReceiverObject.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:panelReceiverObject.callbackRef] ;
    } else {
        lua_pushnil(L) ;
    }
    if (lua_gettop(L) == 2) { // we just added to it...
        // in either case, we need to remove an existing callback, so...
        panelReceiverObject.callbackRef = [skin luaUnref:refTable ref:panelReceiverObject.callbackRef] ;
        if (lua_type(L, 1) == LUA_TFUNCTION) {
            lua_pushvalue(L, 1) ;
            panelReceiverObject.callbackRef = [skin luaRef:refTable] ;
        }
    }
    // return the *last* fn (or nil) so you can save it and re-attach it if something needs to
    // temporarily take the callbacks
    return 1 ;
}

static int colorPanelContinuous(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSColorPanel *cp = [NSColorPanel sharedColorPanel];
    if (lua_gettop(L) == 1) {
        [cp setContinuous:(BOOL)lua_toboolean(L, 1)] ;
    }
    lua_pushboolean(L, cp.continuous) ;
    return 1 ;
}

static int colorPanelShowsAlpha(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSColorPanel *cp = [NSColorPanel sharedColorPanel];
    if (lua_gettop(L) == 1) {
        [cp setShowsAlpha:(BOOL)lua_toboolean(L, 1)] ;
    }
    lua_pushboolean(L, cp.showsAlpha) ;
    return 1 ;
}

static int colorPanelColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    NSColorPanel *cp = [NSColorPanel sharedColorPanel];
    if (lua_gettop(L) == 1) {
        NSColor *theColor = [[LuaSkin shared] luaObjectAtIndex:1 toClass:"NSColor"] ;
        [cp setColor:theColor] ;
    }
    [skin pushNSObject:[cp color]] ;
    return 1 ;
}

static int colorPanelMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSColorPanel *cp = [NSColorPanel sharedColorPanel];
    if (lua_gettop(L) == 1) {
        NSString *theMode = [skin toNSObjectAtIndex:1] ;
        if ([theMode isEqualToString:@"none"]) {
            [cp setMode:NSNoModeColorPanel];
        } else if ([theMode isEqualToString:@"gray"]) {
            [cp setMode:NSGrayModeColorPanel];
        } else if ([theMode isEqualToString:@"RGB"]) {
            [cp setMode:NSRGBModeColorPanel];
        } else if ([theMode isEqualToString:@"CMYK"]) {
            [cp setMode:NSCMYKModeColorPanel];
        } else if ([theMode isEqualToString:@"HSB"]) {
            [cp setMode:NSHSBModeColorPanel];
        } else if ([theMode isEqualToString:@"custom"]) {
            [cp setMode:NSCustomPaletteModeColorPanel];
        } else if ([theMode isEqualToString:@"list"]) {
            [cp setMode:NSColorListModeColorPanel];
        } else if ([theMode isEqualToString:@"wheel"]) {
            [cp setMode:NSWheelModeColorPanel];
        } else if ([theMode isEqualToString:@"crayon"]) {
            [cp setMode:NSCrayonModeColorPanel];
        } else {
            return luaL_error(L, "unknown color panel mode") ;
        }
    }
    switch([cp mode]) {
        case NSNoModeColorPanel:            [skin pushNSObject:@"none"] ; break ;
        case NSGrayModeColorPanel:          [skin pushNSObject:@"gray"] ; break ;
        case NSRGBModeColorPanel:           [skin pushNSObject:@"RGB"] ; break ;
        case NSCMYKModeColorPanel:          [skin pushNSObject:@"CMYK"] ; break ;
        case NSHSBModeColorPanel:           [skin pushNSObject:@"HSB"] ; break ;
        case NSCustomPaletteModeColorPanel: [skin pushNSObject:@"custom"] ; break ;
        case NSColorListModeColorPanel:     [skin pushNSObject:@"list"] ; break ;
        case NSWheelModeColorPanel:         [skin pushNSObject:@"wheel"] ; break ;
        case NSCrayonModeColorPanel:        [skin pushNSObject:@"crayon"] ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"** unrecognized mode:%ld", [cp mode]]] ;
            break ;
    }
    return 1;
}

static int colorPanelAlpha(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushnumber(L, [[NSColorPanel sharedColorPanel] alpha]) ;
    return 1 ;
}

static int colorPanelShow(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    [NSApp orderFrontColorPanel:nil] ;
    return 0 ;
}

static int colorPanelHide(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    [[NSColorPanel sharedColorPanel] close] ;
    return 0 ;
}

static int releaseColorPanelReceiver(__unused lua_State *L) {
    NSColorPanel *cp = [NSColorPanel sharedColorPanel];
    [[NSNotificationCenter defaultCenter] removeObserver:panelReceiverObject
                                                    name:NSWindowWillCloseNotification
                                                  object:cp] ;
    [cp setTarget:nil];
    [cp setAction:nil];
    [cp close];
    panelReceiverObject = nil ;
    return 0 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static luaL_Reg moduleLib[] = {
    {NULL,    NULL}
};

static luaL_Reg colorPanelLib[] = {
    {"alpha",      colorPanelAlpha},
    {"callback",   colorPanelCallback},
    {"color",      colorPanelColor},
    {"continuous", colorPanelContinuous},
    {"mode",       colorPanelMode},
    {"showsAlpha", colorPanelShowsAlpha},
    {"show",       colorPanelShow},
    {"hide",       colorPanelHide},
    {NULL,         NULL}
};

static luaL_Reg module_metaLib[] = {
    {"__gc", releaseColorPanelReceiver},
    {NULL,   NULL}
};

int luaopen_hs__asm_panels_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibrary:moduleLib metaFunctions:module_metaLib] ;

    [NSColorPanel setPickerMask:NSColorPanelAllModesMask] ;
    panelReceiverObject = [[HSColorPanel alloc] init] ;
    luaL_newlib(L, colorPanelLib) ; lua_setfield(L, -2, "color") ;

    return 1;
}
