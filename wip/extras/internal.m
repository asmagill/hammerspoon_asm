#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

/// hs._asm.extras.NSLog(luavalue)
/// Function
/// Send a representation of the lua value passed in to the Console application via NSLog.
static int extras_nslog(__unused lua_State* L) {
    id val = [[LuaSkin shared] toNSObjectFromIndex:1] ;
    NSLog(@"%@", val);
    return 0;
}

/// hs._asm.extras.listWindows([includeDesktopElements])
/// Function
/// Returns an array containing information about all available windows, even those ignored by hs.window
///
/// Parameters:
///  * includeDesktopElements - defaults to false; if true, includes windows which that are elements of the desktop, including the background picture and desktop icons.
///
/// Returns:
///  * An array of windows in the order in which CGWindowListCopyWindowInfo returns them.  Each window entry is a table that contains the information returned by the CoreGraphics CGWindowListCopyWindowInfo function for that window.
///
/// Notes:
///  * The companion function, hs._asm.extras.windowsByName, groups windows a little more usefully and utilizes metatables to allow an easier browsing experience of the data from the console.
///  * The results of this function are of dubious value at the moment... while it should be possible to determine what windows are on other spaces (though probably not which space -- just "this space" or "not this space") there is at present no way to positively distinguish "real" windows from "virtual" windows used for internal application purposes.
///  * This may also provide a mechanism for determine when Mission Control or other System displays are active, but this is untested at present.
static int listWindows(lua_State *L) {
//     CFArrayRef windowInfosRef = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID) ;

    CFArrayRef windowInfosRef = CGWindowListCopyWindowInfo(kCGWindowListOptionAll | (lua_toboolean(L,1) ? 0 : kCGWindowListExcludeDesktopElements), kCGNullWindowID) ;
    // CGWindowID(0) is equal to kCGNullWindowID
    NSArray *windowList = CFBridgingRelease(windowInfosRef) ;  // same as __bridge_transfer
    [[LuaSkin shared] pushNSObject:windowList] ;
    return 1 ;
}

static int extras_defaults(__unused lua_State* L) {
    NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] ;
    [[LuaSkin shared] pushNSObject:defaults] ;
    return 1;
}

// A crash waiting to happen, but proof of concept that a true "bridge" might one day be
// possible... with a crap load of work...  Also check out NSInvocation.  Will need a way to store
// results and return userdata for most things...
//
// static int extras_bridge(lua_State* L) {
//     NSString *className    = [NSString stringWithUTF8String:luaL_checkstring(L, 1)] ;
//     NSString *selectorName = [NSString stringWithUTF8String:luaL_checkstring(L, 2)] ;
//
//     if (NSClassFromString(className)) {
//         if ([NSClassFromString(className) respondsToSelector:NSSelectorFromString(selectorName)]) {
//             lua_pushNSObject(L, [NSClassFromString(className) performSelector:NSSelectorFromString(selectorName)]) ;
//         } else {
//             printToConsole(L, (char *)[[NSString stringWithFormat:@"Class %@ does not respond to selector %@", className, selectorName] UTF8String]) ;
//             lua_pushnil(L) ;
//         }
//     } else {
//         printToConsole(L, (char *)[[NSString stringWithFormat:@"Class %@ is not loaded or doesn't exist", className] UTF8String]) ;
//         lua_pushnil(L) ;
//     }
//
//     return 1 ;
// }

@interface MJConsoleWindowController : NSWindowController

+ (instancetype) singleton;
- (void) setup;

@end

static int console_behavior(lua_State* L) {
    NSWindow *console = [[MJConsoleWindowController singleton] window] ;

    @try {
        if (lua_type(L, 1) != LUA_TNONE)
            [console setCollectionBehavior: lua_tonumber(L, 1) ] ;
    }
    @catch ( NSException *theException ) {
        showError(L, (char *)[[NSString stringWithFormat:@"%@: %@", theException.name, theException.reason] UTF8String]);
        return 0 ;
    }

    if (lua_type(L, 1) != LUA_TNONE)
        [console setCollectionBehavior: lua_tonumber(L, 1) ] ;
    lua_pushinteger(L, [console collectionBehavior]) ;
    return 1 ;
}

