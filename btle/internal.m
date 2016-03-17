#import "btle.h"

static int refTable            = LUA_NOREF;
       int btleGattLookupTable = LUA_NOREF;
       int btleRefTable        = LUA_NOREF;

#pragma mark - Support Functions and Classes

@implementation HSCBCentralManager
- (id)init {
    self = [super initWithDelegate:self queue:nil] ;
    if (self) {
        _selfRef               = LUA_NOREF ;
        _callbackRef           = LUA_NOREF ;
        _peripheralCallbackRef = LUA_NOREF ;
    }
    return self ;
}

#pragma mark - CBCentralManagerDelegate Stuff

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    HSCBCentralManager *manager = (HSCBCentralManager *)central ;
    LuaSkin *skin = [LuaSkin shared] ;
    peripheral.delegate = manager ;
    if (manager.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:manager.callbackRef];
        [skin pushNSObject:manager];
        [skin pushNSObject:@"didConnectPeripheral"];
        [skin pushNSObject:peripheral] ;
        if (![skin protectedCallAndTraceback:3 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didConnectPeripheral callback: %@", USERDATA_TAG, theError]];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    HSCBCentralManager *manager = (HSCBCentralManager *)central ;
    LuaSkin *skin = [LuaSkin shared] ;
    peripheral.delegate = nil ;
    if (manager.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:manager.callbackRef];
        [skin pushNSObject:manager];
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
            [skin logWarn:[NSString stringWithFormat:@"%s:didDisconnectPeripheral callback: %@", USERDATA_TAG, theError]];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    HSCBCentralManager *manager = (HSCBCentralManager *)central ;
    LuaSkin *skin = [LuaSkin shared] ;
    if (manager.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:manager.callbackRef];
        [skin pushNSObject:manager];
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
            [skin logWarn:[NSString stringWithFormat:@"%s:didFailToConnectPeripheral callback: %@", USERDATA_TAG, theError]];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral
                                                       advertisementData:(NSDictionary *)advertisementData
                                                                    RSSI:(NSNumber *)RSSI {
    HSCBCentralManager *manager = (HSCBCentralManager *)central ;
    LuaSkin *skin = [LuaSkin shared] ;
    if (manager.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:manager.callbackRef];
        [skin pushNSObject:manager];
        [skin pushNSObject:@"didDiscoverPeripheral"];
        [skin pushNSObject:peripheral] ;
//         NSLog(@"advertisementdata = %@", advertisementData) ;
        [skin pushNSObject:advertisementData withOptions:LS_NSDescribeUnknownTypes] ;
        [skin pushNSObject:RSSI] ;
        if (![skin protectedCallAndTraceback:5 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didDiscoverPeripheral callback: %@", USERDATA_TAG, theError]];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals {
    HSCBCentralManager *manager = (HSCBCentralManager *)central ;
    LuaSkin *skin = [LuaSkin shared] ;
    if (manager.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:manager.callbackRef];
        [skin pushNSObject:manager];
        [skin pushNSObject:@"didRetrieveConnectedPeripherals"];
        for (CBPeripheral *entry in peripherals) entry.delegate = manager ;
        [skin pushNSObject:peripherals] ;
        if (![skin protectedCallAndTraceback:3 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didRetrieveConnectedPeripherals callback: %@", USERDATA_TAG, theError]];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals {
    HSCBCentralManager *manager = (HSCBCentralManager *)central ;
    LuaSkin *skin = [LuaSkin shared] ;
    if (manager.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:manager.callbackRef];
        [skin pushNSObject:manager];
        [skin pushNSObject:@"didRetrievePeripherals"];
        for (CBPeripheral *entry in peripherals) entry.delegate = manager ;
        [skin pushNSObject:peripherals] ;
        if (![skin protectedCallAndTraceback:3 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didRetrievePeripherals callback: %@", USERDATA_TAG, theError]];
        }
    }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    HSCBCentralManager *manager = (HSCBCentralManager *)central ;
    LuaSkin *skin = [LuaSkin shared] ;
    if (manager.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:manager.callbackRef];
        [skin pushNSObject:manager];
        [skin pushNSObject:@"didUpdateState"];
        if (![skin protectedCallAndTraceback:2 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:didUpdateState callback: %@", USERDATA_TAG, theError]];
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
    LuaSkin *skin = [LuaSkin shared] ;
    if (self.peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:self.peripheralCallbackRef];
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
    LuaSkin *skin = [LuaSkin shared] ;
    if (self.peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:self.peripheralCallbackRef];
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
    LuaSkin *skin = [LuaSkin shared] ;
    if (self.peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:self.peripheralCallbackRef];
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
    LuaSkin *skin = [LuaSkin shared] ;
    if (self.peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:self.peripheralCallbackRef];
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
    LuaSkin *skin = [LuaSkin shared] ;
    if (self.peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:self.peripheralCallbackRef];
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
    LuaSkin *skin = [LuaSkin shared] ;
    if (self.peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:self.peripheralCallbackRef];
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
    LuaSkin *skin = [LuaSkin shared] ;
    if (self.peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:self.peripheralCallbackRef];
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
    LuaSkin *skin = [LuaSkin shared] ;
    if (self.peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:self.peripheralCallbackRef];
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
    LuaSkin *skin = [LuaSkin shared] ;
    if (self.peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:self.peripheralCallbackRef];
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

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error {
    LuaSkin *skin = [LuaSkin shared] ;
    if (self.peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:self.peripheralCallbackRef];
        [skin pushNSObject:peripheral];
        [skin pushNSObject:@"peripheralDidUpdateRSSI"];
        if (error) {
            [skin pushNSObject:[error localizedDescription]] ;
        } else {
            lua_pushnil([skin L]) ;
        }
        if (![skin protectedCallAndTraceback:3 nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop([skin L], 1);
            [skin logWarn:[NSString stringWithFormat:@"%s:peripheralDidUpdateRSSI callback: %@", UD_PERIPHERAL_TAG, theError]];
        }
    }
}

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral {
    LuaSkin *skin = [LuaSkin shared] ;
    if (self.peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:self.peripheralCallbackRef];
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
    LuaSkin *skin = [LuaSkin shared] ;
    if (self.peripheralCallbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:self.peripheralCallbackRef];
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

static int createManager(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    HSCBCentralManager *theManager = [[HSCBCentralManager alloc] init] ;
    if (theManager)
        [skin pushNSObject:theManager] ;
    else
        lua_pushnil(L) ;
    return 1 ;
}

static int assignGattLookup(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    // this is shared among files in the module
    btleRefTable        = refTable ;
    btleGattLookupTable = [skin luaRef:btleRefTable] ;
    return 0 ;
}

#pragma mark - Module Methods

static int getManagerState(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCBCentralManager *manager = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;
    CBCentralManagerState currentState = [manager state] ;
    switch(currentState) {
        case CBCentralManagerStateUnknown:      lua_pushstring(L, "unknown") ; break ;
        case CBCentralManagerStateResetting:    lua_pushstring(L, "resetting") ; break ;
        case CBCentralManagerStateUnsupported:  lua_pushstring(L, "unsupported") ; break ;
        case CBCentralManagerStateUnauthorized: lua_pushstring(L, "unauthorized") ; break ;
        case CBCentralManagerStatePoweredOff:   lua_pushstring(L, "poweredOff") ; break ;
        case CBCentralManagerStatePoweredOn:    lua_pushstring(L, "poweredOn") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized state: %ld", currentState]] ;
            break ;
    }
    return 1 ;
}

static int setManagerCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];
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
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];
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
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCBCentralManager *manager = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;
    [manager stopScan] ;
    lua_pushvalue(L, 1);
    return 1;
}

//FIXME: currently searches for all -- add support for limiting by CBService array
static int startScan(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCBCentralManager *manager = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;
    [manager scanForPeripheralsWithServices:nil options:nil] ;
    lua_pushvalue(L, 1);
    return 1;
}

static int connectPeripheral(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    HSCBCentralManager *manager    = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;
    CBPeripheral       *peripheral = [skin luaObjectAtIndex:2 toClass:"CBPeripheral"] ;
    [manager connectPeripheral:peripheral options:nil] ;
    lua_pushvalue(L, 1);
    return 1;
}

static int cancelPeripheralConnection(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    HSCBCentralManager *manager    = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;
    CBPeripheral       *peripheral = [skin luaObjectAtIndex:2 toClass:"CBPeripheral"] ;
    [manager cancelPeripheralConnection:peripheral] ;
    lua_pushvalue(L, 1);
    return 1;
}

// Doesn't like not having an array... must mull over whether to include deprecated method
// instead/as-well.
//
// //FIXME: currently searches for all -- add support for limiting by CBUUID (service) array
// static int retrieveConnectedPeripherals(__unused lua_State *L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
//     HSCBCentralManager *manager = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;
//     NSArray *thePeripherals = [manager retrieveConnectedPeripheralsWithServices:nil] ;
//     for (CBPeripheral *entry in thePeripherals) entry.delegate = manager ;
//     [skin pushNSObject:thePeripherals] ;
//     return 1;
// }

static int retrievePeripheralsWithIdentifiers(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
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
                [skin logAtLevel:LS_LOG_WARN withMessage:[NSString stringWithFormat:@"index %lld invalid UUID - skipping", i] fromStackPos:1] ;
            } else {
                [peripherals addObject:identifier] ;
            }
        } else {
            [skin logAtLevel:LS_LOG_WARN withMessage:[NSString stringWithFormat:@"index %lld not a string - skipping", i] fromStackPos:1] ;
        }
        lua_pop(L, 1) ;
    }
    NSArray *thePeripherals = [manager retrievePeripheralsWithIdentifiers:peripherals] ;
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

    if (manager.selfRef == LUA_NOREF) {
        void** managerPtr = lua_newuserdata(L, sizeof(HSCBCentralManager *)) ;
        *managerPtr = (__bridge_retained void *)manager ;
        luaL_getmetatable(L, USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
        manager.selfRef = [[LuaSkin shared] luaRef:refTable] ;
    }

    [[LuaSkin shared] pushLuaRef:refTable ref:manager.selfRef] ;
    return 1 ;
}

static id toHSCBCentralManagerFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSCBCentralManager *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSCBCentralManager, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushCBUUID(lua_State *L, id obj) {
    CBUUID *theCBUUID = obj ;
    LuaSkin *skin = [LuaSkin shared] ;
    NSString *answer = theCBUUID.UUIDString ; // default to the UUID itself
    if (btleGattLookupTable != LUA_NOREF && btleRefTable != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:btleGattLookupTable] ;
        if (lua_getfield(L, -1, [answer UTF8String]) == LUA_TTABLE) {
            if (lua_getfield(L, -1, "name") == LUA_TSTRING) {
                answer = [skin toNSObjectAtIndex:-1] ;
            }
            lua_pop(L, 1); // name field
        }
        lua_pop(L, 2); // UUID lookup and gattLookup Table
    }
    [skin pushNSObject:answer];
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    LuaSkin *skin = [LuaSkin shared] ;
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        HSCBCentralManager *obj1 = [skin luaObjectAtIndex:1 toClass:"HSCBCentralManager"] ;
        HSCBCentralManager *obj2 = [skin luaObjectAtIndex:2 toClass:"HSCBCentralManager"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSCBCentralManager *obj = get_objectFromUserdata(__bridge_transfer HSCBCentralManager, L, 1, USERDATA_TAG) ;
    if (obj) {
        LuaSkin *skin             = [LuaSkin shared] ;
        obj.peripheralCallbackRef = [skin luaUnref:refTable ref:obj.peripheralCallbackRef] ;
        obj.callbackRef           = [skin luaUnref:refTable ref:obj.callbackRef] ;
        obj.selfRef               = [skin luaUnref:refTable ref:obj.selfRef] ;
        obj.delegate              = nil ;
        [obj stopScan] ;
        obj = nil ;
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
    {"delete",                userdata_gc},

    {"__tostring",            userdata_tostring},
    {"__eq",                  userdata_eq},
    {"__gc",                  userdata_gc},
    {NULL,                    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"create", createManager},
    {"_assignGattLookup", assignGattLookup},

    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_btle_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    btleGattLookupTable = LUA_NOREF ;
    btleRefTable        = LUA_NOREF;

    [skin registerPushNSHelper:pushHSCBCentralManager         forClass:"HSCBCentralManager"];
    [skin registerLuaObjectHelper:toHSCBCentralManagerFromLua forClass:"HSCBCentralManager"];

    [skin registerPushNSHelper:pushCBUUID                     forClass:"CBUUID"] ;

    luaopen_hs__asm_btle_characteristic(L) ; lua_setfield(L, -2, "characteristic") ;
    luaopen_hs__asm_btle_descriptor(L) ;     lua_setfield(L, -2, "descriptor") ;
    luaopen_hs__asm_btle_peripheral(L) ;     lua_setfield(L, -2, "peripheral") ;
    luaopen_hs__asm_btle_service(L) ;        lua_setfield(L, -2, "service") ;

    return 1;
}
