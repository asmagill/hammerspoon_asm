#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG "hs._asm.liguistictagger"
static LSRefTable refTable = LUA_NOREF;
static int logFnRef = LUA_NOREF;

// #define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Module Functions

static int availableTagSchemesForLanguage(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
// Can't find a good way to pre-validate the string, but an empty string is known to crash, so
// exempt it.
    // force numbers to be strings
    luaL_checkstring(L, 1) ;
    NSString *theLanguage = [skin toNSObjectAtIndex:1] ;
    if (theLanguage && ![theLanguage isEqualToString:@""]) {
        [skin pushNSObject:[NSLinguisticTagger availableTagSchemesForLanguage:theLanguage]] ;
    } else {
        return luaL_error(L, "not valid UTF8 or string is empty") ;
    }
    return 1 ;
}

static int tagsForString(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, // sentence to parse
                    LS_TSTRING | LS_TNUMBER, // language
                    LS_TSTRING | LS_TNUMBER, // scheme
                    LS_TNUMBER, LS_TBREAK] ; // options

    // force numbers to be strings
    luaL_checkstring(L, 1) ; luaL_checkstring(L, 2) ; luaL_checkstring(L, 3) ;
    NSString *textToParse = [skin toNSObjectAtIndex:1] ;
    NSString *language    = [skin toNSObjectAtIndex:2] ;
    NSString *scheme      = [skin toNSObjectAtIndex:3] ;
    luaL_checkinteger(L, 4) ;
    NSUInteger options    = (NSUInteger)lua_tointeger(L, 4) ;

    if (!textToParse) return luaL_error(L, "text is not valid UTF8") ;
    if (!language || [language isEqualToString:@""])
        return luaL_error(L, "language is not valid UTF8 or string is empty") ;
    if (!scheme) return luaL_error(L, "scheme is not valid UTF8") ;

    NSLinguisticTagger *tagger = [[NSLinguisticTagger alloc]
                                  initWithTagSchemes:[NSLinguisticTagger availableTagSchemesForLanguage:language]
                                             options:options];
    tagger.string = textToParse ;

    lua_newtable(L) ;
    [tagger enumerateTagsInRange:NSMakeRange(0, [textToParse length])
                          scheme:scheme
                         options:options
                      usingBlock:^(NSString *tag, NSRange tokenRange, __unused NSRange sentenceRange,
                                   __unused BOOL *stop) {
        lua_newtable(L) ;
        [skin pushNSObject:tag] ;                                            lua_setfield(L, -2, "tag") ;
        [skin pushNSObject:[textToParse substringWithRange:tokenRange]] ;    lua_setfield(L, -2, "token") ;
//         [skin pushNSObject:[textToParse substringWithRange:sentenceRange]] ; lua_setfield(L, -2, "fragment") ;

// really should convert these to lua indexes because lua treats multi-byte UTF8 sequences as multiple index
// positions while objective-c treats a UTF8 char the same as any other char no matter how many bytes it
// takes.  See hs.styledtext and/or hs.speech.
        lua_newtable(L) ;
        lua_pushinteger(L, (lua_Integer)tokenRange.location) ; lua_setfield(L, -2, "location") ;
        lua_pushinteger(L, (lua_Integer)tokenRange.length) ;   lua_setfield(L, -2, "length") ;
        lua_setfield(L, -2, "tokenRange") ;
//         lua_newtable(L) ;
//         lua_pushinteger(L, (lua_Integer)sentenceRange.location) ; lua_setfield(L, -2, "location") ;
//         lua_pushinteger(L, (lua_Integer)sentenceRange.length) ;   lua_setfield(L, -2, "length") ;
//         lua_setfield(L, -2, "sentenceRange") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }];

    return 1 ;
}

#pragma mark - Module Methods

#pragma mark - Module Constants

static int pushLinguisticTaggerOptions(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSLinguisticTaggerOmitWords) ;       lua_setfield(L, -2, "omitWords") ;
    lua_pushinteger(L, NSLinguisticTaggerOmitPunctuation) ; lua_setfield(L, -2, "omitPunctuation") ;
    lua_pushinteger(L, NSLinguisticTaggerOmitWhitespace) ;  lua_setfield(L, -2, "omitWhitespace") ;
    lua_pushinteger(L, NSLinguisticTaggerOmitOther) ;       lua_setfield(L, -2, "omitOther") ;
    lua_pushinteger(L, NSLinguisticTaggerJoinNames) ;       lua_setfield(L, -2, "joinNames") ;
    return 1 ;
}

