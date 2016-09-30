// TODO:
//    Incorporate GeoCoder
//    @property (readonly, nonatomic) CLLocationDistance maximumRegionMonitoringDistance
//    - (void)requestStateForRegion:(CLRegion *)region -- can we get without requiring delegate method?
//        (delegate method would fire with exit and enter as well; would prefer a simple bool test)



@import Cocoa ;
@import LuaSkin ;
@import CoreLocation ;

#if __clang_major__ < 8
#import "xcode7.h"
#endif

static const char *USERDATA_TAG = "hs._asm.location" ;
static int        refTable      = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface ASMLocation : NSObject <CLLocationManagerDelegate>
@property CLLocationManager* manager ;
@property int                callbackRef ;
@property int                referenceCount ;
@end

@implementation ASMLocation
- (id)init {
    if ([CLLocationManager locationServicesEnabled]) {
        self = [super init] ;
    } else {
        [LuaSkin logWarn:@"Location Services not enabled on this system"] ;
        self = nil ;
    }

    if (self) {
        _manager          = [[CLLocationManager alloc] init];
        _manager.delegate = self ;
        _callbackRef      = LUA_NOREF ;
        _referenceCount   = 0 ;
    }
    return self;
}

- (void)dealloc {
    if (_manager) {
        for (CLRegion *region in [_manager monitoredRegions]) {
            [_manager stopMonitoringForRegion:region] ;
        }
    }
}

- (void)locationManager:(__unused CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            [skin pushLuaRef:refTable ref:self->_callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:@"didUpdateLocations"] ;
            [skin pushNSObject:locations] ;
            if (![skin protectedCallAndTraceback:3 nresults:0]) {
                NSString *errMsg = [skin toNSObjectAtIndex:-1] ;
                [skin logError:[NSString stringWithFormat:@"%s:didUpdateLocations callback error:%@", USERDATA_TAG, errMsg]] ;
                lua_pop(skin.L, 1) ;
            }
        }) ;
    }
}

// - (void)locationManager:(__unused CLLocationManager *)manager didDetermineState:(CLRegionState)state
//                                                              forRegion:(CLRegion *)region {
// }

- (void)locationManager:(__unused CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            [skin pushLuaRef:refTable ref:self->_callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:@"didEnterRegion"] ;
            [skin pushNSObject:region] ;
            if (![skin protectedCallAndTraceback:3 nresults:0]) {
                NSString *errMsg = [skin toNSObjectAtIndex:-1] ;
                [skin logError:[NSString stringWithFormat:@"%s:didEnterRegion callback error:%@", USERDATA_TAG, errMsg]] ;
                lua_pop(skin.L, 1) ;
            }
        }) ;
    }
}

- (void)locationManager:(__unused CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            [skin pushLuaRef:refTable ref:self->_callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:@"didExitRegion"] ;
            [skin pushNSObject:region] ;
            if (![skin protectedCallAndTraceback:3 nresults:0]) {
                NSString *errMsg = [skin toNSObjectAtIndex:-1] ;
                [skin logError:[NSString stringWithFormat:@"%s:didExitRegion callback error:%@", USERDATA_TAG, errMsg]] ;
                lua_pop(skin.L, 1) ;
            }
        }) ;
    }
}

- (void)locationManager:(__unused CLLocationManager *)manager didFailWithError:(NSError *)error {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            [skin pushLuaRef:refTable ref:self->_callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:@"didFailWithError"] ;
            [skin pushNSObject:error.localizedDescription] ;
            if (![skin protectedCallAndTraceback:3 nresults:0]) {
                NSString *errMsg = [skin toNSObjectAtIndex:-1] ;
                [skin logError:[NSString stringWithFormat:@"%s:didExitRegion callback error:%@", USERDATA_TAG, errMsg]] ;
                lua_pop(skin.L, 1) ;
            }
        }) ;
    }
}

