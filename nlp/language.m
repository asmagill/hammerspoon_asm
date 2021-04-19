@import Cocoa ;
@import NaturalLanguage ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.nlp.language" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSNLLanguageRecognizerWrapper : NSObject
@property int      selfRefCount ;
@property NSObject *languageRecognizer ;
@end

@implementation HSNLLanguageRecognizerWrapper
- (instancetype)initWithString:(NSString *)text {
    self = [super init] ;
    if (self) {
        _selfRefCount           = 0 ;
        if (@available(macOS 10.14, *)) {
            _languageRecognizer = [[NLLanguageRecognizer alloc] init] ;
            [(NLLanguageRecognizer *)_languageRecognizer processString:text] ;
        } else {
            _languageRecognizer = nil ;
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

#pragma mark - Module Functions

static int language_recognizer(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    NSString *text = getStringFromIndex(L, 1) ;
    HSNLLanguageRecognizerWrapper *obj = [[HSNLLanguageRecognizerWrapper alloc] initWithString:text] ;
    [skin pushNSObject:obj] ;
    return 1 ;
}


#pragma mark - Module Methods

static int language_dominantLanguage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNLLanguageRecognizerWrapper *obj = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 10.14, *)) {
        [skin pushNSObject:[(NLLanguageRecognizer *)obj.languageRecognizer dominantLanguage]] ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLLanguageRecognizer class requires macOS 10.14 (Mojave) or newer") ;
        return 2 ;
    }

    return 1 ;
}

static int language_hypothesis(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSNLLanguageRecognizerWrapper *obj = [skin toNSObjectAtIndex:1] ;
    NSUInteger                    max = (NSUInteger)lua_tointeger(L, 2) ;

    if (@available(macOS 10.14, *)) {
        [skin pushNSObject:[(NLLanguageRecognizer *)obj.languageRecognizer languageHypothesesWithMaximum:max]] ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "NLLanguageRecognizer class requires macOS 10.14 (Mojave) or newer") ;
        return 2 ;
    }

    return 1 ;
}

#pragma mark - Module Constants

