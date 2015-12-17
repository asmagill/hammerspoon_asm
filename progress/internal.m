#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import <QuartzCore/QuartzCore.h>

#import "../hammerspoon.h"

#define USERDATA_TAG "hs._asm.progress"
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Errors and Logging and with hs.logger

static int logFnRef = LUA_NOREF;

#define _cERROR   "ef"
#define _cWARN    "wf"
#define _cINFO    "f"
#define _cDEBUG   "df"
#define _cVERBOSE "vf"

// allow this to be potentially unused in the module
static int __unused log_to_console(lua_State *L, const char *level, NSString *theMessage) {
    lua_Debug functionDebugObject, callerDebugObject;
    int status = lua_getstack(L, 0, &functionDebugObject);
    status = status + lua_getstack(L, 1, &callerDebugObject);
    NSString *fullMessage = nil ;
    if (status == 2) {
        lua_getinfo(L, "n", &functionDebugObject);
        lua_getinfo(L, "Sl", &callerDebugObject);
        fullMessage = [NSString stringWithFormat:@"%s - %@ (%d:%s)", functionDebugObject.name,
                                                                     theMessage,
                                                                     callerDebugObject.currentline,
                                                                     callerDebugObject.short_src];
    } else {
        fullMessage = [NSString stringWithFormat:@"%s callback - %@", USERDATA_TAG,
                                                                      theMessage];
    }
    // Except for Debug and Verbose, put it into the system logs, may help with troubleshooting
    if (level[0] != 'd' && level[0] != 'v') CLS_NSLOG(@"%-2s:%s: %@", level, USERDATA_TAG, fullMessage);

    // If hs.logger reference set, use it and the level will indicate whether the user sees it or not
    // otherwise we print to the console for everything, just in case we forget to register.
    if (logFnRef != LUA_NOREF) {
        [[LuaSkin shared] pushLuaRef:refTable ref:logFnRef];
        lua_getfield(L, -1, level); lua_remove(L, -2);
    } else {
        lua_getglobal(L, "print");
    }

    lua_pushstring(L, [fullMessage UTF8String]);
    if (![[LuaSkin shared] protectedCallAndTraceback:1 nresults:0]) { return lua_error(L); }
    return 0;
}

static int lua_registerLogForC(__unused lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TTABLE, LS_TBREAK];
    logFnRef = [[LuaSkin shared] luaRef:refTable];
    return 0;
}

// allow this to be potentially unused in the module
static int __unused my_lua_error(lua_State *L, NSString *theMessage) {
    lua_Debug functionDebugObject;
    lua_getstack(L, 0, &functionDebugObject);
    lua_getinfo(L, "n", &functionDebugObject);
    return luaL_error(L, [[NSString stringWithFormat:@"%s:%s - %@", USERDATA_TAG, functionDebugObject.name, theMessage] UTF8String]);
}

NSString *validateString(lua_State *L, int idx) {
    luaL_checkstring(L, idx) ; // convert numbers to a string, since that's what we want
    NSString *theString = [[LuaSkin shared] toNSObjectAtIndex:idx];
    if (![theString isKindOfClass:[NSString class]]) {
        log_to_console(L, _cWARN, @"string not valid UTF8");
        theString = nil;
    }
    return theString;
}

#pragma mark - Support Functions and Classes

@interface HS_asmProgressWindow : NSPanel <NSWindowDelegate>
@end