- (void)locationManager:(__unused CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region
                                                                      withError:(NSError *)error {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            [skin pushLuaRef:refTable ref:self->_callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:@"monitoringDidFailForRegion"] ;
            [skin pushNSObject:region] ;
            [skin pushNSObject:error.localizedDescription] ;
            if (![skin protectedCallAndTraceback:4 nresults:0]) {
                NSString *errMsg = [skin toNSObjectAtIndex:-1] ;
                [skin logError:[NSString stringWithFormat:@"%s:didExitRegion callback error:%@", USERDATA_TAG, errMsg]] ;
                lua_pop(skin.L, 1) ;
            }
        }) ;
    }
}

- (void)locationManager:(__unused CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            [skin pushLuaRef:refTable ref:self->_callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:@"didChangeAuthorizationStatus"] ;

// according to the CLLocationManager.h file, kCLAuthorizationStatusAuthorizedWhenInUse is
// forbidden in OS X, but Clang still complains about it not being listed in the switch...
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wswitch-enum"
            switch(status) {
                case kCLAuthorizationStatusNotDetermined:    [skin pushNSObject:@"undefined"] ; break ;
                case kCLAuthorizationStatusRestricted:       [skin pushNSObject:@"restricted"] ; break ;
                case kCLAuthorizationStatusDenied:           [skin pushNSObject:@"denied"] ; break ;
                case kCLAuthorizationStatusAuthorizedAlways: [skin pushNSObject:@"authorized"] ; break ;
                default:
                    [skin pushNSObject:[NSString stringWithFormat:@"unrecognized CLAuthorizationStatus: %d, notify developers", status]] ;
                    break ;
            }
#pragma clang diagnostic pop

            if (![skin protectedCallAndTraceback:3 nresults:0]) {
                NSString *errMsg = [skin toNSObjectAtIndex:-1] ;
                [skin logError:[NSString stringWithFormat:@"%s:didChangeAuthorizationStatus callback error:%@", USERDATA_TAG, errMsg]] ;
                lua_pop(skin.L, 1) ;
            }
        }) ;
    }
}

- (void)locationManager:(__unused CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            [skin pushLuaRef:refTable ref:self->_callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:@"didStartMonitoringForRegion"] ;
            [skin pushNSObject:region] ;
            if (![skin protectedCallAndTraceback:3 nresults:0]) {
                NSString *errMsg = [skin toNSObjectAtIndex:-1] ;
                [skin logError:[NSString stringWithFormat:@"%s:didStartMonitoringForRegion callback error:%@", USERDATA_TAG, errMsg]] ;
                lua_pop(skin.L, 1) ;
            }
        }) ;
    }
}

@end

#pragma mark - Module Functions

static int location_manager(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:[[ASMLocation alloc] init]] ;
    return 1 ;
}

static int location_locationServicesEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushboolean(L, [CLLocationManager locationServicesEnabled]) ;
    return 1 ;
}

static int location_authorizationStatus(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;

// according to the CLLocationManager.h file, kCLAuthorizationStatusAuthorizedWhenInUse is
// forbidden in OS X, but Clang still complains about it not being listed in the switch...
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wswitch-enum"
    switch([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusNotDetermined:    [skin pushNSObject:@"undefined"] ; break ;
        case kCLAuthorizationStatusRestricted:       [skin pushNSObject:@"restricted"] ; break ;
        case kCLAuthorizationStatusDenied:           [skin pushNSObject:@"denied"] ; break ;
        case kCLAuthorizationStatusAuthorizedAlways: [skin pushNSObject:@"authorized"] ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized CLAuthorizationStatus: %d, notify developers", [CLLocationManager authorizationStatus]]] ;
            break ;
    }
#pragma clang diagnostic pop

    return 1 ;
}

static int location_distanceBetween(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TTABLE, LS_TBREAK] ;
    CLLocation *pointA = [skin luaObjectAtIndex:1 toClass:"CLLocation"] ;
    CLLocation *pointB = [skin luaObjectAtIndex:2 toClass:"CLLocation"] ;
    lua_pushnumber(L, [pointA distanceFromLocation:pointB]) ;
    return 1;
}

#pragma mark - Module Methods

