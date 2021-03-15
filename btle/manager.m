@import Cocoa;
@import LuaSkin;
@import CoreBluetooth;

/// === hs._asm.btle.manager ===
///
/// Provides support for managing the discovery of and connections to remote BTLE peripheral devices.
///
/// This submodule handles scanning for, discovering, and connecting to advertising BTLE peripherals.

static const char * const UD_MANAGER_TAG    = "hs._asm.btle.manager" ;
static const char * const UD_PERIPHERAL_TAG = "hs._asm.btle.peripheral" ;
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, TAG) (objType*)*((void**)luaL_checkudata(L, idx, TAG))

#pragma mark - Support Functions and Classes

@interface HSCBCentralManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>
@property int              selfRefCount ;
@property int              callbackRef ;
@property int              peripheralCallbackRef ;
@property CBCentralManager *manager ;
@end

@implementation HSCBCentralManager
- (id)init {
    self = [super init] ;
    if (self) {
        _manager               = [[CBCentralManager alloc]initWithDelegate:self queue:nil] ;
        _selfRefCount          = 0 ;
        _callbackRef           = LUA_NOREF ;
        _peripheralCallbackRef = LUA_NOREF ;
    }
    return self ;
}

#pragma mark - CBCentralManagerDelegate Stuff

- (void)centralManager:(__unused CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    peripheral.delegate = self ;
    if (_callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:self];
        [skin pushNSObject:@"didConnectPeripheral"];
        [skin pushNSObject:peripheral] ;
        if (![skin protectedCallAndTraceback:3 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didConnectPeripheral callback: %@", UD_MANAGER_TAG, theError]];
        }
    }
}

- (void)centralManager:(__unused CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    peripheral.delegate = nil ;
    if (_callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:self];
        [skin pushNSObject:@"didDisconnectPeripheral"];
        [skin pushNSObject:peripheral] ;
        if (error) {
            [skin pushNSObject:[error localizedDescription]] ;
        } else {
            lua_pushnil([skin L]) ;
        }
        if (![skin protectedCallAndTraceback:4 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didDisconnectPeripheral callback: %@", UD_MANAGER_TAG, theError]];
        }
    }
}

- (void)centralManager:(__unused CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (_callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:self];
        [skin pushNSObject:@"didFailToConnectPeripheral"];
        [skin pushNSObject:peripheral] ;
        if (error) {
            [skin pushNSObject:[error localizedDescription]] ;
        } else {
            lua_pushnil([skin L]) ;
        }
        if (![skin protectedCallAndTraceback:4 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didFailToConnectPeripheral callback: %@", UD_MANAGER_TAG, theError]];
        }
    }
}

