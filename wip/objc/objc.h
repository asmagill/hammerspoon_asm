#import <objc/runtime.h>

#define EXPORT __attribute__((visibility("default")))

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

static int push_class(lua_State *L, Class cls) ;
static int push_ivar(lua_State *L, Ivar iv) ;
static int push_method(lua_State *L, Method meth) ;
static int push_property(lua_State *L, objc_property_t prop) ;
static int push_protocol(lua_State *L, Protocol *prot) ;
static int push_selector(lua_State *L, SEL sel) ;
