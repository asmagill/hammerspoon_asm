@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.cfpreferences" ; // used in warnings
static int refTable = LUA_NOREF;

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

// _Nullable CFPropertyListRef CFPreferencesCopyValue(CFStringRef key, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);
static int cfpreferences_copyAppValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *key           = [skin toNSObjectAtIndex:1] ;
    NSString *applicationID = (lua_gettop(L) == 2) ? [skin toNSObjectAtIndex:2] : (__bridge NSString *)kCFPreferencesCurrentApplication ;
    CFPropertyListRef results = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)applicationID) ;
    if (results != NULL) {
        [skin pushNSObject:(__bridge_transfer id)results] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int cfpreferences_getAppBooleanValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *key           = [skin toNSObjectAtIndex:1] ;
    NSString *applicationID = (lua_gettop(L) == 2) ? [skin toNSObjectAtIndex:2] : (__bridge NSString *)kCFPreferencesCurrentApplication ;
    Boolean  existsAndValid = false ;
    Boolean  result = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)key, (__bridge CFStringRef)applicationID, &existsAndValid) ;
    if (existsAndValid) {
        lua_pushboolean(L, result) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int cfpreferences_getAppIntegerValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *key           = [skin toNSObjectAtIndex:1] ;
    NSString *applicationID = (lua_gettop(L) == 2) ? [skin toNSObjectAtIndex:2] : (__bridge NSString *)kCFPreferencesCurrentApplication ;
    Boolean  existsAndValid = false ;
    CFIndex  result = CFPreferencesGetAppIntegerValue((__bridge CFStringRef)key, (__bridge CFStringRef)applicationID, &existsAndValid) ;
    if (existsAndValid) {
        lua_pushinteger(L, result) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

// Boolean CFPreferencesSynchronize(CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);
static int cfpreferences_appSynchronize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *applicationID = (lua_gettop(L) == 1) ? [skin toNSObjectAtIndex:1] : (__bridge NSString *)kCFPreferencesCurrentApplication ;
    lua_pushboolean(L, CFPreferencesAppSynchronize((__bridge CFStringRef)applicationID)) ;
    return 1 ;
}

static int cfpreferences_appValueIsForced(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *key           = [skin toNSObjectAtIndex:1] ;
    NSString *applicationID = (lua_gettop(L) == 2) ? [skin toNSObjectAtIndex:2] : (__bridge NSString *)kCFPreferencesCurrentApplication ;
    lua_pushboolean(L, CFPreferencesAppValueIsForced((__bridge CFStringRef)key, (__bridge CFStringRef)applicationID)) ;
    return 1 ;
}

static int cfpreferences_copyKeyList(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *applicationID = (lua_gettop(L) > 0) ? [skin toNSObjectAtIndex:1] : (__bridge NSString *)kCFPreferencesCurrentApplication ;
    CFStringRef userName    = (lua_gettop(L) > 1) ? (lua_toboolean(L, 2) ? kCFPreferencesAnyUser : kCFPreferencesCurrentUser) : kCFPreferencesCurrentUser ;
    CFStringRef hostName    = (lua_gettop(L) > 2) ? (lua_toboolean(L, 3) ? kCFPreferencesAnyHost : kCFPreferencesCurrentHost) : kCFPreferencesAnyHost ;
    CFArrayRef results = CFPreferencesCopyKeyList((__bridge CFStringRef)applicationID, userName, hostName) ;
    if (results != NULL) {
        [skin pushNSObject:(__bridge_transfer id)results] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

// void CFPreferencesSetAppValue(CFStringRef key, _Nullable CFPropertyListRef value, CFStringRef applicationID);
// void CFPreferencesSetValue(CFStringRef key, _Nullable CFPropertyListRef value, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);

// // See http://www.cocoabuilder.com/archive/cocoa/72061-cfpreferences-vs-nsuserdefaults.html
// // * Note that we can't write for kCFPreferencesAnyUser without root
// // * if applicationID exists in perHost and anyHost directories, which gets read/set? is that sufficient reason to add these even with the limitation that kCFPreferencesAnyUser can't be set?
// // * a reason pro is the the *App* functions aren't supposed to take kCFPreferencesAnyApplication as the application ID (though it seems to work with the getters at least)
    // _Nullable CFPropertyListRef CFPreferencesCopyValue(CFStringRef key, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);
    // void CFPreferencesSetValue(CFStringRef key, _Nullable CFPropertyListRef value, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);
    // Boolean CFPreferencesSynchronize(CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);

// // Easier to iterate in lua?
    // CFDictionaryRef CFPreferencesCopyMultiple(_Nullable CFArrayRef keysToFetch, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);
    // void CFPreferencesSetMultiple(_Nullable CFDictionaryRef keysToSet, _Nullable CFArrayRef keysToRemove, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);

// // Would allow adding into the search space for hs.settings... have to consider the security/safety ramifications, though it probably would
// // allow for user selectable sets of settings...
    // void CFPreferencesAddSuitePreferencesToApp(CFStringRef applicationID, CFStringRef suiteID);
    // void CFPreferencesRemoveSuitePreferencesFromApp(CFStringRef applicationID, CFStringRef suiteID);

// Not sure about these...
// Uundocumented:
extern CFPropertyListRef _CFPreferencesCopyApplicationMap(CFStringRef userName, CFStringRef hostName) __attribute__((weak_import));
extern void              _CFPreferencesFlushCachesForIdentifier(CFStringRef applicationID, CFStringRef userName) __attribute__((weak_import));

static int cfpreferences_flushCachesForIdentifier(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *applicationID = (lua_gettop(L) > 0) ? [skin toNSObjectAtIndex:1] : (__bridge NSString *)kCFPreferencesCurrentApplication ;
    CFStringRef userName    = (lua_gettop(L) > 1) ? (lua_toboolean(L, 2) ? kCFPreferencesAnyUser : kCFPreferencesCurrentUser) : kCFPreferencesCurrentUser ;
    if (&_CFPreferencesFlushCachesForIdentifier != NULL) {
        _CFPreferencesFlushCachesForIdentifier((__bridge CFStringRef)applicationID, userName) ;
        lua_pushboolean(L, YES) ;
    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s.applicationMap - private function _CFPreferencesFlushCachesForIdentifier not defined in this OS version; returning nil", USERDATA_TAG]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int cfpreferences_copyApplicationMap(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    CFStringRef userName = (lua_gettop(L) > 0) ? (lua_toboolean(L, 1) ? kCFPreferencesAnyUser : kCFPreferencesCurrentUser) : kCFPreferencesCurrentUser ;
    CFStringRef hostName = (lua_gettop(L) > 1) ? (lua_toboolean(L, 2) ? kCFPreferencesAnyHost : kCFPreferencesCurrentHost) : kCFPreferencesAnyHost ;
    if (&_CFPreferencesCopyApplicationMap != NULL) {
        CFPropertyListRef results = _CFPreferencesCopyApplicationMap(userName, hostName) ;
        if (results != NULL) {
            [skin pushNSObject:(__bridge_transfer id)results] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s.applicationMap - private function _CFPreferencesCopyApplicationMap not defined in this OS version; returning nil", USERDATA_TAG]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
// Deprecated, so we do the same weak import and check before actually using it
_Nullable CFArrayRef CFPreferencesCopyApplicationList(CFStringRef userName, CFStringRef hostName) __attribute__((weak_import));

static int cfpreferences_copyApplicationList(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    CFStringRef userName = (lua_gettop(L) > 0) ? (lua_toboolean(L, 1) ? kCFPreferencesAnyUser : kCFPreferencesCurrentUser) : kCFPreferencesCurrentUser ;
    CFStringRef hostName = (lua_gettop(L) > 1) ? (lua_toboolean(L, 2) ? kCFPreferencesAnyHost : kCFPreferencesCurrentHost) : kCFPreferencesAnyHost ;
    if (&CFPreferencesCopyApplicationList != NULL) {
        CFPropertyListRef results = CFPreferencesCopyApplicationList(userName, hostName) ;
        if (results != NULL) {
            [skin pushNSObject:(__bridge_transfer id)results] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s.applicationMap - deprecated function CFPreferencesCopyApplicationList not defined in this OS version; returning nil", USERDATA_TAG]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}
#pragma clang diagnostic pop

#pragma mark - Module Methods

#pragma mark - Module Constants

// static int push_preferencesKeys(lua_State *L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     lua_newtable(L) ;
//     [skin pushNSObject:(__bridge NSString *)kCFPreferencesAnyApplication] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:(__bridge NSString *)kCFPreferencesCurrentApplication] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:(__bridge NSString *)kCFPreferencesAnyHost] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:(__bridge NSString *)kCFPreferencesCurrentHost] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:(__bridge NSString *)kCFPreferencesAnyUser] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:(__bridge NSString *)kCFPreferencesCurrentUser] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     return 1 ;
// }

#pragma mark - LuaSkin conversion helpers

// Write our own conversion tool here since CFPropertyListRef is known to be:
//    limited to the following types: CFData, CFString, CFArray, CFDictionary, CFDate, CFBoolean, and CFNumber
//    keys for CFDictionary must be strings
// add our own formats for date in/out like described below?
// to force data type when Hammerspoon thinks it is a valid string?
//
// How to merge with settings/plist?

// NSDate *date = [skin luaObjectAtIndex:idx toClass:"NSDate"] ;
// NSDate *date = [skin toNSObjectAtIndex:idx] ;
// C-API
// Returns an NSDate object as described in the table on the Lua Stack at idx.
//
// The table should have one of the following formats:
//
// { -- output of `os.time()` plus optional float portion for fraction of a second
//     number,
//     __luaSkinType = "NSDate" -- optional if using the luaObjectAtIndex:toClass: , required if using toNSObjectAtIndex:
// }
//
// { -- rfc3339 string (supported by hs.settings) AKA "Internet Date and Time Timestamp Format"
//     'YYYY-MM-DD[T]HH:MM:SS[Z]',
//     __luaSkinType = "NSDate" -- optional if using the luaObjectAtIndex:toClass: , required if using toNSObjectAtIndex:
// }
//
// { -- this matches the output of `os.date("*t")` -- are there other fields we should optionally allow since macOS can be more precise?
//     day   = integer,
//     hour  = integer,
//     isdst = boolean,
//     min   = integer,
//     month = integer,
//     sec   = integer,
//     wday  = integer,
//     yday  = integer,
//     year  = integer,
//     __luaSkinType = "NSDate" -- optional if using the luaObjectAtIndex:toClass: , required if using toNSObjectAtIndex:
// }

// May add others if this approach proves useful
static id table_toNSDate(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared];

//     ...

}

#pragma mark - Hammerspoon/Lua Infrastructure

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"getValue",        cfpreferences_copyAppValue},
    {"getBoolean",      cfpreferences_getAppBooleanValue},
    {"getInteger",      cfpreferences_getAppIntegerValue},
    {"synchronize",     cfpreferences_appSynchronize},
    {"valueIsForced",   cfpreferences_appValueIsForced},
    {"keyList",         cfpreferences_copyKeyList},

    {"applicationList", cfpreferences_copyApplicationList},
    {"applicationMap",  cfpreferences_copyApplicationMap},
    {"flushCaches",     cfpreferences_flushCachesForIdentifier},

    {NULL,         NULL}
};

int luaopen_hs__asm_cfpreferences_internal(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib

//     push_preferencesKeys(L) ; lua_setfield(L, -2, "predefinedKeys") ;

// should move this to hs.settings or hs.plist if this ends up in core
    // we're only doing the table to NSDate helper since LuaSkin already turns NSDate into a time number when going
    // the other way and it would break too many things to change that now... maybe if we do a fundamental rewrite
    [skin registerLuaObjectHelper:table_toNSDate forClass:"NSDate"
                                         withTableMapping:"NSDate"];

    return 1;
}
