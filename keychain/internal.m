#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import <Security/Security.h>

#pragma mark - Definitions and Declarations

// Maximum path length for keychains (e.g. /Users/.../Library/Keychains/login.keychain)
// The number is arbitrary, but necessary as an argument to some functions, so change if
// necessary -- I'm guessing at something reasonable as a max that doesn't waste memory
// unnecessarily
#define MAX_PATH_LENGTH 1024

#define USERDATA_TAG        "hs._asm.keychain"
int refTable ;

#define get_objectFromUserdata(objType, L, idx) (objType)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Module Functions

static int kc_open(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    SecKeychainRef theKeychain ;
    OSStatus resultCode = SecKeychainOpen(luaL_checkstring(L, 1), &theKeychain) ;

    if (resultCode != errSecSuccess) {
        if (theKeychain) CFRelease(theKeychain) ;
        CFStringRef errorMsg = SecCopyErrorMessageString(resultCode, NULL) ;
        if (errorMsg) {
            return luaL_error(L, [(__bridge_transfer NSString *)errorMsg UTF8String]);
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"error code:%d", resultCode] UTF8String]) ;
        }
    }

    // open will give us a keychain object even if the keychain is invalid (corrupted)
    // or missing (file not found), so check it's status as well...

    UInt32 status ;
    resultCode = SecKeychainGetStatus(theKeychain, &status) ;

    if (resultCode != errSecSuccess) {
        if (theKeychain) CFRelease(theKeychain) ;
        CFStringRef errorMsg = SecCopyErrorMessageString(resultCode, NULL) ;
        if (errorMsg) {
            return luaL_error(L, [(__bridge_transfer NSString *)errorMsg UTF8String]);
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"error code:%d", resultCode] UTF8String]) ;
        }
    }

    void** kcPtr = lua_newuserdata(L, sizeof(SecKeychainRef)) ;
    *kcPtr = (void *)theKeychain ;
    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static int kc_default(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    SecKeychainRef theKeychain ;
    OSStatus resultCode = SecKeychainCopyDefault(&theKeychain) ;

    if (resultCode != errSecSuccess) {
        if (theKeychain) CFRelease(theKeychain) ;
        CFStringRef errorMsg = SecCopyErrorMessageString(resultCode, NULL) ;
        if (errorMsg) {
            return luaL_error(L, [(__bridge_transfer NSString *)errorMsg UTF8String]);
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"error code:%d", resultCode] UTF8String]) ;
        }
    }

    if (theKeychain) {
        void** kcPtr = lua_newuserdata(L, sizeof(SecKeychainRef)) ;
        *kcPtr = (void *)theKeychain ;
        luaL_getmetatable(L, USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else
        lua_pushnil(L) ;
    return 1 ;
}

static int kc_lockAll(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    OSStatus resultCode = SecKeychainLockAll() ;

    CFStringRef errorMsg = SecCopyErrorMessageString(resultCode, NULL) ;

    lua_pushboolean(L, (resultCode == errSecSuccess)) ;
    if (errorMsg) {
        lua_pushstring(L, [(__bridge_transfer NSString *)errorMsg UTF8String]);
        CFRelease(errorMsg) ;
    } else {
        lua_pushstring(L, [[NSString stringWithFormat:@"error code:%d", resultCode] UTF8String]) ;
    }

    return 2 ;
}

// Doesn't prevent all prompts, but does prevent some.  Since it was designed for unattended servers,
// it probably doesn't have much use outside of maybe a Kiosk, but providing a password (at least for
// unlock so far) prevents display anyway, so... not going to include for now unless a need arises...
//
// static int kc_allowsInteraction(lua_State *L) {
// //     [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
//
//     if (!lua_isnoneornil(L, 1)) {
//         OSStatus resultCode = SecKeychainSetUserInteractionAllowed((Boolean)lua_toboolean(L, 1)) ;
//         if (resultCode != errSecSuccess) {
//             CFStringRef errorMsg = SecCopyErrorMessageString(resultCode, NULL) ;
//             if (errorMsg) {
//                 return luaL_error(L, [(__bridge_transfer NSString *)errorMsg UTF8String]);
//             } else {
//                 return luaL_error(L, [[NSString stringWithFormat:@"error code:%d", resultCode] UTF8String]) ;
//             }
//         }
//     }
//
//     Boolean current ;
//     OSStatus resultCode = SecKeychainGetUserInteractionAllowed(&current) ;
//
//     if (resultCode != errSecSuccess) {
//         CFStringRef errorMsg = SecCopyErrorMessageString(resultCode, NULL) ;
//         if (errorMsg) {
//             return luaL_error(L, [(__bridge_transfer NSString *)errorMsg UTF8String]);
//         } else {
//             return luaL_error(L, [[NSString stringWithFormat:@"error code:%d", resultCode] UTF8String]) ;
//         }
//     }
//     lua_pushboolean(L, current) ;
//     return 1 ;
// }

static int kc_searchlist(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;

    CFArrayRef searchList ;
    OSStatus resultCode = SecKeychainCopySearchList(&searchList) ;
    if (resultCode != errSecSuccess) {
        if (searchList) CFRelease(searchList) ;
        CFStringRef errorMsg = SecCopyErrorMessageString(resultCode, NULL) ;
        if (errorMsg) {
            return luaL_error(L, [(__bridge_transfer NSString *)errorMsg UTF8String]);
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"error code:%d", resultCode] UTF8String]) ;
        }
    }
    if (searchList) {
        [skin pushNSObject:(__bridge NSArray *)searchList] ;
        CFRelease(searchList) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Object Methods

static int kc_status(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SecKeychainRef theKeychain = get_objectFromUserdata(SecKeychainRef, L, 1) ;
    UInt32 status ;

    OSStatus resultCode = SecKeychainGetStatus(theKeychain, &status) ;

    if (resultCode != errSecSuccess) {
        CFStringRef errorMsg = SecCopyErrorMessageString(resultCode, NULL) ;
        if (errorMsg) {
            return luaL_error(L, [(__bridge_transfer NSString *)errorMsg UTF8String]);
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"error code:%d", resultCode] UTF8String]) ;
        }
    }

    lua_newtable(L) ;
        lua_pushboolean(L, status & kSecUnlockStateStatus) ; lua_setfield(L, -2, "unlocked") ;
        lua_pushboolean(L, status & kSecReadPermStatus) ;    lua_setfield(L, -2, "readable") ;
        lua_pushboolean(L, status & kSecWritePermStatus) ;   lua_setfield(L, -2, "writable") ;

    return 1 ;
}

