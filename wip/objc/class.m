#import <Cocoa/Cocoa.h>
// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"
#import "objc.h"

static int refTable ;

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

static int userdata_tostring(lua_State* L) {
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", CLASS_USERDATA_TAG, class_getName(cls), cls) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    Class cls1 = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    Class cls2 = get_objectFromUserdata(__bridge Class, L, 2, CLASS_USERDATA_TAG) ;
    lua_pushboolean(L, (cls1 == cls2)) ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
// since we don't retain, we don't need to transfer, but this does check to make sure we're
// not called with the wrong type for some reason...
    __unused Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;

// Clear the pointer so it's no longer dangling
    void** thePtr = lua_touserdata(L, 1);
    *thePtr = nil ;

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

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"fromString", objc_classFromString},
    {"list",       objc_classList},

    {NULL,         NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_objc_class(lua_State* __unused L) {
// Use this if your module doesn't have a module specific object that it returns.
//    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [[LuaSkin shared] registerLibraryWithObject:CLASS_USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

    return 1;
}
