#import <objc/runtime.h>

#define ROOT_USERDATA_TAG               "hs._asm.objc"

#define CLASS_USERDATA_TAG              ROOT_USERDATA_TAG ".class"
#define PROPERTY_USERDATA_TAG           ROOT_USERDATA_TAG ".property"
#define IVAR_USERDATA_TAG               ROOT_USERDATA_TAG ".ivar"
#define PROTOCOL_USERDATA_TAG           ROOT_USERDATA_TAG ".protocol"
#define METHOD_USERDATA_TAG             ROOT_USERDATA_TAG ".method"
#define SEL_USERDATA_TAG                ROOT_USERDATA_TAG ".selector"

#define ID_USERDATA_TAG                 ROOT_USERDATA_TAG ".id"

// #define CATEGORY_USERDATA_TAG           ROOT_USERDATA_TAG ".category"
// #define IMP_USERDATA_TAG                ROOT_USERDATA_TAG ".imp"

#define get_objectFromUserdata(objType, L, idx, tag) ((objType)(*((void**)luaL_checkudata(L, idx, tag))))

int push_class(lua_State *L, Class cls) {
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

int push_property(lua_State *L, objc_property_t prop) {
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

int push_ivar(lua_State *L, Ivar iv) {
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

int push_protocol(lua_State *L, Protocol *prot) {
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

int push_method(lua_State *L, Method meth) {
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

int push_selector(lua_State *L, SEL selector) {
    if (selector) {
        void** thePtr = lua_newuserdata(L, sizeof(SEL)) ;
        *thePtr = (void *)selector ;
        luaL_getmetatable(L, SEL_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

