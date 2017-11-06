
/// === hs._asm.guitk.element.slider ===
///
/// Provides a slider element for use with `hs._asm.guitk`. Sliders are horizontal or vertical bars representing a range of numeric values which can be selected by adjusting the position of the knob on the slider.
///
/// * This submodule inherits methods from `hs._asm.guitk.element._control` and you should consult its documentation for additional methods which may be used.
/// * This submodule inherits methods from `hs._asm.guitk.element._view` and you should consult its documentation for additional methods which may be used.

@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.guitk.element.slider" ;
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSASMGUITKElementSlider : NSSlider
@property int selfRefCount ;
@property int callbackRef ;
@end

@implementation HSASMGUITKElementSlider

- (instancetype)initWithFrame:(NSRect)frameRect {
    @try {
        self = [super initWithFrame:frameRect] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:new - %@", USERDATA_TAG, exception.reason]] ;
        self = nil ;
    }

    if (self) {
        _callbackRef    = LUA_NOREF ;
        _selfRefCount   = 0 ;

        self.target     = self ;
        self.action     = @selector(performCallback:) ;
        self.continuous = false ;
    }
    return self ;
}

- (void)callbackHamster:(NSArray *)messageParts { // does the "heavy lifting"
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        for (id part in messageParts) [skin pushNSObject:part] ;
        if (![skin protectedCallAndTraceback:(int)messageParts.count nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:callback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    } else {
        // allow next responder a chance since we don't have a callback set
        id nextInChain = [self nextResponder] ;
        if (nextInChain) {
            SEL passthroughCallback = NSSelectorFromString(@"performPassthroughCallback:") ;
            if ([nextInChain respondsToSelector:passthroughCallback]) {
                [nextInChain performSelectorOnMainThread:passthroughCallback
                                              withObject:messageParts
                                           waitUntilDone:YES] ;
            }
        }
    }
}

- (void)performCallback:(__unused id)sender {
    [self callbackHamster:@[ self, @(self.doubleValue) ]] ;
}

@end

#pragma mark - Module Functions

static int slider_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSASMGUITKElementSlider *slider = [[HSASMGUITKElementSlider alloc] initWithFrame:frameRect];
    if (slider) {
        if (lua_gettop(L) != 1) [slider setFrameSize:[slider fittingSize]] ;
        [skin pushNSObject:slider] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods

static int slider_allowsTickMarkValuesOnly(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementSlider *slider = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, slider.allowsTickMarkValuesOnly) ;
    } else {
        slider.allowsTickMarkValuesOnly = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int slider_altIncrementValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementSlider *slider = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, slider.altIncrementValue) ;
    } else {
        lua_Number value = lua_tonumber(L, 2) ;
        slider.altIncrementValue = (value < 0) ? 0 : value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int slider_currentValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementSlider *slider = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, slider.doubleValue) ;
    } else {
        slider.doubleValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return  1 ;
}

static int slider_maxValuee(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementSlider *slider = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, slider.maxValue) ;
    } else {
        slider.maxValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int slider_minValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementSlider *slider = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, slider.minValue) ;
    } else {
        slider.minValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}
