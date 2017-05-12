@import Cocoa ;
@import AVKit ;
@import AVFoundation ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.avplayer" ;
static int refTable = LUA_NOREF;

static const int32_t PREFERRED_TIMESCALE = 60000 ; // see https://warrenmoore.net/understanding-cmtime
static void *myKVOContext = &myKVOContext ; // See http://nshipster.com/key-value-observing/

static int userdata_gc(lua_State* L) ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static inline NSRect RectWithFlippedYCoordinate(NSRect theRect) {
    return NSMakeRect(theRect.origin.x,
                      [[NSScreen screens][0] frame].size.height - theRect.origin.y - theRect.size.height,
                      theRect.size.width,
                      theRect.size.height) ;
}

#define CONTROLS_STYLES @{ \
    @"none"     : @(AVPlayerViewControlsStyleNone), \
    @"inline"   : @(AVPlayerViewControlsStyleInline), \
    @"floating" : @(AVPlayerViewControlsStyleFloating), \
    @"minimal"  : @(AVPlayerViewControlsStyleMinimal), \
    @"default"  : @(AVPlayerViewControlsStyleDefault), \
}

#pragma mark - Support Functions and Classes

@interface HSAVPlayerWindow : NSPanel <NSWindowDelegate>
@property int        selfRef ;
@property int        windowCallback ;
@property BOOL       keyboardControl ;
@end

@interface HSAVPlayerView : AVPlayerView
@property BOOL       pauseWhenHidden ;
@property BOOL       trackCompleted ;
@property BOOL       trackRate ;
@property BOOL       trackStatus ;
@property int        callbackRef ;
@property id         periodicObserver ;
@property lua_Number periodicPeriod ;
@end

@implementation HSAVPlayerWindow

- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSWindowStyleMask)windowStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)deferCreation
{
    if (!(isfinite(contentRect.origin.x)    && isfinite(contentRect.origin.y) &&
          isfinite(contentRect.size.height) && isfinite(contentRect.size.width))) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:frame must be specified in finite numbers", USERDATA_TAG]];
        return nil;
    }

    self = [super initWithContentRect:contentRect
                            styleMask:windowStyle
                              backing:bufferingType
                                defer:deferCreation];

    if (self) {
        contentRect = RectWithFlippedYCoordinate(contentRect) ;
        [self setFrameOrigin:contentRect.origin];

        // Configure the window
        self.releasedWhenClosed = NO;
        self.backgroundColor    = [NSColor clearColor];
        self.opaque             = YES;
        self.hasShadow          = NO;
        self.ignoresMouseEvents = NO;
        self.restorable         = NO;
        self.hidesOnDeactivate  = NO;
        self.animationBehavior  = NSWindowAnimationBehaviorNone;
        self.level              = NSNormalWindowLevel;

        _selfRef                = LUA_NOREF ;
        _windowCallback         = LUA_NOREF ;
        _keyboardControl        = NO ;

        // can't be set before the callback which acts on delegate methods is defined
        self.delegate           = self;
    }
    return self;
}

- (BOOL)canBecomeKeyWindow {
    return _keyboardControl ;
}

- (BOOL)windowShouldClose:(id __unused)sender {
    if ((self.styleMask & NSClosableWindowMask) != 0) {
        return YES ;
    } else {
        return NO ;
    }
}

#pragma mark windowCallback triggers

- (void)windowWillClose:(__unused NSNotification *)notification {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_State *L = [skin L] ;
    if (_windowCallback != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_windowCallback] ;
        [skin pushNSObject:@"closing"] ;
        [skin pushNSObject:self] ;
        if (![skin  protectedCallAndTraceback:2 nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:windowCallback callback error: %s", USERDATA_TAG, lua_tostring(L, -1)]];
            lua_pop(L, 1) ;
        }
    }
}

- (void)windowDidBecomeKey:(__unused NSNotification *)notification {
    if (_windowCallback != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:_windowCallback] ;
        [skin pushNSObject:@"focusChange"] ;
        [skin pushNSObject:self] ;
        lua_pushboolean(skin.L, YES) ;
        if (![skin  protectedCallAndTraceback:3 nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:windowCallback callback error: %s", USERDATA_TAG, lua_tostring(skin.L, -1)]];
            lua_pop(skin.L, 1) ;
        }
    }
}

- (void)windowDidResignKey:(__unused NSNotification *)notification {
    if (_windowCallback != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:_windowCallback] ;
        [skin pushNSObject:@"focusChange"] ;
        [skin pushNSObject:self] ;
        lua_pushboolean(skin.L, NO) ;
        if (![skin  protectedCallAndTraceback:3 nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:windowCallback callback error: %s", USERDATA_TAG, lua_tostring(skin.L, -1)]];
            lua_pop(skin.L, 1) ;
        }
    }
}

- (void)windowDidResize:(__unused NSNotification *)notification {
    if (_windowCallback != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:_windowCallback] ;
        [skin pushNSObject:@"frameChange"] ;
        [skin pushNSObject:self] ;
        [skin pushNSRect:RectWithFlippedYCoordinate(self.frame)] ;
        if (![skin  protectedCallAndTraceback:3 nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:windowCallback callback error: %s", USERDATA_TAG, lua_tostring(skin.L, -1)]];
            lua_pop(skin.L, 1) ;
        }
    }
}

- (void)windowDidMove:(__unused NSNotification *)notification {
    if (_windowCallback != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:_windowCallback] ;
        [skin pushNSObject:@"frameChange"] ;
        [skin pushNSObject:self] ;
        [skin pushNSRect:RectWithFlippedYCoordinate(self.frame)] ;
        if (![skin  protectedCallAndTraceback:3 nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:windowCallback callback error: %s", USERDATA_TAG, lua_tostring(skin.L, -1)]];
            lua_pop(skin.L, 1) ;
        }
    }
}

@end

@implementation HSAVPlayerView {
    float rateWhenHidden ;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _callbackRef                     = LUA_NOREF ;
        _pauseWhenHidden                 = YES ;
        _trackCompleted                  = NO ;
        _trackRate                       = NO ;
        _trackStatus                     = NO ;
        _periodicObserver                = nil ;
        _periodicPeriod                  = 0.0 ;

        rateWhenHidden                   = 0.0f ;

        self.player                        = [[AVPlayer alloc] init] ;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
        if ([self.player respondsToSelector:@selector(allowsExternalPlayback)]) {
            self.player.allowsExternalPlayback = NO ; // 10.11+
        }
#pragma clang diagnostic pop


        self.controlsStyle               = AVPlayerViewControlsStyleDefault ;
        self.showsFrameSteppingButtons   = NO ;
        self.showsSharingServiceButton   = NO ;
        self.showsFullScreenToggleButton = NO ;
        self.actionPopUpButtonMenu       = nil ;
    }
    return self;
}

