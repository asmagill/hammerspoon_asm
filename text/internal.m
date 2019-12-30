@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs.text" ;
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSTextObject : NSObject
@property NSData           *contents ;
@property int              selfRef ;
@property int              selfRefCount ;
@property NSStringEncoding encoding ;
@end

@implementation HSTextObject

- (instancetype)init:(NSData *)data withEncoding:(NSStringEncoding)encoding {
    self = [super init] ;
    if (self) {
        _contents     = data ;
        _selfRef      = LUA_NOREF ;
        _selfRefCount = 0 ;
        _encoding    = encoding ;
    }
    return self ;
}

@end

#pragma mark - Module Functions

static int text_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK | LS_TVARARG] ;
    NSData *rawData = [skin toNSObjectAtIndex:1 withOptions:LS_NSLuaStringAsDataOnly] ;

    BOOL             hasEncoding = (lua_gettop(L) > 1 && lua_type(L, 2) == LUA_TNUMBER) ;
    NSStringEncoding encoding ;

    if (hasEncoding) {
        [skin checkArgs:LS_TSTRING, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
        encoding = (NSStringEncoding)lua_tointeger(L, 2) ;
    } else {
        [skin checkArgs:LS_TSTRING, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
        BOOL     allowLossy     = (lua_gettop(L) > 1 && lua_type(L, 2) == LUA_TBOOLEAN) ? (BOOL)lua_toboolean(L, 2) : NO ;
        BOOL     includeWindows = (lua_gettop(L) > 2 && lua_type(L, 3) == LUA_TBOOLEAN) ? (BOOL)lua_toboolean(L, 3) : NO ;
        NSString *string        = nil ;
        BOOL     usedLossy      = NO ;

        encoding = [NSString stringEncodingForData:rawData
                                   encodingOptions:@{
                                       NSStringEncodingDetectionAllowLossyKey  : @(allowLossy),
                                       NSStringEncodingDetectionFromWindowsKey : @(includeWindows)
                                   }
                                   convertedString:&string
                               usedLossyConversion:&usedLossy] ;
        if (!string) encoding = 0 ; // it probably will be anyways, but lets be specific
    }

    HSTextObject *object = [[HSTextObject alloc] init:rawData withEncoding:encoding] ;
    [skin pushNSObject:object] ;

    return 1 ;
}

static int text_localizedEncodingName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    NSStringEncoding encoding = (NSStringEncoding)lua_tointeger(L, 1) ;
    // internally 0 is treated as if it were 1, but we're using it as a placeholder for unspecified
    if (encoding == 0) {
        lua_pushstring(L, "raw data") ;
    } else {
        [skin pushNSObject:[NSString localizedNameOfStringEncoding:encoding]] ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int text_guessEncoding(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextObject *object        = [skin toNSObjectAtIndex:1] ;
    BOOL         allowLossy     = (lua_gettop(L) > 1 && lua_type(L, 2) == LUA_TBOOLEAN) ? (BOOL)lua_toboolean(L, 2) : NO ;
    BOOL         includeWindows = (lua_gettop(L) > 2 && lua_type(L, 3) == LUA_TBOOLEAN) ? (BOOL)lua_toboolean(L, 3) : NO ;
    NSString     *string        = nil ;
    BOOL         usedLossy      = NO ;

    NSStringEncoding guess = [NSString stringEncodingForData:object.contents
                                             encodingOptions:@{
                                                 NSStringEncodingDetectionAllowLossyKey  : @(allowLossy),
                                                 NSStringEncodingDetectionFromWindowsKey : @(includeWindows)
                                             }
                                             convertedString:&string
                                         usedLossyConversion:&usedLossy] ;
    lua_pushinteger(L, (lua_Integer)guess) ;
    lua_pushboolean(L, usedLossy) ;
    return 2 ;
}

static int text_fastestEncoding(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSTextObject *object = [skin toNSObjectAtIndex:1] ;

// do we need special check for when encoding = 0?
    NSString *string = [[NSString alloc] initWithData:object.contents encoding:object.encoding] ;
    lua_pushinteger(L, (lua_Integer)string.fastestEncoding) ;
    return 1 ;
}

static int text_smallestEncoding(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSTextObject *object = [skin toNSObjectAtIndex:1] ;

// do we need special check for when encoding = 0?
    NSString *string = [[NSString alloc] initWithData:object.contents encoding:object.encoding] ;
    lua_pushinteger(L, (lua_Integer)string.smallestEncoding) ;
    return 1 ;
}

static int text_encoding(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSTextObject *object = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, (lua_Integer)object.encoding) ;
    return 1 ;
}

static int text_raw(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSTextObject *object = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:object.contents] ;
    return 1 ;
}

