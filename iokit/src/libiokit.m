// probable
//  +  IORegistryEntryCreateIterator
//   ?   with callback to determine inclusion and recursion?
//           i.e. IORegistryIteratorEnterEntry and IORegistryIteratorExitEntry
//
//     Something to do with notifications, not sure what yet
//
//     Connect & IOServiceOpen/Close? not sure...
//
//     IOKit sub classes? (e.g. USB, HID, etc.)

@import Cocoa ;
@import LuaSkin ;
@import IOKit ;

static const char * const USERDATA_TAG = "hs._asm.iokit" ;
static LSRefTable         refTable     = LUA_NOREF ;

#import "iokit_error.h" // needs USERDATA_TAG defined

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSASM_IOobject : NSObject
@property int         selfRefCount ;
@property io_object_t object ;
@end

@implementation HSASM_IOobject

- (instancetype)initWithObjet:(io_object_t)object {
    self = [super init] ;
    if (self) {
        _selfRefCount = 0 ;
        _object       = object ;
        kern_return_t err = IOObjectRetain(_object) ;
        if (err != KERN_SUCCESS) {
            logError(NO, "initWithObject", err, @"unable to retain IOObject") ;
            self = nil ;
        }
    }
    return self ;
}

- (void)dealloc {
    kern_return_t err = IOObjectRelease(_object) ;
    if (err != KERN_SUCCESS) logError(NO, "dealloc", err, @"unable to release IOObject") ;
    _object = 0 ;
}

@end

#pragma mark - Module Functions -

