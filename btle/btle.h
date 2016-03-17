@import Cocoa;
@import LuaSkin;
@import CoreBluetooth;

#define USERDATA_TAG          "hs._asm.btle"
#define UD_PERIPHERAL_TAG     "hs._asm.btle.peripheral"
#define UD_SERVICE_TAG        "hs._asm.btle.services"
#define UD_CHARACTERISTIC_TAG "hs._asm.btle.characteristic"
#define UD_DESCRIPTOR_TAG     "hs._asm.btle.descriptor"

#define get_objectFromUserdata(objType, L, idx, TAG) (objType*)*((void**)luaL_checkudata(L, idx, TAG))

@interface HSCBCentralManager : CBCentralManager <CBCentralManagerDelegate, CBPeripheralDelegate>
@property int selfRef ;
@property int callbackRef ;
@property int peripheralCallbackRef ;
@end

extern int btleGattLookupTable ;
extern int btleRefTable ;

extern int luaopen_hs__asm_btle_characteristic(lua_State* L) ;
extern int luaopen_hs__asm_btle_descriptor(lua_State* L) ;
extern int luaopen_hs__asm_btle_peripheral(lua_State* L) ;
extern int luaopen_hs__asm_btle_service(lua_State* L) ;
