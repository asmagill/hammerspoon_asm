@import Cocoa ;
@import LuaSkin ;
@import CoreImage ;
@import Quartz ;

#define USERDATA_TAG    "hs._asm.cifilter"
#define CIIMAGE_UD_TAG  "hs._asm.ciimage"
#define IKUIVIEW_UD_TAG "hs._asm.ikfilteruiview"

static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, TAG) (objType*)*((void**)luaL_checkudata(L, idx, TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

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

static int HSImageAsCIImage(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, "hs.image", LS_TBREAK] ;
    NSImage *nsImage  = [skin luaObjectAtIndex:1 toClass:"NSImage"] ;
    NSData  *tiffData = [nsImage TIFFRepresentation];
    CIImage *ciImage  = [CIImage imageWithData:tiffData];
    [skin pushNSObject:ciImage] ;
    return 1 ;
}

static int getFilterObject(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    CIFilter *filter = [CIFilter filterWithName:[skin toNSObjectAtIndex:1]] ;
    if (filter) {
        [filter setDefaults] ;
        [skin pushNSObject:filter] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - CIFilter Methods

static int filterDetails(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    CIFilter *filter = [skin luaObjectAtIndex:1 toClass:"CIFilter"] ;
    lua_newtable(L) ;
    [skin pushNSObject:[filter name] withOptions:LS_NSDescribeUnknownTypes] ;
    lua_setfield(L, -2, "name") ;
    [skin pushNSObject:[filter attributes] withOptions:LS_NSDescribeUnknownTypes] ;
    lua_setfield(L, -2, "attributes") ;
    [skin pushNSObject:[filter inputKeys] withOptions:LS_NSDescribeUnknownTypes] ;
    lua_setfield(L, -2, "inputKeys") ;
    [skin pushNSObject:[filter outputKeys] withOptions:LS_NSDescribeUnknownTypes] ;
    lua_setfield(L, -2, "outputKeys") ;
    [skin pushNSObject:[CIFilter localizedNameForFilterName:[filter name]] withOptions:LS_NSDescribeUnknownTypes] ;
    lua_setfield(L, -2, "localizedName") ;
    [skin pushNSObject:[CIFilter localizedDescriptionForFilterName:[filter name]] withOptions:LS_NSDescribeUnknownTypes] ;
    lua_setfield(L, -2, "description") ;
    [skin pushNSObject:[CIFilter localizedReferenceDocumentationForFilterName:[filter name]] withOptions:LS_NSDescribeUnknownTypes] ;
    lua_setfield(L, -2, "referenceDocumentation") ;
    return 1;
}

static int resetFilter(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    CIFilter *filter = [skin luaObjectAtIndex:1 toClass:"CIFilter"] ;
    [filter setDefaults] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int getFilterParameter(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    CIFilter *filter = [skin luaObjectAtIndex:1 toClass:"CIFilter"] ;
    NSString *parameter = [skin toNSObjectAtIndex:2] ;
    if ([[filter inputKeys] containsObject:parameter] || [[filter outputKeys] containsObject:parameter]) {
        [skin pushNSObject:[filter valueForKey:parameter]] ;
    } else {
        return luaL_error(L, "getParameter:invalid parameter specified '%s'", [parameter UTF8String]) ;
    }
    return 1 ;
}

static int enabledFilter(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    CIFilter *filter = [skin luaObjectAtIndex:1 toClass:"CIFilter"] ;
    if (lua_gettop(L) == 2) {
        [filter setEnabled:(BOOL)lua_toboolean(L, 2)] ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, [filter isEnabled]) ;
    }
    return 1 ;
}

static int setFilterParameter(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TANY, LS_TBREAK] ;
    CIFilter *filter = [skin luaObjectAtIndex:1 toClass:"CIFilter"] ;
    NSString *parameter = [skin toNSObjectAtIndex:2 withOptions:LS_NSDescribeUnknownTypes] ;
    if ([[filter inputKeys] containsObject:parameter]) {
        NSDictionary *pDetails = [[filter attributes] valueForKey:parameter] ;
        NSString *theClass      = [pDetails valueForKey:kCIAttributeClass] ;
        NSString *attributeType = [pDetails valueForKey:kCIAttributeType] ;
        NSNumber *minValue      = [pDetails valueForKey:kCIAttributeMin] ;
        NSNumber *maxValue      = [pDetails valueForKey:kCIAttributeMax] ;

        if (theClass) {
            if ([theClass isEqualToString:@"NSNumber"]) {
                if (minValue) {
                    if ([minValue compare:[NSNumber numberWithFloat:(float)lua_tonumber(L, 3)]] == NSOrderedDescending) {
                        return luaL_error(L, [[NSString stringWithFormat:@"setParameter:%@ cannot be less than %@",
                                                                          parameter, minValue] UTF8String]) ;
                    }
                }
                if (maxValue) {
                    if ([maxValue compare:[NSNumber numberWithFloat:(float)lua_tonumber(L, 3)]] == NSOrderedAscending) {
                        return luaL_error(L, [[NSString stringWithFormat:@"setParameter:%@ cannot be greater than %@",
                                                                          parameter, maxValue] UTF8String]) ;
                    }
                }
            }

            if (attributeType) {
                if ([attributeType isEqualToString:kCIAttributeTypeTime]) {
                    float timeNumber = (float)lua_tonumber(L, 3) ;
                    // I hope this is taken care of with min and max above, but since all keys except class are optional, check to be sure
                    if ((timeNumber < 0.0f) || (timeNumber > 1.0f)) {
                        return luaL_error(L, [[NSString stringWithFormat:@"setParameter:%@ must be between 0.0 and 1.0 for attribute type %@",
                                                                          parameter, attributeType] UTF8String]) ;
                    } else {
                        [filter setValue:[NSNumber numberWithFloat:timeNumber] forKey:parameter] ;
                    }
                } else if ([attributeType isEqualToString:kCIAttributeTypeScalar]   ||
                           [attributeType isEqualToString:kCIAttributeTypeDistance] ||
                           [attributeType isEqualToString:kCIAttributeTypeAngle])   {
                    [filter setValue:[NSNumber numberWithFloat:(float)lua_tonumber(L, 3)] forKey:parameter] ;
                } else if ([attributeType isEqualToString:kCIAttributeTypeBoolean]) {
                    [filter setValue:(lua_toboolean(L, 3) ? @(YES) : @(NO)) forKey:parameter] ;
                } else if ([attributeType isEqualToString:kCIAttributeTypeInteger]) {
                    [filter setValue:[NSNumber numberWithLongLong:lua_tointeger(L, 3)] forKey:parameter] ;
                } else if ([attributeType isEqualToString:kCIAttributeTypeCount]) {
                    long long countValue = lua_tointeger(L, 3) ;
                    // I hope this is taken care of with min and max above, but since all keys except class are optional, check to be sure
                    if (countValue < 0) {
                        return luaL_error(L, [[NSString stringWithFormat:@"setParameter:%@ must be a positive integer for attribute type %@",
                                                                          parameter, attributeType] UTF8String]) ;
                    } else {
                        [filter setValue:[NSNumber numberWithLongLong:lua_tointeger(L, 3)] forKey:parameter] ;
                    }
                } else if ([attributeType isEqualToString:kCIAttributeTypePosition] || [attributeType isEqualToString:kCIAttributeTypeOffset]) {
                    if ((lua_type(L, 3) == LUA_TTABLE) && (luaL_len(L, 3) != 2)) {
                        return luaL_error(L, [[NSString stringWithFormat:@"setParameter:%@ must be a 2 element vector (array) for attribute type %@",
                                                                          parameter, attributeType] UTF8String]) ;
                    } else {
                        [filter setValue:[skin luaObjectAtIndex:3 toClass:"CIVector"] forKey:parameter] ;
                    }
                } else if ([attributeType isEqualToString:kCIAttributeTypePosition3]) {
                    if ((lua_type(L, 3) == LUA_TTABLE) && (luaL_len(L, 3) != 3)) {
                        return luaL_error(L, [[NSString stringWithFormat:@"setParameter:%@ must be a 3 element vector (array) for attribute type %@",
                                                                          parameter, attributeType] UTF8String]) ;
                    } else {
                        [filter setValue:[skin luaObjectAtIndex:3 toClass:"CIVector"] forKey:parameter] ;
                    }
                } else if ([attributeType isEqualToString:kCIAttributeTypeRectangle]) {
                    if ((lua_type(L, 3) == LUA_TTABLE) && (luaL_len(L, 3) != 4)) {
                        return luaL_error(L, [[NSString stringWithFormat:@"setParameter:%@ must be a 4 element vector (array) for attribute type %@",
                                                                          parameter, attributeType] UTF8String]) ;
                    } else {
                        [filter setValue:[skin luaObjectAtIndex:3 toClass:"CIVector"] forKey:parameter] ;
                    }
                } else if ([attributeType isEqualToString:kCIAttributeTypeOpaqueColor] || [attributeType isEqualToString:kCIAttributeTypeColor]) {
                // NOTE: we don't distinguish between color with alpha and color without... assume, alpha will be ignored where not wanted.
                    [filter setValue:[skin luaObjectAtIndex:3 toClass:"CIColor"] forKey:parameter] ;
                } else if ([attributeType isEqualToString:kCIAttributeTypeGradient] || [attributeType isEqualToString:kCIAttributeTypeImage]) {
                // NOTE: should we check bounds on kCIAttributeTypeGradient to make sure the image is n X 1 ?
                    [filter setValue:[skin luaObjectAtIndex:3 toClass:"CIImage"] forKey:parameter] ;
                } else if ([attributeType isEqualToString:kCIAttributeTypeTransform]) {
                    [filter setValue:[skin luaObjectAtIndex:3 toClass:"NSAffineTransform"] forKey:parameter] ;
                } else {
                    return luaL_error(L, "setParameter:unrecognized attribute type '%s' for %s found",
                                         [attributeType UTF8String], [parameter UTF8String]) ;
                }
            } else { // Assume that if class is set, but type isn't, that it's a straightforward conversion to a regularly
                     // used object... or one we should add...
                [filter setValue:[skin toNSObjectAtIndex:3] forKey:parameter] ;
            }
        } else {
            return luaL_error(L, "setParameter:no attribute class for %s found", [parameter UTF8String]) ;
        }
    } else {
        return luaL_error(L, "setParameter:invalid parameter specified '%s'", [parameter UTF8String]) ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int filterUserInterface(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE, LS_TSTRING | LS_TNIL | LS_TOPTIONAL,
                    LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    CIFilter *filter = [skin luaObjectAtIndex:1 toClass:"CIFilter"] ;
    NSPoint where = [skin tableToPointAtIndex:2] ;
    NSString *parameterSet = kCIUISetAdvanced ;
    NSString *sizeFlavor = IKUISizeRegular ;

    if (lua_type(L, 3) == LS_TSTRING) {
        NSString *providedParameterSet = [skin toNSObjectAtIndex:3] ;
        if ([providedParameterSet isEqualToString:@"basic"])             { parameterSet = kCIUISetBasic ; }
        else if ([providedParameterSet isEqualToString:@"intermediate"]) { parameterSet = kCIUISetIntermediate ; }
        else if ([providedParameterSet isEqualToString:@"advanced"])     { parameterSet = kCIUISetAdvanced ; }
        else if ([providedParameterSet isEqualToString:@"development"])  { parameterSet = kCIUISetDevelopment ; }
        else {
            return luaL_error(L, [[NSString stringWithFormat:@"%s:invalid parameter set specified: %@",
                                                              IKUIVIEW_UD_TAG, providedParameterSet] UTF8String]) ;
        }
    }
    if (lua_type(L, 4) == LS_TSTRING) {
        NSString *providedSize = [skin toNSObjectAtIndex:4] ;
        if ([providedSize isEqualToString:@"mini"])         { sizeFlavor = IKUISizeMini ; }
        else if ([providedSize isEqualToString:@"small"])   { sizeFlavor = IKUISizeSmall ; }
        else if ([providedSize isEqualToString:@"regular"]) { sizeFlavor = IKUISizeRegular ; }
        else if ([providedSize isEqualToString:@"max"])     { sizeFlavor = IKUImaxSize ; }
        else {
            return luaL_error(L, [[NSString stringWithFormat:@"%s:invalid controller size specified: %@",
                                                              IKUIVIEW_UD_TAG, providedSize] UTF8String]) ;
        }
    }
    IKFilterUIView *theView = [filter viewForUIConfiguration:@{ kCIUIParameterSet       : parameterSet,
                                                                IKUISizeFlavor          : sizeFlavor,
                                                                IKUIFlavorAllowFallback : @(YES) }
                                                excludedKeys:nil] ;

    // TODO: sub-class NSWindow so it can be a delegate and allow input when not titled, etc.
    NSUInteger initialStyle = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask ;
    NSRect viewFrame = [theView frame] ;
    viewFrame.origin.x = where.x ;
    viewFrame.origin.y = where.y ;

    // adjust for title bar, etc based upon default style
    NSRect inWindowFrame = [NSWindow frameRectForContentRect:viewFrame styleMask:initialStyle] ;
    inWindowFrame.origin.y = inWindowFrame.origin.y + (inWindowFrame.size.height - viewFrame.size.height) ;
    inWindowFrame.size.height = viewFrame.size.height ;

//     [skin logInfo:[NSString stringWithFormat:@"UI View Rect:   x:%f y:%f w:%f h:%f",
//                                               viewFrame.origin.x,
//                                               viewFrame.origin.y,
//                                               viewFrame.size.width,
//                                               viewFrame.size.height]] ;
//
//     [skin logInfo:[NSString stringWithFormat:@"UI Window Rect: x:%f y:%f w:%f h:%f",
//                                               inWindowFrame.origin.x,
//                                               inWindowFrame.origin.y,
//                                               inWindowFrame.size.width,
//                                               inWindowFrame.size.height]] ;

    // adjust for inverted coordinate's used in Hammerspoon
    inWindowFrame.origin.y = [[NSScreen screens][0] frame].size.height - inWindowFrame.origin.y - inWindowFrame.size.height ;

    NSWindow *theWindow = [[NSWindow alloc] initWithContentRect:inWindowFrame
                                                      styleMask:initialStyle
                                                        backing:NSBackingStoreBuffered
                                                          defer:YES] ;
    [theWindow setReleasedWhenClosed:NO] ;
    [theWindow setContentView:theView] ;
    void** windowPtr = lua_newuserdata(L, sizeof(NSWindow *)) ;
    *windowPtr = (__bridge_retained void *)theWindow ;
    luaL_getmetatable(L, IKUIVIEW_UD_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

#pragma mark - CIImage Methods

static int ciimageAsHSImage(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, CIIMAGE_UD_TAG, LS_TBREAK] ;
    CIImage      *ciImage = [skin luaObjectAtIndex:1 toClass:"CIImage"] ;
    NSCIImageRep *rep     = [NSCIImageRep imageRepWithCIImage:ciImage];
    NSImage      *nsImage = [[NSImage alloc] initWithSize:rep.size];
    [nsImage addRepresentation:rep];
    [skin pushNSObject:nsImage] ;
    return 1 ;
}

#pragma mark - IKFilterUIView Methods

// bridge to hs.drawing... allows us to use some of its methods as our own.
// unlike other modules, we're not going to advertise this (in fact I may remove it from the others
// when I get a chance) because a closer look suggests that we can cause a crash, even with the
// type checks in many of hs.drawings methods.
typedef struct _drawing_t {
    void *window;
    BOOL skipClose ;
} drawing_t;

static int IKFilterUIViewAsHSDrawing(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, IKUIVIEW_UD_TAG, LS_TBREAK] ;
    NSWindow *theWindow = get_objectFromUserdata(__bridge NSWindow, L, 1, IKUIVIEW_UD_TAG) ;

    drawing_t *drawingObject = lua_newuserdata(L, sizeof(drawing_t));
    memset(drawingObject, 0, sizeof(drawing_t));
    drawingObject->window = (__bridge_retained void*)theWindow;
    // skip the side affects of hs.drawing __gc
    drawingObject->skipClose = YES ;
    luaL_getmetatable(L, "hs.drawing");
    lua_setmetatable(L, -2);
    return 1 ;
}

/// hs._asm.ikfilteruiview:show() -> ikfilteruiviewObject
/// Method
/// Displays the filter configuration UI window.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the filter configuration UI object
static int IKFilterUIViewShow(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, IKUIVIEW_UD_TAG, LS_TBREAK] ;
    NSWindow *theWindow = get_objectFromUserdata(__bridge NSWindow, L, 1, IKUIVIEW_UD_TAG) ;
    [theWindow makeKeyAndOrderFront:nil];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.ikfilteruiview:hide() -> ikfilteruiviewObject
/// Method
/// Hides the filter configuration UI window.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the filter configuration UI object
static int IKFilterUIViewHide(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, IKUIVIEW_UD_TAG, LS_TBREAK] ;
    NSWindow *theWindow = get_objectFromUserdata(__bridge NSWindow, L, 1, IKUIVIEW_UD_TAG) ;
    [theWindow orderOut:nil];
    lua_pushvalue(L, 1);
    return 1;
}

static int IKFilterUIViewWindowStyle(lua_State *L) {
// NOTE:  This method is wrapped in init.lua
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, IKUIVIEW_UD_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSWindow *theWindow = get_objectFromUserdata(__bridge NSWindow, L, 1, IKUIVIEW_UD_TAG) ;
    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushinteger(L, (lua_Integer)theWindow.styleMask) ;
    } else {
        @try {
//         // Because we're using NSPanel, the title is reset when the style is changed
//             NSString *theTitle = [theWindow title] ;
//         // Also, some styles don't get properly set unless we start from a clean slate
//             [theWindow setStyleMask:0] ;
            [theWindow setStyleMask:(NSUInteger)luaL_checkinteger(L, 2)] ;
//             if (theTitle) [theWindow setTitle:theTitle] ;
        }
        @catch ( NSException *theException ) {
            return luaL_error(L, "Invalid style mask: %s, %s", [[theException name] UTF8String], [[theException reason] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants

static int pushFilterCategories(lua_State *L) {
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

static int pushFilterParameterKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
    [skin pushNSObject:kCIOutputImageKey] ;          lua_setfield(L, -2, "outputImage") ;
    [skin pushNSObject:kCIInputBackgroundImageKey] ; lua_setfield(L, -2, "backgroundImage") ;
    [skin pushNSObject:kCIInputImageKey] ;           lua_setfield(L, -2, "inputImage") ;
    [skin pushNSObject:kCIInputTimeKey] ;            lua_setfield(L, -2, "time") ;
    [skin pushNSObject:kCIInputTransformKey] ;       lua_setfield(L, -2, "transform") ;
    [skin pushNSObject:kCIInputScaleKey] ;           lua_setfield(L, -2, "scale") ;
    [skin pushNSObject:kCIInputAspectRatioKey] ;     lua_setfield(L, -2, "aspectRatio") ;
    [skin pushNSObject:kCIInputCenterKey] ;          lua_setfield(L, -2, "center") ;
    [skin pushNSObject:kCIInputRadiusKey] ;          lua_setfield(L, -2, "radius") ;
    [skin pushNSObject:kCIInputAngleKey] ;           lua_setfield(L, -2, "angle") ;
    [skin pushNSObject:kCIInputRefractionKey] ;      lua_setfield(L, -2, "refraction") ;
    [skin pushNSObject:kCIInputWidthKey] ;           lua_setfield(L, -2, "width") ;
    [skin pushNSObject:kCIInputSharpnessKey] ;       lua_setfield(L, -2, "sharpness") ;
    [skin pushNSObject:kCIInputIntensityKey] ;       lua_setfield(L, -2, "intensity") ;
    [skin pushNSObject:kCIInputEVKey] ;              lua_setfield(L, -2, "EV") ;
    [skin pushNSObject:kCIInputSaturationKey] ;      lua_setfield(L, -2, "saturation") ;
    [skin pushNSObject:kCIInputColorKey] ;           lua_setfield(L, -2, "color") ;
    [skin pushNSObject:kCIInputBrightnessKey] ;      lua_setfield(L, -2, "brightness") ;
    [skin pushNSObject:kCIInputContrastKey] ;        lua_setfield(L, -2, "contrast") ;
    [skin pushNSObject:kCIInputGradientImageKey] ;   lua_setfield(L, -2, "gradientImage") ;
    [skin pushNSObject:kCIInputMaskImageKey] ;       lua_setfield(L, -2, "maskImage") ;
    [skin pushNSObject:kCIInputShadingImageKey] ;    lua_setfield(L, -2, "shadingImage") ;
    [skin pushNSObject:kCIInputTargetImageKey] ;     lua_setfield(L, -2, "targetImage") ;
    [skin pushNSObject:kCIInputExtentKey] ;          lua_setfield(L, -2, "extent") ;
    [skin pushNSObject:kCIInputVersionKey] ;         lua_setfield(L, -2, "version") ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushCIImage(lua_State *L, id obj) {
    CIImage *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(CIImage *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, CIIMAGE_UD_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toCIImageFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    CIImage *value ;
    if (luaL_testudata(L, idx, CIIMAGE_UD_TAG)) {
        value = get_objectFromUserdata(__bridge CIImage, L, idx, CIIMAGE_UD_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", CIIMAGE_UD_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushCIFilter(lua_State *L, id obj) {
    CIFilter *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(CIFilter *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toCIFilterFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    CIFilter *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge CIFilter, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

// In hs._asm.canvas, which may be added to core soon
//
// static int pushNSAffineTransform(lua_State *L, id obj) {
//     NSAffineTransformStruct theTransform = [(NSAffineTransform *)obj transformStruct] ;
//     lua_newtable(L) ;
//     lua_pushnumber(L, theTransform.m11) ; lua_setfield(L, -2, "m11") ;
//     lua_pushnumber(L, theTransform.m12) ; lua_setfield(L, -2, "m12") ;
//     lua_pushnumber(L, theTransform.m21) ; lua_setfield(L, -2, "m21") ;
//     lua_pushnumber(L, theTransform.m22) ; lua_setfield(L, -2, "m22") ;
//     lua_pushnumber(L, theTransform.tX) ;  lua_setfield(L, -2, "tX") ;
//     lua_pushnumber(L, theTransform.tY) ;  lua_setfield(L, -2, "tY") ;
//     return 1 ;
// }
//
// static id toNSAffineTransformFromLua(lua_State *L, int idx) {
//     NSAffineTransform *theTransform ;
//     if (lua_type(L, idx) == LUA_TTABLE) {
//         NSAffineTransformStruct transformHolder = { 1.0, 0.0, 0.0, 1.0, 0.0, 0.0 } ;
//         if (lua_getfield(L, idx, "m11") == LUA_TNUMBER) transformHolder.m11 = lua_tonumber(L, -1) ;
//         if (lua_getfield(L, idx, "m12") == LUA_TNUMBER) transformHolder.m12 = lua_tonumber(L, -1) ;
//         if (lua_getfield(L, idx, "m21") == LUA_TNUMBER) transformHolder.m21 = lua_tonumber(L, -1) ;
//         if (lua_getfield(L, idx, "m22") == LUA_TNUMBER) transformHolder.m22 = lua_tonumber(L, -1) ;
//         if (lua_getfield(L, idx, "tX") == LUA_TNUMBER)  transformHolder.tX  = lua_tonumber(L, -1) ;
//         if (lua_getfield(L, idx, "tY") == LUA_TNUMBER)  transformHolder.tY  = lua_tonumber(L, -1) ;
//         lua_pop(L, 6) ; // all at once is a little faster, since we're not doing anything complex that affects the stack with intermediate stuff
//         theTransform = [NSAffineTransform transform] ;
//         [theTransform setTransformStruct:transformHolder] ;
//     } else {
//         [[LuaSkin shared] logError:[NSString stringWithFormat:@"NSAffineTransform expects table, found %s", lua_typename(L, lua_type(L, idx))]] ;
//     }
//     return theTransform ;
// }

static int pushCIVector(lua_State *L, id obj) {
    CIVector *theVector = obj ;
    lua_newtable(L) ;
    for (size_t i = 0; i < [theVector count] ; i++ ) {
        lua_pushnumber(L, [obj valueAtIndex:i]) ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    return 1 ;
}

static id toCIVectorFromLua(lua_State *L, int idx) {
    CIVector *theVector ;
    if (lua_type(L, idx) == LUA_TTABLE) {
        size_t count = (size_t) luaL_len(L, idx) ;
        if (count > 0) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wvla"
            CGFloat vectorParts[count] ;
#pragma clang diagnostic pop
            for (size_t i = 0 ; i < count ; i++) {
                if (lua_rawgeti(L, idx, (int)(i + 1)) == LUA_TNUMBER) {
                    vectorParts[i] = lua_tonumber(L, -1) ;
                } else {
                    vectorParts[i] = 0.0 ;
                }
            }
            lua_pop(L, (int)count) ; // all at once
            theVector = [CIVector vectorWithValues:vectorParts count:count] ;
        } else {
            [[LuaSkin shared] logError:@"CIVector expects non-empty array table"] ;
        }
    } else {
        [[LuaSkin shared] logError:[NSString stringWithFormat:@"CIVector expects table, found %s", lua_typename(L, lua_type(L, idx))]] ;
    }
    return theVector ;
}

static int pushCIColor(__unused lua_State *L, id obj) {
    return [[LuaSkin shared] pushNSObject:[NSColor colorWithCIColor:(CIColor *)obj]] ;
}

static id toCIColorFromLua(__unused lua_State *L, int idx) {
    return [[CIColor alloc] initWithColor:[[LuaSkin shared] luaObjectAtIndex:idx toClass:"NSColor"]] ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    if (luaL_testudata(L, 1, CIIMAGE_UD_TAG)) {
//         CIImage *obj = [skin luaObjectAtIndex:1 toClass:"CIImage"] ;
        [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", CIIMAGE_UD_TAG, lua_topointer(L, 1)]] ;
    } else if (luaL_testudata(L, 1, IKUIVIEW_UD_TAG)) {
        NSWindow *obj = get_objectFromUserdata(__bridge NSWindow, L, 1, IKUIVIEW_UD_TAG) ;
        [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", IKUIVIEW_UD_TAG, [[(IKFilterUIView *)[obj contentView] filter] name], lua_topointer(L, 1)]] ;
    } else {

        CIFilter *obj = [skin luaObjectAtIndex:1 toClass:"CIFilter"] ;
        [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, [obj name], lua_topointer(L, 1)]] ;
    }
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        CIFilter *obj1 = [skin luaObjectAtIndex:1 toClass:"CIFilter"] ;
        CIFilter *obj2 = [skin luaObjectAtIndex:2 toClass:"CIFilter"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else if (luaL_testudata(L, 1, CIIMAGE_UD_TAG) && luaL_testudata(L, 2, CIIMAGE_UD_TAG)) {
        CIImage *obj1 = [skin luaObjectAtIndex:1 toClass:"CIImage"] ;
        CIImage *obj2 = [skin luaObjectAtIndex:2 toClass:"CIImage"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else if (luaL_testudata(L, 1, IKUIVIEW_UD_TAG) && luaL_testudata(L, 2, IKUIVIEW_UD_TAG)) {
        NSWindow *obj1 = get_objectFromUserdata(__bridge NSWindow, L, 1, IKUIVIEW_UD_TAG) ;
        NSWindow *obj2 = get_objectFromUserdata(__bridge NSWindow, L, 2, IKUIVIEW_UD_TAG) ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
// for now, we don't have to differentiate... if that changes, so will this
    id obj = (__bridge_transfer id)*((void**)lua_touserdata(L, 1)) ;
    if (obj) {
        if (luaL_testudata(L, 1, IKUIVIEW_UD_TAG)) {
            [(NSWindow *)obj close] ;
            [(NSWindow *)obj setContentView:nil] ;
        }
        obj = nil ;
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
    {"details",      filterDetails},
    {"reset",        resetFilter},
    {"enabled",      enabledFilter},
    {"getParameter", getFilterParameter},
    {"setParameter", setFilterParameter},
    {"filterUI",     filterUserInterface},
    {"__tostring",   userdata_tostring},
    {"__eq",         userdata_eq},
    {"__gc",         userdata_gc},
    {NULL,           NULL}
};

static const luaL_Reg ciimage_ud_metaLib[] = {
    {"asHSImage",  ciimageAsHSImage},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

static const luaL_Reg ikuiview_ud_metaLib[] = {
    {"show",         IKFilterUIViewShow},
    {"hide",         IKFilterUIViewHide},
    {"delete",       userdata_gc},
    {"_asHSDrawing", IKFilterUIViewAsHSDrawing},
    {"_windowStyle", IKFilterUIViewWindowStyle},

    {"__tostring",   userdata_tostring},
    {"__eq",         userdata_eq},
    {"__gc",         userdata_gc},
    {NULL,           NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"filters",          filterNamesInCategory},
    {"imageFromHSImage", HSImageAsCIImage},
    {"initFilter",       getFilterObject},

    {NULL,               NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_cifilter_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];
    [skin registerObject:CIIMAGE_UD_TAG objectFunctions:ciimage_ud_metaLib] ;
    [skin registerObject:IKUIVIEW_UD_TAG objectFunctions:ikuiview_ud_metaLib] ;

    pushFilterCategories(L) ;            lua_setfield(L, -2, "categories") ;
    pushFilterParameterKeys(L) ;         lua_setfield(L, -2, "parameterKeys") ;


    [skin registerPushNSHelper:pushCIFilter         forClass:"CIFilter"] ;
    [skin registerLuaObjectHelper:toCIFilterFromLua forClass:"CIFilter"];

    [skin registerPushNSHelper:pushCIImage         forClass:"CIImage"] ;
    [skin registerLuaObjectHelper:toCIImageFromLua forClass:"CIImage"];

//     [skin registerPushNSHelper:pushNSAffineTransform         forClass:"NSAffineTransform"] ;
//     [skin registerLuaObjectHelper:toNSAffineTransformFromLua forClass:"NSAffineTransform"];

    [skin registerPushNSHelper:pushCIVector         forClass:"CIVector"] ;
    [skin registerLuaObjectHelper:toCIVectorFromLua forClass:"CIVector"];

    [skin registerPushNSHelper:pushCIColor         forClass:"CIColor"] ;
    [skin registerLuaObjectHelper:toCIColorFromLua forClass:"CIColor"];

    return 1;
}
