// not sure how useful some of this is if we can't gert past the "not published" state
// battery stuff should be good though
// add watchers, assertions

@import Cocoa ;
@import LuaSkin ;
@import IOKit.ps ;
@import IOKit.pwr_mgt ;

static const char * const USERDATA_TAG = "hs._asm.iokit.power" ;
static LSRefTable         refTable     = LUA_NOREF ;

#import "iokit_error.h" // needs USERDATA_TAG defined

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#pragma clang diagnostic ignored "-Wstrict-prototypes"
#pragma clang diagnostic ignored "-Winvalid-utf8"

#import "IOPMLibPrivate.h"

#pragma clang diagnostic pop

static NSDictionary *aggressivenessMap ;

// #define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

#pragma mark - Module Functions -

static int iops_getTimeRemainingEstimate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFTimeInterval timeRemaining = IOPSGetTimeRemainingEstimate() ;
    lua_pushnumber(L, timeRemaining) ;
    return 1 ;
}

static int iops_copyExternalPowerAdapterDetails(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFDictionaryRef adapterDetails = IOPSCopyExternalPowerAdapterDetails() ;
    if (adapterDetails) {
        [skin pushNSObject:(__bridge_transfer NSDictionary *)adapterDetails withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iops_getProvidingPowerSourceType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFTypeRef snapshot = IOPSCopyPowerSourcesInfo() ;
    if (snapshot) {
        [skin pushNSObject:(__bridge NSString *)IOPSGetProvidingPowerSourceType(snapshot)] ;
        CFRelease(snapshot) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "unable to get power source info") ;
        return 2 ;
    }
    return 1 ;
}

static int iops_copyPowerSourcesList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFTypeRef blob = IOPSCopyPowerSourcesInfo() ;
    if (blob) {
        CFArrayRef list = IOPSCopyPowerSourcesList(blob) ;
        if (list) {
            lua_newtable(L) ;
            for (CFIndex i = 0 ; i < CFArrayGetCount(list) ; i++) {
                CFDictionaryRef ps = IOPSGetPowerSourceDescription(blob, CFArrayGetValueAtIndex(list, i)) ;
                if (ps) {
                    [skin pushNSObject:(__bridge NSDictionary *)ps withOptions:LS_NSDescribeUnknownTypes] ;
                } else {
                    [skin pushNSObject:[NSString stringWithFormat:@"unable to get description of power source %ld", i + 1]] ;
                }
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
            CFRelease(list) ;
            CFRelease(blob) ;
        } else {
            CFRelease(blob) ;
            lua_pushnil(L) ;
            lua_pushstring(L, "unable to get power sources list") ;
            return 2 ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "unable to get power source info") ;
        return 2 ;
    }
    return 1 ;
}

static int iops_lowBatteryWarningLevel(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    IOPSLowBatteryWarningLevel level = IOPSGetBatteryWarningLevel() ;
    switch(level) {
        case kIOPSLowBatteryWarningNone:  lua_pushstring(L, "none")     ; break ;
        case kIOPSLowBatteryWarningEarly: lua_pushstring(L, "low")      ; break ;
        case kIOPSLowBatteryWarningFinal: lua_pushstring(L, "critical") ; break ;
        default:
            lua_pushfstring(L, "** unrecognized warning level: %d", level) ;
    }
    return 1 ;
}

// typedef void  (*IOPowerSourceCallbackType)(void *context);
// CFRunLoopSourceRef IOPSNotificationCreateRunLoopSource(IOPowerSourceCallbackType callback, void *context);
// CFRunLoopSourceRef IOPSCreateLimitedPowerNotification(IOPowerSourceCallbackType callback, void *context) __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);

static int iopm_sleepSystem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    io_connect_t rootDomain = IOPMFindPowerManagement(MACH_PORT_NULL) ;
    IOReturn err = IOPMSleepSystem(rootDomain) ;
    lua_pushboolean(L, YES) ;
    if (err != kIOReturnSuccess) {
        logError(YES, "systemSleep", err, @"error attempting to initiate system sleep") ;
        lua_pop(L, 1) ;
        lua_pushnil(L) ;
    }
    err = IOServiceClose(rootDomain) ;
    if (err != kIOReturnSuccess) {
        logError(NO, "systemSleep", err, @"unable to close connection to rootDomain") ;
        lua_pop(L, 1) ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iopm_copyCPUPowerStatus(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFDictionaryRef cpuPowerStatus = NULL ;
    IOReturn err = IOPMCopyCPUPowerStatus(&cpuPowerStatus) ;
    if (err == kIOReturnSuccess) {
        if (cpuPowerStatus) {
            [skin pushNSObject:(__bridge_transfer NSDictionary *)cpuPowerStatus withOptions:LS_NSDescribeUnknownTypes] ;
        } else {
            lua_pushnil(L) ;
            lua_pushstring(L, "unable to get cpuPowerStatus") ;
            return 2 ;
        }
    } else if (err == kIOReturnNotFound) {
        lua_pushstring(L, "not published") ;
    } else {
        logError(YES, "cpuPowerStatus", err, @"error querying cpuPowerStatus") ;
        lua_pushnil(L) ;
        lua_pushstring(L, "error querying cpuPowerStatus") ;
        return 2 ;
    }
    return 1 ;
}

static int iopm_sleepEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    lua_pushboolean(L, IOPMSleepEnabled() ? true : false) ;
    return 1 ;
}

static int iopm_copyScheduledPowerEvents(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFArrayRef events = IOPMCopyScheduledPowerEvents() ;
    if (events) {
        [skin pushNSObject:(__bridge_transfer NSArray *)events withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "unable to get scheduled power events") ;
        return 2 ;
    }
    return 1 ;
}

static int iopm_getSystemLoadAdvisory(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    BOOL detailed = (lua_gettop(L) == 1) ? (BOOL)(lua_toboolean(L, 1)) : NO ;

    if (detailed) {
        CFDictionaryRef details = IOCopySystemLoadAdvisoryDetailed() ;
        if (details) {
            [skin pushNSObject:(__bridge_transfer NSDictionary *)details withOptions:LS_NSDescribeUnknownTypes] ;
        } else {
            lua_pushnil(L) ;
            lua_pushstring(L, "unable to get systemLoadAdvisory details") ;
            return 2 ;
        }
    } else {
        IOSystemLoadAdvisoryLevel level = IOGetSystemLoadAdvisory() ;
        switch(level) {
        case kIOSystemLoadAdvisoryLevelGreat: lua_pushstring(L, "great") ; break ;
        case kIOSystemLoadAdvisoryLevelOK:    lua_pushstring(L, "ok") ;    break ;
        case kIOSystemLoadAdvisoryLevelBad:   lua_pushstring(L, "bad") ;   break ;
        default:
            lua_pushfstring(L, "** unrecognized load advisory: %ld", level) ;
        }
    }
    return 1 ;
}

static int iopm_getThermalWarningLevel(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    uint32_t level ;
    IOReturn err = IOPMGetThermalWarningLevel(&level) ;
    if (err == kIOReturnSuccess) {
        switch(level) {
        case kIOPMThermalWarningLevelNormal: lua_pushstring(L, "normal") ;   break ;
        case kIOPMThermalWarningLevelDanger: lua_pushstring(L, "danger") ;   break ;
        case kIOPMThermalWarningLevelCrisis: lua_pushstring(L, "critical") ; break ;
        default:
            lua_pushfstring(L, "** unrecognized thermal warning level: %ld", level) ;
        }
    } else if (err == kIOReturnNotFound) {
        lua_pushstring(L, "not published") ;
    } else {
        logError(YES, "thermalWarningLevel", err, @"unable to get thermalWarningLevel") ;
        lua_pushnil(L) ;
        lua_pushstring(L, "unable to get thermalWarningLevel") ;
        return 2 ;
    }
    return 1 ;
}

static int iopm_copyAssertionsByProcess(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFDictionaryRef assertions = NULL ;
    IOReturn err = IOPMCopyAssertionsByProcess(&assertions) ;
    if (err == kIOReturnSuccess) {
        [skin pushNSObject:(__bridge_transfer NSDictionary *)assertions withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        logError(YES, "assertionsByProcess", err, @"error querying assertions") ;
        lua_pushnil(L) ;
        lua_pushstring(L, "unable to get assertions") ;
        return 2 ;
    }
    return 1 ;
}

static int iopm_copyAssertionsStatus(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFDictionaryRef assertions = NULL ;
    IOReturn err = IOPMCopyAssertionsStatus(&assertions) ;
    if (err == kIOReturnSuccess) {
        [skin pushNSObject:(__bridge_transfer NSDictionary *)assertions withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        logError(YES, "assertionsStatus", err, @"error querying assertions") ;
        lua_pushnil(L) ;
        lua_pushstring(L, "unable to get assertions") ;
        return 2 ;
    }
    return 1 ;
}

static int iopm_aggressiveness(lua_State *L) {
    static dispatch_once_t once;
    dispatch_once(&once, ^ {
        aggressivenessMap = @{
            @"generalAggressiveness" : @(kPMGeneralAggressiveness),
            @"minutesToDim"          : @(kPMMinutesToDim),
            @"minutesToSpinDown"     : @(kPMMinutesToSpinDown),
            @"minutesToSleep"        : @(kPMMinutesToSleep),
            @"ethernetWOL"           : @(kPMEthernetWakeOnLANSettings),
            @"setProcessorSpeed"     : @(kPMSetProcessorSpeed),
            @"powerSource"           : @(kPMPowerSource),
            @"motionSensor"          : @(kPMMotionSensor),
        } ;
    }) ;

    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;

    io_connect_t          rootDomain ;
    __block IOReturn      err            = kIOReturnSuccess ;
    __block unsigned long aggressiveness = 0 ;

    if (lua_gettop(L) == 0) {
        rootDomain = IOPMFindPowerManagement(MACH_PORT_NULL) ;
        lua_newtable(L) ;
        [aggressivenessMap enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *val, __unused BOOL *stop) {
            err = IOPMGetAggressiveness(rootDomain, val.unsignedLongValue, &aggressiveness) ;
            if (err == kIOReturnSuccess) {
                lua_pushinteger(L, (lua_Integer)aggressiveness) ;
                lua_setfield(L, -2, key.UTF8String) ;
            } else if (err != kIOReturnError) {
                logError(YES, "aggressiveness", err, [NSString stringWithFormat:@"unable to get aggressiveness for %@", key]) ;
            }
        }] ;
    } else {
        NSString *key     = [skin toNSObjectAtIndex:1] ;
        NSNumber *keyEnum = aggressivenessMap[key] ;
        if (!keyEnum) {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"unrecognized key; expected one of %@", [aggressivenessMap.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }

        unsigned long type = keyEnum.unsignedLongValue ;

        rootDomain = IOPMFindPowerManagement(MACH_PORT_NULL) ;

        if (lua_gettop(L) == 2) {
            aggressiveness = (unsigned long)lua_tointeger(L, 2) ;
            err = IOPMSetAggressiveness(rootDomain, type, aggressiveness) ;
            if (err != kIOReturnSuccess && err != kIOReturnError) {
                logError(NO, "aggressiveness", err, [NSString stringWithFormat:@"unable to set aggressiveness for %@", key]) ;
            }
        }
        err = IOPMGetAggressiveness(rootDomain, type, &aggressiveness) ;
        if (err == kIOReturnSuccess) {
            lua_pushinteger(L, (lua_Integer)aggressiveness) ;
        } else if (err == kIOReturnError) {
            lua_pushnil(L) ;
        } else {
            logError(NO, "aggressiveness", err, [NSString stringWithFormat:@"unable to get aggressiveness for %@", key]) ;
            lua_pushnil(L) ;
        }
    }
    err = IOServiceClose(rootDomain) ;
    if (err != kIOReturnSuccess) {
        logError(NO, "aggressiveness", err, @"unable to close connection to rootDomain") ;
    }
    return 1 ;
}

static int iopm_copyBatteryInfo(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    mach_port_t masterPort;
    IOReturn err = IOMainPort(MACH_PORT_NULL, &masterPort) ;
    if (err == kIOReturnSuccess) {
        CFArrayRef batteryInfo ;
        err = IOPMCopyBatteryInfo(masterPort, &batteryInfo) ;
        if (err == kIOReturnSuccess) {
            [skin pushNSObject:(__bridge_transfer NSArray *)batteryInfo withOptions:LS_NSDescribeUnknownTypes] ;
            return 1 ;
        } else {
            if (batteryInfo) CFRelease(batteryInfo) ;
            lua_pushnil(L) ;
            lua_pushstring(L, "unable to get IOPM Battery Info") ;
            return 2 ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "unable to get IO Master Port") ;
        return 2 ;
    }
}

// io_connect_t IORegisterForSystemPower(void *refcon, IONotificationPortRef *thePortRef, IOServiceInterestCallback callback, io_object_t *notifier);
// IOReturn IOAllowPowerChange(io_connect_t kernelPort, intptr_t notificationID);
// IOReturn IOCancelPowerChange(io_connect_t kernelPort, intptr_t notificationID);
// IOReturn IODeregisterApp(io_object_t *notifier);
// IOReturn IODeregisterForSystemPower(io_object_t *notifier);
//
// CFDictionaryRef IOPMAssertionCopyProperties(IOPMAssertionID theAssertion);
// IOReturn IOPMAssertionCreateWithDescription(CFStringRef AssertionType, CFStringRef Name, CFStringRef Details, CFStringRef HumanReadableReason, CFStringRef LocalizationBundlePath, CFTimeInterval Timeout, CFStringRef TimeoutAction, IOPMAssertionID *AssertionID);
// IOReturn IOPMAssertionCreateWithName(CFStringRef AssertionType, IOPMAssertionLevel AssertionLevel, CFStringRef AssertionName, IOPMAssertionID *AssertionID);
// IOReturn IOPMAssertionCreateWithProperties(CFDictionaryRef AssertionProperties, IOPMAssertionID *AssertionID);
// IOReturn IOPMAssertionDeclareUserActivity(CFStringRef AssertionName, IOPMUserActiveType userType, IOPMAssertionID *AssertionID);
// IOReturn IOPMAssertionRelease(IOPMAssertionID AssertionID);
// IOReturn IOPMAssertionSetProperty(IOPMAssertionID theAssertion, CFStringRef theProperty, CFTypeRef theValue);
// void IOPMAssertionRetain(IOPMAssertionID theAssertion);

// // require root
// IOReturn IOPMCancelScheduledPowerEvent(CFDateRef time_to_wake, CFStringRef my_id, CFStringRef type);
// IOReturn IOPMSchedulePowerEvent(CFDateRef time_to_wake, CFStringRef my_id, CFStringRef type);
//
// // deprecated
// io_connect_t IORegisterApp(void *refcon, io_service_t theDriver, IONotificationPortRef *thePortRef, IOServiceInterestCallback callback, io_object_t *notifier);
// IOReturn IOPMAssertionCreate(CFStringRef AssertionType, IOPMAssertionLevel AssertionLevel, IOPMAssertionID *AssertionID);

#pragma mark - IOPMLibPrivate.h -

static int iopm_connectionGetSystemCapabilities(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    IOPMCapabilityBits capabilities = IOPMConnectionGetSystemCapabilities() ;
    lua_pushinteger(L, capabilities) ;
    return 1 ;
}

static int iopm_copyRepeatingPowerEvents(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFDictionaryRef repeatingEvents = IOPMCopyRepeatingPowerEvents() ;
    if (repeatingEvents) {
        [skin pushNSObject:(__bridge_transfer NSDictionary *)repeatingEvents withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iopm_copySleepWakeFailure(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFDictionaryRef failures = IOPMCopySleepWakeFailure() ;
    if (failures) {
        [skin pushNSObject:(__bridge_transfer NSDictionary *)failures withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iopm_copyActivePMPreferences(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFDictionaryRef preferences = IOPMCopyActivePMPreferences() ;
//     CFMutableDictionaryRef preferences = IOPMCopyPMPreferences() ;
    if (preferences) {
        [skin pushNSObject:(__bridge_transfer NSDictionary *)preferences withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iopm_copyDefaultPreferences(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFDictionaryRef preferences = IOPMCopyDefaultPreferences() ;
    if (preferences) {
        [skin pushNSObject:(__bridge_transfer NSDictionary *)preferences withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int iopm_copySystemPowerSettings(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFDictionaryRef settings = IOPMCopySystemPowerSettings() ;
    if (settings) {
        [skin pushNSObject:(__bridge_transfer NSDictionary *)settings withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

// return nil; not sure how useful or what we have to do to make them useful
//     CFArrayRef IOPMGetCurrentAsyncReleasedAssertions() ;
//     CFArrayRef IOPMGetCurrentAsyncTimedAssertions() ;
//     CFDictionaryRef IOPMCopyActiveAsyncAssertionsByProcess() ;
//     CFDictionaryRef IOPMCopyAssertionActivityAggregate( );
//     CFDictionaryRef IOPMCopyAssertionActivityAggregateWithAllocator(CFAllocatorRef allocator);
//     CFDictionaryRef IOPMGetCurrentAsycnRemoteAssertion(void);
//     CFDictionaryRef IOPMGetCurrentAsyncActiveAssertions(void);
//     CFDictionaryRef IOPMGetCurrentAsyncInactiveAssertions(void);


#pragma mark - Module Methods -

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

#pragma mark - Hammerspoon/Lua Infrastructure -

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// // Metatable for userdata objects
// static const luaL_Reg userdata_metaLib[] = {
//     {"__tostring", userdata_tostring},
//     {"__eq",       userdata_eq},
//     {"__gc",       userdata_gc},
//     {NULL,         NULL}
// };

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"estimatedTimeRemaining",    iops_getTimeRemainingEstimate},
    {"externalAdapterDetails",    iops_copyExternalPowerAdapterDetails},
    {"currentPowerSource",        iops_getProvidingPowerSourceType},
    {"powerSources",              iops_copyPowerSourcesList},
    {"batteryWarningLevel",       iops_lowBatteryWarningLevel},

    {"systemSleep",               iopm_sleepSystem},
    {"sleepEnabled",              iopm_sleepEnabled},
    {"cpuPowerStatus",            iopm_copyCPUPowerStatus},
    {"scheduledPowerEvents",      iopm_copyScheduledPowerEvents},
    {"systemLoadAdvisory",        iopm_getSystemLoadAdvisory},
    {"thermalWarningLevel",       iopm_getThermalWarningLevel},
    {"intelBatteryInfo",          iopm_copyBatteryInfo},

    {"assertionsByProcess",       iopm_copyAssertionsByProcess},
    {"assertionsStatus",          iopm_copyAssertionsStatus},

    {"aggressiveness",            iopm_aggressiveness},

    {"systemPowerCapabilities",   iopm_connectionGetSystemCapabilities},
    {"repeatingPowerEvents",      iopm_copyRepeatingPowerEvents},
    {"sleepWakeFailure",          iopm_copySleepWakeFailure},
    {"currentPreferences",        iopm_copyActivePMPreferences},
    {"defaultPreferences",        iopm_copyDefaultPreferences},
    {"systemPowerSettings",       iopm_copySystemPowerSettings},

    {NULL,                        NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_libiokit_power(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:USERDATA_TAG
                           functions:moduleLib
                       metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
//     refTable = [skin registerLibraryWithObject:USERDATA_TAG
//                                      functions:moduleLib
//                                  metaFunctions:nil    // or module_metaLib
//                                objectFunctions:userdata_metaLib];

    return 1;
}