static int text_validEncodings(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextObject *object    = [skin toNSObjectAtIndex:1] ;
    BOOL         allowLossy = (lua_gettop(L) > 1) ? (BOOL)lua_toboolean(L, 2) : NO ;

    lua_newtable(L) ;

    const NSStringEncoding *encoding = [NSString availableStringEncodings] ;
    while (*encoding != 0) {
        NSString *string = [[NSString alloc] initWithData:object.contents encoding:*encoding] ;
        if (string) { // NSString initWithData: allows for lossy encodings, so lets check closer...
            NSData *asData = [string dataUsingEncoding:*encoding allowLossyConversion:NO] ;
            if (allowLossy || (asData && [asData isEqualTo:object.contents])) {
                lua_pushinteger(L, (lua_Integer)*encoding) ;
                lua_seti(L, -2, luaL_len(L, -2) + 1) ;
            }
        }
        encoding++ ;
    }

    return 1 ;
}

static int text_asEncoding(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextObject     *object  = [skin toNSObjectAtIndex:1] ;
    NSStringEncoding encoding = (NSStringEncoding)lua_tointeger(L, 2) ;
    BOOL             lossy    = (lua_gettop(L) == 3) ? (BOOL)lua_toboolean(L, 3) : NO ;

    HSTextObject     *newObject      = nil ;
    NSStringEncoding initialEncoding = (object.encoding != 0) ? object.encoding : encoding ;

    if (encoding != 0) {
        NSString *string = [[NSString alloc] initWithData:object.contents encoding:initialEncoding] ;
        // it's possible to specify an invalid encoding type to the constructor that would cause this to
        // be nil, so let's try as if it's raw data since they're trying to change it anyways...
        if (!string) string = [[NSString alloc] initWithData:object.contents encoding:encoding] ;

        if (string) {
            NSData   *asData = [string dataUsingEncoding:encoding allowLossyConversion:lossy] ;
            if (asData) {
                newObject = [[HSTextObject alloc] init:asData withEncoding:encoding] ;
            }
        }
    } else {
        newObject = [[HSTextObject alloc] init:[object.contents copy] withEncoding:0] ;
    }

    [skin pushNSObject:newObject] ;
    return 1 ;
}

static int text_encodingValid(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSTextObject *object  = [skin toNSObjectAtIndex:1] ;

    BOOL isValid = (object.encoding != 0) ;
    if (isValid) {
        NSString *string = [[NSString alloc] initWithData:object.contents encoding:object.encoding] ;
        if (!string) isValid = NO ;
    }

    lua_pushboolean(L, isValid) ;
    return 1 ;
}

static int text_encodingLossless(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSTextObject *object  = [skin toNSObjectAtIndex:1] ;

    BOOL isLossless = (object.encoding == 0) ;

    if (!isLossless) {
        NSString *string = [[NSString alloc] initWithData:object.contents encoding:object.encoding] ;
        if (string) {
            NSData *asData = [string dataUsingEncoding:object.encoding allowLossyConversion:NO] ;
            if (asData) {
                isLossless = YES ;
            }
        }
    }

    lua_pushboolean(L, isLossless) ;
    return 1 ;
}

static int text_length(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSTextObject *object    = [skin toNSObjectAtIndex:1] ;

    if (object.encoding == 0) {
        lua_pushinteger(L, (lua_Integer)object.contents.length) ;
    } else {
        NSString *objString = [[NSString alloc] initWithData:object.contents encoding:object.encoding] ;
        lua_pushinteger(L, (lua_Integer)objString.length) ;
    }
    return 1 ;
}

#pragma mark - Module Constants