- (void)didFinishPlaying:(__unused NSNotification *)notification {
    if (_callbackRef != LUA_NOREF && _trackCompleted) {
        LuaSkin *skin = [LuaSkin shared] ;
        lua_State *L = [skin L] ;
        [skin pushLuaRef:refTable ref:self->_callbackRef] ;
        [skin pushNSObject:self.window] ;
        [skin pushNSObject:@"finished"] ;
        if (![skin protectedCallAndTraceback:2 nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:trackCompleted callback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (_trackRate && context == myKVOContext && [keyPath isEqualToString:@"rate"]) {
        if (_callbackRef != LUA_NOREF) {
            BOOL isPause = (self.player.rate == 0.0f) ;
            LuaSkin *skin = [LuaSkin shared] ;
            lua_State *L  = [skin L] ;
            [skin pushLuaRef:refTable ref:_callbackRef] ;
            [skin pushNSObject:self.window] ;
            [skin pushNSObject:(isPause ? @"pause" : @"play")] ;
            lua_pushnumber(L, (lua_Number)self.player.rate) ;
            if (![skin protectedCallAndTraceback:3 nresults:0]) {
                NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
                lua_pop(L, 1) ;
                [skin logError:[NSString stringWithFormat:@"%s:trackRate callback error:%@", USERDATA_TAG, errorMessage]] ;
            }
        }
    } else if (_trackStatus && context == myKVOContext && [keyPath isEqualToString:@"status"]) {
        if (_callbackRef != LUA_NOREF) {
            int argCount = 3 ;
            LuaSkin *skin = [LuaSkin shared] ;
            lua_State *L  = [skin L] ;
            [skin pushLuaRef:refTable ref:_callbackRef] ;
            [skin pushNSObject:self.window] ;
            [skin pushNSObject:@"status"] ;
            switch(self.player.currentItem.status) {
                case AVPlayerStatusUnknown:
                    [skin pushNSObject:@"unknown"] ;
                    break ;
                case AVPlayerStatusReadyToPlay:
                    [skin pushNSObject:@"readyToPlay"] ;
                    break ;
                case AVPlayerStatusFailed:
                    [skin pushNSObject:@"failed"] ;
                    [skin pushNSObject:[self.player.currentItem.error localizedDescription]] ;
                    argCount++ ;
                    break ;
                default:
                    [skin pushNSObject:@"unrecognized status"] ;
                    lua_pushinteger(L, self.player.currentItem.status) ;
                    argCount++ ;
                    break ;
            }
            if (![skin protectedCallAndTraceback:argCount nresults:0]) {
                NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
                lua_pop(L, 1) ;
                [skin logError:[NSString stringWithFormat:@"%s:trackStatus callback error:%@", USERDATA_TAG, errorMessage]] ;
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context] ;
    }
}

- (void) menuSelectionCallback:(NSMenuItem *)sender {
    if (_callbackRef != LUA_NOREF) {
        NSEventModifierFlags theFlags = [NSEvent modifierFlags] ;
        LuaSkin *skin = [LuaSkin shared] ;
        lua_State *L  = [skin L] ;
        NSString *title = sender.title ;
        [skin pushLuaRef:refTable ref:self->_callbackRef] ;
        [skin pushNSObject:self.window] ;
        [skin pushNSObject:@"actionMenu"] ;
        [skin pushNSObject:(([title isEqualToString:@""]) ? [sender.attributedTitle string] : title)] ;
        lua_newtable(L) ;
        lua_pushboolean(L, (theFlags & NSEventModifierFlagCommand) != 0) ;  lua_setfield(L, -2, "cmd") ;
        lua_pushboolean(L, (theFlags & NSEventModifierFlagShift) != 0) ;    lua_setfield(L, -2, "shift") ;
        lua_pushboolean(L, (theFlags & NSEventModifierFlagOption) != 0) ;   lua_setfield(L, -2, "alt") ;
        lua_pushboolean(L, (theFlags & NSEventModifierFlagControl) != 0) ;  lua_setfield(L, -2, "ctrl") ;
        lua_pushboolean(L, (theFlags & NSEventModifierFlagFunction) != 0) ; lua_setfield(L, -2, "fn") ;
        lua_pushinteger(L, theFlags) ; lua_setfield(L, -2, "_raw") ;
        if (![skin protectedCallAndTraceback:4 nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:actionMenu callback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    }
}

- (void)viewDidHide {
    if (_pauseWhenHidden) {
        rateWhenHidden = self.player.rate ;
        [self.player pause] ;
    }
}

- (void)viewDidUnhide {
    if (rateWhenHidden != 0.0f) {
        self.player.rate = rateWhenHidden ;
        rateWhenHidden = 0.0f ;
    }
}

@end

// I'm not sure how this is going to work on  Retina display, so leave it as a function so we can
// modify it more easily and affect all (3) places where it is used...
static NSSize proportionallyScaleStateImageSize(NSImage *theImage) {
    CGFloat defaultFromFont   = [[NSFont menuFontOfSize:0] pointSize] ;
    NSSize  stateBoxImageSize = NSMakeSize(defaultFromFont, defaultFromFont) ;

    NSSize sourceSize         = [theImage size] ;

    CGFloat ratio = fmin(stateBoxImageSize.height / sourceSize.height, stateBoxImageSize.width / sourceSize.width) ;
    return NSMakeSize(sourceSize.width * ratio, sourceSize.height * ratio) ;
}

static NSMenu *menuMaker(NSArray *menuItems, id actionTarget) {
    NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"AVPlayer Action Menu"] ;
    [theMenu setAutoenablesItems:NO];
    [menuItems enumerateObjectsUsingBlock:^(NSDictionary *item, NSUInteger idx, __unused BOOL *stop) {
        BOOL checked = NO ;
        while (!checked) {  // doing this as a loop so we can break out as soon as we know enough
            checked = YES ; // but we really don't want to loop

            NSString *title = item[@"title"] ;
            if (!title) {
                [LuaSkin logWarn:[NSString stringWithFormat:@"title key missing at index %lu; skipping", idx + 1]] ;
                break ;
            }
            NSMenuItem *newItem ;
            if ([title isKindOfClass:[NSString class]]) {
                if ([title isEqualToString:@"-"]) {
                    [theMenu addItem:[NSMenuItem separatorItem]] ;
                    break ;
                } else {
                    newItem = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
                }
            } else if ([title isKindOfClass:[NSAttributedString class]]) {
                newItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
                newItem.attributedTitle = (NSAttributedString *)title ;
            }
            if (!newItem) {
                [LuaSkin logWarn:[NSString stringWithFormat:@"title key not a string or hs.styledtext object at index %lu; skipping", idx + 1]] ;
                break ;
            }

            [newItem setTarget:actionTarget];
            [newItem setAction:@selector(menuSelectionCallback:)];

            if ([item[@"menu"] isKindOfClass:[NSArray class]]) {
                newItem.submenu = menuMaker(item[@"menu"], actionTarget) ;
            } else if (item[@"menu"]) {
                [LuaSkin logWarn:[NSString stringWithFormat:@"invalid menu key at index %lu", idx + 1]] ;
            }

            // in a menubar rewrite, if this code is reused there, we'll have to deal with `fn` somehow
            // but for this module, we're going with the single master-callback model.

            newItem.enabled = YES ;
            if ([item[@"disabled"] isKindOfClass:[NSNumber class]] && !strcmp(@encode(BOOL), [item[@"disabled"] objCType])) {
                newItem.enabled = ![item[@"disabled"] boolValue] ;
            } else if (item[@"disabled"]) {
                [LuaSkin logWarn:[NSString stringWithFormat:@"invalid disabled key at index %lu", idx + 1]] ;
            }

            newItem.state = NSOffState ;
            if ([item[@"checked"] isKindOfClass:[NSNumber class]] && !strcmp(@encode(BOOL), [item[@"checked"] objCType])) {
                newItem.state = [item[@"checked"] boolValue] ? NSOnState : NSOffState ;
            } else if (item[@"checked"]) {
                [LuaSkin logWarn:[NSString stringWithFormat:@"invalid checked key at index %lu", idx + 1]] ;
            }
            if ([item[@"state"] isKindOfClass:[NSString class]]) {
                if ([item[@"state"] isEqualToString:@"on"])    newItem.state = NSOnState ;
                if ([item[@"state"] isEqualToString:@"off"])   newItem.state = NSOffState ;
                if ([item[@"state"] isEqualToString:@"mixed"]) newItem.state = NSMixedState ;
            } else if (item[@"state"]) {
                [LuaSkin logWarn:[NSString stringWithFormat:@"invalid state key at index %lu", idx + 1]] ;
            }

            if ([item[@"tooltip"] isKindOfClass:[NSString class]]) {
                newItem.toolTip = item[@"tooltip"] ;
            } else if (item[@"tooltip"]) {
                [LuaSkin logWarn:[NSString stringWithFormat:@"invalid tooltip key at index %lu", idx + 1]] ;
            }

            if ([item[@"indent"] isKindOfClass:[NSNumber class]] && !strcmp(@encode(lua_Integer), [item[@"indent"] objCType])) {
                lua_Integer indent = [item[@"indent"] integerValue] ;
                newItem.indentationLevel = ((indent < 0) ? 0 : ((indent > 15) ? 15 : indent)) ;
            } else if (item[@"indent"]) {
                [LuaSkin logWarn:[NSString stringWithFormat:@"invalid indent key at index %lu", idx + 1]] ;
            }

            if ([item[@"image"] isKindOfClass:[NSImage class]]) {
                newItem.image = item[@"image"] ;
            } else if (item[@"image"]) {
                [LuaSkin logWarn:[NSString stringWithFormat:@"invalid image key at index %lu", idx + 1]] ;
            }

            if ([item[@"onStateImage"] isKindOfClass:[NSImage class]]) {
                NSImage *myImage = item[@"onStateImage"] ;
                [myImage setSize:proportionallyScaleStateImageSize(myImage)] ;
                newItem.onStateImage = myImage ;
            } else if (item[@"onStateImage"]) {
                [LuaSkin logWarn:[NSString stringWithFormat:@"invalid onStateImage key at index %lu", idx + 1]] ;
            }

            if ([item[@"offStateImage"] isKindOfClass:[NSImage class]]) {
                NSImage *myImage = item[@"offStateImage"] ;
                [myImage setSize:proportionallyScaleStateImageSize(myImage)] ;
                newItem.offStateImage = myImage ;
            } else if (item[@"offStateImage"]) {
                [LuaSkin logWarn:[NSString stringWithFormat:@"invalid offStateImage key at index %lu", idx + 1]] ;
            }

            if ([item[@"mixedStateImage"] isKindOfClass:[NSImage class]]) {
                NSImage *myImage = item[@"mixedStateImage"] ;
                [myImage setSize:proportionallyScaleStateImageSize(myImage)] ;
                newItem.mixedStateImage = myImage ;
            } else if (item[@"onStateImage"]) {
                [LuaSkin logWarn:[NSString stringWithFormat:@"invalid mixedStateImage key at index %lu", idx + 1]] ;
            }

            [theMenu addItem:newItem];
        }
    }] ;

    return theMenu ;
}

#pragma mark - Module Functions

/// hs._asm.avplayer.new([frame]) -> avplayerObject
/// Constructor
/// Creates a new AVPlayer object which can display audiovisual media for Hammerspoon.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the window for the avplayer object.
///
/// Returns:
///  * the avplayerObject
static int avplayer_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    NSRect windowRect = [skin tableToRectAtIndex:1] ;
    HSAVPlayerWindow *theWindow = [[HSAVPlayerWindow alloc] initWithContentRect:windowRect
                                                                      styleMask:NSBorderlessWindowMask
                                                                        backing:NSBackingStoreBuffered
                                                                          defer:YES];
    if (theWindow) {
        HSAVPlayerView *theView = [[HSAVPlayerView alloc] initWithFrame:theWindow.contentView.bounds] ;
        theWindow.contentView = theView;
        [skin pushNSObject:theWindow] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods - window related

/// hs._asm.avplayer:topLeft([point]) -> avplayerObject | currentValue
/// Method
/// Get or set the top-left coordinate of the avplayer window
///
/// Parameters:
///  * `point` - An optional point-table specifying the new coordinate the top-left of the avplayer window should be moved to
///
/// Returns:
///  * If an argument is provided, the avplayer object; otherwise the current value.
///
/// Notes:
///  * a point-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the avplayer (keys `x`  and `y`). The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
static int avplayer_topLeft(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    NSRect oldFrame = RectWithFlippedYCoordinate(theWindow.frame);

    if (lua_gettop(L) == 1) {
        [skin pushNSPoint:oldFrame.origin] ;
    } else {
        NSPoint newCoord = [skin tableToPointAtIndex:2] ;
        NSRect  newFrame = RectWithFlippedYCoordinate(NSMakeRect(newCoord.x, newCoord.y, oldFrame.size.width, oldFrame.size.height)) ;
        [theWindow setFrame:newFrame display:YES animate:NO];
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs._asm.avplayer:size([size]) -> avplayerObject | currentValue
/// Method
/// Get or set the size of a avplayer window
///
/// Parameters:
///  * `size` - An optional size-table specifying the width and height the avplayer window should be resized to
///
/// Returns:
///  * If an argument is provided, the avplayer object; otherwise the current value.
///
/// Notes:
///  * a size-table is a table with key-value pairs specifying the size (keys `h` and `w`) the avplayer should be resized to. The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
static int avplayer_size(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;

    NSRect oldFrame = theWindow.frame;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:oldFrame.size] ;
    } else {
        NSSize newSize  = [skin tableToSizeAtIndex:2] ;
        NSRect newFrame = NSMakeRect(oldFrame.origin.x, oldFrame.origin.y + oldFrame.size.height - newSize.height, newSize.width, newSize.height);
        [theWindow setFrame:newFrame display:YES animate:NO];
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs._asm.avplayer:show() -> avplayerObject
/// Method
/// Displays the avplayer object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The avplayer object
static int avplayer_show(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;

    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    [theWindow makeKeyAndOrderFront:nil];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.avplayer:hide() -> avplayerObject
/// Method
/// Hides the avplayer object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The avplayer object
static int avplayer_hide(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;

    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    [theWindow orderOut:nil];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.avplayer:keyboardControl([value]) -> avplayerObject | current value
/// Method
/// Get or set whether or not the avplayer can accept keyboard input for playback control. Defaults to false.
///
/// Parameters:
///  * `value` - an optional boolean value which sets whether or not the avplayer will accept keyboard input.
///
/// Returns:
///  * If a value is provided, then this method returns the avplayer object; otherwise the current value
static int avplayer_keyboardControl(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theWindow.keyboardControl) ;
    } else {
        theWindow.keyboardControl = (BOOL) lua_toboolean(L, 2) ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

static int avplayer_windowStyle(lua_State *L) {
// NOTE:  This method is wrapped in init.lua
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushinteger(L, (lua_Integer)theWindow.styleMask) ;
    } else {
            @try {
            // Because we're using NSPanel, the title is reset when the style is changed
                NSString *theTitle = [theWindow title] ;
            // Also, some styles don't get properly set unless we start from a clean slate
                [theWindow setStyleMask:0] ;
                [theWindow setStyleMask:(NSUInteger)luaL_checkinteger(L, 2)] ;
                if (theTitle) [theWindow setTitle:theTitle] ;
            }
            @catch ( NSException *theException ) {
                return luaL_error(L, "Invalid style mask: %s, %s", [[theException name] UTF8String], [[theException reason] UTF8String]) ;
            }
        lua_settop(L, 1) ;
    }
    return 1 ;
}

static int avplayer_level(lua_State *L) {
// NOTE:  This method is wrapped in init.lua
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, theWindow.level) ;
    } else {
        lua_Integer targetLevel = lua_tointeger(L, 2) ;

        if (targetLevel >= CGWindowLevelForKey(kCGMinimumWindowLevelKey) && targetLevel <= CGWindowLevelForKey(kCGMaximumWindowLevelKey)) {
            [theWindow setLevel:targetLevel] ;
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"window level must be between %d and %d inclusive",
                                   CGWindowLevelForKey(kCGMinimumWindowLevelKey),
                                   CGWindowLevelForKey(kCGMaximumWindowLevelKey)] UTF8String]) ;
        }
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.avplayer:bringToFront([aboveEverything]) -> avplayerObject
/// Method
/// Places the drawing object on top of normal windows
///
/// Parameters:
///  * `aboveEverything` - An optional boolean value that controls how far to the front the avplayer should be placed. True to place the avplayer on top of all windows (including the dock and menubar and fullscreen windows), false to place the avplayer above normal windows, but below the dock, menubar and fullscreen windows. Defaults to false.
///
/// Returns:
///  * The avplayer object
static int avplayer_bringToFront(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    theWindow.level = lua_toboolean(L, 2) ? NSScreenSaverWindowLevel : NSFloatingWindowLevel ;
    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.avplayer:sendToBack() -> avplayerObject
/// Method
/// Places the avplayer object behind normal windows, between the desktop wallpaper and desktop icons
///
/// Parameters:
///  * None
///
/// Returns:
///  * The drawing object
static int avplayer_sendToBack(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    theWindow.level = CGWindowLevelForKey(kCGDesktopIconWindowLevelKey) - 1;
    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.avplayer:alpha([alpha]) -> avplayerObject | currentValue
/// Method
/// Get or set the alpha level of the window containing the hs._asm.avplayer object.
///
/// Parameters:
///  * `alpha` - an optional number between 0.0 and 1.0 specifying the new alpha level for the avplayer.
///
/// Returns:
///  * If a parameter is provided, returns the avplayer object; otherwise returns the current value.
static int avplayer_alpha(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, theWindow.alphaValue) ;
    } else {
        CGFloat newLevel = luaL_checknumber(L, 2);
        theWindow.alphaValue = ((newLevel < 0.0) ? 0.0 : ((newLevel > 1.0) ? 1.0 : newLevel)) ;
        lua_settop(L, 1);
    }
    return 1 ;
}

/// hs._asm.avplayer:shadow([value]) -> avplayerObject | current value
/// Method
/// Get or set whether or not the avplayer window has shadows. Default to false.
///
/// Parameters:
///  * `value` - an optional boolean value indicating whether or not the avplayer should have shadows.
///
/// Returns:
///  * If a value is provided, then this method returns the avplayer object; otherwise the current value
static int avplayer_shadow(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theWindow.hasShadow);
    } else {
        theWindow.hasShadow = (BOOL)lua_toboolean(L, 2);
        lua_settop(L, 1);
    }
    return 1 ;
}

static int avplayer_orderHelper(lua_State *L, NSWindowOrderingMode mode) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK | LS_TVARARG] ;

    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    NSInteger       relativeTo = 0 ;

    if (lua_gettop(L) > 1) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                        LS_TUSERDATA, USERDATA_TAG,
                        LS_TBREAK] ;
        relativeTo = [[skin toNSObjectAtIndex:2] windowNumber] ;
    }

    [theWindow orderWindow:mode relativeTo:relativeTo] ;

    lua_pushvalue(L, 1);
    return 1 ;
}

