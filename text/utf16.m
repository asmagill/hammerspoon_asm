@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs.text.utf16" ;
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSTextUTF16Object : NSObject
@property NSString *utf16string ;
@property int      selfRef ;
@property int      selfRefCount ;
@end

@implementation HSTextUTF16Object

- (instancetype)initWithString:(NSString *)string {
    self = [super init] ;
    if (self) {
        _utf16string  = string ;
        _selfRef      = LUA_NOREF ;
        _selfRefCount = 0 ;
    }
    return self ;
}

@end

BOOL isNotStartOfSingle(NSString *string, NSUInteger idx, BOOL charactersComposed) {
    if (idx == string.length) {
        return NO ;
    } else {
        BOOL answer = (BOOL)CFStringIsSurrogateLowCharacter([string characterAtIndex:idx]) ;
        if (!answer && charactersComposed) {
            NSRange range = [string rangeOfComposedCharacterSequenceAtIndex:idx] ;
            answer = (idx != range.location) ;
        }
        return answer ;
    }
}

#pragma mark - Module Functions

static int utf16_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSData           *input   = [NSData data] ;
    BOOL             lossy    = (lua_gettop(L) > 1) ? (BOOL)lua_toboolean(L, 2) : NO ;
    NSStringEncoding encoding = NSUTF8StringEncoding ;

    if (lua_type(L, 1) == LUA_TUSERDATA) {
        [skin checkArgs:LS_TUSERDATA, "hs.text", LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

        // treat userdata as NSObject so we don't have to link files together to get definition of HSTextObject class
        NSObject *object = [skin toNSObjectAtIndex:1] ;
        input    = [object valueForKey:@"contents"] ;
        // encoding = [object valueForKey:@"encoding"] ; // won't work, return type not (id)

        // NSNumber's `unsignedIntegerValue` has the same objc signature as the implicit getter for the
        // `encoding` property of HSTextObject, so use it when building the invocation:
        NSMethodSignature *signature  = [[NSNumber class] instanceMethodSignatureForSelector:NSSelectorFromString(@"unsignedIntegerValue")] ;
        NSInvocation *encodingGetter = [NSInvocation invocationWithMethodSignature:signature] ;
        // Now set the actual selector we want to invoke -- properties have implicit getters (and setters unless readonly)
        encodingGetter.selector = NSSelectorFromString(@"encoding") ;
        [encodingGetter invokeWithTarget:object] ;
        [encodingGetter getReturnValue:&encoding] ;

        // this submodule doesn't do raw data, so default to UTF8 if they didn't set/convert this with
        // hs.text methods -- UTF8 is what Lua would give us if they used a string instead of hs.text
        // as argument 1 anyways
        if (encoding == 0) encoding = NSUTF8StringEncoding ;
    } else {
        [skin checkArgs:LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
        input = [skin toNSObjectAtIndex:1 withOptions:LS_NSLuaStringAsDataOnly] ;
    }

    NSString *actualString = [[NSString alloc] initWithData:input encoding:encoding] ;

    // if we don't allow lossy, verify string->data->string results in the same string
    // should be more accurate than comparing data directly since we don't care about BOMs
    // or byte-to-byte equivalence, we care about textual equivalence.
    //
    // TODO: Check to see if we need to worry about unicode normilization here... I don't
    //  *think* we do because we're comparing from a single source, so surrogates and order
    // shouldn't change, but I don't know that for a fact...
    if (!lossy) {
        if (actualString) {
            NSData *asData = [actualString dataUsingEncoding:encoding allowLossyConversion:NO] ;
            if (asData) {
                //
                NSString *stringFromAsData = [[NSString alloc] initWithData:asData encoding:encoding] ;
                if (![actualString isEqualToString:stringFromAsData]) actualString = nil ;
            } else {
                actualString = nil ;
            }
        }
    }

    HSTextUTF16Object *object = nil ;
    if (actualString) object = [[HSTextUTF16Object alloc] initWithString:actualString] ;

    [skin pushNSObject:object] ;
    return 1 ;
}

// utf8.char (···)
//
// Receives zero or more integers, converts each one to its corresponding UTF-8 byte sequence and returns a string with the concatenation of all these sequences.
static int utf16_utf8_char(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSMutableString *newString = [NSMutableString stringWithCapacity:(NSUInteger)lua_gettop(L)] ;
    for (int i = 1 ; i <= lua_gettop(L) ; i++) {
        if (lua_type(L, i) != LUA_TNUMBER) return luaL_argerror(L, i, [[NSString stringWithFormat:@"number expected, got %s", luaL_typename(L, i)] UTF8String]) ;
        if (!lua_isinteger(L, i)) return luaL_argerror(L, i, "number has no integer representation") ;
        uint32_t codepoint = (uint32_t)lua_tointeger(L, i) ;
        unichar surrogates[2] ;
        if (CFStringGetSurrogatePairForLongCharacter(codepoint, surrogates)) {
            [newString appendString:[NSString stringWithCharacters:surrogates length:2]] ;
        } else {
            unichar ch1 = (unichar)codepoint ;
            [newString appendString:[NSString stringWithCharacters:&ch1 length:1]] ;
        }
    }

    HSTextUTF16Object *object = [[HSTextUTF16Object alloc] initWithString:newString] ;

    [skin pushNSObject:object] ;
    return 1 ;
}

static int utf16_isHighSurrogate(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    unichar ch = (unichar)lua_tointeger(L, 1) ;
    lua_pushboolean(L, CFStringIsSurrogateHighCharacter(ch)) ;
    return 1 ;
}

static int utf16_isLowSurrogate(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    unichar ch = (unichar)lua_tointeger(L, 1) ;
    lua_pushboolean(L, CFStringIsSurrogateLowCharacter(ch)) ;
    return 1 ;
}

static int utf16_surrogatePairForCodepoint(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    uint32_t codepoint = (uint32_t)lua_tointeger(L, 1) ;
    unichar surrogates[2] ;
    if (CFStringGetSurrogatePairForLongCharacter(codepoint, surrogates)) {
        lua_pushinteger(L, (lua_Integer)surrogates[0]) ;
        lua_pushinteger(L, (lua_Integer)surrogates[1]) ;
        return 2 ;
    } else {
        lua_pushnil(L) ;
        return 1 ;
    }
}

static int utf16_codepointForSurrogatePair(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    unichar ch1 = (unichar)lua_tointeger(L, 1) ;
    unichar ch2 = (unichar)lua_tointeger(L, 2) ;
    if (CFStringIsSurrogateHighCharacter(ch1) && CFStringIsSurrogateLowCharacter(ch2)) {
        uint32_t codepoint = CFStringGetLongCharacterForSurrogatePair(ch1, ch2) ;
        lua_pushinteger(L, (lua_Integer)codepoint) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

// need to understand http://userguide.icu-project.org/transforms/general to see about adding new transforms
// or helpers to make them
static int utf16_transform(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;
    NSString          *transform   = [skin toNSObjectAtIndex:2] ;
    BOOL              reverse      = (lua_gettop(L) == 3) ? (BOOL)lua_toboolean(L, 3) : NO ;

    NSMutableString *resultString  = [objString mutableCopy] ;
    NSRange         range          = NSMakeRange(0, resultString.length) ;
    NSRange         resultingRange ;

    BOOL success = [resultString applyTransform:transform
                                        reverse:reverse
                                          range:range
                                   updatedRange:&resultingRange] ;
    if (success) {
        HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:resultString] ;
        [skin pushNSObject:newObject] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

// Normalizing Strings (see http://www.unicode.org/reports/tr15/)
static int utf16_unicodeDecomposition(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object  = [skin toNSObjectAtIndex:1] ;
    NSString          *objString    = utf16Object.utf16string ;
    BOOL              compatibility = (lua_gettop(L) > 1) ? (BOOL)lua_toboolean(L, 2) : NO ;

    NSString *newString = compatibility ? objString.decomposedStringWithCompatibilityMapping
                                        : objString.decomposedStringWithCanonicalMapping ;

    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:newString] ;
    [skin pushNSObject:newObject] ;
    return 1 ;
}

static int utf16_unicodeComposition(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object  = [skin toNSObjectAtIndex:1] ;
    NSString          *objString    = utf16Object.utf16string ;
    BOOL              compatibility = (lua_gettop(L) > 1) ? (BOOL)lua_toboolean(L, 2) : NO ;

    NSString *newString = compatibility ? objString.precomposedStringWithCompatibilityMapping
                                        : objString.precomposedStringWithCanonicalMapping ;

    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:newString] ;
    [skin pushNSObject:newObject] ;
    return 1 ;
}

static int utf16_unitCharacter(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;
    lua_Integer       i            = (lua_gettop(L) > 1) ? lua_tointeger(L, 2) : 1 ;
    lua_Integer       j            = (lua_gettop(L) > 2) ? lua_tointeger(L, 3) : i ;
    lua_Integer       length       = (lua_Integer)objString.length ;

    // adjust indicies per lua standards
    if (i < 0) i = length + 1 + i ; // negative indicies are from string end
    if (j < 0) j = length + 1 + j ; // negative indicies are from string end

    // match behavior of utf8.codepoint -- it's a little more anal then string.sub about subscripts...
    if ((i < 1) || (i > length)) return luaL_argerror(L, 2, "out of range") ;
    if ((j < 1) || (j > length)) return luaL_argerror(L, 3, "out of range") ;

    int count = 0 ;

    while(i <= j) {
        unichar codeUnit = [objString characterAtIndex:(NSUInteger)(i - 1)] ;
        lua_pushinteger(L, (lua_Integer)codeUnit) ;
        count++ ;
        i++ ;
    }
    return count ;
}

static int utf16_composedCharacterRange(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;
    lua_Integer       i            = (lua_gettop(L) > 1) ? lua_tointeger(L, 2) : 1 ;
    lua_Integer       j            = (lua_gettop(L) > 2) ? lua_tointeger(L, 3) : i ;
    lua_Integer       length       = (lua_Integer)objString.length ;

    // adjust indicies per lua standards
    if (i < 0) i = length + 1 + i ; // negative indicies are from string end
    if (j < 0) j = length + 1 + j ; // negative indicies are from string end

    // match behavior of utf8.codepoint -- it's a little more anal then string.sub about subscripts...
    if ((i < 1) || (i > length)) return luaL_argerror(L, 2, "out of range") ;
    if ((j < 1) || (j > length)) return luaL_argerror(L, 3, "out of range") ;

    NSRange targetRange ;

    if (i == j) {
        targetRange = [objString rangeOfComposedCharacterSequenceAtIndex:(NSUInteger)(i - 1)] ;
    } else {
        NSUInteger loc   = (NSUInteger)i - 1 ;
        NSUInteger len   = (NSUInteger)j - loc ;
        NSRange    range = NSMakeRange(loc, len) ;

        targetRange = [objString rangeOfComposedCharacterSequencesForRange:range] ;
    }
    lua_pushinteger(L, (lua_Integer)(targetRange.location + 1)) ;
    lua_pushinteger(L, (lua_Integer)(targetRange.location + targetRange.length)) ;
    return 2 ;
}

static int utf16_capitalize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;
    BOOL              useLocale    = (lua_gettop(L) == 2) && lua_toboolean(L, 2) ; // string will == true
    NSString          *locale      = (lua_type(L, 2) == LUA_TSTRING) ? [skin toNSObjectAtIndex:2] : nil ;

    NSString          *newString   = nil ;

    if (useLocale) {
        if (locale) {
            NSLocale *specifiedLocale = [NSLocale localeWithLocaleIdentifier:locale] ;
            if (specifiedLocale) {
                newString = [objString capitalizedStringWithLocale:specifiedLocale] ;
            } else {
                return luaL_argerror(L, 2, "unrecognized locale specified") ;
            }
        } else {
            newString = objString.localizedCapitalizedString ;
        }
    } else {
        newString = objString.capitalizedString ;
    }

    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:newString] ;
    [skin pushNSObject:newObject] ;
    return 1 ;
}

