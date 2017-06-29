@import Cocoa ;
@import IOKit.hid ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.forcetouch" ;
static int refTable = LUA_NOREF;

// #define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

// Based in part on code from https://eternalstorms.wordpress.com/2015/11/16/how-to-detect-force-touch-capable-devices-on-the-mac/
BOOL searchForForceTouchDevice(io_iterator_t iterator) {
    BOOL success = NO ;
    if (iterator == NULL) {
        CFMutableDictionaryRef mDict = IOServiceMatching(kIOHIDDeviceKey) ;
        io_iterator_t initialIterator ;
        IOReturn ioReturnValue = IOServiceGetMatchingServices(kIOMasterPortDefault, mDict, &initialIterator) ;
        if (ioReturnValue == kIOReturnSuccess) {
            success = searchForForceTouchDevice(initialIterator) ;
            IOObjectRelease(initialIterator);
        }
    } else {
        if (IOIteratorIsValid(iterator) == false) return NO ;
        io_object_t object = 0 ;
        while ((object = IOIteratorNext(iterator))) {
            CFMutableDictionaryRef result = NULL ;
            kern_return_t state = IORegistryEntryCreateCFProperties(object, &result, kCFAllocatorDefault, 0) ;
            if (state == KERN_SUCCESS && result != NULL) {
                if (CFDictionaryContainsKey(result, CFSTR("DefaultMultitouchProperties"))) {
                    CFDictionaryRef dict = CFDictionaryGetValue(result, CFSTR("DefaultMultitouchProperties")) ;
                    CFTypeRef val = NULL ;
                    if (CFDictionaryGetValueIfPresent(dict, CFSTR("ForceSupported"), &val)) {
                        Boolean aBool = CFBooleanGetValue(val) ;
                        if (aBool) { //supported
                            success = YES ;
                        }
                    }
                }
            }
            if (!success) {
                io_iterator_t childIterator = 0 ;
                kern_return_t err = IORegistryEntryGetChildIterator(object, kIOServicePlane, &childIterator) ;
                if (err == KERN_SUCCESS) {
                    success = searchForForceTouchDevice(childIterator) ;
                    IOObjectRelease(childIterator) ;
                } else {
                    success = NO ;
                }
            }
            if (result != NULL) CFRelease(result) ;
            IOObjectRelease(object) ;
        }
    }
    return success;
}

#pragma mark - Module Functions

