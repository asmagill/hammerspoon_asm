@import Cocoa ;
@import NaturalLanguage ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.nlp.tagger" ;
static LSRefTable         refTable     = LUA_NOREF ;

static NSDictionary<NSString *, NSNumber *> *tokenUnits ;
static NSDictionary<NSString *, NSNumber *> *taggerOptions ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSNLTaggerWrapper : NSObject
@property int      selfRefCount ;
@property NSObject *tagger ;
@property BOOL     using_HS_TEXT_UTF16 ;
@end

@implementation HSNLTaggerWrapper
- (instancetype)initWithTagSchemes:(NSArray *)schemes {
    self = [super init] ;
    if (self) {
        _selfRefCount        = 0 ;
        _using_HS_TEXT_UTF16 = NO ;
        if (@available(macOS 10.14, *)) {
            _tagger          = [[NLTagger alloc] initWithTagSchemes:schemes] ;
        } else {
            _tagger          = nil ;
        }
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

static int pushHS_TEXT_UTF16(lua_State *L, NSString *string) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if ([skin requireModule:"hs.text"]) {
        lua_getfield(L, -1, "utf16") ; lua_remove(L, -2) ;
        lua_getfield(L, -1, "new") ;   lua_remove(L, -2) ;
        lua_pushlightuserdata(L, (__bridge void *)string) ;
        if (![skin protectedCallAndTraceback:1 nresults:1]) {
            NSString *errMsg = [skin toNSObjectAtIndex:-1] ;
            lua_pop(L, 1) ;
            return luaL_error(L, "unable to create hs.text.utf16 object: %s", errMsg.UTF8String) ;
        }
    } else {
        NSString *errMsg = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;
        return luaL_error(L, "unable to load hs.text module: %s", errMsg.UTF8String) ;
    }
    return 1 ;
}

#pragma mark - Module Functions

static int tagger_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    NSArray *schemes = [skin toNSObjectAtIndex:1] ;

    HSNLTaggerWrapper *obj = [[HSNLTaggerWrapper alloc] initWithTagSchemes:schemes] ;
    [skin pushNSObject:obj] ;
    return 1 ;
}

static int tagger_availableTagSchemesForUnit(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK] ;
    NSString          *unit     = [skin toNSObjectAtIndex:1] ;
    NSString          *language = [skin toNSObjectAtIndex:2] ;

    if (@available(macOS 10.14, *)) {
        NSNumber *unitNumber = tokenUnits[unit] ;
        if (!unitNumber) return luaL_argerror(L, 2, [[NSString stringWithFormat:@"unit must be one of %@", [tokenUnits.allKeys componentsJoinedByString:@", "]] UTF8String]) ;

        NSArray *results = [NLTagger availableTagSchemesForUnit:unitNumber.integerValue language:language] ;
        [skin pushNSObject:results] ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLTagger class requires macOS 10.14 (Mojave) or newer") ;
        return 2 ;
    }
    return 1 ;
}

static int tagger_requestAssetsForLanguage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TFUNCTION, LS_TBREAK] ;
    NSString          *scheme     = [skin toNSObjectAtIndex:1] ;
    NSString          *language   = [skin toNSObjectAtIndex:2] ;
    lua_pushvalue(L, 3) ;
    int               callbackRef = [skin luaRef:refTable] ;

    if (@available(macOS 10.15, *)) {
        [NLTagger requestAssetsForLanguage:language tagScheme:scheme completionHandler:^(NLTaggerAssetsResult result, NSError *error) {
            LuaSkin   *_skin = [LuaSkin sharedWithState:NULL] ;
            lua_State *_L    = _skin.L ;
            int       args   = 1 ;
            [_skin pushLuaRef:refTable ref:callbackRef] ;
            switch(result) {
                case NLTaggerAssetsResultAvailable:    lua_pushboolean(_L, true) ; break ;
                case NLTaggerAssetsResultNotAvailable: lua_pushboolean(_L, false) ; break ;
                case NLTaggerAssetsResultError:        lua_pushnil(_L) ; break ;
                default:
                    lua_pushnil(_L) ;
                    lua_pushfstring(_L, "** unrecognized results code %d", result) ;
                    args++ ;
            }
            if (error) {
                [_skin pushNSObject:error.localizedDescription] ;
                args++ ;
            }
            if (![_skin protectedCallAndTraceback:args nresults:0]) {
                [_skin logError:[NSString stringWithFormat:@"%s.requestScheme callback error:%s", USERDATA_TAG, lua_tostring(_L, -1)]] ;
                lua_pop(_L, 1) ;
            }
            [_skin luaUnref:refTable ref:callbackRef] ;
        }] ;
        lua_pushboolean(L, true) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "this function requires macOS 10.15 (Catalina) or newer") ;
        return 2 ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int tagget_tagSchemes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNLTaggerWrapper *obj = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 10.14, *)) {
        NLTagger *tagger = (NLTagger *)obj.tagger ;
        [skin pushNSObject:tagger.tagSchemes] ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLTagger class requires macOS 10.14 (Mojave) or newer") ;
        return 2 ;
    }
    return 1 ;
}

