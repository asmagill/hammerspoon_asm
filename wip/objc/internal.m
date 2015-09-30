#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"
#import "objc.h"

int refTable ;

#pragma mark - Module Functions

static int objc_getImageNames(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;

    lua_newtable(L) ;
      UInt  count ;
      const char **files = objc_copyImageNames(&count) ;
      for(UInt i = 0 ; i < count ; i++) {
          lua_pushstring(L, files[i]) ;
          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      }
      if (files) free(files) ;
    return 1 ;
}

static int objc_classNamesForImage(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TSTRING, LS_TBREAK] ;

    lua_newtable(L) ;
      UInt  count ;
      const char **classes = objc_copyClassNamesForImage(luaL_checkstring(L, 1), &count) ;
      for(UInt i = 0 ; i < count ; i++) {
          lua_pushstring(L, classes[i]) ;
          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      }
      if (classes) free(classes) ;
    return 1 ;
}

// per /usr/include/objc/message.h:

/* Floating-point-returning Messaging Primitives
 *
 * Use these functions to call methods that return floating-point values
 * on the stack.
 * Consult your local function call ABI documentation for details.
 *
 * arm:    objc_msgSend_fpret not used
 * i386:   objc_msgSend_fpret used for `float`, `double`, `long double`.
 * x86-64: objc_msgSend_fpret used for `long double`.
 *
 * arm:    objc_msgSend_fp2ret not used
 * i386:   objc_msgSend_fp2ret not used
 * x86-64: objc_msgSend_fp2ret used for `_Complex long double`.
 *
 * These functions must be cast to an appropriate function pointer type
 * before being called.
 */

// id                              objc_msgSend(id self, SEL op, ...)
// double                          objc_msgSend_fpret(id self, SEL op, ...)
// void                            objc_msgSend_stret(void * stretAddr, id theReceiver, SEL theSelector, ...)
// id                              objc_msgSendSuper(struct objc_super *super, SEL op, ...)
// void                            objc_msgSendSuper_stret(struct objc_super *super, SEL op, ...)

static int lua_msgSend(lua_State *L) {
    int rcvPos = (lua_type(L, 1) == LUA_TUSERDATA) ? 1 : 2 ;
    int selPos = rcvPos + 1 ;

    BOOL  callSuper = NO ;
    int   argCount = lua_gettop(L) - selPos ;
    Class cls ;
    id    rcv ;

    if (rcvPos == 2) callSuper = (BOOL)lua_toboolean(L, 1) ;

    if (luaL_testudata(L, rcvPos, CLASS_USERDATA_TAG)) {
        cls = get_objectFromUserdata(__bridge Class, L, rcvPos, CLASS_USERDATA_TAG) ;
        rcv = (id)cls ;
    } else if(luaL_testudata(L, rcvPos, ID_USERDATA_TAG)) {
        rcv = get_objectFromUserdata(__bridge id, L, rcvPos, ID_USERDATA_TAG) ;
        cls = object_getClass(rcv) ;
    } else {
        luaL_checkudata(L, rcvPos, ID_USERDATA_TAG) ; // use the ID type for the error message
    }
    SEL sel = get_objectFromUserdata(SEL, L, selPos, SEL_USERDATA_TAG) ;

    lua_pushfstring(L, "Class: %s Selector: %s with %d arguments.",
            (callSuper ? class_getName(class_getSuperclass(cls)) : class_getName(cls)),
            sel_getName(sel),
            argCount) ;
    return 1 ;
}
static int lua_msgSendSuper(lua_State *L) {
    lua_pushboolean(L, YES) ;
    lua_insert(L, 1) ;
    lua_msgSend(L) ;
    return 1 ;
}

#pragma mark - LuaSkin conversion functions

static int NSMethodSignature_toLua(lua_State *L, id obj) {
    NSMethodSignature *sig = obj ;
    lua_newtable(L) ;
      lua_pushstring(L, [sig methodReturnType]) ;                 lua_setfield(L, -2, "methodReturnType") ;
      lua_pushinteger(L, (lua_Integer)[sig methodReturnLength]) ; lua_setfield(L, -2, "methodReturnLength") ;
      lua_pushinteger(L, (lua_Integer)[sig frameLength]) ;        lua_setfield(L, -2, "frameLength") ;
      lua_pushinteger(L, (lua_Integer)[sig numberOfArguments]) ;  lua_setfield(L, -2, "numberOfArguments") ;
      lua_newtable(L) ;
        for (NSUInteger i = 0 ; i < [sig numberOfArguments] ; i++) {
            lua_pushstring(L, [sig getArgumentTypeAtIndex:i]) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
      lua_setfield(L, -2, "arguments") ;

    return 1 ;
}

static int NSException_toLua(lua_State *L, id obj) {
    NSException *theError = obj ;

    lua_newtable(L) ;
      [[LuaSkin shared] pushNSObject:[theError name]] ;                     lua_setfield(L, -2, "name") ;
      [[LuaSkin shared] pushNSObject:[theError reason]] ;                   lua_setfield(L, -2, "reason") ;
      [[LuaSkin shared] pushNSObject:[theError userInfo]] ;                 lua_setfield(L, -2, "userInfo") ;
      [[LuaSkin shared] pushNSObject:[theError callStackReturnAddresses]] ; lua_setfield(L, -2, "callStackReturnAddresses") ;
      [[LuaSkin shared] pushNSObject:[theError callStackSymbols]] ;         lua_setfield(L, -2, "callStackSymbols") ;
    return 1 ;
}

static int tryToRegisterHandlers(__unused lua_State *L) {
    [[LuaSkin shared] registerPushNSHelper:NSMethodSignature_toLua forClass:"NSMethodSignature"] ;
    [[LuaSkin shared] registerPushNSHelper:NSException_toLua       forClass:"NSException"] ;
    return 0 ;
}

#pragma mark - Lua Framework Stuff

// static int userdata_tostring(lua_State* L) {
//     return 1 ;
// }

// static int userdata_eq(lua_State* L) {
//     return 1 ;
// }

// static int userdata_gc(lua_State* L) {
//     return 0;
// }

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
// static const luaL_Reg userdata_metaLib[] = {
//     {"__tostring", userdata_tostring},
//     {"__eq",       userdata_eq},
//     {"__gc",       userdata_gc},
//     {NULL,         NULL}
// };

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"objc_msgSend",       lua_msgSend},
    {"objc_msgSendSuper",  lua_msgSendSuper},
    {"imageNames",         objc_getImageNames},
    {"classNamesForImage", objc_classNamesForImage},

    {NULL,                 NULL}
};

// Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
// //     {"__gc", meta_gc},
//     {NULL,         NULL}
// };


int luaopen_hs__asm_objc_internal(lua_State* L) {
// Use this if your module doesn't have a module specific object that it returns.
   refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
//     refTable = [[LuaSkin shared] registerLibraryWithObject:USERDATA_TAG
//                                                  functions:moduleLib
//                                              metaFunctions:module_metaLib
//                                            objectFunctions:userdata_metaLib];

    lua_pushcfunction(L, tryToRegisterHandlers) ;
    if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
        printToConsole(L, (char *)lua_tostring(L, -1)) ;
        lua_pop(L, 1) ;
    }

    return 1;
}
