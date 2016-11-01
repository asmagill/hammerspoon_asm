@import Cocoa ;
@import LuaSkin ;

// #define USERDATA_TAG "hs._asm.module"

static const char           *USERDATA_TAG       = "hs._asm.spotlight" ;
static int                  refTable            = LUA_NOREF;
static dispatch_queue_t     moduleSearchQueue   = NULL ;
static NSNotificationCenter *notificationCenter = nil ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface ASMMetadataQuery : NSObject
@property MDQueryRef metadataQuery ;
@property int        callbackRef ;
@property int        selfPushCount ;

@property BOOL       wantStart ;
@property BOOL       wantFinish ;
@property BOOL       wantUpdate ;
@property BOOL       wantProgress ;

@property (nonatomic) NSString   *queryString ;
@property (nonatomic) CFArrayRef valueListAttrs ;
@property (nonatomic) CFArrayRef sortingAttrs ;
@property (nonatomic) CFArrayRef scopeDirectories ;
@end

@implementation ASMMetadataQuery

@synthesize queryString = _queryString;
@synthesize valueListAttrs = _valueListAttrs;
@synthesize sortingAttrs = _sortingAttrs;
@synthesize scopeDirectories = _scopeDirectories;

- (NSString *)queryString { return _queryString ; }
- (void)setQueryString:(NSString *)value {
    _queryString = value ;
    if (_metadataQuery) { [self resetQuery] ; [self startQuery] ; }
}

- (CFArrayRef)valueListAttrs { return _valueListAttrs ; }
- (void)setValueListAttrs:(CFArrayRef)value {
    _valueListAttrs = value ;
    if (_metadataQuery) { [self resetQuery] ; [self startQuery] ; }
}

- (CFArrayRef)sortingAttrs { return _sortingAttrs ; }
- (void)setSortingAttrs:(CFArrayRef)value {
    _sortingAttrs = value ;
    if (_metadataQuery) { [self resetQuery] ; [self startQuery] ; }
}

- (CFArrayRef)scopeDirectories { return _scopeDirectories ; }
- (void)setScopeDirectories:(CFArrayRef)value {
    _scopeDirectories = value ;
    if (_metadataQuery) { [self resetQuery] ; [self startQuery] ; }
}

- (instancetype)init {
    self = [super init] ;
    if (self) {
        _callbackRef   = LUA_NOREF ;
        _selfPushCount = 0 ;
        _metadataQuery = NULL ;

        _wantStart     = NO ;
        _wantFinish    = YES ;
        _wantUpdate    = NO ;
        _wantProgress  = NO ;

        _queryString      = @"" ;
        _valueListAttrs   = NULL ;
        _sortingAttrs     = NULL ;
        _scopeDirectories = NULL ;
    }
    return self ;
}

- (void)startQuery {
    if (_metadataQuery) {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:startQuery invoked on existing query", USERDATA_TAG]] ;
    } else {
        _metadataQuery = MDQueryCreate(kCFAllocatorDefault, (__bridge CFStringRef)_queryString, _valueListAttrs, _sortingAttrs) ;
        if (_metadataQuery) {
            MDQuerySetDispatchQueue(_metadataQuery, moduleSearchQueue) ;
            [notificationCenter addObserver:self selector:@selector(queryDidComplete:)
                                                     name:(__bridge NSString *)kMDQueryDidFinishNotification
                                                   object:(__bridge id)_metadataQuery];
            [notificationCenter addObserver:self selector:@selector(queryDidUpdate:)
                                                     name:(__bridge NSString *)kMDQueryDidUpdateNotification
                                                   object:(__bridge id)_metadataQuery];
            [notificationCenter addObserver:self selector:@selector(queryInProgress:)
                                                     name:(__bridge NSString *)kMDQueryProgressNotification
                                                   object:(__bridge id)_metadataQuery];
            if (MDQueryExecute(_metadataQuery, kMDQueryWantsUpdates)) [self queryDidStart:nil] ;
        } else {
            [LuaSkin logError:[NSString stringWithFormat:@"%s:startQuery failed to create query; is query string malformed?", USERDATA_TAG]] ;
        }
    }
}