static int location_start(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMLocation       *obj = [skin toNSObjectAtIndex:1] ;
    CLLocationManager *manager = obj.manager ;
    [manager startUpdatingLocation] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int location_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMLocation       *obj = [skin toNSObjectAtIndex:1] ;
    CLLocationManager *manager = obj.manager ;
    [manager stopUpdatingLocation] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int location_monitoredRegions(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMLocation       *obj = [skin toNSObjectAtIndex:1] ;
    CLLocationManager *manager = obj.manager ;
    [skin pushNSObject:manager.monitoredRegions] ;
    return 1 ;
}

static int location_addMonitoredRegion(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    ASMLocation       *obj = [skin toNSObjectAtIndex:1] ;
    CLLocationManager *manager = obj.manager ;
    CLCircularRegion  *region  = [skin luaObjectAtIndex:2 toClass:"CLCircularRegion"] ;
    if (region) {
        [manager startMonitoringForRegion:region] ;
    } else {
        return luaL_argerror(L, 2, "invalid region table specified") ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int location_removeMonitoredRegion(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    ASMLocation       *obj = [skin toNSObjectAtIndex:1] ;
    CLLocationManager *manager = obj.manager ;
    NSString          *identifier = [skin toNSObjectAtIndex:2] ;
    CLCircularRegion  *targetRegion ;
    for (CLCircularRegion *region in manager.monitoredRegions) {
        if ([identifier isEqualToString:region.identifier]) {
            targetRegion = region ;
            break ;
        }
    }
    if (targetRegion) {
        [manager stopMonitoringForRegion:targetRegion] ;
    } else {
        luaL_argerror(L, 2, [[NSString stringWithFormat:@"%@ does not specify a monitored region", identifier] UTF8String]) ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int location_callbackFunction(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    ASMLocation       *obj = [skin toNSObjectAtIndex:1] ;

    obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2) ;
        obj.callbackRef = [skin luaRef:refTable] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int location_location(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMLocation       *obj = [skin toNSObjectAtIndex:1] ;
    CLLocationManager *manager = obj.manager ;
    [skin pushNSObject:manager.location] ;
    return 1 ;
}

static int location_distanceFrom(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    ASMLocation       *obj = [skin toNSObjectAtIndex:1] ;
    CLLocationManager *manager = obj.manager ;
    CLLocation        *pointB = [skin luaObjectAtIndex:2 toClass:"CLLocation"] ;
    lua_pushnumber(L, [manager.location distanceFromLocation:pointB]) ;
    return 1;
}


static int location_distanceFilter(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMLocation       *obj = [skin toNSObjectAtIndex:1] ;
    CLLocationManager *manager = obj.manager ;
    if (lua_gettop(L) == 1) {
        CLLocationDistance distance = manager.distanceFilter ;
        if (distance == kCLDistanceFilterNone) {
            lua_pushnil(L) ;
        } else {
            lua_pushnumber(L, distance) ;
        }
    } else {
        CLLocationDistance distance = kCLDistanceFilterNone ;
        if (lua_type(L, 2) == LUA_TNUMBER) distance = lua_tonumber(L, 2) ;
        manager.distanceFilter = distance ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int location_desiredAccuracy(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMLocation       *obj = [skin toNSObjectAtIndex:1] ;
    CLLocationManager *manager = obj.manager ;
    NSDictionary *mapping = @{
        @"navigation" : @(kCLLocationAccuracyBestForNavigation),
        @"best"       : @(kCLLocationAccuracyBest),
        @"10m"        : @(kCLLocationAccuracyNearestTenMeters),
        @"100m"       : @(kCLLocationAccuracyHundredMeters),
        @"1k"         : @(kCLLocationAccuracyKilometer),
        @"3k"         : @(kCLLocationAccuracyThreeKilometers),
    } ;
    if (lua_gettop(L) == 1) {
        NSNumber *accuracy = @(manager.desiredAccuracy) ;
        NSString *value = [[mapping allKeysForObject:accuracy] firstObject] ;
        if (value) {
            [skin pushNSObject:value] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized desiredAccuracy %@ -- notify developers", USERDATA_TAG, accuracy]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSNumber *value = mapping[[skin toNSObjectAtIndex:2]] ;
        if (value) {
            manager.desiredAccuracy = [value doubleValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of '%@'", [[mapping allKeys] componentsJoinedByString:@"', '"]] UTF8String]) ;
        }
    }
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMLocation(lua_State *L, id obj) {
    ASMLocation *value = obj;
    value.referenceCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMLocation *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toASMLocationFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMLocation *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMLocation, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushCLLocation(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    CLLocation *location = obj ;
    lua_newtable(L) ;
    lua_pushnumber(L, location.coordinate.latitude) ;  lua_setfield(L, -2, "latitude") ;
    lua_pushnumber(L, location.coordinate.longitude) ; lua_setfield(L, -2, "longitude") ;
    lua_pushnumber(L, location.altitude) ;             lua_setfield(L, -2, "altitude") ;
    lua_pushnumber(L, location.horizontalAccuracy) ;   lua_setfield(L, -2, "horizontalAccuracy") ;
    lua_pushnumber(L, location.verticalAccuracy) ;     lua_setfield(L, -2, "verticalAccuracy") ;
    lua_pushnumber(L, location.course) ;               lua_setfield(L, -2, "course") ;
    lua_pushnumber(L, location.speed) ;                lua_setfield(L, -2, "speed") ;
    [skin pushNSObject:location.description] ;         lua_setfield(L, -2, "description") ;
    [skin pushNSObject:location.timestamp] ;           lua_setfield(L, -2, "timestamp") ;
    lua_pushstring(L, "CLLocation") ;                  lua_setfield(L, -2, "__luaSkinType") ;
    return 1 ;
}

static int pushCLCircularRegion(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    CLCircularRegion *theRegion = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:theRegion.identifier] ;      lua_setfield(L, -2, "identifier") ;
    lua_pushnumber(L, theRegion.center.latitude) ;  lua_setfield(L, -2, "latitude") ;
    lua_pushnumber(L, theRegion.center.longitude) ; lua_setfield(L, -2, "longitude") ;
    lua_pushnumber(L, theRegion.radius) ;           lua_setfield(L, -2, "radius") ;
    lua_pushboolean(L, theRegion.notifyOnEntry) ;   lua_setfield(L, -2, "notifyOnEntry") ;
    lua_pushboolean(L, theRegion.notifyOnExit) ;    lua_setfield(L, -2, "notifyOnExit") ;
    return 1 ;
}

static id CLLocationFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    CLLocation *theLocation ;

    if (lua_type(L, idx) == LUA_TTABLE) {
        CLLocationCoordinate2D location   = { 0.0, 0.0 } ;
        CLLocationDistance     altitude   =  0.0 ;
        CLLocationAccuracy     hAccuracy  =  0.0 ;
        CLLocationAccuracy     vAccuracy  = -1.0 ; // invalid unless explicitly specified
        CLLocationDirection    course     = -1.0 ; // invalid unless explicitly specified
        CLLocationSpeed        speed      = -1.0 ; // invalid unless explicitly specified
        NSDate                 *timestamp = [NSDate date] ;

        if (lua_getfield(L, idx, "latitude") == LUA_TNUMBER) location.latitude = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "longitude") == LUA_TNUMBER) location.longitude = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "altitude") == LUA_TNUMBER) altitude = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "horizontalAccuracy") == LUA_TNUMBER) hAccuracy = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "verticalAccuracy") == LUA_TNUMBER) vAccuracy = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "course") == LUA_TNUMBER) course = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "speed") == LUA_TNUMBER) speed = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "timestamp") == LUA_TNUMBER)
            timestamp = [NSDate dateWithTimeIntervalSince1970:lua_tonumber(L, -1)] ;
        lua_pop(L, 8) ;

        theLocation = [[CLLocation alloc] initWithCoordinate:location
                                                    altitude:altitude
                                          horizontalAccuracy:hAccuracy
                                            verticalAccuracy:vAccuracy
                                                      course:course
                                                       speed:speed
                                                   timestamp:timestamp] ;
    } else {
        [skin logError:[NSString stringWithFormat:@"%s:CLLocationFromLua expected table, found %s", USERDATA_TAG, lua_typename(L, lua_type(L, idx))]] ;
    }

    return theLocation ;
}

