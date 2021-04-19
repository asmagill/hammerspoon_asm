@import Cocoa ;
@import LuaSkin ;

@import Darwin.C.tgmath ;

// these two need to track, so I declare them here to keep them together to simplify
// remembering to synchronize them
typedef NS_ENUM( NSUInteger, t_commandTypes ) {
  c__special = 0, // was used for tests with compressed strokes into single path; now uncertain about it...
  c_forward,
  c_back,
  c_left,
  c_right,
  c_setpos,
  c_setxy,
  c_setx,
  c_sety,
  c_setheading,
  c_home,
  c_pendown,
  c_penup,
  c_penpaint,
  c_penerase,
  c_penreverse,
  c_setpensize,
  c_arc,
  c_setscrunch,
  c_setlabelheight,
  c_setlabelfont,
  c_label,
  c_setpencolor,
  c_setbackground,
  c_setpalette,
  c_fillstart,
  c_fillend
} ;

//  name                  synonyms       visual  type(s)
#define t_wrappedCommands @[ \
    @[ @"_special",       @[],           @(YES)  ],                           \
    @[ @"forward",        @[ @"fd" ],    @(YES), @"number" ],                 \
    @[ @"back",           @[ @"bk" ],    @(YES), @"number" ],                 \
    @[ @"left",           @[ @"lt" ],    @(NO),  @"number" ],                 \
    @[ @"right",          @[ @"rt" ],    @(NO),  @"number" ],                 \
    @[ @"setpos",         @[],           @(YES), @[ @"number", @"number" ] ], \
    @[ @"setxy",          @[],           @(YES), @"number", @"number" ],      \
    @[ @"setx",           @[],           @(YES), @"number" ],                 \
    @[ @"sety",           @[],           @(YES), @"number" ],                 \
    @[ @"setheading",     @[ @"seth" ],  @(NO),  @"number" ],                 \
    @[ @"home",           @[],           @(YES), ],                           \
    @[ @"pendown",        @[ @"pd" ],    @(NO),  ],                           \
    @[ @"penup",          @[ @"pu" ],    @(NO),  ],                           \
    @[ @"penpaint",       @[ @"ppt" ],   @(NO),  ],                           \
    @[ @"penerase",       @[ @"pe" ],    @(NO),  ],                           \
    @[ @"penreverse",     @[ @"px" ],    @(NO),  ],                           \
    @[ @"setpensize",     @[],           @(NO),  @[ @"number", @"number" ] ], \
    @[ @"arc",            @[],           @(YES), @"number", @"number" ],      \
    @[ @"setscrunch",     @[],           @(NO),  @"number", @"number" ],      \
    @[ @"setlabelheight", @[],           @(NO),  @"number" ],                 \
    @[ @"setlabelfont",   @[],           @(NO),  @"string" ],                 \
    @[ @"label",          @[],           @(YES), @"string" ],                 \
    @[ @"setpencolor",    @[ @"setpc" ], @(YES), @"color" ],                  \
    @[ @"setbackground",  @[ @"setbg" ], @(YES), @"color" ],                  \
    @[ @"setpalette",     @[],           @(NO),  @"number", @"color" ],       \
    @[ @"fillstart",      @[],           @(NO)   ],                           \
    @[ @"fillend",        @[],           @(YES), @"color" ],                  \
]

//     @"fill",

// TODO:

//   document -- always my bane

//   savepict should allow for type -- raw (default), lua, logo
//      logo limits colors to 3 numbers (ignore alpha or NSColor tables)
//      logo ignores mark type, converts markfill to filled and inserts it where mark was wrapping everything from mark forward
//           skips very next command (which resets our penColor)
//   loadpict only parses raw version; other two are for importing elsewhere

static const char * const USERDATA_TAG = "hs.canvas.turtle" ;
static int                refTable   = LUA_NOREF ;
static int                fontMapRef = LUA_NOREF ;

static const CGFloat      offScreenPadding = 0.01 ; // keep 1% space around actual content

static void *myKVOContext = &myKVOContext ; // See http://nshipster.com/key-value-observing/

static NSArray        *wrappedCommands ;
static NSArray        *defaultColorPalette ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

NSColor *NSColorFromHexColorString(NSString *colorString) {
    NSColor      *result   = nil ;
    unsigned int colorCode = 0 ;

    if (colorString) {
         colorString = [colorString stringByReplacingOccurrencesOfString:@"#" withString:@"0x"] ;
         NSScanner* scanner = [NSScanner scannerWithString:colorString] ;
         [scanner scanHexInt:&colorCode] ;
    }

    result = [NSColor colorWithCalibratedRed:(CGFloat)(((colorCode >> 16)  & 0xff)) / 0xff
                                       green:(CGFloat)(((colorCode >>  8)  & 0xff)) / 0xff
                                        blue:(CGFloat)(( colorCode         & 0xff)) / 0xff
                                       alpha:1.0 ] ;
    return result ;
}

@interface HSCanvasTurtleView : NSView
@property (nonatomic)           int                    selfRefCount ;

@property (nonatomic, readonly) NSMutableArray         *commandList ;

@property (nonatomic)           NSSize                 turtleSize ;
@property (nonatomic)           NSImage                *turtleImage ;
@property (nonatomic)           BOOL                   turtleVisible ;

// current turtle state -- should be updated as commands appended
@property (nonatomic)           CGFloat                tX ;
@property (nonatomic)           CGFloat                tY ;
@property (nonatomic)           CGFloat                tHeading ;
@property (nonatomic, readonly) BOOL                   tPenDown ;
@property (nonatomic, readonly) NSCompositingOperation tPenMode ;
@property (nonatomic, readonly) CGFloat                tPenSize ;
@property (nonatomic, readonly) CGFloat                tScaleX ;
@property (nonatomic, readonly) CGFloat                tScaleY ;

@property (nonatomic, readonly) CGFloat                labelFontSize ;
@property (nonatomic, readonly) NSString               *labelFontName ;

@property (nonatomic, readonly) NSColor                *pColor ;
@property (nonatomic, readonly) NSColor                *bColor ;
@property (nonatomic, readonly) NSUInteger             pPaletteIdx ;
@property (nonatomic, readonly) NSUInteger             bPaletteIdx ;

@property (nonatomic, readonly) NSMutableArray         *colorPalette ;

@property (nonatomic)           CGFloat                translateX ;
@property (nonatomic)           CGFloat                translateY ;

@property (nonatomic)           BOOL                   renderingPaused ;
@property (nonatomic)           BOOL                   neverYield ;
@property (nonatomic)           lua_Integer            yieldRatio ;
@end

@implementation HSCanvasTurtleView {
    BOOL                   _neverRender ;
    NSWindow               *_parentWindow ;

    // things clean doesn't reset -- this is where drawRect starts before rendering anything
    CGFloat                _tInitX ;
    CGFloat                _tInitY ;
    CGFloat                _tInitHeading ;
    BOOL                   _tInitPenDown ;
    NSCompositingOperation _tInitPenMode ;
    CGFloat                _tInitPenSize ;
    CGFloat                _tInitScaleX ;
    CGFloat                _tInitScaleY ;

    CGFloat                _initLabelFontSize ;
    NSString               *_initLabelFontName ;
    NSColor                *_pInitColor ;
    NSColor                *_bInitColor ;

    NSImage                *_offScreen ;
    CGFloat                _offScreenWidth ;
    CGFloat                _offScreenHeight ;
    NSUInteger             _offScreenIdx ;
}

#pragma mark - Required for Canvas compatible view -

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect] ;
    if (self) {
        _selfRefCount = 0 ;

        _parentWindow    = nil ;
        _neverRender     = YES ;
        _renderingPaused = NO ;
        _neverYield      = NO ;
        _yieldRatio      = 500 ;

        _colorPalette    = [defaultColorPalette mutableCopy] ;

        _translateX      = 0.0 ;
        _translateY      = 0.0 ;

        self.wantsLayer = YES ;
        [self resetTurtleView] ;
    }
    return self ;
}

