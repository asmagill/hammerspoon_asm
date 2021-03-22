@import Cocoa ;
@import LuaSkin ;

#import "private.h"

static const char * const USERDATA_TAG = "hs.spaces" ;
static LSRefTable refTable = LUA_NOREF;

static NSRegularExpression *regEx_UUID ;

static int g_connection ;

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

/// hs.spaces.screensHaveSeparateSpaces() -> bool
/// Function
/// Determine if the user has enabled the "Displays Have Separate Spaces" option within Mission Control.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true or false representing the status of the "Displays Have Separate Spaces" option within Mission Control.
static int spaces_screensHaveSeparateSpaces(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushboolean(L, [NSScreen screensHaveSeparateSpaces]) ;
    return 1 ;
}

/// hs.spaces.managedDisplaySpaces() -> table | nil, error
/// Function
/// Returns a table containing information about the managed display spaces
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing information about all of the displays and spaces managed by the OS.
///
/// Notes:
///  * the format and detail of this table is too complex and varied to describe here; suffice it to say this is the workhorse for this module and a careful examination of this table may be informative, but is not required in the normal course of using this module.
static int spaces_managedDisplaySpaces(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    CFArrayRef managedDisplaySpaces = SLSCopyManagedDisplaySpaces(g_connection) ;
    if (managedDisplaySpaces) {
        [skin pushNSObject:(__bridge NSArray *)managedDisplaySpaces withOptions:LS_NSDescribeUnknownTypes] ;
        CFRelease(managedDisplaySpaces) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "SLSCopyManagedDisplaySpaces returned NULL") ;
        return 2 ;
    }
    return 1 ;
}


// static int spaces_managedDisplayGetCurrentSpace(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
//     NSString *screenUUID = [skin toNSObjectAtIndex:1] ;
//
//     if (regEx_UUID) {
//         if ([regEx_UUID numberOfMatchesInString:screenUUID options:NSMatchingAnchored range:NSMakeRange(0, screenUUID.length)] != 1) {
//             lua_pushnil(L) ;
//             lua_pushstring(L, "not a valid UUID string") ;
//             return 2 ;
//         }
//     } else {
//         lua_pushnil(L) ;
//         lua_pushstring(L, "unable to verify UUID") ;
//         return 2 ;
//     }
//
//     lua_pushinteger(L, (lua_Integer)SLSManagedDisplayGetCurrentSpace(g_connection, (__bridge CFStringRef)screenUUID)) ;
//     return 1 ;
// }

/// hs.spaces.focusedSpace() -> integer
/// Function
/// Returns the space ID of the currently focused space
///
/// Parameters:
///  * None
///
/// Returns:
///  * the space ID for the currently focused space. The focused space is the currently active space on the currently active screen (i.e. that the user is working on)
///
/// Notes:
///  * *usually* the currently active screen will be returned by `hs.screen.mainScreen()`; however some full screen applications may have focus without updating which screen is considered "main". You can use this function, and look up the screen UUID with [hs.spaces.displayForSpace](#displayForSpace) to determine the "true" focused screen if required.
static int spaces_getActiveSpace(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushinteger(L, (lua_Integer)SLSGetActiveSpace(g_connection)) ;
    return 1 ;
}

// static int spaces_managedDisplayForSpace(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
//     uint64_t sid = (uint64_t)lua_tointeger(L, 1) ;
//     CFStringRef display = SLSCopyManagedDisplayForSpace(g_connection, sid) ;
//     if (display) {
//         [skin pushNSObject:(__bridge NSString *)display] ;
//         CFRelease(display) ;
//     } else {
//         lua_pushnil(L) ;
//         lua_pushfstring(L, "SLSCopyManagedDisplayForSpace returned NULL for %d", sid) ;
//         return 2 ;
//     }
//     return 1 ;
// }

// static int spaces_getType(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
//     uint64_t sid = (uint64_t)lua_tointeger(L, 1) ;
//     lua_pushinteger(L, (lua_Integer)SLSSpaceGetType(g_connection, sid)) ;
//     return 1 ;
// }

// static int spaces_name(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
//     uint64_t sid = (uint64_t)lua_tointeger(L, 1) ;
//     CFStringRef spaceName = SLSSpaceCopyName(g_connection, sid) ;
//     if (spaceName) {
//         [skin pushNSObject:(__bridge NSString *)spaceName] ;
//         CFRelease(spaceName) ;
//     } else {
//         lua_pushnil(L) ;
//         lua_pushfstring(L, "SLSSpaceCopyName returned NULL for %d", sid) ;
//         return 2 ;
//     }
//     return 1 ;
// }