#pragma mark * From lua string library *

// string.upper (s)
//
// Receives a string and returns a copy of this string with all lowercase letters changed to uppercase. All other characters are left unchanged. The definition of what a lowercase letter is depends on the current locale.
static int utf16_string_upper(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;
    BOOL              useLocale    = (lua_gettop(L) == 2) && lua_toboolean(L, 2) ; // string will == true
    NSString          *locale      = (lua_type(L, 2) == LUA_TSTRING) ? [skin toNSObjectAtIndex:2] : nil ;

    NSString          *newString   = nil ;

    if (useLocale) {
        if (locale) {
            NSLocale *specifiedLocale = [NSLocale localeWithLocaleIdentifier:locale] ;
            if (specifiedLocale) {
                newString = [objString uppercaseStringWithLocale:specifiedLocale] ;
            } else {
                return luaL_argerror(L, 2, "unrecognized locale specified") ;
            }
        } else {
            newString = objString.localizedUppercaseString ;
        }
    } else {
        newString = objString.uppercaseString ;
    }

    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:newString] ;
    [skin pushNSObject:newObject] ;
    return 1 ;
}

// string.lower (s)
//
// Receives a string and returns a copy of this string with all uppercase letters changed to lowercase. All other characters are left unchanged. The definition of what an uppercase letter is depends on the current locale.
static int utf16_string_lower(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;
    BOOL              useLocale    = (lua_gettop(L) == 2) && lua_toboolean(L, 2) ; // string will == true
    NSString          *locale      = (lua_type(L, 2) == LUA_TSTRING) ? [skin toNSObjectAtIndex:2] : nil ;

    NSString          *newString   = nil ;

    if (useLocale) {
        if (locale) {
            NSLocale *specifiedLocale = [NSLocale localeWithLocaleIdentifier:locale] ;
            if (specifiedLocale) {
                newString = [objString lowercaseStringWithLocale:specifiedLocale] ;
            } else {
                return luaL_argerror(L, 2, "unrecognized locale specified") ;
            }
        } else {
            newString = objString.localizedLowercaseString ;
        }
    } else {
        newString = objString.lowercaseString ;
    }

    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:newString] ;
    [skin pushNSObject:newObject] ;
    return 1 ;
}

