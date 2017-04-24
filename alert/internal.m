@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.alert" ;
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

// this is all we need of the actual class header in MJWindowController.h
@interface MJConsoleWindowController : NSWindowController
+ (instancetype)singleton;
@end

@interface HSAlert : NSObject <NSAlertDelegate>
@property int      helpCallback ;
@property int      resultCallback ;
@property BOOL     autoActivate ;
@property BOOL     autoHideConsole ;
@property BOOL     critical ;
@property NSString *messageText ;
@property NSString *informativeText ;
@property NSImage  *icon ;
@property NSArray  *buttons ;
@end

@implementation HSAlert

- (instancetype)init {
    self = [super init] ;
    if (self) {
        _helpCallback    = LUA_NOREF ;
        _resultCallback  = LUA_NOREF ;
        _critical        = NO ;
        _messageText     = @"Alert" ;
        _informativeText = @"" ;
        _icon            = [NSApp applicationIconImage] ;
        _buttons         = [NSArray arrayWithObject:@"OK"] ;
        _autoActivate    = YES ;
        _autoHideConsole = NO ;
    }
    return self ;
}

- (BOOL)alertShowHelp:(__unused NSAlert *)alert {
    if (_helpCallback != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            [skin pushLuaRef:refTable ref:self->_helpCallback] ;
            [skin pushNSObject:self] ;
            if (![skin protectedCallAndTraceback:1 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s:helpCallback error - %@", USERDATA_TAG, [skin toNSObjectAtIndex:-1]]] ;
                lua_pop(skin.L, 1) ;
            }
        }) ;
    }
    return YES ;
}

- (NSString *)runModalAlert {
    NSAlert *alert = [[NSAlert alloc] init] ;
    alert.delegate = self ;
    if (_helpCallback != LUA_NOREF) alert.showsHelp = YES ;
    if (_critical) alert.alertStyle = NSAlertStyleCritical ;
    alert.messageText     = _messageText ;
    alert.informativeText = _informativeText ;
    alert.icon            = _icon ;
    for(NSString *item in [_buttons reverseObjectEnumerator]) [alert addButtonWithTitle:item] ;

    MJConsoleWindowController *console = [MJConsoleWindowController singleton] ;
    BOOL consoleWasShowing = console.window.visible ;
    NSRunningApplication* runningApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (_autoHideConsole && consoleWasShowing) [console.window close] ;
    if (_autoActivate) [[NSRunningApplication currentApplication] activateWithOptions:NSApplicationActivateIgnoringOtherApps] ;

    NSModalResponse response = [alert runModal] ;

    if (_autoActivate) [runningApp activateWithOptions:NSApplicationActivateIgnoringOtherApps] ;
    if (_autoHideConsole && consoleWasShowing) [console showWindow:nil] ;

    NSString *result = @"<no-response>" ;

//     should not happen here, but I hope to expand/replicate this for a sheet based non-modal version at some point
    if (response == NSModalResponseStop) {
        result = @"<NSModalResponseStop>" ;
    } else if (response == NSModalResponseAbort) {
        result = @"<NSModalResponseAbort>" ;
    } else if (response == NSModalResponseContinue) {
        result = @"<NSModalResponseContinue>" ;
    } else {
        NSUInteger index = _buttons.count - (NSUInteger)(response - 999) ;
        result = _buttons[index] ;
    }

    alert.delegate = nil ;
    return result ;
}

@end

#pragma mark - Module Functions

/// hs._asm.alert.new([critical]) -> alertObject
/// Constructor
/// Creates a new alert object.
///
/// Parameters:
///  * critical - an optional boolean, default false, specifying that the alert represents a critical notification as opposed to an informational one or a warning.
///
/// Returns:
///  * the alert object
///
/// Notes:
///  * A critical alert will show a caution icon with a smaller version of the alert's icon -- see [hs._asm.alert:icon](#icon) -- as a badge in the lower right corner.
///  * Apple's current UI guidelines makes no visual distinction between informational or warning alerts -- this module implements the alert as critical or not critical because of this.
static int hsalert_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSAlert *obj = [[HSAlert alloc] init] ;
    obj.critical = (lua_gettop(L) == 1) ? (BOOL)lua_toboolean(L, 1) : NO ;
    [skin pushNSObject:obj] ;
    return 1 ;
}

#pragma mark - Module Methods

