// TODO: add legacy flag to mimic canvas/webview delete/close behavior?
//       or handle with wrappers in lua?
//         to match selfRef behavior, would have to wrap callbacks as well

@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs.fenestra" ;
static LSRefTable refTable = LUA_NOREF ;

static NSArray *fenestraNotifications ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static inline NSRect RectWithFlippedYCoordinate(NSRect theRect) {
    return NSMakeRect(theRect.origin.x,
                      [[NSScreen screens][0] frame].size.height - theRect.origin.y - theRect.size.height,
                      theRect.size.width,
                      theRect.size.height) ;
}

@interface HSFenestra : NSPanel <NSWindowDelegate>
@property int          selfRefCount ;
@property BOOL         allowKeyboardEntry ;
@property BOOL         darkMode ;
@property BOOL         titleFollow ;
// @property BOOL         closeOnEscape ;
@property int          notificationCallback ;
@property NSNumber     *animationTime ;
@property NSMutableSet *notifyFor ;
@property NSString     *subroleOverride ;
@end

@implementation HSFenestra
- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)windowStyle {
    if (!(isfinite(contentRect.origin.x) && isfinite(contentRect.origin.y) && isfinite(contentRect.size.height) && isfinite(contentRect.size.width))) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:coordinates must be finite numbers", USERDATA_TAG]] ;
        self = nil ;
    } else {
        self = [super initWithContentRect:contentRect
                                styleMask:windowStyle
                                  backing:NSBackingStoreBuffered
                                    defer:YES] ;
    }

    if (self) {
        contentRect = RectWithFlippedYCoordinate(contentRect) ;
        [self setFrameOrigin:contentRect.origin] ;

        self.autorecalculatesKeyViewLoop      = YES ;
        self.releasedWhenClosed               = NO ;
        self.ignoresMouseEvents               = NO ;
        self.restorable                       = NO ;
        self.hidesOnDeactivate                = NO ;
        self.animationBehavior                = NSWindowAnimationBehaviorNone ;
        self.level                            = NSNormalWindowLevel ;
        self.displaysWhenScreenProfileChanges = YES ;

        _notificationCallback   = LUA_NOREF ;
//         _closeOnEscape          = NO ;
        _allowKeyboardEntry     = YES ;
        _animationTime          = nil ;
        _subroleOverride        = nil ;
        _notifyFor              = [[NSMutableSet alloc] initWithArray:@[
                                                                          @"willClose",
                                                                          @"didBecomeKey",
                                                                          @"didResignKey",
                                                                          @"didResize",
                                                                          @"didMove",
                                                                      ]] ;
        self.delegate           = self ;
    }
    return self ;
}

// - (void)dealloc {
//     NSLog(@"%s dealloc invoked", USERDATA_TAG) ;
// }

- (NSTimeInterval)animationResizeTime:(NSRect)newWindowFrame {
    if (_animationTime) {
        return [_animationTime doubleValue] ;
    } else {
        return [super animationResizeTime:newWindowFrame] ;
    }
}

// see canvas version if we need to do something a little more complex and check views/subviews
- (BOOL)canBecomeKeyWindow {
    return _allowKeyboardEntry ;
}

- (BOOL)canBecomeMainWindow {
    return _allowKeyboardEntry ;
}

#pragma mark * Custom for Hammerspoon

- (void)fadeIn:(NSTimeInterval)fadeTime {
    [self setAlphaValue:0.0] ;
    [self makeKeyAndOrderFront:nil] ;
    [NSAnimationContext beginGrouping] ;
    [[NSAnimationContext currentContext] setDuration:fadeTime] ;
    [[self animator] setAlphaValue:1.0] ;
    [NSAnimationContext endGrouping] ;
}

- (void)fadeOut:(NSTimeInterval)fadeTime andClose:(BOOL)closeWindow {
    [NSAnimationContext beginGrouping] ;
      __weak HSFenestra *bself = self ;
      [[NSAnimationContext currentContext] setDuration:fadeTime] ;
      [[NSAnimationContext currentContext] setCompletionHandler:^{
          // unlikely that bself will go to nil after this starts, but this keeps the
          // warnings down from [-Warc-repeated-use-of-weak]
          HSFenestra *mySelf = bself ;
          if (mySelf) {
              if (closeWindow) {
                  [mySelf close] ; // trigger callback, if set, then cleanup
              } else {
                  [mySelf orderOut:mySelf] ;
                  [mySelf setAlphaValue:1.0] ;
              }
          }
      }] ;
      [[self animator] setAlphaValue:0.0] ;
    [NSAnimationContext endGrouping] ;
}

#pragma mark * NSAccessibility protocol methods

// to mimic canvas's default subrole, set object subroleOverride to "+.Hammerspoon"
- (NSString *)accessibilitySubrole {
    NSString *defaultSubrole = [super accessibilitySubrole] ;
    NSString *newSubrole     = defaultSubrole ;
    if (_subroleOverride) {
        newSubrole = [_subroleOverride stringByReplacingOccurrencesOfString:@"+"
                                                                 withString:defaultSubrole] ;
    }
    return newSubrole ;
}

#pragma mark * NSStandardKeyBindingResponding protocol methods

// - (void)cancelOperation:(id)sender {
//     if (_closeOnEscape)
//         [super cancelOperation:sender] ;
// }

#pragma mark * NSWindowDelegate protocol methods

// - (BOOL)window:(NSWindow *)window shouldDragDocumentWithEvent:(NSEvent *)event from:(NSPoint)dragImageLocation withPasteboard:(NSPasteboard *)pasteboard ;
// - (BOOL)window:(NSWindow *)window shouldPopUpDocumentPathMenu:(NSMenu *)menu ;
// - (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)client ;
// - (NSApplicationPresentationOptions)window:(NSWindow *)window willUseFullScreenPresentationOptions:(NSApplicationPresentationOptions)proposedOptions ;
// - (NSArray<NSWindow *> *)customWindowsToEnterFullScreenForWindow:(NSWindow *)window onScreen:(NSScreen *)screen ;
// - (NSArray<NSWindow *> *)customWindowsToEnterFullScreenForWindow:(NSWindow *)window ;
// - (NSArray<NSWindow *> *)customWindowsToExitFullScreenForWindow:(NSWindow *)window ;
// - (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect ;
// - (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)newFrame ;
// - (NSSize)window:(NSWindow *)window willResizeForVersionBrowserWithMaxPreferredSize:(NSSize)maxPreferredFrameSize maxAllowedSize:(NSSize)maxAllowedFrameSize ;
// - (NSSize)window:(NSWindow *)window willUseFullScreenContentSize:(NSSize)proposedSize ;
// - (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize ;
// - (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window ;
// - (void)window:(NSWindow *)window didDecodeRestorableState:(NSCoder *)state ;
// - (void)window:(NSWindow *)window startCustomAnimationToEnterFullScreenOnScreen:(NSScreen *)screen withDuration:(NSTimeInterval)duration ;
// - (void)window:(NSWindow *)window startCustomAnimationToEnterFullScreenWithDuration:(NSTimeInterval)duration ;
// - (void)window:(NSWindow *)window startCustomAnimationToExitFullScreenWithDuration:(NSTimeInterval)duration ;
// - (void)window:(NSWindow *)window willEncodeRestorableState:(NSCoder *)state ;

