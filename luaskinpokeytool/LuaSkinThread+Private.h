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

#pragma mark - LuaSkin internal categories/extensions not published in LuaSkin.h

// Extension to LuaSkin class to allow private modification of the lua_State property
@interface LuaSkin ()

@property (readwrite, assign) lua_State *L;

@end

@interface LuaSkin (conversionSupport)

// internal methods for pushNSObject
- (int)pushNSObject:(id)obj     withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSNumber:(id)obj     withOptions:(LS_NSConversionOptions)options ;
- (int)pushNSArray:(id)obj      withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSSet:(id)obj        withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSDictionary:(id)obj withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSValue:(id)obj      withOptions:(LS_NSConversionOptions)options ;

// internal methods for toNSObjectAtIndex
- (id)toNSObjectAtIndex:(int)idx withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (id)tableAtIndex:(int)idx      withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen;
@end

#pragma mark - LuaSkinThread class private extension

@interface LuaSkinThread ()
// I don't remember why the tracking dictionaries were added as local variables in LuaSkin
// rather than as properties of the object itself (I think I was the one who did it, so...)
// but they were, so we have to use our own properties and override any method which uses
// them to keep our conversion functions safe with a LuaSkin subclass...
@property        NSMutableDictionary *registeredNSHelperFunctions ;
@property        NSMutableDictionary *registeredNSHelperLocations ;
@property        NSMutableDictionary *registeredLuaObjectHelperFunctions ;
@property        NSMutableDictionary *registeredLuaObjectHelperLocations ;
@property        NSMutableDictionary *registeredLuaObjectHelperUserdataMappings ;
@property (weak) HSASMLuaThread      *threadForThisSkin ;

// Inject a new class method for use as a replacement for [LuaSkin shared] in a threaded instance.
+(BOOL)inject ;

// Tools for manipulating references from another thread... not sure these will stick around, since its
// a pretty big risk, but I want to play with hs._asm.luaskinpokeytool a little more before I decide...
-(int)getRefForLabel:(const char *)label inModule:(const char *)module inThread:(NSThread *)thread ;
-(BOOL)setRef:(int)refNumber forLabel:(const char *)label inModule:(const char *)module inThread:(NSThread *)thread ;
@end
