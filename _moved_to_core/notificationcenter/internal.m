#import <Cocoa/Cocoa.h>

#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#define USERDATA_TAG    "hs._asm.notificationcenter"

@interface HSNotificationCenterClass : NSObject
    @property int fn;
    @property NSNotificationCenter *whichCenter ;
    @property NSString *notificationName ;
@end

@implementation HSNotificationCenterClass
    - (void) _heard:(id)note {
        [self performSelectorOnMainThread:@selector(heard:)
                                            withObject:note
                                            waitUntilDone:YES];
    }

    - (void) heard:(NSNotification*)note {
        if (self.fn != LUA_NOREF) {
            lua_State *_L = [[LuaSkin shared] L];
            lua_rawgeti(_L, LUA_REGISTRYINDEX, self.fn);
            lua_pushstring(_L, [[note name] UTF8String]);
            [[LuaSkin shared] pushNSObject:[note object]] ;
            [[LuaSkin shared] pushNSObject:[note userInfo]] ;
            if (![[LuaSkin shared] protectedCallAndTraceback:3 nresults:0]) {
                const char *errorMsg = lua_tostring(_L, -1);
                showError(_L, (char *)errorMsg);
            }
        }
    }
@end

static int commonObserverConstruction(lua_State *L, NSNotificationCenter *nc) {
    NSString *notificationName ;

    luaL_checktype(L, 1, LUA_TFUNCTION);
    if (lua_isstring(L, 2)) {
        notificationName = [NSString stringWithUTF8String:luaL_checkstring(L, 2)] ;
    }

    HSNotificationCenterClass* listener = [[HSNotificationCenterClass alloc] init];

    lua_pushvalue(L, 1);
    listener.fn               = luaL_ref(L, LUA_REGISTRYINDEX) ;
    listener.whichCenter      = nc ;
    listener.notificationName = notificationName ;

    void** ud = lua_newuserdata(L, sizeof(id*)) ;
    *ud = (__bridge_retained void*)listener ;

    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;

    return 1;
}

/// hs._asm.notificationcenter.distributedObserver(fn, [name]) -> notificationcenter
/// Constructor
/// Registers a notification observer for distributed (Intra-Application) notifications.
///
/// Parameters:
///  * fn - the callback function to associate with this listener.  The function will receive 3 parameters:
///    * name - a string giving the name of the notification received
///    * object - a table containing information about the notification received
///    * userinfo - an optional table containing information attached to the notification reveived
///  * name - an optional parameter specifying the name of the message you wish to listen for.  If nil or left out, all received notifications will be observed.
///
/// Returns:
///  * a notificationcenter object
static int nc_distributedObserver(lua_State* L) {
    return commonObserverConstruction(L, [NSDistributedNotificationCenter defaultCenter]) ;
}

/// hs._asm.notificationcenter.workspaceObserver(fn, [name]) -> notificationcenter
/// Constructor
/// Registers a notification observer for notifications sent Hammerspoon's shared workspace.
///
/// Parameters:
///  * fn - the callback function to associate with this listener.  The function will receive 3 parameters:
///    * name - a string giving the name of the notification received
///    * object - a table containing information about the notification received
///    * userinfo - an optional table containing information attached to the notification reveived
///  * name - an optional parameter specifying the name of the message you wish to listen for.  If nil or left out, all received notifications will be observed.
///
/// Returns:
///  * a notificationcenter object
static int nc_workspaceObserver(lua_State* L) {
        return commonObserverConstruction(L, [[NSWorkspace sharedWorkspace] notificationCenter]) ;
}

// /// hs._asm.notificationcenter.internalObserver(fn, name) -> notificationcenter
// /// Constructor
// /// Registers a notification observer for notifications sent from within Hammerspoon itself.
// ///
// /// Parameters:
// ///  * fn - the callback function to associate with this listener.  The function will receive 3 parameters:
// ///    * name - a string giving the name of the notification received
// ///    * object - a table containing information about the notification received
// ///    * userinfo - an optional table containing information attached to the notification reveived
// ///  * name - a required parameter specifying the name of the message you wish to listen for.
// ///
// /// Returns:
// ///  * a notificationcenter object
// ///
// /// Notes:
// ///  * I'm not sure how useful this will be until support is added for creating and posting our own messages to the various message centers.
// ///  * Listening for all inter-application messages will cause Hammerspoon to bog down completely, so the name of the message to listen for is required for this version of the contructor.
// static int nc_internalObserver(lua_State* L) {
//     luaL_checktype(L, 2, LUA_TSTRING) ;
//     return commonObserverConstruction(L, [NSNotificationCenter defaultCenter]) ;
// }

/// hs._asm.notificationcenter:start()
/// Method
/// Starts listening for notifications.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the notificationcenter object
static int notificationcenter_start(lua_State* L) {
    HSNotificationCenterClass* listener = (__bridge HSNotificationCenterClass*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    [listener.whichCenter addObserver:listener
                             selector:@selector(_heard:)
                                 name:listener.notificationName
                               object:nil];
    lua_settop(L,1);
    return 1;
}

/// hs._asm.notificationcenter:stop()
/// Method
/// Stops listening for notifications.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the notificationcenter object
static int notificationcenter_stop(lua_State* L) {
    HSNotificationCenterClass* listener = (__bridge HSNotificationCenterClass*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    [listener.whichCenter removeObserver:listener];

    lua_settop(L,1);
    return 1;
}

static int notificationcenter_gc(lua_State* L) {
    HSNotificationCenterClass* listener = (__bridge_transfer HSNotificationCenterClass*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    [listener.whichCenter removeObserver:listener];

    listener = nil ;
    return 0;
}

// Metatable for created objects when _new invoked
static const luaL_Reg notificationcenter_metalib[] = {
    {"start",   notificationcenter_start},
    {"stop",    notificationcenter_stop},
    {"__gc",    notificationcenter_gc},
    {NULL,      NULL}
};

// Functions for returned object when module loads
static const luaL_Reg notificationcenterLib[] = {
//     {"internalObserver",    nc_internalObserver},
    {"workspaceObserver",   nc_workspaceObserver},
    {"distributedObserver", nc_distributedObserver},
    {NULL,      NULL}
};

int luaopen_hs__asm_notificationcenter_internal(lua_State* __unused L) {
    [[LuaSkin shared] registerLibraryWithObject:USERDATA_TAG
                                      functions:notificationcenterLib
                                  metaFunctions:nil
                                objectFunctions:notificationcenter_metalib];
    return 1;
}
