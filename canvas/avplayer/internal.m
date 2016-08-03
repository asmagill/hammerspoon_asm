@import Cocoa ;
@import AVKit;
@import AVFoundation;

@import LuaSkin ;

#define USERDATA_TAG "hs._asm.canvas.avplayer"
static int refTable = LUA_NOREF;

// see https://warrenmoore.net/understanding-cmtime
static const int32_t PREFERRED_TIMESCALE = 60000 ;

static void *myKVOContext = &myKVOContext;

#define VIEW_DEBUG

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#define CONTROLS_STYLES @{ \
    @"none"     : @(AVPlayerViewControlsStyleNone), \
    @"inline"   : @(AVPlayerViewControlsStyleInline), \
    @"floating" : @(AVPlayerViewControlsStyleFloating), \
    @"minimal"  : @(AVPlayerViewControlsStyleMinimal), \
    @"default"  : @(AVPlayerViewControlsStyleDefault), \
}

#pragma mark - Support Functions and Classes

@interface ASMAVPlayerView : AVPlayerView
@property BOOL       pauseWhenHidden ;
@property BOOL       trackCompleted ;
@property BOOL       trackRate ;
@property BOOL       trackStatus ;
@property int        callbackRef ;
@property id         periodicObserver ;
@property lua_Number periodicPeriod ;
@end

@implementation ASMAVPlayerView {
    float rateWhenHidden ;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    if (!(isfinite(frameRect.origin.x)    && isfinite(frameRect.origin.y) &&
          isfinite(frameRect.size.height) && isfinite(frameRect.size.width))) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:frame must be specified in finite numbers", USERDATA_TAG]];
        return nil;
    }

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

//         self.player                      = nil ;
        self.player                      = [[AVPlayer alloc] init] ;
        self.controlsStyle               = AVPlayerViewControlsStyleDefault ;
        self.showsFrameSteppingButtons   = NO ;
        self.showsSharingServiceButton   = NO ;
        self.showsFullScreenToggleButton = NO ;
        self.actionPopUpButtonMenu       = nil ;
    }
    return self;
}

- (void)dealloc {
#ifdef VIEW_DEBUG
        [LuaSkin logInfo:[NSString stringWithFormat:@"%s dealloc for AVPlayerView with frame %@", USERDATA_TAG, NSStringFromRect(self.frame)]] ;
#endif
    LuaSkin *skin = [LuaSkin shared] ;

    // remove function callback if lua state still exists and a callback was assigned
    if ([skin L] && _callbackRef != LUA_NOREF) {
        _callbackRef = [skin luaUnref:refTable ref:_callbackRef] ;
    }

    // remove observers -- should have been done by didRemoveFromCanvas, but just to be on the safe side...
    if (_periodicObserver) {
        [self.player removeTimeObserver:_periodicObserver] ;
        _periodicObserver = nil ;
        _periodicPeriod = 0.0 ;
    }

    if (self.player.currentItem) {
        if (_trackCompleted) {
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:AVPlayerItemDidPlayToEndTimeNotification
                                                          object:self.player.currentItem] ;
        }
        if (_trackStatus) {
            [self.player.currentItem removeObserver:self forKeyPath:@"status" context:myKVOContext] ;
        }
    }
    if (_trackRate) {
        [self.player removeObserver:self forKeyPath:@"rate" context:myKVOContext] ;
    }
}

// Not sure if this is really necessary, but matches out parent -- Hammerspoon is a 0,0 at top-left environment
- (BOOL)isFlipped { return YES; }