static int pushLinguisticTagSchemes(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
    [skin pushNSObject:NSLinguisticTagSchemeTokenType] ;              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSLinguisticTagSchemeLexicalClass] ;           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSLinguisticTagSchemeNameType] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSLinguisticTagSchemeNameTypeOrLexicalClass] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSLinguisticTagSchemeLemma] ;                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSLinguisticTagSchemeLanguage] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSLinguisticTagSchemeScript] ;                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    return 1 ;
}

// Return types, not options or parameters to a function
//
// static int pushLinguisticTagSchemeTokenTypes(lua_State *L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     lua_newtable(L) ;
//     [skin pushNSObject:NSLinguisticTagWord] ;        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagPunctuation] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagWhitespace] ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagOther] ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     return 1 ;
// }
//
// static int pushLinguisticTagSchemeLexicalClasses(lua_State *L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     lua_newtable(L) ;
//     [skin pushNSObject:NSLinguisticTagNoun] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagVerb] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagAdjective] ;          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagAdverb] ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagPronoun] ;            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagDeterminer] ;         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagParticle] ;           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagPreposition] ;        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagNumber] ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagConjunction] ;        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagInterjection] ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagClassifier] ;         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagIdiom] ;              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagOtherWord] ;          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagSentenceTerminator] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagOpenQuote] ;          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagCloseQuote] ;         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagOpenParenthesis] ;    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagCloseParenthesis] ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagWordJoiner] ;         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagDash] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagOtherPunctuation] ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagParagraphBreak] ;     lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagOtherWhitespace] ;    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     return 1 ;
// }
//
// static int pushLinguisticTagSchemeNameTypes(lua_State *L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     lua_newtable(L) ;
//     [skin pushNSObject:NSLinguisticTagPersonalName] ;     lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagPlaceName] ;        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     [skin pushNSObject:NSLinguisticTagOrganizationName] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//     return 1 ;
// }

#pragma mark - Lua Infrastructure

// static int userdata_tostring(lua_State* L) {
// }

// static int userdata_eq(lua_State* L) {
// }

// static int userdata_gc(lua_State* L) {
//     return 0 ;
// }

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
//     {"__tostring", userdata_tostring},
//     {"__eq",       userdata_eq},
//     {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"schemesForLanguage", availableTagSchemesForLanguage},
    {"tagsForString", tagsForString},

    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_linguistictagger_internal(lua_State* __unused L) {
// Use this if your module doesn't have a module specific object that it returns.
//    refTable = [[LuaSkin shared] registerLibrary:USERDATA_TAG functions:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [[LuaSkin shared] registerLibraryWithObject:USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

    logFnRef = LUA_NOREF;

    pushLinguisticTaggerOptions(L)           ; lua_setfield(L, -2, "options") ;
    pushLinguisticTagSchemes(L)              ; lua_setfield(L, -2, "schemes") ;
//     pushLinguisticTagSchemeTokenTypes(L)     ; lua_setfield(L, -2, "tokenTypes") ;
//     pushLinguisticTagSchemeLexicalClasses(L) ; lua_setfield(L, -2, "lexicalClasses") ;
//     pushLinguisticTagSchemeNameTypes(L)      ; lua_setfield(L, -2, "nameTypes") ;

    return 1;
}
