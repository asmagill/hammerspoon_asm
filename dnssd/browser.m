@import Cocoa ;
@import LuaSkin ;

@import dnssd ;

static const char * const USERDATA_TAG = "hs._asm.dnssd.browser" ;
static int refTable   = LUA_NOREF;
static int helpersRef = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

enum t_domainTypes {
    forBrowsing    = kDNSServiceFlagsBrowseDomains,
    forRegistering = kDNSServiceFlagsRegistrationDomains,
} ;

#pragma mark - Support Functions and Classes

static int dnssd_registerHelpers(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;

    lua_pushvalue(L, 1) ;
    helpersRef = [skin luaRef:refTable] ;
    [skin logInfo:[NSString stringWithFormat:@"registered helpers as %d in %d", helpersRef, refTable]] ;
    return 0 ;
}

static int dnssd_error_stringToLuaStack(lua_State *L, DNSServiceErrorType err) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin pushLuaRef:refTable ref:helpersRef] ;
    lua_getfield(L, -1, "_errorList") ;
    lua_remove(L, -2) ;                             // remove helpersRef
    lua_pushinteger(L, err) ;
    if (lua_gettable(L, -2) == LUA_TNIL) {          // eats err, so no remove necessary
        lua_pop(L, 1) ;                             // remove nil and replace with...
        lua_pushfstring(L, "unrecognized error code: %d", err) ;
    }
    lua_remove(L, -2) ;                             // remove _errorList
    return 1 ;
}

static int dnssd_interfaceName_stringToLuaStack(lua_State *L, uint32_t iidx) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin pushLuaRef:refTable ref:helpersRef] ;
    lua_getfield(L, -1, "if_indexToName") ;
    lua_remove(L, -2) ;
    lua_pushinteger(L, iidx) ;
    if (![skin protectedCallAndTraceback:1 nresults:1]) {
        [skin logError:[NSString stringWithFormat:@"%s:interface - error looking up interface name from index: %s", USERDATA_TAG, lua_tostring(L, -1)]] ;
        lua_pop(L, 1) ;
        lua_pushnil(L) ;
    } else {
        if (lua_isnil(L, -1)) {
            [skin logInfo:[NSString stringWithFormat:@"%s:interface - interface index %u not valid (interface removed?)", USERDATA_TAG, iidx]] ;
            lua_pop(L, 1) ;
            lua_pushnil(L) ;
        } // otherwise it's a sring and we want to keep it at the stack top, so no lua_pop
    }
    return 1 ;
}

static int dnssd_interfaceIndex_toLuaStack(lua_State *L, const char *name) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin pushLuaRef:refTable ref:helpersRef] ;
    lua_getfield(L, -1, "if_nameToIndex") ;
    lua_remove(L, -2) ;
    lua_pushstring(L, name) ;
    if (![skin protectedCallAndTraceback:1 nresults:1]) {
        [skin logError:[NSString stringWithFormat:@"%s:interface - error looking up interface index from name: %s", USERDATA_TAG, lua_tostring(L, -1)]] ;
        lua_pop(L, 1) ;
        lua_pushnil(L) ;
    } else {
        if (lua_isnil(L, -1)) {
            [skin logInfo:[NSString stringWithFormat:@"%s:interface - interface name %s not found", USERDATA_TAG, name]] ;
            lua_pop(L, 1) ;
            lua_pushnil(L) ;
        } // otherwise it's an integer and we want to keep it at the stack top, so no lua_pop
    }
    return 1 ;
}

static void domainBrowseCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, const char *replyDomain, void *context) ;

static void serviceBrowseCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, const char *serviceName, const char *regtype, const char *replyDomain, void *context);

@interface ASMDNSSDBrowser : NSObject
@property (readonly) DNSServiceRef   serviceRef ;
@property            int             selfRefCount ;
@property            int             callbackRef ;
@property            DNSServiceFlags flags ;
@property            uint32_t        interfaceIdx ;
@end

@implementation ASMDNSSDBrowser
- (instancetype)init {
    self = [super init] ;
    if (self) {
        _serviceRef   = NULL ;
        _callbackRef  = LUA_NOREF ;
        _selfRefCount = 0 ;
        _flags        = 0 ;
        _interfaceIdx = kDNSServiceInterfaceIndexAny ;
    }
    return self ;
}

- (void)stop {
    if (_serviceRef) {
        LuaSkin *skin = [LuaSkin shared] ;
        CFRelease(_serviceRef) ;
        DNSServiceRefDeallocate(_serviceRef) ;
        _serviceRef  = NULL ;
        _callbackRef = [skin luaUnref:refTable ref:_callbackRef] ;
    }
}

