@import Cocoa ;
@import LuaSkin ;
@import QuartzCore ;

#define USERDATA_TAG "hs._asm.canvas.progress"
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#define PROGRESS_SIZE @{ \
    @"regular" : @(NSRegularControlSize), \
    @"small"   : @(NSSmallControlSize), \
    @"mini"    : @(NSMiniControlSize), \
}

#define PROGRESS_TINT @{ \
    @"default"  : @(NSDefaultControlTint), \
    @"blue"     : @(NSBlueControlTint), \
    @"graphite" : @(NSGraphiteControlTint), \
    @"clear"    : @(NSClearControlTint), \
}

#pragma mark - Support Functions and Classes

@interface ASMProgressView : NSProgressIndicator
@end

@implementation ASMProgressView
- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.usesThreadedAnimation = YES ;
    }
    return self;
}

- (BOOL)isFlipped {
    return YES ;
}

// Code from http://stackoverflow.com/a/32396595
//
// Color works for spinner (both indeterminate and determinate) and partially for bar:
//    indeterminate bar becomes a solid, un-animating color; determinate bar looks fine.
- (void)setCustomColor:(NSColor *)aColor {
    CIFilter *colorPoly = [CIFilter filterWithName:@"CIColorPolynomial"];
    [colorPoly setDefaults];

    CIVector *redVector ;
    CIVector *greenVector ;
    CIVector *blueVector ;
    if (self.style == NSProgressIndicatorSpinningStyle) {
        redVector   = [CIVector vectorWithX:aColor.redComponent   Y:0 Z:0 W:0];
        greenVector = [CIVector vectorWithX:aColor.greenComponent Y:0 Z:0 W:0];
        blueVector  = [CIVector vectorWithX:aColor.blueComponent  Y:0 Z:0 W:0];
    } else {
        redVector   = [CIVector vectorWithX:0 Y:aColor.redComponent   Z:0 W:0];
        greenVector = [CIVector vectorWithX:0 Y:aColor.greenComponent Z:0 W:0];
        blueVector  = [CIVector vectorWithX:0 Y:aColor.blueComponent  Z:0 W:0];
    }
    [colorPoly setValue:redVector   forKey:@"inputRedCoefficients"];
    [colorPoly setValue:greenVector forKey:@"inputGreenCoefficients"];
    [colorPoly setValue:blueVector  forKey:@"inputBlueCoefficients"];
    [self setContentFilters:[NSArray arrayWithObjects:colorPoly, nil]];
}

@end

#pragma mark - Module Functions

static int progressViewNew(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    ASMProgressView *theView = [[ASMProgressView alloc] initWithFrame:frameRect];
    [skin pushNSObject:theView] ;
    return 1 ;
}

#pragma mark - Module Methods

/// hs._asm.canvas.progress:start() -> progressObject
/// Method
/// If the progress indicator is indeterminate, starts the animation for the indicator.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the progress indicator object
///
/// Notes:
///  * This method has no effect if the indicator is not indeterminate.
static int progressViewStart(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    ASMProgressView *theView = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    [theView startAnimation:nil];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.canvas.progress:stop() -> progressObject
/// Method
/// If the progress indicator is indeterminate, stops the animation for the indicator.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the progress indicator object
///
/// Notes:
///  * This method has no effect if the indicator is not indeterminate.
static int progressViewStop(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    ASMProgressView *theView = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    [theView stopAnimation:nil];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.canvas.progress:threaded([flag]) -> progressObject | current value
/// Method
/// Get or set whether or not the animation for an indicator occurs in a separate process thread.
///
/// Parameters:
///  * flag - an optional boolean indicating whether or not the animation for the indicator should occur in a separate thread.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is true.
///  * If this flag is set to false, the indicator animation speed will fluctuate as Hammerspoon performs other activities, though not consistently enough to provide a reliable "activity level" feedback indicator.
static int progressViewThreaded(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    ASMProgressView *theView = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.usesThreadedAnimation = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, theView.usesThreadedAnimation) ;
    }
    return 1;
}

/// hs._asm.canvas.progress:indeterminate([flag]) -> progressObject | current value
/// Method
/// Get or set whether or not the progress indicator is indeterminate.  A determinate indicator displays how much of the task has been completed. An indeterminate indicator shows simply that the application is busy.
///
/// Parameters:
///  * flag - an optional boolean indicating whether or not the indicator is indeterminate.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is true.
///  * If this setting is set to false, you should also take a look at [hs._asm.canvas.progress:min](#min) and [hs._asm.canvas.progress:max](#max), and periodically update the status with [hs._asm.canvas.progress:value](#value) or [hs._asm.canvas.progress:increment](#increment)
static int progressViewIndeterminate(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    ASMProgressView *theView = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.indeterminate = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, theView.indeterminate) ;
    }
    return 1;
}

