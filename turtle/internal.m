@import Cocoa ;
@import LuaSkin ;

@import Darwin.C.tgmath ;

// TODO:

//   add other methods (esp color)
//   figure out WTF to do about fills
//       fill uses floodFill algorithm; probably not reasonable unless we can easily build bitmap, but look into
//       filled takes a list of commands as arguments, so can't implement with method style approach...
//           instead, two methods? 1 to mark begining of filled object, 2 to mark end -- create new path
//               with intervening paths as appended subpaths, then fill new object?
//           make filled take function which accepts one variable (turtleObject) and then applies actions to that,
//               closing off and filling combined bezier path?

// + add way to dump/import commandList?
//   * dump

static const char * const USERDATA_TAG = "hs.canvas.turtle" ;
static int refTable = LUA_NOREF;
static void *myKVOContext = &myKVOContext ; // See http://nshipster.com/key-value-observing/

static NSArray *wrappedCommands ;
static NSArray *penColors ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSCanvasTurtleView : NSView
@property            int                    selfRefCount ;

@property (readonly) NSMutableArray         *commandList ;

@property            NSUInteger             turtleSize ;
@property            NSImageView            *turtleImageView ;

// current turtle state -- should be updated as commands appended
@property            CGFloat                tX ;
@property            CGFloat                tY ;
@property            CGFloat                tHeading ;
@property            BOOL                   tPenDown ;
@property            NSCompositingOperation tPenMode ;
@property            CGFloat                tPenSize ;
@property            CGFloat                tScaleX ;
@property            CGFloat                tScaleY ;


@property            NSUInteger             pColorNumber ;
@property            NSUInteger             bColorNumber ;
@property            NSColor                *pColor ;
@property            NSColor                *bColor ;

@property            BOOL                   renderingPaused ;
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

    NSColor                *_pInitColor ;
    NSColor                *_bInitColor ;
}

#pragma mark - Required for Canvas compatible view -

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect] ;
    if (self) {
        _selfRefCount = 0 ;

        _parentWindow    = nil ;
        _neverRender     = YES ;
        _renderingPaused = NO ;

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
        NSGraphicsContext *gc = [NSGraphicsContext currentContext];
        [gc saveGraphicsState] ;

        CGFloat xOriginOffset = self.frame.size.width / 2 ;
        CGFloat yOriginOffset = self.frame.size.height / 2 ;

        // use transform so origin shifted to center of view
        NSAffineTransform *shiftOriginToCenter = [[NSAffineTransform alloc] init] ;
        [shiftOriginToCenter translateXBy:xOriginOffset yBy:yOriginOffset] ;
        [shiftOriginToCenter concat] ;

        [_pInitColor setStroke] ;
        gc.compositingOperation = _tInitPenMode ;

        for (NSArray *entry in _commandList) {
            NSMutableDictionary *properties = entry[1] ;

            NSBezierPath *strokePath = properties[@"stroke"] ;
            if (strokePath) [strokePath stroke] ;

            NSNumber *compositeMode = properties[@"penMode"] ;
            if (compositeMode) gc.compositingOperation = compositeMode.unsignedIntegerValue ;
        }

        [gc restoreGraphicsState] ;
        [self updateTurtle] ;
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

- (void)defaultTurtleImage {
    _turtleImageView.image          = [NSImage imageNamed:NSImageNameTouchBarColorPickerFont] ;
    _turtleImageView.imageScaling   = NSImageScaleProportionallyUpOrDown ;
    _turtleImageView.imageAlignment =  NSImageAlignCenter ;
}

- (void)resetTurtleView {
    _tX           = 0.0 ;
    _tY           = 0.0 ;
    _tHeading     = 0.0 ;
    _tPenDown     = YES ;
    _tPenMode     = NSCompositingOperationSourceOver ;
    _tPenSize     = NSBezierPath.defaultLineWidth ;
    _tScaleX      = 1.0 ;
    _tScaleY      = 1.0 ;

    _turtleSize      = 45 ;
    _turtleImageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, _turtleSize, _turtleSize)] ;
    [self addSubview:_turtleImageView] ;
    [self defaultTurtleImage] ;

    _pColorNumber = 0 ;
    _bColorNumber = 7 ;
    _pColor       = penColors[_pColorNumber][1] ;
    _bColor       = penColors[_bColorNumber][1] ;

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

    _pInitColor   = _pColor ;
    _bInitColor   = _bColor ;

    _commandList  = [NSMutableArray array] ;

    self.layer.backgroundColor = _bColor.CGColor ;
    self.needsDisplay = !(_neverRender || _renderingPaused) ;
}