- (BOOL)startFindDomains:(enum t_domainTypes)domainType callbackIndex:(int)callbackIdx {
    LuaSkin   *skin = [LuaSkin shared] ;
    if (!_serviceRef) {
        lua_State *L    = skin.L ;

        lua_pushvalue(L, callbackIdx) ;
        _callbackRef = [skin luaRef:refTable] ;

        DNSServiceErrorType err = DNSServiceEnumerateDomains(
                                      &_serviceRef,
                                      domainType,
                                      _interfaceIdx,
                                      domainBrowseCallback,
                                      (__bridge void *)self
                                  ) ;
        if (err == kDNSServiceErr_NoError) {
            CFRetain(_serviceRef) ;
            err = DNSServiceSetDispatchQueue(_serviceRef, dispatch_get_main_queue()) ;
            if (err == kDNSServiceErr_NoError) {
                return YES ;
            } else {
                [self stop] ;
                dnssd_error_stringToLuaStack(L, err) ;
                [skin logError:[NSString stringWithFormat:@"%s:findDomains - error assigning to dispatch queue: %s", USERDATA_TAG, lua_tostring(L, -1)]] ;
                lua_pop(L, 1) ;
            }
        } else {
            _serviceRef = NULL ; // it should still be NULL, but lets be explicit
            _callbackRef = [skin luaUnref:refTable ref:_callbackRef] ;
            dnssd_error_stringToLuaStack(L, err) ;
            [skin logError:[NSString stringWithFormat:@"%s:findDomains - error creating service: %s", USERDATA_TAG, lua_tostring(L, -1)]] ;
            lua_pop(L, 1) ;
        }
    } else {
        [skin logError:[NSString stringWithFormat:@"%s:findDomains - instance already active", USERDATA_TAG]] ;
    }
    return NO ;
}

- (BOOL)findServices:(NSString *)regtype inDomain:(NSString *)domain callbackIndex:(int)callbackIdx {
    LuaSkin   *skin = [LuaSkin shared] ;
    if (!_serviceRef) {
        lua_State *L    = skin.L ;

        lua_pushvalue(L, callbackIdx) ;
        _callbackRef = [skin luaRef:refTable] ;

        DNSServiceErrorType err = DNSServiceBrowse(
                                      &_serviceRef,
                                      _flags,
                                      _interfaceIdx,
                                      regtype.UTF8String,
                                      domain ? domain.UTF8String : NULL,
                                      serviceBrowseCallback,
                                      (__bridge void *)self
                                  ) ;
        if (err == kDNSServiceErr_NoError) {
            CFRetain(_serviceRef) ;
            err = DNSServiceSetDispatchQueue(_serviceRef, dispatch_get_main_queue()) ;
            if (err == kDNSServiceErr_NoError) {
                return YES ;
            } else {
                [self stop] ;
                dnssd_error_stringToLuaStack(L, err) ;
                [skin logError:[NSString stringWithFormat:@"%s:findServices - error assigning to dispatch queue: %s", USERDATA_TAG, lua_tostring(L, -1)]] ;
                lua_pop(L, 1) ;
            }
        } else {
            _serviceRef = NULL ; // it should still be NULL, but lets be explicit
            _callbackRef = [skin luaUnref:refTable ref:_callbackRef] ;
            dnssd_error_stringToLuaStack(L, err) ;
            [skin logError:[NSString stringWithFormat:@"%s:findServices - error creating service: %s", USERDATA_TAG, lua_tostring(L, -1)]] ;
            lua_pop(L, 1) ;
        }
    } else {
        [skin logError:[NSString stringWithFormat:@"%s:findServices - instance already active", USERDATA_TAG]] ;
    }
    return NO ;
}

@end

static void domainBrowseCallback(__unused DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, const char *replyDomain, void *context) {
    ASMDNSSDBrowser *self = (__bridge ASMDNSSDBrowser *)context ;
    if (self.callbackRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin shared] ;
        lua_State *L    = skin.L ;
        _lua_stackguard_entry(L);

        [skin pushLuaRef:refTable ref:self.callbackRef] ;
        [skin pushNSObject:self] ;

        int argCount = 6 ;
        if (errorCode == kDNSServiceErr_NoError) {
            lua_pushstring(L, "domain") ;
            if ((flags & kDNSServiceFlagsDefault) == kDNSServiceFlagsDefault) {
                lua_pushstring(L, "default") ;
            } else {
                lua_pushboolean(L, ((flags & kDNSServiceFlagsAdd) == kDNSServiceFlagsAdd)) ;
            }
            lua_pushstring(L, replyDomain) ;
            dnssd_interfaceName_stringToLuaStack(L, interfaceIndex) ;
            lua_pushboolean(L, ((flags & kDNSServiceFlagsMoreComing) == kDNSServiceFlagsMoreComing)) ;
        } else {
            lua_pushstring(L, "error") ;
            dnssd_error_stringToLuaStack(L, errorCode) ;
            argCount = 3 ;
        }

        if (![skin protectedCallAndTraceback:argCount nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:findDomains callback error:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
            lua_pop(L, -1) ;
        }

        _lua_stackguard_exit(L);
    }
}

