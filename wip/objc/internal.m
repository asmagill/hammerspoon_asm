#define DEBUG_msgSend
// #define DEBUG_GC

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"
#import "objc.h"

#import <stdlib.h>
#import <math.h>

#ifndef MACOSX
#define MACOSX
#endif

#import <ffi/ffi.h>

#pragma mark - ===== SAMPLE CLASS ====================================================

@interface OBJCTest : NSObject
@property BOOL    lastBool ;
@property int     lastInt ;
@property NSArray *wordList ;
@end

@implementation OBJCTest
- (id)init {
    self = [super init] ;
    if (self) {
        NSString *string = [NSString stringWithContentsOfFile:@"/usr/share/dict/words"
                                                     encoding:NSASCIIStringEncoding
                                                        error:NULL] ;
        _wordList = [string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] ;
        _lastBool = NO ;
        _lastInt  = 1 ;
    }
    return self ;
}

- (BOOL)returnBool           { _lastBool = !_lastBool ; return _lastBool ; }
- (int) returnRandomInt      { return (int)arc4random() ; }
- (int) returnInt            { _lastInt++ ; return _lastInt ; }
- (char *)returnCString      { return (char *)[[_wordList objectAtIndex:arc4random()%[_wordList count]] UTF8String]; }
- (NSString *)returnNSString { return  [_wordList objectAtIndex:arc4random()%[_wordList count]]; }
- (SEL)returnSelector        { return @selector(returnInt) ; }
- (float)returnFloat         { return (float)(atan(1)*4) ; }
- (double)returnDouble       { return (double)(atan(1)*4) ; }
@end

@interface OBJCTest2 : OBJCTest
@end

@implementation OBJCTest2
- (id)init {
    self = [super init] ;
    return self ;
}

- (char *)returnCString { return "This is a test" ; }
@end

static int refTable ;
static int logFnRef ;

static int __unused warn_to_console(lua_State *L) {
    if (logFnRef != LUA_NOREF) {
        [[LuaSkin shared] pushLuaRef:refTable ref:logFnRef] ;
        lua_getfield(L, -1, "wf") ; lua_remove(L, -2) ;
        lua_insert(L, 1) ;
        if (![[LuaSkin shared] protectedCallAndTraceback:1 nresults:0]) { return lua_error(L) ; }
    }
    return 0 ;
}

static int __unused info_to_console(lua_State *L) {
    if (logFnRef != LUA_NOREF) {
        [[LuaSkin shared] pushLuaRef:refTable ref:logFnRef] ;
        lua_getfield(L, -1, "f") ; lua_remove(L, -2) ;
        lua_insert(L, 1) ;
        if (![[LuaSkin shared] protectedCallAndTraceback:1 nresults:0]) { return lua_error(L) ; }
    }
    return 0 ;
}

static int __unused debug_to_console(lua_State *L) {
    if (logFnRef != LUA_NOREF) {
        [[LuaSkin shared] pushLuaRef:refTable ref:logFnRef] ;
        lua_getfield(L, -1, "df") ; lua_remove(L, -2) ;
        lua_insert(L, 1) ;
        if (![[LuaSkin shared] protectedCallAndTraceback:1 nresults:0]) { return lua_error(L) ; }
    }
    return 0 ;
}

#pragma mark - ===== CLASS ===========================================================

static int        classRefTable ;

static int push_class(lua_State *L, Class cls) {
#ifdef DEBUG_GC
    NSLog(@"class: create %p", cls) ;
#endif
    if (cls) {
        void** thePtr = lua_newuserdata(L, sizeof(Class)) ;
// Don't alter retain count for Class objects
        *thePtr = (__bridge void *)cls ;
        luaL_getmetatable(L, CLASS_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Functions

static int objc_classFromString(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TSTRING, LS_TBREAK] ;
    Class cls = (Class)objc_lookUpClass(luaL_checkstring(L, 1)) ;

    push_class(L, cls) ;
    return 1 ;
}

static int objc_classList(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;

    lua_newtable(L) ;
      UInt  count ;
      Class *classList = objc_copyClassList(&count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_class(L, classList[i]) ;
          lua_setfield(L, -2, class_getName(classList[i])) ;
      }
      if (classList) free(classList) ;
    return 1 ;
}

#pragma mark - Module Methods

static int objc_class_getMetaClass(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;

    Class meta = (Class)objc_getMetaClass(class_getName(cls)) ;
    push_class(L, meta) ;
    return 1 ;
}

static int objc_class_getMethodList(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;

    lua_newtable(L) ;
      UInt   count ;
      Method *methodList = class_copyMethodList(cls, &count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_method(L, methodList[i]) ;
          lua_setfield(L, -2, sel_getName(method_getName(methodList[i]))) ;
      }
      if (methodList) free(methodList) ;
    return 1 ;
}

static int objc_class_respondsToSelector(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG,
                                LS_TUSERDATA, SEL_USERDATA_TAG,
                                LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    SEL sel = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;

    lua_pushboolean(L, class_respondsToSelector(cls, sel)) ;
    return 1 ;
}

static int objc_class_getInstanceMethod(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG,
                                LS_TUSERDATA, SEL_USERDATA_TAG,
                                LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    SEL sel = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;

    push_method(L, class_getInstanceMethod(cls, sel)) ;
    return 1 ;
}

static int objc_class_getClassMethod(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG,
                                LS_TUSERDATA, SEL_USERDATA_TAG,
                                LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    SEL sel = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;

    push_method(L, class_getClassMethod(cls, sel)) ;
    return 1 ;
}

static int objc_class_getInstanceSize(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushinteger(L, (lua_Integer)class_getInstanceSize(cls)) ;
    return 1 ;
}

static int objc_class_getName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushstring(L, class_getName(cls)) ;
    return 1 ;
}

static int objc_class_getIvarLayout(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushstring(L, (const char *)class_getIvarLayout(cls)) ;
    return 1 ;
}

static int objc_class_getWeakIvarLayout(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushstring(L, (const char *)class_getWeakIvarLayout(cls)) ;
    return 1 ;
}

static int objc_class_getImageName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushstring(L, class_getImageName(cls)) ;
    return 1 ;
}