/// hs.spaces.displayIsAnimating(screenUUID) -> boolean | nil, error
/// Function
/// Returns whether or not the specified screen is currently undergoing space change animation
///
/// Parameters:
///  * `screenUUID` - a string specifying the UUID for the screen to check for animation
///
/// Returns:
///  * true if the screen is currently in the process of animating a space change, or false if it is not
///
/// Notes:
///  * Non-space change animations are not captured by this function -- unfortunately this lack also includes the change to the Mission Control and App Exposé displays.
static int spaces_managedDisplayIsAnimating(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *screenUUID = [skin toNSObjectAtIndex:1] ;

    if (regEx_UUID) {
        if ([regEx_UUID numberOfMatchesInString:screenUUID options:NSMatchingAnchored range:NSMakeRange(0, screenUUID.length)] != 1) {
            lua_pushnil(L) ;
            lua_pushstring(L, "not a valid UUID string") ;
            return 2 ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "unable to verify UUID") ;
        return 2 ;
    }

    lua_pushboolean(L, SLSManagedDisplayIsAnimating(g_connection, (__bridge CFStringRef)screenUUID)) ;
    return 1 ;
}

/// hs.spaces.windowsForSpace(spaceID) -> table | nil, error
/// Function
/// Returns a table containing the window IDs of *all* windows on the specified space
///
/// Parameters:
///  * `spaceID` - an integer specifying the ID of the space to return the window list for
///
/// Returns:
///  * a table containing the window IDs for *all* windows on the specified space
///
/// Notes:
///  * The list of windows includes all items which are considered "windows" by macOS -- this includes visual elements usually considered unimportant like overlays, tooltips, graphics, off-screen windows, etc. so expect a lot of false positives in the results.
///  * In addition, due to the way Accessibility objects work, only those window IDs that are present on the currently visible spaces will be finable with `hs.window` or exist within `hs.window.allWindows()`.
///  * Reviewing how third-party applications have generally pruned this list, I believe it will be necessary to use `hs.window.filter` to prune the list and access `hs.window` objects that are on the non-visible spaces.
///    * as `hs.window.filter` is scheduled to undergo a re-write soon to (hopefully) dramatically speed it up, I am providing this function *as is* at present for those who wish to experiment with it; however, I hope to make it more useful in the coming months and the contents may change in the future (the format won't, but hopefully the useless extras will disappear requiring less pruning logic on your end).
static int spaces_windowsForSpace(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    uint64_t sid              = (uint64_t)lua_tointeger(L, 1) ;
    BOOL     includeMinimized = (lua_gettop(L) > 1) ? (BOOL)(lua_toboolean(L, 2)) : YES ;

    uint32_t owner     = 0 ;
    uint32_t options   = includeMinimized ? 0x7 : 0x2 ;
    uint64_t setTags   = 0 ;
    uint64_t clearTags = 0 ;

    NSArray *spacesList = @[ [NSNumber numberWithUnsignedLongLong:sid] ] ;

    CFArrayRef windowListRef = SLSCopyWindowsWithOptionsAndTags(g_connection, owner, (__bridge CFArrayRef)spacesList, options, &setTags, &clearTags) ;

    if (windowListRef) {
        [skin pushNSObject:(__bridge NSArray *)windowListRef] ;
        CFRelease(windowListRef) ;
    } else {
        lua_pushnil(L) ;
        lua_pushfstring(L, "SLSCopyWindowsWithOptionsAndTags returned NULL for %d", sid) ;
        return 2 ;
    }
    return 1 ;
}

static int spaces_coreDesktopSendNotification(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *message = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, (lua_Integer)(CoreDockSendNotification((__bridge CFStringRef)message, 0))) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Hammerspoon/Lua Infrastructure

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"screensHaveSeparateSpaces", spaces_screensHaveSeparateSpaces},
    {"managedDisplaySpaces",      spaces_managedDisplaySpaces},
    {"displayIsAnimating",        spaces_managedDisplayIsAnimating},

    // hs.spaces.activeSpaceOnScreen(hs.screen.mainScreen()) wrong for full screen apps, so keep
    {"focusedSpace",              spaces_getActiveSpace},

    {"windowsForSpace",           spaces_windowsForSpace},

    {"_coreDesktopNotification",  spaces_coreDesktopSendNotification},

//     {"currentSpaceForDisplay",    spaces_managedDisplayGetCurrentSpace}, -- hs.spaces.activeSpaceOnScreen
//     {"displayForSpace",           spaces_managedDisplayForSpace},        -- can get from managedDisplaySpaces if there's a need
//     {"spaceType",                 spaces_getType},                       -- can get from managedDisplaySpaces if there's a need
//     {"spaceName",                 spaces_name},                          -- can get from managedDisplaySpaces if there's a need

    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_spaces_spacesObjc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:USERDATA_TAG functions:moduleLib metaFunctions:nil] ; // or module_metaLib

    g_connection = SLSMainConnectionID() ;

    NSError *error = nil ;
    regEx_UUID = [NSRegularExpression regularExpressionWithPattern:@"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
                                                           options:NSRegularExpressionCaseInsensitive
                                                             error:&error] ;
    if (error) {
        regEx_UUID = nil ;
        [skin logError:[NSString stringWithFormat:@"%s.luaopen - unable to create UUID regular expression: %@", USERDATA_TAG, error.localizedDescription]] ;
    }

    return 1;
}
