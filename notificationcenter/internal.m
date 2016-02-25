#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG    "hs._asm.notificationcenter"

@interface HSNotificationCenterClass : NSObject
    @property int                  fn;
    @property NSNotificationCenter *whichCenter ;
    @property NSString             *notificationName ;
    @property NSThread             *myMainThread ;
@end

@implementation HSNotificationCenterClass
    - (void) _heard:(id)note {

        [self performSelector:@selector(heard:)
                     onThread:_myMainThread
                   withObject:note
                waitUntilDone:YES];
//         [self performSelectorOnMainThread:@selector(heard:)
//                                             withObject:note
//                                             waitUntilDone:YES];
    }

    - (void) heard:(NSNotification*)note {
        if (self.fn != LUA_NOREF) {
            LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                               [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
//             LuaSkin *skin = [LuaSkin shared] ;
            lua_State *_L = [skin L];
            lua_rawgeti(_L, LUA_REGISTRYINDEX, self.fn);
            lua_pushstring(_L, [[note name] UTF8String]);
            if ([[note object] isKindOfClass:[NSWorkspace class]]) {
                [skin pushNSObject:[[note object] debugDescription]] ;
            } else {
                [skin pushNSObject:[note object] withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
            }
            [skin pushNSObject:[note userInfo] withOptions:LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits] ;
            if (![skin protectedCallAndTraceback:3 nresults:0]) {
                const char *errorMsg = lua_tostring(_L, -1);
                [skin logError:[NSString stringWithFormat:@"%s", errorMsg]] ;
                lua_pop(_L, 1) ;
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
    listener.myMainThread     = [NSThread currentThread] ;

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
/// Registers a notification observer for notifications sent to the shared workspace.
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

/// hs._asm.notificationcenter.internalObserver(fn, name) -> notificationcenter
/// Constructor
/// Registers a notification observer for notifications sent within Hammerspoon itself.
///
/// Parameters:
///  * fn - the callback function to associate with this listener.  The function will receive 3 parameters:
///    * name - a string giving the name of the notification received
///    * object - a table containing information about the notification received
///    * userinfo - an optional table containing information attached to the notification reveived
///  * name - a required parameter specifying the name of the message you wish to listen for.
///
/// Returns:
///  * a notificationcenter object
///
/// Notes:
///  * Listening for all inter-application messages will cause Hammerspoon to bog down completely (not to mention generate its own, thus adding to the mayhem), so the name of the message to listen for is required for this version of the contructor.
///  * Currently this specific constructor is of limited use outside of development and testing, since there is no current way to programmatically send specific messages outside of the internal messaging that all Objective-C applications perform or specify specific objects within Hammerspoon to observe.  Consideration is being given to methods which will allow posting ad-hoc messages and may make this more useful outside of its currently limited scope.
static int nc_internalObserver(lua_State* L) {
    luaL_checktype(L, 2, LUA_TSTRING) ;
    return commonObserverConstruction(L, [NSNotificationCenter defaultCenter]) ;
}

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
    {"internalObserver",    nc_internalObserver},
    {"workspaceObserver",   nc_workspaceObserver},
    {"distributedObserver", nc_distributedObserver},
    {NULL,      NULL}
};

int luaopen_hs__asm_notificationcenter_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
//     LuaSkin *skin = [LuaSkin shared] ;
    [skin registerLibraryWithObject:USERDATA_TAG
                          functions:notificationcenterLib
                      metaFunctions:nil
                    objectFunctions:notificationcenter_metalib];

    return 1;
}