static int objc_class_isMetaClass(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushboolean(L, class_isMetaClass(cls)) ;
    return 1 ;
}

static int objc_class_getSuperClass(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    push_class(L, class_getSuperclass(cls)) ;
    return 1 ;
}

static int objc_class_getVersion(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushinteger(L, (lua_Integer)class_getVersion(cls)) ;
    return 1 ;
}

static int objc_class_getPropertyList(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;

    lua_newtable(L) ;
      UInt            count ;
      objc_property_t *propertyList = class_copyPropertyList(cls, &count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_property(L, propertyList[i]) ;
          lua_setfield(L, -2, property_getName(propertyList[i])) ;
      }
      if (propertyList) free(propertyList) ;
    return 1 ;
}

static int objc_class_getProperty(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    push_property(L, class_getProperty(cls, luaL_checkstring(L, 2))) ;
    return 1 ;
}

static int objc_class_getIvarList(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;

    lua_newtable(L) ;
      UInt count ;
      Ivar *ivarList = class_copyIvarList(cls, &count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_ivar(L, ivarList[i]) ;
          lua_setfield(L, -2, ivar_getName(ivarList[i])) ;
      }
      if (ivarList) free(ivarList) ;
    return 1 ;
}

static int objc_class_getInstanceVariable(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    push_ivar(L, class_getInstanceVariable(cls, luaL_checkstring(L, 2))) ;
    return 1 ;
}

static int objc_class_getClassVariable(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    push_ivar(L, class_getClassVariable(cls, luaL_checkstring(L, 2))) ;
    return 1 ;
}

static int objc_class_getAdoptedProtocols(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;

    lua_newtable(L) ;
      UInt  count ;
      Protocol * __unsafe_unretained *protocolList = class_copyProtocolList(cls, &count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_protocol(L, protocolList[i]) ;
          lua_setfield(L, -2, protocol_getName(protocolList[i])) ;
      }
      if (protocolList) free(protocolList) ;
    return 1 ;
}

static int objc_class_conformsToProtocol(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG,
                                LS_TUSERDATA, PROTOCOL_USERDATA_TAG, LS_TBREAK] ;
    Class    cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 2, PROTOCOL_USERDATA_TAG) ;

    lua_pushboolean(L, class_conformsToProtocol(cls, prot)) ;
    return 1 ;
}

#pragma mark - Lua Framework

static int class_userdata_tostring(lua_State* L) {
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", CLASS_USERDATA_TAG, class_getName(cls), cls) ;
    return 1 ;
}

static int class_userdata_eq(lua_State* L) {
    Class cls1 = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    Class cls2 = get_objectFromUserdata(__bridge Class, L, 2, CLASS_USERDATA_TAG) ;
    lua_pushboolean(L, (cls1 == cls2)) ;
    return 1 ;
}

static int class_userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    Class __unused cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
#ifdef DEBUG_GC
    NSLog(@"class: remove %p", cls) ;
#endif

// Clear the pointer so it's no longer dangling
    void** thePtr = lua_touserdata(L, 1);
    *thePtr = nil ;

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int class_meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg class_userdata_metaLib[] = {
    {"imageName",           objc_class_getImageName},
    {"instanceSize",        objc_class_getInstanceSize},
    {"ivarLayout",          objc_class_getIvarLayout},
    {"name",                objc_class_getName},
    {"superclass",          objc_class_getSuperClass},
    {"weakIvarLayout",      objc_class_getWeakIvarLayout},
    {"isMetaClass",         objc_class_isMetaClass},
    {"version",             objc_class_getVersion},
    {"propertyList",        objc_class_getPropertyList},
    {"property",            objc_class_getProperty},
    {"ivarList",            objc_class_getIvarList},
    {"instanceVariable",    objc_class_getInstanceVariable},
    {"classVariable",       objc_class_getClassVariable},
    {"adoptedProtocols",    objc_class_getAdoptedProtocols},
    {"conformsToProtocol",  objc_class_conformsToProtocol},
    {"methodList",          objc_class_getMethodList},
    {"respondsToSelector",  objc_class_respondsToSelector},
    {"instanceMethod",      objc_class_getInstanceMethod},
    {"classMethod",         objc_class_getClassMethod},
    {"metaClass",           objc_class_getMetaClass},

    {"__tostring",          class_userdata_tostring},
    {"__eq",                class_userdata_eq},
    {"__gc",                class_userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg class_moduleLib[] = {
    {"fromString", objc_classFromString},
    {"list",       objc_classList},

    {NULL,         NULL}
};

// Metatable for module, if needed
// static const luaL_Reg class_module_metaLib[] = {
//     {"__gc", class_meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_class(lua_State* __unused L) {
    classRefTable = [[LuaSkin shared] registerLibraryWithObject:CLASS_USERDATA_TAG
                                                 functions:class_moduleLib
                                             metaFunctions:nil // class_module_metaLib
                                           objectFunctions:class_userdata_metaLib];
    return 1;
}

#pragma mark - ===== IVAR ============================================================

static int        ivarRefTable ;

static int push_ivar(lua_State *L, Ivar iv) {
#ifdef DEBUG_GC
    NSLog(@"ivar: create %p", iv) ;
#endif
    if (iv) {
        void** thePtr = lua_newuserdata(L, sizeof(Ivar)) ;
        *thePtr = (void *)iv ;
        luaL_getmetatable(L, IVAR_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Functions

#pragma mark - Module Methods

static int objc_ivar_getName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, IVAR_USERDATA_TAG, LS_TBREAK] ;
    Ivar iv = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
    lua_pushstring(L, ivar_getName(iv)) ;
    return 1 ;
}

static int objc_ivar_getTypeEncoding(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, IVAR_USERDATA_TAG, LS_TBREAK] ;
    Ivar iv = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
    lua_pushstring(L, ivar_getTypeEncoding(iv)) ;
    return 1 ;
}

static int objc_ivar_getOffset(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, IVAR_USERDATA_TAG, LS_TBREAK] ;
    Ivar iv = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
    lua_pushinteger(L, ivar_getOffset(iv)) ;
    return 1 ;
}

