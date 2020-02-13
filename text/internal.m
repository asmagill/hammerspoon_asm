@import Cocoa ;
@import LuaSkin ;

#import "text.h"

static int refTable = LUA_NOREF;

#pragma mark - Support Functions and Classes

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

/// hs.text.new(text, [encoding] | [lossy, [windows]]) -> textObject
/// Constructor
/// Creates a new text object from a lua string or `hs.text.utf16` object.
///
/// Params:
///  * `text`      - a lua string or `hs.text.utf16` object. When this parameter is an `hs.text.utf16` object, no other parameters are allowed.
///  * `encoding`  - an optional integer, specifying the encoding of the contents of the lua string. Valid encodings are contained within the [hs.text.encodingTypes](#encodingTypes) table.
///  * If `encoding` is not provided, this contructor will attempt to guess the encoding (see [hs.text:guessEncoding](#guessEncoding) for more details).
///    * `lossy`   - an optional boolean, defailt false, specifying whether or not characters can be removed or altered when guessing the encoding.
///    * `windows` - an optional boolean, default false, specifying whether or not to consider encodings corresponding to Windows codepage numbers when guessing the encoding.
///
/// Returns:
///  * a new textObject
///
/// Notes:
///  * The contents of `text` is stored exactly as provided, even if the specified encoding (or guessed encoding) is not valid for the entire contents of the data.
static int text_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSData *rawData = nil ;

    if (lua_type(L, 1) == LUA_TSTRING) {
        [skin checkArgs:LS_TSTRING, LS_TBREAK | LS_TVARARG] ;
        rawData = [skin toNSObjectAtIndex:1 withOptions:LS_NSLuaStringAsDataOnly] ;
    } else {
        [skin checkArgs:LS_TUSERDATA, UTF16_UD_TAG, LS_TBREAK] ;
        HSTextUTF16Object *object = [skin toNSObjectAtIndex:1] ;
        rawData = [object.utf16string dataUsingEncoding:NSUnicodeStringEncoding] ;
    }

    BOOL             hasEncoding = (lua_gettop(L) > 1 && lua_type(L, 2) == LUA_TNUMBER) ;
    NSStringEncoding encoding ;

    if (hasEncoding) {
        [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
        encoding = (NSStringEncoding)lua_tointeger(L, 2) ;
    } else {
        [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
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

/// hs.text.readFile(path, [encoding]) -> textObject | nil, errorString
/// Constructor
/// Create text object with the contents of the file at the specified path.
///
/// Parameters:
///  * `path`     - a string specifying the absolute or relative (to your Hammerspoon configuration directory) path to the file to read.
///  * `encoding` - an optional integer specifying the encoding of the data in the file. See [hs.text.encodingTypes](#encodingTypes) for possible values.
///
/// Returns:
///  * a new textObject containing the contents of the specified file, or nil and a string specifying the error
///
/// Notes:
///  * if no encoding is specified, the encoding will be determined by macOS when the file is read. If no encoding can be determined, the file will be read as if the encoding had been specified as [hs.text.encodingTypes.rawData](#encodingTypes)
///    * to identify the encoding determined, see [hs.text:encoding](#encoding)
static int text_fromFile(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    NSString         *path       = [skin toNSObjectAtIndex:1] ;
    BOOL             hasEncoding = lua_gettop(L) > 1 ;
    NSStringEncoding encoding    = hasEncoding ? (NSStringEncoding)lua_tointeger(L, 2) : (NSStringEncoding)0 ;

    path = path.stringByStandardizingPath ;
    NSData  *data  = nil ;
    NSError *error = nil ;

    if (hasEncoding && encoding != 0) {
        NSString *fileContents = [NSString stringWithContentsOfFile:path
                                                           encoding:encoding
                                                              error:&error] ;
        if (!error) {
            data = [fileContents dataUsingEncoding:encoding] ;
        }
    } else if (!hasEncoding) {
        NSString *fileContents = [NSString stringWithContentsOfFile:path
                                                       usedEncoding:&encoding
                                                              error:&error ] ;
        if (!error) {
            data = [fileContents dataUsingEncoding:encoding] ;
        } else {
            // it probably already is, but since we want to make sure to try a raw data grab, be explicit
            encoding = 0 ;
            error    = nil ;
        }
    }

    if (encoding == 0) {
        data = [NSData dataWithContentsOfFile:path
                                      options:0
                                        error:&error] ;
    }

    if (error) {
        lua_pushnil(L) ;
        [skin pushNSObject:error.localizedDescription] ;
        return 2 ;
    } else {
        HSTextObject *object = [[HSTextObject alloc] init:data withEncoding:encoding] ;
        [skin pushNSObject:object] ;
        return 1 ;
    }
}

/// hs.text.encodingName(encoding) -> string
/// Function
/// Returns the localzed name for the encoding.
///
/// Parameters:
///  * `encoding` - an integer specifying the encoding
///
/// Returns:
///  * a string specifying the localized name for the encoding specified or an empty string if the number does not refer to a valid encoding.
///
/// Notes:
///  * the name returned will match the name of one of the keys in [hs.text.encodingTypes](#encodingTypes) unless the system locale has changed since the module was first loaded.
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

/// hs.text:writeToFile(path, [encoding]) -> textObject | nil, errorString
/// Method
/// Write the textObject to the specified file.
///
/// Parameters:
///  * `path`     - a string specifying the absolute or relative (to your Hammerspoon configuration directory) path to save the data to.
///  * `encoding` - an optional integer specifying the encoding to use when writing the file. If not specified, the current encoding of the textObject is used. See [hs.text.encodingTypes](#encodingTypes) for possible values.
///
/// Returns:
///  * the textObject, or nil and a string specifying the error
static int text_saveToFile(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSTextObject     *object     = [skin toNSObjectAtIndex:1] ;
    NSString         *path       = [skin toNSObjectAtIndex:2] ;
    BOOL             hasEncoding = (lua_gettop(L) > 2) ;
    NSStringEncoding encoding    = hasEncoding ? (NSStringEncoding)lua_tointeger(L, 3) : object.encoding ;

    path = path.stringByStandardizingPath ;

    NSError *writeError = nil ;
    BOOL    succeeded   = NO ;
    if (encoding == 0) {
        succeeded = [object.contents writeToFile:path options:NSDataWritingAtomic error:&writeError] ;
        if (writeError) succeeded = YES ; // probably is already, but just in case
    } else {
        NSString *objectString = [[NSString alloc] initWithData:object.contents encoding:object.encoding] ;
        succeeded = [objectString writeToFile:path atomically:YES encoding:encoding error:&writeError] ;
        if (writeError) succeeded = YES ; // probably is already, but just in case
    }

    if (!succeeded) {
        lua_pushnil(L) ;
        if (writeError) {
            [skin pushNSObject:writeError.localizedDescription] ;
        } else {
            lua_pushstring(L, "unspecified error") ;
        }
        return 2 ;
    } else {
        lua_pushvalue(L, 1) ;
        return 1 ;
    }
}

/// hs.text:guessEncoding([lossy], [windows]) -> integer, boolean
/// Method
/// Guess the encoding for the data held in the textObject
///
/// Paramters:
///  * `lossy`   - an optional boolean, defailt false, specifying whether or not characters can be removed or altered when guessing the encoding.
///  * `windows` - an optional boolean, default false, specifying whether or not to consider encodings corresponding to Windows codepage numbers when guessing the encoding.
///
/// Returns:
///  * an integer specifying the guessed encoding and a boolean indicating whether or not the guess results in partial data loss (lossy)
///
/// Notes:
///  * this method works with the raw data contents of the textObject and ignores the currently assigned encoding.
///  * the integer returned will correspond to an encoding defined in [hs.text.encodingTypes](#encodingTypes)
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

/// hs.text:fastestEncoding() -> integer
/// Method
/// Returns the fastest encoding to which the textObject may be converted without loss of information.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an integer specifying the encoding
///
/// Notes:
///  * this method works with string representation of the textObject in its current encoding.
///  * the integer returned will correspond to an encoding defined in [hs.text.encodingTypes](#encodingTypes)
///  * “Fastest” applies to retrieval of characters from the string. This encoding may not be space efficient. See also [hs.text:smallestEncoding](#smallestEncoding).
static int text_fastestEncoding(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSTextObject *object = [skin toNSObjectAtIndex:1] ;

// do we need special check for when encoding = 0?
    NSString *string = [[NSString alloc] initWithData:object.contents encoding:object.encoding] ;
    lua_pushinteger(L, (lua_Integer)string.fastestEncoding) ;
    return 1 ;
}

/// hs.text:smallestEncoding() -> integer
/// Method
/// Returns the smallest encoding to which the textObject may be converted without loss of information.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an integer specifying the encoding
///
/// Notes:
///  * this method works with string representation of the textObject in its current encoding.
///  * the integer returned will correspond to an encoding defined in [hs.text.encodingTypes](#encodingTypes)
///  * This encoding may not be the fastest for accessing characters, but is space-efficient. See also [hs.text:fastestEncoding](#fastestEncoding).
static int text_smallestEncoding(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSTextObject *object = [skin toNSObjectAtIndex:1] ;

// do we need special check for when encoding = 0?
    NSString *string = [[NSString alloc] initWithData:object.contents encoding:object.encoding] ;
    lua_pushinteger(L, (lua_Integer)string.smallestEncoding) ;
    return 1 ;
}

/// hs.text:encoding() -> integer
/// Method
/// Returns the encoding currently assigned for the textObject
///
/// Parameters:
///  * None
///
/// Returns:
///  * an integer specifying the encoding
///
/// Notes:
///  * the integer returned will correspond to an encoding defined in [hs.text.encodingTypes](#encodingTypes)
static int text_encoding(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSTextObject *object = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, (lua_Integer)object.encoding) ;
    return 1 ;
}

/// hs.text:rawData() -> string
/// Method
/// Returns the raw data which makes up the contents of the textObject
///
/// Parameters:
///  * None
///
/// Returns:
///  * a lua string containing the raw data of the textObject
static int text_raw(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSTextObject *object = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:object.contents] ;
    return 1 ;
}

/// hs.text:validEncodings([lossy]) -> table of integers
/// Method
/// Generate a list of possible encodings for the data represented by the hs.text object
///
/// Paramters:
///  * `lossy`   - an optional boolean, defailt false, specifying whether or not characters can be removed or altered when evaluating each potential encoding.
///
/// Returns:
///  * a table of integers specifying identified potential encodings for the data. Each integer will correspond to an encoding defined in [hs.text.encodingTypes](#encodingTypes)
///
/// Notes:
///  * this method works with the raw data contents of the textObject and ignores the currently assigned encoding.
///  * the encodings identified are ones for which the bytes of data can represent valid character or formatting sequences within the encoding -- the specific textual representation for each encoding may differ. See the notes for [hs.text:asEncoding](#asEncoding) for an example of a byte sequence which has very different textual meanings for different encodings.
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

/// hs.text:asEncoding(encoding, [lossy]) -> textObject | nil
/// Method
/// Convert the textObject to a different encoding.
///
/// Parameters:
///  * `encoding` - an integer specifying the new encoding. Valid encoding values can be looked up in [hs.text.encodingTypes](#encodingTypes)
///  * `lossy`    - a optional boolean, defailt false, specifying whether or not characters can be removed or altered when converted to the new encoding.
///
/// Returns:
///  * a new textObject with the text converted to the new encoding, or nil if the object cannot be converted to the new encoding.
///
/// Notes:
///  * If the encoding is not 0 ([hs.text.encodingTypes.rawData](#encodingTypes)), the actual data in the new textObject may be different then the original if the new encoding represents the characters differently.
///
///  * The encoding type 0 is special in that it creates a new textObject with the exact same data as the original but with no information as to the encoding type. This can be useful when the textObject has assumed an incorrect encoding and you wish to change it without loosing data. For example:
///
///       ~~~
///       a = hs.text.new("abcd")
///       print(a:encoding(), #a, #(a:rawData()), a:tostring()) -- prints `1	4	4	abcd`
///
///       b = a:asEncoding(hs.text.encodingTypes.UTF16)
///       print(b:encoding(), #b, #(b:rawData()), b:tostring()) -- prints `10	4	10	abcd`
///           -- note the change in the length of the raw data (the first two bytes will be the UTF16 BOM, but even factoring that out, the size went from 4 to 8), but not the text represented
///
///       c = a:asEncoding(0):asEncoding(hs.text.encodingTypes.UTF16)
///       print(c:encoding(), #c, #(c:rawData()), c:tostring()) -- prints `10	2	6	慢捤`
///           -- note the change in the length of both the text and the raw data, as well as the actual text represented. Factoring out the UTF16 BOM, the data length is still 4, like the original object.
///       ~~~
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

/// hs.text:encodingValid() -> boolean
/// Method
/// Returns whether or not the current encoding is valid for the data in the textObject
///
/// Paramters:
///  * None
///
/// Returns:
///  * a boolean indicathing whether or not the encoding for the textObject is valid for the data in the textObject
///
/// Notes:
///  * for an encoding to be considered valid by the macOS, it must be able to be converted to an NSString object within the Objective-C runtime. The resulting string may or may not be an exact representation of the data present (i.e. it may be a lossy representation). See also [hs.text:encodingLossless](#encodingLossless).
///  * a textObject with an encoding of 0 (rawData) is always considered invalid (i.e. this method will return false)
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

/// hs.text:encodingLossless() -> boolean
/// Method
/// Returns whether or not the data representing the textObject is completely valid for the objects currently specified encoding with no loss or conversion of characters required.
///
/// Paramters:
///  * None
///
/// Returns:
///  * a boolean indicathing whether or not the data representing the textObject is completely valid for the objects currently specified encoding with no loss or conversion of characters required.
///
/// Notes:
///  * for an encoding to be considered lossless, no data may be dropped or changed when evaluating the data within the requirements of the encoding. See also [hs.text:encodingValid](#encodingValid).
///  * a textObject with an encoding of 0 (rawData) is always considered lossless (i.e. this method will return true)
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

/// hs.text:len() -> integer
/// Method
/// Returns the length of the textObject
///
/// Paramaters:
///  * None
///
/// Returns:
///  * an integer specifying the length of the textObject
///
/// Notes:
///  * if the textObject's encoding is 0 (rawData), this method will return the number of bytes of data the textObject contains
///  * otherwise, the length will be the number of characters the data represents in its current encoding.
static int text_length(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    // when used as the metmethod __len, we may get "self" provided twice, so let's just check the first arg
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;

    HSTextObject *object = [skin toNSObjectAtIndex:1] ;

    if (object.encoding == 0) {
        lua_pushinteger(L, (lua_Integer)object.contents.length) ;
    } else {
        NSString *objString = [[NSString alloc] initWithData:object.contents encoding:object.encoding] ;
        lua_pushinteger(L, (lua_Integer)objString.length) ;
    }
    return 1 ;
}

#pragma mark - Module Constants

/// hs.text.encodingTypes
/// Constant
/// A table containing key-value pairs mapping encoding names to their integer representation used by the methods in this module.
///
/// This table will contain all of the encodings recognized by the macOS Objective-C runtime. Key values (strings) will be the localized name of the encoding based on the users locale at the time this module is loaded.
///
/// In addition to the localized names generated at load time, the following common encoding shorthands are also defined and are guaranteed to be consistent across all locales:
///
///  * `rawData`           - The data of the textObject is treated as 8-bit bytes with no special meaning or encodings.
///  * `ASCII`             - Strict 7-bit ASCII encoding within 8-bit chars; ASCII values 0…127 only.
///  * `ISO2022JP`         - ISO 2022 Japanese encoding for email.
///  * `ISOLatin1`         - 8-bit ISO Latin 1 encoding.
///  * `ISOLatin2`         - 8-bit ISO Latin 2 encoding.
///  * `JapaneseEUC`       - 8-bit EUC encoding for Japanese text.
///  * `MacOSRoman`        - Classic Macintosh Roman encoding.
///  * `NEXTSTEP`          - 8-bit ASCII encoding with NEXTSTEP extensions.
///  * `NonLossyASCII`     - 7-bit verbose ASCII to represent all Unicode characters.
///  * `ShiftJIS`          - 8-bit Shift-JIS encoding for Japanese text.
///  * `Symbol`            - 8-bit Adobe Symbol encoding vector.
///  * `Unicode`           - The canonical Unicode encoding for string objects.
///  * `UTF16`             - A synonym for `Unicode`. The default encoding used by macOS and `hs.text.utf16` for direct manipulation of encoded text.
///  * `UTF16BigEndian`    - UTF16 encoding with explicit endianness specified.
///  * `UTF16LittleEndian` - UTF16 encoding with explicit endianness specified.
///  * `UTF32`             - 32-bit UTF encoding.
///  * `UTF32BigEndian`    - 32-bit UTF encoding with explicit endianness specified.
///  * `UTF32LittleEndian` - 32-bit UTF encoding with explicit endianness specified.
///  * `UTF8`              - An 8-bit representation of Unicode characters, suitable for transmission or storage by ASCII-based systems.
///  * `WindowsCP1250`     - Microsoft Windows codepage 1250; equivalent to WinLatin2.
///  * `WindowsCP1251`     - Microsoft Windows codepage 1251, encoding Cyrillic characters; equivalent to AdobeStandardCyrillic font encoding.
///  * `WindowsCP1252`     - Microsoft Windows codepage 1252; equivalent to WinLatin1.
///  * `WindowsCP1253`     - Microsoft Windows codepage 1253, encoding Greek characters.
///  * `WindowsCP1254`     - Microsoft Windows codepage 1254, encoding Turkish characters.
static int text_encodingTypes(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;

    // add our special built in encoding
    lua_pushinteger(L, 0) ;                                 lua_setfield(L, -2, "rawData") ;

    // add internal encodings with common shorthand names
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
    {"writeToFile",          text_saveToFile},

    {"__tostring",           userdata_tostring},
    {"__len",                text_length},
    {"__eq",                 userdata_eq},
    {"__gc",                 userdata_gc},
    {NULL,                   NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",          text_new},
    {"readFile",     text_fromFile},

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

    luaopen_hs_text_utf16(L) ; lua_setfield(L, -2, "utf16") ;
    luaopen_hs_text_http(L) ;  lua_setfield(L, -2, "http") ;

    return 1;
}
