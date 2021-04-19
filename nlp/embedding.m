@import Cocoa ;
@import NaturalLanguage ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.nlp.embedding" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSNLEmbeddingWrapper : NSObject
@property int      selfRefCount ;
@property NSObject *embedding ;
@property BOOL     sentence ;
@end

@implementation HSNLEmbeddingWrapper
- (instancetype)initWordEmbeddingForLanguage:(NSString *)language revision:(NSInteger)revision {
    self = [super init] ;
    if (self) {
        _selfRefCount  = 0 ;
        _sentence      = NO ;
        if (@available(macOS 10.15, *)) {
            _embedding = (revision == -1) ? [NLEmbedding wordEmbeddingForLanguage:language] :
                                            [NLEmbedding wordEmbeddingForLanguage:language revision:(NSUInteger)revision] ;
        } else {
            _embedding = nil ;
        }
    }
    return self ;
}

- (instancetype)initSentenceEmbeddingForLanguage:(NSString *)language revision:(NSInteger)revision {
    self = [super init] ;
    if (self) {
        _selfRefCount = 0 ;
        if (@available(macOS 11, *)) {
            _embedding = (revision == -1) ? [NLEmbedding sentenceEmbeddingForLanguage:language] :
                                            [NLEmbedding sentenceEmbeddingForLanguage:language revision:(NSUInteger)revision] ;
        } else {
            _embedding = nil ;
        }
        _sentence = YES ;
    }
    return self ;
}

@end

NSString *getStringFromIndex(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSString *result ;

    if (lua_type(L, idx) == LUA_TSTRING) {
        result = [skin toNSObjectAtIndex:idx] ;
    } else if (luaL_testudata(L, idx, "hs.text.utf16")) {
        SEL selector =  NSSelectorFromString(@"utf16string") ;
        NSObject *textUD = [skin toNSObjectAtIndex:idx] ;
        if ([textUD respondsToSelector:selector]) {
            IMP imp = [textUD methodForSelector:selector] ;

            // the following doesn't throw a leak warning during compilation, but it's basically:
            // [tokenizer setString:[textUD performSelector:selector]] ;
            id (*func)(id, SEL) = (id(*)(__strong id, SEL))imp ;
            result = func(textUD, selector) ;

        } else {
            luaL_argerror(L, idx, [[NSString stringWithFormat:@"hs.text.utf16 object doesn't recognize selector %@", NSStringFromSelector(selector)] UTF8String]) ;
        }
    } else {
        luaL_argerror(L, idx, "expected string or hs.text.utf16 object") ;
    }
    return result ;
}

#pragma mark - Module Functions

static int embedding_newWordEmbedding(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;

    NSString    *language = [skin toNSObjectAtIndex:1] ;
    lua_Integer revision  = (lua_gettop(L) > 1) ? lua_tointeger(L, 2) : -1 ;

    if (@available(macOS 10.15, *)) {
        HSNLEmbeddingWrapper *obj = [[HSNLEmbeddingWrapper alloc] initWordEmbeddingForLanguage:language revision:revision] ;
        if (obj && obj.embedding) {
            [skin pushNSObject:obj] ;
        } else {
            lua_pushnil(L) ;
            lua_pushstring(L, "embedding data for language not available") ;
            return 2 ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLEmbedding class requires macOS 10.15 (Catalina) or newer") ;
        return 2 ;
    }
    return 1 ;
}

static int embedding_newSentenceEmbedding(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;

    NSString    *language = [skin toNSObjectAtIndex:1] ;
    lua_Integer revision  = (lua_gettop(L) > 1) ? lua_tointeger(L, 2) : -1 ;

    if (@available(macOS 11, *)) {
        HSNLEmbeddingWrapper *obj = [[HSNLEmbeddingWrapper alloc] initSentenceEmbeddingForLanguage:language revision:revision] ;
        if (obj && obj.embedding) {
            [skin pushNSObject:obj] ;
        } else {
            lua_pushnil(L) ;
            lua_pushstring(L, "embedding data for language not available") ;
            return 2 ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLEmbedding class requires macOS 11 (Big Sur) or newer") ;
        return 2 ;
    }
    return 1 ;
}

static int embedding_currentRevisionForLanguage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    NSString *language = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 10.15, *)) {
        lua_pushinteger(L, (lua_Integer)[NLEmbedding currentRevisionForLanguage:language]) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLEmbedding class requires macOS 10.15 (Catalina) or newer") ;
        return 2 ;
    }

    return 1 ;
}

