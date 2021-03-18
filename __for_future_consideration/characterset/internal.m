#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG "hs._asm.characterset"
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

static int characterSetFromName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    lua_getglobal(L, "hs") ; lua_getfield(L, -1, "cleanUTF8forConsole") ; lua_remove(L, -2) ;
    lua_pushvalue(L, 1) ;
    lua_pcall(L, 1, 1, 0) ;
    NSString *theString = [skin toNSObjectAtIndex:-1] ;
    lua_pop(L, 1) ;

    NSCharacterSet *charSet ;
    if ([theString isEqualToString:@"alphanumeric"])         charSet = [NSCharacterSet alphanumericCharacterSet] ;
    if ([theString isEqualToString:@"capitalizedLetter"])    charSet = [NSCharacterSet capitalizedLetterCharacterSet] ;
    if ([theString isEqualToString:@"control"])              charSet = [NSCharacterSet controlCharacterSet] ;
    if ([theString isEqualToString:@"decimalDigit"])         charSet = [NSCharacterSet decimalDigitCharacterSet] ;
    if ([theString isEqualToString:@"decomposable"])         charSet = [NSCharacterSet decomposableCharacterSet] ;
    if ([theString isEqualToString:@"illegal"])              charSet = [NSCharacterSet illegalCharacterSet] ;
    if ([theString isEqualToString:@"letter"])               charSet = [NSCharacterSet letterCharacterSet] ;
    if ([theString isEqualToString:@"lowercaseLetter"])      charSet = [NSCharacterSet lowercaseLetterCharacterSet] ;
    if ([theString isEqualToString:@"newline"])              charSet = [NSCharacterSet newlineCharacterSet] ;
    if ([theString isEqualToString:@"nonBase"])              charSet = [NSCharacterSet nonBaseCharacterSet] ;
    if ([theString isEqualToString:@"punctuation"])          charSet = [NSCharacterSet punctuationCharacterSet] ;
    if ([theString isEqualToString:@"symbol"])               charSet = [NSCharacterSet symbolCharacterSet] ;
    if ([theString isEqualToString:@"uppercaseLetter"])      charSet = [NSCharacterSet uppercaseLetterCharacterSet] ;
    if ([theString isEqualToString:@"whitespaceAndNewline"]) charSet = [NSCharacterSet whitespaceAndNewlineCharacterSet] ;
    if ([theString isEqualToString:@"whitespace"])           charSet = [NSCharacterSet whitespaceCharacterSet] ;
    if ([theString isEqualToString:@"URLFragmentAllowed"])   charSet = [NSCharacterSet URLFragmentAllowedCharacterSet] ;
    if ([theString isEqualToString:@"URLHostAllowed"])       charSet = [NSCharacterSet URLHostAllowedCharacterSet] ;
    if ([theString isEqualToString:@"URLPasswordAllowed"])   charSet = [NSCharacterSet URLPasswordAllowedCharacterSet] ;
    if ([theString isEqualToString:@"URLPathAllowed"])       charSet = [NSCharacterSet URLPathAllowedCharacterSet] ;
    if ([theString isEqualToString:@"URLQueryAllowed"])      charSet = [NSCharacterSet URLQueryAllowedCharacterSet] ;
    if ([theString isEqualToString:@"URLUserAllowed"])       charSet = [NSCharacterSet URLUserAllowedCharacterSet] ;

    if (charSet)
        [skin pushNSObject:charSet] ;
    else
        return luaL_error(L, "invalid character set specified: %s, see %s.names", [theString UTF8String], USERDATA_TAG) ;

    return 1 ;
}

static int characterSetWithCharactersInString(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    lua_tostring(L, 1) ; // force number into string
    NSString *setChars = [skin toNSObjectAtIndex:1] ;
    if ([setChars isKindOfClass:[NSString class]]) {
        [skin pushNSObject:[NSCharacterSet characterSetWithCharactersInString:setChars]] ;
    } else {
        return luaL_error(L, "string of characters must contain valid Unicode characters") ;
    }
    return 1 ;
}

static int characterSetWithRange(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
    lua_Integer from = luaL_checkinteger(L, 1) ;
    lua_Integer to   = luaL_checkinteger(L, 2) ;

    if (!(from < 0 || to < 0 || to < from)) {
        NSRange unicodeRange = NSMakeRange((NSUInteger)from, (NSUInteger)(to - from + 1)) ;
        [skin pushNSObject:[NSCharacterSet characterSetWithRange:unicodeRange]] ;
    } else {
        if (from < 0) return luaL_argerror(L, 1, "must be non-negative") ;
        if (to < 0)   return luaL_argerror(L, 2, "must be non-negative") ;
        return luaL_error(L, "starting index must be less than the ending index") ;
    }
    return 1 ;
}

