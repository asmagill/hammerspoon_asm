#import "ASMCanvas.h"

#define VIEW_DEBUG

static const char *USERDATA_TAG = "hs._asm.enclosure.canvas" ;
static int refTable = LUA_NOREF;

// Can't have "static" or "constant" dynamic NSObjects like NSArray, so define in lua_open
static NSDictionary *languageDictionary ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

typedef NS_ENUM(NSInteger, attributeValidity) {
    attributeValid,
    attributeNulling,
    attributeInvalid,
};

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
            @"values"      : @[ @"stroke", @"fill", @"strokeAndFill", @"clip", @"build", @"skip" ],
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
        @"clipToPath" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : CLOSED,
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
        @"closed" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(NO),
            @"default"     : @(NO),
            @"requiredFor" : @[ @"segments" ],
        },
        @"coordinates" : @{
            @"class"           : @[ [NSArray class] ],
            @"luaClass"        : @"table",
            @"default"         : @[ ],
            @"nullable"        : @(NO),
            @"requiredFor"     : @[ @"segments", @"points" ],
            @"memberClass"     : [NSDictionary class],
            @"memberLuaClass"  : @"point table",
            @"memberClassKeys" : @{
                @"x"   : @{
                    @"class"       : @[ [NSNumber class], [NSString class] ],
                    @"luaClass"    : @"number or string",
                    @"default"     : @"0.0",
                    @"requiredFor" : @[ @"segments", @"points" ],
                    @"nullable"    : @(NO),
                },
                @"y"   : @{
                    @"class"       : @[ [NSNumber class], [NSString class] ],
                    @"luaClass"    : @"number or string",
                    @"default"     : @"0.0",
                    @"requiredFor" : @[ @"segments", @"points" ],
                    @"nullable"    : @(NO),
                },
                @"c1x" : @{
                    @"class"       : @[ [NSNumber class], [NSString class] ],
                    @"luaClass"    : @"number or string",
                    @"default"     : @"0.0",
                    @"optionalFor" : @[ @"segments" ],
                    @"nullable"    : @(YES),
                },
                @"c1y" : @{
                    @"class"       : @[ [NSNumber class], [NSString class] ],
                    @"luaClass"    : @"number or string",
                    @"default"     : @"0.0",
                    @"optionalFor" : @[ @"segments" ],
                    @"nullable"    : @(YES),
                },
                @"c2x" : @{
                    @"class"       : @[ [NSNumber class], [NSString class] ],
                    @"luaClass"    : @"number or string",
                    @"default"     : @"0.0",
                    @"optionalFor" : @[ @"segments" ],
                    @"nullable"    : @(YES),
                },
                @"c2y" : @{
                    @"class"       : @[ [NSNumber class], [NSString class] ],
                    @"luaClass"    : @"number or string",
                    @"default"     : @"0.0",
                    @"optionalFor" : @[ @"segments" ],
                    @"nullable"    : @(YES),
                },
            },
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
            @"class"          : @[ [NSArray class] ],
            @"luaClass"       : @"table",
            @"default"        : @[ [NSColor blackColor], [NSColor whiteColor] ],
            @"memberClass"    : [NSColor class],
            @"memberLuaClass" : @"hs.drawing.color table",
            @"nullable"       : @(YES),
            @"optionalFor"    : CLOSED,
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
            @"requiredFor"   : @[ @"rectangle", @"oval", @"ellipticalArc", @"text", @"image", @"view" ],
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
            @"default"     : [NSNull null],
            @"optionalFor" : @[ @"image" ],
        },
        @"imageAlpha" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"nullable"    : @(YES),
            @"default"     : @(1.0),
            @"minNumber"   : @(0.0),
            @"maxNumber"   : @(1.0),
            @"optionalFor" : @[ @"image" ],
        },
        @"imageAlignment" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [IMAGEALIGNMENT_TYPES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"center",
            @"optionalFor" : @[ @"image" ],
        },
        @"imageAnimationFrame" : @ {
            @"class"       : @[ [NSNumber class] ],
            @"objCType"    : @(@encode(lua_Integer)),
            @"luaClass"    : @"integer",
            @"nullable"    : @(YES),
            @"default"     : @(0),
            @"optionalFor" : @[ @"image" ],
        },
        @"imageAnimates" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(NO),
            @"default"     : @(NO),
            @"requiredFor" : @[ @"image" ],
        },
        @"imageScaling" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [IMAGESCALING_TYPES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"scaleProportionally",
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
            @"default"     : @(0.0),
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
            @"nullable"    : @(YES),
            @"requiredFor" : @[ @"text" ],
        },
        @"textAlignment" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [TEXTALIGNMENT_TYPES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"natural",
            @"optionalFor" : @[ @"text" ],
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
            @"default"     : [[NSFont systemFontOfSize:0] fontName],
            @"optionalFor" : @[ @"text" ],
        },
        @"textLineBreak" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [TEXTWRAP_TYPES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"wordWrap",
            @"optionalFor" : @[ @"text" ],
        },
        @"textSize" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"nullable"    : @(YES),
            @"default"     : @(27.0),
            @"optionalFor" : @[ @"text" ],
        },
        @"trackMouseByBounds" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @(@encode(BOOL)),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : VISIBLE,
        },
        @"trackMouseEnterExit" : @{
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
        @"view" : @{
            @"class"       : @[ [NSView class] ],
            @"luaClass"    : @"userdata object subclassing NSView",
            @"nullable"    : @(YES),
            @"default"     : [NSNull null],
            @"requiredFor" : @[ @"view" ],
        },
        @"viewAlpha" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"nullable"    : @(YES),
            @"default"     : @(1.0),
            @"minNumber"   : @(0.0),
            @"maxNumber"   : @(1.0),
            @"optionalFor" : @[ @"view" ],
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


static attributeValidity isValueValidForDictionary(NSString *keyName, id keyValue, NSDictionary *attributeDefinition) {
    __block attributeValidity validity = attributeValid ;
    __block NSString          *errorMessage ;

    BOOL checked = NO ;
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

        if ([keyValue isKindOfClass:[NSNumber class]] && !attributeDefinition[@"objCType"]) {
          if (!isfinite([keyValue doubleValue])) {
              errorMessage = [NSString stringWithFormat:@"%@ must be a finite number", keyName] ;
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

                if ([keyValue[subKeyName] isKindOfClass:[NSNumber class]] && !subKeyMiniDefinition[@"objCType"]) {
                  if (!isfinite([keyValue[subKeyName] doubleValue])) {
                      errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be a finite number", subKeyName, keyName] ;
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
            if ([keyValue count] > 0) {
                for (NSUInteger i = 0 ; i < [keyValue count] ; i++) {
                    if (![keyValue[i] isKindOfClass:attributeDefinition[@"memberClass"]]) {
                        isGood = NO ;
                        break ;
                    } else if ([keyValue[i] isKindOfClass:[NSDictionary class]]) {
                        [keyValue[i] enumerateKeysAndObjectsUsingBlock:^(NSString *subKey, id obj, BOOL *stop) {
                            NSDictionary *subKeyDefinition = attributeDefinition[@"memberClassKeys"][subKey] ;
                            if (subKeyDefinition) {
                                validity = isValueValidForDictionary(subKey, obj, subKeyDefinition) ;
                            } else {
                                validity = attributeInvalid ;
                                errorMessage = [NSString stringWithFormat:@"%@ is not a valid subkey for a %@ value", subKey, attributeDefinition[@"memberLuaClass"]] ;
                            }
                            if (validity != attributeValid) *stop = YES ;
                        }] ;
                    }
                }
                if (!isGood) {
                    errorMessage = [NSString stringWithFormat:@"%@ must be an array of %@ values", keyName, attributeDefinition[@"memberLuaClass"]] ;
                    break ;
                }
            }
        }

        if ([keyName isEqualToString:@"textFont"]) {
            NSFont *testFont = [NSFont fontWithName:keyValue size:0.0] ;
            if (!testFont) {
                errorMessage = [NSString stringWithFormat:@"%@ is not a recognized font name", keyValue] ;
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

static attributeValidity isValueValidForAttribute(NSString *keyName, id keyValue) {
    NSDictionary      *attributeDefinition = languageDictionary[keyName] ;
    if (attributeDefinition) {
        return isValueValidForDictionary(keyName, keyValue, attributeDefinition) ;
    } else {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:%@ is not a valid canvas attribute", USERDATA_TAG, keyName]] ;
        return attributeInvalid ;
    }
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

#pragma mark -
@implementation ASMCanvasView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _mouseCallbackRef      = LUA_NOREF;
        _referenceCount        = 0 ;
        _canvasDefaults        = [[NSMutableDictionary alloc] init] ;
        _elementList           = [[NSMutableArray alloc] init] ;
        _elementBounds         = [[NSMutableArray alloc] init] ;
        _canvasTransform       = [NSAffineTransform transform] ;
        _imageAnimations       = [NSMapTable weakToStrongObjectsMapTable] ;

        _canvasMouseDown       = NO ;
        _canvasMouseUp         = NO ;
        _canvasMouseEnterExit  = NO ;
        _canvasMouseMove       = NO ;

        _mouseTracking         = NO ;
        _previousTrackedIndex  = NSNotFound ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"
        [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:frameRect
                                                           options:NSTrackingMouseMoved |
                                                                   NSTrackingMouseEnteredAndExited |
                                                                   NSTrackingActiveAlways |
                                                                   NSTrackingInVisibleRect
                                                             owner:self
                                                          userInfo:nil]] ;
#pragma clang diagnostic pop
    }
    return self;
}

- (BOOL)isFlipped { return YES; }

- (BOOL)acceptsFirstMouse:(__unused NSEvent *)theEvent {
    if (self.window == nil) return NO;
    return !self.window.ignoresMouseEvents;
}

- (BOOL)canBecomeKeyView {
    __block BOOL allowKey = NO ;
    [_elementList enumerateObjectsUsingBlock:^(NSDictionary *element, __unused NSUInteger idx, BOOL *stop) {
        if (element[@"view"] && [element[@"view"] respondsToSelector:@selector(canBecomeKeyView)]) {
            allowKey = [element[@"view"] canBecomeKeyView] ;
            *stop = YES ;
        }
    }] ;
    return allowKey ;
}

- (void)mouseMoved:(NSEvent *)theEvent {
    BOOL canvasMouseEvents = _canvasMouseEnterExit || _canvasMouseMove ;

    if ((_mouseCallbackRef != LUA_NOREF) && (_mouseTracking || canvasMouseEvents)) {
        NSPoint event_location = theEvent.locationInWindow;
        NSPoint local_point = [self convertPoint:event_location fromView:nil];

        __block NSUInteger targetIndex = NSNotFound ;
        __block NSPoint actualPoint = local_point ;

        [_elementBounds enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary *box, NSUInteger idx, BOOL *stop) {
            NSUInteger elementIdx  = [box[@"index"] unsignedIntegerValue] ;
            if ([[self getElementValueFor:@"trackMouseEnterExit" atIndex:elementIdx] boolValue] || [[self getElementValueFor:@"trackMouseMove" atIndex:elementIdx] boolValue]) {
                NSAffineTransform *pointTransform = [self->_canvasTransform copy] ;
                [pointTransform appendTransform:[self getElementValueFor:@"transformation" atIndex:elementIdx]] ;
                [pointTransform invert] ;
                BOOL isView = [[self getElementValueFor:@"type" atIndex:elementIdx] isEqualToString:@"view"] ;
                actualPoint = isView ? local_point : [pointTransform transformPoint:local_point] ;
                if (box[@"imageByBounds"] && ![box[@"imageByBounds"] boolValue]) {
                    NSImage *theImage = self->_elementList[elementIdx][@"image"] ;
                    if (theImage) {
                        NSRect hitRect = NSMakeRect(actualPoint.x, actualPoint.y, 1.0, 1.0) ;
                        NSRect imageRect = [box[@"frame"] rectValue] ;
                        if ([theImage hitTestRect:hitRect withImageDestinationRect:imageRect
                                                                           context:nil
                                                                             hints:nil
                                                                           flipped:YES]) {
                            targetIndex = idx ;
                            *stop = YES ;
                        }
                    }
                } else if ((box[@"frame"] && NSPointInRect(actualPoint, [box[@"frame"] rectValue])) || (box[@"path"] && [box[@"path"] containsPoint:actualPoint])) {
                    targetIndex = idx ;
                    *stop = YES ;
                }
            }
        }] ;

        NSUInteger realTargetIndex = (targetIndex != NSNotFound) ?
                    [_elementBounds[targetIndex][@"index"] unsignedIntegerValue]  : NSNotFound ;
        NSUInteger realPrevIndex = (_previousTrackedIndex != NSNotFound) ?
                    [_elementBounds[_previousTrackedIndex][@"index"] unsignedIntegerValue]  : NSNotFound ;

        if (_previousTrackedIndex == targetIndex) {
            if ((targetIndex != NSNotFound) && [[self getElementValueFor:@"trackMouseMove" atIndex:realPrevIndex] boolValue]) {
                id targetID = [self getElementValueFor:@"id" atIndex:realPrevIndex onlyIfSet:YES] ;
                if (!targetID) targetID = @(realPrevIndex + 1) ;
                [self doMouseCallback:@"mouseMove" for:targetID at:local_point] ;
            }
        } else {
            if ((_previousTrackedIndex != NSNotFound) && [[self getElementValueFor:@"trackMouseEnterExit" atIndex:realPrevIndex] boolValue]) {
                id targetID = [self getElementValueFor:@"id" atIndex:realPrevIndex onlyIfSet:YES] ;
                if (!targetID) targetID = @(realPrevIndex + 1) ;
                [self doMouseCallback:@"mouseExit" for:targetID at:local_point] ;
            }
            if (targetIndex != NSNotFound) {
                id targetID = [self getElementValueFor:@"id" atIndex:realTargetIndex onlyIfSet:YES] ;
                if (!targetID) targetID = @(realTargetIndex + 1) ;
                if ([[self getElementValueFor:@"trackMouseEnterExit" atIndex:realTargetIndex] boolValue]) {
                    [self doMouseCallback:@"mouseEnter" for:targetID at:local_point] ;
                } else if ([[self getElementValueFor:@"trackMouseMove" atIndex:realTargetIndex] boolValue]) {
                    [self doMouseCallback:@"mouseMove" for:targetID at:local_point] ;
                }
                if (_canvasMouseEnterExit && (_previousTrackedIndex == NSNotFound)) {
                    [self doMouseCallback:@"mouseExit" for:@"_canvas_" at:local_point] ;
                }
            }
        }

        if ((_canvasMouseEnterExit || _canvasMouseMove) && (targetIndex == NSNotFound)) {
            if (_previousTrackedIndex == NSNotFound && _canvasMouseMove) {
                [self doMouseCallback:@"mouseMove" for:@"_canvas_" at:local_point] ;
            } else if (_previousTrackedIndex != NSNotFound && _canvasMouseEnterExit) {
                [self doMouseCallback:@"mouseEnter" for:@"_canvas_" at:local_point] ;
            }
        }
        _previousTrackedIndex = targetIndex ;
    }
}

- (void)mouseEntered:(NSEvent *)theEvent {
    if ((_mouseCallbackRef != LUA_NOREF) && _canvasMouseEnterExit) {
        NSPoint event_location = theEvent.locationInWindow;
        NSPoint local_point = [self convertPoint:event_location fromView:nil];

        [self doMouseCallback:@"mouseEnter" for:@"_canvas_" at:local_point] ;
    }
}

- (void)mouseExited:(NSEvent *)theEvent {
    BOOL canvasMouseEvents = _canvasMouseEnterExit || _canvasMouseMove ;

    if ((_mouseCallbackRef != LUA_NOREF) && (_mouseTracking || canvasMouseEvents)) {
        NSPoint event_location = theEvent.locationInWindow;
        NSPoint local_point = [self convertPoint:event_location fromView:nil];
        if (_previousTrackedIndex != NSNotFound) {
            NSUInteger realPrevIndex = (_previousTrackedIndex != NSNotFound) ?
                    [_elementBounds[_previousTrackedIndex][@"index"] unsignedIntegerValue]  : NSNotFound ;
            if ([[self getElementValueFor:@"trackMouseEnterExit" atIndex:realPrevIndex] boolValue]) {
                id targetID = [self getElementValueFor:@"id" atIndex:realPrevIndex onlyIfSet:YES] ;
                if (!targetID) targetID = @(realPrevIndex + 1) ;
                [self doMouseCallback:@"mouseExit" for:targetID at:local_point] ;
            }
        }
        if (_canvasMouseEnterExit) {
            [self doMouseCallback:@"mouseExit" for:@"_canvas_" at:local_point] ;
        }
    }
    _previousTrackedIndex = NSNotFound ;
}

- (void)doMouseCallback:(NSString *)message for:(id)elementIdentifier at:(NSPoint)location {
    if (elementIdentifier && _mouseCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared];
        [skin pushLuaRef:refTable ref:_mouseCallbackRef];
        [skin pushNSObject:self] ;
        [skin pushNSObject:message] ;
        [skin pushNSObject:elementIdentifier] ;
        lua_pushnumber(skin.L, location.x) ;
        lua_pushnumber(skin.L, location.y) ;
        if (![skin protectedCallAndTraceback:5 nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:clickCallback for %@ callback error: %s",
                                                      USERDATA_TAG,
                                                      message,
                                                      lua_tostring(skin.L, -1)]];
            lua_pop(skin.L, 1) ;
        }
    }
}

// NOTE: Do we need/want this?
- (void)subviewCallback:(id)sender {
    if (_mouseCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared];
        [skin pushLuaRef:refTable ref:_mouseCallbackRef];
        [skin pushNSObject:self] ;
        [skin pushNSObject:@"_subview_"] ;
        [skin pushNSObject:sender] ;
        if (![skin protectedCallAndTraceback:3 nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:buttonCallback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    }
}

- (void)mouseDown:(NSEvent *)theEvent {
    [NSApp preventWindowOrdering];
    if (_mouseCallbackRef != LUA_NOREF) {
        BOOL isDown = (theEvent.type == NSEventTypeLeftMouseDown)  ||
                      (theEvent.type == NSEventTypeRightMouseDown) ||
                      (theEvent.type == NSEventTypeOtherMouseDown) ;

        NSPoint event_location = theEvent.locationInWindow;
        NSPoint local_point = [self convertPoint:event_location fromView:nil];
//         [LuaSkin logWarn:[NSString stringWithFormat:@"mouse click at (%f, %f)", local_point.x, local_point.y]] ;

        __block id targetID = nil ;
        __block NSPoint actualPoint = local_point ;

        [_elementBounds enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary *box, __unused NSUInteger idx, BOOL *stop) {
            NSUInteger elementIdx  = [box[@"index"] unsignedIntegerValue] ;
            if ([[self getElementValueFor:(isDown ? @"trackMouseDown" : @"trackMouseUp") atIndex:elementIdx] boolValue]) {
                NSAffineTransform *pointTransform = [self->_canvasTransform copy] ;
                [pointTransform appendTransform:[self getElementValueFor:@"transformation" atIndex:elementIdx]] ;
                [pointTransform invert] ;
                BOOL isView = [[self getElementValueFor:@"type" atIndex:elementIdx] isEqualToString:@"view"] ;
                actualPoint = isView ? local_point : [pointTransform transformPoint:local_point] ;                actualPoint = [pointTransform transformPoint:local_point] ;
                if (box[@"imageByBounds"] && ![box[@"imageByBounds"] boolValue]) {
                    NSImage *theImage = self->_elementList[elementIdx][@"image"] ;
                    if (theImage) {
                        NSRect hitRect = NSMakeRect(actualPoint.x, actualPoint.y, 1.0, 1.0) ;
                        NSRect imageRect = [box[@"frame"] rectValue] ;
                        if ([theImage hitTestRect:hitRect withImageDestinationRect:imageRect
                                                                           context:nil
                                                                             hints:nil
                                                                           flipped:YES]) {
                        targetID = [self getElementValueFor:@"id" atIndex:elementIdx onlyIfSet:YES] ;
                        if (!targetID) targetID = @(elementIdx + 1) ;
                            *stop = YES ;
                        }
                    }
                } else if ((box[@"frame"] && NSPointInRect(actualPoint, [box[@"frame"] rectValue])) || (box[@"path"] && [box[@"path"] containsPoint:actualPoint])) {
                    targetID = [self getElementValueFor:@"id" atIndex:elementIdx onlyIfSet:YES] ;
                    if (!targetID) targetID = @(elementIdx + 1) ;
                    *stop = YES ;
                }
                if (*stop) {
                    if (isDown && [[self getElementValueFor:@"trackMouseDown" atIndex:elementIdx] boolValue]) {
                        [self doMouseCallback:@"mouseDown" for:targetID at:local_point] ;
                    }
                    if (!isDown && [[self getElementValueFor:@"trackMouseUp" atIndex:elementIdx] boolValue]) {
                        [self doMouseCallback:@"mouseUp" for:targetID at:local_point] ;
                    }
                }
            }
        }] ;

        if (!targetID) {
            if (isDown && _canvasMouseDown) {
                [self doMouseCallback:@"mouseDown" for:@"_canvas_" at:local_point] ;
            } else if (!isDown && _canvasMouseUp) {
                [self doMouseCallback:@"mouseUp" for:@"_canvas_" at:local_point] ;
            }
        }
    }
}

- (void)rightMouseDown:(NSEvent *)theEvent { [self mouseDown:theEvent] ; }
- (void)otherMouseDown:(NSEvent *)theEvent { [self mouseDown:theEvent] ; }
- (void)mouseUp:(NSEvent *)theEvent        { [self mouseDown:theEvent] ; }
- (void)rightMouseUp:(NSEvent *)theEvent   { [self mouseDown:theEvent] ; }
- (void)otherMouseUp:(NSEvent *)theEvent   { [self mouseDown:theEvent] ; }

#ifdef VIEW_DEBUG
- (void)didAddSubview:(NSView *)subview {
    [super didAddSubview:subview] ;
    [LuaSkin logInfo:[NSString stringWithFormat:@"%s - didAddSubview for %@", USERDATA_TAG, subview]] ;
}
#endif

- (void)willRemoveSubview:(NSView *)subview {
    [super willRemoveSubview:subview] ;
#ifdef VIEW_DEBUG
    [LuaSkin logInfo:[NSString stringWithFormat:@"%s - willRemoveSubview for %@", USERDATA_TAG, subview]] ;
#endif

    __block BOOL viewFound = NO ;
    [_elementList enumerateObjectsUsingBlock:^(NSMutableDictionary *element, __unused NSUInteger idx, BOOL *stop){
        if ([element[@"view"] isEqualTo:subview]) {
            [element removeObjectForKey:@"view"] ;
            viewFound = YES ;
            *stop = YES ;
        }
    }] ;
    if (!viewFound) [LuaSkin logError:@"view removed from canvas superview does not belong to any known canvas element"] ;
}

- (NSBezierPath *)pathForElementAtIndex:(NSUInteger)idx {
    NSDictionary *frame = [self getElementValueFor:@"frame" atIndex:idx resolvePercentages:YES] ;
    NSRect frameRect = NSMakeRect([frame[@"x"] doubleValue], [frame[@"y"] doubleValue],
                                  [frame[@"w"] doubleValue], [frame[@"h"] doubleValue]) ;
    return [self pathForElementAtIndex:idx withFrame:frameRect] ;
}

- (NSBezierPath *)pathForElementAtIndex:(NSUInteger)idx withFrame:(NSRect)frameRect {
    NSBezierPath *elementPath = nil ;
    NSString     *elementType = [self getElementValueFor:@"type" atIndex:idx] ;

#pragma mark - ARC
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
#pragma mark - CIRCLE
    if ([elementType isEqualToString:@"circle"]) {
        NSDictionary *center = [self getElementValueFor:@"center" atIndex:idx resolvePercentages:YES] ;
        CGFloat cx = [center[@"x"] doubleValue] ;
        CGFloat cy = [center[@"y"] doubleValue] ;
        CGFloat r  = [[self getElementValueFor:@"radius" atIndex:idx resolvePercentages:YES] doubleValue] ;
        elementPath = [NSBezierPath bezierPath];
        [elementPath appendBezierPathWithOvalInRect:NSMakeRect(cx - r, cy - r, r * 2, r * 2)] ;
    } else
#pragma mark - ELLIPTICALARC
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
#pragma mark - OVAL
    if ([elementType isEqualToString:@"oval"]) {
        elementPath = [NSBezierPath bezierPath];
        [elementPath appendBezierPathWithOvalInRect:frameRect] ;
    } else
#pragma mark - RECTANGLE
    if ([elementType isEqualToString:@"rectangle"]) {
        elementPath = [NSBezierPath bezierPath];
        NSDictionary *roundedRect = [self getElementValueFor:@"roundedRectRadii" atIndex:idx] ;
        [elementPath appendBezierPathWithRoundedRect:frameRect
                                          xRadius:[roundedRect[@"xRadius"] doubleValue]
                                          yRadius:[roundedRect[@"yRadius"] doubleValue]] ;
    } else
#pragma mark - POINTS
    if ([elementType isEqualToString:@"points"]) {
        elementPath = [NSBezierPath bezierPath];
        NSArray *coordinates = [self getElementValueFor:@"coordinates" atIndex:idx resolvePercentages:YES] ;

        [coordinates enumerateObjectsUsingBlock:^(NSDictionary *aPoint, __unused NSUInteger idx2, __unused BOOL *stop2) {
            NSNumber *xNumber   = aPoint[@"x"] ;
            NSNumber *yNumber   = aPoint[@"y"] ;
            [elementPath appendBezierPathWithRect:NSMakeRect([xNumber doubleValue], [yNumber doubleValue], 1.0, 1.0)] ;
        }] ;
    } else
#pragma mark - SEGMENTS
    if ([elementType isEqualToString:@"segments"]) {
        elementPath = [NSBezierPath bezierPath];
        NSArray *coordinates = [self getElementValueFor:@"coordinates" atIndex:idx resolvePercentages:YES] ;

        [coordinates enumerateObjectsUsingBlock:^(NSDictionary *aPoint, NSUInteger idx2, __unused BOOL *stop2) {
            NSNumber *xNumber   = aPoint[@"x"] ;
            NSNumber *yNumber   = aPoint[@"y"] ;
            NSNumber *c1xNumber = aPoint[@"c1x"] ;
            NSNumber *c1yNumber = aPoint[@"c1y"] ;
            NSNumber *c2xNumber = aPoint[@"c2x"] ;
            NSNumber *c2yNumber = aPoint[@"c2y"] ;
            BOOL goodForCurve = (c1xNumber) && (c1yNumber) && (c2xNumber) && (c2yNumber) ;
            if (idx2 == 0) {
                [elementPath moveToPoint:NSMakePoint([xNumber doubleValue], [yNumber doubleValue])] ;
            } else if (!goodForCurve) {
                [elementPath lineToPoint:NSMakePoint([xNumber doubleValue], [yNumber doubleValue])] ;
            } else {
                [elementPath curveToPoint:NSMakePoint([xNumber doubleValue], [yNumber doubleValue])
                            controlPoint1:NSMakePoint([c1xNumber doubleValue], [c1yNumber doubleValue])
                            controlPoint2:NSMakePoint([c2xNumber doubleValue], [c2yNumber doubleValue])] ;
            }
        }] ;
        if ([[self getElementValueFor:@"closed" atIndex:idx] boolValue]) {
            [elementPath closePath] ;
        }
    }

    return elementPath ;
}

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

    // because of changes to the elements, skip actions, etc, previous tracking info may change...
    NSUInteger previousTrackedRealIndex = NSNotFound ;
    if (_previousTrackedIndex != NSNotFound) {
        previousTrackedRealIndex = [_elementBounds[_previousTrackedIndex][@"index"] unsignedIntegerValue] ;
        _previousTrackedIndex = NSNotFound ;
    }

    _elementBounds = [[NSMutableArray alloc] init] ;

    // renderPath needs to persist through iterations, so define it here
    __block NSBezierPath *renderPath ;
    __block BOOL         clippingModified = NO ;
    __block BOOL         needMouseTracking = NO ;

    [_elementList enumerateObjectsUsingBlock:^(NSDictionary *element, NSUInteger idx, __unused BOOL *stop) {
        NSBezierPath *elementPath ;
        NSString     *elementType = element[@"type"] ;
        NSString     *action      = [self getElementValueFor:@"action" atIndex:idx] ;

        if (![action isEqualTo:@"skip"]) {
            if (!needMouseTracking) {
                needMouseTracking = [[self getElementValueFor:@"trackMouseEnterExit" atIndex:idx] boolValue] || [[self getElementValueFor:@"trackMouseMove" atIndex:idx] boolValue] ;
            }

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
            if (strokeColor) [strokeColor setStroke] ;

            NSAffineTransform *elementTransform = [self getElementValueFor:@"transformation" atIndex:idx] ;
            if (elementTransform) [elementTransform concat] ;

            NSDictionary *frame = [self getElementValueFor:@"frame" atIndex:idx resolvePercentages:YES] ;
            NSRect frameRect = NSMakeRect([frame[@"x"] doubleValue], [frame[@"y"] doubleValue],
                                          [frame[@"w"] doubleValue], [frame[@"h"] doubleValue]) ;

//             // Converts the corners of a specified rectangle to lie on the center of device pixels, which is useful in compensating for rendering overscanning when the coordinate system has been scaled.
//             frameRect = [self centerScanRect:frameRect] ;

            elementPath = [self pathForElementAtIndex:idx withFrame:frameRect] ;

            // First, if it's not a path, make sure it's not an element which doesn't have a path...

            if (!elementPath) {
    #pragma mark - IMAGE
                if ([elementType isEqualToString:@"image"]) {
                    NSImage *theImage = self->_elementList[idx][@"image"] ;
                    if (theImage && [theImage isKindOfClass:[NSImage class]]) {
                        [self drawImage:theImage
                                atIndex:idx
                                 inRect:frameRect
                              operation:[COMPOSITING_TYPES[CS] unsignedIntValue]] ;
                        [self->_elementBounds addObject:@{
                            @"index"         : @(idx),
                            @"frame"         : [NSValue valueWithRect:frameRect],
                            @"imageByBounds" : [self getElementValueFor:@"trackMouseByBounds" atIndex:idx]
                        }] ;
                    }
                    elementPath = nil ; // shouldn't be necessary, but lets be explicit
                } else
    #pragma mark - TEXT
                if ([elementType isEqualToString:@"text"]) {
                    id textEntry = [self getElementValueFor:@"text" atIndex:idx onlyIfSet:YES] ;
                    if (!textEntry) {
                        textEntry = @"" ;
                    } else if([textEntry isKindOfClass:[NSNumber class]]) {
                        textEntry = [(NSNumber *)textEntry stringValue] ;
                    }

                    if ([textEntry isKindOfClass:[NSString class]]) {
                        NSString *myFont = [self getElementValueFor:@"textFont" atIndex:idx onlyIfSet:NO] ;
                        NSNumber *mySize = [self getElementValueFor:@"textSize" atIndex:idx onlyIfSet:NO] ;
                        NSMutableParagraphStyle *theParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
                        NSString *alignment = [self getElementValueFor:@"textAlignment" atIndex:idx onlyIfSet:NO] ;
                        theParagraphStyle.alignment = [TEXTALIGNMENT_TYPES[alignment] unsignedIntValue] ;
                        NSString *wrap = [self getElementValueFor:@"textLineBreak" atIndex:idx onlyIfSet:NO] ;
                        theParagraphStyle.lineBreakMode = [TEXTWRAP_TYPES[wrap] unsignedIntValue] ;
                        NSDictionary *attributes = @{
                            NSForegroundColorAttributeName : [self getElementValueFor:@"textColor" atIndex:idx onlyIfSet:NO],
                            NSFontAttributeName            : [NSFont fontWithName:myFont size:[mySize doubleValue]],
                            NSParagraphStyleAttributeName  : theParagraphStyle,
                        } ;

                        [(NSString *)textEntry drawInRect:frameRect withAttributes:attributes] ;
                    } else {
                        [(NSAttributedString *)textEntry drawInRect:frameRect] ;
                    }
                    [self->_elementBounds addObject:@{
                        @"index" : @(idx),
                        @"frame" : [NSValue valueWithRect:frameRect]
                    }] ;
                    elementPath = nil ; // shouldn't be necessary, but lets be explicit
                } else
    #pragma mark - VIEW
                if ([elementType isEqualToString:@"view"]) {
                    NSView *externalView = [self getElementValueFor:@"view" atIndex:idx onlyIfSet:NO] ;
                    if ([externalView isKindOfClass:[NSView class]]) {
                        externalView.needsDisplay = YES ;
                        NSNumber *alpha = [self getElementValueFor:@"viewAlpha" atIndex:idx onlyIfSet:YES] ;
                        if (alpha) externalView.alphaValue = [alpha doubleValue] ;
                        [externalView setFrame:frameRect] ;
                        [self->_elementBounds addObject:@{
                            @"index" : @(idx),
                            @"frame" : [NSValue valueWithRect:frameRect]
                        }] ;
                    }
                    elementPath = nil ; // shouldn't be necessary, but lets be explicit
                } else
    #pragma mark - RESETCLIP
                if ([elementType isEqualToString:@"resetClip"]) {
                    [gc restoreGraphicsState] ; // from beginning of enumeration
                    wasClippingChanged = YES ;
                    if (clippingModified) {
                        [gc restoreGraphicsState] ; // from clip action
                        clippingModified = NO ;
                    } else {
                        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - un-nested resetClip at index %lu", USERDATA_TAG, idx + 1]] ;
                    }
                    elementPath = nil ; // shouldn't be necessary, but lets be explicit
                } else {
                    [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - unrecognized type %@ at index %lu", USERDATA_TAG, elementType, idx + 1]] ;
                    elementPath = nil ; // shouldn't be necessary, but lets be explicit
                }
            }
            // Now, if it's still not a path, we don't render it.  But if it is...

    #pragma mark - Render Logic
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

                    BOOL clipToPath = [[self getElementValueFor:@"clipToPath" atIndex:idx] boolValue] ;
                    if ([CLOSED containsObject:elementType] && clipToPath) {
                        [gc saveGraphicsState] ;
                        [renderPath addClip] ;
                    }

                    if (![elementType isEqualToString:@"points"] && ([action isEqualToString:@"fill"] || [action isEqualToString:@"strokeAndFill"])) {
                        NSString     *fillGradient   = [self getElementValueFor:@"fillGradient" atIndex:idx] ;
                        if (![fillGradient isEqualToString:@"none"] && ![renderPath isEmpty]) {
                            NSArray *gradientColors = [self getElementValueFor:@"fillGradientColors" atIndex:idx] ;
                            NSGradient* gradient = [[NSGradient alloc] initWithColors:gradientColors];
                            if ([fillGradient isEqualToString:@"linear"]) {
                                [gradient drawInBezierPath:renderPath angle:[[self getElementValueFor:@"fillGradientAngle" atIndex:idx] doubleValue]] ;
                            } else if ([fillGradient isEqualToString:@"radial"]) {
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

                        NSArray *strokeDashes = [self getElementValueFor:@"strokeDashPattern" atIndex:idx] ;
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

                    if ([CLOSED containsObject:elementType] && clipToPath) {
                        [gc restoreGraphicsState] ;
                    }

                    if ([[self getElementValueFor:@"trackMouseByBounds" atIndex:idx] boolValue]) {
                        NSRect objectBounds = NSZeroRect ;
                        if (![renderPath isEmpty]) objectBounds = [renderPath bounds] ;
                        [self->_elementBounds addObject:@{
                            @"index" : @(idx),
                            @"frame"  : [NSValue valueWithRect:objectBounds],
                        }] ;
                    } else {
                        [self->_elementBounds addObject:@{
                            @"index" : @(idx),
                            @"path"  : renderPath,
                        }] ;
                    }
                    renderPath = nil ;
                } else if (![action isEqualToString:@"build"]) {
                    [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - unrecognized action %@ at index %lu", USERDATA_TAG, action, idx + 1]] ;
                }
            }
            // to keep nesting correct, this was already done if we adjusted clipping this round
            if (!wasClippingChanged) [gc restoreGraphicsState] ;

            if (idx == previousTrackedRealIndex) self->_previousTrackedIndex = [self->_elementBounds count] - 1 ;
        }
    }] ;

    if (clippingModified) [gc restoreGraphicsState] ; // balance our saves

    _mouseTracking = needMouseTracking ;
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

    // fillGradientColors is an array of colors
    } else if ([keyName isEqualToString:@"fillGradientColors"]) {
        newValue = [[NSMutableArray alloc] init] ;
        [(NSMutableArray *)oldValue enumerateObjectsUsingBlock:^(NSDictionary *anItem, NSUInteger idx, __unused BOOL *stop) {
            if ([anItem isKindOfClass:[NSDictionary class]]) {
                [skin pushNSObject:anItem] ;
                lua_pushstring(L, "NSColor") ;
                lua_setfield(L, -2, "__luaSkinType") ;
                anItem = [skin toNSObjectAtIndex:-1] ;
                lua_pop(L, 1) ;
            }
            if (anItem && [anItem isKindOfClass:[NSColor class]] && [(NSColor *)anItem colorUsingColorSpaceName:NSCalibratedRGBColorSpace]) {
                [(NSMutableArray *)newValue addObject:anItem] ;
            } else {
                [LuaSkin logWarn:[NSString stringWithFormat:@"%s:not a proper color at index %lu of fillGradientColor; using Black", USERDATA_TAG, idx + 1]] ;
                [(NSMutableArray *)newValue addObject:[NSColor blackColor]] ;
            }
        }] ;
        if ([(NSMutableArray *)newValue count] < 2) {
            [LuaSkin logWarn:[NSString stringWithFormat:@"%s:fillGradientColor requires at least 2 colors; using default", USERDATA_TAG]] ;
            newValue = [self getDefaultValueFor:keyName onlyIfSet:NO] ;
        }
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
    self.needsDisplay = YES ;
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

    if ([keyName isEqualToString:@"imageAnimationFrame"]) {
        NSImage *theImage = _elementList[index][@"image"] ;
        if (theImage && [theImage isKindOfClass:[NSImage class]]) {
            for (NSBitmapImageRep *representation in [theImage representations]) {
                if ([representation isKindOfClass:[NSBitmapImageRep class]]) {
                    NSNumber *currentFrame = [representation valueForProperty:NSImageCurrentFrame] ;
                    if (currentFrame) {
                        foundObject = currentFrame ;
                        break ;
                    }
                }
            }
        }
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
        } else if ([keyName isEqualToString:@"center"]) {
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
        } else if ([keyName isEqualToString:@"coordinates"]) {
        // make sure we adjust a copy and not the actual items as defined; this is necessary because the copy above just does the top level element; this attribute is an array of objects unlike above attributes
            NSMutableArray *ourCopy = [[NSMutableArray alloc] init] ;
            [(NSMutableArray *)foundObject enumerateObjectsUsingBlock:^(NSMutableDictionary *subItem, NSUInteger idx, __unused BOOL *stop) {
                NSMutableDictionary *targetItem = [[NSMutableDictionary alloc] init] ;
                for (NSString *field in @[ @"x", @"y", @"c1x", @"c1y", @"c2x", @"c2y" ]) {
                    if (subItem[field] && [subItem[field] isKindOfClass:[NSString class]]) {
                        NSNumber *percentage = convertPercentageStringToNumber(subItem[field]) ;
                        CGFloat ourPadding = [field hasSuffix:@"x"] ? paddedWidth : paddedHeight ;
                        targetItem[field] = [NSNumber numberWithDouble:(padding + [percentage doubleValue] * ourPadding)] ;
                    } else {
                        targetItem[field] = subItem[field] ;
                    }
                }
                ourCopy[idx] = targetItem ;
            }] ;
            foundObject = ourCopy ;
        }
    }

    return foundObject ;
}

- (attributeValidity)setElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index to:(id)keyValue {
    if (index > [_elementList count]) return attributeInvalid ;
    keyValue = [self massageKeyValue:keyValue forKey:keyName] ;
    __block attributeValidity validityStatus = isValueValidForAttribute(keyName, keyValue) ;

    switch (validityStatus) {
        case attributeValid: {
            if ([keyName isEqualToString:@"radius"]) {
                if ([keyValue isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            } else if ([keyName isEqualToString:@"center"]) {
                if ([keyValue[@"x"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"x"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field x of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"y"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"y"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field y of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            } else if ([keyName isEqualToString:@"frame"]) {
                if ([keyValue[@"x"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"x"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field x of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"y"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"y"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field y of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"w"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"w"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field w of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"h"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"h"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field h of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            } else if ([keyName isEqualToString:@"coordinates"]) {
                [(NSMutableArray *)keyValue enumerateObjectsUsingBlock:^(NSMutableDictionary *subItem, NSUInteger idx, BOOL *stop) {
                    NSMutableSet *seenFields = [[NSMutableSet alloc] init] ;
                    for (NSString *field in @[ @"x", @"y", @"c1x", @"c1y", @"c2x", @"c2y" ]) {
                        if (subItem[field]) {
                            [seenFields addObject:field] ;
                            if ([subItem[field] isKindOfClass:[NSString class]]) {
                                NSNumber *percentage = convertPercentageStringToNumber(subItem[field]) ;
                                if (!percentage) {
                                    [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field %@ at index %lu of %@ for element %lu", USERDATA_TAG, field, idx + 1, keyName, index + 1]];
                                    validityStatus = attributeInvalid ;
                                    *stop = YES ;
                                    break ;
                                }
                            }
                        }
                    }
                    BOOL goodForPoint = [seenFields containsObject:@"x"] && [seenFields containsObject:@"y"] ;
                    BOOL goodForCurve = goodForPoint && [seenFields containsObject:@"c1x"] && [seenFields containsObject:@"c1y"] &&
                                                        [seenFields containsObject:@"c2x"] && [seenFields containsObject:@"c2y"] ;
                    BOOL partialCurve = ([seenFields containsObject:@"c1x"] || [seenFields containsObject:@"c1y"] ||
                                        [seenFields containsObject:@"c2x"] || [seenFields containsObject:@"c2y"]) && !goodForCurve ;

                    if (!goodForPoint) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:index %lu of %@ for element %lu does not specify a valid point or curve with control points", USERDATA_TAG, idx + 1, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                    } else if (goodForPoint && partialCurve) {
                        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:index %lu of %@ for element %lu does not contain complete curve control points; treating as a singular point", USERDATA_TAG, idx + 1, keyName, index + 1]];
                    }
                }] ;
                if (validityStatus == attributeInvalid) break ;
            } else if ([keyName isEqualToString:@"view"]) {
                NSView *newView = (NSView *)keyValue ;
                NSView *oldView = (NSView *)_elementList[index][keyName] ;
                if (![newView isEqualTo:oldView]) {
                    if (![newView isDescendantOf:self] && ((!newView.window) || (newView.window && ![newView.window isVisible]))) {
                        if (oldView) {
                            [oldView removeFromSuperview] ;
                        }

                        [self addSubview:newView] ;
                    } else {
                        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:view for element %lu is already in use", USERDATA_TAG, index + 1]] ;
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            } else if ([keyName isEqualToString:@"imageAnimationFrame"]) {
                if ([[self getElementValueFor:@"imageAnimates" atIndex:index] boolValue]) {
                    [LuaSkin logWarn:[NSString stringWithFormat:@"%s:%@ cannot be changed when element %lu is animating", USERDATA_TAG, keyName, index + 1]] ;
                    validityStatus = attributeInvalid ;
                    break ;
                } else {
                    NSImage *theImage = _elementList[index][@"image"] ;
                    if (theImage && [theImage isKindOfClass:[NSImage class]]) {
                        for (NSBitmapImageRep *representation in [theImage representations]) {
                            if ([representation isKindOfClass:[NSBitmapImageRep class]]) {
                                NSNumber *maxFrames = [representation valueForProperty:NSImageFrameCount] ;
                                if (maxFrames) {
                                    lua_Integer newFrame = [keyValue integerValue] % [maxFrames integerValue] ;
                                    while (newFrame < 0) newFrame = [maxFrames integerValue] + newFrame ;
                                    [representation setProperty:NSImageCurrentFrame withValue:[NSNumber numberWithInteger:newFrame]] ;
                                    break ;
                                }
                            }
                        }
                    }
                }
            } else if ([keyName isEqualToString:@"imageAnimates"]) {
                NSImage *currentImage = _elementList[index][@"image"] ;
                if (currentImage && [currentImage isKindOfClass:[NSImage class]]) {
                    BOOL shouldAnimate = [keyValue boolValue] ;
                    ASMGifAnimator *animator = [_imageAnimations objectForKey:currentImage] ;
                    if (shouldAnimate) {
                        if (!animator) {
                            animator = [[ASMGifAnimator alloc] initWithImage:currentImage forCanvas:self] ;
                            if (animator) [_imageAnimations setObject:animator forKey:currentImage] ;
                        }
                        if (animator) [animator startAnimating] ;
                    } else {
                        if (animator) [animator stopAnimating] ;
                    }
                }
            } else if ([keyName isEqualToString:@"image"]) {
                NSImage *currentImage = _elementList[index][@"image"] ;
                if (currentImage && [currentImage isKindOfClass:[NSImage class]]) {
                    ASMGifAnimator *animator = [_imageAnimations objectForKey:currentImage] ;
                    if (animator) {
                        [animator stopAnimating] ;
                        [_imageAnimations removeObjectForKey:currentImage] ;
                    }
                }
                BOOL shouldAnimate = [[self getElementValueFor:@"imageAnimates" atIndex:index] boolValue] ;
                if (shouldAnimate) {
                    ASMGifAnimator *animator = [[ASMGifAnimator alloc] initWithImage:keyValue forCanvas:self] ;
                    if (animator) {
                        [_imageAnimations setObject:animator forKey:currentImage] ;
                        [animator startAnimating] ;
                    }
                }
            }

            if (![keyName isEqualToString:@"imageAnimationFrame"]) _elementList[index][keyName] = keyValue ;

            // add defaults, if not already present, for type (recurse into this method as needed)
            if ([keyName isEqualToString:@"type"]) {
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
            if ([keyName isEqualToString:@"view"]) {
                NSView *oldView = (NSView *)_elementList[index][keyName] ;
                [oldView removeFromSuperview] ;
            } else if ([keyName isEqualToString:@"imageAnimationFrame"]) {
                if ([[self getElementValueFor:@"imageAnimates" atIndex:index] boolValue]) {
                    [LuaSkin logWarn:[NSString stringWithFormat:@"%s:%@ cannot be changed when element %lu is animating", USERDATA_TAG, keyName, index + 1]] ;
                    validityStatus = attributeInvalid ;
                    break ;
                } else {
                    NSImage *theImage = _elementList[index][@"image"] ;
                    if (theImage && [theImage isKindOfClass:[NSImage class]]) {
                        NSNumber *imageFrame = [self getDefaultValueFor:@"imageAnimationFrame" onlyIfSet:NO] ;
                        for (NSBitmapImageRep *representation in [theImage representations]) {
                            if ([representation isKindOfClass:[NSBitmapImageRep class]]) {
                                NSNumber *maxFrames = [representation valueForProperty:NSImageFrameCount] ;
                                if (maxFrames) {
                                    lua_Integer newFrame = [imageFrame integerValue] % [maxFrames integerValue] ;
                                    [representation setProperty:NSImageCurrentFrame withValue:[NSNumber numberWithInteger:newFrame]] ;
                                    break ;
                                }
                            }
                        }
                    }
                }
            } else if ([keyName isEqualToString:@"imageAnimates"]) {
                NSImage *currentImage = _elementList[index][@"image"] ;
                if (currentImage && [currentImage isKindOfClass:[NSImage class]]) {
                    BOOL shouldAnimate = [[self getDefaultValueFor:@"imageAnimates" onlyIfSet:NO] boolValue] ;
                    ASMGifAnimator *animator = [_imageAnimations objectForKey:currentImage] ;
                    if (shouldAnimate) {
                        if (!animator) {
                            animator = [[ASMGifAnimator alloc] initWithImage:currentImage forCanvas:self] ;
                            if (animator) [_imageAnimations setObject:animator forKey:currentImage] ;
                        }
                        if (animator) [animator startAnimating] ;
                    } else {
                        if (animator) [animator stopAnimating] ;
                    }
                }
            } else if ([keyName isEqualToString:@"image"]) {
                NSImage *currentImage = _elementList[index][@"image"] ;
                if (currentImage && [currentImage isKindOfClass:[NSImage class]]) {
                    ASMGifAnimator *animator = [_imageAnimations objectForKey:currentImage] ;
                    if (animator) {
                        [animator stopAnimating] ;
                        [_imageAnimations removeObjectForKey:currentImage] ;
                    }
                }
            }

            [(NSMutableDictionary *)_elementList[index] removeObjectForKey:keyName] ;
            break ;
        case attributeInvalid:
            break ;
        default:
            [LuaSkin logWarn:@"unexpected validity status returned; notify developers"] ;
            break ;
    }
    self.needsDisplay = YES ;
    return validityStatus ;
}

// see https://www.stairways.com/blog/2009-04-21-nsimage-from-nsview
- (NSImage *)imageWithSubviews {
    NSBitmapImageRep *bir = [self bitmapImageRepForCachingDisplayInRect:self.bounds];
    [bir setSize:self.bounds.size];
    [self cacheDisplayInRect:self.bounds toBitmapImageRep:bir];

    NSImage* image = [[NSImage alloc]initWithSize:self.bounds.size] ;
    [image addRepresentation:bir];
    return image;
}

@end

#pragma mark - Module Functions

static int canvas_newView(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;

    ASMCanvasView *canvasView = [[ASMCanvasView alloc] initWithFrame:frameRect];
    if (canvasView) {
        [skin pushNSObject:canvasView] ;
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

static int default_textAttributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_newtable(L) ;
    NSString *fontName = languageDictionary[@"textFont"][@"default"] ;
    if (fontName) {
        [skin pushNSObject:[NSFont fontWithName:fontName
                                           size:[languageDictionary[@"textSize"][@"default"] doubleValue]]] ;
        lua_setfield(L, -2, "font") ;
        [skin pushNSObject:languageDictionary[@"textColor"][@"default"]] ;
        lua_setfield(L, -2, "color") ;
        [skin pushNSObject:[NSParagraphStyle defaultParagraphStyle]] ;
        lua_setfield(L, -2, "paragraphStyle") ;
    } else {
        return luaL_error(L, "%s:unable to get default font name from element language dictionary", USERDATA_TAG) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int canvas_alphaValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMCanvasView *canvasView = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, canvasView.alphaValue) ;
    } else {
        CGFloat newAlpha = luaL_checknumber(L, 2);
        canvasView.alphaValue = ((newAlpha < 0.0) ? 0.0 : ((newAlpha > 1.0) ? 1.0 : newAlpha)) ;
        lua_pushvalue(L, 1);
    }
    return 1 ;
}

static int canvas_hidden(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMCanvasView *canvasView = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, canvasView.hidden) ;
    } else {
        canvasView.hidden = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int canvas_getTextElementSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;
    int        textIndex    = 2 ;
    NSUInteger elementIndex = NSNotFound ;
    if (lua_gettop(L) == 3) {
        if (lua_type(L, 3) == LUA_TSTRING) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TSTRING, LS_TBREAK] ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TUSERDATA, "hs.styledtext", LS_TBREAK] ;
        }
        elementIndex = (NSUInteger)lua_tointeger(L, 2) - 1 ;
        if ((NSInteger)elementIndex < 0 || elementIndex >= [canvasView.elementList count]) {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index %ld out of bounds", elementIndex + 1] UTF8String]) ;
        }
        textIndex = 3 ;
    } else {
        if (lua_type(L, 2) == LUA_TSTRING) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.styledtext", LS_TBREAK] ;
        }
    }
    NSSize theSize = NSZeroSize ;
    NSString *theText = [skin toNSObjectAtIndex:textIndex] ;

    if (lua_type(L, textIndex) == LUA_TSTRING) {
        NSString *myFont = (elementIndex == NSNotFound) ?
            [canvasView getDefaultValueFor:@"textFont" onlyIfSet:NO] :
            [canvasView getElementValueFor:@"textFont" atIndex:elementIndex onlyIfSet:NO] ;
        NSNumber *mySize = (elementIndex == NSNotFound) ?
            [canvasView getDefaultValueFor:@"textSize" onlyIfSet:NO] :
            [canvasView getElementValueFor:@"textSize" atIndex:elementIndex onlyIfSet:NO] ;
        NSMutableParagraphStyle *theParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        NSString *alignment = (elementIndex == NSNotFound) ?
            [canvasView getDefaultValueFor:@"textAlignment" onlyIfSet:NO] :
            [canvasView getElementValueFor:@"textAlignment" atIndex:elementIndex onlyIfSet:NO] ;
        theParagraphStyle.alignment = [TEXTALIGNMENT_TYPES[alignment] unsignedIntValue] ;
        NSString *wrap = (elementIndex == NSNotFound) ?
            [canvasView getDefaultValueFor:@"textLineBreak" onlyIfSet:NO] :
            [canvasView getElementValueFor:@"textLineBreak" atIndex:elementIndex onlyIfSet:NO] ;
        theParagraphStyle.lineBreakMode = [TEXTWRAP_TYPES[wrap] unsignedIntValue] ;
        NSColor *color = (elementIndex == NSNotFound) ?
            [canvasView getDefaultValueFor:@"textColor" onlyIfSet:NO] :
            [canvasView getElementValueFor:@"textColor" atIndex:elementIndex onlyIfSet:NO] ;
        NSDictionary *attributes = @{
            NSForegroundColorAttributeName : color,
            NSFontAttributeName            : [NSFont fontWithName:myFont size:[mySize doubleValue]],
            NSParagraphStyleAttributeName  : theParagraphStyle,
        } ;
        theSize = [theText sizeWithAttributes:attributes] ;
    } else {
//       NSAttributedString *theText = [skin luaObjectAtIndex:textIndex toClass:"NSAttributedString"] ;
      theSize = [(NSAttributedString *)theText size] ;
    }
    [skin pushNSSize:theSize] ;
    return 1 ;
}

static int canvas_canvasTransformation(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:canvasView.canvasTransform] ;
    } else {
        NSAffineTransform *transform = [NSAffineTransform transform] ;
        if (lua_type(L, 2) == LUA_TTABLE) transform = [skin luaObjectAtIndex:2 toClass:"NSAffineTransform"] ;
        canvasView.canvasTransform = transform ;
        canvasView.needsDisplay = YES ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int canvas_mouseCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;

    // We're either removing callback(s), or setting new one(s). Either way, remove existing.
    canvasView.mouseCallbackRef = [skin luaUnref:refTable ref:canvasView.mouseCallbackRef];
    canvasView.previousTrackedIndex = NSNotFound ;

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        canvasView.mouseCallbackRef = [skin luaRef:refTable] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

static int canvas_canvasMouseEvents(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, canvasView.canvasMouseDown) ;
        lua_pushboolean(L, canvasView.canvasMouseUp) ;
        lua_pushboolean(L, canvasView.canvasMouseEnterExit) ;
        lua_pushboolean(L, canvasView.canvasMouseMove) ;
        return 4 ;
    } else {
        if (lua_type(L, 2) == LUA_TBOOLEAN) {
            canvasView.canvasMouseDown = (BOOL)lua_toboolean(L, 2) ;
        }
        if (lua_type(L, 3) == LUA_TBOOLEAN) {
            canvasView.canvasMouseUp = (BOOL)lua_toboolean(L, 3) ;
        }
        if (lua_type(L, 4) == LUA_TBOOLEAN) {
            canvasView.canvasMouseEnterExit = (BOOL)lua_toboolean(L, 4) ;
        }
        if (lua_type(L, 5) == LUA_TBOOLEAN) {
            canvasView.canvasMouseMove = (BOOL)lua_toboolean(L, 5) ;
        }

        lua_pushvalue(L, 1) ;
        return 1;
    }
}

static int canvas_canvasAsImage(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK] ;

    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;
    NSImage *image = [canvasView imageWithSubviews] ;
    [skin pushNSObject:image] ;
    return 1;
}

static int canvas_wantsLayer(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;

    if (lua_type(L, 2) != LUA_TNONE) {
        [canvasView setWantsLayer:(BOOL)lua_toboolean(L, 2)];
        canvasView.needsDisplay = YES ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, (BOOL)[canvasView wantsLayer]) ;
    }

    return 1;
}

static int canvas_canvasDefaultFor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;
    NSString *keyName = [skin toNSObjectAtIndex:2] ;

    if (!languageDictionary[keyName]) {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"attribute name %@ unrecognized", keyName] UTF8String]) ;
    }

    id attributeDefault = [canvasView getDefaultValueFor:keyName onlyIfSet:NO] ;
    if (!attributeDefault) {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"attribute %@ has no default value", keyName] UTF8String]) ;
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
                    return luaL_argerror(L, 3, [[NSString stringWithFormat:@"invalid argument type for %@ specified", keyName] UTF8String]) ;
                } else {
                    return luaL_argerror(L, 2, [[NSString stringWithFormat:@"attribute default for %@ cannot be changed", keyName] UTF8String]) ;
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
    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;
    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = (lua_gettop(L) == 3) ? (lua_tointeger(L, 3) - 1) : (NSInteger)elementCount ;

    if (tablePosition < 0 || tablePosition > (NSInteger)elementCount) {
        return luaL_argerror(L, 3, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
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
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalid type %@; must be one of %@", elementType, [ALL_TYPES componentsJoinedByString:@", "]] UTF8String]) ;
        }
    } else {
        return luaL_argerror(L, 2, "invalid element definition; must contain key-value pairs");
    }

    canvasView.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int canvas_removeElementAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;
    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = (lua_gettop(L) == 2) ? (lua_tointeger(L, 2) - 1) : (NSInteger)elementCount - 1 ;

    if (tablePosition < 0 || tablePosition >= (NSInteger)elementCount) {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
    }

    NSUInteger realIndex = (NSUInteger)tablePosition ;
    if (realIndex < elementCount && canvasView.elementList[realIndex] && canvasView.elementList[realIndex][@"view"]) {
        [canvasView.elementList[realIndex][@"view"] removeFromSuperview] ;
    }
    [canvasView.elementList removeObjectAtIndex:realIndex] ;

    canvasView.needsDisplay = YES ;
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
    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;
    NSString        *keyName      = [skin toNSObjectAtIndex:3] ;

    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = lua_tointeger(L, 2) - 1 ;

    BOOL            resolvePercentages = NO ;

    if (tablePosition < 0 || tablePosition >= (NSInteger)elementCount) {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
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
            return luaL_argerror(L, 3, [[NSString stringWithFormat:@"attribute name %@ unrecognized", keyName] UTF8String]) ;
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
                return luaL_argerror(L, 4, [[NSString stringWithFormat:@"invalid argument type for %@ specified", keyName] UTF8String]) ;
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
    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;
    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = lua_tointeger(L, 2) - 1 ;

    if (tablePosition < 0 || tablePosition >= (NSInteger)elementCount) {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
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
    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;
    lua_pushinteger(L, (lua_Integer)[canvasView.elementList count]) ;
    return 1 ;
}

static int canvas_canvasDefaults(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;
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
    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;

    NSMutableSet *list = [[NSMutableSet alloc] initWithArray:[(NSDictionary *)canvasView.canvasDefaults allKeys]] ;
    if ((lua_gettop(L) == 2) && lua_toboolean(L, 2)) {
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
    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;
    [skin pushNSObject:canvasView.elementList withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

static int canvas_elementBoundsAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TBREAK] ;
    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;

    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = (lua_tointeger(L, 2) - 1) ;

    if (tablePosition < 0 || tablePosition > (NSInteger)elementCount - 1) {
        return luaL_argerror(L, 3, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
    }

    NSUInteger   idx         = (NSUInteger)tablePosition ;
    NSRect       boundingBox = NSZeroRect ;
    NSBezierPath *itemPath   = [canvasView pathForElementAtIndex:idx] ;
    if (itemPath) {
        if ([itemPath isEmpty]) {
            boundingBox = NSZeroRect ;
        } else {
            boundingBox = [itemPath bounds] ;
        }
    } else {
        NSString *itemType = canvasView.elementList[idx][@"type"] ;
        if ([itemType isEqualToString:@"image"] || [itemType isEqualToString:@"text"] || [itemType isEqualToString:@"view"]) {
            NSDictionary *frame = [canvasView getElementValueFor:@"frame"
                                                         atIndex:idx
                                              resolvePercentages:YES] ;
            boundingBox = NSMakeRect([frame[@"x"] doubleValue], [frame[@"y"] doubleValue],
                                     [frame[@"w"] doubleValue], [frame[@"h"] doubleValue]) ;
        } else {
            lua_pushnil(L) ;
            return 1 ;
        }
    }
    [skin pushNSRect:boundingBox] ;
    return 1 ;
}

static int canvas_assignElementAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TNIL,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    ASMCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;

    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = (lua_gettop(L) == 3) ? (lua_tointeger(L, 3) - 1) : (NSInteger)elementCount ;

    if (tablePosition < 0 || tablePosition > (NSInteger)elementCount) {
        return luaL_argerror(L, 3, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
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
                NSUInteger realIndex = (NSUInteger)tablePosition ;
                if (realIndex < elementCount && canvasView.elementList[realIndex] && canvasView.elementList[realIndex][@"view"]) {
                    [canvasView.elementList[realIndex][@"view"] removeFromSuperview] ;
                }
                canvasView.elementList[realIndex] = [[NSMutableDictionary alloc] init] ;
                [element enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, id keyValue, __unused BOOL *stop) {
                    // skip type in here to minimize the need to copy in defaults just to be overwritten
                    if (![keyName isEqualTo:@"type"]) [canvasView setElementValueFor:keyName atIndex:realIndex to:keyValue] ;
                }] ;
                [canvasView setElementValueFor:@"type" atIndex:realIndex to:elementType] ;
            } else {
                return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalid type %@; must be one of %@", elementType, [ALL_TYPES componentsJoinedByString:@", "]] UTF8String]) ;
            }
        } else {
            return luaL_argerror(L, 2, "invalid element definition; must contain key-value pairs");
        }
    }

    canvasView.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants

static int pushCompositeTypes(__unused lua_State *L) {
    [[LuaSkin shared] pushNSObject:COMPOSITING_TYPES] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMCanvasView(lua_State *L, id obj) {
    ASMCanvasView *value = obj;
    value.referenceCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMCanvasView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toASMCanvasViewFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMCanvasView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMCanvasView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMCanvasView *obj = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;
    NSString *title ;
    title = NSStringFromRect(obj.frame) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMCanvasView *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMCanvasView"] ;
        ASMCanvasView *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMCanvasView"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMCanvasView *theView = get_objectFromUserdata(__bridge_transfer ASMCanvasView, L, 1, USERDATA_TAG) ;
    if (theView) {
        theView.referenceCount-- ;
        if (theView.referenceCount == 0) {
            [theView.elementList enumerateObjectsUsingBlock:^(NSMutableDictionary *element, __unused NSUInteger idx, __unused BOOL *stop) {
                NSView *subview = element[@"view"] ;
                if (subview) {
#ifdef VIEW_DEBUG
                    [LuaSkin logWarn:[NSString stringWithFormat:@"%s.__gc removing view with frame %@ at index %lu", USERDATA_TAG, NSStringFromRect(subview.frame), idx]] ;
#endif
                    [subview removeFromSuperview] ;
                    element[@"view"] = nil ;
                }
            }] ;
#ifdef VIEW_DEBUG
            for (NSView *subview in theView.subviews) {
                [LuaSkin logWarn:[NSString stringWithFormat:@"%s.__gc orphan subview with frame %@ found after element subview purge", USERDATA_TAG, NSStringFromRect(subview.frame)]] ;
            }
#endif
            theView.subviews = [NSArray array] ;
            theView.mouseCallbackRef = [skin luaUnref:refTable ref:theView.mouseCallbackRef] ;
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

// // Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
// affects drawing elements
    {"alphaValue",          canvas_alphaValue},
    {"assignElement",       canvas_assignElementAtIndex},
    {"canvasElements",      canvas_canvasElements},
    {"canvasDefaults",      canvas_canvasDefaults},
    {"canvasMouseEvents",   canvas_canvasMouseEvents},
    {"canvasDefaultKeys",   canvas_canvasDefaultKeys},
    {"canvasDefaultFor",    canvas_canvasDefaultFor},
    {"elementAttribute",    canvas_elementAttributeAtIndex},
    {"elementBounds",       canvas_elementBoundsAtIndex},
    {"elementCount",        canvas_elementCount},
    {"elementKeys",         canvas_elementKeysAtIndex},
    {"imageFromCanvas",     canvas_canvasAsImage},
    {"insertElement",       canvas_insertElementAtIndex},
    {"minimumTextSize",     canvas_getTextElementSize},
    {"removeElement",       canvas_removeElementAtIndex},

    {"hidden",              canvas_hidden},
    {"mouseCallback",       canvas_mouseCallback},
    {"transformation",      canvas_canvasTransformation},
    {"wantsLayer",          canvas_wantsLayer},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"defaultTextStyle",     default_textAttributes},
    {"elementSpec",          dumpLanguageDictionary},
    {"newView",              canvas_newView},

    {NULL,                   NULL}
};

int luaopen_hs__asm_enclosure_canvas_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    languageDictionary = defineLanguageDictionary() ;

    [skin registerPushNSHelper:pushASMCanvasView         forClass:"ASMCanvasView"];
    [skin registerLuaObjectHelper:toASMCanvasViewFromLua forClass:"ASMCanvasView"
                                              withUserdataMapping:USERDATA_TAG];

    pushCompositeTypes(L) ;      lua_setfield(L, -2, "compositeTypes") ;

    return 1;
}
