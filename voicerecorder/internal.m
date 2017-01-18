@import Cocoa ;
@import LuaSkin ;
@import AudioToolbox.AudioQueue ;

static const char *USERDATA_TAG = "hs._asm.voicerecorder" ;
static int        refTable      = LUA_NOREF;

#define NUM_BUFFERS 1
static const int kSampleRate = 16000 ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface ASMVoiceRecorder : NSObject
@property            int                         callbackRef ;
@property            int                         selfRefCount ;
@property            BOOL                        recording ;
@property (readonly) AudioStreamBasicDescription inputFormat ;
@end

@implementation ASMVoiceRecorder {
  AudioQueueRef       queue ;
  AudioQueueBufferRef buffers[NUM_BUFFERS] ;
}

- (instancetype)init {
    self = [super init] ;
    if (self) {
        _callbackRef  = LUA_NOREF ;
        _selfRefCount = 0 ;
        _recording    = NO ;

        // 16bit Linear PCM, 16kHz sample rate, Single channel, Little endian byte order
        _inputFormat.mSampleRate       = kSampleRate ;
        _inputFormat.mFormatID         = kAudioFormatLinearPCM ;
        _inputFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger ;
        _inputFormat.mBytesPerPacket   = sizeof(SInt16) ;
        _inputFormat.mFramesPerPacket  = 1 ;
        _inputFormat.mBytesPerFrame    = sizeof(SInt16) ;
        _inputFormat.mChannelsPerFrame = 1 ;
        _inputFormat.mBitsPerChannel   = 8 * sizeof(SInt16) ;
        _inputFormat.mReserved         = 0 ;
    }
    return self ;
}
@end

#pragma mark - Module Functions

#pragma mark - Module Methods

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMVoiceRecorder(lua_State *L, id obj) {
    ASMVoiceRecorder *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMVoiceRecorder *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toASMVoiceRecorderFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMVoiceRecorder *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMVoiceRecorder, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMVoiceRecorder *obj = [skin luaObjectAtIndex:1 toClass:"ASMVoiceRecorder"] ;
    NSString *title = [obj description] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMVoiceRecorder *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMVoiceRecorder"] ;
        ASMVoiceRecorder *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMVoiceRecorder"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMVoiceRecorder *obj = get_objectFromUserdata(__bridge_transfer ASMVoiceRecorder, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            obj.callbackRef = [[LuaSkin shared] luaUnref:refTable ref:obj.callbackRef] ;
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
    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_voicerecorder_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASMVoiceRecorder         forClass:"ASMVoiceRecorder"];
    [skin registerLuaObjectHelper:toASMVoiceRecorderFromLua forClass:"ASMVoiceRecorder"
                                                 withUserdataMapping:USERDATA_TAG];

    return 1;
}
