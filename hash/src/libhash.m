// TODO:
//  +  pathList:
//  *      Change allow to exceptions to the ignore option
//  *          i.e. gets all files except those ignored
//         Move this to hs.fs?
//  *      change option parsing to loop through and warn of bad ooptions
//  *      change symlinks to followSymlinks
//  *      add expandSymlinks to optionally expand them or keep "linked path" to the file
//
//     Document
//     All files in table to individual line-by-line report wrapper
//     All files in table to one combined hash?
//  *  Add SHA-3
//     Add others?

@import Cocoa ;
@import CommonCrypto.CommonDigest ;
@import CommonCrypto.CommonHMAC ;
@import zlib ;
@import LuaSkin ;

// When adding a new hash type, you should only need to update a couple of areas...
// they are labeled with ADD_NEW_HASH_HERE

// uncomment to include deprecated/less-common hash types (see hashLookupTable below)
// #define INCLUDE_HISTORICAL

#include "algorithms.h"
#include "sha3.h"
// ADD_NEW_HASH_HERE -- assuming new hash code is in its own .m and .h files

static const char * const USERDATA_TAG = "hs.hash" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static const hashEntry_t hashLookupTable[] = {
#ifdef INCLUDE_HISTORICAL
    { "MD2",        init_MD2,        append_MD2,        finish_MD2        },
    { "MD4",        init_MD4,        append_MD4,        finish_MD4        },
    { "SHA224",     init_SHA224,     append_SHA224,     finish_SHA224     },
    { "SHA384",     init_SHA384,     append_SHA384,     finish_SHA384     },
    { "hmacSHA224", init_hmacSHA224, append_hmac,       finish_hmacSHA224 },
    { "hmacSHA384", init_hmacSHA384, append_hmac,       finish_hmacSHA384 },
#endif

    { "CRC32",      init_CRC32,      append_CRC32,      finish_CRC32      },
    { "MD5",        init_MD5,        append_MD5,        finish_MD5        },
    { "SHA1",       init_SHA1,       append_SHA1,       finish_SHA1       },
    { "SHA256",     init_SHA256,     append_SHA256,     finish_SHA256     },
    { "SHA512",     init_SHA512,     append_SHA512,     finish_SHA512     },
    { "hmacMD5",    init_hmacMD5,    append_hmac,       finish_hmacMD5    },
    { "hmacSHA1",   init_hmacSHA1,   append_hmac,       finish_hmacSHA1   },
    { "hmacSHA256", init_hmacSHA256, append_hmac,       finish_hmacSHA256 },
    { "hmacSHA512", init_hmacSHA512, append_hmac,       finish_hmacSHA512 },

    { "SHA3_224",   init_SHA3_224,   append_SHA3,       finish_SHA3_224   },
    { "SHA3_256",   init_SHA3_256,   append_SHA3,       finish_SHA3_256   },
    { "SHA3_384",   init_SHA3_384,   append_SHA3,       finish_SHA3_384   },
    { "SHA3_512",   init_SHA3_512,   append_SHA3,       finish_SHA3_512   },
// ADD_NEW_HASH_HERE -- label(s) for Hammerspoon and functions for initializing, appending to, and finishing
} ;

static const NSUInteger knownHashCount = sizeof(hashLookupTable) / sizeof(hashEntry_t) ;

@interface HSHashObject : NSObject
@property int        selfRefCount ;
@property NSUInteger hashType ;
@property NSData     *secret ;
@property void       *context ;
@property NSData     *value ;
@end

@implementation HSHashObject
- (instancetype)initHashType:(NSUInteger)hashType withSecret:(NSData *)secret {
    self = [super init] ;
    if (self) {
        _selfRefCount = 0 ;
        _hashType     = hashType ;
        _secret       = secret ;
        _context      = (hashLookupTable[_hashType].initFn)(secret) ;
        _value        = nil ;
    }
    return self ;
}

- (void)append:(NSData *)data {
    (hashLookupTable[_hashType].appendFn)(_context, data) ;
}

- (void)finish {
    _value = (hashLookupTable[_hashType].finishFn)(_context) ;
    _context = NULL ; // it was freed in the finish function
}
@end

#pragma mark - Module Functions

