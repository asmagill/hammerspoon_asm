// not sure how useful some of this is if we can't gert past the "not published" state
// battery stuff should be good though
// add watchers

@import Cocoa ;
@import LuaSkin ;
@import IOKit.ps ;
@import IOKit.pwr_mgt ;
// #import <IOKit/pwr_mgt/IOPMLib.h>

static const char * const USERDATA_TAG = "hs._asm.iokit.power" ;
static LSRefTable         refTable     = LUA_NOREF ;

// #define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

// in case I ever decide to expand upon what the kernel error numbers actually are, consolidate
// the reporting
static void logError(BOOL debug, const char *func, kern_return_t err, NSString *message) {
    if (debug) {
        [LuaSkin logDebug:@"%s.%s -- %@ (Kernel Error %d)", USERDATA_TAG, func, message, err] ;
    } else {
        [LuaSkin  logWarn:@"%s.%s -- %@ (Kernel Error %d)", USERDATA_TAG, func, message, err] ;
    }
}

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
        [skin pushNSObject:(__bridge_transfer NSDictionary *)adapterDetails] ;
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
        logError(YES, "systemSleep", err, @"unable to close connection to rootDomain") ;
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
            [skin pushNSObject:(__bridge_transfer NSDictionary *)cpuPowerStatus] ;
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
        [skin pushNSObject:(__bridge_transfer NSArray *)events] ;
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
            [skin pushNSObject:(__bridge_transfer NSDictionary *)details] ;
        } else {
            lua_pushnil(L) ;
            lua_pushstring(L, "unable to get systemLoadAdvisory details") ;
            return 2 ;
        }
    } else {
        IOSystemLoadAdvisoryLevel level = IOGetSystemLoadAdvisory() ;
        switch(level) {
        case kIOSystemLoadAdvisoryLevelGreat:
            lua_pushstring(L, "great") ;
            break ;
        case kIOSystemLoadAdvisoryLevelOK:
            lua_pushstring(L, "ok") ;
            break ;
        case kIOSystemLoadAdvisoryLevelBad:
            lua_pushstring(L, "bad") ;
            break ;
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
        case kIOPMThermalWarningLevelNormal:
            lua_pushstring(L, "normal") ;
            break ;
        case kIOPMThermalWarningLevelDanger:
            lua_pushstring(L, "danger") ;
            break ;
        case kIOPMThermalWarningLevelCrisis:
            lua_pushstring(L, "critical") ;
            break ;
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

// IOReturn IOPMGetAggressiveness(io_connect_t fb, unsigned long type, unsigned long *aggressiveness);
// IOReturn IOPMSetAggressiveness(io_connect_t fb, unsigned long type, unsigned long aggressiveness);
//
// io_connect_t IOPMFindPowerManagement(mach_port_t master_device_port);
// io_connect_t IORegisterForSystemPower(void *refcon, IONotificationPortRef *thePortRef, IOServiceInterestCallback callback, io_object_t *notifier);
// IOReturn IOAllowPowerChange(io_connect_t kernelPort, intptr_t notificationID);
// IOReturn IOCancelPowerChange(io_connect_t kernelPort, intptr_t notificationID);
// IOReturn IODeregisterApp(io_object_t *notifier);
// IOReturn IODeregisterForSystemPower(io_object_t *notifier);
//
// IOReturn IOPMCopyAssertionsByProcess(CFDictionaryRef *AssertionsByPID);
// IOReturn IOPMCopyAssertionsStatus(CFDictionaryRef *AssertionsStatus);
//
// CFDictionaryRef IOPMAssertionCopyProperties(IOPMAssertionID theAssertion);
// IOReturn IOPMAssertionCreateWithDescription(CFStringRef AssertionType, CFStringRef Name, CFStringRef Details, CFStringRef HumanReadableReason, CFStringRef LocalizationBundlePath, CFTimeInterval Timeout, CFStringRef TimeoutAction, IOPMAssertionID *AssertionID);
// IOReturn IOPMAssertionCreateWithName(CFStringRef AssertionType, IOPMAssertionLevel AssertionLevel, CFStringRef AssertionName, IOPMAssertionID *AssertionID);
// IOReturn IOPMAssertionCreateWithProperties(CFDictionaryRef AssertionProperties, IOPMAssertionID *AssertionID);
// IOReturn IOPMAssertionDeclareUserActivity(CFStringRef AssertionName, IOPMUserActiveType userType, IOPMAssertionID *AssertionID);
// IOReturn IOPMAssertionRelease(IOPMAssertionID AssertionID);
// IOReturn IOPMAssertionSetProperty(IOPMAssertionID theAssertion, CFStringRef theProperty, CFTypeRef theValue);
// void IOPMAssertionRetain(IOPMAssertionID theAssertion);
//
// // require root
// IOReturn IOPMCancelScheduledPowerEvent(CFDateRef time_to_wake, CFStringRef my_id, CFStringRef type);
// IOReturn IOPMSchedulePowerEvent(CFDateRef time_to_wake, CFStringRef my_id, CFStringRef type);
//
// // deprecated
// io_connect_t IORegisterApp(void *refcon, io_service_t theDriver, IONotificationPortRef *thePortRef, IOServiceInterestCallback callback, io_object_t *notifier);
// IOReturn IOPMAssertionCreate(CFStringRef AssertionType, IOPMAssertionLevel AssertionLevel, IOPMAssertionID *AssertionID);
// IOReturn IOPMCopyBatteryInfo(mach_port_t masterPort, CFArrayRef *info);

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
    {"estimatedTimeRemaining", iops_getTimeRemainingEstimate},
    {"externalAdapterDetails", iops_copyExternalPowerAdapterDetails},
    {"providingPowerSource",   iops_getProvidingPowerSourceType},
    {"powerSources",           iops_copyPowerSourcesList},

    {"systemSleep",            iopm_sleepSystem},
    {"sleepEnabled",           iopm_sleepEnabled},
    {"cpuPowerStatus",         iopm_copyCPUPowerStatus},
    {"scheduledPowerEvents",   iopm_copyScheduledPowerEvents},
    {"systemLoadAdvisory",     iopm_getSystemLoadAdvisory},
    {"thermalWarningLevel",    iopm_getThermalWarningLevel},

    {NULL,                     NULL}
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
