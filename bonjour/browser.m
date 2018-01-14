@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.bonjour.browser" ;
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

@interface ASMNetServiceBrowser : NSNetServiceBrowser <NSNetServiceBrowserDelegate>
@property int  callbackRef ;
@property int  selfRefCount ;
@end

@implementation ASMNetServiceBrowser

- (instancetype)init {
    self = [super init] ;
    if (self) {
        _callbackRef  = LUA_NOREF ;
        _selfRefCount = 0 ;

        self.delegate = self ;
    }
    return self ;
}

- (void)stop {
    [super stop] ;
    _callbackRef = [[LuaSkin shared] luaUnref:refTable ref:_callbackRef] ;
}

- (void)performCallbackWith:(id)argument {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin shared] ;
        lua_State *L    = skin.L ;
        int argCount    = 1 ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
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

- (void)netServiceBrowser:(__unused NSNetServiceBrowser *)browser
            didFindDomain:(NSString *)domainString
               moreComing:(BOOL)moreComing {
    [self performCallbackWith:@[@"domain", @(YES), domainString, @(moreComing)]] ;
}
- (void)netServiceBrowser:(__unused NSNetServiceBrowser *)browser
          didRemoveDomain:(NSString *)domainString
               moreComing:(BOOL)moreComing {
    [self performCallbackWith:@[@"domain", @(NO), domainString, @(moreComing)]] ;
}

- (void)netServiceBrowser:(__unused NSNetServiceBrowser *)browser
             didNotSearch:(NSDictionary *)errorDict {
    [self performCallbackWith:@[@"error", netServiceErrorToString(errorDict)]] ;
}

- (void)netServiceBrowser:(__unused NSNetServiceBrowser *)browser
           didFindService:(NSNetService *)service
               moreComing:(BOOL)moreComing {
    [self performCallbackWith:@[@"service", @(YES), service, @(moreComing)]] ;
}
- (void)netServiceBrowser:(__unused NSNetServiceBrowser *)browser
         didRemoveService:(NSNetService *)service
               moreComing:(BOOL)moreComing {
    [self performCallbackWith:@[@"service", @(NO), service, @(moreComing)]] ;
}

// - (void)netServiceBrowserDidStopSearch:(__unused NSNetServiceBrowser *)browser {
//     [self performCallbackWith:@"stop"] ;
// }
//
// - (void)netServiceBrowserWillSearch:(__unused NSNetServiceBrowser *)browser {
//     [self performCallbackWith:@"start"] ;
// }

@end

#pragma mark - Module Functions

static int browser_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    ASMNetServiceBrowser *browser = [[ASMNetServiceBrowser alloc] init] ;
    if (browser) {
        [skin pushNSObject:browser] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int browser_includesPeerToPeer(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMNetServiceBrowser *browser = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, browser.includesPeerToPeer) ;
    } else {
        browser.includesPeerToPeer = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int browser_searchForBrowsableDomains(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION, LS_TBREAK] ;
    ASMNetServiceBrowser *browser = [skin toNSObjectAtIndex:1] ;
    if (browser.callbackRef != LUA_NOREF) [browser stop] ;
    lua_pushvalue(L, 2) ;
    browser.callbackRef = [skin luaRef:refTable] ;
    [browser searchForBrowsableDomains] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int browser_searchForRegistrationDomains(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION, LS_TBREAK] ;
    ASMNetServiceBrowser *browser = [skin toNSObjectAtIndex:1] ;
    if (browser.callbackRef != LUA_NOREF) [browser stop] ;
    lua_pushvalue(L, 2) ;
    browser.callbackRef = [skin luaRef:refTable] ;
    [browser searchForRegistrationDomains] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int browser_searchForServices(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    ASMNetServiceBrowser *browser = [skin toNSObjectAtIndex:1] ;
    NSString *service = @"_services._dns-sd._udp." ;
    NSString *domain  = @"" ;
    switch(lua_gettop(L)) {
        case 2:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION, LS_TBREAK] ;
            break ;
        case 3:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TFUNCTION, LS_TBREAK] ;
            service = [skin toNSObjectAtIndex:2] ;
            break ;
//         case 4: // if it's less than 2 or greater than 4, this will error out, so... it's the default
        default:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TSTRING, LS_TFUNCTION, LS_TBREAK] ;
            service = [skin toNSObjectAtIndex:2] ;
            domain  = [skin toNSObjectAtIndex:3] ;
            break ;
    }
    if (browser.callbackRef != LUA_NOREF) [browser stop] ;
    lua_pushvalue(L, -1) ;
    browser.callbackRef = [skin luaRef:refTable] ;
    [browser searchForServicesOfType:service inDomain:domain] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int browser_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMNetServiceBrowser *browser = [skin toNSObjectAtIndex:1] ;
    [browser stop] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMNetServiceBrowser(lua_State *L, id obj) {
    ASMNetServiceBrowser *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMNetServiceBrowser *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toASMNetServiceBrowserFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMNetServiceBrowser *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMNetServiceBrowser, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMNetServiceBrowser *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMNetServiceBrowser"] ;
        ASMNetServiceBrowser *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMNetServiceBrowser"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMNetServiceBrowser *obj = get_objectFromUserdata(__bridge_transfer ASMNetServiceBrowser, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            obj.delegate = nil ;
            [obj stop] ; // stop does this for us: [skin luaUnref:refTable ref:obj.callbackRef] ;
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
    {"includesPeerToPeer",      browser_includesPeerToPeer},
    {"findBrowsableDomains",    browser_searchForBrowsableDomains},
    {"findRegistrationDomains", browser_searchForRegistrationDomains},
    {"findServices",            browser_searchForServices},
    {"stop",                    browser_stop},

    {"__tostring",              userdata_tostring},
    {"__eq",                    userdata_eq},
    {"__gc",                    userdata_gc},
    {NULL,                      NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", browser_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_bonjour_browser(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASMNetServiceBrowser         forClass:"ASMNetServiceBrowser"];
    [skin registerLuaObjectHelper:toASMNetServiceBrowserFromLua forClass:"ASMNetServiceBrowser"
                                                     withUserdataMapping:USERDATA_TAG];

    return 1;
}