// TODO: Constructors
// + (NSCharacterSet *)characterSetWithBitmapRepresentation:(NSData *)data
// + (NSCharacterSet *)characterSetWithContentsOfFile:(NSString *)path

#pragma mark - Module Methods

static int bitmapRepresentation(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSCharacterSet *charSet = [skin luaObjectAtIndex:1 toClass:"NSCharacterSet"] ;
    [skin pushNSObject:[charSet bitmapRepresentation]] ;
    return 1 ;
}

static int invertedSet(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSCharacterSet *charSet = [skin luaObjectAtIndex:1 toClass:"NSCharacterSet"] ;
    [skin pushNSObject:[charSet invertedSet]] ;
    return 1 ;
}

static int setCharacters(lua_State *L) {
// tweaked from http://stackoverflow.com/questions/26610931/list-of-characters-in-an-nscharacterset
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSCharacterSet *charSet = [skin luaObjectAtIndex:1 toClass:"NSCharacterSet"] ;

    NSMutableArray *array = [NSMutableArray array];
    for (unsigned int plane = 0; plane <= 16; plane++) {
        if ([charSet hasMemberInPlane:(uint8_t)plane]) {
            UTF32Char c;
            for (c = plane << 16; c < (plane+1) << 16; c++) {
                if ([charSet longCharacterIsMember:c]) {
                    UTF32Char c1 = OSSwapHostToLittleInt32(c); // To make it byte-order safe
                    NSString *s = [[NSString alloc] initWithBytes:&c1 length:4 encoding:NSUTF32LittleEndianStringEncoding];
                    if (s) {
                        [array addObject:s];
                    } else {
                        [skin logDebug:[NSString stringWithFormat:@"%s:setCharacters skipping 0x%08x : nil string representation",
                                                                   USERDATA_TAG, c1]] ;
                    }
                }
            }
        }
    }
    [skin pushNSObject:array] ;
    return 1 ;
}

static int isSupersetOfSet(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSCharacterSet *superSet = [skin luaObjectAtIndex:1 toClass:"NSCharacterSet"] ;
    NSCharacterSet *subSet   = [skin luaObjectAtIndex:2 toClass:"NSCharacterSet"] ;
    lua_pushboolean(L, [superSet isSupersetOfSet:subSet]) ;
    return 1 ;
}

static int intersectionWithSet(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSMutableCharacterSet *charSet1 = [[skin luaObjectAtIndex:1 toClass:"NSCharacterSet"] mutableCopy];
    NSCharacterSet        *charSet2 = [skin luaObjectAtIndex:2 toClass:"NSCharacterSet"] ;
    [charSet1 formIntersectionWithCharacterSet:charSet2] ;
    [skin pushNSObject:charSet1] ;
    return 1 ;
}

static int unionWithSet(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSMutableCharacterSet *charSet1 = [[skin luaObjectAtIndex:1 toClass:"NSCharacterSet"] mutableCopy];
    NSCharacterSet        *charSet2 = [skin luaObjectAtIndex:2 toClass:"NSCharacterSet"] ;
    [charSet1 formUnionWithCharacterSet:charSet2] ;
    [skin pushNSObject:charSet1] ;
    return 1 ;
}

static int removeCharactersFromSet(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSMutableCharacterSet *charSet = [[skin luaObjectAtIndex:1 toClass:"NSCharacterSet"] mutableCopy];
    if (lua_gettop(L) == 2) {
        luaL_checkstring(L, 2) ;
        [charSet removeCharactersInString:[skin toNSObjectAtIndex:2]] ;
    } else {
        lua_Integer starts = luaL_checkinteger(L, 2) ;
        lua_Integer ends   = luaL_checkinteger(L, 3) ;
        if (starts < 0 || ends < 0) {
            return luaL_error(L, "starting and ending codepoints must be positive") ;
        } else if (ends < starts) {
            return luaL_error(L, "ending codepoint must be greater than starting codepoint") ;
        }
        NSUInteger location = (NSUInteger)starts ;
        NSUInteger length   = (NSUInteger)ends + 1 - location ;
        [charSet removeCharactersInRange:NSMakeRange(location, length)] ;
    }
    [skin pushNSObject:charSet] ;
    return 1 ;
}

