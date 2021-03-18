@import Cocoa ;
@import LuaSkin ;

// Loosely based on code from http://stackoverflow.com/questions/16391279/how-to-redirect-stdout-to-a-nstextview

static const char * const USERDATA_TAG = "hs._asm.consolepipe" ;
static const char * const stdout_label = "<stdout>" ;
static const char * const stderr_label = "<stderr>" ;

static LSRefTable refTable = LUA_NOREF;
static dispatch_queue_t consolepipeQueue = nil ;

static NSPipe *stdOutPipe ;
static NSPipe *stdErrPipe ;

#define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

typedef struct _consolepipe_userdata_t {
    int selfRef;
    int callbackRef;
    void *source;
    const char *label ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString     *which = [skin toNSObjectAtIndex:1] ;
    const char   *label ;

    if ([which isEqualToString:@"stdout"]) {
        label = stdout_label ;
    } else if ([which isEqualToString:@"stderr"]) {
        label = stderr_label ;
    } else {
        return luaL_argerror(L, 1, "specify stdout or stderr") ;
    }

    consolepipe_userdata_t *userData = lua_newuserdata(L, sizeof(consolepipe_userdata_t));
    memset(userData, 0, sizeof(consolepipe_userdata_t));
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    userData->selfRef     = LUA_NOREF ;
    userData->callbackRef = LUA_NOREF ;
    userData->label       = label ;
    userData->source      = NULL ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    consolepipe_userdata_t *userData = get_structFromUserdata(consolepipe_userdata_t, L, 1, USERDATA_TAG) ;

    if (userData->source) {
        [skin logWarn:[NSString stringWithFormat:@"%s:start - already running; ignoring start request", USERDATA_TAG]] ;
    } else {
        NSFileHandle *pipeReadHandle ;

        if (userData->label == stdout_label) {
            pipeReadHandle = [stdOutPipe fileHandleForReading] ;
        } else if (userData->label == stderr_label) {
            pipeReadHandle = [stdErrPipe fileHandleForReading] ;
        } else {
            return luaL_error(L, "unrecognized file handle:%s", [[NSString stringWithFormat:@"%s", userData->label] UTF8String]) ;
        }

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
                        LuaSkin   *_skin = [LuaSkin sharedWithState:NULL] ;
                        [_skin pushLuaRef:refTable ref:userData->callbackRef] ;
                        [_skin pushNSObject:[[NSString alloc] initWithBytesNoCopy:data
                                                                           length:(NSUInteger)readResult
                                                                         encoding:NSUTF8StringEncoding
                                                                     freeWhenDone:YES]];
                        if (![_skin protectedCallAndTraceback:1 nresults:0]) {
                            [_skin logError:[NSString stringWithFormat:@"%s:error in Lua callback:%@",
                                                                        USERDATA_TAG,
                                                                        [_skin toNSObjectAtIndex:-1]]] ;
                            lua_pop([_skin L], 1) ; // error string from pcall
                        }
                    }
                });
            } else {
                free(data);
            }
        });
        userData->source = (__bridge_retained void *)source ;
        dispatch_resume((__bridge dispatch_source_t)userData->source);
    }
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    consolepipe_userdata_t *userData = get_structFromUserdata(consolepipe_userdata_t, L, 1, USERDATA_TAG) ;

    if (userData->source) {
        dispatch_source_cancel((__bridge_transfer dispatch_source_t)userData->source);
        userData->source = NULL ;
    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s:stop - not running; ignoring stop request", USERDATA_TAG]] ;
    }
    lua_pushvalue(L, 1);
    return 1;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    consolepipe_userdata_t *userData = get_structFromUserdata(consolepipe_userdata_t, L, 1, USERDATA_TAG) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %s (%p)", USERDATA_TAG, userData->label, lua_topointer(L, 1)]] ;
    return 1 ;
}

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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    consolepipe_userdata_t  *userData = get_structFromUserdata(consolepipe_userdata_t, L, 1, USERDATA_TAG) ;

    userData->selfRef     = [skin luaUnref:refTable ref:userData->selfRef] ;
    userData->callbackRef = [skin luaUnref:refTable ref:userData->callbackRef] ;
    if (userData->source) {
        dispatch_source_cancel((__bridge_transfer dispatch_source_t)userData->source);
        userData->source = NULL ;
    }
    userData->label = NULL ;

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

int luaopen_hs__asm_consolepipe_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    consolepipeQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);

    // closing (releasing) these causes Hammerspoon to quit with a signal 13, so we create them
    // at module load and keep them around even through reloads...
    // TODO: revisit this... it may have been trying to cancel a suspended dispatch_source that was the problem and not this...a
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