static int kc_settings(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SecKeychainRef theKeychain = get_objectFromUserdata(SecKeychainRef, L, 1) ;
    UInt32 version ; SecKeychainGetVersion(&version) ;

    SecKeychainSettings theSettings ;
    theSettings.version = version ;

    OSStatus resultCode = SecKeychainCopySettings(theKeychain, &theSettings);

    if (resultCode != errSecSuccess) {
        CFStringRef errorMsg = SecCopyErrorMessageString(resultCode, NULL) ;
        if (errorMsg) {
            return luaL_error(L, [(__bridge_transfer NSString *)errorMsg UTF8String]);
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"error code:%d", resultCode] UTF8String]) ;
        }
    }

    lua_newtable(L) ;
        lua_pushinteger(L, theSettings.version) ;         lua_setfield(L, -2, "version") ;
        lua_pushboolean(L, theSettings.lockOnSleep) ;     lua_setfield(L, -2, "lockOnSleep") ;
        lua_pushboolean(L, theSettings.useLockInterval) ; lua_setfield(L, -2, "useLockInterval") ;
        lua_pushinteger(L, theSettings.lockInterval) ;    lua_setfield(L, -2, "lockInterval") ;
    return 1 ;
}

static int kc_path(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SecKeychainRef theKeychain = get_objectFromUserdata(SecKeychainRef, L, 1) ;
    UInt32 length = MAX_PATH_LENGTH ;
    char   path[MAX_PATH_LENGTH] ;

    OSStatus resultCode = SecKeychainGetPath(theKeychain, &length, path) ;

    if (resultCode != errSecSuccess) {
        CFStringRef errorMsg = SecCopyErrorMessageString(resultCode, NULL) ;
        if (errorMsg) {
            return luaL_error(L, [(__bridge_transfer NSString *)errorMsg UTF8String]);
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"error code:%d", resultCode] UTF8String]) ;
        }
    }

    lua_pushlstring(L, path, length) ;
    return 1 ;
}