static int embedding_supportedRevisionsForLanguage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    NSString *language = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 10.15, *)) {
        [skin pushNSObject:[NLEmbedding supportedRevisionsForLanguage:language]] ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLEmbedding class requires macOS 10.15 (Catalina) or newer") ;
        return 2 ;
    }

    return 1 ;
}

static int embedding_currentSentenceEmbeddingRevisionForLanguage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    NSString *language = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 11, *)) {
        lua_pushinteger(L, (lua_Integer)[NLEmbedding currentSentenceEmbeddingRevisionForLanguage:language]) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLEmbedding class requires macOS 11 (Big Sur) or newer") ;
        return 2 ;
    }

    return 1 ;
}

static int embedding_supportedSentenceEmbeddingRevisionsForLanguage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    NSString *language = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 11, *)) {
        [skin pushNSObject:[NLEmbedding supportedSentenceEmbeddingRevisionsForLanguage:language]] ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLEmbedding class requires macOS 11 (Big Sur) or newer") ;
        return 2 ;
    }

    return 1 ;
}

#pragma mark - Module Methods

static int embedding_dimension(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNLEmbeddingWrapper *obj = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 10.15, *)) {
        lua_pushinteger(L, (lua_Integer)[(NLEmbedding *)obj.embedding dimension]) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLEmbedding class requires macOS 10.15 (Catalina) or newer") ;
        return 2 ;
    }

    return 1 ;
}

static int embedding_vocabularySize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNLEmbeddingWrapper *obj = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 10.15, *)) {
        lua_pushinteger(L, (lua_Integer)[(NLEmbedding *)obj.embedding vocabularySize]) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLEmbedding class requires macOS 10.15 (Catalina) or newer") ;
        return 2 ;
    }

    return 1 ;
}

static int embedding_language(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNLEmbeddingWrapper *obj = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 10.15, *)) {
        [skin pushNSObject:[(NLEmbedding *)obj.embedding language]] ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLEmbedding class requires macOS 10.15 (Catalina) or newer") ;
        return 2 ;
    }

    return 1 ;
}

static int embedding_revision(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNLEmbeddingWrapper *obj = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 10.15, *)) {
        lua_pushinteger(L, (lua_Integer)[(NLEmbedding *)obj.embedding revision]) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLEmbedding class requires macOS 10.15 (Catalina) or newer") ;
        return 2 ;
    }

    return 1 ;
}

static int embedding_containsString(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
    HSNLEmbeddingWrapper *obj  = [skin toNSObjectAtIndex:1] ;
    NSString             *text = getStringFromIndex(L, 2) ;

    if (@available(macOS 10.15, *)) {
        lua_pushboolean(L, [(NLEmbedding *)obj.embedding containsString:text]) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLEmbedding class requires macOS 10.15 (Catalina) or newer") ;
        return 2 ;
    }

    return 1 ;
}

static int embedding_vectorForString(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
    HSNLEmbeddingWrapper *obj  = [skin toNSObjectAtIndex:1] ;
    NSString             *text = getStringFromIndex(L, 2) ;

    if (@available(macOS 10.15, *)) {
        [skin pushNSObject:[(NLEmbedding *)obj.embedding vectorForString:text]] ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLEmbedding class requires macOS 10.15 (Catalina) or newer") ;
        return 2 ;
    }

    return 1 ;
}

static int embedding_distanceBetweenStrings(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TANY, LS_TBREAK] ;
    HSNLEmbeddingWrapper *obj   = [skin toNSObjectAtIndex:1] ;
    NSString             *text1 = getStringFromIndex(L, 2) ;
    NSString             *text2 = getStringFromIndex(L, 3) ;

    if (@available(macOS 10.15, *)) {
        lua_pushnumber(L, [(NLEmbedding *)obj.embedding distanceBetweenString:text1 andString:text2 distanceType:NLDistanceTypeCosine]) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLEmbedding class requires macOS 10.15 (Catalina) or newer") ;
        return 2 ;
    }

    return 1 ;
}