static void serviceBrowseCallback(__unused DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, const char *serviceName, const char *regtype, const char *replyDomain, void *context) {
    ASMDNSSDBrowser *self = (__bridge ASMDNSSDBrowser *)context ;
    if (self.callbackRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin shared] ;
        lua_State *L    = skin.L ;
        _lua_stackguard_entry(L);

        [skin pushLuaRef:refTable ref:self.callbackRef] ;
        [skin pushNSObject:self] ;

//         int argCount = ... ;
//         if (errorCode == kDNSServiceErr_NoError) {
//             ...
//         } else {
//             lua_pushstring(L, "error") ;
//             dnssd_error_stringToLuaStack(L, err) ;
//             argCount = 3 ;
//         }
//
//         if (![skin protectedCallAndTraceback:argCount nresults:0]) {
//             [skin logError:[NSString stringWithFormat:@"%s:findDomains callback error:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
//             lua_pop(L, -1) ;
//         }

        _lua_stackguard_exit(L);
    }
}

#pragma mark - Module Functions

static int dnssd_browser_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    ASMDNSSDBrowser *browser = [[ASMDNSSDBrowser alloc] init] ;
    if (browser) {
        [skin pushNSObject:browser] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int dnssd_browser_includesP2P(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMDNSSDBrowser *browser = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, ((browser.flags & kDNSServiceFlagsIncludeP2P) == kDNSServiceFlagsIncludeP2P)) ;
    } else if (browser.serviceRef == NULL) {
        if (lua_toboolean(L, 2)) {
            browser.flags |= kDNSServiceFlagsIncludeP2P ;
        } else {
            browser.flags &= ~((uint32_t)kDNSServiceFlagsIncludeP2P) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        return luaL_error(L, "P2P flag cannot be changed on an active browser instance") ;
    }
    return 1 ;
}

static int dnssd_browser_interface(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMDNSSDBrowser *browser = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        dnssd_interfaceName_stringToLuaStack(L, browser.interfaceIdx) ;
    } else if (browser.serviceRef == NULL) {
        NSString *name = [skin toNSObjectAtIndex:2] ;
        dnssd_interfaceIndex_toLuaStack(L, name.UTF8String) ;
        if (!lua_isnil(L, -1)) {
            browser.interfaceIdx = (uint32_t)lua_tointeger(L, -1) ;
            lua_pop(L, 1) ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        return luaL_error(L, "interface cannot be changed on an active browser instance") ;
    }
    return 1 ;
}

static int dnssd_browser_enumerateBrowsableDomains(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION, LS_TBREAK] ;
    ASMDNSSDBrowser *browser = [skin toNSObjectAtIndex:1] ;
    if ([browser startFindDomains:forBrowsing callbackIndex:2]) {
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int dnssd_browser_enumerateRegistrationDomains(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION, LS_TBREAK] ;
    ASMDNSSDBrowser *browser = [skin toNSObjectAtIndex:1] ;
    if ([browser startFindDomains:forRegistering callbackIndex:2]) {
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

// static int dnssd_browser_findServices(lua_State *L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
//     ASMDNSSDBrowser *browser = [skin toNSObjectAtIndex:1] ;
// }

static int dnssd_browser_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMDNSSDBrowser *browser = [skin toNSObjectAtIndex:1] ;
    [browser stop] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}


#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMDNSSDBrowser(lua_State *L, id obj) {
    ASMDNSSDBrowser *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMDNSSDBrowser *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toASMDNSSDBrowserFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMDNSSDBrowser *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMDNSSDBrowser, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
//     ASMDNSSDBrowser *obj = [skin luaObjectAtIndex:1 toClass:"ASMDNSSDBrowser"] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMDNSSDBrowser *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMDNSSDBrowser"] ;
        ASMDNSSDBrowser *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMDNSSDBrowser"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMDNSSDBrowser *obj = get_objectFromUserdata(__bridge_transfer ASMDNSSDBrowser, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            [obj stop] ;
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
    {"includeP2P",          dnssd_browser_includesP2P},
    {"interface",           dnssd_browser_interface},
    {"browsableDomains",    dnssd_browser_enumerateBrowsableDomains},
    {"registrationDomains", dnssd_browser_enumerateRegistrationDomains},
//     {"findServices",        dnssd_browser_findServices},
    {"stop",                dnssd_browser_stop},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",              dnssd_browser_new},

    {"_registerHelpers", dnssd_registerHelpers},
    {NULL,               NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_dnssd_browser(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASMDNSSDBrowser         forClass:"ASMDNSSDBrowser"];
    [skin registerLuaObjectHelper:toASMDNSSDBrowserFromLua forClass:"ASMDNSSDBrowser"
                                                withUserdataMapping:USERDATA_TAG];

    return 1;
}