static id CLCircularRegionFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    CLCircularRegion *theRegion ;

    if (lua_type(L, idx) == LUA_TTABLE) {
        CLLocationCoordinate2D theCenter  = { 0.0, 0.0 } ;
        CLLocationDistance     theRadius = 0.0 ;
        NSString               *theIdentifier = [[NSUUID UUID] UUIDString] ;

        if (lua_getfield(L, idx, "longitude") == LUA_TNUMBER)  theCenter.longitude = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "latitude") == LUA_TNUMBER)   theCenter.latitude = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "radius") == LUA_TNUMBER)     theRadius = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "identifier") == LUA_TSTRING) theIdentifier = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 4) ;

        theRegion = [[CLCircularRegion alloc] initWithCenter:theCenter
                                                      radius:theRadius
                                                  identifier:theIdentifier] ;

        if (lua_getfield(L, idx, "notifyOnEntry") == LUA_TBOOLEAN) theRegion.notifyOnEntry = (BOOL)lua_toboolean(L, -1) ;
        if (lua_getfield(L, idx, "notifyOnExit") == LUA_TBOOLEAN)  theRegion.notifyOnExit = (BOOL)lua_toboolean(L, -1) ;
        lua_pop(L, 2) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"%s:CLCircularRegionFromLua expected table, found %s", USERDATA_TAG, lua_typename(L, lua_type(L, idx))]] ;
    }
    return theRegion ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
