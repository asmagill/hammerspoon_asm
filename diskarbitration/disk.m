#import "diskarbitration.h"

static const char * const USERDATA_TAG = "hs._asm.diskarbitration.disk" ;
static LSRefTable refTable = LUA_NOREF;

#define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

// These next two are *almost* identical to whats in hs._asm.axuielement and slightly extended
// versions of similar code already in Hammerspoon. LuaSkin can't handle CFObjects yet like it can
// NSObjects... I hope to address this in 2018, but until then, code repetition is necessary...
static int pushCFTypeHamster(lua_State *L, CFTypeRef theItem, NSMutableDictionary *alreadySeen) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    if (!theItem) {
        lua_pushnil(L) ;
        return 1 ;
    }
    CFTypeID theType = CFGetTypeID(theItem) ;
// These types are known to be possible by examining the DADisk.h file
    if (theType == CFBooleanGetTypeID() || theType == CFNumberGetTypeID()) {
        [skin pushNSObject:(__bridge NSNumber *)theItem] ;
    } else if (theType == CFStringGetTypeID()) {
        [skin pushNSObject:(__bridge NSString *)theItem] ;
    } else if (theType == CFDataGetTypeID()) {
        [skin pushNSObject:(__bridge NSData *)theItem] ;
    } else if (theType == CFURLGetTypeID()) {
        [skin pushNSObject:(__bridge_transfer NSString *)CFRetain(CFURLGetString(theItem))] ;
    } else if (theType == CFUUIDGetTypeID()) {
        [skin pushNSObject:(__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, theItem)] ;
    } else if (theType == CFDictionaryGetTypeID()) {
        if (alreadySeen[(__bridge id)theItem]) {
            [skin pushLuaRef:refTable ref:[alreadySeen[(__bridge id)theItem] intValue]] ;
            return 1 ;
        }
        lua_newtable(L) ;
        alreadySeen[(__bridge id)theItem] = [NSNumber numberWithInt:[skin luaRef:refTable]] ;
        [skin pushLuaRef:refTable ref:[alreadySeen[(__bridge id)theItem] intValue]] ; // put it back on the stack
        NSArray *keys = [(__bridge NSDictionary *)theItem allKeys] ;
        NSArray *values = [(__bridge NSDictionary *)theItem allValues] ;
        for (unsigned long i = 0 ; i < [keys count] ; i++) {
// NOTE: If we make this universal, disk_description will need to be re-written to take this exception into account
            CFTypeRef theKey = (__bridge CFTypeRef)[keys objectAtIndex:i] ;
            CFTypeRef theValue = (__bridge CFTypeRef)[values objectAtIndex:i] ;
            pushCFTypeHamster(L, theKey, alreadySeen) ;
            if (CFGetTypeID(theKey) == CFStringGetTypeID() && CFGetTypeID(theValue) == CFDataGetTypeID() &&
                  [(__bridge NSString *)theKey isEqualToString:(__bridge NSString *)kDADiskDescriptionDeviceGUIDKey]) {
                [LuaSkin logWarn:[NSString stringWithFormat:@"GUID:%@ == %@", (__bridge id)theKey, (__bridge id)theValue]] ;
                const CFUUIDBytes *asBytes = (const CFUUIDBytes *)CFDataGetBytePtr((CFDataRef)theValue) ;
                CFUUIDRef uuidRepresentation = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, *asBytes) ;
                pushCFTypeHamster(L, uuidRepresentation, alreadySeen) ;
                CFRelease(uuidRepresentation) ;
            } else {
                pushCFTypeHamster(L, theValue, alreadySeen) ;
            }
            lua_settable(L, -3) ;
        }
    }

// and these are just in case and because I'm hoping to make a more generic version eventually so I
// can stop replicating this code...
    else if (theType == CFNullGetTypeID()) {
        [skin pushNSObject:(__bridge NSNull *)theItem] ;
    } else if (theType == CFDateGetTypeID()) {
        [skin pushNSObject:(__bridge NSDate *)theItem] ;
    } else if (theType == CFArrayGetTypeID()) {
        if (alreadySeen[(__bridge id)theItem]) {
            [skin pushLuaRef:refTable ref:[alreadySeen[(__bridge id)theItem] intValue]] ;
            return 1 ;
        }
        lua_newtable(L) ;
        alreadySeen[(__bridge id)theItem] = [NSNumber numberWithInt:[skin luaRef:refTable]] ;
        [skin pushLuaRef:refTable ref:[alreadySeen[(__bridge id)theItem] intValue]] ; // put it back on the stack
        for(id thing in (__bridge NSArray *)theItem) {
            pushCFTypeHamster(L, (__bridge CFTypeRef)thing, alreadySeen) ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else if (theType == CFAttributedStringGetTypeID()) {
        [skin pushNSObject:(__bridge NSAttributedString *)theItem] ;
    } else {
        NSString *typeLabel = [NSString stringWithFormat:@"unrecognized type: %lu", theType] ;
        [skin logError:[NSString stringWithFormat:@"%s:CF->Lua conversion; unrecognized type %@ (%lu) detected", USERDATA_TAG, (__bridge_transfer NSString *)CFCopyTypeIDDescription(theType), theType]] ;
        lua_pushstring(L, [typeLabel UTF8String]) ;
    }
    return 1 ;
}

static int pushCFTypeToLua(lua_State *L, CFTypeRef theItem) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    NSMutableDictionary *alreadySeen = [[NSMutableDictionary alloc] init] ;
    pushCFTypeHamster(L, theItem, alreadySeen) ;
    for (id entry in alreadySeen) {
        [skin luaUnref:refTable ref:[alreadySeen[entry] intValue]] ;
    }
    return 1 ;
}