// This is the default, but I put it here as a reminder since almost everything else in
// Hammerspoon *does* use a flipped coordinate system
- (BOOL)isFlipped { return NO ; }

- (void)drawRect:(__unused NSRect)dirtyRect {
    if (!(_neverRender || _renderingPaused)) {
        [self updateOffScreenImage] ;
        self.layer.backgroundColor = _bColor.CGColor ;

        NSGraphicsContext *gc = [NSGraphicsContext currentContext];
        [gc saveGraphicsState] ;

// // Shows boundary of _offScreen image for debugging purposes
//         [_pInitColor setStroke] ;
//         [[NSBezierPath bezierPathWithRect:NSMakeRect(
//             (self.frame.size.width - _offScreenWidth)   / 2.0 + _translateX,
//             (self.frame.size.height - _offScreenHeight) / 2.0 + _translateY,
//             _offScreenWidth,
//             _offScreenHeight
//         )] stroke] ;

        NSRect fromRect = NSMakeRect(
            (_offScreenWidth  - self.frame.size.width)  / 2.0 - _translateX,
            (_offScreenHeight - self.frame.size.height) / 2.0 - _translateY,
            self.frame.size.width,
            self.frame.size.height
        ) ;

        [_offScreen drawAtPoint:NSZeroPoint
                        fromRect:fromRect
                       operation:NSCompositingOperationSourceOver
                        fraction:1.0] ;

        if (_turtleVisible) {
            NSPoint location = NSMakePoint(
                _tX + self.frame.size.width  / 2.0 + _translateX,
                _tY + self.frame.size.height / 2.0 + _translateY
            ) ;
            NSAffineTransform *turtleRotation = [[NSAffineTransform alloc] init] ;
            [turtleRotation translateXBy:location.x yBy:location.y] ;
            [turtleRotation rotateByDegrees:(360 - _tHeading)] ;

            [gc saveGraphicsState];

            [turtleRotation concat] ;
            [_turtleImage drawAtPoint:NSMakePoint((_turtleSize.width / -2.0), (_turtleSize.height / -2.0))
                             fromRect:NSZeroRect
                            operation:NSCompositingOperationSourceOver
                             fraction:1.0] ;

            [gc restoreGraphicsState] ;
        }

        [gc restoreGraphicsState] ;
    }
}

#pragma mark   Only required if we want to know when we are hidden
// unless we add our own methods for this, will require updates to hs.canvas to toggle this
// during skip action

- (void)viewDidHide {
    _neverRender = YES ;
}

- (void)viewDidUnhide {
    _neverRender = !((self.window != nil) && self.window.visible) ;
}


#pragma mark   Only required if we want to know when owner is visible

// All this crap just to be notified when the window changes visibility...
// See also userdata_gc which calls removeObserver

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                                                     change:(NSDictionary *)change
                                                    context:(void *)context {
    if (context == myKVOContext && [keyPath isEqualToString:@"visible"]) {
        _neverRender = !self.window.visible ;
        self.needsDisplay = !(_neverRender || _renderingPaused) ;
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context] ;
    }
}

- (void)removeObserver {
    if (_parentWindow) {
        [_parentWindow removeObserver:self forKeyPath:@"visible" context:myKVOContext] ;
        _parentWindow = nil ;
    }
}

- (void)viewDidMoveToWindow {
    if (self.window) {
        if (_parentWindow && ![_parentWindow isEqualTo:self.window]) {
            [self removeObserver] ;
        }
        if (!_parentWindow) {
            _parentWindow = self.window ;
            [_parentWindow addObserver:self forKeyPath:@"visible" options:0 context:myKVOContext] ;
        }
        _neverRender = !self.window.visible ;
    } else {
        [self removeObserver] ;
        _neverRender = YES ;
    }
}

#pragma mark - HSTurtleView Specific Methods -

- (NSImage *)defaultTurtleImage {
    return [NSImage imageNamed:NSImageNameTouchBarColorPickerFont] ;
}

- (void)resetTurtleView {
    _tX       = 0.0 ;
    _tY       = 0.0 ;
    _tHeading = 0.0 ;
    _tPenDown = YES ;
    _tPenMode = NSCompositingOperationSourceOver ;
    _tPenSize = NSBezierPath.defaultLineWidth ;
    _tScaleX  = 1.0 ;
    _tScaleY  = 1.0 ;

    _labelFontSize = 14.0 ;
    _labelFontName = @"sans-serif" ;

    _turtleVisible = YES ;
    _turtleSize    = NSMakeSize(45, 45) ;
    _turtleImage   = [self defaultTurtleImage] ;

    _pPaletteIdx  = 0 ;
    _bPaletteIdx  = 7 ;
    _pColor       = _colorPalette[_pPaletteIdx][1] ;
    _bColor       = _colorPalette[_bPaletteIdx][1] ;

    [self resetForClean] ;
}

- (void)resetForClean {
    _tInitX       = _tX ;
    _tInitY       = _tY ;
    _tInitHeading = _tHeading ;
    _tInitPenDown = _tPenDown ;
    _tInitPenMode = _tPenMode ;
    _tInitPenSize = _tPenSize ;
    _tInitScaleX  = _tScaleX ;
    _tInitScaleY  = _tScaleY ;

    _initLabelFontSize = _labelFontSize ;
    _initLabelFontName = _labelFontName ;

    _pInitColor   = _pColor ;
    _bInitColor   = _bColor ;

    _commandList  = [NSMutableArray array] ;

    _offScreenWidth  = _turtleSize.width  * (1.0 + offScreenPadding * 2.0) ;
    _offScreenHeight = _turtleSize.height * (1.0 + offScreenPadding * 2.0) ;
    _offScreenIdx    = 0 ;
    _offScreen       = [[NSImage alloc] initWithSize:NSMakeSize(_offScreenWidth, _offScreenHeight)] ;

    self.layer.backgroundColor = _bColor.CGColor ;
    self.needsDisplay = !(_neverRender || _renderingPaused) ;
}

- (NSColor *)colorFromArgument:(NSObject *)argument withState:(lua_State *)L {
    // fallback in case nothing matches, though they *should* already be validated in check:forExpectedType:
    NSColor *result = _colorPalette[0][1] ;

    if ([argument isKindOfClass:[NSNumber class]]) {
        NSUInteger paletteColorIdx = ((NSNumber *)argument).unsignedIntegerValue ;
        if (paletteColorIdx >= _colorPalette.count) paletteColorIdx = 0 ;
        result = _colorPalette[paletteColorIdx][1] ;
    } else if ([argument isKindOfClass:[NSString class]]) {
        NSString *argumentAsString = (NSString *)argument ;
        if ([argumentAsString hasPrefix:@"#"]) {
            result = NSColorFromHexColorString(argumentAsString) ;
        } else {
            for (NSArray *entry in _colorPalette) {
                if ([(NSString *)entry[0] isEqualToString:argumentAsString]) {
                    result = entry[1] ;
                    break ;
                }
            }
        }
    } else if ([argument isKindOfClass:[NSArray class]]) {
        NSArray<NSNumber *> *argumentAsNumericArray = (NSArray *)argument ;
        CGFloat red   = [argumentAsNumericArray[0] doubleValue] ;
        CGFloat green = [argumentAsNumericArray[1] doubleValue] ;
        CGFloat blue  = [argumentAsNumericArray[2] doubleValue] ;
        CGFloat alpha = (argumentAsNumericArray.count == 4) ? [argumentAsNumericArray[3] doubleValue] : 100.0 ;
        result = [NSColor colorWithCalibratedRed:(red / 100.0) green:(green / 100.0) blue:(blue / 100.0) alpha:(alpha / 100.0)] ;
    } else if ([argument isKindOfClass:[NSDictionary class]]) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        [skin pushNSObject:argument] ;
        result = [skin luaObjectAtIndex:-1 toClass:"NSColor"] ;
        lua_pop(L, 1) ;
    } else if ([argument isKindOfClass:[NSColor class]]) {
        result = (NSColor *)argument ;
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:@colorFromArgument:withState: - unrecognized color object type %@ (notify developer); ignoring and using black", USERDATA_TAG, argument.className]] ;
    }
    return result ;
}