static int embedding_neighbors(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSNLEmbeddingWrapper *obj     = [skin toNSObjectAtIndex:1] ;
    NSArray              *vector  = (lua_type(L, 2) == LUA_TTABLE) ? [skin toNSObjectAtIndex:2] : nil ;
    NSString             *text    = (!vector) ? getStringFromIndex(L, 2) : nil ;
    NSUInteger           maxCount = (NSUInteger)lua_tointeger(L, 3) ;

    if (vector) {
        BOOL vectorIsGood = [vector isKindOfClass:[NSArray class]] ;
        if (vectorIsGood) {
            for (NSNumber *number in vector) {
                if (![number isKindOfClass:[NSNumber class]]) {
                    vectorIsGood = NO ;
                    break ;
                }
            }
        }
        if (!vectorIsGood) return luaL_argerror(L, 2, "expected table of numbers") ;
    }

    if (@available(macOS 10.15, *)) {
        if (lua_gettop(L) == 3) {
            if (text) {
                [skin pushNSObject:[(NLEmbedding *)obj.embedding neighborsForString:text
                                                                       maximumCount:maxCount
                                                                       distanceType:NLDistanceTypeCosine]] ;
            } else {
                [skin pushNSObject:[(NLEmbedding *)obj.embedding neighborsForVector:vector
                                                                       maximumCount:maxCount
                                                                       distanceType:NLDistanceTypeCosine]] ;
            }
        } else {
            if (text) {
                [skin pushNSObject:[(NLEmbedding *)obj.embedding neighborsForString:text
                                                                       maximumCount:maxCount
                                                                    maximumDistance:lua_tonumber(L, 4)
                                                                       distanceType:NLDistanceTypeCosine]] ;
            } else {
                [skin pushNSObject:[(NLEmbedding *)obj.embedding neighborsForVector:vector
                                                                       maximumCount:maxCount
                                                                    maximumDistance:lua_tonumber(L, 4)
                                                                       distanceType:NLDistanceTypeCosine]] ;
            }
        }

    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLEmbedding class requires macOS 10.15 (Catalina) or newer") ;
        return 2 ;
    }

    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSNLEmbeddingWrapper(lua_State *L, id obj) {
    HSNLEmbeddingWrapper *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSNLEmbeddingWrapper *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSNLEmbeddingWrapperFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSNLEmbeddingWrapper *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSNLEmbeddingWrapper, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

// Probably should be added to LuaSkin at some point...
static int pushNSIndexSet(lua_State *L, id obj) {
    NSIndexSet *value = obj ;

    lua_newtable(L) ;
    [value enumerateIndexesUsingBlock:^(NSUInteger idx, __unused BOOL *stop) {
        lua_pushinteger(L, (lua_Integer)idx) ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }];

    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSNLEmbeddingWrapper *obj = [skin luaObjectAtIndex:1 toClass:"HSNLEmbeddingWrapper"] ;
    NSString *title = obj.sentence ? @"sentance" : @"word" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSNLEmbeddingWrapper *obj1 = [skin luaObjectAtIndex:1 toClass:"HSNLEmbeddingWrapper"] ;
        HSNLEmbeddingWrapper *obj2 = [skin luaObjectAtIndex:2 toClass:"HSNLEmbeddingWrapper"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSNLEmbeddingWrapper *obj = get_objectFromUserdata(__bridge_transfer HSNLEmbeddingWrapper, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            // other clean up as necessary
            obj.embedding = nil ;
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
    {"contains",        embedding_containsString},
    {"dimension",       embedding_dimension},
    {"distanceBetween", embedding_distanceBetweenStrings},
    {"language",        embedding_language},
    {"neighbors",       embedding_neighbors},
    {"revision",        embedding_revision},
    {"vector",          embedding_vectorForString},
    {"vocabularySize",  embedding_vocabularySize},

    {"__tostring",      userdata_tostring},
    {"__eq",            userdata_eq},
    {"__gc",            userdata_gc},
    {NULL,              NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"word",                       embedding_newWordEmbedding},
    {"sentence",                   embedding_newSentenceEmbedding},

    {"revision",                   embedding_currentRevisionForLanguage},
    {"supportedRevisions",         embedding_supportedRevisionsForLanguage},
    {"sentenceRevision",           embedding_currentSentenceEmbeddingRevisionForLanguage},
    {"supportedSentenceRevisions", embedding_supportedSentenceEmbeddingRevisionsForLanguage},
    {NULL,                         NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_nlp_embedding(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    if (@available(macOS 10.15, *)) {
        refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                         functions:moduleLib
                                     metaFunctions:nil    // or module_metaLib
                                   objectFunctions:userdata_metaLib];

        [skin registerPushNSHelper:pushHSNLEmbeddingWrapper         forClass:"HSNLEmbeddingWrapper"];
        [skin registerLuaObjectHelper:toHSNLEmbeddingWrapperFromLua forClass:"HSNLEmbeddingWrapper"
                                                         withUserdataMapping:USERDATA_TAG];

        [skin registerPushNSHelper:pushNSIndexSet forClass:"NSIndexSet"];

    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s - requires macOS 10.15 (Catalina) or newer", USERDATA_TAG]] ;
        lua_pushboolean(L, false) ;
    }

    return 1;
}