- (void)updateTurtle {
    if (!(_neverRender || _renderingPaused)) {
        CGFloat xOriginOffset = self.frame.size.width / 2 ;
        CGFloat yOriginOffset = self.frame.size.height / 2 ;

        _turtleImageView.frameCenterRotation = 0 ;
        _turtleImageView.frame = NSMakeRect(
            xOriginOffset + _tX - _turtleSize / 2,
            yOriginOffset + _tY - _turtleSize / 2,
            _turtleSize,
            _turtleSize
        ) ;
        _turtleImageView.frameCenterRotation = -_tHeading ;
        _turtleImageView.needsDisplay = YES ;
    }
}

- (BOOL)validateCommand:(NSUInteger)cmd withArguments:(nullable NSArray *)arguments
                                                error:(NSError * __autoreleasing *)error {
    NSUInteger cmdCount = wrappedCommands.count ;
    NSString *errMsg = nil ;

    if (cmd < cmdCount) {
        NSArray    *cmdDetails      = wrappedCommands[cmd] ;
        NSString   *cmdName         = cmdDetails[0] ;
        NSUInteger expectedArgCount = [(NSNumber *)cmdDetails[3] unsignedIntegerValue] ;
        NSUInteger actualArgCount   = (arguments) ? arguments.count : 0 ;

        if (expectedArgCount == actualArgCount) {
            if (expectedArgCount > 0) {
                for (NSUInteger i = 0 ; i < expectedArgCount ; i++) {
                    NSString *expectedArgType = cmdDetails[4 + i] ;
                    if ([expectedArgType isKindOfClass:[NSString class]]) {
                        if ([expectedArgType isEqualToString:@"number"]) {
                            if (![(NSObject *)arguments[i] isKindOfClass:[NSNumber class]]) {
                                errMsg = [NSString stringWithFormat:@"expected %@ for argument %lu of %@", expectedArgType, (i + 1), cmdName] ;
                                break ;
                            }
                            if (!isfinite([(NSNumber *)arguments[i] doubleValue])) {
                                errMsg = [NSString stringWithFormat:@"argument %lu of %@ must be a finite number", (i + 1), cmdName] ;
                                break ;
                            }
                        } else if ([expectedArgType isEqualToString:@"string"]) {
                            if (![(NSObject *)arguments[i] isKindOfClass:[NSString class]]) {
                                errMsg = [NSString stringWithFormat:@"expected %@ for argument %lu of %@", expectedArgType, (i + 1), cmdName] ;
                                break ;
                            }
                        } else {
                            errMsg = [NSString stringWithFormat:@"invalid definition for %@: argument type %@ not supported", cmdName, expectedArgType] ;
                            break ;
                        }
                    } else if ([expectedArgType isKindOfClass:[NSArray class]]) {
                        NSArray *list = arguments[i] ;
                        if (![list isKindOfClass:[NSArray class]]) {
                            errMsg = [NSString stringWithFormat:@"expected table for argument %lu of %@", (i + 1), cmdName] ;
                            break ;
                        }

                        NSArray *expectedTableArgTypes = (NSArray *)expectedArgType ;
                        for (NSUInteger j = 0 ; i < expectedTableArgTypes.count ; j++) {
                            expectedArgType = expectedTableArgTypes[j] ;
                            if ([expectedArgType isKindOfClass:[NSString class]]) {
                                if ([expectedArgType isEqualToString:@"number"]) {
                                    if (![(NSObject *)list[j] isKindOfClass:[NSNumber class]]) {
                                        errMsg = [NSString stringWithFormat:@"expected %@ for index %lu of argument %lu of %@", expectedArgType, (j + 1), (i + 1), cmdName] ;
                                        break ;
                                    }
                                    if (!isfinite([(NSNumber *)list[j] doubleValue])) {
                                        errMsg = [NSString stringWithFormat:@"index %lu of argument %lu of %@ must be a finite number", (j + 1), (i + 1), cmdName] ;
                                        break ;
                                    }
                                } else if ([expectedArgType isEqualToString:@"string"]) {
                                    if (![(NSObject *)list[j] isKindOfClass:[NSString class]]) {
                                        errMsg = [NSString stringWithFormat:@"expected %@ for argument %lu, index %lu of %@", expectedArgType, (i + 1), (j + 1), cmdName] ;
                                        break ;
                                    }
                                } else {
                                    errMsg = [NSString stringWithFormat:@"invalid definition for %@: argument type %@ in table not supported", cmdName, expectedArgType] ;
                                    break ;
                                }
                            } else {
                                errMsg = [NSString stringWithFormat:@"invalid definition for %@: argument type %@ in table not supported", cmdName, [expectedArgType className]] ;
                                break ;
                            }
                        }
                        if (errMsg) break ;
                    } else {
                        errMsg = [NSString stringWithFormat:@"invalid definition for %@: argument type %@ not supported", cmdName, [expectedArgType className]] ;
                        break ;
                    }
                }

                // command specific validataion
                if (!errMsg) {
                    if (cmd == 15 || cmd == 16) { // pensize / penwidth
                        CGFloat number = [(NSNumber *)arguments[0] doubleValue] ;
                        if (number < 0) errMsg = [NSString stringWithFormat:@"%@: width must be positive", cmdName] ;
                    } else if (cmd == 18) { // setscrunch
                        CGFloat number = [(NSNumber *)arguments[0] doubleValue] ;
                        if (number < 0) errMsg = [NSString stringWithFormat:@"%@: xscale must be positive", cmdName] ;
                        number = [(NSNumber *)arguments[1] doubleValue] ;
                        if (number < 0) errMsg = [NSString stringWithFormat:@"%@: yscale must be positive", cmdName] ;
                    }
                }
            }
        } else {
            errMsg = [NSString stringWithFormat:@"%@ requires %lu arguments but %lu were provided", cmdName, expectedArgCount, actualArgCount] ;
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

- (void)updateStateWithCommand:(NSUInteger)cmd andArguments:(nullable NSArray *)arguments {
    NSMutableDictionary *stepAttributes = _commandList.lastObject[1] ;

    CGFloat x = _tX ;
    CGFloat y = _tY ;

    switch(cmd) {
        case  0:   // forward
        case  1:   // back
        case  4:   // setpos
        case  5:   // setxy
        case  6:   // setx
        case  7:   // sety
        case  9: { // home
            if (cmd < 2) {
                CGFloat headingInRadians = _tHeading * M_PI / 180 ;
                CGFloat distance = [(NSNumber *)arguments[0] doubleValue] ;
                if (cmd == 1) distance = -distance ;
                _tX = x + distance * sin(headingInRadians) * _tScaleX ;
                _tY = y + distance * cos(headingInRadians) * _tScaleY ;
            } else if (cmd == 4) {
                NSArray *list = (NSArray *)arguments[0] ;
                _tX = [(NSNumber *)list[0] doubleValue] * _tScaleX ;
                _tY = [(NSNumber *)list[1] doubleValue] * _tScaleY ;
            } else if (cmd == 5) {
                _tX = [(NSNumber *)arguments[0] doubleValue] * _tScaleX ;
                _tY = [(NSNumber *)arguments[1] doubleValue] * _tScaleY ;
            } else if (cmd == 6) {
                _tX = [(NSNumber *)arguments[0] doubleValue] * _tScaleX ;
            } else if (cmd == 7) {
                _tY = [(NSNumber *)arguments[0] doubleValue] * _tScaleY ;
            } else if (cmd == 9) {
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
            }
        } break ;

        case  2:   // left
        case  3:   // right
        case  8: { // setheading
            CGFloat angle = [(NSNumber *)arguments[0] doubleValue] ;
            if (cmd == 2) {
                angle = _tHeading - angle ;
            } else if (cmd == 3) {
                angle = _tHeading + angle ;
         // } else if (cmd == 8) { // NOP since first line in this block does this
         //     angle = angle ;
            }
            _tHeading = fmod(angle, 360) ;
        } break ;

        case 10:   // pendown
        case 11: { // penup
            _tPenDown = (cmd == 10) ;
        } break ;

        case 12:   // penpaint
        case 13:   // penerase
        case 14: { // penreverse
            _tPenMode = (cmd == 14) ? NSCompositingOperationDifference :
                        (cmd == 13) ? NSCompositingOperationDestinationOut :
                                      NSCompositingOperationSourceOver ;
            _tPenDown = YES ;
            stepAttributes[@"penMode"] = @(_tPenMode) ;
        } break ;
        case 15:   // setpensize
        case 16: { // setpenwidth
            _tPenSize = [(NSNumber *)arguments[0] doubleValue] ;
        } break ;
        case 17: { // arc
            CGFloat angle  = [(NSNumber *)arguments[0] doubleValue] ;
            NSBezierPath *strokePath = [NSBezierPath bezierPath] ;
            strokePath.lineWidth = _tPenSize ;
            [strokePath appendBezierPathWithArcWithCenter:NSMakePoint(0, 0)
                                                   radius:[(NSNumber *)arguments[1] doubleValue]
                                               startAngle:((360 - _tHeading) + 90)
                                                 endAngle:((360 - (_tHeading + angle)) + 90)
                                                clockwise:(angle > 0)] ;
            NSAffineTransform *scrunch = [[NSAffineTransform alloc] init] ;
            [scrunch scaleXBy:_tScaleX yBy:_tScaleY] ;
            [scrunch translateXBy:(_tX / _tScaleX) yBy:(_tY / _tScaleY)] ;
            [strokePath transformUsingAffineTransform:scrunch] ;
            stepAttributes[@"stroke"] = strokePath ;
        } break ;
        case 18: { // setscrunch
            _tScaleX = [(NSNumber *)arguments[0] doubleValue] ;
            _tScaleY = [(NSNumber *)arguments[1] doubleValue] ;
        } break ;
        default: {
            [LuaSkin logWarn:[NSString stringWithFormat:@"%s:@updateStateWithCommand:andArguments: - command code %lu currently unsupported; ignoring", USERDATA_TAG, cmd]] ;
            return ;
        }
    }
}

- (BOOL)appendCommand:(NSUInteger)cmd withArguments:(nullable NSArray *)arguments
                                              error:(NSError * __autoreleasing *)error {

    BOOL isGood = [self validateCommand:cmd withArguments:arguments error:error] ;
    if (isGood) {
        NSArray *newCommand = @[ @(cmd), [NSMutableDictionary dictionary] ] ;
        if (arguments) newCommand[1][@"arguments"] = arguments ;
        [_commandList addObject:newCommand] ;
        [self updateStateWithCommand:cmd andArguments:arguments] ;

        if ([(NSNumber *)(wrappedCommands[cmd][2]) boolValue]) {
            self.needsDisplay = !(_neverRender || _renderingPaused) ;
        } else {
            [self updateTurtle] ;
        }
    }

    return isGood ;
}

- (NSImage *)renderToImage {
// NOTE: this should track drawRect, but ignore background color changes as they aren't captured by this
    NSImage *newImage = [[NSImage alloc] initWithSize:self.bounds.size] ;
    [newImage lockFocus] ;
        NSGraphicsContext *gc = [NSGraphicsContext currentContext];
        [gc saveGraphicsState];

        CGFloat xOriginOffset = self.frame.size.width / 2 ;
        CGFloat yOriginOffset = self.frame.size.height / 2 ;

        // use transform so origin shifted to center of view
        NSAffineTransform *shiftOriginToCenter = [[NSAffineTransform alloc] init] ;
        [shiftOriginToCenter translateXBy:xOriginOffset yBy:yOriginOffset] ;
        [shiftOriginToCenter concat] ;

        [_pInitColor setStroke] ;
        gc.compositingOperation = _tInitPenMode ;

        for (NSArray *entry in _commandList) {
            NSMutableDictionary *properties = entry[1] ;

            NSBezierPath *strokePath = properties[@"stroke"] ;
            if (strokePath) [strokePath stroke] ;

            NSNumber *compositeMode = properties[@"penMode"] ;
            if (compositeMode) gc.compositingOperation = compositeMode.unsignedIntegerValue ;
        }

        [gc restoreGraphicsState] ;
    [newImage unlockFocus] ;
    return newImage ;
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

#pragma mark - Module Methods

static int turtle_pauseRendering(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, turtleCanvas.renderingPaused) ;
    } else {
        turtleCanvas.renderingPaused = lua_toboolean(L, 2) ;
        turtleCanvas.needsDisplay = !turtleCanvas.renderingPaused ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int turtle_asImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    NSImage *image = [turtleCanvas renderToImage] ;
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
        [skin pushNSObject:turtleCanvas.turtleImageView.image] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            [turtleCanvas defaultTurtleImage] ;
        } else {
            NSImage *newTurtle = [skin toNSObjectAtIndex:2] ;
            turtleCanvas.turtleImageView.image = newTurtle ;
            [turtleCanvas updateTurtle] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int turtle_turtleSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)turtleCanvas.turtleSize) ;
    } else {
        lua_Integer newSize = lua_tointeger(L, 2) ;
        if (newSize < 1) newSize = 1 ;
        turtleCanvas.turtleSize = (NSUInteger)newSize ;
        [turtleCanvas updateTurtle] ;
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
    BOOL raw = (lua_gettop(L) == 1) ? NO : (BOOL)lua_toboolean(L, 2) ;

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
    [turtleCanvas appendCommand:(NSUInteger)command withArguments:arguments error:&errMsg] ;

    if (errMsg) {
        // error is handled in lua wrapper
        [skin pushNSObject:errMsg.localizedDescription] ;
    } else {
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int turtle_pos(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_newtable(L) ;
    lua_pushnumber(L, turtleCanvas.tX / turtleCanvas.tScaleX) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushnumber(L, turtleCanvas.tY / turtleCanvas.tScaleY) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    return 1 ;
}

static int turtle_xcor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushnumber(L, turtleCanvas.tX / turtleCanvas.tScaleX) ;
    return 1 ;
}

static int turtle_ycor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushnumber(L, turtleCanvas.tY / turtleCanvas.tScaleY) ;
    return 1 ;
}

static int turtle_heading(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushnumber(L, turtleCanvas.tHeading) ;
    return 1 ;
}

static int turtle_clean(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    [turtleCanvas resetForClean] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int turtle_clearscreen(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    turtleCanvas.tX       = 0.0 ;
    turtleCanvas.tY       = 0.0 ;
    turtleCanvas.tHeading = 0.0 ;
    return turtle_clean(L) ;
}

static int turtle_shownp(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, !turtleCanvas.turtleImageView.hidden) ;
    return 1 ;
}

static int turtle_pendownp(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, turtleCanvas.tPenDown) ;
    return 1 ;
}

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
        case NSCompositingOperationDifference:     lua_pushstring(L, "REVERSE") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"** unknown compositing mode: %lu", turtleCanvas.tPenMode]] ;
    }