- (NSString *)check:(NSObject *)argument forExpectedType:(NSString *)expectedArgType {
    NSString *errMsg = nil ;
    NSNumber *argumentAsNumber = (NSNumber *)argument ;

    if ([expectedArgType isEqualToString:@"number"]) {
        if (![argumentAsNumber isKindOfClass:[NSNumber class]]) {
            errMsg = [NSString stringWithFormat:@"expected %@", expectedArgType] ;
        } else if (!isfinite(argumentAsNumber.doubleValue)) {
            errMsg = @"must be a finite number" ;
        }
    } else if ([expectedArgType isEqualToString:@"string"]) {
        if (![argument isKindOfClass:[NSString class]]) errMsg = [NSString stringWithFormat:@"expected %@", expectedArgType] ;
    } else if ([expectedArgType isEqualToString:@"color"]) {
        if ([argument isKindOfClass:[NSNumber class]]) {
            NSInteger idx = argumentAsNumber.integerValue ;
            if (idx < 0 || idx > 255) errMsg = @"index must be between 0 and 255 inclusive" ;
        } else if ([argument isKindOfClass:[NSString class]]) {
            NSString *argumentAsString = (NSString *)argument ;
            if (![argumentAsString hasPrefix:@"#"]) {
                BOOL found = NO ;
                for (NSUInteger i = 0 ; i < 16 ; i++) {
                    NSString *colorLabel = _colorPalette[i][0] ;
                    if (![colorLabel isEqualToString:@""]) { // colors > 7 can be overwritten which clears their label
                        if ([argumentAsString isEqualToString:colorLabel]) {
                            found = YES ;
                            break ;
                        }
                    }
                }
                if (!found) errMsg = [NSString stringWithFormat:@"%@ is not a recognized color label", argument] ;
            }
        } else if ([argument isKindOfClass:[NSArray class]]) {
            NSArray<NSObject *> *list = (NSArray *)argument ;
            if (list.count < 3 || list.count > 4) {
                errMsg = @"color array must contain 3 or 4 numbers" ;
            } else {
                for (NSUInteger i = 0 ; i < list.count ; i++) {
                    if (![list[i] isKindOfClass:[NSNumber class]]) {
                        errMsg = [NSString stringWithFormat:@"expected number at index %lu of color array", (i + 1)] ;
                        break ;
                    }
                }
            }
//         } else if ([argument isKindOfClass:[NSDictionary class]]) {
//             errMsg = @"color table must include key \"__luaSkinType\" set to \"NSColor\". See `hs.drawaing.color`" ;
//         } else if (![argument isKindOfClass:[NSColor class]]) {
        } else if (!([argument isKindOfClass:[NSColor class]] || [argument isKindOfClass:[NSDictionary class]])) {
            errMsg = [NSString stringWithFormat:@"%@ does not specify a recognized color type", argument.className] ;
        }
    } else {
        errMsg = [NSString stringWithFormat:@"argument type %@ not implemented yet (notify developer)", expectedArgType] ;
    }

    return errMsg ;
}

- (BOOL)validateCommand:(NSUInteger)cmd withArguments:(nullable NSArray *)arguments
                                                error:(NSError * __autoreleasing *)error {
    NSUInteger cmdCount = wrappedCommands.count ;
    NSString *errMsg = nil ;

    if (cmd < cmdCount) {
        NSArray    *cmdDetails      = wrappedCommands[cmd] ;
        NSString   *cmdName         = cmdDetails[0] ;
        NSUInteger expectedArgCount = cmdDetails.count - 3 ;
        NSUInteger actualArgCount   = (arguments) ? arguments.count : 0 ;

        if (expectedArgCount == actualArgCount) {
            if (expectedArgCount > 0) {
                for (NSUInteger i = 0 ; i < expectedArgCount ; i++) {
                    NSString *expectedArgType = cmdDetails[3 + i] ;
                    if ([expectedArgType isKindOfClass:[NSString class]]) {
                        errMsg = [self check:arguments[i] forExpectedType:expectedArgType] ;
                        if (errMsg) {
                            errMsg = [NSString stringWithFormat:@"%@: %@ for argument %lu", cmdName, errMsg, (i + 1)] ;
                            break ;
                        }
                    } else if ([expectedArgType isKindOfClass:[NSArray class]]) {
                        NSArray *argList = arguments[i] ;
                        if (![argList isKindOfClass:[NSArray class]]) {
                            errMsg = [NSString stringWithFormat:@"%@: expected table for argument %lu", cmdName, (i + 1)] ;
                            break ;
                        }
                        NSArray *expectedTableArgTypes = (NSArray *)expectedArgType ;
                        if (expectedTableArgTypes.count == argList.count) {
                            for (NSUInteger j = 0 ; j < expectedTableArgTypes.count ; j++) {
                                expectedArgType = expectedTableArgTypes[j] ;
                                if ([expectedArgType isKindOfClass:[NSString class]]) {
                                    errMsg = [self check:argList[j] forExpectedType:expectedArgType] ;
                                    if (errMsg) {
                                        errMsg = [NSString stringWithFormat:@"%@: %@ for index %lu of argument %lu", cmdName, errMsg, (j + 1), (i + 1)] ;
                                        break ;
                                    }
                                } else {
                                    errMsg = [NSString stringWithFormat:@"%@: argument type %@ not supported in table argument of definition table (notify developer)", cmdName, expectedArgType.className] ;
                                    break ;
                                }
                            }
                            if (errMsg) break ;
                        } else {
                            errMsg = [NSString stringWithFormat:@"%@: expected %lu arguments in table argument %lu but found %lu", cmdName, expectedTableArgTypes.count, (i + 1), argList.count] ;
                            break ;
                        }
                    } else {
                        errMsg = [NSString stringWithFormat:@"%@: argument type %@ not supported in definition table (notify developer)", cmdName, expectedArgType.className] ;
                        break ;
                    }
                }

                // command specific validataion
                if (!errMsg) {
                    NSArray<NSNumber *> *argumentsAsNumbers = arguments ;
                    if (cmd == c_setpensize) {
                        NSArray<NSNumber *> *list = arguments[0] ;
                        CGFloat number = list[0].doubleValue ;
                        if (number <= 0) errMsg = [NSString stringWithFormat:@"%@: width must be positive", cmdName] ;
                    } else if (cmd == c_setscrunch) {
                        CGFloat number = argumentsAsNumbers[0].doubleValue ;
                        if (number <= 0) errMsg = [NSString stringWithFormat:@"%@: xscale must be positive", cmdName] ;
                        number = argumentsAsNumbers[1].doubleValue ;
                        if (number <= 0) errMsg = [NSString stringWithFormat:@"%@: yscale must be positive", cmdName] ;
                    } else if (cmd == c_setpalette) {
                        NSInteger idx = argumentsAsNumbers[0].integerValue ;
                        if (idx < 0 || idx > 255) {
                            errMsg = [NSString stringWithFormat:@"%@: index must be between 0 and 255 inclusive", cmdName] ;
                        }
                    }
                }
            }
        } else {
            errMsg = [NSString stringWithFormat:@"%@: expected %lu arguments but found %lu", cmdName, expectedArgCount, actualArgCount] ;
        }
    } else {
        errMsg = @"undefined command number specified" ;
    }

    if (errMsg) {
        if (error) {
            *error = [NSError errorWithDomain:(NSString * _Nonnull)[NSString stringWithUTF8String:USERDATA_TAG]
                                         code:-1
                                     userInfo:@{ NSLocalizedDescriptionKey : errMsg }] ;
        }
        return NO ;
    }
    return YES ;
}

