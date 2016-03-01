#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import "LuaSkinThread.h"
#import "LuaSkinThread+Private.h"

#define USERDATA_TAG "hs._asm.luaskinpokeytool"
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes
extern NSMutableDictionary *registeredNSHelperFunctions ;
extern NSMutableDictionary *registeredNSHelperLocations ;
extern NSMutableDictionary *registeredLuaObjectHelperFunctions ;
extern NSMutableDictionary *registeredLuaObjectHelperLocations ;
extern NSMutableDictionary *registeredLuaObjectHelperUserdataMappings;

#pragma mark - Module Functions

/// hs._asm.luaskinpokeytool.skin() -> luaSkin object
/// Constructor
/// Returns a reference to the LuaSkin object for the current Lua environment.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a luaSkin object
///
/// Notes:
///  * Because Hammerspoon itself runs a single-threaded Lua instance, there is only ever one LuaSkin instance available without using `hs._asm.luathread`.  Generally, in this situation, the available methods should be thread-safe, but remember you are dealing directly with the underpinnings of the Lua state for Hammerspoon -- there are other ways to screw things up if you're not careful!
///
///  * To access a LuaSkin object for a different thread, you *must* be using `hs._asm.luathread` and copy it with the `hs._asm.luathread:get` method or shared dictionary table support.
///
///  * It is **HIGHLY** recommended that you do not try to do things in the other direction (i.e. copy the Hammerspoon LuaSkin object into an `hs._asm.luathread` one with `hs._asm.luathread:set`) because the Hammerspoon LuaSkin instance is in use for every timer, hotkey invocation, callback function, etc.  Even submitting or receiving results from a threaded lua causes some LuaSkin activity on Hammerspoon's main thread, so the primary Hammerspoon LuaSkin instance can **NEVER** be considered inactive enough to be even *some-times* safe to examine or modify from another thread.
static int getLuaSkinObject(__unused lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin() ; // [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:skin] ;
    return 1 ;
}

/// hs._asm.luaskinpokeytool.classLogMessage(level, message, [asClass]) -> None
/// Method
/// Uses the class methods of LuaSkin to log a message
///
/// Parameters:
///  * `level`   - an integer value from the `hs._asm.luaskinpokeytool.logLevels` table specifying the level of the log message.
///  * `message` - a string containing the message to log.
///
/// Returns:
///  * None
///
/// Notes:
///  * This is wrapped in init.lua to provide the following shortcuts:
///    * `hs._asm.luaskinpokeytool.logBreadcrumb(msg)`
///    * `hs._asm.luaskinpokeytool.logVerbose(msg)`
///    * `hs._asm.luaskinpokeytool.logDebug(msg)`
///    * `hs._asm.luaskinpokeytool.logInfo(msg)`
///    * `hs._asm.luaskinpokeytool.logWarn(msg)`
///    * `hs._asm.luaskinpokeytool.logError(msg)`
///
///  * No matter what thread this function is invoked in, it will always send the logs to the primary LuaSkin (i.e. the Hammerspoon main LuaSkin instance).
static int classLogWithLevel(lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin() ; // [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER,
                    LS_TSTRING,
                    LS_TBREAK] ;
    NSString *message   = [skin toNSObjectAtIndex:2] ;

    switch(luaL_checkinteger(L, 1)) {
        case LS_LOG_BREADCRUMB: [LuaSkin logBreadcrumb:message] ; break ;
        case LS_LOG_VERBOSE:    [LuaSkin logVerbose:message] ; break ;
        case LS_LOG_DEBUG:      [LuaSkin logDebug:message] ; break ;
        case LS_LOG_INFO:       [LuaSkin logInfo:message] ; break ;
        case LS_LOG_WARN:       [LuaSkin logWarn:message] ; break ;
        case LS_LOG_ERROR:      [LuaSkin logError:message] ; break ;
        default:                return luaL_argerror(L, 1, "invalid level number specified") ;
    }
    return 1 ;
}

