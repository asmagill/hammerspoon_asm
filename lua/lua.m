//   remove LuaSkin dependency in this specific module so it can be used by itself?
//       add way to safely fail if LS accessed? Would allow simpler path consolidation

//   move data conversion into recursive function
//       handle tables (can we do without recursion?)
//       handle functions (see lua src lstr.c)?
//       opt *some* userdata?

//   Need way to capture print output
//   Need way to interrupt like ctrl-c in shell
//   Need way to invoke function/code in Hammerspoon sync and async

//   Examples with other embedded languages:
//       ECL (Common Lisp)
//       LuaJit?
//       Python? (https://docs.python.org/3/c-api/index.html)

@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.lua" ;
static LSRefTable         refTable     = LUA_NOREF ;

static NSArray          *defaultColors ;
static NSUInteger       currentColorIdx = 0 ;
static dispatch_queue_t lua_queue ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static int msghandler (lua_State *L) {
  const char *msg = lua_tostring(L, 1);
  if (msg == NULL) {  /* is error object not a string? */
    if (luaL_callmeta(L, 1, "__tostring") &&  /* does it have a metamethod */
        lua_type(L, -1) == LUA_TSTRING)  /* that produces a string? */
      return 1;  /* that is the message */
    else
      msg = lua_pushfstring(L, "(error object is a %s value)",
                               luaL_typename(L, 1));
  }
  luaL_traceback(L, L, msg, 1);  /* append a standard traceback */
  return 1;  /* return the traceback */
}

@interface ASMLuaInstance : NSObject
@property            int            selfRefCount ;
@property            int            callbackRef ;

@property (readonly) int            selfRef ; // when active this is set to prevent collection

@property (readonly) lua_State      *L ;
@property (readonly) NSMutableArray *queuedCommands ;
@property (readonly) BOOL           abort ;

@property            NSColor        *printColor ;
@end

@implementation ASMLuaInstance
- (instancetype)initWithCallbackRef:(int)callbackRef {
    self = [super init] ;
    if (self) {
        _selfRefCount   = 0 ;
        _callbackRef    = callbackRef ;

        _selfRef        = LUA_NOREF ;

        _L              = luaL_newstate() ;
        _queuedCommands = [NSMutableArray array] ;
        _abort          = NO ;

        _printColor     = defaultColors[currentColorIdx] ;
        currentColorIdx = (currentColorIdx + 1) % defaultColors.count ;

        luaL_openlibs(_L) ;
        // FIXME: Need way to capture print output
        // FIXME: Need way to interrupt like ctrl-c in shell
        // FIXME: Need way to invoke function/code in Hammerspoon sync and async
    }
    return self ;
}

- (BOOL)isActive {
    return (_selfRef != LUA_NOREF) ;
}

- (void)run {
    LuaSkin  *skin = [LuaSkin sharedWithState:NULL] ;

    if (!self.isActive) {
        [skin pushNSObject:self] ;
        _selfRef = [skin luaRef:refTable] ;
        _selfRefCount++ ;
    }

    NSData *cmd  = _queuedCommands.firstObject ;
    if (cmd) {
        [_queuedCommands removeObjectAtIndex:0] ;
        dispatch_async(lua_queue, ^{
            NSMutableDictionary *results = [NSMutableDictionary dictionary] ;

            int status = luaL_loadbuffer (self->_L, cmd.bytes, cmd.length, "=hammerspoon") ;

            if (status == LUA_OK) {
                int base = lua_gettop(self->_L) ;
                lua_pushcfunction(self->_L, msghandler) ;
                lua_insert(self->_L, base) ;
                status = lua_pcall(self->_L, 0, LUA_MULTRET, base) ;
                lua_remove(self->_L, base) ;  /* remove message handler from the stack */

                if (status == LUA_OK) {
                    NSMutableArray *stack = [NSMutableArray array] ;

                    while(lua_gettop(self->_L) > 0) {
                        switch(lua_type(self->_L, -1)) {
                            case LUA_TNIL:
                                [stack addObject:[NSNull null]] ;
                                break ;
                            case LUA_TNUMBER:
                                [stack addObject:(lua_isinteger(self->_L, -1) ? @(lua_tointeger(self->_L, -1)) : @(lua_tonumber(self->_L, -1)))] ;
                                break ;
                            case LUA_TBOOLEAN:
                                [stack addObject:(lua_toboolean(self->_L, -1) ? @(YES) : @(NO))] ;
                                break ;
                            case LUA_TFUNCTION:
                            case LUA_TTABLE:
                            case LUA_TUSERDATA:
                            case LUA_TTHREAD:
                            case LUA_TLIGHTUSERDATA:
                            case LUA_TSTRING: {
                                size_t size ;
                                const char *junk = luaL_tolstring(self->_L, -1, &size) ;
                                [stack addObject:[NSData dataWithBytes:(const void *)junk length:size]] ;
                                lua_pop(self->_L, 1) ; // pop luaL_tolstring result from stack
                                break ;
                            }
                        }
                        lua_pop(self->_L, 1) ;
                    }

                    results[@"stack"] = stack ;
                } else {
                    results[@"error"] = [NSString stringWithFormat:@"%s", lua_tostring(self->_L, -1)] ;
                    lua_pop(self->_L, 1) ;
                }
            } else {
                results[@"error"] = [NSString stringWithFormat:@"%s", lua_tostring(self->_L, -1)] ;
                lua_pop(self->_L, 1) ;
            }

            results[@"status"] = @(status) ;

            // invoke callback
            dispatch_sync(dispatch_get_main_queue(), ^{
                LuaSkin *skin2 = [LuaSkin sharedWithState:NULL] ;
                if (self->_callbackRef != LUA_NOREF) {
                    [skin2 pushLuaRef:refTable ref:self->_callbackRef] ;
                    [skin2 pushNSObject:results] ;
                    if (![skin2 protectedCallAndTraceback:1 nresults:0]) {
                        [skin2 logError:[NSString stringWithFormat:@"%s:callback error: %s", USERDATA_TAG, lua_tostring(skin2.L, -1)]] ;
                        lua_pop(skin2.L, 1) ;
                    }
                }
            }) ;

            // now get next command
            dispatch_async(dispatch_get_main_queue(), ^{
                [self run] ;
            }) ;
        }) ;
    } else {
        _selfRef = [skin luaUnref:refTable ref:_selfRef] ;
        _selfRefCount-- ;
    }
}

