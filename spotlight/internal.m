// Change NSMetadataItem into userdata as well
// Figure out entitlement that allows us to get file url, etc.

@import Cocoa ;
@import LuaSkin ;

static const char       *USERDATA_TAG = "hs._asm.spotlight" ;
static const char       *GROUP_UD_TAG = "hs._asm.spotlight.group" ;

static int              refTable = LUA_NOREF;
static NSOperationQueue *moduleSearchQueue ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static id toNSSortDescriptorFromLua(lua_State *L, int idx) ;

@interface ASMMetadataQuery : NSObject
@property NSMetadataQuery *metadataSearch ;
@property int             callbackRef ;
@property int             selfPushCount ;
@property BOOL            wantComplete ;
@property BOOL            wantProgress ;
@property BOOL            wantStart ;
@property BOOL            wantUpdate ;
@end

@implementation ASMMetadataQuery

- (instancetype)init {
    self = [super init] ;
    if (self) {
        _callbackRef    = LUA_NOREF ;
        _selfPushCount  = 0 ;
        _metadataSearch = [[NSMetadataQuery alloc] init] ;
        _wantComplete   = YES ;
        _wantProgress   = NO ;
        _wantStart      = NO ;
        _wantUpdate     = NO ;

        if (!moduleSearchQueue) moduleSearchQueue = [NSOperationQueue new] ;
        _metadataSearch.operationQueue = moduleSearchQueue ;

        // Register the notifications for batch and completion updates
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter] ;
        [notificationCenter addObserver:self selector:@selector(queryDidFinish:)
                                                 name:NSMetadataQueryDidFinishGatheringNotification
                                               object:_metadataSearch];
        [notificationCenter addObserver:self selector:@selector(queryDidStart:)
                                                 name:NSMetadataQueryDidStartGatheringNotification
                                               object:_metadataSearch];
        [notificationCenter addObserver:self selector:@selector(queryDidUpdate:)
                                                 name:NSMetadataQueryDidUpdateNotification
                                               object:_metadataSearch];
        [notificationCenter addObserver:self selector:@selector(queryProgress:)
                                                 name:NSMetadataQueryGatheringProgressNotification
                                               object:_metadataSearch];
    }
    return self ;
}

- (void)queryDidFinish:(NSNotification *)notification {
    if (_callbackRef != LUA_NOREF && _wantComplete) [self doCallbackFor:@"didFinish" with:notification] ;
}

- (void)queryDidStart:(NSNotification *)notification {
    if (_callbackRef != LUA_NOREF && _wantStart) [self doCallbackFor:@"didStart" with:notification] ;
}

- (void)queryDidUpdate:(NSNotification *)notification {
    if (_callbackRef != LUA_NOREF && _wantUpdate) [self doCallbackFor:@"didUpdate" with:notification] ;
}