static int slider_numberOfTickMarks(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementSlider *slider = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, slider.numberOfTickMarks) ;
    } else {
        NSInteger marks = lua_tointeger(L, 2) ;
        slider.numberOfTickMarks = (marks < 0) ? 0 : marks ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int slider_sliderType(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementSlider *slider = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        switch(slider.sliderType) {
            case NSSliderTypeCircular:
                lua_pushstring(L, "circular") ;
                break ;
            case NSSliderTypeLinear:
                lua_pushstring(L, "linear") ;
                break ;
            default:
                lua_pushstring(L, [[NSString stringWithFormat:@"unrecognized sliderType:%lu", slider.sliderType] UTF8String]) ;
                break ;
        }
    } else {
        NSString *position = [skin toNSObjectAtIndex:2] ;
        if ([position isEqualToString:@"circular"]) {
            slider.sliderType = NSSliderTypeCircular ;
        } else if ([position isEqualToString:@"linear"]) {
            slider.sliderType = NSSliderTypeLinear ;
        } else {
            luaL_argerror(L, 2, "expected circular or linear") ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int slider_tickMarkPosition(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementSlider *slider = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        switch(slider.tickMarkPosition) {
//             case NSTickMarkPositionAbove:
            case NSTickMarkPositionLeading:
                lua_pushstring(L, "leading") ;
                break ;
//             case NSTickMarkPositionBelow:
            case NSTickMarkPositionTrailing:
                lua_pushstring(L, "trailing") ;
                break ;
            default:
                lua_pushstring(L, [[NSString stringWithFormat:@"unrecognized tickMarkPosition:%lu", slider.tickMarkPosition] UTF8String]) ;
                break ;
        }
    } else {
        NSString *position = [skin toNSObjectAtIndex:2] ;
        if ([position isEqualToString:@"leading"]) {
            slider.tickMarkPosition = NSTickMarkPositionLeading ;
        } else if ([position isEqualToString:@"trailing"]) {
            slider.tickMarkPosition = NSTickMarkPositionTrailing ;
        } else {
            luaL_argerror(L, 2, "expected leading or trailing") ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int slider_trackFillColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementSlider *slider = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
        if ([slider respondsToSelector:@selector(trackFillColor)]) {
            [skin pushNSObject:slider.trackFillColor] ;
        } else {
            lua_pushnil(L) ;
        }
#pragma clang diagnostic pop
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
        if ([slider respondsToSelector:@selector(trackFillColor)]) {
            slider.trackFillColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:trackFillColor - requries macOS 10.12.1 or later", USERDATA_TAG]] ;
        }
#pragma clang diagnostic pop
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int slider_knobThickness(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMGUITKElementSlider *slider = [skin toNSObjectAtIndex:1] ;

    lua_pushnumber(L, slider.knobThickness) ;
    return 1 ;
}

static int slider_vertical(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementSlider *slider = [skin toNSObjectAtIndex:1] ;

// TODO: Test in 10.10 -- docs say this has been valid since 10.0, but the compiler disagrees
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, slider.vertical) ;
    } else {
        slider.vertical = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
#pragma clang diagnostic pop
    return 1 ;
}

static int slider_tickMarkValueAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSASMGUITKElementSlider *slider = [skin toNSObjectAtIndex:1] ;
    lua_Integer index = lua_tointeger(L, 2) ;

    NSInteger numberOfTickMarks = slider.numberOfTickMarks ;
    if (index < 1 || index > numberOfTickMarks) {
        if (numberOfTickMarks > 0) {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index must be between 1 and %ld", numberOfTickMarks] UTF8String]) ;
        } else {
            return luaL_argerror(L, 2, "slider does not have any tick marks") ;
        }
    }
    lua_pushnumber(L, [slider tickMarkValueAtIndex:index - 1]) ;
    return 1 ;
}

static int slider_closestTickMarkValueToValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK] ;
    HSASMGUITKElementSlider *slider = [skin toNSObjectAtIndex:1] ;

    lua_pushnumber(L, [slider closestTickMarkValueToValue:lua_tonumber(L, 2)]) ;
    return 1 ;
}

static int slider_rectOfTickMarkAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSASMGUITKElementSlider *slider = [skin toNSObjectAtIndex:1] ;
    lua_Integer index = lua_tointeger(L, 2) ;

    NSInteger numberOfTickMarks = slider.numberOfTickMarks ;
    if (index < 1 || index > numberOfTickMarks) {
        if (numberOfTickMarks > 0) {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index must be between 1 and %ld", numberOfTickMarks] UTF8String]) ;
        } else {
            return luaL_argerror(L, 2, "slider does not have any tick marks") ;
        }
    }
    [skin pushNSRect:[slider rectOfTickMarkAtIndex:index - 1]] ;
    return 1 ;
}

// not really much use unless we add mouse tracking to elements and not just the manager
static int slider_indexOfTickMarkAtPoint(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    HSASMGUITKElementSlider *slider = [skin toNSObjectAtIndex:1] ;

    NSInteger tickMark = [slider indexOfTickMarkAtPoint:[skin tableToPointAtIndex:2]] ;
    if (tickMark == NSNotFound) {
        lua_pushnil(L) ;
    } else {
        lua_pushinteger(L, tickMark + 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSASMGUITKElementSlider(lua_State *L, id obj) {
    HSASMGUITKElementSlider *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSASMGUITKElementSlider *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toHSASMGUITKElementSliderFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMGUITKElementSlider *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSASMGUITKElementSlider, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMGUITKElementSlider *obj = [skin luaObjectAtIndex:1 toClass:"HSASMGUITKElementSlider"] ;
    NSString *title = NSStringFromRect(obj.frame) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSASMGUITKElementSlider *obj1 = [skin luaObjectAtIndex:1 toClass:"HSASMGUITKElementSlider"] ;
        HSASMGUITKElementSlider *obj2 = [skin luaObjectAtIndex:2 toClass:"HSASMGUITKElementSlider"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSASMGUITKElementSlider *obj = get_objectFromUserdata(__bridge_transfer HSASMGUITKElementSlider, L, 1, USERDATA_TAG) ;
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
    {"tickMarksOnly",        slider_allowsTickMarkValuesOnly},
    {"altClickIncrement",    slider_altIncrementValue},
    {"max",                  slider_maxValuee},
    {"min",                  slider_minValue},
    {"tickMarks",            slider_numberOfTickMarks},
    {"type",                 slider_sliderType},
    {"tickMarkLocation",     slider_tickMarkPosition},
    {"trackFillColor",       slider_trackFillColor},
    {"knobThickness",        slider_knobThickness},
    {"vertical",             slider_vertical},
    {"value",                slider_currentValue},
    {"valueOfTickMark",      slider_tickMarkValueAtIndex},
    {"closestTickMarkValue", slider_closestTickMarkValueToValue},
    {"rectOfTickMark",       slider_rectOfTickMarkAtIndex},
    {"indexOfTickMarkAt",    slider_indexOfTickMarkAtPoint},

    {"__tostring",           userdata_tostring},
    {"__eq",                 userdata_eq},
    {"__gc",                 userdata_gc},
    {NULL,                   NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", slider_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_guitk_element_slider(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSASMGUITKElementSlider         forClass:"HSASMGUITKElementSlider"];
    [skin registerLuaObjectHelper:toHSASMGUITKElementSliderFromLua forClass:"HSASMGUITKElementSlider"
                                             withUserdataMapping:USERDATA_TAG];

    // allow hs._asm.guitk.manager:elementProperties to get/set these
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"tickMarksOnly",
        @"altClickIncrement",
        @"max",
        @"min",
        @"tickMarks",
        @"type",
        @"tickMarkLocation",
        @"trackFillColor",
        @"vertical",
        @"value",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ;
//     lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritView") ;
    lua_pop(L, 1) ;

    return 1;
}
