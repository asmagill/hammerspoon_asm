@import Cocoa ;
@import LuaSkin ;

@import notify ;

static const char * const USERDATA_TAG = "hs.darwinnotifications" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSDarwinNotification : NSObject
@property (readwrite) int      selfRefCount ;
@property (readonly)  NSString *name ;
@property (readonly)  int      token ;
@property (readwrite) int      callbackRef ;
@property (readonly)  BOOL     suspended ;
@end

@implementation HSDarwinNotification
- (instancetype)initWithName:(NSString *)name {
    self = [super init] ;
    if (self) {
        _selfRefCount = 0 ;
        _callbackRef  = LUA_NOREF ;
        _token        = NOTIFY_TOKEN_INVALID ;
        _name         = name ;
        _suspended    = NO ;
    }
    return self ;
}

- (uint32_t)start {
    uint32_t status = NOTIFY_STATUS_OK ;

    if (!notify_is_valid_token(_token)) {
        status = notify_register_dispatch(
            _name.UTF8String,
            &_token,
            dispatch_get_main_queue(),
            ^(int t) {
                [self callbackWithToken:t] ;
            }
        ) ;
    }
    if (status == NOTIFY_STATUS_OK) [self resume] ;

    return status ;
}

- (uint32_t)stop {
    uint32_t status = NOTIFY_STATUS_OK ;

    if (notify_is_valid_token(_token)) {
        status = notify_cancel(_token) ;
        if (status == NOTIFY_STATUS_OK) _token = NOTIFY_TOKEN_INVALID ;
    }
    return status ;
}

- (uint32_t)suspend {
    uint32_t status = NOTIFY_STATUS_OK ;

    if (!_suspended) {
        status = notify_suspend(_token) ;
        if (status == NOTIFY_STATUS_OK) _suspended = YES ;
    }
    return status ;
}

- (uint32_t)resume {
    uint32_t status = NOTIFY_STATUS_OK ;

    if (_suspended) {
        status = notify_resume(_token) ;
        if (status == NOTIFY_STATUS_OK) _suspended = NO ;
    }
    return status ;
}

- (void)callbackWithToken:(__unused int)t {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;

        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:self] ;
        [skin protectedCallAndError:[NSString stringWithUTF8String:USERDATA_TAG]
                              nargs:1
                           nresults:0] ;
    }
}

@end

static NSString *darwinnotifications_errorStringFor(uint32_t status) {
    switch(status) {
        case NOTIFY_STATUS_OK:               return @"no error" ;
        case NOTIFY_STATUS_INVALID_NAME:     return @"invalid name" ;
        case NOTIFY_STATUS_INVALID_TOKEN:    return @"invalid token" ;
        case NOTIFY_STATUS_INVALID_PORT:     return @"invalid port" ;
        case NOTIFY_STATUS_INVALID_FILE:     return @"invalid file" ;
        case NOTIFY_STATUS_INVALID_SIGNAL:   return @"invalid signal" ;
        case NOTIFY_STATUS_INVALID_REQUEST:  return @"an internal error occurred" ;
        case NOTIFY_STATUS_NOT_AUTHORIZED:   return @"not authorized" ;
        case NOTIFY_STATUS_OPT_DISABLE:      return @"an internal error occurred" ;
        case NOTIFY_STATUS_SERVER_NOT_FOUND: return @"server could not be found" ;
        case NOTIFY_STATUS_NULL_INPUT:       return @"null input" ;
        case NOTIFY_STATUS_FAILED:           return @"an internal failure of the library has occurred" ;
        default:
            return [NSString stringWithFormat:@"** unrecognized error code: %u", status] ;
    }
}

#pragma mark - Module Functions

static int darwinnotifications_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    NSString *name = [skin toNSObjectAtIndex:1] ;
    HSDarwinNotification *observer = [[HSDarwinNotification alloc] initWithName:name] ;
    if (observer) {
        [skin pushNSObject:observer] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int darwinnotifications_post(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    NSString *message = [skin toNSObjectAtIndex:1] ;
    uint32_t status = notify_post(message.UTF8String) ;

    if (status == NOTIFY_STATUS_OK) {
        lua_pushboolean(L, YES) ;
        return 1 ;
    } else {
        lua_pushnil(L) ;
        [skin pushNSObject:darwinnotifications_errorStringFor(status)] ;
        return 2 ;
    }
}

#pragma mark - Module Methods

static int darwinnotifications_token(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSDarwinNotification *observer = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, observer.token) ;
    return 1 ;
}

static int darwinnotifications_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSDarwinNotification *observer = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:observer.name] ;
    return 1 ;
}