@implementation HS_asmProgressWindow
- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)windowStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)deferCreation {

    if (!(isfinite(contentRect.origin.x)    && isfinite(contentRect.origin.y) &&
          isfinite(contentRect.size.height) && isfinite(contentRect.size.width))) {
        log_to_console([[LuaSkin shared] L], _cERROR, @"non-finite co-ordinate or size specified") ;
        return nil;
    }

    self = [super initWithContentRect:contentRect
                            styleMask:windowStyle
                              backing:bufferingType
                                defer:deferCreation];

    if (self) {
        [self setDelegate:self];
        contentRect.origin.y = [[NSScreen screens][0] frame].size.height -
                              contentRect.origin.y -
                              contentRect.size.height;
        [self setFrameOrigin:contentRect.origin];

        // Configure the window
        self.releasedWhenClosed = NO;
        self.backgroundColor    = [NSColor colorWithCalibratedWhite:.75 alpha:.75];
        self.opaque             = NO;
        self.hasShadow          = NO;
        self.ignoresMouseEvents = YES;
        self.restorable         = NO;
        self.hidesOnDeactivate  = NO;
        self.animationBehavior  = NSWindowAnimationBehaviorNone;
        self.level              = NSScreenSaverWindowLevel;
    }
    return self;
}

- (BOOL)windowShouldClose:(id __unused)sender {
    return NO;
}
@end

@interface HS_asmProgressView : NSProgressIndicator
@end

@implementation HS_asmProgressView
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

// NSProgressIndicator shrinks to 32x32 at 0,0 for spinning, and 20xcurrentWidth at 0,0 for
// bar; however, changing to spin, then back to bar makes the currentWidth = 32, so here
// we center the object in the rectangle "window" and make it the full width if it's a
// bar.
- (void)centerInWindow {
    NSRect rect = self.frame ;
    NSRect parentRect = self.window.frame ;
    rect.origin.y = (parentRect.size.height - rect.size.height) / 2 ;
    if (self.style == NSProgressIndicatorBarStyle) {
        rect.origin.x = 0.0 ;
        rect.size.width = parentRect.size.width ;
    } else {
        rect.origin.x = (parentRect.size.width - rect.size.width) / 2 ;
    }
    [self setFrame:rect] ;
    lua_State *_L = [[LuaSkin shared] L] ;
    log_to_console(_L, _cDEBUG, [NSString stringWithFormat:@"Window    Rect: %.2fx%.2f+%.2f+%.2f",
                                                          parentRect.size.width, parentRect.size.height,
                                                          parentRect.origin.x, parentRect.origin.y]) ;
    log_to_console(_L, _cDEBUG, [NSString stringWithFormat:@"Indicator Rect: %.2fx%.2f+%.2f+%.2f",
                                                          rect.size.width, rect.size.height,
                                                          rect.origin.x, rect.origin.y]) ;
}

// Code from http://stackoverflow.com/a/32396595
//
// Color works for spinner (both indeterminate and determinate) and mostly for bar:
// indeterminate bar becomes a solid, un-animating color; determinate bar looks fine.
- (void)setCustomColor:(NSColor *)aColor {
    CIFilter *colorPoly = [CIFilter filterWithName:@"CIColorPolynomial"];
    [colorPoly setDefaults];

    CIVector *redVector = [CIVector vectorWithX:aColor.redComponent Y:0 Z:0 W:0];
    CIVector *greenVector = [CIVector vectorWithX:aColor.greenComponent Y:0 Z:0 W:0];
    CIVector *blueVector = [CIVector vectorWithX:aColor.blueComponent Y:0 Z:0 W:0];
    [colorPoly setValue:redVector forKey:@"inputRedCoefficients"];
    [colorPoly setValue:greenVector forKey:@"inputGreenCoefficients"];
    [colorPoly setValue:blueVector forKey:@"inputBlueCoefficients"];
    [self setContentFilters:[NSArray arrayWithObjects:colorPoly, nil]];
}

@end

#pragma mark - Module Functions