/// hs._asm.avplayer:orderAbove([avplayer2]) -> avplayerObject
/// Method
/// Moves avplayer object above avplayer2, or all avplayer objects in the same presentation level, if avplayer2 is not given.
///
/// Parameters:
///  * `avplayer2` -An optional avplayer object to place the avplayer object above.
///
/// Returns:
///  * The avplayer object
///
/// Notes:
///  * If the avplayer object and avplayer2 are not at the same presentation level, this method will will move the avplayer object as close to the desired relationship without changing the avplayer object's presentation level. See [hs._asm.avplayer.level](#level).
static int avplayer_orderAbove(lua_State *L) {
    return avplayer_orderHelper(L, NSWindowAbove) ;
}

/// hs._asm.avplayer:orderBelow([avplayer2]) -> avplayerObject
/// Method
/// Moves avplayer object below avplayer2, or all avplayer objects in the same presentation level, if avplayer2 is not given.
///
/// Parameters:
///  * `avplayer2` -An optional avplayer object to place the avplayer object below.
///
/// Returns:
///  * The avplayer object
///
/// Notes:
///  * If the avplayer object and avplayer2 are not at the same presentation level, this method will will move the avplayer object as close to the desired relationship without changing the avplayer object's presentation level. See [hs._asm.avplayer.level](#level).
static int avplayer_orderBelow(lua_State *L) {
    return avplayer_orderHelper(L, NSWindowBelow) ;
}