static int tagger_string(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSNLTaggerWrapper *obj = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 10.14, *)) {
        NLTagger *tagger = (NLTagger *)obj.tagger ;
        if (lua_gettop(L) == 1) {
            if (obj.using_HS_TEXT_UTF16) {
                pushHS_TEXT_UTF16(L, tagger.string) ;
            } else {
                [skin pushNSObject:tagger.string] ;
            }
        } else {
            NSString *newString = (lua_type(L, 2) != LUA_TNIL) ? getStringFromIndex(L, 2) : nil ;
            tagger.string           = newString ;
            obj.using_HS_TEXT_UTF16 = (BOOL)(lua_type(L, 2) == LUA_TUSERDATA) ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLTagger class requires macOS 10.14 (Mojave) or newer") ;
        return 2 ;
    }
    return 1 ;
}

static int tagger_setLanguageForRange(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING,
                    LS_TNUMBER | LS_TNUMBER | LS_TOPTIONAL,
                    LS_TNUMBER | LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSNLTaggerWrapper *obj      = [skin toNSObjectAtIndex:1] ;
    NSString          *language = [skin toNSObjectAtIndex:2] ;

    lua_Integer       i = 1 ;
    lua_Integer       j = -1 ;

    switch(lua_gettop(L)) {
        case 2: // don't need to change defaults set above
            break ;
        case 3:
            i = lua_tointeger(L, 3) ;
            break ;
        case 4:
            i = lua_tointeger(L, 3) ;
            j = lua_tointeger(L, 4) ;
            break ;
        default: // shouldn't happen because qty of args checked above, but just to be safe
            return luaL_argerror(L, 5, "expected no more than 4 arguments total") ;
    }

    if (@available(macOS 10.14, *)) {
        NLTagger *tagger  = (NLTagger *)obj.tagger ;
        NSString *text    = tagger.string ;

        // adjust indicies per lua standards
        lua_Integer length       = (lua_Integer)text.length ;

// FIXME do we need to adjust as per hs.text.regex for UTF8 vs UTF16?

        // adjust indicies per lua standards
        if (i < 0) i = length + 1 + i ; // negative indicies are from string end
        if (j < 0) j = length + 1 + j ; // negative indicies are from string end

        if ((i < 1) || (i > length)) return luaL_argerror(L, 2, "starting index out of range") ;
        if ((j < 1) || (j > length)) return luaL_argerror(L, 3, "ending index out of range") ;

        NSUInteger loc   = (NSUInteger)i - 1 ;
        NSUInteger len   = (NSUInteger)j - loc ;
        NSRange    range = NSMakeRange(loc, len) ;

        [tagger setLanguage:language range:range] ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLTagger class requires macOS 10.14 (Mojave) or newer") ;
        return 2 ;
    }
    return 1 ;
}

static int tagger_dominantLanguage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSNLTaggerWrapper *obj = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 10.14, *)) {
        if (lua_gettop(L) == 1) {
            NLTagger *tagger = (NLTagger *)obj.tagger ;
            [skin pushNSObject:tagger.dominantLanguage] ;
        } else {
            return tagger_setLanguageForRange(L) ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLTagger class requires macOS 10.14 (Mojave) or newer") ;
        return 2 ;
    }
    return 1 ;
}

