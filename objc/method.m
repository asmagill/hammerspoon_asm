/// === hs._asm.objc.method ===
///
/// The submodule for hs._asm.objc which provides methods for working with and examining Objective-C class and protocol methods.
///
/// The terms `selector` and `method` are often used interchangeably in this documentation and in many books and tutorials about Objective-C.  Strictly speaking this is lazy; for most purposes, I find that the easiest way to think of them is as follows: A selector is the name or label for a method, and a method is the actual implementation or function (code) for a selector.  Usually the specific intention is clear from context, but I hope to clean up this documentation to be more precise as time allows.

#import "objc.h"

static LSRefTable refTable = LUA_NOREF;

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

#pragma mark - Module Methods

/// hs._asm.objc.method:selector() -> selectorObject
/// Method
/// Returns the selector for the method
///
/// Parameters:
///  * None
///
/// Returns:
///  * the selectorObject for the method
static int objc_method_getName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    push_selector(L, method_getName(meth)) ;
    return 1 ;
}

/// hs._asm.objc.method:typeEncoding() -> string
/// Method
/// Returns a string describing a method's parameter and return types.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the type encoding for the method as a string
///
/// Notes:
///  * Encoding types are described at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
///
///  * The numerical value between the return type (first character) and the arguments represents an idealized stack size for the method's argument list.  The numbers between arguments specify offsets within that idealized space.  These numbers should not be trusted as they ignore register usage and other optimizations that may be in effect for a given architecture.
///  * Since our implementation of Objective-C message sending utilizes the NSInvocation Objective-C class, we do not have to concern ourselves with the stack space -- it is handled for us; this method is generally not necessary and is provided for informational purposes only.
static int objc_method_getTypeEncoding(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    lua_pushstring(L, method_getTypeEncoding(meth)) ;
    return 1 ;
}

/// hs._asm.objc.method:returnType() -> string
/// Method
/// Returns a string describing a method's return type.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the return type as a string for the method.
///
/// Notes:
///  * Encoding types are described at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
static int objc_method_getReturnType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    const char      *result = method_copyReturnType(meth) ;

    lua_pushstring(L, result) ;
    free((void *)(size_t)result) ;
    return 1 ;
}

/// hs._asm.objc.method:argumentType(index) -> string | nil
/// Method
/// Returns a string describing a single parameter type of a method.
///
/// Parameters:
///  * index - the index of the parameter in the method to return the type for.  Note that the index starts at 0, and all methods have 2 internal arguments at index positions 0 and 1: The object or class receiving the message, and the selector representing the message being sent.
///
/// Returns:
///  * the type for the parameter specified, or nil if there is no parameter at the specified index.
///
/// Notes:
///  * Encoding types are described at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
static int objc_method_getArgumentType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TNUMBER, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    const char      *result = method_copyArgumentType(meth, (UInt)luaL_checkinteger(L, 2)) ;

    lua_pushstring(L, result) ;
    free((void *)(size_t)result) ;
    return 1 ;
}

/// hs._asm.objc.method:numberOfArguments() -> integer
/// Method
/// Returns the number of arguments accepted by a method.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the number of arguments accepted by the method.  Note that all methods have two internal arguments: the object or class receiving the message, and the selector representing the message being sent.  A method which takes additional user provided arguments will return a number greater than 2 for this method.
///
/// Notes:
///  * Note that all methods have two internal arguments: the object or class receiving the message, and the selector representing the message being sent.  A method which takes additional user provided arguments will return a number greater than 2 for this method.
static int objc_method_getNumberOfArguments(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    lua_pushinteger(L, method_getNumberOfArguments(meth)) ;
    return 1 ;
}

/// hs._asm.objc.method:description() -> table
/// Method
/// Returns a table containing the selector for this method and the type encoding for the method.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table with two keys: `selector`, whose value is the selector for this method, and `types` whose value contains the type encoding for the method.
///
/// Notes:
///  * Encoding types are described at https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
///
///  * See also the notes for [hs._asm.objc.method:typeEncoding](#typeEncoding) concerning the type encoding value returned by this method.
static int objc_method_getDescription(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;

    struct objc_method_description *result = method_getDescription(meth) ;
    lua_newtable(L) ;
      lua_pushstring(L, result->types) ; lua_setfield(L, -2, "types") ;
      push_selector(L, result->name)   ; lua_setfield(L, -2, "selector") ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions

int push_method(lua_State *L, Method meth) {
#if defined(DEBUG_GC)
    [LuaSkin logDebug:[NSString stringWithFormat:@"method: create %@ (%p)",
                                                          NSStringFromSelector(method_getName(meth)),
                                                          meth]] ;
#endif
    if (meth) {
        void** thePtr = lua_newuserdata(L, sizeof(Method)) ;
        *thePtr = (void *)meth ;
        luaL_getmetatable(L, METHOD_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int method_userdata_tostring(lua_State* L) {
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s {%s} (%p)", METHOD_USERDATA_TAG, method_getName(meth), method_getTypeEncoding(meth), meth) ;
    return 1 ;
}

static int method_userdata_eq(lua_State* L) {
    Method meth1 = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    Method meth2 = get_objectFromUserdata(Method, L, 2, METHOD_USERDATA_TAG) ;
    lua_pushboolean(L, (meth1 == meth2)) ;
    return 1 ;
}

static int method_userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    Method __unused meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
#if defined(DEBUG_GC)
    [LuaSkin logDebug:[NSString stringWithFormat:@"method: remove %@ (%p)",
                                                          NSStringFromSelector(method_getName(meth)),
                                                          meth]] ;
#endif

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int method_meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg method_userdata_metaLib[] = {
    {"selector",          objc_method_getName},
    {"typeEncoding",      objc_method_getTypeEncoding},
    {"returnType",        objc_method_getReturnType},
    {"argumentType",      objc_method_getArgumentType},
    {"numberOfArguments", objc_method_getNumberOfArguments},
    {"description",       objc_method_getDescription},

    {"__tostring",        method_userdata_tostring},
    {"__eq",              method_userdata_eq},
    {"__gc",              method_userdata_gc},
    {NULL,                NULL}
};

// Functions for returned object when module loads
static luaL_Reg method_moduleLib[] = {
    {NULL, NULL}
};

// Metatable for module, if needed
// static const luaL_Reg method_module_metaLib[] = {
//     {"__gc", method_meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_method(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:METHOD_USERDATA_TAG
                                     functions:method_moduleLib
                                 metaFunctions:nil // method_module_metaLib
                               objectFunctions:method_userdata_metaLib];

    return 1;
}