- (void)queryProgress:(NSNotification *)notification {
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

static int spotlight_searchScopes(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:query.metadataSearch.searchScopes] ;
    } else {
        NSMutableArray *newScopes = [[NSMutableArray alloc] init] ;
        NSString __block *errorMessage ;
        NSArray *items = [skin toNSObjectAtIndex:2] ;
        if (![items isKindOfClass:[NSArray class]]) items = [NSArray arrayWithObject:items] ;
        [items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isKindOfClass:[NSString class]]) {
                [newScopes addObject:[(NSString *)obj stringByExpandingTildeInPath]] ;
            } else if ([obj isKindOfClass:[NSDictionary class]]) {
                NSString *stringAsURL = [(NSDictionary *)obj objectForKey:@"url"] ;
                if (stringAsURL) {
                    NSURL *newURL = [NSURL URLWithString:stringAsURL] ;
                    if (!newURL.fileURL) {
                        errorMessage = [NSString stringWithFormat:@"index %lu does not represent a file URL", idx + 1] ;
                        *stop = YES ;
                    } else {
                        [newScopes addObject:newURL] ;
                    }
                } else {
                    errorMessage = [NSString stringWithFormat:@"index %lu does not represent a file URL", idx + 1] ;
                    *stop = YES ;
                }
            } else {
                errorMessage = [NSString stringWithFormat:@"index %lu is not a path string or a file URL", idx + 1] ;
                *stop = YES ;
            }
        }] ;
        if (errorMessage) {
            return luaL_argerror(L, 2, errorMessage.UTF8String) ;
        } else {
            query.metadataSearch.searchScopes = newScopes ;
        }
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
        if (query.wantComplete) { lua_pushstring(L, "didFinish") ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; }
        if (query.wantStart)    { lua_pushstring(L, "didStart") ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; }
        if (query.wantUpdate)   { lua_pushstring(L, "didUpdate") ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; }
        if (query.wantProgress) { lua_pushstring(L, "inProgress") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; }
    } else {
        NSArray *items = [skin toNSObjectAtIndex:2] ;
        if ([items isKindOfClass:[NSString class]]) items = [NSArray arrayWithObject:items] ;
        if (![items isKindOfClass:[NSArray class]]) {
            return luaL_argerror(L, 2, "expected string or array of strings") ;
        }
        NSString __block *errorMessage ;
        NSArray *messages = @[ @"didFinish", @"didStart", @"didUpdate", @"inProgress" ] ;
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
            query.wantComplete = [items containsObject:@"didFinish"] ;
            query.wantStart    = [items containsObject:@"didStart"] ;
            query.wantUpdate   = [items containsObject:@"didUpdate"] ;
            query.wantProgress = [items containsObject:@"inProgress"] ;
            lua_pushvalue(L, 1) ;
        }
    }
    return 1 ;
}

static int spotlight_updateInterval(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, query.metadataSearch.notificationBatchingInterval) ;
    } else {
        query.metadataSearch.notificationBatchingInterval = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int spotlight_sortDescriptors(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:query.metadataSearch.sortDescriptors] ;
    } else {
        NSMutableArray *newDescriptors = [[NSMutableArray alloc] init] ;
        NSArray        *hopefuls       = [skin toNSObjectAtIndex:2] ;
        if (![hopefuls isKindOfClass:[NSArray class]]) hopefuls = [NSArray arrayWithObject:hopefuls] ;
        NSString __block *errorMessage ;
        if ([hopefuls isKindOfClass:[NSArray class]]) {
            [hopefuls enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj isKindOfClass:[NSSortDescriptor class]]) {
                    [newDescriptors addObject:obj] ;
                } else {
                    lua_rawgeti(L, 2, (lua_Integer)(idx + 1)) ;
                    NSSortDescriptor *candidate = toNSSortDescriptorFromLua(L, -1) ;
                    if (candidate) {
                        [newDescriptors addObject:candidate] ;
                    } else {
                        errorMessage = [NSString stringWithFormat:@"expected string or NSSortDescriptor table at index %lu", idx + 1] ;
                        *stop = YES ;
                    }
                    lua_pop(L, 1) ;
                }
            }] ;
        } else {
            errorMessage = @"expected an array of sort descriptors" ;
        }
        if (errorMessage) {
            return luaL_argerror(L, 2, errorMessage.UTF8String) ;
        } else {
            query.metadataSearch.sortDescriptors = newDescriptors ;
            lua_pushvalue(L, 1) ;
        }
    }
    return 1 ;
}

