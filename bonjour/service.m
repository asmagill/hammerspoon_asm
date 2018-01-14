@import Cocoa ;
@import LuaSkin ;

@import Darwin.POSIX.netinet.in ;
@import Darwin.POSIX.netdb ;

static const char * const USERDATA_TAG = "hs._asm.bonjour.service" ;
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static NSString *netServiceErrorToString(NSDictionary *error) {
    NSString *message = [NSString stringWithFormat:@"unrecognized error dictionary:%@", error] ;

    NSNumber *errorCode   = error[NSNetServicesErrorCode] ;
//     NSNumber *errorDomain = error[NSNetServicesErrorDomain] ;
    if (errorCode) {
        switch (errorCode.intValue) {
            case NSNetServicesActivityInProgress:
                message = @"activity in progress; cannot process new request" ;
                break ;
            case NSNetServicesBadArgumentError:
                message = @"invalid argument" ;
                break ;
            case NSNetServicesCancelledError:
                message = @"request was cancelled" ;
                break ;
            case NSNetServicesCollisionError:
                message = @"name already in use" ;
                break ;
            case NSNetServicesInvalidError:
                message = @"service improperly configured" ;
                break ;
            case NSNetServicesNotFoundError:
                message = @"service could not be found" ;
                break ;
            case NSNetServicesTimeoutError:
                message = @"timed out" ;
                break ;
            case NSNetServicesUnknownError:
                message = @"an unknown error has occurred" ;
                break ;
            default:
                message = [NSString stringWithFormat:@"unrecognized error code:%@", errorCode] ;
        }
    }
    return message ;
}

@interface ASMNetServiceWrapper : NSObject <NSNetServiceDelegate>
@property NSNetService *service ;
@property int          callbackRef ;
@property int          monitorCallbackRef ;
@property int          selfRefCount ;
// stupid macOS API will cause an exception if we try to publish a discovered service (or one created to
// be resolved) but won't give us a method telling us which it is, so we'll have to track on our own and
// assume that if this module didn't create it, we can't publish it.
@property BOOL         canPublish ;
@end

@implementation ASMNetServiceWrapper

- (instancetype)initWithService:(NSNetService *)service {
    self = [super init] ;
    if (self && service) {
        _service            = service ;
        _callbackRef        = LUA_NOREF ;
        _monitorCallbackRef = LUA_NOREF ;
        _selfRefCount       = 0 ;
        _canPublish         = NO ;

        service.delegate = self ;
    }
    return self ;
}

- (void)performCallbackWith:(id)argument usingCallback:(int)fnRef {
    if (fnRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin shared] ;
        lua_State *L    = skin.L ;
        int argCount    = 1 ;
        [skin pushLuaRef:refTable ref:fnRef] ;
        [skin pushNSObject:self] ;
        if (argument) {
            if ([argument isKindOfClass:[NSArray class]]) {
                NSArray *args = (NSArray *)argument ;
                for (id obj in args) [skin pushNSObject:obj withOptions:LS_NSDescribeUnknownTypes] ;
                argCount += args.count ;
            } else {
                [skin pushNSObject:argument withOptions:LS_NSDescribeUnknownTypes] ;
                argCount++ ;
            }
        }
        if (![skin protectedCallAndTraceback:argCount nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:callback error:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
            lua_pop(L, -1) ;
        }
    }
}

#pragma mark * Delegate Methods

- (void)netServiceDidPublish:(__unused NSNetService *)sender {
    [self performCallbackWith:@"published" usingCallback:_callbackRef] ;
}

- (void)netService:(__unused NSNetService *)sender didNotPublish:(NSDictionary *)errorDict {
    if (_callbackRef != LUA_NOREF) {
        [self performCallbackWith:@[@"error", netServiceErrorToString(errorDict)]
                    usingCallback:_callbackRef] ;
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:publish error:%@", USERDATA_TAG, netServiceErrorToString(errorDict)]] ;
    }
}