- (BOOL)windowShouldClose:(__unused NSWindow *)sender {
    if ((self.styleMask & NSWindowStyleMaskClosable) != 0) {
        return YES ;
    } else {
        return NO ;
    }
}

// - (BOOL)windowShouldZoom:(NSWindow *)window toFrame:(NSRect)newFrame {}

- (void)performNotificationCallbackFor:(NSString *)message with:(NSNotification *)notification {
    if (_notificationCallback != LUA_NOREF && [_notifyFor containsObject:message]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_notificationCallback != LUA_NOREF) {
                LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
                [skin pushLuaRef:refTable ref:self->_notificationCallback] ;
// TODO: should be the window object itself, but need to test for all of them as the docs only mention it for some of the delegate calls
                [skin pushNSObject:notification.object] ;
                [skin pushNSObject:message] ;
                [skin pushNSObject:notification.userInfo] ;
                if (![skin protectedCallAndTraceback:3 nresults:0]) {
                    NSString *errorMsg = [skin toNSObjectAtIndex:-1] ;
                    lua_pop([skin L], 1) ;
                    [skin logError:[NSString stringWithFormat:@"%s:%@ notification callback error:%@", USERDATA_TAG, message, errorMsg]] ;
                }
            }
        }) ;
    }
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didBecomeKey" with:notification] ;
}
- (void)windowDidBecomeMain:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didBecomeMain" with:notification] ;
}
- (void)windowDidChangeBackingProperties:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didChangeBackingProperties" with:notification] ;
}
- (void)windowDidChangeOcclusionState:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didChangeOcclusionState" with:notification] ;
}
- (void)windowDidChangeScreen:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didChangeScreen" with:notification] ;
}
- (void)windowDidChangeScreenProfile:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didChangeScreenProfile" with:notification] ;
}
- (void)windowDidDeminiaturize:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didDeminiaturize" with:notification] ;
}
- (void)windowDidEndLiveResize:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didEndLiveResize" with:notification] ;
}
- (void)windowDidEndSheet:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didEndSheet" with:notification] ;
}
- (void)windowDidEnterFullScreen:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didEnterFullScreen" with:notification] ;
}
- (void)windowDidEnterVersionBrowser:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didEnterVersionBrowser" with:notification] ;
}
- (void)windowDidExitFullScreen:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didExitFullScreen" with:notification] ;
}
- (void)windowDidExitVersionBrowser:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didExitVersionBrowser" with:notification] ;
}
- (void)windowDidExpose:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didExpose" with:notification] ;
}
- (void)windowDidMiniaturize:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didMiniaturize" with:notification] ;
}
- (void)windowDidMove:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didMove" with:notification] ;
}
- (void)windowDidResignKey:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didResignKey" with:notification] ;
}
- (void)windowDidResignMain:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didResignMain" with:notification] ;
}
- (void)windowDidResize:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didResize" with:notification] ;
}
- (void)windowDidUpdate:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didUpdate" with:notification] ;
}
- (void)windowWillBeginSheet:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willBeginSheet" with:notification] ;
}
- (void)windowWillClose:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willClose" with:notification] ;
}
- (void)windowWillEnterFullScreen:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willEnterFullScreen" with:notification] ;
}
- (void)windowWillEnterVersionBrowser:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willEnterVersionBrowser" with:notification] ;
}
- (void)windowWillExitFullScreen:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willExitFullScreen" with:notification] ;
}
- (void)windowWillExitVersionBrowser:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willExitVersionBrowser" with:notification] ;
}
- (void)windowWillMiniaturize:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willMiniaturize" with:notification] ;
}
- (void)windowWillMove:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willMove" with:notification] ;
}
- (void)windowWillStartLiveResize:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willStartLiveResize" with:notification] ;
}

- (void)windowDidFailToEnterFullScreen:(NSWindow *)window {
    [self performNotificationCallbackFor:@"didFailToEnterFullScreen"
                                    with:[NSNotification notificationWithName:@"didFailToEnterFullScreen"
                                                                       object:window]] ;
}
- (void)windowDidFailToExitFullScreen:(NSWindow *)window {
    [self performNotificationCallbackFor:@"didFailToExitFullScreen"
                                    with:[NSNotification notificationWithName:@"didFailToExitFullScreen"
                                                                       object:window]] ;
}

@end

static NSWindowStyleMask defaultWindowMask = NSWindowStyleMaskTitled         |
                                             NSWindowStyleMaskClosable       |
                                             NSWindowStyleMaskResizable      |
                                             NSWindowStyleMaskMiniaturizable ;

static int window_orderHelper(lua_State *L, NSWindowOrderingMode mode) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;
    NSInteger relativeTo = 0 ;

    if (lua_gettop(L) > 1) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
        HSFenestra *otherWindow = [skin toNSObjectAtIndex:2] ;
        if (otherWindow) relativeTo = [otherWindow windowNumber] ;
    }
    if (window) [window orderWindow:mode relativeTo:relativeTo] ;
    return 1 ;
}

#pragma mark - Module Functions

static int window_minFrameWidthWithTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    NSString   *title = [skin toNSObjectAtIndex:1] ;
    NSUInteger style  = (lua_gettop(L) == 2) ? (NSUInteger)lua_tointeger(L, 2) : defaultWindowMask ;

    lua_pushnumber(L, [NSWindow minFrameWidthWithTitle:title styleMask:style]) ;
    return 1 ;
}

static int window_contentRectForFrameRect(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    NSRect     fRect  = [skin tableToRectAtIndex:1] ;
    NSUInteger style  = (lua_gettop(L) == 2) ? (NSUInteger)lua_tointeger(L, 2) : defaultWindowMask ;

    [skin pushNSRect:[NSWindow contentRectForFrameRect:fRect styleMask:style]] ;
    return 1 ;
}

static int window_frameRectForContentRect(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    NSRect     cRect  = [skin tableToRectAtIndex:1] ;
    NSUInteger style  = (lua_gettop(L) == 2) ? (NSUInteger)lua_tointeger(L, 2) : defaultWindowMask ;

    [skin pushNSRect:[NSWindow frameRectForContentRect:cRect styleMask:style]] ;
    return 1 ;
}