static int spotlight_valueListAttributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:query.metadataSearch.valueListAttributes] ;
    } else {
        NSArray *newAttributes = [skin toNSObjectAtIndex:2] ;
        if ([newAttributes isKindOfClass:[NSString class]]) newAttributes = [NSArray arrayWithObject:newAttributes] ;
        NSString __block *errorMessage ;
        if ([newAttributes isKindOfClass:[NSArray class]]) {
            [newAttributes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if (![obj isKindOfClass:[NSString class]]) {
                    errorMessage = [NSString stringWithFormat:@"expected string at index %lu", idx + 1] ;
                    *stop = YES ;
                }
            }] ;
        } else {
            errorMessage = @"expected an array of attribute strings" ;
        }
        if (errorMessage) {
            return luaL_argerror(L, 2, errorMessage.UTF8String) ;
        } else {
            query.metadataSearch.valueListAttributes = newAttributes ;
            lua_pushvalue(L, 1) ;
        }
    }
    return 1 ;
}

static int spotlight_groupingAttributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:query.metadataSearch.groupingAttributes] ;
    } else {
        NSArray *newAttributes = [skin toNSObjectAtIndex:2] ;
        if ([newAttributes isKindOfClass:[NSString class]]) newAttributes = [NSArray arrayWithObject:newAttributes] ;
        NSString __block *errorMessage ;
        if ([newAttributes isKindOfClass:[NSArray class]]) {
            [newAttributes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if (![obj isKindOfClass:[NSString class]]) {
                    errorMessage = [NSString stringWithFormat:@"expected string at index %lu", idx + 1] ;
                    *stop = YES ;
                }
            }] ;
        } else {
            errorMessage = @"expected an array of attribute strings" ;
        }
        if (errorMessage) {
            return luaL_argerror(L, 2, errorMessage.UTF8String) ;
        } else {
            query.metadataSearch.groupingAttributes = newAttributes ;
            lua_pushvalue(L, 1) ;
        }
    }
    return 1 ;
}

static int spotlight_start(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (query.metadataSearch.started && !query.metadataSearch.stopped) {
        [skin logInfo:@"query already started"] ;
    } else {
        if (query.metadataSearch.predicate) {
            [query.metadataSearch.operationQueue addOperationWithBlock:^{
                [query.metadataSearch startQuery];
            }];
        } else {
            return luaL_error(L, "no query defined") ;
        }
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int spotlight_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (query.metadataSearch.started && !query.metadataSearch.stopped) {
        [query.metadataSearch stopQuery] ;
    } else {
        [skin logInfo:@"query not running"] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int spotlight_isRunning(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, query.metadataSearch.started && !query.metadataSearch.stopped) ;
    return 1 ;
}

static int spotlight_isGathering(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, query.metadataSearch.gathering) ;
    return 1 ;
}

static int spotlight_predicate(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL |LS_TOPTIONAL, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:[query.metadataSearch.predicate predicateFormat]] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            query.metadataSearch.predicate = nil ;
        } else {
            NSString *errorMessage ;
            @try {
                NSPredicate *queryPredicate = [NSPredicate predicateWithFormat:[skin toNSObjectAtIndex:2]] ;
                query.metadataSearch.predicate = queryPredicate ;
            } @catch(NSException *exception) {
                errorMessage = exception.reason ;
            }
            if (errorMessage) return luaL_argerror(L, 2, errorMessage.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int spotlight_resultCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, (lua_Integer)query.metadataSearch.resultCount) ;
    return 1 ;
}

// faster and more memory efficient to mimic through metamethods
// static int spotlight_results(lua_State *L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
//     ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;
//
//     lua_newtable(L) ;
//     [query.metadataSearch enumerateResultsUsingBlock:^(id result, NSUInteger idx, __unused BOOL *stop){
//         [skin pushNSObject:result withOptions:LS_NSDescribeUnknownTypes] ; lua_rawseti(L, -2, (lua_Integer)(idx + 1)) ;
//     }] ;
//     return 1 ;
// }

