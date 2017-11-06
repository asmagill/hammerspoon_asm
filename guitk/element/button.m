// TODO:
// *  Can we mimic the 10.12 constructors so that macOS version doesn't matter?
//    Look closer at NSButtonCell, specifically backgroundColor, highlightsBy, showsStateBy
//    keyEquivalent?
//    check accelerator buttons and image leading/trailing in 10.10 VM

// #define TEST_FALLBACKS


/// === hs._asm.guitk.element.button ===
///
/// Provides button and checkbox elements for use with `hs._asm.guitk`.
///
/// * This submodule inherits methods from `hs._asm.guitk.element._control` and you should consult its documentation for additional methods which may be used.
/// * This submodule inherits methods from `hs._asm.guitk.element._view` and you should consult its documentation for additional methods which may be used.

@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.guitk.element.button" ;
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *BUTTON_STYLES ;
static NSDictionary *BEZEL_STYLES ;
static NSDictionary *IMAGE_POSITIONS ;
static NSDictionary *BUTTON_STATES ;
static NSDictionary *IMAGE_SCALING_TYPES ;

#pragma mark - Support Functions and Classes

static void defineInternalDictionaryies() {
// These use enums, so they get expanded during compile time, and we compile on the latest OS, but since
// they are considered partial, the compiler whines a lot.
// still, use of them may crash in 10.10... should check that in VM
    BUTTON_STYLES = @{
        @"momentaryLight"        : @(NSButtonTypeMomentaryLight),
        @"pushOnPushOff"         : @(NSButtonTypePushOnPushOff),
        @"toggle"                : @(NSButtonTypeToggle),
        @"switch"                : @(NSButtonTypeSwitch),
        @"radio"                 : @(NSButtonTypeRadio),
        @"momentaryChange"       : @(NSButtonTypeMomentaryChange),
        @"onOff"                 : @(NSButtonTypeOnOff),
        @"momentaryPushIn"       : @(NSButtonTypeMomentaryPushIn),
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
        @"accelerator"           : @(NSButtonTypeAccelerator),
        @"multiLevelAccelerator" : @(NSButtonTypeMultiLevelAccelerator),
#pragma clang diagnostic pop
    } ;


    BEZEL_STYLES = @{
        @"rounded"           : @(NSBezelStyleRounded),
        @"regularSquare"     : @(NSBezelStyleRegularSquare),
        @"disclosure"        : @(NSBezelStyleDisclosure),
        @"shadowlessSquare"  : @(NSBezelStyleShadowlessSquare),
        @"circular"          : @(NSBezelStyleCircular),
        @"texturedSquare"    : @(NSBezelStyleTexturedSquare),
        @"helpButton"        : @(NSBezelStyleHelpButton),
        @"smallSquare"       : @(NSBezelStyleSmallSquare),
        @"texturedRounded"   : @(NSBezelStyleTexturedRounded),
        @"roundRect"         : @(NSBezelStyleRoundRect),
        @"recessed"          : @(NSBezelStyleRecessed),
        @"roundedDisclosure" : @(NSBezelStyleRoundedDisclosure),
        @"inline"            : @(NSBezelStyleInline),
    } ;

    IMAGE_SCALING_TYPES = @{
        @"proportionallyDown"     : @(NSImageScaleProportionallyDown),
        @"axesIndependently"      : @(NSImageScaleAxesIndependently),
        @"none"                   : @(NSImageScaleNone),
        @"proportionallyUpOrDown" : @(NSImageScaleProportionallyUpOrDown),
    } ;

    IMAGE_POSITIONS = @{
        @"none"     : @(NSNoImage),
        @"only"     : @(NSImageOnly),
        @"left"     : @(NSImageLeft),
        @"right"    : @(NSImageRight),
        @"below"    : @(NSImageBelow),
        @"above"    : @(NSImageAbove),
        @"overlaps" : @(NSImageOverlaps),
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
        @"leading"  : @(NSImageLeading),
        @"trailing" : @(NSImageTrailing),
#pragma clang diagnostic pop
    } ;

    BUTTON_STATES = @{
        @"on"    : @(NSOnState),
        @"off"   : @(NSOffState),
        @"mixed" : @(NSMixedState),
    } ;
}

@interface HSASMGUITKElementButton : NSButton
@property int callbackRef ;
@property int selfRefCount ;
@end

@implementation HSASMGUITKElementButton

