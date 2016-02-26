#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG    "hs._asm.notificationcenter"
// Modules which support luathread have to store refTable in the threadDictionary rather than a static
// static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSNotificationCenterClass : NSObject
    @property int                  fn;
    @property NSNotificationCenter *whichCenter ;
    @property NSString             *notificationName ;
    @property NSString             *typeName ;
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
            int refTable = [[[[[NSThread currentThread] threadDictionary] objectForKey:@"_refTables"]
                                        objectForKey:[NSString stringWithFormat:@"%s", USERDATA_TAG]] intValue] ;

            [skin pushLuaRef:refTable ref:self.fn] ;
            [skin pushNSObject:[note name]] ;
            if ([[note object] isKindOfClass:[NSWorkspace class]]) {
    // NSWorkspace is a common object sender, so don't trigger the LuaSkin warnings for one that
    // we know has no converter function
                [skin pushNSObject:[[note object] debugDescription]] ;
            } else {
    // otherwise, there may be a converter function; and if not, go ahead and fallback to debugDescription
                [skin pushNSObject:[note object] withOptions:LS_NSDescribeUnknownTypes |
                                                             LS_NSUnsignedLongLongPreserveBits] ;
            }
            [skin pushNSObject:[note userInfo] withOptions:LS_NSDescribeUnknownTypes |
                                                           LS_NSUnsignedLongLongPreserveBits] ;
            if (![skin protectedCallAndTraceback:3 nresults:0]) {
                [skin logError:[skin toNSObjectAtIndex:-1]] ;
                lua_pop([skin L], 1) ;
            }
        }
    }
@end

static int commonObserverConstruction(lua_State *L, NSNotificationCenter *nc, NSString *typeName) {
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    int refTable = [[[[[NSThread currentThread] threadDictionary] objectForKey:@"_refTables"]
                                objectForKey:[NSString stringWithFormat:@"%s", USERDATA_TAG]] intValue] ;

    NSString *notificationName = (lua_gettop(L) == 2) ? [skin toNSObjectAtIndex:2] : nil ;
    lua_pushvalue(L, 1);

    HSNotificationCenterClass* listener = [[HSNotificationCenterClass alloc] init];
    listener.fn               = [skin luaRef:refTable] ;
    listener.whichCenter      = nc ;
    listener.notificationName = notificationName ;
    listener.typeName         = typeName ;
    listener.myMainThread     = [NSThread currentThread] ;

    [skin pushNSObject:listener] ;
    return 1;
}

#pragma mark - Module Functions