#pragma mark - Module Methods

/// hs._asm.luaskinpokeytool:NSHelperFunctions() -> table
/// Method
/// Returns a table containing the registered helper functions LuaSkin uses for converting NSObjects into a Lua usable form.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table with keys matching the NSObject classes registered as convertible into a form usable within the Lua environment of Hammerspoon.
///
/// Notes:
///  * The value for each key in the returned table contains a reference to the C-function behind the conversion tool and is probably not generally useful from the Lua side.
///  * This function does not invoke the targeted LuaSkin instance so this method should be thread-safe if examining a LuaSkin instance other than the one running on the current thread.
static int getRegisteredNSHelperFunctions(__unused lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin() ; // [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    LuaSkin *targetSkin = [skin toNSObjectAtIndex:1] ;

    BOOL isThreadVersion = [targetSkin isKindOfClass:NSClassFromString(@"LuaSkinThread")] ;
    if (isThreadVersion) {
        [skin pushNSObject:[targetSkin performSelector:@selector(registeredNSHelperFunctions)] withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    } else {
        [skin pushNSObject:registeredNSHelperFunctions withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    }
    return 1 ;
}

/// hs._asm.luaskinpokeytool:NSHelperLocations() -> table
/// Method
/// Returns a table containing the registered helper functions LuaSkin uses for converting NSObjects into a Lua usable form and information about the file/module which registered the function.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table with keys matching the NSObject classes registered as convertible into a form usable within the Lua environment of Hammerspoon.  The value of each key is the short-path captured in the lua traceback at the time at which the function was registered.
///
/// Notes:
///  * This function does not invoke the targeted LuaSkin instance so this method should be thread-safe if examining a LuaSkin instance other than the one running on the current thread.
///  * If you have modified the lua `require` function in a fashion other than what Hammerspoon does by default, the location information may be blank or wrong.  You can try adjusting the stack level used to capture this information by adjusting the undocumented Hammerspoon setting `HSLuaSkinRegisterRequireLevel` from its default value of 3 with `hs.settings`.  Generally, if you have "undone" the wrapping of `require` to include crashlytic log messages each time the function is invoked, you should try reducing this number, and if you have added your own wrapper to the `require` function, you should try increasing this number.
static int getRegisteredNSHelperLocations(__unused lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin() ; // [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    LuaSkin *targetSkin = [skin toNSObjectAtIndex:1] ;

    BOOL isThreadVersion = [targetSkin isKindOfClass:NSClassFromString(@"LuaSkinThread")] ;
    if (isThreadVersion) {
        [skin pushNSObject:[targetSkin performSelector:@selector(registeredNSHelperLocations)] withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    } else {
        [skin pushNSObject:registeredNSHelperLocations withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    }
    return 1 ;
}

/// hs._asm.luaskinpokeytool:luaHelperFunctions() -> table
/// Method
/// Returns a table containing the registered helper functions LuaSkin uses for converting lua objects and tables into NSObjects.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table with keys matching the NSObject types which are convertible from a lua format upon request by a module.
///
/// Notes:
///  * The value for each key in the returned table contains a reference to the C-function behind the conversion tool and is probably not generally useful from the Lua side.
///  * This function does not invoke the targeted LuaSkin instance so this method should be thread-safe if examining a LuaSkin instance other than the one running on the current thread.
static int getRegisteredLuaObjectHelperFunctions(__unused lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin() ; // [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    LuaSkin *targetSkin = [skin toNSObjectAtIndex:1] ;

    BOOL isThreadVersion = [targetSkin isKindOfClass:NSClassFromString(@"LuaSkinThread")] ;
    if (isThreadVersion) {
        [skin pushNSObject:[targetSkin performSelector:@selector(registeredLuaObjectHelperFunctions)] withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    } else {
        [skin pushNSObject:registeredLuaObjectHelperFunctions withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    }
    return 1 ;
}

/// hs._asm.luaskinpokeytool:luaHelperLocations() -> table
/// Method
/// Returns a table containing the registered helper functions LuaSkin uses for converting lua objects and tables into NSObjects and information about the file/module which registered the function.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table with keys matching the NSObject types which are convertible from a lua format upon request by a module.  The value of each key is the short-path captured in the lua traceback at the time at which the function was registered.
///
/// Notes:
///  * This function does not invoke the targeted LuaSkin instance so this method should be thread-safe if examining a LuaSkin instance other than the one running on the current thread.
///  * If you have modified the lua `require` function in a fashion other than what Hammerspoon does by default, the location information may be blank or wrong.  You can try adjusting the stack level used to capture this information by adjusting the undocumented Hammerspoon setting `HSLuaSkinRegisterRequireLevel` from its default value of 3 with `hs.settings`.  Generally, if you have "undone" the wrapping of `require` to include crashlytic log messages each time the function is invoked, you should try reducing this number, and if you have added your own wrapper to the `require` function, you should try increasing this number.
static int getRegisteredLuaObjectHelperLocations(__unused lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin() ; // [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    LuaSkin *targetSkin = [skin toNSObjectAtIndex:1] ;

    BOOL isThreadVersion = [targetSkin isKindOfClass:NSClassFromString(@"LuaSkinThread")] ;
    if (isThreadVersion) {
        [skin pushNSObject:[targetSkin performSelector:@selector(registeredLuaObjectHelperLocations)] withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    } else {
        [skin pushNSObject:registeredLuaObjectHelperLocations withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    }
    return 1 ;
}

/// hs._asm.luaskinpokeytool:luaUserdataMapping() -> table
/// Method
/// Returns a table containing userdata types which have a registered conversion function that can be automatically identified by LuaSkin during conversion, rather than requiring the module's coder to explicitly request the conversion function.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table with keys matching the userdata types which can be automatically identified by LuaSkin and value is the NSObject class that the userdata can be automatically converted to without explicit request by a module developer.
///
/// Notes:
///  * This function does not invoke the targeted LuaSkin instance so this method should be thread-safe if examining a LuaSkin instance other than the one running on the current thread.
static int getRegisteredLuaObjectHelperUserdataMappings(__unused lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin() ; // [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    LuaSkin *targetSkin = [skin toNSObjectAtIndex:1] ;

    BOOL isThreadVersion = [targetSkin isKindOfClass:NSClassFromString(@"LuaSkinThread")] ;
    if (isThreadVersion) {
        [skin pushNSObject:[targetSkin performSelector:@selector(registeredLuaObjectHelperUserdataMappings)] withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    } else {
        [skin pushNSObject:registeredLuaObjectHelperUserdataMappings withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
    }
    return 1 ;
}

/// hs._asm.luaskinpokeytool:maxNatIndex(table | index) -> integer
/// Method
/// Returns the maximum consecutive integer key, starting at 1, in the table specified.
///
/// Parameters:
///  * a table or index to a table in the target LuaSkin's stack
///
/// Returns:
///  * an integer specifying the largest integer key in the table, or 0 if there are no integer keys
///
/// Notes:
///  * If `hs._asm.luaskinpokeytool:maxNatIndex(X) == hs._asm.luaskinpokeytool:countNatIndex(X)` and neither is equal to zero, then it is safe to assume the table is a non-sparse array starting at index 1.  This logic is used within LuaSkin to determine if a lua table is best represented as an NSDictionary or NSArray during conversions.
///
///  * If the targetSkin and the currently active LuaSkin are identical, then a table argument is examined in place (i.e. as the method argument).
///  * If the targetSkin and the currently active LuaSkin are not the same, then a table argument causes the table to be copied into the targetSkin at the current global stack top and examined in the target skin.  Depending upon the conversion support functions currently available in the targetSkin, the table may not be identical to the table you supply.
///
///  * If you specify an index, then the index location in the targetSkin is verified to be a table, and if it is, this method examines that table.  Otherwise, an error is returned.
static int maxNatIndex(lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin() ; // [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNUMBER, LS_TBREAK] ;
    LuaSkin   *targetSkin = [skin toNSObjectAtIndex:1] ;
    lua_State *targetL    = [targetSkin L] ;

    lua_Integer result ;

    if ((lua_type(L, 2) == LUA_TTABLE) && [skin isEqualTo:targetSkin]) {
        result = [skin maxNatIndex:2] ;
    } else if (lua_type(L, 2) == LUA_TTABLE) {
        id obj = [skin toNSObjectAtIndex:2 withOptions:LS_NSUnsignedLongLongPreserveBits |
                                                       LS_NSDescribeUnknownTypes         |
                                                       LS_NSPreserveLuaStringExactly     |
                                                       LS_NSAllowsSelfReference] ;
        [targetSkin pushNSObject:obj withOptions:LS_NSUnsignedLongLongPreserveBits |
                                                 LS_NSDescribeUnknownTypes         |
                                                 LS_NSPreserveLuaStringExactly     |
                                                 LS_NSAllowsSelfReference] ;
        result = [targetSkin maxNatIndex:-1] ;
        lua_pop(L, 1) ;
    } else if (lua_type(targetL, (int)luaL_checkinteger(L, 2)) == LUA_TTABLE) {
        result = [targetSkin maxNatIndex:(int)luaL_checkinteger(L, 2)] ;
    } else {
        return luaL_argerror(L, 2, "expected table or index to a table in the targetSkin") ;
    }
    lua_pushinteger(L, result) ;
    return 1 ;
}

/// hs._asm.luaskinpokeytool:countNatIndex(table | index) -> integer
/// Method
/// Returns the number of keys of any type in the table specified.
///
/// Parameters:
///  * a table or index to a table in the target LuaSkin's stack
///
/// Returns:
///  * an integer specifying the number of keys in the table
///
/// Notes:
///  * If `hs._asm.luaskinpokeytool:maxNatIndex(X) == hs._asm.luaskinpokeytool:countNatIndex(X)` and neither is equal to zero, then it is safe to assume the table is a non-sparse array starting at index 1.  This logic is used within LuaSkin to determine if a lua table is best represented as an NSDictionary or NSArray during conversions.
///
///  * If the targetSkin and the currently active LuaSkin are identical, then a table argument is examined in place (i.e. as the method argument).
///  * If the targetSkin and the currently active LuaSkin are not the same, then a table argument causes the table to be copied into the targetSkin at the current global stack top and examined in the target skin.  Depending upon the conversion support functions currently available in the targetSkin, the table may not be identical to the table you supply.
///
///  * If you specify an index, then the index location in the targetSkin is verified to be a table, and if it is, this method examines that table.  Otherwise, an error is returned.
static int countNatIndex(lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin() ; // [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNUMBER, LS_TBREAK] ;
    LuaSkin *targetSkin = [skin toNSObjectAtIndex:1] ;
    lua_Integer result ;

    if ((lua_type(L, 2) == LUA_TTABLE) && [skin isEqualTo:targetSkin]) {
        result = [skin countNatIndex:2] ;
    } if ((lua_type(L, 2) == LUA_TTABLE) && [skin isEqualTo:targetSkin]) {
        id obj = [skin toNSObjectAtIndex:2 withOptions:LS_NSUnsignedLongLongPreserveBits |
                                                       LS_NSDescribeUnknownTypes         |
                                                       LS_NSPreserveLuaStringExactly     |
                                                       LS_NSAllowsSelfReference] ;
        [targetSkin pushNSObject:obj withOptions:LS_NSUnsignedLongLongPreserveBits |
                                                 LS_NSDescribeUnknownTypes         |
                                                 LS_NSPreserveLuaStringExactly     |
                                                 LS_NSAllowsSelfReference] ;
        result = [targetSkin countNatIndex:-1] ;
        lua_pop(L, 1) ;
    } else if (lua_type([targetSkin L], (int)luaL_checkinteger(L, 2)) == LUA_TTABLE) {
        result = [targetSkin countNatIndex:(int)luaL_checkinteger(L, 2)] ;
    } else {
        return luaL_argerror(L, 2, "expected table or index to a table in the targetSkin") ;
    }
    lua_pushinteger(L, result) ;
    return 1 ;
}

/// hs._asm.luaskinpokeytool:requireModule(moduleName) -> boolean
/// Method
/// Attempts to load the specified module into the target LuaSkin.
///
/// Parameters:
///  * the module to load
///
/// Returns:
///  * A boolean indicating whether or not the module was successfully loaded (true) or not (false)
///
/// Notes:
///  * This is probably a bad idea to use on a target LuaSkin other than the one that is currently active where this method is being invoked because some modules which are designed to work with a threaded LuaSkin use the current thread at the time of loading to store state information that is required for proper functioning when used in multiple environments.  If the module had not already been loaded, it may misidentify the proper thread.  I'm pondering possible work-arounds, since this actually seems like a useful tool to add to `hs._asm.luathread` proper...
static int requireModule(lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin() ; // [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    LuaSkin *targetSkin = [skin toNSObjectAtIndex:1] ;

    BOOL success = NO ;
    @try {
        success = [targetSkin requireModule:(char *)luaL_checkstring(L, 2)] ;
        lua_pop(L, 1) ;
    } @catch (NSException *theException) {
        NSString *error = [NSString stringWithFormat:@"exception %@:%@",
                                                      theException.name,
                                                      theException.reason] ;
        [skin logError:error] ;
        success = NO ;
    }
    lua_pushboolean(L, success) ;
    return 1 ;
}

/// hs._asm.luaskinpokeytool:logMessage(level, message, [asClass]) -> None
/// Method
/// Uses the target LuaSkin's logging methods to log a message.
///
/// Parameters:
///  * `level`   - an integer value from the `hs._asm.luaskinpokeytool.logLevels` table specifying the level of the log message.
///  * `message` - a string containing the message to log.
///
/// Returns:
///  * None
///
/// Notes:
///  * This is wrapped in init.lua to provide the following shortcuts:
///    * `hs._asm.luaskinpokeytool:logBreadcrumb(msg)`
///    * `hs._asm.luaskinpokeytool:logVerbose(msg)`
///    * `hs._asm.luaskinpokeytool:logDebug(msg)`
///    * `hs._asm.luaskinpokeytool:logInfo(msg)`
///    * `hs._asm.luaskinpokeytool:logWarn(msg)`
///    * `hs._asm.luaskinpokeytool:logError(msg)`
///
///  * I'm not sure how well this is going to work, since the same thread issue that `hs._asm.luaskinpokeytool:requireModule` has will come up with respect to the lua portion of the logging delegate.  However, I will test and ponder because this is another thing that seems like it might be useful to include in `hs._asm.luathread`.
static int logWithLevel(lua_State *L) {
    LuaSkin *skin = LST_getLuaSkin() ; // [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER,
                    LS_TSTRING,
                    LS_TBREAK] ;
    LuaSkin *targetSkin = [skin toNSObjectAtIndex:1] ;
    NSString *message   = [skin toNSObjectAtIndex:3] ;

    switch(luaL_checkinteger(L, 2)) {
        case LS_LOG_BREADCRUMB: [targetSkin logBreadcrumb:message] ; break ;
        case LS_LOG_VERBOSE:    [targetSkin logVerbose:message] ; break ;
        case LS_LOG_DEBUG:      [targetSkin logDebug:message] ; break ;
        case LS_LOG_INFO:       [targetSkin logInfo:message] ; break ;
        case LS_LOG_WARN:       [targetSkin logWarn:message] ; break ;
        case LS_LOG_ERROR:      [targetSkin logError:message] ; break ;
        default:
            [targetSkin logAtLevel:(int)luaL_checkinteger(L, 2) withMessage:message] ; break ;
    }
    return 1 ;
}

// re-examine everything now that we can get the thread from a LuaSkinThread object

// ?   - (NSString *)tracebackWithTag:(NSString *)theTag fromStackPos:(int)level ;
// ?   - (void)logAtLevel:(int)level withMessage:(NSString *)theMessage fromStackPos:(int)pos ;

// ?   - (BOOL)protectedCallAndTraceback:(int)nargs nresults:(int)nresults;
// ?   - (void)checkArgs:(int)firstArg, ...;
// ?   - (int)luaRef:(int)refTable;
// ?   - (int)luaRef:(int)refTable atIndex:(int)idx;
// ?   - (int)luaUnref:(int)refTable ref:(int)ref;
// ?   - (int)pushLuaRef:(int)refTable ref:(int)ref;

// possible to allow lua-based modules to be registered through these?  does that gain us anything for a lua-only module?
//     - (int)registerLibrary:(const luaL_Reg *)functions metaFunctions:(const luaL_Reg *)metaFunctions;
//     - (int)registerLibraryWithObject:(const char *)libraryName functions:(const luaL_Reg *)functions metaFunctions:(const luaL_Reg *)metaFunctions objectFunctions:(const luaL_Reg *)objectFunctions;
//     - (void)registerObject:(const char *)objectName objectFunctions:(const luaL_Reg *)objectFunctions;

// possible to allow lua-based conversion tools?  would you want to?
//     - (BOOL)registerPushNSHelper:(pushNSHelperFunction)helperFN forClass:(char *)className ;
//     - (BOOL)registerLuaObjectHelper:(luaObjectHelperFunction)helperFN forClass:(char *)className ;
//     - (BOOL)registerLuaObjectHelper:(luaObjectHelperFunction)helperFN forClass:(char *)className withUserdataMapping:(char *)userdataTag;

#pragma mark - Module Constants

static int pushLogLevels(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, LS_LOG_BREADCRUMB) ; lua_setfield(L, -2, "breadcrumb") ;
    lua_pushinteger(L, LS_LOG_VERBOSE) ;    lua_setfield(L, -2, "verbose") ;
    lua_pushinteger(L, LS_LOG_DEBUG) ;      lua_setfield(L, -2, "debug") ;
    lua_pushinteger(L, LS_LOG_INFO) ;       lua_setfield(L, -2, "info") ;
    lua_pushinteger(L, LS_LOG_WARN) ;       lua_setfield(L, -2, "warn") ;
    lua_pushinteger(L, LS_LOG_ERROR) ;      lua_setfield(L, -2, "error") ;
    return 1 ;
}

static int pushCheckArgumentTypes(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, LS_TBREAK) ;    lua_setfield(L, -2, "break") ;
    lua_pushinteger(L, LS_TOPTIONAL) ; lua_setfield(L, -2, "optional") ;
    lua_pushinteger(L, LS_TNIL) ;      lua_setfield(L, -2, "nil") ;
    lua_pushinteger(L, LS_TBOOLEAN) ;  lua_setfield(L, -2, "boolean") ;
    lua_pushinteger(L, LS_TNUMBER) ;   lua_setfield(L, -2, "number") ;
    lua_pushinteger(L, LS_TSTRING) ;   lua_setfield(L, -2, "string") ;
    lua_pushinteger(L, LS_TTABLE) ;    lua_setfield(L, -2, "table") ;
    lua_pushinteger(L, LS_TFUNCTION) ; lua_setfield(L, -2, "function") ;
    lua_pushinteger(L, LS_TUSERDATA) ; lua_setfield(L, -2, "userdata") ;
    lua_pushinteger(L, LS_TNONE) ;     lua_setfield(L, -2, "none") ;
    lua_pushinteger(L, LS_TANY) ;      lua_setfield(L, -2, "optional") ;
    lua_pushinteger(L, LS_TVARARG) ;   lua_setfield(L, -2, "vararg") ;
    lua_pushinteger(L, LS_TINTEGER) ;  lua_setfield(L, -2, "integer") ;
    return 1 ;
}

static int pushConversionOptions(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, LS_NSNone) ;                         lua_setfield(L, -2, "none") ;
    lua_pushinteger(L, LS_NSUnsignedLongLongPreserveBits) ; lua_setfield(L, -2, "unsignedLongLongPreserveBits") ;
    lua_pushinteger(L, LS_NSDescribeUnknownTypes) ;         lua_setfield(L, -2, "describeUnknownTypes") ;
    lua_pushinteger(L, LS_NSIgnoreUnknownTypes) ;           lua_setfield(L, -2, "ignoreUnknownTypes") ;
    lua_pushinteger(L, LS_NSPreserveLuaStringExactly) ;     lua_setfield(L, -2, "preserveLuaStringExactly") ;
    lua_pushinteger(L, LS_NSLuaStringAsDataOnly) ;          lua_setfield(L, -2, "luaStringAsDataOnly") ;
    lua_pushinteger(L, LS_NSAllowsSelfReference) ;          lua_setfield(L, -2, "allowsSelfReference") ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushLuaSkin(lua_State *L, id obj) {
    LuaSkin *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(LuaSkin *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toLuaSkinFromLua(lua_State *L, int idx) {
    LuaSkin *skin = LST_getLuaSkin() ; // [LuaSkin shared] ;
    LuaSkin *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge LuaSkin, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = LST_getLuaSkin() ; // [LuaSkin shared] ;
    LuaSkin *obj = [skin luaObjectAtIndex:1 toClass:"LuaSkin"] ;
    NSString *title = [obj isKindOfClass:NSClassFromString(@"LuaSkinThread")] ? @"LuaSkinThread" : @"LuaSkin" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = LST_getLuaSkin() ; // [LuaSkin shared] ;
        LuaSkin *obj1 = [skin luaObjectAtIndex:1 toClass:"LuaSkin"] ;
        LuaSkin *obj2 = [skin luaObjectAtIndex:2 toClass:"LuaSkin"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *obj = get_objectFromUserdata(__bridge_transfer LuaSkin, L, 1, USERDATA_TAG) ;
    if (obj) obj = nil ;
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
    {"NSHelperFunctions",   getRegisteredNSHelperFunctions},
    {"NSHelperLocations",   getRegisteredNSHelperLocations},
    {"luaHelperFunctions",  getRegisteredLuaObjectHelperFunctions},
    {"luaHelperLocations",  getRegisteredLuaObjectHelperLocations},
    {"luaUserdataMappings", getRegisteredLuaObjectHelperUserdataMappings},
    {"countN",              countNatIndex},
    {"maxN",                maxNatIndex},
    {"requireModule",       requireModule},
    {"logMessage",          logWithLevel},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"skin",            getLuaSkinObject},
    {"classLogMessage", classLogWithLevel},
    {NULL,              NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_luaskinpokeytool_internal(lua_State* __unused L) {
    LuaSkin *skin = LST_getLuaSkin() ; // [LuaSkin shared] ;

    LST_setRefTable(skin, USERDATA_TAG, refTable,
        [skin registerLibraryWithObject:USERDATA_TAG
                              functions:moduleLib
                          metaFunctions:nil
                        objectFunctions:userdata_metaLib]) ;

    [skin registerPushNSHelper:pushLuaSkin         forClass:"LuaSkin"];
    [skin registerLuaObjectHelper:toLuaSkinFromLua forClass:"LuaSkin"
                                        withUserdataMapping:USERDATA_TAG];

    pushLogLevels(L) ;          lua_setfield(L, -2, "logLevels") ;
    pushCheckArgumentTypes(L) ; lua_setfield(L, -2, "checkArgumentTypes") ;
    pushConversionOptions(L) ;  lua_setfield(L, -2, "conversionOptions") ;

    return 1;
}
