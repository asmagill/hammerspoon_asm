#import <Cocoa/Cocoa.h>
#import <IOKit/IOKitLib.h>

#import <LuaSkin/LuaSkin.h>

#define kIOAcceleratorClassName       "IOAccelerator"
#define kIOAppleLabelSchemeClass      "IOAppleLabelScheme"
#define kIOApplePartitionSchemeClass  "IOApplePartitionScheme"
#define kIOAudioControlClassName      "IOAudioControl"
#define kIOAudioDeviceClassName       "IOAudioDevice"
#define kIOAudioEngineClassName       "IOAudioEngine"
#define kIOAudioPortClassName         "IOAudioPort"
#define kIOAudioStreamClassName       "IOAudioStream"
#define kIOBDBlockStorageDeviceClass  "IOBDBlockStorageDevice"
#define kIOBDBlockStorageDriverClass  "IOBDBlockStorageDriver"
#define kIOBDMediaClass               "IOBDMedia"
#define kIOBlockStorageDeviceClass    "IOBlockStorageDevice"
#define kIOBlockStorageDriverClass    "IOBlockStorageDriver"
#define kIOCDBlockStorageDeviceClass  "IOCDBlockStorageDevice"
#define kIOCDBlockStorageDriverClass  "IOCDBlockStorageDriver"
#define kIOCDMediaClass               "IOCDMedia"
#define kIOCDPartitionSchemeClass     "IOCDPartitionScheme"
#define kIODVDBlockStorageDeviceClass "IODVDBlockStorageDevice"
#define kIODVDBlockStorageDriverClass "IODVDBlockStorageDriver"
#define kIODVDMediaClass              "IODVDMedia"
#define kIOEthernetControllerClass    "IOEthernetController"
#define kIOEthernetInterfaceClass     "IOEthernetInterface"
#define kIOFDiskPartitionSchemeClass  "IOFDiskPartitionScheme"
#define kIOFilterSchemeClass          "IOFilterScheme"
#define kIOGUIDPartitionSchemeClass   "IOGUIDPartitionScheme"
#define kIOHIDSystemClass             "IOHIDSystem"
#define kIOHIKeyboardClass            "IOHIKeyboard"
#define kIOHIPointingClass            "IOHIPointing"
#define kIOI2CInterfaceClassName      "IOI2CInterface"
#define kIOMediaClass                 "IOMedia"
#define kIONetworkControllerClass     "IONetworkController"
#define kIONetworkInterfaceClass      "IONetworkInterface"
#define kIOPartitionSchemeClass       "IOPartitionScheme"
#define kIOResourcesClass             "IOResources"
#define kIOServiceClass               "IOService"
#define kIOStorageClass               "IOStorage"
#define kIOUSBDeviceClassName         "IOUSBDevice"
#define kIOUSBInterfaceClassName      "IOUSBInterface"
#define kIOVideoDevice_ClassName      "IOVideoDevice"

int refTable ;

NSDictionary* listProps(io_service_t  Service)
{
  CFMutableDictionaryRef propertiesDict;
  kern_return_t __unused kr = IORegistryEntryCreateCFProperties( Service,
                                                    &propertiesDict,
                                                    kCFAllocatorDefault,
                                                    kNilOptions );
    return (__bridge_transfer NSDictionary*) propertiesDict;
}

