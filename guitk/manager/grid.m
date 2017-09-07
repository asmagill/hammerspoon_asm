@import Cocoa ;
@import LuaSkin ;

// static const char * const USERDATA_TAG = "hs._asm.guitk.manager.grid" ;
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
int luaopen_hs__asm_guitk_manager_grid(lua_State* __unused L) {
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

// class Grid(builtins.object)
//  |  Geometry manager Grid.
//  |
//  |  Base class to use the methods grid_* in every widget.
//  |
//  |  Methods defined here:
//  |
//  |  bbox = grid_bbox(self, column=None, row=None, col2=None, row2=None)
//  |
//  |  columnconfigure = grid_columnconfigure(self, index, cnf={}, **kw)
//  |
//  |  config = grid_configure(self, cnf={}, **kw)
//  |
//  |  configure = grid_configure(self, cnf={}, **kw)
//  |
//  |  forget = grid_forget(self)
//  |
//  |  grid = grid_configure(self, cnf={}, **kw)
//  |
//  |  grid_bbox(self, column=None, row=None, col2=None, row2=None)
//  |      Return a tuple of integer coordinates for the bounding
//  |      box of this widget controlled by the geometry manager grid.
//  |
//  |      If COLUMN, ROW is given the bounding box applies from
//  |      the cell with row and column 0 to the specified
//  |      cell. If COL2 and ROW2 are given the bounding box
//  |      starts at that cell.
//  |
//  |      The returned integers specify the offset of the upper left
//  |      corner in the master widget and the width and height.
//  |
//  |  grid_columnconfigure(self, index, cnf={}, **kw)
//  |      Configure column INDEX of a grid.
//  |
//  |      Valid resources are minsize (minimum size of the column),
//  |      weight (how much does additional space propagate to this column)
//  |      and pad (how much space to let additionally).
//  |
//  |  grid_configure(self, cnf={}, **kw)
//  |      Position a widget in the parent widget in a grid. Use as options:
//  |      column=number - use cell identified with given column (starting with 0)
//  |      columnspan=number - this widget will span several columns
//  |      in=master - use master to contain this widget
//  |      in_=master - see 'in' option description
//  |      ipadx=amount - add internal padding in x direction
//  |      ipady=amount - add internal padding in y direction
//  |      padx=amount - add padding in x direction
//  |      pady=amount - add padding in y direction
//  |      row=number - use cell identified with given row (starting with 0)
//  |      rowspan=number - this widget will span several rows
//  |      sticky=NSEW - if cell is larger on which sides will this
//  |                    widget stick to the cell boundary
//  |
//  |  grid_forget(self)
//  |      Unmap this widget.
//  |
//  |  grid_info(self)
//  |      Return information about the options
//  |      for positioning this widget in a grid.
//  |
//  |  grid_location(self, x, y)
//  |      Return a tuple of column and row which identify the cell
//  |      at which the pixel at position X and Y inside the master
//  |      widget is located.
//  |
//  |  grid_propagate(self, flag=['_noarg_'])
//  |      Set or get the status for propagation of geometry information.
//  |
//  |      A boolean argument specifies whether the geometry information
//  |      of the slaves will determine the size of this widget. If no argument
//  |      is given, the current setting will be returned.
//  |
//  |  grid_remove(self)
//  |      Unmap this widget but remember the grid options.
//  |
//  |  grid_rowconfigure(self, index, cnf={}, **kw)
//  |      Configure row INDEX of a grid.
//  |
//  |      Valid resources are minsize (minimum size of the row),
//  |      weight (how much does additional space propagate to this row)
//  |      and pad (how much space to let additionally).
//  |
//  |  grid_size(self)
//  |      Return a tuple of the number of column and rows in the grid.
//  |
//  |  grid_slaves(self, row=None, column=None)
//  |      Return a list of all slaves of this widget
//  |      in its packing order.
//  |
//  |  info = grid_info(self)
//  |
//  |  location = grid_location(self, x, y)
//  |
//  |  propagate = grid_propagate(self, flag=['_noarg_'])
//  |
//  |  rowconfigure = grid_rowconfigure(self, index, cnf={}, **kw)
//  |
//  |  size = grid_size(self)
//  |
//  |  slaves = grid_slaves(self, row=None, column=None)
//  |
//  |  ----------------------------------------------------------------------
//  |  Data descriptors defined here:
//  |
//  |  __dict__
//  |      dictionary for instance variables (if defined)
//  |
//  |  __weakref__
//  |      list of weak references to the object (if defined)