#pragma mark - Lua Framework

static int ivar_userdata_tostring(lua_State* L) {
    Ivar iv = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", IVAR_USERDATA_TAG, ivar_getName(iv), iv) ;
    return 1 ;
}

static int ivar_userdata_eq(lua_State* L) {
    Ivar iv1 = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
    Ivar iv2 = get_objectFromUserdata(Ivar, L, 2, IVAR_USERDATA_TAG) ;
    lua_pushboolean(L, (iv1 == iv2)) ;
    return 1 ;
}

static int ivar_userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    Ivar __unused iv = get_objectFromUserdata(Ivar, L, 1, IVAR_USERDATA_TAG) ;
#ifdef DEBUG_GC
    NSLog(@"ivar: remove %p", iv) ;
#endif

// Clear the pointer so it's no longer dangling
    void** thePtr = lua_touserdata(L, 1);
    *thePtr = nil ;

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int ivar_meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg ivar_userdata_metaLib[] = {
    {"name",         objc_ivar_getName},
    {"typeEncoding", objc_ivar_getTypeEncoding},
    {"offset",       objc_ivar_getOffset},

    {"__tostring",   ivar_userdata_tostring},
    {"__eq",         ivar_userdata_eq},
    {"__gc",         ivar_userdata_gc},
    {NULL,           NULL}
};

// Functions for returned object when module loads
static luaL_Reg ivar_moduleLib[] = {
    {NULL, NULL}
};

// Metatable for module, if needed
// static const luaL_Reg ivar_module_metaLib[] = {
//     {"__gc", ivar_meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_ivar(lua_State* __unused L) {
    ivarRefTable = [[LuaSkin shared] registerLibraryWithObject:IVAR_USERDATA_TAG
                                                 functions:ivar_moduleLib
                                             metaFunctions:nil // ivar_module_metaLib
                                           objectFunctions:ivar_userdata_metaLib];

    return 1;
}

#pragma mark - ===== METHOD ==========================================================

static int        methodRefTable ;

static int push_method(lua_State *L, Method meth) {
#ifdef DEBUG_GC
    NSLog(@"method: create %p", meth) ;
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

#pragma mark - Module Functions

#pragma mark - Module Methods

static int objc_method_getName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    push_selector(L, method_getName(meth)) ;
    return 1 ;
}

static int objc_method_getTypeEncoding(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    lua_pushstring(L, method_getTypeEncoding(meth)) ;
    return 1 ;
}

static int objc_method_getReturnType(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    const char      *result = method_copyReturnType(meth) ;

    lua_pushstring(L, result) ;
    free((void *)result) ;
    return 1 ;
}

static int objc_method_getArgumentType(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TNUMBER, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    const char      *result = method_copyArgumentType(meth, (UInt)luaL_checkinteger(L, 2)) ;

    lua_pushstring(L, result) ;
    free((void *)result) ;
    return 1 ;
}

static int objc_method_getNumberOfArguments(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    lua_pushinteger(L, method_getNumberOfArguments(meth)) ;
    return 1 ;
}

static int objc_method_getDescription(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;

    struct objc_method_description *result = method_getDescription(meth) ;
    lua_newtable(L) ;
      lua_pushstring(L, result->types) ; lua_setfield(L, -2, "types") ;
      push_selector(L, result->name)   ; lua_setfield(L, -2, "selector") ;
    return 1 ;
}

#pragma mark - Lua Framework

