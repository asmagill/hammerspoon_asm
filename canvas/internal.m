
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
@property             int                 selfRef ;
@property (nonatomic) NSMutableDictionary *canvasDefaults ;
@property (nonatomic) NSMutableArray      *elementList ;
@end

@interface ASMCanvasView : NSView
@property int clickDownRef;
@property int clickUpRef;
@end

typedef NS_ENUM(NSInteger, attributeValidity) {
    attributeValid,
    attributeNulling,
    attributeInvalid,
};

#pragma mark - Support Functions and Classes

#define ALL_TYPES @[ @"arc", @"circle", @"curve", @"ellipticalArc", @"image", @"line", @"oval", @"point", @"rectangle", @"resetClip", @"segments", @"text" ]

static NSDictionary *defineLanguageDictionary() {
    return @{
        @"type" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : ALL_TYPES,
            @"nullable"    : @(NO),
            @"requiredFor" : ALL_TYPES,
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
        @"absolutePosition" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : ALL_TYPES,
        },
        @"absoluteSize" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : ALL_TYPES,
        },
        @"addToClipRegion" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : ALL_TYPES,
        },
        @"inverseClip" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : ALL_TYPES,
        },
        @"compositeRule" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : @[
                                 @"clear",
                                 @"copy",
                                 @"sourceOver",
                                 @"sourceIn",
                                 @"sourceOut",
                                 @"sourceAtop",
                                 @"destinationOver",
                                 @"destinationIn",
                                 @"destinationOut",
                                 @"destinationAtop",
                                 @"XOR",
                                 @"plusDarker",
                                 @"plusLighter",
                             ],
            @"nullable"    : @(YES),
            @"default"     : @"copy",
            @"optionalFor" : ALL_TYPES,
        },
        @"id" : @{
            @"class"       : @[ [NSString class], [NSNumber class] ],
            @"luaClass"    : @"string or number",
            @"nullable"    : @(YES),
            @"optionalFor" : ALL_TYPES,
        },
        @"trackMouseDown" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : ALL_TYPES,
        },
        @"trackMouseUp" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : ALL_TYPES,
        },
        @"trackMouseEnter" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : ALL_TYPES,
        },
        @"trackMouseExit" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : ALL_TYPES,
        },
        @"trackMouseMove" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : ALL_TYPES,
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
        @"fill" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(YES),
            @"optionalFor" : @[ @"arc", @"circle", @"ellipticalArc", @"oval", @"rectangle", @"segments" ],
        },
        @"fillColor" : @{
            @"class"       : @[ [NSColor class] ],
            @"luaClass"    : @"hs.color table",
            @"nullable"    : @(YES),
            @"default"     : [NSColor redColor],
            @"optionalFor" : @[ @"arc", @"circle", @"ellipticalArc", @"oval", @"rectangle", @"segments" ],
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
            @"optionalFor" : @[ @"arc", @"circle", @"ellipticalArc", @"oval", @"rectangle", @"segments" ],
        },
        @"fillGradientColors" : @{
            @"class"       : @[ [NSDictionary class] ],
            @"luaClass"    : @"table",
            @"keys"        : @{
                @"startColor" : @{
                    @"class"    : @[ [NSColor class] ],
                    @"luaClass" : @"hs.color table",
                },
                @"endColor" : @{
                    @"class"    : @[ [NSColor class] ],
                    @"luaClass" : @"hs.color table",
                },
            },
            @"default"     : @{
                                 @"startColor" : [NSColor blackColor],
                                 @"endColor"   : [NSColor whiteColor],
                             },
            @"nullable"    : @(YES),
            @"optionalFor" : @[ @"arc", @"circle", @"ellipticalArc", @"oval", @"rectangle", @"segments" ],
        },
        @"fillGradientAngle"  : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"nullable"    : @(YES),
            @"default"     : @(0.0),
            @"optionalFor" : @[ @"arc", @"circle", @"ellipticalArc", @"oval", @"rectangle", @"segments" ],
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
            @"optionalFor"   : @[ @"arc", @"circle", @"ellipticalArc", @"oval", @"rectangle", @"segments" ],
        },
        @"flatness" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"nullable"    : @(YES),
            @"default"     : @([NSBezierPath defaultFlatness]),
            @"optionalFor" : ALL_TYPES,
        },
        @"flattenPath" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : ALL_TYPES,
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
                                   @"x" : @(0.0),
                                   @"y" : @(0.0),
                                   @"h" : @"100%",
                                   @"w" : @"100%",
                               },
            @"nullable"      : @(NO),
            @"requiredFor"   : @[ @"rectangle", @"oval", @"ellipticalArc", @"text", @"image" ],
        },
        @"image" : @{
            @"class"       : @[ [NSImage class] ],
            @"luaClass"    : @"hs.image object",
            @"nullable"    : @(YES),
            @"default"     : [[NSImage alloc] initWithSize:NSMakeSize(1.0, 1.0)],
            @"optionalFor" : @[ @"image" ],
        },
        @"imageAlignment" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : @[
                                   @"topLeft",
                                   @"top",
                                   @"topRight",
                                   @"left",
                                   @"center",
                                   @"right",
                                   @"bottomLeft",
                                   @"bottom",
                                   @"bottomRight",
                             ],
            @"nullable"    : @(YES),
            @"default"     : @"center",
            @"optionalFor" : @[ @"image" ],
        },
        @"imageAnimates" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(YES),
            @"optionalFor" : @[ @"image" ],
        },
        @"imageFrameStyle" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : @[
                                   @"none",
                                   @"photo",
                                   @"bezel",
                                   @"groove",
                                   @"button",
                             ],
            @"nullable"    : @(YES),
            @"default"     : @"none",
            @"optionalFor" : @[ @"image" ],
        },
        @"imageRotation" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"nullable"    : @(YES),
            @"default"     : @(0.0),
            @"optionalFor" : @[ @"image" ],
        },
        @"imageScaling" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : @[
                                   @"shrinkToFit",
                                   @"scaleToFir",
                                   @"none",
                                   @"scaleProportionally",
                             ],
            @"nullable"    : @(YES),
            @"default"     : @"scaleProportionally",
            @"optionalFor" : @[ @"image" ],
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
            @"optionalFor" : ALL_TYPES,
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
                                   @"x" : @(0.0),
                                   @"y" : @(0.0),
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
        @"stroke" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(YES),
            @"optionalFor" : @[ @"arc", @"circle", @"curve", @"ellipticalArc", @"line", @"oval", @"point", @"rectangle", @"segments" ],
        },
        @"strokeCapStyle" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : @[
                                   @"butt",
                                   @"round",
                                   @"square",
                             ],
            @"nullable"    : @(YES),
            @"default"     : @"butt",
            @"optionalFor" : @[ @"arc", @"circle", @"curve", @"ellipticalArc", @"line", @"oval", @"point", @"rectangle", @"segments" ],
        },
        @"strokeColor" : @{
            @"class"       : @[ [NSColor class] ],
            @"luaClass"    : @"hs.color table",
            @"nullable"    : @(YES),
            @"default"     : [NSColor blackColor],
            @"optionalFor" : @[ @"arc", @"circle", @"curve", @"ellipticalArc", @"line", @"oval", @"point", @"rectangle", @"segments" ],
        },
        @"strokeDashPattern" : @{
            @"class"          : @[ [NSArray class] ],
            @"luaClass"       : @"table",
            @"nullable"       : @(YES),
            @"default"        : @[ ],
            @"memberClass"    : [NSNumber class],
            @"memberLuaClass" : @"number",
            @"optionalFor"    : @[ @"arc", @"circle", @"curve", @"ellipticalArc", @"line", @"oval", @"point", @"rectangle", @"segments" ],
        },
        @"strokeDashPhase" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"default"     : @(0.0),
            @"nullable"    : @(YES),
            @"optionalFor" : @[ @"arc", @"circle", @"curve", @"ellipticalArc", @"line", @"oval", @"point", @"rectangle", @"segments" ],
        },
        @"strokeJoinStyle" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : @[
                                   @"miter",
                                   @"round",
                                   @"bevel",
                             ],
            @"nullable"    : @(YES),
            @"default"     : @"miter",
            @"optionalFor" : @[ @"arc", @"circle", @"curve", @"ellipticalArc", @"line", @"oval", @"point", @"rectangle", @"segments" ],
        },
        @"miterLimit" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"default"     : @([NSBezierPath defaultMiterLimit]),
            @"nullable"    : @(YES),
            @"optionalFor" : @[ @"arc", @"circle", @"curve", @"ellipticalArc", @"line", @"oval", @"point", @"rectangle", @"segments" ],
        },
        @"strokeWidth" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"default"     : @([NSBezierPath defaultLineWidth]),
            @"nullable"    : @(YES),
            @"optionalFor" : @[ @"arc", @"circle", @"curve", @"ellipticalArc", @"line", @"oval", @"point", @"rectangle", @"segments" ],
        },
        @"text" : @{
            @"class"       : @[ [NSString class], [NSAttributedString class] ],
            @"luaClass"    : @"string or styledText object",
            @"default"     : @"",
            @"nullable"    : @(NO),
            @"requiredFor" : @[ @"text" ],
        },
        @"textColor" : @{
            @"class"       : @[ [NSColor class] ],
            @"luaClass"    : @"hs.color table",
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
        @"textStyle" : @{
            @"class"         : @[ [NSDictionary class] ],
            @"luaClass"      : @"table",
            @"nullable"      : @(YES),
            @"keys"          : @{
                @"alignment" : @{
                    @"class"    : @[ [NSString class] ],
                    @"luaClass" : @"string",
                    @"values"   : @[ @"left", @"right", @"center", @"justified", @"natural" ],
                },
                @"lineBreak" : @{
                    @"class"    : @[ [NSString class] ],
                    @"luaClass" : @"string",
                    @"values"   : @[ @"wordWrap", @"charWrap", @"clip", @"truncateHead", @"truncateTail", @"truncateMiddle" ],
                },
            },
            @"default"       : @{
                                   @"alignment" : @"natural",
                                   @"lineBreak" : @"wordWrap",
                               },
            @"optionalFor"   : @[ @"text" ],
        },
        @"transformation" : @{
            @"class"       : @[ [NSAffineTransform class] ],
            @"luaClass"    : @"transform table",
            @"nullable"    : @(YES),
            @"default"     : [NSAffineTransform transform],
            @"optionalFor" : @[ @"arc", @"circle", @"curve", @"ellipticalArc", @"line", @"oval", @"point", @"rectangle", @"segments", @"text" ],
        },
        @"windingRule" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : @[
                                   @"nonZero",
                                   @"evenOdd",
                             ],
            @"nullable"    : @(YES),
            @"default"     : @"nonZero",
            @"optionalFor" : @[ @"arc", @"circle", @"curve", @"ellipticalArc", @"line", @"oval", @"point", @"rectangle", @"segments", @"text" ],
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
        [skin logError:[NSString stringWithFormat:@"%s:canvas with non-finite co-ordinates/size specified", USERDATA_TAG]];
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

        _canvasDefaults = [[NSMutableDictionary alloc] init] ;
        _elementList    = [[NSMutableArray alloc] init] ;
    }
    return self;
}