//     ASMLocation *obj = [skin luaObjectAtIndex:1 toClass:"ASMLocation"] ;
//     NSString *title = ... ;
//     [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMLocation *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMLocation"] ;
        ASMLocation *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMLocation"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMLocation *obj = get_objectFromUserdata(__bridge_transfer ASMLocation, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.referenceCount-- ;
        if (obj.referenceCount == 0) {
            LuaSkin *skin = [LuaSkin shared] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.manager.delegate = nil ;
            [obj.manager stopUpdatingLocation] ;
            for (CLRegion *region in [obj.manager monitoredRegions]) {
                [obj.manager stopMonitoringForRegion:region] ;
            }
            obj.manager = nil ;
            obj = nil ;
        }
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
    {"start",                 location_start},
    {"stop",                  location_stop},
    {"distanceFrom",          location_distanceFrom},
    {"monitoredRegions",      location_monitoredRegions},
    {"addMonitoredRegion",    location_addMonitoredRegion},
    {"removeMonitoredRegion", location_removeMonitoredRegion},
    {"callbackFunction",      location_callbackFunction},
    {"location",              location_location},
    {"distanceFilter",        location_distanceFilter},
    {"desiredAccuracy",       location_desiredAccuracy},

    {"__tostring",            userdata_tostring},
    {"__eq",                  userdata_eq},
    {"__gc",                  userdata_gc},
    {NULL,                    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"manager",                 location_manager},
    {"distanceBetween",         location_distanceBetween},
    {"locationServicesEnabled", location_locationServicesEnabled},
    {"authorizationStatus",     location_authorizationStatus},
    {NULL,                      NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_location_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASMLocation         forClass:"ASMLocation"];
    [skin registerLuaObjectHelper:toASMLocationFromLua forClass:"ASMLocation"
                                             withUserdataMapping:USERDATA_TAG];

    [skin registerPushNSHelper:pushCLLocation       forClass:"CLLocation"] ;
    [skin registerLuaObjectHelper:CLLocationFromLua forClass:"CLLocation"
                                            withTableMapping:"CLLocation"] ;

    [skin registerPushNSHelper:pushCLCircularRegion       forClass:"CLCircularRegion"] ;
    [skin registerLuaObjectHelper:CLCircularRegionFromLua forClass:"CLCircularRegion"
                                                  withTableMapping:"CLCircularRegion"] ;
    return 1;
}