static int addCharactersToSet(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSMutableCharacterSet *charSet = [[skin luaObjectAtIndex:1 toClass:"NSCharacterSet"] mutableCopy];
    if (lua_gettop(L) == 2) {
        luaL_checkstring(L, 2) ;
        [charSet addCharactersInString:[skin toNSObjectAtIndex:2]] ;
    } else {
        lua_Integer starts = luaL_checkinteger(L, 2) ;
        lua_Integer ends   = luaL_checkinteger(L, 3) ;
        if (starts < 0 || ends < 0) {
            return luaL_error(L, "starting and ending codepoints must be positive") ;
        } else if (ends < starts) {
            return luaL_error(L, "ending codepoint must be greater than starting codepoint") ;
        }
        NSUInteger location = (NSUInteger)starts ;
        NSUInteger length   = (NSUInteger)ends + 1 - location ;
        [charSet addCharactersInRange:NSMakeRange(location, length)] ;
    }
    [skin pushNSObject:charSet] ;
    return 1 ;
}

static int stringIsMemberOfSet(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    luaL_checkstring(L, 2) ;

    NSCharacterSet *charSet   = [skin luaObjectAtIndex:1 toClass:"NSCharacterSet"] ;
    NSString       *theString = [skin toNSObjectAtIndex:2] ;
    BOOL           isGood     = YES ;
    NSUInteger     len        = [theString length];
    unichar        buffer[len+1];
    NSUInteger     idx        = 0 ;

    // NOTE: won't work with decomposed characters, but then I don't think Hammerspoon's console or much else
    // in Hammerspoon will either, so... cowardly ignore until it matters
    // See http://stackoverflow.com/questions/4158646/most-efficient-way-to-iterate-over-all-the-chars-in-an-nsstring/25938062#25938062
    // if it ever does matter.

    [theString getCharacters:buffer range:NSMakeRange(0, len)];
    while(isGood && idx < len) {
        isGood = [charSet characterIsMember:buffer[idx]] ;
        idx++ ;
    }
    lua_pushboolean(L, isGood) ;
    return 1 ;
}

// TODO: Methods
// Need to think about UTF32 and how it compares/converts to UTF8, which is what almost everything
// else in Hammerspoon is based upon.
// - (BOOL)hasMemberInPlane:(uint8_t)thePlane
// - (BOOL)longCharacterIsMember:(UTF32Char)theLongChar

#pragma mark - Module Constants

static int pushCharacterSetNames(lua_State *L) {
    lua_newtable(L) ;
    lua_pushstring(L, "alphanumeric") ;         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "capitalizedLetter") ;    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "control") ;              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "decimalDigit") ;         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "decomposable") ;         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "illegal") ;              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "letter") ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "lowercaseLetter") ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "newline") ;              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "nonBase") ;              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "punctuation") ;          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "symbol") ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "uppercaseLetter") ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "whitespaceAndNewline") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "whitespace") ;           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "URLFragmentAllowed") ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "URLHostAllowed") ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "URLPasswordAllowed") ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "URLPathAllowed") ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "URLQueryAllowed") ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "URLUserAllowed") ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushNSCharacterSet(lua_State *L, id obj) {
    NSCharacterSet *charSet = obj;
    void** charSetPtr = lua_newuserdata(L, sizeof(NSCharacterSet *));
    *charSetPtr = (__bridge_retained void *)charSet;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toNSCharacterSetFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSCharacterSet *charSet ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        charSet = get_objectFromUserdata(__bridge NSCharacterSet, L, idx) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return charSet ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     NSCharacterSet *obj = [skin luaObjectAtIndex:1 toClass:"NSCharacterSet"] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        NSCharacterSet *obj1 = [skin luaObjectAtIndex:1 toClass:"NSCharacterSet"] ;
        NSCharacterSet *obj2 = [skin luaObjectAtIndex:2 toClass:"NSCharacterSet"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    NSCharacterSet *obj = get_objectFromUserdata(__bridge_transfer NSCharacterSet, L, 1) ;
    if (obj) obj = nil ;
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// // Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"bitmapRepresentation", bitmapRepresentation},
    {"inverted",             invertedSet},
    {"characters",           setCharacters},
    {"isSupersetOf",         isSupersetOfSet},
    {"intersectionWith",     intersectionWithSet},
    {"unionWith",            unionWithSet},
    {"addToSet",             addCharactersToSet},
    {"removeFromSet",        removeCharactersFromSet},
    {"containsString",       stringIsMemberOfSet},

    {"__tostring",           userdata_tostring},
    {"__eq",                 userdata_eq},
    {"__gc",                 userdata_gc},
    {NULL,                   NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"fromName",   characterSetFromName},
    {"fromString", characterSetWithCharactersInString},
    {"fromRange",  characterSetWithRange},
    {NULL,         NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_characterset_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    pushCharacterSetNames(L) ; lua_setfield(L, -2, "names") ;

    [skin registerPushNSHelper:pushNSCharacterSet         forClass:"NSCharacterSet"];
    [skin registerLuaObjectHelper:toNSCharacterSetFromLua forClass:"NSCharacterSet"];

    return 1;
}