- (void)updateStateWithCommand:(NSUInteger)cmd andArguments:(nullable NSArray *)arguments andState:(lua_State *)L {
    NSMutableDictionary *stepAttributes = _commandList.lastObject[1] ;

    NSArray<NSNumber *> *argumentsAsNumbers = (NSArray *)arguments ;

    CGFloat x = _tX ;
    CGFloat y = _tY ;

    CGFloat withPadding = 1.0 + offScreenPadding * 2.0 ;

    switch(cmd) {
        case c_forward:
        case c_back:
        case c_setpos:
        case c_setxy:
        case c_setx:
        case c_sety:
        case c_home: {
            if (cmd == c_forward || cmd == c_back) {
                CGFloat headingInRadians = _tHeading * M_PI / 180 ;
                CGFloat distance = argumentsAsNumbers[0].doubleValue ;
                if (cmd == c_back) distance = -distance ;
                _tX = x + distance * sin(headingInRadians) * _tScaleX ;
                _tY = y + distance * cos(headingInRadians) * _tScaleY ;
            } else if (cmd == c_setpos) {
                NSArray<NSNumber *> *listOfNumbers = arguments[0] ;
                _tX = listOfNumbers[0].doubleValue * _tScaleX ;
                _tY = listOfNumbers[1].doubleValue * _tScaleY ;
            } else if (cmd == c_setxy) {
                _tX = argumentsAsNumbers[0].doubleValue * _tScaleX ;
                _tY = argumentsAsNumbers[1].doubleValue * _tScaleY ;
            } else if (cmd == c_setx) {
                _tX = argumentsAsNumbers[0].doubleValue * _tScaleX ;
            } else if (cmd == c_sety) {
                _tY = argumentsAsNumbers[0].doubleValue * _tScaleY ;
            } else if (cmd == c_home) {
                _tX       = 0.0 ;
                _tY       = 0.0 ;
                _tHeading = 0.0 ;
            }

            if (_tPenDown) {
                NSBezierPath *strokePath = [NSBezierPath bezierPath] ;
                strokePath.lineWidth = _tPenSize ;
                [strokePath moveToPoint:NSMakePoint(x, y)] ;
                [strokePath lineToPoint:NSMakePoint(_tX, _tY)] ;
                stepAttributes[@"stroke"] = strokePath ;

                NSRect strokeBounds = strokePath.bounds ;
                _offScreenWidth  = fmax(
                    (fabs(strokeBounds.origin.x) * 2 + strokeBounds.size.width) * withPadding,
                    _offScreenWidth
                ) ;
                _offScreenHeight = fmax(
                    (fabs(strokeBounds.origin.y) * 2 + strokeBounds.size.height) * withPadding,
                    _offScreenHeight
                ) ;
            }
            stepAttributes[@"startPoint"] = [NSValue valueWithPoint:NSMakePoint(x, y)] ;
            stepAttributes[@"endPoint"]   = [NSValue valueWithPoint:NSMakePoint(_tX, _tY)] ;
        } break ;

        case c_left:
        case c_right:
        case c_setheading: {
            CGFloat angle = argumentsAsNumbers[0].doubleValue ;
            if (cmd == c_left) {
                angle = _tHeading - angle ;
            } else if (cmd == c_right) {
                angle = _tHeading + angle ;
         // } else if (cmd == c_setheading) { // NOP since first line in this block does this
         //     angle = angle ;
            }
            _tHeading = fmod(angle, 360) ;
        } break ;

        case c_pendown:
        case c_penup: {
            _tPenDown = (cmd == c_pendown) ;
        } break ;

        case c_penpaint:
        case c_penerase:
        case c_penreverse: {
            _tPenMode = (cmd == c_penreverse) ? NSCompositingOperationXOR :
                        (cmd == c_penerase)   ? NSCompositingOperationDestinationOut :
                                                NSCompositingOperationSourceOver ;
            _tPenDown = YES ;
            stepAttributes[@"penMode"] = @(_tPenMode) ;
        } break ;
        case c_setpensize: {
            NSArray<NSNumber *> *list = arguments[0] ;
            _tPenSize = list[0].doubleValue ;
        } break ;
        case c_arc: {
            CGFloat angle  = argumentsAsNumbers[0].doubleValue ;
            CGFloat radius = argumentsAsNumbers[1].doubleValue ;
            NSBezierPath *strokePath = [NSBezierPath bezierPath] ;
            strokePath.lineWidth = _tPenSize ;
            [strokePath appendBezierPathWithArcWithCenter:NSMakePoint(0, 0)
                                                   radius:radius
                                               startAngle:((360 - _tHeading) + 90)
                                                 endAngle:((360 - (_tHeading + angle)) + 90)
                                                clockwise:(angle > 0)] ;
            NSAffineTransform *scrunch = [[NSAffineTransform alloc] init] ;
            [scrunch scaleXBy:_tScaleX yBy:_tScaleY] ;
            [scrunch translateXBy:(_tX / _tScaleX) yBy:(_tY / _tScaleY)] ;
            [strokePath transformUsingAffineTransform:scrunch] ;
            stepAttributes[@"stroke"] = strokePath ;

            NSRect strokeBounds = strokePath.bounds ;
            _offScreenWidth  = fmax(
                (fabs(strokeBounds.origin.x) * 2 + strokeBounds.size.width) * withPadding,
                _offScreenWidth
            ) ;
            _offScreenHeight = fmax(
                (fabs(strokeBounds.origin.y) * 2 + strokeBounds.size.height) * withPadding,
                _offScreenHeight
            ) ;
        } break ;
        case c_setscrunch: {
            _tScaleX = argumentsAsNumbers[0].doubleValue ;
            _tScaleY = argumentsAsNumbers[1].doubleValue ;
        } break ;
        case c_setlabelheight: {
            _labelFontSize = argumentsAsNumbers[0].doubleValue ;
        } break ;
        case c_setlabelfont: {
            _labelFontName = (NSString *)arguments[0] ;
        } break ;
        case c_label: {
            NSString *fontName = _labelFontName ;
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            [skin pushLuaRef:refTable ref:fontMapRef] ;
            if (lua_getfield(L, -1, _labelFontName.UTF8String) != LUA_TNIL) fontName = [skin toNSObjectAtIndex:-1] ;
            lua_pop(L, 2) ;

            NSFont *theFont = [NSFont fontWithName:fontName size:_labelFontSize] ;
            if (!theFont) theFont = [NSFont userFontOfSize:_labelFontSize] ;

            NSBezierPath* strokePath   = [NSBezierPath bezierPath] ;
            NSTextStorage *storage     = [[NSTextStorage alloc] initWithString:(NSString *)arguments[0]
                                                                    attributes:@{ NSFontAttributeName : theFont }] ;
            NSLayoutManager *manager   = [[NSLayoutManager alloc] init] ;
            NSTextContainer *container = [[NSTextContainer alloc] init] ;

            [storage addLayoutManager:manager] ;
            [manager addTextContainer:container] ;

            NSRange glyphRange = [manager glyphRangeForTextContainer:container] ;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wvla"
            CGGlyph glyphArray[glyphRange.length + 1] ;
#pragma clang diagnostic pop

            NSUInteger glyphCount = [manager getGlyphsInRange:glyphRange glyphs:glyphArray
                                                                     properties:NULL
                                                               characterIndexes:NULL
                                                                     bidiLevels:NULL] ;

            [strokePath moveToPoint:NSZeroPoint] ;
            [strokePath appendBezierPathWithCGGlyphs:glyphArray count:(NSInteger)glyphCount inFont:theFont] ;
            NSAffineTransform *scrunchAndTurn = [[NSAffineTransform alloc] init] ;
            [scrunchAndTurn scaleXBy:_tScaleX yBy:_tScaleY] ;
            [scrunchAndTurn translateXBy:(_tX / _tScaleX) yBy:(_tY / _tScaleY)] ;
            [scrunchAndTurn rotateByDegrees:((360 - _tHeading) + 90)] ;
            [strokePath transformUsingAffineTransform:scrunchAndTurn] ;
//             stepAttributes[@"stroke"] = strokePath ; // I think it looks crisper with just the fill
            stepAttributes[@"fill"] = strokePath ;

            NSRect strokeBounds = strokePath.bounds ;
            _offScreenWidth  = fmax(
                (fabs(strokeBounds.origin.x) * 2 + strokeBounds.size.width) * withPadding,
                _offScreenWidth
            ) ;
            _offScreenHeight = fmax(
                (fabs(strokeBounds.origin.y) * 2 + strokeBounds.size.height) * withPadding,
                _offScreenHeight
            ) ;
        } break ;
        case c_setpencolor: {
            _pColor = [self colorFromArgument:arguments[0] withState:L] ;
            stepAttributes[@"penColor"] = _pColor ;
            if ([(NSObject *)arguments[0] isKindOfClass:[NSNumber class]]) {
                _pPaletteIdx = argumentsAsNumbers[0].unsignedIntegerValue ;
            } else {
                _pPaletteIdx = NSUIntegerMax ;
            }
        } break ;
        case c_setbackground: {
            _bColor = [self colorFromArgument:arguments[0] withState:L] ;
            stepAttributes[@"backgroundColor"] = _bColor ;
            if ([(NSObject *)arguments[0] isKindOfClass:[NSNumber class]]) {
                _bPaletteIdx = argumentsAsNumbers[0].unsignedIntegerValue ;
            } else {
                _bPaletteIdx = NSUIntegerMax ;
            }
        } break ;
        case c_setpalette: {
            NSUInteger paletteIdx = argumentsAsNumbers[0].unsignedIntegerValue ;
            if (paletteIdx > 7) { // we ignore changes to the first 8 colors
                // it's eitehr this or switch to NSDictionary for a "sparse" array
                while (paletteIdx > _colorPalette.count) _colorPalette[_colorPalette.count] = @[ @"", _colorPalette[0][1] ] ;
                _colorPalette[paletteIdx] = @[ @"", [self colorFromArgument:arguments[1] withState:L]] ;
            }
        } break ;
        case c_fillstart: {
            stepAttributes[@"startPoint"] = [NSValue valueWithPoint:NSMakePoint(_tX, _tY)] ;
        } break ;
        case c_fillend: {
            stepAttributes[@"penColor"] = [self colorFromArgument:arguments[0] withState:L] ;
            NSBezierPath *fillPath = [NSBezierPath bezierPath] ;
            NSUInteger startIdx = 0 ;
            for (NSUInteger i = _commandList.count ; i > 0 ; i--) {
                NSUInteger currentCmd = ((NSNumber *)_commandList[i - 1][0]).unsignedIntegerValue ;
                if (currentCmd == c_fillstart) {
                    startIdx = i - 1 ;
                    break ;
                }
            }
            BOOL hasStartPoint = NO ;
            for (NSUInteger j = startIdx ; j < _commandList.count ; j++) {
                NSDictionary *properties = _commandList[j][1] ;
                if (!hasStartPoint && properties[@"startPoint"]) {
                    hasStartPoint = YES ;
                    [fillPath moveToPoint:((NSValue *)properties[@"startPoint"]).pointValue] ;
                }
                if (hasStartPoint && properties[@"endPoint"]) {
                    [fillPath lineToPoint:((NSValue *)properties[@"endPoint"]).pointValue] ;
                }
            }
            [fillPath closePath] ;
            stepAttributes[@"fill"]     = fillPath ;
            stepAttributes[@"endPoint"] = [NSValue valueWithPoint:NSMakePoint(_tX, _tY)] ;
            [self appendCommand:c_setpencolor withArguments:@[ _pColor ] andState:L error:NULL] ; // reset color back to pre-fill color
        } break ;
        default: {
            [LuaSkin logWarn:[NSString stringWithFormat:@"%s:@updateStateWithCommand:andArguments:andState: - command code %lu currently unsupported; ignoring", USERDATA_TAG, cmd]] ;
            return ;
        }
    }
}