/// hs.fenestra.new(rect, [styleMask]) -> fenestraObject
/// Constructor
/// Creates a new empty fenestra window.
///
/// Parameters:
///  * `rect`     - a rect-table specifying the initial location and size of the fenestra window.
///  * `styleMask` - an optional integer specifying the style mask for the window as a combination of logically or'ed values from the [hs.fenestra.masks](#masks) table.  Defaults to `titled | closable | resizable | miniaturizable` (a standard macOS window with the appropriate titlebar and decorations).
///
/// Returns:
///  * the fenestra object, or nil if there was an error creating the window.
///
/// Notes:
///  * a rect-table is a table with key-value pairs specifying the top-left coordinate on the screen of the fenestra window (keys `x`  and `y`) and the size (keys `h` and `w`). The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
static int window_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;

    NSUInteger windowStyle = (lua_gettop(L) == 2) ? (NSUInteger)lua_tointeger(L, 2) : defaultWindowMask ;

    HSFenestra *window = [[HSFenestra alloc] initWithContentRect:[skin tableToRectAtIndex:1]
                                                       styleMask:windowStyle] ;
    if (window) {
        [skin pushNSObject:window] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

/// hs.fenestra:allowTextEntry([value]) -> fenestraObject | boolean
/// Method
/// Get or set whether or not the fenestra object can accept keyboard entry. Defaults to true.
///
/// Parameters:
///  * `value` - an optional boolean, default true, which sets whether or not the fenestra will accept keyboard input.
///
/// Returns:
///  * If a value is provided, then this method returns the fenestra object; otherwise the current value
///
/// Notes:
///  * Most controllable elements require keybaord focus even if they do not respond directly to keyboard input.
static int fenestra_allowTextEntry(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.allowKeyboardEntry) ;
    } else {
        window.allowKeyboardEntry = (BOOL) lua_toboolean(L, 2) ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

// /// hs.fenestra:deleteOnClose([value]) -> fenestraObject | boolean
// /// Method
// /// Get or set whether or not the fenestra window should delete itself when its window is closed.
// ///
// /// Parameters:
// ///  * `value` - an optional boolean, default false, which sets whether or not the fenestra will delete itself when its window is closed by any method.
// ///
// /// Returns:
// ///  * If a value is provided, then this method returns the fenestra object; otherwise the current value
// ///
// /// Notes:
// ///  * setting this to true allows Lua garbage collection to release the window resources when the user closes the window.
// static int fenestra_deleteOnClose(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
//     HSFenestra *window = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 1) {
//         lua_pushboolean(L, window.deleteOnClose) ;
//     } else {
//         window.deleteOnClose = (BOOL) lua_toboolean(L, 2) ;
//         lua_settop(L, 1) ;
//     }
//     return 1 ;
// }

/// hs.fenestra:alpha([alpha]) -> fenestraObject | number
/// Method
/// Get or set the alpha level of the window representing the fenestra object.
///
/// Parameters:
///  * `alpha` - an optional number, default 1.0, specifying the alpha level (0.0 - 1.0, inclusive) for the window.
///
/// Returns:
///  * If an argument is provided, the fenestra object; otherwise the current value.
static int window_alphaValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, window.alphaValue) ;
    } else {
        CGFloat newAlpha = luaL_checknumber(L, 2);
        window.alphaValue = ((newAlpha < 0.0) ? 0.0 : ((newAlpha > 1.0) ? 1.0 : newAlpha)) ;
        lua_pushvalue(L, 1);
    }
    return 1 ;
}

