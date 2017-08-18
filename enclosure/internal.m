@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.enclosure" ;
static int refTable    = LUA_NOREF ;
static int logTableRef = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

static NSArray *enclosureNotifications ;

typedef enum {
  TSB_No = 0,
  TSB_Yes,
  TSB_Undefined
} TriStateBool ;

#pragma mark - Support Functions and Classes

static inline NSRect RectWithFlippedYCoordinate(NSRect theRect) ;
static int userdata_gc(lua_State* L) ;

@interface HSASMEnclosure : NSPanel <NSWindowDelegate>
@property int          selfRef ;
@property int          notificationCallback ;
@property NSMutableSet *notifyFor ;
@property TriStateBool specifiedKeyWindowState ;
@property TriStateBool specifiedMainWindowState ;
@property BOOL         honorPerformClose ;
@property BOOL         closeOnEscape ;
@property BOOL         assignedHSView ;
@property NSString     *subroleOverride ;
@property NSNumber     *animationTime ;
@end

@implementation HSASMEnclosure

- (instancetype)initWithContentRect:(NSRect)contentRect
                          styleMask:(NSWindowStyleMask)windowStyle
                            backing:(NSBackingStoreType)bufferingType
                              defer:(BOOL)deferCreation {

    if (!(isfinite(contentRect.origin.x) && isfinite(contentRect.origin.y) && isfinite(contentRect.size.height) && isfinite(contentRect.size.width))) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:coordinates must be finite numbers", USERDATA_TAG]];
        return nil;
    }

    @try {
        self = [super initWithContentRect:contentRect
                                styleMask:windowStyle
                                  backing:bufferingType
                                    defer:deferCreation];
    }
    @catch ( NSException *theException ) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid style mask - %@, %@", USERDATA_TAG, theException.name, theException.reason]] ;
        self = nil ;
    }

    if (self) {
        [self setFrameOrigin:RectWithFlippedYCoordinate(contentRect).origin];

        _selfRef                  = LUA_NOREF ;
        _notificationCallback     = LUA_NOREF ;
        _notifyFor                = [[NSMutableSet alloc] init] ;
        _specifiedKeyWindowState  = TSB_Undefined ;
        _specifiedMainWindowState = TSB_Undefined ;
        _honorPerformClose        = YES ;
        _closeOnEscape            = NO ;
        _assignedHSView           = NO ;
        _subroleOverride          = nil ;
        _animationTime            = nil ;

        // memory management becomes *much* harder if we allow these to be changeable from
        // Lua; better to just not support them unless/until required for something
        self.releasedWhenClosed   = NO ;
        self.restorable           = NO ;
        self.delegate             = self ;
    }
    return self;
}

- (BOOL)canBecomeKeyWindow {
    // if we've defined a state for the window as a whole, honor it
    if (_specifiedKeyWindowState != TSB_Undefined) return (BOOL)_specifiedKeyWindowState ;

    // otherwise, test contentView and subviews and return when we find the first YES
    __block BOOL allowKey = NO ;
    if (self.contentView) {
        if ([self.contentView respondsToSelector:@selector(canBecomeKeyView)]) {
            allowKey = [self.contentView canBecomeKeyView] ;
        }
        if (allowKey) return YES ;

        NSArray *subviews = self.contentView.subviews ;
        if (subviews) {
            [subviews enumerateObjectsUsingBlock:^(NSView *view, __unused NSUInteger idx, BOOL *stop) {
                if ([view respondsToSelector:@selector(canBecomeKeyView)]) {
                    allowKey = [view canBecomeKeyView] ;
                }
                if (allowKey) *stop = YES ;
            }] ;
        }
        if (allowKey) return YES ;
    }

    // else attempt to mimic the NSWindow defaults of YES when has title bar or is resizable
    if ((NSWindowStyleMaskResizable | NSWindowStyleMaskTitled) & self.styleMask) {
        return YES ;
    } else {
        return NO ;
    }
}

- (BOOL)canBecomeMainWindow {
     // if we've defined a state for the window as a whole, honor it
    if (_specifiedMainWindowState != TSB_Undefined) return (BOOL)_specifiedMainWindowState ;

    // else attempt to mimic the NSWindow defaults of YES when has title bar or is resizable
    if ((NSWindowStyleMaskResizable | NSWindowStyleMaskTitled) & self.styleMask) {

        return YES ;
    } else {
        return NO ;
    }
}

// - (BOOL)queryBoolFrom:(id)target with:(SEL)selector {
//     NSMethodSignature *signature  = [NSMethodSignature signatureWithObjCTypes:"c16@0:8"] ;
//     NSInvocation      *invocation = [NSInvocation invocationWithMethodSignature:signature] ;
//     BOOL result ;
//     [invocation setTarget:target] ;
//     [invocation setSelector:selector] ;
//     [invocation getReturnValue:&result] ;
//     return result ;
// }

- (NSString *)accessibilitySubrole {
    if (_subroleOverride) {
        if ([_subroleOverride isEqualToString:@""]) {
            return [super accessibilitySubrole] ;
        } else {
            return _subroleOverride ;
        }
    } else {
        return [[super accessibilitySubrole] stringByAppendingString:@".Hammerspoon"] ;
    }
}

