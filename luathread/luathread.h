#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG  "hs._asm.luathread"
#define THREAD_UD_TAG "hs._asm.luathread.thread"

#define MSGID_RESULT     100
#define MSGID_PRINTFLUSH 101

#define MSGID_INPUT      200
#define MSGID_CANCEL     201

NSDictionary *assignmentsFromParent ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#define DEBUG(MSG)
// #define DEBUG(MSG) if ([NSThread isMainThread]) { \
//         dispatch_async(dispatch_get_main_queue(), ^{ \
//             [[LuaSkin shared] logDebug:[NSString stringWithFormat:@"%s:%@", USERDATA_TAG, MSG]] ; \
//         }) ; \
//     } else { \
//         dispatch_sync(dispatch_get_main_queue(), ^{ \
//             [[LuaSkin shared] logDebug:[NSString stringWithFormat:@"%s:%@", THREAD_UD_TAG, MSG]] ; \
//         }) ; \
//     }

#define INFORMATION(MSG) if ([NSThread isMainThread]) { \
        dispatch_async(dispatch_get_main_queue(), ^{ \
            [[LuaSkin shared] logInfo:[NSString stringWithFormat:@"%s:%@", USERDATA_TAG, MSG]] ; \
        }) ; \
    } else { \
        dispatch_sync(dispatch_get_main_queue(), ^{ \
            [[LuaSkin shared] logInfo:[NSString stringWithFormat:@"%s:%@", THREAD_UD_TAG, MSG]] ; \
        }) ; \
    }

#define ERROR(MSG) if ([NSThread isMainThread]) { \
        dispatch_async(dispatch_get_main_queue(), ^{ \
            [[LuaSkin shared] logError:[NSString stringWithFormat:@"%s:%@", USERDATA_TAG, MSG]] ; \
        }) ; \
    } else { \
        dispatch_sync(dispatch_get_main_queue(), ^{ \
            [[LuaSkin shared] logError:[NSString stringWithFormat:@"%s:%@", THREAD_UD_TAG, MSG]] ; \
        }) ; \
    }

@interface HSASMBooleanType : NSObject
@property (readonly) BOOL value ;
@end

int getHamster(lua_State *L, id obj, NSMutableDictionary *alreadySeen) ;
id setHamster(lua_State *L, int idx, NSMutableDictionary *alreadySeen) ;

@interface HSASMLuaThread : NSObject <NSPortDelegate>
@property (readonly) lua_State      *L ;
@property (readonly) int            runStringRef ;
@property            BOOL           performLuaClose ;
@property            BOOL           dictionaryLock ;
@property            BOOL           idle ;
@property (readonly) NSThread       *thread ;
@property (readonly) NSPort         *inPort ;
@property (readonly) NSPort         *outPort ;
@property (readonly) NSMutableArray *cachedOutput ;
@property (readonly) NSDictionary   *finalDictionary ;

-(instancetype)initWithPort:(NSPort *)outPort ;
@end

@interface HSASMLuaThreadManager : NSObject  <NSPortDelegate>
@property            int            callbackRef ;
@property            int            selfRef ;
@property (readonly) HSASMLuaThread *threadObj ;
@property (readonly) NSPort         *inPort ;
@property (readonly) NSPort         *outPort ;
@property (readonly) NSMutableArray *output ;
@property            BOOL           printImmediate ;
@property (readonly) NSString       *name ;
@end