- (void)didFinishPlaying:(__unused NSNotification *)notification {
    if (_callbackRef != LUA_NOREF && _trackCompleted) {
        LuaSkin *skin = [LuaSkin shared] ;
        lua_State *L = [skin L] ;
        [skin pushLuaRef:refTable ref:self->_callbackRef] ;
        [skin pushNSObject:self] ;
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
            [skin pushNSObject:self] ;
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
            [skin pushNSObject:self] ;
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
        [skin pushNSObject:self] ;
        [skin pushNSObject:@"actionMenu"] ;
        [skin pushNSObject:(([title isEqualToString:@""]) ? [sender.attributedTitle string] : title)] ;
        lua_newtable(L) ;
        lua_pushboolean(L, (theFlags & NSCommandKeyMask) != 0) ;   lua_setfield(L, -2, "cmd") ;
        lua_pushboolean(L, (theFlags & NSShiftKeyMask) != 0) ;     lua_setfield(L, -2, "shift") ;
        lua_pushboolean(L, (theFlags & NSAlternateKeyMask) != 0) ; lua_setfield(L, -2, "alt") ;
        lua_pushboolean(L, (theFlags & NSControlKeyMask) != 0) ;   lua_setfield(L, -2, "ctrl") ;
        lua_pushboolean(L, (theFlags & NSFunctionKeyMask) != 0) ;  lua_setfield(L, -2, "fn") ;
        lua_pushinteger(L, theFlags) ; lua_setfield(L, -2, "_raw") ;
        if (![skin protectedCallAndTraceback:4 nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:actionMenu callback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    }
}

// Methods which are invoked by the canvas on us

- (void)canvasWillHide {
    if (_pauseWhenHidden) {
        rateWhenHidden = self.player.rate ;
        [self.player pause] ;
    }
}

// - (void)canvasDidHide {}
// - (void)canvasWillShow {}

- (void)canvasDidShow {
    if (rateWhenHidden != 0.0f) {
        self.player.rate = rateWhenHidden ;
        rateWhenHidden = 0.0f ;
    }
}

// - (void)willRemoveFromCanvas {}

- (void)didRemoveFromCanvas {
    self.player.rate = 0.0f ;

// remove observers when we're not part of a canvas -- prevents deallocation if going bye-bye
    if (_periodicObserver) {
        [self.player removeTimeObserver:_periodicObserver] ;
        _periodicObserver = nil ;
        _periodicPeriod = 0.0 ;
    }

    if (self.player.currentItem) {
        if (_trackCompleted) {
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:AVPlayerItemDidPlayToEndTimeNotification
                                                          object:self.player.currentItem] ;
            _trackCompleted = NO ;
        }
        if (_trackStatus) {
            [self.player.currentItem removeObserver:self forKeyPath:@"status" context:myKVOContext] ;
            _trackStatus = NO ;
        }
    }
    if (_trackRate) {
        [self.player removeObserver:self forKeyPath:@"rate" context:myKVOContext] ;
        _trackRate = NO ;
    }

#ifdef VIEW_DEBUG
    [LuaSkin logInfo:@"avplayer in didRemoveFromCanvas"] ;
#endif
}

// - (void)willAddToCanvas {}
// - (void)didAddToCanvas {}

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

/// hs._asm.canvas.avplayer.new([frame]) -> avplayerObject
/// Constructor
/// Creates a new AVPlayer object which can display audiovisual media within an `hs._asm.canvas` object.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size the object is initialized with.
///
/// Returns:
///  * the avplayerObject
///
/// Notes:
///  * The `frame` argument is ignored by `hs._asm.canvas`.  When an object is added as a `view` element to an `hs._asm.canvas` object, it is assigned the frame defined for the canvas element.  This parameter is allowed in case it proves necessary for the use of an avplayer object in future contexts (i.e. future Hammerspoon modules).
static int avplayer_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    ASMAVPlayerView *playerView = [[ASMAVPlayerView alloc] initWithFrame:frameRect];
    [skin pushNSObject:playerView] ;
    return 1 ;
}

#pragma mark - Module Methods

#pragma mark - ASMAVPlayerView methods

/// hs._asm.canvas.avplayer:controlsStyle([style]) -> avplayerObject | current value
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
///
/// Notes:
///  * Media controls can only receive mouse events if the canvas can.  This requires that the canvas has a callback function defined, even though mouse events affecting the view are not handled by the canvas callback function. `canvasObject:mouseCallback(function() end)` is sufficient for this purpose if no other canvas element requires the callback function.
static int avplayer_controlsStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;

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

/// hs._asm.canvas.avplayer:fullScreenButton([state]) -> avplayerObject | current value
/// Method
/// Get or set whether or not the full screen toggle button should be included in the media controls.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not the full screen toggle button should be included in the media controls.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
///
/// Notes:
///  * this method is experimental -- currently it causes problems with keeping the avplayer object properly assigned within the canvas.  This method may be removed until a reliable solution cannot be found.
static int avplayer_showsFullScreenToggleButton(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.showsFullScreenToggleButton) ;
    } else {
        playerView.showsFullScreenToggleButton = (BOOL)lua_toboolean(L, 2) ;
    }
    return 1 ;
}

/// hs._asm.canvas.avplayer:frameSteppingButtons([state]) -> avplayerObject | current value
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
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.showsFrameSteppingButtons) ;
    } else {
        playerView.showsFrameSteppingButtons = (BOOL)lua_toboolean(L, 2) ;
    }
    return 1 ;
}

