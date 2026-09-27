@import Cocoa ;
@import LuaSkin ;
@import CoreBluetooth ;

#import "libbtle.h"

static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

static NSDictionary *BTLE_STATES ;
static NSDictionary *BTLE_AUTHORIZATION ;
static NSDictionary *BTLE_CONNECT_OPTIONS ;

@interface HSBTLECentralManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>
@property int              selfRefCount ;
@property int              callbackRef ;
@property CBCentralManager *manager ;
@end

@implementation HSBTLECentralManager
- (instancetype)init {
    self = [super init] ;
    if (self) {
        _selfRefCount = 0 ;
        _callbackRef  = LUA_NOREF ;
        _manager      = [[CBCentralManager alloc] initWithDelegate:self queue:nil] ;
    }
    return self ;
}

- (void) callbackHamster:(NSArray *)arguments forMethod:(NSString *)method {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (!arguments) arguments = [NSArray array] ;

    if (_callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:self] ;
        for (NSObject *arg in arguments) [skin pushNSObject:arg withOptions:LS_NSDescribeUnknownTypes] ;

        if (![skin protectedCallAndTraceback:(1 + (int)arguments.count) nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop(skin.L, 1);
            [skin logError:@"%s:%@ callback: %@", USERDATA_TAG, method, theError] ;
        }
    }
}

- (void) callbackHamster:(NSArray *)arguments forPeripheral:(CBPeripheral *)peripheral
                                                 withMethod:(NSString *)method {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (!arguments) arguments = [NSArray array] ;

    if (peripheral.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:peripheral.refTable ref:peripheral.callbackRef] ;
        [skin pushNSObject:peripheral] ;
        for (NSObject *arg in arguments) [skin pushNSObject:arg withOptions:LS_NSDescribeUnknownTypes] ;

        if (![skin protectedCallAndTraceback:(1 + (int)arguments.count) nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop(skin.L, 1);
            [skin logError:@"%s:%@ peripheral callback: %@", USERDATA_TAG, method, theError] ;
        }
    } else {
        [self callbackHamster:@[ @"peripheralCB", [@[peripheral] arrayByAddingObjectsFromArray:arguments] ]
                    forMethod:method] ;
    }
}

- (void) callbackHamster:(NSArray *)arguments forService:(CBService *)service
                                              withMethod:(NSString *)method {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (!arguments) arguments = [NSArray array] ;

    if (service.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:service.refTable ref:service.callbackRef] ;
        [skin pushNSObject:service] ;
        for (NSObject *arg in arguments) [skin pushNSObject:arg withOptions:LS_NSDescribeUnknownTypes] ;

        if (![skin protectedCallAndTraceback:(1 + (int)arguments.count) nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop(skin.L, 1);
            [skin logError:@"%s:%@ service callback: %@", USERDATA_TAG, method, theError] ;
        }
    } else {
        [self callbackHamster:@[ @"serviceCB", [@[service] arrayByAddingObjectsFromArray:arguments] ]
                forPeripheral:service.peripheral
                   withMethod:method] ;
    }
}

- (void) callbackHamster:(NSArray *)arguments forCharacteristic:(CBCharacteristic *)characteristic
                                                     withMethod:(NSString *)method {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (!arguments) arguments = [NSArray array] ;

    if (characteristic.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:characteristic.refTable ref:characteristic.callbackRef] ;
        [skin pushNSObject:characteristic] ;
        for (NSObject *arg in arguments) [skin pushNSObject:arg withOptions:LS_NSDescribeUnknownTypes] ;

        if (![skin protectedCallAndTraceback:(1 + (int)arguments.count) nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop(skin.L, 1);
            [skin logError:@"%s:%@ characteristic callback: %@", USERDATA_TAG, method, theError] ;
        }
    } else {
        [self callbackHamster:@[ @"characteristicCB", [@[characteristic] arrayByAddingObjectsFromArray:arguments] ]
                   forService:characteristic.service
                   withMethod:method] ;
    }
}

