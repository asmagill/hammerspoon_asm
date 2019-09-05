/// === hs._asm.objc.object ===
///
/// The submodule for hs._asm.objc which provides methods for working with and examining Objective-C objects.
///
/// Most of the methods of this sub-module concentrate on the object as an Objective-C class instance (as an object of type `id`), but there are also methods for examining property values and for converting (some) Objective-C objects to and from a format usable directly by Hammerspoon or Lua.

#import "objc.h"

static int refTable = LUA_NOREF;

#pragma mark - Module Functions

/// hs._asm.objc.object.fromLuaObject(value) -> idObject | nil
/// Constructor
/// Converts a Hammerspoon/Lua value or userdata object into the corresponding Objective-C object.
///
/// Parameters:
///  * value - the Hammerspoon or Lua value or userdata object to return an Objective-C object for.
///
/// Returns:
///  * an idObject (Objective-C class instance) or nil, if no reasonable Objective-C representation exists for the value.
///
/// Notes:
///  * The primary Lua variable types supported are as follows:
///    * number  - will convert to an NSNumber
///    * string  - will convert to an NSString or NSData, if the string does not contain properly formated UTF8 byte-code sequences
///    * table   - will convert to an NSArray, if the table contains only non-sparse, numeric integer indexes starting at 1, or NSDictionary otherwise.
///    * boolean - will convert to an NSNumber
///    * other lua basic types are not supported and will return nil
///  * Many userdata objects which have converters registered by their modules can also be converted to an appropriate type.  An incomplete list of examples follows:
///    * hs.application   - will convert to an NSRunningApplication, if the `hs.application` module has been loaded
///    * hs.styledtext    - will convert to an NSAttributedString, if the `hs.styledtext` module has been loaded
///    * hs.image         - will convert to an NSImage, if the `hs.image` module has been loaded
///  * Some tables with the appropriate __luaSkinType tag can also be converted.  An incomplete list of examples follows:
///    * hs.drawing.color table - will convert to an NSColor, if the `hs.drawing.color` module has been loaded
///    * a Rect table           - will convert to an NSValue containing an NSRect; the hs.geometry equivalent is not yet supported, but this is expected to be a temporary limitation.
///    * a Point table          - will convert to an NSValue containing an NSPoint; the hs.geometry equivalent is not yet supported, but this is expected to be a temporary limitation.
///    * a Size table           - will convert to an NSValue containing an NSSize; the hs.geometry equivalent is not yet supported, but this is expected to be a temporary limitation.
static int object_fromLuaObject(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    id obj = [skin toNSObjectAtIndex:1] ;
    push_object(L, obj) ;
    return 1 ;
}

#pragma mark - Module Methods

/// hs._asm.objc.object:className() -> string
/// Method
/// Returns the class name of the object as a string
///
/// Parameters:
///  * None
///
/// Returns:
///  * the name of the object's class as a string
static int objc_object_getClassName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, ID_USERDATA_TAG, LS_TBREAK] ;
    id obj = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    lua_pushstring(L, object_getClassName(obj)) ;
    return 1 ;
}

/// hs._asm.objc.object:class() -> classObject
/// Method
/// Returns the classObject of the object
///
/// Parameters:
///  * None
///
/// Returns:
///  * the classObject (hs._asm.objc.class) of the object.
static int objc_object_getClass(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, ID_USERDATA_TAG, LS_TBREAK] ;
    id obj = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    push_class(L, object_getClass(obj)) ;
    return 1 ;
}

/// hs._asm.objc.object:value() -> any
/// Method
/// Returns the Hammerspoon or Lua equivalent value of the object
///
/// Parameters:
///  * None
///
/// Returns:
///  * the value of the object as its closest Hammerspoon or Lua equivalent.  Where modules have registered helper functions for handling Objective-C types directly, the appropriate userdata object is returned.  Where no such convertor exists, and if the object does not match a basic Lua data type (string, boolean, number, table), the Objective-C `debugDescription` method of the object is used to return a string describing the object.
static int object_value(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, ID_USERDATA_TAG, LS_TBREAK] ;
    id obj = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    [skin pushNSObject:obj withOptions:LS_NSUnsignedLongLongPreserveBits |
                                       LS_NSDescribeUnknownTypes         |
                                       LS_NSPreserveLuaStringExactly] ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions

int push_object(lua_State *L, id obj) {
#if defined(DEBUG_GC) || defined(DEBUG_GC_OBJONLY)
    [[LuaSkin shared] logDebug:[NSString stringWithFormat:@"object: create %@ (%p)", [obj class], obj]] ;
#endif
    if (obj) {
        void** thePtr = lua_newuserdata(L, sizeof(id)) ;
        *thePtr = (__bridge_retained void *)obj ;
        luaL_getmetatable(L, ID_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int object_userdata_tostring(lua_State* L) {
    id obj = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", ID_USERDATA_TAG, object_getClassName(obj), obj) ;
    return 1 ;
}

static int object_userdata_eq(lua_State* L) {
    id obj1 = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    id obj2 = get_objectFromUserdata(__bridge id, L, 2, ID_USERDATA_TAG) ;
    lua_pushboolean(L, [(NSObject *)obj1 isEqual:(NSObject *)obj2]) ;
    return 1 ;
}

static int object_userdata_gc(lua_State* L) {
    id __unused obj = get_objectFromUserdata(__bridge_transfer id, L, 1, ID_USERDATA_TAG) ;
#if defined(DEBUG_GC) || defined(DEBUG_GC_OBJONLY)
    [[LuaSkin shared] logDebug:[NSString stringWithFormat:@"object: remove %@ (%p)", [obj class], obj]] ;
#endif

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int object_meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg object_userdata_metaLib[] = {
    {"class",      objc_object_getClass},
    {"className",  objc_object_getClassName},
    {"value",      object_value},

    {"__tostring", object_userdata_tostring},
    {"__eq",       object_userdata_eq},
    {"__gc",       object_userdata_gc},
    {NULL,         NULL}
};

// Functions for returned obj when module loads
static luaL_Reg object_moduleLib[] = {
    {"fromLuaObject", object_fromLuaObject},
    {NULL,            NULL}
};

// Metatable for module, if needed
// static const luaL_Reg object_module_metaLib[] = {
//     {"__gc", object_meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_object(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:ID_USERDATA_TAG
                                     functions:object_moduleLib
                                 metaFunctions:nil // object_module_metaLib
                               objectFunctions:object_userdata_metaLib];

    return 1;
}
