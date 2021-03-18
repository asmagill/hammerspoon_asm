@import Cocoa ;
@import CommonCrypto.CommonDigest ;
@import CommonCrypto.CommonHMAC ;
@import LuaSkin ;

static const char *USERDATA_TAG = "hs.hash" ;

static int doHash(lua_State *L, CC_LONG length, unsigned char *(*hashFunc)(const void *, CC_LONG, unsigned char *)) {
    unsigned char digest[length + 1];
    size_t sourceLength;
    const char *source = luaL_checklstring(L, 1, &sourceLength);
    NSMutableString *conversionSink = [NSMutableString string];

    hashFunc(source, (CC_LONG)sourceLength, digest);
    digest[length] = 0;

    for (unsigned int i = 0; i < length; i++) {
        [conversionSink appendFormat:@"%02x", digest[i]];
    }

    //NSLog(@"Hashed '%s' into '%@'", source, conversionSink);

    lua_pushstring(L, [conversionSink UTF8String]);

    return 1;
}

static int doHashHMAC(lua_State *L, CCHmacAlgorithm algorithm, CC_LONG resultLength) {
    unsigned char digest[resultLength + 1];
    size_t keyLength;
    size_t dataLength;
    const char *key = luaL_checklstring(L, 1, &keyLength);
    const char *data = luaL_checklstring(L, 2, &dataLength);
    NSMutableString *conversionSink = [NSMutableString string];

    CCHmac(algorithm, key, keyLength, data, dataLength, digest);
    digest[resultLength] = 0;

    for (unsigned int i = 0; i < resultLength; i++) {
        [conversionSink appendFormat:@"%02x", digest[i]];
    }

    //NSLog(@"HMAC Hashed '%s' with key '%s' into '%@'", data, key, conversionSink);

    lua_pushstring(L, [conversionSink UTF8String]);

    return 1;
}

/// hs.hash.SHA1(data) -> string
/// Function
/// Calculates an SHA1 hash
///
/// Parameters:
///  * data - A string containing some data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_sha1(lua_State *L) {
    return doHash(L, CC_SHA1_DIGEST_LENGTH, CC_SHA1);
}

/// hs.hash.SHA256(data) -> string
/// Function
/// Calculates an SHA256 hash
///
/// Parameters:
///  * data - A string containing some data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_sha256(lua_State *L) {
    return doHash(L, CC_SHA256_DIGEST_LENGTH, CC_SHA256);
}

/// hs.hash.SHA512(data) -> string
/// Function
/// Calculates an SHA512 hash
///
/// Parameters:
///  * data - A string containing some data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_sha512(lua_State *L) {
    return doHash(L, CC_SHA512_DIGEST_LENGTH, CC_SHA512);
}

/// hs.hash.MD5(data) -> string
/// Function
/// Calculates an MD5 hash
///
/// Parameters:
///  * data - A string containing some data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_md5(lua_State *L) {
    return doHash(L, CC_MD5_DIGEST_LENGTH, CC_MD5);
}

/// hs.hash.hmacSHA1(key, data) -> string
/// Function
/// Calculates an HMAC using a key and a SHA1 hash
///
/// Parameters:
///  * key - A string containing a secret key to use
///  * data - A string containing the data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_sha1_hmac(lua_State *L) {
    return doHashHMAC(L, kCCHmacAlgSHA1, CC_SHA1_DIGEST_LENGTH);
}

/// hs.hash.hmacSHA256(key, data) -> string
/// Function
/// Calculates an HMAC using a key and a SHA256 hash
///
/// Parameters:
///  * key - A string containing a secret key to use
///  * data - A string containing the data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_sha256_hmac(lua_State *L) {
    return doHashHMAC(L, kCCHmacAlgSHA256, CC_SHA256_DIGEST_LENGTH);
}

/// hs.hash.hmacSHA512(key, data) -> string
/// Function
/// Calculates an HMAC using a key and a SHA512 hash
///
/// Parameters:
///  * key - A string containing a secret key to use
///  * data - A string containing the data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_sha512_hmac(lua_State *L) {
    return doHashHMAC(L, kCCHmacAlgSHA512, CC_SHA512_DIGEST_LENGTH);
}