// string.len (s)
//
// Receives a string and returns its length. The empty string "" has length 0. Embedded zeros are counted, so "a\000bc\000" has length 5.
static int utf16_string_length(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    // when used as the metmethod __len, we may get "self" provided twice, so let's just check the first arg
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;

    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;

    lua_pushinteger(L, (lua_Integer)objString.length) ;
    return 1 ;
}

// string.sub (s, i [, j])
//
// Returns the substring of s that starts at i and continues until j; i and j can be negative. If j is absent, then it is assumed to be equal to -1 (which is the same as the string length). In particular, the call string.sub(s,1,j) returns a prefix of s with length j, and string.sub(s, -i) (for a positive i) returns a suffix of s with length i.
// If, after the translation of negative indices, i is less than 1, it is corrected to 1. If j is greater than the string length, it is corrected to that length. If, after these corrections, i is greater than j, the function returns the empty string.
static int utf16_string_sub(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;
    lua_Integer       i            = lua_tointeger(L, 2) ;
    lua_Integer       j            = (lua_gettop(L) > 2) ? lua_tointeger(L, 3) : -1 ;
    lua_Integer       length       = (lua_Integer)objString.length ;

    // adjust indicies per lua standards
    if (i < 0) i = length + 1 + i ; // negative indicies are from string end
    if (j < 0) j = length + 1 + j ; // negative indicies are from string end
    if (i < 1) i = 1 ;              // if i still less than 1, force to 1
    if (j > length) j = length ;    // if j greater than length, force to length

    NSString *subString = @"" ;

    if (!((i > length) || (j < i))) { // i.e. indices are within range
        // now find Objective-C index and length
        NSUInteger loc   = (NSUInteger)i - 1 ;
        NSUInteger len   = (NSUInteger)j - loc ;
        NSRange    range = NSMakeRange(loc, len) ;

        subString = [objString substringWithRange:range] ;
    }

    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:subString] ;
    [skin pushNSObject:newObject] ;
    return 1 ;
}