static int kc_lock(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SecKeychainRef theKeychain = get_objectFromUserdata(SecKeychainRef, L, 1) ;

    OSStatus resultCode = SecKeychainLock(theKeychain) ;

    CFStringRef errorMsg = SecCopyErrorMessageString(resultCode, NULL) ;

    lua_pushboolean(L, (resultCode == errSecSuccess)) ;
    if (errorMsg) {
        lua_pushstring(L, [(__bridge_transfer NSString *)errorMsg UTF8String]);
        CFRelease(errorMsg) ;
    } else {
        lua_pushstring(L, [[NSString stringWithFormat:@"error code:%d", resultCode] UTF8String]) ;
    }

    return 2 ;
}

static int kc_unlock(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                                LS_TSTRING | LS_TOPTIONAL,
                                LS_TBREAK] ;

    SecKeychainRef theKeychain = get_objectFromUserdata(SecKeychainRef, L, 1) ;
    char   *password   = NULL ;
    size_t length      = 0 ;
    BOOL   hasPassword = NO ;

    if (lua_type(L, 2) == LUA_TSTRING) {
        hasPassword = YES ;
        password = (char *)lua_tolstring(L, 2, &length) ;
    }

    OSStatus resultCode = SecKeychainUnlock(theKeychain, (UInt32)length, password, (Boolean)hasPassword) ;

    CFStringRef errorMsg = SecCopyErrorMessageString(resultCode, NULL) ;

    lua_pushboolean(L, (resultCode == errSecSuccess)) ;
    if (errorMsg) {
        lua_pushstring(L, [(__bridge_transfer NSString *)errorMsg UTF8String]);
        CFRelease(errorMsg) ;
    } else {
        lua_pushstring(L, [[NSString stringWithFormat:@"error code:%d", resultCode] UTF8String]) ;
    }

    return 2 ;
}

static int userdata_tostring(lua_State* L) {
    SecKeychainRef theKeychain = get_objectFromUserdata(SecKeychainRef, L, 1) ;

    UInt32 length = MAX_PATH_LENGTH ;
    char   path[MAX_PATH_LENGTH] ;

    OSStatus resultCode = SecKeychainGetPath(theKeychain, &length, path) ;

    if (resultCode != errSecSuccess) {
        CFStringRef errorMsg = SecCopyErrorMessageString(resultCode, NULL) ;
        if (errorMsg) {
            lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, (__bridge_transfer NSString *)errorMsg, lua_topointer(L, 1)] UTF8String]) ;
        } else {
            lua_pushstring(L, [[NSString stringWithFormat:@"%s: error code:%d (%p)", USERDATA_TAG, resultCode, lua_topointer(L, 1)] UTF8String]) ;
        }
    } else {
        lua_pushstring(L, [[NSString stringWithFormat:@"%s: %s (%p)", USERDATA_TAG, path, lua_topointer(L, 1)] UTF8String]) ;
    }

    return 1 ;
}

#pragma mark - Lua Infrastructure

// static int userdata_eq(lua_State* L) {
// }

static int userdata_gc(lua_State* L) {
    SecKeychainRef theKeychain = get_objectFromUserdata(SecKeychainRef, L, 1) ;
    CFRelease(theKeychain) ;

// Clear the pointer so it's no longer dangling
    void** kcPtr = lua_touserdata(L, 1);
    *kcPtr = nil ;

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     [hsimageReferences removeAllIndexes];
//     hsimageReferences = nil;
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
//     {"version",    kc_version},
    {"status",     kc_status},
    {"settings",   kc_settings},
    {"path",       kc_path},
    {"lock",       kc_lock},
    {"unlock",     kc_unlock},
    {"release",    userdata_gc},

    {"__tostring", userdata_tostring},
//     {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"open",              kc_open},
    {"default",           kc_default},
    {"locakAll",          kc_lockAll},
    {"searchList",        kc_searchlist},

//     {"allowsInteraction", kc_allowsInteraction},
    {NULL,                NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_keychain_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

    return 1;
}
