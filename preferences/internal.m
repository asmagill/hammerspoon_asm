@import Cocoa ;
@import LuaSkin ;
@import SystemConfiguration ;

static const char * const USERDATA_TAG     = "hs._asm.preferences" ;
static int                refTable         = LUA_NOREF ;
static dispatch_queue_t   preferencesQueue = nil ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSASMPreferencesObject : NSObject
@property SCPreferencesRef prefObject ;
@property int              callbackRef ;
@property int              selfRefCount ;
@property BOOL             watcherEnabled ;
@end

@implementation HSASMPreferencesObject

- (instancetype)initWithName:(NSString *)name prefsID:(NSString *)prefsID {
    self = [super init] ;
    if (self) {
        SCPreferencesRef po = SCPreferencesCreate(kCFAllocatorDefault, (__bridge CFStringRef)name, (__bridge CFStringRef)prefsID) ;
        if (po) {
                               // This is the observed behavior, but I can't find docs to confirm:
            _prefObject = po ; //   can be stored in property but doesn't do a new retain, so don't release it
                               //   NULLing it in __gc will release it, though, so don't do a CFRelease there...

            _callbackRef    = LUA_NOREF ;
            _selfRefCount   = 0 ;
            _watcherEnabled = NO ;
        } else {
            [LuaSkin logError:[NSString stringWithFormat:@"%s.open - error getting preferences reference:%s", USERDATA_TAG, SCErrorString(SCError())]] ;
            self = nil ;
        }
    }
    return self ;
}

@end

static void preferencesWatcherCallback(__unused SCPreferencesRef prefs, SCPreferencesNotification notificationType, void *info) {
    HSASMPreferencesObject *self = (__bridge HSASMPreferencesObject *)info ;

    if (self.callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            [skin pushLuaRef:refTable ref:self.callbackRef] ;
            [skin pushNSObject:self] ;
            switch(notificationType ) {
                case kSCPreferencesNotificationCommit: [skin pushNSObject:@"commit"] ; break ;
                case kSCPreferencesNotificationApply:  [skin pushNSObject:@"apply"]  ; break ;
                default:
                    [skin pushNSObject:[NSString stringWithFormat:@"unrecognized notification:%d", notificationType]] ;
                    break ;
            }
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s:callback error:%@", USERDATA_TAG, [skin toNSObjectAtIndex:-1]]] ;
                lua_pop(L, 1) ;
            }
        }) ;
    }
}

#pragma mark - Module Functions