- (void)stopQuery {
    if (_metadataQuery) {
        [notificationCenter removeObserver:self name:(__bridge NSString *)kMDQueryDidFinishNotification
                                              object:(__bridge id)_metadataQuery];
        [notificationCenter removeObserver:self name:(__bridge NSString *)kMDQueryDidUpdateNotification
                                              object:(__bridge id)_metadataQuery];
        [notificationCenter removeObserver:self name:(__bridge NSString *)kMDQueryProgressNotification
                                              object:(__bridge id)_metadataQuery];
        MDQueryStop(_metadataQuery) ;
        // we don't clear it in case they still want to review its results
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:stopQuery invoked when no query exists", USERDATA_TAG]] ;
    }
}

- (void)resetQuery {
    if (_metadataQuery) {
        [self stopQuery] ;
        CFRelease(_metadataQuery) ;
        _metadataQuery = NULL ;
    }
}

- (void)queryDidStart:(NSNotification *)notification {
    if (_callbackRef != LUA_NOREF && _wantStart) [self doCallbackFor:@"didStart" with:notification] ;
}

- (void)queryDidComplete:(NSNotification *)notification {
    if (_callbackRef != LUA_NOREF && _wantFinish) [self doCallbackFor:@"didFinish" with:notification] ;
}

- (void)queryDidUpdate:(NSNotification *)notification {
    if (_callbackRef != LUA_NOREF && _wantUpdate) [self doCallbackFor:@"didUpdate" with:notification] ;
}

- (void)queryInProgress:(NSNotification *)notification {
    if (_callbackRef != LUA_NOREF && _wantProgress) [self doCallbackFor:@"inProgress" with:notification] ;
}

- (void)doCallbackFor:(NSString *)message with:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:self->_callbackRef] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:message] ;
        [skin pushNSObject:notification.userInfo withOptions:LS_NSDescribeUnknownTypes] ;
        if (![skin protectedCallAndTraceback:3 nresults:0]) {
            lua_State *L = [skin L] ;
            [skin logError:[NSString stringWithFormat:@"%s:callback error: %s", USERDATA_TAG, lua_tostring(L, -1)]] ;
            lua_pop(L, 1) ;
        }
    }) ;
}

@end

#pragma mark - Module Functions

static int spotlight_new(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:[[ASMMetadataQuery alloc] init]] ;
    return 1 ;
}

#pragma mark - Module Methods

