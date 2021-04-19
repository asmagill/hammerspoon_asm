#import "diskarbitration.h"

static const char * const USERDATA_TAG = "hs._asm.diskarbitration" ;
static LSRefTable refTable = LUA_NOREF;

DASessionRef arbitrationSession = NULL ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

typedef NS_OPTIONS(NSUInteger, ASMdiskArbitrationType) {
    diskAppeared           = 1 << 0,
    diskDescriptionChanged = 1 << 1,
    diskDisappeared        = 1 << 2,
    diskEjectApproval      = 1 << 3,
    diskMountApproval      = 1 << 4,
    diskUnmountApproval    = 1 << 5,
//     diskPeek               = 1 << 6,
} ;

static NSDictionary *diskarbitrationTypeLabels = nil ;

@interface ASMdiskArbitrationWatcher : NSObject
@property int                    callbackRef ;
@property int                    selfRefCount ;
@property (readonly) BOOL        active ;
@property NSDictionary           *matching ;
@property NSArray                *watching ;
@property ASMdiskArbitrationType types ;
@end

static void commonCallbackNoResponseExpected(NSString *label, DADiskRef disk, CFArrayRef keys, void *context) {
    LuaSkin                   *skin = [LuaSkin sharedWithState:NULL] ;
    lua_State                 *L    = skin.L ;
    ASMdiskArbitrationWatcher *self = (__bridge ASMdiskArbitrationWatcher *)context ;
    int                       args  = keys ? 4 : 3 ;

    if (self.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:self.callbackRef] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:label] ;
        pushDADiskRef(L, disk) ;
        if (keys) [skin pushNSObject:(__bridge NSArray *)keys] ;
        if (![skin protectedCallAndTraceback:args nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:%@ - callback error:%s", USERDATA_TAG, label, lua_tostring(L, -1)]] ;
            lua_pop(L, 1) ;
        }
    }
}

static void diskAppearedCallback(DADiskRef disk, void *context) {
    commonCallbackNoResponseExpected(@"appeared", disk, NULL, context) ;
}

static void diskDescriptionChangedCallback(DADiskRef disk, CFArrayRef keys, void *context) {
    commonCallbackNoResponseExpected(@"descriptionChanged", disk, keys, context) ;
}

static void diskDisappearedCallback(DADiskRef disk, void *context) {
    commonCallbackNoResponseExpected(@"disappeared", disk, NULL, context) ;
}

static DADissenterRef commonCallbackWithDissenter(NSString *label, DADiskRef disk, void *context) {
    DADissenterRef            response = NULL ;
    LuaSkin                   *skin    = [LuaSkin sharedWithState:NULL] ;
    lua_State                 *L       = skin.L ;
    ASMdiskArbitrationWatcher *self    = (__bridge ASMdiskArbitrationWatcher *)context ;
    if (self.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:self.callbackRef] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:label] ;
        pushDADiskRef(L, disk) ;
        if ([skin protectedCallAndTraceback:3 nresults:1]) {
            if (lua_type(L, -1) == LUA_TSTRING) {
                response = DADissenterCreate(kCFAllocatorDefault, kDAReturnNotPermitted, (__bridge CFStringRef)[skin toNSObjectAtIndex:-1]) ;
            } else if (lua_isboolean(L, -1)) {
                // if true, leave the dissenter undefined -- it means we approve
                if (!lua_toboolean(L, -1)) {
                    response = DADissenterCreate(kCFAllocatorDefault, kDAReturnNotPermitted, NULL) ;
                }
            } else if (!lua_isnil(L, -1)) {
                [skin logError:[NSString stringWithFormat:@"%s:%@ - callback error:string, boolean, or nil response expected; implicitly approving", USERDATA_TAG, label]] ;
            }
        } else {
            [skin logError:[NSString stringWithFormat:@"%s:%@ - callback error:%s; implicitly approving", USERDATA_TAG, label, lua_tostring(L, -1)]] ;
        }
        lua_pop(L, 1) ;
    }
    return response ;
}

static DADissenterRef diskEjectApprovalCallback(DADiskRef disk, void *context) {
    return commonCallbackWithDissenter(@"ejectApproval", disk, context) ;
}

