//
// Will need to add CLGeocoder, Core Location, and MKPlacemark support
//
#import <Cocoa/Cocoa.h>
#import <MapKit/MapKit.h>
// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#define USERDATA_TAG        "hs._asm.map"
int refTable ;

#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))

static int push_nsobject(lua_State *L, id obj) {
// [[LuaSkin shared] pushNSObject:NSFont] ;
// C-API
// Creates a userdata object representing the NSAttributedString
    MKMapItem *mapItem = obj ;

    void** mapPtr = lua_newuserdata(L, sizeof(MKMapItem *)) ;
    *mapPtr = (__bridge_retained void *)mapItem ;
    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;

    return 1 ;
}

static int currentLocation(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    MKMapItem *theLocation = [MKMapItem mapItemForCurrentLocation] ;
    push_nsobject(L, theLocation) ;
    return 1 ;
}

static int placemark(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    MKMapItem *mapItem = get_objectFromUserdata(__bridge MKMapItem, L, 1) ;
    [[LuaSkin shared] pushNSObject:[mapItem placemark]] ;
    return 1 ;
}

static int isCurrentLocation(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    MKMapItem *mapItem = get_objectFromUserdata(__bridge MKMapItem, L, 1) ;
    lua_pushboolean(L, [mapItem isCurrentLocation]) ;
    return 1 ;
}

static int name(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    MKMapItem *mapItem = get_objectFromUserdata(__bridge MKMapItem, L, 1) ;
    [[LuaSkin shared] pushNSObject:[mapItem name]] ;
    return 1 ;
}

static int phoneNumber(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    MKMapItem *mapItem = get_objectFromUserdata(__bridge MKMapItem, L, 1) ;
    [[LuaSkin shared] pushNSObject:[mapItem phoneNumber]] ;
    return 1 ;
}

static int url(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    MKMapItem *mapItem = get_objectFromUserdata(__bridge MKMapItem, L, 1) ;
    [[LuaSkin shared] pushNSObject:[mapItem url]] ;
    return 1 ;
}

static int openInMaps(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    MKMapItem *mapItem = get_objectFromUserdata(__bridge MKMapItem, L, 1) ;
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
                return luaL_error(L, "openInMaps:invalid map type specified: %s", [theType UTF8String]) ;
            }
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, 2, "traffic") == LUA_TBOOLEAN) {
            [theOptions setObject:[NSNumber numberWithBool:(BOOL)lua_toboolean(L, -1)]
                           forKey:MKLaunchOptionsShowsTrafficKey] ;
        }
        lua_pop(L, 1) ;
    }
    lua_pushboolean(L, [mapItem openInMapsWithLaunchOptions:theOptions]) ;
    return 1;
}

static int userdata_tostring(lua_State* L) {
    MKMapItem *mapItem = get_objectFromUserdata(__bridge MKMapItem, L, 1) ;
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, [mapItem name], lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

// static int userdata_eq(lua_State* L) {
// }

static int userdata_gc(lua_State* L) {
    MKMapItem *mapItem = get_objectFromUserdata(__bridge_transfer MKMapItem, L, 1) ;
    mapItem = nil ;

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
    {"isCurrentLocation", isCurrentLocation},
    {"placemark",         placemark},
    {"name",              name},
    {"phoneNumber",       phoneNumber},
    {"url",               url},
    {"openInMaps",        openInMaps},
    {"__tostring",        userdata_tostring},
//     {"__eq",              userdata_eq},
    {"__gc",              userdata_gc},
    {NULL,                NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"currentLocation", currentLocation},
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_map_internal(lua_State* __unused L) {
// Use this if your module doesn't have a module specific object that it returns.
//    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [[LuaSkin shared] registerLibraryWithObject:USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

    return 1;
}
