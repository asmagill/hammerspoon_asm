#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import <CoreBluetooth/CoreBluetooth.h>

// #import "../hammerspoon.h"

#define USERDATA_TAG          "hs._asm.btle"
#define UD_PERIPHERAL_TAG     "hs._asm.btle.peripheral"
#define UD_SERVICE_TAG        "hs._asm.btle.services"
#define UD_CHARACTERISTIC_TAG "hs._asm.btle.charactersitic"
#define UD_DESCRIPTOR_TAG     "hs._asm.btle.descriptor"

static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, TAG) (objType*)*((void**)luaL_checkudata(L, idx, TAG))

#pragma mark - Support Functions and Classes

@interface HSCBCentralManager : CBCentralManager <CBCentralManagerDelegate, CBPeripheralDelegate>
@property int selfRef ;
@property int callbackRef ;
@property int peripheralCallbackRef ;
@end

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
        // we discovered it, so I guess we're now it's delegate... at least until I find that this breaks something
        peripheral.delegate = manager ;
        [skin pushNSObject:peripheral] ;
        [skin pushNSObject:advertisementData] ;
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
                [skin logWarn:[NSString stringWithFormat:@"index %lld invalid UUID - skipping", i] fromLevel:1] ;
            } else {
                [peripherals addObject:identifier] ;
            }
        } else {
            [skin logWarn:[NSString stringWithFormat:@"index %lld not a string - skipping", i] fromLevel:1] ;
        }
        lua_pop(L, 1) ;
    }
    NSArray *thePeripherals = [manager retrievePeripheralsWithIdentifiers:peripherals] ;
    for (CBPeripheral *entry in thePeripherals) entry.delegate = manager ;
    [skin pushNSObject:thePeripherals] ;
    return 1;
}

#pragma mark - Peripheral Methods

static int peripheralIdentifier(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [skin pushNSObject:[thePeripheral.identifier UUIDString]] ;
    return 1 ;
}

static int peripheralName(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [skin pushNSObject:thePeripheral.name] ;
    return 1 ;
}

static int peripheralServices(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [skin pushNSObject:thePeripheral.services] ;
    return 1 ;
}

