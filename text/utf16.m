@import Cocoa ;
@import LuaSkin ;

#import "text.h"

/// === hs.text.utf16 ===
///
/// Perform text manipulation on UTF16 objects created by the `hs.text` module.
///
/// This sumodule replicates many of the functions found in the lua `string` and `utf8` libraries but modified for use with UTF16 text objects.
///
/// Metamethods to make the objects work more like Lua strings:
///
///  * unlike most userdata objects used by Hammerspoon modules, `hs.text.utf16` objects have their `__tostring` metamethod defined to return the UTF8 equivalent of the object. This allows the object to be printed to the Hammerspoon console directly with the lua `print` command (e.g. `print(object)`). You can also save the object as a lua string with `tostring(object)`.
///  * (in)equality -- the metamethods for equality and inequality use [hs.text.utf16:compare({"literal"})](#compate) when you use `==`, `~=`, `<`, `<=`, `>`, or `>=` to compare a `hs.text.utf16` to another or to a lua string.
///  * concatenation -- you can create a new `hs.utf16.text` objext by combining two objects (or one and a lua string) with `..`
///
/// Additional Notes
///
/// Internally, the macOS provides a wide range of functions for manipulating and managing UTF16 strings in the Objective-C runtime. While a wide variety of encodings can be used for importing and exporting data (see the main body of the `hs.text` module), string manipulation is provided by macOS only for the UTf16 representation of the encoded data. When working with data encoded in other formats, use the `hs.text:toUTF16()` method which will create an object his submodule can manipulate. When finished, you can convert the data back to the necessary encoding with the `hs.text.new()` function and then export the data back (e.g. writing to a file or posting to a URL).
///
/// In addition to the lua `string` and `utf8` functions, additional functions provided by the macOS are included. This includes, but is not limited to, Unicode normalization and ICU transforms.

static int refTable = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

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

BOOL inMiddleOfChar(NSString *string, NSUInteger idx, BOOL charactersComposed) {
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

static int combinedFindAndMatch(lua_State *L, NSString *objString, NSString *pattern, lua_Integer idx, BOOL isFind) {
    LuaSkin *skin = [LuaSkin shared] ;

    NSRegularExpressionOptions options = 0 ;
    if (isFind && (lua_gettop(L) == 4) && lua_toboolean(L, 4)) options = NSRegularExpressionIgnoreMetacharacters ;

// NOTE: Do we want/need to convert lua style regular expression codes (e.g. %d instead of \d)? If so, do it here...

    NSError             *error     = nil ;
    NSRegularExpression *patternRE = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                               options:options
                                                                                 error:&error] ;
    if (error)  return luaL_argerror(L, 2, error.localizedDescription.UTF8String) ;

    idx-- ;
    NSRange searchRange = NSMakeRange((NSUInteger)idx, objString.length - (NSUInteger)idx) ;
    NSTextCheckingResult *searchResults = [patternRE firstMatchInString:objString
                                                                options:0
                                                                  range:searchRange] ;
    int returning = 0 ;
    if (searchResults) {
        if (isFind) {
            lua_pushinteger(L, (lua_Integer)(searchResults.range.location + 1)) ;
            lua_pushinteger(L, (lua_Integer)(searchResults.range.location + searchResults.range.length)) ;
            returning = 2 ;
        }
        if (searchResults.numberOfRanges > 1) {
            for (NSUInteger a = 1 ; a < searchResults.numberOfRanges ; a++) {
                NSRange componentRange = [searchResults rangeAtIndex:a] ;
                if (componentRange.location == NSNotFound) {
                    lua_pushnil(L) ;
                } else {
                    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:[objString substringWithRange:componentRange]] ;
                    [skin pushNSObject:newObject] ;
                }
            }
            returning = returning + (int)(searchResults.numberOfRanges - 1) ;
        } else if (!isFind) {
            HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:[objString substringWithRange:searchResults.range]] ;
            [skin pushNSObject:newObject] ;
            returning = 1 ;
        }
    } else {
        lua_pushnil(L) ;
        returning = 1 ;
    }
    return returning ;
}

#pragma mark - Module Functions
/// hs.text.utf16.new(text, [lossy]) -> utf16TextObject
/// Constructor
/// Create a new utf16TextObject from a lua string or `hs.text` object
///
/// Parameters:
///  * `text`  - a lua string or `hs.text` object specifying the text for the new utf16TextObject
///  * `lossy` - an optional boolean, default false, specifying whether or not characters can be removed or altered when converting the data to the UTF16 encoding.
///
/// Returns:
///  * a new utf16TextObject, or nil if the data could not be encoded as a utf16TextObject
static int utf16_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSData           *input   = [NSData data] ;
    BOOL             lossy    = (lua_gettop(L) > 1) ? (BOOL)lua_toboolean(L, 2) : NO ;
    NSStringEncoding encoding = NSUTF8StringEncoding ;

    if (lua_type(L, 1) == LUA_TUSERDATA) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

        HSTextObject *object = [skin toNSObjectAtIndex:1] ;
        input                = object.contents ;
        encoding             = object.encoding ;

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

/// hs.text.utf16.char(...) -> utf16TextObject
/// Constructor
/// Create a new utf16TextObject from the Unicode Codepoints specified.
///
/// Paramters:
///  * zero or more Unicode Codepoints specified as integers
///
/// Returns:
///  * a new utf16TextObject
///
/// Notes:
///  * Unicode Codepoints are often written as `U+xxxx` where `xxxx` is between 4 and 6 hexadecimal digits. Lua can automatically convert hexadecimal numbers to integers, so replace the `U+` with `0x` when specifying codepoints in this format.
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

/// hs.text.utf16.isHighSurrogate(unitchar) -> boolean
/// Function
/// Returns whether or not the specified 16-bit UTF16 unit character is a High Surrogate
///
/// Parameters:
///  * `unitchar` - an integer specifying a single UTF16 character
///
/// Returns:
///  * a boolean specifying whether or not the single UTF16 character specified is a High Surrogate (true) or not (false).
///
/// Notes:
///  * UTF16 represents Unicode characters in the range of U+010000 to U+10FFFF as a pair of UTF16 characters known as a surrogate pair. A surrogate pair is made up of a High Surrogate and a Low Surrogate.
///    * A high surrogate is a single UTF16 "character" with an integer representation between 0xD800 and 0xDBFF inclusive
///    * A low surrogate is a single UTF16 "character" with an integer representation between 0xDC00 and 0xDFFF inclusive.
///    * It is an encoding error if a high surrogate is not immediately followed by a low surrogate or for either surrogate type to be found by itself or surrounded by UTF16 characters outside of the surrogate pair ranges. However, most implementations silently ignore this and simply treat unpaired surrogates as unprintable (control characters) or equivalent to the Unicode Replacement character (U+FFFD).
///
/// * See also [hs.text.utf16.isLowSurrogate](#isLowSurrogate)
static int utf16_isHighSurrogate(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    unichar ch = (unichar)lua_tointeger(L, 1) ;
    lua_pushboolean(L, CFStringIsSurrogateHighCharacter(ch)) ;
    return 1 ;
}