// hs._asm.nlp.tagger:tags(unit, scheme, [options], [i], [j], [callback]) -> { { tag = string, start = integer, end = integer } }, ... } | self
static int tagger_enumerateTags(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING,
                    LS_TSTRING,
                    LS_TBREAK | LS_TVARARG] ;
    HSNLTaggerWrapper *obj    = [skin toNSObjectAtIndex:1] ;
    NSString          *unit   = [skin toNSObjectAtIndex:2] ;
    NSString          *scheme = [skin toNSObjectAtIndex:3] ;

    NSArray           *options    = [NSArray array] ;
    lua_Integer       i           =  1 ;
    lua_Integer       j           = -1 ;
    int               callbackRef = LUA_NOREF ;

    switch(lua_gettop(L)) {
        case 3: // don't need to change defaults set above
            break ;
        case 4:
            [skin checkArgs:LS_TANY, LS_TANY, LS_TANY, LS_TTABLE | LS_TNUMBER | LS_TINTEGER | LS_TFUNCTION, LS_TBREAK] ;
            if (lua_type(L, 4) == LUA_TTABLE) {
                options = [skin toNSObjectAtIndex:4] ;
            } else if (lua_type(L, 4) == LUA_TNUMBER) {
                i = lua_tointeger(L, 4) ;
            } else {
                lua_pushvalue(L, 4) ;
                callbackRef = [skin luaRef:refTable] ;
            }
            break ;
        case 5:
            if (lua_type(L, 4) == LUA_TTABLE) {
                [skin checkArgs:LS_TANY, LS_TANY, LS_TANY, LS_TTABLE, LS_TNUMBER | LS_TINTEGER | LS_TFUNCTION, LS_TBREAK] ;
                options = [skin toNSObjectAtIndex:4] ;
                if (lua_type(L, 5) == LUA_TNUMBER) {
                    i = lua_tointeger(L, 5) ;
                } else {
                    lua_pushvalue(L, 5) ;
                    callbackRef = [skin luaRef:refTable] ;
                }
            } else if (lua_type(L, 4) == LUA_TNUMBER) {
                [skin checkArgs:LS_TANY, LS_TANY, LS_TANY, LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER | LS_TFUNCTION, LS_TBREAK] ;
                i = lua_tointeger(L, 4) ;
                if (lua_type(L, 5) == LUA_TNUMBER) {
                    j = lua_tointeger(L, 5) ;
                } else {
                    lua_pushvalue(L, 5) ;
                    callbackRef = [skin luaRef:refTable] ;
                }
            }
            break ;
        case 6:
            if (lua_type(L, 4) == LUA_TTABLE) {
                [skin checkArgs:LS_TANY, LS_TANY, LS_TANY, LS_TTABLE, LS_TNUMBER | LS_TINTEGER,  LS_TNUMBER | LS_TINTEGER | LS_TFUNCTION, LS_TBREAK] ;
                options = [skin toNSObjectAtIndex:4] ;
                i = lua_tointeger(L, 5) ;
                if (lua_type(L, 6) == LUA_TNUMBER) {
                    j = lua_tointeger(L, 6) ;
                } else {
                    lua_pushvalue(L, 6) ;
                    callbackRef = [skin luaRef:refTable] ;
                }
            } else {
                [skin checkArgs:LS_TANY, LS_TANY, LS_TANY, LS_TNUMBER | LS_TINTEGER,  LS_TNUMBER | LS_TINTEGER, LS_TFUNCTION, LS_TBREAK] ;
                i = lua_tointeger(L, 4) ;
                j = lua_tointeger(L, 5) ;
                lua_pushvalue(L, 6) ;
                callbackRef = [skin luaRef:refTable] ;
            }
            break ;
        case 7:
            [skin checkArgs:LS_TANY, LS_TANY, LS_TANY, LS_TTABLE, LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER, LS_TFUNCTION, LS_TBREAK] ;
            options = [skin toNSObjectAtIndex:4] ;
            i = lua_tointeger(L, 5) ;
            j = lua_tointeger(L, 6) ;
            lua_pushvalue(L, 7) ;
            callbackRef = [skin luaRef:refTable] ;
            break ;
        default: // shouldn't happen because qty of args checked above, but just to be safe
            return luaL_argerror(L, 8, "expected no more than 7 arguments total") ;
    }

    if (@available(macOS 10.14, *)) {
        NLTagger *tagger  = (NLTagger *)obj.tagger ;
        NSString *text    = tagger.string ;

        // adjust indicies per lua standards
        lua_Integer length       = (lua_Integer)text.length ;

// FIXME do we need to adjust as per hs.text.regex for UTF8 vs UTF16?

        // adjust indicies per lua standards
        if (i < 0) i = length + 1 + i ; // negative indicies are from string end
        if (j < 0) j = length + 1 + j ; // negative indicies are from string end

        if ((i < 1) || (i > length)) return luaL_argerror(L, 2, "starting index out of range") ;
        if ((j < 1) || (j > length)) return luaL_argerror(L, 3, "ending index out of range") ;

        NSUInteger loc   = (NSUInteger)i - 1 ;
        NSUInteger len   = (NSUInteger)j - loc ;
        NSRange    range = NSMakeRange(loc, len) ;

        NLTaggerOptions optionsNumber = 0 ;
        BOOL            optionErr     = ![options isKindOfClass:[NSArray class]] ;
        if (!optionErr) {
            for (NSString *string in options) {
                if ([string isKindOfClass:[NSString class]]) {
                    NSNumber *number = taggerOptions[string] ;
                    if (number) {
                        optionsNumber = optionsNumber | number.unsignedIntegerValue ;
                        continue ;
                    }
                }
                optionErr = YES ;
                break ;
            }
        }
        if (optionErr) luaL_argerror(L, 4, [[NSString stringWithFormat:@"options must be a table containing zero or more of the following strings: %@", [tokenUnits.allKeys componentsJoinedByString:@", "]] UTF8String]) ;

        NSNumber *unitNumber = tokenUnits[unit] ;
        if (!unitNumber) return luaL_argerror(L, 2, [[NSString stringWithFormat:@"unit must be one of %@", [tokenUnits.allKeys componentsJoinedByString:@", "]] UTF8String]) ;

        if (callbackRef == LUA_NOREF) {
            NSArray *tokenRanges ;
            NSArray *tokens      = [tagger tagsInRange:range
                                                  unit:unitNumber.integerValue
                                                scheme:scheme
                                               options:optionsNumber
                                           tokenRanges:&tokenRanges] ;
            lua_newtable(L) ;
            for (NSUInteger idx = 0 ; idx < tokens.count ; idx++) {
                NSValue *tokenRange = tokenRanges[idx] ;
                lua_newtable(L) ;
                [skin pushNSObject:tokens[idx]] ;
                lua_setfield(L, -2, "tag") ;
// FIXME: should we return HS_TEXT_UTF16 is that's what was passed in? silly for word and sentence, but not for paragraph or document...
                [skin pushNSObject:[text substringWithRange:tokenRange.rangeValue]] ;
                lua_setfield(L, -2, "token") ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                LuaSkin   *_skin = [LuaSkin sharedWithState:NULL] ;
                lua_State *_L    = _skin.L ;
                [tagger enumerateTagsInRange:range unit:unitNumber.integerValue scheme:scheme options:optionsNumber
                                  usingBlock:^(NLTag tag, NSRange tokenRange, BOOL *stop) {
                    [_skin pushLuaRef:refTable ref:callbackRef] ;
                    [_skin pushNSObject:tag] ;
// FIXME: should we return HS_TEXT_UTF16 if that's what was passed in? silly for word and sentence, but not for paragraph or document...
                    [_skin pushNSObject:[text substringWithRange:tokenRange]] ;

                    if ([_skin protectedCallAndTraceback:2 nresults:1]) {
                        *stop = (BOOL)(lua_toboolean(_L, -1)) ;
                    } else {
                        [_skin logError:[NSString stringWithFormat:@"%s:enumerateTags - callback error:%s", USERDATA_TAG, lua_tostring(_L, -1)]] ;
                        *stop = YES ;
                    }
                    lua_pop(_L, 1) ;
                }] ;

                [_skin luaUnref:refTable ref:callbackRef] ;
            }) ;
            lua_pushvalue(L, 1) ;
        }

    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLTagger class requires macOS 10.14 (Mojave) or newer") ;
        return 2 ;
    }
    return 1 ;
}