/// hs._asm.iokit.list([class][,plane]) -> string
/// Function
/// Function for looking around in IOKit services... very raw right now and not entirely sure where, if anywhere this will go.  Defaults to IOService for both class and plane, if not provided, or if nil.  If an object's properties contain binary data, you'll need to wrap this in hs.extras.hexdump or hs.extras.ascii_only to allow inspect in order to view the results in the console.
static int iterate(lua_State* L) {
    io_iterator_t   iter;
    kern_return_t   kr;
    io_service_t    device;
    io_name_t       deviceName;
    io_name_t       deviceNameInPlane;
    io_string_t     devicePath;
    char            *ioDefClassName = "IOService";
    char            *ioDefPlaneName = "IOService";
    const char*     ioClassName ;
    const char*     ioPlaneName ;

    if (!lua_isnone(L, 1) && lua_isstring(L,1))
        ioClassName = luaL_checkstring(L,1);
    else
        ioClassName = ioDefClassName ;

    if (!lua_isnone(L, 2) && lua_isstring(L,2))
        ioPlaneName = luaL_checkstring(L,2);
    else
        ioPlaneName = ioDefPlaneName ;

    kr = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(ioClassName), &iter);

    if (kr != KERN_SUCCESS)
    {
        lua_pushstring(L, "Unable to create IOService iterator.");
        lua_error(L);
        return 0;
    }

    lua_newtable(L);

    /* iterate */
    while ((device = IOIteratorNext(iter)))
    {
        /* do something with device, eg. check properties */
        kr = IORegistryEntryGetName(device, deviceName);
        if (kr) {
            IOObjectRelease(device);
                NSLog(@"Error getting name for device.") ;
//             lua_pushstring(L, "Error getting name for device");
//             lua_error(L);
//             return 0;
            continue;
        }

        kr = IORegistryEntryGetPath(device, ioPlaneName, devicePath);
        if (kr) {
            // Device does not exist on this plane
            IOObjectRelease(device);
            continue;
        }
        kr = IORegistryEntryGetNameInPlane(device, ioPlaneName, deviceNameInPlane);

        lua_newtable(L);
        lua_pushstring(L, deviceName);
        lua_setfield(L, -2, "Name");
        lua_pushstring(L, devicePath);
        lua_setfield(L, -2, "Path");
        lua_pushstring(L, deviceNameInPlane);
        lua_setfield(L, -2, "NameInPlane");
        [[LuaSkin shared] pushNSObject:listProps(device)] ;
        lua_setfield(L, -2, "Properties");

        lua_rawseti(L, -2, luaL_len(L, -2) + 1);

        /* And free the reference taken before continuing to the next item */
        IOObjectRelease(device);
    }

   /* Done, release the iterator */
   IOObjectRelease(iter);

   return 1;
}


static int iokit_planes(lua_State* L) {
    lua_newtable(L);
    lua_pushstring(L, kIOServicePlane);     lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOPowerPlane);       lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIODeviceTreePlane);  lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOAudioPlane);       lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOFireWirePlane);    lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOUSBPlane);         lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    return 1;
}

static int iokit_classes(lua_State* L) {
    lua_newtable(L);
    lua_pushstring(L, kIOServiceClass);               lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOResourcesClass);             lua_rawseti(L, -2, luaL_len(L, -2) + 1);
lua_pushstring(L, "-------------------------------"); lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOHIDSystemClass);             lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOHIKeyboardClass);            lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOHIPointingClass);            lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOEthernetControllerClass);    lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOEthernetInterfaceClass);     lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIONetworkControllerClass);     lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIONetworkInterfaceClass);      lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOAppleLabelSchemeClass);      lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOApplePartitionSchemeClass);  lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOBDBlockStorageDeviceClass);  lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOBDMediaClass);               lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOBlockStorageDeviceClass);    lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOBlockStorageDriverClass);    lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOCDBlockStorageDeviceClass);  lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOCDMediaClass);               lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOCDPartitionSchemeClass);     lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIODVDBlockStorageDeviceClass); lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIODVDMediaClass);              lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOFDiskPartitionSchemeClass);  lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOFilterSchemeClass);          lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOGUIDPartitionSchemeClass);   lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOMediaClass);                 lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOPartitionSchemeClass);       lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOStorageClass);               lua_rawseti(L, -2, luaL_len(L, -2) + 1);
lua_pushstring(L, "-------------------------------"); lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOBDBlockStorageDriverClass);  lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOCDBlockStorageDriverClass);  lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIODVDBlockStorageDriverClass); lua_rawseti(L, -2, luaL_len(L, -2) + 1);
lua_pushstring(L, "-------------------------------"); lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOAudioDeviceClassName);       lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOAudioEngineClassName);       lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOAudioStreamClassName);       lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOAudioPortClassName);         lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOAudioControlClassName);      lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOAcceleratorClassName);       lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOI2CInterfaceClassName);      lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOUSBDeviceClassName);         lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOUSBInterfaceClassName);      lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOVideoDevice_ClassName);      lua_rawseti(L, -2, luaL_len(L, -2) + 1);

    return 1;
}

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"list",    iterate},
    {NULL,      NULL}
};

int luaopen_hs__asm_iokit_internal(lua_State* L) {
    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib

    iokit_planes(L); lua_setfield(L, -2, "IOPlane");
    iokit_classes(L); lua_setfield(L, -2, "IOClass");

    return 1;
}

