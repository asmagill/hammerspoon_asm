#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import <CoreImage/CoreImage.h>
// #import "../hammerspoon.h"

// #define USERDATA_TAG "hs._asm.cifilter"
static int refTable = LUA_NOREF;

// #define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

// - (NSMutableDictionary *)buildFilterDictionary:(NSArray *)filterClassNames  // 1
// {
//     NSMutableDictionary *filters = [NSMutableDictionary dictionary];
//     for (NSString *className in filterClassNames) {                         // 2
//         CIFilter *filter = [CIFilter filterWithName:className];             // 3
//
//         if (filter) {
//             filters[className] = [filter attributes];                       // 4
//         } else {
//             NSLog(@"could not create '%@' filter", className);
//         }
//     }
//     return filters;
// }

// CIImage *ciImage = ...;
// NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:ciImage];
// NSImage *nsImage = [[NSImage alloc] initWithSize:rep.size];
// [nsImage addRepresentation:rep];

#pragma mark - Module Functions

static int filterNamesInCategory(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    NSMutableArray *theCategories ;
    if (lua_type(L, 1) == LUA_TTABLE) {
        theCategories = [[skin toNSObjectAtIndex:1 withOptions:LS_NSNone] mutableCopy];
        for (id item in [NSArray arrayWithArray:theCategories]) {
            if (![item isKindOfClass:[NSString class]]) [theCategories removeObject:item];
        }
    } else if (lua_type(L, 1) == LUA_TSTRING) {
        [theCategories addObject:[skin toNSObjectAtIndex:1 withOptions:LS_NSNone]] ;
    }

    [skin pushNSObject:[CIFilter filterNamesInCategories:theCategories]] ;
    return 1 ;
}

static int filterDetails(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    CIFilter *filter = [CIFilter filterWithName:[skin toNSObjectAtIndex:1]] ;
    if (filter) {
        [filter setDefaults] ;
        lua_newtable(L) ;
        [skin pushNSObject:[filter name] withOptions:LS_NSDescribeUnknownTypes] ;
        lua_setfield(L, -2, "name") ;
        [skin pushNSObject:[filter attributes] withOptions:LS_NSDescribeUnknownTypes] ;
        lua_setfield(L, -2, "attributes") ;
        [skin pushNSObject:[filter inputKeys] withOptions:LS_NSDescribeUnknownTypes] ;
        lua_setfield(L, -2, "inputKeys") ;
        [skin pushNSObject:[filter outputKeys] withOptions:LS_NSDescribeUnknownTypes] ;
        lua_setfield(L, -2, "outputKeys") ;
        [skin pushNSObject:[filter outputImage] withOptions:LS_NSDescribeUnknownTypes] ;
        lua_setfield(L, -2, "outputImage") ;
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}

#pragma mark - Module Methods

// LS_NSDescribeUnknownTypes

#pragma mark - Module Constants

static int pushCIFilterCategories(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
    [skin pushNSObject:kCICategoryDistortionEffect] ;   lua_setfield(L, -2, "distortionEffect") ;
    [skin pushNSObject:kCICategoryGeometryAdjustment] ; lua_setfield(L, -2, "geometryAdjustment") ;
    [skin pushNSObject:kCICategoryCompositeOperation] ; lua_setfield(L, -2, "compositeOperation") ;
    [skin pushNSObject:kCICategoryHalftoneEffect] ;     lua_setfield(L, -2, "halftoneEffect") ;
    [skin pushNSObject:kCICategoryColorAdjustment] ;    lua_setfield(L, -2, "colorAdjustment") ;
    [skin pushNSObject:kCICategoryColorEffect] ;        lua_setfield(L, -2, "colorEffect") ;
    [skin pushNSObject:kCICategoryTransition] ;         lua_setfield(L, -2, "transition") ;
    [skin pushNSObject:kCICategoryTileEffect] ;         lua_setfield(L, -2, "tileEffect") ;
    [skin pushNSObject:kCICategoryGenerator] ;          lua_setfield(L, -2, "generator") ;
    [skin pushNSObject:kCICategoryReduction] ;          lua_setfield(L, -2, "reduction") ;
    [skin pushNSObject:kCICategoryGradient] ;           lua_setfield(L, -2, "gradient") ;
    [skin pushNSObject:kCICategoryStylize] ;            lua_setfield(L, -2, "stylize") ;
    [skin pushNSObject:kCICategorySharpen] ;            lua_setfield(L, -2, "sharpen") ;
    [skin pushNSObject:kCICategoryBlur] ;               lua_setfield(L, -2, "blur") ;
    [skin pushNSObject:kCICategoryVideo] ;              lua_setfield(L, -2, "video") ;
    [skin pushNSObject:kCICategoryStillImage] ;         lua_setfield(L, -2, "stillImage") ;
    [skin pushNSObject:kCICategoryInterlaced] ;         lua_setfield(L, -2, "interlaced") ;
    [skin pushNSObject:kCICategoryNonSquarePixels] ;    lua_setfield(L, -2, "nonSquarePixels") ;
    [skin pushNSObject:kCICategoryHighDynamicRange] ;   lua_setfield(L, -2, "highDynamicRange") ;
    [skin pushNSObject:kCICategoryBuiltIn] ;            lua_setfield(L, -2, "builtIn") ;
    [skin pushNSObject:kCICategoryFilterGenerator] ;    lua_setfield(L, -2, "filterGenerator") ;
    return 1 ;
}

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
//         value = get_objectFromUserdata(__bridge <moduleType>, L, idx) ;
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
//     <moduleType> *obj = get_objectFromUserdata(__bridge_transfer <moduleType>, L, 1) ;
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
    {"filters",       filterNamesInCategory},
    {"filterDetails", filterDetails},
    {NULL,            NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_cifilter_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
// Use this if your module doesn't have a module specific object that it returns.
   refTable = [skin registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
//     refTable = [skin registerLibraryWithObject:USERDATA_TAG
//                                      functions:moduleLib
//                                  metaFunctions:nil    // or module_metaLib
//                                objectFunctions:userdata_metaLib];

//     [skin registerPushNSHelper:push<moduleType>         forClass:"<moduleType>"];
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"];

    pushCIFilterCategories(L) ; lua_setfield(L, -2, "categories") ;

    return 1;
}
