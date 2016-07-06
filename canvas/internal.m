
//   in init.lua, add wrapper to take array of elements and replace all
//   ALL_TYPES like languageDictionary, rather than as repeated literal?
//   keep elementSpec function?
//   should circle and arc remain or auto-convert or be removed?

//   Redo callback details per description in `hs._asm.canvas:elements`
//   Should we optionally allow turning off NSView rect clipping like drawing does always?
//   Start coding the hard parts, you monkey!

@import Cocoa ;
@import LuaSkin ;

#define USERDATA_TAG "hs._asm.canvas"
static int refTable = LUA_NOREF;

// Can't have "static" or "constant" dynamic NSObjects like NSArray, so define in lua_open
static NSDictionary *languageDictionary ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

@interface ASMCanvasWindow : NSPanel <NSWindowDelegate>
@property int                 selfRef ;
@end

@interface ASMCanvasView : NSView
@property int                 clickDownRef;
@property int                 clickUpRef;
@property NSMutableDictionary *canvasDefaults ;
@property NSMutableArray      *elementList ;
@property NSAffineTransform   *canvasTransform ;
@end

typedef NS_ENUM(NSInteger, attributeValidity) {
    attributeValid,
    attributeNulling,
    attributeInvalid,
};

#define ALL_TYPES  @[ @"arc", @"circle", @"curve", @"ellipticalArc", @"image", @"line", @"oval", @"point", @"rectangle", @"resetClip", @"segments", @"text" ]
#define VISIBLE    @[ @"arc", @"circle", @"curve", @"ellipticalArc", @"image", @"line", @"oval", @"point", @"rectangle", @"segments", @"text" ]
#define PRIMITIVES @[ @"arc", @"circle", @"curve", @"ellipticalArc", @"line", @"oval", @"point", @"rectangle", @"segments" ]
#define CLOSED     @[ @"arc", @"circle", @"ellipticalArc", @"oval", @"rectangle", @"segments" ]


#define STROKE_JOIN_STYLES @{ \
        @"miter" : @(NSMiterLineJoinStyle), \
        @"round" : @(NSBevelLineJoinStyle), \
        @"bevel" : @(NSBevelLineJoinStyle), \
}

#define STROKE_CAP_STYLES @{ \
        @"butt"   : @(NSButtLineCapStyle), \
        @"round"  : @(NSRoundLineCapStyle), \
        @"square" : @(NSSquareLineCapStyle), \
}

#define COMPOSITING_TYPES @{ \
        @"clear"           : @(NSCompositeClear), \
        @"copy"            : @(NSCompositeCopy), \
        @"sourceOver"      : @(NSCompositeSourceOver), \
        @"sourceIn"        : @(NSCompositeSourceIn), \
        @"sourceOut"       : @(NSCompositeSourceOut), \
        @"sourceAtop"      : @(NSCompositeSourceAtop), \
        @"destinationOver" : @(NSCompositeDestinationOver), \
        @"destinationIn"   : @(NSCompositeDestinationIn), \
        @"destinationOut"  : @(NSCompositeDestinationOut), \
        @"destinationAtop" : @(NSCompositeDestinationAtop), \
        @"XOR"             : @(NSCompositeXOR), \
        @"plusDarker"      : @(NSCompositePlusDarker), \
        @"plusLighter"     : @(NSCompositePlusLighter), \
}

#define WINDING_RULES @{ \
        @"evenOdd" : @(NSEvenOddWindingRule), \
        @"nonZero" : @(NSNonZeroWindingRule), \
}

#pragma mark - Support Functions and Classes

static NSDictionary *defineLanguageDictionary() {
    // the default shadow has no offset or blur radius, so lets setup one that is at least visible
    NSShadow *defaultShadow = [[NSShadow alloc] init] ;
    [defaultShadow setShadowOffset:NSMakeSize(5.0, -5.0)];
    [defaultShadow setShadowBlurRadius:5.0];
//     [defaultShadow setShadowColor:[[NSColor blackColor] colorWithAlphaComponent:0.3]];

    return @{
        @"action" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"default"     : @"strokeAndFill",
            @"values"      : @[
                                   @"stroke",
                                   @"fill",
                                   @"strokeAndFill",
                                   @"clip",
                                   @"build",
                                   @"skip",
                             ],
            @"nullable" : @(YES),
            @"optionalFor" : ALL_TYPES,
        },
        @"absolutePosition" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(YES),
            @"optionalFor" : VISIBLE,
        },
        @"absoluteSize" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(YES),
            @"optionalFor" : VISIBLE,
        },
        @"antialias" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(YES),
            @"optionalFor" : VISIBLE,
        },
        @"arcRadii" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(YES),
            @"optionalFor" : @[ @"arc", @"ellipticalArc" ],
        },
        @"arcClockwise" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(YES),
            @"optionalFor" : @[ @"arc", @"ellipticalArc" ],
        },
        @"compositeRule" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [COMPOSITING_TYPES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"sourceOver",
            @"optionalFor" : VISIBLE,
        },
        @"center" : @{
            @"class"         : @[ [NSDictionary class] ],
            @"luaClass"      : @"table",
            @"keys"          : @{
                @"x" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
                @"y" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
            },
            @"default"       : @{
                                   @"x" : @"50%",
                                   @"y" : @"50%",
                               },
            @"nullable"      : @(NO),
            @"requiredFor"   : @[ @"circle", @"arc" ],
        },
        @"end" : @{
            @"class"         : @[ [NSDictionary class] ],
            @"luaClass"      : @"table",
            @"keys"          : @{
                @"x" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
                @"y" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
            },
            @"default"       : @{
                                   @"x" : @"100%",
                                   @"y" : @"100%",
                               },
            @"nullable"      : @(NO),
            @"requiredFor"   : @[ @"line" ],
        },
        @"endAngle" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"default"     : @(360.0),
            @"nullable"    : @(NO),
            @"requiredFor" : @[ @"arc", @"ellipticalArc" ],
        },
        @"fillColor" : @{
            @"class"       : @[ [NSColor class] ],
            @"luaClass"    : @"hs.drawing.color table",
            @"nullable"    : @(YES),
            @"default"     : [NSColor redColor],
            @"optionalFor" : CLOSED,
        },
        @"fillGradient" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : @[
                                   @"none",
                                   @"linear",
                                   @"radial",
                             ],
            @"nullable"    : @(YES),
            @"default"     : @"none",
            @"optionalFor" : CLOSED,
        },
        @"fillGradientAngle"  : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"nullable"    : @(YES),
            @"default"     : @(0.0),
            @"optionalFor" : CLOSED,
        },
        @"fillGradientCenter" : @{
            @"class"         : @[ [NSDictionary class] ],
            @"luaClass"      : @"table",
            @"keys"          : @{
                @"x" : @{
                    @"class"     : @[ [NSNumber class] ],
                    @"luaClass"  : @"number",
                    @"maxNumber" : @(1.0),
                    @"minNumber" : @(-1.0),
                },
                @"y" : @{
                    @"class"    : @[ [NSNumber class] ],
                    @"luaClass" : @"number",
                    @"maxNumber" : @(1.0),
                    @"minNumber" : @(-1.0),
                },
            },
            @"default"       : @{
                                   @"x" : @(0.0),
                                   @"y" : @(0.0),
                               },
            @"nullable"      : @(YES),
            @"optionalFor"   : CLOSED,
        },
        @"fillGradientColors" : @{
            @"class"       : @[ [NSDictionary class] ],
            @"luaClass"    : @"table",
            @"keys"        : @{
                @"startColor" : @{
                    @"class"    : @[ [NSColor class] ],
                    @"luaClass" : @"hs.drawing.color table",
                },
                @"endColor" : @{
                    @"class"    : @[ [NSColor class] ],
                    @"luaClass" : @"hs.drawing.color table",
                },
            },
            @"default"     : @{
                                 @"startColor" : [NSColor blackColor],
                                 @"endColor"   : [NSColor whiteColor],
                             },
            @"nullable"    : @(YES),
            @"optionalFor" : CLOSED,
        },
        @"flatness" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"nullable"    : @(YES),
            @"default"     : @([NSBezierPath defaultFlatness]),
            @"optionalFor" : PRIMITIVES,
        },
        @"flattenPath" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : PRIMITIVES,
        },
        @"frame" : @{
            @"class"         : @[ [NSDictionary class] ],
            @"luaClass"      : @"table",
            @"keys"          : @{
                @"x" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
                @"y" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
                @"h" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
                @"w" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
            },
            @"default"       : @{
                                   @"x" : @"0%",
                                   @"y" : @"0%",
                                   @"h" : @"100%",
                                   @"w" : @"100%",
                               },
            @"nullable"      : @(NO),
            @"requiredFor"   : @[ @"rectangle", @"oval", @"ellipticalArc", @"text", @"image" ],
        },
        @"id" : @{
            @"class"       : @[ [NSString class], [NSNumber class] ],
            @"luaClass"    : @"string or number",
            @"nullable"    : @(YES),
            @"optionalFor" : VISIBLE,
        },
        @"image" : @{
            @"class"       : @[ [NSImage class] ],
            @"luaClass"    : @"hs.image object",
            @"nullable"    : @(YES),
            @"default"     : [[NSImage alloc] initWithSize:NSMakeSize(1.0, 1.0)],
            @"optionalFor" : @[ @"image" ],
        },
        @"miterLimit" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"default"     : @([NSBezierPath defaultMiterLimit]),
            @"nullable"    : @(YES),
            @"optionalFor" : PRIMITIVES,
        },
        @"padding" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"default"     : @(10.0),
            @"nullable"    : @(YES),
            @"optionalFor" : VISIBLE,
        },
        @"radius" : @{
            @"class"       : @[ [NSNumber class], [NSString class] ],
            @"luaClass"    : @"number or string",
            @"nullable"    : @(NO),
            @"default"     : @"50%",
            @"requiredFor" : @[ @"arc", @"circle" ],
        },
        @"reversePath" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : PRIMITIVES,
        },
        @"roundedRectRadii" : @{
            @"class"         : @[ [NSDictionary class] ],
            @"luaClass"      : @"table",
            @"keys"          : @{
                @"xRadius" : @{
                    @"class"    : @[ [NSNumber class] ],
                    @"luaClass" : @"number",
                },
                @"yRadius" : @{
                    @"class"    : @[ [NSNumber class] ],
                    @"luaClass" : @"number",
                },
            },
            @"default"       : @{
                                   @"xRadius" : @(0.0),
                                   @"yRadius" : @(0.0),
                               },
            @"nullable"      : @(YES),
            @"optionalFor"   : @[ @"rectangle" ],
        },
        @"shadow" : @{
            @"class"       : @[ [NSShadow class] ],
            @"luaClass"    : @"shadow table",
            @"nullable"    : @(YES),
            @"default"     : defaultShadow,
            @"optionalFor" : PRIMITIVES,
        },
        @"start" : @{
            @"class"         : @[ [NSDictionary class] ],
            @"luaClass"      : @"table",
            @"keys"          : @{
                @"x" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
                @"y" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
            },
            @"default"       : @{
                                   @"x" : @"0%",
                                   @"y" : @"0%",
                               },
            @"nullable"      : @(NO),
            @"requiredFor"   : @[ @"line" ],
        },
        @"startAngle" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"default"     : @(0.0),
            @"nullable"    : @(NO),
            @"requiredFor" : @[ @"arc", @"ellipticalArc" ],
        },
        @"strokeCapStyle" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [STROKE_CAP_STYLES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"butt",
            @"optionalFor" : PRIMITIVES,
        },
        @"strokeColor" : @{
            @"class"       : @[ [NSColor class] ],
            @"luaClass"    : @"hs.drawing.color table",
            @"nullable"    : @(YES),
            @"default"     : [NSColor blackColor],
            @"optionalFor" : PRIMITIVES,
        },
        @"strokeDashPattern" : @{
            @"class"          : @[ [NSArray class] ],
            @"luaClass"       : @"table",
            @"nullable"       : @(YES),
            @"default"        : @[ ],
            @"memberClass"    : [NSNumber class],
            @"memberLuaClass" : @"number",
            @"optionalFor"    : PRIMITIVES,
        },
        @"strokeDashPhase" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"default"     : @(0.0),
            @"nullable"    : @(YES),
            @"optionalFor" : PRIMITIVES,
        },
        @"strokeJoinStyle" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [STROKE_JOIN_STYLES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"miter",
            @"optionalFor" : PRIMITIVES,
        },
        @"strokeWidth" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"default"     : @([NSBezierPath defaultLineWidth]),
            @"nullable"    : @(YES),
            @"optionalFor" : PRIMITIVES,
        },
        @"text" : @{
            @"class"       : @[ [NSString class], [NSNumber class], [NSAttributedString class] ],
            @"luaClass"    : @"string or hs.styledText object",
            @"default"     : @"",
            @"nullable"    : @(NO),
            @"requiredFor" : @[ @"text" ],
        },
        @"textColor" : @{
            @"class"       : @[ [NSColor class] ],
            @"luaClass"    : @"hs.drawing.color table",
            @"nullable"    : @(YES),
            @"default"     : [NSColor colorWithCalibratedWhite:1.0 alpha:1.0],
            @"optionalFor" : @[ @"text" ],
        },
        @"textFont" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"nullable"    : @(YES),
            @"default"     : [[NSFont systemFontOfSize: 27] fontName],
            @"optionalFor" : @[ @"text" ],
        },
        @"textSize" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"nullalble"   : @(YES),
            @"default"     : @(27.0),
            @"optionalFor" : @[ @"text" ],
        },
        @"trackMouseEnter" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : VISIBLE,
        },
        @"trackMouseExit" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : VISIBLE,
        },
        @"trackMouseDown" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : VISIBLE,
        },
        @"trackMouseUp" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : VISIBLE,
        },
        @"trackMouseMove" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : VISIBLE,
        },
        @"transformation" : @{
            @"class"       : @[ [NSAffineTransform class] ],
            @"luaClass"    : @"transform table",
            @"nullable"    : @(YES),
            @"default"     : [NSAffineTransform transform],
            @"optionalFor" : VISIBLE,
        },
        @"type" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : ALL_TYPES,
            @"nullable"    : @(NO),
            @"requiredFor" : ALL_TYPES,
        },
        @"windingRule" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [WINDING_RULES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"nonZero",
            @"optionalFor" : PRIMITIVES,
        },
        @"withShadow" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : PRIMITIVES,
        },
    } ;
}