static int language_languages(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    lua_newtable(L) ;
    if (@available(macOS 10.14, *)) {
        [skin pushNSObject:NLLanguageAmharic] ;            lua_setfield(L, -2, "Amharic") ;
        [skin pushNSObject:NLLanguageArabic] ;             lua_setfield(L, -2, "Arabic") ;
        [skin pushNSObject:NLLanguageArmenian] ;           lua_setfield(L, -2, "Armenian") ;
        [skin pushNSObject:NLLanguageBengali] ;            lua_setfield(L, -2, "Bengali") ;
        [skin pushNSObject:NLLanguageBulgarian] ;          lua_setfield(L, -2, "Bulgarian") ;
        [skin pushNSObject:NLLanguageBurmese] ;            lua_setfield(L, -2, "Burmese") ;
        [skin pushNSObject:NLLanguageCatalan] ;            lua_setfield(L, -2, "Catalan") ;
        [skin pushNSObject:NLLanguageCherokee] ;           lua_setfield(L, -2, "Cherokee") ;
        [skin pushNSObject:NLLanguageCroatian] ;           lua_setfield(L, -2, "Croatian") ;
        [skin pushNSObject:NLLanguageCzech] ;              lua_setfield(L, -2, "Czech") ;
        [skin pushNSObject:NLLanguageDanish] ;             lua_setfield(L, -2, "Danish") ;
        [skin pushNSObject:NLLanguageDutch] ;              lua_setfield(L, -2, "Dutch") ;
        [skin pushNSObject:NLLanguageEnglish] ;            lua_setfield(L, -2, "English") ;
        [skin pushNSObject:NLLanguageFinnish] ;            lua_setfield(L, -2, "Finnish") ;
        [skin pushNSObject:NLLanguageFrench] ;             lua_setfield(L, -2, "French") ;
        [skin pushNSObject:NLLanguageGeorgian] ;           lua_setfield(L, -2, "Georgian") ;
        [skin pushNSObject:NLLanguageGerman] ;             lua_setfield(L, -2, "German") ;
        [skin pushNSObject:NLLanguageGreek] ;              lua_setfield(L, -2, "Greek") ;
        [skin pushNSObject:NLLanguageGujarati] ;           lua_setfield(L, -2, "Gujarati") ;
        [skin pushNSObject:NLLanguageHebrew] ;             lua_setfield(L, -2, "Hebrew") ;
        [skin pushNSObject:NLLanguageHindi] ;              lua_setfield(L, -2, "Hindi") ;
        [skin pushNSObject:NLLanguageHungarian] ;          lua_setfield(L, -2, "Hungarian") ;
        [skin pushNSObject:NLLanguageIcelandic] ;          lua_setfield(L, -2, "Icelandic") ;
        [skin pushNSObject:NLLanguageIndonesian] ;         lua_setfield(L, -2, "Indonesian") ;
        [skin pushNSObject:NLLanguageItalian] ;            lua_setfield(L, -2, "Italian") ;
        [skin pushNSObject:NLLanguageJapanese] ;           lua_setfield(L, -2, "Japanese") ;
        [skin pushNSObject:NLLanguageKannada] ;            lua_setfield(L, -2, "Kannada") ;
        [skin pushNSObject:NLLanguageKhmer] ;              lua_setfield(L, -2, "Khmer") ;
        [skin pushNSObject:NLLanguageKorean] ;             lua_setfield(L, -2, "Korean") ;
        [skin pushNSObject:NLLanguageLao] ;                lua_setfield(L, -2, "Lao") ;
        [skin pushNSObject:NLLanguageMalay] ;              lua_setfield(L, -2, "Malay") ;
        [skin pushNSObject:NLLanguageMalayalam] ;          lua_setfield(L, -2, "Malayalam") ;
        [skin pushNSObject:NLLanguageMarathi] ;            lua_setfield(L, -2, "Marathi") ;
        [skin pushNSObject:NLLanguageMongolian] ;          lua_setfield(L, -2, "Mongolian") ;
        [skin pushNSObject:NLLanguageNorwegian] ;          lua_setfield(L, -2, "Norwegian") ;
        [skin pushNSObject:NLLanguageOriya] ;              lua_setfield(L, -2, "Oriya") ;
        [skin pushNSObject:NLLanguagePersian] ;            lua_setfield(L, -2, "Persian") ;
        [skin pushNSObject:NLLanguagePolish] ;             lua_setfield(L, -2, "Polish") ;
        [skin pushNSObject:NLLanguagePortuguese] ;         lua_setfield(L, -2, "Portuguese") ;
        [skin pushNSObject:NLLanguagePunjabi] ;            lua_setfield(L, -2, "Punjabi") ;
        [skin pushNSObject:NLLanguageRomanian] ;           lua_setfield(L, -2, "Romanian") ;
        [skin pushNSObject:NLLanguageRussian] ;            lua_setfield(L, -2, "Russian") ;
        [skin pushNSObject:NLLanguageSimplifiedChinese] ;  lua_setfield(L, -2, "SimplifiedChinese") ;
        [skin pushNSObject:NLLanguageSinhalese] ;          lua_setfield(L, -2, "Sinhalese") ;
        [skin pushNSObject:NLLanguageSlovak] ;             lua_setfield(L, -2, "Slovak") ;
        [skin pushNSObject:NLLanguageSpanish] ;            lua_setfield(L, -2, "Spanish") ;
        [skin pushNSObject:NLLanguageSwedish] ;            lua_setfield(L, -2, "Swedish") ;
        [skin pushNSObject:NLLanguageTamil] ;              lua_setfield(L, -2, "Tamil") ;
        [skin pushNSObject:NLLanguageTelugu] ;             lua_setfield(L, -2, "Telugu") ;
        [skin pushNSObject:NLLanguageThai] ;               lua_setfield(L, -2, "Thai") ;
        [skin pushNSObject:NLLanguageTibetan] ;            lua_setfield(L, -2, "Tibetan") ;
        [skin pushNSObject:NLLanguageTraditionalChinese] ; lua_setfield(L, -2, "TraditionalChinese") ;
        [skin pushNSObject:NLLanguageTurkish] ;            lua_setfield(L, -2, "Turkish") ;
        [skin pushNSObject:NLLanguageUkrainian] ;          lua_setfield(L, -2, "Ukrainian") ;
        [skin pushNSObject:NLLanguageUrdu] ;               lua_setfield(L, -2, "Urdu") ;
        [skin pushNSObject:NLLanguageVietnamese] ;         lua_setfield(L, -2, "Vietnamese") ;
        [skin pushNSObject:NLLanguageUndetermined] ;       lua_setfield(L, -2, "Undetermined") ;
    }
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSNLLanguageRecognizerWrapper(lua_State *L, id obj) {
    HSNLLanguageRecognizerWrapper *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSNLLanguageRecognizerWrapper *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSNLLanguageRecognizerWrapperFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSNLLanguageRecognizerWrapper *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSNLLanguageRecognizerWrapper, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     HSNLLanguageRecognizerWrapper *obj = [skin luaObjectAtIndex:1 toClass:"HSNLLanguageRecognizerWrapper"] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSNLLanguageRecognizerWrapper *obj1 = [skin luaObjectAtIndex:1 toClass:"HSNLLanguageRecognizerWrapper"] ;
        HSNLLanguageRecognizerWrapper *obj2 = [skin luaObjectAtIndex:2 toClass:"HSNLLanguageRecognizerWrapper"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSNLLanguageRecognizerWrapper *obj = get_objectFromUserdata(__bridge_transfer HSNLLanguageRecognizerWrapper, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            // other clean up as necessary
            obj.languageRecognizer = nil ;
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
    {"dominant",      language_dominantLanguage},
    {"probabilities", language_hypothesis},

    {"__tostring",    userdata_tostring},
    {"__eq",          userdata_eq},
    {"__gc",          userdata_gc},
    {NULL,            NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"recognizer", language_recognizer},
    {NULL,         NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_nlp_language(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    if (@available(macOS 10.14, *)) {
        refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                         functions:moduleLib
                                     metaFunctions:nil    // or module_metaLib
                                   objectFunctions:userdata_metaLib];

        [skin registerPushNSHelper:pushHSNLLanguageRecognizerWrapper         forClass:"HSNLLanguageRecognizerWrapper"];
        [skin registerLuaObjectHelper:toHSNLLanguageRecognizerWrapperFromLua forClass:"HSNLLanguageRecognizerWrapper"
                                                                  withUserdataMapping:USERDATA_TAG];

        language_languages(L) ; lua_setfield(L, -2, "languages") ;

    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s - requires macOS 10.14 (Mojave) or newer", USERDATA_TAG]] ;
        lua_pushboolean(L, false) ;
    }

    return 1;
}