// string.reverse (s)
//
// Returns a string that is the string s reversed.
static int utf16_string_reverse(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;

    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;

    NSMutableString *reversedString = [NSMutableString stringWithCapacity:objString.length] ;
    [objString enumerateSubstringsInRange:NSMakeRange(0, objString.length)
                                  options:(NSStringEnumerationReverse | NSStringEnumerationByComposedCharacterSequences)
                               usingBlock:^(NSString *substring, __unused NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL *stop) {
                                             [reversedString appendString:substring] ;
                                          }
    ] ;


    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:reversedString] ;
    [skin pushNSObject:newObject] ;
    return 1 ;
}

#pragma mark * From lua utf8 library *

// utf8.codepoint (s [, i [, j]])
//
// Returns the codepoints (as integers) from all characters in s that start between byte position i and j (both included). The default for i is 1 and for j is i. It raises an error if it meets any invalid byte sequence.
static int utf16_utf8_codepoint(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;
    lua_Integer       i            = (lua_gettop(L) > 1) ? lua_tointeger(L, 2) : 1 ;
    lua_Integer       j            = (lua_gettop(L) > 2) ? lua_tointeger(L, 3) : i ;
    lua_Integer       length       = (lua_Integer)objString.length ;

    // adjust indicies per lua standards
    if (i < 0) i = length + 1 + i ; // negative indicies are from string end
    if (j < 0) j = length + 1 + j ; // negative indicies are from string end

    // match behavior of utf8.codepoint -- it's a little more anal then string.sub about subscripts...
    if ((i < 1) || (i > length)) return luaL_argerror(L, 2, "out of range") ;
    if ((j < 1) || (j > length)) return luaL_argerror(L, 3, "out of range") ;

    int count = 0 ;

    if (CFStringIsSurrogateLowCharacter([objString characterAtIndex:(NSUInteger)(i - 1)])) {
        // initial index is in the middle of a surrogate pair
        return luaL_error(L, "invalid UTF-16 code") ;
    }

    while(i <= j) {
        unichar  ch1       = [objString characterAtIndex:(NSUInteger)(i - 1)] ;
        uint32_t codepoint = ch1 ;
        if (CFStringIsSurrogateHighCharacter(ch1)) {
            i++ ; // surrogate pair, so get second half
            if (i > length) {
                // if we've exceded the string length, then string ends with a broken surrogate pair
                return luaL_error(L, "invalid UTF-16 code") ;
            }
            unichar ch2 = [objString characterAtIndex:(NSUInteger)(i - 1)] ;
            codepoint = CFStringGetLongCharacterForSurrogatePair(ch1, ch2) ;
        }
        lua_pushinteger(L, (lua_Integer)codepoint) ;
        i++ ;
        count++ ;
    }

    return count ;
}