/// hs._asm.forcetouch.feedback(type, [immediate]) -> boolean
/// Function
/// Generate haptic feedback on the currently active force touch device.
///
/// Parameters:
///  * type - a string which must be one of the following values:
///    * "generic"   - A general haptic feedback pattern. Use this when no other feedback patterns apply.
///    * "alignment" - A haptic feedback pattern to be used in response to the alignment of an object the user is dragging around. For example, this pattern of feedback could be used in a drawing app when the user drags a shape into alignment with with another shape. Other scenarios where this type of feedback could be used might include scaling an object to fit within specific dimensions, positioning an object at a preferred location, or reaching the beginning/minimum or end/maximum of something, such as a track view in an audio/video app.
///    * "level"     - A haptic feedback pattern to be used as the user moves between discrete levels of pressure. This pattern of feedback is used by multilevel accelerator buttons.
///  * immediate - an optional boolean, default false, indicating whether the feedback should occur immediately (true) or when the screen has finished updating (false)
///
/// Returns:
///  * true if a feedback performer object exists within the current system, or false if it does not.
///
/// Notes:
///  * The existence of a feedback performer object is dependent upon the OS X version and not necessarily on the hardware available -- laptops with a trackpad which predates force touch will return true, even though this function does nothing on such systems.
///  * Even on systems with a force touch device, this function will only generate feedback when the device is active or being touched -- from the Apple docs: "In some cases, the system may override a call to this method. For example, a Force Touch trackpad won’t provide haptic feedback if the user isn’t touching the trackpad."
static int forcetoucFeedback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *type = [skin toNSObjectAtIndex:1] ;
    NSHapticFeedbackPattern         pattern ;
    NSHapticFeedbackPerformanceTime when = (lua_gettop(L) == 2) ? (lua_toboolean(L, 2) ? NSHapticFeedbackPerformanceTimeNow : NSHapticFeedbackPerformanceTimeDrawCompleted) : NSHapticFeedbackPerformanceTimeDrawCompleted ;

    if ([type isEqualToString:@"generic"]) {
        pattern = NSHapticFeedbackPatternGeneric ;
    } else if ([type isEqualToString:@"alignment"]) {
        pattern = NSHapticFeedbackPatternAlignment ;
    } else if ([type isEqualToString:@"level"]) {
        pattern = NSHapticFeedbackPatternLevelChange ;
    } else {
        return luaL_argerror(L, 1, [@"expected 'generic', 'alignment', or 'level'" UTF8String]) ;
    }

    Class NSHFMClass = NSClassFromString(@"NSHapticFeedbackManager");
    if (NSHFMClass) {
        id performer = [NSHFMClass defaultPerformer] ;
        if (performer && [performer respondsToSelector:@selector(performFeedbackPattern:performanceTime:)]) {
            [performer performFeedbackPattern:pattern performanceTime:when] ;
            lua_pushboolean(L, YES) ;
        } else {
            lua_pushboolean(L, NO) ;
        }
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

/// hs._asm.forcetouch.deviceAttached() -> boolean
/// Function
/// Returns a boolean indicating whether or not a force touch capable device is currently attached to the system.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean value indicating whether or not a force touch capable device is currently attached to the system.
///
/// Notes:
///  * Based in part on code from https://eternalstorms.wordpress.com/2015/11/16/how-to-detect-force-touch-capable-devices-on-the-mac/
static int forcetouchDeviceDeviceAttached(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    lua_pushboolean(L, searchForForceTouchDevice(NULL)) ;
    return 1 ;
}

#pragma mark - Module Methods

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

// static int push<moduleType>(lua_State *L, id obj) {
//     <moduleType> *value = obj;
//     void** valuePtr = lua_newuserdata(L, sizeof(<moduleType> *));
//     *valuePtr = (__bridge_retained void *)value;
//     luaL_getmetatable(L, USERDATA_TAG);
//     lua_setmetatable(L, -2);
//     return 1;
// }
//
// id to<moduleType>FromLua(lua_State *L, int idx) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     <moduleType> *value ;
//     if (luaL_testudata(L, idx, USERDATA_TAG)) {
//         value = get_objectFromUserdata(__bridge <moduleType>, L, idx, USERDATA_TAG) ;
//     } else {
//         [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
//                                                    lua_typename(L, lua_type(L, idx))]] ;
//     }
//     return value ;
// }

#pragma mark - Hammerspoon/Lua Infrastructure

// static int userdata_tostring(lua_State* L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     <moduleType> *obj = [skin luaObjectAtIndex:1 toClass:"<moduleType>"] ;
//     NSString *title = ... ;
//     [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
//     return 1 ;
// }

// static int userdata_eq(lua_State* L) {
// // can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// // so use luaL_testudata before the macro causes a lua error
//     if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
//         LuaSkin *skin = [LuaSkin shared] ;
//         <moduleType> *obj1 = [skin luaObjectAtIndex:1 toClass:"<moduleType>"] ;
//         <moduleType> *obj2 = [skin luaObjectAtIndex:2 toClass:"<moduleType>"] ;
//         lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
//     } else {
//         lua_pushboolean(L, NO) ;
//     }
//     return 1 ;
// }

// static int userdata_gc(lua_State* L) {
//     <moduleType> *obj = get_objectFromUserdata(__bridge_transfer <moduleType>, L, 1, USERDATA_TAG) ;
//     if (obj) obj = nil ;
//     // Remove the Metatable so future use of the variable in Lua won't think its valid
//     lua_pushnil(L) ;
//     lua_setmetatable(L, 1) ;
//     return 0 ;
// }

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// // Metatable for userdata objects
// static const luaL_Reg userdata_metaLib[] = {
//     {"__tostring", userdata_tostring},
//     {"__eq",       userdata_eq},
//     {"__gc",       userdata_gc},
//     {NULL,         NULL}
// };

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"feedback",       forcetoucFeedback},
    {"deviceAttached", forcetouchDeviceDeviceAttached},
    {NULL,             NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_forcetouch_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
// Use this if your module doesn't have a module specific object that it returns.
   refTable = [skin registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
//     refTable = [skin registerLibraryWithObject:USERDATA_TAG
//                                      functions:moduleLib
//                                  metaFunctions:nil    // or module_metaLib
//                                objectFunctions:userdata_metaLib];

//     [skin registerPushNSHelper:push<moduleType>         forClass:"<moduleType>"];

// // one, but not both, of...
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"
//                                              withUserdataMapping:USERDATA_TAG];
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"];

    return 1;
}