/// hs.fenestra:backgroundColor([color]) -> fenestraObject | color table
/// Method
/// Get or set the color for the background of fenestra window.
///
/// Parameters:
/// * `color` - an optional table containing color keys as described in `hs.drawing.color`
///
/// Returns:
///  * If an argument is provided, the fenestra object; otherwise the current value.
static int window_backgroundColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:window.backgroundColor] ;
    } else {
        window.backgroundColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.fenestra:hasShadow([state]) -> fenestraObject | boolean
/// Method
/// Get or set whether the fenestra window displays a shadow.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether or not the window draws a shadow.
///
/// Returns:
///  * If an argument is provided, the fenestra object; otherwise the current value.
static int window_hasShadow(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.hasShadow) ;
    } else {
        window.hasShadow = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.fenestra:opaque([state]) -> fenestraObject | boolean
/// Method
/// Get or set whether the fenestra window is opaque.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether or not the window is opaque.
///
/// Returns:
///  * If an argument is provided, the fenestra object; otherwise the current value.
static int window_opaque(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.opaque) ;
    } else {
        window.opaque = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.fenestra:ignoresMouseEvents([state]) -> fenestraObject | boolean
/// Method
/// Get or set whether the fenestra window ignores mouse events.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not the window receives mouse events.
///
/// Returns:
///  * If an argument is provided, the fenestra object; otherwise the current value.
///
/// Notes:
///  * Setting this to true will prevent elements in the window from receiving mouse button events or mouse movement events which affect the focus of the window or its elements. For elements which accept keyboard entry, this *may* also prevent the user from focusing the element for keyboard input unless the element is focused programmatically with [hs.fenestra:activeElement](#activeElement).
///  * Mouse tracking events (see `hs.fenestra.manager:mouseCallback`) will still occur, even if this is true; however if two windows at the same level (see [hs.fenestra:level](#level)) both occupy the current mouse location and one or both of the windows have this attribute set to false, spurious and unpredictable mouse callbacks may occur as the "frontmost" window changes based on which is acting on the event at that instant in time.
static int window_ignoresMouseEvents(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.ignoresMouseEvents) ;
    } else {
        window.ignoresMouseEvents = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_styleMask(lua_State *L) {
// NOTE:  This method is wrapped in init.lua
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    NSUInteger oldStyle = window.styleMask ;
    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushinteger(L, (lua_Integer)oldStyle) ;
    } else {
// FIXME: can we check this through logic or do we have to use try/catch?
            @try {
            // Because we're using NSPanel, the title is reset when the style is changed
                NSString *theTitle = window.title ;
            // Also, some styles don't get properly set unless we start from a clean slate
                window.styleMask = 0 ;
                window.styleMask = (NSUInteger)luaL_checkinteger(L, 2) ;
                if (theTitle) window.title = theTitle ;
            }
            @catch ( NSException *theException ) {
                window.styleMask = oldStyle ;
                return luaL_error(L, "invalid style mask: %s, %s", [[theException name] UTF8String], [[theException reason] UTF8String]) ;
            }
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs.fenestra:title([title]) -> fenestraObject | string
/// Method
/// Get or set the fenestra window's title.
///
/// Parameters:
///  * `title` - an optional string specifying the title to assign to the fenestra window.
///
/// Returns:
///  * If an argument is provided, the fenestra object; otherwise the current value.
static int window_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
      [skin pushNSObject:window.title] ;
    } else {
        window.title = [skin toNSObjectAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.fenestra:titlebarAppearsTransparent([state]) -> fenestraObject | boolean
/// Method
/// Get or set whether the fenestra window's title bar draws its background.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether or not the fenestra window's title bar draws its background.
///
/// Returns:
///  * If an argument is provided, the fenestra object; otherwise the current value.
static int window_titlebarAppearsTransparent(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.titlebarAppearsTransparent) ;
    } else {
        window.titlebarAppearsTransparent = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.fenestra:titleVisibility([state]) -> fenestraObject | currentValue
/// Method
/// Get or set whether or not the title is displayed in the fenestra window titlebar.
///
/// Parameters:
///  * `state` - an optional string containing the text "visible" or "hidden", specifying whether or not the fenestra window's title text appears.
///
/// Returns:
///  * If an argument is provided, the fenestra object; otherwise the current value.
///
/// Notes:
///  * NOT IMPLEMENTED YET - When a toolbar is attached to the fenestra window (see the `hs.webview.toolbar` module documentation), this function can be used to specify whether the Toolbar appears underneath the window's title ("visible") or in the window's title bar itself, as seen in applications like Safari ("hidden").
static int window_titleVisibility(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;
// FIXME: should we switch this to true/false?
    NSDictionary *mapping = @{
        @"visible" : @(NSWindowTitleVisible),
        @"hidden"  : @(NSWindowTitleHidden),
    } ;
    if (lua_gettop(L) == 1) {
        NSNumber *titleVisibility = @(window.titleVisibility) ;
        NSString *value = [[mapping allKeysForObject:titleVisibility] firstObject] ;
        if (value) {
            [skin pushNSObject:value] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized titleVisibility %@ -- notify developers", USERDATA_TAG, titleVisibility]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSNumber *value = mapping[[skin toNSObjectAtIndex:2]] ;
        if (value) {
            window.titleVisibility = [value intValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of '%@'", [[mapping allKeys] componentsJoinedByString:@"', '"]] UTF8String]) ;
        }
    }
    return 1 ;
}

/// hs.fenestra:appearance([appearance]) -> fenestraObject | string
/// Method
/// Get or set the appearance name applied to the window decorations for the fenestra window.
///
/// Parameters:
///  * `appearance` - an optional string specifying the name of the appearance style to apply to the window frame and decorations.  Should be one of "aqua", "light", or "dark".
///
/// Returns:
///  * If an argument is provided, the fenestra object; otherwise the current value.
///
/// Notes:
///  * Other string values are allowed for forwards compatibility if Apple or third party software adds additional themes.
///  * The built in labels are actually shortcuts:
///    * "aqua"  is shorthand for "NSAppearanceNameAqua" and is the default.
///    * "light" is shorthand for "NSAppearanceNameVibrantLight"
///    * "dark"  is shorthand for "NSAppearanceNameVibrantDark" and can be used to mimic the macOS dark mode.
///  * This method will return an error if the string provided does not correspond to a recognized appearance theme.
static int appearanceCustomization_appearance(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    NSDictionary *mapping = @{
        @"aqua"                 : NSAppearanceNameAqua,          // 10.9+
        @"light"                : NSAppearanceNameVibrantLight,  // 10.10+
        @"dark"                 : NSAppearanceNameVibrantDark,   // 10.10+
    } ;
    if (@available(macOS 10.14, *)) {
        mapping = @{
            @"aqua"                 : NSAppearanceNameAqua,
            @"darkAqua"             : NSAppearanceNameDarkAqua,
            @"light"                : NSAppearanceNameVibrantLight,
            @"dark"                 : NSAppearanceNameVibrantDark,
            @"highContrastAqua"     : NSAppearanceNameAccessibilityHighContrastAqua,
            @"highContrastDarkAqua" : NSAppearanceNameAccessibilityHighContrastDarkAqua,
            @"highContrastLight"    : NSAppearanceNameAccessibilityHighContrastVibrantLight,
            @"highContrastDark"     : NSAppearanceNameAccessibilityHighContrastVibrantDark
        } ;
    }
    if (lua_gettop(L) == 1) {
        NSString *actual   = window.effectiveAppearance.name ;
        NSString *returned = [[mapping allKeysForObject:actual] firstObject] ;
        if (!returned) returned = actual ;
        [skin pushNSObject:returned] ;
    } else {
        NSString *name = [skin toNSObjectAtIndex:2] ;
        NSString *appearanceName = mapping[name] ;
        if (!appearanceName) appearanceName = name ;
        NSAppearance *appearance = [NSAppearance appearanceNamed:appearanceName] ;
        if (appearance) {
            window.appearance = appearance ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of '%@'", [[mapping allKeys] componentsJoinedByString:@"', '"]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// /// hs.fenestra:closeOnEscape([flag]) -> fenestraObject | boolean
// /// Method
// /// If the fenestra window is closable, this will get or set whether or not the Escape key is allowed to close the fenestra window.
// ///
// /// Parameters:
// ///  * `flag` - an optional boolean value which indicates whether the fenestra window, when it's style includes `closable` (see [hs.fenestra:styleMask](#styleMask)), should allow the Escape key to be a shortcut for closing the window.  Defaults to false.
// ///
// /// Returns:
// ///  * If a value is provided, then this method returns the fenestra object; otherwise the current value
// ///
// /// Notes:
// ///  * If this is set to true, Escape will only close the window if no other element responds to the Escape key first (e.g. if you are editing a textfield element, the Escape will be captured by the text field, not by the fenestra window.)
// static int fenestra_closeOnEscape(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
//     HSFenestra *window = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 1) {
//         lua_pushboolean(L, window.closeOnEscape) ;
//     } else {
//         window.closeOnEscape = (BOOL)lua_toboolean(L, 2) ;
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }

/// hs.fenestra:frame([rect], [animated]) -> fenestraObject | rect-table
/// Method
/// Get or set the frame of the fenestra window.
///
/// Parameters:
///  * `rect`     - An optional rect-table containing the co-ordinates and size the fenestra window should be moved and set to
///  * `animated` - an optional boolean, default false, indicating whether the frame change should be performed with a smooth transition animation (true) or not (false).
///
/// Returns:
///  * If an argument is provided, the fenestra object; otherwise the current value.
///
/// Notes:
///  * a rect-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the fenestra window (keys `x`  and `y`) and the new size (keys `h` and `w`). The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
///
///  * See also [hs.fenestra:animationDuration](#animationDuration).
static int window_frame(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    NSRect oldFrame = RectWithFlippedYCoordinate(window.frame);
    if (lua_gettop(L) == 1) {
        [skin pushNSRect:oldFrame] ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
        NSRect newFrame = RectWithFlippedYCoordinate([skin tableToRectAtIndex:2]) ;
        BOOL animate = (lua_gettop(L) == 3) ? (BOOL)lua_toboolean(L, 3) : NO ;
        [window setFrame:newFrame display:YES animate:animate];
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs.fenestra:topLeft([point], [animated]) -> fenestraObject | rect-table
/// Method
/// Get or set the top left corner of the fenestra window.
///
/// Parameters:
///  * `point`     - An optional point-table specifying the new coordinate the top-left of the fenestra window should be moved to
///  * `animated` - an optional boolean, default false, indicating whether the frame change should be performed with a smooth transition animation (true) or not (false).
///
/// Returns:
///  * If an argument is provided, the fenestra object; otherwise the current value.
///
/// Notes:
///  * a point-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the fenestra (keys `x`  and `y`). The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
///
///  * See also [hs.fenestra:animationDuration](#animationDuration).
static int window_topLeft(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    NSRect oldFrame = RectWithFlippedYCoordinate(window.frame);
    if (lua_gettop(L) == 1) {
        [skin pushNSPoint:oldFrame.origin] ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
        NSPoint newCoord = [skin tableToPointAtIndex:2] ;
        BOOL animate = (lua_gettop(L) == 3) ? (BOOL)lua_toboolean(L, 3) : NO ;
        NSRect  newFrame = RectWithFlippedYCoordinate(NSMakeRect(newCoord.x, newCoord.y, oldFrame.size.width, oldFrame.size.height)) ;
        [window setFrame:newFrame display:YES animate:animate];
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs.fenestra:size([size], [animated]) -> fenestraObject | rect-table
/// Method
/// Get or set the size of the fenestra window.
///
/// Parameters:
///  * `size`     - an optional size-table specifying the width and height the fenestra window should be resized to
///  * `animated` - an optional boolean, default false, indicating whether the frame change should be performed with a smooth transition animation (true) or not (false).
///
/// Returns:
///  * If an argument is provided, the fenestra object; otherwise the current value.
///
/// Notes:
///  * a size-table is a table with key-value pairs specifying the size (keys `h` and `w`) the fenestra window should be resized to. The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
///
///  * See also [hs.fenestra:animationDuration](#animationDuration).
static int window_size(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    NSRect oldFrame = window.frame;
    if (lua_gettop(L) == 1) {
        [skin pushNSSize:oldFrame.size] ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
        NSSize newSize  = [skin tableToSizeAtIndex:2] ;
        BOOL animate = (lua_gettop(L) == 3) ? (BOOL)lua_toboolean(L, 3) : NO ;
        NSRect newFrame = NSMakeRect(oldFrame.origin.x, oldFrame.origin.y + oldFrame.size.height - newSize.height, newSize.width, newSize.height) ;
        [window setFrame:newFrame display:YES animate:animate] ;
        lua_pushvalue(L, 1) ;
    }
    return 1;
}

/// hs.fenestra:animationBehavior([behavior]) -> fenestraObject | string
/// Method
/// Get or set the macOS animation behavior used when the fenestra window is shown or hidden.
///
/// Parameters:
///  * `behavior` - an optional string specifying the animation behavior. The string should be one of the following:
///    * "default"        - The automatic animation that’s appropriate to the window type.
///    * "none"           - No automatic animation used. This is the default which makes window appearance immediate unless you use the fade time argument with [hs.fenestra:show](#show), [hs.fenestra:hide](#hide), or [hs.fenestra:delete](#delete).
///    * "documentWindow" - The animation behavior that’s appropriate to a document window.
///    * "utilityWindow"  - The animation behavior that’s appropriate to a utility window.
///    * "alertPanel"     - The animation behavior that’s appropriate to an alert window.
///
/// Returns:
///  * If an argument is provided, the fenestra object; otherwise the current value.
///
/// Notes:
///  * This animation is separate from the fade-in and fade-out options provided with the [hs.fenestra:show](#show), [hs.fenestra:hide](#hide), and [hs.fenestra:delete](#delete) methods and is provided by the macOS operating system itself.
static int window_animationBehavior(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    NSDictionary *mapping = @{
        @"default"        : @(NSWindowAnimationBehaviorDefault),
        @"none"           : @(NSWindowAnimationBehaviorNone),
        @"documentWindow" : @(NSWindowAnimationBehaviorDocumentWindow),
        @"utilityWindow"  : @(NSWindowAnimationBehaviorUtilityWindow),
        @"alertPanel"     : @(NSWindowAnimationBehaviorAlertPanel),
    } ;

    if (lua_gettop(L) == 1) {
        NSNumber *animationBehavior = @(window.animationBehavior) ;
        NSString *value = [[mapping allKeysForObject:animationBehavior] firstObject] ;
        if (value) {
            [skin pushNSObject:value] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized animationBehavior %@ -- notify developers", USERDATA_TAG, animationBehavior]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSNumber *value = mapping[[skin toNSObjectAtIndex:2]] ;
        if (value) {
            window.animationBehavior = [value integerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of '%@'", [[mapping allKeys] componentsJoinedByString:@"', '"]] UTF8String]) ;
        }
    }
    return 1 ;
}

/// hs.fenestra:animationDuration([duration | nil]) -> fenestraObject | number | nil
/// Method
/// Get or set the macOS animation duration for smooth frame transitions used when the fenestra window is moved or resized.
///
/// Parameters:
///  * `duration` - a number or nil, default nil, specifying the time in seconds to move or resize by 150 pixels when the `animated` flag is set for [hs.fenestra:frame](#frame), [hs.fenestra:topLeft](#topLeft), or [hs.fenestra:size](#size). An explicit `nil` defaults to the macOS default, which is currently 0.2.
///
/// Returns:
///  * If an argument is provided, the fenestra object; otherwise the current value.
static int fenestra_animationDuration(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:window.animationTime] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            window.animationTime = nil ;
        } else {
            window.animationTime = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_collectionBehavior(lua_State *L) {
// NOTE:  This method is wrapped in init.lua
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    NSWindowCollectionBehavior oldBehavior = window.collectionBehavior ;
    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)oldBehavior) ;
    } else {
// FIXME: can we check this through logic or do we have to use try/catch?
        @try {
            window.collectionBehavior = (NSUInteger)lua_tointeger(L, 2) ;
        }
        @catch ( NSException *theException ) {
            window.collectionBehavior = oldBehavior ;
            return luaL_error(L, "invalid collection behavior: %s, %s", [[theException name] UTF8String], [[theException reason] UTF8String]) ;
        }
        lua_pushvalue(L, 1);
    }
    return 1 ;
}

// /// hs.fenestra:delete([fadeOut]) -> none
// /// Method
// /// Destroys the fenestra object, optionally fading it out first (if currently visible).
// ///
// /// Parameters:
// ///  * `fadeOut` - An optional number of seconds over which to fade out the fenestra object. Defaults to zero (i.e. immediate).
// ///
// /// Returns:
// ///  * None
// ///
// /// Notes:
// ///  * This method is automatically called during garbage collection, notably during a Hammerspoon termination or reload, with a fade time of 0.
// static int fenestra_delete(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
//     HSFenestra *window = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 1) {
//         lua_pushcfunction(L, userdata_gc) ;
//         lua_pushvalue(L, 1) ;
//         if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
//             [skin logError:[NSString stringWithFormat:@"%s:error invoking __gc for delete method:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
//             lua_pop(L, 1) ;
//             [window orderOut:nil] ; // the least we can do is hide the fenestra if an error occurs with __gc
//         }
//     } else {
//         [window fadeOut:lua_tonumber(L, 2) andDelete:YES] ;
//     }
//     lua_pushnil(L);
//     return 1;
// }

/// hs.fenestra:hide([fadeOut]) -> fenestraObject
/// Method
/// Hides the fenestra object
///
/// Parameters:
///  * `fadeOut` - An optional number of seconds over which to fade out the fenestra object. Defaults to zero (i.e. immediate).
///
/// Returns:
///  * The fenestra object
static int fenestra_hide(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [window orderOut:window];
    } else {
        [window fadeOut:lua_tonumber(L, 2) andClose:NO];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.fenestra:show([fadeIn]) -> fenestraObject
/// Method
/// Displays the fenestra object
///
/// Parameters:
///  * `fadeIn` - An optional number of seconds over which to fade in the fenestra object. Defaults to zero (i.e. immediate).
///
/// Returns:
///  * The fenestra object
static int fenestra_show(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [window makeKeyAndOrderFront:nil];
    } else {
        [window fadeIn:lua_tonumber(L, 2)];
    }
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.fenestra:orderAbove([fenestra2]) -> fenestraObject
/// Method
/// Moves the fenestra window above fenestra2, or all fenestra windows in the same presentation level, if fenestra2 is not given.
///
/// Parameters:
///  * `fenestra2` -An optional fenestra window object to place the fenestra window above.
///
/// Returns:
///  * The fenestra object
///
/// Notes:
///  * If the fenestra window and fenestra2 are not at the same presentation level, this method will will move the window as close to the desired relationship as possible without changing the object's presentation level. See [hs.fenestra.level](#level).
static int window_orderAbove(lua_State *L) {
    return window_orderHelper(L, NSWindowAbove) ;
}

/// hs.fenestra:orderBelow([fenestra2]) -> fenestraObject
/// Method
/// Moves the fenestra window below fenestra2, or all fenestra windows in the same presentation level, if fenestra2 is not given.
///
/// Parameters:
///  * `fenestra2` -An optional fenestra window object to place the fenestra window below.
///
/// Returns:
///  * The fenestra object
///
/// Notes:
///  * If the fenestra window and fenestra2 are not at the same presentation level, this method will will move the window as close to the desired relationship as possible without changing the object's presentation level. See [hs.fenestra.level](#level).
static int window_orderBelow(lua_State *L) {
    return window_orderHelper(L, NSWindowBelow) ;
}

static int window_level(lua_State *L) {
// NOTE:  This method is wrapped in init.lua
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSFenestra *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, window.level) ;
    } else {
        lua_Integer targetLevel = lua_tointeger(L, 2) ;
        lua_Integer minLevel = CGWindowLevelForKey(kCGMinimumWindowLevelKey) ;
        lua_Integer maxLevel = CGWindowLevelForKey(kCGMaximumWindowLevelKey) ;
        window.level = (targetLevel < minLevel) ? minLevel : ((targetLevel > maxLevel) ? maxLevel : targetLevel) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants

/// hs.fenestra.windowBehaviors[]
/// Constant
/// Array of window behavior labels for determining how an fenestra is handled in Spaces and Exposé
///
/// * `default`                   - The window can be associated to one space at a time.
/// * `canJoinAllSpaces`          - The window appears in all spaces. The menu bar behaves this way.
/// * `moveToActiveSpace`         - Making the window active does not cause a space switch; the window switches to the active space.
///
/// Only one of these may be active at a time:
///
/// * `managed`                   - The window participates in Spaces and Exposé. This is the default behavior if windowLevel is equal to NSNormalWindowLevel.
/// * `transient`                 - The window floats in Spaces and is hidden by Exposé. This is the default behavior if windowLevel is not equal to NSNormalWindowLevel.
/// * `stationary`                - The window is unaffected by Exposé; it stays visible and stationary, like the desktop window.
///
/// Only one of these may be active at a time:
///
/// * `participatesInCycle`       - The window participates in the window cycle for use with the Cycle Through Windows Window menu item.
/// * `ignoresCycle`              - The window is not part of the window cycle for use with the Cycle Through Windows Window menu item.
///
/// Only one of these may be active at a time:
///
/// * `fullScreenPrimary`         - A window with this collection behavior has a fullscreen button in the upper right of its titlebar.
/// * `fullScreenAuxiliary`       - Windows with this collection behavior can be shown on the same space as the fullscreen window.
/// * `fullScreenNone`            - The window can not be made fullscreen
///
/// Only one of these may be active at a time:
///
/// * `fullScreenAllowsTiling`    - A window with this collection behavior be a full screen tile window and does not have to have `fullScreenPrimary` set.
/// * `fullScreenDisallowsTiling` - A window with this collection behavior cannot be made a fullscreen tile window, but it can have `fullScreenPrimary` set.  You can use this setting to prevent other windows from being placed in the window’s fullscreen tile.
static int window_collectionTypeTable(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSWindowCollectionBehaviorDefault) ;                   lua_setfield(L, -2, "default") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorCanJoinAllSpaces) ;          lua_setfield(L, -2, "canJoinAllSpaces") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorMoveToActiveSpace) ;         lua_setfield(L, -2, "moveToActiveSpace") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorManaged) ;                   lua_setfield(L, -2, "managed") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorTransient) ;                 lua_setfield(L, -2, "transient") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorStationary) ;                lua_setfield(L, -2, "stationary") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorParticipatesInCycle) ;       lua_setfield(L, -2, "participatesInCycle") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorIgnoresCycle) ;              lua_setfield(L, -2, "ignoresCycle") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenPrimary) ;         lua_setfield(L, -2, "fullScreenPrimary") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenAuxiliary) ;       lua_setfield(L, -2, "fullScreenAuxiliary") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenNone) ;            lua_setfield(L, -2, "fullScreenNone") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenAllowsTiling) ;    lua_setfield(L, -2, "fullScreenAllowsTiling") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenDisallowsTiling) ; lua_setfield(L, -2, "fullScreenDisallowsTiling") ;
    return 1 ;
}