static int method_userdata_tostring(lua_State* L) {
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", METHOD_USERDATA_TAG, method_getName(meth), meth) ;
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
#ifdef DEBUG_GC
    NSLog(@"method: remove %p", meth) ;
#endif

// Clear the pointer so it's no longer dangling
    void** thePtr = lua_touserdata(L, 1);
    *thePtr = nil ;

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

int luaopen_hs__asm_objc_method(lua_State* __unused L) {
    methodRefTable = [[LuaSkin shared] registerLibraryWithObject:METHOD_USERDATA_TAG
                                                 functions:method_moduleLib
                                             metaFunctions:nil // method_module_metaLib
                                           objectFunctions:method_userdata_metaLib];

    return 1;
}

#pragma mark - ===== OBJECT ==========================================================

static int        objectRefTable ;

static int push_object(lua_State *L, id obj) {
#ifdef DEBUG_GC
    NSLog(@"object: create %p", obj) ;
#endif
    if (obj) {
        void** thePtr = lua_newuserdata(L, sizeof(id)) ;
// Do alter retain count on objects... we don't want ARC to remove them until lua does first
        *thePtr = (__bridge_retained void *)obj ;
        luaL_getmetatable(L, ID_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Functions

#pragma mark - Module Methods

static int objc_object_getClassName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, ID_USERDATA_TAG, LS_TBREAK] ;
    id obj = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    lua_pushstring(L, object_getClassName(obj)) ;
    return 1 ;
}

static int objc_object_getClass(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, ID_USERDATA_TAG, LS_TBREAK] ;
    id obj = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    push_class(L, object_getClass(obj)) ;
    return 1 ;
}

static int object_value(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, ID_USERDATA_TAG, LS_TBREAK] ;
    @try {
        id obj = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
        [[LuaSkin shared] pushNSObject:obj] ;
    }
    @catch ( NSException *theException ) {
        return errorOnException(L, ID_USERDATA_TAG, theException) ;
    }
    return 1 ;
}

#pragma mark - Lua Framework

static int object_userdata_tostring(lua_State* L) {
    id obj = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", ID_USERDATA_TAG, object_getClassName(obj), obj) ;
    return 1 ;
}

static int object_userdata_eq(lua_State* L) {
    id obj1 = get_objectFromUserdata(__bridge id, L, 1, ID_USERDATA_TAG) ;
    id obj2 = get_objectFromUserdata(__bridge id, L, 2, ID_USERDATA_TAG) ;
    lua_pushboolean(L, [obj1 isEqual:obj2]) ;
    return 1 ;
}

static int object_userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    id obj = get_objectFromUserdata(__bridge_transfer id, L, 1, ID_USERDATA_TAG) ;
#ifdef DEBUG_GC
    NSLog(@"object: remove %p", obj) ;
#endif
    obj = nil ;

// Clear the pointer so it's no longer dangling
    void** thePtr = lua_touserdata(L, 1);
    *thePtr = nil ;

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int object_meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg object_userdata_metaLib[] = {
    {"class",       objc_object_getClass},
    {"className",   objc_object_getClassName},
    {"value",       object_value},

    {"__tostring", object_userdata_tostring},
    {"__eq",       object_userdata_eq},
    {"__gc",       object_userdata_gc},
    {NULL,         NULL}
};

// Functions for returned obj when module loads
static luaL_Reg object_moduleLib[] = {
    {NULL, NULL}
};

// Metatable for module, if needed
// static const luaL_Reg object_module_metaLib[] = {
//     {"__gc", object_meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_object(lua_State* __unused L) {
    objectRefTable = [[LuaSkin shared] registerLibraryWithObject:ID_USERDATA_TAG
                                                 functions:object_moduleLib
                                             metaFunctions:nil // object_module_metaLib
                                           objectFunctions:object_userdata_metaLib];

    return 1;
}

#pragma mark - ===== PROPERTY ========================================================

static int        propertyRefTable ;

static int push_property(lua_State *L, objc_property_t prop) {
#ifdef DEBUG_GC
    NSLog(@"property: create %p", prop) ;
#endif
    if (prop) {
        void** thePtr = lua_newuserdata(L, sizeof(objc_property_t)) ;
        *thePtr = (void *)prop ;
        luaL_getmetatable(L, PROPERTY_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Functions

#pragma mark - Module Methods

static int objc_property_getName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROPERTY_USERDATA_TAG, LS_TBREAK] ;
    objc_property_t prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
    lua_pushstring(L, property_getName(prop)) ;
    return 1 ;
}

static int objc_property_getAttributes(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROPERTY_USERDATA_TAG, LS_TBREAK] ;
    objc_property_t prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
    lua_pushstring(L, property_getAttributes(prop)) ;
    return 1 ;
}

static int objc_property_getAttributeValue(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROPERTY_USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    objc_property_t prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
    const char      *result = property_copyAttributeValue(prop, luaL_checkstring(L, 2)) ;

    lua_pushstring(L, result) ;
    free((void *)result) ;
    return 1 ;
}

static int objc_property_getAttributeList(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROPERTY_USERDATA_TAG, LS_TBREAK] ;
    objc_property_t prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;

    lua_newtable(L) ;
      UInt                      count ;
      objc_property_attribute_t *attributeList = property_copyAttributeList(prop, &count) ;
      for(UInt i = 0 ; i < count ; i++) {
//           lua_newtable(L) ;
//             lua_pushstring(L, attributeList[i].name) ;  lua_setfield(L, -2, "name") ;
//             lua_pushstring(L, attributeList[i].value) ; lua_setfield(L, -2, "value") ;
//           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushstring(L, attributeList[i].value) ; lua_setfield(L, -2, attributeList[i].name) ;
      }
      free(attributeList) ;
    return 1 ;
}

#pragma mark - Lua Framework

static int property_userdata_tostring(lua_State* L) {
    objc_property_t prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", PROPERTY_USERDATA_TAG, property_getName(prop), prop) ;
    return 1 ;
}

static int property_userdata_eq(lua_State* L) {
    objc_property_t prop1 = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
    objc_property_t prop2 = get_objectFromUserdata(objc_property_t, L, 2, PROPERTY_USERDATA_TAG) ;
    lua_pushboolean(L, (prop1 == prop2)) ;
    return 1 ;
}

