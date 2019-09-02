@import Cocoa ;
@import LuaSkin ;

@import dnssd ;
@import Darwin.POSIX.net ;

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

static const char *dnssd_error_string(DNSServiceErrorType err) {
    switch (err) {
        case kDNSServiceErr_Unknown:                   return "Unknwon" ;
        case kDNSServiceErr_NoSuchName:                return "No such name" ;
        case kDNSServiceErr_NoMemory:                  return "No memory" ;
        case kDNSServiceErr_BadParam:                  return "Bad parameter" ;
        case kDNSServiceErr_BadReference:              return "Bad reference" ;
        case kDNSServiceErr_BadState:                  return "Bad state" ;
        case kDNSServiceErr_BadFlags:                  return "Bad flags" ;
        case kDNSServiceErr_Unsupported:               return "Unsupported" ;
        case kDNSServiceErr_NotInitialized:            return "Not initialized" ;
        case kDNSServiceErr_AlreadyRegistered:         return "Already registered" ;
        case kDNSServiceErr_NameConflict:              return "Name conflict" ;
        case kDNSServiceErr_Invalid:                   return "Invalid" ;
        case kDNSServiceErr_Firewall:                  return "Firewall" ;
        case kDNSServiceErr_Incompatible:              return "Incompatible" ;
        case kDNSServiceErr_BadInterfaceIndex:         return "Bad interface index" ;
        case kDNSServiceErr_Refused:                   return "Refused" ;
        case kDNSServiceErr_NoSuchRecord:              return "No such record" ;
        case kDNSServiceErr_NoAuth:                    return "No auth" ;
        case kDNSServiceErr_NoSuchKey:                 return "No such key" ;
        case kDNSServiceErr_NATTraversal:              return "NAT Traversal" ;
        case kDNSServiceErr_DoubleNAT:                 return "Double NAT" ;
        case kDNSServiceErr_BadTime:                   return "Bad time" ;
        case kDNSServiceErr_BadSig:                    return "Bad sig" ;
        case kDNSServiceErr_BadKey:                    return "Bad key" ;
        case kDNSServiceErr_Transient:                 return "Transient" ;
        case kDNSServiceErr_ServiceNotRunning:         return "Service not running" ;
        case kDNSServiceErr_NATPortMappingUnsupported: return "NAT port mapping unsupported" ;
        case kDNSServiceErr_NATPortMappingDisabled:    return "NAT port mapping disabled" ;
        case kDNSServiceErr_NoRouter:                  return "No router" ;
        case kDNSServiceErr_PollingMode:               return "Polling mode" ;
        case kDNSServiceErr_Timeout:                   return "Timeout" ;
        default:                                       return NULL ;
    }
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
                const char *errStr = dnssd_error_string(err) ;
                if (!errStr) errStr = [[NSString stringWithFormat:@"unrecognized error: %d", err] UTF8String] ;
                [skin logError:[NSString stringWithFormat:@"%s:findDomains - error assigning to dispatch queue: %s", USERDATA_TAG, errStr]] ;
            }
        } else {
            _serviceRef = NULL ; // it should still be NULL, but lets be explicit
            _callbackRef = [skin luaUnref:refTable ref:_callbackRef] ;
            const char *errStr = dnssd_error_string(err) ;
            if (!errStr) errStr = [[NSString stringWithFormat:@"unrecognized error: %d", err] UTF8String] ;
            [skin logError:[NSString stringWithFormat:@"%s:findDomains - error creating service: %s", USERDATA_TAG, errStr]] ;
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
                const char *errStr = dnssd_error_string(err) ;
                if (!errStr) errStr = [[NSString stringWithFormat:@"unrecognized error: %d", err] UTF8String] ;
                [skin logError:[NSString stringWithFormat:@"%s:findServices - error assigning to dispatch queue: %s", USERDATA_TAG, errStr]] ;
            }
        } else {
            _serviceRef = NULL ; // it should still be NULL, but lets be explicit
            _callbackRef = [skin luaUnref:refTable ref:_callbackRef] ;
            const char *errStr = dnssd_error_string(err) ;
            if (!errStr) errStr = [[NSString stringWithFormat:@"unrecognized error: %d", err] UTF8String] ;
            [skin logError:[NSString stringWithFormat:@"%s:findServices - error creating service: %s", USERDATA_TAG, errStr]] ;
        }
    } else {
        [skin logError:[NSString stringWithFormat:@"%s:findServices - instance already active", USERDATA_TAG]] ;
    }
    return NO ;
}

