#import <Cocoa/Cocoa.h>
// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#define USERDATA_TAG "hs._asm.liguistictagger"
static int refTable = LUA_NOREF;
static int logFnRef = LUA_NOREF;

// #define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Testing out better logging with hs.logger

#define _cERROR   "ef"
#define _cWARN    "wf"
#define _cINFO    "f"
#define _cDEBUG   "df"
#define _cVERBOSE "vf"

// allow this to be potentially unused in the module
static int __unused log_to_console(lua_State *L, const char *level, NSString *theMessage) {
    lua_Debug functionDebugObject, callerDebugObject;
    int status = lua_getstack(L, 0, &functionDebugObject);
    status = status + lua_getstack(L, 1, &callerDebugObject);
    NSString *fullMessage = nil ;
    if (status == 2) {
        lua_getinfo(L, "n", &functionDebugObject);
        lua_getinfo(L, "Sl", &callerDebugObject);
        fullMessage = [NSString stringWithFormat:@"%s - %@ (%d:%s)", functionDebugObject.name,
                                                                     theMessage,
                                                                     callerDebugObject.currentline,
                                                                     callerDebugObject.short_src];
    } else {
        fullMessage = [NSString stringWithFormat:@"%s callback - %@", USERDATA_TAG,
                                                                      theMessage];
    }
    // Put it into the system logs, may help with troubleshooting
    CLS_NSLOG(@"%s: %@", USERDATA_TAG, fullMessage);

    // If hs.logger reference set, use it and the level will indicate whether the user sees it or not
    // otherwise we print to the console for everything, just in case we forget to register.
    if (logFnRef != LUA_NOREF) {
        [[LuaSkin shared] pushLuaRef:refTable ref:logFnRef];
        lua_getfield(L, -1, level); lua_remove(L, -2);
    } else {
        lua_getglobal(L, "print");
    }

    lua_pushstring(L, [fullMessage UTF8String]);
    if (![[LuaSkin shared] protectedCallAndTraceback:1 nresults:0]) { return lua_error(L); }
    return 0;
}

static int lua_registerLogForC(__unused lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TTABLE, LS_TBREAK];
    logFnRef = [[LuaSkin shared] luaRef:refTable];
    return 0;
}

// allow this to be potentially unused in the module
static int __unused my_lua_error(lua_State *L, NSString *theMessage) {
    lua_Debug functionDebugObject;
    lua_getstack(L, 0, &functionDebugObject);
    lua_getinfo(L, "n", &functionDebugObject);
    return luaL_error(L, [[NSString stringWithFormat:@"%s:%s - %@", USERDATA_TAG, functionDebugObject.name, theMessage] UTF8String]);
}

NSString *validateString(lua_State *L, int idx) {
    luaL_checkstring(L, idx) ; // convert numbers to a string, since that's what we want
    NSString *theString = [[LuaSkin shared] toNSObjectAtIndex:idx];
    if (![theString isKindOfClass:[NSString class]]) {
        log_to_console(L, _cWARN, @"string not valid UTF8");
        theString = nil;
    }
    return theString;
}

#pragma mark - Module Functions

static int availableTagSchemesForLanguage(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
// Can't find a good way to pre-validate the string, but an empty string is known to crash, so
// exempt it.
    NSString *theLanguage = validateString(L, 1) ;
    if (theLanguage && ![theLanguage isEqualToString:@""]) {
        [skin pushNSObject:[NSLinguisticTagger availableTagSchemesForLanguage:theLanguage]] ;
    } else {
        return my_lua_error(L, @"not valid UTF8 or string is empty") ;
    }
    return 1 ;
}

static int tagsForString(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, // sentence to parse
                    LS_TSTRING | LS_TNUMBER, // language
                    LS_TSTRING | LS_TNUMBER, // scheme
                    LS_TNUMBER, LS_TBREAK] ; // options

    NSString *textToParse = validateString(L, 1) ;
    NSString *language    = validateString(L, 2) ;
    NSString *scheme      = validateString(L, 3) ;
    luaL_checkinteger(L, 4) ;
    NSUInteger options    = (NSUInteger)lua_tointeger(L, 4) ;

    if (!textToParse)
        return my_lua_error(L, @"text is not valid UTF8") ;
    if (!language || [language isEqualToString:@""])
        return my_lua_error(L, @"language is not valid UTF8 or string is empty") ;
    if (!scheme)
        return my_lua_error(L, @"scheme is not valid UTF8") ;

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

    {"_registerLogForC", lua_registerLogForC},
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
//    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
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