static int property_userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    objc_property_t __unused prop = get_objectFromUserdata(objc_property_t, L, 1, PROPERTY_USERDATA_TAG) ;
#ifdef DEBUG_GC
    NSLog(@"property: remove %p", prop) ;
#endif

// Clear the pointer so its not pointing at anything
    void** thePtr = lua_touserdata(L, 1);
    *thePtr = nil ;

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int property_meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg property_userdata_metaLib[] = {
    {"attributeValue", objc_property_getAttributeValue},
    {"attributes",     objc_property_getAttributes},
    {"name",           objc_property_getName},
    {"attributeList",  objc_property_getAttributeList},

    {"__tostring",     property_userdata_tostring},
    {"__eq",           property_userdata_eq},
    {"__gc",           property_userdata_gc},
    {NULL,             NULL}
};

// Functions for returned object when module loads
static luaL_Reg property_moduleLib[] = {
    {NULL, NULL}
};

// Metatable for module, if needed
// static const luaL_Reg property_module_metaLib[] = {
//     {"__gc", property_meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_property(lua_State* __unused L) {
    propertyRefTable = [[LuaSkin shared] registerLibraryWithObject:PROPERTY_USERDATA_TAG
                                                 functions:property_moduleLib
                                             metaFunctions:nil // property_module_metaLib
                                           objectFunctions:property_userdata_metaLib];

    return 1;
}

#pragma mark - ===== PROTOCOL ========================================================

static int        protocolRefTable ;

static int push_protocol(lua_State *L, Protocol *prot) {
#ifdef DEBUG_GC
    NSLog(@"protocol: create %p", prot) ;
#endif
    if (prot) {
        void** thePtr = lua_newuserdata(L, sizeof(Protocol *)) ;
// Don't alter retain count for Protocol objects
        *thePtr = (__bridge void *)prot ;
        luaL_getmetatable(L, PROTOCOL_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Functions

static int objc_protocolFromString(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TSTRING, LS_TBREAK] ;
    Protocol *prot = objc_getProtocol(luaL_checkstring(L, 1)) ;

    push_protocol(L, prot) ;
    return 1 ;
}

static int objc_protocolList(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;

    lua_newtable(L) ;
      UInt  count ;
      Protocol * __unsafe_unretained *protocolList = objc_copyProtocolList(&count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_protocol(L, protocolList[i]) ;
          lua_setfield(L, -2, protocol_getName(protocolList[i])) ;
      }
      if (protocolList) free(protocolList) ;
    return 1 ;
}

#pragma mark - Module Methods

static int objc_protocol_getName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    lua_pushstring(L, protocol_getName(prot)) ;
    return 1 ;
}

static int objc_protocol_getPropertyList(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;

    lua_newtable(L) ;
      UInt            count ;
      objc_property_t *propertyList = protocol_copyPropertyList(prot, &count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_property(L, propertyList[i]) ;
          lua_setfield(L, -2, property_getName(propertyList[i])) ;
      }
      if (propertyList) free(propertyList) ;
    return 1 ;
}

static int objc_protocol_getProperty(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG,
                                LS_TSTRING,
                                LS_TBOOLEAN,
                                LS_TBOOLEAN, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    push_property(L, protocol_getProperty(prot, luaL_checkstring(L, 2),
                                             (BOOL)lua_toboolean(L, 3),
                                             (BOOL)lua_toboolean(L, 4))) ;
    return 1 ;
}


static int objc_protocol_getAdoptedProtocols(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;

    lua_newtable(L) ;
      UInt  count ;
      Protocol * __unsafe_unretained *protocolList = protocol_copyProtocolList(prot, &count) ;
      for(UInt i = 0 ; i < count ; i++) {
          push_protocol(L, protocolList[i]) ;
          lua_setfield(L, -2, protocol_getName(protocolList[i])) ;
      }
      if (protocolList) free(protocolList) ;
    return 1 ;
}

static int objc_protocol_conformsToProtocol(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG,
                                LS_TUSERDATA, PROTOCOL_USERDATA_TAG, LS_TBREAK] ;
    Protocol *prot1 = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    Protocol *prot2 = get_objectFromUserdata(__bridge Protocol *, L, 2, PROTOCOL_USERDATA_TAG) ;
    lua_pushboolean(L, protocol_conformsToProtocol(prot1, prot2)) ;
    return 1 ;
}

static int objc_protocol_getMethodDescriptionList(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG,
                                LS_TBOOLEAN,
                                LS_TBOOLEAN, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    UInt count ;
    struct objc_method_description *results = protocol_copyMethodDescriptionList(prot,
                                                                (BOOL)lua_toboolean(L, 2),
                                                                (BOOL)lua_toboolean(L, 3),
                                                                      &count) ;
    lua_newtable(L) ;
    for(UInt i = 0 ; i < count ; i++) {
        lua_newtable(L) ;
          lua_pushstring(L, results[i].types) ; lua_setfield(L, -2, "types") ;
          push_selector(L, results[i].name)   ; lua_setfield(L, -2, "selector") ;
//         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_setfield(L, -2, sel_getName(results[i].name)) ;
    }
    if (results) free(results) ;
    return 1 ;
}