- (void)enqueue:(NSData *)cmd {
    [_queuedCommands addObject:cmd] ;
    if (!self.isActive) [self run] ;
}

- (void)interrupt {
    [_queuedCommands removeAllObjects] ;
    if (self.isActive) _abort = YES ;
}

- (void)close {
    lua_close(_L) ;
    _L = NULL ;
}

@end

#pragma mark - Module Functions

static int asm_lua_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;

    int callbackRef = LUA_NOREF ;
    if (!lua_isnil(L, 1)) {
        lua_pushvalue(L, 1) ;
        callbackRef = [skin luaRef:refTable] ;
    }

    ASMLuaInstance *obj = [[ASMLuaInstance alloc] initWithCallbackRef:callbackRef] ;
    [skin pushNSObject:obj] ;
    return 1 ;
}

#pragma mark - Module Methods

static int asm_lua_enqueue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    ASMLuaInstance *obj = [skin toNSObjectAtIndex:1] ;
    NSData         *cmd = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] ;
    [obj enqueue:cmd] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int asm_lua_isActive(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMLuaInstance *obj = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, (obj.isActive)) ;
    return 1 ;
}

static int asm_lua_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMLuaInstance *obj = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (obj.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:obj.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
        if (!lua_isnil(L, 2)) {
            lua_pushvalue(L, 2) ;
            obj.callbackRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int asm_lua_printColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMLuaInstance *obj = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:obj.printColor] ;
    } else {
        NSColor *newColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        if (newColor) {
            obj.printColor = newColor ;
            lua_pushvalue(L, 1) ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int asm_lua_break(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMLuaInstance *obj = [skin toNSObjectAtIndex:1] ;

    [obj interrupt] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMLuaInstance(lua_State *L, id obj) {
    ASMLuaInstance *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMLuaInstance *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

static id toASMLuaInstanceFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    ASMLuaInstance *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMLuaInstance, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    ASMLuaInstance *obj = [skin luaObjectAtIndex:1 toClass:"ASMLuaInstance"] ;
    NSString *title = [NSString stringWithFormat:@"%@ (%lu queued)",
                                                 (obj.isActive ? @"active" : @"idle"),
                                                 obj.queuedCommands.count] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        ASMLuaInstance *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMLuaInstance"] ;
        ASMLuaInstance *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMLuaInstance"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMLuaInstance *obj = get_objectFromUserdata(__bridge_transfer ASMLuaInstance, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;

            [obj close] ;
            obj = nil ;
        }

    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
//     dispatch_release(lua_queue) ; // Not needed with ARC
    lua_queue = nil ;
    defaultColors = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"enqueue",    asm_lua_enqueue},
    {"isActive",   asm_lua_isActive},
    {"callback",   asm_lua_callback},

    {"printColor", asm_lua_printColor},
    {"break",      asm_lua_break},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", asm_lua_new},

    {NULL, NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs__asm_lua_lua(lua_State* L) {
    lua_queue = dispatch_queue_create_with_target(USERDATA_TAG, DISPATCH_QUEUE_CONCURRENT, dispatch_get_global_queue(QOS_CLASS_BACKGROUND ,0)) ;

    if (@available(macOS 10.15, *)) {
        defaultColors = @[
            NSColor.systemBlueColor,
            NSColor.systemBrownColor,
            NSColor.systemGrayColor,
            NSColor.systemGreenColor,
            NSColor.systemIndigoColor,
            NSColor.systemOrangeColor,
            NSColor.systemPinkColor,
            NSColor.systemPurpleColor,
            NSColor.systemRedColor,
            NSColor.systemTealColor,
            NSColor.systemYellowColor
        ] ;
    } else {
        defaultColors = @[
            NSColor.systemBlueColor,
            NSColor.systemBrownColor,
            NSColor.systemGrayColor,
            NSColor.systemGreenColor,
            NSColor.systemOrangeColor,
            NSColor.systemPinkColor,
            NSColor.systemPurpleColor,
            NSColor.systemRedColor,
            NSColor.systemTealColor,
            NSColor.systemYellowColor
        ] ;
    }

    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASMLuaInstance         forClass:"ASMLuaInstance"];
    [skin registerLuaObjectHelper:toASMLuaInstanceFromLua forClass:"ASMLuaInstance"
                                               withUserdataMapping:USERDATA_TAG];

    return 1;
}