/// hs._asm.alert:helpCallback(fn | nil) -> alertObject
/// Method
/// Set or remove a callback function which should be invoked if the user clicks on the help icon of the alert.
///
/// Parameters:
///  * fn - a function to register as the callback when the user clicks on the help icon of the alert, or an explicit nil to remove any existing callback.
///
/// Returns:
///  * the alert object
///
/// Notes:
///  * If no help callback is set, the help icon will not be displayed in the alert dialog.
///  * While the alert is being displayed with [hs._asm.alert:modal](#modal), Hammerspoon activity is blocked; however this callback function will be executed because it is within the same thread as the modal alert itself.  Be aware however that any action initiated by this callback function which relies on injecting events into the Hammerspoon application run loop (timers, notification watchers, etc.) will be delayed until the alert is dismissed.
static int hsalert_helpCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    HSAlert *obj = [skin toNSObjectAtIndex:1] ;
    obj.helpCallback = [skin luaUnref:refTable ref:obj.helpCallback] ;
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        obj.helpCallback = [skin luaRef:refTable atIndex:2] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.alert:information([text]) -> current value | alertObject
/// Method
/// Get or set the information text field of the alert.  This text is displayed in the main body of the alert.
///
/// Parameters:
///  * text - an optional string specifying the text to be displayed in the main body of the alert. Defaults to the empty string, "".
///
/// Returns:
///  * if an argument is provided, returns the alert object; otherwise returns the current value
///
/// Notes:
///  * The information text is displayed in the main body of the alert and is not in bold.  It can be multiple lines in length, and you can use `\\n` to force an explicit line break within the text to be displayed.
static int hsalert_informativeText(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSAlert *obj = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSObject:obj.informativeText] ;
    } else {
        obj.informativeText = [skin toNSObjectAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.alert:message([text]) -> current value | alertObject
/// Method
/// Get or set the message text field of the alert.  This text is displayed at the top of the alert like a title for the alert.
///
/// Parameters:
///  * text - an optional string specifying the text to be displayed at the top of the alert. Defaults to "Alert".
///
/// Returns:
///  * if an argument is provided, returns the alert object; otherwise returns the current value
///
/// Notes:
///  * The message text is displayed at the top of the alert and is in bold.  It can be multiple lines in length, and you can use `\\n` to force an explicit line break within the text to be displayed.
static int hsalert_messageText(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSAlert *obj = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSObject:obj.messageText] ;
    } else {
        obj.messageText = [skin toNSObjectAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.alert:icon([image]) -> current value | alertObject
/// Method
/// Get or set the message icon for the alert.
///
/// Parameters:
///  * image - an optional `hs.image` object specifying the image to use as the icon at the left of the alert dialog.  Defaults to the Hammerspoon application icon.  You can revert this to the Hammerspoon application icon by specifying an explicit nil as the image argument.
///
/// Returns:
///  * if an argument is provided, returns the alert object; otherwise returns the current value
///
/// Notes:
///  * If the alert is a critical one as specified when created with [hs._asm.alert.new](#new), this is the image which appears as the small badge at the lower right of the caution icon.
static int hsalert_icon(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSAlert *obj = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSObject:obj.icon] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            obj.icon = [NSApp applicationIconImage] ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            obj.icon = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.alert:resultCallback(fn | nil) -> alertObject
/// Method
/// *** Currently does nothing *** : Get or set a callback to be invoked with the result of a non-modal alert when the user dismisses the dialog.
/// Parameters:
///  * fn - a function to register as the callback when the user clicks on a button to dismiss the alert, or an explicit nil to remove any existing callback.
///
/// Returns:
///  * the alert object
///
/// Notes:
///  * This method is included for testing during development while a non-modal method of displaying the alerts is researched.  At present, using this method to set a callback has no affect since such a callback is never actually invoked.
static int hsalert_resultCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    HSAlert *obj = [skin toNSObjectAtIndex:1] ;
    obj.helpCallback = [skin luaUnref:refTable ref:obj.resultCallback] ;
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        obj.resultCallback = [skin luaRef:refTable atIndex:2] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.alert:modal() -> result
/// Method
/// Displays the alert as a modal dialog, pausing Hammerspoon activity until the user makes their selection from the buttons provided.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the string title of the button the user clicked on to dismiss the alert.
///
/// Notes:
///  * as described in the [hs._asm.alert:buttons](#buttons) method, some buttons may have keyboard equivalents for clicking on them -- the string returned is identical and we have no way to distinguish *how* they selected a button, just which button they did select.
static int hsalert_runModal(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSAlert *obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[obj runModalAlert]] ;
    return 1 ;
}

/// hs._asm.alert:autoActivate([state]) -> current value | alertObject
/// Method
/// Get or set whether or not the alert should automatically grab focus when it is displayed with [hs._asm.alert:modal](#modal).
///
/// Parameters:
///  * state - an optional boolean, default true, indicathing whether the alert dialog should become the focused user interface element when it is displayed.
///
/// Returns:
///  * if an argument is provided, returns the alert object; otherwise returns the current value
///
/// Notes:
///  * When set to true, the application which was frontmost right before the alert is displayed will be reactivated when the alert is dismissed.
///  * When set to false then the user must click on the dialog before it will respond to any key equivalents which may be in effect for the alert -- see [hs._asm.alert:buttons](#buttons).
static int hsalert_autoActivate(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSAlert *obj = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, obj.autoActivate) ;
    } else {
        obj.autoActivate = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.alert:autoHideConsole([state]) -> current value | alertObject
/// Method
/// Get or set whether or not the Hammerspoon console should be hidden while the alert is visible.
///
/// Parameters:
///  * state - an optional boolean, default false, indicathing whether the Hammerspoon console, should be hidden when the alert is visible.  If this is set to true and the console is visible, it will be hidden and then re-opened when the alert is dismissed.
///
/// Returns:
///  * if an argument is provided, returns the alert object; otherwise returns the current value
///
/// Notes:
///  * Because responding to an alert requires Hammerspoon to become the focused application, the Hammerspoon console may be brought forward if it is visible when you display an alert. When used in conjunction with [hs._asm.alert:autoActivate(true)[#autoActivate], this method may be used to minimize the visual distraction of this.
static int hsalert_autoHideConsole(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSAlert *obj = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, obj.autoHideConsole) ;
    } else {
        obj.autoHideConsole = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.alert:buttons([list]) -> current value | alertObject
/// Method
/// Get or set the list of buttons which are displayed by the alert as options for the user to choose from.
///
/// Parameters:
///  * an optional table containing a list of one or more strings which will be the titles on the buttons provided in the alert.  Defaults to `{ "OK" }`.
///
/// Returns:
///  * if an argument is provided, returns the alert object; otherwise returns the current value
///
/// Notes:
///  * The list of buttons will be displayed from right to left in the order in which they appear in this list.
///  * The *last* button title specifies the default for the alert and will be selected if the user hits the Return key rather than clicking on another button.
///  * If a button (other than the *last* one) is named "Cancel", then the user may press the Escape key to choose it instead of clicking on it.
///  * If a button (other than the *last* one) is named "Don't Save", then the user may press Command-D to choose it instead of clicking on it.
///
/// * These key equivalents are built in. At preset there is no way to override them or set your own, though adding this is being considered.
/// * Programmers note: This ordering of the button titles was chosen to more accurately represent their visual order and is opposite from the way buttons are added internally to the NSAlert object.
static int hsalert_buttons(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSAlert *obj = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSObject:obj.buttons] ;
    } else {
        NSArray *alertButtons = [skin toNSObjectAtIndex:2] ;
        BOOL isGoodTable = YES ;
        if ([alertButtons isKindOfClass:[NSArray class]]) {
            if ([alertButtons count] == 0) {
                isGoodTable = NO ;
            } else {
                for (NSString *item in alertButtons) {
                    if (![item isKindOfClass:[NSString class]]) {
                        isGoodTable = NO ;
                        break ;
                    }
                }
            }
        } else {
            isGoodTable = NO ;
        }
        if (isGoodTable) {
            obj.buttons = alertButtons ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "expected an array of one or more strings") ;
        }
    }
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSAlert(lua_State *L, id obj) {
    HSAlert *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(HSAlert *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toHSAlertFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSAlert *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSAlert, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSAlert *obj = [skin luaObjectAtIndex:1 toClass:"HSAlert"] ;
    NSString *title = obj.messageText ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSAlert *obj1 = [skin luaObjectAtIndex:1 toClass:"HSAlert"] ;
        HSAlert *obj2 = [skin luaObjectAtIndex:2 toClass:"HSAlert"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSAlert *obj = get_objectFromUserdata(__bridge_transfer HSAlert, L, 1, USERDATA_TAG) ;
    if (obj) {
        LuaSkin *skin = [LuaSkin shared] ;
        obj.resultCallback = [skin luaUnref:refTable ref:obj.resultCallback] ;
        obj.helpCallback   = [skin luaUnref:refTable ref:obj.helpCallback] ;
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
    {"helpCallback",    hsalert_helpCallback},
    {"message",         hsalert_messageText},
    {"information",     hsalert_informativeText},
    {"icon",            hsalert_icon},
    {"resultCallback",  hsalert_resultCallback},
    {"modal",           hsalert_runModal},
    {"buttons",         hsalert_buttons},
    {"autoActivate",    hsalert_autoActivate},
    {"autoHideConsole", hsalert_autoHideConsole},

    {"__tostring",      userdata_tostring},
    {"__eq",            userdata_eq},
    {"__gc",            userdata_gc},
    {NULL,              NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", hsalert_new},
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_alert_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSAlert         forClass:"HSAlert"];
    [skin registerLuaObjectHelper:toHSAlertFromLua forClass:"HSAlert"
                                             withUserdataMapping:USERDATA_TAG];

    return 1;
}
