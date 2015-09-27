#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#define USERDATA_TAG        "hs._asm.bridging"
#define get_objectFromUserdata(objType, L, idx) (objType)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))

int refTable ;

static int pushAsObject(lua_State *L, id object) {
    void** idPtr = lua_newuserdata(L, sizeof(id)) ;
    *idPtr = (__bridge_retained void *)object ;
    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

/// hs._asm.bridging.NSLog(luavalue)
/// Function
/// Send a representation of the lua value passed in to the Console application via NSLog.
static int bridging_nslog(__unused lua_State* L) {
    id val = [[LuaSkin shared] toNSObjectAtIndex:1] ;
    NSLog(@"%@", val);
    return 0;
}

static int errorOnException(lua_State *L, NSException *theException) {
// NSLog(@"stack before examining exception: %d", lua_gettop(L)) ;
    [[LuaSkin shared] pushNSObject:theException] ;

    lua_getfield(L, -1, "name") ;
    lua_getfield(L, -2, "reason") ;
    lua_pushfstring(L, "%s: Exception:%s, %s", USERDATA_TAG, lua_tostring(L, -2), lua_tostring(L, -1)) ;
    lua_remove(L, -2) ;
    lua_remove(L, -2) ;
    lua_remove(L, -2) ;
// NSLog(@"stack after examining exception: %d (should be only 1 more)", lua_gettop(L)) ;
    return lua_error(L) ;
}

static int bridging_bridging(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK] ;
    NSString *className    = [[LuaSkin shared] toNSObjectAtIndex:1] ;
    NSString *selectorName = [[LuaSkin shared] toNSObjectAtIndex:2] ;

    if (NSClassFromString(className)) {
        if ([NSClassFromString(className) respondsToSelector:NSSelectorFromString(selectorName)]) {
            @try {
                pushAsObject(L, [NSClassFromString(className) performSelector:NSSelectorFromString(selectorName)]) ;
            }
            @catch ( NSException *theException ) {
                return errorOnException(L, theException) ;
            }
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"Class %@ does not respond to selector %@", className, selectorName] UTF8String]) ;
        }
    } else {
        return luaL_error(L, [[NSString stringWithFormat:@"Class %@ is not loaded or doesn't exist", className] UTF8String]) ;
    }

    return 1 ;
}

static int bridging_methodSignature(lua_State *L) {
    NSString *className    = [[LuaSkin shared] toNSObjectAtIndex:1] ;
    NSString *selectorName = [[LuaSkin shared] toNSObjectAtIndex:2] ;

    if (NSClassFromString(className)) {
        if ([NSClassFromString(className) respondsToSelector:NSSelectorFromString(selectorName)]) {
            @try {
                [[LuaSkin shared] pushNSObject:[NSClassFromString(className) methodSignatureForSelector:NSSelectorFromString(selectorName)]] ;
            }
            @catch ( NSException *theException ) {
                return errorOnException(L, theException) ;
            }
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"Class %@ does not respond to selector %@", className, selectorName] UTF8String]) ;
        }
    } else {
        return luaL_error(L, [[NSString stringWithFormat:@"Class %@ is not loaded or doesn't exist", className] UTF8String]) ;
    }

    return 1 ;
}

static int bridging_class(lua_State *L) {
    @try {
        id object = get_objectFromUserdata(__bridge id, L, 1) ;
        lua_pushstring(L, [NSStringFromClass([object class]) UTF8String]) ;
    }
    @catch ( NSException *theException ) {
        return errorOnException(L, theException) ;
    }
    return 1 ;
}

static int bridging_superclass(lua_State *L) {
    @try {
        id object = get_objectFromUserdata(__bridge id, L, 1) ;
        lua_pushstring(L, [NSStringFromClass([object superclass]) UTF8String]) ;
    }
    @catch ( NSException *theException ) {
        return errorOnException(L, theException) ;
    }
    return 1 ;
}

static int bridging_description(lua_State *L) {
    @try {
        id object = get_objectFromUserdata(__bridge id, L, 1) ;
        lua_pushstring(L, [[object description] UTF8String]) ;
    }
    @catch ( NSException *theException ) {
        return errorOnException(L, theException) ;
    }
    return 1 ;
}

static int bridging_debugDescription(lua_State *L) {
    @try {
        id object = get_objectFromUserdata(__bridge id, L, 1) ;
        lua_pushstring(L, [[object debugDescription] UTF8String]) ;
    }
    @catch ( NSException *theException ) {
        return errorOnException(L, theException) ;
    }
    return 1 ;
}

static int bridging_hash(lua_State *L) {
    @try {
        id object = get_objectFromUserdata(__bridge id, L, 1) ;
        lua_pushinteger(L, (lua_Integer)[object hash]) ;
    }
    @catch ( NSException *theException ) {
        return errorOnException(L, theException) ;
    }
    return 1 ;
}

static int bridging_value(lua_State *L) {
    @try {
        id object = get_objectFromUserdata(__bridge id, L, 1) ;
        [[LuaSkin shared] pushNSObject:object] ;
    }
    @catch ( NSException *theException ) {
        return errorOnException(L, theException) ;
    }
    return 1 ;
}