static attributeValidity isValueValidForAttribute(NSString *keyName, id keyValue) {
    NSDictionary      *attributeDefinition = languageDictionary[keyName] ;
    attributeValidity validity = attributeValid ;
    NSString          *errorMessage ;
    BOOL              checked = NO ;

    while (!checked) {  // doing this as a loop so we can break out as soon as we know enough
        checked = YES ; // but we really don't want to loop

        if (!keyValue || [keyValue isKindOfClass:[NSNull class]]) {
            if (attributeDefinition[@"nullable"] && [attributeDefinition[@"nullable"] boolValue]) {
                validity = attributeNulling ;
            } else {
                errorMessage = [NSString stringWithFormat:@"%@ is not nullable", keyName] ;
            }
            break ;
        }

        if ([attributeDefinition[@"class"] isKindOfClass:[NSArray class]]) {
            BOOL found = NO ;
            for (NSUInteger i = 0 ; i < [attributeDefinition[@"class"] count] ; i++) {
                found = [keyValue isKindOfClass:attributeDefinition[@"class"][i]] ;
                if (found) break ;
            }
            if (!found) {
                errorMessage = [NSString stringWithFormat:@"%@ must be a %@", keyName, attributeDefinition[@"luaClass"]] ;
                break ;
            }
        } else {
            if (![keyValue isKindOfClass:attributeDefinition[@"class"]]) {
                errorMessage = [NSString stringWithFormat:@"%@ must be a %@", keyName, attributeDefinition[@"luaClass"]] ;
                break ;
            }
        }

        if (attributeDefinition[@"objCType"]) {
            if (strcmp([attributeDefinition[@"objCType"] UTF8String], [keyValue objCType])) {
                errorMessage = [NSString stringWithFormat:@"%@ must be a %@", keyName, attributeDefinition[@"luaClass"]] ;
                break ;
            }
        }

        if (attributeDefinition[@"values"]) {
            BOOL found = NO ;
            for (NSUInteger i = 0 ; i < [attributeDefinition[@"values"] count] ; i++) {
                found = [attributeDefinition[@"values"][i] isEqualToString:keyValue] ;
                if (found) break ;
            }
            if (!found) {
                errorMessage = [NSString stringWithFormat:@"%@ must be one of %@", keyName, [attributeDefinition[@"values"] componentsJoinedByString:@", "]] ;
                break ;
            }
        }

        if (attributeDefinition[@"maxNumber"]) {
            if ([keyValue doubleValue] > [attributeDefinition[@"maxNumber"] doubleValue]) {
                errorMessage = [NSString stringWithFormat:@"%@ must be <= %f", keyName, [attributeDefinition[@"maxNumber"] doubleValue]] ;
                break ;
            }
        }

        if (attributeDefinition[@"minNumber"]) {
            if ([keyValue doubleValue] < [attributeDefinition[@"minNumber"] doubleValue]) {
                errorMessage = [NSString stringWithFormat:@"%@ must be >= %f", keyName, [attributeDefinition[@"minNumber"] doubleValue]] ;
                break ;
            }
        }

        if ([keyValue isKindOfClass:[NSDictionary class]]) {
            NSDictionary *subKeys = attributeDefinition[@"keys"] ;
            for (NSString *subKeyName in subKeys) {
                NSDictionary *subKeyMiniDefinition = subKeys[subKeyName] ;
                if ([subKeyMiniDefinition[@"class"] isKindOfClass:[NSArray class]]) {
                    BOOL found = NO ;
                    for (NSUInteger i = 0 ; i < [subKeyMiniDefinition[@"class"] count] ; i++) {
                        found = [keyValue[subKeyName] isKindOfClass:subKeyMiniDefinition[@"class"][i]] ;
                        if (found) break ;
                    }
                    if (!found) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be a %@", subKeyName, keyName, subKeyMiniDefinition[@"luaClass"]] ;
                        break ;
                    }
                } else {
                    if (![keyValue[subKeyName] isKindOfClass:subKeyMiniDefinition[@"class"]]) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be a %@", subKeyName, keyName, subKeyMiniDefinition[@"luaClass"]] ;
                        break ;
                    }
                }

                if (subKeyMiniDefinition[@"objCType"]) {
                    if (strcmp([subKeyMiniDefinition[@"objCType"] UTF8String], [keyValue[subKeyName] objCType])) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be a %@", subKeyName, keyName, subKeyMiniDefinition[@"luaClass"]] ;
                        break ;
                    }
                }

                if (subKeyMiniDefinition[@"values"]) {
                    BOOL found = NO ;
                    NSString *subKeyValue = keyValue[subKeyName] ;
                    for (NSUInteger i = 0 ; i < [subKeyMiniDefinition[@"values"] count] ; i++) {
                        found = [subKeyMiniDefinition[@"values"][i] isEqualToString:subKeyValue] ;
                        if (found) break ;
                    }
                    if (!found) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be one of %@", subKeyName, keyName, [subKeyMiniDefinition[@"values"] componentsJoinedByString:@", "]] ;
                        break ;
                    }
                }

                if (subKeyMiniDefinition[@"maxNumber"]) {
                    if ([keyValue[subKeyName] doubleValue] > [subKeyMiniDefinition[@"maxNumber"] doubleValue]) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be <= %f", subKeyName, keyName, [subKeyMiniDefinition[@"maxNumber"] doubleValue]] ;
                        break ;
                    }
                }

                if (subKeyMiniDefinition[@"minNumber"]) {
                    if ([keyValue[subKeyName] doubleValue] < [subKeyMiniDefinition[@"minNumber"] doubleValue]) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be >= %f", subKeyName, keyName, [subKeyMiniDefinition[@"minNumber"] doubleValue]] ;
                        break ;
                    }
                }

            }
            if (errorMessage) break ;
        }

        if ([keyValue isKindOfClass:[NSArray class]]) {
            BOOL isGood = YES ;
            for (NSUInteger i = 0 ; i < [keyValue count] ; i++) {
                if (![keyValue[i] isKindOfClass:attributeDefinition[@"memberClass"]]) {
                    isGood = NO ;
                    break ;
                }
            }
            if (!isGood) {
                errorMessage = [NSString stringWithFormat:@"%@ must be an array of %@ values", keyName, attributeDefinition[@"memberLuaClass"]] ;
                break ;
            }
        }
    }
    if (errorMessage) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:%@", USERDATA_TAG, errorMessage]] ;
        validity = attributeInvalid ;
    }
    return validity ;
}

static NSNumber *convertPercentageStringToNumber(NSString *stringValue) {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = [NSLocale currentLocale] ;
    formatter.numberStyle = NSNumberFormatterDecimalStyle ;

    NSNumber *tmpValue = [formatter numberFromString:stringValue] ;
    if (!tmpValue) {
        formatter.numberStyle = NSNumberFormatterPercentStyle ;
        tmpValue = [formatter numberFromString:stringValue] ;
    }
    return tmpValue ;
}

static inline NSRect RectWithFlippedYCoordinate(NSRect theRect) {
    return NSMakeRect(theRect.origin.x,
                      [[NSScreen screens][0] frame].size.height - theRect.origin.y - theRect.size.height,
                      theRect.size.width,
                      theRect.size.height) ;
}

static int canvas_orderHelper(lua_State *L, NSWindowOrderingMode mode) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK | LS_TVARARG] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    NSInteger       relativeTo = 0 ;

    if (lua_gettop(L) > 1) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                        LS_TUSERDATA, USERDATA_TAG,
                        LS_TBREAK] ;
        relativeTo = [[skin luaObjectAtIndex:2 toClass:"ASMCanvasWindow"] windowNumber] ;
    }

    [canvasWindow orderWindow:mode relativeTo:relativeTo] ;

    lua_pushvalue(L, 1);
    return 1 ;
}

static int userdata_gc(lua_State* L) ;