static NSString *DissenterStatusAsString(DAReturn status) {
    NSString *result = nil ;
    switch(status) {
        case kDAReturnSuccess:
            result = @"success" ;
            break ;
        case kDAReturnError:
            result = @"error" ;
            break ;
        case kDAReturnBusy:
            result = @"busy" ;
            break ;
        case kDAReturnBadArgument:
            result = @"bad argument" ;
            break ;
        case kDAReturnExclusiveAccess:
            result = @"exclusive access" ;
            break ;
        case kDAReturnNoResources:
            result = @"no resources" ;
            break ;
        case kDAReturnNotFound:
            result = @"not found" ;
            break ;
        case kDAReturnNotMounted:
            result = @"not mounted" ;
            break ;
        case kDAReturnNotPermitted:
            result = @"not permitted" ;
            break ;
        case kDAReturnNotPrivileged:
            result = @"not privileged" ;
            break ;
        case kDAReturnNotReady:
            result = @"not ready" ;
            break ;
        case kDAReturnNotWritable:
            result = @"not writable" ;
            break ;
        case kDAReturnUnsupported:
            result = @"unsupported" ;
            break ;
    }

    // try bsd errors
    if (!result) result = [NSString stringWithFormat:@"%s", strerror(err_get_code(status))] ;

    // If *that* doesn't recognize it, it should result in "Unknown error: #", but just in case...
    if (!result) result = [NSString stringWithFormat:@"unexpected dissenter status:%d", status] ;

    return result ;
}

static void disk_callback(DADiskRef disk, DADissenterRef dissenter, void *context) {
    NSDictionary *details = (__bridge_transfer NSDictionary *)context ;
    int callbackRef = [(NSNumber *)details[@"callback"] intValue] ;
    if (callbackRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L    = skin.L ;
        int       args  = 2 ;

        [skin pushLuaRef:refTable ref:callbackRef] ;
        pushDADiskRef(L, disk) ;
        lua_pushboolean(L, (dissenter == NULL)) ;
        if (dissenter) {
            args = args + 2 ;
            [skin pushNSObject:DissenterStatusAsString(DADissenterGetStatus(dissenter))] ;
            [skin pushNSObject:(__bridge NSString *)DADissenterGetStatusString(dissenter)] ;
        }
        if (![skin protectedCallAndTraceback:args nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:%@ callback error:%s", USERDATA_TAG, details[@"type"], lua_tostring(L, -1)]] ;
            lua_pop(L, 1) ;
        }
        [skin luaUnref:refTable ref:callbackRef] ;
    }
}

#pragma mark - Module Functions

static int disk_fromBSD(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString  *bsdName   = [skin toNSObjectAtIndex:1] ;
    DADiskRef diskObject = NULL ;

    if (bsdName) {
        const char *bsdNameAsCString = bsdName.UTF8String ;
        if (bsdNameAsCString) diskObject = DADiskCreateFromBSDName(kCFAllocatorDefault, arbitrationSession, bsdNameAsCString) ;
    }

    // the helper handles the case where diskObject is NULL
    pushDADiskRef(L, diskObject) ;
    if (diskObject) CFRelease(diskObject) ;
    return 1 ;
}

static int disk_fromPath(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString  *path      = [skin toNSObjectAtIndex:1] ;
    NSURL     *pathURL   = nil ;
    DADiskRef diskObject = NULL ;

    if ([path hasPrefix:@"file:"] || [path hasPrefix:@"FILE:"]) {
        pathURL = [NSURL URLWithString:path] ;
    } else {
        if (!([path hasPrefix:@"~"] || [path hasPrefix:@"/"])) path = [NSString stringWithFormat:@"/Volumes/%@", path] ;
        pathURL = [NSURL fileURLWithPath:[path stringByExpandingTildeInPath]] ;
    }

    if (pathURL) diskObject = DADiskCreateFromVolumePath(kCFAllocatorDefault, arbitrationSession, (__bridge CFURLRef) pathURL) ;

    // the helper handles the case where diskObject is NULL
    pushDADiskRef(L, diskObject) ;
    if (diskObject) CFRelease(diskObject) ;
    return 1 ;
}

#pragma mark - Disk Submodule Methods

static int disk_bsdName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    DADiskRef diskObject = get_cfobjectFromUserdata(DADiskRef, L, 1, USERDATA_TAG) ;
    lua_pushstring(L, DADiskGetBSDName(diskObject)) ;
    return 1 ;
}

