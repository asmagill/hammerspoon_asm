#import <Cocoa/Cocoa.h>
#import <IOKit/IOKitLib.h>
#import <lauxlib.h>

NSDictionary* listProps(io_service_t	Service)
{
  CFMutableDictionaryRef propertiesDict;
  kern_return_t __unused kr = IORegistryEntryCreateCFProperties( Service,
                                                    &propertiesDict,
                                                    kCFAllocatorDefault,
                                                    kNilOptions );
    return (__bridge_transfer NSDictionary*) propertiesDict;
}

static void NSObject_to_lua(lua_State* L, id obj) {
    if (obj == nil || [obj isEqual: [NSNull null]]) { lua_pushnil(L); }
    else if ([obj isKindOfClass: [NSDictionary class]]) {
        BOOL handled = NO;
        if ([obj count] == 1) {
            if ([obj objectForKey:@"MJ_LUA_NIL"]) {
                lua_pushnil(L);
                handled = YES;
            } else
            if ([obj objectForKey:@"MJ_LUA_TABLE"]) {
                NSArray* parts = [obj objectForKey:@"MJ_LUA_TABLE"] ;
                NSArray* numerics = [parts objectAtIndex:0] ;
                NSDictionary* nonNumerics = [parts objectAtIndex:1] ;
                lua_newtable(L);
                int i = 0;
                for (id item in numerics) {
                    NSObject_to_lua(L, item);
                    lua_rawseti(L, -2, ++i);
                }
                NSArray *keys = [nonNumerics allKeys];
                NSArray *values = [nonNumerics allValues];
                for (unsigned long i = 0; i < keys.count; i++) {
                    NSObject_to_lua(L, [keys objectAtIndex:i]);
                    NSObject_to_lua(L, [values objectAtIndex:i]);
                    lua_settable(L, -3);
                }
                handled = YES;
            }
        }
        if (!handled) {
            NSArray *keys = [obj allKeys];
            NSArray *values = [obj allValues];
            lua_newtable(L);
            for (unsigned long i = 0; i < keys.count; i++) {
                NSObject_to_lua(L, [keys objectAtIndex:i]);
                NSObject_to_lua(L, [values objectAtIndex:i]);
                lua_settable(L, -3);
            }
        }
    } else if ([obj isKindOfClass: [NSNumber class]]) {
        NSNumber* number = obj;
        if (number == (id)kCFBooleanTrue)
            lua_pushboolean(L, YES);
        else if (number == (id)kCFBooleanFalse)
            lua_pushboolean(L, NO);
        else
            lua_pushnumber(L, [number doubleValue]);
    } else if ([obj isKindOfClass: [NSString class]]) {
        NSString* string = obj;
        lua_pushstring(L, [string UTF8String]);
    } else if ([obj isKindOfClass: [NSArray class]]) {
        int i = 0;
        NSArray* list = obj;
        lua_newtable(L);
        for (id item in list) {
            NSObject_to_lua(L, item);
            lua_rawseti(L, -2, ++i);
        }
    } else if ([obj isKindOfClass: [NSDate class]]) {
        lua_pushnumber(L, [(NSDate *) obj timeIntervalSince1970]);
    } else if ([obj isKindOfClass: [NSData class]]) {           // May need to optionally offer to base64 it, if I ever write the generic version of this function...
        lua_pushlstring(L, [obj bytes], [obj length]) ;
    } else {
        lua_pushstring(L, [[NSString stringWithFormat:@"<Object> : %@", obj] UTF8String]) ;
    }
}

/// {PATH}.{MODULE}.list([class][,plane]) -> string
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
    char	        *ioDefPlaneName = "IOService";
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
        NSObject_to_lua(L, listProps(device));
        lua_setfield(L, -2, "Properties");

        lua_rawseti(L, -2, luaL_len(L, -2) + 1);

        /* And free the reference taken before continuing to the next item */
        IOObjectRelease(device);
    }

   /* Done, release the iterator */
   IOObjectRelease(iter);

   return 1;
}


static int iokit_plane(lua_State* L) {
    lua_newtable(L);
    lua_pushstring(L, kIOServicePlane);     lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOPowerPlane);       lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIODeviceTreePlane);  lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOAudioPlane);       lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOFireWirePlane);    lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    lua_pushstring(L, kIOUSBPlane);         lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    return 1;
}

// Functions for returned object when module loads
static const luaL_Reg {MODULE}Lib[] = {
    {"list",    iterate},
    {NULL,      NULL}
};

int luaopen_{F_PATH}_{MODULE}_internal(lua_State* L) {
    luaL_newlib(L, {MODULE}Lib);

    iokit_plane(L);
    lua_setfield(L, -2, "IOPlane");
//     iokit_class(L);
//     lua_setfield(L, -2, "IOClass");

    return 1;
}