/// hs._asm.avplayer:delete() -> nil
/// Method
/// Destroys the avplayer object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * nil
///
/// Notes:
///  * This method is automatically called during garbage collection, notably during a Hammerspoon termination or reload
static int avplayer_delete(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;

    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    [theWindow close] ; // trigger callback, if set, then cleanup
    lua_pushcfunction(L, userdata_gc) ;
    lua_pushvalue(L, 1) ;
    if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"%s:error invoking _gc for delete method:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
        lua_pop(L, 1) ;
    }

    lua_pushnil(L);
    return 1;
}

static int avplayer_behavior(lua_State *L) {
// NOTE:  This method is wrapped in init.lua
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, [theWindow collectionBehavior]) ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                        LS_TNUMBER | LS_TINTEGER,
                        LS_TBREAK] ;

        NSInteger newLevel = lua_tointeger(L, 2);
        @try {
            [theWindow setCollectionBehavior:(NSWindowCollectionBehavior)newLevel] ;
        }
        @catch ( NSException *theException ) {
            return luaL_error(L, "%s: %s", [[theException name] UTF8String], [[theException reason] UTF8String]) ;
        }

        lua_pushvalue(L, 1);
    }

    return 1 ;
}

/// hs._asm.avplayer:windowCallback(fn) -> avplayerObject
/// Method
/// Set or clear a callback for updates to the avplayer window
///
/// Parameters:
///  * `fn` - the function to be called when the avplayer window is moved or closed. Specify an explicit nil to clear the current callback.  The function should expect 2 or 3 arguments and return none.  The arguments will be one of the following:
///
///    * "closing", avplayer - specifies that the avplayer window is being closed, either by the user or with the [hs._asm.avplayer:delete](#delete) method.
///      * `action`   - in this case "closing", specifying that the avplayer window is being closed
///      * `avplayer` - the avplayer that is being closed
///
///    * "focusChange", avplayer, state - indicates that the avplayer window has either become or stopped being the focused window
///      * `action`   - in this case "focusChange", specifying that the avplayer window is being closed
///      * `avplayer` - the avplayer that is being closed
///      * `state`    - a boolean, true if the avplayer has become the focused window, or false if it has lost focus
///
///    * "frameChange", avplayer, frame - indicates that the avplayer window has been moved or resized
///      * `action`   - in this case "focusChange", specifying that the avplayer window is being closed
///      * `avplayer` - the avplayer that is being closed
///      * `frame`    - a rect-table containing the new co-ordinates and size of the avplayer window
///
/// Returns:
///  * The avplayer object
static int avplayer_windowCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL,
                    LS_TBREAK] ;

    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;

    // We're either removing a callback, or setting a new one. Either way, we want to clear out any callback that exists
    theWindow.windowCallback = [skin luaUnref:refTable ref:theWindow.windowCallback] ;

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        theWindow.windowCallback = [skin luaRef:refTable] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

#pragma mark - Module Methods - view related

#pragma mark - Module Methods - ASMAVPlayerView methods