/// hs.text.utf16.isLowSurrogate(unitchar) -> boolean
/// Function
/// Returns whether or not the specified 16-bit UTF16 unit character is a Low Surrogate
///
/// Parameters:
///  * `unitchar` - an integer specifying a single UTF16 character
///
/// Returns:
///  * a boolean specifying whether or not the single UTF16 character specified is a Low Surrogate (true) or not (false).
///
/// Notes:
///  * UTF16 represents Unicode characters in the range of U+010000 to U+10FFFF as a pair of UTF16 characters known as a surrogate pair. A surrogate pair is made up of a High Surrogate and a Low Surrogate.
///    * A high surrogate is a single UTF16 "character" with an integer representation between 0xD800 and 0xDBFF inclusive
///    * A low surrogate is a single UTF16 "character" with an integer representation between 0xDC00 and 0xDFFF inclusive.
///    * It is an encoding error if a high surrogate is not immediately followed by a low surrogate or for either surrogate type to be found by itself or surrounded by UTF16 characters outside of the surrogate pair ranges. However, most implementations silently ignore this and simply treat unpaired surrogates as unprintable (control characters) or equivalent to the Unicode Replacement character (U+FFFD).
///
/// * See also [hs.text.utf16.isHighSurrogate](#isHighSurrogate)
static int utf16_isLowSurrogate(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    unichar ch = (unichar)lua_tointeger(L, 1) ;
    lua_pushboolean(L, CFStringIsSurrogateLowCharacter(ch)) ;
    return 1 ;
}

/// hs.text.utf16.surrogatePairForCodepoint(codepoint) -> integer, integer | nil
/// Function
/// Returns the surrogate pair for the specified Unicode Codepoint
///
/// Parameters:
///  * `codepoint` - an integer specifying the Unicode codepoint
///
/// Returns:
///  * if the codepoint is between U+010000 to U+10FFFF, returns the UTF16 surrogate pair for the character as 2 integers; otherwise returns nil
///
/// Notes:
///  * UTF16 represents Unicode characters in the range of U+010000 to U+10FFFF as a pair of UTF16 characters known as a surrogate pair. A surrogate pair is made up of a High Surrogate and a Low Surrogate.
///
/// * See also [hs.text.utf16.isHighSurrogate](#isHighSurrogate) and [hs.text.utf16.isLowSurrogate](#isLowSurrogate)
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

/// hs.text.utf16.codepointForSurrogatePair(high, low) -> integer | nil
/// Function
/// Returns the Unicode Codepoint number for the specified high and low surrogate pair
///
/// Parameters:
///  * `high` - an integer specifying the UTF16 "character" specifying the High Surrogate
///  * `low` - an integer specifying the UTF16 "character" specifying the Low Surrogate
///
/// Returns:
///  * if the `high` and `low` values specify a valid UTF16 surrogate pair, returns an integer specifying the codepoint for the pair; otherwise returns nil
///
/// Notes:
///  * UTF16 represents Unicode characters in the range of U+010000 to U+10FFFF as a pair of UTF16 characters known as a surrogate pair. A surrogate pair is made up of a High Surrogate and a Low Surrogate.
///
/// * See also [hs.text.utf16.isHighSurrogate](#isHighSurrogate) and [hs.text.utf16.isLowSurrogate](#isLowSurrogate)
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

/// hs.text.utf16:copy() -> utf16TextObject
/// Method
/// Create a copy of the utf16TextObject
///
/// Paramters:
///  * None
///
/// Returns:
///  * a copy of the utf16TextObject as a new object
static int utf16_copy(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;

    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:[objString copy]] ;
    [skin pushNSObject:newObject] ;
    return 1 ;
}

/// hs.text.utf16:transform(transform, [inverse]) -> utf16TextObject | nil
/// Method
/// Create a new utf16TextObject by applying the specified ICU transform
///
/// Paramters:
///  * `transform` - a string specifying the ICU transform(s) to apply
///  * `inverse`   - an optional boolean, default false, specifying whether or not to apply the inverse (or reverse) of the specified transformation
///
/// Returns:
///  * a new utf16TextObject containing the transformed data, or nil if the transform (or its inverse) could not be applied or was invalid
///
/// Notes:
///  * some built in transforms are identified in the constant table [hs.text.utf16.builtinTransforms](#builtInTransforms).
///  * transform syntax is beyond the scope of this document; see http://userguide.icu-project.org/transforms/general for more information on creating your own transforms
///
///  * Note that not all transforms have an inverse or are reversible.
static int utf16_transform(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
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

/// hs.text.utf16:unicodeDecomposition([compatibilityMapping]) -> utf16TextObject
/// Method
/// Create a new utf16TextObject with the contents of the parent normalized using Unicode Normalization Form (K)D.
///
/// Paramters:
///  * `compatibilityMapping` - an optionabl boolean, default false, specifying whether compatibility mapping (true) should be used (Normalization Form KD) or canonical mapping (false) should be used (Normalization Form D) when normalizing the text.
///
/// Returns:
///  * a new utf16TextObject with the contents of the parent normalized using Unicode NormalizationForm (K)D.
///
/// Notes:
///  * At its most basic, normalization is useful when comparing strings which may have been composed differently (e.g. a single UTF16 character representing an accented `á` vs the visually equivalent composed character sequence of an `a` followed by U+0301) or use stylized versions of characters or numbers (e.g. `1` vs `①`), but need to be compared for their "visual" or "intended" equivalance.
///
///  * see http://www.unicode.org/reports/tr15/ for a more complete discussion of the various types of Unicode Normalization and the differences/strengths/weaknesses of each.
///
///  * See also [hs.text.utf16:unicodeComposition](#unicodeComposition)
static int utf16_unicodeDecomposition(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object  = [skin toNSObjectAtIndex:1] ;
    NSString          *objString    = utf16Object.utf16string ;
    BOOL              compatibility = (lua_gettop(L) > 1) ? (BOOL)lua_toboolean(L, 2) : NO ;

    NSString *newString = compatibility ? objString.decomposedStringWithCompatibilityMapping
                                        : objString.decomposedStringWithCanonicalMapping ;

    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:newString] ;
    [skin pushNSObject:newObject] ;
    return 1 ;
}

/// hs.text.utf16:unicodeComposition([compatibilityMapping]) -> utf16TextObject
/// Method
/// Create a new utf16TextObject with the contents of the parent normalized using Unicode Normalization Form (K)C.
///
/// Paramters:
///  * `compatibilityMapping` - an optionabl boolean, default false, specifying whether compatibility mapping (true) should be used (Normalization Form KC) or canonical mapping (false) should be used (Normalization Form C) when normalizing the text.
///
/// Returns:
///  * a new utf16TextObject with the contents of the parent normalized using Unicode NormalizationForm (K)C.
///
/// Notes:
///  * At its most basic, normalization is useful when comparing strings which may have been composed differently (e.g. a single UTF16 character representing an accented `á` vs the visually equivalent composed character sequence of an `a` followed by U+0301) or use stylized versions of characters or numbers (e.g. `1` vs `①`), but need to be compared for their "visual" or "intended" equivalance.
///
///  * see http://www.unicode.org/reports/tr15/ for a more complete discussion of the various types of Unicode Normalization and the differences/strengths/weaknesses of each.
///
///  * See also [hs.text.utf16:unicodeDecomposition](#unicodeDecomposition)
static int utf16_unicodeComposition(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object  = [skin toNSObjectAtIndex:1] ;
    NSString          *objString    = utf16Object.utf16string ;
    BOOL              compatibility = (lua_gettop(L) > 1) ? (BOOL)lua_toboolean(L, 2) : NO ;

    NSString *newString = compatibility ? objString.precomposedStringWithCompatibilityMapping
                                        : objString.precomposedStringWithCanonicalMapping ;

    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:newString] ;
    [skin pushNSObject:newObject] ;
    return 1 ;
}

