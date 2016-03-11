/// === hs._asm.objc.class ===
///
/// The submodule for hs._asm.objc which provides methods for working with and examining Objective-C classes.

#import "objc.h"

static int refTable = LUA_NOREF;

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

/// hs._asm.objc.class.fromString(name) -> classObject
/// Constructor
/// Returns a class object for the named class
///
/// Parameters:
///  * name - a string containing the name of the desired class
///
/// Returns:
///  * the class object for the name specified or nil if a class with the specified name does not exist
///
/// Notes:
///  * This constructor has also been assigned to the __call metamethod of the `hs._asm.objc.class` sub-module so that it can be invoked as `hs._asm.objc.class(name)` as a shortcut.
static int objc_classFromString(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    Class cls = (Class)objc_lookUpClass(luaL_checkstring(L, 1)) ;

    push_class(L, cls) ;
    return 1 ;
}

/// hs._asm.objc.class.list() -> table
/// Function
/// Returns a list of all currently available classes
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table of all currently available classes as key-value pairs.  The key is the class name as a string and the value for each key is the classObject for the named class.
static int objc_classList(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;

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
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;

    Class meta = (Class)objc_getMetaClass(class_getName(cls)) ;
    push_class(L, meta) ;
    return 1 ;
}

static int objc_class_getMethodList(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
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
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG,
                                LS_TUSERDATA, SEL_USERDATA_TAG,
                                LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    SEL sel = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;

    lua_pushboolean(L, class_respondsToSelector(cls, sel)) ;
    return 1 ;
}

static int objc_class_getInstanceMethod(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG,
                                LS_TUSERDATA, SEL_USERDATA_TAG,
                                LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    SEL sel = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;

    push_method(L, class_getInstanceMethod(cls, sel)) ;
    return 1 ;
}

static int objc_class_getClassMethod(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG,
                                LS_TUSERDATA, SEL_USERDATA_TAG,
                                LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    SEL sel = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;

    push_method(L, class_getClassMethod(cls, sel)) ;
    return 1 ;
}

static int objc_class_getInstanceSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushinteger(L, (lua_Integer)class_getInstanceSize(cls)) ;
    return 1 ;
}

static int objc_class_getName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushstring(L, class_getName(cls)) ;
    return 1 ;
}

static int objc_class_getIvarLayout(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushstring(L, (const char *)class_getIvarLayout(cls)) ;
    return 1 ;
}

static int objc_class_getWeakIvarLayout(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushstring(L, (const char *)class_getWeakIvarLayout(cls)) ;
    return 1 ;
}

static int objc_class_getImageName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushstring(L, class_getImageName(cls)) ;
    return 1 ;
}

static int objc_class_isMetaClass(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushboolean(L, class_isMetaClass(cls)) ;
    return 1 ;
}

static int objc_class_getSuperClass(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    push_class(L, class_getSuperclass(cls)) ;
    return 1 ;
}

static int objc_class_getVersion(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    lua_pushinteger(L, (lua_Integer)class_getVersion(cls)) ;
    return 1 ;
}

static int objc_class_getPropertyList(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
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
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    push_property(L, class_getProperty(cls, luaL_checkstring(L, 2))) ;
    return 1 ;
}

static int objc_class_getIvarList(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
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
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    push_ivar(L, class_getInstanceVariable(cls, luaL_checkstring(L, 2))) ;
    return 1 ;
}

static int objc_class_getClassVariable(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    Class cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    push_ivar(L, class_getClassVariable(cls, luaL_checkstring(L, 2))) ;
    return 1 ;
}

static int objc_class_getAdoptedProtocols(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG, LS_TBREAK] ;
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
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG,
                                LS_TUSERDATA, PROTOCOL_USERDATA_TAG, LS_TBREAK] ;
    Class    cls = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    Protocol *prot = get_objectFromUserdata(__bridge Protocol *, L, 2, PROTOCOL_USERDATA_TAG) ;

    lua_pushboolean(L, class_conformsToProtocol(cls, prot)) ;
    return 1 ;
}

static int class_signatureForMethod(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CLASS_USERDATA_TAG,
                    LS_TUSERDATA, SEL_USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    Class    cls        = get_objectFromUserdata(__bridge Class, L, 1, CLASS_USERDATA_TAG) ;
    SEL      sel        = get_objectFromUserdata(SEL, L, 2, SEL_USERDATA_TAG) ;
    BOOL     classCheck = NO ;

    if (lua_type(L, 3) != LUA_TNONE) classCheck = (BOOL)lua_toboolean(L, 3) ;

    [skin pushNSObject:(classCheck) ? [cls methodSignatureForSelector:sel] :
                                      [cls instanceMethodSignatureForSelector:sel]] ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions

int push_class(lua_State *L, Class cls) {
#if defined(DEBUG_GC)
    [[LuaSkin shared] logDebug:[NSString stringWithFormat:@"class: create %@ (%p)", NSStringFromClass(cls), cls]] ;
#endif
    if (cls) {
        void** thePtr = lua_newuserdata(L, sizeof(Class)) ;
        *thePtr = (__bridge void *)cls ;
        luaL_getmetatable(L, CLASS_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

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
#if defined(DEBUG_GC)
    [[LuaSkin shared] logDebug:[NSString stringWithFormat:@"class: remove %@ (%p)", NSStringFromClass(cls), cls]] ;
#endif

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
    {"imageName",          objc_class_getImageName},
    {"instanceSize",       objc_class_getInstanceSize},
    {"ivarLayout",         objc_class_getIvarLayout},
    {"name",               objc_class_getName},
    {"superclass",         objc_class_getSuperClass},
    {"weakIvarLayout",     objc_class_getWeakIvarLayout},
    {"isMetaClass",        objc_class_isMetaClass},
    {"version",            objc_class_getVersion},
    {"propertyList",       objc_class_getPropertyList},
    {"property",           objc_class_getProperty},
    {"ivarList",           objc_class_getIvarList},
    {"instanceVariable",   objc_class_getInstanceVariable},
    {"classVariable",      objc_class_getClassVariable},
    {"adoptedProtocols",   objc_class_getAdoptedProtocols},
    {"conformsToProtocol", objc_class_conformsToProtocol},
    {"methodList",         objc_class_getMethodList},
    {"respondsToSelector", objc_class_respondsToSelector},
    {"instanceMethod",     objc_class_getInstanceMethod},
    {"classMethod",        objc_class_getClassMethod},
    {"metaClass",          objc_class_getMetaClass},
    {"signatureForMethod", class_signatureForMethod},

    {"__tostring",         class_userdata_tostring},
    {"__eq",               class_userdata_eq},
    {"__gc",               class_userdata_gc},
    {NULL,                 NULL}
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
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:CLASS_USERDATA_TAG
                                     functions:class_moduleLib
                                 metaFunctions:nil // class_module_metaLib
                               objectFunctions:class_userdata_metaLib];
    return 1;
}
