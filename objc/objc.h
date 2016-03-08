@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC ;

#define DEBUG_msgSend
// #define DEBUG_GC
// #define DEBUG_GC_OBJONLY

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

int luaopen_hs__asm_objc_class(lua_State* L) ;
int luaopen_hs__asm_objc_ivar(lua_State* L) ;
int luaopen_hs__asm_objc_method(lua_State* L) ;
int luaopen_hs__asm_objc_object(lua_State* L) ;
int luaopen_hs__asm_objc_property(lua_State* L) ;
int luaopen_hs__asm_objc_protocol(lua_State* L) ;
int luaopen_hs__asm_objc_selector(lua_State* L) ;

int push_class(lua_State *L, Class cls) ;
int push_ivar(lua_State *L, Ivar iv) ;
int push_method(lua_State *L, Method meth) ;
int push_object(lua_State *L, id obj) ;
int push_property(lua_State *L, objc_property_t prop) ;
int push_protocol(lua_State *L, Protocol *prot) ;
int push_selector(lua_State *L, SEL sel) ;