- (NSTimeInterval)animationResizeTime:(NSRect)newWindowFrame {
    if (_animationTime) {
        return [_animationTime doubleValue] ;
    } else {
        return [super animationResizeTime:newWindowFrame] ;
    }
}

#pragma mark - NSResponder overrides

// used in hs.webview to support escape to close window
- (void)cancelOperation:(id)sender {
    if (_closeOnEscape) [super cancelOperation:sender] ;
}

#pragma mark - NSWindowDelegate Methods

- (BOOL)windowShouldClose:(id __unused)sender {
    return _honorPerformClose ;
}

#pragma mark * NSWindowDelegate Notifications

- (void)performNotificationCallbackFor:(NSString *)message with:(NSNotification *)notification {
    if (_notificationCallback != LUA_NOREF && [_notifyFor containsObject:message]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            [skin pushLuaRef:refTable ref:self->_notificationCallback] ;
            [skin pushNSObject:notification.object] ;
            [skin pushNSObject:message] ;
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                NSString *errorMsg = [skin toNSObjectAtIndex:-1] ;
                lua_pop([skin L], 1) ;
                [skin logError:[NSString stringWithFormat:@"%s:%@ notification callback error:%@", USERDATA_TAG, message, errorMsg]] ;
            }
        }) ;
    }
}

// - (void)window:(NSWindow *)window didDecodeRestorableState:(NSCoder *)state {}
// - (void)window:(NSWindow *)window startCustomAnimationToEnterFullScreenOnScreen:(NSScreen *)screen withDuration:(NSTimeInterval)duration {}
// - (void)window:(NSWindow *)window startCustomAnimationToEnterFullScreenWithDuration:(NSTimeInterval)duration {}
// - (void)window:(NSWindow *)window startCustomAnimationToExitFullScreenWithDuration:(NSTimeInterval)duration {}
// - (void)window:(NSWindow *)window willEncodeRestorableState:(NSCoder *)state {}
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

@end

#pragma mark -

static inline NSRect RectWithFlippedYCoordinate(NSRect theRect) {
    return NSMakeRect(theRect.origin.x,
                      [[NSScreen screens][0] frame].size.height - theRect.origin.y - theRect.size.height,
                      theRect.size.width,
                      theRect.size.height) ;
}

static int enclosure_orderHelper(lua_State *L, NSWindowOrderingMode mode) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSASMEnclosure *theEnclosure = [skin toNSObjectAtIndex:1] ;
    NSInteger relativeTo = 0 ;

    if (lua_gettop(L) > 1) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
        HSASMEnclosure *otherEnclosure = [skin toNSObjectAtIndex:2] ;
        if (otherEnclosure) relativeTo = [otherEnclosure windowNumber] ;
    }
    if (theEnclosure) [theEnclosure orderWindow:mode relativeTo:relativeTo] ;
    return 1 ;
}

#pragma mark - Module Functions