/// hs.fenestra.levels
/// Constant
/// A table of predefined window levels usable with [hs.fenestra:level](#level)
///
/// Predefined levels are:
///  * _MinimumWindowLevelKey - lowest allowed window level. If you specify a level lower than this, it will be set to this value.
///  * desktop
///  * desktopIcon            - [hs.fenestra:sendToBack](#sendToBack) is equivalent to this level - 1
///  * normal                 - normal application windows
///  * floating               - equivalent to [hs.fenestra:bringToFront(false)](#bringToFront); where "Always Keep On Top" windows are usually set
///  * tornOffMenu
///  * modalPanel             - modal alert dialog
///  * utility
///  * dock                   - level of the Dock
///  * mainMenu               - level of the Menubar
///  * status
///  * popUpMenu              - level of a menu when displayed (open)
///  * overlay
///  * help
///  * dragging
///  * screenSaver            - equivalent to [hs.fenestra:bringToFront(true)](#bringToFront)
///  * assistiveTechHigh
///  * cursor
///  * _MaximumWindowLevelKey - highest allowed window level. If you specify a level larger than this, it will be set to this value.
///
/// Notes:
///  * These key names map to the constants used in CoreGraphics to specify window levels and may not actually be used for what the name might suggest. For example, tests suggest that an active screen saver actually runs at a level of 2002, rather than at 1000, which is the window level corresponding to `hs.fenestra.levels.screenSaver`.
///
///  * Each window level is sorted separately and [hs.fenestra:orderAbove](#orderAbove) and [hs.fenestra:orderBelow](#orderBelow) only arrange windows within the same level.
///
///  * If you use Dock hiding (or in 10.11+, Menubar hiding) please note that when the Dock (or Menubar) is popped up, it is done so with an implicit orderAbove, which will place it above any items you may also draw at the Dock (or MainMenu) level.
///
///  * Recent versions of macOS have made significant changes to the way full-screen apps work which may prevent placing Hammerspoon elements above some full screen applications.  At present the exact conditions are not fully understood and no work around currently exists in these situations.
static int window_windowLevels(lua_State *L) {
    lua_newtable(L) ;
//       lua_pushinteger(L, CGWindowLevelForKey(kCGBaseWindowLevelKey)) ;              lua_setfield(L, -2, "kCGBaseWindowLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGMinimumWindowLevelKey)) ;           lua_setfield(L, -2, "_MinimumWindowLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDesktopWindowLevelKey)) ;           lua_setfield(L, -2, "desktop") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDesktopIconWindowLevelKey)) ;       lua_setfield(L, -2, "desktopIcon") ;
//       lua_pushinteger(L, CGWindowLevelForKey(kCGBackstopMenuLevelKey)) ;            lua_setfield(L, -2, "backstopMenuLevel") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGNormalWindowLevelKey)) ;            lua_setfield(L, -2, "normal") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGFloatingWindowLevelKey)) ;          lua_setfield(L, -2, "floating") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGTornOffMenuWindowLevelKey)) ;       lua_setfield(L, -2, "tornOffMenu") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGModalPanelWindowLevelKey)) ;        lua_setfield(L, -2, "modalPanel") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGUtilityWindowLevelKey)) ;           lua_setfield(L, -2, "utility") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDockWindowLevelKey)) ;              lua_setfield(L, -2, "dock") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGMainMenuWindowLevelKey)) ;          lua_setfield(L, -2, "mainMenu") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGStatusWindowLevelKey)) ;            lua_setfield(L, -2, "status") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGPopUpMenuWindowLevelKey)) ;         lua_setfield(L, -2, "popUpMenu") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGOverlayWindowLevelKey)) ;           lua_setfield(L, -2, "overlay") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGHelpWindowLevelKey)) ;              lua_setfield(L, -2, "help") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDraggingWindowLevelKey)) ;          lua_setfield(L, -2, "dragging") ;
//       lua_pushinteger(L, CGWindowLevelForKey(kCGNumberOfWindowLevelKeys)) ;         lua_setfield(L, -2, "kCGNumberOfWindowLevelKeys") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGScreenSaverWindowLevelKey)) ;       lua_setfield(L, -2, "screenSaver") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGAssistiveTechHighWindowLevelKey)) ; lua_setfield(L, -2, "assistiveTechHigh") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGCursorWindowLevelKey)) ;            lua_setfield(L, -2, "cursor") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGMaximumWindowLevelKey)) ;           lua_setfield(L, -2, "_MaximumWindowLevelKey") ;
    return 1 ;
}
/// hs.fenestra.masks[]
/// Constant
/// A table containing valid masks for the fenestra window.
///
/// Table Keys:
///  * `borderless`             - The window has no border decorations
///  * `titled`                 - The window title bar is displayed
///  * `closable`               - The window has a close button
///  * `miniaturizable`         - The window has a minimize button
///  * `resizable`              - The window is resizable
///  * `texturedBackground`     - The window has a texturized background
///  * `fullSizeContentView`    - If titled, the titlebar is within the frame size specified at creation, not above it.  Shrinks actual content area by the size of the titlebar, if present.
///  * `utility`                - If titled, the window shows a utility panel titlebar (thinner than normal)
///  * `nonactivating`          - If the window is activated, it won't bring other Hammerspoon windows forward as well
///  * `HUD`                    - Requires utility; the window titlebar is shown dark and can only show the close button and title (if they are set)
///
/// The following are still being evaluated and may require additional support or specific methods to be in effect before use. Use with caution.
///  * `unifiedTitleAndToolbar` -
///  * `fullScreen`             -
///  * `docModal`               -
///
/// Notes:
///  * The Maximize button in the window title is enabled when Resizable is set.
///  * The Close, Minimize, and Maximize buttons are only visible when the Window is also Titled.
///
///  * Not all combinations of masks are valid and will through an error if set with [hs.fenestra:mask](#mask).
static int window_windowMasksTable(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSWindowStyleMaskBorderless) ;             lua_setfield(L, -2, "borderless") ;
    lua_pushinteger(L, NSWindowStyleMaskTitled) ;                 lua_setfield(L, -2, "titled") ;
    lua_pushinteger(L, NSWindowStyleMaskClosable) ;               lua_setfield(L, -2, "closable") ;
    lua_pushinteger(L, NSWindowStyleMaskMiniaturizable) ;         lua_setfield(L, -2, "miniaturizable") ;
    lua_pushinteger(L, NSWindowStyleMaskResizable) ;              lua_setfield(L, -2, "resizable") ;
    lua_pushinteger(L, NSWindowStyleMaskTexturedBackground) ;     lua_setfield(L, -2, "texturedBackground") ;
    lua_pushinteger(L, NSWindowStyleMaskUnifiedTitleAndToolbar) ; lua_setfield(L, -2, "unifiedTitleAndToolbar") ;
    lua_pushinteger(L, NSWindowStyleMaskFullScreen) ;             lua_setfield(L, -2, "fullScreen") ;
    lua_pushinteger(L, NSWindowStyleMaskFullSizeContentView) ;    lua_setfield(L, -2, "fullSizeContentView") ;
    lua_pushinteger(L, NSWindowStyleMaskUtilityWindow) ;          lua_setfield(L, -2, "utility") ;
    lua_pushinteger(L, NSWindowStyleMaskDocModalWindow) ;         lua_setfield(L, -2, "docModal") ;
    lua_pushinteger(L, NSWindowStyleMaskNonactivatingPanel) ;     lua_setfield(L, -2, "nonactivating") ;
    lua_pushinteger(L, NSWindowStyleMaskHUDWindow) ;              lua_setfield(L, -2, "HUD") ;
    return 1 ;
}