/// hs.hash.hmacMD5(key, data) -> string
/// Function
/// Calculates an HMAC using a key and an MD5 hash
///
/// Parameters:
///  * key - A string containing a secret key to use
///  * data - A string containing the data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_md5_hmac(lua_State *L) {
    return doHashHMAC(L, kCCHmacAlgMD5, CC_MD5_DIGEST_LENGTH);
}

NSArray *getCompleteFileList(lua_State *L, NSString *path, BOOL subdirs, BOOL links, lua_Integer *dirCount) {
    NSFileManager *fileManager = [NSFileManager defaultManager] ;
    BOOL          isDirectory ;
    BOOL          fileExists = [fileManager fileExistsAtPath:path isDirectory:&isDirectory] ;

    // take care of the easy cases:
    if (!fileExists) {
        luaL_argerror(L, 1, "path does not specify a reachable file or directory") ;
        return nil ;
    } else if (!isDirectory) {
        return @[ path ] ;
    }

    NSMutableArray *foundPaths      = [NSMutableArray array] ;
    NSMutableArray *seenDirectories = [NSMutableArray array] ; // to prevent loops when links is true
    NSMutableArray *directories     = [NSMutableArray arrayWithObject:path] ;

    while(directories.count > 0) {
        NSString *thisDir = directories[0] ;
        (*dirCount)++ ;
        [directories removeObjectAtIndex:0] ;
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

            if (links) {
                NSNumber *isSymbolicLink = nil ;
                [fileURL getResourceValue:&isSymbolicLink forKey:NSURLIsSymbolicLinkKey error:nil] ;
                if (isSymbolicLink) {
                    NSString *newPath = filePath.stringByResolvingSymlinksInPath ;
                    if ([fileManager fileExistsAtPath:newPath]) {
                        fileURL = [NSURL fileURLWithPath:newPath] ;
                        [fileURL getResourceValue:&filePath forKey:NSURLPathKey error:nil] ;
                    } else {
                        [LuaSkin logWarn:[NSString stringWithFormat:@"hs.hash._getCompleteFileList - error resolving symbolic link %@", newPath]] ;
                        continue ;
                    }
                }
            }

            NSNumber *isRegularFile = nil ;
            [fileURL getResourceValue:&isRegularFile forKey:NSURLIsRegularFileKey error:nil] ;
            if (isRegularFile.boolValue) {
                [foundPaths addObject:filePath] ;
            } else if (subdirs) {
                NSNumber *isThisDir = nil ;
                [fileURL getResourceValue:&isThisDir forKey:NSURLIsRegularFileKey error:nil] ;
                if (isThisDir && ![seenDirectories containsObject:filePath]) [directories addObject:filePath] ;
            }
        }
    }

    // ensure consistent order
    [foundPaths sortUsingSelector:@selector(compare:)] ;

    return [foundPaths copy] ;
}

NSString *convertHashToString(unsigned char *hash, CC_LONG length) {
    NSMutableString *string = [NSMutableString stringWithCapacity:length*2] ;
    for (CC_LONG i = 0 ; i < length ; i++) [string appendFormat:@"%02x", hash[i]] ;
    return [string copy] ;
}