/// hs.text.utf16:unitCharacter([i], [j]) -> integer, ...
/// Method
/// Returns the UTF16 unit character codes for the range specified
///
/// Paramters:
///  * `i` - the starting index, default 1, specifying which UTF16 character to begin at; negative indicies are counted from the end of the string.
///  * `j` - the ending index, default the valur of `i`, specifying the end of the range; negative indicies are counted from the end of the string.
///
/// Returns:
///  * zero or more integers representing the individual utf16 "characters" of the object within the range specified
///
/// Notes:
///  * this method returns the 16bit integer corresponding to the UTF16 "character" at the indicies specified. Surrogate pairs *are* treated as two separate "characters" by this method, so the initial or final character may be a broken surrogate -- see [hs.text.utf16.isHighSurrogate](#isHighSurrogate) and [hs.text.utf16.isLowSurrogate](#isLowSurrogate).
///
///  * this method follows the semantics of `utf8.codepoint` -- if a specified index is out of range, an error is generated.
static int utf16_unitCharacter(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
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

/// hs.text.utf16:composedCharacterRange([i], [j]) -> start, end
/// Method
/// Returns the starting and ending index of the specified range, adjusting for composed characters or surrogate pairs at the beginning and end of the range.
///
/// Paramters:
///  * `i` - the starting index, default 1, specifying which UTF16 character to begin at; negative indicies are counted from the end of the string.
///  * `j` - the ending index, default the valur of `i`, specifying the end of the range; negative indicies are counted from the end of the string.
///
/// Returns:
///  * the `start` and `end` indicies for the range of characters specified by the initial range
///
/// Notes:
///  * if the unit character at index `i` specifies a low surrogate or is in the middle of a mulit-"character" composed character, `start` will be < `i`
///  * likewise if `j` is in the middle of a multi-"character" composition or surrogate, `end` will be > `j`.
///
///  * this method follows the semantics of `utf8.codepoint` -- if a specified index is out of range, an error is generated.
static int utf16_composedCharacterRange(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
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

/// hs.text.utf16:capitalize([locale]) -> utf16TextObject
/// Method
/// Returns a copy of the utf16TextObject with all words capitalized.
///
/// Paramters:
///  * `locale` - an optional string or boolean (default ommitted) specifying whether to consider localization when determining how to capitalize words.
///    * if this parameter is ommitted, uses canonical (non-localized) mapping suitable for programming operations that require stable results not depending on the current locale.
///    * if this parameter is the boolean `false` or `nil`, uses the system locale
///    * if this parameter is the boolean `true`, uses the users current locale
///    * if this parameter is a string, the locale specified by the string is used. (See `hs.host.locale.availableLocales()` for valid locale identifiers)
///
/// Returns:
///  * a new utf16TextObject containing the capitalized version of the source
///
/// Notes:
///  * For the purposes of this methif, a capitalized string is a string with the first character in each word changed to its corresponding uppercase value, and all remaining characters set to their corresponding lowercase values. A word is any sequence of characters delimited by spaces, tabs, or line terminators. Some common word delimiting punctuation isn’t considered, so this property may not generally produce the desired results for multiword strings.
static int utf16_capitalize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TSTRING | LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;
    BOOL              useLocale    = (lua_gettop(L) == 2) ;
    NSString          *locale      = (lua_type(L, 2) == LUA_TSTRING) ? [skin toNSObjectAtIndex:2] : nil ;

    NSString          *newString   = nil ;

    if (useLocale) {
        NSLocale *specifiedLocale = lua_toboolean(L, 2) ? [NSLocale currentLocale] : nil ; // handles boolean/nil
        if (locale) {
            specifiedLocale = [NSLocale localeWithLocaleIdentifier:locale] ;
            if (!specifiedLocale) {
                return luaL_argerror(L, 2, "unrecognized locale specified") ;
            }
        }
        newString = [objString capitalizedStringWithLocale:specifiedLocale] ;
    } else {
        newString = objString.capitalizedString ;
    }

    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:newString] ;
    [skin pushNSObject:newObject] ;
    return 1 ;
}

// documented in `init.lua`
static int utf16_compare(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG,
                    LS_TANY,
                    LS_TNUMBER | LS_TINTEGER | LS_TSTRING | LS_TNIL | LS_TOPTIONAL,
                    LS_TSTRING | LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;

    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;

    NSString          *target      = [NSString stringWithUTF8String:luaL_tolstring(L, 2, NULL)] ;
    lua_pop(L, 1) ;
    if (lua_type(L, 2) == LUA_TUSERDATA) {
        [skin checkArgs:LS_TANY, LS_TUSERDATA, UTF16_UD_TAG, LS_TBREAK | LS_TVARARG] ;
        HSTextUTF16Object *targetObject = [skin toNSObjectAtIndex:2] ;
        target = targetObject.utf16string ;
    }

    NSStringCompareOptions options = 0 ;
    int                    localeIdx = 3 ;

    if (lua_type(L, 3) == LUA_TNUMBER) {
        localeIdx++ ;
        options = (NSStringCompareOptions)(lua_tointeger(L, 3)) ;
    }

    BOOL     useLocale = (lua_gettop(L) == localeIdx) ;
    NSString *locale   = (lua_type(L, localeIdx) == LUA_TSTRING) ? [skin toNSObjectAtIndex:localeIdx] : nil ;

    NSRange  compareRange = NSMakeRange(0, objString.length) ;

    NSComparisonResult result ;
    if (useLocale) {
        NSLocale *specifiedLocale = lua_toboolean(L, localeIdx) ? [NSLocale currentLocale] : nil ; // handles boolean/nil
        if (locale) {
            specifiedLocale = [NSLocale localeWithLocaleIdentifier:locale] ;
            if (!specifiedLocale) {
                return luaL_argerror(L, localeIdx, "unrecognized locale specified") ;
            }
        }
        result = [objString compare:target options:options range:compareRange locale:specifiedLocale] ;
    } else {
        result = [objString compare:target options:options range:compareRange] ;
    }

    switch (result) {
        case NSOrderedAscending:  lua_pushinteger(L, -1) ; break ;
        case NSOrderedSame:       lua_pushinteger(L,  0) ; break ;
        case NSOrderedDescending: lua_pushinteger(L,  1) ; break ;
        default:
            [skin logError:[NSString stringWithFormat:@"%s:compare - unexpected comparison result of %ld when comparing %@ and %@", UTF16_UD_TAG, result, objString, target]] ;
            lua_pushinteger(L, -999) ;
    }
    return 1 ;
}

#pragma mark * From lua string library *