- (BOOL)appendCommand:(NSUInteger)cmd withArguments:(nullable NSArray *)arguments
                                           andState:(lua_State *)L
                                              error:(NSError * __autoreleasing *)error {

    BOOL isGood = [self validateCommand:cmd withArguments:arguments error:error] ;
    if (isGood) {
        NSArray *newCommand = @[ @(cmd), [NSMutableDictionary dictionary] ] ;
        if (arguments) newCommand[1][@"arguments"] = arguments ;
        [_commandList addObject:newCommand] ;
        [self updateStateWithCommand:cmd andArguments:arguments andState:L] ;

        self.needsDisplay = !(_neverRender || _renderingPaused) ;
    }

    return isGood ;
}

- (NSImage *)generateImageFromVisible:(BOOL)onlyVisible
                       withBackground:(BOOL)withBackground
                            andTurtle:(BOOL)withTurtle {

    [self updateOffScreenImage] ;
    NSImage *newImage = [[NSImage alloc] initWithSize:(onlyVisible ? self.frame.size : _offScreen.size)] ;

    [newImage lockFocus] ;
        NSGraphicsContext *gc = [NSGraphicsContext currentContext];
        [gc saveGraphicsState];

        if (withBackground) {
            [_bColor setFill] ;
            [NSBezierPath fillRect:NSMakeRect(0, 0, newImage.size.width, newImage.size.height)] ;
        }

        NSRect fromRect = NSZeroRect ;
        if (onlyVisible) {
            fromRect = NSMakeRect(
                (_offScreenWidth  - self.frame.size.width)  / 2.0 - _translateX,
                (_offScreenHeight - self.frame.size.height) / 2.0 - _translateY,
                self.frame.size.width,
                self.frame.size.height
            ) ;
        }
        [_offScreen drawAtPoint:NSZeroPoint
                        fromRect:fromRect
                       operation:NSCompositingOperationSourceOver
                        fraction:1.0] ;

        if (withTurtle) {
            NSPoint location = NSMakePoint(
                _tX + (onlyVisible ? self.frame.size.width  : _offScreenWidth)  / 2.0,
                _tY + (onlyVisible ? self.frame.size.height : _offScreenHeight) / 2.0
            ) ;
            if (onlyVisible) {
                location.x = location.x + _translateX ;
                location.y = location.y + _translateY ;
            }
            NSAffineTransform *turtleRotation = [[NSAffineTransform alloc] init] ;
            [turtleRotation translateXBy:location.x yBy:location.y] ;
            [turtleRotation rotateByDegrees:(360 - _tHeading)] ;

            [gc saveGraphicsState];

            [turtleRotation concat] ;
            [_turtleImage drawAtPoint:NSMakePoint((_turtleSize.width / -2.0), (_turtleSize.height / -2.0))
                             fromRect:NSZeroRect
                            operation:NSCompositingOperationSourceOver
                             fraction:1.0] ;

            [gc restoreGraphicsState] ;
        }

        [gc restoreGraphicsState] ;
    [newImage unlockFocus] ;

    return newImage ;
}