/// hs._asm.progress.new(rect) -> progressObject
/// Constructor
/// Create a new progress indicator object at the specified location and size.
///
/// Parameters:
///  * rect - a table containing the rectangular coordinates of the progress indicator and its background.
///
/// Returns:
///  * a progress indicator object
///
/// Notes:
///  * Depending upon the type and size of the indicator, the actual indicator's size varies.  As of 10.11, the observed sizes are:
///    * circular - between 10 and 32 for width and height, depending upon size
///    * bar      - between 12 and 20 for height, depending upon size.
///  * The rectangle defined in this function reflects a rectangle in which the indicator is centered.  This is to facilitate drawing an opaque or semi-transparent "shade" over content, if desired, while performing some task for which the indicator is being used to indicate activity.  This shade is set to a light grey semi-transparent color (defined in `hs.drawing.color` as { white = 0.75, alpha = 0.75 }).
static int newProgressView(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TTABLE, LS_TBREAK];

    NSRect windowRect = [skin tableToRectAtIndex:1];
    HS_asmProgressWindow *theWindow = [[HS_asmProgressWindow alloc] initWithContentRect:windowRect
                                                                              styleMask:NSBorderlessWindowMask
                                                                                backing:NSBackingStoreBuffered
                                                                                  defer:YES];
    if (theWindow) {
        void** windowPtr = lua_newuserdata(L, sizeof(HS_asmProgressWindow *)) ;
        *windowPtr = (__bridge_retained void *)theWindow ;
        luaL_getmetatable(L, USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;

        NSRect viewRect = ((NSView *)theWindow.contentView).bounds ;
        HS_asmProgressView *theView = [[HS_asmProgressView alloc] initWithFrame:viewRect];
        theWindow.contentView = theView;
        [theView setWantsLayer:YES] ;
    } else {
        lua_pushnil(L);
    }
    return 1;
}

#pragma mark - Module Methods

/// hs._asm.progress:show() -> progressObject
/// Method
/// Displays the progress indicator and its background.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the progress indicator object
static int progressViewShow(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    [theWindow makeKeyAndOrderFront:nil];
    [theView centerInWindow] ;
    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.progress:hide() -> progressObject
/// Method
/// Hides the progress indicator and its background.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the progress indicator object
static int progressViewHide(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    [theWindow orderOut:nil];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.progress:start() -> progressObject
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
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    [theView startAnimation:nil];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.progress:stop() -> progressObject
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
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    [theView stopAnimation:nil];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.progress:threaded([flag]) -> progressObject | current value
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
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.usesThreadedAnimation = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, theView.usesThreadedAnimation) ;
    }
    return 1;
}

/// hs._asm.progress:indeterminate([flag]) -> progressObject | current value
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
///  * If this setting is set to false, you should also take a look at [hs._asm.progress:min](#min) and [hs._asm.progress:max](#max), and periodically update the status with [hs._asm.progress:value](#value) or [hs._asm.progress:increment](#increment)
static int progressViewIndeterminate(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.indeterminate = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, theView.indeterminate) ;
    }
    return 1;
}

/// hs._asm.progress:bezeled([flag]) -> progressObject | current value
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
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.bezeled = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, theView.bezeled) ;
    }
    return 1;
}

/// hs._asm.progress:displayWhenStopped([flag]) -> progressObject | current value
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
///  * The background is not hidden by this method when animation is not running, only the indicator itself.
static int progressViewDisplayedWhenStopped(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.displayedWhenStopped = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, theView.displayedWhenStopped) ;
    }
    return 1;
}

/// hs._asm.progress:circular([flag]) -> progressObject | current value
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
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.style = (BOOL)lua_toboolean(L, 2) ? NSProgressIndicatorSpinningStyle : NSProgressIndicatorBarStyle ;
        [theView sizeToFit] ;
        [theView centerInWindow] ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, (theView.style == NSProgressIndicatorSpinningStyle)) ;
    }
    return 1;
}

/// hs._asm.progress:value([value]) -> progressObject | current value
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
///  * For a determinate indicator, this will affect how "filled" the bar or circle is.  If the value is lower than [hs._asm.progress:min](#min), then it will be reset to that value.  If the value is greater than [hs._asm.progress:max](#max), then it will be reset to that value.
static int progressViewValue(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.doubleValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnumber(L, theView.doubleValue) ;
    }
    return 1;
}