// hs._asm.nlp.tagger:tag(unit, scheme, index, [max]) -> tag|table, i, j
//
//    - (NLTag)tagAtIndex:(NSUInteger)characterIndex unit:(NLTokenUnit)unit scheme:(NLTagScheme)scheme tokenRange:(NSRangePointer)tokenRange;
//    - (NSDictionary<NLTag,NSNumber *> *)tagHypothesesAtIndex:(NSUInteger)characterIndex unit:(NLTokenUnit)unit scheme:(NLTagScheme)scheme maximumCount:(NSUInteger)maximumCount tokenRange:(NSRangePointer)tokenRange;


// hs._asm.nlp:tokenRange(unit, [i], [j]) -> integer, integer
//

static int tagger_tokenRangeForUnit(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSNLTaggerWrapper *obj  = [skin toNSObjectAtIndex:1] ;
    NSString          *unit = [skin toNSObjectAtIndex:2] ;
    lua_Integer       i     =  1 ;
    lua_Integer       j     = -1 ;

    switch(lua_gettop(L)) {
        case 2: // don't need to change defaults set above
            break ;
        case 3:
            [skin checkArgs:LS_TANY, LS_TANY, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
            i = lua_tointeger(L, 3) ;
            break ;
        case 4:
            [skin checkArgs:LS_TANY, LS_TANY, LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
            i = lua_tointeger(L, 3) ;
            j = lua_tointeger(L, 4) ;
            if (@available(macOS 11, *)) {
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:tokenRange - specifying an ending index position is only supported on Big Sur and later", USERDATA_TAG]] ;
            }
            break ;
        default: // shouldn't happen because qty of args checked above, but just to be safe
            return luaL_argerror(L, 5, "expected no more than 4 arguments total") ;
    }

    if (@available(macOS 10.14, *)) {
        NLTagger *tagger = (NLTagger *)obj.tagger ;
        NSString * text  = tagger.string ;

        // adjust indicies per lua standards
        lua_Integer length       = (lua_Integer)text.length ;

// FIXME do we need to adjust as per hs.text.regex for UTF8 vs UTF16?

        // adjust indicies per lua standards
        if (i < 0) i = length + 1 + i ; // negative indicies are from string end
        if (j < 0) j = length + 1 + j ; // negative indicies are from string end

        if ((i < 1) || (i > length)) return luaL_argerror(L, 2, "starting index out of range") ;
        if ((j < 1) || (j > length)) return luaL_argerror(L, 3, "ending index out of range") ;

        NSUInteger loc   = (NSUInteger)i - 1 ;
        NSUInteger len   = (NSUInteger)j - loc ;
        NSRange    range = NSMakeRange(loc, len) ;

        NSNumber *unitNumber = tokenUnits[unit] ;
        if (!unitNumber) return luaL_argerror(L, 2, [[NSString stringWithFormat:@"unit must be one of %@", [tokenUnits.allKeys componentsJoinedByString:@", "]] UTF8String]) ;

        NSRange tokenRange ;
        if (@available(macOS 11, *)) {
            if (lua_gettop(L) == 3) {
                tokenRange = [tagger tokenRangeAtIndex:(NSUInteger)i unit:unitNumber.integerValue] ;
            } else {
                tokenRange = [tagger tokenRangeForRange:range unit:unitNumber.integerValue] ;
            }
        } else {
            tokenRange = [tagger tokenRangeAtIndex:(NSUInteger)i unit:unitNumber.integerValue] ;
        }

// FIXME do we need to adjust as per hs.text.regex for UTF8 vs UTF16?
        lua_pushinteger(L, (lua_Integer)(tokenRange.location + 1)) ;
        lua_pushinteger(L, (lua_Integer)(tokenRange.location + tokenRange.length)) ;
        return 2 ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLTagger class requires macOS 10.14 (Mojave) or newer") ;
        return 2 ;
    }
}

#pragma mark - Module Constants

static int tagger_tokenUnits(lua_State *L) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (@available(macOS 10.14, *)) {
            tokenUnits = @{
                @"word"      : @(NLTokenUnitWord),
                @"sentence"  : @(NLTokenUnitSentence),
                @"paragraph" : @(NLTokenUnitParagraph),
                @"document"  : @(NLTokenUnitDocument)
            } ;
        } else {
            tokenUnits = [NSDictionary dictionary] ;
        }
    }) ;

    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:tokenUnits.allKeys] ;
    return 1 ;
}