static DADissenterRef diskMountApprovalCallback(DADiskRef disk, void *context) {
    return commonCallbackWithDissenter(@"mountApproval", disk, context) ;
}

static DADissenterRef diskUnmountApprovalCallback(DADiskRef disk, void *context) {
    return commonCallbackWithDissenter(@"unmountApproval", disk, context) ;
}

// Requires the ability to claim and unclaim whole disk objects... think iTunes and disk writing... not
// something Hammerspoon can do right now (maybe ever without elevated privileges?)
// static void diskPeekCallback(DADiskRef disk, void *context) {
// }

static CFDictionaryRef CreateDiskArbitrationCFDictionary(NSDictionary *match) {
    CFMutableDictionaryRef results = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks) ;

    [match enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSObject *obj, __unused BOOL *stop) {
        if ([key isEqualToString:(__bridge NSString *)kDADiskDescriptionDeviceInternalKey] ||
              [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaEjectableKey] ||
              [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaLeafKey] ||
              [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaRemovableKey] ||
              [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaWholeKey] ||
              [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaWritableKey] ||
              [key isEqualToString:(__bridge NSString *)kDADiskDescriptionVolumeMountableKey] ||
              [key isEqualToString:(__bridge NSString *)kDADiskDescriptionVolumeNetworkKey]) {
            CFBooleanRef value = [(NSNumber *)obj boolValue] ? kCFBooleanTrue : kCFBooleanFalse ;
            CFDictionarySetValue(results, (__bridge CFStringRef)key, value) ;
        } else if ([key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaUUIDKey] ||
                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionVolumeUUIDKey]) {
            CFUUIDRef value = CFUUIDCreateFromString(kCFAllocatorDefault,(__bridge CFStringRef)((NSString *)obj)) ;
            CFDictionarySetValue(results, (__bridge CFStringRef)key, value) ;
            CFRelease(value) ;
        } else if ([key isEqualToString:(__bridge NSString *)kDADiskDescriptionDeviceGUIDKey]) {
            CFUUIDRef   value   = CFUUIDCreateFromString(kCFAllocatorDefault,(__bridge CFStringRef)((NSString *)obj)) ;
            CFUUIDBytes asBytes = CFUUIDGetUUIDBytes(value) ;
            CFDataRef   asData  = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (uint8_t *)&asBytes, 16, kCFAllocatorNull) ;
            CFDictionarySetValue(results, (__bridge CFStringRef)key, asData) ;
            CFRelease(asData) ;
            CFRelease(value) ;
        } else if ([key isEqualToString:(__bridge NSString *)kDADiskDescriptionVolumePathKey]) {
            NSString  *path  = (NSString *)obj ;
            NSURL     *value = nil ;
            if ([path hasPrefix:@"file:"] || [path hasPrefix:@"FILE:"]) {
                value = [NSURL URLWithString:path] ;
            } else {
                if (!([path hasPrefix:@"~"] || [path hasPrefix:@"/"])) path = [NSString stringWithFormat:@"/Volumes/%@", path] ;
                value = [NSURL fileURLWithPath:[path stringByExpandingTildeInPath]] ;
            }
            CFDictionarySetValue(results, (__bridge CFStringRef)key, (__bridge CFURLRef)value) ;
        } else {
            CFDictionarySetValue(results, (__bridge CFStringRef)key, (__bridge CFTypeRef)obj) ;
        }
    }] ;

    CFDictionaryRef resultToReturn = CFDictionaryCreateCopy(kCFAllocatorDefault, results) ;
    CFRelease(results) ;
    return resultToReturn ;
}

@implementation ASMdiskArbitrationWatcher
- (instancetype)init {
    self = [super init] ;
    if (self) {
        _callbackRef  = LUA_NOREF ;
        _selfRefCount = 0 ;
        _active       = NO ;
        _types        = 0 ;
        _matching     = [[NSDictionary alloc] init] ;
        _watching     = [[NSArray alloc] init] ;
    }
    return self ;
}