/// hs._asm.canvas.progress:bezeled([flag]) -> progressObject | current value
/// Method
/// Get or set whether or not the progress indicator’s frame has a three-dimensional bezel.
///
/// Parameters:
///  * flag - an optional boolean indicating whether or not the indicator's frame is bezeled.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is true.
///  * In my testing, this setting does not seem to have much, if any, effect on the visual aspect of the indicator and is provided in this module in case this changes in a future OS X update (there are some indications that it may have had an effect in previous versions).
static int progressViewBezeled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    ASMProgressView *theView = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.bezeled = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, theView.bezeled) ;
    }
    return 1;
}

/// hs._asm.canvas.progress:visibleWhenStopped([flag]) -> progressObject | current value
/// Method
/// Get or set whether or not the progress indicator is visible when animation has been stopped.
///
/// Parameters:
///  * flag - an optional boolean indicating whether or not the progress indicator is visible when animation has stopped.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is true.
static int progressViewDisplayedWhenStopped(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    ASMProgressView *theView = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.displayedWhenStopped = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, theView.displayedWhenStopped) ;
    }
    return 1;
}

/// hs._asm.canvas.progress:circular([flag]) -> progressObject | current value
/// Method
/// Get or set whether or not the progress indicator is circular or a in the form of a progress bar.
///
/// Parameters:
///  * flag - an optional boolean indicating whether or not the indicator is circular (true) or a progress bar (false)
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is false.
///  * An indeterminate circular indicator is displayed as the spinning star seen during system startup.
///  * A determinate circular indicator is displayed as a pie chart which fills up as its value increases.
///  * An indeterminate progress indicator is displayed as a rounded rectangle with a moving pulse.
///  * A determinate progress indicator is displayed as a rounded rectangle that fills up as its value increases.
static int progressViewCircular(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    ASMProgressView *theView = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.style = (BOOL)lua_toboolean(L, 2) ? NSProgressIndicatorSpinningStyle : NSProgressIndicatorBarStyle ;
//         [theView sizeToFit] ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, (theView.style == NSProgressIndicatorSpinningStyle)) ;
    }
    return 1;
}

/// hs._asm.canvas.progress:value([value]) -> progressObject | current value
/// Method
/// Get or set the current value of the progress indicator's completion status.
///
/// Parameters:
///  * value - an optional number indicating the current extent of the progress.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default value for this is 0.0
///  * This value has no effect on the display of an indeterminate progress indicator.
///  * For a determinate indicator, this will affect how "filled" the bar or circle is.  If the value is lower than [hs._asm.canvas.progress:min](#min), then it will be reset to that value.  If the value is greater than [hs._asm.canvas.progress:max](#max), then it will be reset to that value.
static int progressViewValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    ASMProgressView *theView = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.doubleValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnumber(L, theView.doubleValue) ;
    }
    return 1;
}

/// hs._asm.canvas.progress:min([value]) -> progressObject | current value
/// Method
/// Get or set the minimum value (the value at which the progress indicator should display as empty) for the progress indicator.
///
/// Parameters:
///  * value - an optional number indicating the minimum value.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default value for this is 0.0
///  * This value has no effect on the display of an indeterminate progress indicator.
///  * For a determinate indicator, the behavior is undefined if this value is greater than [hs._asm.canvas.progress:max](#max).
static int progressViewMin(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    ASMProgressView *theView = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.minValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnumber(L, theView.minValue) ;
    }
    return 1;
}

/// hs._asm.canvas.progress:max([value]) -> progressObject | current value
/// Method
/// Get or set the maximum value (the value at which the progress indicator should display as full) for the progress indicator.
///
/// Parameters:
///  * value - an optional number indicating the maximum value.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default value for this is 100.0
///  * This value has no effect on the display of an indeterminate progress indicator.
///  * For a determinate indicator, the behavior is undefined if this value is less than [hs._asm.canvas.progress:min](#min).
static int progressViewMax(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    ASMProgressView *theView = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.maxValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnumber(L, theView.maxValue) ;
    }
    return 1;
}

/// hs._asm.canvas.progress:increment(value) -> progressObject | current value
/// Method
/// Increment the current value of a progress indicator's progress by the amount specified.
///
/// Parameters:
///  * value - the value by which to increment the progress indicator's current value.
///
/// Returns:
///  * the progress indicator object
///
/// Notes:
///  * Programmatically, this is equivalent to `hs._asm.canvas.progress:value(hs._asm.canvas.progress:value() + value)`, but is faster.
static int progressViewIncrement(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    ASMProgressView *theView = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK] ;
    [theView incrementBy:lua_tonumber(L, 2)] ;
    lua_pushvalue(L, 1) ;
    return 1;
}