NSDictionary *threadInfo(NSThread *theThread) {
    NSMutableDictionary *theResults = [[NSMutableDictionary alloc] init] ;

    [theResults setObject:@([NSThread isMultiThreaded]) forKey:@"isMultiThreaded"] ;

    [theResults setObject:@([theThread isMainThread])   forKey:@"isMainThread"] ;
    [theResults setObject:@([theThread isExecuting])    forKey:@"isExecuting"] ;
    [theResults setObject:@([theThread isFinished])     forKey:@"isFinished"] ;
    [theResults setObject:@([theThread isCancelled])    forKey:@"isCancelled"] ;
    [theResults setObject:@([theThread stackSize])      forKey:@"stackSize"] ;
    [theResults setObject:@([theThread threadPriority]) forKey:@"threadPriority"] ;
    [theResults setObject:[theThread name]              forKey:@"name"] ;

    [theResults setObject:[[[NSThread currentThread] threadDictionary] copy]
                   forKey:@"threadDictionary"] ;

    if ([theThread isEqual:[NSThread currentThread]]) {
        [theResults setObject:[[NSThread callStackReturnAddresses] copy]
                       forKey:@"callStackReturnAddresses"] ;
        [theResults setObject:[[NSThread callStackSymbols] copy]
                       forKey:@"callStackSymbols"] ;
    }

    return [[NSDictionary alloc] initWithDictionary:theResults] ;
}

static int bridging_luaThreadInfo(__unused lua_State *L) {
    // probably main thread, but... I has ideas... plus I intend to use this via package.loadlib to share
    // the above function, so right now, who knows...
    [[LuaSkin shared] pushNSObject:threadInfo([NSThread currentThread])] ;
    return 1 ;
}

static int NSMethodSignature_toLua(lua_State *L, id obj) {
    NSMethodSignature *sig = obj ;
    lua_newtable(L) ;
      lua_pushstring(L, [sig methodReturnType]) ;                 lua_setfield(L, -2, "methodReturnType") ;
      lua_pushinteger(L, (lua_Integer)[sig methodReturnLength]) ; lua_setfield(L, -2, "methodReturnLength") ;
      lua_pushinteger(L, (lua_Integer)[sig frameLength]) ;        lua_setfield(L, -2, "frameLength") ;
      lua_pushinteger(L, (lua_Integer)[sig numberOfArguments]) ;  lua_setfield(L, -2, "numberOfArguments") ;
      lua_newtable(L) ;
        for (NSUInteger i = 0 ; i < [sig numberOfArguments] ; i++) {
            lua_pushstring(L, [sig getArgumentTypeAtIndex:i]) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
      lua_setfield(L, -2, "arguments") ;

    return 1 ;
}

static int NSException_toLua(lua_State *L, id obj) {
    NSException *theError = obj ;

    lua_newtable(L) ;
        [[LuaSkin shared] pushNSObject:[theError name]] ;                     lua_setfield(L, -2, "name") ;
        [[LuaSkin shared] pushNSObject:[theError reason]] ;                   lua_setfield(L, -2, "reason") ;
        [[LuaSkin shared] pushNSObject:[theError userInfo]] ;                 lua_setfield(L, -2, "userInfo") ;
        [[LuaSkin shared] pushNSObject:[theError callStackReturnAddresses]] ; lua_setfield(L, -2, "callStackReturnAddresses") ;
        [[LuaSkin shared] pushNSObject:[theError callStackSymbols]] ;         lua_setfield(L, -2, "callStackSymbols") ;
    return 1 ;
}

static int tryToRegisterHandlers(__unused lua_State *L) {
    [[LuaSkin shared] registerPushNSHelper:NSMethodSignature_toLua forClass:"NSMethodSignature"] ;
    [[LuaSkin shared] registerPushNSHelper:NSException_toLua       forClass:"NSException"] ;
    return 0 ;
}

#pragma mark - Lua Framework Stuff

static int userdata_tostring(lua_State* L) {
    @try {
        id object = get_objectFromUserdata(__bridge id, L, 1) ;

        lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG,
                                                                      [object debugDescription],
                                                                      object] UTF8String]) ;
    }
    @catch ( NSException *theException ) {
        return errorOnException(L, theException) ;
    }
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    @try {
        id object1 = get_objectFromUserdata(__bridge id, L, 1) ;
        id object2 = get_objectFromUserdata(__bridge id, L, 2) ;
        lua_pushboolean(L, [object1 isEqual:object2]) ;
    }
    @catch ( NSException *theException ) {
        return errorOnException(L, theException) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    id object = get_objectFromUserdata(__bridge_transfer id, L, 1) ;
    object = nil ;

// Clear the pointer so it's no longer dangling
    void** idPtr = lua_touserdata(L, 1);
    *idPtr = nil ;

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"class",            bridging_class},
    {"value",            bridging_value},
    {"superclass",       bridging_superclass},
    {"description",      bridging_description},
    {"debugDescription", bridging_debugDescription},
    {"hash",             bridging_hash},

    {"__tostring",       userdata_tostring},
    {"__eq",             userdata_eq},
    {"__gc",             userdata_gc},
    {NULL,               NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"NSLog",           bridging_nslog },
    {"bridging",        bridging_bridging},
    {"luaThreadInfo",   bridging_luaThreadInfo},
    {"methodSignature", bridging_methodSignature},
    {NULL,              NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
    {NULL,         NULL}
};


int luaopen_hs__asm_bridging_internal(lua_State* L) {
    refTable = [[LuaSkin shared] registerLibraryWithObject:USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:module_metaLib
                                           objectFunctions:userdata_metaLib];

    lua_pushcfunction(L, tryToRegisterHandlers) ;
    if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
        printToConsole(L, (char *)lua_tostring(L, -1)) ;
        lua_pop(L, 1) ;
    }

    return 1;
}