- (void)registerCallbacks {
    if (_active) return ;

    CFDictionaryRef match = NULL ;
    if (_matching.count > 0) match = CreateDiskArbitrationCFDictionary(_matching) ;

    CFArrayRef      watch = (_watching.count > 0) ? (__bridge CFArrayRef)_watching : NULL ;

    if ((_types & diskAppeared) == diskAppeared) {
        DARegisterDiskAppearedCallback(arbitrationSession, match, diskAppearedCallback, (__bridge void *)self) ;
    }
    if ((_types & diskDescriptionChanged) == diskDescriptionChanged) {
        DARegisterDiskDescriptionChangedCallback(arbitrationSession, match, watch, diskDescriptionChangedCallback, (__bridge void *)self) ;
    }
    if ((_types & diskDisappeared) == diskDisappeared) {
        DARegisterDiskDisappearedCallback(arbitrationSession, match, diskDisappearedCallback, (__bridge void *)self) ;
    }
    if ((_types & diskEjectApproval) == diskEjectApproval) {
        DARegisterDiskEjectApprovalCallback(arbitrationSession, match, diskEjectApprovalCallback, (__bridge void *)self) ;
    }
    if ((_types & diskMountApproval) == diskMountApproval) {
        DARegisterDiskMountApprovalCallback(arbitrationSession, match, diskMountApprovalCallback, (__bridge void *)self) ;
    }
    if ((_types & diskUnmountApproval) == diskUnmountApproval) {
        DARegisterDiskUnmountApprovalCallback(arbitrationSession, match, diskUnmountApprovalCallback, (__bridge void *)self) ;
    }

// we're *not* transferring ownership or increasing the retain count, so we don't need to release this... I think...
// will need to figure out a way to test that theory...
//     if (watch) CFRelease(watch) ;

    if (match) CFRelease(match) ;
    watch   = NULL ;
    match   = NULL ;
    _active = YES ;
}

- (void)unregisterCallbacks {
    if (!_active) return ;

    if (arbitrationSession) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpedantic"
        if ((_types & diskAppeared) == diskAppeared) {
            DAUnregisterCallback(arbitrationSession, diskAppearedCallback, (__bridge void *)self) ;
        }
        if ((_types & diskDescriptionChanged) == diskDescriptionChanged) {
            DAUnregisterCallback(arbitrationSession, diskDescriptionChangedCallback, (__bridge void *)self) ;
        }
        if ((_types & diskDisappeared) == diskDisappeared) {
            DAUnregisterCallback(arbitrationSession, diskDisappearedCallback, (__bridge void *)self) ;
        }
        if ((_types & diskEjectApproval) == diskEjectApproval) {
            DAUnregisterApprovalCallback(arbitrationSession, diskEjectApprovalCallback, (__bridge void *)self) ;
        }
        if ((_types & diskMountApproval) == diskMountApproval) {
            DAUnregisterApprovalCallback(arbitrationSession, diskMountApprovalCallback, (__bridge void *)self) ;
        }
        if ((_types & diskUnmountApproval) == diskUnmountApproval) {
            DAUnregisterApprovalCallback(arbitrationSession, diskUnmountApprovalCallback, (__bridge void *)self) ;
        }
#pragma clang diagnostic pop

        _active = NO ;
    } else {
        // if this happens and causes a crash, make sure something is logged
        // currently breadcrumb is the only way to ensure it makes it into Crashlytics
        [LuaSkin logBreadcrumb:[NSString stringWithFormat:@"%s:unregisterCallbacks called after arbitrationSession released; this shouldn't happen -- it means that the module was garbage collected before the userdata instances were.", USERDATA_TAG]] ;
        // but if it by some miracle *doesn't* crash immediately, I'd still like to see it
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:unregisterCallbacks called after arbitrationSession released; this shouldn't happen -- it means that the module was garbage collected before the userdata instances were.", USERDATA_TAG]] ;
    }
}

@end

#pragma mark - Module Functions