- (void) callbackHamster:(NSArray *)arguments forDescriptor:(CBDescriptor *)descriptor
                                                     withMethod:(NSString *)method {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    if (!arguments) arguments = [NSArray array] ;

    if (descriptor.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:descriptor.refTable ref:descriptor.callbackRef] ;
        [skin pushNSObject:descriptor] ;
        for (NSObject *arg in arguments) [skin pushNSObject:arg withOptions:LS_NSDescribeUnknownTypes] ;

        if (![skin protectedCallAndTraceback:(1 + (int)arguments.count) nresults:0]) {
            NSString *theError = [skin toNSObjectAtIndex:-1];
            lua_pop(skin.L, 1);
            [skin logError:@"%s:%@ descriptor callback: %@", USERDATA_TAG, method, theError] ;
        }
    } else {
        [self callbackHamster:@[ @"descriptorCB", [@[descriptor] arrayByAddingObjectsFromArray:arguments] ]
            forCharacteristic:descriptor.characteristic
                   withMethod:method] ;
    }
}

#pragma mark * CBCentralManagerDelegate methods

- (void) centralManagerDidUpdateState:(CBCentralManager *)central {
    CBManagerState newState = _manager.state ;
    NSString       *state   = BTLE_STATES[@(newState)] ;

    if (!state) state = [NSString stringWithFormat:@"unrecognized state: %ld", newState] ;
    [self callbackHamster:@[ @"stateChanged", state ] forMethod:NSStringFromSelector(_cmd)] ;
}

- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral
                                                        advertisementData:(NSDictionary<NSString *,id> *)advertisementData
                                                                     RSSI:(NSNumber *)RSSI {
    peripheral.delegate = self ;
    [self callbackHamster:@[ @"discovered", peripheral, advertisementData, RSSI ] forMethod:NSStringFromSelector(_cmd)] ;
}


- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    peripheral.delegate = self ;
    [self callbackHamster:@[ @"connected", peripheral ] forMethod:NSStringFromSelector(_cmd)] ;
}

- (void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral
                                                                      error:(NSError *)error {
    peripheral.delegate = self ;
    NSArray *argumentArray = @[ @"disconnected", peripheral ] ;
    if (error) argumentArray = [argumentArray arrayByAddingObject:error.localizedDescription] ;
    [self callbackHamster:argumentArray forMethod:NSStringFromSelector(_cmd)] ;
}

// - (void) centralManager:(CBCentralManager *) central didDisconnectPeripheral:(CBPeripheral *)peripheral timestamp:(CFAbsoluteTime)timestamp isReconnecting:(BOOL)isReconnecting error:(NSError *)error ;

- (void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral
                                                                         error:(NSError *)error {
    peripheral.delegate = self ;
    NSArray *argumentArray = @[ @"connectionFailed", peripheral ] ;
    if (error) argumentArray = [argumentArray arrayByAddingObject:error.localizedDescription] ;
    [self callbackHamster:argumentArray forMethod:NSStringFromSelector(_cmd)] ;
}

// - (void) centralManager:(CBCentralManager *) central willRestoreState:(NSDictionary<NSString *,id> *) dict;

#pragma mark * CBPeripheralDelegate methods

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    NSArray *argumentArray = @[ @"discoveredServices" ] ;
    if (error) argumentArray = [argumentArray arrayByAddingObject:error.localizedDescription] ;
    [self callbackHamster:argumentArray forPeripheral:peripheral withMethod:NSStringFromSelector(_cmd)] ;
}

- (void) peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray<CBService *> *)invalidatedServices {
    NSArray *argumentArray = @[ @"invalidatedServices", invalidatedServices ] ;
    [self callbackHamster:argumentArray forPeripheral:peripheral withMethod:NSStringFromSelector(_cmd)] ;
}

// // - (void) peripheral:(CBPeripheral *) peripheral didOpenL2CAPChannel:(CBL2CAPChannel *) channel error:(NSError *) error;