/// hs.hash.new(hash, [secret]) -> hashObject
/// Constructor
/// Creates a new context for the specified hash function.
///
/// Parameters:
///  * `hash`    - a string specifying the name of the hash function to use. This must be one of the string values found in the [hs.hash.types](#types) constant.
///  * `secret`  - an optional string specifying the shared secret to prepare the hmac hash function with. For all other hash types this field is ignored. Leaving this parameter off when specifying an hmac hash function is equivalent to specifying an empty secret or a secret composed solely of null values.
///
/// Returns:
///  * the new hash object
static int hash_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *hashName = [skin toNSObjectAtIndex:1] ;
    NSData   *secret   = nil ;
    if (lua_gettop(L) == 2) secret = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] ;

    NSUInteger hashType  = 0 ;
    BOOL       hashFound = NO ;

    for (NSUInteger i = 0 ; i < knownHashCount ; i++) {
        NSString *label = @(hashLookupTable[i].hashName) ;
        if ([hashName caseInsensitiveCompare:label] == NSOrderedSame) {
            hashFound = YES ;
            hashType = i ;
            break ;
        }
    }
    if (hashFound) {
        HSHashObject *object = [[HSHashObject alloc] initHashType:hashType
                                                          withSecret:secret] ;
        [skin pushNSObject:object] ;
    } else {
        return luaL_argerror(L, 1, "unrecognized hash type") ;
    }
    return 1 ;
}

/// hs.fs.fileListForPath(path, [options]) -> table
/// Function
/// Returns a table containing the paths to all of the files located at the specified path.
///
/// Parameters:
///  * `path`    - a string specifying the path to gather the files from. If this path specifies a file, then the return value is a table containing only this path. If the path specifies a directory, then the table contains the paths of all of the files found in the specified directory.
///  * `options` - an optional table with one or more key-value pairs determining how and what files are to be included in the table returned.
///    * The following keys are recognized:
///      * `subdirs`        - a boolean, default false, indicating whether or not subdirectories should be descended into and examined for files as well.
///      * `followSymlinks` - a boolean, default false, indicating whether or not symbolic links should be followed
///      * `expandSymlinks` - a boolean, default false, specifying whether or not the real path of any files discovered after following a symbolic link should be included in the list (true) or whether the path added to the list should remain relative to the starting path (false).
///      * `relativePath`   - a boolean, default false, specifying whether paths included in the result list should be relative to the starting path (true) or the full and complete path to the file (false).
///      * `ignore`         - a table of strings, specifying regular expression matches for files to exclude from the result list. If not provided, this value will be inherited from the module's variable [hs.fs.defaultPathListExcludes](#defaultPathListExcludes) which, by defualt, is set to ignore all files beginning with a period (often called dot-files). To include all files, set this option equal to the empty table (i.e. `{}`).
///      * `except`         - a table of strings, default empty, specifying regular expression matches for files that match an `ignore` rule, but should be included anyways. For example, if this option is set to `{ "^\\.gitignore$" }`, then a file named `.gitignore` would be included, even though it would normally be excluded by the default `ignore` ruleset.
///
/// Returns:
///  * a table containing the paths to the files discovered at the specified path. Only files will be included -- directory names are not included in the resulting list. The table will be sorted as per the Objective-C NSString's `compare:` method.
///
/// Notes:
///  * `ignore` and `except` options require the use of actual regular expressions, not the simplified pattern matching used by Lua. More details about the proper syntax for the strings to use in the tables of these options can be found at https://unicode-org.github.io/icu/userguide/strings/regexp.html.
///    * note that this function only checks to see if the regular expression returns a match for each filename found (not the path, just the filename component of the path). Any captures are ignored.
static int hash_filesInPath(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING,
                    LS_TTABLE | LS_TOPTIONAL,
                    LS_TBREAK] ;

    NSString *path   = [skin toNSObjectAtIndex:1] ;

    BOOL    subdirs        = NO ;
    BOOL    followSymlinks = NO ;
    BOOL    expandSymlinks = NO ;
    BOOL    relativePath   = NO ;