- (void)updateOffScreenImage {
    BOOL resizeImage = (_offScreenWidth  > _offScreen.size.width) ||
                       (_offScreenHeight > _offScreen.size.height) ;
    if (resizeImage) {
        @autoreleasepool {
            NSImage *oldImage = _offScreen ;
            NSSize  newSize   = NSMakeSize(_offScreenWidth, _offScreenHeight) ;
            _offScreen = [[NSImage alloc] initWithSize:newSize] ;
            [_offScreen lockFocus] ;
                NSGraphicsContext *gc = [NSGraphicsContext currentContext];
                [gc saveGraphicsState] ;
                [oldImage drawInRect:NSMakeRect(
                    (newSize.width  - oldImage.size.width)  / 2.0,
                    (newSize.height - oldImage.size.height) / 2.0,
                    oldImage.size.width,
                    oldImage.size.height
                )] ;
                [gc restoreGraphicsState] ;
            [_offScreen unlockFocus] ;
        }
    }

    if (_offScreenIdx < _commandList.count) {
        [_offScreen lockFocus] ;
            NSGraphicsContext *gc = [NSGraphicsContext currentContext];
            [gc saveGraphicsState] ;

            // use transform so origin shifted to center of image
            NSAffineTransform *shiftOriginToCenter = [[NSAffineTransform alloc] init] ;
            [shiftOriginToCenter translateXBy:(_offScreenWidth  / 2.0)
                                          yBy:(_offScreenHeight / 2.0)] ;
            [shiftOriginToCenter concat] ;

            [_pInitColor setStroke] ;
            [_pInitColor setFill] ;
            gc.compositingOperation = _tPenMode ;

            for (NSUInteger i = _offScreenIdx ; i < _commandList.count ; i++) {
                NSArray *entry = _commandList[i] ;
                NSMutableDictionary *properties = entry[1] ;

                NSNumber *compositeMode = properties[@"penMode"] ;
                if (compositeMode) gc.compositingOperation = compositeMode.unsignedIntegerValue ;

                NSColor *penColor = properties[@"penColor"] ;
                if (penColor) {
                    [penColor setStroke] ;
                    [penColor setFill] ;
                }

                NSBezierPath *strokePath = properties[@"stroke"] ;
                if (strokePath) [strokePath stroke] ;

                NSBezierPath *fillPath = properties[@"fill"] ;
                if (fillPath) [fillPath fill] ;
            }

            [gc restoreGraphicsState] ;
        [_offScreen unlockFocus] ;
        _offScreenIdx = _commandList.count ;
    }
}

@end

#pragma mark - Module Functions

static int turtle_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSMakeRect(0, 0, 200, 200) ;
    HSCanvasTurtleView *newView = [[HSCanvasTurtleView alloc] initWithFrame:frameRect] ;

    if (newView) {
        [skin pushNSObject:newView] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int turtle_registerFontMap(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    lua_pushvalue(L, 1) ;
    fontMapRef = [skin luaRef:refTable] ;
    return 0 ;
}

static int turtle_registerDefaultPalette(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    defaultColorPalette = [skin toNSObjectAtIndex:1] ;
    return 0 ;
}

#pragma mark - Module Methods

static int turtle_dumpPalette(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:turtleCanvas.colorPalette] ;
    return 1 ;
}

/// hs.canvas.turtle:_yieldRatio([count]) -> turtleViewObject | int
/// Method
/// Get or set the number of turtle drawing commands that will be performed between yields when using [hs.canvas.turtle:_background](#_background).
///
/// Parameters:
///  * `count` - an optional integer specifying the number of drawing commands to perform between yields.
///
/// Returns:
///  * if an argument is provided, returns the turtleViewObject; otherwise returns the current value.
///
/// Notes:
///  * when you background a drawing function with [hs.canvas.turtle:_background](#_background), a coroutine is created which will yield after a certain number of drawing commands have occurred. This method allows you to adjust this number so you can balance speed of rendering and Hammerspoon responsiveness to your specific needs.
static int turtle_yieldRatio(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, turtleCanvas.yieldRatio) ;
    } else {
        lua_Integer newRatio = lua_tointeger(L, 2) ;
        if (newRatio < 1) newRatio = 1 ;
        turtleCanvas.yieldRatio = newRatio ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.canvas.turtle:_neverYield([state]) -> turtleViewObject | boolean
/// Method
/// Get or set the whether or not [hs.canvas.turtle:_background](#_background) actually yields.
///
/// Parameters:
///  * `state` - an optional boolean specifying whether or not backgrounded functions should actually yield.
///
/// Returns:
///  * if an argument is provided, returns the turtleViewObject; otherwise returns the current value.
///
/// Notes:
///  * Setting this to false before using [hs.canvas.turtle:_background](#_background) essentially causes the `_background` method to block until completion, as if you had gone ahead and run the function yourself. Setting it to false while a function is already running will cause it (and any additionally queued background functions) to run to completion after it next resumes without further yields.
static int turtle_neverYield(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, turtleCanvas.neverYield) ;
    } else {
        turtleCanvas.neverYield = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int turtle_pauseRendering(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, turtleCanvas.renderingPaused) ;
    } else {
        turtleCanvas.renderingPaused = (BOOL)(lua_toboolean(L, 2)) ;
        turtleCanvas.needsDisplay = !turtleCanvas.renderingPaused ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int turtle_asImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                                                LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                                                LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                                                LS_TBREAK] ;

    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;
    BOOL withBackground = (lua_gettop(L) > 1 && lua_isboolean(L, 2)) ? (BOOL)(lua_toboolean(L, 2)) : NO ;
    BOOL withTurtle     = (lua_gettop(L) > 2 && lua_isboolean(L, 3)) ? (BOOL)(lua_toboolean(L, 3)) : NO ;
    BOOL onlyVisible    = (lua_gettop(L) > 3 && lua_isboolean(L, 4)) ? (BOOL)(lua_toboolean(L, 4)) : YES ;

    NSImage *image = [turtleCanvas generateImageFromVisible:onlyVisible
                                             withBackground:withBackground
                                                  andTurtle:withTurtle] ;
    [skin pushNSObject:image] ;
    return 1;
}

static int turtle_parentView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:turtleCanvas.superview withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

static int turtle_turtleImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA | LS_TNIL | LS_TOPTIONAL, "hs.image", LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:turtleCanvas.turtleImage] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            turtleCanvas.turtleImage = [turtleCanvas defaultTurtleImage] ;
        } else {
            NSImage *newTurtle = [skin toNSObjectAtIndex:2] ;
            turtleCanvas.turtleImage = newTurtle ;
            turtleCanvas.needsDisplay = !turtleCanvas.renderingPaused ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int turtle_turtleSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TTABLE | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:turtleCanvas.turtleSize] ;
    } else {
        if (lua_type(L, 2) == LUA_TTABLE) {
            NSSize newSize = [skin tableToSizeAtIndex:2] ;
            if (newSize.height < 1) newSize.height = 1 ;
            if (newSize.width < 1)  newSize.width = 1 ;
            turtleCanvas.turtleSize = newSize ;
        } else {
            lua_Number newSize = lua_tonumber(L, 2) ;
            if (newSize < 1) newSize = 1 ;
            turtleCanvas.turtleSize = NSMakeSize(newSize, newSize) ;
        }
        turtleCanvas.needsDisplay = !turtleCanvas.renderingPaused ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int turtle_commandCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, (lua_Integer)turtleCanvas.commandList.count) ;
    return 1 ;
}