static int spotlight_startQuery(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared ] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;
    [query startQuery] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int spotlight_stopQuery(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared ] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;
    [query stopQuery] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int spotlight_resetQuery(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared ] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;
    [query resetQuery] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int spotlight_queryString(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared ] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSObject:query.queryString] ;
    } else {
        query.queryString = [skin toNSObjectAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int spotlight_valueListAttrs(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared ] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSObject:(__bridge NSArray *)query.valueListAttrs] ;
    } else {
        NSArray  *hopefuls = nil ;
        NSString __block *error = nil ;
        if (lua_type(L, 2) != LUA_TNIL) {
            hopefuls = [skin toNSObjectAtIndex:2] ;
            if ([hopefuls isKindOfClass:[NSString class]]) hopefuls = [NSArray arrayWithObject:hopefuls] ;
            if ([hopefuls isKindOfClass:[NSArray class]]) {
                [hopefuls enumerateObjectsUsingBlock:^(NSString *attr, NSUInteger idx, BOOL *stop) {
                    if (![attr isKindOfClass:[NSString class]]) {
                        error = [NSString stringWithFormat:@"expected string at index %lu", idx + 1] ;
                        *stop = YES ;
                    }
                }] ;
            } else {
                error = @"expected nil, string or array of strings" ;
            }
        }
        if (error) return luaL_argerror(L, 2, error.UTF8String) ;
        if (query.valueListAttrs) { CFRelease(query.valueListAttrs) ; query.valueListAttrs = NULL ; }
        if (hopefuls) query.valueListAttrs = (__bridge_retained CFArrayRef)hopefuls ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int spotlight_sortingAttrs(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared ] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSObject:(__bridge NSArray *)query.sortingAttrs] ;
    } else {
        NSArray  *hopefuls = nil ;
        NSString __block *error = nil ;
        if (lua_type(L, 2) != LUA_TNIL) {
            hopefuls = [skin toNSObjectAtIndex:2] ;
            if ([hopefuls isKindOfClass:[NSString class]]) hopefuls = [NSArray arrayWithObject:hopefuls] ;
            if ([hopefuls isKindOfClass:[NSArray class]]) {
                [hopefuls enumerateObjectsUsingBlock:^(NSString *attr, NSUInteger idx, BOOL *stop) {
                    if (![attr isKindOfClass:[NSString class]]) {
                        error = [NSString stringWithFormat:@"expected string at index %lu", idx + 1] ;
                        *stop = YES ;
                    }
                }] ;
            } else {
                error = @"expected nil, string or array of strings" ;
            }
        }
        if (error) return luaL_argerror(L, 2, error.UTF8String) ;
        if (query.sortingAttrs) { CFRelease(query.sortingAttrs) ; query.sortingAttrs = NULL ; }
        if (hopefuls) query.sortingAttrs = (__bridge_retained CFArrayRef)hopefuls ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int spotlight_scopeDirectories(lua_State *L) {
// FIXME: If this works better than the NSMetadataQuery version, we need to update this method to handle URLs
// TODO:  Also, should check actual MDQuery for value, since these aren't set at creation time
    LuaSkin *skin = [LuaSkin shared ] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSObject:(__bridge NSArray *)query.scopeDirectories] ;
    } else {
        NSArray  *hopefuls = nil ;
        NSString __block *error = nil ;
        if (lua_type(L, 2) != LUA_TNIL) {
            hopefuls = [skin toNSObjectAtIndex:2] ;
            if ([hopefuls isKindOfClass:[NSString class]]) hopefuls = [NSArray arrayWithObject:hopefuls] ;
            if ([hopefuls isKindOfClass:[NSArray class]]) {
                [hopefuls enumerateObjectsUsingBlock:^(NSString *attr, NSUInteger idx, BOOL *stop) {
                    if (![attr isKindOfClass:[NSString class]]) {
                        error = [NSString stringWithFormat:@"expected string at index %lu", idx + 1] ;
                        *stop = YES ;
                    }
                }] ;
            } else {
                error = @"expected nil, string or array of strings" ;
            }
        }
        if (error) return luaL_argerror(L, 2, error.UTF8String) ;
        if (query.scopeDirectories) { CFRelease(query.scopeDirectories) ; query.scopeDirectories = NULL ; }
        if (hopefuls) query.scopeDirectories = (__bridge_retained CFArrayRef)hopefuls ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int spotlight_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    query.callbackRef = [skin luaUnref:refTable ref:query.callbackRef] ;
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2) ;
        query.callbackRef = [skin luaRef:refTable] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int spotlight_callbackMessages(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_newtable(L) ;
        if (query.wantStart)    { lua_pushstring(L, "didStart") ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; }
        if (query.wantFinish)   { lua_pushstring(L, "didFinish") ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; }
        if (query.wantUpdate)   { lua_pushstring(L, "didUpdate") ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; }
        if (query.wantProgress) { lua_pushstring(L, "inProgress") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; }
    } else {
        NSArray *items = [skin toNSObjectAtIndex:2] ;
        if ([items isKindOfClass:[NSString class]]) items = [NSArray arrayWithObject:items] ;
        if (![items isKindOfClass:[NSArray class]]) return luaL_argerror(L, 2, "expected string or array of strings") ;
        NSString __block *errorMessage ;
        NSArray *messages = @[ @"didStart", @"didFinish", @"didUpdate", @"inProgress" ] ;
        [items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isKindOfClass:[NSString class]]) {
                if (![messages containsObject:(NSString *)obj]) {
                    errorMessage = [NSString stringWithFormat:@"index %lu must be one of '%@'", idx + 1, [messages componentsJoinedByString:@"', '"]] ;
                    *stop = YES ;
                }
            } else {
                errorMessage = [NSString stringWithFormat:@"index %lu is not a string", idx + 1] ;
                *stop = YES ;
            }
        }] ;
        if (errorMessage) {
            return luaL_argerror(L, 2, errorMessage.UTF8String) ;
        } else {
            query.wantStart    = [items containsObject:@"didStart"] ;
            query.wantFinish   = [items containsObject:@"didFinish"] ;
            query.wantUpdate   = [items containsObject:@"didUpdate"] ;
            query.wantProgress = [items containsObject:@"inProgress"] ;
            lua_pushvalue(L, 1) ;
        }
    }
    return 1 ;
}

