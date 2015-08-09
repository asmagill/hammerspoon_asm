#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#import "objectconversion.m"

/// hs._asm.extras.NSLog(luavalue)
/// Function
/// Send a representation of the lua value passed in to the Console application via NSLog.
static int extras_nslog(lua_State* L) {
    id val = lua_toNSObject(L, 1);
    NSLog(@"%@", val);
    return 0;
}


static int extras_defaults(lua_State* L) {
    NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] ;
    NSObject_tolua(L, defaults) ;
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
//             NSObject_tolua(L, [NSClassFromString(className) performSelector:NSSelectorFromString(selectorName)]) ;
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

// /// hs.automaticallyChecksForUpdates([setting]) -> bool
// /// Function
// /// Gets and optionally sets the Hammerspoon option to automatically check for updates.
// ///
// /// Parameters:
// ///  * setting - an optional boolean variable indicating if Hammerspoon should (true) or should not (false) check for updates.
// ///
// /// Returns:
// ///  * The current (or newly set) value indicating whether or not automatic update checks should occur for Hammerspoon.
// ///
// /// Notes:
// ///  * If you are running a non-release or locally compiled version of Hammerspoon then the results of this function are unspecified.
// static int automaticallyChecksForUpdates(lua_State *L) {
//     if (NSClassFromString(@"SUUpdater")) {
//         NSString *frameworkPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:@"Sparkle.framework"];
//         if ([[NSBundle bundleWithPath:frameworkPath] load]) {
//             id sharedUpdater = [NSClassFromString(@"SUUpdater")  performSelector:@selector(sharedUpdater)] ;
//             if (lua_isboolean(L, 1)) {
//
//             // This convoluted #$@#% is required (a) because we want to weakly link to the SparkleFramework for dev builds, and
//             // (b) because performSelector: withObject: only works when withObject: takes an argument of type id or nil
//
//             // the following is equivalent to: [sharedUpdater setAutomaticallyChecksForUpdates:lua_toboolean(L, 1)] ;
//
//                 BOOL myBoolValue = lua_toboolean(L, 1) ;
//                 NSMethodSignature * mySignature = [NSClassFromString(@"SUUpdater") instanceMethodSignatureForSelector:@selector(setAutomaticallyChecksForUpdates:)];
//                 NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
//                 [myInvocation setTarget:sharedUpdater];
//             // even though signature specifies this, we need to specify it in the invocation, since the signature is re-usable
//             // for any method which accepts the same signature list for the target.
//                 [myInvocation setSelector:@selector(setAutomaticallyChecksForUpdates:)];
//                 [myInvocation setArgument:&myBoolValue atIndex:2];
//                 [myInvocation invoke];
//
//             // whew!
//
//             }
//             lua_pushboolean(L, (BOOL)[sharedUpdater performSelector:@selector(automaticallyChecksForUpdates)]) ;
//         } else {
//             printToConsole(L, "-- Sparkle Update framework not available for the running instance of Hammerspoon.") ;
//             lua_pushboolean(L, NO) ;
//         }
//     } else {
//         printToConsole(L, "-- Sparkle Update framework not available for the running instance of Hammerspoon.") ;
//         lua_pushboolean(L, NO) ;
//     }
//     return 1 ;
// }
//
// /// hs.checkForUpdates() -> none
// /// Function
// /// Check for an update now, and if one is available, prompt the user to continue the update process.
// ///
// /// Parameters:
// ///  * None
// ///
// /// Returns:
// ///  * None
// ///
// /// Notes:
// ///  * If you are running a non-release or locally compiled version of Hammerspoon then the results of this function are unspecified.
// static int checkForUpdates(lua_State *L) {
//     if (NSClassFromString(@"SUUpdater")) {
//         NSString *frameworkPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:@"Sparkle.framework"];
//         if ([[NSBundle bundleWithPath:frameworkPath] load]) {
//             id sharedUpdater = [NSClassFromString(@"SUUpdater")  performSelector:@selector(sharedUpdater)] ;
//
//             [sharedUpdater performSelector:@selector(checkForUpdates:) withObject:nil] ;
//         } else {
//             printToConsole(L, "-- Sparkle Update framework not available for the running instance of Hammerspoon.") ;
//         }
//     } else {
//         printToConsole(L, "-- Sparkle Update framework not available for the running instance of Hammerspoon.") ;
//     }
//     return 0 ;
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

static const luaL_Reg extrasLib[] = {
    {"consoleBehavior",     console_behavior },
    {"NSLog",               extras_nslog },
    {"defaults",            extras_defaults },
    {"userDataToString",    ud_tostring},
    {"getMenuArray",        getMenuArray},
//     {"automaticallyChecksForUpdates",     automaticallyChecksForUpdates},
//     {"checkForUpdates",  checkForUpdates},
    {NULL,                  NULL}
};

int luaopen_hs__asm_extras_internal(lua_State* L) {
    luaL_newlib(L, extrasLib);

    return 1;
}