static int objc_protocol_getMethodDescription(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, PROTOCOL_USERDATA_TAG,
                                LS_TUSERDATA, SEL_USERDATA_TAG,
                                LS_TBOOLEAN,
                                LS_TBOOLEAN, LS_TBREAK] ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    SEL      sel   = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;

    struct objc_method_description  result = protocol_getMethodDescription(prot, sel,
                                                                (BOOL)lua_toboolean(L, 3),
                                                                (BOOL)lua_toboolean(L, 4)) ;
    if (result.types == NULL || result.name == NULL) {
        lua_pushnil(L) ;
    } else {
        lua_newtable(L) ;
          lua_pushstring(L, result.types) ; lua_setfield(L, -2, "types") ;
          push_selector(L, result.name)   ; lua_setfield(L, -2, "selector") ;
    }
    return 1 ;
}

#pragma mark - Lua Framework

static int protocol_userdata_tostring(lua_State* L) {
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", PROTOCOL_USERDATA_TAG, protocol_getName(prot), prot) ;
    return 1 ;
}

static int protocol_userdata_eq(lua_State* L) {
    Protocol *prot1 = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
    Protocol *prot2 = get_objectFromUserdata(__bridge Protocol *, L, 2, PROTOCOL_USERDATA_TAG) ;
    lua_pushboolean(L, protocol_isEqual(prot1, prot2)) ;
    return 1 ;
}

static int protocol_userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    Protocol * __unused prot = get_objectFromUserdata(__bridge Protocol *, L, 1, PROTOCOL_USERDATA_TAG) ;
#ifdef DEBUG_GC
    NSLog(@"protocol: remove %p", prot) ;
#endif

// Clear the pointer so it's no longer dangling
    void** thePtr = lua_touserdata(L, 1);
    *thePtr = nil ;

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int protocol_meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg protocol_userdata_metaLib[] = {
    {"name",                  objc_protocol_getName},
    {"propertyList",          objc_protocol_getPropertyList},
    {"property",              objc_protocol_getProperty},
    {"adoptedProtocols",      objc_protocol_getAdoptedProtocols},
    {"conformsToProtocol",    objc_protocol_conformsToProtocol},
    {"methodDescriptionList", objc_protocol_getMethodDescriptionList},
    {"methodDescription",     objc_protocol_getMethodDescription},

    {"__tostring",            protocol_userdata_tostring},
    {"__eq",                  protocol_userdata_eq},
    {"__gc",                  protocol_userdata_gc},
    {NULL,                    NULL}
};

// Functions for returned object when module loads
static luaL_Reg protocol_moduleLib[] = {
    {"fromString", objc_protocolFromString},
    {"list",       objc_protocolList},

    {NULL,         NULL}
};

// Metatable for module, if needed
// static const luaL_Reg protocol_module_metaLib[] = {
//     {"__gc", protocol_meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_protocol(lua_State* __unused L) {
    protocolRefTable = [[LuaSkin shared] registerLibraryWithObject:PROTOCOL_USERDATA_TAG
                                                 functions:protocol_moduleLib
                                             metaFunctions:nil // protocol_module_metaLib
                                           objectFunctions:protocol_userdata_metaLib];

    return 1;
}

#pragma mark - ===== SELECTOR ========================================================

static int        selectorRefTable ;

static int push_selector(lua_State *L, SEL sel) {
#ifdef DEBUG_GC
    NSLog(@"selector: create %p", sel) ;
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

#pragma mark - Module Functions

// sel_registerName/sel_getUid (which is what NSSelectorFromString uses) creates the selector, even if it doesn't exist yet, so it can't be used to verify that a selector is a valid message for any, much less a specific, class. See init.lua which adds selector methods to class, protocol, and object which check for the selector string in the "current" context without creating anything that doesn't already exist yet.
static int objc_sel_selectorFromName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TSTRING, LS_TBREAK] ;
    push_selector(L, sel_getUid(luaL_checkstring(L, 1))) ;
    return 1 ;
}

#pragma mark - Module Methods

static int objc_sel_getName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, SEL_USERDATA_TAG, LS_TBREAK] ;
    SEL sel = get_objectFromUserdata(SEL, L, 1, SEL_USERDATA_TAG) ;
    lua_pushstring(L, sel_getName(sel)) ;
    return 1 ;
}

#pragma mark - Lua Framework

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
#ifdef DEBUG_GC
    NSLog(@"selector: remove %p", sel) ;
#endif

// Clear the pointer so it's no longer dangling
    void** thePtr = lua_touserdata(L, 1);
    *thePtr = nil ;

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

int luaopen_hs__asm_objc_selector(lua_State* __unused L) {
    selectorRefTable = [[LuaSkin shared] registerLibraryWithObject:SEL_USERDATA_TAG
                                                 functions:selector_moduleLib
                                             metaFunctions:nil // selector_module_metaLib
                                           objectFunctions:selector_userdata_metaLib];

    return 1;
}

#pragma mark - ===== MODULE CORE =====================================================

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