- (instancetype)initWithFrame:(NSRect)frameRect {
    @try {
        self = [super initWithFrame:frameRect] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:new - %@", USERDATA_TAG, exception.reason]] ;
        self = nil ;
    }

    if (self) {
        _callbackRef  = LUA_NOREF ;
        _selfRefCount = 0 ;
    }
    return self ;
}

- (void)performCallback:(NSButton *)button {
    NSNumber *state  = @(button.state) ;
    NSArray  *temp   = [BUTTON_STATES allKeysForObject:state];
    NSString *answer = [temp firstObject] ;
    if (!answer) answer = [NSString stringWithFormat:@"unrecognized button state %@", state] ;

    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:button] ;
        [skin pushNSObject:answer] ;
        if (![skin protectedCallAndTraceback:2 nresults:0]) {
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
                                              withObject:@[ button, answer ]
                                           waitUntilDone:YES] ;
            }
        }
    }
}

@end

#pragma mark - Module Functions

/// hs._asm.guitk.element.button.buttonType(type, [frame]) -> buttonObject
/// Constructor
/// Creates a new button element of the specified type for `hs._asm.guitk`.
///
/// Parameters:
///  * `button` - a string specifying the type of button to create. The string must be one of the following:
///    * "momentaryLight"        - When the button is clicked (on state), it appears illuminated. If the button has borders, it may also appear recessed. When the button is released, it returns to its normal (off) state. This type of button is best for simply triggering actions because it doesn’t show its state; it always displays its normal image or title.
///    * "pushOnPushOff"         - When the button is clicked (on state), it appears illuminated. If the button has borders, it may also appear recessed. A second click returns it to its normal (off) state.
///    * "toggle"                - After the first click, the button displays its alternate image or title (on state); a second click returns the button to its normal (off) state.
///    * "switch"                - This style is a variant of "toggle" that has no border and is typically used to represent a checkbox.
///    * "radio"                 - This style is similar to "switch", but it is used to constrain a selection to a single element from several elements.
///    * "momentaryChange"       - When the button is clicked, the alternate (on state) image and alternate title are displayed. Otherwise, the normal (off state) image and title are displayed.
///    * "onOff"                 - The first click highlights the button; a second click returns it to the normal (unhighlighted) state.
///    * "momentaryPushIn"       - When the user clicks the button (on state), the button appears illuminated. Most buttons in macOS, such as Cancel button in many dialogs, are momentary light buttons. If you click one, it highlights briefly, triggers an action, and returns to its original state.
///    * "accelerator"           - On pressure-sensitive systems, such as systems with the Force Touch trackpad, an accelerator button sends repeating actions as pressure changes occur. It stops sending actions when the user releases pressure entirely. Only available in macOS 10.12 and newer.
///    * "multiLevelAccelerator" - A multilevel accelerator button is a variation of a normal accelerator button that allows for a configurable number of stepped pressure levels. As each one is reached, the user receives light tactile feedback and an action is sent. Only available in macOS 10.12 and newer.
///  * `frame` - an optional frame table specifying the position and size of the frame for the button.
///
/// Returns:
///  * a new buttonObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a manager or to a `hs._asm.guitk` window.
///
///  * See also:
///    * [hs._asm.guitk.element.button.buttonWithTitle](#buttonWithTitle)
///    * [hs._asm.guitk.element.button.buttonWithTitleAndImage](#buttonWithTitleAndImage)
///    * [hs._asm.guitk.element.button.buttonWithImage](#buttonWithImage)
///    * [hs._asm.guitk.element.button.checkbox](#checkbox)
///    * [hs._asm.guitk.element.button.radioButton](#radioButton)
static int button_newButtonType(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSString *key = [skin toNSObjectAtIndex:1] ;
    NSNumber *buttonStyle = BUTTON_STYLES[key] ;
    if (buttonStyle) {
        NSRect frameRect = (lua_gettop(L) == 2) ? [skin tableToRectAtIndex:2] : NSZeroRect ;
        HSASMGUITKElementButton *button = [[HSASMGUITKElementButton alloc] initWithFrame:frameRect] ;
        if (button) {
            [button setButtonType:[buttonStyle unsignedIntegerValue]] ;
            button.action     = @selector(performCallback:) ;
            button.target     = button ;
            button.bezelStyle = NSBezelStyleRounded ;
            if (lua_gettop(L) != 2) [button setFrameSize:[button fittingSize]] ;
            [skin pushNSObject:button] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[BUTTON_STYLES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
    }
    return 1 ;
}

/// hs._asm.guitk.element.button.buttonWithTitle(title) -> buttonObject
/// Constructor
/// Creates a new button element of the specified of type "momentaryPushIn" with the specified title for `hs._asm.guitk`.
///
/// Parameters:
///  * `title` - the title which will be displayed in the button
///
/// Returns:
///  * a new buttonObject
///
/// Notes:
///  * This creates a standard macOS push button with the title centered within the button.
///  * The default frame created will be the minimum size necessary to display the button with its title. If you need to adjust the button's size further, do so with the element frame details options available once the button element is attached to a guitk manager (see `hs._asm.guitk.manager`)
///
///  * This constructor uses an NSButton initializer introduced with macOS 10.12; for macOS versions prior to this, this module attempts to mimic the appearance and behavior of the button using the equivalent of [hs._asm.guitk.element.button.buttonType](#buttonType) and the other methods within this module. If you believe that something has been missed in the fallback initializer, please submit an issue to the Hammerspoon github site.
///
///  * See also:
///    * [hs._asm.guitk.element.button.buttonType](#buttonType)
///    * [hs._asm.guitk.element.button.buttonWithTitleAndImage](#buttonWithTitleAndImage)
///    * [hs._asm.guitk.element.button.buttonWithImage](#buttonWithImage)
static int button_newButtonWithTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *title = [skin toNSObjectAtIndex:1] ;

    HSASMGUITKElementButton *button ;
#ifndef TEST_FALLBACKS
    if ([NSButton respondsToSelector:NSSelectorFromString(@"buttonWithTitle:target:action:")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
        button = [HSASMGUITKElementButton buttonWithTitle:title
                                                   target:nil
                                                   action:@selector(performCallback:)] ;
#pragma clang diagnostic pop
    } else {
#endif
        button = [[HSASMGUITKElementButton alloc] initWithFrame:NSZeroRect] ;
        if (button) {
            [button setButtonType:NSButtonTypeMomentaryPushIn] ;
            button.title         = title ;
            button.font          = [NSFont systemFontOfSize:0] ;
            button.action        = @selector(performCallback:) ;
            button.bezelStyle    = NSBezelStyleRounded ;
            button.imagePosition = NSNoImage ;
            [button setFrameSize:[button fittingSize]] ;
        }
#ifndef TEST_FALLBACKS
    }
#endif

    if (button) {
        button.target = button ;
        [skin pushNSObject:button] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.guitk.element.button.buttonWithTitleAndImage(title, image) -> buttonObject
/// Constructor
/// Creates a new button element of the specified of type "momentaryPushIn" with the specified title and image for `hs._asm.guitk`.
///
/// Parameters:
///  * `title` - the title which will be displayed in the button
///  * `image` - the `hs.image` object specifying the image to display preceding the button title.
///
/// Returns:
///  * a new buttonObject
///
/// Notes:
///  * This creates a standard macOS push button with an image at the left and the title centered within the button.
///  * The default frame created will be the minimum size necessary to display the button with its image and title. If you need to adjust the button's size further, do so with the element frame details options available once the button element is attached to a guitk manager (see `hs._asm.guitk.manager`)
///
///  * This constructor uses an NSButton initializer introduced with macOS 10.12; for macOS versions prior to this, this module attempts to mimic the appearance and behavior of the button using the equivalent of [hs._asm.guitk.element.button.buttonType](#buttonType) and the other methods within this module. If you believe that something has been missed in the fallback initializer, please submit an issue to the Hammerspoon github site.
///
///  * See also:
///    * [hs._asm.guitk.element.button.buttonType](#buttonType)
///    * [hs._asm.guitk.element.button.buttonWithTitle](#buttonWithTitle)
///    * [hs._asm.guitk.element.button.buttonWithImage](#buttonWithImage)
static int button_newButtonWithTitleAndImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
    NSString *title = [skin toNSObjectAtIndex:1] ;
    NSImage  *image = [skin toNSObjectAtIndex:2] ;

    HSASMGUITKElementButton *button ;
#ifndef TEST_FALLBACKS
    if ([NSButton respondsToSelector:NSSelectorFromString(@"buttonWithTitle:image:target:action:")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
        button = [HSASMGUITKElementButton buttonWithTitle:title
                                                    image:image
                                                   target:nil
                                                   action:@selector(performCallback:)] ;
#pragma clang diagnostic pop
    } else {
#endif
        button = [[HSASMGUITKElementButton alloc] initWithFrame:NSZeroRect] ;
        if (button) {
            [button setButtonType:NSButtonTypeMomentaryPushIn] ;
            button.title         = title ;
            button.font          = [NSFont systemFontOfSize:0] ;
            button.image         = image ;
            button.action        = @selector(performCallback:) ;
            button.bezelStyle    = NSBezelStyleRounded ;
            button.imagePosition = NSImageLeft ;
            ((NSButtonCell *)button.cell).imageScaling = NSImageScaleProportionallyDown ;
            [button setFrameSize:[button fittingSize]] ;
        }
#ifndef TEST_FALLBACKS
    }
#endif

    if (button) {
        button.target = button ;
        [skin pushNSObject:button] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.guitk.element.button.buttonWithImage(image) -> buttonObject
/// Constructor
/// Creates a new button element of the specified of type "momentaryPushIn" with the specified title for `hs._asm.guitk`.
///
/// Parameters:
///  * `image` - the `hs.image` object specifying the image to display in the button.
///
/// Returns:
///  * a new buttonObject
///
/// Notes:
///  * This creates a standard macOS push button with the image centered within the button.
///  * The default frame created will be the minimum size necessary to display the button with the image. If you need to adjust the button's size further, do so with the element frame details options available once the button element is attached to a guitk manager (see `hs._asm.guitk.manager`)
///
///  * This constructor uses an NSButton initializer introduced with macOS 10.12; for macOS versions prior to this, this module attempts to mimic the appearance and behavior of the button using the equivalent of [hs._asm.guitk.element.button.buttonType](#buttonType) and the other methods within this module. If you believe that something has been missed in the fallback initializer, please submit an issue to the Hammerspoon github site.
///
///  * See also:
///    * [hs._asm.guitk.element.button.buttonType](#buttonType)
///    * [hs._asm.guitk.element.button.buttonWithTitle](#buttonWithTitle)
///    * [hs._asm.guitk.element.button.buttonWithTitleAndImage](#buttonWithTitleAndImage)
static int button_newButtonWithImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, "hs.image", LS_TBREAK] ;
    NSImage  *image = [skin toNSObjectAtIndex:1] ;

    HSASMGUITKElementButton *button ;
#ifndef TEST_FALLBACKS
    if ([NSButton respondsToSelector:NSSelectorFromString(@"buttonWithImage:target:action:")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
        button = [HSASMGUITKElementButton buttonWithImage:image
                                                    target:nil
                                                    action:@selector(performCallback:)] ;
#pragma clang diagnostic pop
    } else {
#endif
        button = [[HSASMGUITKElementButton alloc] initWithFrame:NSZeroRect] ;
        if (button) {
            [button setButtonType:NSButtonTypeMomentaryPushIn] ;
            button.title         = @"Button" ;
            button.font          = [NSFont systemFontOfSize:0] ;
            button.image         = image ;
            button.action        = @selector(performCallback:) ;
            button.bezelStyle    = NSBezelStyleRounded ;
            button.imagePosition = NSImageOnly ;
            ((NSButtonCell *)button.cell).imageScaling = NSImageScaleProportionallyDown ;
            [button setFrameSize:[button fittingSize]] ;
        }
#ifndef TEST_FALLBACKS
    }
#endif

    if (button) {
        button.target = button ;
        [skin pushNSObject:button] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.guitk.element.button.checkbox(title) -> buttonObject
/// Constructor
/// Creates a new checkbox button element of the specified of type "switch" with the specified title for `hs._asm.guitk`.
///
/// Parameters:
///  * `title` - the title which will be displayed next to the checkbox
///
/// Returns:
///  * a new buttonObject
///
/// Notes:
///  * This creates a standard macOS checkbox with the title next to it.
///  * The default frame created will be the minimum size necessary to display the checkbox with its title. If you need to adjust the button's size further, do so with the element frame details options available once the button element is attached to a guitk manager (see `hs._asm.guitk.manager`)
///
///  * This constructor uses an NSButton initializer introduced with macOS 10.12; for macOS versions prior to this, this module attempts to mimic the appearance and behavior of the button using the equivalent of [hs._asm.guitk.element.button.buttonType](#buttonType) and the other methods within this module. If you believe that something has been missed in the fallback initializer, please submit an issue to the Hammerspoon github site.
///
///  * See also [hs._asm.guitk.element.button.buttonType](#buttonType)
static int button_newButtonWithCheckbox(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *title = [skin toNSObjectAtIndex:1] ;

    HSASMGUITKElementButton *button ;
#ifndef TEST_FALLBACKS
    if ([NSButton respondsToSelector:NSSelectorFromString(@"checkboxWithTitle:target:action:")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
       button = [HSASMGUITKElementButton checkboxWithTitle:title
                                                     target:nil
                                                     action:@selector(performCallback:)] ;
#pragma clang diagnostic pop
    } else {
#endif
        button = [[HSASMGUITKElementButton alloc] initWithFrame:NSZeroRect] ;
        if (button) {
            [button setButtonType:NSButtonTypeSwitch] ;
            button.title         = title ;
            button.font          = [NSFont systemFontOfSize:0] ;
            button.action        = @selector(performCallback:) ;
            button.bezelStyle    = NSBezelStyleRegularSquare ;
            button.imagePosition = NSImageLeft ;
            [button setFrameSize:[button fittingSize]] ;
        }
#ifndef TEST_FALLBACKS
    }
#endif

    if (button) {
        button.target = button ;
        [skin pushNSObject:button] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.guitk.element.button.radioButton(title) -> buttonObject
/// Constructor
/// Creates a new radio button element of the specified of type "radio" with the specified title for `hs._asm.guitk`.
///
/// Parameters:
///  * `title` - the title which will be displayed next to the radio button
///
/// Returns:
///  * a new buttonObject
///
/// Notes:
///  * This creates a standard macOS radio button with the title next to it.
///    * Only one radio button in the same manager can be active (selected) at one time; multiple radio buttons in the same manager are treated as a group or set.
///    * To display multiple independent radio button sets in the same window or view (manager), each group must be in a separate `hs._asm.guitk.manager` object and these separate objects may then be assigned as elements to a "parent" manager which is assigned to the `hs._asm.guitk` window; alternatively use [hs._asm.guitk.element.button.radioButtonSet](#radioBUttonSet)
///
///  * The default frame created will be the minimum size necessary to display the checkbox with its title. If you need to adjust the button's size further, do so with the element frame details options available once the button element is attached to a guitk manager (see `hs._asm.guitk.manager`)
///
///  * This constructor uses an NSButton initializer introduced with macOS 10.12; for macOS versions prior to this, this module attempts to mimic the appearance and behavior of the button using the equivalent of [hs._asm.guitk.element.button.buttonType](#buttonType) and the other methods within this module. If you believe that something has been missed in the fallback initializer, please submit an issue to the Hammerspoon github site.
///
///  * See also:
///    * [hs._asm.guitk.element.button.radioButtonSet](#radioBUttonSet)
///    * [hs._asm.guitk.element.button.buttonType](#buttonType)
static int button_newButtonWithRadiobutton(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *title = [skin toNSObjectAtIndex:1] ;

    HSASMGUITKElementButton *button ;
#ifndef TEST_FALLBACKS
    if ([NSButton respondsToSelector:NSSelectorFromString(@"radioButtonWithTitle:target:action:")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
        button = [HSASMGUITKElementButton radioButtonWithTitle:title
                                                         target:nil
                                                         action:@selector(performCallback:)] ;
#pragma clang diagnostic pop
    } else {
#endif
        button = [[HSASMGUITKElementButton alloc] initWithFrame:NSZeroRect] ;
        if (button) {
            [button setButtonType:NSButtonTypeRadio] ;
            button.title         = title ;
            button.font          = [NSFont systemFontOfSize:0] ;
            button.action        = @selector(performCallback:) ;
            button.bezelStyle    = NSBezelStyleRegularSquare ;
            button.imagePosition = NSImageLeft ;
            [button setFrameSize:[button fittingSize]] ;
        }
#ifndef TEST_FALLBACKS
    }
#endif

    if (button) {
        button.target = button ;
        [skin pushNSObject:button] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

/// hs._asm.guitk.element.button:callback([fn | nil]) -> buttonObject | fn | nil
/// Method
/// Get or set the callback function which will be invoked whenever the user clicks on the button element.
///
/// Parameters:
///  * `fn` - a lua function, or explicit nil to remove, which will be invoked when the clicks on the button.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * The button callback will receive two arguments and should return none. The arguments will be the buttonObject userdata and the new button state -- see [hs._asm.guitk.element.button:state](#state)
static int button_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementButton *obj = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            obj.callbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (obj.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:obj.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

/// hs._asm.guitk.element.button:title([title]) -> buttonObject | string | hs.styledtext object
/// Method
/// Get or set the title displayed for the button
///
/// Parameters:
///  * `title` - an optional string or `hs.styledtext` object specifying the title to set for the button.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * The button constructors which allow specifying a title require a string; if you wish to change to a styled text object, you'll need to invoke this method on the new object after it is constructed.
static int button_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSString *title = button.title ;
        [skin pushNSObject:([title isEqualToString:@""] ? button.attributedTitle : title)] ;
    } else {
        if (lua_type(L, 2) == LUA_TUSERDATA) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.styledtext", LS_TBREAK] ;
            button.title = @"" ;
            button.attributedTitle = [skin toNSObjectAtIndex:2] ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
            button.title = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.guitk.element.button:alternateTitle([title]) -> buttonObject | string | hs.styledtext object
/// Method
/// Get or set the alternate title displayed by button types which support this
///
/// Parameters:
///  * `title` - an optional string or `hs.styledtext` object specifying the alternate title for the button.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * For buttons which change their appearance based upon their state, this is the title which will be displayed when the button is in its "on" state.
///  * Observation shows that the alternateTitle value is used by the following button types:
///    * "toggle"          - the button will alternate between the title and the alternateTitle
///    * "momentaryChange" - if the button is not bordered, the alternate title will be displayed while the user is clicking on the button and will revert back to the title once the user has released the mouse button.
///    * "switch"          - when the checkbox is checked, it will display its alternateTitle, if one has been assigned
///    * "radio"           - when the radio button is selected, it will display its alternateTitle, if one has been assigned
///  * Other button types have not been observed to use this attribute; if you believe you have discovered something we have missed here, please submit an issue to the Hamemrspoon github web site.
static int button_alternateTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSString *alternateTitle = button.alternateTitle ;
        [skin pushNSObject:(([alternateTitle isEqualToString:@""]) ? [button.attributedAlternateTitle string] : alternateTitle)] ;
    } else {
        if (lua_type(L, 2) == LUA_TUSERDATA) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.styledtext", LS_TBREAK] ;
            button.alternateTitle = @"" ;
            button.attributedAlternateTitle = [skin toNSObjectAtIndex:2] ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
            button.alternateTitle = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.guitk.element.button:bordered([state]) -> buttonObject | boolean
/// Method
/// Get or set whether a border is displayed around the button.
///
/// Parameters:
///  * `state` - an optional boolean specifying whether the button should display a border around the button area or not.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * setting this to true for the "switch" or "radio" button types will prevent the alternate image, if defined, from being displayed.
static int button_bordered(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, button.bordered) ;
    } else {
        button.bordered = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.guitk.element.button:transparent([state]) -> buttonObject | boolean
/// Method
/// Get or set whether the button's background is transparent.
///
/// Parameters:
///  * `state` - an optional boolean specifying whether the button's background is transparent.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
static int button_transparent(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, button.transparent) ;
    } else {
        button.transparent = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.guitk.element.button:borderOnHover([state]) -> buttonObject | boolean
/// Method
/// Get or set whether the button's border is toggled when the mouse hovers over the button
///
/// Parameters:
///  * `state` - an optional boolean specifying whether the button's border is toggled when the mouse hovers over the button
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * Has no effect on buttons of type "switch" or "radio"
///  * Changing this value will not affect whether or not the border is currently being displayed until the cursor actually hovers over the button or the button is clicked by the user. To keep the visual display in sync, make sure to set this value before displaying the guitk (e.g. `hs._asm.guitk:show()`) or set the border manually to the initial state you wish with [hs._asm.guitk.element.button:bordered](#bordered).
static int button_borderOnHover(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, button.showsBorderOnlyWhileMouseInside) ;
    } else {
        button.showsBorderOnlyWhileMouseInside = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int button_allowsMixedState(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, button.allowsMixedState) ;
    } else {
        button.allowsMixedState = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int button_bezelStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *bezelStyle = @(button.bezelStyle) ;
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
            button.bezelStyle = [bezelStyle unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[BEZEL_STYLES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int button_imagePosition(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *imagePosition = @(button.imagePosition) ;
        NSArray *temp = [IMAGE_POSITIONS allKeysForObject:imagePosition];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized image position %@ -- notify developers", USERDATA_TAG, imagePosition]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *imagePosition = IMAGE_POSITIONS[key] ;
        if (imagePosition) {
            button.imagePosition = [imagePosition unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[IMAGE_POSITIONS allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int button_imageScaling(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *imageScaling = @(((NSButtonCell *)button.cell).imageScaling) ;
        NSArray *temp = [IMAGE_SCALING_TYPES allKeysForObject:imageScaling];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized image scaling %@ -- notify developers", USERDATA_TAG, imageScaling]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *imageScaling = IMAGE_SCALING_TYPES[key] ;
        if (imageScaling) {
            ((NSButtonCell *)button.cell).imageScaling = [imageScaling unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[IMAGE_SCALING_TYPES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int button_image(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:button.image] ;
    } else {
        if (lua_isnil(L, 2) && lua_gettop(L) == 2) {
            button.image = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            button.image = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int button_sound(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:button.sound] ;
    } else {
        if (lua_isnil(L, 2) && lua_gettop(L) == 2) {
            button.sound = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.sound", LS_TBREAK] ;
            button.sound = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.guitk.element.button:alternateImage([image]) -> buttonObject | hs.image object | nil
/// Method
/// Get or set the alternate image displayed by button types which support this
///
/// Parameters:
///  * `image` - an optional hs.image object, or explicit nil to remove, specifying the alternate image for the button.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * For buttons which change their appearance based upon their state, this is the image which will be displayed when the button is in its "on" state.
///  * Observation shows that the alternateTitle value is used by the following button types:
///    * "toggle"          - the button will alternate between the image and the alternateImage
///    * "momentaryChange" - if the button is not bordered, the alternate image will be displayed while the user is clicking on the button and will revert back to the image once the user has released the mouse button.///    * "switch"               - when the checkbox is checked, it will display its alternateImage as the checked box, if one has been assigned
///    * "radio"           - when the radio button is selected, it will display its alternateImage as the filled in radio button, if one has been assigned
///  * Other button types have not been observed to use this attribute; if you believe you have discovered something we have missed here, please submit an issue to the Hamemrspoon github web site.
static int button_alternateImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:button.alternateImage] ;
    } else {
        if (lua_isnil(L, 2) && lua_gettop(L) == 2) {
            button.alternateImage = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            button.alternateImage = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int button_state(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *state = @(button.state) ;
        NSArray *temp = [BUTTON_STATES allKeysForObject:state];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized button state %@ -- notify developers", USERDATA_TAG, state]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        if ([key isEqualToString:@"next"]) {
            [button setNextState] ;
        } else {
            NSNumber *state = BUTTON_STATES[key] ;
            if (state) {
                button.state = [state integerValue] ;
            } else {
                return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@, or next", [[BUTTON_STATES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
            }
            lua_pushvalue(L, 1) ;
        }
    }
    return 1 ;
}

static int button_highlighted(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, button.highlighted) ;
    } else {
        [button highlight:(BOOL)lua_toboolean(L, 2)] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int button_value(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if ((lua_type(L, 2) == LUA_TBOOLEAN) && lua_toboolean(L, 2)) {
        lua_pushnumber(L, [button doubleValue]) ;
    } else {
        lua_pushinteger(L, [button integerValue]) ;
    }
    return 1 ;
}

static int button_maxAcceleratorLevel(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if ([button respondsToSelector:NSSelectorFromString(@"maxAcceleratorLevel")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
            lua_pushinteger(L, button.maxAcceleratorLevel) ;
#pragma clang diagnostic pop
        } else {
            lua_pushinteger(L, 1) ;
        }
    } else {
        if ([button respondsToSelector:NSSelectorFromString(@"setMaxAcceleratorLevel:")]) {
            lua_Integer level = lua_tointeger(L, 2) ;
            if (level < 1 || level > 5) {
                return luaL_argerror(L, 2, "must be an integer between 1 and 5 inclusive") ;
            }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
            button.maxAcceleratorLevel = level ;
#pragma clang diagnostic pop
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:maxAcceleratorLevel only available in 10.10.3 and newer", USERDATA_TAG]] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static float fclamp(float d, float min, float max) {
  const float t = d < min ? min : d;
  return t > max ? max : t;
}

static int button_periodicDelay(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        float delay    = 0.0f ;
        float interval = 0.0f ;
        [button getPeriodicDelay:&delay interval:&interval] ;
        lua_newtable(L) ;
        lua_pushnumber(L, (lua_Number)delay) ;    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushnumber(L, (lua_Number)interval) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    } else {
        float delay    = 0.4f ;
        float interval = 0.075f ;
        if (lua_geti(L, 2, 1) == LUA_TNUMBER) {
            delay = fclamp((float)lua_tonumber(L, -1), 0.0, 60.0) ;
        } else if (lua_type(L, -1) != LUA_TNIL) {
            return luaL_argerror(L, 2, "expected number for delay at index position 1") ;
        }
        lua_pop(L, 1) ;
        if (lua_geti(L, 2, 2) == LUA_TNUMBER) {
            interval = fclamp((float)lua_tonumber(L, -1), 0.0, 60.0) ;
        } else if (lua_type(L, -1) != LUA_TNIL) {
            return luaL_argerror(L, 2, "expected number for interval at index position 2") ;
        }
        lua_pop(L, 1) ;
        [button setPeriodicDelay:delay interval:interval] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSASMGUITKElementButton(lua_State *L, id obj) {
    HSASMGUITKElementButton *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSASMGUITKElementButton *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toHSASMGUITKElementButtonFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMGUITKElementButton *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSASMGUITKElementButton, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMGUITKElementButton *obj = [skin luaObjectAtIndex:1 toClass:"HSASMGUITKElementButton"] ;
    NSString *title = NSStringFromRect(obj.frame) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSASMGUITKElementButton *obj1 = [skin luaObjectAtIndex:1 toClass:"HSASMGUITKElementButton"] ;
        HSASMGUITKElementButton *obj2 = [skin luaObjectAtIndex:2 toClass:"HSASMGUITKElementButton"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSASMGUITKElementButton *obj = get_objectFromUserdata(__bridge_transfer HSASMGUITKElementButton, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin shared] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
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
    {"callback",            button_callback},
    {"title",               button_title},
    {"alternateTitle",      button_alternateTitle},
    {"bordered",            button_bordered},
    {"transparent",         button_transparent},
    {"borderOnHover",       button_borderOnHover},
    {"allowsMixedState",    button_allowsMixedState},
    {"bezelStyle",          button_bezelStyle},
    {"image",               button_image},
    {"alternateImage",      button_alternateImage},
    {"imagePosition",       button_imagePosition},
    {"imageScaling",        button_imageScaling},
    {"state",               button_state},
    {"highlighted",         button_highlighted},
    {"sound",               button_sound},
    {"value",               button_value},
    {"maxAcceleratorLevel", button_maxAcceleratorLevel},
    {"periodicDelay",       button_periodicDelay},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"buttonType",              button_newButtonType},
    {"buttonWithTitle",         button_newButtonWithTitle},
    {"buttonWithTitleAndImage", button_newButtonWithTitleAndImage},
    {"buttonWithImage",         button_newButtonWithImage},
    {"checkbox",                button_newButtonWithCheckbox},
    {"radioButton",             button_newButtonWithRadiobutton},
    {NULL,                      NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_guitk_element_button(lua_State* L) {
    defineInternalDictionaryies() ;

    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSASMGUITKElementButton         forClass:"HSASMGUITKElementButton"];
    [skin registerLuaObjectHelper:toHSASMGUITKElementButtonFromLua forClass:"HSASMGUITKElementButton"
                                                        withUserdataMapping:USERDATA_TAG];

    // allow hs._asm.guitk.manager:elementProperties to get/set these
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"title",
        @"alternateTitle",
        @"bordered",
        @"transparent",
        @"borderOnHover",
        @"allowsMixedState",
        @"bezelStyle",
        @"imagePosition",
        @"imageScaling",
        @"image",
        @"sound",
        @"alternateImage",
        @"state",
        @"periodicDelay",
        @"highlighted",
        @"callback",
    ]] ;
    if ([NSButton instancesRespondToSelector:NSSelectorFromString(@"maxAcceleratorLevel")]) {
        lua_pushstring(L, "maxAcceleratorLevel") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    lua_setfield(L, -2, "_propertyList") ;
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ;
//     lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritView") ;
    lua_pop(L, 1) ;

    return 1;
}