static int disk_description(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    DADiskRef diskObject = get_cfobjectFromUserdata(DADiskRef, L, 1, USERDATA_TAG) ;
    CFDictionaryRef description = DADiskCopyDescription(diskObject) ;
    pushCFTypeToLua(L, description) ;
    if (description) CFRelease(description) ;
    return 1 ;
}

static int disk_wholeDisk(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    DADiskRef diskObject = get_cfobjectFromUserdata(DADiskRef, L, 1, USERDATA_TAG) ;
    DADiskRef wholeDisk = DADiskCopyWholeDisk(diskObject) ;
    pushDADiskRef(L, wholeDisk) ;
    if (wholeDisk) CFRelease(wholeDisk) ;
    return 1 ;
}

static int disk_isClaimed(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    DADiskRef diskObject = get_cfobjectFromUserdata(DADiskRef, L, 1, USERDATA_TAG) ;
    lua_pushboolean(L, DADiskIsClaimed(diskObject)) ;
    return 1 ;
}

static int disk_mount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL,
                    LS_TTABLE | LS_TOPTIONAL,  // callback required if passing in arguments
                    LS_TSTRING | LS_TOPTIONAL, // or options
                    LS_TBREAK] ;
    DADiskRef          diskObject = get_cfobjectFromUserdata(DADiskRef, L, 1, USERDATA_TAG) ;
    int                callback   = LUA_NOREF ;
    CFStringRef        *arguments = NULL ;
    DADiskMountOptions options    = kDADiskMountOptionDefault ;

    if (lua_gettop(L) > 1 && !lua_isnil(L, 2)) {
        lua_pushvalue(L, 2) ;
        callback = [skin luaRef:refTable] ;
    }

    NSArray *args ; // if set, needs to persist through call to DADiskMountWithArguments
    if (lua_gettop(L) > 2) {
        args = [skin toNSObjectAtIndex:3] ;
        NSString __block *argsError = nil ;
        if ([args isKindOfClass:[NSArray class]]) {
            [args enumerateObjectsUsingBlock:^(NSString *entry, NSUInteger idx, BOOL *stop) {
                if (![entry isKindOfClass:[NSString class]]) {
                    argsError = [NSString stringWithFormat:@"expect string at index position %lu", idx + 1] ;
                    *stop = YES ;
                }
            }] ;
        } else {
            argsError = @"expected an array of strings" ;
        }
        if (argsError) return luaL_argerror(L, 3, argsError.UTF8String) ;

        arguments = calloc(args.count + 1, sizeof(CFStringRef));
        CFArrayGetValues((__bridge CFArrayRef)args, CFRangeMake(0, (CFIndex)args.count), (const void **)arguments) ;
    }

    int lastIdx = lua_gettop(L) ;
    if (lua_type(L, lastIdx) == LUA_TSTRING) {
        NSString *optionString = [skin toNSObjectAtIndex:lastIdx] ;
        if ([optionString isEqualToString:@"disk"]) {
            options = kDADiskMountOptionWhole ;
        } else {
            return luaL_argerror(L, lastIdx, "must be \"disk\" if argument is supplied") ;
        }
    }

    void *context = (__bridge_retained void*)@{ @"callback" : @(callback), @"type" : @"mount" } ;
    if (arguments) {
        DADiskMountWithArguments(diskObject, NULL, options, disk_callback, context, arguments) ;
        free(arguments) ;
    } else {
        DADiskMount(diskObject, NULL, options, disk_callback, context) ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int disk_unmount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL,
                    LS_TSTRING | LS_TOPTIONAL,    // callback required if passing in options
                    LS_TBREAK] ;
    DADiskRef            diskObject = get_cfobjectFromUserdata(DADiskRef, L, 1, USERDATA_TAG) ;
    int                  callback   = LUA_NOREF ;
    DADiskUnmountOptions options    = kDADiskUnmountOptionDefault ;
    if (lua_gettop(L) > 1 && !lua_isnil(L, 2)) {
        lua_pushvalue(L, 2) ;
        callback = [skin luaRef:refTable] ;
    }
    if (lua_gettop(L) > 2) {
        NSString *optionString = [skin toNSObjectAtIndex:3] ;
        if ([optionString isEqualToString:@"force"]) {
            options = kDADiskUnmountOptionForce ;
        } else if ([optionString isEqualToString:@"disk"]) {
            options = kDADiskUnmountOptionWhole ;
        } else if ([optionString isEqualToString:@"forceDisk"]) {
            options = kDADiskUnmountOptionForce | kDADiskUnmountOptionWhole ;
        } else {
            return luaL_argerror(L, 3, "must be one of \"force\", \"disk\", or \"forceDisk\" if argument is supplied") ;
        }
    }

    void *context = (__bridge_retained void*)@{ @"callback" : @(callback), @"type" : @"unmount" } ;
    DADiskUnmount(diskObject, options, disk_callback, context) ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int disk_eject(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL,
                    LS_TBREAK] ;
    DADiskRef          diskObject = get_cfobjectFromUserdata(DADiskRef, L, 1, USERDATA_TAG) ;
    int                callback   = LUA_NOREF ;
    DADiskEjectOptions options    = kDADiskEjectOptionDefault ;
    if (lua_gettop(L) > 1 && !lua_isnil(L, 2)) {
        lua_pushvalue(L, 2) ;
        callback = [skin luaRef:refTable] ;
    }

    void *context = (__bridge_retained void*)@{ @"callback" : @(callback), @"type" : @"eject" } ;
    DADiskEject(diskObject, options, disk_callback, context) ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int disk_ioServiceID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    DADiskRef diskObject = get_cfobjectFromUserdata(DADiskRef, L, 1, USERDATA_TAG) ;
    io_service_t diskService = DADiskCopyIOMedia(diskObject) ;
    uint64_t entryID ;
    kern_return_t err = IORegistryEntryGetRegistryEntryID(diskService, &entryID) ;
    if (err == KERN_SUCCESS) {
        lua_pushinteger(L, (lua_Integer)entryID) ;
        IOObjectRelease(diskService) ;
    } else {
        [LuaSkin logDebug:[NSString stringWithFormat:@"%s:ioServiceID -- unable to retrieve IOObject entryID (Kernel Error #%d)", USERDATA_TAG, err]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - CFObject->Lua Conversion Functions

int pushDADiskRef(lua_State *L, DADiskRef disk) {
    if (disk && CFGetTypeID(disk) == DADiskGetTypeID()) {
        DADiskRef *thePtr = lua_newuserdata(L, sizeof(disk)) ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincompatible-pointer-types-discards-qualifiers"
// CFRetain returns CFTypeRef (aka 'const void *'), while CFHostRef (aka 'struct __DADisk *'),
// a noticeably non-constant type...
// Probably an oversite on Apple's part since other CF type refs don't trigger a warning.
        *thePtr = CFRetain(disk) ;
#pragma clang diagnostic pop
        luaL_getmetatable(L, USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
        return 1 ;
    } else if (disk) {
        [[LuaSkin sharedWithState:L] logError:[NSString stringWithFormat:@"%s:pushDADiskRef expected DADiskRef object, found %@ (%lu)", USERDATA_TAG, (__bridge_transfer NSString *)CFCopyTypeIDDescription(CFGetTypeID(disk)), CFGetTypeID(disk)]] ;
    }
    lua_pushnil(L) ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    DADiskRef diskObject = get_cfobjectFromUserdata(DADiskRef, L, 1, USERDATA_TAG) ;
    const char *title = DADiskGetBSDName(diskObject) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %s (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        DADiskRef diskObject1 = get_cfobjectFromUserdata(DADiskRef, L, 1, USERDATA_TAG) ;
        DADiskRef diskObject2 = get_cfobjectFromUserdata(DADiskRef, L, 2, USERDATA_TAG) ;
        lua_pushboolean(L, CFEqual(diskObject1, diskObject2)) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    DADiskRef diskObject = get_cfobjectFromUserdata(DADiskRef, L, 1, USERDATA_TAG) ;
    if (diskObject) CFRelease(diskObject) ;

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"bsdName",     disk_bsdName},
    {"description", disk_description},
    {"parent",      disk_wholeDisk},
    {"isClaimed",   disk_isClaimed},
    {"unmount",     disk_unmount},
    {"eject",       disk_eject},
    {"mount",       disk_mount},
    {"ioServiceID", disk_ioServiceID},

    {"__tostring",  userdata_tostring},
    {"__eq",        userdata_eq},
    {"__gc",        userdata_gc},
    {NULL,          NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"fromDevice", disk_fromBSD},
    {"fromPath",   disk_fromPath},
    {NULL,         NULL}
};

int luaopen_hs__asm_diskarbitration_disk(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:NULL
                               objectFunctions:userdata_metaLib];

    return 1;
}