/// hs._asm.extras.userDataToString(userdata) -> string
/// Function
/// Returns the userdata object as a binary string. Usually userdata is pretty boring -- containing c pointers, etc.  However, for some of the more complex userdata blobs for callbacks and such this can be useful with hs._asm.extras.hexdump for debugging to see what parts of the structure are actually getting set, etc.
static int ud_tostring (lua_State *L) {
    void *data = lua_touserdata(L,1);
    size_t sz;
    if (data == NULL) {
        lua_pushnil(L);
        lua_pushstring(L,"not a userdata type");
        return 2;
    } else {
        sz = lua_rawlen(L,1);
        lua_pushlstring(L,data,sz);
        return 1;
    }
}

#define get_app(L, idx) *((AXUIElementRef*)luaL_checkudata(L, idx, "hs.application"))

// Internal helper function for getMenuArray
static void _buildMenuArray(lua_State* L, AXUIElementRef app, AXUIElementRef menuItem) {

    CFTypeRef cf_title ; NSString* title ;
    AXError error = AXUIElementCopyAttributeValue(menuItem, kAXTitleAttribute, &cf_title);
    if (error == kAXErrorAttributeUnsupported) {
        title = @"-- title unsupported --" ; // Special case, mostly for wrapper objects
    } else if (error) {
        title = [NSString stringWithFormat:@"-- title error: AXError %d --", error] ;
    } else {
        title = (__bridge_transfer NSString *)cf_title;
   }
    lua_pushstring(L, [title UTF8String]) ; lua_setfield(L, -2, "title") ;

    CFIndex count = -1;
    error = AXUIElementGetAttributeValueCount(menuItem, kAXChildrenAttribute, &count);
    if (error) {
        lua_pushfstring(L, "unable to get child count: AXError %d", error) ; lua_setfield(L, -2, "error") ;
        count = -1 ; // just to make sure it didn't get some funky value
    }

    if (count > 0) {
        CFArrayRef cf_children;
        error = AXUIElementCopyAttributeValues(menuItem, kAXChildrenAttribute, 0, count, &cf_children);
        if (error) {
            lua_pushfstring(L, "unable to get children: AXError %d", error) ; lua_setfield(L, -2, "error") ;
        } else {
            NSMutableArray *toCheck = [[NSMutableArray alloc] init];
            [toCheck addObjectsFromArray:(__bridge NSArray *)cf_children];

            lua_newtable(L) ;
            for(unsigned int i = 0 ; i < [toCheck count] ; i++) {
                AXUIElementRef element = (__bridge AXUIElementRef)[toCheck objectAtIndex: i] ;
                lua_newtable(L) ;
                _buildMenuArray(L, app, element) ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
                CFRelease(element) ;
            }

            if (luaL_len(L, -1) == 0) lua_pop(L,1) ; else lua_setfield(L, -2, "items") ;
        }
    } else if (count == 0) {
        CFTypeRef enabled; error = AXUIElementCopyAttributeValue(menuItem, kAXEnabledAttribute, &enabled);
        lua_pushboolean(L, [(__bridge NSNumber *)enabled boolValue]); lua_setfield(L, -2, "enabled");

        CFTypeRef markchar; error = AXUIElementCopyAttributeValue(menuItem, kAXMenuItemMarkCharAttribute, &markchar);
        BOOL marked; if (error == kAXErrorNoValue) { marked = false; } else { marked = true; }
        lua_pushboolean(L, marked); lua_setfield(L, -2, "marked");
    }

    return ;
}

/// hs._asm.extras.getMenuArray(application) -> array
/// Function
/// Returns an array containing the menu items for the specified application.
///
/// Notes:
///  * Really amazingly in-progress/pre-alpha/don't-use-unless-you-like-broken-things/it's-your-fault-not-mine.  Seriously, I've lost my train of thought and will get back to this... or something similar... There are interesting things lurking in the AXUIElement area, but I don't have time to figure them out right now...
static int getMenuArray(lua_State *L) {
    AXUIElementRef app = get_app(L, 1);
    AXUIElementRef menuBar ;
    AXError error = AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute, (CFTypeRef *)&menuBar) ;
    if (error) { return luaL_error(L, "Unable to retrieve menuBar object: AXError %d", error) ; }
    lua_settop(L, 0) ;
    lua_newtable(L) ;
    _buildMenuArray(L, app, menuBar) ;
    CFRelease(menuBar) ;
    return 1 ;
}

// // // // // END: hs.application candidate

// // Not sure what I'll do with this now... just got lua/hs.eventtap version working.  Args are different
// // (I like these better now), but that's just a simple code change when I'm not tired...