// utf8.len (s [, i [, j]])
//
// Returns the number of UTF-8 characters in string s that start between positions i and j (both inclusive). The default for i is 1 and for j is -1. If it finds any invalid byte sequence, returns a false value plus the position of the first invalid byte.

// utf8.offset (s, n [, i])
//
// Returns the position (in bytes) where the encoding of the n-th character of s (counting from position i) starts. A negative n gets characters before position i. The default for i is 1 when n is non-negative and #s + 1 otherwise, so that utf8.offset(s, -n) gets the offset of the n-th character from the end of the string. If the specified character is neither in the subject nor right after its end, the function returns nil.
// As a special case, when n is 0 the function returns the start of the encoding of the character that contains the i-th byte of s.
//
// This function assumes that s is a valid UTF-8 string.
static int utf16_utf8_offset(lua_State *L) {
    LuaSkin *skin              = [LuaSkin shared] ;
    int     nIdx               = 2 ;
    BOOL    charactersComposed = NO ;
    if (lua_type(L, 2) == LUA_TBOOLEAN) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN, LS_TNUMBER | LS_TINTEGER,  LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
        nIdx++ ;
        charactersComposed = (BOOL)lua_toboolean(L, 2) ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER,  LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    }
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;
    lua_Integer       n            = lua_tointeger(L, nIdx) ;
    lua_Integer       length       = (lua_Integer)objString.length ;
    lua_Integer       i            = (lua_gettop(L) > nIdx) ? lua_tointeger(L, nIdx + 1) : ((n > -1) ? 1 : (length + 1)) ;
    if (i < 0) i = (length + i < 0) ? 0 : (length + i + 1) ;
    luaL_argcheck(L, 1 <= i && --i <= length, nIdx + 1, "position out of range") ;

    // horked from lutf8lib... I *think* I understand it...
    if (n == 0) {
        while (i > 0 && isNotStartOfSingle(objString, (NSUInteger)i, charactersComposed)) i-- ;
    } else {
        if (isNotStartOfSingle(objString, (NSUInteger)i, charactersComposed)) return luaL_error(L, "initial position is a continuation byte") ;
        if (n < 0) {
            while (n < 0 && i > 0) {  // move back
                do {  // find beginning of previous character
                    i-- ;
                } while (i > 0 && isNotStartOfSingle(objString, (NSUInteger)i, charactersComposed)) ;
                n++ ;
            }
        } else {
            n-- ;  // do not move for 1st character
            while (n > 0 && i < length) {
                do {  // find beginning of next character
                    i++ ;
                } while (isNotStartOfSingle(objString, (NSUInteger)i, charactersComposed)) ;  // (cannot pass final '\0')
                n-- ;
            }
        }
    }
    if (n == 0) { // did it find given character?
        lua_pushinteger(L, i + 1) ;
    } else  { // no such character
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Constants

// need to understand http://userguide.icu-project.org/transforms/general to see about adding new transforms
// or helpers to make them
static int utf16_builtinTransforms(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
    [skin pushNSObject:NSStringTransformLatinToKatakana] ;      lua_setfield(L, -2, "latinToKatakana") ;
    [skin pushNSObject:NSStringTransformLatinToHiragana] ;      lua_setfield(L, -2, "latinToHiragana") ;
    [skin pushNSObject:NSStringTransformLatinToHangul] ;        lua_setfield(L, -2, "latinToHangul") ;
    [skin pushNSObject:NSStringTransformLatinToArabic] ;        lua_setfield(L, -2, "latinToArabic") ;
    [skin pushNSObject:NSStringTransformLatinToHebrew] ;        lua_setfield(L, -2, "latinToHebrew") ;
    [skin pushNSObject:NSStringTransformLatinToThai] ;          lua_setfield(L, -2, "latinToThai") ;
    [skin pushNSObject:NSStringTransformLatinToCyrillic] ;      lua_setfield(L, -2, "latinToCyrillic") ;
    [skin pushNSObject:NSStringTransformLatinToGreek] ;         lua_setfield(L, -2, "latinToGreek") ;
    [skin pushNSObject:NSStringTransformToLatin] ;              lua_setfield(L, -2, "toLatin") ;
    [skin pushNSObject:NSStringTransformMandarinToLatin] ;      lua_setfield(L, -2, "mandarinToLatin") ;
    [skin pushNSObject:NSStringTransformHiraganaToKatakana] ;   lua_setfield(L, -2, "hiraganaToKatakana") ;
    [skin pushNSObject:NSStringTransformFullwidthToHalfwidth] ; lua_setfield(L, -2, "fullwidthToHalfwidth") ;
    [skin pushNSObject:NSStringTransformToXMLHex] ;             lua_setfield(L, -2, "toXMLHex") ;
    [skin pushNSObject:NSStringTransformToUnicodeName] ;        lua_setfield(L, -2, "toUnicodeName") ;
    [skin pushNSObject:NSStringTransformStripCombiningMarks] ;  lua_setfield(L, -2, "stripCombiningMarks") ;
    [skin pushNSObject:NSStringTransformStripDiacritics] ;      lua_setfield(L, -2, "stripDiacritics") ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSTextUTF16Object(lua_State *L, id obj) {
    LuaSkin *skin  = [LuaSkin shared] ;
    HSTextUTF16Object *value = obj;
    if (value.selfRefCount == 0) {
        void** valuePtr = lua_newuserdata(L, sizeof(HSTextUTF16Object *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
        value.selfRef = [skin luaRef:refTable] ;
    }
    value.selfRefCount++ ;
    [skin pushLuaRef:refTable ref:value.selfRef] ;
    return 1;
}

id toHSTextUTF16ObjectFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSTextUTF16Object *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSTextUTF16Object, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_concat(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
// can't get here if at least one of us isn't our userdata type
    HSTextUTF16Object *obj1 = luaL_testudata(L, 1, USERDATA_TAG) ? [skin luaObjectAtIndex:1 toClass:"HSTextUTF16Object"] : nil ;
    if (!obj1) {
        if (lua_type(L, 1) == LUA_TSTRING || lua_type(L, 1) == LUA_TNUMBER) {
            const char *input = lua_tostring(L, 1) ;
            obj1 = [[HSTextUTF16Object alloc] initWithString:[NSString stringWithCString:input encoding:NSUTF8StringEncoding]] ;
        } else {
            return luaL_error(L, "attempt to concatenate a %s value", lua_typename(L, 1)) ;
        }
    }
    HSTextUTF16Object *obj2 = luaL_testudata(L, 2, USERDATA_TAG) ? [skin luaObjectAtIndex:2 toClass:"HSTextUTF16Object"] : nil ;
    if (!obj2) {
        if (lua_type(L, 2) == LUA_TSTRING || lua_type(L, 2) == LUA_TNUMBER) {
            const char *input = lua_tostring(L, 2) ;
            obj2 = [[HSTextUTF16Object alloc] initWithString:[NSString stringWithCString:input encoding:NSUTF8StringEncoding]] ;
        } else {
            return luaL_error(L, "attempt to concatenate a %s value", lua_typename(L, 2)) ;
        }
    }

    NSString *newString = [obj1.utf16string stringByAppendingString:obj2.utf16string] ;
    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:newString] ;
    [skin pushNSObject:newObject] ;
    return 1 ;
}

static int userdata_tostring(__unused lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSTextUTF16Object *obj  = [skin luaObjectAtIndex:1 toClass:"HSTextUTF16Object"] ;
    NSString          *text = obj.utf16string ;
    [skin pushNSObject:text] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error.
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSTextUTF16Object *obj1 = [skin luaObjectAtIndex:1 toClass:"HSTextUTF16Object"] ;
        HSTextUTF16Object *obj2 = [skin luaObjectAtIndex:2 toClass:"HSTextUTF16Object"] ;
        lua_pushboolean(L, [obj1.utf16string isEqualToString:obj2.utf16string]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSTextUTF16Object *obj = get_objectFromUserdata(__bridge_transfer HSTextUTF16Object, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin shared] ;
            obj.selfRef = [skin luaUnref:refTable ref:obj.selfRef] ;
            obj.utf16string = nil ;
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
    {"unicodeDecomposition",   utf16_unicodeDecomposition},
    {"unicodeComposition",     utf16_unicodeComposition},
    {"transform",              utf16_transform},
    {"unitCharacter",          utf16_unitCharacter},
    {"composedCharacterRange", utf16_composedCharacterRange},
    {"capitalize",             utf16_capitalize},

    {"upper",                  utf16_string_upper},
    {"lower",                  utf16_string_lower},
    {"len",                    utf16_string_length},
    {"sub",                    utf16_string_sub},
    {"reverse",                utf16_string_reverse},

    {"codepoint",              utf16_utf8_codepoint},
    {"offset",                 utf16_utf8_offset},

    {"__concat",               userdata_concat},
    {"__tostring",             userdata_tostring},
    {"__len",                  utf16_string_length},
    {"__eq",                   userdata_eq},
    {"__gc",                   userdata_gc},
    {NULL,                     NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",                       utf16_new},
    {"char",                      utf16_utf8_char},
    {"isHighSurrogate",           utf16_isHighSurrogate},
    {"isLowSurrogate",            utf16_isLowSurrogate},
    {"surrogatePairForCodepoint", utf16_surrogatePairForCodepoint},
    {"codepointForSurrogatePair", utf16_codepointForSurrogatePair},
    {NULL,                        NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_text_utf16(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    utf16_builtinTransforms(L) ; lua_setfield(L, -2, "builtinTransforms") ;

    [skin registerPushNSHelper:pushHSTextUTF16Object         forClass:"HSTextUTF16Object"];
    [skin registerLuaObjectHelper:toHSTextUTF16ObjectFromLua forClass:"HSTextUTF16Object"
                                                  withUserdataMapping:USERDATA_TAG];

    return 1;
}