/// hs._asm.progress:min([value]) -> progressObject | current value
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
///  * For a determinate indicator, the behavior is undefined if this value is greater than [hs._asm.progress:max](#max).
static int progressViewMin(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.minValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnumber(L, theView.minValue) ;
    }
    return 1;
}

/// hs._asm.progress:max([value]) -> progressObject | current value
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
///  * For a determinate indicator, the behavior is undefined if this value is less than [hs._asm.progress:min](#min).
static int progressViewMax(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        theView.maxValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnumber(L, theView.maxValue) ;
    }
    return 1;
}

/// hs._asm.progress:increment(value) -> progressObject | current value
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
///  * Programmatically, this is equivalent to `hs._asm.progress:value(hs._asm.progress:value() + value)`, but is faster.
static int progressViewIncrement(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK] ;
    [theView incrementBy:lua_tonumber(L, 2)] ;
    lua_pushvalue(L, 1) ;
    return 1;
}

/// hs._asm.progress:tint([tint]) -> progressObject | current value
/// Method
/// Get or set the indicator's tint.
///
/// Parameters:
///  * tint - an optional integer matching one of the values in [hs._asm.progress.controlTint](#controlTint), which indicates the tint of the progress indicator.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is 0, which corresponds to `hs._asm.progress.controlTint.default`.
///  * In my testing, this setting does not seem to have much, if any, effect on the visual aspect of the indicator and is provided in this module in case this changes in a future OS X update (there are some indications that it may have had an effect in previous versions).
static int progressViewControlTint(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        luaL_checkinteger(L, 2) ;
        [theView setControlTint:(NSControlTint)lua_tointeger(L, 2)] ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushinteger(L, theView.controlTint) ;
    }
    return 1;
}

/// hs._asm.progress:indicatorSize([size]) -> progressObject | current value
/// Method
/// Get or set the indicator's size.
///
/// Parameters:
///  * size - an optional integer matching one of the values in [hs._asm.progress.controlSize](#controlSize), which indicates the desired size of the indicator.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is 0, which corresponds to `hs._asm.progress.controlSize.regular`.
///  * For circular indicators, the sizes seem to be 32x32, 16x16, and 10x10 in 10.11.
///  * For bar indicators, the height seems to be 20 and 12; the mini size seems to be ignored, at least in 10.11.
static int progressViewControlSize(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        luaL_checkinteger(L, 2) ;
        theView.controlSize = (NSControlSize)lua_tointeger(L, 2) ;
        [theView sizeToFit] ;
        [theView centerInWindow] ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushinteger(L, theView.controlSize) ;
    }
    return 1;
}

/// hs._asm.progress:setTopLeft(point) -> progressObject
/// Method
/// Sets the top left point of the progress objects background.
///
/// Parameters:
///  * point - a table containing a keys for x and y, specifying the top left point to move the indicator and its background to.
///
/// Returns:
///  * the progress indicator object
static int progressViewSetTopLeft(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    NSPoint windowLoc  = [skin tableToPointAtIndex:2] ;

    windowLoc.y=[[NSScreen screens][0] frame].size.height - windowLoc.y ;
    [theWindow setFrameTopLeftPoint:windowLoc] ;
    [theView centerInWindow] ;

    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.progress:setSize(size) -> progressObject
/// Method
/// Sets the size of the indicator's background.
///
/// Parameters:
///  * size - a table containing a keys for h and w, specifying the size of the indicators background.
///
/// Returns:
///  * the progress indicator object
static int progressViewSetSize(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    NSSize windowSize = [skin tableToSizeAtIndex:2] ;

    NSRect oldFrame = theWindow.frame;
    NSRect newFrame = NSMakeRect(oldFrame.origin.x,
                                 oldFrame.origin.y + oldFrame.size.height - windowSize.height,
                                 windowSize.width,
                                 windowSize.height);
    [theWindow setFrame:newFrame display:YES animate:NO];
    [theView sizeToFit] ;
    [theView centerInWindow] ;

    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.progress:frame([rect]) -> progressObject
/// Method
/// Get or set the frame of the the progress indicator and its background.
///
/// Parameters:
///  * rect - an optional table containing the rectangular coordinates for the progress indicator and its background.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
static int progressViewFrame(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) == 2) {
        lua_pushcfunction(L, progressViewSetSize) ;
        lua_pushvalue(L, 1) ;
        lua_pushvalue(L, 2) ;
        lua_call(L, 2, 1) ;
        lua_pop(L, 1) ;
        lua_pushcfunction(L, progressViewSetTopLeft) ;
        lua_pushvalue(L, 1) ;
        lua_pushvalue(L, 2) ;
        lua_call(L, 2, 1) ;
    } else {
        [skin pushNSRect:[theWindow frame]] ;
    }
    return 1;
}