#pragma mark -
@implementation ASMCanvasWindow
- (instancetype)initWithContentRect:(NSRect)contentRect
                          styleMask:(NSUInteger)windowStyle
                            backing:(NSBackingStoreType)bufferingType
                              defer:(BOOL)deferCreation {

    LuaSkin *skin = [LuaSkin shared];

    if (!(isfinite(contentRect.origin.x) && isfinite(contentRect.origin.y) && isfinite(contentRect.size.height) && isfinite(contentRect.size.width))) {
        [skin logError:[NSString stringWithFormat:@"%s: non-finite co-ordinates/size specified", USERDATA_TAG]];
        return nil;
    }

    self = [super initWithContentRect:contentRect
                            styleMask:windowStyle
                              backing:bufferingType
                                defer:deferCreation];
    if (self) {
        _selfRef = LUA_NOREF ;

        [self setDelegate:self];

        [self setFrameOrigin:RectWithFlippedYCoordinate(contentRect).origin];

        // Configure the window
        self.releasedWhenClosed = NO;
        self.backgroundColor    = [NSColor clearColor];
        self.opaque             = NO;
        self.hasShadow          = NO;
        self.ignoresMouseEvents = YES;
        self.restorable         = NO;
        self.hidesOnDeactivate  = NO;
        self.animationBehavior  = NSWindowAnimationBehaviorNone;
        self.level              = NSScreenSaverWindowLevel;
    }
    return self;
}

#pragma mark - NSWindowDelegate Methods

- (BOOL)windowShouldClose:(id __unused)sender {
    return NO;
}

#pragma mark - Window Animation Methods

- (void)fadeIn:(NSTimeInterval)fadeTime {
    [self setAlphaValue:0.0];
    [self makeKeyAndOrderFront:nil];
    [NSAnimationContext beginGrouping];
      [[NSAnimationContext currentContext] setDuration:fadeTime];
      [[self animator] setAlphaValue:1.0];
    [NSAnimationContext endGrouping];
}

- (void)fadeOut:(NSTimeInterval)fadeTime andDelete:(BOOL)deleteCanvas {
    [NSAnimationContext beginGrouping];
#if __has_feature(objc_arc)
      __weak ASMCanvasWindow *bself = self; // in ARC, __block would increase retain count
#else
      __block ASMCanvasWindow *bself = self;
#endif
      [[NSAnimationContext currentContext] setDuration:fadeTime];
      [[NSAnimationContext currentContext] setCompletionHandler:^{
          // unlikely that bself will go to nil after this starts, but this keeps the warnings down from [-Warc-repeated-use-of-weak]
          ASMCanvasWindow *mySelf = bself ;
          if (mySelf) {
              if (deleteCanvas) {
              LuaSkin *skin = [LuaSkin shared] ;
                  lua_State *L = [skin L] ;
                  lua_pushcfunction(L, userdata_gc) ;
                  [skin pushLuaRef:refTable ref:mySelf.selfRef] ;
                  if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
                      [skin logBreadcrumb:[NSString stringWithFormat:@"%s:error invoking _gc for delete (with fade) method:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
                      lua_pop(L, 1) ;
                      [mySelf close] ;  // the least we can do is close the canvas if an error occurs with __gc
                  }
              } else {
                  [mySelf orderOut:nil];
                  [mySelf setAlphaValue:1.0];
              }
          }
      }];
      [[self animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
}
@end

#pragma mark -
@implementation ASMCanvasView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _clickDownRef    = LUA_NOREF;
        _clickUpRef      = LUA_NOREF;
        _canvasDefaults  = [[NSMutableDictionary alloc] init] ;
        _elementList     = [[NSMutableArray alloc] init] ;
        _canvasTransform = [NSAffineTransform transform] ;
    }
    return self;
}

- (BOOL)isFlipped { return YES; }

- (BOOL)acceptsFirstMouse:(__unused NSEvent *)theEvent {
    if (self.window == nil) return NO;
    return !self.window.ignoresMouseEvents;
}

- (void)mouseDown:(NSEvent *)theEvent {
    [NSApp preventWindowOrdering];
    BOOL isDown = (theEvent.type == NSLeftMouseDown)  ||
                  (theEvent.type == NSRightMouseDown) ||
                  (theEvent.type == NSOtherMouseDown) ;
    int callbackRef = isDown ? _clickDownRef : _clickUpRef ;

    if (callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared];
        [skin pushLuaRef:refTable ref:callbackRef];
        [skin pushLuaRef:refTable ref:((ASMCanvasWindow *)self.window).selfRef] ;
        if (![skin protectedCallAndTraceback:1 nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:clickCallback %s callback error: %s",
                                                      USERDATA_TAG,
                                                      (isDown ? "mouseDown" : "mouseUp"),
                                                      lua_tostring(skin.L, -1)]];
            lua_pop(skin.L, 1) ;
        }
    }
}

- (void)rightMouseDown:(NSEvent *)theEvent { [self mouseDown:theEvent] ; }
- (void)otherMouseDown:(NSEvent *)theEvent { [self mouseDown:theEvent] ; }
- (void)mouseUp:(NSEvent *)theEvent        { [self mouseDown:theEvent] ; }
- (void)rightMouseUp:(NSEvent *)theEvent   { [self mouseDown:theEvent] ; }
- (void)otherMouseUp:(NSEvent *)theEvent   { [self mouseDown:theEvent] ; }