/// hs.text.utf16:upper([locale]) -> utf16TextObject
/// Method
/// Returns a copy of the utf16TextObject with an uppercase representation of the source.
///
/// Paramters:
///  * `locale` - an optional string or boolean (default ommitted) specifying whether to consider localization when determining how change case.
///    * if this parameter is ommitted, uses canonical (non-localized) mapping suitable for programming operations that require stable results not depending on the current locale.
///    * if this parameter is the boolean `false` or `nil`, uses the system locale
///    * if this parameter is the boolean `true`, uses the users current locale
///    * if this parameter is a string, the locale specified by the string is used. (See `hs.host.locale.availableLocales()` for valid locale identifiers)
///
/// Returns:
///  * a new utf16TextObject containing an uppercase representation of the source.
///
/// Notes:
///  * This method is the utf16 equivalent of lua's `string.upper`
///  * Case transformations aren’t guaranteed to be symmetrical or to produce strings of the same lengths as the originals.
static int utf16_string_upper(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TSTRING | LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;
    BOOL              useLocale    = (lua_gettop(L) == 2) ;
    NSString          *locale      = (lua_type(L, 2) == LUA_TSTRING) ? [skin toNSObjectAtIndex:2] : nil ;

    NSString          *newString   = nil ;

    if (useLocale) {
        NSLocale *specifiedLocale = lua_toboolean(L, 2) ? [NSLocale currentLocale] : nil ; // handles boolean/nil
        if (locale) {
            specifiedLocale = [NSLocale localeWithLocaleIdentifier:locale] ;
            if (!specifiedLocale) {
                return luaL_argerror(L, 2, "unrecognized locale specified") ;
            }
        }
        newString = [objString uppercaseStringWithLocale:specifiedLocale] ;
    } else {
        newString = objString.uppercaseString ;
    }

    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:newString] ;
    [skin pushNSObject:newObject] ;
    return 1 ;
}

/// hs.text.utf16:lower([locale]) -> utf16TextObject
/// Method
/// Returns a copy of the utf16TextObject with an lowercase representation of the source.
///
/// Paramters:
///  * `locale` - an optional string or boolean (default ommitted) specifying whether to consider localization when determining how change case.
///    * if this parameter is ommitted, uses canonical (non-localized) mapping suitable for programming operations that require stable results not depending on the current locale.
///    * if this parameter is the boolean `false` or `nil`, uses the system locale
///    * if this parameter is the boolean `true`, uses the users current locale
///    * if this parameter is a string, the locale specified by the string is used. (See `hs.host.locale.availableLocales()` for valid locale identifiers)
///
/// Returns:
///  * a new utf16TextObject containing an lowercase representation of the source.
///
/// Notes:
///  * This method is the utf16 equivalent of lua's `string.lower`
///  * Case transformations aren’t guaranteed to be symmetrical or to produce strings of the same lengths as the originals.
static int utf16_string_lower(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TSTRING | LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;
    BOOL              useLocale    = (lua_gettop(L) == 2) ;
    NSString          *locale      = (lua_type(L, 2) == LUA_TSTRING) ? [skin toNSObjectAtIndex:2] : nil ;

    NSString          *newString   = nil ;

    if (useLocale) {
        NSLocale *specifiedLocale = lua_toboolean(L, 2) ? [NSLocale currentLocale] : nil ; // handles boolean/nil
        if (locale) {
            specifiedLocale = [NSLocale localeWithLocaleIdentifier:locale] ;
            if (!specifiedLocale) {
                return luaL_argerror(L, 2, "unrecognized locale specified") ;
            }
        }
        newString = [objString lowercaseStringWithLocale:specifiedLocale] ;
    } else {
        newString = objString.lowercaseString ;
    }

    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:newString] ;
    [skin pushNSObject:newObject] ;
    return 1 ;
}

/// hs.text.utf16:len() -> integer
/// Method
/// Returns the length in UTF16 characters in the object
///
/// Parameters:
///  * None
///
/// Returns:
///  * the number of UTF16 characterss in the object
///
/// Notes:
///  * This method is the utf16 equivalent of lua's `string.len`
///  * Composed character sequences and surrogate pairs are made up of multiple UTF16 "characters"; see also [hs.text.utf16:characterCount](#characterCount) wihch offers more options.
static int utf16_string_length(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    // when used as the metmethod __len, we may get "self" provided twice, so let's just check the first arg
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TBREAK | LS_TVARARG] ;

    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;

    lua_pushinteger(L, (lua_Integer)objString.length) ;
    return 1 ;
}

