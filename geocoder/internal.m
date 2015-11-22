//
// Add support for other keys which can be sent to the Maps application (directions, center, etc.)
// Add ReverseGeocode lookup as well
//
// Docs will follow... if you want to tryout:
//   g = require("hs._asm.geocoder")
//   l = g.searchForAddress("some-address", function(s, e) print(g.openPlacesInMaps(e)) end)

#import <Cocoa/Cocoa.h>
#import <MapKit/MapKit.h>
// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#define USERDATA_TAG  "hs._asm.geocoder"

int refTable   = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Module Functions

static int lookupString(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TSTRING, LS_TFUNCTION, LS_TBREAK] ;
    NSString *searchString = [NSString stringWithUTF8String:lua_tostring(L, 1)] ;
    lua_pushvalue(L, 2) ;
    int fnRef = [[LuaSkin shared] luaRef:refTable] ;

    CLGeocoder *geoItem = [[CLGeocoder alloc] init] ;
    [geoItem geocodeAddressString:searchString completionHandler:^(NSArray *placemark, NSError *error) {
        [[LuaSkin shared] pushLuaRef:refTable ref:fnRef] ;
        lua_pushboolean(L, (error == NULL)) ;
        if (error)
            [[LuaSkin shared] pushNSObject:error] ;
        else
            [[LuaSkin shared] pushNSObject:placemark] ;

        if (![[LuaSkin shared] protectedCallAndTraceback:2 nresults:0]) {
            const char *errorMsg = lua_tostring([[LuaSkin shared] L], -1);
            showError([[LuaSkin shared] L], (char *)errorMsg);
            lua_pop([[LuaSkin shared] L], 1) ;
        }

        [[LuaSkin shared] luaUnref:refTable ref:fnRef] ;
    }] ;
    [[LuaSkin shared] pushNSObject:geoItem] ;
    return 1 ;
}

// Was hoping for a Siri like "Find the nearest Walgreens to the specified region" type of
// thing... no such luck, so not sure how much use this would be for most people; however,
// leave it ... it may help with very similar addresses, though I haven't discovered any in
// my (admittedly limited) testing so far...

static int lookupStringNearby(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TSTRING,
                                LS_TTABLE | LS_TFUNCTION | LS_TOPTIONAL,
                                LS_TFUNCTION | LS_TOPTIONAL,
                                LS_TBREAK] ;
    NSString *searchString = [NSString stringWithUTF8String:lua_tostring(L, 1)] ;
    int fnPos = 2 ;
    CLCircularRegion *theRegion = NULL ;
    if (lua_type(L, 2) == LUA_TTABLE) {
        theRegion = [[LuaSkin shared] luaObjectAtIndex:2 toClass:"CLCircularRegion"] ;
        fnPos++ ;
    }
    lua_pushvalue(L, fnPos) ;
    int fnRef = [[LuaSkin shared] luaRef:refTable] ;
    CLGeocoder *geoItem = [[CLGeocoder alloc] init] ;
    [geoItem geocodeAddressString:searchString inRegion:theRegion
                completionHandler:^(NSArray *placemark, NSError *error) {
        [[LuaSkin shared] pushLuaRef:refTable ref:fnRef] ;
        lua_pushboolean(L, (error == NULL)) ;
        if (error)
            [[LuaSkin shared] pushNSObject:error] ;
        else
            [[LuaSkin shared] pushNSObject:placemark] ;

        if (![[LuaSkin shared] protectedCallAndTraceback:2 nresults:0]) {
            const char *errorMsg = lua_tostring([[LuaSkin shared] L], -1);
            showError([[LuaSkin shared] L], (char *)errorMsg);
            lua_pop([[LuaSkin shared] L], 1) ;
        }

        [[LuaSkin shared] luaUnref:refTable ref:fnRef] ;
    }] ;
    [[LuaSkin shared] pushNSObject:geoItem] ;
    return 1 ;
}