- (void) peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI
                                                     error:(NSError *)error {
    NSArray *argumentArray = @[ @"readRSSI", RSSI ] ;
    if (error) argumentArray = [argumentArray arrayByAddingObject:error.localizedDescription] ;
    [self callbackHamster:argumentArray forPeripheral:peripheral withMethod:NSStringFromSelector(_cmd)] ;
}

- (void) peripheralDidUpdateName:(CBPeripheral *)peripheral {
    NSArray *argumentArray = @[ @"nameChanged" ] ;
    [self callbackHamster:argumentArray forPeripheral:peripheral withMethod:NSStringFromSelector(_cmd)] ;
}

- (void) peripheralIsReadyToSendWriteWithoutResponse:(CBPeripheral *)peripheral {
    NSArray *argumentArray = @[ @"readyToWrite" ] ;
    [self callbackHamster:argumentArray forPeripheral:peripheral withMethod:NSStringFromSelector(_cmd)] ;
}

#pragma mark * CBPeripheralDelegate methods for characteristic

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic
                                                                                 error:(NSError *) error {
    NSArray *argumentArray = @[ @"discoveredDescriptors" ] ;
    if (error) argumentArray = [argumentArray arrayByAddingObject:error.localizedDescription] ;
    [self callbackHamster:argumentArray forCharacteristic:characteristic withMethod:NSStringFromSelector(_cmd)] ;
}

- (void) peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
                                                                                     error:(NSError *)error {
    NSArray *argumentArray = @[ @"notificationStateChanged" ] ;
    if (error) argumentArray = [argumentArray arrayByAddingObject:error.localizedDescription] ;
    [self callbackHamster:argumentArray forCharacteristic:characteristic withMethod:NSStringFromSelector(_cmd)] ;
}