static int spotlight_resultAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER| LS_TINTEGER, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    lua_Integer index = lua_tointeger(L, 2) ;
    NSUInteger  count = query.metadataSearch.resultCount ;
    if (index < 1 || index >(lua_Integer)count) {
        if (count == 0) {
            return luaL_argerror(L, 2, "result set is empty") ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index must be between 1 and %lu inclusive", count] UTF8String]) ;
        }
    } else {
        [query.metadataSearch disableUpdates] ;
        NSMetadataItem *item = [query.metadataSearch resultAtIndex:(NSUInteger)(index - 1)] ;
        [query.metadataSearch enableUpdates] ;
        [skin pushNSObject:item withOptions:LS_NSDescribeUnknownTypes] ;
    }
    return 1 ;
}

static int spotlight_attributesAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER| LS_TINTEGER, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    lua_Integer index = lua_tointeger(L, 2) ;
    NSUInteger  count = query.metadataSearch.resultCount ;
    if (index < 1 || index >(lua_Integer)count) {
        if (count == 0) {
            return luaL_argerror(L, 2, "result set is empty") ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index must be between 1 and %lu inclusive", count] UTF8String]) ;
        }
    } else {
        [query.metadataSearch disableUpdates] ;
        NSMetadataItem *item = [query.metadataSearch resultAtIndex:(NSUInteger)(index - 1)] ;
        [query.metadataSearch enableUpdates] ;
        if (item) {
            [skin pushNSObject:[item attributes] withOptions:LS_NSDescribeUnknownTypes] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int spotlight_attributeValueAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TNUMBER| LS_TINTEGER, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    NSString *attribute = [skin toNSObjectAtIndex:2] ;
    lua_Integer index = lua_tointeger(L, 3) ;
    NSUInteger  count = query.metadataSearch.resultCount ;
    if (index < 1 || index >(lua_Integer)count) {
        if (count == 0) {
            return luaL_argerror(L, 2, "result set is empty") ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index must be between 1 and %lu inclusive", count] UTF8String]) ;
        }
    } else {
        [query.metadataSearch disableUpdates] ;
        [skin pushNSObject:[query.metadataSearch valueOfAttribute:attribute forResultAtIndex:(NSUInteger)(index - 1)] withOptions:LS_NSDescribeUnknownTypes] ;
        [query.metadataSearch enableUpdates] ;
    }
    return 1 ;
}

static int spotlight_refinedSearch(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    ASMMetadataQuery *newQuery = [[ASMMetadataQuery alloc] init] ;
    if (newQuery) {
        [query.metadataSearch disableUpdates] ;
        newQuery.metadataSearch.searchItems = query.metadataSearch.results ;
        [query.metadataSearch enableUpdates] ;
    }

    [skin pushNSObject:newQuery] ;
    return 1 ;
}

static int spotlight_valueLists(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:query.metadataSearch.valueLists] ;
    return 1 ;
}

static int spotlight_groupedResults(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:query.metadataSearch.groupedResults] ;
    return 1 ;
}

#pragma mark - Module Group Methods

static int group_attribute(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, GROUP_UD_TAG, LS_TBREAK] ;
    NSMetadataQueryResultGroup *resultGroup = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:resultGroup.attribute] ;
    return 1 ;
}

static int group_value(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, GROUP_UD_TAG, LS_TBREAK] ;
    NSMetadataQueryResultGroup *resultGroup = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:resultGroup.value] ;
    return 1 ;
}

static int group_resultCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, GROUP_UD_TAG, LS_TBREAK] ;
    NSMetadataQueryResultGroup *resultGroup = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, (lua_Integer)resultGroup.resultCount) ;
    return 1 ;
}

static int group_resultAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, GROUP_UD_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    NSMetadataQueryResultGroup *resultGroup = [skin toNSObjectAtIndex:1] ;

    lua_Integer index = lua_tointeger(L, 2) ;
    NSUInteger  count = resultGroup.resultCount ;
    if (index < 1 || index >(lua_Integer)count) {
        if (count == 0) {
            return luaL_argerror(L, 2, "result set is empty") ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index must be between 1 and %lu inclusive", count] UTF8String]) ;
        }
    } else {
        [skin pushNSObject:[resultGroup resultAtIndex:(NSUInteger)(index - 1)]] ;
    }
    return 1 ;
}

