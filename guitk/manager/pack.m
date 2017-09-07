@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.guitk.manager.pack" ;
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSASMGUITKManagerPack : NSView
@property NSMutableArray *elementsArray ;
@property BOOL           propagate ;
@property int            selfRefCount ;
@end

@implementation HSASMGUITKManagerPack

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect] ;
    if (self) {
        _elementsArray = [[NSMutableArray alloc] init] ;
        _propagate     = NO ;
        _selfRefCount  = 0 ;
    }
    return self ;
}

- (BOOL)isFlipped { return YES; }

// - (void)validateOptions:(NSDictionary *)options forElement:(NSView *)element error:(NSError * __autoreleasing *)error {
// //  |      after=widget - pack it after you have packed widget
// //  |      anchor=NSEW (or subset) - position widget according to
// //  |                                given direction
// //  |      before=widget - pack it before you will pack widget
// //  |      expand=bool - expand widget if parent size grows
// //  |      fill=NONE or X or Y or BOTH - fill widget if widget grows
// //  |      in=master - use master to contain this widget
// //  |      in_=master - see 'in' option description
// //  |      ipadx=amount - add internal padding in x direction
// //  |      ipady=amount - add internal padding in y direction
// //  |      padx=amount - add padding in x direction
// //  |      pady=amount - add padding in y direction
// //  |      side=TOP or BOTTOM or LEFT or RIGHT -  where to add this widget.
// }

- (void)addOrReplace:(NSView *)element withOptions:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
// @{
//     @"ref"     : luaref to userdata for view
//     @"view"    : NSView itself
//     @"options" : options dictionary
// }
}

- (void)remove:(NSView *)element {

}

- (void)drawRect:(__unused NSRect)rect {

}

@end

#pragma mark - Module Functions

#pragma mark - Module Methods

