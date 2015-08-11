#ifndef _OBJECTCONVERSION_STUFF
#define _OBJECTCONVERSION_STUFF

#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#define maxParseDepth 10

// structures to allow easily adding helper functions for new NSClasses as becomes necessary...

// Horked and modified from: http://dev-tricks.net/check-if-a-string-is-valid-utf8
// returns 0 if good utf8, anything else, barf
size_t is_utf8(unsigned char *str, size_t len) ;

// LUA -> NSObject

typedef id (*lua2nsFunction) (lua_State *L, int idx);
typedef struct lua2nsHelpers {
  const int      type;
  lua2nsFunction func;
} lua2nsHelpers;

extern id luanumber_tons(lua_State *L, int idx) ;
extern id luastring_tons(lua_State *L, int idx) ;
extern id luanil_tons(lua_State __unused *L, int __unused idx) ;
extern id luabool_tons(lua_State *L, int idx) ;
extern id luatable_tons(lua_State *L, int idx) ;
extern id luaunknown_tons(lua_State *L, int idx) ;

extern lua2nsHelpers luaobj_tons_helpers[] ;

extern id lua_toNSObject(lua_State* L, int idx) ;

// NSObject -> LUA

typedef int (*ns2luaFunction) (lua_State *L, id obj);
typedef struct ns2luaHelpers {
  const char     *name;
  ns2luaFunction  func;
} ns2luaHelpers;


extern int nsnull_tolua(lua_State *L, __unused id obj) ;
extern int nsnumber_tolua(lua_State *L, id obj) ;
extern int nsstring_tolua(lua_State *L, id obj) ;
extern int nsdata_tolua(lua_State *L, id obj) ;
extern int nsdate_tolua(lua_State *L, id obj) ;
extern int nsarray_tolua(lua_State *L, id obj) ;
extern int nsset_tolua(lua_State *L, id obj) ;
extern int nsdictionary_tolua(lua_State *L, id obj) ;
extern int nsunknown_tolua(lua_State *L, id obj) ;

extern ns2luaHelpers nsobj_tolua_helpers[] ;

extern int NSObject_tolua(lua_State *L, id obj) ;

#endif