static int text_encodingTypes(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;

    // first add internal encodings with common shorthand names
    lua_pushinteger(L, NSASCIIStringEncoding) ;             lua_setfield(L, -2, "ASCII") ;
    lua_pushinteger(L, NSNEXTSTEPStringEncoding) ;          lua_setfield(L, -2, "NEXTSTEP") ;
    lua_pushinteger(L, NSJapaneseEUCStringEncoding) ;       lua_setfield(L, -2, "JapaneseEUC") ;
    lua_pushinteger(L, NSUTF8StringEncoding) ;              lua_setfield(L, -2, "UTF8") ;
    lua_pushinteger(L, NSISOLatin1StringEncoding) ;         lua_setfield(L, -2, "ISOLatin1") ;
    lua_pushinteger(L, NSSymbolStringEncoding) ;            lua_setfield(L, -2, "Symbol") ;
    lua_pushinteger(L, NSNonLossyASCIIStringEncoding) ;     lua_setfield(L, -2, "NonLossyASCII") ;
    lua_pushinteger(L, NSShiftJISStringEncoding) ;          lua_setfield(L, -2, "ShiftJIS") ;
    lua_pushinteger(L, NSISOLatin2StringEncoding) ;         lua_setfield(L, -2, "ISOLatin2") ;
    lua_pushinteger(L, NSUnicodeStringEncoding) ;           lua_setfield(L, -2, "Unicode") ;
    lua_pushinteger(L, NSWindowsCP1251StringEncoding) ;     lua_setfield(L, -2, "WindowsCP1251") ;
    lua_pushinteger(L, NSWindowsCP1252StringEncoding) ;     lua_setfield(L, -2, "WindowsCP1252") ;
    lua_pushinteger(L, NSWindowsCP1253StringEncoding) ;     lua_setfield(L, -2, "WindowsCP1253") ;
    lua_pushinteger(L, NSWindowsCP1254StringEncoding) ;     lua_setfield(L, -2, "WindowsCP1254") ;
    lua_pushinteger(L, NSWindowsCP1250StringEncoding) ;     lua_setfield(L, -2, "WindowsCP1250") ;
    lua_pushinteger(L, NSISO2022JPStringEncoding) ;         lua_setfield(L, -2, "ISO2022JP") ;
    lua_pushinteger(L, NSMacOSRomanStringEncoding) ;        lua_setfield(L, -2, "MacOSRoman") ;
    lua_pushinteger(L, NSUTF16StringEncoding) ;             lua_setfield(L, -2, "UTF16") ;
    lua_pushinteger(L, NSUTF16BigEndianStringEncoding) ;    lua_setfield(L, -2, "UTF16BigEndian") ;
    lua_pushinteger(L, NSUTF16LittleEndianStringEncoding) ; lua_setfield(L, -2, "UTF16LittleEndian") ;
    lua_pushinteger(L, NSUTF32StringEncoding) ;             lua_setfield(L, -2, "UTF32") ;
    lua_pushinteger(L, NSUTF32BigEndianStringEncoding) ;    lua_setfield(L, -2, "UTF32BigEndian") ;
    lua_pushinteger(L, NSUTF32LittleEndianStringEncoding) ; lua_setfield(L, -2, "UTF32LittleEndian") ;

    // now add all known encodings with fully localized names; will duplicate above but with locallized name
    const NSStringEncoding *encoding = [NSString availableStringEncodings] ;
    while (*encoding != 0) {
        [skin pushNSObject:[NSString localizedNameOfStringEncoding:*encoding]] ;
        lua_pushinteger(L, (lua_Integer)*encoding) ;
        lua_settable(L, -3) ;
        encoding++ ;
    }
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSTextObject(lua_State *L, id obj) {
    LuaSkin *skin  = [LuaSkin shared] ;
    HSTextObject *value = obj;
    if (value.selfRefCount == 0) {
        void** valuePtr = lua_newuserdata(L, sizeof(HSTextObject *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
        value.selfRef = [skin luaRef:refTable] ;
    }
    value.selfRefCount++ ;
    [skin pushLuaRef:refTable ref:value.selfRef] ;
    return 1;
}

id toHSTextObjectFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSTextObject *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSTextObject, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
//     HSTextObject *obj = [skin luaObjectAtIndex:1 toClass:"HSTextObject"] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSTextObject *obj1 = [skin luaObjectAtIndex:1 toClass:"HSTextObject"] ;
        HSTextObject *obj2 = [skin luaObjectAtIndex:2 toClass:"HSTextObject"] ;
        lua_pushboolean(L, [obj1.contents isEqualTo:obj2.contents]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSTextObject *obj = get_objectFromUserdata(__bridge_transfer HSTextObject, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin shared] ;
            obj.selfRef = [skin luaUnref:refTable ref:obj.selfRef] ;
            obj.contents = nil ;
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
    {"rawData",              text_raw},
    {"asEncoding",           text_asEncoding},
    {"validEncodings",       text_validEncodings},
    {"encoding",             text_encoding},
    {"guessEncoding",        text_guessEncoding},
    {"encodingValid",        text_encodingValid},
    {"encodingLossless",     text_encodingLossless},
    {"smallestEncoding",     text_smallestEncoding},
    {"fastestEncoding",      text_fastestEncoding},
    {"len",                  text_length},

    {"__tostring",           userdata_tostring},
    {"__len",                text_length},
    {"__eq",                 userdata_eq},
    {"__gc",                 userdata_gc},
    {NULL,                   NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",          text_new},
    {"encodingName", text_localizedEncodingName},
    {NULL,           NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_text_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    text_encodingTypes(L) ; lua_setfield(L, -2, "encodingTypes") ;

    [skin registerPushNSHelper:pushHSTextObject         forClass:"HSTextObject"];
    [skin registerLuaObjectHelper:toHSTextObjectFromLua forClass:"HSTextObject"
                                             withUserdataMapping:USERDATA_TAG];

    return 1;
}