static int openPlacesInMaps(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE) ;
    NSMutableArray *theItems = [[NSMutableArray alloc] init] ;
    for (int i = 1 ; i <= luaL_len(L, 1) ; i++) {
        if (lua_rawgeti(L, 1, i) == LUA_TTABLE) {
            MKPlacemark *theMKPlacemark = [[LuaSkin shared] luaObjectAtIndex:-1 toClass:"MKPlacemark"] ;
            [theItems addObject:[[MKMapItem alloc] initWithPlacemark:theMKPlacemark]] ;
        }
        lua_pop(L, 1) ;
    }

    NSMutableDictionary *theOptions = [[NSMutableDictionary alloc] init] ;
    if (lua_type(L, 2) == LUA_TTABLE) {
        if (lua_getfield(L, 2, "mapType") == LUA_TSTRING) {
            NSString *theType = [[LuaSkin shared] toNSObjectAtIndex:-1] ;
            if ([theType isEqualToString:@"standard"]) {
                [theOptions setObject:[NSNumber numberWithInt:MKMapTypeStandard]
                               forKey:MKLaunchOptionsMapTypeKey] ;
            } else if ([theType isEqualToString:@"satellite"]) {
                [theOptions setObject:[NSNumber numberWithInt:MKMapTypeSatellite]
                               forKey:MKLaunchOptionsMapTypeKey] ;
            } else if ([theType isEqualToString:@"hybrid"]) {
                [theOptions setObject:[NSNumber numberWithInt:MKMapTypeHybrid]
                               forKey:MKLaunchOptionsMapTypeKey] ;
            } else {
                return luaL_error(L, "openPlacesInMaps:invalid map type specified: %s", [theType UTF8String]) ;
            }
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, 2, "traffic") == LUA_TBOOLEAN) {
            [theOptions setObject:[NSNumber numberWithBool:(BOOL)lua_toboolean(L, -1)]
                           forKey:MKLaunchOptionsShowsTrafficKey] ;
        }
        lua_pop(L, 1) ;
    }

    lua_pushboolean(L, [MKMapItem openMapsWithItems:theItems launchOptions:theOptions]) ;
    return 1 ;
}

#pragma mark - Object Methods

static int isGeocoding(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    CLGeocoder *geoItem = get_objectFromUserdata(__bridge CLGeocoder, L, 1) ;
    lua_pushboolean(L, [geoItem isGeocoding]) ;
    return 1 ;
}

static int cancelGeocoding(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    CLGeocoder *geoItem = get_objectFromUserdata(__bridge CLGeocoder, L, 1) ;
    [geoItem cancelGeocode] ;
    return 0 ;
}

#pragma mark - Data Type Converters

static int CLPlacemark_tolua(lua_State *L, id obj) {
    CLPlacemark *thePlace = obj ;
    lua_newtable(L) ;
      [[LuaSkin shared] pushNSObject:[thePlace location]] ;                 lua_setfield(L, -2, "location") ;
      [[LuaSkin shared] pushNSObject:[thePlace name]] ;                     lua_setfield(L, -2, "name") ;
      [[LuaSkin shared] pushNSObject:[thePlace addressDictionary]] ;        lua_setfield(L, -2, "addressDictionary") ;
      [[LuaSkin shared] pushNSObject:[thePlace ISOcountryCode]] ;           lua_setfield(L, -2, "ISOcountryCode") ;
      [[LuaSkin shared] pushNSObject:[thePlace country]] ;                  lua_setfield(L, -2, "country") ;
      [[LuaSkin shared] pushNSObject:[thePlace postalCode]] ;               lua_setfield(L, -2, "postalCode") ;
      [[LuaSkin shared] pushNSObject:[thePlace administrativeArea]] ;       lua_setfield(L, -2, "administrativeArea") ;
      [[LuaSkin shared] pushNSObject:[thePlace subAdministrativeArea]] ;    lua_setfield(L, -2, "subAdministrativeArea") ;
      [[LuaSkin shared] pushNSObject:[thePlace locality]] ;                 lua_setfield(L, -2, "locality") ;
      [[LuaSkin shared] pushNSObject:[thePlace subLocality]] ;              lua_setfield(L, -2, "subLocality") ;
      [[LuaSkin shared] pushNSObject:[thePlace thoroughfare]] ;             lua_setfield(L, -2, "thoroughfare") ;
      [[LuaSkin shared] pushNSObject:[thePlace subThoroughfare]] ;          lua_setfield(L, -2, "subThoroughfare") ;
      [[LuaSkin shared] pushNSObject:[thePlace region]] ;                   lua_setfield(L, -2, "region") ;
      [[LuaSkin shared] pushNSObject:[[thePlace timeZone] abbreviation]] ;  lua_setfield(L, -2, "timeZone") ;
      [[LuaSkin shared] pushNSObject:[thePlace inlandWater]] ;              lua_setfield(L, -2, "inlandWater") ;
      [[LuaSkin shared] pushNSObject:[thePlace ocean]] ;                    lua_setfield(L, -2, "ocean") ;
      [[LuaSkin shared] pushNSObject:[thePlace areasOfInterest]] ;          lua_setfield(L, -2, "areasOfInterest") ;
    return 1 ;
}