/// hs._asm.progress:setFillColor(color) -> progressObject
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
///  * For circular and determinate bar progress indicators, this method works as expected.
///  * For indeterminate bar progress indicators, this method will set the entire bar to the color specified and no animation effect is apparent.  Hopefully this is a temporary limitation.
static int progressViewSetCustomColor(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)theWindow.contentView ;
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;

    NSColor *theColor = [[skin luaObjectAtIndex:2 toClass:"NSColor"] colorUsingColorSpaceName:NSCalibratedRGBColorSpace] ;
    if (theColor) {
        [theView setCustomColor:theColor] ;
    } else {
        return my_lua_error(L, @"Color must be expressible as RGB") ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.progress:backgroundColor([color]) -> progressObject
/// Method
/// Get or set the color of the progress indicator's background.
///
/// Parameters:
///  * color - an optional table specifying a color as defined in `hs.drawing.color` for the progress indicator's background.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
static int progressViewBackgroundColor(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) == 2) {
        NSColor *theColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        [theWindow setBackgroundColor:theColor] ;
        lua_pushvalue(L, 1) ;
    } else {
        [skin pushNSObject:theWindow.backgroundColor] ;
    }
    return 1 ;
}

#pragma mark - Module Constants

/// hs._asm.progress.controlSize[]
/// Constant
/// A table containing key-value pairs defining recognized sizes which can be used with the [hs._asm.progress:indicatorSize](#indicatorSize) method.
///
/// Contents:
///  * regular - display the indicator at its regular size
///  * small   - display a smaller version of the indicator
///  * mini    - for circular indicators, display an even smaller version; for bar indicators, this setting has no effect.
static int pushControlSizeTable(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSRegularControlSize) ; lua_setfield(L, -2, "regular") ;
    lua_pushinteger(L, NSSmallControlSize) ;   lua_setfield(L, -2, "small") ;
    lua_pushinteger(L, NSMiniControlSize) ;    lua_setfield(L, -2, "mini") ;
    return 1 ;
}

/// hs._asm.progress.controlTint[]
/// Constant
/// A table containing key-value pairs defining recognized tints which can be used with the [hs._asm.progress:tint](#tint) method.
///
/// Contents:
///  * default
///  * blue
///  * graphite
///  * clear
///
/// Notes:
///  * In my testing, setting `hs._asm.progress:tint` does not seem to have much, if any, effect on the visual aspect of an indicator and this table is provided in this module in case this changes in a future OS X update (there are some indications that it may have had an effect in previous versions).
static int pushControlTintTable(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSDefaultControlTint) ;  lua_setfield(L, -2, "default") ;
    lua_pushinteger(L, NSBlueControlTint) ;     lua_setfield(L, -2, "blue") ;
    lua_pushinteger(L, NSGraphiteControlTint) ; lua_setfield(L, -2, "graphite") ;
    lua_pushinteger(L, NSClearControlTint) ;    lua_setfield(L, -2, "clear") ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions

#pragma mark - Hammerspoon/Lua Infrastructure

// bridge to hs.drawing... allows us to use some of its methods as our own.
// unlike other modules, we're not going to advertise this (in fact I may remove it from the others
// when I get a chance) because a closer look suggests that we can cause a crash, even with the
// type checks in many of hs.drawings methods.
typedef struct _drawing_t {
    void *window;
    BOOL skipClose ;
} drawing_t;

static int progressViewAsHSDrawing(lua_State *L) {
    HS_asmProgressWindow *theWindow = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;

    drawing_t *drawingObject = lua_newuserdata(L, sizeof(drawing_t));
    memset(drawingObject, 0, sizeof(drawing_t));
    drawingObject->window = (__bridge_retained void*)theWindow;
    // skip the side affects of hs.drawing __gc
    drawingObject->skipClose = YES ;
    luaL_getmetatable(L, "hs.drawing");
    lua_setmetatable(L, -2);
    return 1 ;
}

static int userdata_tostring(lua_State* L) {
    HS_asmProgressWindow *obj = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
    HS_asmProgressView   *theView = (HS_asmProgressView *)obj.contentView ;
    LuaSkin *skin = [LuaSkin shared] ;
    NSString *title = nil ;
    if ([theView isIndeterminate]) {
        title = @"indeterminate" ;
    } else {
        title = [NSString stringWithFormat:@"@%.2f of [%.2f, %.2f]", theView.doubleValue,
                                                              theView.minValue,
                                                              theView.maxValue] ;
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        HS_asmProgressWindow *obj1 = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 1) ;
        HS_asmProgressWindow *obj2 = get_objectFromUserdata(__bridge HS_asmProgressWindow, L, 2) ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

/// hs._asm.progress:delete() -> none
/// Method
/// Close and remove a progress indicator.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * This method is called automatically during garbage collection (most notably, when Hammerspoon is exited or the Hammerspoon configuration is reloaded).
static int userdata_gc(lua_State* L) {
    HS_asmProgressWindow *obj = get_objectFromUserdata(__bridge_transfer HS_asmProgressWindow, L, 1) ;
    if (obj) {
        [obj close] ;
        obj.contentView = nil ;
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
    {"show",               progressViewShow},
    {"hide",               progressViewHide},
    {"delete",             userdata_gc},
    {"start",              progressViewStart},
    {"stop",               progressViewStop},
    {"threaded",           progressViewThreaded},
    {"indeterminate",      progressViewIndeterminate},
    {"circular",           progressViewCircular},
    {"bezeled",            progressViewBezeled},
    {"displayWhenStopped", progressViewDisplayedWhenStopped},
    {"value",              progressViewValue},
    {"min",                progressViewMin},
    {"max",                progressViewMax},
    {"increment",          progressViewIncrement},
    {"indicatorSize",      progressViewControlSize},
    {"tint",               progressViewControlTint},
    {"backgroundColor",    progressViewBackgroundColor},

    {"frame",              progressViewFrame},
    {"setTopLeft",         progressViewSetTopLeft},
    {"setSize",            progressViewSetSize},
    {"setFillColor",       progressViewSetCustomColor},

    {"_asHSDrawing",       progressViewAsHSDrawing},
    {"__tostring",         userdata_tostring},
    {"__eq",               userdata_eq},
    {"__gc",               userdata_gc},
    {NULL,                 NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", newProgressView},

    {"_registerLogForC", lua_registerLogForC},
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_progress_internal(lua_State* __unused L) {
// Use this if your module doesn't have a module specific object that it returns.
//    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [[LuaSkin shared] registerLibraryWithObject:USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

    pushControlSizeTable(L) ; lua_setfield(L, -2, "controlSize") ;
    pushControlTintTable(L) ; lua_setfield(L, -2, "controlTint") ;

    return 1;
}