static int turtle_commandDump(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;
    BOOL raw = (lua_gettop(L) == 1) ? NO : (BOOL)(lua_toboolean(L, 2)) ;

    if (raw) {
        [skin pushNSObject:turtleCanvas.commandList withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        lua_newtable(L) ;
        for (NSArray *entry in turtleCanvas.commandList) {
            lua_newtable(L) ;
            [skin pushNSObject:entry[0]] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            NSArray *arguments = entry[1][@"arguments"] ;
            if (arguments) {
                for (NSObject *arg in arguments) {
                    [skin pushNSObject:arg] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
                }
            }
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    }
    return 1 ;
}

static int turtle_appendCommand(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TBREAK | LS_TVARARG] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;
    lua_Integer        command       = lua_tointeger(L, 2) ;

    int     argCount  = lua_gettop(L) - 2 ;
    NSArray *arguments = nil ;

    if (argCount > 0) {
        NSMutableArray *argAccumulator = [NSMutableArray arrayWithCapacity:(NSUInteger)argCount] ;
        for (int i = 0 ; i < argCount ; i++) [argAccumulator addObject:[skin toNSObjectAtIndex:(3 + i)]] ;
        arguments = [argAccumulator copy] ;
    }

    NSError *errMsg  = nil ;
    [turtleCanvas appendCommand:(NSUInteger)command withArguments:arguments andState:L error:&errMsg] ;

    if (errMsg) {
        // error is handled in lua wrapper
        [skin pushNSObject:errMsg.localizedDescription] ;
    } else {
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int turtle_translate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, turtleCanvas.translateX) ;
        lua_pushnumber(L, turtleCanvas.translateY) ;
        return 2 ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
        CGFloat x = lua_tonumber(L, 2) ;
        CGFloat y = lua_tonumber(L, 3) ;
        if (!isfinite(x)) return luaL_argerror(L, 2, "x translation must be a finite number") ;
        if (!isfinite(y)) return luaL_argerror(L, 3, "y translation must be a finite number") ;

        turtleCanvas.translateX = x ;
        turtleCanvas.translateY = y ;
        turtleCanvas.needsDisplay = !turtleCanvas.renderingPaused ;
        lua_pushvalue(L, 1) ;
        return 1 ;
    }
}

// since it's wrapped in init.lua, document it there
static int turtle_visibleAxes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    NSSize viewSize = turtleCanvas.frame.size ;
    CGFloat maxAbsX = viewSize.width / 2.0 ;
    CGFloat maxAbsY = viewSize.height / 2.0 ;

    lua_newtable(L) ;
    lua_newtable(L) ;
    lua_pushnumber(L, -maxAbsX - turtleCanvas.translateX) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushnumber(L,  maxAbsX - turtleCanvas.translateX) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_newtable(L) ;
    lua_pushnumber(L, -maxAbsY - turtleCanvas.translateY) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushnumber(L,  maxAbsY - turtleCanvas.translateY) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;

    return 1 ;
}

// since it's wrapped in init.lua, document it there
static int turtle_pos(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_newtable(L) ;
    lua_pushnumber(L, turtleCanvas.tX / turtleCanvas.tScaleX) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushnumber(L, turtleCanvas.tY / turtleCanvas.tScaleY) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    return 1 ;
}

/// hs.canvas.turtle:xcor() -> number
/// Method
/// Returns the X coordinate of the turtle's current position.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a number representing the X coordinate of the turtle's current position
static int turtle_xcor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushnumber(L, turtleCanvas.tX / turtleCanvas.tScaleX) ;
    return 1 ;
}

/// hs.canvas.turtle:ycor() -> number
/// Method
/// Returns the Y coordinate of the turtle's current position.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a number representing the Y coordinate of the turtle's current position
static int turtle_ycor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushnumber(L, turtleCanvas.tY / turtleCanvas.tScaleY) ;
    return 1 ;
}

/// hs.canvas.turtle:heading() -> number
/// Method
/// Returns the current heading of the turtle in degrees.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a number representing the current heading of the turtle in degrees clockwise from the positive Y axis
static int turtle_heading(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushnumber(L, turtleCanvas.tHeading) ;
    return 1 ;
}

/// hs.canvas.turtle:clean() -> turtleViewObject
/// Method
/// Clears the turtle view, effectively erasing all lines that the turtle has drawn on the graphics window.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the turtleViewObject
///
/// Notes:
///  * The turtle’s state (position, heading, pen mode, etc.) is not changed.
static int turtle_clean(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    [turtleCanvas resetForClean] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.canvas.turtle:clearscreen() -> turtleViewObject
/// Method
/// Erases the graphics window and send the turtle to its initial position and heading.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the turtleViewObject
///
/// Notes:
///  * Synonym: `hs.canvas.turtle:cs()`
///
///  * This method is equivalent to  `hs.canvas.turtle:home():clean()`.
static int turtle_clearscreen(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    turtleCanvas.tX       = 0.0 ;
    turtleCanvas.tY       = 0.0 ;
    turtleCanvas.tHeading = 0.0 ;
    return turtle_clean(L) ;
}

/// hs.canvas.turtle:shownp() -> boolean
/// Method
/// Returns whether or not the turtle is currently visible within the turtle view.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean specifying whether the turtle is currently visible (true) or not (false).
static int turtle_shownp(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, turtleCanvas.turtleVisible) ;
    return 1 ;
}

/// hs.canvas.turtle:pendownp() -> boolean
/// Method
/// Returns whether or not the pen is in the down position.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean value specifying whether the pen is down (true) or up (false).
static int turtle_pendownp(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, turtleCanvas.tPenDown) ;
    return 1 ;
}

/// hs.canvas.turtle:penmode() -> string
/// Method
/// Returns the current pen drawing mode.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string specifying the current drawing mode. Possible values are "PAINT", "ERASE", or "REVERSE", corresponding to [hs.canvas.turtle:penpaint](#penpaint), [hs.canvas.turtle:penerase](#penerase), or [hs.canvas.turtle:penreverse](#penreverse) respectively.
static int turtle_penmode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

// this is a stupid warning to have to supress since I included a default... it makes sense
// if I don't, but... CLANG is muy muy loco when all warnings are turned on...
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wswitch-enum"
    switch(turtleCanvas.tPenMode) {
        case NSCompositingOperationSourceOver:     lua_pushstring(L, "PAINT") ; break ;
        case NSCompositingOperationDestinationOut: lua_pushstring(L, "ERASE") ; break ;
        case NSCompositingOperationXOR:            lua_pushstring(L, "REVERSE") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"** unknown compositing mode: %lu", turtleCanvas.tPenMode]] ;
    }
#pragma clang diagnostic pop

    return 1 ;
}

// since it's wrapped in init.lua, document it there
static int turtle_pensize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_newtable(L) ;
    lua_pushnumber(L, turtleCanvas.tPenSize) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushnumber(L, turtleCanvas.tPenSize) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    return 1 ;
}

// since it's wrapped in init.lua, document it there
static int turtle_scrunch(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_newtable(L) ;
    lua_pushnumber(L, turtleCanvas.tScaleX) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushnumber(L, turtleCanvas.tScaleY) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    return 1 ;
}

/// hs.canvas.turtle:hideturtle() -> turtleViewObject
/// Method
/// Hides the turtle in the turtle view.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the turtleViewObject
///
/// Notes:
///  * Synonym: `hs.canvas.turtle:ht()`
static int turtle_showturtle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    turtleCanvas.turtleVisible = YES ;
    turtleCanvas.needsDisplay = !turtleCanvas.renderingPaused ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.canvas.turtle:showturtle() -> turtleViewObject
/// Method
/// Makes the turtle visible in the turtle view.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the turtleViewObject
///
/// Notes:
///  * Synonym: `hs.canvas.turtle:st()`
static int turtle_hideturtle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    turtleCanvas.turtleVisible = NO ;
    turtleCanvas.needsDisplay = !turtleCanvas.renderingPaused ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