static id lua_toMKPlacemark(lua_State *L, int idx) {
    CLLocationCoordinate2D theLocation = { 0.0, 0.0 } ;
    NSDictionary *theAddress ;

    if (lua_getfield(L, idx, "location") == LUA_TTABLE) {
        if (lua_getfield(L, -1, "longitude") == LUA_TNUMBER) theLocation.longitude = lua_tonumber(L, -1) ;
        lua_pop(L, 1) ;
        if (lua_getfield(L, -1, "latitude") == LUA_TNUMBER)  theLocation.latitude = lua_tonumber(L, -1) ;
        lua_pop(L, 1) ;
    }
    lua_pop(L, 1) ;
    if (lua_getfield(L, idx, "addressDictionary") == LUA_TTABLE)
        theAddress = [[LuaSkin shared] toNSObjectAtIndex:-1] ;
    lua_pop(L, 1) ;

    return [[MKPlacemark alloc] initWithCoordinate:theLocation addressDictionary:theAddress] ;
}

static int CLLocation_tolua(lua_State *L, id obj) {
    CLLocation *location = obj ;
    lua_newtable(L) ;
      lua_pushnumber(L, [location coordinate].latitude) ;  lua_setfield(L, -2, "latitude") ;
      lua_pushnumber(L, [location coordinate].longitude) ; lua_setfield(L, -2, "longitude") ;
      lua_pushnumber(L, [location altitude]) ;                 lua_setfield(L, -2, "altitude") ;
// Not sure how useful these are, but in case someone wants them...
//       lua_pushnumber(L, [location horizontalAccuracy]) ;       lua_setfield(L, -2, "horizontalAccuracy") ;
//       lua_pushnumber(L, [location verticalAccuracy]) ;         lua_setfield(L, -2, "verticalAccuracy") ;
//       [[LuaSkin shared] pushNSObject:[location timestamp]] ;   lua_setfield(L, -2, "timestamp") ;
//       [[LuaSkin shared] pushNSObject:[location description]] ; lua_setfield(L, -2, "description") ;
    return 1 ;
}

static int CLCircularRegion_tolua(lua_State *L, id obj) {
    CLCircularRegion *theRegion = obj ;
    lua_newtable(L) ;
      [[LuaSkin shared] pushNSObject:[theRegion identifier]] ; lua_setfield(L, -2, "identifier") ;
      lua_newtable(L) ;
        lua_pushnumber(L, [theRegion center].latitude) ;  lua_setfield(L, -2, "latitude") ;
        lua_pushnumber(L, [theRegion center].longitude) ; lua_setfield(L, -2, "longitude") ;
      lua_setfield(L, -2, "center") ;
      lua_pushnumber(L, [theRegion radius]) ;                  lua_setfield(L, -2, "radius") ;
    return 1 ;
}