- (void)drawRect:(__unused NSRect)rect {
    NSDisableScreenUpdates() ;

    NSGraphicsContext* gc = [NSGraphicsContext currentContext];
    [gc saveGraphicsState];

    [_canvasTransform concat] ;

    [NSBezierPath setDefaultLineWidth:[[self getDefaultValueFor:@"strokeWidth" onlyIfSet:NO] doubleValue]] ;
    [NSBezierPath setDefaultMiterLimit:[[self getDefaultValueFor:@"miterLimit" onlyIfSet:NO] doubleValue]] ;
    [NSBezierPath setDefaultFlatness:[[self getDefaultValueFor:@"flatness" onlyIfSet:NO] doubleValue]] ;

    NSString *LJS = [self getDefaultValueFor:@"strokeJoinStyle" onlyIfSet:NO] ;
    [NSBezierPath setDefaultLineJoinStyle:[STROKE_JOIN_STYLES[LJS] unsignedIntValue]] ;

    NSString *LCS = [self getDefaultValueFor:@"strokeCapStyle" onlyIfSet:NO] ;
    [NSBezierPath setDefaultLineJoinStyle:[STROKE_CAP_STYLES[LCS] unsignedIntValue]] ;

    NSString *WR = [self getDefaultValueFor:@"windingRule" onlyIfSet:NO] ;
    [NSBezierPath setDefaultWindingRule:[WINDING_RULES[WR] unsignedIntValue]] ;

    NSString *CS = [self getDefaultValueFor:@"compositeRule" onlyIfSet:NO] ;
    gc.compositingOperation = [COMPOSITING_TYPES[CS] unsignedIntValue] ;

    [[self getDefaultValueFor:@"antialias" onlyIfSet:NO] boolValue] ;
    [[self getDefaultValueFor:@"fillColor" onlyIfSet:NO] setFill] ;
    [[self getDefaultValueFor:@"strokeColor" onlyIfSet:NO] setStroke] ;

    __block BOOL clippingModified = NO ;

    __block NSBezierPath *renderPath ;
    [_elementList enumerateObjectsUsingBlock:^(NSDictionary *element, NSUInteger idx, __unused BOOL *stop) {
        NSBezierPath *elementPath ;
        NSString     *elementType = element[@"type"] ;
        NSString     *action      = [self getElementValueFor:@"action" atIndex:idx] ;

        BOOL wasClippingChanged = NO ; // necessary to keep graphicsState stack properly ordered

        [gc saveGraphicsState] ;

        BOOL hasShadow = [[self getElementValueFor:@"withShadow" atIndex:idx] boolValue] ;
        if (hasShadow) [(NSShadow *)[self getElementValueFor:@"shadow" atIndex:idx] set] ;

        NSNumber *shouldAntialias = [self getElementValueFor:@"antialias" atIndex:idx onlyIfSet:YES] ;
        if (shouldAntialias) gc.shouldAntialias = [shouldAntialias boolValue] ;

        NSString *compositingString = [self getElementValueFor:@"compositeRule" atIndex:idx onlyIfSet:YES] ;
        if (compositingString) gc.compositingOperation = [COMPOSITING_TYPES[compositingString] unsignedIntValue] ;

        NSColor *fillColor = [self getElementValueFor:@"fillColor" atIndex:idx onlyIfSet:YES] ;
        if (fillColor) [fillColor setFill] ;

        NSColor *strokeColor = [self getElementValueFor:@"strokeColor" atIndex:idx onlyIfSet:YES] ;
        if (strokeColor) [strokeColor setFill] ;

        NSAffineTransform *elementTransform = [self getElementValueFor:@"transformation" atIndex:idx onlyIfSet:YES] ;
        if (elementTransform) [elementTransform concat] ;

        NSDictionary *frame = [self getElementValueFor:@"frame" atIndex:idx resolvePercentages:YES] ;
        NSRect  frameRect = NSMakeRect([frame[@"x"] doubleValue], [frame[@"y"] doubleValue],
                                       [frame[@"w"] doubleValue], [frame[@"h"] doubleValue]) ;


        if ([elementType isEqualToString:@"arc"]) {
            NSDictionary *center = [self getElementValueFor:@"center" atIndex:idx resolvePercentages:YES] ;
            CGFloat cx = [center[@"x"] doubleValue] ;
            CGFloat cy = [center[@"y"] doubleValue] ;
            CGFloat r  = [[self getElementValueFor:@"radius" atIndex:idx resolvePercentages:YES] doubleValue] ;
            NSPoint myCenterPoint = NSMakePoint(cx, cy) ;
            elementPath = [NSBezierPath bezierPath];
            CGFloat startAngle = [[self getElementValueFor:@"startAngle" atIndex:idx] doubleValue] - 90 ;
            CGFloat endAngle   = [[self getElementValueFor:@"endAngle" atIndex:idx] doubleValue] - 90 ;
            BOOL    arcDir     = [[self getElementValueFor:@"arcClockwise" atIndex:idx] boolValue] ;
            BOOL    arcLegs    = [[self getElementValueFor:@"arcRadii" atIndex:idx] boolValue] ;
            if (arcLegs) [elementPath moveToPoint:myCenterPoint] ;
            [elementPath appendBezierPathWithArcWithCenter:myCenterPoint
                                                    radius:r
                                                startAngle:startAngle
                                                  endAngle:endAngle
                                                 clockwise:!arcDir // because our canvas is flipped, we have to reverse this
            ] ;
            if (arcLegs) [elementPath lineToPoint:myCenterPoint] ;
        } else
        if ([elementType isEqualToString:@"circle"]) {
            NSDictionary *center = [self getElementValueFor:@"center" atIndex:idx resolvePercentages:YES] ;
            CGFloat cx = [center[@"x"] doubleValue] ;
            CGFloat cy = [center[@"y"] doubleValue] ;
            CGFloat r  = [[self getElementValueFor:@"radius" atIndex:idx resolvePercentages:YES] doubleValue] ;
            elementPath = [NSBezierPath bezierPath];
            [elementPath appendBezierPathWithOvalInRect:NSMakeRect(cx - r, cy - r, r * 2, r * 2)] ;
        } else
        if ([elementType isEqualToString:@"ellipticalArc"]) {
            CGFloat cx     = frameRect.origin.x + frameRect.size.width / 2 ;
            CGFloat cy     = frameRect.origin.y + frameRect.size.height / 2 ;
            CGFloat r      = frameRect.size.width / 2 ;

            NSAffineTransform *moveTransform = [NSAffineTransform transform] ;
            [moveTransform translateXBy:cx yBy:cy] ;
            NSAffineTransform *scaleTransform = [NSAffineTransform transform] ;
            [scaleTransform scaleXBy:1.0 yBy:(frameRect.size.height / frameRect.size.width)] ;
            NSAffineTransform *finalTransform = [[NSAffineTransform alloc] initWithTransform:scaleTransform] ;
            [finalTransform appendTransform:moveTransform] ;
            elementPath = [NSBezierPath bezierPath];
            CGFloat startAngle = [[self getElementValueFor:@"startAngle" atIndex:idx] doubleValue] - 90 ;
            CGFloat endAngle   = [[self getElementValueFor:@"endAngle" atIndex:idx] doubleValue] - 90 ;
            BOOL    arcDir     = [[self getElementValueFor:@"arcClockwise" atIndex:idx] boolValue] ;
            BOOL    arcLegs    = [[self getElementValueFor:@"arcRadii" atIndex:idx] boolValue] ;
            if (arcLegs) [elementPath moveToPoint:NSZeroPoint] ;
            [elementPath appendBezierPathWithArcWithCenter:NSZeroPoint
                                                    radius:r
                                                startAngle:startAngle
                                                  endAngle:endAngle
                                                 clockwise:!arcDir // because our canvas is flipped, we have to reverse this
            ] ;
            if (arcLegs) [elementPath lineToPoint:NSZeroPoint] ;
            elementPath = [finalTransform transformBezierPath:elementPath] ;
        } else
        if ([elementType isEqualToString:@"image"]) {
            if (![action isEqualTo:@"skip"]) {
// to support drawing image attributes, we'd need to use subviews and some way to link view to element dictionary, since subviews is an array... gonna need thought if desired... only really useful missing option is animates; others can be created by hand or by adjusting transform or frame
                NSImage      *theImage = [self getElementValueFor:@"image" atIndex:idx onlyIfSet:YES] ;
                if (theImage) [theImage drawInRect:frameRect] ;
                elementPath = nil ; // shouldn't be necessary, but lets be explicit
            }
        } else
        if ([elementType isEqualToString:@"text"]) {
            if (![action isEqualTo:@"skip"]) {
                id textEntry = [self getElementValueFor:@"text" atIndex:idx onlyIfSet:YES] ;
                if (!textEntry) {
                    textEntry = @"" ;
                } else if([textEntry isKindOfClass:[NSNumber class]]) {
                    textEntry = [(NSNumber *)textEntry stringValue] ;
                }

                if ([textEntry isKindOfClass:[NSString class]]) {
                    NSString *myFont = [self getElementValueFor:@"textFont" atIndex:idx onlyIfSet:NO] ;
                    NSNumber *mySize = [self getElementValueFor:@"textSize" atIndex:idx onlyIfSet:NO] ;
                    NSDictionary *attributes = @{
                        NSForegroundColorAttributeName : [self getElementValueFor:@"textColor" atIndex:idx onlyIfSet:NO],
                        NSFontAttributeName            : [NSFont fontWithName:myFont size:[mySize doubleValue]],
                    } ;
                    [(NSString *)textEntry drawInRect:frameRect withAttributes:attributes] ;
                } else {
                    [(NSAttributedString *)textEntry drawInRect:frameRect] ;
                }
                elementPath = nil ; // shouldn't be necessary, but lets be explicit
            }
        } else
        if ([elementType isEqualToString:@"oval"]) {
            elementPath = [NSBezierPath bezierPath];
            [elementPath appendBezierPathWithOvalInRect:frameRect] ;
        } else
        if ([elementType isEqualToString:@"rectangle"]) {
            elementPath = [NSBezierPath bezierPath];
            NSDictionary *roundedRect = [self getElementValueFor:@"roundedRectRadii" atIndex:idx] ;
            [elementPath appendBezierPathWithRoundedRect:frameRect
                                              xRadius:[roundedRect[@"xRadius"] doubleValue]
                                              yRadius:[roundedRect[@"yRadius"] doubleValue]] ;
        } else
//         if ([elementType isEqualToString:@"line"]) {
//         } else
//         if ([elementType isEqualToString:@"curve"]) {
//         } else
//         if ([elementType isEqualToString:@"point"]) {
//         } else
//         if ([elementType isEqualToString:@"segments"]) {
//         } else
        if ([elementType isEqualToString:@"resetClip"]) {
            if (![action isEqualTo:@"skip"]) {
                [gc restoreGraphicsState] ; // from beginning of enumeration
                wasClippingChanged = YES ;
                if (clippingModified) {
                    [gc restoreGraphicsState] ; // from clip action
                    clippingModified = NO ;
                } else {
                    [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - un-nested resetClip at index %lu", USERDATA_TAG, idx + 1]] ;
                }
                elementPath = nil ; // shouldn't be necessary, but lets be explicit
            }
        } else
        {
            [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - unrecognized type %@ at index %lu", USERDATA_TAG, elementType, idx + 1]] ;
        }

        if (elementPath) {
            NSNumber *miterLimit = [self getElementValueFor:@"miterLimit" atIndex:idx onlyIfSet:YES] ;
            if (miterLimit) elementPath.miterLimit = [miterLimit doubleValue] ;

            NSNumber *flatness = [self getElementValueFor:@"flatness" atIndex:idx onlyIfSet:YES] ;
            if (flatness) elementPath.flatness = [flatness doubleValue] ;

            if ([[self getElementValueFor:@"flattenPath" atIndex:idx] boolValue]) {
                elementPath = elementPath.bezierPathByFlatteningPath ;
            }
            if ([[self getElementValueFor:@"reversePath" atIndex:idx] boolValue]) {
                elementPath = elementPath.bezierPathByReversingPath ;
            }

            NSString *windingRule = [self getElementValueFor:@"windingRule" atIndex:idx onlyIfSet:YES] ;
            if (windingRule) elementPath.windingRule = [WINDING_RULES[windingRule] unsignedIntValue] ;

            if (renderPath) {
                [renderPath appendBezierPath:elementPath] ;
            } else {
                renderPath = elementPath ;
            }

            if ([action isEqualToString:@"clip"]) {
                [gc restoreGraphicsState] ; // from beginning of enumeration
                wasClippingChanged = YES ;
                if (!clippingModified) {
                    [gc saveGraphicsState] ;
                    clippingModified = YES ;
                }
                [renderPath addClip] ;
                renderPath = nil ;

            } else if ([action isEqualToString:@"fill"] || [action isEqualToString:@"stroke"] || [action isEqualToString:@"strokeAndFill"]) {
                if ([action isEqualToString:@"fill"] || [action isEqualToString:@"strokeAndFill"]) {
                    NSString     *fillGradient   = [self getElementValueFor:@"fillGradient" atIndex:idx] ;
                    if (![fillGradient isEqualToString:@"none"]) {
                        NSDictionary *gradientColors = [self getElementValueFor:@"fillGradientColors" atIndex:idx] ;
                        NSColor      *startColor     = gradientColors[@"startColor"] ;
                        NSColor      *endColor       = gradientColors[@"endColor"] ;
                        if ([fillGradient isEqualToString:@"linear"]) {
                            NSGradient* gradient = [[NSGradient alloc] initWithStartingColor:startColor endingColor:endColor];
                            [gradient drawInBezierPath:renderPath angle:[[self getElementValueFor:@"fillGradientAngle" atIndex:idx] doubleValue]] ;
                        } else if ([fillGradient isEqualToString:@"radial"]) {
                            NSGradient* gradient = [[NSGradient alloc] initWithStartingColor:startColor endingColor:endColor];
                            NSDictionary *centerPoint = [self getElementValueFor:@"fillGradientCenter" atIndex:idx] ;
                            [gradient drawInBezierPath:renderPath
                                relativeCenterPosition:NSMakePoint([centerPoint[@"x"] doubleValue], [centerPoint[@"y"] doubleValue])] ;
                        }
                    } else {
                        [renderPath fill] ;
                    }
                }

                if ([action isEqualToString:@"stroke"] || [action isEqualToString:@"strokeAndFill"]) {
                    NSNumber *strokeWidth = [self getElementValueFor:@"strokeWidth" atIndex:idx onlyIfSet:YES] ;
                    if (strokeWidth) renderPath.lineWidth  = [strokeWidth doubleValue] ;

                    NSString *lineJoinStyle = [self getElementValueFor:@"strokeJoinStyle" atIndex:idx onlyIfSet:YES] ;
                    if (lineJoinStyle) renderPath.lineJoinStyle = [STROKE_JOIN_STYLES[lineJoinStyle] unsignedIntValue] ;

                    NSString *lineCapStyle = [self getElementValueFor:@"strokeCapStyle" atIndex:idx onlyIfSet:YES] ;
                    if (lineCapStyle) renderPath.lineCapStyle = [STROKE_CAP_STYLES[lineCapStyle] unsignedIntValue] ;

                    NSArray *strokeDashes = [self getElementValueFor:@"strokeDashPattern" atIndex:idx onlyIfSet:YES] ;
                    if ([strokeDashes count] > 0) {
                        NSUInteger count = [strokeDashes count] ;
                        CGFloat    phase = [[self getElementValueFor:@"strokeDashPhase" atIndex:idx] doubleValue] ;
                        CGFloat *pattern ;
                        pattern = (CGFloat *)malloc(sizeof(CGFloat) * count) ;
                        if (pattern) {
                            for (NSUInteger i = 0 ; i < count ; i++) {
                                pattern[i] = [strokeDashes[i] doubleValue] ;
                            }
                            [renderPath setLineDash:pattern count:(NSInteger)count phase:phase];
                            free(pattern) ;
                        }
                    }

                    [renderPath stroke] ;
                }

                renderPath = nil ;
            } else if ([action isEqualToString:@"skip"]) {
                renderPath = nil ;
            } else if (![action isEqualToString:@"build"]) {
                [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - unrecognized action %@ at index %lu", USERDATA_TAG, action, idx + 1]] ;
            }
        }
        // to keep nesting correct, this was already done if we adjusted clipping this round
        if (!wasClippingChanged) [gc restoreGraphicsState] ;
    }] ;

    if (clippingModified) [gc restoreGraphicsState] ; // balance our saves

    [gc restoreGraphicsState];
    NSEnableScreenUpdates() ;
}

// To facilitate the way frames and points are specified, we get our tables from lua with the LS_NSRawTables option... this forces rect-tables and point-tables to be just that - tables, but also prevents color tables, styledtext tables, and transform tables from being converted... so we add fixes for them here...
// Plus we allow some "laziness" on the part of the programmer to leave out __luaSkinType when crafting the tables by hand, either to make things cleaner/easier or for historical reasons...

- (id)massageKeyValue:(id)oldValue forKey:(NSString *)keyName {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_State *L = [skin L] ;

    id newValue = oldValue ; // assume we're not changing anything
//     [LuaSkin logWarn:[NSString stringWithFormat:@"keyname %@ (%@) oldValue is %@", keyName, NSStringFromClass([oldValue class]), [oldValue debugDescription]]] ;

    // fix "...Color" tables
    if ([keyName hasSuffix:@"Color"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        lua_pushstring(L, "NSColor") ;
        lua_setfield(L, -2, "__luaSkinType") ;
        newValue = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

    // fix NSAffineTransform table
    } else if ([keyName isEqualToString:@"transformation"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        lua_pushstring(L, "NSAffineTransform") ;
        lua_setfield(L, -2, "__luaSkinType") ;
        newValue = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

    // fix NSShadow table
    } else if ([keyName isEqualToString:@"shadow"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        lua_pushstring(L, "NSShadow") ;
        lua_setfield(L, -2, "__luaSkinType") ;
        newValue = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

    // fix hs.styledText as Table
    } else if ([keyName isEqualToString:@"text"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        lua_pushstring(L, "NSAttributedString") ;
        lua_setfield(L, -2, "__luaSkinType") ;
        newValue = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

    // recurse into fields which have subfields to check those as well -- this should be done last in case the dictionary can be coerced into an object, like the color tables handled above
    } else if ([oldValue isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *blockValue = [[NSMutableDictionary alloc] init] ;
        [oldValue enumerateKeysAndObjectsUsingBlock:^(id blockKeyName, id valueForKey, __unused BOOL *stop) {
            [blockValue setObject:[self massageKeyValue:valueForKey forKey:blockKeyName] forKey:blockKeyName] ;
        }] ;
        newValue = blockValue ;
    }
//     [LuaSkin logWarn:[NSString stringWithFormat:@"newValue is %@", [newValue debugDescription]]] ;

    return newValue ;
}

- (id)getDefaultValueFor:(NSString *)keyName onlyIfSet:(BOOL)onlyIfSet {
    NSDictionary *attributeDefinition = languageDictionary[keyName] ;
    id result ;
    if (!attributeDefinition[@"default"]) {
        return nil ;
    } else if (_canvasDefaults[keyName]) {
        result = _canvasDefaults[keyName] ;
    } else if (!onlyIfSet) {
        result = attributeDefinition[@"default"] ;
    } else {
        result = nil ;
    }

    if ([[result class] conformsToProtocol:@protocol(NSMutableCopying)]) {
        result = [result mutableCopy] ;
    } else if ([[result class] conformsToProtocol:@protocol(NSCopying)]) {
        result = [result copy] ;
    }
    return result ;
}

- (attributeValidity)setDefaultFor:(NSString *)keyName to:(id)keyValue {
    attributeValidity validityStatus       = attributeInvalid ;
    if ([languageDictionary[keyName][@"nullable"] boolValue]) {
        keyValue = [self massageKeyValue:keyValue forKey:keyName] ;
        validityStatus = isValueValidForAttribute(keyName, keyValue) ;
        switch (validityStatus) {
            case attributeValid:
                _canvasDefaults[keyName] = keyValue ;
                break ;
            case attributeNulling:
                [_canvasDefaults removeObjectForKey:keyName] ;
                break ;
            case attributeInvalid:
                break ;
            default:
                [LuaSkin logWarn:@"unexpected validity status returned; notify developers"] ;
                break ;
        }
    }
    self.needsDisplay = true ;
    return validityStatus ;
}

- (id)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index {
    return [self getElementValueFor:keyName atIndex:index resolvePercentages:NO onlyIfSet:NO] ;
}

- (id)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index onlyIfSet:(BOOL)onlyIfSet {
    return [self getElementValueFor:keyName atIndex:index resolvePercentages:NO onlyIfSet:onlyIfSet] ;
}

- (id)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index resolvePercentages:(BOOL)resolvePercentages {
    return [self getElementValueFor:keyName atIndex:index resolvePercentages:resolvePercentages onlyIfSet:NO] ;
}

- (id)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index resolvePercentages:(BOOL)resolvePercentages onlyIfSet:(BOOL)onlyIfSet {
    if (index > [_elementList count]) return nil ;
    NSDictionary *elementAttributes = _elementList[index] ;
    id foundObject = elementAttributes[keyName] ? elementAttributes[keyName] : (onlyIfSet ? nil : [self getDefaultValueFor:keyName onlyIfSet:NO]) ;
    if ([[foundObject class] conformsToProtocol:@protocol(NSMutableCopying)]) {
        foundObject = [foundObject mutableCopy] ;
    } else if ([[foundObject class] conformsToProtocol:@protocol(NSCopying)]) {
        foundObject = [foundObject copy] ;
    }

    if (foundObject && resolvePercentages) {
        CGFloat padding = [[self getElementValueFor:@"padding" atIndex:index] doubleValue] ;
        CGFloat paddedWidth = self.frame.size.width - padding * 2 ;
        CGFloat paddedHeight = self.frame.size.height - padding * 2 ;

        if ([keyName isEqualToString:@"radius"]) {
            if ([foundObject isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber(foundObject) ;
                foundObject = [NSNumber numberWithDouble:([percentage doubleValue] * paddedWidth)] ;
            }
        } else if ([keyName isEqualToString:@"center"] || [keyName isEqualToString:@"end"] || [keyName isEqualToString:@"start"]) {
            if ([foundObject[@"x"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber(foundObject[@"x"]) ;
                foundObject[@"x"] = [NSNumber numberWithDouble:(padding + [percentage doubleValue] * paddedWidth)] ;
            }
            if ([foundObject[@"y"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber(foundObject[@"y"]) ;
                foundObject[@"y"] = [NSNumber numberWithDouble:(padding + [percentage doubleValue] * paddedHeight)] ;
            }
        } else if ([keyName isEqualToString:@"frame"]) {
            if ([foundObject[@"x"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber(foundObject[@"x"]) ;
                foundObject[@"x"] = [NSNumber numberWithDouble:(padding + [percentage doubleValue] * paddedWidth)] ;
            }
            if ([foundObject[@"y"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber(foundObject[@"y"]) ;
                foundObject[@"y"] = [NSNumber numberWithDouble:(padding + [percentage doubleValue] * paddedHeight)] ;
            }
            if ([foundObject[@"w"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber(foundObject[@"w"]) ;
                foundObject[@"w"] = [NSNumber numberWithDouble:([percentage doubleValue] * paddedWidth)] ;
            }
            if ([foundObject[@"h"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber(foundObject[@"h"]) ;
                foundObject[@"h"] = [NSNumber numberWithDouble:([percentage doubleValue] * paddedHeight)] ;
            }
        }
    }

    return foundObject ;
}

- (attributeValidity)setElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index to:(id)keyValue {
    if (index > [_elementList count]) return attributeInvalid ;
    keyValue = [self massageKeyValue:keyValue forKey:keyName] ;
    attributeValidity validityStatus = isValueValidForAttribute(keyName, keyValue) ;

    switch (validityStatus) {
        case attributeValid: {
            if ([keyName isEqualToString:@"radius"]) {
                if ([keyValue isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for %@", USERDATA_TAG, keyName]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            } else if ([keyName isEqualToString:@"center"] || [keyName isEqualToString:@"end"] || [keyName isEqualToString:@"start"]) {
                if ([keyValue[@"x"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"x"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field x of %@", USERDATA_TAG, keyName]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"y"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"y"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field y of %@", USERDATA_TAG, keyName]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            } else if ([keyName isEqualToString:@"frame"]) {
                if ([keyValue[@"x"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"x"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field x of %@", USERDATA_TAG, keyName]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"y"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"y"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field y of %@", USERDATA_TAG, keyName]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"w"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"w"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field w of %@", USERDATA_TAG, keyName]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"h"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"h"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field h of %@", USERDATA_TAG, keyName]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            }
            _elementList[index][keyName] = keyValue ;
            if ([keyName isEqualToString:@"type"]) {
                // add defaults, if not already present, for type (recurse into this method as needed)
                NSSet *defaultsForType = [languageDictionary keysOfEntriesPassingTest:^BOOL(NSString *typeName, NSDictionary *typeDefinition, __unused BOOL *stop){
                    return ![typeName isEqualToString:@"type"] && typeDefinition[@"requiredFor"] && [typeDefinition[@"requiredFor"] containsObject:keyValue] ;
                }] ;
                for (NSString *additionalKey in defaultsForType) {
                    if (!_elementList[index][additionalKey]) {
                        [self setElementValueFor:additionalKey atIndex:index to:[self getDefaultValueFor:additionalKey onlyIfSet:NO]] ;
                    }
                }
            }
        }   break ;
        case attributeNulling:
            [(NSMutableDictionary *)_elementList[index] removeObjectForKey:keyName] ;
            break ;
        case attributeInvalid:
            break ;
        default:
            [LuaSkin logWarn:@"unexpected validity status returned; notify developers"] ;
            break ;
    }
    self.needsDisplay = true ;
    return validityStatus ;
}

@end

#pragma mark - Module Functions

/// hs._asm.canvas.new(rect) -> canvasObject
/// Constructor
/// Create a new canvas object at the specified coordinates
///
/// Parameters:
///  * `rect` - A rect-table containing the co-ordinates and size for the canvas object
///
/// Returns:
///  * a new, empty, canvas object, or nil if the canvas cannot be created with the specified coordinates
///
/// Notes:
///  * The size of the canvas defines the visible area of the canvas -- any portion of a canvas element which extends past the canvas's edges will be clipped.
///  * a rect-table is a table with key-value pairs specifying the top-left coordinate on the screen for the canvas (keys `x  and `y`) and the size (keys `h` and `w`) of the canvas. The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
static int canvas_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [[ASMCanvasWindow alloc] initWithContentRect:[skin tableToRectAtIndex:1]
                                                                       styleMask:NSBorderlessWindowMask
                                                                         backing:NSBackingStoreBuffered
                                                                           defer:YES] ;
    if (canvasWindow) {
        canvasWindow.contentView = [[ASMCanvasView alloc] initWithFrame:canvasWindow.contentView.bounds];
        [skin pushNSObject:canvasWindow] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int dumpLanguageDictionary(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:languageDictionary withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

#pragma mark - Module Methods

static int canvas_canvasTransformation(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    ASMCanvasView   *canvasView   = (ASMCanvasView *)canvasWindow.contentView ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:canvasView.canvasTransform] ;
    } else {
        NSAffineTransform *transform = [NSAffineTransform transform] ;
        if (lua_type(L, 2) == LUA_TTABLE) transform = [skin luaObjectAtIndex:2 toClass:"NSAffineTransform"] ;
        canvasView.canvasTransform = transform ;
        canvasView.needsDisplay = true ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.canvas:show([fadeInTime]) -> canvasObject
/// Method
/// Displays the canvas object
///
/// Parameters:
///  * `fadeInTime` - An optional number of seconds over which to fade in the canvas object. Defaults to zero.
///
/// Returns:
///  * The canvas object
static int canvas_show(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;

    if (lua_gettop(L) == 1) {
        [canvasWindow makeKeyAndOrderFront:nil];
    } else {
        [canvasWindow fadeIn:lua_tonumber(L, 2)];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.canvas:hide([fadeOutTime]) -> canvasObject
/// Method
/// Hides the canvas object
///
/// Parameters:
///  * `fadeOutTime` - An optional number of seconds over which to fade out the canvas object. Defaults to zero.
///
/// Returns:
///  * The canvas object
static int canvas_hide(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;

    if (lua_gettop(L) == 1) {
        [canvasWindow orderOut:nil];
    } else {
        [canvasWindow fadeOut:lua_tonumber(L, 2) andDelete:NO];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.canvas:clickCallback(mouseUpFn, mouseDownFn) -> canvasObject
/// Method
/// Sets a callback for mouseUp and mouseDown click events
///
/// Parameters:
///  * `mouseUpFn`   - A function, can be nil, that will be called when the canvas object is clicked on and the mouse button is released. If this argument is nil, any existing callback is removed.
///  * `mouseDownFn` - A function, can be nil, that will be called when the canvas object is clicked on and the mouse button is first pressed down. If this argument is nil, any existing callback is removed.
///
/// Returns:
///  * The canvas object
///
/// Notes:
///  * the `mouseUpFn` and `mouseDownFn` functions may accept one argument (the canvasObject that received the mouse click) and should return nothing.
///
///  * No distinction is made between the left, right, or other mouse buttons -- they all invoke the same up or down function. If you need to determine which specific button was pressed, use `hs.eventtap.checkMouseButtons()` within your callback to check.
static int canvas_clickCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL,
                    LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    ASMCanvasView   *canvasView   = (ASMCanvasView *)canvasWindow.contentView ;

    // We're either removing callback(s), or setting new one(s). Either way, remove existing.
    canvasView.clickUpRef   = [skin luaUnref:refTable ref:canvasView.clickUpRef];
    canvasView.clickDownRef = [skin luaUnref:refTable ref:canvasView.clickDownRef];
    canvasWindow.ignoresMouseEvents = YES ;

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        canvasView.clickUpRef = [skin luaRef:refTable] ;
        canvasWindow.ignoresMouseEvents = NO ;
    }

    if (lua_type(L, 3) == LUA_TFUNCTION) {
        lua_pushvalue(L, 3);
        canvasView.clickDownRef = [skin luaRef:refTable] ;
        canvasWindow.ignoresMouseEvents = NO ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.canvas:clickActivating([flag]) -> canvasObject | currentValue
/// Method
/// Get or set whether or not clicking on a canvas with a click callback defined should bring all of Hammerspoon's open windows to the front.
///
/// Parameters:
///  * `flag` - an optional boolean indicating whether or not clicking on a canvas with a click callback function defined should activate Hammerspoon and bring its windows forward. Defaults to true.
///
/// Returns:
///  * If an argument is provided, returns the canvas object; otherwise returns the current setting.
///
/// Notes:
///  * Setting this to false changes a canvas object's AXsubrole value and may affect the results of filters used with `hs.window.filter`, depending upon how they are defined.
static int canvas_clickActivating(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;

    if (lua_type(L, 2) != LUA_TNONE) {
        if (lua_toboolean(L, 2)) {
            canvasWindow.styleMask &= (unsigned long)~NSNonactivatingPanelMask ;
        } else {
            canvasWindow.styleMask |= NSNonactivatingPanelMask ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, ((canvasWindow.styleMask & NSNonactivatingPanelMask) != NSNonactivatingPanelMask)) ;
    }

    return 1;
}

/// hs._asm.canvas:topLeft([point]) -> canvasObject | currentValue
/// Method
/// Get or set the top-left coordinate of the canvas object
///
/// Parameters:
///  * `point` - An optional point-table specifying the new coordinate the top-left of the canvas object should be moved to
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
///
/// Notes:
///  * a point-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the canvas (keys `x  and `y`). The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
static int canvas_topLeft(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    NSRect oldFrame = RectWithFlippedYCoordinate(canvasWindow.frame);

    if (lua_gettop(L) == 1) {
        [skin pushNSPoint:oldFrame.origin] ;
    } else {
        NSPoint newCoord = [skin tableToPointAtIndex:2] ;
        NSRect  newFrame = RectWithFlippedYCoordinate(NSMakeRect(newCoord.x, newCoord.y, oldFrame.size.width, oldFrame.size.height)) ;
        [canvasWindow setFrame:newFrame display:YES animate:NO];
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs._asm.canvas:size([size]) -> canvasObject | currentValue
/// Method
/// Get or set the size of a canvas object
///
/// Parameters:
///  * `size` - An optional size-table specifying the width and height the canvas object should be resized to
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
///
/// Notes:
///  * a size-table is a table with key-value pairs specifying the size (keys `h` and `w`) the canvas should be resized to. The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
///
///  * elements in the canvas that do not have the `absolutePosition` attribute set will be moved so that their relative position within the canvas remains the same with respect to the new size.
///  * elements in the canvas that do not have the `absoluteSize` attribute set will be resized so that their size relative to the canvas remains the same with respect to the new size.
static int canvas_size(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    ASMCanvasView   *canvasView   = (ASMCanvasView *)canvasWindow.contentView ;

    NSRect oldFrame = canvasWindow.frame;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:oldFrame.size] ;
    } else {
        NSSize newSize  = [skin tableToSizeAtIndex:2] ;
        NSRect newFrame = NSMakeRect(oldFrame.origin.x, oldFrame.origin.y + oldFrame.size.height - newSize.height, newSize.width, newSize.height);

        CGFloat xFactor = newFrame.size.width / oldFrame.size.width ;
        CGFloat yFactor = newFrame.size.height / oldFrame.size.height ;

        for (NSUInteger i = 0 ; i < [canvasView.elementList count] ; i++) {
            NSNumber *absPos = [canvasView getElementValueFor:@"absolutePosition" atIndex:i] ;
            NSNumber *absSiz = [canvasView getElementValueFor:@"absoluteSize" atIndex:i] ;
            if (absPos && absSiz) {
                BOOL absolutePosition = absPos ? [absPos boolValue] : YES ;
                BOOL absoluteSize     = absSiz ? [absSiz boolValue] : YES ;
                NSMutableDictionary *attributeDefinition = canvasView.elementList[i] ;
                if (!absolutePosition) {
                    [attributeDefinition enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, id keyValue, __unused BOOL *stop) {
                        if ([(@[ @"center", @"end", @"frame", @"start"]) containsObject:keyName]) {
                            if ([keyValue[@"x"] isKindOfClass:[NSNumber class]]) {
                                keyValue[@"x"] = [NSNumber numberWithDouble:([keyValue[@"x"] doubleValue] * xFactor)] ;
                            }
                            if ([keyValue[@"y"] isKindOfClass:[NSNumber class]]) {
                                keyValue[@"y"] = [NSNumber numberWithDouble:([keyValue[@"y"] doubleValue] * yFactor)] ;
                            }
                        }
                    }] ;
                }
                if (!absoluteSize) {
                    [attributeDefinition enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, id keyValue, __unused BOOL *stop) {
                        if ([keyName isEqualToString:@"frame"]) {
                            if ([keyValue[@"h"] isKindOfClass:[NSNumber class]]) {
                                keyValue[@"h"] = [NSNumber numberWithDouble:([keyValue[@"h"] doubleValue] * yFactor)] ;
                            }
                            if ([keyValue[@"w"] isKindOfClass:[NSNumber class]]) {
                                keyValue[@"w"] = [NSNumber numberWithDouble:([keyValue[@"w"] doubleValue] * xFactor)] ;
                            }
                        } else if ([keyName isEqualToString:@"radius"]) {
                            if ([keyValue isKindOfClass:[NSNumber class]]) {
                                attributeDefinition[keyName] = [NSNumber numberWithDouble:([keyValue doubleValue] * xFactor)] ;
                            }
                        }
                    }] ;
                }
            } else {
                [skin logError:[NSString stringWithFormat:@"%s:unable to get absolute positioning info for index position %lu", USERDATA_TAG, i + 1]] ;
            }
        }
        [canvasWindow setFrame:newFrame display:YES animate:NO];
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs._asm.canvas:alpha([alpha]) -> canvasObject | currentValue
/// Method
/// Get or set the alpha level of the window containing the canvasObject.
///
/// Parameters:
///  * `alpha` - an optional number specifying the new alpha level (0.0 - 1.0, inclusive) for the canvasObject
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
static int canvas_alpha(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, canvasWindow.alphaValue) ;
    } else {
        CGFloat newLevel = luaL_checknumber(L, 2);
        canvasWindow.alphaValue = ((newLevel < 0.0) ? 0.0 : ((newLevel > 1.0) ? 1.0 : newLevel)) ;
        lua_pushvalue(L, 1);
    }

    return 1 ;
}

/// hs._asm.canvas:orderAbove([canvas2]) -> canvasObject
/// Method
/// Moves canvas object above canvas2, or all canvas objects in the same presentation level, if canvas2 is not given.
///
/// Parameters:
///  * `canvas2` -An optional canvas object to place the canvas object above.
///
/// Returns:
///  * The canvas object
///
/// Notes:
///  * If the canvas object and canvas2 are not at the same presentation level, this method will will move the canvas object as close to the desired relationship without changing the canvas object's presentation level. See [hs._asm.canvas.level](#level).
static int canvas_orderAbove(lua_State *L) {
    return canvas_orderHelper(L, NSWindowAbove) ;
}

/// hs._asm.canvas:orderBelow([canvas2]) -> canvasObject
/// Method
/// Moves canvas object below canvas2, or all canvas objects in the same presentation level, if canvas2 is not given.
///
/// Parameters:
///  * `canvas2` -An optional canvas object to place the canvas object below.
///
/// Returns:
///  * The canvas object
///
/// Notes:
///  * If the canvas object and canvas2 are not at the same presentation level, this method will will move the canvas object as close to the desired relationship without changing the canvas object's presentation level. See [hs._asm.canvas.level](#level).
static int canvas_orderBelow(lua_State *L) {
    return canvas_orderHelper(L, NSWindowBelow) ;
}

/// hs._asm.canvas:level([level]) -> canvasObject | currentValue
/// Method
/// Sets the window level more precisely than sendToBack and bringToFront.
///
/// Parameters:
///  * `level` - an optional level, specified as a number or as a string, specifying the new window level for the canvasObject. If it is a string, it must match one of the keys in `hs.drawing.windowLevels`.
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
///
/// Notes:
///  * see the notes for `hs.drawing.windowLevels`
static int canvas_level(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TSTRING | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, [canvasWindow level]) ;
    } else {
        lua_Integer targetLevel ;
        if (lua_type(L, 2) == LUA_TNUMBER) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TNUMBER | LS_TINTEGER,
                            LS_TBREAK] ;
            targetLevel = lua_tointeger(L, 2) ;
        } else {
            if ([skin requireModule:"hs.drawing"]) {
                if (lua_getfield(L, -1, "windowLevels") == LUA_TTABLE) {
                    if (lua_getfield(L, -1, [[skin toNSObjectAtIndex:2] UTF8String]) == LUA_TNUMBER) {
                        targetLevel = lua_tointeger(L, -1) ;
                        lua_pop(L, 3) ; // value, windowLevels and hs.drawing
                    } else {
                        lua_pop(L, 3) ; // wrong value, windowLevels and hs.drawing
                        return luaL_error(L, [[NSString stringWithFormat:@"unrecognized window level: %@", [skin toNSObjectAtIndex:2]] UTF8String]) ;
                    }
                } else {
                    NSString *errorString = [NSString stringWithFormat:@"hs.drawing.windowLevels - table expected, found %s", lua_typename(L, (lua_type(L, -1)))] ;
                    lua_pop(L, 2) ; // windowLevels and hs.drawing
                    return luaL_error(L, [errorString UTF8String]) ;
                }
            } else {
                NSString *errorString = [NSString stringWithFormat:@"unable to load hs.drawing module to access windowLevels table:%s", lua_tostring(L, -1)] ;
                lua_pop(L, 1) ;
                return luaL_error(L, [errorString UTF8String]) ;
            }
        }

        targetLevel = (targetLevel < CGWindowLevelForKey(kCGMinimumWindowLevelKey)) ? CGWindowLevelForKey(kCGMinimumWindowLevelKey) : ((targetLevel > CGWindowLevelForKey(kCGMaximumWindowLevelKey)) ? CGWindowLevelForKey(kCGMaximumWindowLevelKey) : targetLevel) ;
        [canvasWindow setLevel:targetLevel] ;
        lua_pushvalue(L, 1) ;
    }

    return 1 ;
}

/// hs._asm.canvas:wantsLayer([flag]) -> canvasObject | currentValue
/// Method
/// Get or set whether or not the canvas object should be rendered by the view or by Core Animation.
///
/// Parameters:
///  * `flag` - optional boolean (default false) which indicates whether the canvas object should be rendered by the containing view (false) or by Core Animation (true).
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
///
/// Notes:
///  * This method can help smooth the display of small text objects on non-Retina monitors.
static int canvas_wantsLayer(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    ASMCanvasView   *canvasView   = (ASMCanvasView *)canvasWindow.contentView ;

    if (lua_type(L, 2) != LUA_TNONE) {
        [canvasView setWantsLayer:(BOOL)lua_toboolean(L, 2)];
        canvasView.needsDisplay = true ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, (BOOL)[canvasView wantsLayer]) ;
    }

    return 1;
}

/// hs._asm.canvas:behavior([behavior]) -> canvasObject | currentValue
/// Method
/// Get or set the window behavior settings for the canvas object.
///
/// Parameters:
///  * `behavior` - an optional number representing the desired window behaviors for the canvas object.
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
///
/// Notes:
///  * Window behaviors determine how the canvas object is handled by Spaces and Exposé. See `hs.drawing.windowBehaviors` for more information.
static int canvas_behavior(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, [canvasWindow collectionBehavior]) ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                        LS_TNUMBER | LS_TINTEGER,
                        LS_TBREAK] ;

        NSInteger newLevel = lua_tointeger(L, 2);
        @try {
            [canvasWindow setCollectionBehavior:(NSWindowCollectionBehavior)newLevel] ;
        }
        @catch ( NSException *theException ) {
            return luaL_error(L, "%s: %s", [[theException name] UTF8String], [[theException reason] UTF8String]) ;
        }

        lua_pushvalue(L, 1);
    }

    return 1 ;
}

/// hs._asm.canvas:delete([fadeOutTime]) -> none
/// Method
/// Destroys the canvas object, optionally fading it out first (if currently visible).
///
/// Parameters:
///  * `fadeOutTime` - An optional number of seconds over which to fade out the canvas object. Defaults to zero.
///
/// Returns:
///  * None
///
/// Notes:
///  * This method is automatically called during garbage collection, notably during a Hammerspoon termination or reload, with a fade time of 0.
static int canvas_delete(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    if ((lua_gettop(L) == 1) || (![canvasWindow isVisible])) {
        lua_pushcfunction(L, userdata_gc) ;
        lua_pushvalue(L, 1) ;
        if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
            [skin logBreadcrumb:[NSString stringWithFormat:@"%s:error invoking _gc for delete method:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
            lua_pop(L, 1) ;
            [canvasWindow close] ; // the least we can do is close the canvas if an error occurs with __gc
        }
    } else {
        [canvasWindow fadeOut:lua_tonumber(L, 2) andDelete:YES];
    }

    lua_pushnil(L);
    return 1;
}

/// hs._asm.canvas:isShowing() -> boolean
/// Method
/// Returns whether or not the canvas is currently being shown.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean indicating whether or not the canvas is currently being shown (true) or is currently hidden (false).
///
/// Notes:
///  * This method only determines whether or not the canvas is being shown or is hidden -- it does not indicate whether or not the canvas is currently off screen or is occluded by other objects.
///  * See also [hs._asm.canvas:isOccluded](#isOccluded).
static int canvas_isShowing(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    lua_pushboolean(L, [canvasWindow isVisible]) ;
    return 1 ;
}

/// hs._asm.canvas:isOccluded() -> boolean
/// Method
/// Returns whether or not the canvas is currently occluded (hidden by other windows, off screen, etc).
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean indicating whether or not the canvas is currently being occluded.
///
/// Notes:
///  * If any part of the canvas is visible (even if that portion of the canvas does not contain any canvas elements), then the canvas is not considered occluded.
///  * a canvas which is completely covered by one or more opaque windows is considered occluded; however, if the windows covering the canvas are not opaque, then the canvas is not occluded.
///  * a canvas that is currently hidden or with a height of 0 or a width of 0 is considered occluded.
///  * See also [hs._asm.canvas:isShowing](#isShowing).
static int canvas_isOccluded(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    lua_pushboolean(L, ([canvasWindow occlusionState] & NSWindowOcclusionStateVisible) != NSWindowOcclusionStateVisible) ;
    return 1 ;
}

/// hs._asm.canvas:canvasDefaultFor(keyName, [newValue]) -> canvasObject | currentValue
/// Method
/// Get or set the element default specified by keyName.
///
/// Paramters:
///  * `keyName` - the element default to examine or modify
///  * `value`   - an optional new value to set as the default fot his canvas when not specified explicitly in an element declaration.
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
///
/// Notes:
///  * Not all keys will apply to all element types.
///  * Any key listed may be set in an element declaration to specify an alternate value when that element is rendered.
///  * To get a table containing all of the current defaults, use [hs._asm.canvas:canvasDefaults](#canvasDefaults).
static int canvas_canvasDefaultFor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    ASMCanvasView   *canvasView   = (ASMCanvasView *)canvasWindow.contentView ;
    NSString *keyName = [skin toNSObjectAtIndex:2] ;

    if (!languageDictionary[keyName]) {
        return luaL_argerror(L, 2, "unrecognized attribute name") ;
    }

    id attributeDefault = [canvasView getDefaultValueFor:keyName onlyIfSet:NO] ;
    if (!attributeDefault) {
        return luaL_argerror(L, 2, "attribute has no default value") ;
    }

    if (lua_gettop(L) == 2) {
        [skin pushNSObject:attributeDefault] ;
    } else {
        id keyValue = [skin toNSObjectAtIndex:3 withOptions:LS_NSRawTables] ;

        switch([canvasView setDefaultFor:keyName to:keyValue]) {
            case attributeValid:
            case attributeNulling:
                break ;
            case attributeInvalid:
            default:
                if ([languageDictionary[keyName][@"nullable"] boolValue]) {
                    return luaL_argerror(L, 3, "invalid argument type specified") ;
                } else {
                    return luaL_argerror(L, 2, "attribute default cannot be changed") ;
                }
//                 break ;
        }

        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int canvas_insertElementAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    ASMCanvasView   *canvasView   = (ASMCanvasView *)canvasWindow.contentView ;
    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = (lua_gettop(L) == 3) ? (lua_tointeger(L, 3) - 1) : (NSInteger)elementCount ;

    if (tablePosition < 0 || tablePosition > (NSInteger)elementCount) {
        return luaL_argerror(L, 3, "index out of bounds") ;
    }

    NSDictionary *element = [skin toNSObjectAtIndex:2 withOptions:LS_NSRawTables] ;
    if ([element isKindOfClass:[NSDictionary class]]) {
        NSString *elementType = element[@"type"] ;
        if (elementType && [ALL_TYPES containsObject:elementType]) {
            [canvasView.elementList insertObject:[[NSMutableDictionary alloc] init] atIndex:(NSUInteger)tablePosition] ;
            [element enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, id keyValue, __unused BOOL *stop) {
                // skip type in here to minimize the need to copy in defaults just to be overwritten
                if (![keyName isEqualTo:@"type"]) [canvasView setElementValueFor:keyName atIndex:(NSUInteger)tablePosition to:keyValue] ;
            }] ;
            [canvasView setElementValueFor:@"type" atIndex:(NSUInteger)tablePosition to:elementType] ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalid element; type required and must be one of %@", [ALL_TYPES componentsJoinedByString:@", "]] UTF8String]) ;
        }
    } else {
        return luaL_argerror(L, 2, "invalid element definition; must contain key-value pairs");
    }

    canvasView.needsDisplay = true ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int canvas_removeElementAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    ASMCanvasView   *canvasView   = (ASMCanvasView *)canvasWindow.contentView ;
    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = (lua_gettop(L) == 2) ? (lua_tointeger(L, 2) - 1) : (NSInteger)elementCount - 1 ;

    if (tablePosition < 0 || tablePosition >= (NSInteger)elementCount) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    [canvasView.elementList removeObjectAtIndex:(NSUInteger)tablePosition] ;

    canvasView.needsDisplay = true ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int canvas_elementAttributeAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TSTRING,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TBREAK] ;
    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    ASMCanvasView   *canvasView   = (ASMCanvasView *)canvasWindow.contentView ;
    NSString        *keyName      = [skin toNSObjectAtIndex:3] ;

    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = lua_tointeger(L, 2) - 1 ;

    BOOL            resolvePercentages = NO ;

    if (tablePosition < 0 || tablePosition > (NSInteger)elementCount) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    if (!languageDictionary[keyName]) {
        if (lua_gettop(L) == 3) {
            // check if keyname ends with _raw, if so we get with converted numeric values
            if ([keyName hasSuffix:@"_raw"]) {
                keyName = [keyName substringWithRange:NSMakeRange(0, [keyName length] - 4)] ;
                if (languageDictionary[keyName]) resolvePercentages = YES ;
            }
            if (!resolvePercentages) {
                lua_pushnil(L) ;
                return 1 ;
            }
        } else {
            return luaL_argerror(L, 3, "unrecognized attribute name") ;
        }
    }

    if (lua_gettop(L) == 3) {
        [skin pushNSObject:[canvasView getElementValueFor:keyName atIndex:(NSUInteger)tablePosition resolvePercentages:resolvePercentages onlyIfSet:NO]] ;
    } else {
        id keyValue = [skin toNSObjectAtIndex:4 withOptions:LS_NSRawTables] ;
        switch([canvasView setElementValueFor:keyName atIndex:(NSUInteger)tablePosition to:keyValue]) {
            case attributeValid:
            case attributeNulling:
                lua_pushvalue(L, 1) ;
                break ;
            case attributeInvalid:
            default:
                return luaL_argerror(L, 4, "invalid argument type specified") ;
//                 break ;
        }
    }
    return 1 ;
}

static int canvas_elementKeysAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    ASMCanvasView   *canvasView   = (ASMCanvasView *)canvasWindow.contentView ;
    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = lua_tointeger(L, 2) - 1 ;

    if (tablePosition < 0 || tablePosition > (NSInteger)elementCount) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }
    NSUInteger indexPosition = (NSUInteger)tablePosition ;

    NSMutableSet *list = [[NSMutableSet alloc] initWithArray:[(NSDictionary *)canvasView.elementList[indexPosition] allKeys]] ;
    if ((lua_gettop(L) == 3) && lua_toboolean(L, 3)) {
        NSString *ourType = canvasView.elementList[indexPosition][@"type"] ;
        [languageDictionary enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, NSDictionary *keyValue, __unused BOOL *stop) {
            if (keyValue[@"optionalFor"] && [keyValue[@"optionalFor"] containsObject:ourType]) {
                [list addObject:keyName] ;
            }
        }] ;
    }
    [skin pushNSObject:list] ;
    return 1 ;
}

static int canvas_elementCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    ASMCanvasView   *canvasView   = (ASMCanvasView *)canvasWindow.contentView ;
    lua_pushinteger(L, (lua_Integer)[canvasView.elementList count]) ;
    return 1 ;
}

/// hs._asm.canvas:canvasDefaults() -> table
/// Method
/// Get a table of the default key-value pairs currently in effect for the canvas
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing all of the default values for elements that will be rendered in the canvas.
///
/// Notes:
///  * Not all keys will apply to all element types.
///  * Any key listed may be set in an element declaration to specify an alternate value when that element is rendered.
///  * To change the defaults for the canvas, use [hs._asm.canvas:canvasDefaultFor](#canvasDefaultFor).
static int canvas_canvasDefaults(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    ASMCanvasView   *canvasView   = (ASMCanvasView *)canvasWindow.contentView ;
    if ((lua_gettop(L) == 2) && lua_toboolean(L, 2)) {
        lua_newtable(L) ;
        for (NSString *keyName in languageDictionary) {
            id keyValue = [canvasView getDefaultValueFor:keyName onlyIfSet:NO] ;
            if (keyValue) {
                [skin pushNSObject:keyValue] ; lua_setfield(L, -2, [keyName UTF8String]) ;
            }
        }
    } else {
        [skin pushNSObject:canvasView.canvasDefaults withOptions:LS_NSDescribeUnknownTypes] ;
    }
    return 1 ;
}

static int canvas_canvasDefaultKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    ASMCanvasView   *canvasView   = (ASMCanvasView *)canvasWindow.contentView ;

    NSMutableSet *list = [[NSMutableSet alloc] initWithArray:[(NSDictionary *)canvasView.canvasDefaults allKeys]] ;
    if ((lua_gettop(L) == 3) && lua_toboolean(L, 3)) {
        [languageDictionary enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, NSDictionary *keyValue, __unused BOOL *stop) {
            if (keyValue[@"default"]) {
                [list addObject:keyName] ;
            }
        }] ;
    }
    [skin pushNSObject:list] ;
    return 1 ;
}

static int canvas_canvasElements(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK] ;
    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    ASMCanvasView   *canvasView   = (ASMCanvasView *)canvasWindow.contentView ;
    [skin pushNSObject:canvasView.elementList withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

static int canvas_assignElementAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TNIL,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    ASMCanvasView   *canvasView   = (ASMCanvasView *)canvasWindow.contentView ;

    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = (lua_gettop(L) == 3) ? (lua_tointeger(L, 3) - 1) : (NSInteger)elementCount ;

    if (tablePosition < 0 || tablePosition > (NSInteger)elementCount) {
        return luaL_argerror(L, 3, "index out of bounds") ;
    }

    if (lua_isnil(L, 2)) {
        if (tablePosition == (NSInteger)elementCount - 1) {
            [canvasView.elementList removeLastObject] ;
        } else {
            return luaL_argerror(L, 3, "nil only valid for final element") ;
        }
    } else {
        NSDictionary *element = [skin toNSObjectAtIndex:2 withOptions:LS_NSRawTables] ;
        if ([element isKindOfClass:[NSDictionary class]]) {
            NSString *elementType = element[@"type"] ;
            if (elementType && [ALL_TYPES containsObject:elementType]) {
                canvasView.elementList[tablePosition] = [[NSMutableDictionary alloc] init] ;
                [element enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, id keyValue, __unused BOOL *stop) {
                    // skip type in here to minimize the need to copy in defaults just to be overwritten
                    if (![keyName isEqualTo:@"type"]) [canvasView setElementValueFor:keyName atIndex:(NSUInteger)tablePosition to:keyValue] ;
                }] ;
                [canvasView setElementValueFor:@"type" atIndex:(NSUInteger)tablePosition to:elementType] ;
            } else {
                return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalid element; type required and must be one of %@", [ALL_TYPES componentsJoinedByString:@", "]] UTF8String]) ;
            }
        } else {
            return luaL_argerror(L, 2, "invalid element definition; must contain key-value pairs");
        }
    }

    canvasView.needsDisplay = true ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants

/// hs._asm.canvas.compositeTypes[]
/// Constant
/// A table containing the possible compositing rules for elements within the canvas.
///
/// Compositing rules specify how an element assigned to the canvas is combined with the earlier elements of the canvas. The default compositing rule for the canvas is `sourceOver`, but each element of the canvas can be assigned a composite type which overrides this default for the specific element.
///
/// The available types are as follows:
///  * `clear`           - Transparent. (R = 0)
///  * `copy`            - Source image. (R = S)
///  * `sourceOver`      - Source image wherever source image is opaque, and destination image elsewhere. (R = S + D*(1 - Sa))
///  * `sourceIn`        - Source image wherever both images are opaque, and transparent elsewhere. (R = S*Da)
///  * `sourceOut`       - Source image wherever source image is opaque but destination image is transparent, and transparent elsewhere. (R = S*(1 - Da))
///  * `sourceAtop`      - Source image wherever both images are opaque, destination image wherever destination image is opaque but source image is transparent, and transparent elsewhere. (R = S*Da + D*(1 - Sa))
///  * `destinationOver` - Destination image wherever destination image is opaque, and source image elsewhere. (R = S*(1 - Da) + D)
///  * `destinationIn`   - Destination image wherever both images are opaque, and transparent elsewhere. (R = D*Sa)
///  * `destinationOut`  - Destination image wherever destination image is opaque but source image is transparent, and transparent elsewhere. (R = D*(1 - Sa))
///  * `destinationAtop` - Destination image wherever both images are opaque, source image wherever source image is opaque but destination image is transparent, and transparent elsewhere. (R = S*(1 - Da) + D*Sa)
///  * `XOR`             - Exclusive OR of source and destination images. (R = S*(1 - Da) + D*(1 - Sa)). Works best with black and white images and is not recommended for color contexts.
///  * `plusDarker`      - Sum of source and destination images, with color values approaching 0 as a limit. (R = MAX(0, (1 - D) + (1 - S)))
///  * `plusLighter`     - Sum of source and destination images, with color values approaching 1 as a limit. (R = MIN(1, S + D))
///
/// In each equation, R is the resulting (premultiplied) color, S is the source color, D is the destination color, Sa is the alpha value of the source color, and Da is the alpha value of the destination color.
///
/// The `source` object is the individual element as it is rendered in order within the canvas, and the `destination` object is the combined state of the previous elements as they have been composited within the canvas.
static int pushCompositeTypes(lua_State *L) {
    lua_newtable(L) ;
      lua_pushstring(L, "clear") ;           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushstring(L, "copy") ;            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushstring(L, "sourceOver") ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushstring(L, "sourceIn") ;        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushstring(L, "sourceOut") ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushstring(L, "sourceAtop") ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushstring(L, "destinationOver") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushstring(L, "destinationIn") ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushstring(L, "destinationOut") ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushstring(L, "destinationAtop") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushstring(L, "XOR") ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushstring(L, "plusDarker") ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//       lua_pushstring(L, "highlight") ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; // mapped to NSCompositeSourceOver
      lua_pushstring(L, "plusLighter") ;     lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMCanvasWindow(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMCanvasWindow *value = obj;
    if (value.selfRef == LUA_NOREF) {
        void** valuePtr = lua_newuserdata(L, sizeof(ASMCanvasWindow *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
        value.selfRef = [skin luaRef:refTable] ;
    }
    [skin pushLuaRef:refTable ref:value.selfRef] ;
    return 1;
}

static id toASMCanvasWindowFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMCanvasWindow *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMCanvasWindow, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMCanvasWindow *obj = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    NSString *title = NSStringFromRect(RectWithFlippedYCoordinate(obj.frame)) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMCanvasWindow *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
        ASMCanvasWindow *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMCanvasWindow"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMCanvasWindow *obj = get_objectFromUserdata(__bridge_transfer ASMCanvasWindow, L, 1, USERDATA_TAG) ;
    if (obj) {
        if (obj.contentView) {
            ASMCanvasView *theView  = (ASMCanvasView *)obj.contentView ;

            theView.clickDownRef = [skin luaUnref:refTable ref:theView.clickDownRef] ;
            theView.clickUpRef   = [skin luaUnref:refTable ref:theView.clickUpRef] ;
        }
        [obj close];
        obj.selfRef = [skin luaUnref:refTable ref:obj.selfRef] ;
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

// // Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
// affects drawing elements
    {"assignElement",      canvas_assignElementAtIndex},
    {"canvasDefaults",     canvas_canvasDefaults},
    {"canvasDefaultKeys",  canvas_canvasDefaultKeys},
    {"canvasDefaultFor",   canvas_canvasDefaultFor},
    {"elementAttribute",   canvas_elementAttributeAtIndex},
    {"elementKeys",        canvas_elementKeysAtIndex},
    {"elementCount",       canvas_elementCount},
    {"canvasElements",     canvas_canvasElements},
    {"insertElement",      canvas_insertElementAtIndex},
    {"removeElement",      canvas_removeElementAtIndex},
// affects whole canvas
    {"alpha",              canvas_alpha},
    {"behavior",           canvas_behavior},
    {"clickActivating",    canvas_clickActivating},
    {"clickCallback",      canvas_clickCallback},
    {"delete",             canvas_delete},
    {"hide",               canvas_hide},
    {"isOccluded",         canvas_isOccluded},
    {"isShowing",          canvas_isShowing},
    {"level",              canvas_level},
    {"orderAbove",         canvas_orderAbove},
    {"orderBelow",         canvas_orderBelow},
    {"show",               canvas_show},
    {"size",               canvas_size},
    {"topLeft",            canvas_topLeft},
    {"transformation",     canvas_canvasTransformation},
    {"wantsLayer",         canvas_wantsLayer},

    {"__tostring",         userdata_tostring},
    {"__eq",               userdata_eq},
    {"__gc",               userdata_gc},
    {NULL,                 NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",         canvas_new},
    {"elementSpec", dumpLanguageDictionary},

    {NULL,          NULL}
};

int luaopen_hs__asm_canvas_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    languageDictionary = defineLanguageDictionary() ;

    [skin registerPushNSHelper:pushASMCanvasWindow         forClass:"ASMCanvasWindow"];
    [skin registerLuaObjectHelper:toASMCanvasWindowFromLua forClass:"ASMCanvasWindow"
                                                withUserdataMapping:USERDATA_TAG];

    pushCompositeTypes(L) ; lua_setfield(L, -2, "compositeTypes") ;

    return 1;
}
