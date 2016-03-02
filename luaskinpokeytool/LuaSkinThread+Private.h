/*

    Private Interface to LuaSkinThread sub-class of LuaSkin

    These methods are generally not to be used outside of `hs._asm.luathread` and LuaSkinThread
    itself, as they can royally screw things up if you're not careful.

    Unless you have a specific need, it is highly suggested that you do not include this header
    in your projects and limit yourself to the methods and macros defined in LuaSkinThread.h

    You have been warned!

*/

#import "LuaSkinThread.h"
// #import "luathread.h"

// the only part of luathread.h we actually need
@interface HSASMLuaThread : NSThread <NSPortDelegate, LuaSkinDelegate>
@property (readonly) lua_State      *L ;
@property (readonly) int            runStringRef ;
@property            BOOL           performLuaClose ;
@property            NSLock         *dictionaryLock ;
@property            BOOL           idle ;
@property            BOOL           resetLuaState ;
@property (readonly) NSPort         *inPort ;
@property (readonly) NSPort         *outPort ;
@property (readonly) NSMutableArray *cachedOutput ;
@property (readonly) NSDictionary   *finalDictionary ;
@property (readonly) LuaSkin        *skin ;

-(instancetype)initWithPort:(NSPort *)outPort andName:(NSString *)name ;
@end

#pragma mark - LuaSkin internal extension not published in LuaSkin.h

// Extension to LuaSkin class to allow private modification of the lua_State property
@interface LuaSkin ()
@property (readwrite, assign) lua_State *L;
@property (readonly, atomic)  NSMutableDictionary *registeredNSHelperFunctions ;
@property (readonly, atomic)  NSMutableDictionary *registeredNSHelperLocations ;
@property (readonly, atomic)  NSMutableDictionary *registeredLuaObjectHelperFunctions ;
@property (readonly, atomic)  NSMutableDictionary *registeredLuaObjectHelperLocations ;
@property (readonly, atomic)  NSMutableDictionary *registeredLuaObjectHelperUserdataMappings;
@end

#pragma mark - LuaSkinThread class private extension

@interface LuaSkinThread ()
@property (weak) HSASMLuaThread      *threadForThisSkin ;

// Inject a new class method for use as a replacement for [LuaSkin shared] in a threaded instance.
+(BOOL)inject ;

// Tools for manipulating references from another thread... not sure these will stick around, since its
// a pretty big risk, but I want to play with hs._asm.luaskinpokeytool a little more before I decide...
-(int)getRefForLabel:(const char *)label inModule:(const char *)module inThread:(NSThread *)thread ;
-(BOOL)setRef:(int)refNumber forLabel:(const char *)label inModule:(const char *)module inThread:(NSThread *)thread ;
@end