static id lua_toCLCircularRegion(lua_State *L, int idx) {
    luaL_checktype(L, idx, LUA_TTABLE) ;
    CLLocationCoordinate2D theCenter  = { 0.0, 0.0 } ;
    CLLocationDistance     theRadius = 0.0 ;
    NSString               *theIdentifier = [[NSUUID UUID] UUIDString] ;

    if (lua_getfield(L, idx, "center") == LUA_TTABLE) {
        if (lua_getfield(L, -1, "longitude") == LUA_TNUMBER) theCenter.longitude = lua_tonumber(L, -1) ;
        lua_pop(L, 1) ;
        if (lua_getfield(L, -1, "latitude") == LUA_TNUMBER)  theCenter.latitude = lua_tonumber(L, -1) ;
        lua_pop(L, 1) ;
    }
    lua_pop(L, 1) ;
// allow lua coders to be lazy and put all three into the same table
    if (lua_getfield(L, idx, "longitude") == LUA_TNUMBER) theCenter.longitude = lua_tonumber(L, -1) ;
    lua_pop(L, 1) ;
    if (lua_getfield(L, idx, "latitude") == LUA_TNUMBER)  theCenter.latitude = lua_tonumber(L, -1) ;
    lua_pop(L, 1) ;
    if (lua_getfield(L, idx, "radius") == LUA_TNUMBER)    theRadius = lua_tonumber(L, -1) ;
    lua_pop(L, 1) ;
    if (lua_getfield(L, idx, "identifier") == LUA_TSTRING) theIdentifier = [[LuaSkin shared] toNSObjectAtIndex:-1] ;
    lua_pop(L, 1) ;

    CLCircularRegion *theRegion = [[CLCircularRegion alloc] initWithCenter:theCenter
                                                                    radius:theRadius
                                                                identifier:theIdentifier] ;
    return theRegion ;
}

static int CLGeocoder_tolua(lua_State *L, id obj) {
    CLGeocoder *geoItem = obj ;

    void** geoPtr = lua_newuserdata(L, sizeof(CLGeocoder *)) ;
    *geoPtr = (__bridge_retained void *)geoItem ;
    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;

    return 1 ;
}

#pragma mark - Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    CLGeocoder *geoItem = get_objectFromUserdata(__bridge_transfer CLGeocoder, L, 1) ;
    lua_pushfstring(L, "%s: %s (%p)", USERDATA_TAG, ([geoItem isGeocoding] ? "geocoding" : "idle"), lua_topointer(L, 1)) ;
    return 1 ;
}

// static int userdata_eq(lua_State* L) {
// }

static int userdata_gc(lua_State* L) {
    CLGeocoder *geoItem = get_objectFromUserdata(__bridge_transfer CLGeocoder, L, 1) ;
    geoItem = nil ;

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg object_metaLib[] = {
    {"geocoding",  isGeocoding},
    {"cancel",     cancelGeocoding},
    {"__tostring", userdata_tostring},
//     {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"searchForAddress",   lookupString},
    {"searchNearLocation", lookupStringNearby},
    {"openPlacesInMaps",   openPlacesInMaps},
    {NULL, NULL}
};

int luaopen_hs__asm_geocoder_internal(lua_State* __unused L) {
    refTable = [[LuaSkin shared] registerLibraryWithObject:USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:object_metaLib];

    [[LuaSkin shared] registerPushNSHelper:CLGeocoder_tolua  forClass:"CLGeocoder"] ;
    [[LuaSkin shared] registerPushNSHelper:CLPlacemark_tolua forClass:"CLPlacemark"] ;
    [[LuaSkin shared] registerPushNSHelper:CLLocation_tolua  forClass:"CLLocation"] ;
    [[LuaSkin shared] registerPushNSHelper:CLCircularRegion_tolua    forClass:"CLCircularRegion"] ;

    [[LuaSkin shared] registerLuaObjectHelper:lua_toCLCircularRegion    forClass:"CLCircularRegion"] ;
    [[LuaSkin shared] registerLuaObjectHelper:lua_toMKPlacemark forClass:"MKPlacemark"] ;
    return 1;
}