/// _asm.extras.doSpacesKey([key],[win],[mod]) -> None
/// Function
/// Preforms Mission Control key sequences (and clicks, when a window or point is provided) for spaces.
///
/// Parameters:
///  * key - the string representing the keyboard character which is to be "pressed" -- defaults to the right arrow ("right") -- see hs.keycodes.map for other keys.
///  * win - a hs.window object or point table indicating where the mouse pointer and mouse click should occur for the trigger. Defaults to no window.
///  * mod - a table containing the keyboard modifiers to be "pressed".  Defaults to { "ctrl" }. The following values are allowed in this table:
///   * cmd
///   * alt
///   * shift
///   * ctrl
///   * fn
///
/// Notes:
///  * The only semi-reliable way to move windows around in Spaces is to take advantage of the fact that we can simulate the keypresses which are defined for Mission Control and Spaces in the Keyboard Shortcuts System Preferences Panel.  That is what this function is intended for.  It will have no effect if you disabled these shortcuts.  By default they are defined as:
///    * Ctrl-# - jump to a specific space, or if a window title bar is being clicked on when pressed, move the window to the specific space.
///    * Ctrl-Right Arrow - move (or move a window) one space to the right.
///    * Ctrl-Left Arrow - move (or move a window) one space to the left.
///    * Ctrl-Up Arrow - show the Mission Control panel (has no effect if a window is clicked on during this keypress)
///    * Ctrl-Down Arror - show the Application Windows screen (has no effect if a window is clicked on during this keypress)
///  * Technically this could probably replicate almost any Keyboard Shortcut from the System Preferences Panel, but only Spaces has been tested.
///  * For window movement, if a window is provided, it will be brought into focus and the mouse moved for the click and keypress.
///  * If a point table ({ x = #, y= # }) is provided instead of a window, no window focus is performed -- it is assumed that you have already done so or that you know what you are doing.  This is supported in case some window is found to have a different acceptable click region for inclusion in Space moves, or in case this function turns out to be useful in other contexts.
///  * This function performs the following steps (unfortunately I couldn't seem to get the timing right using hs.eventtap.events, though I may try again at another date since it should be possible.) -- edit: maybe I just did... hmm... keep this for reference/legacy?
///    * If a window is provided, focus it and get it's topLeft corner.  Set the targetMouseLocation to just between the Close Circle and the Minimize Circle in its title bar.
///    * If a point table is provided, set the targetMouseLocation to the provided point.
///    * If a targetMouseLocation is set, move the mouse to it and perform a leftClickDown event
///    * perform a keyDown event with the provided key and modifiers (or default Ctrl-Right Arrow, if none are provided)
///    * perform a keyUp event with the same key and modifiers
///    * If a targetMouseLocation is set, perform a leftClickUp event.
static int doSpacesKey(lua_State *L) {
    CGPoint       mouseCursorPoint ;
    CGKeyCode     theKey           = kVK_RightArrow ;
    CGEventFlags  theMods          = kCGEventFlagMaskControl ;
    BOOL           withWindow      = NO ;

    if (!lua_isnoneornil(L, 1)) {
        const char* key = luaL_checkstring(L, 1);
        lua_getglobal(L, "hs"); lua_getfield(L, -1, "keycodes"); lua_getfield(L, -1, "map");
        lua_pushstring(L, key);
        lua_gettable(L, -2);
        theKey = (CGKeyCode) lua_tointeger(L, -1);
        lua_pop(L, 4); // hs.window.map and result
    }

    if (lua_isuserdata(L, 2)) {
        withWindow = YES ;

        lua_getglobal(L, "hs"); lua_getfield(L, -1, "window"); lua_getfield(L, -1, "topLeft");
        lua_pushvalue(L, 2) ;
        if (lua_pcall(L, 1, 1, 0) != LUA_OK)
            return luaL_error(L, "unable to get window position") ;
        else {
            lua_getfield(L, -1, "x") ;
            mouseCursorPoint.x = lua_tonumber(L, -1) + 24 ; // approx midway between the close
            lua_pop(L, 1) ;
            lua_getfield(L, -1, "y") ;
            mouseCursorPoint.y = lua_tonumber(L, -1) + 11 ; // circle and the minimize circle
            lua_pop(L, 4) ; // 1 for the getfield, 1 for the function result, 2 for the hs.window
        }

        lua_getglobal(L, "hs"); lua_getfield(L, -1, "window"); lua_getfield(L, -1, "focus");
        lua_pushvalue(L, 2) ;
        if (lua_pcall(L, 1, 1, 0) != LUA_OK)
            return luaL_error(L, "unable to bring window to the front for space change") ;
        else {
            lua_pop(L, 3) ; // 1 for the result and 2 for the hs.window
            usleep(125000) ; // duration seems to work -- we need time for the window activation to complete
        }

    } else if (!lua_isnoneornil(L, 2)) {
        withWindow = YES ;

        luaL_checktype(L, 2, LUA_TTABLE) ;
        if (lua_getfield(L, 2, "x") == LUA_TNUMBER) {
            mouseCursorPoint.x = lua_tonumber(L, -1) ;
            lua_pop(L, 1) ;
        } else
            return luaL_error(L, "you must provide an x coordinate in a point table") ;
        if (lua_getfield(L, 2, "y") == LUA_TNUMBER) {
            mouseCursorPoint.y = lua_tonumber(L, -1) ;
            lua_pop(L, 1) ;
        } else
            return luaL_error(L, "you must provide a y coordinate in a point table") ;
    }

    if (!lua_isnoneornil(L, 3)) {
        luaL_checktype(L, 3, LUA_TTABLE) ;
        lua_pushnil(L);
        theMods = 0 ;
        while (lua_next(L, 3) != 0) {
            const char *modifier = lua_tostring(L, -1);

            // lenient for now... ignore if not string key
            if (!modifier) { lua_pop(L, 1); continue; }

            if      (strcmp(modifier, "cmd") == 0   || strcmp(modifier, "⌘") == 0) theMods |= kCGEventFlagMaskCommand;
            else if (strcmp(modifier, "ctrl") == 0  || strcmp(modifier, "⌃") == 0) theMods |= kCGEventFlagMaskControl;
            else if (strcmp(modifier, "alt") == 0   || strcmp(modifier, "⌥") == 0) theMods |= kCGEventFlagMaskAlternate;
            else if (strcmp(modifier, "shift") == 0 || strcmp(modifier, "⇧") == 0) theMods |= kCGEventFlagMaskShift;
            else if (strcmp(modifier, "fn") == 0)                                  theMods |= kCGEventFlagMaskSecondaryFn;
            lua_pop(L, 1);
        }
    }

    CGEventRef mouseMoveEvent    = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved,    mouseCursorPoint, kCGMouseButtonLeft);
    CGEventRef mouseDownEvent    = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, mouseCursorPoint, kCGMouseButtonLeft);
    CGEventRef mouseUpEvent      = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp,   mouseCursorPoint, kCGMouseButtonLeft);
    CGEventRef keyboardDownEvent = CGEventCreateKeyboardEvent(NULL, theKey, true);
    CGEventRef keyboardUpEvent   = CGEventCreateKeyboardEvent(NULL, theKey, false);

    CGEventSetFlags(mouseMoveEvent, 0);
    CGEventSetFlags(mouseDownEvent, 0);
    CGEventSetFlags(mouseUpEvent, 0);
    CGEventSetFlags(keyboardDownEvent, theMods);
    CGEventSetFlags(keyboardUpEvent, 0);

    if (withWindow) CGEventPost(kCGHIDEventTap, mouseMoveEvent);
    if (withWindow) CGEventPost(kCGHIDEventTap, mouseDownEvent);
    usleep(125000) ; // and apparently for the window to realize it's clicked on
    CGEventPost(kCGHIDEventTap, keyboardDownEvent);
    usleep(125000) ; // and that a keypress occurred... hey, it's working for me so far!
    CGEventPost(kCGHIDEventTap, keyboardUpEvent);
    if (withWindow) CGEventPost(kCGHIDEventTap, mouseUpEvent);

    CFRelease(mouseMoveEvent);
    CFRelease(mouseDownEvent);
    CFRelease(mouseUpEvent);
    CFRelease(keyboardDownEvent);
    CFRelease(keyboardUpEvent);
    return 0 ;
}