/// hs.fenestra.notifications[]
/// Constant
/// An array containing all of the notifications which can be enabled with [hs.fenestra:notificationMessages](#notificationMessages).
///
/// Array values:
///  * `didBecomeKey`               - The window has become the key window; controls or elements of the window can now be manipulated by the user and keyboard entry (if appropriate) will be captured by the relevant elements.
///  * `didBecomeMain`              - The window has become the main window of Hammerspoon. In most cases, this is equivalent to the window becoming key and both notifications may be sent if they are being watched for.
///  * `didChangeBackingProperties` - The backing properties of the window have changed. This will be posted if the scaling factor of color space for the window changes, most likely because it moved to a different screen.
///  * `didChangeOcclusionState`    - The window's occlusion state has changed (i.e. whether or not at least part of the window is currently visible)
///  * `didChangeScreen`            - Part of the window has moved onto or off of the current screens
///  * `didChangeScreenProfile`     - The screen the window is on has changed its properties or color profile
///  * `didDeminiaturize`           - The window has been de-miniaturized
///  * `didEndLiveResize`           - The user resized the window
///  * `didEndSheet`                - The window has closed an attached sheet
///  * `didEnterFullScreen`         - The window has entered full screen mode
///  * `didEnterVersionBrowser`     - The window will enter version browser mode
///  * `didExitFullScreen`          - The window has exited full screen mode
///  * `didExitVersionBrowser`      - The window will exit version browser mode
///  * `didExpose`                  - Posted whenever a portion of a nonretained window is exposed - may not be applicable to the way Hammerspoon manages windows; will have to evaluate further
///  * `didFailToEnterFullScreen`   - The window failed to enter full screen mode
///  * `didFailToExitFullScreen`    - The window failed to exit full screen mode
///  * `didMiniaturize`             - The window was miniaturized
///  * `didMove`                    - The window was moved
///  * `didResignKey`               - The window has stopped being the key window
///  * `didResignMain`              - The window has stopped being the main window
///  * `didResize`                  - The window did resize
///  * `didUpdate`                  - The window received an update message (a request to redraw all content and the content of its subviews)
///  * `willBeginSheet`             - The window is about to open an attached sheet
///  * `willClose`                  - The window is about to close; the window has not closed yet, so its userdata is still valid, even if it's set to be deleted on close, so do any clean up at this time.
///  * `willEnterFullScreen`        - The window is about to enter full screen mode but has not done so yet
///  * `willEnterVersionBrowser`    - The window will enter version browser mode but has not done so yet
///  * `willExitFullScreen`         - The window will exit full screen mode but has not done so yet
///  * `willExitVersionBrowser`     - The window will exit version browser mode but has not done so yet
///  * `willMiniaturize`            - The window will miniaturize but has not done so yet
///  * `willMove`                   - The window will move but has not done so yet
///  * `willStartLiveResize`        - The window is about to be resized by the user
///
/// Notes:
///  * Not all of the notifications here are currently fully supported and the specific details and support will change as this module and its submodules evolve and get fleshed out. Some may be removed if it is determined they will never be supported by this module while others may lead to additions when the need arises. Please post an issue or pull request if you would like to request specific support or provide additions yourself.