- (void)centralManager:(__unused CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral
                                                       advertisementData:(NSDictionary *)advertisementData
                                                                    RSSI:(NSNumber *)RSSI {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (_callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:self];
        [skin pushNSObject:@"didDiscoverPeripheral"];
        [skin pushNSObject:peripheral] ;
//         NSLog(@"advertisementdata = %@", advertisementData) ;
        [skin pushNSObject:advertisementData withOptions:LS_NSDescribeUnknownTypes] ;
        [skin pushNSObject:RSSI] ;
        if (![skin protectedCallAndTraceback:5 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didDiscoverPeripheral callback: %@", UD_MANAGER_TAG, theError]];
        }
    }
}

// Used by deprecated methods; since we're not implementing an interface to such methods, don't support for now
//
// - (void)centralManager:(__unused CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals {
//     LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
//     if (_callbackRef != LUA_NOREF) {
//         [skin pushLuaRef:refTable ref:_callbackRef];
//         [skin pushNSObject:self];
//         [skin pushNSObject:@"didRetrieveConnectedPeripherals"];
//         for (CBPeripheral *entry in peripherals) entry.delegate = manager ;
//         [skin pushNSObject:peripherals] ;
//         if (![skin protectedCallAndTraceback:3 nresults:0]) {
//             NSString *theError = [skin toNSObjectAtIndex:-1];
//             lua_pop([skin L], 1);
//             [skin logWarn:[NSString stringWithFormat:@"%s:didRetrieveConnectedPeripherals callback: %@", UD_MANAGER_TAG, theError]];
//         }
//     }
// }
//
// - (void)centralManager:(__unused CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals {
//     LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
//     if (_callbackRef != LUA_NOREF) {
//         [skin pushLuaRef:refTable ref:_callbackRef];
//         [skin pushNSObject:self];
//         [skin pushNSObject:@"didRetrievePeripherals"];
//         for (CBPeripheral *entry in peripherals) entry.delegate = manager ;
//         [skin pushNSObject:peripherals] ;
//         if (![skin protectedCallAndTraceback:3 nresults:0]) {
//             NSString *theError = [skin toNSObjectAtIndex:-1];
//             lua_pop([skin L], 1);
//             [skin logWarn:[NSString stringWithFormat:@"%s:didRetrievePeripherals callback: %@", UD_MANAGER_TAG, theError]];
//         }
//     }
// }

- (void)centralManagerDidUpdateState:(__unused CBCentralManager *)central {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (_callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:self];
        [skin pushNSObject:@"didUpdateState"];
        if (![skin protectedCallAndTraceback:2 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didUpdateState callback: %@", UD_MANAGER_TAG, theError]];
        }
    }
}

// NOTE: - (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *,id> *)dict
    // Discussion
    // For apps that opt in to the state preservation and restoration feature of Core Bluetooth, this is the first
    // method invoked when your app is relaunched into the background to complete some Bluetooth-related task.
    // Use this method to synchronize the state of your app with the state of the Bluetooth system.
    //
    // Only real discussions of "bluetooth-central background mode" are all IOS, though the docs suggest OS X can
    // do it/support it to (at least, the delegate methods and constants are defined on the OS X side as well).
    //
    // Not going to bother with right now, but if/when, check out (constants aren't in Dash's OS X docs (yet?)):
    // https://developer.apple.com/library/ios/documentation/CoreBluetooth/Reference/CBCentralManagerDelegate_Protocol/#//apple_ref/doc/constant_group/Central_Manager_State_Restoration_Options

#pragma mark - CBPeripheralDelegate Stuff

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (_peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_peripheralCallbackRef];
        [skin pushNSObject:peripheral];
        [skin pushNSObject:@"didDiscoverServices"];
        if (error) {
            [skin pushNSObject:[error localizedDescription]] ;
        } else {
            lua_pushnil([skin L]) ;
        }
        if (![skin protectedCallAndTraceback:3 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didDiscoverServices callback: %@", UD_PERIPHERAL_TAG, theError]];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service error:(NSError *)error {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (_peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_peripheralCallbackRef];
        [skin pushNSObject:peripheral];
        [skin pushNSObject:@"didDiscoverIncludedServicesForService"];
        [skin pushNSObject:service];
        if (error) {
            [skin pushNSObject:[error localizedDescription]] ;
        } else {
            lua_pushnil([skin L]) ;
        }
        if (![skin protectedCallAndTraceback:4 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didDiscoverIncludedServicesForService callback: %@", UD_PERIPHERAL_TAG, theError]];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (_peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_peripheralCallbackRef];
        [skin pushNSObject:peripheral];
        [skin pushNSObject:@"didDiscoverCharacteristicsForService"];
        [skin pushNSObject:service];
        if (error) {
            [skin pushNSObject:[error localizedDescription]] ;
        } else {
            lua_pushnil([skin L]) ;
        }
        if (![skin protectedCallAndTraceback:4 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didDiscoverCharacteristicsForService callback: %@", UD_PERIPHERAL_TAG, theError]];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (_peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_peripheralCallbackRef];
        [skin pushNSObject:peripheral];
        [skin pushNSObject:@"didDiscoverDescriptorsForCharacteristic"];
        [skin pushNSObject:characteristic];
        if (error) {
            [skin pushNSObject:[error localizedDescription]] ;
        } else {
            lua_pushnil([skin L]) ;
        }
        if (![skin protectedCallAndTraceback:4 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didDiscoverDescriptorsForCharacteristic callback: %@", UD_PERIPHERAL_TAG, theError]];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    [skin logDebug:[NSString stringWithFormat:@"didUpdateValueForCharacteristic %@ error = %@",characteristic.UUID,error]];
    [skin logDebug:[NSString stringWithFormat:@"didUpdateValue %@ %lu ; error = %@",characteristic.value, characteristic.value.length, error]];
    if (_peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_peripheralCallbackRef];
        [skin pushNSObject:peripheral];
        [skin pushNSObject:@"didUpdateValueForCharacteristic"];
        [skin pushNSObject:characteristic];
        if (error) {
            [skin pushNSObject:[error localizedDescription]] ;
        } else {
            lua_pushnil([skin L]) ;
        }
        if (![skin protectedCallAndTraceback:4 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didUpdateValueForCharacteristic callback: %@", UD_PERIPHERAL_TAG, theError]];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (_peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_peripheralCallbackRef];
        [skin pushNSObject:peripheral];
        [skin pushNSObject:@"didUpdateValueForDescriptor"];
        [skin pushNSObject:descriptor];
        if (error) {
            [skin pushNSObject:[error localizedDescription]] ;
        } else {
            lua_pushnil([skin L]) ;
        }
        if (![skin protectedCallAndTraceback:4 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didUpdateValueForDescriptor callback: %@", UD_PERIPHERAL_TAG, theError]];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (_peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_peripheralCallbackRef];
        [skin pushNSObject:peripheral];
        [skin pushNSObject:@"didWriteValueForCharacteristic"];
        [skin pushNSObject:characteristic];
        if (error) {
            [skin pushNSObject:[error localizedDescription]] ;
        } else {
            lua_pushnil([skin L]) ;
        }
        if (![skin protectedCallAndTraceback:4 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didWriteValueForCharacteristic callback: %@", UD_PERIPHERAL_TAG, theError]];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (_peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_peripheralCallbackRef];
        [skin pushNSObject:peripheral];
        [skin pushNSObject:@"didWriteValueForDescriptor"];
        [skin pushNSObject:descriptor];
        if (error) {
            [skin pushNSObject:[error localizedDescription]] ;
        } else {
            lua_pushnil([skin L]) ;
        }
        if (![skin protectedCallAndTraceback:4 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didWriteValueForDescriptor callback: %@", UD_PERIPHERAL_TAG, theError]];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (_peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_peripheralCallbackRef];
        [skin pushNSObject:peripheral];
        [skin pushNSObject:@"didUpdateNotificationStateForCharacteristic"];
        [skin pushNSObject:characteristic];
        if (error) {
            [skin pushNSObject:[error localizedDescription]] ;
        } else {
            lua_pushnil([skin L]) ;
        }
        if (![skin protectedCallAndTraceback:4 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didUpdateNotificationStateForCharacteristic callback: %@", UD_PERIPHERAL_TAG, theError]];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (_peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_peripheralCallbackRef];
        [skin pushNSObject:peripheral];
        [skin pushNSObject:@"peripheralDidReadRSSI"];
        if (error) {
            [skin pushNSObject:[error localizedDescription]] ;
        } else {
            [skin pushNSObject:RSSI] ;
        }
        if (![skin protectedCallAndTraceback:3 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:peripheralDidReadRSSI callback: %@", UD_PERIPHERAL_TAG, theError]];
        }
    }
}

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (_peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_peripheralCallbackRef];
        [skin pushNSObject:peripheral];
        [skin pushNSObject:@"peripheralDidUpdateName"];
        if (![skin protectedCallAndTraceback:2 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:peripheralDidUpdateName callback: %@", UD_PERIPHERAL_TAG, theError]];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray *)invalidatedServices {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (_peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_peripheralCallbackRef];
        [skin pushNSObject:peripheral];
        [skin pushNSObject:@"didModifyServices"];
        [skin pushNSObject:invalidatedServices] ;
        if (![skin protectedCallAndTraceback:3 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didModifyServices callback: %@", UD_PERIPHERAL_TAG, theError]];
        }
    }
}

@end

#pragma mark - Module Functions

/// hs._asm.btle.manager.create() -> btleObject
/// Constructor
/// Creates a BTLE Central Manager object to manage the discovery of and connections to remote BTLE peripheral objects.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a new btleObject
static int createManager(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    HSCBCentralManager *theManager = [[HSCBCentralManager alloc] init] ;
    if (theManager)
        [skin pushNSObject:theManager] ;
    else
        lua_pushnil(L) ;
    return 1 ;
}

#pragma mark - Module Methods

/// hs._asm.btle.manager:state() -> string
/// Method
/// Returns a string indicating the current state of the BTLE manager object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string matching one of the following:
///    * "unknown"      - The current state of the central manager is unknown; an update is imminent.
///    * "resetting"    - The connection with the system service was momentarily lost; an update is imminent.
///    * "unsupported"  - The machine does not support Bluetooth low energy. BTLE requires a mac which supports Bluetooth 4.
///    * "unauthorized" - Hammerspoon is not authorized to use Bluetooth low energy.
///    * "poweredOff"   - Bluetooth is currently powered off.
///    * "poweredOn"    - Bluetooth is currently powered on and available to use.
///
/// Notes:
///  * If you have set a callback with [hs._asm.btle.manager:setCallback](#setCallback), a state change will generate a callback with the "didUpdateState" message.
static int getManagerState(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_MANAGER_TAG, LS_TBREAK] ;
    HSCBCentralManager *manager = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;
    CBManagerState currentState = [manager.manager state] ;
    switch(currentState) {
        case CBManagerStateUnknown:      lua_pushstring(L, "unknown") ; break ;
        case CBManagerStateResetting:    lua_pushstring(L, "resetting") ; break ;
        case CBManagerStateUnsupported:  lua_pushstring(L, "unsupported") ; break ;
        case CBManagerStateUnauthorized: lua_pushstring(L, "unauthorized") ; break ;
        case CBManagerStatePoweredOff:   lua_pushstring(L, "poweredOff") ; break ;
        case CBManagerStatePoweredOn:    lua_pushstring(L, "poweredOn") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized state: %ld", currentState]] ;
            break ;
    }
    return 1 ;
}

static int setManagerCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_MANAGER_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];
    HSCBCentralManager *manager = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;

    // in either case, we need to remove an existing callback, so...
    manager.callbackRef = [skin luaUnref:refTable ref:manager.callbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        manager.callbackRef = [skin luaRef:refTable];
    }
    lua_pushvalue(L, 1);
    return 1;
}

static int setPeripheralCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_MANAGER_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];
    HSCBCentralManager *manager = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;

    // in either case, we need to remove an existing callback, so...
    manager.peripheralCallbackRef = [skin luaUnref:refTable ref:manager.peripheralCallbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        manager.peripheralCallbackRef = [skin luaRef:refTable];
    }
    lua_pushvalue(L, 1);
    return 1;
}

static int stopScan(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_MANAGER_TAG, LS_TBREAK] ;
    HSCBCentralManager *manager = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;
    [manager.manager stopScan] ;
    lua_pushvalue(L, 1);
    return 1;
}

static int startScan(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_MANAGER_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSCBCentralManager *manager = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;

    NSMutableArray *servicesList = (lua_gettop(L) == 2) ? [[NSMutableArray alloc] init] : nil ;
    if (servicesList) {
        NSArray *list = [skin toNSObjectAtIndex:2] ;
        __block NSString *errorReason = nil ;
        if ([list isKindOfClass:[NSArray class]]) {
            [list enumerateObjectsUsingBlock:^(NSString *item, NSUInteger idx, BOOL *stop) {
                if ([item isKindOfClass:[NSString class]]) {
                    CBUUID *uuid ;
                    @try {
                        uuid = [CBUUID UUIDWithString:item] ;
                    }
                    @catch (NSException *exception) {
                        if (exception.name == NSInternalInconsistencyException) {
                            uuid = nil ;
                        } else {
                            @throw ;
                        }
                    }
                    if (uuid) {
                        [servicesList addObject:uuid] ;
                    } else {
                        errorReason = [NSString stringWithFormat:@"string at index %lu does not represent a valid BTLE uuid", idx + 1] ;
                        *stop = YES ;
                    }
                } else {
                    errorReason = [NSString stringWithFormat:@"string expected at index %lu", idx + 1] ;
                    *stop = YES ;
                }
            }] ;
        } else {
            errorReason = @"expected list of strings" ;
        }
        if (errorReason) return luaL_argerror(L, 2, errorReason.UTF8String) ;
    }
    [manager.manager scanForPeripheralsWithServices:servicesList options:nil] ;
    lua_pushvalue(L, 1);
    return 1;
}

static int connectPeripheral(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_MANAGER_TAG, LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    HSCBCentralManager *manager    = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;
    CBPeripheral       *peripheral = [skin luaObjectAtIndex:2 toClass:"CBPeripheral"] ;
    [manager.manager connectPeripheral:peripheral options:nil] ;
    lua_pushvalue(L, 1);
    return 1;
}

static int cancelPeripheralConnection(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_MANAGER_TAG, LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    HSCBCentralManager *manager    = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;
    CBPeripheral       *peripheral = [skin luaObjectAtIndex:2 toClass:"CBPeripheral"] ;
    [manager.manager cancelPeripheralConnection:peripheral] ;
    lua_pushvalue(L, 1);
    return 1;
}

// Doesn't like not having an array... must mull over whether to include deprecated method
// instead/as-well.
//
// //FIXME: currently searches for all -- add support for limiting by CBUUID (service) array
// static int retrieveConnectedPeripherals(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, UD_MANAGER_TAG, LS_TBREAK] ;
//     HSCBCentralManager *manager = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;
//     NSArray *thePeripherals = [manager.manager retrieveConnectedPeripheralsWithServices:nil] ;
//     for (CBPeripheral *entry in thePeripherals) entry.delegate = manager ;
//     [skin pushNSObject:thePeripherals] ;
//     return 1;
// }

static int retrievePeripheralsWithIdentifiers(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_MANAGER_TAG, LS_TTABLE, LS_TBREAK] ;
    HSCBCentralManager *manager = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;
    NSMutableArray *peripherals = [[NSMutableArray alloc] init] ;
    lua_Integer i = 0 ;
    while (i < luaL_len(L, 2)) {
        i++ ;
        if (lua_rawgeti(L, 2, i) == LUA_TSTRING) {
            NSUUID   *identifier ;
            NSString *string = [skin toNSObjectAtIndex:-1] ;
            if ([string isKindOfClass:[NSString class]]) {
                identifier = [[NSUUID alloc] initWithUUIDString:string] ;
            }
            if (!identifier) {
                [skin logWarn:[NSString stringWithFormat:@"index %lld invalid UUID - skipping", i]] ;
            } else {
                [peripherals addObject:identifier] ;
            }
        } else {
            [skin logWarn:[NSString stringWithFormat:@"index %lld not a string - skipping", i]] ;
        }
        lua_pop(L, 1) ;
    }
    NSArray *thePeripherals = [manager.manager retrievePeripheralsWithIdentifiers:peripherals] ;
    for (CBPeripheral *entry in thePeripherals) entry.delegate = manager ;
    [skin pushNSObject:thePeripherals] ;
    return 1;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSCBCentralManager(lua_State *L, id obj) {
    HSCBCentralManager *manager = obj ;
    manager.selfRefCount++ ;
    void** managerPtr = lua_newuserdata(L, sizeof(HSCBCentralManager *)) ;
    *managerPtr = (__bridge_retained void *)manager ;
    luaL_getmetatable(L, UD_MANAGER_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static id toHSCBCentralManagerFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSCBCentralManager *value ;
    if (luaL_testudata(L, idx, UD_MANAGER_TAG)) {
        value = get_objectFromUserdata(__bridge HSCBCentralManager, L, idx, UD_MANAGER_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_MANAGER_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushCBUUID(lua_State *L, id obj) {
    CBUUID *theCBUUID = obj ;
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSString *answer = theCBUUID.UUIDString ;
    [skin pushNSObject:answer];
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", UD_MANAGER_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if (luaL_testudata(L, 1, UD_MANAGER_TAG) && luaL_testudata(L, 2, UD_MANAGER_TAG)) {
        HSCBCentralManager *obj1 = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;
        HSCBCentralManager *obj2 = [skin luaObjectAtIndex:2 toClass:"HSCBCentralManager"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSCBCentralManager *obj = get_objectFromUserdata(__bridge_transfer HSCBCentralManager, L, 1, UD_MANAGER_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin             = [LuaSkin sharedWithState:L] ;
            obj.peripheralCallbackRef = [skin luaUnref:refTable ref:obj.peripheralCallbackRef] ;
            obj.callbackRef           = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.manager.delegate      = nil ;
            [obj.manager stopScan] ;
            obj.manager = nil ;
            obj = nil ;
        }
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* L) {
//     return 0 ;
// }

// // Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"state",                 getManagerState},
    {"setCallback",           setManagerCallback},
    {"setPeripheralCallback", setPeripheralCallback},
    {"startScan",             startScan},
    {"stopScan",              stopScan},
    {"connectPeripheral",     connectPeripheral},
    {"retrievePeripherals",   retrievePeripheralsWithIdentifiers},
//     {"connectedPeripherals",  retrieveConnectedPeripherals},
    {"disconnectPeripheral",  cancelPeripheralConnection},

    {"__tostring",            userdata_tostring},
    {"__eq",                  userdata_eq},
    {"__gc",                  userdata_gc},
    {NULL,                    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"create", createManager},
    {NULL,     NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_btle_manager(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:UD_MANAGER_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSCBCentralManager         forClass:"HSCBCentralManager"];
    [skin registerLuaObjectHelper:toHSCBCentralManagerFromLua forClass:"HSCBCentralManager"];

    [skin registerPushNSHelper:pushCBUUID                     forClass:"CBUUID"] ;

    return 1;
}
