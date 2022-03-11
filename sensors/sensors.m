@import Cocoa ;
@import LuaSkin ;

#import <IOKit/hidsystem/IOHIDEventSystemClient.h>

// See IOHIDFamily/AppleHIDUsageTables.h for more information
// https://opensource.apple.com/source/IOHIDFamily/IOHIDFamily-701.60.2/IOHIDFamily/AppleHIDUsageTables.h.auto.html

#define kHIDPage_AppleVendor                     0xff00
#define kHIDUsage_AppleVendor_TemperatureSensor  0x0005

#define kHIDPage_AppleVendorPowerSensor          0xff08
#define kHIDUsage_AppleVendorPowerSensor_Current 0x0002
#define kHIDUsage_AppleVendorPowerSensor_Voltage 0x0003

// from IOHIDFamily/IOHIDEventTypes.h
// e.g., https://opensource.apple.com/source/IOHIDFamily/IOHIDFamily-701.60.2/IOHIDFamily/IOHIDEventTypes.h.auto.html

#define IOHIDEventFieldBase(type) (type << 16)
#define kIOHIDEventTypeTemperature 15
#define kIOHIDEventTypePower 25

// Declarations from other IOKit source code
typedef struct __IOHIDEvent* IOHIDEventRef;
typedef struct __IOHIDServiceClient* IOHIDServiceClientRef;
typedef double IOHIDFloat;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef, int64_t, int32_t, int64_t);
extern CFStringRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef property);
extern IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

static const char * const USERDATA_TAG = "hs._asm.sensors" ;
static LSRefTable         refTable     = LUA_NOREF ;

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

static int sensors_productNames(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    int page  = (int)lua_tointeger(L, 1) ;
    int usage = (int)lua_tointeger(L, 2) ;

    NSDictionary *matchingDict = @{
        @"PrimaryUsagePage" : @(page),
        @"PrimaryUsage"     : @(usage)
    } ;

    IOHIDEventSystemClientRef system = IOHIDEventSystemClientCreate(kCFAllocatorDefault) ;
    IOHIDEventSystemClientSetMatching(system, (__bridge CFDictionaryRef)matchingDict) ;
    NSArray *matchingsrvs = (__bridge_transfer NSArray *)IOHIDEventSystemClientCopyServices(system) ;

    unsigned long count = matchingsrvs.count ;
    NSMutableArray* array = [NSMutableArray array] ;
    for (unsigned long  i = 0 ; i < count ; i++) {
        IOHIDServiceClientRef sc = (__bridge IOHIDServiceClientRef)matchingsrvs[i] ;
        NSString* name = (__bridge_transfer NSString *)IOHIDServiceClientCopyProperty(sc, (__bridge CFStringRef) @"Product") ;
        if (name) {
            [array addObject:name] ;
        } else {
            [array addObject:@"noname"] ;
        }
    }
    [skin pushNSObject:array] ;
    return 1 ;
}

static int sensors_m1Voltage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    NSDictionary *matchingDict = @ {
        @"PrimaryUsagePage" : @(kHIDPage_AppleVendorPowerSensor),
        @"PrimaryUsage"     : @(kHIDUsage_AppleVendorPowerSensor_Voltage)
    } ;
    IOHIDEventSystemClientRef system = IOHIDEventSystemClientCreate(kCFAllocatorDefault) ;
    IOHIDEventSystemClientSetMatching(system, (__bridge CFDictionaryRef)matchingDict) ;
    NSArray *matchingsrvs = (__bridge_transfer NSArray *)IOHIDEventSystemClientCopyServices(system) ;

    NSMutableDictionary *results = [NSMutableDictionary dictionary] ;
    unsigned long count = matchingsrvs.count ;

    for (unsigned long  i = 0 ; i < count ; i++) {
        IOHIDServiceClientRef sc = (__bridge IOHIDServiceClientRef)matchingsrvs[i] ;
        NSString* name = (__bridge_transfer NSString *)IOHIDServiceClientCopyProperty(sc, (__bridge CFStringRef) @"Product") ;
        if (!name) name = @"no-name" ;

        IOHIDEventRef event = IOHIDServiceClientCopyEvent(sc, kIOHIDEventTypePower, 0, 0);

        double value = (double)NAN ;
        if (event != 0) {
            value = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypePower)) / 1000.0;
        }

        [results setValue:@(value) forKey:name] ;
    }
    [skin pushNSObject:results] ;
    return 1 ;
}