- (void)netServiceDidResolveAddress:(__unused NSNetService *)sender {
    [self performCallbackWith:@"resolved" usingCallback:_callbackRef] ;
}

- (void)netService:(__unused NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    if (_callbackRef != LUA_NOREF) {
        [self performCallbackWith:@[@"error", netServiceErrorToString(errorDict)]
                    usingCallback:_callbackRef] ;
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:resolve error:%@", USERDATA_TAG, netServiceErrorToString(errorDict)]] ;
    }
}

// we clear the callback before stopping, but resolveWithTimeout uses this for indicating that the
// timeout has been reached.
- (void)netServiceDidStop:(__unused NSNetService *)sender {
    [self performCallbackWith:@"stop" usingCallback:_callbackRef] ;
}

// - (void)netServiceWillPublish:(__unused NSNetService *)sender {
//     [self performCallbackWith:@"publish" usingCallback:_callbackRef] ;
// }
//
// - (void)netServiceWillResolve:(__unused NSNetService *)sender {
//     [self performCallbackWith:@"resolve" usingCallback:_callbackRef] ;
// }
//
// - (void)netService:(NSNetService *)sender didAcceptConnectionWithInputStream:(NSInputStream *)inputStream
//                                                                 outputStream:(NSOutputStream *)outputStream;

- (void)netService:(__unused NSNetService *)sender didUpdateTXTRecordData:(NSData *)data {
    [self performCallbackWith:@[@"txtRecord", [NSNetService dictionaryFromTXTRecordData:data]]
                usingCallback:_monitorCallbackRef] ;
}

@end

#pragma mark - Module Functions

// - (instancetype)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name;
// - (instancetype)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name port:(int)port;

static int service_newForResolve(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *name   = [skin toNSObjectAtIndex:1] ;
    NSString *type   = [skin toNSObjectAtIndex:2] ;
    NSString *domain = (lua_gettop(L) > 2) ? [skin toNSObjectAtIndex:3] : @"" ;
    NSNetService *service = [[NSNetService alloc] initWithDomain:domain type:type name:name] ;
    if (service) {
        ASMNetServiceWrapper *wrapper = [[ASMNetServiceWrapper alloc] initWithService:service] ;
        if (wrapper) {
            [skin pushNSObject:wrapper] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int service_newForPublish(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TNUMBER | LS_TINTEGER, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *name   = [skin toNSObjectAtIndex:1] ;
    NSString *type   = [skin toNSObjectAtIndex:2] ;
    int      port    = (int)lua_tointeger(L, 3) ;
    NSString *domain = (lua_gettop(L) > 3) ? [skin toNSObjectAtIndex:4] : @"" ;
    NSNetService *service = [[NSNetService alloc] initWithDomain:domain type:type name:name port:port] ;
    if (service) {
        ASMNetServiceWrapper *wrapper = [[ASMNetServiceWrapper alloc] initWithService:service] ;
        if (wrapper) {
            wrapper.canPublish = YES ;
            [skin pushNSObject:wrapper] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int service_addresses(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;

    lua_newtable(L) ;
    NSArray *addresses = wrapper.service.addresses ;
    if (addresses) {
        for (NSData *thisAddr in addresses) {
            int  err;
            char addrStr[NI_MAXHOST];
            err = getnameinfo((const struct sockaddr *) [thisAddr bytes], (socklen_t) [thisAddr length], addrStr, sizeof(addrStr), NULL, 0, NI_NUMERICHOST | NI_WITHSCOPEID | NI_NUMERICSERV);
            if (err == 0) {
                lua_pushstring(L, addrStr) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            } else {
                lua_pushfstring(L, "** error:%s", gai_strerror(err)) ;
            }
        }
    }
    return 1 ;
}

static int service_domain(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:wrapper.service.domain] ;
    return 1 ;
}

static int service_name(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:wrapper.service.name] ;
    return 1 ;
}

static int service_hostName(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:wrapper.service.hostName] ;
    return 1 ;
}

static int service_type(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:wrapper.service.type] ;
    return 1 ;
}

static int service_port(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, wrapper.service.port) ;
    return 1 ;
}

static int service_TXTRecordData(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        NSData *txtRecord = wrapper.service.TXTRecordData ;
        if (txtRecord) {
            [skin pushNSObject:[NSNetService dictionaryFromTXTRecordData:txtRecord] withOptions:LS_NSDescribeUnknownTypes] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        NSData *txtRecord = nil ;
        if (lua_type(L, 2) == LUA_TTABLE) {
            NSDictionary *dict   = [skin toNSObjectAtIndex:2 withOptions:LS_NSPreserveLuaStringExactly] ;
            NSString     *errMsg = nil ;
            if ([dict isKindOfClass:[NSDictionary class]]) {
                for (NSString* key in dict) {
                    id value = [dict objectForKey:key] ;
                    if (![key isKindOfClass:[NSString class]]) {
                        errMsg = [NSString stringWithFormat:@"table key %@ is not a string", key] ;
                    } else if (!([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSData class]])) {
                        errMsg = [NSString stringWithFormat:@"value for key %@ must be a string", key] ;
                    }
                }
            } else {
                errMsg = @"expected table of key-value pairs" ;
            }
            if (errMsg) return luaL_argerror(L, 2, errMsg.UTF8String) ;
            txtRecord = [NSNetService dataFromTXTRecordDictionary:dict] ;
        }
        if ([wrapper.service setTXTRecordData:txtRecord]) {
            lua_pushvalue(L, 1) ;
        } else {
            lua_pushboolean(L, NO) ;
        }
    }
    return 1 ;
}

