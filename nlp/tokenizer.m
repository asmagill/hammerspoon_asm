@import Cocoa ;
@import NaturalLanguage ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.nlp.tokenizer" ;
static LSRefTable         refTable     = LUA_NOREF ;

static NSDictionary<NSNumber *, NSString *> *tokenUnitMap ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSTokenizerWrapper : NSObject
@property int      selfRefCount ;
@property NSObject *tokenizer ;
@property NSString *language ;
@end

@implementation HSTokenizerWrapper
- (instancetype)initWithUnit:(NLTokenUnit)unit {
    self = [super init] ;
    if (self) {
        _selfRefCount = 0 ;
        if (@available(macOS 10.14, *)) {
            _tokenizer = [[NLTokenizer alloc] initWithUnit:unit] ;
        } else {
            _tokenizer = nil ;
        }
        _language = nil ;
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

/// hs._asm.nlp.tokenizer.new(unitType) -> tokenizerObject
/// Constructor
/// Creates a new tokenizer of the specified type.
///
/// Parameters:
///  * `unitType` - a string specifying the tokenizer type. Valid values can be found in the [hs._asm.nlp.tokenizer.types](#types) table.
///
/// Returns:
///  * the new tokenizer object.
static int tokenizer_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    NSString *unit       = [skin toNSObjectAtIndex:1] ;
    NSSet *keySetForUnit = [tokenUnitMap keysOfEntriesPassingTest:^BOOL(NSNumber *key, NSString *value, BOOL *stop) {
       BOOL found = [unit isEqualToString:value] ;
       if (found) {
          HSTokenizerWrapper *obj = [[HSTokenizerWrapper alloc] initWithUnit:key.integerValue] ;
          [skin pushNSObject:obj] ;
          *stop = YES ;
      }
       return found;
    }] ;
    if (keySetForUnit.count == 0) {
        return luaL_argerror(L, 1, [[NSString stringWithFormat:@"expected one of %@", [tokenUnitMap.allValues componentsJoinedByString:@", "]] UTF8String]) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int tokenizer_language(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSTokenizerWrapper *obj = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 10.14, *)) {
        if (lua_gettop(L) == 1) {
            [skin pushNSObject:obj.language] ;
        } else {
            NSString *language = (lua_type(L, 2) != LUA_TNIL) ? [skin toNSObjectAtIndex:2] : nil ;
            obj.language = language ;
            [(NLTokenizer *)obj.tokenizer setLanguage:language] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLTokenizer class requires macOS 10.14 (Mojave) or newer") ;
        return 2 ;
    }
    return 1 ;
}

static int tokenizer_type(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSTokenizerWrapper *obj = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 10.14, *)) {
        NSString *unitType = tokenUnitMap[@(((NLTokenizer *)obj.tokenizer).unit)] ;
        [skin pushNSObject:unitType] ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLTokenizer class requires macOS 10.14 (Mojave) or newer") ;
        return 2 ;
    }
    return 1 ;
}

