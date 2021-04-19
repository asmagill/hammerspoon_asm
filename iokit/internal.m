@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.iokit" ;
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface ASM_IO_OBJECT_T : NSObject
@property int         selfRefCount ;
@property io_object_t object ;
@end

@implementation ASM_IO_OBJECT_T

- (instancetype)initWithObjet:(io_object_t)object {
    self = [super init] ;
    if (self) {
        _selfRefCount = 0 ;
        _object       = object ;
        kern_return_t err = IOObjectRetain(_object) ;
        if (err != KERN_SUCCESS) {
            [LuaSkin logWarn:[NSString stringWithFormat:@"%s:initWithObject -- unable to retain IOObject (Kernel Error #%d)", USERDATA_TAG, err]] ;
            self = nil ;
        }
    }
    return self ;
}

- (void)dealloc {
    kern_return_t err = IOObjectRelease(_object) ;
    if (err != KERN_SUCCESS) {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:dealloc -- unable to release IOObject (Kernel Error #%d)", USERDATA_TAG, err]] ;
    }
    _object = 0 ;
}

@end

#pragma mark - Module Functions

static int iokit_rootEntry(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    io_object_t root = IORegistryGetRootEntry(kIOMasterPortDefault) ;
    if (root != MACH_PORT_NULL) {
        [skin pushNSObject:[[ASM_IO_OBJECT_T alloc] initWithObjet:root]] ;
        kern_return_t err = IOObjectRelease(root) ;
        if (err != KERN_SUCCESS) {
            [LuaSkin logDebug:[NSString stringWithFormat:@"%s.root -- unable to release IOObject (Kernel Error #%d)", USERDATA_TAG, err]] ;
        }
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
            [skin pushNSObject:[[ASM_IO_OBJECT_T alloc] initWithObjet:obj]] ;
            kern_return_t err = IOObjectRelease(obj) ;
            if (err != KERN_SUCCESS) {
                [LuaSkin logDebug:[NSString stringWithFormat:@"%s.serviceMatching -- unable to release IOObject (Kernel Error #%d)", USERDATA_TAG, err]] ;
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
                [skin pushNSObject:[[ASM_IO_OBJECT_T alloc] initWithObjet:entry]] ;
                err = IOObjectRelease(entry) ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
                if (err != KERN_SUCCESS) {
                    [LuaSkin logDebug:[NSString stringWithFormat:@"%s.servicesMatching -- unable to release entry %lld (Kernel Error #%d)", USERDATA_TAG, luaL_len(L, -2), err]] ;
                }
            }
            err = IOObjectRelease(iterator) ;
            if (err != KERN_SUCCESS) {
                [LuaSkin logDebug:[NSString stringWithFormat:@"%s.servicesMatching -- unable to release iterator (Kernel Error #%d)", USERDATA_TAG, err]] ;
            }
        } else {
            [LuaSkin logDebug:[NSString stringWithFormat:@"%s.servicesMatching -- unable to get iterator (Kernel Error #%d)", USERDATA_TAG, err]] ;
            lua_pushnil(L) ;
        }
    } else {
        return luaL_argerror(L, 1, "expected table of key-value pairs") ;
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
        [skin pushNSObject:[[ASM_IO_OBJECT_T alloc] initWithObjet:obj]] ;
        kern_return_t err = IOObjectRelease(obj) ;
        if (err != KERN_SUCCESS) {
            [LuaSkin logDebug:[NSString stringWithFormat:@"%s.serviceForPath -- unable to release IOObject (Kernel Error #%d)", USERDATA_TAG, err]] ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_dictionaryMatchingName(lua_State *L) {
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

static int iokit_dictionaryMatchingClass(lua_State *L) {
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

static int iokit_dictionaryMatchingEntryID(lua_State *L) {
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

static int iokit_dictionaryMatchingBSDName(lua_State *L) {
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

#pragma mark - Module Methods

static int iokit_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASM_IO_OBJECT_T *obj = [skin toNSObjectAtIndex:1] ;
    io_name_t deviceName ;
    kern_return_t err = IORegistryEntryGetName(obj.object, deviceName) ;
    if (err == KERN_SUCCESS) {
        lua_pushstring(L, deviceName) ;
    } else {
        [LuaSkin logDebug:[NSString stringWithFormat:@"%s:name -- unable to retrieve IOObject name (Kernel Error #%d)", USERDATA_TAG, err]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_class(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASM_IO_OBJECT_T *obj = [skin toNSObjectAtIndex:1] ;
    CFStringRef className = IOObjectCopyClass(obj.object) ;
    if (className) {
        [skin pushNSObject:(__bridge_transfer NSString *)className] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_properties(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASM_IO_OBJECT_T *obj = [skin toNSObjectAtIndex:1] ;
    BOOL includeNonSerializable = (lua_gettop(L) > 1) ? (BOOL)(lua_toboolean(L, 2)) : NO ;
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
        [LuaSkin logDebug:[NSString stringWithFormat:@"%s:properties -- unable to retrieve IOObject properties (Kernel Error #%d)", USERDATA_TAG, err]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_entryID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASM_IO_OBJECT_T *obj = [skin toNSObjectAtIndex:1] ;
    uint64_t entryID ;
    kern_return_t err = IORegistryEntryGetRegistryEntryID(obj.object, &entryID) ;
    if (err == KERN_SUCCESS) {
        lua_pushinteger(L, (lua_Integer)entryID) ;
    } else {
        [LuaSkin logDebug:[NSString stringWithFormat:@"%s:entryID -- unable to retrieve IOObject entryID (Kernel Error #%d)", USERDATA_TAG, err]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_equals(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASM_IO_OBJECT_T *obj1 = [skin toNSObjectAtIndex:1] ;
    ASM_IO_OBJECT_T *obj2 = [skin toNSObjectAtIndex:2] ;
    lua_pushboolean(L, (Boolean)IOObjectIsEqualTo(obj1.object, obj2.object)) ;
    return 1 ;
}

static int iokit_childrenInPlane(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASM_IO_OBJECT_T *obj = [skin toNSObjectAtIndex:1] ;
    io_name_t plane = kIOServicePlane ;
    if (lua_gettop(L) > 1) strncpy(plane, lua_tostring(L, 2), sizeof(io_name_t)) ;

    io_iterator_t iterator = 0 ;
    kern_return_t err = IORegistryEntryGetChildIterator(obj.object, plane, &iterator) ;
    if (err == KERN_SUCCESS) {
        lua_newtable(L) ;
        io_object_t entry = 0 ;
        while ((entry = IOIteratorNext(iterator))) {
            [skin pushNSObject:[[ASM_IO_OBJECT_T alloc] initWithObjet:entry]] ;
            err = IOObjectRelease(entry) ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            if (err != KERN_SUCCESS) {
                [LuaSkin logDebug:[NSString stringWithFormat:@"%s:childrenInPlane(%s) -- unable to release entry %lld (Kernel Error #%d)", USERDATA_TAG, plane, luaL_len(L, -2), err]] ;
            }
        }
        err = IOObjectRelease(iterator) ;
        if (err != KERN_SUCCESS) {
            [LuaSkin logDebug:[NSString stringWithFormat:@"%s:childrenInPlane(%s) -- unable to release iterator (Kernel Error #%d)", USERDATA_TAG, plane, err]] ;
        }
    } else {
        [LuaSkin logDebug:[NSString stringWithFormat:@"%s:childrenInPlane(%s) -- unable to get iterator (Kernel Error #%d)", USERDATA_TAG, plane, err]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_parentsInPlane(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASM_IO_OBJECT_T *obj = [skin toNSObjectAtIndex:1] ;
    io_name_t plane = kIOServicePlane ;
    if (lua_gettop(L) > 1) strncpy(plane, lua_tostring(L, 2), sizeof(io_name_t)) ;

    io_iterator_t iterator = 0 ;
    kern_return_t err = IORegistryEntryGetParentIterator(obj.object, plane, &iterator) ;
    if (err == KERN_SUCCESS) {
        lua_newtable(L) ;
        io_object_t entry = 0 ;
        while ((entry = IOIteratorNext(iterator))) {
            [skin pushNSObject:[[ASM_IO_OBJECT_T alloc] initWithObjet:entry]] ;
            err = IOObjectRelease(entry) ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            if (err != KERN_SUCCESS) {
                [LuaSkin logDebug:[NSString stringWithFormat:@"%s:parentsInPlane(%s) -- unable to release entry %lld (Kernel Error #%d)", USERDATA_TAG, plane, luaL_len(L, -2), err]] ;
            }
        }
        err = IOObjectRelease(iterator) ;
        if (err != KERN_SUCCESS) {
            [LuaSkin logDebug:[NSString stringWithFormat:@"%s:parentsInPlane(%s) -- unable to release iterator (Kernel Error #%d)", USERDATA_TAG, plane, err]] ;
        }
    } else {
        [LuaSkin logDebug:[NSString stringWithFormat:@"%s:parentsInPlane(%s) -- unable to get iterator (Kernel Error #%d)", USERDATA_TAG, plane, err]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_conformsTo(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    ASM_IO_OBJECT_T *obj = [skin toNSObjectAtIndex:1] ;
    io_name_t className ;
    strncpy(className, lua_tostring(L, 2), sizeof(io_name_t)) ;
    lua_pushboolean(L, (Boolean)IOObjectConformsTo(obj.object, className)) ;
    return 1 ;
}

static int iokit_locationInPlane(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASM_IO_OBJECT_T *obj = [skin toNSObjectAtIndex:1] ;
    io_name_t plane = kIOServicePlane ;
    io_name_t location ;
    if (lua_gettop(L) > 1) strncpy(plane, lua_tostring(L, 2), sizeof(io_name_t)) ;

    kern_return_t err = IORegistryEntryGetLocationInPlane(obj.object, plane, location) ;
    if (err == KERN_SUCCESS) {
        lua_pushstring(L, location) ;
    } else {
        [LuaSkin logDebug:[NSString stringWithFormat:@"%s:locationInPlane(%s) -- unable to retrieve IOObject location (Kernel Error #%d)", USERDATA_TAG, plane, err]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_nameInPlane(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASM_IO_OBJECT_T *obj = [skin toNSObjectAtIndex:1] ;
    io_name_t plane = kIOServicePlane ;
    io_name_t name ;
    if (lua_gettop(L) > 1) strncpy(plane, lua_tostring(L, 2), sizeof(io_name_t)) ;

    kern_return_t err = IORegistryEntryGetNameInPlane(obj.object, plane, name) ;
    if (err == KERN_SUCCESS) {
        lua_pushstring(L, name) ;
    } else {
        [LuaSkin logDebug:[NSString stringWithFormat:@"%s:nameInPlane(%s) -- unable to retrieve IOObject location (Kernel Error #%d)", USERDATA_TAG, plane, err]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_pathInPlane(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASM_IO_OBJECT_T *obj = [skin toNSObjectAtIndex:1] ;
    io_name_t plane = kIOServicePlane ;
    io_string_t path ;
    if (lua_gettop(L) > 1) strncpy(plane, lua_tostring(L, 2), sizeof(io_name_t)) ;

    kern_return_t err = IORegistryEntryGetPath(obj.object, plane, path) ;
    if (err == KERN_SUCCESS) {
        lua_pushstring(L, path) ;
    } else {
        [LuaSkin logDebug:[NSString stringWithFormat:@"%s:pathInPlane(%s) -- unable to retrieve IOObject location (Kernel Error #%d)", USERDATA_TAG, plane, err]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iokit_inPlane(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASM_IO_OBJECT_T *obj = [skin toNSObjectAtIndex:1] ;
    io_name_t plane = kIOServicePlane ;
    if (lua_gettop(L) > 1) strncpy(plane, lua_tostring(L, 2), sizeof(io_name_t)) ;
    lua_pushboolean(L, (Boolean)IORegistryEntryInPlane(obj.object, plane)) ;
    return 1 ;
}

static int iokit_searchForProperty(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK | LS_TVARARG] ;
    ASM_IO_OBJECT_T *obj    = [skin toNSObjectAtIndex:1] ;
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

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASM_IO_OBJECT_T(lua_State *L, id obj) {
    ASM_IO_OBJECT_T *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(ASM_IO_OBJECT_T *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toASM_IO_OBJECT_TFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    ASM_IO_OBJECT_T *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASM_IO_OBJECT_T, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    ASM_IO_OBJECT_T *obj = [skin luaObjectAtIndex:1 toClass:"ASM_IO_OBJECT_T"] ;
    io_name_t name ;
    kern_return_t err = IORegistryEntryGetName(obj.object, name) ;
    NSString *title ;
    if (err == KERN_SUCCESS) {
        title = [NSString stringWithUTF8String:name] ;
    } else {
        title = @"<err>" ;
        [LuaSkin logDebug:[NSString stringWithFormat:@"%s:__tostring -- unable to retrieve IOObject name (Kernel Error #%d)", USERDATA_TAG, err]] ;
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
        ASM_IO_OBJECT_T *obj1 = [skin luaObjectAtIndex:1 toClass:"ASM_IO_OBJECT_T"] ;
        ASM_IO_OBJECT_T *obj2 = [skin luaObjectAtIndex:2 toClass:"ASM_IO_OBJECT_T"] ;
//         lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
        lua_pushboolean(L, (Boolean)IOObjectIsEqualTo(obj1.object, obj2.object)) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASM_IO_OBJECT_T *obj = get_objectFromUserdata(__bridge_transfer ASM_IO_OBJECT_T, L, 1, USERDATA_TAG) ;
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
    {"properties",        iokit_properties},
    {"registryID",        iokit_entryID},
    {"sameAs",            iokit_equals},
    {"childrenInPlane",   iokit_childrenInPlane},
    {"parentsInPlane",    iokit_parentsInPlane},
    {"conformsTo",        iokit_conformsTo},
    {"locationInPlane",   iokit_locationInPlane},
    {"nameInPlane",       iokit_nameInPlane},
    {"pathInPlane",       iokit_pathInPlane},
    {"inPlane",           iokit_inPlane},
    {"searchForProperty", iokit_searchForProperty},

    {"__tostring",        userdata_tostring},
    {"__eq",              userdata_eq},
    {"__gc",              userdata_gc},
    {NULL,                NULL}
};

#if defined(SOURCE_PATH) && ! defined(RELEASE_VERSION)
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)
static int source_path(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushstring(L, TOSTRING(SOURCE_PATH)) ;
    return 1 ;
}
#undef TOSTRING
#undef STRINGIFY
#endif

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"root",                         iokit_rootEntry},
    {"serviceMatching",              iokit_serviceMatching},
    {"servicesMatching",             iokit_servicesMatching},
    {"serviceForPath",               iokit_serviceFromPath},

    {"dictionaryMatchingName",       iokit_dictionaryMatchingName},
    {"dictionaryMatchingClass",      iokit_dictionaryMatchingClass},
    {"dictionaryMatchingRegistryID", iokit_dictionaryMatchingEntryID},
    {"dictionaryMatchingBSDName",    iokit_dictionaryMatchingBSDName},

    {"bundleIDForClass",             iokit_bundleIdentifierForClass},
    {"superclassForClass",           iokit_superclassForClass},
#if defined(SOURCE_PATH) && ! defined(RELEASE_VERSION)
    {"_source_path",                 source_path},
#endif
    {NULL,                           NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_iokit_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASM_IO_OBJECT_T         forClass:"ASM_IO_OBJECT_T"];
    [skin registerLuaObjectHelper:toASM_IO_OBJECT_TFromLua forClass:"ASM_IO_OBJECT_T"
                                                withUserdataMapping:USERDATA_TAG];

    return 1;
}