static int lua_FFISend(lua_State *L) {
    int rcvPos = (lua_type(L, 1) == LUA_TNUMBER) ? 2 : 1 ;
    int selPos = rcvPos + 1 ;

    BOOL  callSuper      = NO ;
    BOOL  callAllocFirst = NO ;
    BOOL  rcvIsClass     = NO ;
    int   argCount       = lua_gettop(L) - selPos ;
    int   callType       = 0 ;

    if (rcvPos == 2) callType = (int) luaL_checkinteger(L, 1) ;
    if ((callType & 0x01) != 0) { callSuper = YES ; }
    if ((callType & 0x02) != 0) { callAllocFirst = YES ; }

    Class cls ;
    id    rcv ;

    if (luaL_testudata(L, rcvPos, CLASS_USERDATA_TAG)) {
        cls = get_objectFromUserdata(__bridge Class, L, rcvPos, CLASS_USERDATA_TAG) ;
        rcv = (id)cls ;
        rcvIsClass = YES ;
    } else if(luaL_testudata(L, rcvPos, ID_USERDATA_TAG) && !callAllocFirst) {
        rcv = get_objectFromUserdata(__bridge id, L, rcvPos, ID_USERDATA_TAG) ;
        cls = object_getClass(rcv) ;
        rcvIsClass = NO ;
    } else {
        luaL_checkudata(L, rcvPos, (callAllocFirst ? CLASS_USERDATA_TAG : ID_USERDATA_TAG)) ;
    }
    SEL sel = get_objectFromUserdata(SEL, L, selPos, SEL_USERDATA_TAG) ;

// TODO TEST: can you call msgSendSuper when receiver is a class?
    char *returnType  = method_copyReturnType((rcvIsClass ?
                                class_getClassMethod((callSuper ? class_getSuperclass(cls) : cls), sel) :
                                class_getInstanceMethod((callSuper ? class_getSuperclass(cls) : cls), sel))) ;

    if (!returnType)
        return luaL_error(L, "%s is not a%s method for %s", sel_getName(sel),
                            (rcvIsClass ? " class" : "n instance"), class_getName(cls)) ;

    char *messageHolder ;
    int jic = asprintf(&messageHolder, "[%s%s%s %s]",
                      (rcvIsClass ? "" : "<"),
                      (callSuper ? class_getName(class_getSuperclass(cls)) : class_getName(cls)),
                      (rcvIsClass ? "" : ">"),
                      sel_getName(sel)) ;
    if (jic == -1) messageHolder = "{error creating label}" ;

#ifdef DEBUG_msgSend
    lua_pushcfunction(L, info_to_console) ;
    lua_pushfstring(L, "%s = %s with %d arguments", returnType, messageHolder, argCount) ;
    lua_pcall(L, 1, 0, 0) ;
#endif

    if (callAllocFirst) { rcv = objc_msgSend(cls, @selector(alloc)) ; }

    UInt typePos ;
    switch(returnType[0]) {
        case 'r':   // const
        case 'n':   // in
        case 'N':   // inout
        case 'o':   // out
        case 'O':   // bycopy
        case 'R':   // byref
        case 'V':   // oneway
            typePos = 1 ; break ;
        default:
            typePos = 0 ; break ;
    }

    ffi_cif cif ;
    ffi_type **argTypes ;
    ffi_type *retType ;

// FIXME: This needs to change, but to prevent crashes related to missing args for now...
    argCount = 0 ;

    argTypes = malloc(sizeof(ffi_type *) * ((unsigned long)argCount + 2)) ;
    argTypes[0] = &ffi_type_pointer ;
    argTypes[1] = &ffi_type_pointer ;

    // do something to get the others, but for now lets assume we're sticking with no args

    switch(returnType[typePos]) {
        case 'c':
        case 'B': // C++ bool or a C99 _Bool
                  retType = &ffi_type_uchar ;   break ;
        case 'C': retType = &ffi_type_schar ;   break ;
        case 'i': retType = &ffi_type_uint ;    break ;
        case 'I': retType = &ffi_type_sint ;    break ;
        case 's': retType = &ffi_type_ushort ;  break ;
        case 'S': retType = &ffi_type_sshort ;  break ;
        case 'l': retType = &ffi_type_ulong ;   break ;
        case 'L': retType = &ffi_type_slong ;   break ;
        case 'q': retType = &ffi_type_uint64 ;  break ;
        case 'Q': retType = &ffi_type_sint64 ;  break ;
        case 'f': retType = &ffi_type_float ;   break ;
        case 'd': retType = &ffi_type_double ;  break ;
        case 'v': retType = &ffi_type_void ;    break ;
        case '*':     // char *
        case '@':     // id
        case '#':     // Class
        case ':':     // SEL
                  retType = &ffi_type_pointer ; break ;

    //  [array type]    An array
    //  {name=type...}  A structure
    //  (name=type...)  A union
    //  bnum            A bit field of num bits
    //  ^type           A pointer to type
    //  ?               An unknown type (among other things, this is used for function ptrs)
        default:
                  free(argTypes) ;
                  lua_pushcfunction(L, warn_to_console) ;
                  lua_pushfstring(L, "%s: %s return type not supported yet", messageHolder, returnType) ;
                  lua_pcall(L, 1, 0, 0) ;
                  lua_pushnil(L) ;
                  return 1 ;
                  break ;
    }

    ffi_status status = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (unsigned int)argCount + 2, retType, argTypes) ;
    switch(status) {
        case FFI_OK:
            break ;
        case FFI_BAD_TYPEDEF:
            return luaL_error(L, "ffi_prep_cif: bad type definition") ;
            break ;
        case FFI_BAD_ABI:
            return luaL_error(L, "ffi_prep_cif: bad ABI specification") ;
            break ;
        default:
            return luaL_error(L, "ffi_prep_cif: unknown error %d", status) ;
            break ;
    }

    struct objc_super superInfo ;
    struct objc_super *superPtr = &superInfo ;
    superInfo.receiver    = rcv ;
    superInfo.super_class = class_getSuperclass(cls) ;

    void **values ;
    values = malloc(sizeof(void *) * ((unsigned long)argCount + 2)) ;
    values[0] = callSuper ? (void *)&superPtr : (void *)&rcv ;
    values[1] = &sel ;

    @try {
        switch(returnType[typePos]) {
            case 'c': {    // char
                char result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                if (result == 0 || result == 1)
                    lua_pushboolean(L, result) ;
                else
                    lua_pushinteger(L, result) ;
                break ;
            }
            case 'C': {    // unsigned char
                unsigned char result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                lua_pushinteger(L, result) ;
                break ;
            }
            case 'i': {    // int
                int result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                lua_pushinteger(L, result) ;
                break ;
            }
            case 's': {    // short
                short result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                lua_pushinteger(L, result) ;
                break ;
            }
            case 'l': {    // long
                long result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                lua_pushinteger(L, result) ;
                break ;
            }
            case 'q':      // long long
            case 'Q': {    // unsigned long long (lua can't do unsigned long long; choose bits over magnitude)
                long long result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                lua_pushinteger(L, result) ;
                break ;
            }
            case 'I': {    // unsigned int
                unsigned int result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                lua_pushinteger(L, result) ;
                break ;
            }
            case 'S': {    // unsigned short
                unsigned short result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                lua_pushinteger(L, result) ;
                break ;
            }
            case 'L': {    // unsigned long
                unsigned long result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                lua_pushinteger(L, (lua_Integer)result) ;
                break ;
            }

            case 'f': {    // float
                float result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                lua_pushnumber(L, result) ;
                break ;
            }
            case 'd': {    // double
                double result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                lua_pushnumber(L, result) ;
                break ;
            }

            case 'B': {    // C++ bool or a C99 _Bool
                char result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                lua_pushboolean(L, result) ;
                break ;
            }

            case 'v': {    // void
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), NULL, values);
                lua_pushnil(L) ;
                break ;
            }

            case '*': {    // char *
                char *result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                lua_pushstring(L, result) ;
                break ;
            }

            case '@': {    // id
                id result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                push_object(L, result) ;
                break ;
            }

            case '#': {    // Class
                Class result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                push_class(L, result) ;
                break ;
            }

            case ':': {    // SEL
                SEL result ;
                ffi_call(&cif, (callSuper ? FFI_FN(objc_msgSendSuper) : FFI_FN(objc_msgSend)), &result, values);
                push_selector(L, result) ;
                break ;
            }

