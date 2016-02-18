#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG "hs._asm.luathread"
static int          refTable = LUA_NOREF;
static NSDictionary *assignmentsFromParent ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static int pushHSASMLuaThread(lua_State *L, id obj) ;
static id toHSASMLuaThreadFromLua(lua_State *L, int idx) ;

// Thread specific userdata methods
static int threadCancelled(lua_State *L) ;
static int returnString(lua_State *L) ;

// Methods used by both
static int threadName(lua_State *L) ;
static int submitString(lua_State *L) ;
static int cancelThread(lua_State *L) ;

static int userdata_tostring(lua_State* L) ;
static int userdata_eq(lua_State* L) ;
static int userdata_gc(lua_State* L) ;

static const luaL_Reg thread_userdata_metaLib[] = {
    {"cancel",      cancelThread},
    {"name",        threadName},
    {"isCancelled", threadCancelled},
    {"submit",      submitString},
    {"print",       returnString},

    {"__tostring",  userdata_tostring},
    {"__eq",        userdata_eq},
    {"__gc",        userdata_gc},
    {NULL,          NULL}
};