/// hs._asm.notificationcenter.distributedObserver(fn, [name]) -> notificationcenter
/// Constructor
/// Registers a notification observer for distributed (Intra-Application) notifications.
///
/// Parameters:
///  * fn - the callback function to associate with this listener.  The function will receive 3 parameters:
///    * name - a string giving the name of the notification received
///    * object - the object that posted this notification
///    * userinfo - an optional table containing information attached to the notification reveived
///  * name - an optional parameter specifying the name of the message you wish to listen for.  If nil or left out, all received notifications will be observed.
///
/// Returns:
///  * a notificationcenter object
static int nc_distributedObserver(lua_State* L) {
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    [skin checkArgs:LS_TFUNCTION, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    return commonObserverConstruction(L, [NSDistributedNotificationCenter defaultCenter], @"distributed") ;
}

/// hs._asm.notificationcenter.workspaceObserver(fn, [name]) -> notificationcenter
/// Constructor
/// Registers a notification observer for notifications sent to the shared workspace.
///
/// Parameters:
///  * fn - the callback function to associate with this listener.  The function will receive 3 parameters:
///    * name - a string giving the name of the notification received
///    * object - the object that posted this notification
///    * userinfo - an optional table containing information attached to the notification reveived
///  * name - an optional parameter specifying the name of the message you wish to listen for.  If nil or left out, all received notifications will be observed.
///
/// Returns:
///  * a notificationcenter object
static int nc_workspaceObserver(lua_State* L) {
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    [skin checkArgs:LS_TFUNCTION, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
        return commonObserverConstruction(L, [[NSWorkspace sharedWorkspace] notificationCenter], @"workspace") ;
}

/// hs._asm.notificationcenter.internalObserver(fn, name) -> notificationcenter
/// Constructor
/// Registers a notification observer for notifications sent within Hammerspoon itself.
///
/// Parameters:
///  * fn - the callback function to associate with this listener.  The function will receive 3 parameters:
///    * name - a string giving the name of the notification received
///    * object - the object that posted this notification
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
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    [skin checkArgs:LS_TFUNCTION, LS_TSTRING, LS_TBREAK] ;
    return commonObserverConstruction(L, [NSNotificationCenter defaultCenter], @"internal") ;
}

#pragma mark - Module Methods

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
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNotificationCenterClass* listener = [skin toNSObjectAtIndex:1] ;
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
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNotificationCenterClass* listener = [skin toNSObjectAtIndex:1] ;
    [listener.whichCenter removeObserver:listener name:listener.notificationName object:nil] ;
    lua_settop(L,1);
    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSNotificationCenterClass(lua_State *L, id obj) {
    HSNotificationCenterClass *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(HSNotificationCenterClass *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toHSNotificationCenterClassFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    HSNotificationCenterClass *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSNotificationCenterClass, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                       [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
    HSNotificationCenterClass *obj = [skin luaObjectAtIndex:1 toClass:"HSNotificationCenterClass"] ;
    NSString *title = [NSString stringWithFormat:@"%@:%@", obj.typeName, obj.notificationName] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                           [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
        HSNotificationCenterClass *obj1 = [skin luaObjectAtIndex:1 toClass:"HSNotificationCenterClass"] ;
        HSNotificationCenterClass *obj2 = [skin luaObjectAtIndex:2 toClass:"HSNotificationCenterClass"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSNotificationCenterClass *obj = get_objectFromUserdata(__bridge_transfer HSNotificationCenterClass, L, 1, USERDATA_TAG) ;
    if (obj) {
        LuaSkin *skin = [LuaSkin respondsToSelector:@selector(thread)] ?
                           [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared] ;
        int refTable = [[[[[NSThread currentThread] threadDictionary] objectForKey:@"_refTables"]
                                    objectForKey:[NSString stringWithFormat:@"%s", USERDATA_TAG]] intValue];

        obj.fn = [skin luaUnref:refTable ref:obj.fn] ;
        [obj.whichCenter removeObserver:obj name:obj.notificationName object:nil] ;
        obj = nil ;
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// Metatable for created objects when _new invoked
static const luaL_Reg notificationcenter_metalib[] = {
    {"start",      notificationcenter_start},
    {"stop",       notificationcenter_stop},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
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

    // Necessary only for modules which are written to work in either Hammerspoon or luathread.
    // For luathread only modules (i.e. those included with hs._asm.luathread), this is taken care
    // of during thread initialization
    if ([NSThread isMainThread]) {
        [[[NSThread currentThread] threadDictionary] setObject:[[NSMutableDictionary alloc] init]
                                                        forKey:@"_refTables"] ;
    }

    // This is necessary for any module which is to be used within luathread to ensure each module
    // has a unique refTable value for each thread it may be running in
    [[[[NSThread currentThread] threadDictionary] objectForKey:@"_refTables"]
        setObject:@([skin registerLibraryWithObject:USERDATA_TAG
                                          functions:notificationcenterLib
                                      metaFunctions:nil
                                    objectFunctions:notificationcenter_metalib])
           forKey:[NSString stringWithFormat:@"%s", USERDATA_TAG]] ;

    [skin registerPushNSHelper:pushHSNotificationCenterClass         forClass:"HSNotificationCenterClass"];
    [skin registerLuaObjectHelper:toHSNotificationCenterClassFromLua forClass:"HSNotificationCenterClass"
                                                          withUserdataMapping:USERDATA_TAG];

    return 1;
}