// Can self-reference be created in NSObjects and returned to Lua?
static int pathological(__unused lua_State *L) {
    NSMutableDictionary *test = [[NSMutableDictionary alloc] init] ;
    [test setValue:test forKey:@"myself"] ;
    [test setValue:@"otherStuff" forKey:@"notMySelf"] ;

    [[LuaSkin shared] pushNSObject:test] ;
    return 1 ;
}

// Verify conversion tools properly handle self reference
static int copyAndTouch(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE) ;
    id stuff = [[LuaSkin shared] toNSObjectFromIndex:1 allowSelfReference:(BOOL)lua_toboolean(L, 2)] ;
    if ([stuff isKindOfClass: [NSArray class]]) {
        [stuff addObject:@"KilroyWasHere"] ;
    } else {
        [stuff setObject:@(YES) forKey:@"KilroyWasHere"] ;
    }
//     NSLog(@"cAt: %@",stuff) ;
    [[LuaSkin shared] pushNSObject:stuff] ;
    return 1 ;
}

static int spotlight(lua_State *L) {
    lua_pushboolean(L, [[NSWorkspace sharedWorkspace] showSearchResultsForQueryString:[NSString stringWithUTF8String:luaL_checkstring(L, 1)]]) ;
    return 1 ;
}

static int cleanUTF8(lua_State *L) {
    luaL_checktype(L, 1, LUA_TSTRING) ;
    size_t sourceLength ;
    unsigned char *src  = (unsigned char *)lua_tolstring(L, 1, &sourceLength) ;
    NSMutableData *dest = [[NSMutableData alloc] init] ;

    unsigned char nullChar[]    = { 0xE2, 0x88, 0x85 } ;
    unsigned char invalidChar[] = { 0xEF, 0xBF, 0xBD } ;

    size_t pos = 0 ;
    while (pos < sourceLength) {
        if (src[pos] > 0 && src[pos] <= 127) {
            [dest appendBytes:(void *)(src + pos) length:1] ; pos++ ;
        } else if ((src[pos] >= 194 && src[pos] <= 223) && (src[pos+1] >= 128 && src[pos+1] <= 191)) {
            [dest appendBytes:(void *)(src + pos) length:2] ; pos = pos + 2 ;
        } else if ((src[pos] == 224 && (src[pos+1] >= 160 && src[pos+1] <= 191) && (src[pos+2] >= 128 && src[pos+2] <= 191)) ||
                   ((src[pos] >= 225 && src[pos] <= 236) && (src[pos+1] >= 128 && src[pos+1] <= 191) && (src[pos+2] >= 128 && src[pos+2] <= 191)) ||
                   (src[pos] == 237 && (src[pos+1] >= 128 && src[pos+1] <= 159) && (src[pos+2] >= 128 && src[pos+2] <= 191)) ||
                   ((src[pos] >= 238 && src[pos] <= 239) && (src[pos+1] >= 128 && src[pos+1] <= 191) && (src[pos+2] >= 128 && src[pos+2] <= 191))) {
            [dest appendBytes:(void *)(src + pos) length:3] ; pos = pos + 3 ;
        } else if ((src[pos] == 240 && (src[pos+1] >= 144 && src[pos+1] <= 191) && (src[pos+2] >= 128 && src[pos+2] <= 191) && (src[pos+3] >= 128 && src[pos+3] <= 191)) ||
                   ((src[pos] >= 241 && src[pos] <= 243) && (src[pos+1] >= 128 && src[pos+1] <= 191) && (src[pos+2] >= 128 && src[pos+2] <= 191) && (src[pos+3] >= 128 && src[pos+3] <= 191)) ||
                   (src[pos] == 244 && (src[pos+1] >= 128 && src[pos+1] <= 143) && (src[pos+2] >= 128 && src[pos+2] <= 191) && (src[pos+3] >= 128 && src[pos+3] <= 191))) {
            [dest appendBytes:(void *)(src + pos) length:4] ; pos = pos + 4 ;
        } else {
            if (src[pos] == 0)
                [dest appendBytes:(void *)nullChar length:3] ;
            else
                [dest appendBytes:(void *)invalidChar length:3] ;
            pos = pos + 1 ;
        }
    }

    NSString *destStr = [[NSString alloc] initWithData:dest encoding:NSUTF8StringEncoding] ;
    lua_pushlstring(L, [destStr UTF8String], [destStr lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1) ;
    return 1 ;
}

static const luaL_Reg extrasLib[] = {
    {"consoleBehavior",     console_behavior},
    {"listWindows",         listWindows},
    {"NSLog",               extras_nslog },
    {"defaults",            extras_defaults },
    {"userDataToString",    ud_tostring},
    {"getMenuArray",        getMenuArray},
    {"doSpacesKey",         doSpacesKey},
    {"spotlight",           spotlight},
    {"pathological",        pathological},
    {"copyAndTouch",        copyAndTouch},
    {"cleanUTF8",           cleanUTF8},
    {NULL,                  NULL}
};

int luaopen_hs__asm_extras_internal(lua_State* L) {
    luaL_newlib(L, extrasLib);

    return 1;
}