static int diskarbitration_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    ASMdiskArbitrationWatcher *watcher = [[ASMdiskArbitrationWatcher alloc] init] ;
    if (watcher) {
        [skin pushNSObject:watcher] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int diskarbitration_descriptionKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMdiskArbitrationWatcher *watcher = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:watcher.watching] ;
    } else {
        if (!watcher.active) {
            NSArray *descriptionKeysArray = [skin toNSObjectAtIndex:2] ;
            __block NSString *errorMsg = nil ;
            if ([descriptionKeysArray isKindOfClass:[NSArray class]]) {
                [descriptionKeysArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
                    if (![key isKindOfClass:[NSString class]]) {
                        errorMsg = [NSString stringWithFormat:@"expected string at index position %lu", idx + 1] ;
                        *stop = YES ;
                    }
                }] ;
            } else {
                errorMsg = @"expected an array of strings" ;
            }
            if (errorMsg) {
                return luaL_error(L, errorMsg.UTF8String) ;
            }
            watcher.watching = descriptionKeysArray ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "descriptionKeys can only be modified when the watcher is inactive") ;
        }
    }
    return 1 ;
}

static int diskarbitration_matchCriteria(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMdiskArbitrationWatcher *watcher = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:watcher.matching] ;
    } else {
        if (!watcher.active) {
            NSDictionary *criteriaDictionary = [skin toNSObjectAtIndex:2] ;
            __block NSString *errorMsg = nil ;
            if ([criteriaDictionary isKindOfClass:[NSDictionary class]]) {
                [criteriaDictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSObject *obj, BOOL *stop) {
                    if ([key isKindOfClass:[NSString class]]) {
                        if ([key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaUUIDKey] ||
                            [key isEqualToString:(__bridge NSString *)kDADiskDescriptionDeviceGUIDKey] ||
                            [key isEqualToString:(__bridge NSString *)kDADiskDescriptionVolumeUUIDKey]) {
                            NSUUID *value = nil ;
                            if ([obj isKindOfClass:[NSString class]]) value = [[NSUUID alloc] initWithUUIDString:(NSString *)obj] ;
                            if (!value) {
                                errorMsg = [NSString stringWithFormat:@"%@ requires a string representing a valid UUID as its value", key] ;
                            }
//                         } else if ([key isEqualToString:(__bridge NSString *)kDADiskDescriptionDeviceGUIDKey]) {
//                             if (!([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSData class]])) {
//                                 errorMsg = [NSString stringWithFormat:@"%@ requires a string representing binary data as its value", key] ;
//                             }
                        } else if ([key isEqualToString:(__bridge NSString *)kDADiskDescriptionVolumePathKey]) {
                            NSURL *value = nil ;
                            if ([obj isKindOfClass:[NSString class]]) {
                                NSString  *path  = (NSString *)obj ;
                                if ([path hasPrefix:@"file:"] || [path hasPrefix:@"FILE:"]) {
                                    value = [NSURL URLWithString:path] ;
                                } else {
                                    if (!([path hasPrefix:@"~"] || [path hasPrefix:@"/"])) path = [NSString stringWithFormat:@"/Volumes/%@", path] ;
                                    value = [NSURL fileURLWithPath:[path stringByExpandingTildeInPath]] ;
                                }
                            }
                            if (!value) {
                                errorMsg = [NSString stringWithFormat:@"%@ requires a string representing a file URL or path as its value", key] ;
                            }
                        } else if ([key isEqualToString:(__bridge NSString *)kDADiskDescriptionBusNameKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionBusPathKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionDeviceModelKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionDevicePathKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionDeviceProtocolKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionDeviceRevisionKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionDeviceVendorKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaBSDNameKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaContentKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaKindKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaNameKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaPathKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaTypeKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionVolumeKindKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionVolumeNameKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionVolumeTypeKey]) {
                            if (![obj isKindOfClass:[NSString class]]) {
                                errorMsg = [NSString stringWithFormat:@"%@ requires a string as its value", key] ;
                            }
                        } else if ([key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaIconKey]) {
                            // as of right now, we don't know enough to validate the tables contents, so just check its type
                            if (![obj isKindOfClass:[NSDictionary class]]) {
                                errorMsg = [NSString stringWithFormat:@"%@ requires a table of key-value pairs as its value", key] ;
                            }
                        } else if ([key isEqualToString:(__bridge NSString *)kDADiskDescriptionDeviceUnitKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaBlockSizeKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaBSDMajorKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaBSDMinorKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaBSDUnitKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaSizeKey]) {
                            if (![obj isKindOfClass:[NSNumber class]]) {
                                errorMsg = [NSString stringWithFormat:@"%@ requires a number as its value", key] ;
                            }
                        } else if ([key isEqualToString:(__bridge NSString *)kDADiskDescriptionDeviceInternalKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaEjectableKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaLeafKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaRemovableKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaWholeKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionMediaWritableKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionVolumeMountableKey] ||
                                   [key isEqualToString:(__bridge NSString *)kDADiskDescriptionVolumeNetworkKey]) {
                            if (![obj isKindOfClass:[NSNumber class]]) {
                                errorMsg = [NSString stringWithFormat:@"%@ requires a boolean as its value", key] ;
                            }
                        // } else {
                        //     // it's a key-value pair undefined in the framework as of XCode 9.2, so we'll pass it
                        //     // along and hope for the best
                        }
                    } else {
                        errorMsg = @"keys for matchCriteria must be strings" ;
                        *stop = YES ;
                    }
                }] ;
            } else {
                errorMsg = @"expected a table of key-value pairs" ;
            }
            if (errorMsg) {
                return luaL_error(L, errorMsg.UTF8String) ;
            }
            watcher.matching = criteriaDictionary ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "matchCriteria can only be modified when the watcher is inactive") ;
        }
    }
    return 1 ;
}