/// hs.hash.SHA1forPath(path, [subdirs], [links]) -> hash, dirCount, fileCount
/// Function
/// Calculates the SHA1 hash for the file or directory specified.
///
/// Paramters:
///  * `path`    - a string specifying the path to the file or directory to be hashed. If this is a symbolic link, it will be expanded but all other symbolic links encountered during a directory traversal will follow the `links` parameter described below.
///  * `subdirs` - an optional boolean, default false, specifying whether to include the files in subdirectories of the specified directory (true) or just the files in the specified directory (false). If `path` refers to a file, this parameter is ignored.
///  * `links`   - an optional boolean, default false, specifying whether symbolic links encountered during the search for files to include should be followed (true) or ignored (false). If `path` refers to a file, this parameter is ignored.
///
/// Returns:
///  * a string containing a hash value for the contents of the file or directory specified, the number of directories visited, and the number of files included in the hashed data. Returns an error if `path` is not a valid file or directory.
///
/// Notes:
///  * Directories are hashed by finding all of the files in the directory (as modified by `subdirs` and `links`), sorting them by full system path for each individual file, then feeding the contents of each file into the hashing algorithm as a contiguous stream of data.
///    * the hash string generated by `hs.hash.SHA1forPath(<path>, true, false)` is equivalent to the terminal command `find <path> -type f -print |sort |  xargs cat | shasum -a 1`.
static int hash_SHA1forPath(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *path   = [skin toNSObjectAtIndex:1] ;
    BOOL     subdirs = (lua_gettop(L) > 1) ? (BOOL)(lua_toboolean(L, 2)) : NO ;
    BOOL     links   = (lua_gettop(L) > 2) ? (BOOL)(lua_toboolean(L, 3)) : NO ;

    path = path.stringByExpandingTildeInPath.stringByResolvingSymlinksInPath ;
    lua_Integer fileCount = 0 ;
    lua_Integer dirCount  = 0 ;
    NSArray     *filePaths = getCompleteFileList(L, path, subdirs, links, &dirCount) ;

    CC_SHA1_CTX context ;
    CC_SHA1_Init(&context) ;
    for (NSString *file in filePaths) {
        NSError *error = nil ;
        NSData  *data  = [NSData dataWithContentsOfFile:file options:NSDataReadingUncached error:&error] ;
        if (!error) {
            CC_SHA1_Update(&context, data.bytes, (CC_LONG)data.length) ;
            fileCount++ ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"hs.hash.SHA1forPath - error scanning contents of %@: %@", file, error.localizedDescription]] ;
        }
    }
    unsigned char hash[CC_SHA1_DIGEST_LENGTH] ;
    CC_SHA1_Final(hash, &context) ;

    [skin pushNSObject:convertHashToString(hash, CC_SHA1_DIGEST_LENGTH)] ;
    lua_pushinteger(L, dirCount) ;
    lua_pushinteger(L, fileCount) ;
    return 3 ;
}

/// hs.hash.SHA256forPath(path, [subdirs], [links]) -> hash, dirCount, fileCount
/// Function
/// Calculates the SHA256 hash for the file or directory specified.
///
/// Paramters:
///  * `path`    - a string specifying the path to the file or directory to be hashed. If this is a symbolic link, it will be expanded but all other symbolic links encountered during a directory traversal will follow the `links` parameter described below.
///  * `subdirs` - an optional boolean, default false, specifying whether to include the files in subdirectories of the specified directory (true) or just the files in the specified directory (false). If `path` refers to a file, this parameter is ignored.
///  * `links`   - an optional boolean, default false, specifying whether symbolic links encountered during the search for files to include should be followed (true) or ignored (false). If `path` refers to a file, this parameter is ignored.
///
/// Returns:
///  * a string containing a hash value for the contents of the file or directory specified, the number of directories visited, and the number of files included in the hashed data. Returns an error if `path` is not a valid file or directory.
///
/// Notes:
///  * Directories are hashed by finding all of the files in the directory (as modified by `subdirs` and `links`), sorting them by full system path for each individual file, then feeding the contents of each file into the hashing algorithm as a contiguous stream of data.
///    * the hash string generated by `hs.hash.SHA256forPath(<path>, true, false)` is equivalent to the terminal command `find <path> -type f -print |sort |  xargs cat | shasum -a 256`.
static int hash_SHA256forPath(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *path   = [skin toNSObjectAtIndex:1] ;
    BOOL     subdirs = (lua_gettop(L) > 1) ? (BOOL)(lua_toboolean(L, 2)) : NO ;
    BOOL     links   = (lua_gettop(L) > 2) ? (BOOL)(lua_toboolean(L, 3)) : NO ;

    path = path.stringByExpandingTildeInPath.stringByResolvingSymlinksInPath ;
    lua_Integer fileCount = 0 ;
    lua_Integer dirCount  = 0 ;
    NSArray     *filePaths = getCompleteFileList(L, path, subdirs, links, &dirCount) ;

    CC_SHA256_CTX context ;
    CC_SHA256_Init(&context) ;
    for (NSString *file in filePaths) {
        NSError *error = nil ;
        NSData  *data  = [NSData dataWithContentsOfFile:file options:NSDataReadingUncached error:&error] ;
        if (!error) {
            CC_SHA256_Update(&context, data.bytes, (CC_LONG)data.length) ;
            fileCount++ ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"hs.hash.SHA256forPath - error scanning contents of %@: %@", file, error.localizedDescription]] ;
        }
    }
    unsigned char hash[CC_SHA256_DIGEST_LENGTH] ;
    CC_SHA256_Final(hash, &context) ;

    [skin pushNSObject:convertHashToString(hash, CC_SHA256_DIGEST_LENGTH)] ;
    lua_pushinteger(L, dirCount) ;
    lua_pushinteger(L, fileCount) ;
    return 3 ;
}