//FIXME: currently searches for all -- add support for limiting by CBService array
static int peripheralDiscoverServices(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [thePeripheral discoverServices:nil] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

//FIXME: currently searches for all -- add support for limiting by CBService array
static int peripheralDiscoverIncludedServices(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    CBService    *theService    = [skin luaObjectAtIndex:2 toClass:"CBService"] ;
    [thePeripheral discoverIncludedServices:nil forService:theService] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

//FIXME: currently searches for all -- add support for limiting by CBCharacteristic array
static int peripheralDiscoverCharacteristicsForService(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    CBService    *theService    = [skin luaObjectAtIndex:2 toClass:"CBService"] ;
    [thePeripheral discoverCharacteristics:nil forService:theService] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int peripheralDiscoverDescriptorsForCharacteristic(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBPeripheral     *thePeripheral     = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:2 toClass:"CBCharacteristic"] ;
    [thePeripheral discoverDescriptorsForCharacteristic:theCharacteristic] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int peripheralReadValueForCharacteristic(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBPeripheral     *thePeripheral     = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:2 toClass:"CBCharacteristic"] ;
    [thePeripheral readValueForCharacteristic:theCharacteristic] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int peripheralReadValueForDescriptor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    CBDescriptor *theDescriptor = [skin luaObjectAtIndex:2 toClass:"CBDescriptor"] ;
    [thePeripheral readValueForDescriptor:theDescriptor] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

// TODO: - (void)writeValue:(NSData *)data forCharacteristic:(CBCharacteristic *)characteristic type:(CBCharacteristicWriteType)type
// TODO: - (void)writeValue:(NSData *)data forDescriptor:(CBDescriptor *)descriptor

static int peripheralSetNotifyForCharacteristic(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBOOLEAN, LS_TBREAK] ;
    CBPeripheral     *thePeripheral     = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:2 toClass:"CBCharacteristic"] ;
    [thePeripheral setNotifyValue:(BOOL)lua_toboolean(L, 3) forCharacteristic:theCharacteristic] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int peripheralState(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    CBPeripheralState theState = thePeripheral.state ;
    switch(theState) {
        case CBPeripheralStateDisconnected: lua_pushstring(L, "disconnected") ; break ;
        case CBPeripheralStateConnecting:   lua_pushstring(L, "connecting") ; break ;
        case CBPeripheralStateConnected:    lua_pushstring(L, "connected") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized state: %ld", theState]] ;
            break ;
    }
    return 1 ;
}

static int peripheralRSSI(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [skin pushNSObject:thePeripheral.RSSI] ;
    return 1 ;
}

static int peripheralReadRSSI(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    CBPeripheral *thePeripheral = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
    [thePeripheral readRSSI] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Service Methods

static int serviceUUID(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *theService = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    [skin pushNSObject:theService.UUID] ;
    return 1 ;
}

static int servicePeripheral(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *theService = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    [skin pushNSObject:theService.peripheral] ;
    return 1 ;
}

static int serviceCharacteristics(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *theService = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    [skin pushNSObject:theService.characteristics] ;
    return 1 ;
}

static int serviceIncludedServices(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *theService = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    [skin pushNSObject:theService.includedServices] ;
    return 1 ;
}

static int servicePrimary(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_SERVICE_TAG, LS_TBREAK] ;
    CBService *theService = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
    lua_pushboolean(L, theService.isPrimary) ;
    return 1 ;
}

#pragma mark - Characteristic Methods

static int characteristicUUID(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    [skin pushNSObject:theCharacteristic.UUID] ;
    return 1 ;
}

static int characteristicService(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    [skin pushNSObject:theCharacteristic.service] ;
    return 1 ;
}

static int characteristicValue(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    [skin pushNSObject:theCharacteristic.value] ;
    return 1 ;
}

static int characteristicDescriptors(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    [skin pushNSObject:theCharacteristic.descriptors] ;
    return 1 ;
}

static int characteristicProperties(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    lua_pushinteger(L, theCharacteristic.properties) ;
    return 1 ;
}

static int characteristicIsNotifying(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    lua_pushinteger(L, theCharacteristic.isNotifying) ;
    return 1 ;
}

static int characteristicIsBroadcasted(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_CHARACTERISTIC_TAG, LS_TBREAK] ;
    CBCharacteristic *theCharacteristic = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
    lua_pushinteger(L, theCharacteristic.isBroadcasted) ;
    return 1 ;
}

#pragma mark - Descriptor Methods

static int descriptorUUID(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TBREAK] ;
    CBDescriptor *theDescriptor = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
    [skin pushNSObject:theDescriptor.UUID] ;
    return 1 ;
}

static int descriptorValue(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TBREAK] ;
    CBDescriptor *theDescriptor = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
    [skin pushNSObject:theDescriptor.value] ;
    return 1 ;
}

static int descriptorCharacteristic(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, UD_DESCRIPTOR_TAG, LS_TBREAK] ;
    CBDescriptor *theDescriptor = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
    [skin pushNSObject:theDescriptor.characteristic] ;
    return 1 ;
}

#pragma mark - Module Constants

static int pushCBUUIDStrings(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
    [skin pushNSObject:CBUUIDCharacteristicExtendedPropertiesString] ;        lua_setfield(L, -2, "characteristicExtendedProperties") ;
    [skin pushNSObject:CBUUIDCharacteristicUserDescriptionString] ;           lua_setfield(L, -2, "characteristicUserDescription") ;
    [skin pushNSObject:CBUUIDClientCharacteristicConfigurationString] ;       lua_setfield(L, -2, "clientCharacteristicConfiguration") ;
    [skin pushNSObject:CBUUIDServerCharacteristicConfigurationString] ;       lua_setfield(L, -2, "serverCharacteristicConfiguration") ;
    [skin pushNSObject:CBUUIDCharacteristicFormatString] ;                    lua_setfield(L, -2, "characteristicFormat") ;
    [skin pushNSObject:CBUUIDCharacteristicAggregateFormatString] ;           lua_setfield(L, -2, "characteristicAggregateFormat") ;
    [skin pushNSObject:CBUUIDGenericAccessProfileString] ;                    lua_setfield(L, -2, "genericAccessProfile") ;
    [skin pushNSObject:CBUUIDGenericAttributeProfileString] ;                 lua_setfield(L, -2, "genericAttributeProfile") ;
    [skin pushNSObject:CBUUIDDeviceNameString] ;                              lua_setfield(L, -2, "deviceName") ;
    [skin pushNSObject:CBUUIDAppearanceString] ;                              lua_setfield(L, -2, "appearance") ;
    [skin pushNSObject:CBUUIDPeripheralPrivacyFlagString] ;                   lua_setfield(L, -2, "peripheralPrivacyFlag") ;
    [skin pushNSObject:CBUUIDReconnectionAddressString] ;                     lua_setfield(L, -2, "reconnectionAddress") ;
    [skin pushNSObject:CBUUIDPeripheralPreferredConnectionParametersString] ; lua_setfield(L, -2, "peripheralPreferredConnectionParameters") ;
    [skin pushNSObject:CBUUIDServiceChangedString] ;                          lua_setfield(L, -2, "serviceChanged") ;
    [skin pushNSObject:CBUUIDValidRangeString] ;                              lua_setfield(L, -2, "validRange") ;
    return 1 ;
}