/// hs._asm.avplayer:controlsStyle([style]) -> avplayerObject | current value
/// Method
/// Get or set the style of controls displayed in the avplayerObject for controlling media playback.
///
/// Parameters:
///  * `style` - an optional string, default "default", specifying the stye of the controls displayed for controlling media playback.  The string may be one of the following:
///    * `none`     - no controls are provided -- playback must be managed programmatically through Hammerspoon Lua code.
///    * `inline`   - media controls are displayed in an autohiding status bar at the bottom of the media display.
///    * `floating` - media controls are displayed in an autohiding panel which floats over the media display.
///    * `minimal`  - media controls are displayed as a round circle in the center of the media display.
///    * `none`     - no media controls are displayed in the media display.
///    * `default`  - use the OS X default control style; under OS X 10.11, this is the "inline".
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayer_controlsStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;

    if (lua_gettop(L) == 1) {
        NSNumber *controlsStyle = @(playerView.controlsStyle) ;
        NSArray *temp = [CONTROLS_STYLES allKeysForObject:controlsStyle];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized controls style %@ for AVPlayerView -- notify developers", USERDATA_TAG, controlsStyle]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *controlsStyle = CONTROLS_STYLES[key] ;
        if (controlsStyle) {
            playerView.controlsStyle = [controlsStyle integerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[CONTROLS_STYLES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

/// hs._asm.avplayer:frameSteppingButtons([state]) -> avplayerObject | current value
/// Method
/// Get or set whether frame stepping or scrubbing controls are included in the media controls.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether frame stepping (true) or scrubbing (false) controls are included in the media controls.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayer_showsFrameSteppingButtons(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.showsFrameSteppingButtons) ;
    } else {
        playerView.showsFrameSteppingButtons = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.avplayer:sharingServiceButton([state]) -> avplayerObject | current value
/// Method
/// Get or set whether or not the sharing services button is included in the media controls.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not the sharing services button is included in the media controls.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayer_showsSharingServiceButton(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.showsSharingServiceButton) ;
    } else {
        playerView.showsSharingServiceButton = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.avplayer:flashChapterAndTitle(number, [string]) -> avplayerObject
/// Method
/// Flashes the number and optional string over the media playback display momentarily.
///
/// Parameters:
///  * `number` - an integer specifying the chapter number to display.
///  * `string` - an optional string specifying the chapter name to display.
///
/// Returns:
///  * the avplayerObject
///
/// Notes:
///  * If only a number is provided, the text "Chapter #" is displayed.  If a string is also provided, "#. string" is displayed.
static int avplayer_flashChapterAndTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TSTRING | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    NSUInteger       chapterNumber = (lua_Unsigned)lua_tointeger(L, 2) ;
    NSString         *chapterTitle = (lua_gettop(L) == 3) ? [skin toNSObjectAtIndex:3] : nil ;

    [playerView flashChapterNumber:chapterNumber chapterTitle:chapterTitle] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.avplayer:pauseWhenHidden([state]) -> avplayerObject | current value
/// Method
/// Get or set whether or not playback of media should be paused when the avplayer object is hidden.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether or not media playback should be paused when the avplayer object is hidden.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayer_pauseWhenHidden(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.pauseWhenHidden) ;
    } else {
        playerView.pauseWhenHidden = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.avplayer:setCallback(fn) -> avplayerObject
/// Method
/// Set the callback function for the avplayerObject.
///
/// Parameters:
///  * `fn` - a function, or explicit `nil`, specifying the callback function which is used by this avplayerObject.  If `nil` is specified, the currently active callback function is removed.
///
/// Returns:
///  * the avplayerObject
///
/// Notes:
///  * The callback function should expect 2 or more arguments.  The first two arguments will always be:
///    * `avplayObject` - the avplayerObject userdata
///    * `message`      - a string specifying the reason for the callback.
///  * Additional arguments depend upon the message.  See the following methods for details concerning the arguments for each message:
///    * `actionMenu` - [hs._asm.avplayer:actionMenu](#actionMenu)
///    * `finished`   - [hs._asm.avplayer:trackCompleted](#trackCompleted)
///    * `pause`      - [hs._asm.avplayer:trackRate](#trackRate)
///    * `play`       - [hs._asm.avplayer:trackRate](#trackRate)
///    * `progress`   - [hs._asm.avplayer:trackProgress](#trackProgress)
///    * `seek`       - [hs._asm.avplayer:seek](#seek)
///    * `status`     - [hs._asm.avplayer:trackStatus](#trackStatus)
static int avplayer_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL,
                    LS_TBREAK] ;

    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;

    // We're either removing a callback, or setting a new one. Either way, remove existing.
    playerView.callbackRef = [skin luaUnref:refTable ref:playerView.callbackRef];

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        playerView.callbackRef = [skin luaRef:refTable] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.avplayer:actionMenu(menutable | nil) -> avplayerObject
/// Method
/// Set or remove the additional actions menu from the media controls for the avplayer.
///
/// Parameters:
///  * `menutable` - a table containing a menu definition as described in the documentation for `hs.menubar:setMenu`.  If `nil` is specified, any existing menu is removed.
///
/// Parameters:
///  * the avplayerObject
///
/// Notes:
///  * All menu keys supported by `hs.menubar:setMenu`, except for the `fn` key, are supported by this method.
///  * When a menu item is selected, the callback function (see [hs._asm.avplayer:setCallback](#setCallback)) is invoked with the following 4 arguments:
///    * the avplayerObject
///    * "actionMenu"
///    * the `title` field of the menu item selected
///    * a table containing the following keys set to true or false indicating which key modifiers were down when the menu item was selected: "cmd", "shift", "alt", "ctrl", and "fn".
static int avplayer_actionMenu(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;

// TODO: I *really* want hs.menubar to be re-written so menus can be used in other modules... maybe someday

    if (lua_type(L, 2) == LUA_TNIL) {
        playerView.actionPopUpButtonMenu = nil ;
    } else {
        NSArray *menuItems = [skin toNSObjectAtIndex:2] ;
        if (![menuItems isKindOfClass:[NSArray class]]) {
            return luaL_argerror(L, 2, "must be an array of key-value tables") ;
        }
        for (NSString *item in menuItems) {
            if (![item isKindOfClass:[NSDictionary class]]) {
                return luaL_argerror(L, 2, "must be an array of key-value tables") ;
            }
        }
        playerView.actionPopUpButtonMenu = menuMaker(menuItems, playerView) ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Methods - AVPlayer methods

/// hs._asm.avplayer:load(path) -> avplayerObject
/// Method
/// Load the specified resource for playback.
///
/// Parameters:
///  * `path` - a string specifying the file path or URL to the audiovisual resource.
///
/// Returns:
///  * the avplayerObject
///
/// Notes:
///  * Content will not start autoplaying when loaded - you must use the controls provided in the audiovisual player or one of [hs._asm.avplayer:play](#play) or [hs._asm.avplayer:rate](#rate) to begin playback.
///
///  * If the path or URL are malformed, unreachable, or otherwise unavailable, [hs._asm.avplayer:status](#status) will return "failed".
///  * Because a remote URL may not respond immediately, you can also setup a callback with [hs._asm.avplayer:trackStatus](#trackStatus) to be notified when the item has loaded or if it has failed.
static int avplayer_load(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayer         *player = playerView.player ;

    if (player.currentItem) {
        if (playerView.trackCompleted) {
            [[NSNotificationCenter defaultCenter] removeObserver:playerView
                                                            name:AVPlayerItemDidPlayToEndTimeNotification
                                                          object:player.currentItem] ;
        }
        if (playerView.trackStatus) {
            [player.currentItem removeObserver:playerView forKeyPath:@"status" context:myKVOContext] ;
        }
    }

    player.rate = 0.0f ; // any load should start in a paused state
    [player replaceCurrentItemWithPlayerItem:nil] ;

    if (lua_type(L, 2) != LUA_TNIL) {
        NSString *path   = [skin toNSObjectAtIndex:2] ;
        NSURL    *theURL = [NSURL URLWithString:path] ;

        if (!theURL) {
//             [LuaSkin logInfo:@"trying as fileURL"] ;
            theURL = [NSURL fileURLWithPath:[path stringByExpandingTildeInPath]] ;
        }

        [player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:theURL]] ;
    }

    if (player.currentItem) {
        if (playerView.trackCompleted) {
            [[NSNotificationCenter defaultCenter] addObserver:playerView
                                                     selector:@selector(didFinishPlaying:)
                                                         name:AVPlayerItemDidPlayToEndTimeNotification
                                                       object:player.currentItem] ;
        }
        if (playerView.trackStatus) {
            [player.currentItem addObserver:playerView
                                 forKeyPath:@"status"
                                    options:NSKeyValueObservingOptionNew
                                    context:myKVOContext] ;
        }
    }

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.avplayer:play([fromBeginning]) -> avplayerObject
/// Method
/// Play the audiovisual media currently loaded in the avplayer object.
///
/// Parameters:
///  * `fromBeginning` - an optional boolean, default false, specifying whether or not the media playback should start from the beginning or from the current location.
///
/// Returns:
///  * the avplayerObject
///
/// Notes:
///  * this is equivalent to setting the rate to 1.0 (see [hs._asm.avplayer:rate(1.0)](#rate)`)
static int avplayer_play(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayer         *player = playerView.player ;

    if (lua_gettop(L) == 2 && lua_toboolean(L, 2)) {
        [player seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero] ;
    }
    [player play] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.avplayer:pause() -> avplayerObject
/// Method
/// Pause the audiovisual media currently loaded in the avplayer object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the avplayerObject
///
/// Notes:
///  * this is equivalent to setting the rate to 0.0 (see [hs._asm.avplayer:rate(0.0)](#rate)`)
static int avplayer_pause(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayer         *player = playerView.player ;

    [player pause] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.avplayer:rate([rate]) -> avplayerObject | current value
/// Method
/// Get or set the rate of playback for the audiovisual content of the avplayer object.
///
/// Parameters:
///  * `rate` - an optional number specifying the rate you wish for the audiovisual content to be played.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
///
/// Notes:
///  * This method affects the playback rate of both video and audio -- if you wish to mute audio during a "fast forward" or "rewind", see [hs._asm.avplayer:mute](#mute).
///  * A value of 0.0 is equivalent to [hs._asm.avplayer:pause](#pause).
///  * A value of 1.0 is equivalent to [hs._asm.avplayer:play](#play).
///
///  * Other rates may not be available for all media and will be ignored if specified and the media does not support playback at the specified rate:
///    * Rates between 0.0 and 1.0 are allowed if [hs._asm.avplayer:playbackInformation](#playbackInformation) returns true for the `canPlaySlowForward` field
///    * Rates greater than 1.0 are allowed if [hs._asm.avplayer:playbackInformation](#playbackInformation) returns true for the `canPlayFastForward` field
///    * The item can be played in reverse (a rate of -1.0) if [hs._asm.avplayer:playbackInformation](#playbackInformation) returns true for the `canPlayReverse` field
///    * Rates between 0.0 and -1.0 are allowed if [hs._asm.avplayer:playbackInformation](#playbackInformation) returns true for the `canPlaySlowReverse` field
///    * Rates less than -1.0 are allowed if [hs._asm.avplayer:playbackInformation](#playbackInformation) returns true for the `canPlayFastReverse` field
static int avplayer_rate(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayer         *player = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number)player.rate) ;
    } else {
        player.rate = (float)lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.avplayer:mute([state]) -> avplayerObject | current value
/// Method
/// Get or set whether or not audio output is muted for the audovisual media item.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not audio output has been muted for the avplayer object.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayer_mute(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayer         *player = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, player.muted) ;
    } else {
        player.muted = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.avplayer:volume([volume]) -> avplayerObject | current value
/// Method
/// Get or set the avplayer object's volume on a linear scale from 0.0 (silent) to 1.0 (full volume, relative to the current OS volume).
///
/// Parameters:
///  * `volume` - an optional number, default as specified by the media or 1.0 if no designation is specified by the media, specifying the player's volume relative to the system volume level.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayer_volume(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayer         *player = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number)player.volume) ;
    } else {
        float newLevel = (float)lua_tonumber(L, 2) ;
        player.volume = ((newLevel < 0.0f) ? 0.0f : ((newLevel > 1.0f) ? 1.0f : newLevel)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.avplayer:ccEnabled([state]) -> avplayerObject | current value
/// Method
/// Get or set whether or not the player can use close captioning, if it is included in the audiovisual content.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not the player should display closed captioning information, if it is available.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayer_closedCaptionDisplayEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayer         *player = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, player.closedCaptionDisplayEnabled) ;
    } else {
        player.closedCaptionDisplayEnabled = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.avplayer:trackProgress([number | nil]) -> avplayerObject | current value
/// Method
/// Enable or disable a periodic callback at the interval specified.
///
/// Parameters:
///  * `number` - an optional number specifying how often, in seconds, the callback function should be invoked to report progress.  If an explicit nil is specified, then the progress callback is disabled. Defaults to nil.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.  A return value of `nil` indicates that no progress callback is in effect.
///
/// Notes:
///  * the callback function (see [hs._asm.avplayer:setCallback](#setCallback)) will be invoked with the following 3 arguments:
///    * the avplayerObject
///    * "progress"
///    * the time in seconds specifying the current location in the media playback.
///
///  * From Apple Documentation: The block is invoked periodically at the interval specified, interpreted according to the timeline of the current item. The block is also invoked whenever time jumps and whenever playback starts or stops. If the interval corresponds to a very short interval in real time, the player may invoke the block less frequently than requested. Even so, the player will invoke the block sufficiently often for the client to update indications of the current time appropriately in its end-user interface.
static int avplayer_trackProgress(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayer         *player     = playerView.player ;

    if (lua_gettop(L) == 1) {
        if (playerView.periodicObserver) {
            lua_pushnumber(L, playerView.periodicPeriod) ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (playerView.periodicObserver) {
            [player removeTimeObserver:playerView.periodicObserver] ;
            playerView.periodicObserver = nil ;
            playerView.periodicPeriod = 0.0 ;
        }
        if (lua_type(L, 2) != LUA_TNIL) {
            playerView.periodicPeriod = lua_tonumber(L, 2) ;
            CMTime period = CMTimeMakeWithSeconds(playerView.periodicPeriod, PREFERRED_TIMESCALE) ;
            playerView.periodicObserver = [player addPeriodicTimeObserverForInterval:period
                                                                               queue:NULL
                                                                          usingBlock:^(CMTime time) {
                if (playerView.callbackRef != LUA_NOREF) {
                    [skin pushLuaRef:refTable ref:playerView.callbackRef] ;
                    [skin pushNSObject:playerView] ;
                    lua_pushstring(L, "progress") ;
                    lua_pushnumber(L, CMTimeGetSeconds(time)) ;
                    if (![skin protectedCallAndTraceback:3 nresults:0]) {
                        NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
                        lua_pop(L, 1) ;
                        [skin logError:[NSString stringWithFormat:@"%s:trackProgress callback error:%@", USERDATA_TAG, errorMessage]] ;
                    }
                }
            }] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.avplayer:trackRate([state]) -> avplayerObject | current value
/// Method
/// Enable or disable a callback whenever the rate of playback changes.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not playback rate changes should invoke a callback.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
///
/// Notes:
///  * the callback function (see [hs._asm.avplayer:setCallback](#setCallback)) will be invoked with the following 3 arguments:
///    * the avplayerObject
///    * "pause", if the rate changes to 0.0, or "play" if the rate changes to any other value
///    * the rate that the playback was changed to.
///
///  * Not all media content can have its playback rate changed; attempts to do so will invoke the callback twice -- once signifying that the change was made, and a second time indicating that the rate of play was reset back to the limits of the media content.  See [hs._asm:rate](#rate) for more information.
static int avplayer_trackRate(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayer         *player     = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.trackRate) ;
    } else {
        if (playerView.trackRate) {
            [player removeObserver:playerView forKeyPath:@"rate" context:myKVOContext] ;
        }

        playerView.trackRate = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;

        if (playerView.trackRate) {
            [player addObserver:playerView
                     forKeyPath:@"rate"
                        options:NSKeyValueObservingOptionNew
                        context:myKVOContext] ;
        }
    }
    return 1 ;
}

#pragma mark - Module Methods - AVPlayerItem methods

/// hs._asm.avplayer:playbackInformation() -> table | nil
/// Method
/// Returns a table containing information about the media playback characteristics of the audiovisual media currently loaded in the avplayerObject.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the following media characteristics, or `nil` if no media content is currently loaded:
///    * "playbackLikelyToKeepUp" - Indicates whether the item will likely play through without stalling.  Note that this is only a prediction.
///    * "playbackBufferEmpty"    - Indicates whether playback has consumed all buffered media and that playback may stall or end.
///    * "playbackBufferFull"     - Indicates whether the internal media buffer is full and that further I/O is suspended.
///    * "canPlayReverse"         - A Boolean value indicating whether the item can be played with a rate of -1.0.
///    * "canPlayFastForward"     - A Boolean value indicating whether the item can be played at rates greater than 1.0.
///    * "canPlayFastReverse"     - A Boolean value indicating whether the item can be played at rates less than –1.0.
///    * "canPlaySlowForward"     - A Boolean value indicating whether the item can be played at a rate between 0.0 and 1.0.
///    * "canPlaySlowReverse"     - A Boolean value indicating whether the item can be played at a rate between -1.0 and 0.0.
static int avplayer_playbackInformation(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayerItem     *playerItem = playerView.player.currentItem ;

    if (playerItem) {
        lua_newtable(L) ;
        lua_pushboolean(L, playerItem.playbackLikelyToKeepUp) ; lua_setfield(L, -2, "playbackLikelyToKeepUp") ;
        lua_pushboolean(L, playerItem.playbackBufferEmpty) ;    lua_setfield(L, -2, "playbackBufferEmpty") ;
        lua_pushboolean(L, playerItem.playbackBufferFull) ;     lua_setfield(L, -2, "playbackBufferFull") ;
        lua_pushboolean(L, playerItem.canPlayReverse) ;         lua_setfield(L, -2, "canPlayReverse") ;
        lua_pushboolean(L, playerItem.canPlayFastForward) ;     lua_setfield(L, -2, "canPlayFastForward") ;
        lua_pushboolean(L, playerItem.canPlayFastReverse) ;     lua_setfield(L, -2, "canPlayFastReverse") ;
        lua_pushboolean(L, playerItem.canPlaySlowForward) ;     lua_setfield(L, -2, "canPlaySlowForward") ;
        lua_pushboolean(L, playerItem.canPlaySlowReverse) ;     lua_setfield(L, -2, "canPlaySlowReverse") ;

// Not currently supported by the module since it involves tracks
//         lua_pushboolean(L, playerItem.canStepBackward) ;        lua_setfield(L, -2, "canStepBackward") ;
//         lua_pushboolean(L, playerItem.canStepForward) ;         lua_setfield(L, -2, "canStepForward") ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.avplayer:status() -> status[, error] | nil
/// Method
/// Returns the current status of the media content loaded for playback.
///
/// Parameters:
///  * None
///
/// Returns:
///  * One of the following status strings, or `nil` if no media content is currently loaded:
///    * "unknown"     - The content's status is unknown; often this is returned when remote content is still loading or being evaluated for playback.
///    * "readyToPlay" - The content has been loaded or sufficiently buffered so that playback may begin
///    * "failed"      - There was an error loading the content; a second return value will contain a string which may contain more information about the error.
static int avplayer_status(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayerItem     *playerItem = playerView.player.currentItem ;
    int              returnCount = 1 ;

    if (playerItem) {
        switch(playerItem.status) {
            case AVPlayerStatusUnknown:
                lua_pushstring(L, "unknown") ;
                break ;
            case AVPlayerStatusReadyToPlay:
                lua_pushstring(L, "readyToPlay") ;
                break ;
            case AVPlayerStatusFailed:
                lua_pushstring(L, "failed") ;
                [skin pushNSObject:[playerItem.error localizedDescription]] ;
                returnCount++ ;
                break ;
            default:
                lua_pushstring(L, [[NSString stringWithFormat:@"unrecognized status:%ld", playerItem.status] UTF8String]) ;
                break ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return returnCount ;
}


/// hs._asm.avplayer:trackCompleted([state]) -> avplayerObject | current value
/// Method
/// Enable or disable a callback whenever playback of the current media content is completed (reaches the end).
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not completing the playback of media should invoke a callback.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
///
/// Notes:
///  * the callback function (see [hs._asm.avplayer:setCallback](#setCallback)) will be invoked with the following 2 arguments:
///    * the avplayerObject
///    * "finished"
static int avplayer_trackCompleted(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayerItem     *playerItem = playerView.player.currentItem ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.trackCompleted) ;
    } else {
        if (playerItem && playerView.trackCompleted) {
            [[NSNotificationCenter defaultCenter] removeObserver:playerView
                                                            name:AVPlayerItemDidPlayToEndTimeNotification
                                                          object:playerItem] ;
        }

        playerView.trackCompleted = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;

        if (playerItem && playerView.trackCompleted) {
            [[NSNotificationCenter defaultCenter] addObserver:playerView
                                                     selector:@selector(didFinishPlaying:)
                                                         name:AVPlayerItemDidPlayToEndTimeNotification
                                                       object:playerItem] ;
        }
    }
    return 1 ;
}

/// hs._asm.avplayer:trackStatus([state]) -> avplayerObject | current value
/// Method
/// Enable or disable a callback whenever the status of loading a media item changes.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not changes to the status of audiovisual media's loading status should generate a callback..
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
///
/// Notes:
///  * the callback function (see [hs._asm.avplayer:setCallback](#setCallback)) will be invoked with the following 3 or 4 arguments:
///    * the avplayerObject
///    * "status"
///    * a string matching one of the states described in [hs._asm.avplayer:status](#status)
///    * if the state reported is failed, an error message describing the error that occurred.
static int avplayer_trackStatus(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayerItem     *playerItem = playerView.player.currentItem ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.trackStatus) ;
    } else {
        if (playerItem && playerView.trackStatus) {
            [playerItem removeObserver:playerView forKeyPath:@"status" context:myKVOContext] ;
        }

        playerView.trackStatus = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;

        if (playerItem && playerView.trackStatus) {
            [playerItem addObserver:playerView
                         forKeyPath:@"status"
                            options:NSKeyValueObservingOptionNew
                            context:myKVOContext] ;
        }
    }
    return 1 ;
}

/// hs._asm.avplayer:time() -> number | nil
/// Method
/// Returns the current position in seconds within the audiovisual media content.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the current position, in seconds, within the audiovisual media content, or `nil` if no media content is currently loaded.
static int avplayer_currentTime(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayerItem     *playerItem = playerView.player.currentItem ;

    if (playerItem) {
        lua_pushnumber(L, CMTimeGetSeconds(playerItem.currentTime)) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.avplayer:duration() -> number | nil
/// Method
/// Returns the duration, in seconds, of the audiovisual media content currently loaded.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the duration, in seconds, of the audiovisual media content currently loaded, if it can be determined, or `nan` (not-a-number) if it cannot.  If no item has been loaded, this method will return nil.
///
/// Notes:
///  * the duration of an item which is still loading cannot be determined; you may want to use [hs._asm.avplayer:trackStatus](#trackStatus) and wait until it receives a "readyToPlay" state before querying this method.
///
///  * a live stream may not provide duration information and also return `nan` for this method.
///
///  * Lua defines `nan` as a number which is not equal to itself.  To test if the value of this method is `nan` requires code like the following:
///  ~~~lua
///  duration = avplayer:duration()
///  if type(duration) == "number" and duration ~= duration then
///      -- the duration is equal to `nan`
///  end
/// ~~~
static int avplayer_duration(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayerItem     *playerItem = playerView.player.currentItem ;

    if (playerItem) {
        lua_pushnumber(L, CMTimeGetSeconds(playerItem.duration)) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.avplayer:seek(time, [callback]) -> avplayerObject | nil
/// Method
/// Jumps to the specified location in the audiovisual content currently loaded into the player.
///
/// Parameters:
///  * `time`     - the location, in seconds, within the audiovisual content to seek to.
///  * `callback` - an optional boolean, default false, specifying whether or not a callback should be invoked when the seek operation has completed.
///
/// Returns:
///  * the avplayerObject, or nil if no media content is currently loaded
///
/// Notes:
///  * If you specify `callback` as true, the callback function (see [hs._asm.avplayer:setCallback](#setCallback)) will be invoked with the following 3 or 4 arguments:
///    * the avplayerObject
///    * "seek"
///    * the current time, in seconds, specifying the current playback position in the media content
///    * `true` if the seek operation was allowed to complete, or `false` if it was interrupted (for example by another seek request).
static int avplayer_seekToTime(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayerItem     *playerItem = playerView.player.currentItem ;
    lua_Number       desiredPosition = lua_tonumber(L, 2) ;

    if (playerItem) {
        CMTime positionAsCMTime = CMTimeMakeWithSeconds(desiredPosition, PREFERRED_TIMESCALE) ;
        if (lua_gettop(L) == 3 && lua_toboolean(L, 3)) {
            [playerItem seekToTime:positionAsCMTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
                if (playerView.callbackRef != LUA_NOREF) {
                    [skin pushLuaRef:refTable ref:playerView.callbackRef] ;
                    [skin pushNSObject:playerView] ;
                    lua_pushstring(L, "seek") ;
                    lua_pushnumber(L, CMTimeGetSeconds(playerItem.currentTime)) ;
                    lua_pushboolean(L, finished) ;
                    if (![skin protectedCallAndTraceback:4 nresults:0]) {
                        NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
                        lua_pop(L, 1) ;
                        [skin logError:[NSString stringWithFormat:@"%s:seek callback error:%@", USERDATA_TAG, errorMessage]] ;
                    }
                }
            }] ;
        } else {
            [playerItem seekToTime:positionAsCMTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods - experimental

/// hs._asm.avplayer:fullScreenButton([state]) -> avplayerObject | current value
/// Method
/// Get or set whether or not the full screen toggle button should be included in the media controls.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not the full screen toggle button should be included in the media controls.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayer_showsFullScreenToggleButton(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.showsFullScreenToggleButton) ;
    } else {
        playerView.showsFullScreenToggleButton = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.avplayer:allowExternalPlayback([state]) -> avplayerObject | current value
/// Method
/// Get or set whether or not external playback via AirPlay is allowed for this item.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether external playback via AirPlay is allowed for this item.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
///
/// Notes:
///  * External playback via AirPlay is only available in macOS 10.11 and newer.
static int avplayer_allowsExternalPlayback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayer         *player = playerView.player ;

    if (lua_gettop(L) == 1) {
        if ([player respondsToSelector:@selector(allowsExternalPlayback)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
            lua_pushboolean(L, player.allowsExternalPlayback) ;
#pragma clang diagnostic pop
        } else {
            lua_pushboolean(L, NO) ;
        }
    } else {
        if ([player respondsToSelector:@selector(setAllowsExternalPlayback:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
            player.allowsExternalPlayback = (BOOL)lua_toboolean(L, 2) ;
#pragma clang diagnostic pop
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:external playback only available in 10.11 and newer", USERDATA_TAG]] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.avplayer:externalPlayback() -> Boolean
/// Method
/// Returns whether or not external playback via AirPlay is currently active for the avplayer object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true, if AirPlay is currently being used to play the audiovisual content, or false if it is not.
///
/// Notes:
///  * External playback via AirPlay is only available in macOS 10.11 and newer.
static int avplayer_externalPlaybackActive(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSAVPlayerWindow *theWindow = [skin toNSObjectAtIndex:1] ;
    HSAVPlayerView   *playerView = theWindow.contentView ;
    AVPlayer         *player = playerView.player ;

    if ([player respondsToSelector:@selector(isExternalPlaybackActive)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
        lua_pushboolean(L, player.externalPlaybackActive) ;
#pragma clang diagnostic pop
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSAVPlayerWindow(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSAVPlayerWindow *value = obj;
    if (value.selfRef == LUA_NOREF) {
        void** valuePtr = lua_newuserdata(L, sizeof(HSAVPlayerWindow *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
        value.selfRef = [skin luaRef:refTable] ;
    }
    [skin pushLuaRef:refTable ref:value.selfRef] ;
    return 1 ;
}

static id toHSAVPlayerWindowFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSAVPlayerWindow *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSAVPlayerWindow, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSAVPlayerWindow *obj = [skin luaObjectAtIndex:1 toClass:"HSAVPlayerWindow"] ;
    NSString *title = obj.title ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSAVPlayerWindow *obj1 = [skin luaObjectAtIndex:1 toClass:"HSAVPlayerWindow"] ;
        HSAVPlayerWindow *obj2 = [skin luaObjectAtIndex:2 toClass:"HSAVPlayerWindow"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSAVPlayerWindow *obj = get_objectFromUserdata(__bridge_transfer HSAVPlayerWindow, L, 1, USERDATA_TAG) ;
    if (obj) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSAVPlayerView *view = obj.contentView ;
        obj.selfRef          = [skin luaUnref:refTable ref:obj.selfRef] ;
        obj.windowCallback   = [skin luaUnref:refTable ref:obj.windowCallback] ;
        view.callbackRef     = [skin luaUnref:refTable ref:view.callbackRef] ;
        if (view.periodicObserver) {
            [view.player removeTimeObserver:view.periodicObserver] ;
            view.periodicObserver = nil ;
            view.periodicPeriod = 0.0 ;
        }

        if (view.player.currentItem) {
            if (view.trackCompleted) {
                [[NSNotificationCenter defaultCenter] removeObserver:view
                                                                name:AVPlayerItemDidPlayToEndTimeNotification
                                                              object:view.player.currentItem] ;
            }
            if (view.trackStatus) {
                [view.player.currentItem removeObserver:view forKeyPath:@"status" context:myKVOContext] ;
            }
        }
        if (view.trackRate) {
            [view.player removeObserver:view forKeyPath:@"rate" context:myKVOContext] ;
        }

        [obj close] ;
        obj.delegate = nil ;
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
    {"alpha",           avplayer_alpha},
    {"behavior",        avplayer_behavior},
    {"bringToFront",    avplayer_bringToFront},
    {"delete",          avplayer_delete},
    {"hide",            avplayer_hide},
    {"keyboardControl", avplayer_keyboardControl},
    {"level",           avplayer_level},
    {"orderAbove",      avplayer_orderAbove},
    {"orderBelow",      avplayer_orderBelow},
    {"sendToBack",      avplayer_sendToBack},
    {"shadow",          avplayer_shadow},
    {"show",            avplayer_show},
    {"size",            avplayer_size},
    {"topLeft",         avplayer_topLeft},
    {"windowCallback",  avplayer_windowCallback},
    {"windowStyle",     avplayer_windowStyle},

// ASMAVPlayerView methods
    {"actionMenu",            avplayer_actionMenu},
    {"controlsStyle",         avplayer_controlsStyle},
    {"flashChapterAndTitle",  avplayer_flashChapterAndTitle},
    {"frameSteppingButtons",  avplayer_showsFrameSteppingButtons},
    {"fullScreenButton",      avplayer_showsFullScreenToggleButton},
    {"pauseWhenHidden",       avplayer_pauseWhenHidden},
    {"setCallback",           avplayer_callback},
    {"sharingServiceButton",  avplayer_showsSharingServiceButton},

// AVPlayer methods
    {"allowExternalPlayback", avplayer_allowsExternalPlayback},
    {"ccEnabled",             avplayer_closedCaptionDisplayEnabled},
    {"externalPlayback",      avplayer_externalPlaybackActive},
    {"load",                  avplayer_load},
    {"mute",                  avplayer_mute},
    {"pause",                 avplayer_pause},
    {"play",                  avplayer_play},
    {"rate",                  avplayer_rate},
    {"trackProgress",         avplayer_trackProgress},
    {"trackRate",             avplayer_trackRate},
    {"volume",                avplayer_volume},

// AVPlayerItem methods
    {"duration",              avplayer_duration},
    {"playbackInformation",   avplayer_playbackInformation},
    {"seek",                  avplayer_seekToTime},
    {"status",                avplayer_status},
    {"time",                  avplayer_currentTime},
    {"trackStatus",           avplayer_trackStatus},
    {"trackCompleted",        avplayer_trackCompleted},

    {"__tostring",      userdata_tostring},
    {"__eq",            userdata_eq},
    {"__gc",            userdata_gc},
    {NULL,              NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", avplayer_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_avplayer_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSAVPlayerWindow         forClass:"HSAVPlayerWindow"];
    [skin registerLuaObjectHelper:toHSAVPlayerWindowFromLua forClass:"HSAVPlayerWindow"
                                                 withUserdataMapping:USERDATA_TAG];

    return 1;
}