/// hs.hash.SHA512forPath(path, [subdirs], [links]) -> hash, dirCount, fileCount
/// Function
/// Calculates the SHA512 hash for the file or directory specified.
///
/// Paramters:
///  * `path`    - a string specifying the path to the file or directory to be hashed. If this is a symbolic link, it will be expanded but all other symbolic links encountered during a directory traversal will follow the `links` parameter described below.
///  * `subdirs` - an optional boolean, default false, specifying whether to include the files in subdirectories of the specified directory (true) or just the files in the specified directory (false). If `path` refers to a file, this parameter is ignored.
///  * `links`   - an optional boolean, default false, specifying whether symbolic links encountered during the search for files to include should be followed (true) or ignored (false). If `path` refers to a file, this parameter is ignored.
///
/// Returns:
///  * a string containing a hash value for the contents of the file or directory specified, the number of directories visited, and the number of files included in the hashed data. Returns an error if `path` is not a valid file or directory.
///
/// Notes:
///  * Directories are hashed by finding all of the files in the directory (as modified by `subdirs` and `links`), sorting them by full system path for each individual file, then feeding the contents of each file into the hashing algorithm as a contiguous stream of data.
///    * the hash string generated by `hs.hash.SHA512forPath(<path>, true, false)` is equivalent to the terminal command `find <path> -type f -print |sort |  xargs cat | shasum -a 512`.
static int hash_SHA512forPath(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *path   = [skin toNSObjectAtIndex:1] ;
    BOOL     subdirs = (lua_gettop(L) > 1) ? (BOOL)(lua_toboolean(L, 2)) : NO ;
    BOOL     links   = (lua_gettop(L) > 2) ? (BOOL)(lua_toboolean(L, 3)) : NO ;

    path = path.stringByExpandingTildeInPath.stringByResolvingSymlinksInPath ;
    lua_Integer fileCount = 0 ;
    lua_Integer dirCount  = 0 ;
    NSArray     *filePaths = getCompleteFileList(L, path, subdirs, links, &dirCount) ;

    CC_SHA512_CTX context ;
    CC_SHA512_Init(&context) ;
    for (NSString *file in filePaths) {
        NSError *error = nil ;
        NSData  *data  = [NSData dataWithContentsOfFile:file options:NSDataReadingUncached error:&error] ;
        if (!error) {
            CC_SHA512_Update(&context, data.bytes, (CC_LONG)data.length) ;
            fileCount++ ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"hs.hash.SHA512forPath - error scanning contents of %@: %@", file, error.localizedDescription]] ;
        }
    }
    unsigned char hash[CC_SHA512_DIGEST_LENGTH] ;
    CC_SHA512_Final(hash, &context) ;

    [skin pushNSObject:convertHashToString(hash, CC_SHA512_DIGEST_LENGTH)] ;
    lua_pushinteger(L, dirCount) ;
    lua_pushinteger(L, fileCount) ;
    return 3 ;
}

static const luaL_Reg hashlib[] = {
    {"SHA1", hash_sha1},
    {"SHA256", hash_sha256},
    {"SHA512", hash_sha512},
    {"MD5", hash_md5},

    {"SHA1forPath",   hash_SHA1forPath},
    {"SHA256forPath", hash_SHA256forPath},
    {"SHA512forPath", hash_SHA512forPath},
//     {"MD5forPath",    hash_MD5forPath},

    {"hmacSHA1", hash_sha1_hmac},
    {"hmacSHA256", hash_sha256_hmac},
    {"hmacSHA512", hash_sha512_hmac},
    {"hmacMD5", hash_md5_hmac},

//     {"hmacSHA1forPath",   hash_hmacSHA1forPath},
//     {"hmacSHA256forPath", hash_hmacSHA256forPath},
//     {"hmacSHA512forPath", hash_hmacSHA512forPath},
//     {"hmacMD5forPath",    hash_hmacMD5forPath},

    {NULL, NULL}
};

/* NOTE: The substring "hs_hash_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.hash.internal". */

int luaopen_hs_hash_internal(lua_State *L) {
    // Table for luaopen
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:USERDATA_TAG functions:hashlib metaFunctions:nil];

    return 1;
}