/// hs._asm.canvas.avplayer:sharingServiceButton([state]) -> avplayerObject | current value
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
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.showsSharingServiceButton) ;
    } else {
        playerView.showsSharingServiceButton = (BOOL)lua_toboolean(L, 2) ;
    }
    return 1 ;
}

/// hs._asm.canvas.avplayer:flashChapterAndTitle(number, [string]) -> avplayerObject
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
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    NSUInteger      chapterNumber = (lua_Unsigned)lua_tointeger(L, 2) ;
    NSString        *chapterTitle = (lua_gettop(L) == 3) ? [skin toNSObjectAtIndex:3] : nil ;

    [playerView flashChapterNumber:chapterNumber chapterTitle:chapterTitle] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.canvas.avplayer:pauseWhenHidden([state]) -> avplayerObject | current value
/// Method
/// Get or set whether or not playback of media should be paused when the canvas it belongs to is hidden.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether or not media playback should be paused when the canvas it belongs to is hidden.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayer_pauseWhenHidden(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.pauseWhenHidden) ;
    } else {
        playerView.pauseWhenHidden = (BOOL)lua_toboolean(L, 2) ;
    }
    return 1 ;
}

/// hs._asm.canvas.avplayer:setCallback(fn) -> avplayerObject
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
///    * `actionMenu` - [hs._asm.canvas.avplayer:actionMenu](#actionMenu)
///    * `finished`   - [hs._asm.canvas.avplayer:trackCompleted](#trackCompleted)
///    * `pause`      - [hs._asm.canvas.avplayer:trackRate](#trackRate)
///    * `play`       - [hs._asm.canvas.avplayer:trackRate](#trackRate)
///    * `progress`   - [hs._asm.canvas.avplayer:trackProgress](#trackProgress)
///    * `seek`       - [hs._asm.canvas.avplayer:seek](#seek)
///    * `status`     - [hs._asm.canvas.avplayer:trackStatus](#trackStatus)
static int avplayer_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL,
                    LS_TBREAK] ;

    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;

    // We're either removing a callback, or setting a new one. Either way, remove existing.
    playerView.callbackRef = [skin luaUnref:refTable ref:playerView.callbackRef];

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        playerView.callbackRef = [skin luaRef:refTable] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.canvas.avplayer:actionMenu(menutable | nil) -> avplayerObject
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
///  * When a menu item is selected, the callback function (see [hs._asm.canvas.avplayer:setCallback](#setCallback)) is invoked with the following 4 arguments:
///    * the avplayerObject
///    * "actionMenu"
///    * the `title` field of the menu item selected
///    * a table containing the following keys set to true or false indicating which key modifiers were down when the menu item was selected: "cmd", "shift", "alt", "ctrl", and "fn".
static int avplayer_actionMenu(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
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

#pragma mark - AVPlayer methods

static int avplayer_load(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer        *player = playerView.player ;

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
        NSString *path    = [skin toNSObjectAtIndex:2] ;
        NSURL    *theURL ;

        if ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByExpandingTildeInPath]]) {
            theURL = [NSURL fileURLWithPath:[path stringByExpandingTildeInPath]] ;
        } else {
            theURL = [NSURL URLWithString:path] ;
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

static int avplayer_play(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer        *player = playerView.player ;

    if (lua_gettop(L) == 2 && lua_toboolean(L, 2)) {
        [player seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero] ;
    }
    [player play] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int avplayer_pause(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer        *player = playerView.player ;

    [player pause] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int avplayer_rate(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer        *player = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number)player.rate) ;
    } else {
        player.rate = (float)lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int avplayer_mute(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer        *player = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, player.muted) ;
    } else {
        player.muted = (BOOL)lua_toboolean(L, 2) ;
    }
    return 1 ;
}

static int avplayer_volume(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer        *player = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number)player.volume) ;
    } else {
        float newLevel = (float)lua_tonumber(L, 2) ;
        player.volume = ((newLevel < 0.0f) ? 0.0f : ((newLevel > 1.0f) ? 1.0f : newLevel)) ;
    }
    return 1 ;
}

static int avplayer_allowsExternalPlayback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer        *player = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, player.allowsExternalPlayback) ;
    } else {
        player.allowsExternalPlayback = (BOOL)lua_toboolean(L, 2) ;
    }
    return 1 ;
}

static int avplayer_externalPlaybackActive(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer        *player = playerView.player ;

    lua_pushboolean(L, player.externalPlaybackActive) ;
    return 1 ;
}