static int spotlight_resultCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;
    MDQueryRef       metadataQuery = query.metadataQuery ;
    if (metadataQuery) {
        lua_pushinteger(L, MDQueryGetResultCount(metadataQuery)) ;
    } else {
        lua_pushinteger(L, 0) ;
    }
    return 1 ;
}

static int spotlight_resultAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;
    MDQueryRef       metadataQuery = query.metadataQuery ;
    if (metadataQuery) {
        lua_Integer index = lua_tointeger(L, 2) ;
        CFIndex     count = MDQueryGetResultCount(metadataQuery) ;
        if (index < 1 || index >(lua_Integer)count) {
            if (count == 0) {
                return luaL_argerror(L, 2, "result set is empty") ;
            } else {
                return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index must be between 1 and %lu inclusive", count] UTF8String]) ;
            }
        } else {
            MDQueryDisableUpdates(metadataQuery) ;

// (const void *) is a bitch to cast around... just ignore it.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincompatible-pointer-types-discards-qualifiers"
            MDItemRef queryItem = MDQueryGetResultAtIndex(metadataQuery, (CFIndex)(index - 1)) ;
#pragma clang diagnostic pop

            lua_newtable(L) ;
            if (queryItem) {
                CFArrayRef attributes = MDItemCopyAttributeNames(queryItem) ;
                if (attributes) {
                    for (CFIndex i = 0 ; i < CFArrayGetCount(attributes) ; i++ ) {
                        CFStringRef name = CFArrayGetValueAtIndex(attributes, i) ;
                        if (name) {
                            CFTypeRef value = MDItemCopyAttribute(queryItem, name) ;
                            if (value) {
                                if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
                                    lua_pushboolean(L, CFBooleanGetValue(value)) ;
                                } else { // the other types are bridgeable: CFArray, CFDate, CFNumber, CFString
                                    [skin pushNSObject:(__bridge id)value withOptions:LS_NSDescribeUnknownTypes] ;
                                }
                                lua_setfield(L, -2, [(__bridge NSString *)name UTF8String]) ;
                            } else {
                                [skin logInfo:[NSString stringWithFormat:@"%s:resultAtIndex - unable to get value for %@ of MDItemRef", USERDATA_TAG, (__bridge id)name]] ;
                            }
                        } else {
                            [skin logInfo:[NSString stringWithFormat:@"%s:resultAtIndex - unable to get CFStringRef at index %lu of MDItemCopyAttributeNames", USERDATA_TAG, i]] ;
                        }
                    }
                } else {
                    [skin logInfo:[NSString stringWithFormat:@"%s:resultAtIndex - unable to get CFArrayRef with MDItemCopyAttributeNames", USERDATA_TAG]] ;
                }
            } else {
                [skin logInfo:[NSString stringWithFormat:@"%s:resultAtIndex - unable to get MDItemRef at index %lld with MDQueryGetResultAtIndex", USERDATA_TAG, (index - 1)]] ;
            }
            MDQueryEnableUpdates(metadataQuery) ;
        }
    } else {
        return luaL_argerror(L, 2, "no query has been performed") ;
    }
    return 1 ;
}

#pragma mark - Module Constants

static int push_searchScopes(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
    [skin pushNSObject:NSMetadataQueryUserHomeScope] ;                              lua_setfield(L, -2, "userHome") ;
    [skin pushNSObject:NSMetadataQueryLocalComputerScope] ;                         lua_setfield(L, -2, "localComputer") ;
    [skin pushNSObject:NSMetadataQueryNetworkScope] ;                               lua_setfield(L, -2, "network") ;
    [skin pushNSObject:NSMetadataQueryUbiquitousDocumentsScope] ;                   lua_setfield(L, -2, "iCloudDocuments") ;
    [skin pushNSObject:NSMetadataQueryUbiquitousDataScope] ;                        lua_setfield(L, -2, "iCloudData") ;
    [skin pushNSObject:NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope] ; lua_setfield(L, -2, "iCloudExternalDocuments") ;
    [skin pushNSObject:NSMetadataQueryIndexedLocalComputerScope] ;                  lua_setfield(L, -2, "indexedLocalComputer") ;
    [skin pushNSObject:NSMetadataQueryIndexedNetworkScope] ;                        lua_setfield(L, -2, "indexedNetwork") ;
    return 1 ;
}

