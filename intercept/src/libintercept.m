@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.intercept" ;
static LSRefTable         refTable     = LUA_NOREF ;

#pragma mark - Support Functions

static lua_State *globalL     = NULL ;
static lua_Hook  curHook      = NULL ;
static int       curHookCount = 0 ;
static int       curHookMask  = 0 ;

/*
** Use 'sigaction' when available.
*/
static void setsignal (int sig, void (*handler)(int)) {
  struct sigaction sa;
  sa.sa_handler = handler;
  sa.sa_flags = 0;
  sigemptyset(&sa.sa_mask);  /* do not mask any signal */
  sigaction(sig, &sa, NULL);
}

/*
** Hook set by signal function to stop the interpreter.
*/
static void lstop(lua_State *L, __unused lua_Debug *ar) {
//   (void)ar ;  /* unused arg. */
  lua_sethook(L, curHook, curHookMask, curHookCount) ;  /* reset hook */
  luaL_error(L, "interrupted!") ;
}

/*
** Function to be called at a C signal. Because a C signal cannot
** just change a Lua state (as there is no proper synchronization),
** this function only sets a hook that, when called, will stop the
** interpreter.
*/
static void laction(int i) {
    int flag = LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE | LUA_MASKCOUNT ;
    setsignal(i, SIG_DFL) ; /* if another SIGINT happens, terminate process */

    curHook      = lua_gethook(globalL) ;
    curHookCount = lua_gethookcount(globalL) ;
    curHookMask  = lua_gethookmask(globalL) ;

    lua_sethook(globalL, lstop, flag, 1) ;
}

#pragma mark - Module Functions

static int intercept_enable(lua_State *L) {
    globalL = L;  /* to be available to 'laction' */
    setsignal(SIGINT, laction);  /* set C-signal handler */
    return 0 ;
}

static int intercept_disable(__unused lua_State *L) {
    setsignal(SIGINT, SIG_DFL); /* reset C-signal handler */
    return 0 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"enable",  intercept_enable},
    {"disable", intercept_disable},
    {NULL,      NULL}
} ;

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", intercept_disable},
    {NULL,   NULL}
} ;

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_libintercept(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:USERDATA_TAG
                           functions:moduleLib
                       metaFunctions:module_metaLib] ;

    return 1;
}