//     BOOL    objectWrapper  = NO ;
    NSArray *ignore        = nil ;
    NSArray *except        = nil ;

    if (lua_type(L, 2) == LUA_TTABLE) {
        lua_pushnil(L) ;
        while (lua_next(L, 2) != 0) {
            if (lua_type(L, -2) == LUA_TSTRING) {
                const char *keyName = lua_tostring(L, -2) ;
                if (!strcmp(keyName, "subdirs")) {
                    if (lua_type(L, -1) == LUA_TBOOLEAN) {
                        subdirs = (BOOL)(lua_toboolean(L, -1)) ;
                    } else {
                        return luaL_argerror(L, 2, "subdirs option expects boolean value") ;
                    }
                } else if (!strcmp(keyName, "followSymlinks")) {
                    if (lua_type(L, -1) == LUA_TBOOLEAN) {
                        followSymlinks = (BOOL)(lua_toboolean(L, -1)) ;
                    } else {
                        return luaL_argerror(L, 2, "followSymlinks option expects boolean value") ;
                    }
                } else if (!strcmp(keyName, "expandSymlinks")) {
                    if (lua_type(L, -1) == LUA_TBOOLEAN) {
                        expandSymlinks = (BOOL)(lua_toboolean(L, -1)) ;
                    } else {
                        return luaL_argerror(L, 2, "expandSymlinks option expects boolean value") ;
                    }
                } else if (!strcmp(keyName, "relativePath")) {
                    if (lua_type(L, -1) == LUA_TBOOLEAN) {
                        relativePath = (BOOL)(lua_toboolean(L, -1)) ;
                    } else {
                        return luaL_argerror(L, 2, "relativePath option expects boolean value") ;
                    }
// The speedup hoped for by this wasn't as impressive as desired; leaving the code in, though, in case we
// decide we need it later anyways. Also see the return section at the bottom
//                 } else if (!strcmp(keyName, "objectWrapper")) {
//                     if (lua_type(L, -1) == LUA_TBOOLEAN) {
//                         objectWrapper = (BOOL)(lua_toboolean(L, -1)) ;
//                     } else {
//                         return luaL_argerror(L, 2, "objectWrapper option expects boolean value") ;
//                     }
                } else if (!strcmp(keyName, "ignore")) {
                    ignore = [skin toNSObjectAtIndex:-1] ;
                    if ([ignore isKindOfClass:[NSArray class]]) {
                        for (NSString *entry in ignore) {
                            if ([entry isKindOfClass:[NSString class]]) continue ;
                            return luaL_argerror(L, 2, "ignore option table entries must be strings") ;
                        }
                    } else {
                        return luaL_argerror(L, 2, "ignore option expects table value") ;
                    }
                } else if (!strcmp(keyName, "except")) {
                    except = [skin toNSObjectAtIndex:-1] ;
                    if ([except isKindOfClass:[NSArray class]]) {
                        for (NSString *entry in except) {
                            if ([entry isKindOfClass:[NSString class]]) continue ;
                            return luaL_argerror(L, 2, "except option table entries must be strings") ;
                        }
                    } else {
                        return luaL_argerror(L, 2, "except option expects table value") ;
                    }
                } else {
                    return luaL_argerror(L, 2, [[NSString stringWithFormat:@"option %s not recognized", keyName] UTF8String]) ;
                }
            } else {
                return luaL_argerror(L, 2, "option table keys must be strings") ;
            }
            lua_pop(L, 1);
        }
    }

    if (!except) except = [NSArray array] ;

    if (!ignore) {
        [skin requireModule:USERDATA_TAG] ; // put our module on top of the stack
        lua_getfield(L, -1, "defaultPathListExcludes") ;
        ignore = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 2) ;
    }

    NSMutableArray *excluders  = [NSMutableArray arrayWithCapacity:ignore.count] ;
    NSMutableArray *exceptions = [NSMutableArray arrayWithCapacity:except.count] ;
    for (NSUInteger i = 0 ; i < ignore.count ; i++) {
        NSError *error = nil ;
        NSRegularExpression *p = [NSRegularExpression regularExpressionWithPattern:ignore[i]
                                                                           options:NSRegularExpressionUseUnicodeWordBoundaries
                                                                             error:&error] ;
        if (!error) {
            [excluders addObject:p] ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalid regex (%@) at index %lu of ignore option", error.localizedDescription, i + 1] UTF8String]) ;
        }
    }
    for (NSUInteger i = 0 ; i < except.count ; i++) {
        NSError *error = nil ;
        NSRegularExpression *p = [NSRegularExpression regularExpressionWithPattern:except[i]
                                                                           options:NSRegularExpressionUseUnicodeWordBoundaries
                                                                             error:&error] ;
        if (!error) {
            [exceptions addObject:p] ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalid regex (%@) at index %lu of except option", error.localizedDescription, i + 1] UTF8String]) ;
        }
    }

    path = path.stringByExpandingTildeInPath.stringByResolvingSymlinksInPath ;
    lua_Integer dirCount  = 0 ;

    NSFileManager *fileManager = [NSFileManager defaultManager] ;
    BOOL        isDirectory ;
    BOOL        fileExists = [fileManager fileExistsAtPath:path isDirectory:&isDirectory] ;

    // take care of the easy cases:
    if (!fileExists) {
        return luaL_argerror(L, 1, "path does not specify a reachable file or directory") ;
    } else if (!isDirectory) {
        [skin pushNSObject:@[ path ]] ;
        lua_pushinteger(L, 1) ;
        lua_pushinteger(L, 0) ;
        return 3 ;
    }

    NSURL    *startingURL  = [NSURL fileURLWithPath:path isDirectory:YES] ;