static int push_commonAttributeKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;

    // pulled from 10.12 framework headers based on string names "kMDItem.+", "NSMetadataItem.+", and
    // "NSMetadataUbiquitousItem.+" then duplicate values removed

    [skin pushNSObject:(__bridge NSString *)kMDItemFSHasCustomIcon] ;            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kMDItemFSInvisible] ;                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kMDItemFSIsExtensionHidden] ;        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kMDItemFSIsStationery] ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kMDItemFSLabel] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kMDItemFSNodeCount] ;                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kMDItemFSOwnerGroupID] ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kMDItemFSOwnerUserID] ;              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;

    // kMDItemHTMLContent doesn't exist in 10.10
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    if (&kMDItemHTMLContent != NULL) {
        [skin pushNSObject:(__bridge NSString *)kMDItemHTMLContent] ;            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
#pragma clang diagnostic pop


    [skin pushNSObject:NSMetadataItemAcquisitionMakeKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAcquisitionModelKey] ;                      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAlbumKey] ;                                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAltitudeKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemApertureKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAppleLoopDescriptorsKey] ;                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAppleLoopsKeyFilterTypeKey] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAppleLoopsLoopModeKey] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAppleLoopsRootKeyKey] ;                     lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemApplicationCategoriesKey] ;                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAttributeChangeDateKey] ;                   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAudiencesKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAudioBitRateKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAudioChannelCountKey] ;                     lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAudioEncodingApplicationKey] ;              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAudioSampleRateKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAudioTrackNumberKey] ;                      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAuthorAddressesKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAuthorEmailAddressesKey] ;                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAuthorsKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemBitsPerSampleKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCameraOwnerKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCFBundleIdentifierKey] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCityKey] ;                                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCodecsKey] ;                                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemColorSpaceKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCommentKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemComposerKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemContactKeywordsKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemContentCreationDateKey] ;                   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemContentModificationDateKey] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemContentTypeKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemContentTypeTreeKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemContributorsKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCopyrightKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCountryKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCoverageKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCreatorKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDateAddedKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDeliveryTypeKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDescriptionKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDirectorKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDisplayNameKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDownloadedDateKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDueDateKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDurationSecondsKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemEditorsKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemEmailAddressesKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemEncodingApplicationsKey] ;                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemExecutableArchitecturesKey] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemExecutablePlatformKey] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemEXIFGPSVersionKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemEXIFVersionKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemExposureModeKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemExposureProgramKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemExposureTimeSecondsKey] ;                   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemExposureTimeStringKey] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFinderCommentKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFlashOnOffKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFNumberKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFocalLength35mmKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFocalLengthKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFontsKey] ;                                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFSContentChangeDateKey] ;                   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFSCreationDateKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFSNameKey] ;                                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFSSizeKey] ;                                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGenreKey] ;                                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSAreaInformationKey] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSDateStampKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSDestBearingKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSDestDistanceKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSDestLatitudeKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSDestLongitudeKey] ;                      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSDifferentalKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSDOPKey] ;                                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSMapDatumKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSMeasureModeKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSProcessingMethodKey] ;                   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSStatusKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSTrackKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemHasAlphaChannelKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemHeadlineKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemIdentifierKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemImageDirectionKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemInformationKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemInstantMessageAddressesKey] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemInstructionsKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemIsApplicationManagedKey] ;                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemIsGeneralMIDISequenceKey] ;                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemIsLikelyJunkKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemISOSpeedKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemIsUbiquitousKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemKeySignatureKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemKeywordsKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemKindKey] ;                                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemLanguagesKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemLastUsedDateKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemLatitudeKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemLayerNamesKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemLensModelKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemLongitudeKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemLyricistKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemMaxApertureKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemMediaTypesKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemMeteringModeKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemMusicalGenreKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemMusicalInstrumentCategoryKey] ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemMusicalInstrumentNameKey] ;                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemNamedLocationKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemNumberOfPagesKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemOrganizationsKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemOrientationKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemOriginalFormatKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemOriginalSourceKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPageHeightKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPageWidthKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemParticipantsKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPathKey] ;                                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPerformersKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPhoneNumbersKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPixelCountKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPixelHeightKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPixelWidthKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemProducerKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemProfileNameKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemProjectsKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPublishersKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemRecipientAddressesKey] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemRecipientEmailAddressesKey] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemRecipientsKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemRecordingDateKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemRecordingYearKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemRedEyeOnOffKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemResolutionHeightDPIKey] ;                   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemResolutionWidthDPIKey] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemRightsKey] ;                                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemSecurityMethodKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemSpeedKey] ;                                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemStarRatingKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemStateOrProvinceKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemStreamableKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemSubjectKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemTempoKey] ;                                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemTextContentKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemThemeKey] ;                                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemTimeSignatureKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemTimestampKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemTitleKey] ;                                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemTotalBitRateKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemURLKey] ;                                   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemVersionKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemVideoBitRateKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemWhereFromsKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemWhiteBalanceKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemContainerDisplayNameKey] ;        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemDownloadingErrorKey] ;            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemDownloadingStatusCurrent] ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemDownloadingStatusDownloaded] ;    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemDownloadingStatusKey] ;           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemDownloadingStatusNotDownloaded] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemDownloadRequestedKey] ;           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemHasUnresolvedConflictsKey] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemIsDownloadingKey] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemIsExternalDocumentKey] ;          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemIsUploadedKey] ;                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemIsUploadingKey] ;                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemPercentDownloadedKey] ;           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemPercentUploadedKey] ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemUploadingErrorKey] ;              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemURLInLocalContainerKey] ;         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;

    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMMetadataQuery(lua_State *L, id obj) {
    ASMMetadataQuery *value = obj;
    value.selfPushCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMMetadataQuery *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toASMMetadataQueryFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMMetadataQuery *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMMetadataQuery, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMMetadataQuery *obj = [skin luaObjectAtIndex:1 toClass:"ASMMetadataQuery"] ;
    NSString *title = [obj.queryString isEqualToString:@""] ? @"<undefined>" : obj.queryString ;
    if (!title) title = @"<undefined>" ; // shouldn't be possible, but let's catch it just in case
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMMetadataQuery *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMMetadataQuery"] ;
        ASMMetadataQuery *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMMetadataQuery"] ;
        lua_pushboolean(L, CFEqual(obj1.metadataQuery, obj2.metadataQuery)) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMMetadataQuery *obj = get_objectFromUserdata(__bridge_transfer ASMMetadataQuery, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfPushCount-- ;
        if (obj.selfPushCount == 0) {
            LuaSkin *skin = [LuaSkin shared] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            if (obj.metadataQuery) {
                [obj resetQuery] ;
                if (obj.sortingAttrs) { CFRelease(obj.sortingAttrs) ; obj.sortingAttrs = NULL ; }
                if (obj.valueListAttrs) { CFRelease(obj.valueListAttrs) ; obj.valueListAttrs = NULL ; }
                if (obj.scopeDirectories) { CFRelease(obj.scopeDirectories) ; obj.scopeDirectories = NULL ; }
            }
            obj = nil ;
        }
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    moduleSearchQueue  = NULL ;
    notificationCenter = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"callback",            spotlight_callback},
    {"callbackMessages",    spotlight_callbackMessages},
    {"valueListAttributes", spotlight_valueListAttrs},
    {"sortingAttributes",   spotlight_sortingAttrs},
    {"searchScopes",        spotlight_scopeDirectories},
    {"queryString",         spotlight_queryString},
    {"resultCount",         spotlight_resultCount},
    {"resultAtIndex",       spotlight_resultAtIndex},
    {"start",               spotlight_startQuery},
    {"stop",                spotlight_stopQuery},
    {"reset",               spotlight_resetQuery},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", spotlight_new},
    {NULL,  NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs__asm_spotlight_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    push_searchScopes(L) ;        lua_setfield(L, -2, "searchScopes") ;
    push_commonAttributeKeys(L) ; lua_setfield(L, -2, "commonAttributeKeys") ;

    moduleSearchQueue  = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    notificationCenter = [NSNotificationCenter defaultCenter] ;

    [skin registerPushNSHelper:pushASMMetadataQuery         forClass:"ASMMetadataQuery"];
    [skin registerLuaObjectHelper:toASMMetadataQueryFromLua forClass:"ASMMetadataQuery"
                                                 withUserdataMapping:USERDATA_TAG];

    return 1;
}