static int newPreferencesObject(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *prefsID = (lua_gettop(L) == 0) ? nil : [[skin toNSObjectAtIndex:1] stringByExpandingTildeInPath] ;
    NSString *name    = [[NSUUID UUID] UUIDString] ;
    HSASMPreferencesObject *obj = [[HSASMPreferencesObject alloc] initWithName:name prefsID:prefsID] ;
    if (obj) {
        [skin pushNSObject:obj] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int preferencesKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMPreferencesObject *obj = [skin toNSObjectAtIndex:1] ;
    CFArrayRef results = SCPreferencesCopyKeyList(obj.prefObject) ;
    if (results) {
        [skin pushNSObject:(__bridge NSArray *)results withOptions:(LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits)] ;
        CFRelease(results) ;
    } else {
        return luaL_error(L, "error getting keys:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

static int preferencesSignature(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMPreferencesObject *obj = [skin toNSObjectAtIndex:1] ;

    CFDataRef results = SCPreferencesGetSignature(obj.prefObject) ;
    if (results) {
        [skin pushNSObject:(__bridge NSData *)results] ;
        CFRelease(results) ;
    } else {
        return luaL_error(L, "error getting signature:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

static int preferencesValueForKey(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    HSASMPreferencesObject *obj = [skin toNSObjectAtIndex:1] ;
    luaL_tolstring(L, 2, NULL) ; // force into string
    NSString *keyName = [skin toNSObjectAtIndex:-1] ;
    lua_pop(L, 1) ;

    SCPreferencesLock(obj.prefObject, true) ;
    CFPropertyListRef theValue = SCPreferencesGetValue(obj.prefObject, (__bridge CFStringRef)keyName) ;
    SCPreferencesUnlock(obj.prefObject) ;

    if (theValue) {
        CFTypeID theType = CFGetTypeID(theValue) ;
        if (theType == CFDataGetTypeID())            { [skin pushNSObject:(__bridge NSData *)theValue] ; }
        else if (theType == CFStringGetTypeID())     { [skin pushNSObject:(__bridge NSString *)theValue] ; }
        else if (theType == CFArrayGetTypeID())      { [skin pushNSObject:(__bridge NSArray *)theValue] ; }
        else if (theType == CFDictionaryGetTypeID()) { [skin pushNSObject:(__bridge NSDictionary *)theValue] ; }
        else if (theType == CFDateGetTypeID())       { [skin pushNSObject:(__bridge NSDate *)theValue] ; }
        else if (theType == CFBooleanGetTypeID())    { [skin pushNSObject:(__bridge NSNumber *)theValue] ; }
        else if (theType == CFNumberGetTypeID())     { [skin pushNSObject:(__bridge NSNumber *)theValue] ; }
        else { [skin pushNSObject:[NSString stringWithFormat:@"** invalid CF type %lu", theType]] ; }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int preferencesValueForPath(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    HSASMPreferencesObject *obj = [skin toNSObjectAtIndex:1] ;
    luaL_tolstring(L, 2, NULL) ; // force into string
    NSString *pathName = [skin toNSObjectAtIndex:-1] ;
    lua_pop(L, 1) ;

    SCPreferencesLock(obj.prefObject, true) ;
    CFDictionaryRef theValue = SCPreferencesPathGetValue(obj.prefObject, (__bridge CFStringRef)pathName) ;
    SCPreferencesUnlock(obj.prefObject) ;

    if (theValue) {
        [skin pushNSObject:(__bridge NSDictionary *)theValue] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int preferencesLinkForPath(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    HSASMPreferencesObject *obj = [skin toNSObjectAtIndex:1] ;
    luaL_tolstring(L, 2, NULL) ; // force into string
    NSString *pathName = [skin toNSObjectAtIndex:-1] ;
    lua_pop(L, 1) ;

    SCPreferencesLock(obj.prefObject, true) ;
    CFStringRef theValue = SCPreferencesPathGetLink(obj.prefObject, (__bridge CFStringRef)pathName) ;
    SCPreferencesUnlock(obj.prefObject) ;

    if (theValue) {
        [skin pushNSObject:(__bridge NSString *)theValue] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int preferencesCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMPreferencesObject *obj = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            obj.callbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (obj.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:obj.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int preferencesStartWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMPreferencesObject *obj = [skin toNSObjectAtIndex:1] ;

    if (!obj.watcherEnabled) {
        SCPreferencesContext context = { 0, (__bridge void *)obj, NULL, NULL, NULL } ;
        if (SCPreferencesSetCallback(obj.prefObject, preferencesWatcherCallback, &context)) {
            if (SCPreferencesSetDispatchQueue(obj.prefObject, preferencesQueue)) {
                obj.watcherEnabled = YES ;
            } else {
                SCPreferencesSetCallback(obj.prefObject, NULL, NULL) ;
                return luaL_error(L, "error setting watcher dispatch queue:%s", SCErrorString(SCError())) ;
            }
        } else {
            return luaL_error(L, "error setting watcher callback:%s", SCErrorString(SCError())) ;
        }
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int preferencesStopWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMPreferencesObject *obj = [skin toNSObjectAtIndex:1] ;

    SCPreferencesSetCallback(obj.prefObject, NULL, NULL) ;
    SCPreferencesSetDispatchQueue(obj.prefObject, NULL) ;
    obj.watcherEnabled = NO ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSASMPreferencesObject(lua_State *L, id obj) {
    HSASMPreferencesObject *value = obj ;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSASMPreferencesObject *)) ;
    *valuePtr = (__bridge_retained void *)value ;
    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static id toHSASMPreferencesObjectFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMPreferencesObject *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSASMPreferencesObject, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
//     HSASMPreferencesObject *obj = [skin luaObjectAtIndex:1 toClass:"HSASMPreferencesObject"] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSASMPreferencesObject *obj1 = [skin luaObjectAtIndex:1 toClass:"HSASMPreferencesObject"] ;
        HSASMPreferencesObject *obj2 = [skin luaObjectAtIndex:2 toClass:"HSASMPreferencesObject"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSASMPreferencesObject *obj = get_objectFromUserdata(__bridge_transfer HSASMPreferencesObject, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin shared] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            SCPreferencesSetCallback(obj.prefObject, NULL, NULL) ;
            SCPreferencesSetDispatchQueue(obj.prefObject, NULL) ;
            // see notes in init method above
            obj.prefObject = NULL ;
        }
        obj = nil ;
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    preferencesQueue = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"keys",         preferencesKeys},
    {"signature",    preferencesSignature},
    {"valueForKey",  preferencesValueForKey},
    {"valueForPath", preferencesValueForPath},
    {"linkForPath",  preferencesLinkForPath},
    {"callback",     preferencesCallback},
    {"start",        preferencesStartWatcher},
    {"stop",         preferencesStopWatcher},

    {"__tostring",   userdata_tostring},
    {"__eq",         userdata_eq},
    {"__gc",         userdata_gc},
    {NULL,           NULL}
} ;

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"open", newPreferencesObject},
    {NULL,   NULL}
} ;

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
} ;

int luaopen_hs__asm_preferences_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib] ;

    preferencesQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0) ;

    [skin registerPushNSHelper:pushHSASMPreferencesObject         forClass:"HSASMPreferencesObject"] ;
    [skin registerLuaObjectHelper:toHSASMPreferencesObjectFromLua forClass:"HSASMPreferencesObject"
                                                       withUserdataMapping:USERDATA_TAG] ;

    return 1 ;
}