static int darwinnotifications_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSDarwinNotification *observer = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (observer.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:observer.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        observer.callbackRef = [skin luaUnref:refTable ref:observer.callbackRef] ;
        if (!lua_isnil(L, 2)) observer.callbackRef = [skin luaRef:refTable atIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int darwinnotifications_state(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSDarwinNotification *observer = [skin toNSObjectAtIndex:1] ;

    uint32_t status = NOTIFY_STATUS_OK ;
    uint64_t stateValue = 0 ;

    if (lua_gettop(L) == 1) {
        status = notify_get_state(observer.token, &stateValue) ;
        if (status == NOTIFY_STATUS_OK) lua_pushinteger(L, (lua_Integer)stateValue) ;
    } else {
        stateValue = (uint64_t)lua_tointeger(L, 2) ;
        status = notify_set_state(observer.token, stateValue) ;
        if (status == NOTIFY_STATUS_OK) lua_pushvalue(L, 1) ;
    }
    if (status != NOTIFY_STATUS_OK) {
        lua_pushnil(L) ;
        [skin pushNSObject:darwinnotifications_errorStringFor(status)] ;
        return 2 ;
    }
    return 1 ;
}

static int darwinnotifications_start(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSDarwinNotification *observer = [skin toNSObjectAtIndex:1] ;

    uint32_t status = [observer start] ;
    if (status != NOTIFY_STATUS_OK) {
        lua_pushnil(L) ;
        [skin pushNSObject:darwinnotifications_errorStringFor(status)] ;
        return 2 ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int darwinnotifications_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSDarwinNotification *observer = [skin toNSObjectAtIndex:1] ;

    uint32_t status = [observer stop] ;
    if (status != NOTIFY_STATUS_OK) {
        lua_pushnil(L) ;
        [skin pushNSObject:darwinnotifications_errorStringFor(status)] ;
        return 2 ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int darwinnotifications_suspend(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSDarwinNotification *observer = [skin toNSObjectAtIndex:1] ;

    uint32_t status = [observer suspend] ;
    if (status != NOTIFY_STATUS_OK) {
        lua_pushnil(L) ;
        [skin pushNSObject:darwinnotifications_errorStringFor(status)] ;
        return 2 ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int darwinnotifications_resume(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSDarwinNotification *observer = [skin toNSObjectAtIndex:1] ;

    uint32_t status = [observer resume] ;
    if (status != NOTIFY_STATUS_OK) {
        lua_pushnil(L) ;
        [skin pushNSObject:darwinnotifications_errorStringFor(status)] ;
        return 2 ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int darwinnotifications_isValid(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSDarwinNotification *observer = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, notify_is_valid_token(observer.token)) ;
    return 1 ;
}

static int darwinnotifications_isSuspended(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSDarwinNotification *observer = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, observer.suspended) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSDarwinNotification(lua_State *L, id obj) {
    HSDarwinNotification *value = obj;

    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSDarwinNotification *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

static id toHSDarwinNotificationFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSDarwinNotification *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSDarwinNotification, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSDarwinNotification *obj = [skin luaObjectAtIndex:1 toClass:"HSDarwinNotification"] ;
    NSString *title = [NSString stringWithFormat:@"%@ (%@active%@)",
        obj.name,
        (notify_is_valid_token(obj.token) ? @"" : @"in"),
        (obj.suspended ? @", suspended" : @"")
    ] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSDarwinNotification *obj1 = [skin luaObjectAtIndex:1 toClass:"HSDarwinNotification"] ;
        HSDarwinNotification *obj2 = [skin luaObjectAtIndex:2 toClass:"HSDarwinNotification"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSDarwinNotification *obj = get_objectFromUserdata(__bridge_transfer HSDarwinNotification, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            if (notify_is_valid_token(obj.token)) [obj stop] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj = nil ;
        }

    }
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
    {"callback",    darwinnotifications_callback},
    {"isSuspended", darwinnotifications_isSuspended},
    {"isValid",     darwinnotifications_isValid},
    {"name",        darwinnotifications_name},
    {"resume",      darwinnotifications_resume},
    {"start",       darwinnotifications_start},
    {"state",       darwinnotifications_state},
    {"stop",        darwinnotifications_stop},
    {"suspend",     darwinnotifications_suspend},
    {"token",       darwinnotifications_token},

    {"__tostring",  userdata_tostring},
    {"__eq",        userdata_eq},
    {"__gc",        userdata_gc},
    {NULL,          NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",  darwinnotifications_new},
    {"post", darwinnotifications_post},
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs_libdarwinnotifications(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSDarwinNotification         forClass:"HSDarwinNotification"];
    [skin registerLuaObjectHelper:toHSDarwinNotificationFromLua forClass:"HSDarwinNotification"
                                                     withUserdataMapping:USERDATA_TAG];

    return 1;
}