static int window_notifications(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    fenestraNotifications = @[
        @"didBecomeKey",
        @"didBecomeMain",
        @"didChangeBackingProperties",
        @"didChangeOcclusionState",
        @"didChangeScreen",
        @"didChangeScreenProfile",
        @"didDeminiaturize",
        @"didEndLiveResize",
        @"didEndSheet",
        @"didEnterFullScreen",
        @"didEnterVersionBrowser",
        @"didExitFullScreen",
        @"didExitVersionBrowser",
        @"didExpose",
        @"didFailToEnterFullScreen",
        @"didFailToExitFullScreen",
        @"didMiniaturize",
        @"didMove",
        @"didResignKey",
        @"didResignMain",
        @"didResize",
        @"didUpdate",
        @"willBeginSheet",
        @"willClose",
        @"willEnterFullScreen",
        @"willEnterVersionBrowser",
        @"willExitFullScreen",
        @"willExitVersionBrowser",
        @"willMiniaturize",
        @"willMove",
        @"willStartLiveResize",
    ] ;
    [skin pushNSObject:fenestraNotifications] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSFenestra(lua_State *L, id obj) {
    HSFenestra *value = obj ;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSFenestra *)) ;
    *valuePtr = (__bridge_retained void *)value ;
    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static id toHSFenestraFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSFenestra *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSFenestra, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSFenestra *obj = [skin luaObjectAtIndex:1 toClass:"HSFenestra"] ;
    NSString *title = obj.title ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ @%@ (%p)", USERDATA_TAG, title, NSStringFromRect(RectWithFlippedYCoordinate(obj.frame)), lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSFenestra *obj1 = [skin luaObjectAtIndex:1 toClass:"HSFenestra"] ;
        HSFenestra *obj2 = [skin luaObjectAtIndex:2 toClass:"HSFenestra"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

// The monster, in his consternation, demonstrates defenestration... -- Bill Waterson
static int userdata_gc(lua_State* L) {
    HSFenestra *obj = get_objectFromUserdata(__bridge_transfer HSFenestra, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L];
            obj.notificationCallback   = [skin luaUnref:refTable ref:obj.notificationCallback] ;
            obj.delegate               = nil ;
           [skin luaRelease:refTable forNSObject:obj.contentView] ;
            obj.contentView            = nil ;
// causes crash in autoreleasepool during reload or quit; did confirm dealloc invoked on gc, though,
// so I guess it doesn't matter. May need to consider wrapper to mimic drawing/canvas/webview behavior of
// requiring explicit delete since this implementation could have multiple ud for the same object still
// floating around
//             obj.releasedWhenClosed     = YES ;
            [obj close] ;
            obj                        = nil ;
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
    {"appearance",                 appearanceCustomization_appearance},

    {"allowTextEntry",             fenestra_allowTextEntry},
    {"animationDuration",          fenestra_animationDuration},
    {"hide",                       fenestra_hide},
    {"show",                       fenestra_show},

    {"alphaValue",                 window_alphaValue},
    {"animationBehavior",          window_animationBehavior},
    {"backgroundColor",            window_backgroundColor},
    {"collectionBehavior",         window_collectionBehavior},
    {"frame",                      window_frame},
    {"hasShadow",                  window_hasShadow},
    {"ignoresMouseEvents",         window_ignoresMouseEvents},
    {"level",                      window_level},
    {"opaque",                     window_opaque},
    {"orderAbove",                 window_orderAbove},
    {"orderBelow",                 window_orderBelow},
    {"size",                       window_size},
    {"styleMask",                  window_styleMask},
    {"title",                      window_title},
    {"titlebarAppearsTransparent", window_titlebarAppearsTransparent},
    {"titleVisibility",            window_titleVisibility},
    {"topLeft",                    window_topLeft},

//     {"notificationCallback",       guitk_notificationCallback},
//     {"notificationMessages",       guitk_notificationWatchFor},
//     {"accessibilitySubrole",       guitk_accessibilitySubrole},
//     {"isOccluded",                 window_isOccluded},
//     {"isShowing",                  window_isShowing},
//     {"contentManager",             window_contentView},
//     {"passthroughCallback",        window_passthroughCallback},
//     {"activeElement",              window_firstResponder},

    {"__tostring",                 userdata_tostring},
    {"__eq",                       userdata_eq},
    {"__gc",                       userdata_gc},
    {NULL,                         NULL}
} ;

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"minimumWidth",        window_minFrameWidthWithTitle},
    {"contentRectForFrame", window_contentRectForFrameRect},
    {"frameRectForContent", window_frameRectForContentRect},
    {"new",                 window_new},
    {NULL,                  NULL}
} ;

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// } ;

int luaopen_hs_fenestra_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib] ;

    [skin registerPushNSHelper:pushHSFenestra         forClass:"HSFenestra"] ;
    [skin registerLuaObjectHelper:toHSFenestraFromLua forClass:"HSFenestra"
                                           withUserdataMapping:USERDATA_TAG] ;

    window_collectionTypeTable(L) ; lua_setfield(L, -2, "behaviors") ;
    window_windowLevels(L) ;        lua_setfield(L, -2, "levels") ;
    window_windowMasksTable(L) ;    lua_setfield(L, -2, "masks") ;
    window_notifications(L) ;       lua_setfield(L, -2, "notifications") ;

    return 1 ;
}