#pragma clang diagnostic pop

    return 1 ;
}

static int turtle_pensize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_newtable(L) ;
    lua_pushnumber(L, turtleCanvas.tPenSize) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushnumber(L, turtleCanvas.tPenSize) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    return 1 ;
}

static int turtle_penwidth(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushnumber(L, turtleCanvas.tPenSize) ;
    return 1 ;
}

static int turtle_scrunch(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_newtable(L) ;
    lua_pushnumber(L, turtleCanvas.tScaleX) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushnumber(L, turtleCanvas.tScaleY) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    return 1 ;
}

static int turtle_showturtle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    turtleCanvas.turtleImageView.hidden = NO ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int turtle_hideturtle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    turtleCanvas.turtleImageView.hidden = YES ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

// Probably to be wrapped, if implemented
    // 6.3 Turtle and Window Control
        //   fill
        //   filled
        //   label
        //   setlabelheight
    // 6.5 Pen and Background Control
        //   setpencolor
        //   setpalette
        //   setbackground
    // suggested by JS logo at https://www.calormen.com/jslogo/#
        //   setlabelfont ['serif', 'sans-serif', 'cursive', 'fantasy', 'monospace']

// Probably defined in here, if implemented
    // 6.4 Turtle and Window Queries
        //   labelsize
    // 6.6 Pen Queries
        //   pencolor
        //   palette
        //   background
    // suggested by JS logo at https://www.calormen.com/jslogo/#
        //   labelfont

