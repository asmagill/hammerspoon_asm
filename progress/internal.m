@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.progress" ;
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static inline NSRect RectWithFlippedYCoordinate(NSRect theRect) {
    return NSMakeRect(theRect.origin.x,
                      [[NSScreen screens][0] frame].size.height - theRect.origin.y - theRect.size.height,
                      theRect.size.width,
                      theRect.size.height) ;
}

@interface ASMProgressWindow : NSPanel <NSWindowDelegate>
@end

@implementation ASMProgressWindow
- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)windowStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)deferCreation {

    if (!(isfinite(contentRect.origin.x)    && isfinite(contentRect.origin.y) &&
          isfinite(contentRect.size.height) && isfinite(contentRect.size.width))) {
        [[LuaSkin shared] logError:@"non-finite co-ordinate or size specified"] ;
        return nil;
    }

    self = [super initWithContentRect:contentRect
                            styleMask:windowStyle
                              backing:bufferingType
                                defer:deferCreation];

    if (self) {
        contentRect = RectWithFlippedYCoordinate(contentRect) ;
        [self setFrameOrigin:contentRect.origin];

        // Configure the window
        self.releasedWhenClosed = NO;
        self.backgroundColor    = [NSColor colorWithCalibratedWhite:.75 alpha:.75];
        self.opaque             = NO;
        self.hasShadow          = NO;
        self.ignoresMouseEvents = YES;
        self.restorable         = NO;
        self.hidesOnDeactivate  = NO;
        self.animationBehavior  = NSWindowAnimationBehaviorNone;
        self.level              = NSScreenSaverWindowLevel;
        self.delegate           = self;
    }
    return self;
}

- (BOOL)windowShouldClose:(id __unused)sender {
    return NO;
}
@end

@interface ASMProgressView : NSProgressIndicator
@end

@implementation ASMProgressView
- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.usesThreadedAnimation = YES ;
    }
    return self;
}

- (BOOL)isFlipped {
    return YES ;
}

// NSProgressIndicator shrinks to 32x32 at 0,0 for spinning, and 20xcurrentWidth at 0,0 for
// bar; however, changing to spin, then back to bar makes the currentWidth = 32, so here
// we center the object in the rectangle "window" and make it the full width if it's a
// bar.
- (void)centerInWindow {
    NSRect rect = self.frame ;
    NSRect parentRect = self.window.frame ;
    rect.origin.y = (parentRect.size.height - rect.size.height) / 2 ;
    if (self.style == NSProgressIndicatorBarStyle) {
        rect.origin.x = 0.0 ;
        rect.size.width = parentRect.size.width ;
    } else {
        rect.origin.x = (parentRect.size.width - rect.size.width) / 2 ;
    }
    [self setFrame:rect] ;
}

// Code from http://stackoverflow.com/a/32396595
//
// Color works for spinner (both indeterminate and determinate) and partially for bar:
//    indeterminate bar becomes a solid, un-animating color; determinate bar looks fine.
- (void)setCustomColor:(NSColor *)aColor {
    CIFilter *colorPoly = [CIFilter filterWithName:@"CIColorPolynomial"];
    [colorPoly setDefaults];

    CIVector *redVector ;
    CIVector *greenVector ;
    CIVector *blueVector ;
    if (self.style == NSProgressIndicatorSpinningStyle) {
        redVector   = [CIVector vectorWithX:aColor.redComponent   Y:0 Z:0 W:0];
        greenVector = [CIVector vectorWithX:aColor.greenComponent Y:0 Z:0 W:0];
        blueVector  = [CIVector vectorWithX:aColor.blueComponent  Y:0 Z:0 W:0];
    } else {
        redVector   = [CIVector vectorWithX:0 Y:aColor.redComponent   Z:0 W:0];
        greenVector = [CIVector vectorWithX:0 Y:aColor.greenComponent Z:0 W:0];
        blueVector  = [CIVector vectorWithX:0 Y:aColor.blueComponent  Z:0 W:0];
    }
    [colorPoly setValue:redVector   forKey:@"inputRedCoefficients"];
    [colorPoly setValue:greenVector forKey:@"inputGreenCoefficients"];
    [colorPoly setValue:blueVector  forKey:@"inputBlueCoefficients"];
    [self setContentFilters:[NSArray arrayWithObjects:colorPoly, nil]];
}

@end

#pragma mark - Module Functions

#pragma mark - Module Methods

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

// static int push<moduleType>(lua_State *L, id obj) {
//     <moduleType> *value = obj;
//     void** valuePtr = lua_newuserdata(L, sizeof(<moduleType> *));
//     *valuePtr = (__bridge_retained void *)value;
//     luaL_getmetatable(L, USERDATA_TAG);
//     lua_setmetatable(L, -2);
//     return 1;
// }
//
// id to<moduleType>FromLua(lua_State *L, int idx) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     <moduleType> *value ;
//     if (luaL_testudata(L, idx, USERDATA_TAG)) {
//         value = get_objectFromUserdata(__bridge <moduleType>, L, idx, USERDATA_TAG) ;
//     } else {
//         [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
//                                                    lua_typename(L, lua_type(L, idx))]] ;
//     }
//     return value ;
// }

#pragma mark - Hammerspoon/Lua Infrastructure

// static int userdata_tostring(lua_State* L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     <moduleType> *obj = [skin luaObjectAtIndex:1 toClass:"<moduleType>"] ;
//     NSString *title = ... ;
//     [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
//     return 1 ;
// }

// static int userdata_eq(lua_State* L) {
// // can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// // so use luaL_testudata before the macro causes a lua error
//     if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
//         LuaSkin *skin = [LuaSkin shared] ;
//         <moduleType> *obj1 = [skin luaObjectAtIndex:1 toClass:"<moduleType>"] ;
//         <moduleType> *obj2 = [skin luaObjectAtIndex:2 toClass:"<moduleType>"] ;
//         lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
//     } else {
//         lua_pushboolean(L, NO) ;
//     }
//     return 1 ;
// }

// static int userdata_gc(lua_State* L) {
//     <moduleType> *obj = get_objectFromUserdata(__bridge_transfer <moduleType>, L, 1, USERDATA_TAG) ;
//     if (obj) obj = nil ;
//     // Remove the Metatable so future use of the variable in Lua won't think its valid
//     lua_pushnil(L) ;
//     lua_setmetatable(L, 1) ;
//     return 0 ;
// }

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// // Metatable for userdata objects
// static const luaL_Reg userdata_metaLib[] = {
//     {"__tostring", userdata_tostring},
//     {"__eq",       userdata_eq},
//     {"__gc",       userdata_gc},
//     {NULL,         NULL}
// };

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_module_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
// Use this if your module doesn't have a module specific object that it returns.
   refTable = [skin registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
//     refTable = [skin registerLibraryWithObject:USERDATA_TAG
//                                      functions:moduleLib
//                                  metaFunctions:nil    // or module_metaLib
//                                objectFunctions:userdata_metaLib];

//     [skin registerPushNSHelper:push<moduleType>         forClass:"<moduleType>"];

// // one, but not both, of...
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"
//                                              withUserdataMapping:USERDATA_TAG];
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"];

    return 1;
}