static int iokit_rootEntry(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    io_object_t root = IORegistryGetRootEntry(kIOMasterPortDefault) ;
    if (root != MACH_PORT_NULL) {
        [skin pushNSObject:[[HSASM_IOobject alloc] initWithObjet:root]] ;
        kern_return_t err = IOObjectRelease(root) ;
        if (err != KERN_SUCCESS) logError(YES, "root", err, @"unable to release IOObject") ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_serviceFromPath(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    io_string_t path ;
    strncpy(path, lua_tostring(L, 1), sizeof(io_string_t)) ;
    io_object_t obj = IORegistryEntryFromPath(kIOMasterPortDefault, path) ;
    if (obj) {
        [skin pushNSObject:[[HSASM_IOobject alloc] initWithObjet:obj]] ;
        kern_return_t err = IOObjectRelease(obj) ;
        if (err != KERN_SUCCESS) logError(YES, "serviceForPath", err, @"unable to release IOObject") ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_serviceMatching(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    NSDictionary *matchCriteria = [skin toNSObjectAtIndex:1] ;
    if ([matchCriteria isKindOfClass:[NSDictionary class]]) {
        // IOServiceGetMatchingService consumes a CFReference, so transfer it out of ARC
        io_object_t obj = IOServiceGetMatchingService(kIOMasterPortDefault, (__bridge_retained CFDictionaryRef)matchCriteria) ;
        if (obj) {
            [skin pushNSObject:[[HSASM_IOobject alloc] initWithObjet:obj]] ;
            kern_return_t err = IOObjectRelease(obj) ;
            if (err != KERN_SUCCESS) {
                logError(YES, "serviceMatching", err, @"unable to release IOObject") ;
            }
        } else {
            lua_pushnil(L) ;
        }
    } else {
        return luaL_argerror(L, 1, "expected table of key-value pairs") ;
    }
    return 1 ;
}

static int iokit_servicesMatching(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    NSDictionary *matchCriteria = [skin toNSObjectAtIndex:1] ;
    if ([matchCriteria isKindOfClass:[NSDictionary class]]) {
        io_iterator_t iterator = 0 ;
        // IOServiceGetMatchingServices consumes a CFReference, so transfer it out of ARC
        kern_return_t err = IOServiceGetMatchingServices(kIOMasterPortDefault, (__bridge_retained CFDictionaryRef)matchCriteria, &iterator) ;
        if (err == KERN_SUCCESS) {
            lua_newtable(L) ;
            io_object_t entry = 0 ;
            while ((entry = IOIteratorNext(iterator))) {
                [skin pushNSObject:[[HSASM_IOobject alloc] initWithObjet:entry]] ;
                err = IOObjectRelease(entry) ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
                if (err != KERN_SUCCESS) {
                    logError(YES, "servicesMatching", err, [NSString stringWithFormat:@"unable to release entry %lld", luaL_len(L, -2)]) ;
                }
            }
            err = IOObjectRelease(iterator) ;
            if (err != KERN_SUCCESS) {
                logError(YES, "servicesMatching", err, @"unable to release iterator") ;
            }
        } else {
            logError(YES, "servicesMatching", err, @"unable to get iterator") ;
            lua_pushnil(L) ;
        }
    } else {
        return luaL_argerror(L, 1, "expected table of key-value pairs") ;
    }
    return 1 ;
}

static int iokit_matchingName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    CFDictionaryRef matchingDict = IOServiceNameMatching(lua_tostring(L, 1)) ;
    if (matchingDict) {
        [skin pushNSObject:(__bridge_transfer NSMutableDictionary *)matchingDict] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_matchingClass(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    CFDictionaryRef matchingDict = IOServiceMatching(lua_tostring(L, 1)) ;
    if (matchingDict) {
        [skin pushNSObject:(__bridge_transfer NSMutableDictionary *)matchingDict] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_matchingEntryID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    uint64_t entryID = (uint64_t)lua_tointeger(L, 1) ;
    CFDictionaryRef matchingDict = IORegistryEntryIDMatching(entryID) ;
    if (matchingDict) {
        [skin pushNSObject:(__bridge_transfer NSMutableDictionary *)matchingDict] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_matchingBSDName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    CFDictionaryRef matchingDict = IOBSDNameMatching(kIOMasterPortDefault, kNilOptions, lua_tostring(L, 1)) ;
    if (matchingDict) {
        [skin pushNSObject:(__bridge_transfer NSMutableDictionary *)matchingDict] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_bundleIdentifierForClass(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *className = [skin toNSObjectAtIndex:1] ;
    CFStringRef bundle = IOObjectCopyBundleIdentifierForClass((__bridge CFStringRef)className) ;
    if (bundle) {
        [skin pushNSObject:(__bridge_transfer NSString *)bundle] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_superclassForClass(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *className = [skin toNSObjectAtIndex:1] ;
    CFStringRef superclass = IOObjectCopySuperclassForClass((__bridge CFStringRef)className) ;
    if (superclass) {
        [skin pushNSObject:(__bridge_transfer NSString *)superclass] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int iokit_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASM_IOobject *obj = [skin toNSObjectAtIndex:1] ;

    io_name_t deviceName ;
    kern_return_t err = IORegistryEntryGetName(obj.object, deviceName) ;
    if (err == KERN_SUCCESS) {
        lua_pushstring(L, deviceName) ;
    } else {
        logError(YES, "name", err, @"unable to retrieve IOObject name") ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_class(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASM_IOobject *obj = [skin toNSObjectAtIndex:1] ;

    io_name_t className ;
    kern_return_t err = IOObjectGetClass(obj.object, className) ;
    if (err == KERN_SUCCESS) {
        lua_pushstring(L, className) ;
    } else {
        logError(YES, "class", err, @"unable to retrieve IOObject class") ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_conformsTo(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    HSASM_IOobject *obj = [skin toNSObjectAtIndex:1] ;

    io_name_t conformingClass ;
    strncpy(conformingClass, lua_tostring(L, 2), sizeof(io_name_t)) ;

    boolean_t conforms = IOObjectConformsTo(obj.object, conformingClass) ;
    lua_pushboolean(L, conforms ? true : false) ;
    return 1 ;
}

static int iokit_registryEntryID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASM_IOobject *obj   = [skin toNSObjectAtIndex:1] ;

    uint64_t entryID ;
    kern_return_t err = IORegistryEntryGetRegistryEntryID(obj.object, &entryID) ;
    if (err == KERN_SUCCESS) {
        lua_pushinteger(L, (lua_Integer)entryID) ;
    } else {
        logError(YES, "registryID", err, @"unable to retrieve IOObject registryID") ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_properties(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASM_IOobject *obj                   = [skin toNSObjectAtIndex:1] ;
    BOOL           includeNonSerializable = (lua_gettop(L) > 1) ? (BOOL)(lua_toboolean(L, 2)) : NO ;

    CFMutableDictionaryRef propertiesDict ;
    kern_return_t err = IORegistryEntryCreateCFProperties(obj.object, &propertiesDict, kCFAllocatorDefault, kNilOptions) ;
    if (err == KERN_SUCCESS) {
        lua_newtable(L) ;
        if (propertiesDict) {
            NSDictionary *properties = (__bridge_transfer NSDictionary *)propertiesDict ;
            [properties enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, __unused BOOL *stop) {
                // don't bother with properties we can't represent unless asked
                if (includeNonSerializable || !([(NSObject *)value isKindOfClass:[NSString class]] && [(NSString *)value hasSuffix:@" is not serializable"])) {
                    [skin pushNSObject:value withOptions:LS_NSDescribeUnknownTypes] ;
                    lua_setfield(L, -2, key.UTF8String) ;
                }
            }] ;
        }
    } else {
        logError(YES, "properties", err, @"unable to retrieve IOObject properties") ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_propertyNames(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASM_IOobject *obj = [skin toNSObjectAtIndex:1] ;

    CFMutableDictionaryRef propertiesDict ;
    kern_return_t err = IORegistryEntryCreateCFProperties(obj.object, &propertiesDict, kCFAllocatorDefault, kNilOptions) ;
    if (err == KERN_SUCCESS) {
        if (propertiesDict) {
            NSDictionary *properties = (__bridge_transfer NSDictionary *)propertiesDict ;
            [skin pushNSObject:properties.allKeys] ;
        } else {
            lua_newtable(L) ;
        }
    } else {
        logError(YES, "propertyNames", err, @"unable to retrieve IOObject properties") ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_propertyValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSASM_IOobject *obj = [skin toNSObjectAtIndex:1] ;
    NSString       *key = [skin toNSObjectAtIndex:2] ;

    if (lua_gettop(L) == 2) {
        CFTypeRef value = IORegistryEntryCreateCFProperty(obj.object, (__bridge CFStringRef)key, kCFAllocatorDefault, kNilOptions) ;

        if (value) {
            [skin pushNSObject:(__bridge_transfer id)value] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        NSObject  *value        = [skin toNSObjectAtIndex:3] ;
        CFTypeRef propertyValue = NULL ;

        if ([value isKindOfClass:[NSString class]]) {
            propertyValue = (__bridge CFStringRef)((NSString *)value) ;
        } else if ([value isKindOfClass:[NSNumber class]]) {
            if (lua_type(L, 3) == LUA_TBOOLEAN) {
                propertyValue = lua_toboolean(L, 2) ? kCFBooleanTrue : kCFBooleanFalse ;
            } else {
                propertyValue = (__bridge CFNumberRef)((NSNumber *)value) ;
            }
        } else if ([value isKindOfClass:[NSDictionary class]]) {
            // FIXME: should we validate members?
            propertyValue = (__bridge CFDictionaryRef)((NSDictionary *)value) ;
        } else if ([value isKindOfClass:[NSArray class]]) {
            // FIXME: should we validate members?
            propertyValue = (__bridge CFArrayRef)((NSArray *)value) ;
        } else if ([value isKindOfClass:[NSSet class]]) {
            propertyValue = (__bridge CFSetRef)((NSSet *)value) ;
        } else if ([value isKindOfClass:[NSData class]]) {
            propertyValue = (__bridge CFDataRef)((NSData *)value) ;
        } else {
            return luaL_argerror(L, 3, "value must be serializable (i.e. a simple data type)") ;
        }

        if (propertyValue) {
            kern_return_t err = IORegistryEntrySetCFProperty(obj.object, (__bridge CFStringRef)key, propertyValue) ;
            if (err != KERN_SUCCESS) {
                logError(YES, "propertyValue", err, @"unable to set property value") ;
            }
        }

        lua_pushvalue(L, 1) ;
    }

    return 1 ;
}

static int iokit_locationInPlane(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASM_IOobject *obj = [skin toNSObjectAtIndex:1] ;

    io_name_t plane = kIOServicePlane ;
    if (lua_gettop(L) > 1) strncpy(plane, lua_tostring(L, 2), sizeof(io_name_t)) ;

    io_name_t location ;
    kern_return_t err = IORegistryEntryGetLocationInPlane(obj.object, plane, location) ;
    if (err == KERN_SUCCESS) {
        lua_pushstring(L, location) ;
    } else {
        logError(YES, "locationInPlane", err, @"unable to retrieve IOObject location") ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_nameInPlane(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASM_IOobject *obj = [skin toNSObjectAtIndex:1] ;

    io_name_t plane = kIOServicePlane ;
    if (lua_gettop(L) > 1) strncpy(plane, lua_tostring(L, 2), sizeof(io_name_t)) ;

    io_name_t name ;
    kern_return_t err = IORegistryEntryGetNameInPlane(obj.object, plane, name) ;
    if (err == KERN_SUCCESS) {
        lua_pushstring(L, name) ;
    } else {
        logError(YES, "nameInPlane", err, @"unable to retrieve IOObject name") ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_pathInPlane(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASM_IOobject *obj = [skin toNSObjectAtIndex:1] ;

    io_name_t plane = kIOServicePlane ;
    if (lua_gettop(L) > 1) strncpy(plane, lua_tostring(L, 2), sizeof(io_name_t)) ;

    io_string_t path ;
    kern_return_t err = IORegistryEntryGetPath(obj.object, plane, path) ;
    if (err == KERN_SUCCESS) {
        lua_pushstring(L, path) ;
    } else {
        logError(YES, "pathInPlane", err, @"unable to retrieve IOObject path") ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_inPlane(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSASM_IOobject *obj = [skin toNSObjectAtIndex:1] ;

    io_name_t plane = kIOServicePlane ;
    if (lua_gettop(L) > 1) strncpy(plane, lua_tostring(L, 2), sizeof(io_name_t)) ;

    boolean_t inPlane = IORegistryEntryInPlane(obj.object, plane) ;
    lua_pushboolean(L, inPlane ? true : false) ;
    return 1 ;
}

static int iokit_childrenInPlane(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING | LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK | LS_TVARARG] ;
    HSASM_IOobject *obj    = [skin toNSObjectAtIndex:1] ;
    io_name_t      plane   = kIOServicePlane ;
    IOOptionBits   options = 0 ;

    if (lua_type(L, 2) == LUA_TSTRING) {
        [skin checkArgs:LS_TANY, LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
        strncpy(plane, lua_tostring(L, 2), sizeof(io_name_t)) ;
    } else {
        [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    }

    if (lua_type(L, -1) == LUA_TBOOLEAN && lua_toboolean(L, -1)) options |= kIORegistryIterateRecursively ;

    io_iterator_t iterator = 0 ;
    kern_return_t err = IORegistryEntryCreateIterator(obj.object, plane, options, &iterator) ;
    if (err == KERN_SUCCESS) {
        lua_newtable(L) ;
        io_object_t entry = 0 ;
        while ((entry = IOIteratorNext(iterator))) {
            [skin pushNSObject:[[HSASM_IOobject alloc] initWithObjet:entry]] ;
            err = IOObjectRelease(entry) ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            if (err != KERN_SUCCESS) {
                logError(YES, "childrenInPlane", err, [NSString stringWithFormat:@"unable to release entry %lld", luaL_len(L, -2)]) ;
            }
        }
        err = IOObjectRelease(iterator) ;
        if (err != KERN_SUCCESS) {
            logError(YES, "childrenInPlane", err, @"unable to release iterator") ;
        }
    } else {
        logError(YES, "childrenInPlane", err, @"unable to get iterator") ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_parentsInPlane(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING | LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK | LS_TVARARG] ;
    HSASM_IOobject *obj    = [skin toNSObjectAtIndex:1] ;
    io_name_t      plane   = kIOServicePlane ;
    IOOptionBits   options = kIORegistryIterateParents ;

    if (lua_type(L, 2) == LUA_TSTRING) {
        [skin checkArgs:LS_TANY, LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
        strncpy(plane, lua_tostring(L, 2), sizeof(io_name_t)) ;
    } else {
        [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    }

    if (lua_type(L, -1) == LUA_TBOOLEAN && lua_toboolean(L, -1)) options |= kIORegistryIterateRecursively ;

    io_iterator_t iterator = 0 ;
    kern_return_t err = IORegistryEntryCreateIterator(obj.object, plane, options, &iterator) ;
    if (err == KERN_SUCCESS) {
        lua_newtable(L) ;
        io_object_t entry = 0 ;
        while ((entry = IOIteratorNext(iterator))) {
            [skin pushNSObject:[[HSASM_IOobject alloc] initWithObjet:entry]] ;
            err = IOObjectRelease(entry) ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            if (err != KERN_SUCCESS) {
                logError(YES, "parentsInPlane", err, [NSString stringWithFormat:@"unable to release entry %lld", luaL_len(L, -2)]) ;
            }
        }
        err = IOObjectRelease(iterator) ;
        if (err != KERN_SUCCESS) {
            logError(YES, "parentsInPlane", err, @"unable to release iterator") ;
        }
    } else {
        logError(YES, "parentsInPlane", err, @"unable to get iterator") ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_searchForProperty(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK | LS_TVARARG] ;
    HSASM_IOobject *obj     = [skin toNSObjectAtIndex:1] ;
    NSString        *key    = [skin toNSObjectAtIndex:2] ;
    io_name_t       plane   = kIOServicePlane ;
    IOOptionBits    options = kIORegistryIterateRecursively ;

    switch(lua_gettop(L)) {
        case 3:
            if (lua_type(L, 3) == LUA_TBOOLEAN) break ;
        case 4:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
            strncpy(plane, lua_tostring(L, 3), sizeof(io_name_t)) ;
            break ;
    }
    if (lua_type(L, -1) == LUA_TBOOLEAN && lua_toboolean(L, -1)) options |= kIORegistryIterateParents ;

    CFTypeRef result = IORegistryEntrySearchCFProperty(obj.object, plane, (__bridge CFStringRef)key, kCFAllocatorDefault, options) ;
    if (result) {
        [skin pushNSObject:(__bridge_transfer id)result] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSASM_IOobject(lua_State *L, id obj) {
    HSASM_IOobject *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSASM_IOobject *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id pullHSASM_IOobject(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSASM_IOobject *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSASM_IOobject, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSASM_IOobject *obj = [skin luaObjectAtIndex:1 toClass:"HSASM_IOobject"] ;
    io_name_t name ;
    kern_return_t err = IORegistryEntryGetName(obj.object, name) ;
    NSString *title ;
    if (err == KERN_SUCCESS) {
        title = [NSString stringWithUTF8String:name] ;
    } else {
        title = @"<err>" ;
        logError(YES, "__tostring", err, @"unable to retrieve IOObject name") ;
        lua_pushnil(L) ;
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSASM_IOobject *obj1 = [skin luaObjectAtIndex:1 toClass:"HSASM_IOobject"] ;
        HSASM_IOobject *obj2 = [skin luaObjectAtIndex:2 toClass:"HSASM_IOobject"] ;
        lua_pushboolean(L, (int)(IOObjectIsEqualTo(obj1.object, obj2.object))) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSASM_IOobject *obj = get_objectFromUserdata(__bridge_transfer HSASM_IOobject, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
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
    {"name",              iokit_name},
    {"class",             iokit_class},
    {"conformsTo",        iokit_conformsTo},
    {"registryID",        iokit_registryEntryID},

    {"locationInPlane",   iokit_locationInPlane},
    {"nameInPlane",       iokit_nameInPlane},
    {"pathInPlane",       iokit_pathInPlane},
    {"isInPlane",         iokit_inPlane},
    {"childrenInPlane",   iokit_childrenInPlane},
    {"parentsInPlane",    iokit_parentsInPlane},

    {"properties",        iokit_properties},
    {"propertyNames",     iokit_propertyNames},
    {"propertyValue",     iokit_propertyValue},
    {"propertySearch",    iokit_searchForProperty},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"rootEntry",           iokit_rootEntry},
    {"serviceForPath",      iokit_serviceFromPath},

    {"serviceMatching",     iokit_serviceMatching},
    {"servicesMatching",    iokit_servicesMatching},

    {"bundleIDForClass",    iokit_bundleIdentifierForClass},
    {"superclassForClass",  iokit_superclassForClass},

    {"_matchingName",       iokit_matchingName},
    {"_matchingClass",      iokit_matchingClass},
    {"_matchingRegistryID", iokit_matchingEntryID},
    {"_matchingBSDName",    iokit_matchingBSDName},

    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_libiokit(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSASM_IOobject    forClass:"HSASM_IOobject"];
    [skin registerLuaObjectHelper:pullHSASM_IOobject forClass:"HSASM_IOobject"
                                          withUserdataMapping:USERDATA_TAG];

    return 1;
}