- (void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
                                                                         error:(NSError *)error {
    NSArray *argumentArray = @[ @"valueUpdated" ] ;
    if (error) argumentArray = [argumentArray arrayByAddingObject:error.localizedDescription] ;
    [self callbackHamster:argumentArray forCharacteristic:characteristic withMethod:NSStringFromSelector(_cmd)] ;
}

- (void) peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
                                                                        error:(NSError *)error {
    NSArray *argumentArray = @[ @"valueWritten" ] ;
    if (error) argumentArray = [argumentArray arrayByAddingObject:error.localizedDescription] ;
    [self callbackHamster:argumentArray forCharacteristic:characteristic withMethod:NSStringFromSelector(_cmd)] ;
}

#pragma mark * CBPeripheralDelegate methods for descriptor

- (void) peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor
                                                                     error:(NSError *)error {
    NSArray *argumentArray = @[ @"valueUpdated" ] ;
    if (error) argumentArray = [argumentArray arrayByAddingObject:error.localizedDescription] ;
    [self callbackHamster:argumentArray forDescriptor:descriptor withMethod:NSStringFromSelector(_cmd)] ;
}

- (void) peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor
                                                                    error:(NSError *)error {
    NSArray *argumentArray = @[ @"valueWritten" ] ;
    if (error) argumentArray = [argumentArray arrayByAddingObject:error.localizedDescription] ;
    [self callbackHamster:argumentArray forDescriptor:descriptor withMethod:NSStringFromSelector(_cmd)] ;
}

#pragma mark * CBPeripheralDelegate methods for service

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service
                                                                              error:(NSError *)error {
    NSArray *argumentArray = @[ @"discoveredCharacteristics" ] ;
    if (error) argumentArray = [argumentArray arrayByAddingObject:error.localizedDescription] ;
    [self callbackHamster:argumentArray forService:service withMethod:NSStringFromSelector(_cmd)] ;
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service
                                                                               error:(NSError *) error {
    NSArray *argumentArray = @[ @"discoveredServices" ] ;
    if (error) argumentArray = [argumentArray arrayByAddingObject:error.localizedDescription] ;
    [self callbackHamster:argumentArray forService:service withMethod:NSStringFromSelector(_cmd)] ;
}

@end

#pragma mark - Module Functions -

static int btle_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    HSBTLECentralManager *manager = [[HSBTLECentralManager alloc] init] ;
    [skin pushNSObject:manager] ;
    return 1 ;
}

static int btle_authorization(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CBManagerAuthorization currentAuth = CBCentralManager.authorization ;
    NSString *authorization = BTLE_AUTHORIZATION[@(currentAuth)] ;
    if (!authorization) authorization = [NSString stringWithFormat:@"unrecognized authorization state: %ld", currentAuth] ;
    [skin pushNSObject:authorization] ;
    return 1 ;
}

#pragma mark - Module Methods -

static int btle_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSBTLECentralManager *manager = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        manager.callbackRef = [skin luaUnref:refTable ref:manager.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            manager.callbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (manager.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:manager.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int btle_state(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSBTLECentralManager *manager = [skin toNSObjectAtIndex:1] ;

    CBManagerState currentState = manager.manager.state ;
    NSString *state = BTLE_STATES[@(currentState)] ;
    if (!state) state = [NSString stringWithFormat:@"unrecognized state: %ld", currentState] ;
    [skin pushNSObject:state] ;
    return 1 ;
}

static int btle_connectPeripheral(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TUSERDATA, UD_PERIPHERAL_TAG,
                    LS_TBOOLEAN | LS_TTABLE | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSBTLECentralManager *manager    = [skin toNSObjectAtIndex:1] ;
    CBPeripheral         *peripheral = [skin toNSObjectAtIndex:2] ;

    NSMutableDictionary *options = [NSMutableDictionary dictionary] ;
    if (lua_gettop(L) > 2) {
        if (lua_type(L, 3) == LUA_TBOOLEAN) {
            if (@available(macOS 14.0, *)) {
                options[CBConnectPeripheralOptionEnableAutoReconnect] = @(lua_toboolean(L, 3)) ;
            } else {
                [skin logWarn:@"autoReconnect only supported on macOS 14.0 and newer; ignoring"] ;
            }
        } else {
            lua_pushnil(L);               // first key
            while (lua_next(L, 3) != 0) { // puts 'key' (at index -2) and 'value' (at index -1)
                if (lua_type(L, -2) == LUA_TSTRING) {
                    NSString     *key        = [skin toNSObjectAtIndex:-1] ;
                    NSDictionary *definition = BTLE_CONNECT_OPTIONS[key] ;
                    if (definition) {
                        NSObject *optionValue = nil ;
                        NSString *optionKey   = definition[@"key"] ;
                        NSString *optionType  = definition[@"type"] ;
                        if ([optionType isEqualToString:@"boolean"]) {
                            if (lua_type(L, -1) == LUA_TBOOLEAN) optionValue = [skin toNSObjectAtIndex:-1] ;
                        } else if ([optionType isEqualToString:@"number"]) {
                            if (lua_type(L, -1) == LUA_TNUMBER)  optionValue = [skin toNSObjectAtIndex:-1] ;
                        } else {
                            return luaL_argerror(L, 3,
                                [NSString stringWithFormat:@"unrecognized option type %@ for %@; inform developers", optionType, key].UTF8String) ;
                        }

                        if (optionValue) {
                            if (@available(macOS 14.0, *)) {
                                options[optionKey] = optionValue ;
                            } else {
                                if ([key isEqualToString:@"autoReconnect"]) {
                                    [skin logWarn:@"autoReconnect only supported on macOS 14.0 and newer; ignoring"] ;
                                } else {
                                    options[optionKey] = optionValue ;
                                }
                            }
                        } else {
                            return luaL_argerror(L, 3,
                                [NSString stringWithFormat:@"%@ requires a value type of %@", key, optionType].UTF8String) ;
                        }
                    } else {
                        return luaL_argerror(L, 3,
                            [NSString stringWithFormat:@"%@ invalid option key; must be one of %@", key, [BTLE_CONNECT_OPTIONS.allKeys componentsJoinedByString:@", "]].UTF8String) ;
                    }
                } else {
                    return luaL_argerror(L, 3,
                        [NSString stringWithFormat:@"%s invalid option key type; must be a string matching one of %@", lua_typename(L, lua_type(L, -2)), [BTLE_CONNECT_OPTIONS.allKeys componentsJoinedByString:@", "]].UTF8String) ;
                }
                lua_pop(L, 1);             // removes 'value'; keeps 'key' for next iteration
            }
        }
    }

    [manager.manager connectPeripheral:peripheral options:options] ;
    lua_pushvalue(L, 1);
    return 1;
}

static int btle_cancelPeripheralConnection(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, UD_PERIPHERAL_TAG, LS_TBREAK] ;
    HSBTLECentralManager *manager    = [skin toNSObjectAtIndex:1] ;
    CBPeripheral         *peripheral = [skin toNSObjectAtIndex:2] ;

    [manager.manager cancelPeripheralConnection:peripheral] ;
    lua_pushvalue(L, 1);
    return 1;
}

static int btle_startScan(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSBTLECentralManager *manager      = [skin toNSObjectAtIndex:1] ;
    NSArray              *servicesList = nil ;

    if (lua_gettop(L) > 1) {
        NSArray *list  = [skin toNSObjectAtIndex:2] ;
        NSError *error = nil ;
        servicesList   = validateAndConvertUUIDs(list, YES, &error) ;

        if (error) return luaL_argerror(L, 2, error.localizedDescription.UTF8String) ;
    }

    [manager.manager scanForPeripheralsWithServices:servicesList options:nil] ;
    lua_pushvalue(L, 1);
    return 1;
}

static int btle_retrieveConnectedPeripheralsWithServices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TTABLE, LS_TBREAK] ;
    HSBTLECentralManager *manager = [skin toNSObjectAtIndex:1] ;

    NSArray *list         = [skin toNSObjectAtIndex:2] ;
    NSError *error        = nil ;
    NSArray *servicesList = validateAndConvertUUIDs(list, YES, &error) ;

    if (error) return luaL_argerror(L, 2, error.localizedDescription.UTF8String) ;

    NSArray *results = [manager.manager retrieveConnectedPeripheralsWithServices:servicesList] ;
    if (results) {
        for (CBPeripheral *peripheral in results) peripheral.delegate = manager ;
    }
    [skin pushNSObject:results] ;
    return 1;
}