static int tagger_taggerOptions(lua_State *L) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (@available(macOS 10.14, *)) {
            taggerOptions = @{
                @"omitWords"        : @(NLTaggerOmitWords),
                @"omitPunctuation"  : @(NLTaggerOmitPunctuation),
                @"omitWhitespace"   : @(NLTaggerOmitWhitespace),
                @"omitOther"        : @(NLTaggerOmitOther),
                @"joinNames"        : @(NLTaggerJoinNames),
                @"joinContractions" : @(NLTaggerJoinContractions),
            } ;
        } else {
            taggerOptions = [NSDictionary dictionary] ;
        }
    }) ;

    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:taggerOptions.allKeys] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSNLTaggerWrapper(lua_State *L, id obj) {
    HSNLTaggerWrapper *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSNLTaggerWrapper *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSNLTaggerWrapperFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSNLTaggerWrapper *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSNLTaggerWrapper, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSNLTaggerWrapper *obj = [skin luaObjectAtIndex:1 toClass:"HSNLTaggerWrapper"] ;
    NSString *title = @"** invalid **" ;
    if (@available(macOS 10.14, *)) {
        NLTagger *tagger = (NLTagger *)obj.tagger ;
        title = [tagger.tagSchemes componentsJoinedByString:@", "] ;
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSNLTaggerWrapper *obj1 = [skin luaObjectAtIndex:1 toClass:"HSNLTaggerWrapper"] ;
        HSNLTaggerWrapper *obj2 = [skin luaObjectAtIndex:2 toClass:"HSNLTaggerWrapper"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSNLTaggerWrapper *obj = get_objectFromUserdata(__bridge_transfer HSNLTaggerWrapper, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            // other clean up as necessary
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
    {"text",             tagger_string},
    {"dominantLanguage", tagger_dominantLanguage},
    {"setLanguage",      tagger_setLanguageForRange},
    {"enumerateTags",    tagger_enumerateTags},
    {"tokenRange",       tagger_tokenRangeForUnit},
    {"tagSchemes",       tagget_tagSchemes},

    {"__tostring",       userdata_tostring},
    {"__eq",             userdata_eq},
    {"__gc",             userdata_gc},
    {NULL,               NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",             tagger_new},
    {"schemeAvailable", tagger_availableTagSchemesForUnit},
    {"requestScheme",   tagger_requestAssetsForLanguage},

    {NULL,     NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_nlp_tagger(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    if (@available(macOS 10.14, *)) {
        refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                         functions:moduleLib
                                     metaFunctions:nil    // or module_metaLib
                                   objectFunctions:userdata_metaLib];

        [skin registerPushNSHelper:pushHSNLTaggerWrapper         forClass:"HSNLTaggerWrapper"];
        [skin registerLuaObjectHelper:toHSNLTaggerWrapperFromLua forClass:"HSNLTaggerWrapper"
                                                      withUserdataMapping:USERDATA_TAG];

        tagger_tokenUnits(L) ;    lua_setfield(L, -2, "units") ;
        tagger_taggerOptions(L) ; lua_setfield(L, -2, "options") ;
    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s - requires macOS 10.14 (Mojave) or newer", USERDATA_TAG]] ;
        lua_pushboolean(L, false) ;
    }

    return 1;
}