static int tokenizer_tokensForRange(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TANY,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSTokenizerWrapper *obj  = [skin toNSObjectAtIndex:1] ;
    NSString           *text = getStringFromIndex(L, 2) ;
    lua_Integer i            = 1 ;
    lua_Integer j            = -1 ;
    int         callbackRef  = LUA_NOREF ;

    switch(lua_gettop(L)) {
        case 2: // don't need to change defaults set above
            break ;
        case 3:
            [skin checkArgs:LS_TANY, LS_TANY, LS_TNUMBER | LS_TINTEGER | LS_TFUNCTION, LS_TBREAK] ;
            if (lua_type(L, 3) == LUA_TNUMBER) {
                i = lua_tointeger(L, 3) ;
            } else {
                lua_pushvalue(L, 3) ;
                callbackRef = [skin luaRef:refTable] ;
            }
            break ;
        case 4:
            [skin checkArgs:LS_TANY, LS_TANY, LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER | LS_TFUNCTION, LS_TBREAK] ;
            i = lua_tointeger(L, 3) ;
            if (lua_type(L, 4) == LUA_TNUMBER) {
                j = lua_tointeger(L, 4) ;
            } else {
                lua_pushvalue(L, 4) ;
                callbackRef = [skin luaRef:refTable] ;
            }
            break ;
        case 5:
            [skin checkArgs:LS_TANY, LS_TANY, LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER, LS_TFUNCTION, LS_TBREAK] ;
            i = lua_tointeger(L, 3) ;
            j = lua_tointeger(L, 4) ;
            lua_pushvalue(L, 5) ;
            callbackRef = [skin luaRef:refTable] ;
            break ;
        default: // shouldn't happen because qty of args checked above, but just to be safe
            return luaL_argerror(L, 5, "expected no more than 5 arguments total") ;
    }

    if (@available(macOS 10.14, *)) {
        NLTokenizer *tokenizer = (NLTokenizer *)obj.tokenizer ;
        tokenizer.string       = text ;

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

        if (callbackRef == LUA_NOREF) {
            NSArray  *tokenRanges = [tokenizer tokensForRange:range] ;
            lua_newtable(L) ;
            for (NSValue *tokenRange in tokenRanges) {
// FIXME: should we return HS_TEXT_UTF16 if that's what was passed in? silly for word and sentence, but not for paragraph or document...
                [skin pushNSObject:[text substringWithRange:tokenRange.rangeValue]] ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                LuaSkin   *_skin = [LuaSkin sharedWithState:NULL] ;
                lua_State *_L    = _skin.L ;
                [tokenizer enumerateTokensInRange:range usingBlock:^(NSRange tokenRange, NLTokenizerAttributes flags, BOOL *stop) {
                    [_skin pushLuaRef:refTable ref:callbackRef] ;
// FIXME: should we return HS_TEXT_UTF16 if that's what was passed in? silly for word and sentence, but not for paragraph or document...
                    [_skin pushNSObject:[text substringWithRange:tokenRange]] ;
                    int argCount = 2 ;
                    switch(flags) {
                        case 0:                            argCount-- ; break ;
                        case NLTokenizerAttributeNumeric:  lua_pushstring(_L, "numeric") ;  break ;
                        case NLTokenizerAttributeEmoji:    lua_pushstring(_L, "emoji") ;    break ;
                        case NLTokenizerAttributeSymbolic: lua_pushstring(_L, "symbolic") ; break ;
                        default:
                            lua_pushfstring(_L, "** unrecognized flag value:%d", flags) ;
                    }
                    if ([_skin protectedCallAndTraceback:argCount nresults:1]) {
                        *stop = (BOOL)(lua_toboolean(_L, -1)) ;
                    } else {
                        [_skin logError:[NSString stringWithFormat:@"%s:tokens - callback error:%s", USERDATA_TAG, lua_tostring(_L, -1)]] ;
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
        lua_pushstring(L, "NLTokenizer class requires macOS 10.14 (Mojave) or newer") ;
        return 2 ;
    }
    return 1 ;
}

static int tokenizer_tokenRangeIncluding(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TANY,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSTokenizerWrapper *obj  = [skin toNSObjectAtIndex:1] ;
    NSString           *text = getStringFromIndex(L, 2) ;
    lua_Integer        i     = 1 ;
    lua_Integer        j     = -1 ;

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
        NLTokenizer *tokenizer  = (NLTokenizer *)obj.tokenizer ;
        tokenizer.string        = text ;

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

        NSRange tokenRange ;
        if (@available(macOS 11, *)) {
            if (lua_gettop(L) == 3) {
                tokenRange = [tokenizer tokenRangeAtIndex:(NSUInteger)i] ;
            } else {
                tokenRange = [tokenizer tokenRangeForRange:range] ;
            }
        } else {
            tokenRange = [tokenizer tokenRangeAtIndex:(NSUInteger)i] ;
        }

// FIXME do we need to adjust as per hs.text.regex for UTF8 vs UTF16?
        lua_pushinteger(L, (lua_Integer)(tokenRange.location + 1)) ;
        lua_pushinteger(L, (lua_Integer)(tokenRange.location + tokenRange.length)) ;
        return 2 ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLTokenizer class requires macOS 10.14 (Mojave) or newer") ;
        return 2 ;
    }
}

#pragma mark - Module Constants

/// hs._asm.nlp.tokenizer.types
/// Constant
/// Lookup table for tokenizer unit types
///
/// Notes:
///  * This table contains a list of the unit type strings recognized by the [hs._asm.nlp.tokenizer.new](#new) constructor.
///    * "word"      - tokenizes text into individual words
///    * "sentence"  - tokenizes text into sentences
///    * "paragraph" - tokenizes text into paragraphs
///    * "document"  - represents the document in its entirety
///
/// * It is expected that this table will be more useful (and this description expended accordingly) when I have a better understanding of the other NLP related classes and objects; one step at a time!
static int tokenizer_unitTypes(lua_State *L) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tokenUnitMap = @{
            @(NLTokenUnitWord)      : @"word",
            @(NLTokenUnitSentence)  : @"sentence",
            @(NLTokenUnitParagraph) : @"paragraph",
            @(NLTokenUnitDocument)  : @"document"
        } ;
    });

    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:tokenUnitMap.allValues] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSTokenizerWrapper(lua_State *L, id obj) {
    HSTokenizerWrapper *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSTokenizerWrapper *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSTokenizerWrapperFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSTokenizerWrapper *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSTokenizerWrapper, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG, lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSTokenizerWrapper *obj = [skin luaObjectAtIndex:1 toClass:"HSTokenizerWrapper"] ;
    NSString *title = @"** invalid" ;
    if (@available(macOS 10.14, *)) {
        title = tokenUnitMap[@(((NLTokenizer *)obj.tokenizer).unit)] ;
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSTokenizerWrapper *obj1 = [skin luaObjectAtIndex:1 toClass:"HSTokenizerWrapper"] ;
        HSTokenizerWrapper *obj2 = [skin luaObjectAtIndex:2 toClass:"HSTokenizerWrapper"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSTokenizerWrapper *obj = get_objectFromUserdata(__bridge_transfer HSTokenizerWrapper, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            obj.tokenizer = nil ;
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
    {"language",        tokenizer_language},
    {"type",            tokenizer_type},
    {"enumerateTokens", tokenizer_tokensForRange},
    {"tokenRange",      tokenizer_tokenRangeIncluding},

    {"__tostring",      userdata_tostring},
    {"__eq",            userdata_eq},
    {"__gc",            userdata_gc},
    {NULL,              NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", tokenizer_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_nlp_tokenizer(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    if (@available(macOS 10.14, *)) {
        refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                         functions:moduleLib
                                     metaFunctions:nil    // or module_metaLib
                                   objectFunctions:userdata_metaLib];

        [skin registerPushNSHelper:pushHSTokenizerWrapper         forClass:"HSTokenizerWrapper"];
        [skin registerLuaObjectHelper:toHSTokenizerWrapperFromLua forClass:"HSTokenizerWrapper"
                                                       withUserdataMapping:USERDATA_TAG];

        tokenizer_unitTypes(L) ; lua_setfield(L, -2, "types") ;
    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s - requires macOS 10.14 (Mojave) or newer", USERDATA_TAG]] ;
        lua_pushboolean(L, false) ;
    }

    return 1;
}
