// NOTE: We'll need to keep the store reference around for notification callbacks, so why
// does this crash or (when we're lucky) the store reference go stale?

#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <SystemConfiguration/SCDynamicStoreCopyDHCPInfo.h>

#define USERDATA_TAG    "hs._asm.dynamicstore"
static int              refTable          = LUA_NOREF;
static dispatch_queue_t dynamicStoreQueue = nil ;

#define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

typedef struct _dynamicstore_t {
    SCDynamicStoreRef storeObject;
    int               callbackRef ;
    int               selfRef ;
    BOOL              watcherEnabled ;
} dynamicstore_t;

static void doDynamicStoreCallback(__unused SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
    dynamicstore_t *theStoreStruct = (dynamicstore_t *)info ;
    if (theStoreStruct->callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            [skin pushLuaRef:refTable ref:theStoreStruct->callbackRef] ;
            [skin pushLuaRef:refTable ref:theStoreStruct->selfRef] ;
            if (changedKeys) {
                [skin pushNSObject:(__bridge NSArray *)changedKeys] ;
            } else {
                lua_pushnil(L) ;
            }
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s:error in Lua callback:%@",
                                                            USERDATA_TAG,
                                                            [skin toNSObjectAtIndex:-1]]] ;
                lua_pop(L, 1) ; // error string from pcall
            }
        }) ;
    }
}

#pragma mark - Module Functions

static int newStoreObject(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;

    NSString *theName = [[NSUUID UUID] UUIDString] ;

    dynamicstore_t *thePtr = lua_newuserdata(L, sizeof(dynamicstore_t)) ;
    memset(thePtr, 0, sizeof(dynamicstore_t)) ;

    SCDynamicStoreContext context = { 0, NULL, NULL, NULL, NULL };
    context.info = (void *)thePtr;
    SCDynamicStoreRef theStore = SCDynamicStoreCreate(kCFAllocatorDefault, (__bridge CFStringRef)theName, doDynamicStoreCallback, &context );
    if (theStore) {
        thePtr->storeObject    = CFRetain(theStore) ;
        thePtr->callbackRef    = LUA_NOREF ;
        thePtr->selfRef        = LUA_NOREF ;
        thePtr->watcherEnabled = NO ;

        luaL_getmetatable(L, USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
//         CFRelease(theStore) ;
    } else {
        return luaL_error(L, "unable to get dynamicStore reference:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int dynamicStoreContents(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    NSArray *keys ;
    BOOL keysIsPattern = NO ;
    if (lua_gettop(L) == 1) {
        keys = @[ @".*" ] ;
        keysIsPattern = YES ;
    } else if (lua_gettop(L) == 2) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
        keys = [skin toNSObjectAtIndex:2] ;
    } else {
        keys = [skin toNSObjectAtIndex:2] ;
        keysIsPattern = (BOOL)lua_toboolean(L, 3) ;
    }

    CFDictionaryRef results ;
    if (keysIsPattern) {
        results = SCDynamicStoreCopyMultiple (theStore, NULL, (__bridge CFArrayRef)keys);
    } else {
        results = SCDynamicStoreCopyMultiple (theStore, (__bridge CFArrayRef)keys, NULL);
    }
    if (results) {
        [skin pushNSObject:(__bridge NSDictionary *)results withOptions:(LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits)] ;
        CFRelease(results) ;
    } else {
        return luaL_error(L, "unable to get dynamicStore contents:%s", SCErrorString(SCError())) ;
    }
    CFRelease(theStore) ;

    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, theStore]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        SCDynamicStoreRef theStore1 = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;
        SCDynamicStoreRef theStore2 = get_structFromUserdata(dynamicstore_t, L, 2)->storeObject ;
        lua_pushboolean(L, CFEqual(theStore1, theStore2)) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin logDebug:@"dynamicstore GC"] ;
    dynamicstore_t* theStore = get_structFromUserdata(dynamicstore_t, L, 1) ;
    if (theStore->callbackRef != LUA_NOREF) {
        theStore->callbackRef = [skin luaUnref:refTable ref:theStore->callbackRef] ;
        SCDynamicStoreSetDispatchQueue(theStore->storeObject, NULL);
    }
    theStore->selfRef = [skin luaUnref:refTable ref:theStore->selfRef] ;

    CFRelease(theStore->storeObject) ;
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    dynamicStoreQueue = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"contents",   dynamicStoreContents},
    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"newStore", newStoreObject},
    {NULL,       NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs__asm_dynamicstore_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    dynamicStoreQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);

    return 1;
}