/// hs.text.utf16:sub([i], [j]) -> utf16TextObject
/// Method
/// Returns a new utf16TextObject containing a substring of the source object
///
/// Parameters:
///  * `i` - an integer specifying the starting index of the substring; negative indicies are counted from the end of the string.
///  * `j` - an optional integer, default -1, specifying the end of the substring; negative indicies are counted from the end of the string.
///
/// Returns:
///  * a new utf16TextObject containing a substring of the source object as delimited by the indicies `i` and `j`
///
/// Notes:
///  * This method is the utf16 equivalent of lua's `string.sub`
///    * In particular, `hs.text.utf16:sub(1, j)` will return the prefix of the source with a length of `j`, and `hs.text.utf16:sub(-i)` returns the suffix of the source with a length of `i`.
///
///  * This method uses the specific indicies provided, which could result in a broken surrogate or composed character sequence at the begining or end of the substring. If this is a concern, use [hs.text.utf16:composedCharacterRange](#composedCharacterRange) to adjust the range values before invoking this method.
static int utf16_string_sub(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
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

/// hs.text.utf16:reverse() -> utf16TextObject
/// Method
/// Returns a new utf16TextObject with the characters reveresed.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a new utf16TextObject with the characters reveresed
///
/// Notes:
///  * This method is the utf16 equivalent of lua's `string.reverse`
///  * Surrogate pairs and composed character sequences are maintained, so the reversed object will be composed of valid UTF16 sequences (assuming, of course, that the original object was composed of valid UTF16 sequences)
static int utf16_string_reverse(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TBREAK] ;

    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;

// Courtesy of https://stackoverflow.com/a/6730329
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

/// hs.text.utf16:match(pattern, [i]) -> match(es) | nil
/// Method
/// Looks for the first match of a pattern within the utf16TextObject and returns it
///
/// Paramters:
///  * `pattern` - a lua string or utf16TextObject specifying the pattern for the match. See *Notes*.
///  * `i`       - an optional integer, default 1, specifying the index of the utf16TextObject where the search for the pattern should begin; negative indicies are counted from the end of the object.
///
/// Returns:
///  * If a match is found and the pattern specifies captures, returns a new utf16TextObjects for each capture; if no captures are specified, returns the entire match as a new utf16TextObject. If no matche is found, returns nil.
///
/// Notes:
///  * This method is the utf16 equivalent of lua's `string.match` with one important caveat:
///    * This method utilizes regular expressions as described at http://userguide.icu-project.org/strings/regexp, not the Lua pattern matching syntax.
///    * Again, ***Lua pattern matching syntax will not work with this method.***
static int utf16_string_match(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TANY, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;

    NSString          *pattern     = [NSString stringWithUTF8String:luaL_tolstring(L, 2, NULL)] ;
    lua_pop(L, 1) ;
    if (lua_type(L, 2) == LUA_TUSERDATA) {
        [skin checkArgs:LS_TANY, LS_TUSERDATA, UTF16_UD_TAG, LS_TBREAK | LS_TVARARG] ;
        HSTextUTF16Object *patternObject = [skin toNSObjectAtIndex:2] ;
        pattern = patternObject.utf16string ;
    }

    lua_Integer       i            = (lua_gettop(L) > 2) ? lua_tointeger(L, 3) : 1 ;
    lua_Integer       length       = (lua_Integer)objString.length ;
    // adjust indicies per lua standards
    if (i < 0) i = length + 1 + i ; // negative indicies are from string end
    if (i < 1) i = 1 ;              // if i still less than 1, force to 1

    if (i > length) {
        lua_pushnil(L) ;
        return 1 ;
    }

    return combinedFindAndMatch(L, objString, pattern, i, NO) ;
}

/// hs.text.utf16:find(pattern, [i], [plain]) -> start, end, [captures...] | nil
/// Method
/// Looks for the first match of a pattern within the utf16TextObject and returns the indicies of the match
///
/// Paramters:
///  * `pattern` - a lua string or utf16TextObject specifying the pattern for the match. See *Notes*.
///  * `i`       - an optional integer, default 1, specifying the index of the utf16TextObject where the search for the pattern should begin; negative indicies are counted from the end of the object.
///  * `plain`   - an optional boolean, default false, specifying that the pattern should be matched *exactly* (true) instead of treated as a regular expression (false).
///
/// Returns:
///  * If a match is found, returns the starting and ending indicies of the match (as integers); if captures are specified in the pattern, also returns a new utf16TextObjects for each capture after the indicies. If no match is found, returns nil.
///
/// Notes:
///  * This method is the utf16 equivalent of lua's `string.find` with one important caveat:
///    * This method utilizes regular expressions as described at http://userguide.icu-project.org/strings/regexp, not the Lua pattern matching syntax.
///    * Again, ***Lua pattern matching syntax will not work with this method.***
static int utf16_string_find(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TANY, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;

    NSString          *pattern     = [NSString stringWithUTF8String:luaL_tolstring(L, 2, NULL)] ;
    lua_pop(L, 1) ;
    if (lua_type(L, 2) == LUA_TUSERDATA) {
        [skin checkArgs:LS_TANY, LS_TUSERDATA, UTF16_UD_TAG, LS_TBREAK | LS_TVARARG] ;
        HSTextUTF16Object *patternObject = [skin toNSObjectAtIndex:2] ;
        pattern = patternObject.utf16string ;
    }

    lua_Integer       i            = (lua_gettop(L) > 2) ? lua_tointeger(L, 3) : 1 ;
    lua_Integer       length       = (lua_Integer)objString.length ;
    // adjust indicies per lua standards
    if (i < 0) i = length + 1 + i ; // negative indicies are from string end
    if (i < 1) i = 1 ;              // if i still less than 1, force to 1

    if (i > length) {
        lua_pushnil(L) ;
        return 1 ;
    }

    return combinedFindAndMatch(L, objString, pattern, i, YES) ;
}

/// hs.text.urf16:gsub(pattern, replacement, [n]) -> utf16TextObject, count
/// Method
/// Return a gopy of the object with occurances of the pattern replaced; global substitution.
///
/// Paramters:
///  * `pattern`     - a lua string or utf16TextObject specifying the pattern for the match. See *Notes*.
///  * `replacement` - a lua string, utf16TextObject, table, or function which specifies replacement(s) for pattern matches.
///    * if `replacement` is a string or utf16TextObject, then its value is used for replacement. Any sequence in the replacement of the form `$n` where `n` is an integer >= 0 will be replaced by the `n`th capture from the pattern (`$0` specifies the entire match). A `$` not followed by a number is treated as a literal `$`. To specify a literal `$` followed by a numeric digit, escape the dollar sign (e.g. `\$1`)
///    * if `replacement` is a table, the table is queried for every match using the first capture (if captures are specified) or the entire match (if no captures are specified). Keys in the table must be lua strings or utf16TextObjects, and values must be lua strings, numbers, or utf16TextObjects. If no key matches the capture, no replacement of the match occurs.
///    * if `replacement` is a function, the function will be called with all of the captured substrings passed in as utf16TextObjects in order (or the entire match, if no captures are specified). The return value is used as the repacement of the match and must be `nil`, a lua string, a number, or a utf16TextObject. If the return value is `nil`, no replacement of the match occurs.
///  * `n`           - an optional integer specifying the maximum number of replacements to perform. If this is not specified, all matches in the object will be replaced.
///
/// Returns:
///  * a new utf16TextObject with the substitutions specified, followed by an integer specifying the number of substitutions that occurred.
///
/// Notes:
///  * This method is the utf16 equivalent of lua's `string.gsub` with one important caveat:
///    * This method utilizes regular expressions as described at http://userguide.icu-project.org/strings/regexp, not the Lua pattern matching syntax.
///    * Again, ***Lua pattern matching syntax will not work with this method.***
///
///  * The following examples are from the Lua documentation for `string.gsub` modified with the proper syntax:
///
///      ~~~
///      x = hs.text.utf16.new("hello world"):gsub("(\\w+)", "$1 $1")
///      -- x will equal "hello hello world world"
///
///      -- note that if we use Lua's block quotes (e.g. `[[` and `]]`), then we don't have to escape the backslash:
///
///      x = hs.text.utf16.new("hello world"):gsub([[\w+]], "$0 $0", 1)
///      -- x will equal "hello hello world"
///
///      x = hs.text.utf16.new("hello world from Lua"):gsub([[(\w+)\s*(\w+)]], "$2 $1")
///      -- x will equal "world hello Lua from"
///
///      x = hs.text.utf16.new("home = $HOME, user = $USER"):gsub([[\$(\w+)]], function(a) return os.getenv(tostring(a)) end)
///      -- x will equal "home = /home/username, user = username"
///
///      x = hs.text.utf16.new("4+5 = $return 4+5$"):gsub([[\$(.+)\$]], function (s) return load(tostring(s))() end)
///      -- x will equal "4+5 = 9"
///
///      local t = {name="lua", version="5.3"}
///      x = hs.text.utf16.new("$name-$version.tar.gz"):gsub([[\$(\w+)]], t)
///      -- x will equal "lua-5.3.tar.gz"
///      ~~~
static int utf16_string_gsub(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TANY, LS_TANY, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;

    NSString          *pattern     = [NSString stringWithUTF8String:luaL_tolstring(L, 2, NULL)] ;
    lua_pop(L, 1) ;
    if (lua_type(L, 2) == LUA_TUSERDATA) {
        [skin checkArgs:LS_TANY, LS_TUSERDATA, UTF16_UD_TAG, LS_TBREAK | LS_TVARARG] ;
        HSTextUTF16Object *patternObject = [skin toNSObjectAtIndex:2] ;
        pattern = patternObject.utf16string ;
    } else {
        [skin checkArgs:LS_TANY, LS_TSTRING | LS_TNUMBER, LS_TBREAK | LS_TVARARG] ;
    }

    // prepare placeholders for the possible values of argument 3
    NSString *replString = (lua_type(L, 3) == LUA_TSTRING) ? [skin toNSObjectAtIndex:3] : nil ;
    if (lua_type(L, 3) == LUA_TUSERDATA) {
        [skin checkArgs:LS_TANY, LS_TANY, LS_TUSERDATA, UTF16_UD_TAG, LS_TBREAK | LS_TVARARG] ;
        HSTextUTF16Object *replObject = [skin toNSObjectAtIndex:3] ;
        replString = replObject.utf16string ;
    } else {
        [skin checkArgs:LS_TANY, LS_TANY, LS_TSTRING | LS_TTABLE | LS_TFUNCTION, LS_TBREAK | LS_TVARARG] ;
    }

    NSDictionary *replDictionary = (lua_type(L, 3) == LUA_TTABLE)  ? [skin toNSObjectAtIndex:3] : nil ;
    // if they pass in an array like table, we silently ignore it since the keys have to be strings
    if ([replDictionary isKindOfClass:[NSArray class]]) {
        replDictionary = [NSDictionary dictionary] ;
    } else {
        NSMutableDictionary *realReplDictionary = [NSMutableDictionary dictionaryWithCapacity:replDictionary.count] ;
        __block NSString *errorMessage = nil ;
        [replDictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
            NSString *newKey   = key ;
            NSString *newValue = value ;
            if ([key isKindOfClass:[HSTextUTF16Object class]]) {
                newKey = ((HSTextUTF16Object *)key).utf16string ;
            } else {
                errorMessage = @"expected string or hs.text.utf16 object for replacement key in table" ;
                *stop = true ;
                return ;
            }
            if ([value isKindOfClass:[HSTextUTF16Object class]]) {
                newValue = ((HSTextUTF16Object *)value).utf16string ;
            } else if ([value isKindOfClass:[NSNumber class]]) {
                newValue = ((NSNumber *)value).stringValue ;
            } else {
                errorMessage = @"expected string, number, or hs.text.utf16 object for replacement value in table" ;
                *stop = true ;
                return ;
            }
            realReplDictionary[newKey] = newValue ;
        }] ;
        if (errorMessage) return luaL_argerror(L, 3, errorMessage.UTF8String) ;

        replDictionary = [realReplDictionary copy] ;
    }

    int replFnRef = LUA_NOREF ;
    if (lua_type(L, 3) == LUA_TFUNCTION) {
        lua_pushvalue(L, 3) ;
        replFnRef = [skin luaRef:refTable] ;
    }

    lua_Integer maxSubstitutions = (lua_gettop(L) > 3) ? lua_tointeger(L, 4) : ((lua_Integer)objString.length + 1) ;

// NOTE: Do we want/need to convert lua style regular expression codes (e.g. %d instead of \d)? If so, do it here...

    NSError             *error     = nil ;
    NSRegularExpression *patternRE = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                               options:0
                                                                                 error:&error] ;
    if (error)  return luaL_argerror(L, 2, error.localizedDescription.UTF8String) ;

    lua_Integer changeCount = 0 ;

    // inspired by https://stackoverflow.com/a/23827451
    NSMutableString* mutableString = [objString mutableCopy] ;
    NSInteger offset = 0 ; // keeps track of range changes in the string due to replacements.
    for (NSTextCheckingResult* result in [patternRE matchesInString:objString
                                                            options:0
                                                              range:NSMakeRange(0, objString.length)]) {
        if (changeCount >= maxSubstitutions) break ;

        NSRange resultRange = [result range] ;
        resultRange.location = (NSUInteger)((NSInteger)resultRange.location + offset) ; // resultRange.location is updated based on the offset updated below

        NSMutableArray *elements = [NSMutableArray arrayWithCapacity:result.numberOfRanges] ;
        for (NSUInteger i = 0 ; i < result.numberOfRanges ; i++) {
            NSRange componentRange = [result rangeAtIndex:i] ;
            if (componentRange.location == NSNotFound) {
                [elements addObject:@""] ;
            } else {
                componentRange.location = (NSUInteger)((NSInteger)componentRange.location + offset) ;
                [elements addObject:[mutableString substringWithRange:componentRange]] ;
            }
        }

        // here's where the magic happens
        NSString *replacement = nil ;
        if (replString) {
            replacement = [patternRE replacementStringForResult:result
                                                       inString:mutableString
                                                         offset:offset
                                                       template:replString] ;
        } else if (replDictionary) {
            replacement = [replDictionary objectForKey:(elements.count > 1) ? elements[1] : elements[0]] ;
            if (!replacement) replacement = elements[0] ;
        } else if (replFnRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:replFnRef] ;
            int argCount = (int)elements.count - 1 ;
            if (argCount == 0) {
                HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:elements[0]] ;
                [skin pushNSObject:newObject] ;
                argCount = 1 ;
            } else {
                for (NSUInteger i = 1 ; i < elements.count ; i++) {
                    HSTextUTF16Object *newObject = [[HSTextUTF16Object alloc] initWithString:elements[i]] ;
                    [skin pushNSObject:newObject] ;
                }
            }
            if (![skin protectedCallAndTraceback:argCount nresults:1]) {
                return luaL_error(L, lua_tostring(L, -1)) ;
            } else {
                switch(lua_type(L, -1)) {
                    case LUA_TNIL:
                        replacement = elements[0] ;
                        break ;
                    case LUA_TSTRING:
                        {
                            NSData *input = [skin toNSObjectAtIndex:-1 withOptions:LS_NSLuaStringAsDataOnly] ;
                            replacement = [[NSString alloc] initWithData:input encoding:NSUTF8StringEncoding] ;
                        }
                        break ;
                    case LUA_TNUMBER:
                        replacement = [NSString stringWithCString:lua_tostring(L, -1) encoding:NSUTF8StringEncoding] ;
                        break ;
                    case LUA_TUSERDATA:
                        if (luaL_testudata(L, -1, UTF16_UD_TAG)) {
                            HSTextUTF16Object *newObject = [skin toNSObjectAtIndex:-1] ;
                            replacement = newObject.utf16string ;
                            break ;
                        }
                    default:
                        return luaL_error(L, "invalid replacement value (a %s)", lua_typename(L, -1)) ;
                }
            }
        }

        // make the replacement
        [mutableString replaceCharactersInRange:resultRange withString:replacement] ;

        // update the offset based on the replacement
        offset += ((NSInteger)replacement.length - (NSInteger)resultRange.length) ;

        changeCount++ ;
    }

    if (replFnRef != LUA_NOREF) {
        replFnRef = [skin luaUnref:refTable ref:replFnRef] ;
    }
    [skin pushNSObject:mutableString] ;
    lua_pushinteger(L, changeCount) ;
    return 2 ;
}