// since it's wrapped in init.lua, document it there
static int turtle_labelsize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_newtable(L) ;
    lua_pushnumber(L, turtleCanvas.labelFontSize) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushnumber(L, turtleCanvas.labelFontSize) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    return 1 ;
}

static int turtle_labelfont(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:turtleCanvas.labelFontName] ;
    return 1 ;
}

// since it's wrapped in init.lua, document it there
static int turtle_pencolor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    if (turtleCanvas.pPaletteIdx == NSUIntegerMax) {
        NSColor *safeColor = [turtleCanvas.pColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace] ;
        if (safeColor) {
            lua_newtable(L) ;
            lua_pushnumber(L, safeColor.redComponent) ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            lua_pushnumber(L, safeColor.greenComponent) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            lua_pushnumber(L, safeColor.blueComponent) ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            CGFloat alpha = safeColor.alphaComponent ;
            if (alpha < 0.9999) {
                lua_pushnumber(L, alpha) ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
        } else {
            [skin pushNSObject:turtleCanvas.pColor] ;
        }
    } else {
        lua_pushinteger(L, (lua_Integer)turtleCanvas.pPaletteIdx) ;
    }
    return 1 ;
}

// since it's wrapped in init.lua, document it there
static int turtle_background(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    if (turtleCanvas.bPaletteIdx == NSUIntegerMax) {
        NSColor *safeColor = [turtleCanvas.bColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace] ;
        if (safeColor) {
            lua_newtable(L) ;
            lua_pushnumber(L, safeColor.redComponent) ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            lua_pushnumber(L, safeColor.greenComponent) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            lua_pushnumber(L, safeColor.blueComponent) ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            CGFloat alpha = safeColor.alphaComponent ;
            if (alpha < 0.9999) {
                lua_pushnumber(L, alpha) ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
        } else {
            [skin pushNSObject:turtleCanvas.bColor] ;
        }
    } else {
        lua_pushinteger(L, (lua_Integer)turtleCanvas.bPaletteIdx) ;
    }
    return 1 ;
}

// since it's wrapped in init.lua, document it there
static int turtle_palette(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;
    lua_Integer idx = lua_tointeger(L, 2) ;

    if (idx < 0 || idx > 255) {
        return luaL_argerror(L, 2, "index must be between 0 and 255 inclusive") ;
    }
    if ((NSUInteger)idx >= turtleCanvas.colorPalette.count) idx = 0 ;
    NSColor *safeColor = [(NSColor *)(turtleCanvas.colorPalette[(NSUInteger)idx][1]) colorUsingColorSpace:NSColorSpace.genericRGBColorSpace] ;
    if (safeColor) {
        lua_newtable(L) ;
        lua_pushnumber(L, safeColor.redComponent) ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushnumber(L, safeColor.greenComponent) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushnumber(L, safeColor.blueComponent) ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        CGFloat alpha = safeColor.alphaComponent ;
        if (alpha < 0.9999) {
            lua_pushnumber(L, alpha) ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else {
        [skin pushNSObject:turtleCanvas.colorPalette[(NSUInteger)idx][1]] ;
    }
    return 1 ;
}

// Probably to be wrapped, if implemented
    // 6.3 Turtle and Window Control
        //   fill
        //   filled

// Not Sure Yet
    // 6.7 Saving and Loading Pictures
        //   savepict -- could do in lua, leveraging _commands
        //   loadpict -- could do in lua, leveraging _appendCommand after resetting state

#pragma mark - Module Constants

static int turtle_CommandsToBeWrapped(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:wrappedCommands] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSCanvasTurtleView(lua_State *L, id obj) {
    HSCanvasTurtleView *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSCanvasTurtleView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSCanvasTurtleViewFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSCanvasTurtleView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSCanvasTurtleView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSCanvasTurtleView *obj = [skin luaObjectAtIndex:1 toClass:"HSCanvasTurtleView"] ;

    NSSize viewSize = obj.frame.size ;
    CGFloat maxAbsX = viewSize.width / 2.0 ;
    CGFloat maxAbsY = viewSize.height / 2.0 ;
    NSString *title = [NSString stringWithFormat:@"X ∈ [%.2f, %.2f], Y ∈ [%.2f, %.2f]",
        -maxAbsX - obj.translateX, maxAbsX - obj.translateX, -maxAbsY - obj.translateY, maxAbsY - obj.translateY] ;

    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSCanvasTurtleView *obj1 = [skin luaObjectAtIndex:1 toClass:"HSCanvasTurtleView"] ;
        HSCanvasTurtleView *obj2 = [skin luaObjectAtIndex:2 toClass:"HSCanvasTurtleView"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSCanvasTurtleView *obj = get_objectFromUserdata(__bridge_transfer HSCanvasTurtleView, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            [obj removeObserver] ;
            [obj removeFromSuperview] ;
            obj = nil ;
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

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"pos",              turtle_pos},
    {"xcor",             turtle_xcor},
    {"ycor",             turtle_ycor},
    {"heading",          turtle_heading},
    {"clean",            turtle_clean},
    {"clearscreen",      turtle_clearscreen},
    {"showturtle",       turtle_showturtle},
    {"hideturtle",       turtle_hideturtle},
    {"shownp",           turtle_shownp},
    {"pendownp",         turtle_pendownp},
    {"penmode",          turtle_penmode},
    {"pensize",          turtle_pensize},
    {"scrunch",          turtle_scrunch},
    {"labelsize",        turtle_labelsize},
    {"labelfont",        turtle_labelfont},
    {"pencolor",         turtle_pencolor},
    {"background",       turtle_background},
    {"palette",          turtle_palette},

    {"_yieldRatio",      turtle_yieldRatio},
    {"_neverYield",      turtle_neverYield},
    {"_pause",           turtle_pauseRendering},
    {"_image",           turtle_asImage},
    {"_cmdCount",        turtle_commandCount},
    {"_appendCommand",   turtle_appendCommand},
    {"_turtleImage",     turtle_turtleImage},
    {"_turtleSize",      turtle_turtleSize},
    {"_canvas",          turtle_parentView},
    {"_commands",        turtle_commandDump},
    {"_palette",         turtle_dumpPalette},
    {"_translate",       turtle_translate},
    {"_visibleAxes",     turtle_visibleAxes},

    {"__tostring",       userdata_tostring},
    {"__eq",             userdata_eq},
    {"__gc",             userdata_gc},
    {NULL,               NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",                     turtle_new},
    {"_registerDefaultPalette", turtle_registerDefaultPalette},
    {"_registerFontMap",        turtle_registerFontMap},
    {NULL,                      NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs_canvas_turtle_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSCanvasTurtleView         forClass:"HSCanvasTurtleView"];
    [skin registerLuaObjectHelper:toHSCanvasTurtleViewFromLua forClass:"HSCanvasTurtleView"
                                                   withUserdataMapping:USERDATA_TAG];

    // in case for some reason init.lua doesn't set it, have a minimal backup
    defaultColorPalette = @[
        @[ @"black",   [NSColor blackColor] ],
        @[ @"blue",    [NSColor blueColor] ],
        @[ @"green",   [NSColor greenColor] ],
        @[ @"cyan",    [NSColor cyanColor] ],
        @[ @"red",     [NSColor redColor] ],
        @[ @"magenta", [NSColor magentaColor] ],
        @[ @"yellow",  [NSColor yellowColor] ],
        @[ @"white",   [NSColor whiteColor] ],
    ] ;

    wrappedCommands = t_wrappedCommands ;
    turtle_CommandsToBeWrapped(L) ; lua_setfield(L, -2, "_wrappedCommands") ;

    return 1;
}