static int diskarbitration_callbackFor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMdiskArbitrationWatcher *watcher = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_newtable(L) ;
        [diskarbitrationTypeLabels enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *obj, __unused BOOL *stop) {
            NSUInteger value = obj.unsignedIntegerValue ;
            if ((watcher.types & value) == value) {
                [skin pushNSObject:key] ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
        }] ;
    } else {
        if (!watcher.active) {
            NSArray *typesArray = [skin toNSObjectAtIndex:2] ;
            __block ASMdiskArbitrationType newTypes = 0 ;
            __block NSString *errorMsg = nil ;
            if ([typesArray isKindOfClass:[NSArray class]]) {
                [typesArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
                    if ([key isKindOfClass:[NSString class]]) {
                        NSNumber *value = diskarbitrationTypeLabels[key] ;
                        if (value) {
                            newTypes = newTypes | value.unsignedIntegerValue ;
                        } else {
                            errorMsg = [NSString stringWithFormat:@"unrecognized string %@ at index position %lu", key, idx + 1] ;
                            *stop = YES ;
                        }
                    } else {
                        errorMsg = [NSString stringWithFormat:@"expected string at index position %lu", idx + 1] ;
                        *stop = YES ;
                    }
                }] ;
            } else {
                errorMsg = @"expected an array of strings" ;
            }
            if (errorMsg) {
                return luaL_error(L, [[NSString stringWithFormat:@"%@; array should contain one or more of %@", errorMsg, [diskarbitrationTypeLabels.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
            }
            watcher.types = newTypes ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "callbackFor can only be modified when the watcher is inactive") ;
        }
    }
    return 1 ;
}


static int diskarbitration_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMdiskArbitrationWatcher *watcher = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        watcher.callbackRef = [skin luaUnref:refTable ref:watcher.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            watcher.callbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (watcher.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:watcher.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int diskarbitration_start(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMdiskArbitrationWatcher *watcher = [skin toNSObjectAtIndex:1] ;
    [watcher registerCallbacks] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int diskarbitration_stop(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMdiskArbitrationWatcher *watcher = [skin toNSObjectAtIndex:1] ;
    [watcher unregisterCallbacks] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int diskarbitration_isActive(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMdiskArbitrationWatcher *watcher = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, watcher.active) ;
    return 1 ;
}

#pragma mark - Module Constants

static int push_diskarbitrationKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;

    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionVolumeKindKey] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionVolumeMountableKey] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFBoolean    ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionVolumeNameKey] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionVolumeNetworkKey] ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFBoolean    ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionVolumePathKey] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFURL        ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionVolumeTypeKey] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionVolumeUUIDKey] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFUUID       ) */

    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaBlockSizeKey] ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFNumber     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaBSDMajorKey] ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFNumber     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaBSDMinorKey] ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFNumber     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaBSDNameKey] ;    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaBSDUnitKey] ;    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFNumber     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaContentKey] ;    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaEjectableKey] ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFBoolean    ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaIconKey] ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFDictionary ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaKindKey] ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaLeafKey] ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFBoolean    ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaNameKey] ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaPathKey] ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaRemovableKey] ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFBoolean    ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaSizeKey] ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFNumber     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaTypeKey] ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaUUIDKey] ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFUUID       ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaWholeKey] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFBoolean    ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionMediaWritableKey] ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFBoolean    ) */

    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionDeviceGUIDKey] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFData       ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionDeviceInternalKey] ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFBoolean    ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionDeviceModelKey] ;     lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionDevicePathKey] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionDeviceProtocolKey] ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionDeviceRevisionKey] ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionDeviceUnitKey] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFNumber     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionDeviceVendorKey] ;    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */

    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionBusNameKey] ;         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */
    [skin pushNSObject:(__bridge NSString *)kDADiskDescriptionBusPathKey] ;         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; /* ( CFString     ) */
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMdiskArbitrationWatcher(lua_State *L, id obj) {
    ASMdiskArbitrationWatcher *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMdiskArbitrationWatcher *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toASMdiskArbitrationWatcherFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    ASMdiskArbitrationWatcher *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMdiskArbitrationWatcher, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        ASMdiskArbitrationWatcher *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMdiskArbitrationWatcher"] ;
        ASMdiskArbitrationWatcher *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMdiskArbitrationWatcher"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMdiskArbitrationWatcher *obj = get_objectFromUserdata(__bridge_transfer ASMdiskArbitrationWatcher, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            if (obj.active) {
                [obj unregisterCallbacks] ;
                obj.types  = 0 ;
            }
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    if (arbitrationSession) {
        DASessionUnscheduleFromRunLoop(arbitrationSession, CFRunLoopGetCurrent(), kCFRunLoopCommonModes) ;
        CFRelease(arbitrationSession) ;
        arbitrationSession = NULL ;
    }
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"descriptionKeys", diskarbitration_descriptionKeys},
    {"matchCriteria",   diskarbitration_matchCriteria},
    {"callbackFor",     diskarbitration_callbackFor},
    {"callback",        diskarbitration_callback},
    {"start",           diskarbitration_start},
    {"stop",            diskarbitration_stop},
    {"isActive",        diskarbitration_isActive},

    {"__tostring",      userdata_tostring},
    {"__eq",            userdata_eq},
    {"__gc",            userdata_gc},
    {NULL,              NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", diskarbitration_new},
    {NULL,  NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs__asm_diskarbitration_internal(lua_State* L) {
    arbitrationSession = DASessionCreate(kCFAllocatorDefault) ;
    if (arbitrationSession) {
        DASessionScheduleWithRunLoop(arbitrationSession, CFRunLoopGetCurrent(), kCFRunLoopCommonModes) ;
    } else {
        return luaL_error(L, "%s - unable to establish session with DiskArbitration framework", USERDATA_TAG) ;
    }

    diskarbitrationTypeLabels = @{
        @"appeared"           : @(diskAppeared),
        @"descriptionChanged" : @(diskDescriptionChanged),
        @"disappeared"        : @(diskDisappeared),
        @"ejectApproval"      : @(diskEjectApproval),
        @"mountApproval"      : @(diskMountApproval),
        @"unmountApproval"    : @(diskUnmountApproval),
//         @"peek"               : @(diskPeek),
    } ;

    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    push_diskarbitrationKeys(L) ;             lua_setfield(L, -2, "keys") ;
//     [skin pushNSObject:diskarbitrationTypeLabels] ; lua_setfield(L, -2, "callbackTypes") ;

    luaopen_hs__asm_diskarbitration_disk(L) ; lua_setfield(L, -2, "disk") ;

    [skin registerPushNSHelper:pushASMdiskArbitrationWatcher         forClass:"ASMdiskArbitrationWatcher"];
    [skin registerLuaObjectHelper:toASMdiskArbitrationWatcherFromLua forClass:"ASMdiskArbitrationWatcher"
                                                          withUserdataMapping:USERDATA_TAG];

    return 1;
}
