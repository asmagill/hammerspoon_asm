#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
// #import "../hammerspoon.h"

#define USERDATA_TAG "hs._asm.service"
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_cfobjectFromUserdata(objType, L, idx) *((objType*)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

@interface HSServiceObject : NSObject
@property            NSString* providerName ;
@property            int       selfRef ;
@property            int       callbackRef ;
@property (readonly) NSString* errorHolder ;
@end

@implementation HSServiceObject

- (instancetype)initWithName:(NSString *)providerName {
    self = [super init] ;
    if (self) {
        _providerName = providerName ;
        _selfRef      = LUA_NOREF ;
        _callbackRef  = LUA_NOREF ;
        _errorHolder  = nil ;
    }
    return self ;
}

- (void)registerServiceProver {
    NSRegisterServicesProvider(self, _providerName);
    NSUpdateDynamicServices();
}

- (void)unregisterServiceProvider {
    NSUnregisterServicesProvider(_providerName);
    NSUpdateDynamicServices();
}

- (void)serviceSelectorOnMainThread:(NSPasteboard *)pboard {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin logWarn:@"in serviceSelectorOnMainThread"] ;
    [skin pushLuaRef:refTable ref:_callbackRef] ;
    [skin pushNSObject:[pboard name]] ;
    [skin protectedCallAndTraceback:1 nresults:1] ;
    // success or no, if it's a string, it's an error, either in the callback or in the service handling
    if (lua_type([skin L], -1) == LUA_TSTRING) {
        _errorHolder = [skin toNSObjectAtIndex:-1] ;
        [skin logError:_errorHolder] ;
    }
    lua_pop([skin L], 1) ;
}

- (void)serviceSelector:(NSPasteboard *)pboard
               userData:(__unused NSString *)userData
                  error:(NSString **)error {

    if (_callbackRef != LUA_NOREF) {
        _errorHolder = nil ;
        [self performSelectorOnMainThread:@selector(serviceSelectorOnMainThread:)
                               withObject:pboard
                            waitUntilDone:YES] ;
        if (_errorHolder) *error = _errorHolder ;
        _errorHolder = nil ;
    }
}

//     Test for strings on the pasteboard.
//     NSArray *classes = [NSArray arrayWithObject:[NSString class]];
//     NSDictionary *options = [NSDictionary dictionary];
//
//     if (![pboard canReadObjectForClasses:classes options:options]) {
//          *error = @"hammerspoonAsService:pasteboard does not contain text.";
//          return;
//     }
//
//     NSString *pboardString = [pboard stringForType:NSPasteboardTypeString];
//     NSString *newString    = MJLuaRunString(pboardString) ;
//     if (!newString) {
//          *error = @"hammerspoonAsService:MJLuaRunString returned nil";
//          return;
//     }
//
//     [pboard clearContents];
//     [pboard writeObjects:[NSArray arrayWithObject:newString]];
// }

@end

#pragma mark - Module Functions

// BOOL NSPerformService ( NSString *itemName, NSPasteboard *pboard );

static int newServiceProvider(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    HSServiceObject *obj = [[HSServiceObject alloc] initWithName:[skin toNSObjectAtIndex:1]] ;
    [skin pushNSObject:obj] ;
    return 1 ;
}

#pragma mark - Module Methods

static int setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    HSServiceObject *obj = [skin luaObjectAtIndex:1 toClass:"HSServiceObject"] ;

    obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        obj.callbackRef = [skin luaRef:refTable];
        if (obj.selfRef == LUA_NOREF) {
            lua_pushvalue(L, 1) ;
            obj.selfRef = [skin luaRef:refTable] ;
            [obj registerServiceProver] ;
        }
    } else {
        obj.selfRef = [skin luaUnref:refTable ref:obj.selfRef] ;
        [obj unregisterServiceProvider] ;
    }
    lua_pushvalue(L, 1);
    return 1;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSServiceObject(lua_State *L, id obj) {
    HSServiceObject *value = obj;
    if (value.selfRef == LUA_NOREF) {
        void** valuePtr = lua_newuserdata(L, sizeof(HSServiceObject *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
    } else {
        [[LuaSkin shared] pushLuaRef:refTable ref:value.selfRef] ;
    }
    return 1;
}

id toHSServiceObjectFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSServiceObject *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSServiceObject, L, idx) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSServiceObject *obj = [skin luaObjectAtIndex:1 toClass:"HSServiceObject"] ;
    NSString *title = [obj providerName] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSServiceObject *obj1 = [skin luaObjectAtIndex:1 toClass:"HSServiceObject"] ;
        HSServiceObject *obj2 = [skin luaObjectAtIndex:2 toClass:"HSServiceObject"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSServiceObject *obj = get_objectFromUserdata(__bridge_transfer HSServiceObject, L, 1) ;
    if (obj) {
        LuaSkin *skin = [LuaSkin shared] ;
        obj.selfRef     = [skin luaUnref:refTable ref:obj.selfRef] ;
        obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
        [obj unregisterServiceProvider] ;
        obj = nil ;
    }
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
    {"setCallback", setCallback},

    {"__tostring",  userdata_tostring},
    {"__eq",        userdata_eq},
    {"__gc",        userdata_gc},
    {NULL,          NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", newServiceProvider},

    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_service_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSServiceObject         forClass:"HSServiceObject"];
    [skin registerLuaObjectHelper:toHSServiceObjectFromLua forClass:"HSServiceObject"];

    return 1;
}