/// hs._asm.canvas.progress:tint([tint]) -> progressObject | current value
/// Method
/// Get or set the indicator's tint.
///
/// Parameters:
///  * tint - an optional string specifying the tint of the progress indicator.  May be one of "Default", "blue", "graphite", or "clear".
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is "default".
///  * In my testing, this setting does not seem to have much, if any, effect on the visual aspect of the indicator and is provided in this module in case this changes in a future OS X update (there are some indications that it may have had an effect in previous versions).
static int progressViewControlTint(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMProgressView *theView = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;

    if (lua_gettop(L) == 2) {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *controlTint = PROGRESS_TINT[key] ;
        if (controlTint) {
            theView.controlTint = [controlTint unsignedIntegerValue] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[PROGRESS_TINT allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        NSNumber *controlTint = @(theView.controlTint) ;
        NSArray *temp = [PROGRESS_TINT allKeysForObject:controlTint];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized control tint %@ -- notify developers", USERDATA_TAG, controlTint]] ;
            lua_pushnil(L) ;
        }
    }
    return 1;


}

/// hs._asm.canvas.progress:indicatorSize([size]) -> progressObject | current value
/// Method
/// Get or set the indicator's size.
///
/// Parameters:
///  * size - an optional string specifying the size of the progress indicator object.  May be one of "regular", "small", or "mini".
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is "regular".
///  * For circular indicators, the sizes seem to be 32x32, 16x16, and 10x10 in 10.11.
///  * For bar indicators, the height seems to be 20 and 12; the mini size seems to be ignored, at least in 10.11.
static int progressViewControlSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMProgressView *theView = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;

    if (lua_gettop(L) == 2) {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *controlSize = PROGRESS_SIZE[key] ;
        if (controlSize) {
            theView.controlSize = [controlSize unsignedIntegerValue] ;
//             [theView sizeToFit] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[PROGRESS_SIZE allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        NSNumber *controlSize = @(theView.controlSize) ;
        NSArray *temp = [PROGRESS_SIZE allKeysForObject:controlSize];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized control size %@ -- notify developers", USERDATA_TAG, controlSize]] ;
            lua_pushnil(L) ;
        }
    }
    return 1;
}

/// hs._asm.canvas.progress:color(color) -> progressObject
/// Method
/// Sets the fill color for a progress indicator.
///
/// Parameters:
///  * color - a table specifying a color as defined in `hs.drawing.color` indicating the color to use for the progress indicator.
///
/// Returns:
///  * the progress indicator object
///
/// Notes:
///  * This method is not based upon the methods inherent in the NSProgressIndicator Objective-C class, but rather on code found at http://stackoverflow.com/a/32396595 utilizing a CIFilter object to adjust the view's output.
///  * Because the filter must be applied differently depending upon the progress indicator style, make sure to invoke this method *after* [hs._asm.canvas.progress:circular](#circular).
static int progressViewSetCustomColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    ASMProgressView *theView = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;

    NSColor *theColor = [[skin luaObjectAtIndex:2 toClass:"NSColor"] colorUsingColorSpaceName:NSCalibratedRGBColorSpace] ;
    if (theColor) {
        [theView setCustomColor:theColor] ;
    } else {
        return luaL_error(L, "color must be expressible as RGB") ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMProgressView(lua_State *L, id obj) {
    ASMProgressView *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMProgressView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toASMProgressViewFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared]  ;
    ASMProgressView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMProgressView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    ASMProgressView *obj = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;
    NSString *title = nil ;
    if ([obj isIndeterminate]) {
        title = @"indeterminate" ;
    } else {
        title = [NSString stringWithFormat:@"@%.2f of [%.2f, %.2f]", obj.doubleValue,
                                                                     obj.minValue,
                                                                     obj.maxValue] ;
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared]  ;
        ASMProgressView *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMProgressView"] ;
        ASMProgressView *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMProgressView"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMProgressView *obj = get_objectFromUserdata(__bridge_transfer ASMProgressView, L, 1, USERDATA_TAG) ;
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
    {"start",              progressViewStart},
    {"stop",               progressViewStop},
    {"threaded",           progressViewThreaded},
    {"indeterminate",      progressViewIndeterminate},
    {"circular",           progressViewCircular},
    {"bezeled",            progressViewBezeled},
    {"visibleWhenStopped", progressViewDisplayedWhenStopped},
    {"value",              progressViewValue},
    {"min",                progressViewMin},
    {"max",                progressViewMax},
    {"increment",          progressViewIncrement},
    {"indicatorSize",      progressViewControlSize},
    {"tint",               progressViewControlTint},
    {"color",              progressViewSetCustomColor},

    {"__tostring",         userdata_tostring},
    {"__eq",               userdata_eq},
    {"__gc",               userdata_gc},
    {NULL,                 NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", progressViewNew},

    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_canvas_progress_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASMProgressView         forClass:"ASMProgressView"];
    [skin registerLuaObjectHelper:toASMProgressViewFromLua forClass:"ASMProgressView"
                                             withUserdataMapping:USERDATA_TAG];

    return 1;
}