// stdlib realpath() instead?
    NSString *startingPath = nil ;
    [startingURL getResourceValue:&startingPath forKey:NSURLPathKey error:nil] ;

    NSMutableArray *foundPaths      = [NSMutableArray array] ;
    NSMutableArray *seenDirectories = [NSMutableArray array] ; // to prevent loops when links is true
    NSMutableArray *directories     = [NSMutableArray arrayWithObject:@[ startingPath, startingPath ]] ;

    while(directories.count > 0) {
        NSArray *currentPathArray = directories[0] ;
        [directories removeObjectAtIndex:0] ;
        dirCount++ ;

        NSString *thisDir     = currentPathArray[0] ;
        NSString *symbolicDir = currentPathArray[1] ;

        [seenDirectories addObject:thisDir] ;

        NSURL                 *thisDirURL = [NSURL fileURLWithPath:thisDir isDirectory:YES] ;
        NSDirectoryEnumerator *dirEnum    = [fileManager enumeratorAtURL:thisDirURL
                                              includingPropertiesForKeys:@[
                                                                             NSURLIsRegularFileKey,
                                                                             NSURLIsSymbolicLinkKey,
                                                                             NSURLIsDirectoryKey,
                                                                             NSURLPathKey
                                                                         ]
                                                                 options: NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                                            errorHandler:nil] ;
        for (__strong NSURL *fileURL in dirEnum) {
            NSString *filePath = nil ;
            [fileURL getResourceValue:&filePath forKey:NSURLPathKey error:nil] ;

            NSNumber *isSymbolicLink = nil ;
            [fileURL getResourceValue:&isSymbolicLink forKey:NSURLIsSymbolicLinkKey error:nil] ;

            NSString *originalFilePath = [filePath copy] ;
            NSString *fileName = originalFilePath.lastPathComponent ;

            if (isSymbolicLink.boolValue) {
                if (followSymlinks) {
                    NSString *newPath = filePath.stringByResolvingSymlinksInPath ;
                    if ([fileManager fileExistsAtPath:newPath]) {
                        fileURL = [NSURL fileURLWithPath:newPath] ;
                        [fileURL getResourceValue:&filePath forKey:NSURLPathKey error:nil] ;
                    } else {
                        [LuaSkin logWarn:[NSString stringWithFormat:@"%s.pathList - error resolving symbolic link %@", USERDATA_TAG, newPath]] ;
                        continue ;
                    }
                } else {
                    continue ;
                }
            }

            BOOL keepGoing = YES ;

            for (NSRegularExpression *test in excluders) {
                NSUInteger matches = [test numberOfMatchesInString:fileName options:0 range:NSMakeRange(0, fileName.length)] ;
                if (matches > 0) {
                    keepGoing = NO ;
                    break ;
                }
            }

            for (NSRegularExpression *test in exceptions) {
                NSUInteger matches = [test numberOfMatchesInString:fileName options:0 range:NSMakeRange(0, fileName.length)] ;
                if (matches > 0) {
                    keepGoing = YES ;
                    break ;
                }
            }

            if (!keepGoing) continue ;

            NSNumber *isRegularFile = nil ;
            [fileURL getResourceValue:&isRegularFile forKey:NSURLIsRegularFileKey error:nil] ;
            if (isRegularFile.boolValue) {
                if (!expandSymlinks) {
                    filePath = [originalFilePath stringByReplacingOccurrencesOfString:thisDir
                                                                           withString:symbolicDir
                                                                              options:(NSAnchoredSearch | NSLiteralSearch)
                                                                                range:NSMakeRange(0, originalFilePath.length)] ;
                }
                if (relativePath && [filePath hasPrefix:startingPath]) {
                    [foundPaths addObject:[filePath substringFromIndex:startingPath.length + 1]] ; // include / before rest of path
                } else {
                    [foundPaths addObject:filePath] ;
                }
            } else if (subdirs) {
                NSNumber *isThisDir = nil ;
                [fileURL getResourceValue:&isThisDir forKey:NSURLIsDirectoryKey error:nil] ;
                if (isThisDir.boolValue && ![seenDirectories containsObject:filePath]) {
                    [directories addObject:@[ filePath, [NSString stringWithFormat:@"%@/%@", symbolicDir, fileName] ]] ;
                }
            }
        }
    }

    // ensure consistent order
    [foundPaths sortUsingSelector:@selector(compare:)] ;