static int btle_retrievePeripheralsWithIdentifiers(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TTABLE, LS_TBREAK] ;
    HSBTLECentralManager *manager = [skin toNSObjectAtIndex:1] ;

    NSArray *list        = [skin toNSObjectAtIndex:2] ;
    NSError *error       = nil ;
    NSArray *identifiers = validateAndConvertUUIDs(list, NO, &error) ;

    if (error) return luaL_argerror(L, 2, error.localizedDescription.UTF8String) ;

    NSArray *results = [manager.manager retrievePeripheralsWithIdentifiers:identifiers] ;
    if (results) {
        for (CBPeripheral *peripheral in results) peripheral.delegate = manager ;
    }
    [skin pushNSObject:results] ;
    return 1;
}

static int btle_stopScan(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSBTLECentralManager *manager = [skin toNSObjectAtIndex:1] ;
    [manager.manager stopScan] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int btle_isScanning(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSBTLECentralManager *manager = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, manager.manager.isScanning) ;
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSBTLECentralManager(lua_State *L, id obj) {
    HSBTLECentralManager *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSBTLECentralManager *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSBTLECentralManagerFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSBTLECentralManager *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSBTLECentralManager, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     HSBTLECentralManager *obj = [skin luaObjectAtIndex:1 toClass:"HSBTLECentralManager"] ;
//     NSString *title = ... ;
//     [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSBTLECentralManager *obj1 = [skin luaObjectAtIndex:1 toClass:"HSBTLECentralManager"] ;
        HSBTLECentralManager *obj2 = [skin luaObjectAtIndex:2 toClass:"HSBTLECentralManager"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSBTLECentralManager *obj = get_objectFromUserdata(__bridge_transfer HSBTLECentralManager, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.manager = nil ;
            obj = nil ;
        }
    }
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
    {"state",                btle_state},
    {"callback",             btle_callback},
    {"scanning",             btle_isScanning},
    {"stopScan",             btle_stopScan},
    {"startScan",            btle_startScan},
    {"connectedPeripherals", btle_retrieveConnectedPeripheralsWithServices},
    {"retrievePeripherals",  btle_retrievePeripheralsWithIdentifiers},
    {"connectPeripheral",    btle_connectPeripheral},
    {"disconnectPeripheral", btle_cancelPeripheralConnection},

    {"__tostring",           userdata_tostring},
    {"__eq",                 userdata_eq},
    {"__gc",                 userdata_gc},
    {NULL,                   NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"manager",       btle_new},
    {"authorization", btle_authorization},
    {NULL,            NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_libbtle(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil // module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSBTLECentralManager         forClass:"HSBTLECentralManager"];
    [skin registerLuaObjectHelper:toHSBTLECentralManagerFromLua forClass:"HSBTLECentralManager"
                                                     withUserdataMapping:USERDATA_TAG];

    BTLE_STATES = @{
        @(CBManagerStateUnknown)      : @"unknown",
        @(CBManagerStateResetting)    : @"resetting",
        @(CBManagerStateUnsupported)  : @"unsupported",
        @(CBManagerStateUnauthorized) : @"unauthorized",
        @(CBManagerStatePoweredOff)   : @"poweredOff",
        @(CBManagerStatePoweredOn)    : @"poweredOn",
    } ;

    BTLE_AUTHORIZATION = @{
        @(CBManagerAuthorizationAllowedAlways) : @"allowed",
        @(CBManagerAuthorizationDenied)        : @"denied",
        @(CBManagerAuthorizationNotDetermined) : @"unknown",
        @(CBManagerAuthorizationRestricted)    : @"restricted",
    } ;

    if (@available(macOS 14.0, *)) {
        BTLE_CONNECT_OPTIONS = @{
            @"autoReconnect" : @{
                @"key"  : CBConnectPeripheralOptionEnableAutoReconnect,
                @"type" : @"boolean",
            },
            @"connectNotification" : @{
                @"key"  : CBConnectPeripheralOptionNotifyOnConnectionKey,
                @"type" : @"boolean",
            },
            @"disconnectNotification" : @{
                @"key"  : CBConnectPeripheralOptionNotifyOnDisconnectionKey,
                @"type" : @"boolean",
            },
            @"otherNotifications" : @{
                @"key"  : CBConnectPeripheralOptionNotifyOnNotificationKey,
                @"type" : @"boolean",
            },
            @"delay" : @{
                @"key"  : CBConnectPeripheralOptionStartDelayKey,
                @"type" : @"number",
            },
        } ;
    } else {
        BTLE_CONNECT_OPTIONS = @{
            @"autoReconnect" : @{
                @"key"  : @"kCBConnectOptionAutoReconnect",
                @"type" : @"boolean",
            },
            @"connectNotification" : @{
                @"key"  : CBConnectPeripheralOptionNotifyOnConnectionKey,
                @"type" : @"boolean",
            },
            @"disconnectNotification" : @{
                @"key"  : CBConnectPeripheralOptionNotifyOnDisconnectionKey,
                @"type" : @"boolean",
            },
            @"otherNotifications" : @{
                @"key"  : CBConnectPeripheralOptionNotifyOnNotificationKey,
                @"type" : @"boolean",
            },
            @"delay" : @{
                @"key"  : CBConnectPeripheralOptionStartDelayKey,
                @"type" : @"number",
            },
        } ;
    }

    return 1;
}
