@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;

#pragma mark - Support Functions and Classes

@interface ShimmyShimShim : NSObject
@property (class, readonly, atomic) BOOL injectionNecessary ;
@property (class, readonly, atomic) BOOL injectionSucceeded ;
@end

@implementation ShimmyShimShim

static BOOL _injectionNecessary = YES ;
static BOOL _injectionSucceeded = NO ;

+ (BOOL)injectionNecessary { return _injectionNecessary ; }
+ (BOOL)injectionSucceeded { return _injectionSucceeded ; }

+ (LuaSkin *)sharedWithState:(__unused lua_State *)L {
    return [LuaSkin shared] ;
}

+ (void)injectIfNecessary {
    static dispatch_once_t onceToken ;

    dispatch_once(&onceToken, ^{
        SEL   desiredSelector = NSSelectorFromString(@"sharedWithState:") ;
        Class LSClass         = [LuaSkin class] ;
        Class LSMetaclass     = object_getClass(LSClass) ;
        BOOL alreadyThere     = (class_getClassMethod(LSMetaclass, desiredSelector) != NULL) ;

        if (alreadyThere) {
            _injectionNecessary = NO ;
            _injectionSucceeded = NO ;
        } else {
            _injectionNecessary = YES ;

            Class SSSClass     = [ShimmyShimShim class] ;
            Class SSSMetaclass = object_getClass(SSSClass) ;

            Method     desiredMethod    = class_getClassMethod(SSSMetaclass, desiredSelector) ;
            IMP        desiredIMP       = method_getImplementation(desiredMethod) ;
            const char *desiredEncoding = method_getTypeEncoding(desiredMethod) ;

            _injectionSucceeded = class_addMethod(LSMetaclass, desiredSelector, desiredIMP, desiredEncoding) ;

        }
    }) ;
}

@end

int luaopen_hs__asm_coroutineshim_internal(lua_State* L) {
    [ShimmyShimShim injectIfNecessary] ;

    lua_newtable(L) ;
    lua_pushboolean(L, ShimmyShimShim.injectionNecessary) ;
    lua_setfield(L, -2, "shimRequired") ;
    if (ShimmyShimShim.injectionNecessary) {
        lua_pushboolean(L, ShimmyShimShim.injectionSucceeded) ;
        lua_setfield(L, -2, "shimInjected") ;
    }
    return 1;
}