static int sensors_m1Current(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    NSDictionary *matchingDict = @ {
        @"PrimaryUsagePage" : @(kHIDPage_AppleVendorPowerSensor),
        @"PrimaryUsage"     : @(kHIDUsage_AppleVendorPowerSensor_Current)
    } ;
    IOHIDEventSystemClientRef system = IOHIDEventSystemClientCreate(kCFAllocatorDefault) ;
    IOHIDEventSystemClientSetMatching(system, (__bridge CFDictionaryRef)matchingDict) ;
    NSArray *matchingsrvs = (__bridge_transfer NSArray *)IOHIDEventSystemClientCopyServices(system) ;

    NSMutableDictionary *results = [NSMutableDictionary dictionary] ;
    unsigned long count = matchingsrvs.count ;

    for (unsigned long  i = 0 ; i < count ; i++) {
        IOHIDServiceClientRef sc = (__bridge IOHIDServiceClientRef)matchingsrvs[i] ;
        NSString* name = (__bridge_transfer NSString *)IOHIDServiceClientCopyProperty(sc, (__bridge CFStringRef) @"Product") ;
        if (!name) name = @"no-name" ;

        IOHIDEventRef event = IOHIDServiceClientCopyEvent(sc, kIOHIDEventTypePower, 0, 0);

        double value = (double)NAN ;
        if (event != 0) {
            value = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypePower)) / 1000.0;
        }

        [results setValue:@(value) forKey:name] ;
    }
    [skin pushNSObject:results] ;
    return 1 ;
}

static int sensors_m1Temperature(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    NSDictionary *matchingDict = @ {
        @"PrimaryUsagePage" : @(kHIDPage_AppleVendor),
        @"PrimaryUsage"     : @(kHIDUsage_AppleVendor_TemperatureSensor)
    } ;
    IOHIDEventSystemClientRef system = IOHIDEventSystemClientCreate(kCFAllocatorDefault) ;
    IOHIDEventSystemClientSetMatching(system, (__bridge CFDictionaryRef)matchingDict) ;
    NSArray *matchingsrvs = (__bridge_transfer NSArray *)IOHIDEventSystemClientCopyServices(system) ;

    NSMutableDictionary *results = [NSMutableDictionary dictionary] ;
    unsigned long count = matchingsrvs.count ;

    for (unsigned long  i = 0 ; i < count ; i++) {
        IOHIDServiceClientRef sc = (__bridge IOHIDServiceClientRef)matchingsrvs[i] ;
        NSString* name = (__bridge_transfer NSString *)IOHIDServiceClientCopyProperty(sc, (__bridge CFStringRef) @"Product") ;
        if (!name) name = @"no-name" ;

        IOHIDEventRef event = IOHIDServiceClientCopyEvent(sc, kIOHIDEventTypeTemperature, 0, 0);

        double value = (double)NAN ;
        if (event != 0) {
            value = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature)) ;
        }

        [results setValue:@(value) forKey:name] ;
    }
    [skin pushNSObject:results] ;
    return 1 ;
}

#pragma mark - Module Methods

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions

#pragma mark - Hammerspoon/Lua Infrastructure

#if defined(SOURCE_PATH) && ! defined(RELEASE_VERSION)
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)
static int source_path(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushstring(L, TOSTRING(SOURCE_PATH)) ;
    return 1 ;
}
#undef TOSTRING
#undef STRINGIFY
#endif

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"names",         sensors_productNames},
    {"m1Voltage",     sensors_m1Voltage},
    {"m1Current",     sensors_m1Current},
    {"m1Temperature", sensors_m1Temperature},

#if defined(SOURCE_PATH) && ! defined(RELEASE_VERSION)
    {"_source_path", source_path},
#endif
    {NULL, NULL}
};

int luaopen_hs__asm_sensors_sensors(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:USERDATA_TAG
                           functions:moduleLib
                       metaFunctions:nil] ; // or module_metaLib

    return 1;
}