static int avplayer_closedCaptionDisplayEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer        *player = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, player.closedCaptionDisplayEnabled) ;
    } else {
        player.closedCaptionDisplayEnabled = (BOOL)lua_toboolean(L, 2) ;
    }
    return 1 ;
}

static int avplayer_trackProgress(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer        *player     = playerView.player ;

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

static int avplayer_trackRate(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer        *player     = playerView.player ;

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

#pragma mark - AVPlayerItem methods

/// hs._asm.canvas.avplayer:playerInformation() -> table
/// Method
/// Returns a table containing information about the media playback characteristics of the audiovisual media currently loaded in the avplayerObject.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the following media characteristics:
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
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayerItem    *playerItem = playerView.player.currentItem ;

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

static int avplayer_status(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayerItem    *playerItem = playerView.player.currentItem ;
    int             returnCount = 1 ;

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

static int avplayer_trackCompleted(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayerItem    *playerItem = playerView.player.currentItem ;

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

static int avplayer_trackStatus(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayerItem    *playerItem = playerView.player.currentItem ;

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

static int avplayer_currentTime(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayerItem    *playerItem = playerView.player.currentItem ;

    if (playerItem) {
        lua_pushnumber(L, CMTimeGetSeconds(playerItem.currentTime)) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int avplayer_duration(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayerItem    *playerItem = playerView.player.currentItem ;

    if (playerItem) {
        lua_pushnumber(L, CMTimeGetSeconds(playerItem.duration)) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int avplayer_seekToTime(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayerItem    *playerItem = playerView.player.currentItem ;
    lua_Number      desiredPosition = lua_tonumber(L, 2) ;

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

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMAVPlayerView(lua_State *L, id obj) {
    ASMAVPlayerView *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMAVPlayerView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toASMAVPlayerViewFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMAVPlayerView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMAVPlayerView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMAVPlayerView *obj = [skin luaObjectAtIndex:1 toClass:"ASMAVPlayerView"] ;
    NSString *title = NSStringFromRect(obj.frame) ;

    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMAVPlayerView *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMAVPlayerView"] ;
        ASMAVPlayerView *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMAVPlayerView"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMAVPlayerView *obj = get_objectFromUserdata(__bridge_transfer ASMAVPlayerView, L, 1, USERDATA_TAG) ;
    if (obj) {

// If we have a selfRef, like canvas or drawing, we have to have a delete function and the user has
// to use it. Skipping the callback deref wastes memory by leaving a dangling function reference in lua,
// but that's less memory then leaving an AVPlayerView object that's no longer strongly held in a canvas's
// element list or in a lua variable.
//
// Moving function deref into object dealloc method mitigates this, but only if we make sure that no
// strong references exist to/within the object or its observers (see didRemoveFromCanvas).  Since the
// only use for this module right now *is* as a member of a canvas this seems reasonable.  Will have to
// reconsider if someone comes up with another use for this submodule/
//
//         obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;

#ifdef VIEW_DEBUG
        [LuaSkin logInfo:[NSString stringWithFormat:@"%s.__gc releasing AVPlayerView with frame %@", USERDATA_TAG, NSStringFromRect(obj.frame)]] ;
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s.__gc invoked for nil AVPlayerView", USERDATA_TAG]] ;
#endif

    }
    obj = nil ;

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
// ASMAVPlayerView methods
    {"actionMenu",            avplayer_actionMenu},
    {"controlsStyle",         avplayer_controlsStyle},
    {"flashChapterAndTitle",  avplayer_flashChapterAndTitle},
    {"frameSteppingButtons",  avplayer_showsFrameSteppingButtons},
    {"pauseWhenHidden",       avplayer_pauseWhenHidden},
    {"setCallback",           avplayer_callback},
    {"sharingServiceButton",  avplayer_showsSharingServiceButton},

// AVPlayer methods
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

// FIXME: subview release/loss from canvas with fullscreen (maybe AirPlay as well?)
    {"fullScreenButton",      avplayer_showsFullScreenToggleButton},
    {"allowExternalPlayback", avplayer_allowsExternalPlayback},

// Lua meta-methods
    {"__tostring",            userdata_tostring},
    {"__eq",                  userdata_eq},
    {"__gc",                  userdata_gc},
    {NULL,                    NULL}
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

int luaopen_hs__asm_canvas_avplayer_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASMAVPlayerView         forClass:"ASMAVPlayerView"];
    [skin registerLuaObjectHelper:toASMAVPlayerViewFromLua forClass:"ASMAVPlayerView"
                                             withUserdataMapping:USERDATA_TAG];

    return 1;
}