//     [array type]    An array
//     {name=type...}  A structure
//     (name=type...)  A union
//     bnum            A bit field of num bits
//     ^type           A pointer to type
//     ?               An unknown type (among other things, this code is used for function pointers)

            default:
                lua_pushcfunction(L, warn_to_console) ;
                lua_pushfstring(L, "%s: %s return type not supported yet", messageHolder, returnType) ;
                lua_pcall(L, 1, 0, 0) ;
                lua_pushnil(L) ;
                break ;
        }
    }
    @catch ( NSException *theException ) {
        return errorOnException(L, messageHolder, theException) ;
    }
    @finally { // yeah, the lual_error in errorOnException means these might not be freed until the lua state is reset, but they will be freed eventually.
        free(returnType) ;
        free(messageHolder) ;
        free(argTypes) ;
        free(values) ;
    }

    return 1 ;
}

// static int lua_FFISendSuper(lua_State *L) {
//     return luaL_error(L, "not implemented yet") ;
//     lua_pushinteger(L, 1) ;
//     lua_insert(L, 1) ;
//     lua_FFISend(L) ;
//     return 1 ;
// }
//
// static int lua_allocAndFFISend(lua_State *L) {
//     lua_pushinteger(L, 2) ;
//     lua_insert(L, 1) ;
//     lua_FFISend(L) ;
//     return 1 ;
// }
//
// static int lua_allocAndFFISendSuper(lua_State *L) {
//     return luaL_error(L, "not implemented yet") ;
//     lua_pushinteger(L, 3) ;
//     lua_insert(L, 1) ;
//     lua_FFISend(L) ;
//     return 1 ;
// }

static int lua_registerLogForC(__unused lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TTABLE, LS_TBREAK] ;
    logFnRef = [[LuaSkin shared] luaRef:refTable] ;
    return 0 ;
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

static luaL_Reg moduleLib[] = {
    {"objc_msgSend",              lua_FFISend},
//     {"objc_FFISendSuper",         lua_FFISendSuper},
//     {"objc_allocAndFFISend",      lua_allocAndFFISend},
//     {"objc_allocAndFFISendSuper", lua_allocAndFFISendSuper},
    {"imageNames",                objc_getImageNames},
    {"classNamesForImage",        objc_classNamesForImage},

    {"registerLogForC",           lua_registerLogForC},
    {NULL,                        NULL}
};

int luaopen_hs__asm_objc_internal(lua_State* L) {
    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ;

    logFnRef = LUA_NOREF ;

    lua_pushcfunction(L, tryToRegisterHandlers) ;
    if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
        printToConsole(L, (char *)lua_tostring(L, -1)) ;
        lua_pop(L, 1) ;
    }

    luaopen_hs__asm_objc_class(L) ;    lua_setfield(L, -2, "class") ;
    luaopen_hs__asm_objc_ivar(L) ;     lua_setfield(L, -2, "ivar") ;
    luaopen_hs__asm_objc_method(L) ;   lua_setfield(L, -2, "method") ;
    luaopen_hs__asm_objc_object(L) ;   lua_setfield(L, -2, "object") ;
    luaopen_hs__asm_objc_property(L) ; lua_setfield(L, -2, "property") ;
    luaopen_hs__asm_objc_protocol(L) ; lua_setfield(L, -2, "protocol") ;
    luaopen_hs__asm_objc_selector(L) ; lua_setfield(L, -2, "selector") ;

    return 1;
}