static int group_subgroups(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, GROUP_UD_TAG, LS_TBREAK] ;
    NSMetadataQueryResultGroup *resultGroup = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:resultGroup.subgroups] ;
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

static int pushNSMetadataQueryResultGroup(lua_State *L, id obj) {
    NSMetadataQueryResultGroup *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(NSMetadataQueryResultGroup *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, GROUP_UD_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toNSMetadataQueryResultGroup(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSMetadataQueryResultGroup *value ;
    if (luaL_testudata(L, idx, GROUP_UD_TAG)) {
        value = get_objectFromUserdata(__bridge NSMetadataQueryResultGroup, L, idx, GROUP_UD_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", GROUP_UD_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSSortDescriptor(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSSortDescriptor *descriptor = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:descriptor.key] ; lua_setfield(L, -2, "key") ;
    lua_pushboolean(L, descriptor.ascending) ; lua_setfield(L, -2, "ascending") ;
    lua_pushstring(L, "NSSortDescriptor") ; lua_setfield(L, -2, "__luaSkinType") ;
    return 1 ;
}

static id toNSSortDescriptorFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSSortDescriptor *value ;
    idx = lua_absindex(L, idx) ;
    if (lua_type(L, idx) == LUA_TSTRING) {
        value = [NSSortDescriptor sortDescriptorWithKey:[skin toNSObjectAtIndex:idx] ascending:YES] ;
    } else if (lua_type(L, idx) == LUA_TTABLE) {
        if (lua_getfield(L, idx, "key") == LUA_TSTRING) {
            NSString *key = [skin toNSObjectAtIndex:-1] ;
            BOOL     ascending = YES ;
            if (lua_getfield(L, idx, "ascending") == LUA_TBOOLEAN) {
                ascending = (BOOL)lua_toboolean(L, -1) ;
            }
            lua_pop(L, 1) ;
            value = [NSSortDescriptor sortDescriptorWithKey:key ascending:ascending] ;
        } else {
            [skin logError:@"key field missing in NSSortDescriptor table"] ;
        }
        lua_pop(L, 1) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected string or table describing an NSSortDescriptor, found %s",
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSMetadataItem(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSMetadataItem *item = obj ;

// // because I want to figure out why we never get a URL when the docs suggest we should, at least when in our
// // own documents directory...
//     NSURL *URL = [item valueForAttribute:NSMetadataItemURLKey];
//     [skin logWarn:[NSString stringWithFormat:@"Forcing a URL:%@ (%@)", URL, [URL absoluteString]]] ;

    NSArray *attributes = item.attributes ;
    if (attributes) {
// under some circumstances, returns nil because of CFTypeRef conversion error... apparently something isn't
// bridging, causing entire conversion to fail
//         [skin pushNSObject:[item valuesForAttributes:attributes] withOptions:LS_NSDescribeUnknownTypes] ;
//     } else {
        lua_newtable(L) ;
        [attributes enumerateObjectsUsingBlock:^(NSString *key, __unused NSUInteger idx, __unused BOOL *stop) {
            id value = [item valueForAttribute:key] ;
            if (value) {
                [skin pushNSObject:value withOptions:LS_NSDescribeUnknownTypes] ;
                lua_setfield(L, -2, key.UTF8String) ;
            } else {
                CFTypeRef cfValue = (__bridge_retained CFTypeRef)[item valueForAttribute:key] ;
                if (cfValue) {
                    CFTypeID theType = CFGetTypeID(cfValue) ;
                    if (theType == CFBooleanGetTypeID()) {
                        lua_pushboolean(L, CFBooleanGetValue(cfValue)) ; lua_setfield(L, -2, key.UTF8String) ;
                    } else {
                        [skin logDebug:[NSString stringWithFormat:@"%s:pushNSMetadataItem - unknown CFTypeID of %ld for value for key %@ of %@", USERDATA_TAG, theType, key, item]] ;
                    }
                    CFRelease(cfValue) ;
                } else {
                    [skin logDebug:[NSString stringWithFormat:@"%s:pushNSMetadataItem - nil value for key %@ of %@", USERDATA_TAG, key, item]] ;
                }
            }
        }] ;
    } else {
        [skin logDebug:[NSString stringWithFormat:@"%s:pushNSMetadataItem - no attributes list for %@", USERDATA_TAG, item]] ;
        lua_pushnil(L) ;
    }
    if (lua_type(L, -1) == LUA_TTABLE) {
        lua_pushstring(L, "NSMetadataItem") ; lua_setfield(L, -2, "__luaSkinType") ;
    }
    return 1 ;
}

static int pushNSURL(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSURL *url = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:[url absoluteString]] ;
    lua_setfield(L, -2, "url") ;
    lua_pushstring(L, "NSURL") ; lua_setfield(L, -2, "__luaSkinType") ;
    return 1 ;
}

static id toNSURLFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSURL   *url ;
    idx = lua_absindex(L, idx) ;
    if (lua_type(L, idx) == LUA_TSTRING) {
        url = [NSURL URLWithString:[skin toNSObjectAtIndex:idx]] ;
    } else if (lua_type(L, idx) == LUA_TTABLE) {
        if (lua_getfield(L, idx, "url") == LUA_TSTRING) {
            url = [NSURL URLWithString:[skin toNSObjectAtIndex:-1]] ;
        }
        lua_pop(L, 1) ;
    }
    if (!url) {
        [skin logError:[NSString stringWithFormat:@"expected string or table describing an NSURL, found %s",
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return url ;
}

static int pushNSMetadataQueryAttributeValueTuple(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSMetadataQueryAttributeValueTuple *tuple = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:tuple.attribute] ;          lua_setfield(L, -2, "attribute") ;
    lua_pushinteger(L, (lua_Integer)tuple.count) ; lua_setfield(L, -2, "count") ;
    [skin pushNSObject:tuple.value] ;              lua_setfield(L, -2, "value") ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMMetadataQuery *obj = [skin luaObjectAtIndex:1 toClass:"ASMMetadataQuery"] ;
    NSString *title = obj.metadataSearch.predicate.predicateFormat ;
    if (!title) title = @"<undefined>" ;
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
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
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
            NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter] ;
            [notificationCenter removeObserver:obj name:NSMetadataQueryDidFinishGatheringNotification object:obj.metadataSearch];
            [notificationCenter removeObserver:obj name:NSMetadataQueryDidStartGatheringNotification  object:obj.metadataSearch];
            [notificationCenter removeObserver:obj name:NSMetadataQueryDidUpdateNotification          object:obj.metadataSearch];
            [notificationCenter removeObserver:obj name:NSMetadataQueryGatheringProgressNotification  object:obj.metadataSearch];
            if (!obj.metadataSearch.stopped) [obj.metadataSearch stopQuery] ;
            obj.metadataSearch = nil ;
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int group_userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSMetadataQueryResultGroup *obj = [skin luaObjectAtIndex:1 toClass:"NSMetadataQueryResultGroup"] ;
    NSString *title = obj.attribute ;
    if (!title) title = @"<undefined>" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", GROUP_UD_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int group_userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, GROUP_UD_TAG) && luaL_testudata(L, 2, GROUP_UD_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        NSMetadataQueryResultGroup *obj1 = [skin luaObjectAtIndex:1 toClass:"NSMetadataQueryResultGroup"] ;
        NSMetadataQueryResultGroup *obj2 = [skin luaObjectAtIndex:2 toClass:"NSMetadataQueryResultGroup"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int group_userdata_gc(lua_State* L) {
    NSMetadataQueryResultGroup *obj = get_objectFromUserdata(__bridge_transfer NSMetadataQueryResultGroup, L, 1, GROUP_UD_TAG) ;
    if (obj) obj = nil ;
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    if (moduleSearchQueue) {
        [moduleSearchQueue cancelAllOperations] ;
        [moduleSearchQueue waitUntilAllOperationsAreFinished] ;
        moduleSearchQueue = nil ;
    }
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"searchScopes",          spotlight_searchScopes},
    {"callback",              spotlight_callback},
    {"callbackMessages",      spotlight_callbackMessages},
    {"updateInterval",        spotlight_updateInterval},
    {"sortDescriptors",       spotlight_sortDescriptors},
    {"groupingAttributes",    spotlight_groupingAttributes},
    {"valueListAttributes",   spotlight_valueListAttributes},
    {"start",                 spotlight_start},
    {"stop",                  spotlight_stop},
    {"isRunning",             spotlight_isRunning},
    {"isGathering",           spotlight_isGathering},
    {"queryString",           spotlight_predicate},
// faster and more memory efficient to mimic through metamethods
//     {"results",               spotlight_results},
    {"resultCount",           spotlight_resultCount},
    {"resultAtIndex",         spotlight_resultAtIndex},
    {"attributesAtIndex",     spotlight_attributesAtIndex},
    {"attributeValueAtIndex", spotlight_attributeValueAtIndex},
    {"valueLists",            spotlight_valueLists},
    {"groupedResults",        spotlight_groupedResults},
    {"newRefinedQuery",       spotlight_refinedSearch},

    {"__tostring",            userdata_tostring},
    {"__eq",                  userdata_eq},
    {"__gc",                  userdata_gc},
    {NULL,                    NULL}
};

static const luaL_Reg group_userdata_metalib[] = {
    {"attribute",     group_attribute},
    {"value",         group_value},
    {"resultCount",   group_resultCount},
    {"resultAtIndex", group_resultAtIndex},
    {"subgroups",     group_subgroups},

    {"__tostring",    group_userdata_tostring},
    {"__eq",          group_userdata_eq},
    {"__gc",          group_userdata_gc},
    {NULL,            NULL}
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

    [skin registerObject:GROUP_UD_TAG objectFunctions:group_userdata_metalib] ;

    push_searchScopes(L) ;        lua_setfield(L, -2, "searchScopes") ;
    push_commonAttributeKeys(L) ; lua_setfield(L, -2, "commonAttributeKeys") ;

    [skin registerPushNSHelper:pushASMMetadataQuery                   forClass:"ASMMetadataQuery"];
    [skin registerLuaObjectHelper:toASMMetadataQueryFromLua           forClass:"ASMMetadataQuery"
                                                           withUserdataMapping:USERDATA_TAG];

    [skin registerPushNSHelper:pushNSMetadataQueryResultGroup         forClass:"NSMetadataQueryResultGroup"];
    [skin registerLuaObjectHelper:toNSMetadataQueryResultGroup        forClass:"NSMetadataQueryResultGroup"
                                                           withUserdataMapping:GROUP_UD_TAG];

    [skin registerPushNSHelper:pushNSMetadataItem                     forClass:"NSMetadataItem"] ;

    [skin registerPushNSHelper:pushNSMetadataQueryAttributeValueTuple forClass:"NSMetadataQueryAttributeValueTuple"] ;

    [skin registerPushNSHelper:pushNSSortDescriptor                   forClass:"NSSortDescriptor"] ;
    [skin registerLuaObjectHelper:toNSSortDescriptorFromLua           forClass:"NSSortDescriptor"
                                                              withTableMapping:"NSSortDescriptor"] ;

    // should probably move at some point, unless this module ends up in core
    [skin registerPushNSHelper:pushNSURL                              forClass:"NSURL"] ;
    [skin registerLuaObjectHelper:toNSURLFromLua                      forClass:"NSURL"
                                                              withTableMapping:"NSURL"] ;

    return 1;
}
