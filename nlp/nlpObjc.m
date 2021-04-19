@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.nlp" ;
static LSRefTable         refTable     = LUA_NOREF ;

#pragma mark - Module Functions

/// hs._asm.nlp.available() -> boolean
/// Function
/// Returns whether or not NLP support is available on this Mac or not.
///
/// Paramters:
///  * None
///
/// Returns:
///  * a boolean indicating if NLP support is available (true) or not (false).
///
/// Notes:
///  * the NLP methods used by this module are only available in macOS 10.14 (Mojave) or newer.
static int nlp_available(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    if (@available(macOS 10.14, *)) {
        lua_pushboolean(L, true) ;
    } else {
        lua_pushboolean(L, false) ;
    }
    return 1 ;
}

/// hs._asm.nlp.embeddingAvailable() -> boolean
/// Function
/// Returns whether or not NLP Embedding support is available on this Mac or not.
///
/// Paramters:
///  * None
///
/// Returns:
///  * a boolean indicating if NLP Embedding support is available (true) or not (false).
///
/// Notes:
///  * the NLP Embedding methods used by this module are only available in macOS 10.15 (Catalina) or newer.
static int nlp_embeddingAvailable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    if (@available(macOS 10.15, *)) {
        lua_pushboolean(L, true) ;
    } else {
        lua_pushboolean(L, false) ;
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

#if defined(SOURCE_PATH) && ! defined(RELEASE_VERSION)
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)
static int source_path(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushstring(L, TOSTRING(SOURCE_PATH)) ;
    return 1 ;
}
#undef TOSTRING
#undef STRINGIFY
#endif

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"available",          nlp_available},
    {"embeddingAvailable", nlp_embeddingAvailable},

#if defined(SOURCE_PATH) && ! defined(RELEASE_VERSION)
    {"_source_path", source_path},
#endif
    {NULL, NULL}
};

int luaopen_hs__asm_nlp_nlpObjc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:USERDATA_TAG
                           functions:moduleLib
                       metaFunctions:nil] ; // or module_metaLib

    if (@available(macOS 10.14, *)) {
    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s - requires macOS 10.14 (Mojave) or newer", USERDATA_TAG]] ;
    }

    return 1;
}