static int window_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;

    NSUInteger windowStyle = (lua_gettop(L) == 2) ? (NSUInteger)lua_tointeger(L, 2)
                                                  : NSWindowStyleMaskBorderless ;

    HSASMEnclosure *window = [[HSASMEnclosure alloc] initWithContentRect:[skin tableToRectAtIndex:1]
                                                               styleMask:windowStyle
                                                                 backing:NSBackingStoreBuffered
                                                                   defer:YES] ;
    if (window) {
        [skin pushNSObject:window] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int disableUpdates(__unused lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    NSDisableScreenUpdates() ;
    return 0 ;
}

static int enableUpdates(__unused lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    NSEnableScreenUpdates() ;
    return 0 ;
}

#pragma mark - Module Methods

static int enclosure_notificationCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    // either way, lets release any function which may already be stored in the registry
    window.notificationCallback = [skin luaUnref:refTable ref:window.notificationCallback] ;
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2) ;
        window.notificationCallback = [skin luaRef:refTable] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int enclosure_notificationWatchFor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TSTRING | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:window.notifyFor] ;
    } else {
        NSArray *watchingFor ;
        if (lua_type(L, 2) == LUA_TSTRING) {
            watchingFor = @[ [skin toNSObjectAtIndex:2] ] ;
        } else {
            watchingFor = [skin toNSObjectAtIndex:2] ;
            BOOL isGood = YES ;
            if ([watchingFor isKindOfClass:[NSArray class]]) {
                for (NSString *item in watchingFor) {
                    if (![item isKindOfClass:[NSString class]]) {
                        isGood = NO ;
                        break ;
                    }
                }
            } else {
                isGood = NO ;
            }
            if (!isGood) {
                return luaL_argerror(L, 2, "expected a string or an array of strings") ;
            }
        }
        BOOL willAdd = (lua_gettop(L) == 2) ? YES : (BOOL)lua_toboolean(L, 3) ;
        for (NSString *item in watchingFor) {
            if (![enclosureNotifications containsObject:item]) {
                return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one or more of the following:%@", [enclosureNotifications componentsJoinedByString:@", "]] UTF8String]) ;
            }
        }
        for (NSString *item in watchingFor) {
            if (willAdd) {
                [window.notifyFor addObject:item] ;
            } else {
                [window.notifyFor removeObject:item] ;
            }
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int enclosure_contentView(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (window.assignedHSView) {
            [skin pushNSObject:window.contentView] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            window.assignedHSView = NO ;
            // placeholder, since a window/panel always has one after init, let's follow that pattern
            window.contentView = [[NSView alloc] initWithFrame:window.contentView.bounds] ;
        } else if (lua_type(L, 2) == LUA_TUSERDATA) {
            NSView *newView = [skin toNSObjectAtIndex:2] ;
            if ([newView isKindOfClass:[NSView class]]) {
                window.assignedHSView = YES ;
//                 newView.bounds = window.contentView.bounds ;
                window.contentView = newView ;
//                 [window setFrameOrigin:RectWithFlippedYCoordinate(window.frame).origin];
            } else {
                return luaL_argerror(L, 2, "userdata object representing an NSView expected") ;
            }
        } else {
            return luaL_argerror(L, 2, "expected userdata or nil") ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int enclosure_contentViewBounds(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;
    NSRect boundsRect = NSZeroRect ;
    if (window.contentView) { // should never be nil, but just in case, we don't want to crash
        boundsRect = window.contentView.bounds ;
    }
    [skin pushNSRect:boundsRect] ;
    return 1 ;
}

static int enclosure_honorPerformClose(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.honorPerformClose) ;
    } else {
        window.honorPerformClose = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int enclosure_closeOnEscape(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.closeOnEscape) ;
    } else {
        window.closeOnEscape = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int enclosure_specifyCanBecomeKeyWindow(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        switch(window.specifiedKeyWindowState) {
            case TSB_No:
                lua_pushboolean(L, NO) ; break ;
            case TSB_Yes:
                lua_pushboolean(L, YES) ; break ;
            case TSB_Undefined:
                lua_pushnil(L) ; break ;
        }
    } else {
        if (lua_isnil(L, 2)) {
            window.specifiedKeyWindowState = TSB_Undefined ;
        } else if (lua_toboolean(L, 2)) {
            window.specifiedKeyWindowState = TSB_Yes ;
        } else {
            window.specifiedKeyWindowState = TSB_No ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int enclosure_specifyCanBecomeMainWindow(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        switch(window.specifiedMainWindowState) {
            case TSB_No:
                lua_pushboolean(L, NO) ; break ;
            case TSB_Yes:
                lua_pushboolean(L, YES) ; break ;
            case TSB_Undefined:
                lua_pushnil(L) ; break ;
        }
    } else {
        if (lua_isnil(L, 2)) {
            window.specifiedMainWindowState = TSB_Undefined ;
        } else if (lua_toboolean(L, 2)) {
            window.specifiedMainWindowState = TSB_Yes ;
        } else {
            window.specifiedMainWindowState = TSB_No ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_acceptsMouseMovedEvents(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.acceptsMouseMovedEvents) ;
    } else {
        window.acceptsMouseMovedEvents = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_allowsConcurrentViewDrawing(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.allowsConcurrentViewDrawing) ;
    } else {
        window.allowsConcurrentViewDrawing = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_allowsToolTipsWhenApplicationIsInactive(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.allowsToolTipsWhenApplicationIsInactive) ;
    } else {
        window.allowsToolTipsWhenApplicationIsInactive = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_canHide(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.canHide) ;
    } else {
        window.canHide = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_displaysWhenScreenProfileChanges(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.displaysWhenScreenProfileChanges) ;
    } else {
        window.displaysWhenScreenProfileChanges = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_hasShadow(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.hasShadow) ;
    } else {
        window.hasShadow = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_hidesOnDeactivate(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.hidesOnDeactivate) ;
    } else {
        window.hidesOnDeactivate = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_ignoresMouseEvents(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.ignoresMouseEvents) ;
    } else {
        window.ignoresMouseEvents = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_preservesContentDuringLiveResize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.preservesContentDuringLiveResize) ;
    } else {
        window.preservesContentDuringLiveResize = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_preventsApplicationTerminationWhenModal(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.preventsApplicationTerminationWhenModal) ;
    } else {
        window.preventsApplicationTerminationWhenModal = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// Seems to no longer be supported -- does nothing and always returns false
static int window_showsResizeIndicator(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.showsResizeIndicator) ;
    } else {
        window.showsResizeIndicator = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// Seems to no longer be supported -- does nothing and always returns false
static int window_showsToolbarButton(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.showsToolbarButton) ;
    } else {
        window.showsToolbarButton = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_titlebarAppearsTransparent(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.titlebarAppearsTransparent) ;
    } else {
        window.titlebarAppearsTransparent = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int appearanceCustomization_appearance(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:window.effectiveAppearance.name] ;
    } else {
        NSString     *type = [skin toNSObjectAtIndex:2] ;
        NSAppearance *appearance ;
        if ([type isEqualToString:@"aqua"]) {
            appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua] ;
        } else if ([type isEqualToString:@"light"]) {
            appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantLight] ;
        } else if ([type isEqualToString:@"dark"]) {
            appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark] ;
        }
        if (appearance) {
            window.appearance = appearance ;
        } else {
            return luaL_argerror(L, 2, "must be one of 'aqua', 'light', or 'dark'") ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_documentEdited(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.documentEdited) ;
    } else {
        window.documentEdited = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_excludedFromWindowsMenu(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.excludedFromWindowsMenu) ;
    } else {
        window.excludedFromWindowsMenu = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_movable(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.movable) ;
    } else {
        window.movable = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_movableByWindowBackground(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.movableByWindowBackground) ;
    } else {
        window.movableByWindowBackground = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_opaque(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.opaque) ;
    } else {
        window.opaque = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int panel_becomesKeyOnlyIfNeeded(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.becomesKeyOnlyIfNeeded) ;
    } else {
        window.becomesKeyOnlyIfNeeded = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int panel_worksWhenModal(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.worksWhenModal) ;
    } else {
        window.worksWhenModal = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int panel_floatingPanel(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.floatingPanel) ;
    } else {
        window.floatingPanel = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_alphaValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, window.alphaValue) ;
    } else {
        CGFloat newAlpha = luaL_checknumber(L, 2);
        window.alphaValue = ((newAlpha < 0.0) ? 0.0 : ((newAlpha > 1.0) ? 1.0 : newAlpha)) ;
        lua_pushvalue(L, 1);
    }
    return 1 ;
}

static int window_level(lua_State *L) {
// NOTE:  This method is wrapped in init.lua
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, window.level) ;
    } else {
        lua_Integer targetLevel = lua_tointeger(L, 2) ;
        window.level = (targetLevel < CGWindowLevelForKey(kCGMinimumWindowLevelKey)) ? CGWindowLevelForKey(kCGMinimumWindowLevelKey) : ((targetLevel > CGWindowLevelForKey(kCGMaximumWindowLevelKey)) ? CGWindowLevelForKey(kCGMaximumWindowLevelKey) : targetLevel) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_backgroundColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:window.backgroundColor] ;
    } else {
        window.backgroundColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_animationBehavior(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;
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

// FIXME: need integer version; see defaultDepthLimit and functions in docs to decipher its meaning
static int window_depthLimit(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;
    NSDictionary *mapping = @{
        @"default"   : @(0),
        @"24BitRGB"  : @(NSWindowDepthTwentyfourBitRGB),
        @"64BitRGB"  : @(NSWindowDepthSixtyfourBitRGB),
        @"128BitRGB" : @(NSWindowDepthOnehundredtwentyeightBitRGB),
    } ;

    if (lua_gettop(L) == 1) {
        NSNumber *depthLimit = @(window.depthLimit) ;
        NSString *value = [[mapping allKeysForObject:depthLimit] firstObject] ;
        if (value) {
            [skin pushNSObject:value] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized depthLimit %@ -- notify developers", USERDATA_TAG, depthLimit]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSNumber *value = mapping[[skin toNSObjectAtIndex:2]] ;
        if (value) {
            window.depthLimit = [value intValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of '%@'", [[mapping allKeys] componentsJoinedByString:@"', '"]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int window_sharingType(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;
    NSDictionary *mapping = @{
        @"none"      : @(NSWindowSharingNone),
        @"readOnly"  : @(NSWindowSharingReadOnly),
        @"readWrite" : @(NSWindowSharingReadWrite),
    } ;

    if (lua_gettop(L) == 1) {
        NSNumber *sharingType = @(window.sharingType) ;
        NSString *value = [[mapping allKeysForObject:sharingType] firstObject] ;
        if (value) {
            [skin pushNSObject:value] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized sharingType %@ -- notify developers", USERDATA_TAG, sharingType]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSNumber *value = mapping[[skin toNSObjectAtIndex:2]] ;
        if (value) {
            window.sharingType = [value unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of '%@'", [[mapping allKeys] componentsJoinedByString:@"', '"]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int window_titleVisibility(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;
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

static int window_aspectRatio(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:window.aspectRatio] ;
    } else {
        window.aspectRatio = [skin tableToSizeAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_contentAspectRatio(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:window.contentAspectRatio] ;
    } else {
        window.contentAspectRatio = [skin tableToSizeAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_maxSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:window.maxSize] ;
    } else {
        window.maxSize = [skin tableToSizeAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_contentMaxSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:window.contentMaxSize] ;
    } else {
        window.contentMaxSize = [skin tableToSizeAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_minSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:window.minSize] ;
    } else {
        window.minSize = [skin tableToSizeAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_contentMinSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:window.contentMinSize] ;
    } else {
        window.contentMinSize = [skin tableToSizeAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_resizeIncrements(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:window.resizeIncrements] ;
    } else {
        window.resizeIncrements = [skin tableToSizeAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_contentResizeIncrements(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:window.contentResizeIncrements] ;
    } else {
        window.contentResizeIncrements = [skin tableToSizeAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_maxFullScreenContentSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    int stackSize = lua_gettop(L) ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
    if ([window respondsToSelector:@selector(maxFullScreenContentSize)]) {
        if (stackSize == 1) {
            [skin pushNSSize:window.maxFullScreenContentSize] ;
        } else {
            window.maxFullScreenContentSize = [skin tableToSizeAtIndex:2] ;
            lua_pushvalue(L, 1) ;
        }
#pragma clang diagnostic pop
    } else {
        [skin logInfo:[NSString stringWithFormat:@"%s:maxFullScreenContentSize is not supported in 10.10; using %s:contentMaxSize instead", USERDATA_TAG, USERDATA_TAG]] ;
        lua_pushcfunction(L, window_contentMaxSize) ;
        lua_pushvalue(L, 1) ;
        if (stackSize == 2) lua_pushvalue(L, 2) ;
        lua_call(L, stackSize, 1) ;
    }
    return 1 ;
}

static int window_minFullScreenContentSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    int stackSize = lua_gettop(L) ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
    if ([window respondsToSelector:@selector(minFullScreenContentSize)]) {
        if (stackSize == 1) {
            [skin pushNSSize:window.minFullScreenContentSize] ;
        } else {
            window.minFullScreenContentSize = [skin tableToSizeAtIndex:2] ;
            lua_pushvalue(L, 1) ;
        }
#pragma clang diagnostic pop
    } else {
        [skin logInfo:[NSString stringWithFormat:@"%s:minFullScreenContentSize is not supported in 10.10; using %s:contentMinSize instead", USERDATA_TAG, USERDATA_TAG]] ;
        lua_pushcfunction(L, window_contentMinSize) ;
        lua_pushvalue(L, 1) ;
        if (stackSize == 2) lua_pushvalue(L, 2) ;
        lua_call(L, stackSize, 1) ;
    }
    return 1 ;
}

static int window_styleMask(lua_State *L) {
// NOTE:  This method is wrapped in init.lua
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;
    NSUInteger oldStyle = window.styleMask ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushinteger(L, (lua_Integer)oldStyle) ;
    } else {
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

static int window_collectionBehavior(lua_State *L) {
// NOTE:  This method is wrapped in init.lua
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;
    NSWindowCollectionBehavior oldBehavior = window.collectionBehavior ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, oldBehavior) ;
    } else {
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

static int window_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
      [skin pushNSObject:window.title] ;
    } else {
        window.title = [skin toNSObjectAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_miniwindowTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
      [skin pushNSObject:window.miniwindowTitle] ;
    } else {
        window.miniwindowTitle = lua_isstring(L, 2) ? [skin toNSObjectAtIndex:2] : nil ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int enclosure_accessibilitySubrole(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
      [skin pushNSObject:window.subroleOverride] ;
    } else {
        window.subroleOverride = lua_isstring(L, 2) ? [skin toNSObjectAtIndex:2] : nil ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int enclosure_animationDuration(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

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

static int window_representedFilename(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
      [skin pushNSObject:window.representedFilename] ;
    } else {
        window.representedFilename = [skin toNSObjectAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_representedURL(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
      [skin pushNSObject:[window.representedURL absoluteString]] ;
    } else {
        NSURL *asURL ;
        if (lua_isstring(L, 2)) {
            NSString *asString = [skin toNSObjectAtIndex:2] ;
            asURL = [NSURL fileURLWithPath:[asString stringByExpandingTildeInPath]] ;
            if (!asURL) asURL = [NSURL URLWithString:asString] ;
            if (!asURL) {
                [skin logWarn:[NSString stringWithFormat:@"%s: %@ does not represent a recognizable URL or file", USERDATA_TAG, asString]] ;
            }
        }
        window.representedURL = asURL ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_miniwindowImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
      [skin pushNSObject:window.miniwindowImage] ;
    } else {
        if (lua_isnil(L, 2)) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNIL, LS_TBREAK] ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
        }
        window.miniwindowImage = lua_isuserdata(L, 2) ? [skin toNSObjectAtIndex:2] : nil ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// // TODO: I would like to be able to support this someday, but not right now...
// static int window_restorable(lua_State *L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
//     HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 1) {
//         lua_pushboolean(L, window.restorable) ;
//     } else {
//         window.restorable = (BOOL)lua_toboolean(L, 2) ;
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }

static int enclosure_show(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;
    [window makeKeyAndOrderFront:nil];
    lua_pushvalue(L, 1);
    return 1;
}

static int enclosure_hide(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;
    [window orderOut:nil];

    lua_pushvalue(L, 1);
    return 1;
}

static int enclosure_clickActivating(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    if (lua_type(L, 2) != LUA_TNONE) {
        if (lua_toboolean(L, 2)) {
            window.styleMask &= (unsigned long)~NSWindowStyleMaskNonactivatingPanel ;
        } else {
            window.styleMask |= NSWindowStyleMaskNonactivatingPanel ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, ((window.styleMask & NSWindowStyleMaskNonactivatingPanel) != NSWindowStyleMaskNonactivatingPanel)) ;
    }

    return 1;
}

static int enclosure_frame(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;
    NSRect oldFrame = RectWithFlippedYCoordinate(window.frame);

    if (lua_gettop(L) == 1) {
        [skin pushNSRect:oldFrame] ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                        LS_TTABLE,
                        LS_TBOOLEAN | LS_TOPTIONAL,
                        LS_TBREAK] ;
        NSRect newFrame = RectWithFlippedYCoordinate([skin tableToRectAtIndex:2]) ;
        BOOL animate = (lua_gettop(L) == 3) ? (BOOL)lua_toboolean(L, 3) : NO ;
        [window setFrame:newFrame display:YES animate:animate];
        lua_pushvalue(L, 1);
    }
    return 1;
}

static int enclosure_topLeft(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;
    NSRect oldFrame = RectWithFlippedYCoordinate(window.frame);

    if (lua_gettop(L) == 1) {
        [skin pushNSPoint:oldFrame.origin] ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                        LS_TTABLE,
                        LS_TBOOLEAN | LS_TOPTIONAL,
                        LS_TBREAK] ;
        NSPoint newCoord = [skin tableToPointAtIndex:2] ;
        BOOL animate = (lua_gettop(L) == 3) ? (BOOL)lua_toboolean(L, 3) : NO ;
        NSRect  newFrame = RectWithFlippedYCoordinate(NSMakeRect(newCoord.x, newCoord.y, oldFrame.size.width, oldFrame.size.height)) ;
        [window setFrame:newFrame display:YES animate:animate];
        lua_pushvalue(L, 1);
    }
    return 1;
}

static int enclosure_size(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;
    NSRect oldFrame = window.frame;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:oldFrame.size] ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                        LS_TTABLE,
                        LS_TBOOLEAN | LS_TOPTIONAL,
                        LS_TBREAK] ;
        NSSize newSize  = [skin tableToSizeAtIndex:2] ;
        BOOL animate = (lua_gettop(L) == 3) ? (BOOL)lua_toboolean(L, 3) : NO ;
        NSRect newFrame = NSMakeRect(oldFrame.origin.x, oldFrame.origin.y + oldFrame.size.height - newSize.height, newSize.width, newSize.height);

        [window setFrame:newFrame display:YES animate:animate];
        lua_pushvalue(L, 1);
    }
    return 1;
}

static int enclosure_orderAbove(lua_State *L) {
    return enclosure_orderHelper(L, NSWindowAbove) ;
}

static int enclosure_orderBelow(lua_State *L) {
    return enclosure_orderHelper(L, NSWindowBelow) ;
}

static int enclosure_delete(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;
    lua_pushcfunction(L, userdata_gc) ;
    lua_pushvalue(L, 1) ;
    if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
        [skin logError:[NSString stringWithFormat:@"%s:error invoking _gc for delete method:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
        lua_pop(L, 1) ;
        [window orderOut:nil] ; // the least we can do is hide the enclosure if an error occurs with __gc
    }

    lua_pushnil(L);
    return 1;
}

static int enclosure_isShowing(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, [window isVisible]) ;
    return 1 ;
}

static int enclosure_isOccluded(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, ([window occlusionState] & NSWindowOcclusionStateVisible) != NSWindowOcclusionStateVisible) ;
    return 1 ;
}

/// hs._asm.enclosure:hswindow() -> hs.window object
/// Method
/// Returns an hs.window object for the enclosure so that you can use hs.window methods on it.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an hs.window object
///
/// Notes:
///  * hs.window:minimize only works if the webview is minimizable; see [hs._asm.enclosure.styleMask](#styleMask)
///  * hs.window:setSize only works if the webview is resizable; see [hs._asm.enclosure.styleMask](#styleMask)
///  * hs.window:close only works if the webview is closable; see [hs._asm.enclosure.styleMask](#styleMask)
///  * hs.window:maximize will reposition the webview to the upper left corner of your screen, but will only resize the webview if the webview is resizable; see [hs._asm.enclosure.styleMask](#styleMask)
static int enclosure_hswindow(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMEnclosure *window = [skin toNSObjectAtIndex:1] ;
    CGWindowID windowID = (CGWindowID)[window windowNumber];
    [skin requireModule:"hs.window"] ;
    lua_getfield(L, -1, "windowForID") ;
    lua_pushinteger(L, windowID) ;
    lua_call(L, 1, 1) ;
    return 1 ;
}

#pragma mark - Module Constants

/// hs._asm.enclosure.windowBehaviors[]
/// Constant
/// Array of window behavior labels for determining how an enclosure is handled in Spaces and Exposé
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
///
/// Only one of these may be active at a time (Available in OS X 10.11 and later):
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
    lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenAllowsTiling) ;    lua_setfield(L, -2, "fullScreenAllowsTiling") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenDisallowsTiling) ; lua_setfield(L, -2, "fullScreenDisallowsTiling") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenNone) ;            lua_setfield(L, -2, "fullScreenNone") ;
    return 1 ;
}


/// hs._asm.enclosure.windowLevels
/// Constant
/// A table of predefined window levels usable with [hs._asm.enclosure:level](#level)
///
/// Predefined levels are:
///  * _MinimumWindowLevelKey - lowest allowed window level
///  * desktop
///  * desktopIcon            - [hs._asm.enclosure:sendToBack](#sendToBack) is equivalent to this level - 1
///  * normal                 - normal application windows
///  * tornOffMenu
///  * floating               - equivalent to [hs._asm.enclosure:bringToFront(false)](#bringToFront); where "Always Keep On Top" windows are usually set
///  * modalPanel             - modal alert dialog
///  * utility
///  * dock                   - level of the Dock
///  * mainMenu               - level of the Menubar
///  * status
///  * popUpMenu              - level of a menu when displayed (open)
///  * overlay
///  * help
///  * dragging
///  * screenSaver            - equivalent to [hs._asm.enclosure:bringToFront(true)](#bringToFront)
///  * assistiveTechHigh
///  * cursor
///  * _MaximumWindowLevelKey - highest allowed window level
///
/// Notes:
///  * These key names map to the constants used in CoreGraphics to specify window levels and may not actually be used for what the name might suggest. For example, tests suggest that an active screen saver actually runs at a level of 2002, rather than at 1000, which is the window level corresponding to kCGScreenSaverWindowLevelKey.
///  * Each window level is sorted separately and [hs._asm.enclosure:orderAbove](#orderAbove) and [hs._asm.enclosure:orderBelow](#orderBelow) only arrange windows within the same level.
///  * If you use Dock hiding (or in 10.11, Menubar hiding) please note that when the Dock (or Menubar) is popped up, it is done so with an implicit orderAbove, which will place it above any items you may also draw at the Dock (or MainMenu) level.
static int window_windowLevels(lua_State *L) {
    lua_newtable(L) ;
//       lua_pushinteger(L, CGWindowLevelForKey(kCGBaseWindowLevelKey)) ;              lua_setfield(L, -2, "kCGBaseWindowLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGMinimumWindowLevelKey)) ;           lua_setfield(L, -2, "_MinimumWindowLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDesktopWindowLevelKey)) ;           lua_setfield(L, -2, "desktop") ;
//       lua_pushinteger(L, CGWindowLevelForKey(kCGBackstopMenuLevelKey)) ;            lua_setfield(L, -2, "kCGBackstopMenuLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGNormalWindowLevelKey)) ;            lua_setfield(L, -2, "normal") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGFloatingWindowLevelKey)) ;          lua_setfield(L, -2, "floating") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGTornOffMenuWindowLevelKey)) ;       lua_setfield(L, -2, "tornOffMenu") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDockWindowLevelKey)) ;              lua_setfield(L, -2, "dock") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGMainMenuWindowLevelKey)) ;          lua_setfield(L, -2, "mainMenu") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGStatusWindowLevelKey)) ;            lua_setfield(L, -2, "status") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGModalPanelWindowLevelKey)) ;        lua_setfield(L, -2, "modalPanel") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGPopUpMenuWindowLevelKey)) ;         lua_setfield(L, -2, "popUpMenu") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDraggingWindowLevelKey)) ;          lua_setfield(L, -2, "dragging") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGScreenSaverWindowLevelKey)) ;       lua_setfield(L, -2, "screenSaver") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGMaximumWindowLevelKey)) ;           lua_setfield(L, -2, "_MaximumWindowLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGOverlayWindowLevelKey)) ;           lua_setfield(L, -2, "overlay") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGHelpWindowLevelKey)) ;              lua_setfield(L, -2, "help") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGUtilityWindowLevelKey)) ;           lua_setfield(L, -2, "utility") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDesktopIconWindowLevelKey)) ;       lua_setfield(L, -2, "desktopIcon") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGCursorWindowLevelKey)) ;            lua_setfield(L, -2, "cursor") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGAssistiveTechHighWindowLevelKey)) ; lua_setfield(L, -2, "assistiveTechHigh") ;
//       lua_pushinteger(L, CGWindowLevelForKey(kCGNumberOfWindowLevelKeys)) ;         lua_setfield(L, -2, "kCGNumberOfWindowLevelKeys") ;
    return 1 ;
}

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

static int window_notifications(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    enclosureNotifications = @[
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
    [skin pushNSObject:enclosureNotifications] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSASMEnclosure(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMEnclosure *value = obj;
    if (value.selfRef == LUA_NOREF) {
        void** valuePtr = lua_newuserdata(L, sizeof(HSASMEnclosure *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
        value.selfRef = [skin luaRef:refTable] ;
    }
    [skin pushLuaRef:refTable ref:value.selfRef] ;
    return 1;
}

id toHSASMEnclosureFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMEnclosure *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSASMEnclosure, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMEnclosure *obj = [skin luaObjectAtIndex:1 toClass:"HSASMEnclosure"] ;
    NSString *title = obj.title ;
    if (!title) title = @"<untitled>" ;
    title = [NSString stringWithFormat:@"%@ %@", title, NSStringFromRect(RectWithFlippedYCoordinate(obj.frame))] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSASMEnclosure *obj1 = [skin luaObjectAtIndex:1 toClass:"HSASMEnclosure"] ;
        HSASMEnclosure *obj2 = [skin luaObjectAtIndex:2 toClass:"HSASMEnclosure"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMEnclosure *obj = get_objectFromUserdata(__bridge_transfer HSASMEnclosure, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRef = [skin luaUnref:refTable ref:obj.selfRef] ;
        obj.notificationCallback = [skin luaUnref:refTable ref:obj.notificationCallback] ;
        obj.contentView = nil ;
        obj.delegate = nil ;
        [obj close] ;
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
    {"animationDuration",                       enclosure_animationDuration},
    {"clickActivating",                         enclosure_clickActivating},
    {"closeOnEscape",                           enclosure_closeOnEscape},
    {"contentView",                             enclosure_contentView},
    {"contentViewBounds",                       enclosure_contentViewBounds},
    {"delete",                                  enclosure_delete},
    {"frame",                                   enclosure_frame},
    {"hide",                                    enclosure_hide},
    {"honorClose",                              enclosure_honorPerformClose},
    {"isOccluded",                              enclosure_isOccluded},
    {"isShowing",                               enclosure_isShowing},
    {"orderAbove",                              enclosure_orderAbove},
    {"orderBelow",                              enclosure_orderBelow},
    {"show",                                    enclosure_show},
    {"size",                                    enclosure_size},
    {"specifyCanBecomeKeyWindow",               enclosure_specifyCanBecomeKeyWindow},
    {"specifyCanBecomeMainWindow",              enclosure_specifyCanBecomeMainWindow},
    {"topLeft",                                 enclosure_topLeft},
    {"notificationCallback",                    enclosure_notificationCallback},
    {"notificationMessages",                    enclosure_notificationWatchFor},
    {"accessibilitySubrole",                    enclosure_accessibilitySubrole},
    {"hswindow",                                enclosure_hswindow},

    {"acceptsMouseMovedEvents",                 window_acceptsMouseMovedEvents},
    {"allowsConcurrentViewDrawing",             window_allowsConcurrentViewDrawing},
    {"allowsToolTipsWhenApplicationIsInactive", window_allowsToolTipsWhenApplicationIsInactive},
    {"alphaValue",                              window_alphaValue},
    {"animationBehavior",                       window_animationBehavior},
    {"aspectRatio",                             window_aspectRatio},
    {"backgroundColor",                         window_backgroundColor},
    {"canHide",                                 window_canHide},
    {"collectionBehavior",                      window_collectionBehavior},
    {"contentAspectRatio",                      window_contentAspectRatio},
    {"contentMaxSize",                          window_contentMaxSize},
    {"contentMinSize",                          window_contentMinSize},
    {"contentResizeIncrements",                 window_contentResizeIncrements},
    {"depthLimit",                              window_depthLimit},
    {"displaysWhenScreenProfileChanges",        window_displaysWhenScreenProfileChanges},
    {"documentEdited",                          window_documentEdited},
    {"excludedFromWindowsMenu",                 window_excludedFromWindowsMenu},
    {"hasShadow",                               window_hasShadow},
    {"hidesOnDeactivate",                       window_hidesOnDeactivate},
    {"ignoresMouseEvents",                      window_ignoresMouseEvents},
    {"level",                                   window_level},
    {"maxFullScreenContentSize",                window_maxFullScreenContentSize},
    {"maxSize",                                 window_maxSize},
    {"minFullScreenContentSize",                window_minFullScreenContentSize},
    {"miniwindowImage",                         window_miniwindowImage},
    {"miniwindowTitle",                         window_miniwindowTitle},
    {"minSize",                                 window_minSize},
    {"movable",                                 window_movable},
    {"movableByWindowBackground",               window_movableByWindowBackground},
    {"opaque",                                  window_opaque},
    {"preservesContentDuringLiveResize",        window_preservesContentDuringLiveResize},
    {"preventsApplicationTerminationWhenModal", window_preventsApplicationTerminationWhenModal},
    {"showsResizeIndicator",                    window_showsResizeIndicator},
    {"showsToolbarButton",                      window_showsToolbarButton},
    {"representedFilename",                     window_representedFilename},
    {"representedURL",                          window_representedURL},
    {"resizeIncrements",                        window_resizeIncrements},
    {"sharingType",                             window_sharingType},
    {"styleMask",                               window_styleMask},
    {"title",                                   window_title},
    {"titlebarAppearsTransparent",              window_titlebarAppearsTransparent},
    {"titleVisibility",                         window_titleVisibility},

    {"becomesKeyOnlyIfNeeded",                  panel_becomesKeyOnlyIfNeeded},
    {"floatingPanel",                           panel_floatingPanel},
    {"worksWhenModal",                          panel_worksWhenModal},

    {"appearance",                              appearanceCustomization_appearance},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",                  window_new},
    {"disableScreenUpdates", disableUpdates},
    {"enableScreenUpdates",  enableUpdates},
    {NULL,                   NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_enclosure_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSASMEnclosure         forClass:"HSASMEnclosure"];
    [skin registerLuaObjectHelper:toHSASMEnclosureFromLua forClass:"HSASMEnclosure"
                                               withUserdataMapping:USERDATA_TAG];

    window_collectionTypeTable(L) ; lua_setfield(L, -2, "behaviors") ;
    window_windowLevels(L) ;        lua_setfield(L, -2, "levels") ;
    window_windowMasksTable(L) ;    lua_setfield(L, -2, "masks") ;
    window_notifications(L) ;       lua_setfield(L, -2, "notifications") ;

    return 1;
}