- (void)interfaceNameForIndex:(uint32_t)iidx toLuaStack:(lua_State *)L {
    switch(iidx) {
        case kDNSServiceInterfaceIndexAny:       lua_pushstring(L, "any") ; break ;
        case kDNSServiceInterfaceIndexLocalOnly: lua_pushstring(L, "local") ; break ;
        case kDNSServiceInterfaceIndexUnicast:   lua_pushstring(L, "unicast") ; break ;
        case kDNSServiceInterfaceIndexP2P:       lua_pushstring(L, "P2P") ; break ;
        case kDNSServiceInterfaceIndexBLE:       lua_pushstring(L, "BLE") ; break ;
        default: {
            char *interfaceName = malloc(IFNAMSIZ) ;
            if (if_indextoname(iidx, interfaceName)) {
                lua_pushstring(L, interfaceName) ;
                free(interfaceName) ;
            } else {
                [LuaSkin logWarn:[NSString stringWithFormat:@"%s:interface - index %u no longer valid (interface removed?)", USERDATA_TAG, iidx]] ;
                lua_pushnil(L) ;
            }
        }
    }
}

- (void)interfaceNameToLuaStack:(lua_State *)L {
    [self interfaceNameForIndex:_interfaceIdx toLuaStack:L] ;
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
            [self interfaceNameForIndex:interfaceIndex toLuaStack:L] ;
            lua_pushboolean(L, ((flags & kDNSServiceFlagsMoreComing) == kDNSServiceFlagsMoreComing)) ;
        } else {
            const char *errStr = dnssd_error_string(errorCode) ;
            if (!errStr) errStr = [[NSString stringWithFormat:@"unrecognized error: %d", errorCode] UTF8String] ;
            lua_pushstring(L, "error") ;
            lua_pushstring(L, errStr) ;
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
//             const char *errStr = dnssd_error_string(errorCode) ;
//             if (!errStr) errStr = [[NSString stringWithFormat:@"unrecognized error: %d", errorCode] UTF8String] ;
//             lua_pushstring(L, "error") ;
//             lua_pushstring(L, errStr) ;
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

static int dnssd_browser_registerHelpers(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;

    lua_pushvalue(L, 1) ;
    helpersRef = [skin luaRef:refTable] ;
    return 0 ;
}

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

static int dnssd_browser_setInterface(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMDNSSDBrowser *browser = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [browser interfaceNameToLuaStack:L] ;
    } else if (browser.serviceRef == NULL) {
        NSString *name = [skin toNSObjectAtIndex:2] ;
        if ([name caseInsensitiveCompare:@"any"] == NSOrderedSame) {
            browser.interfaceIdx = kDNSServiceInterfaceIndexAny ;
        } else if ([name caseInsensitiveCompare:@"local"] == NSOrderedSame) {
            browser.interfaceIdx = kDNSServiceInterfaceIndexLocalOnly ;
        } else if ([name caseInsensitiveCompare:@"unicast"] == NSOrderedSame) {
            browser.interfaceIdx = kDNSServiceInterfaceIndexUnicast ;
        } else if ([name caseInsensitiveCompare:@"P2P"] == NSOrderedSame) {
            browser.interfaceIdx = kDNSServiceInterfaceIndexP2P ;
        } else if ([name caseInsensitiveCompare:@"BLE"] == NSOrderedSame) {
            browser.interfaceIdx = kDNSServiceInterfaceIndexBLE ;
        } else {
            uint32_t interfaceIdx = if_nametoindex(name.UTF8String) ;
            if (interfaceIdx == 0) {
                return luaL_error(L, "interface name %s not found", name.UTF8String) ;
            } else {
                browser.interfaceIdx = interfaceIdx ;
            }
        }
        lua_pushvalue(L, 1) ;
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
    {"interface",           dnssd_browser_setInterface},
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

    {"_registerHelpers", dnssd_browser_registerHelpers},

    {NULL,               NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
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