static int pack__guitk(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMGUITKManagerPack *manager = [skin toNSObjectAtIndex:1] ;
    if ([manager isEqualTo:manager.window.contentView] && [manager.window isKindOfClass:NSClassFromString(@"HSASMGuiWindow")]) {
        [skin pushNSObject:manager.window] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int pack_configure(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKManagerPack *manager = [skin toNSObjectAtIndex:1] ;
    NSView                *element = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
    if (!element || ![element isKindOfClass:[NSView class]]) {
        return luaL_argerror(L, 2, "expected userdata representing a manageable element (NSView subclass)") ;
    }
    NSDictionary *options = (lua_gettop(L) == 3) ? [skin toNSObjectAtIndex:3] : @{} ;
    NSError *validationError = nil ;
    [manager addOrReplace:element withOptions:options error:&validationError] ;
    if (validationError) {
        return luaL_argerror(L, 3, [[NSString stringWithFormat:@"invalid options specified:%@", validationError.localizedDescription] UTF8String]) ;
    } else {
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int pack_forget(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
    HSASMGUITKManagerPack *manager = [skin toNSObjectAtIndex:1] ;
    NSView                *element = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
    if (!element || ![element isKindOfClass:[NSView class]]) {
        return luaL_argerror(L, 2, "expected userdata representing a manageable element (NSView subclass)") ;
    }
    [manager remove:element] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int pack_info(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
    HSASMGUITKManagerPack *manager = [skin toNSObjectAtIndex:1] ;
    NSView                *element = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
    if (!element || ![element isKindOfClass:[NSView class]]) {
        return luaL_argerror(L, 2, "expected userdata representing a manageable element (NSView subclass)") ;
    }
    if ([manager.subviews containsObject:element]) {
        BOOL __block found = NO ;
        [manager.elementsArray enumerateObjectsUsingBlock:^(NSDictionary *item, __unused NSUInteger idx, BOOL *stop) {
            if ([element isEqualTo:item[@"view"]]) {
                [skin pushNSObject:item[@"options"]] ;
                found = YES ;
                *stop = YES ;
            }
        }] ;
        if (!found) {
            [skin logError:[NSString stringWithFormat:@"%s:info internal inconsistency:%@ missing from members array:%@", USERDATA_TAG, element, manager.elementsArray]] ;
            return luaL_error(L, "internal inconsistency -- no details for element available; notify developers") ;
        }
    } else {
        return luaL_argerror(L, 2, "element is not managed being managed by this manager") ;
    }
    return 1 ;
}

static int pack_propagate(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKManagerPack *manager = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, manager.propagate) ;
    } else {
        manager.propagate = (BOOL)lua_toboolean(L, 2) ;
        manager.needsDisplay = YES ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int pack_slaves(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMGUITKManagerPack *manager = [skin toNSObjectAtIndex:1] ;
    lua_newtable(L) ;
    [manager.elementsArray enumerateObjectsUsingBlock:^(NSDictionary *item, NSUInteger idx, BOOL *stop) {
        NSNumber *refNumber = item[@"ref"] ;
        if (refNumber) {
            [skin pushLuaRef:refTable ref:refNumber.intValue] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        } else {
            [skin logError:[NSString stringWithFormat:@"%s:slaves internal inconsistency:no ref for index %lu in members array:%@", USERDATA_TAG, idx + 1, manager.elementsArray]] ;
            luaL_error(L, "internal inconsistency -- missing ref for index %l in members array; notify developers", idx + 1) ;
            // luaL_error never returns, so we'll never really get here, but it conveys the intention
            *stop = YES ;
        }
    }] ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSASMGUITKManagerPack(lua_State *L, id obj) {
    HSASMGUITKManagerPack *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSASMGUITKManagerPack *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toHSASMGUITKManagerPackFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMGUITKManagerPack *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSASMGUITKManagerPack, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
//     HSASMGUITKManagerPack *obj = [skin luaObjectAtIndex:1 toClass:"HSASMGUITKManagerPack"] ;
//     NSString *title = @"title-me" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSASMGUITKManagerPack *obj1 = [skin luaObjectAtIndex:1 toClass:"HSASMGUITKManagerPack"] ;
        HSASMGUITKManagerPack *obj2 = [skin luaObjectAtIndex:2 toClass:"HSASMGUITKManagerPack"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSASMGUITKManagerPack *obj = get_objectFromUserdata(__bridge_transfer HSASMGUITKManagerPack, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin shared] ;
            [obj.elementsArray enumerateObjectsUsingBlock:^(NSDictionary *item, __unused NSUInteger idx, __unused BOOL *stop) {
                NSNumber *refNumber = item[@"ref"] ;
                [skin luaUnref:refTable ref:refNumber.intValue] ;
            }] ;
            [obj.elementsArray removeAllObjects] ;
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
    {"configure",  pack_configure},
    {"forget",     pack_forget},
    {"info",       pack_info},
    {"propagate",  pack_propagate},
    {"slaves",     pack_slaves},

    {"_guitk",     pack__guitk},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_guitk_manager_pack(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSASMGUITKManagerPack         forClass:"HSASMGUITKManagerPack"];
    [skin registerLuaObjectHelper:toHSASMGUITKManagerPackFromLua forClass:"HSASMGUITKManagerPack"
                                                      withUserdataMapping:USERDATA_TAG];

    return 1;
}

// class Pack(builtins.object)
//  |  Geometry manager Pack.
//  |
//  |  Base class to use the methods pack_* in every widget.
//  |
//  |  Methods defined here:
//  |
//  |  config = pack_configure(self, cnf={}, **kw)
//  |
//  |  configure = pack_configure(self, cnf={}, **kw)
//  |
//  |  forget = pack_forget(self)
//  |
//  |  info = pack_info(self)
//  |
//  |  pack = pack_configure(self, cnf={}, **kw)
//  |
//  |  pack_configure(self, cnf={}, **kw)
//  |      Pack a widget in the parent widget. Use as options:
//  |      after=widget - pack it after you have packed widget
//  |      anchor=NSEW (or subset) - position widget according to
//  |                                given direction
//  |      before=widget - pack it before you will pack widget
//  |      expand=bool - expand widget if parent size grows
//  |      fill=NONE or X or Y or BOTH - fill widget if widget grows
//  |      in=master - use master to contain this widget
//  |      in_=master - see 'in' option description
//  |      ipadx=amount - add internal padding in x direction
//  |      ipady=amount - add internal padding in y direction
//  |      padx=amount - add padding in x direction
//  |      pady=amount - add padding in y direction
//  |      side=TOP or BOTTOM or LEFT or RIGHT -  where to add this widget.
//  |
//  |  pack_forget(self)
//  |      Unmap this widget and do not use it for the packing order.
//  |
//  |  pack_info(self)
//  |      Return information about the packing options
//  |      for this widget.
//  |
//  |  pack_propagate(self, flag=['_noarg_'])
//  |      Set or get the status for propagation of geometry information.
//  |
//  |      A boolean argument specifies whether the geometry information
//  |      of the slaves will determine the size of this widget. If no argument
//  |      is given the current setting will be returned.
//  |
//  |  pack_slaves(self)
//  |      Return a list of all slaves of this widget
//  |      in its packing order.
//  |
//  |  propagate = pack_propagate(self, flag=['_noarg_'])
//  |
//  |  slaves = pack_slaves(self)
//  |
//  |  ----------------------------------------------------------------------
//  |  Data descriptors defined here:
//  |
//  |  __dict__
//  |      dictionary for instance variables (if defined)
//  |
//  |  __weakref__
//  |      list of weak references to the object (if defined)
