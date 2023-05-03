@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.module" ;
static LSRefTable         refTable     = LUA_NOREF ;

// #define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

// @interface <moduleType> : NSObject
// @property int selfRef ;      -- one of these, but probably not both
// @property int selfRefCount ; -- see notes in push<moduleType>
// @end
//
// @implementation <moduleType>
// - (instancetype)init {
//     self = [super init] ;
//     if (self) {
//         _selfRef      = LUA_NOREF ; -- one of these, but probably not both
//         _selfRefCount = 0 ;         -- see notes in push<moduleType>
//     }
//     return self ;
// }
// @end

#pragma mark - Module Functions

#pragma mark - Module Methods

// // if using selfRef (not selfRefCount, unless you're using a hybrid)
// static int userdata_gc(lua_State *L) ; // forward ref for delete method
// static int <moduleType>Delete(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     obj.selfRef = [skin luaUnref:refTable ref:obj.selfRef] ;
//     // call userdata_gc here to make sure any remaining objects in lua
//     // space that refer to this object won't prevent garbage collection. If __gc
//     // delayed, a registered callback could "recreate" selfRef thus negating the
//     // delete entirely.
//     return userdata_gc(L) ;
// }
// // or just move userdata_gc into this method and change the functionref in module_metatable below.

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

// static int push<moduleType>(lua_State *L, id obj) {
//     <moduleType> *value = obj;

// // Using selfRef: ensures that everytime this object is pushed back to Lua, the identical userdata is used
// //     Pros: can use userdata as key in key-value table
// //     Cons: requires explicit delete method because useradata will never collect on its own (it exists in
// //           the registry at `self.selfRef`)
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     if (value.selfRef == LUA_NOREF) {
//         void** valuePtr = lua_newuserdata(L, sizeof(<moduleType> *));
//         *valuePtr = (__bridge_retained void *)value;
//         luaL_getmetatable(L, USERDATA_TAG);
//         lua_setmetatable(L, -2);
//         value.selfRef = [skin luaRef:refTable] ;
//     }
//     [skin pushLuaRef:refTable ref:value.selfRef] ;

// // Using selfRefCount: auto collection when *last* userdata for object leaves lua variable space
// //     Pros: can autoclean with __gc
// //     Cons: can't directly be used as key in key-value table because different instances of userdata
// //           for same object have different hash values; requires O(n) search on table to find out if
// //           a userdata in the table matches the one we have right now (say as arg to a callback)
// //           (__eq checks aganst *object* equality, not userdata equality)
//     value.selfRefCount++ ;
//     void** valuePtr = lua_newuserdata(L, sizeof(<moduleType> *));
//     *valuePtr = (__bridge_retained void *)value;
//     luaL_getmetatable(L, USERDATA_TAG);
//     lua_setmetatable(L, -2);

// // If you use both, explicit delete will be required (see notes for selfRef above)

//     return 1;
// }
//
// static id to<moduleType>FromLua(lua_State *L, int idx) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     <moduleType> *value ;
//     if (luaL_testudata(L, idx, USERDATA_TAG)) {
//         value = get_objectFromUserdata(__bridge <moduleType>, L, idx, USERDATA_TAG) ;
//     } else {
//         [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
//                                                    lua_typename(L, lua_type(L, idx))]] ;
//     }
//     return value ;
// }

#pragma mark - Hammerspoon/Lua Infrastructure

// static int userdata_tostring(lua_State* L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     <moduleType> *obj = [skin luaObjectAtIndex:1 toClass:"<moduleType>"] ;
//     NSString *title = ... ;
//     [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
//     return 1 ;
// }

// static int userdata_eq(lua_State* L) {
// // can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// // so use luaL_testudata before the macro causes a lua error
//     if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
//         LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//         <moduleType> *obj1 = [skin luaObjectAtIndex:1 toClass:"<moduleType>"] ;
//         <moduleType> *obj2 = [skin luaObjectAtIndex:2 toClass:"<moduleType>"] ;
//         lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
//     } else {
//         lua_pushboolean(L, NO) ;
//     }
//     return 1 ;
// }

// static int userdata_gc(lua_State* L) {
//     <moduleType> *obj = get_objectFromUserdata(__bridge_transfer <moduleType>, L, 1, USERDATA_TAG) ;
//     if (obj) {

// // If using selfRef:
//         LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//         obj.selfRef = [skin luaUnref:refTable ref:obj.selfRef] ; // in case force by reload or meta_gc
//         // other clean up as necessary
//         obj = nil ;

// // If using selfRefCount:
//         obj. selfRefCount-- ;
//         if (obj.selfRefCount == 0) {
//             // other clean up as necessary
//             obj = nil ;
//         }

//     }
//     // Remove the Metatable so future use of the variable in Lua won't think its valid
//     lua_pushnil(L) ;
//     lua_setmetatable(L, 1) ;
//     return 0 ;
// }

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// // Metatable for userdata objects
// static const luaL_Reg userdata_metaLib[] = {
//     {"__tostring", userdata_tostring},
//     {"__eq",       userdata_eq},
//     {"__gc",       userdata_gc},
//     {NULL,         NULL}
// };

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
#if defined(SOURCE_PATH) && ! defined(RELEASE_VERSION)
    {"_source_path", source_path},
#endif
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_module_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
// Use this if your module doesn't have a module specific object that it returns.
    refTable = [skin registerLibrary:USERDATA_TAG
                           functions:moduleLib
                       metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
//     refTable = [skin registerLibraryWithObject:USERDATA_TAG
//                                      functions:moduleLib
//                                  metaFunctions:nil    // or module_metaLib
//                                objectFunctions:userdata_metaLib];

//     [skin registerPushNSHelper:push<moduleType>         forClass:"<moduleType>"];
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"
//                                              withUserdataMapping:USERDATA_TAG];

    return 1;
}
