#import "diskarbitration.h"

static const char * const USERDATA_TAG = "hs._asm.diskarbitration" ;
static int refTable = LUA_NOREF;

DASessionRef arbitrationSession = NULL ;

// #define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

// typedef NS_ENUM(NSInteger, ASMdiskArbitrationType) {
//     diskAppeared,
//     diskDescriptionChanged,
//     diskDisappeared,
//     diskEjectApproval,
//     diskMountApproval,
//     diskPeek,
//     diskUnmountApproval
// } ;
//
// @interface ASMdiskArbitrationWatcher : NSObject
// @property int                    callbackRef ;
// @property ASMdiskArbitrationType type ;
// @end
//
// @implementation ASMdiskArbitrationWatcher
// @end

#pragma mark - Module Functions

// typedef void ( *DADiskAppearedCallback )( DADiskRef disk, void * __nullable context );
// extern void DARegisterDiskAppearedCallback( DASessionRef               session,
//                                             CFDictionaryRef __nullable match,
//                                             DADiskAppearedCallback     callback,
//                                             void * __nullable          context );

// typedef void ( *DADiskDescriptionChangedCallback )( DADiskRef disk, CFArrayRef keys, void * __nullable context );
// extern void DARegisterDiskDescriptionChangedCallback( DASessionRef                     session,
//                                                       CFDictionaryRef __nullable       match,
//                                                       CFArrayRef __nullable            watch,
//                                                       DADiskDescriptionChangedCallback callback,
//                                                       void * __nullable                context );

// typedef void ( *DADiskDisappearedCallback )( DADiskRef disk, void * __nullable context );
// extern void DARegisterDiskDisappearedCallback( DASessionRef               session,
//                                                CFDictionaryRef __nullable match,
//                                                DADiskDisappearedCallback  callback,
//                                                void * __nullable          context );

// typedef DADissenterRef __nullable ( *DADiskMountApprovalCallback )( DADiskRef disk, void * __nullable context );
// extern void DARegisterDiskMountApprovalCallback( DASessionRef                session,
//                                                  CFDictionaryRef __nullable  match,
//                                                  DADiskMountApprovalCallback callback,
//                                                  void * __nullable           context );
//

// typedef DADissenterRef __nullable ( *DADiskUnmountApprovalCallback )( DADiskRef disk, void * __nullable context );
// extern void DARegisterDiskUnmountApprovalCallback( DASessionRef                  session,
//                                                    CFDictionaryRef __nullable    match,
//                                                    DADiskUnmountApprovalCallback callback,
//                                                    void * __nullable             context );

// typedef DADissenterRef __nullable ( *DADiskEjectApprovalCallback )( DADiskRef disk, void * __nullable context );
// extern void DARegisterDiskEjectApprovalCallback( DASessionRef                session,
//                                                  CFDictionaryRef __nullable  match,
//                                                  DADiskEjectApprovalCallback callback,
//                                                  void * __nullable           context );

// typedef void ( *DADiskPeekCallback )( DADiskRef disk, void * __nullable context );
// extern void DARegisterDiskPeekCallback( DASessionRef               session,
//                                         CFDictionaryRef __nullable match,
//                                         CFIndex                    order,
//                                         DADiskPeekCallback         callback,
//                                         void * __nullable          context );
//

// extern void DAUnregisterCallback( DASessionRef session, void * callback, void * __nullable context );

#pragma mark - Module Methods

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

// static int push<moduleType>(lua_State *L, id obj) {
//     <moduleType> *value = obj;
//     value.selfRefCount++ ;
//     void** valuePtr = lua_newuserdata(L, sizeof(<moduleType> *));
//     *valuePtr = (__bridge_retained void *)value;
//     luaL_getmetatable(L, USERDATA_TAG);
//     lua_setmetatable(L, -2);
//     return 1;
// }
//
// id to<moduleType>FromLua(lua_State *L, int idx) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     <moduleType> *value ;
//     if (luaL_testudata(L, idx, USERDATA_TAG)) {
//         value = get_objectFromUserdata(__bridge <moduleType>, L, idx, USERDATA_TAG) ;
//     } else {
//         [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
//                                                    lua_typename(L, lua_type(L, idx))]] ;
//     }
//     return value ;
// }

#pragma mark - Hammerspoon/Lua Infrastructure

// static int userdata_tostring(lua_State* L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     <moduleType> *obj = [skin luaObjectAtIndex:1 toClass:"<moduleType>"] ;
//     NSString *title = ... ;
//     [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
//     return 1 ;
// }

// static int userdata_eq(lua_State* L) {
// // can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// // so use luaL_testudata before the macro causes a lua error
//     if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
//         LuaSkin *skin = [LuaSkin shared] ;
//         <moduleType> *obj1 = [skin luaObjectAtIndex:1 toClass:"<moduleType>"] ;
//         <moduleType> *obj2 = [skin luaObjectAtIndex:2 toClass:"<moduleType>"] ;
//         lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
//     } else {
//         lua_pushboolean(L, NO) ;
//     }
//     return 1 ;
// }

// static int userdata_gc(lua_State* L) {
//     <moduleType> *obj = get_objectFromUserdata(__bridge_transfer <moduleType>, L, 1, USERDATA_TAG) ;
//     if (obj) {
//         obj.selfRefCount-- ;
//         if (obj.selfRefCount == 0) {
//             obj = nil ;
//         }
//     }
//     // Remove the Metatable so future use of the variable in Lua won't think its valid
//     lua_pushnil(L) ;
//     lua_setmetatable(L, 1) ;
//     return 0 ;
// }

static int meta_gc(lua_State* __unused L) {
    if (arbitrationSession) {
        DASessionUnscheduleFromRunLoop(arbitrationSession, CFRunLoopGetCurrent(), kCFRunLoopCommonModes) ;
        CFRelease(arbitrationSession) ;
        arbitrationSession = NULL ;
    }
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
//     {"__tostring", userdata_tostring},
//     {"__eq",       userdata_eq},
//     {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {NULL, NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs__asm_diskarbitration_internal(lua_State* L) {
    arbitrationSession = DASessionCreate(kCFAllocatorDefault) ;
    if (arbitrationSession) {
        DASessionScheduleWithRunLoop(arbitrationSession, CFRunLoopGetCurrent(), kCFRunLoopCommonModes) ;
    } else {
        return luaL_error(L, "%s - unable to establish session with DiskArbitration framework", USERDATA_TAG) ;
    }

    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    luaopen_hs__asm_diskarbitration_disk(L) ;
    lua_setfield(L, -2, "disk") ;

//     [skin registerPushNSHelper:push<moduleType>         forClass:"<moduleType>"];

// // one, but not both, of...
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"
//                                              withUserdataMapping:USERDATA_TAG];
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"];

    return 1;
}