static int pushCBCharacteristicProperties(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, CBCharacteristicPropertyBroadcast) ;                  lua_setfield(L, -2, "broadcast") ;
    lua_pushinteger(L, CBCharacteristicPropertyRead) ;                       lua_setfield(L, -2, "read") ;
    lua_pushinteger(L, CBCharacteristicPropertyWriteWithoutResponse) ;       lua_setfield(L, -2, "writeWithoutResponse") ;
    lua_pushinteger(L, CBCharacteristicPropertyWrite) ;                      lua_setfield(L, -2, "write") ;
    lua_pushinteger(L, CBCharacteristicPropertyNotify) ;                     lua_setfield(L, -2, "notify") ;
    lua_pushinteger(L, CBCharacteristicPropertyIndicate) ;                   lua_setfield(L, -2, "indicate") ;
    lua_pushinteger(L, CBCharacteristicPropertyAuthenticatedSignedWrites) ;  lua_setfield(L, -2, "authenticatedSignedWrites") ;
    lua_pushinteger(L, CBCharacteristicPropertyExtendedProperties) ;         lua_setfield(L, -2, "extendedProperties") ;
    lua_pushinteger(L, CBCharacteristicPropertyNotifyEncryptionRequired) ;   lua_setfield(L, -2, "notifyEncryptionRequired") ;
    lua_pushinteger(L, CBCharacteristicPropertyIndicateEncryptionRequired) ; lua_setfield(L, -2, "indicateEncryptionRequired") ;
    return 1 ;
}

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