// To facilitate the way frames and points are specified, we get our tables from lua with the LS_NSRawTables option... this forces rect-tables and point-tables to be just that - tables, but also prevents color tables, styledtext tables, and transform tables from being converted... so we add fixes for them here...
// Plus we allow some "laziness" on the part of the programmer to leave out __luaSkinType when crafting the tables by hand, either to make things cleaner/easier or for historical reasons...

- (id)massageKeyValue:(id)oldValue forKey:(NSString *)keyName {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_State *L = [skin L] ;

    id newValue = oldValue ; // assume we're not changing anything

    // fix "...Color" tables
    if ([keyName hasSuffix:@"Color"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        // in case they left it out
        lua_pushstring(L, "NSColor") ;
        lua_setfield(L, -2, "__luaSkinType") ;
        newValue = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

    // fix NSAffineTransform table
    } else if ([keyName isEqualToString:@"transformation"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        // in case they left it out
        lua_pushstring(L, "NSAffineTransform") ;
        lua_setfield(L, -2, "__luaSkinType") ;
        newValue = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

    // fix styledText as Table
    } else if ([keyName isEqualToString:@"text"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        // in case they left it out
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

    return newValue ;
}

- (id)getDefaultValueFor:(NSString *)keyName {
    NSDictionary *attributeDefinition = languageDictionary[keyName] ;
    if (!attributeDefinition[@"default"]) {
        return nil ;
    } else if (_canvasDefaults[keyName]) {
        return _canvasDefaults[keyName] ;
    } else {
        return attributeDefinition[@"default"] ;
    }
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
    self.contentView.needsDisplay = true ;
    return validityStatus ;
}

- (id)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index {
    if (index > [_elementList count]) return nil ;
    NSDictionary *elementAttributes = _elementList[index] ;
    return elementAttributes[keyName] ? elementAttributes[keyName] : [self getDefaultValueFor:keyName] ;
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
                    if (percentage) {
                        keyValue = [NSNumber numberWithDouble:([percentage doubleValue] * self.frame.size.width)] ;
                    } else {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for %@", USERDATA_TAG, keyName]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            } else if ([keyName isEqualToString:@"center"] || [keyName isEqualToString:@"end"] || [keyName isEqualToString:@"start"]) {
                if ([keyValue[@"x"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"x"]) ;
                    if (percentage) {
                        keyValue[@"x"] = [NSNumber numberWithDouble:([percentage doubleValue] * self.frame.size.width)] ;
                    } else {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field x of %@", USERDATA_TAG, keyName]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"y"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"y"]) ;
                    if (percentage) {
                        keyValue[@"y"] = [NSNumber numberWithDouble:([percentage doubleValue] * self.frame.size.height)] ;
                    } else {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field y of %@", USERDATA_TAG, keyName]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            } else if ([keyName isEqualToString:@"frame"]) {
                if ([keyValue[@"x"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"x"]) ;
                    if (percentage) {
                        keyValue[@"x"] = [NSNumber numberWithDouble:([percentage doubleValue] * self.frame.size.width)] ;
                    } else {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field x of %@", USERDATA_TAG, keyName]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"y"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"y"]) ;
                    if (percentage) {
                        keyValue[@"y"] = [NSNumber numberWithDouble:([percentage doubleValue] * self.frame.size.height)] ;
                    } else {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field y of %@", USERDATA_TAG, keyName]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"w"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"w"]) ;
                    if (percentage) {
                        keyValue[@"w"] = [NSNumber numberWithDouble:([percentage doubleValue] * self.frame.size.width)] ;
                    } else {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field w of %@", USERDATA_TAG, keyName]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"h"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"h"]) ;
                    if (percentage) {
                        keyValue[@"h"] = [NSNumber numberWithDouble:([percentage doubleValue] * self.frame.size.height)] ;
                    } else {
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
                        [self setElementValueFor:additionalKey atIndex:index to:[self getDefaultValueFor:additionalKey]] ;
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
    self.contentView.needsDisplay = true ;
    return validityStatus ;
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
    NSGraphicsContext* gc = [NSGraphicsContext currentContext];
    [gc saveGraphicsState];
    __block BOOL clippingModified = NO ;

    ASMCanvasWindow *myWindow = (ASMCanvasWindow *)self.window ;

    [myWindow.elementList enumerateObjectsUsingBlock:^(NSDictionary *element, NSUInteger idx, __unused BOOL *stop) {
        NSBezierPath *elementPath ;
        NSString     *elementType = element[@"type"] ;

        if ([elementType isEqualToString:@"arc"]) {
            NSDictionary *center = [myWindow getElementValueFor:@"center" atIndex:idx] ;
            CGFloat cx = [center[@"x"] doubleValue] ;
            CGFloat cy = [center[@"y"] doubleValue] ;
            CGFloat r  = [[myWindow getElementValueFor:@"radius" atIndex:idx] doubleValue] ;
            NSPoint myCenterPoint = NSMakePoint(cx, cy) ;
            elementPath = [NSBezierPath bezierPath];
            CGFloat startAngle = [[myWindow getElementValueFor:@"startAngle" atIndex:idx] doubleValue] - 90 ;
            CGFloat endAngle   = [[myWindow getElementValueFor:@"endAngle" atIndex:idx] doubleValue] - 90 ;
            BOOL    arcDir     = [[myWindow getElementValueFor:@"arcClockwise" atIndex:idx] boolValue] ;
            BOOL    arcLegs    = [[myWindow getElementValueFor:@"arcRadii" atIndex:idx] boolValue] ;
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
            NSDictionary *center = [myWindow getElementValueFor:@"center" atIndex:idx] ;
            CGFloat cx = [center[@"x"] doubleValue] ;
            CGFloat cy = [center[@"y"] doubleValue] ;
            CGFloat r  = [[myWindow getElementValueFor:@"radius" atIndex:idx] doubleValue] ;
            elementPath = [NSBezierPath bezierPath];
            [elementPath appendBezierPathWithOvalInRect:NSMakeRect(cx - r, cy - r, r * 2, r * 2)] ;
        } else
        if ([elementType isEqualToString:@"ellipticalArc"]) {
            NSDictionary *frame = [myWindow getElementValueFor:@"frame" atIndex:idx] ;
            NSRect  myRect = NSMakeRect([frame[@"x"] doubleValue], [frame[@"y"] doubleValue],
                                        [frame[@"w"] doubleValue], [frame[@"h"] doubleValue]) ;
            CGFloat cx     = myRect.origin.x + myRect.size.width / 2 ;
            CGFloat cy     = myRect.origin.y + myRect.size.height / 2 ;
            CGFloat r      = myRect.size.width / 2 ;

            NSAffineTransform *moveTransform = [NSAffineTransform transform] ;
            [moveTransform translateXBy:cx yBy:cy] ;
            NSAffineTransform *scaleTransform = [NSAffineTransform transform] ;
            [scaleTransform scaleXBy:1.0 yBy:(myRect.size.height / myRect.size.width)] ;
            NSAffineTransform *finalTransform = [[NSAffineTransform alloc] initWithTransform:scaleTransform] ;
            [finalTransform appendTransform:moveTransform] ;
            elementPath = [NSBezierPath bezierPath];
            CGFloat startAngle = [[myWindow getElementValueFor:@"startAngle" atIndex:idx] doubleValue] - 90 ;
            CGFloat endAngle   = [[myWindow getElementValueFor:@"endAngle" atIndex:idx] doubleValue] - 90 ;
            BOOL    arcDir     = [[myWindow getElementValueFor:@"arcClockwise" atIndex:idx] boolValue] ;
            BOOL    arcLegs    = [[myWindow getElementValueFor:@"arcRadii" atIndex:idx] boolValue] ;
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
//         if ([elementType isEqualToString:@"line"]) {
//         } else
//         if ([elementType isEqualToString:@"image"]) {
//         } else
//         if ([elementType isEqualToString:@"text"]) {
//         } else
        if ([elementType isEqualToString:@"oval"]) {
            elementPath = [NSBezierPath bezierPath];
            NSDictionary *frame = [myWindow getElementValueFor:@"frame" atIndex:idx] ;
            [elementPath appendBezierPathWithOvalInRect:NSMakeRect([frame[@"x"] doubleValue], [frame[@"y"] doubleValue],
                                                                 [frame[@"w"] doubleValue], [frame[@"h"] doubleValue])] ;
        } else
        if ([elementType isEqualToString:@"rectangle"]) {
            elementPath = [NSBezierPath bezierPath];
            NSDictionary *frame       = [myWindow getElementValueFor:@"frame" atIndex:idx] ;
            NSDictionary *roundedRect = [myWindow getElementValueFor:@"roundedRectRadii" atIndex:idx] ;
            [elementPath appendBezierPathWithRoundedRect:NSMakeRect([frame[@"x"] doubleValue], [frame[@"y"] doubleValue],
                                                                 [frame[@"w"] doubleValue], [frame[@"h"] doubleValue])
                                              xRadius:[roundedRect[@"xRadius"] doubleValue]
                                              yRadius:[roundedRect[@"yRadius"] doubleValue]] ;
        } else
//         if ([elementType isEqualToString:@"curve"]) {
//         } else
//         if ([elementType isEqualToString:@"point"]) {
//         } else
//         if ([elementType isEqualToString:@"segments"]) {
//         } else
        if ([elementType isEqualToString:@"resetClip"]) {
            if (clippingModified) {
                [gc restoreGraphicsState] ;
                clippingModified = NO ;
            } else {
                [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - resetClip requested with no clipping changes in effect at index %lu", USERDATA_TAG, idx]] ;
            }
            elementPath = nil ; // shouldn't be necessary, but lets be explicit
        } else
        {
            [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - unrecognized type %@ at index %lu", USERDATA_TAG, elementType, idx]] ;
        }

        if (elementPath) {
            elementPath.miterLimit = [[myWindow getElementValueFor:@"miterLimit" atIndex:idx] doubleValue] ;
            elementPath.flatness   = [[myWindow getElementValueFor:@"flatness" atIndex:idx] doubleValue] ;

            if ([[myWindow getElementValueFor:@"flattenPath" atIndex:idx] boolValue]) {
                elementPath = elementPath.bezierPathByFlatteningPath ;
            }
            if ([[myWindow getElementValueFor:@"reversePath" atIndex:idx] boolValue]) {
                elementPath = elementPath.bezierPathByReversingPath ;
            }

            NSString *windingRule = [myWindow getElementValueFor:@"windingRule" atIndex:idx] ;
            if ([windingRule isEqualToString:@"nonZero"]) {
                elementPath.windingRule = NSNonZeroWindingRule ;
            } else if ([windingRule isEqualToString:@"evenOdd"]) {
                elementPath.windingRule = NSEvenOddWindingRule ;
            } else {
                [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - unrecognized winding rule %@ at index %lu", USERDATA_TAG, windingRule, idx]] ;
            }

            if ([[myWindow getElementValueFor:@"addToClipRegion" atIndex:idx] boolValue]) {
                if (!clippingModified) {
                    [gc saveGraphicsState] ;
                    clippingModified = YES ;
                }
                if ([[myWindow getElementValueFor:@"inverseClip" atIndex:idx] boolValue]) {
                    NSBezierPath *framePath = [NSBezierPath bezierPathWithRect:self.bounds] ;
                    [framePath appendBezierPath:elementPath.bezierPathByReversingPath ;
                    [framePath addClip] ;
                } else {
                    [elementPath addClip] ;
                }
            } else {
                NSCompositingOperation savedCompositing = gc.compositingOperation ;
                NSString *compositingString = [myWindow getElementValueFor:@"compositeRule" atIndex:idx] ;
                if ([compositingString isEqualToString:@"clear"]) {
                    gc.compositingOperation = NSCompositeClear ;
                } else if ([compositingString isEqualToString:@"copy"]) {
                    gc.compositingOperation = NSCompositeCopy ;
                } else if ([compositingString isEqualToString:@"sourceOver"]) {
                    gc.compositingOperation = NSCompositeSourceOver ;
                } else if ([compositingString isEqualToString:@"sourceIn"]) {
                    gc.compositingOperation = NSCompositeSourceIn ;
                } else if ([compositingString isEqualToString:@"sourceOut"]) {
                    gc.compositingOperation = NSCompositeSourceOut ;
                } else if ([compositingString isEqualToString:@"sourceAtop"]) {
                    gc.compositingOperation = NSCompositeSourceAtop ;
                } else if ([compositingString isEqualToString:@"destinationOver"]) {
                    gc.compositingOperation = NSCompositeDestinationOver ;
                } else if ([compositingString isEqualToString:@"destinationIn"]) {
                    gc.compositingOperation = NSCompositeDestinationIn ;
                } else if ([compositingString isEqualToString:@"destinationOut"]) {
                    gc.compositingOperation = NSCompositeDestinationOut ;
                } else if ([compositingString isEqualToString:@"destinationAtop"]) {
                    gc.compositingOperation = NSCompositeDestinationAtop ;
                } else if ([compositingString isEqualToString:@"XOR"]) {
                    gc.compositingOperation = NSCompositeXOR ;
                } else if ([compositingString isEqualToString:@"plusDarker"]) {
                    gc.compositingOperation = NSCompositePlusDarker ;
                } else if ([compositingString isEqualToString:@"plusLighter"]) {
                    gc.compositingOperation = NSCompositePlusLighter ;
                } else {
                    [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - unrecognized compositingOperation %@ at index %lu", USERDATA_TAG, compositingString, idx]] ;
                }

                if ([[myWindow getElementValueFor:@"fill" atIndex:idx] boolValue]) {
                    NSString     *fillGradient   = [myWindow getElementValueFor:@"fillGradient" atIndex:idx] ;
                    NSDictionary *gradientColors = [myWindow getElementValueFor:@"fillGradientColors" atIndex:idx] ;
                    NSColor      *startColor     = gradientColors[@"startColor"] ;
                    NSColor      *endColor       = gradientColors[@"endColor"] ;
                    if ([fillGradient isEqualToString:@"linear"]) {
                        NSGradient* gradient = [[NSGradient alloc] initWithStartingColor:startColor endingColor:endColor];
                        [gradient drawInBezierPath:elementPath angle:[[myWindow getElementValueFor:@"fillGradientAngle" atIndex:idx] doubleValue]] ;
                    } else if ([fillGradient isEqualToString:@"radial"]) {
                        NSGradient* gradient = [[NSGradient alloc] initWithStartingColor:startColor endingColor:endColor];
                        NSDictionary *centerPoint = [myWindow getElementValueFor:@"fillGradientCenter" atIndex:idx] ;
                        [gradient drawInBezierPath:elementPath
                            relativeCenterPosition:NSMakePoint([centerPoint[@"x"] doubleValue], [centerPoint[@"y"] doubleValue])] ;
                    } else if ([fillGradient isEqualToString:@"none"]) {
                        [[myWindow getElementValueFor:@"fillColor" atIndex:idx] setFill] ;
                        [elementPath fill] ;
                    } else {
                        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - unrecognized gradient type %@ at index %lu", USERDATA_TAG, fillGradient, idx]] ;
                    }
                }
                if ([[myWindow getElementValueFor:@"stroke" atIndex:idx] boolValue]) {
                    elementPath.lineWidth  = [[myWindow getElementValueFor:@"strokeWidth" atIndex:idx] doubleValue] ;

                    NSString *lineJoinStyle = [myWindow getElementValueFor:@"strokeJoinStyle" atIndex:idx] ;
                    if ([lineJoinStyle isEqualToString:@"miter"]) {
                        elementPath.lineJoinStyle = NSMiterLineJoinStyle ;
                    } else if ([lineJoinStyle isEqualToString:@"round"]) {
                        elementPath.lineJoinStyle = NSRoundLineJoinStyle ;
                    } else if ([lineJoinStyle isEqualToString:@"bevel"]) {
                        elementPath.lineJoinStyle = NSBevelLineJoinStyle ;
                    } else {
                        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - unrecognized strokeJoinStyle %@ at index %lu", USERDATA_TAG, lineJoinStyle, idx]] ;
                    }

                    NSString *lineCapStyle = [myWindow getElementValueFor:@"strokeCapStyle" atIndex:idx] ;
                    if ([lineCapStyle isEqualToString:@"butt"]) {
                        elementPath.lineCapStyle = NSButtLineCapStyle ;
                    } else if ([lineCapStyle isEqualToString:@"round"]) {
                        elementPath.lineCapStyle = NSRoundLineCapStyle ;
                    } else if ([lineCapStyle isEqualToString:@"square"]) {
                        elementPath.lineCapStyle = NSSquareLineCapStyle ;
                    } else {
                        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - unrecognized strokeCapStyle %@ at index %lu", USERDATA_TAG, lineCapStyle, idx]] ;
                    }

                    NSArray *strokeDashes = [myWindow getElementValueFor:@"strokeDashPattern" atIndex:idx] ;
                    if ([strokeDashes count] > 0) {
                        NSUInteger count = [strokeDashes count] ;
                        CGFloat    phase = [[myWindow getElementValueFor:@"strokeDashPhase" atIndex:idx] doubleValue] ;
                        CGFloat *pattern ;
                        pattern = (CGFloat *)malloc(sizeof(CGFloat) * count) ;
                        if (pattern) {
                            for (NSUInteger i = 0 ; i < count ; i++) {
                                pattern[i] = [strokeDashes[i] doubleValue] ;
                            }
                            [elementPath setLineDash:pattern count:(NSInteger)count phase:phase];
                            free(pattern) ;
                        }
                    }
                    [[myWindow getElementValueFor:@"strokeColor" atIndex:idx] setStroke] ;
                    [elementPath stroke] ;
                }
                gc.compositingOperation = savedCompositing ;
            }
        }
    }] ;

    if (clippingModified) [gc restoreGraphicsState] ; // balance our saves
    [gc restoreGraphicsState];
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
    NSRect oldFrame = canvasWindow.frame;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:oldFrame.size] ;
    } else {
        NSSize newSize  = [skin tableToSizeAtIndex:2] ;
        NSRect newFrame = NSMakeRect(oldFrame.origin.x, oldFrame.origin.y + oldFrame.size.height - newSize.height, newSize.width, newSize.height);

        CGFloat xFactor = newFrame.size.width / oldFrame.size.width ;
        CGFloat yFactor = newFrame.size.height / oldFrame.size.height ;

        for (NSUInteger i = 0 ; i < [canvasWindow.elementList count] ; i++) {
            NSNumber *absPos = [canvasWindow getElementValueFor:@"absolutePosition" atIndex:i] ;
            NSNumber *absSiz = [canvasWindow getElementValueFor:@"absoluteSize" atIndex:i] ;
            if (absPos && absSiz) {
                BOOL absolutePosition = absPos ? [absPos boolValue] : YES ;
                BOOL absoluteSize     = absSiz ? [absSiz boolValue] : YES ;
                NSMutableDictionary *attributeDefinition = canvasWindow.elementList[i] ;
                if (!absolutePosition) {
                    [attributeDefinition enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, id keyValue, __unused BOOL *stop) {
                        if ([(@[ @"center", @"end", @"frame", @"start"]) containsObject:keyName]) {
                            keyValue[@"x"] = [NSNumber numberWithDouble:([keyValue[@"x"] doubleValue] * xFactor)] ;
                            keyValue[@"y"] = [NSNumber numberWithDouble:([keyValue[@"y"] doubleValue] * yFactor)] ;
                        }
                    }] ;
                }
                if (!absoluteSize) {
                    [attributeDefinition enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, id keyValue, __unused BOOL *stop) {
                        if ([keyName isEqualToString:@"frame"]) {
                            keyValue[@"h"] = [NSNumber numberWithDouble:([keyValue[@"h"] doubleValue] * yFactor)] ;
                            keyValue[@"w"] = [NSNumber numberWithDouble:([keyValue[@"w"] doubleValue] * xFactor)] ;
                        } else if ([keyName isEqualToString:@"radius"]) {
                            attributeDefinition[keyName] = [NSNumber numberWithDouble:([keyValue doubleValue] * xFactor)] ;
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
                    LS_TBREAK] ;
    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    lua_newtable(L) ;
    for (NSString *keyName in languageDictionary) {
        id keyValue = [canvasWindow getDefaultValueFor:keyName] ;
        if (keyValue) {
            [skin pushNSObject:keyValue] ; lua_setfield(L, -2, [keyName UTF8String]) ;
        }
    }
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
    NSString *keyName = [skin toNSObjectAtIndex:2] ;

    if (!languageDictionary[keyName]) {
        return luaL_argerror(L, 2, "unrecognized attribute name") ;
    }

    id attributeDefault = [canvasWindow getDefaultValueFor:keyName] ;
    if (!attributeDefault) {
        return luaL_argerror(L, 2, "attribute has no default value") ;
    }

    if (lua_gettop(L) == 2) {
        [skin pushNSObject:attributeDefault] ;
    } else {
        id keyValue = [skin toNSObjectAtIndex:3 withOptions:LS_NSRawTables] ;

        switch([canvasWindow setDefaultFor:keyName to:keyValue]) {
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
    NSUInteger      elementCount  = [canvasWindow.elementList count] ;
    NSInteger       tablePosition = (lua_gettop(L) == 3) ? (lua_tointeger(L, 3) - 1) : (NSInteger)elementCount ;

    if (tablePosition < 0 || tablePosition > (NSInteger)elementCount) {
        return luaL_argerror(L, 3, "index out of bounds") ;
    }

    NSDictionary *element = [skin toNSObjectAtIndex:2] ;
    if ([element isKindOfClass:[NSDictionary class]]) {
        NSString *elementType = element[@"type"] ;
        if (elementType && [ALL_TYPES containsObject:elementType]) {
            [canvasWindow.elementList insertObject:[[NSMutableDictionary alloc] init] atIndex:(NSUInteger)tablePosition] ;
            [element enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, id keyValue, __unused BOOL *stop) {
                // skip type in here to minimize the need to copy in defaults just to be overwritten
                if (![keyName isEqualTo:@"type"]) [canvasWindow setElementValueFor:keyName atIndex:(NSUInteger)tablePosition to:keyValue] ;
            }] ;
            [canvasWindow setElementValueFor:@"type" atIndex:(NSUInteger)tablePosition to:elementType] ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalid element; type required and must be one of %@", [ALL_TYPES componentsJoinedByString:@", "]] UTF8String]) ;
        }
    } else {
        return luaL_argerror(L, 2, "invalid element definition; must contain key-value pairs");
    }

    canvasWindow.contentView.needsDisplay = true ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int canvas_removeElementAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    NSUInteger      elementCount  = [canvasWindow.elementList count] ;
    NSInteger       tablePosition = (lua_gettop(L) == 2) ? (lua_tointeger(L, 2) - 1) : (NSInteger)elementCount - 1 ;

    if (tablePosition < 0 || tablePosition >= (NSInteger)elementCount) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    [canvasWindow.elementList removeObjectAtIndex:(NSUInteger)tablePosition] ;

    canvasWindow.contentView.needsDisplay = true ;
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
    NSString        *keyName      = [skin toNSObjectAtIndex:3] ;

    NSUInteger      elementCount  = [canvasWindow.elementList count] ;
    NSInteger       tablePosition = lua_tointeger(L, 2) - 1 ;

    if (tablePosition < 0 || tablePosition > (NSInteger)elementCount) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    if (!languageDictionary[keyName]) {
        if (lua_gettop(L) == 3) {
            lua_pushnil(L) ;
            return 1 ;
        } else {
            return luaL_argerror(L, 3, "unrecognized attribute name") ;
        }
    }

    if (lua_gettop(L) == 3) {
        [skin pushNSObject:[canvasWindow getElementValueFor:keyName atIndex:(NSUInteger)tablePosition]] ;
    } else {
        id keyValue = [skin toNSObjectAtIndex:4 withOptions:LS_NSRawTables] ;
        switch([canvasWindow setElementValueFor:keyName atIndex:(NSUInteger)tablePosition to:keyValue]) {
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
    NSUInteger      elementCount  = [canvasWindow.elementList count] ;
    NSInteger       tablePosition = lua_tointeger(L, 2) - 1 ;

    if (tablePosition < 0 || tablePosition > (NSInteger)elementCount) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }
    NSUInteger indexPosition = (NSUInteger)tablePosition ;

    NSMutableSet *list = [[NSMutableSet alloc] initWithArray:[(NSDictionary *)canvasWindow.elementList[indexPosition] allKeys]] ;
    if ((lua_gettop(L) == 3) && lua_toboolean(L, 3)) {
        NSString *ourType = canvasWindow.elementList[indexPosition][@"type"] ;
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
    lua_pushinteger(L, (lua_Integer)[canvasWindow.elementList count]) ;
    return 1 ;
}

static int canvas_canvasElements(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK] ;
    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    [skin pushNSObject:canvasWindow.elementList withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

static int canvas_assignElementAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TNIL,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;

    NSUInteger      elementCount  = [canvasWindow.elementList count] ;
    NSInteger       tablePosition = (lua_gettop(L) == 3) ? (lua_tointeger(L, 3) - 1) : (NSInteger)elementCount ;

    if (tablePosition < 0 || tablePosition > (NSInteger)elementCount) {
        return luaL_argerror(L, 3, "index out of bounds") ;
    }

    if (lua_isnil(L, 2)) {
        if (tablePosition == (NSInteger)elementCount - 1) {
            [canvasWindow.elementList removeLastObject] ;
        } else {
            return luaL_argerror(L, 3, "nil only valid for final element") ;
        }
    } else {
        NSDictionary *element = [skin toNSObjectAtIndex:2] ;
        if ([element isKindOfClass:[NSDictionary class]]) {
            NSString *elementType = element[@"type"] ;
            if (elementType && [ALL_TYPES containsObject:elementType]) {
                canvasWindow.elementList[tablePosition] = [[NSMutableDictionary alloc] init] ;
                [element enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, id keyValue, __unused BOOL *stop) {
                    // skip type in here to minimize the need to copy in defaults just to be overwritten
                    if (![keyName isEqualTo:@"type"]) [canvasWindow setElementValueFor:keyName atIndex:(NSUInteger)tablePosition to:keyValue] ;
                }] ;
                [canvasWindow setElementValueFor:@"type" atIndex:(NSUInteger)tablePosition to:elementType] ;
            } else {
                return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalid element; type required and must be one of %@", [ALL_TYPES componentsJoinedByString:@", "]] UTF8String]) ;
            }
        } else {
            return luaL_argerror(L, 2, "invalid element definition; must contain key-value pairs");
        }
    }

    canvasWindow.contentView.needsDisplay = true ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int dashtest(lua_State *L) {
    NSBezierPath *path = [[NSBezierPath alloc] init] ;

    lua_newtable(L) ;
    NSInteger count = 0 ;
    CGFloat   phase = 0.0 ;
    [path getLineDash:nil count:&count phase:&phase];
    lua_pushinteger(L, count) ; lua_setfield(L, -2, "count") ;
    lua_pushnumber(L, phase) ; lua_setfield(L, -2, "phase") ;
    CGFloat *results ;
    results = (CGFloat *) malloc(sizeof(CGFloat) * (NSUInteger)count);
    [path getLineDash:results count:nil phase:nil];
    for (NSInteger i = 0 ; i < count ; i++) {
      lua_pushnumber(L, results[i]) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if (results) free(results) ;
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

static int pushNSAffineTransform(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    if ([obj isKindOfClass:[NSAffineTransform class]]) {
        NSAffineTransformStruct structure = [(NSAffineTransform *)obj transformStruct] ;
        lua_newtable(L) ;
          lua_pushnumber(L, structure.m11) ; lua_setfield(L, -2, "m11") ;
          lua_pushnumber(L, structure.m12) ; lua_setfield(L, -2, "m12") ;
          lua_pushnumber(L, structure.m21) ; lua_setfield(L, -2, "m21") ;
          lua_pushnumber(L, structure.m22) ; lua_setfield(L, -2, "m22") ;
          lua_pushnumber(L, structure.tX) ;  lua_setfield(L, -2, "tX") ;
          lua_pushnumber(L, structure.tY) ;  lua_setfield(L, -2, "tY") ;
          lua_pushstring(L, "NSAffineTransform") ; lua_setfield(L, -2, "__luaSkinType") ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected NSAffineTransform, found %@",
                                                   [obj className]]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static id toNSAffineTransformFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSAffineTransform  *value = [NSAffineTransform transform] ;
    NSAffineTransformStruct structure = [value transformStruct] ;
    if (lua_type(L, idx) == LUA_TTABLE) {
        idx = lua_absindex(L, idx) ;
        if (lua_getfield(L, idx, "m11") == LUA_TNUMBER) {
            structure.m11 = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"NSAffineTransform field m11 is not a number"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m12") == LUA_TNUMBER) {
            structure.m12 = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"NSAffineTransform field m12 is not a number"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m21") == LUA_TNUMBER) {
            structure.m21 = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"NSAffineTransform field m21 is not a number"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m22") == LUA_TNUMBER) {
            structure.m22 = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"NSAffineTransform field m22 is not a number"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "tX") == LUA_TNUMBER) {
            structure.tX = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"NSAffineTransform field tX is not a number"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "tY") == LUA_TNUMBER) {
            structure.tY = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"NSAffineTransform field tY is not a number"] ;
        }
        lua_pop(L, 1) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected NSAffineTransform table, found %s",
                                                  lua_typename(L, lua_type(L, idx))]] ;
    }

    [value setTransformStruct:structure] ;
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
    {"canvasDefaultFor",   canvas_canvasDefaultFor},
    {"elementAttribute",   canvas_elementAttributeAtIndex},
    {"elementKeys",        canvas_elementKeysAtIndex},
    {"elementCount",       canvas_elementCount},
    {"elementsArray",      canvas_canvasElements},
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
    {"dashtest",    dashtest},

    {NULL,          NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

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

    [skin registerPushNSHelper:pushNSAffineTransform         forClass:"NSAffineTransform"];
    [skin registerLuaObjectHelper:toNSAffineTransformFromLua forClass:"NSAffineTransform"];

    pushCompositeTypes(L) ; lua_setfield(L, -2, "compositeTypes") ;

    return 1;
}