#pragma mark * From lua utf8 library *

// utf8.codepoint (s [, i [, j]])
//
// Returns the codepoints (as integers) from all characters in s that start between byte position i and j (both included). The default for i is 1 and for j is i. It raises an error if it meets any invalid byte sequence.
static int utf16_utf8_codepoint(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
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
static int utf16_utf8_len(lua_State *L) {
    LuaSkin *skin              = [LuaSkin shared] ;
    int     iIdx               = 2 ;
    BOOL    charactersComposed = NO ;
    if (lua_type(L, 2) == LUA_TBOOLEAN) {
        [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TBOOLEAN, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,  LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
        iIdx++ ;
        charactersComposed = (BOOL)lua_toboolean(L, 2) ;
    } else {
        [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,  LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    }

   // horked from lutf8lib.c... I *think* I understand it...

    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;
    lua_Integer       i            = (lua_gettop(L) >= iIdx) ? lua_tointeger(L, iIdx)     :  1 ;
    lua_Integer       j            = (lua_gettop(L) >  iIdx) ? lua_tointeger(L, iIdx + 1) : -1 ;
    lua_Integer       length       = (lua_Integer)objString.length ;

    if (i < 0) i = (length + i < 0) ? 0 : (length + i + 1) ;
    if (j < 0) j = (length + j < 0) ? 0 : (length + j + 1) ;
    luaL_argcheck(L, 1 <= i && --i <= length, iIdx, "initial position out of string") ;
    luaL_argcheck(L, --j < length, iIdx + 1, "final position out of string") ;

    lua_Integer n = 0 ;

    while (i <= j) {
        unichar ch1 = [objString characterAtIndex:(NSUInteger)i] ;
        if (CFStringIsSurrogateHighCharacter(ch1)) {
            if ((i < j) && CFStringIsSurrogateLowCharacter([objString characterAtIndex:(NSUInteger)(i + 1)])) {
                i +=2 ; // valid surrogate pair in range
            } else {
                // not followed by low surrogate or low surrogate out of range
                lua_pushnil(L) ;
                lua_pushinteger(L, i + 1) ;
                return 2 ;
            }
        } else if (!CFStringIsSurrogateLowCharacter(ch1)) {
            if (charactersComposed) {
                NSRange cc = [objString rangeOfComposedCharacterSequenceAtIndex:(NSUInteger)i] ;
// [skin logWarn:[NSString stringWithFormat:@"(i, j, cc.loc, cc.len) == (%lld, %lld, %lu, %lu)", i, j, cc.location, cc.length]] ;
                if ((cc.location == (NSUInteger)i) && ((i + (lua_Integer)cc.length - 1) <= j)) {
                    i += (lua_Integer)cc.length ; // valid composed character
                } else {
                    lua_pushnil(L) ;
                    if (cc.location == (NSUInteger)i) {
                        // composed character extends beyond range
                        lua_pushinteger(L, j + 1) ;
                    } else {
                        // not at begining of composed character
                        lua_pushinteger(L, i + 1) ;
                    }
                    return 2 ;
                }
            } else {
                i++ ; // valid single unit
            }
        } else {
            // char is lone low surrogate
            lua_pushnil(L) ;
            lua_pushinteger(L, i + 1) ;
            return 2 ;
        }
        n++ ;
    }

    lua_pushinteger(L, n) ;
    return 1 ;
}

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
        [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TBOOLEAN, LS_TNUMBER | LS_TINTEGER,  LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
        nIdx++ ;
        charactersComposed = (BOOL)lua_toboolean(L, 2) ;
    } else {
        [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TNUMBER | LS_TINTEGER,  LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    }

    // horked from lutf8lib.c... I *think* I understand it...

    HSTextUTF16Object *utf16Object = [skin toNSObjectAtIndex:1] ;
    NSString          *objString   = utf16Object.utf16string ;
    lua_Integer       n            = lua_tointeger(L, nIdx) ;
    lua_Integer       length       = (lua_Integer)objString.length ;
    lua_Integer       i            = (lua_gettop(L) > nIdx) ? lua_tointeger(L, nIdx + 1) : ((n > -1) ? 1 : (length + 1)) ;
    if (i < 0) i = (length + i < 0) ? 0 : (length + i + 1) ;
    luaL_argcheck(L, 1 <= i && --i <= length, nIdx + 1, "position out of range") ;

    if (n == 0) {
        while (i > 0 && inMiddleOfChar(objString, (NSUInteger)i, charactersComposed)) i-- ;
    } else {
        if (inMiddleOfChar(objString, (NSUInteger)i, charactersComposed)) return luaL_error(L, "initial position is a continuation byte") ;
        if (n < 0) {
            while (n < 0 && i > 0) {  // move back
                do {  // find beginning of previous character
                    i-- ;
                } while (i > 0 && inMiddleOfChar(objString, (NSUInteger)i, charactersComposed)) ;
                n++ ;
            }
        } else {
            n-- ;  // do not move for 1st character
            while (n > 0 && i < length) {
                do {  // find beginning of next character
                    i++ ;
                } while (inMiddleOfChar(objString, (NSUInteger)i, charactersComposed)) ;  // (cannot pass final '\0')
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
/// hs.text.utf16.builtInTransforms
/// Constant
/// Built in transormations which can be used with [hs.text.utf16:transform](#transform).
///
/// This table contains key-value pairs identifying built in transforms provided by the macOS Objective-C runtime environment for use with [hs.text.utf16:transform](#transform). See http://userguide.icu-project.org/transforms/general for a more complete discussion on how to specify aditional transformations.
///
/// The built in transformations are:
///  * `fullwidthToHalfwidth` - transform full-width CJK characters to their half-width forms. e.g. “マット” transforms to “ﾏｯﾄ”. This transformation is reversible.
///  * `hiraganaToKatakana`   - transliterate the text from Hiragana script to Katakana script. e.g. “ひらがな” transliterates to “カタカナ”. This transformation is reversible.
///  * `latinToArabic`        - transliterate the text from Latin script to Arabic script. e.g. “ạlʿarabīẗ‎” transliterates to “العَرَبِية”. This transformation is reversible.
///  * `latinToCyrillic`      - transliterate the text from Latin script to Cyrillic script. e.g. “kirillica” transliterates to “кириллица”. This transformation is reversible.
///  * `latinToGreek`         - transliterate the text from Latin script to Greek script. e.g. “Ellēnikó alphábēto‎” transliterates to “Ελληνικό αλφάβητο”. This transformation is reversible.
///  * `latinToHangul`        - transliterate the text from Latin script to Hangul script. e.g. “hangul” transliterates to “한굴”. This transformation is reversible.
///  * `latinToHebrew`        - transliterate the text from Latin script to Hebrew script. e.g. “ʻbryţ” transliterates to “עברית”. This transformation is reversible.
///  * `latinToHiragana`      - transliterate the text from Latin script to Hiragana script. e.g. “hiragana” transliterates to “ひらがな”. This transformation is reversible.
///  * `latinToKatakana`      - transliterate the text from Latin script to Katakana script. e.g. “katakana” transliterates to “カタカナ”. This transformation is reversible.
///  * `latinToThai`          - transliterate the text from Latin script to Thai script. e.g. “p̣hās̄ʹā thịy” transliterates to “ภาษาไทย”. This transformation is reversible.
///  * `mandarinToLatin`      - transliterate the text from Han script to Latin script. e.g. “hàn zì” transliterates to “汉字”.
///  * `stripCombiningMarks`  - removes all combining marks (including diacritics and accents) from the text
///  * `stripDiacritics`      - removes all diacritic marks from the text
///  * `toLatin`              - transliterate all text possible to Latin script. Ideographs are transliterated as Mandarin Chinese.
///  * `toUnicodeName`        - converts characters other than printable ASCII to their Unicode character name in braces. e.g. “🐶🐮” transforms to "\N{DOG FACE}\N{COW FACE}". This transformation is reversible.
///  * `toXMLHex`             - transliterate characters other than printable ASCII to XML/HTML numeric entities. e.g. “❦” transforms to “&#x2766;”. This transformation is reversible.
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

/// hs.text.utf16.compareOptions
/// Constant
/// A table containing the modifier options for use with the [hs.text.utf16:compare](#compare) method.
///
/// This table contains key-value pairs specifying the numeric values which should be logically OR'ed together (or listed individually in a table as either the integer or the key name) for use with the [hs.text.utf16:compare](#compare) method.
///
/// Valid options are as follows:
///  * `caseInsensitive`      - sort order is case-insensitive
///  * `diacriticInsensitive` - ignores diacritic marks
///  * `finderFileOrder`      - sort order matches what the Finder uses for the locale specified. This is a convienence combination which is equivalent to `{ "caseInsensitive", "numeric", "widthInsensitive", "forcedOrdering" }`.
///  * `forcedOrdering`       - comparisons are forced to return either -1 or 1 if the strings are equivalent but not strictly equal. (e.g.  “aaa” is greater than "AAA" if `caseInsensitive` is also set.)
///  * `literal`              - exact character-by-character equivalence.
///  * `numeric`              - numbers within the string are compared numerically. This only applies to actual numeric characters, not characters that would have meaning in a numeric representation such as a negative sign, a comma, or a decimal point.
///  * `widthInsensitive`     - ignores width differences in characters that have full-width and half-width forms, common in East Asian character sets.
static int utf16_compareOptions(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSCaseInsensitiveSearch) ;      lua_setfield(L, -2, "caseInsensitive") ;
    lua_pushinteger(L, NSLiteralSearch) ;              lua_setfield(L, -2, "literal") ;
    lua_pushinteger(L, NSNumericSearch) ;              lua_setfield(L, -2, "numeric") ;
    lua_pushinteger(L, NSDiacriticInsensitiveSearch) ; lua_setfield(L, -2, "diacriticInsensitive") ;
    lua_pushinteger(L, NSWidthInsensitiveSearch) ;     lua_setfield(L, -2, "widthInsensitive") ;
    lua_pushinteger(L, NSForcedOrderingSearch) ;       lua_setfield(L, -2, "forcedOrdering") ;
    // convienence combination:
    lua_pushinteger(L, NSCaseInsensitiveSearch | NSNumericSearch | NSWidthInsensitiveSearch | NSForcedOrderingSearch) ;
    lua_setfield(L, -2, "finderFileOrder") ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSTextUTF16Object(lua_State *L, id obj) {
    LuaSkin *skin  = [LuaSkin shared] ;
    HSTextUTF16Object *value = obj ;
    if (value.selfRefCount == 0) {
        void** valuePtr = lua_newuserdata(L, sizeof(HSTextUTF16Object *)) ;
        *valuePtr = (__bridge_retained void *)value ;
        luaL_getmetatable(L, UTF16_UD_TAG) ;
        lua_setmetatable(L, -2) ;
        value.selfRef = [skin luaRef:refTable] ;
    }
    value.selfRefCount++ ;
    [skin pushLuaRef:refTable ref:value.selfRef] ;
    return 1 ;
}

id toHSTextUTF16ObjectFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSTextUTF16Object *value ;
    if (luaL_testudata(L, idx, UTF16_UD_TAG)) {
        value = get_objectFromUserdata(__bridge HSTextUTF16Object, L, idx, UTF16_UD_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UTF16_UD_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_concat(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
// can't get here if at least one of us isn't our userdata type
    HSTextUTF16Object *obj1 = luaL_testudata(L, 1, UTF16_UD_TAG) ? [skin luaObjectAtIndex:1 toClass:"HSTextUTF16Object"] : nil ;
    if (!obj1) {
        if (lua_type(L, 1) == LUA_TSTRING || lua_type(L, 1) == LUA_TNUMBER) {
            const char *input = lua_tostring(L, 1) ;
            obj1 = [[HSTextUTF16Object alloc] initWithString:[NSString stringWithCString:input encoding:NSUTF8StringEncoding]] ;
        } else {
            return luaL_error(L, "attempt to concatenate a %s value", lua_typename(L, 1)) ;
        }
    }
    HSTextUTF16Object *obj2 = luaL_testudata(L, 2, UTF16_UD_TAG) ? [skin luaObjectAtIndex:2 toClass:"HSTextUTF16Object"] : nil ;
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

static int userdata_common_compare_wrapper(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
// can't get here if at least one of us isn't our userdata type
    HSTextUTF16Object *obj1 = luaL_testudata(L, 1, UTF16_UD_TAG) ? [skin luaObjectAtIndex:1 toClass:"HSTextUTF16Object"] : nil ;
    if (!obj1) {
        if (lua_type(L, 1) == LUA_TSTRING || lua_type(L, 1) == LUA_TNUMBER) {
            const char *input = lua_tostring(L, 1) ;
            obj1 = [[HSTextUTF16Object alloc] initWithString:[NSString stringWithCString:input encoding:NSUTF8StringEncoding]] ;
        } else {
            return luaL_error(L, "attempt to compare a %s value", lua_typename(L, 1)) ;
        }
    }
    HSTextUTF16Object *obj2 = luaL_testudata(L, 2, UTF16_UD_TAG) ? [skin luaObjectAtIndex:2 toClass:"HSTextUTF16Object"] : nil ;
    if (!obj2) {
        if (lua_type(L, 2) == LUA_TSTRING || lua_type(L, 2) == LUA_TNUMBER) {
            const char *input = lua_tostring(L, 2) ;
            obj2 = [[HSTextUTF16Object alloc] initWithString:[NSString stringWithCString:input encoding:NSUTF8StringEncoding]] ;
        } else {
            return luaL_error(L, "attempt to compare a %s value", lua_typename(L, 2)) ;
        }
    }

    lua_pushcfunction(L, utf16_compare) ;
    [skin pushNSObject:obj1] ;
    [skin pushNSObject:obj2] ;
    lua_pushinteger(L, NSLiteralSearch) ;
    if (![skin protectedCallAndTraceback:3 nresults:1]) {
        return luaL_error(L, lua_tostring(L, -1)) ;
    }
    return 1 ;
}

// less than
static int userdata_lt(lua_State *L) {
    userdata_common_compare_wrapper(L) ;
    lua_Integer result = lua_tointeger(L, -1) ;
    lua_pop(L, 1) ;
    lua_pushboolean(L, (result < 0)) ;
    return 1 ;
}

// less than or equal to
// (strictly not required in 5.3 as lua assumes `a <= b` is equivalent to `not (b < a)`
// but this use case is listed as "may go away in the future", so...)
static int userdata_le(lua_State *L) {
    userdata_common_compare_wrapper(L) ;
    lua_Integer result = lua_tointeger(L, -1) ;
    lua_pop(L, 1) ;
    lua_pushboolean(L, (result <= 0)) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    userdata_common_compare_wrapper(L) ;
    lua_Integer result = lua_tointeger(L, -1) ;
    lua_pop(L, 1) ;
    lua_pushboolean(L, (result == 0)) ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSTextUTF16Object *obj = get_objectFromUserdata(__bridge_transfer HSTextUTF16Object, L, 1, UTF16_UD_TAG) ;
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
    {"copy",                   utf16_copy},
    {"_compare",               utf16_compare},

    {"upper",                  utf16_string_upper},
    {"lower",                  utf16_string_lower},
    {"len",                    utf16_string_length},
    {"sub",                    utf16_string_sub},
    {"reverse",                utf16_string_reverse},
    {"match",                  utf16_string_match},
    {"find",                   utf16_string_find},
    {"gsub",                   utf16_string_gsub},

    {"codepoint",              utf16_utf8_codepoint},
    {"offset",                 utf16_utf8_offset},
    {"characterCount",         utf16_utf8_len},

    {"__concat",               userdata_concat},
    {"__tostring",             userdata_tostring},
    {"__len",                  utf16_string_length},
    {"__lt",                   userdata_lt},
    {"__le",                   userdata_le},
    {"__eq",                   userdata_eq},
    {"__gc",                   userdata_gc},
    {NULL,                     NULL}
} ;

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",                       utf16_new},
    {"char",                      utf16_utf8_char},
    {"isHighSurrogate",           utf16_isHighSurrogate},
    {"isLowSurrogate",            utf16_isLowSurrogate},
    {"surrogatePairForCodepoint", utf16_surrogatePairForCodepoint},
    {"codepointForSurrogatePair", utf16_codepointForSurrogatePair},
    {NULL,                        NULL}
} ;

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// } ;

int luaopen_hs_text_utf16(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:UTF16_UD_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib] ;

    utf16_builtinTransforms(L) ; lua_setfield(L, -2, "builtinTransforms") ;
    utf16_compareOptions(L) ;    lua_setfield(L, -2, "compareOptions") ;

    [skin registerPushNSHelper:pushHSTextUTF16Object         forClass:"HSTextUTF16Object"] ;
    [skin registerLuaObjectHelper:toHSTextUTF16ObjectFromLua forClass:"HSTextUTF16Object"
                                                  withUserdataMapping:UTF16_UD_TAG] ;

    return 1 ;
}
