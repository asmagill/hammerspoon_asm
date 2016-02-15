#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG "hs._asm.consolepipe"
static int refTable = LUA_NOREF;
static dispatch_queue_t consolepipeQueue = nil ;

static NSPipe *stdOutPipe ;
static NSPipe *stdErrPipe ;

// #define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
#define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

typedef struct _consolepipe_userdata_t {
    int selfRef;
    int callbackRef;
//     void *pipe;
    void *source;
} consolepipe_userdata_t;

#pragma mark - Module Functions

/// hs._asm.consolepipe.new(stream) -> consolePipe object
/// Constructor
/// Create a stream watcher.
///
/// Parameters:
///  * stream - a string of "stdout" or "stderr" specifying which stream to create the watcher for.
///
/// Returns:
///  * the consolePipe object
static int newConsolePipe(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString     *which = [skin toNSObjectAtIndex:1] ;
    NSFileHandle *pipeReadHandle ;

    if ([which isEqualToString:@"stdout"]) {
        pipeReadHandle = [stdOutPipe fileHandleForReading] ;
    } else if ([which isEqualToString:@"stderr"]) {
        pipeReadHandle = [stdErrPipe fileHandleForReading] ;
    } else {
        return luaL_argerror(L, 1, "specify stdout or stderr") ;
    }

    consolepipe_userdata_t *userData = lua_newuserdata(L, sizeof(consolepipe_userdata_t));
    memset(userData, 0, sizeof(consolepipe_userdata_t));
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    userData->selfRef     = LUA_NOREF ;
    userData->callbackRef = LUA_NOREF ;

// http://stackoverflow.com/questions/16391279/how-to-redirect-stdout-to-a-nstextview

    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)[pipeReadHandle fileDescriptor], 0, consolepipeQueue);
    dispatch_source_set_event_handler(source, ^{
        void* data = malloc(4096);
        ssize_t readResult = 0;
        do {
            errno = 0;
            readResult = read([pipeReadHandle fileDescriptor], data, 4096);
        } while (readResult == -1 && errno == EINTR);
        if (readResult > 0) {
            dispatch_async(dispatch_get_main_queue(),^{
                if (userData->callbackRef != LUA_NOREF) {
                    LuaSkin   *skin = [LuaSkin shared] ;
                    [skin pushLuaRef:refTable ref:userData->callbackRef] ;
                    [skin pushNSObject:[[NSString alloc] initWithBytesNoCopy:data
                                                                      length:(NSUInteger)readResult
                                                                    encoding:NSUTF8StringEncoding
                                                                freeWhenDone:YES]];
                    if (![skin protectedCallAndTraceback:1 nresults:0]) {
                        [skin logError:[NSString stringWithFormat:@"%s:error in Lua callback:%@",
                                                                    USERDATA_TAG,
                                                                    [skin toNSObjectAtIndex:-1]]] ;
                        lua_pop([skin L], 1) ; // error string from pcall
                    }
                }
            });
        } else {
            free(data);
        }
    });

//     userData->pipe   = (__bridge_retained void *)pipe ;
    userData->source = (__bridge_retained void *)source ;
    return 1;
}

#pragma mark - Module Methods

/// hs._asm.consolepipe:setCallback(fn | nil) -> consolePipe object
/// Method
/// Set or remove the callback function for the stream.
///
/// Parameters:
///  * fn - a function, or an explicit nil to remove, to be installed as the callback when data is available on the stream.  The callback should expect one parameter -- a string containing the data which has been sent to the stream.
///
/// Returns:
///  * the consolePipe object
static int consolePipeCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];
    consolepipe_userdata_t *userData = get_structFromUserdata(consolepipe_userdata_t, L, 1, USERDATA_TAG) ;

    // in either case, we need to remove an existing callback, so...
    userData->callbackRef = [skin luaUnref:refTable ref:userData->callbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        userData->callbackRef = [skin luaRef:refTable];
        if (userData->selfRef == LUA_NOREF) {               // make sure that we won't be __gc'd if a callback exists
            lua_pushvalue(L, 1) ;                           // but the user doesn't save us somewhere
            userData->selfRef = [skin luaRef:refTable];
        }
    } else {
        userData->selfRef = [skin luaUnref:refTable ref:userData->selfRef] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.consolepipe:start() -> consolePipe object
/// Method
/// Starts calling the callback function when data becomes available on the attached stream.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the consolePipe object
static int consolePipeStart(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    consolepipe_userdata_t *userData = get_structFromUserdata(consolepipe_userdata_t, L, 1, USERDATA_TAG) ;
    dispatch_resume((__bridge dispatch_source_t)userData->source);
    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.consolepipe:stop() -> consolePipe object
/// Method
/// Suspends calling the callback function when data becomes available on the attached stream.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the consolePipe object
static int consolePipeStop(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    consolepipe_userdata_t *userData = get_structFromUserdata(consolepipe_userdata_t, L, 1, USERDATA_TAG) ;
    dispatch_suspend((__bridge dispatch_source_t)userData->source);
    lua_pushvalue(L, 1);
    return 1;
}

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
//         value = get_objectFromUserdata(__bridge <moduleType>, L, idx) ;
//     } else {
//         [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
//                                                    lua_typename(L, lua_type(L, idx))]] ;
//     }
//     return value ;
// }

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(__unused lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

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

/// hs._asm.consolepipe:delete() -> none
/// Method
/// Deletes the stream callback and releases the callback function.  This method is called automatically during reload.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    consolepipe_userdata_t  *userData = get_structFromUserdata(consolepipe_userdata_t, L, 1, USERDATA_TAG) ;
    dispatch_source_t       source    = (__bridge_transfer dispatch_source_t)userData->source;
//     NSPipe                  *pipe     = (__bridge_transfer NSPipe *)userData->pipe ;

    userData->selfRef     = [skin luaUnref:refTable ref:userData->selfRef] ;
    userData->callbackRef = [skin luaUnref:refTable ref:userData->callbackRef] ;
    dispatch_source_cancel(source);
    userData->source = NULL ;
//     userData->pipe = NULL ;

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    consolepipeQueue = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"setCallback", consolePipeCallback},
    {"start",       consolePipeStart},
    {"stop",        consolePipeStop},
    {"delete",      userdata_gc},

    {"__tostring",  userdata_tostring},
//     {"__eq",       userdata_eq},
    {"__gc",        userdata_gc},
    {NULL,          NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", newConsolePipe},
    {NULL,  NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs__asm_consolepipe_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    consolepipeQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);

    // closing (releasing) these causes Hammerspoon to quit with a signal 13, so we create them
    // at module load and keep them around even through reloads...
    if (!stdOutPipe) {
        stdOutPipe = [NSPipe pipe] ;
        dup2([[stdOutPipe fileHandleForWriting] fileDescriptor], fileno(stdout));
    }
    if (!stdErrPipe) {
        stdErrPipe = [NSPipe pipe] ;
        dup2([[stdErrPipe fileHandleForWriting] fileDescriptor], fileno(stderr));
    }

    return 1;
}
