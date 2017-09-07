@import Cocoa ;
@import LuaSkin ;

// static const char * const USERDATA_TAG = "hs._asm.guitk.manager.place" ;
static int refTable = LUA_NOREF;

// #define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

#pragma mark - Module Methods

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

// static int push<moduleType>(lua_State *L, id obj) {
//     <moduleType> *value = obj;
//     void** valuePtr = lua_newuserdata(L, sizeof(<moduleType> *));
//     *valuePtr = (__bridge_retained void *)value;
//     luaL_getmetatable(L, USERDATA_TAG);
//     lua_setmetatable(L, -2);
//     return 1;
// }
//
// id to<moduleType>FromLua(lua_State *L, int idx) {
//     LuaSkin *skin = [LuaSkin shared] ;
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
//     LuaSkin *skin = [LuaSkin shared] ;
//     <moduleType> *obj = [skin luaObjectAtIndex:1 toClass:"<moduleType>"] ;
//     NSString *title = ... ;
//     [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
//     return 1 ;
// }

// static int userdata_eq(lua_State* L) {
// // can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// // so use luaL_testudata before the macro causes a lua error
//     if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
//         LuaSkin *skin = [LuaSkin shared] ;
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
//     if (obj) obj = nil ;
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

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_guitk_manager_place(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
// Use this if your module doesn't have a module specific object that it returns.
   refTable = [skin registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
//     refTable = [skin registerLibraryWithObject:USERDATA_TAG
//                                      functions:moduleLib
//                                  metaFunctions:nil    // or module_metaLib
//                                objectFunctions:userdata_metaLib];

//     [skin registerPushNSHelper:push<moduleType>         forClass:"<moduleType>"];

// // one, but not both, of...
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"
//                                              withUserdataMapping:USERDATA_TAG];
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"];

    return 1;
}

// class Place(builtins.object)
//  |  Geometry manager Place.
//  |
//  |  Base class to use the methods place_* in every widget.
//  |
//  |  Methods defined here:
//  |
//  |  config = place_configure(self, cnf={}, **kw)
//  |
//  |  configure = place_configure(self, cnf={}, **kw)
//  |
//  |  forget = place_forget(self)
//  |
//  |  info = place_info(self)
//  |
//  |  place = place_configure(self, cnf={}, **kw)
//  |
//  |  place_configure(self, cnf={}, **kw)
//  |      Place a widget in the parent widget. Use as options:
//  |      in=master - master relative to which the widget is placed
//  |      in_=master - see 'in' option description
//  |      x=amount - locate anchor of this widget at position x of master
//  |      y=amount - locate anchor of this widget at position y of master
//  |      relx=amount - locate anchor of this widget between 0.0 and 1.0
//  |                    relative to width of master (1.0 is right edge)
//  |      rely=amount - locate anchor of this widget between 0.0 and 1.0
//  |                    relative to height of master (1.0 is bottom edge)
//  |      anchor=NSEW (or subset) - position anchor according to given direction
//  |      width=amount - width of this widget in pixel
//  |      height=amount - height of this widget in pixel
//  |      relwidth=amount - width of this widget between 0.0 and 1.0
//  |                        relative to width of master (1.0 is the same width
//  |                        as the master)
//  |      relheight=amount - height of this widget between 0.0 and 1.0
//  |                         relative to height of master (1.0 is the same
//  |                         height as the master)
//  |      bordermode="inside" or "outside" - whether to take border width of
//  |                                         master widget into account
//  |
//  |  place_forget(self)
//  |      Unmap this widget.
//  |
//  |  place_info(self)
//  |      Return information about the placing options
//  |      for this widget.
//  |
//  |  place_slaves(self)
//  |      Return a list of all slaves of this widget
//  |      in its packing order.
//  |
//  |  slaves = place_slaves(self)
//  |
//  |  ----------------------------------------------------------------------
//  |  Data descriptors defined here:
//  |
//  |  __dict__
//  |      dictionary for instance variables (if defined)
//  |
//  |  __weakref__
//  |      list of weak references to the object (if defined)