// Not Sure Yet
    // 6.5 Pen and Background Control
        //   setpen
    // 6.6 Pen Queries
        //   pen
    // 6.7 Saving and Loading Pictures
        //   savepict -- could do in lua, leveraging _commands
        //   loadpict -- could do in lua, leveraging _appendCommand after resetting state

// Probably Not
    // 6.3 Turtle and Window Control
        //   wrap            -- marked as nop
        //   window          -- marked as nop
        //   fence           -- marked as nop
        //   textscreen      -- marked as nop
        //   fullscreen      -- marked as nop
        //   splitscreen     -- marked as nop
        //   refresh         -- marked as nop
        //   norefresh       -- marked as nop
    // 6.5 Pen and Background Control
        //   setpenpattern
    // 6.6 Pen Queries
        //   penpattern
    // 6.7 Saving and Loading Pictures
        //   epspict
    // 6.8 Mouse Queries
        //   mousepos
        //   clickpos
        //   buttonp
        //   button

#pragma mark - Module Constants

static int turtle_CommandsToBeWrapped(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:wrappedCommands] ;
    return 1 ;
}

static int turtle_assignPenColorsFromLua(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    penColors = [skin toNSObjectAtIndex:1] ;
    return 0 ;
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

id toHSCanvasTurtleViewFromLua(lua_State *L, int idx) {
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
    CGFloat maxAbsX = viewSize.width / 2 ;
    CGFloat maxAbsY = viewSize.height / 2 ;
    NSString *title = [NSString stringWithFormat:@"X ∈ [%.2f, %.2f], Y ∈ [%.2f, %.2f]",
        -maxAbsX, maxAbsX, -maxAbsY, maxAbsY] ;

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
    {"pos",             turtle_pos},
    {"xcor",            turtle_xcor},
    {"ycor",            turtle_ycor},
    {"heading",         turtle_heading},
    {"clean",           turtle_clean},
    {"clearscreen",     turtle_clearscreen},
    {"showturtle",      turtle_showturtle},
    {"hideturtle",      turtle_hideturtle},
    {"shownp",          turtle_shownp},
    {"pendownp",        turtle_pendownp},
    {"penmode",         turtle_penmode},
    {"pensize",         turtle_pensize},
    {"penwidth",        turtle_penwidth},
    {"scrunch",         turtle_scrunch},

    {"_pause",          turtle_pauseRendering},
    {"_image",          turtle_asImage},
    {"_cmdCount",       turtle_commandCount},
    {"_appendCommand",  turtle_appendCommand},
    {"_turtleImage",    turtle_turtleImage},
    {"_turtleSize",     turtle_turtleSize},
    {"_canvas",         turtle_parentView},
    {"_commands",       turtle_commandDump},

    {"__tostring",      userdata_tostring},
    {"__eq",            userdata_eq},
    {"__gc",            userdata_gc},
    {NULL,              NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",          turtle_new},
    {"_shareColors", turtle_assignPenColorsFromLua},
    {NULL,  NULL}
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

    wrappedCommands = @[
        // name            synonyms                              visual  #args type(s)
        @[ @"forward",     @[ @"fd" ],                           @(YES), @(1), @"number" ],
        @[ @"back",        @[ @"bk" ],                           @(YES), @(1), @"number" ],
        @[ @"left",        @[ @"lt" ],                           @(NO),  @(1), @"number" ],
        @[ @"right",       @[ @"rt" ],                           @(NO),  @(1), @"number" ],
        @[ @"setpos",      @[ @"setPos" ],                       @(YES), @(1), @[ @(2), @"number", @"number" ] ],
        @[ @"setxy",       @[ @"setXY" ],                        @(YES), @(2), @"number", @"number" ],
        @[ @"setx",        @[ @"setX" ],                         @(YES), @(1), @"number" ],
        @[ @"sety",        @[ @"setY" ],                         @(YES), @(1), @"number" ],
        @[ @"setheading",  @[ @"seth", @"setH", @"setHeading" ], @(NO),  @(1), @"number" ],
        @[ @"home",        @[],                                  @(YES), @(0) ],
        @[ @"pendown",     @[ @"pd", @"penDown" ],               @(NO),  @(0) ],
        @[ @"penup",       @[ @"pu", @"penUp" ],                 @(NO),  @(0) ],
        @[ @"penpaint",    @[ @"ppt", @"penPaint" ],             @(NO),  @(0) ],
        @[ @"penerase",    @[ @"pe", @"penErase" ],              @(NO),  @(0) ],
        @[ @"penreverse",  @[ @"px", @"penReverse" ],            @(NO),  @(0) ],
        @[ @"setpensize",  @[ @"setPenSize"],                    @(NO),  @(2), @"number", @"number" ],
        @[ @"setpenwidth", @[ @"setPenWidth"],                   @(NO),  @(1), @"number" ],
        @[ @"arc",         @[],                                  @(YES), @(2), @"number", @"number" ],
        @[ @"setscrunch",  @[ @"setScrunch" ],                   @(NO),  @(2), @"number", @"number" ],
    //     @"fill",
    //     @"filled",
    //     @"label",
    //     @"setlabelheight",
    //     @"setpencolor",
    //     @"setpalette",
    //     @"setpenpattern",
    //     @"setpen",
    //     @"setbackground",

    ] ;
    turtle_CommandsToBeWrapped(L) ; lua_setfield(L, -2, "_wrappedCommands") ;

    return 1;
}