static int service_includesPeerToPeer(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, wrapper.service.includesPeerToPeer) ;
    } else {
        wrapper.service.includesPeerToPeer = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// - (BOOL)getInputStream:(out NSInputStream * _Nullable *)inputStream outputStream:(out NSOutputStream * _Nullable *)outputStream;

static int service_publish(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    ASMNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    if (!wrapper.canPublish) return luaL_error(L, "can't publish a service created for resolution") ;

    BOOL allowRename = YES ;
    BOOL hasFunction = NO ;
    switch(lua_gettop(L)) {
        case 1:
            break ;
        case 2:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TBOOLEAN, LS_TBREAK] ;
            hasFunction = (BOOL)(lua_type(L, 2) != LUA_TBOOLEAN) ;
            if (!hasFunction) allowRename = (BOOL)lua_toboolean(L, 2) ;
            break ;
//      case 3: // if it's less than 2 or greater than 3, this will error out, so... it's the default
        default:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN, LS_TFUNCTION, LS_TBREAK] ;
            hasFunction = YES ;
            allowRename = (BOOL)lua_toboolean(L, 2) ;
            break ;
    }

    wrapper.callbackRef = [skin luaUnref:refTable ref:wrapper.callbackRef] ;
    [wrapper.service stop] ;
    if (hasFunction) {
        lua_pushvalue(L, -1) ;
        wrapper.callbackRef = [skin luaRef:refTable] ;
    }

    [wrapper.service publishWithOptions:(allowRename ? 0 : NSNetServiceNoAutoRename)] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int service_resolveWithTimeout(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    ASMNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    if (wrapper.canPublish) return luaL_error(L, "can't resolve a service created for publishing") ;
    // well, technically it won't crash like publishing a service created for resolving will, but
    // it will either timeout/fail because there is nothing out there, or it will get *our* address
    // if we published and then stopped because we're still in someone's cache. The result is
    // not useful, either way.

    NSTimeInterval duration = 0.0 ;
    BOOL           hasFunction = false ;
    switch(lua_gettop(L)) {
        case 1:
            break ;
        case 2:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNUMBER, LS_TBREAK] ;
            hasFunction = (BOOL)(lua_type(L, 2) != LUA_TNUMBER) ;
            if (!hasFunction) duration = lua_tonumber(L, 2) ;
            break ;
//      case 3: // if it's less than 2 or greater than 3, this will error out, so... it's the default
        default:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TFUNCTION, LS_TBREAK] ;
            hasFunction = YES ;
            duration = lua_tonumber(L, 2) ;
            break ;
    }

    wrapper.callbackRef = [skin luaUnref:refTable ref:wrapper.callbackRef] ;
    [wrapper.service stop] ;
    if (hasFunction) {
        lua_pushvalue(L, -1) ;
        wrapper.callbackRef = [skin luaRef:refTable] ;
    }

    [wrapper.service resolveWithTimeout:duration] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int service_startMonitoring(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TOPTIONAL, LS_TBREAK] ;
    ASMNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;

    wrapper.monitorCallbackRef = [skin luaUnref:refTable ref:wrapper.monitorCallbackRef] ;
    [wrapper.service stopMonitoring] ;
    if (lua_gettop(L) == 2) {
        lua_pushvalue(L, -1) ;
        wrapper.monitorCallbackRef = [skin luaRef:refTable] ;
    }

    [wrapper.service startMonitoring] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int service_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    wrapper.callbackRef = [skin luaUnref:refTable ref:wrapper.callbackRef] ;
    [wrapper.service stop] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int service_stopMonitoring(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    wrapper.monitorCallbackRef = [skin luaUnref:refTable ref:wrapper.monitorCallbackRef] ;
    [wrapper.service stopMonitoring] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMNetServiceWrapper(lua_State *L, id obj) {
    ASMNetServiceWrapper *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMNetServiceWrapper *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toASMNetServiceWrapperFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMNetServiceWrapper *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMNetServiceWrapper, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSNetService(lua_State *L, id obj) {
    ASMNetServiceWrapper *value = [[ASMNetServiceWrapper alloc] initWithService:obj] ;
    if (value) {
        [[LuaSkin shared] pushNSObject:value] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMNetServiceWrapper *obj = [skin luaObjectAtIndex:1 toClass:"ASMNetServiceWrapper"] ;
    NSString *title = [NSString stringWithFormat:@"%@ (%@%@)", obj.service.name, obj.service.type, obj.service.domain] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMNetServiceWrapper *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMNetServiceWrapper"] ;
        ASMNetServiceWrapper *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMNetServiceWrapper"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMNetServiceWrapper *obj = get_objectFromUserdata(__bridge_transfer ASMNetServiceWrapper, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin shared] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.monitorCallbackRef = [skin luaUnref:refTable ref:obj.monitorCallbackRef] ;
            obj.service.delegate = nil ;
            [obj.service stop] ;
            [obj.service stopMonitoring] ;
            obj.service = nil ;
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
    {"addresses",          service_addresses},
    {"domain",             service_domain},
    {"name",               service_name},
    {"hostname",           service_hostName},
    {"type",               service_type},
    {"port",               service_port},
    {"txtRecord",          service_TXTRecordData},
    {"includesPeerToPeer", service_includesPeerToPeer},
    {"resolve",            service_resolveWithTimeout},
    {"monitor",            service_startMonitoring},
    {"stop",               service_stop},
    {"stopMonitoring",     service_stopMonitoring},
    {"publish",            service_publish},

    {"__tostring",         userdata_tostring},
    {"__eq",               userdata_eq},
    {"__gc",               userdata_gc},
    {NULL,                 NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"remote", service_newForResolve},
    {"new",    service_newForPublish},
    {NULL,     NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_bonjour_service(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASMNetServiceWrapper         forClass:"ASMNetServiceWrapper"];
    [skin registerLuaObjectHelper:toASMNetServiceWrapperFromLua forClass:"ASMNetServiceWrapper"
                                             withUserdataMapping:USERDATA_TAG];

    [skin registerPushNSHelper:pushNSNetService forClass:"NSNetService"];

    return 1;
}