static int pushCBPeripheralAsUD(lua_State *L, id obj) {
    CBPeripheral *theCBPeripheral = obj ;
    void** peripheralPtr = lua_newuserdata(L, sizeof(CBPeripheral *)) ;
    *peripheralPtr = (__bridge_retained void *)theCBPeripheral ;

    luaL_getmetatable(L, UD_PERIPHERAL_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static int pushCBServiceAsUD(lua_State *L, id obj) {
    CBService *theCBService = obj ;
    void** servicePtr = lua_newuserdata(L, sizeof(CBService *)) ;
    *servicePtr = (__bridge_retained void *)theCBService ;

    luaL_getmetatable(L, UD_SERVICE_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static int pushCBCharacteristicAsUD(lua_State *L, id obj) {
    CBCharacteristic *theCBCharacteristic = obj ;
    void** characteristicPtr = lua_newuserdata(L, sizeof(CBCharacteristic *)) ;
    *characteristicPtr = (__bridge_retained void *)theCBCharacteristic ;

    luaL_getmetatable(L, UD_CHARACTERISTIC_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static int pushCBDescriptorAsUD(lua_State *L, id obj) {
    CBDescriptor *theCBDescriptor = obj ;
    void** descriptorPtr = lua_newuserdata(L, sizeof(CBDescriptor *)) ;
    *descriptorPtr = (__bridge_retained void *)theCBDescriptor ;

    luaL_getmetatable(L, UD_DESCRIPTOR_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

id toCBPeripheralFromLuaUD(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    CBPeripheral *value ;
    if (luaL_testudata(L, idx, UD_PERIPHERAL_TAG)) {
        value = get_objectFromUserdata(__bridge CBPeripheral, L, idx, UD_PERIPHERAL_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_PERIPHERAL_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

id toCBServiceFromLuaUD(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    CBService *value ;
    if (luaL_testudata(L, idx, UD_SERVICE_TAG)) {
        value = get_objectFromUserdata(__bridge CBService, L, idx, UD_SERVICE_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_SERVICE_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

id toCBCharacteristicFromLuaUD(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    CBCharacteristic *value ;
    if (luaL_testudata(L, idx, UD_CHARACTERISTIC_TAG)) {
        value = get_objectFromUserdata(__bridge CBCharacteristic, L, idx, UD_CHARACTERISTIC_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_CHARACTERISTIC_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

id toCBDescriptorFromLuaUD(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    CBDescriptor *value ;
    if (luaL_testudata(L, idx, UD_DESCRIPTOR_TAG)) {
        value = get_objectFromUserdata(__bridge CBDescriptor, L, idx, UD_DESCRIPTOR_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_DESCRIPTOR_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushCBUUID(lua_State *L, id obj) {
    CBUUID *theCBUUID = obj ;
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
    [skin pushNSObject:theCBUUID.UUIDString] ; lua_setfield(L, -2, "UUID") ;
    [skin pushNSObject:theCBUUID.data] ;       lua_setfield(L, -2, "data") ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    if (luaL_testudata(L, 1, UD_PERIPHERAL_TAG)) {
        CBPeripheral *obj = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
        [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_PERIPHERAL_TAG, [obj name], lua_topointer(L, 1)]] ;
    } else if (luaL_testudata(L, 1, UD_SERVICE_TAG)) {
        CBService *obj = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
        [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_SERVICE_TAG, [[obj UUID] UUIDString], lua_topointer(L, 1)]] ;
    } else if (luaL_testudata(L, 1, UD_CHARACTERISTIC_TAG)) {
        CBCharacteristic *obj = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
        [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_CHARACTERISTIC_TAG, [[obj UUID] UUIDString], lua_topointer(L, 1)]] ;
    } else if (luaL_testudata(L, 1, UD_DESCRIPTOR_TAG)) {
        CBDescriptor *obj = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
        [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_DESCRIPTOR_TAG, [[obj UUID] UUIDString], lua_topointer(L, 1)]] ;
    } else {
        [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    }
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
    } else if (luaL_testudata(L, 1, UD_PERIPHERAL_TAG) && luaL_testudata(L, 2, UD_PERIPHERAL_TAG)) {
        CBPeripheral *obj1 = [skin luaObjectAtIndex:1 toClass:"CBPeripheral"] ;
        CBPeripheral *obj2 = [skin luaObjectAtIndex:2 toClass:"CBPeripheral"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else if (luaL_testudata(L, 1, UD_SERVICE_TAG) && luaL_testudata(L, 2, UD_SERVICE_TAG)) {
        CBService *obj1 = [skin luaObjectAtIndex:1 toClass:"CBService"] ;
        CBService *obj2 = [skin luaObjectAtIndex:2 toClass:"CBService"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else if (luaL_testudata(L, 1, UD_CHARACTERISTIC_TAG) && luaL_testudata(L, 2, UD_CHARACTERISTIC_TAG)) {
        CBCharacteristic *obj1 = [skin luaObjectAtIndex:1 toClass:"CBCharacteristic"] ;
        CBCharacteristic *obj2 = [skin luaObjectAtIndex:2 toClass:"CBCharacteristic"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else if (luaL_testudata(L, 1, UD_DESCRIPTOR_TAG) && luaL_testudata(L, 2, UD_DESCRIPTOR_TAG)) {
        CBDescriptor *obj1 = [skin luaObjectAtIndex:1 toClass:"CBDescriptor"] ;
        CBDescriptor *obj2 = [skin luaObjectAtIndex:2 toClass:"CBDescriptor"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    if (luaL_testudata(L, 1, UD_SERVICE_TAG) || luaL_testudata(L, 1, UD_CHARACTERISTIC_TAG) || luaL_testudata(L, 1, UD_DESCRIPTOR_TAG)) {
        id obj = (__bridge_transfer id)*((void**)lua_touserdata(L, 1)) ;
        if (obj) obj = nil ;
    } else if (luaL_testudata(L, 1, UD_PERIPHERAL_TAG)) {
        CBPeripheral *obj = get_objectFromUserdata(__bridge_transfer CBPeripheral, L, 1, UD_PERIPHERAL_TAG) ;
        if (obj) {
            obj.delegate = nil ;
            obj          = nil ;
        }
    } else {
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

static const luaL_Reg peripheral_metaLib[] = {
    {"identifier",                        peripheralIdentifier},
    {"name",                              peripheralName},
    {"services",                          peripheralServices},
    {"discoverServices",                  peripheralDiscoverServices},
    {"discoverIncludedServices",          peripheralDiscoverIncludedServices},
    {"discoverServiceCharacteristics",    peripheralDiscoverCharacteristicsForService},
    {"discoverCharacteristicDescriptors", peripheralDiscoverDescriptorsForCharacteristic},
    {"readValueForCharacteristic",        peripheralReadValueForCharacteristic},
    {"readValueForDescriptor",            peripheralReadValueForDescriptor},
    {"watchCharacteristic",               peripheralSetNotifyForCharacteristic},
    {"state",                             peripheralState},
    {"RSSI",                              peripheralRSSI},
    {"readRSSI",                          peripheralReadRSSI},

    {"__tostring",                        userdata_tostring},
    {"__eq",                              userdata_eq},
    {"__gc",                              userdata_gc},
    {NULL,                                NULL}
};

static const luaL_Reg service_metaLib[] = {
    {"UUID",             serviceUUID},
    {"peripheral",       servicePeripheral},
    {"characteristics",  serviceCharacteristics},
    {"includedServices", serviceIncludedServices},
    {"primary",          servicePrimary},

    {"__tostring",       userdata_tostring},
    {"__eq",             userdata_eq},
    {"__gc",             userdata_gc},
    {NULL,               NULL}
};

static const luaL_Reg characteristic_metaLib[] = {
    {"UUID",          characteristicUUID},
    {"service",       characteristicService},
    {"value",         characteristicValue},
    {"descriptors",   characteristicDescriptors},
    {"properties",    characteristicProperties},
    {"isNotifying",   characteristicIsNotifying},
    {"isBroadcasted", characteristicIsBroadcasted},

    {"__tostring",  userdata_tostring},
    {"__eq",        userdata_eq},
    {"__gc",        userdata_gc},
    {NULL,          NULL}
};

static const luaL_Reg descriptor_metaLib[] = {
    {"UUID",           descriptorUUID},
    {"value",          descriptorValue},
    {"characteristic", descriptorCharacteristic},

    {"__tostring",     userdata_tostring},
    {"__eq",           userdata_eq},
    {"__gc",           userdata_gc},
    {NULL,             NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"create", createManager},
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

    pushCBUUIDStrings(L) ;              lua_setfield(L, -2, "UUIDLookup") ;
    pushCBCharacteristicProperties(L) ; lua_setfield(L, -2, "characteristicProperties") ;

    [skin registerPushNSHelper:pushHSCBCentralManager         forClass:"HSCBCentralManager"];
    [skin registerLuaObjectHelper:toHSCBCentralManagerFromLua forClass:"HSCBCentralManager"];

// sub types handled by this module
    [skin registerObject:UD_PERIPHERAL_TAG     objectFunctions:peripheral_metaLib] ;
    [skin registerPushNSHelper:pushCBPeripheralAsUD           forClass:"CBPeripheral"] ;
    [skin registerLuaObjectHelper:toCBPeripheralFromLuaUD     forClass:"CBPeripheral"];

    [skin registerObject:UD_SERVICE_TAG        objectFunctions:service_metaLib] ;
    [skin registerPushNSHelper:pushCBServiceAsUD              forClass:"CBService"] ;
    [skin registerLuaObjectHelper:toCBServiceFromLuaUD        forClass:"CBService"];

    [skin registerObject:UD_CHARACTERISTIC_TAG objectFunctions:characteristic_metaLib] ;
    [skin registerPushNSHelper:pushCBCharacteristicAsUD       forClass:"CBCharacteristic"] ;
    [skin registerLuaObjectHelper:toCBCharacteristicFromLuaUD forClass:"CBCharacteristic"];

    [skin registerObject:UD_DESCRIPTOR_TAG     objectFunctions:descriptor_metaLib] ;
    [skin registerPushNSHelper:pushCBDescriptorAsUD           forClass:"CBDescriptor"] ;
    [skin registerLuaObjectHelper:toCBDescriptorFromLuaUD     forClass:"CBDescriptor"];

// other convertors
    [skin registerPushNSHelper:pushCBUUID                     forClass:"CBUUID"] ;

    return 1;
}