//     if (objectWrapper) {
//         [skin pushNSObject:foundPaths withOptions:LS_WithObjectWrapper | LS_OW_ReadWrite] ;
//     } else {
        [skin pushNSObject:foundPaths] ;
//     }
    lua_pushinteger(L, (lua_Integer)foundPaths.count) ;
    lua_pushinteger(L, dirCount) ;
    return 3;
}

#pragma mark - Module Methods

/// hs.hash:append(data) -> hashObject
/// Method
/// Adds the provided data to the input of the hash function currently in progress for the hashObject.
///
/// Parameters:
///  * `data` - a string containing the data to add to the hash functions input.
///
/// Returns:
///  * the hash object
static int hash_append(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    HSHashObject *object = [skin toNSObjectAtIndex:1] ;
    NSData       *data   = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] ;

    if (!object.value) {
        [object append:data] ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "hash calculation completed") ;
        return 2 ;
    }

    lua_pushvalue(L, 1) ;
    return 1 ;
}


static int hash_appendFile(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    HSHashObject *object = [skin toNSObjectAtIndex:1] ;
    NSString     *path   = [skin toNSObjectAtIndex:2] ;

    path = path.stringByExpandingTildeInPath.stringByResolvingSymlinksInPath ;
    NSError *error = nil ;
    NSData  *data  = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:&error] ;
    if (!error) {
        [object append:data] ;
    } else {
        lua_pushnil(L) ;
        lua_pushfstring(L, "error reading contents of %s: %s", path.UTF8String, error.localizedDescription.UTF8String) ;
        return 2 ;
    }

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int hash_finish(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSHashObject *object = [skin toNSObjectAtIndex:1] ;

    if (!object.value) [object finish] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int hash_value(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSHashObject *object  = [skin toNSObjectAtIndex:1] ;
    BOOL         inBinary = (lua_gettop(L) == 2) ? (BOOL)(lua_toboolean(L, 2)) : NO ;

    if (object.value) {
        if (inBinary) {
            [skin pushNSObject:object.value] ;
        } else {
            NSMutableString* asHex = [NSMutableString stringWithCapacity:(object.value.length * 2)] ;
            [object.value enumerateByteRangesUsingBlock:^(const void *bytes, NSRange range, __unused BOOL *stop) {
                for (NSUInteger i = 0; i < range.length; ++i) {
                    [asHex appendFormat:@"%02x", ((const uint8_t*)bytes)[i]];
                }
            }];
            [skin pushNSObject:asHex] ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int hash_type(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSHashObject *object = [skin toNSObjectAtIndex:1] ;
    lua_pushstring(L, hashLookupTable[object.hashType].hashName) ;
    return 1 ;
}

#pragma mark - Module Constants

static int hash_types(lua_State *L) {
    lua_newtable(L) ;
    for (NSUInteger i = 0 ; i < knownHashCount ; i++) {
        lua_pushstring(L, hashLookupTable[i].hashName) ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSHashObject(lua_State *L, id obj) {
    HSHashObject *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSHashObject *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSHashObjectFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSHashObject *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSHashObject, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSHashObject *obj = [skin luaObjectAtIndex:1 toClass:"HSHashObject"] ;
    NSString *title = [NSString stringWithFormat:@"%s", hashLookupTable[obj.hashType].hashName] ;
    if (!obj.value) {
        title = [NSString stringWithFormat:@"%@ <in-progress>", title];
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSHashObject *obj1 = [skin luaObjectAtIndex:1 toClass:"HSHashObject"] ;
        HSHashObject *obj2 = [skin luaObjectAtIndex:2 toClass:"HSHashObject"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSHashObject *obj = get_objectFromUserdata(__bridge_transfer HSHashObject, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            if (obj.context) [obj finish] ;
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
    {"append",     hash_append},
    {"appendFile", hash_appendFile},
    {"finish",     hash_finish},
    {"value",      hash_value},
    {"type",       hash_type},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",         hash_new},
    {"filesInPath", hash_filesInPath},
    {NULL,          NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_libhash(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    hash_types(L) ; lua_setfield(L, -2, "types") ;

    [skin registerPushNSHelper:pushHSHashObject         forClass:"HSHashObject"];
    [skin registerLuaObjectHelper:toHSHashObjectFromLua forClass:"HSHashObject"
                                             withUserdataMapping:USERDATA_TAG];

    return 1;
}
