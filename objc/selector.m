/// === hs._asm.objc.selector ===
///
/// The submodule for hs._asm.objc which provides methods for working with and examining Objective-C selectors.
///
/// The terms `selector` and `method` are often used interchangeably in this documentation and in many books and tutorials about Objective-C.  Strictly speaking this is lazy; for most purposes, I find that the easiest way to think of them is as follows: A selector is the name or label for a method, and a method is the actual implementation or function (code) for a selector.  Usually the specific intention is clear from context, but I hope to clean up this documentation to be more precise as time allows.

#import "objc.h"

static LSRefTable refTable = LUA_NOREF;

#pragma mark - Module Functions

/// hs._asm.objc.selector.fromString(name) -> selectorObject
/// Constructor
/// Returns a selector object for the named selector
///
/// Parameters:
///  * name - a string containing the name of the desired selector
///
/// Returns:
///  * the selector object for the name specified
///
/// Notes:
///  * This constructor has also been assigned to the __call metamethod of the `hs._asm.objc.selector` sub-module so that it can be invoked as `hs._asm.objc.selector(name)` as a shortcut.
///
///  * This constructor should not generally be used; instead use [hs._asm.objc.class:selector](#selector), [hs._asm.objc.object:selector](#selector3), or [hs._asm.objc.protocol:selector](#selector4), as they first verify that the named selector is actually valid for the class, object, or protocol in question.
///
///  * This constructor works by attempting to create the specified selector and returning the created selector object.  If the selector already exists (i.e. is defined as a valid selector in a class or protocol somewhere), then the already existing selector is returned instead of a new one.  Because there is no built in facility for determining if a selector is valid without also creating it if it does not already exist, use of this constructor is not preferred.
static int objc_sel_selectorFromName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
// sel_registerName/sel_getUid (which is what NSSelectorFromString uses) creates the selector, even if it doesn't exist yet, so it can't be used to verify that a selector is a valid message for any, much less a specific, class. See init.lua which adds selector methods to class, protocol, and object which check for the selector string in the "current" context without creating anything that doesn't already exist yet.
    push_selector(L, sel_getUid(luaL_checkstring(L, 1))) ;
    return 1 ;
}

#pragma mark - Module Methods

/// hs._asm.objc.selector:name() -> string
/// Method
/// Returns the name of the selector as a string
///
/// Parameters:
///  * None
///
/// Returns:
///  * the selector's name as a string.
static int objc_sel_getName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, SEL_USERDATA_TAG, LS_TBREAK] ;
    SEL sel = get_objectFromUserdata(SEL, L, 1, SEL_USERDATA_TAG) ;
    lua_pushstring(L, sel_getName(sel)) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions

int push_selector(lua_State *L, SEL sel) {
#if defined(DEBUG_GC)
    [LuaSkin logDebug:[NSString stringWithFormat:@"selector: create %@ (%p)", NSStringForSelector(sel), sel]] ;
#endif
    if (sel) {
        void** thePtr = lua_newuserdata(L, sizeof(SEL)) ;
        *thePtr = (void *)sel ;
        luaL_getmetatable(L, SEL_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int selector_userdata_tostring(lua_State* L) {
    SEL sel = get_objectFromUserdata(SEL, L, 1, SEL_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", SEL_USERDATA_TAG, sel_getName(sel), sel) ;
    return 1 ;
}

static int selector_userdata_eq(lua_State* L) {
    SEL sel1 = get_objectFromUserdata(SEL, L, 1, SEL_USERDATA_TAG) ;
    SEL sel2 = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;
    lua_pushboolean(L, sel_isEqual(sel1, sel2)) ;
    return 1 ;
}

static int selector_userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    SEL __unused sel = get_objectFromUserdata(SEL, L, 1, SEL_USERDATA_TAG) ;
#if defined(DEBUG_GC)
    [LuaSkin logDebug:[NSString stringWithFormat:@"selector: remove %@ (%p)", NSStringForSelector(sel), sel]] ;
#endif

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int selector_meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg selector_userdata_metaLib[] = {
    {"name",       objc_sel_getName},

    {"__tostring", selector_userdata_tostring},
    {"__eq",       selector_userdata_eq},
    {"__gc",       selector_userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg selector_moduleLib[] = {
    {"fromString", objc_sel_selectorFromName},

    {NULL,         NULL}
};

// Metatable for module, if needed
// static const luaL_Reg selector_module_metaLib[] = {
//     {"__gc", selector_meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_selector(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:SEL_USERDATA_TAG
                                     functions:selector_moduleLib
                                 metaFunctions:nil // selector_module_metaLib
                               objectFunctions:selector_userdata_metaLib];

    return 1;
}
