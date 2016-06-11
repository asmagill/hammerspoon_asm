// Redo callback details per description in `hs._asm.canvas:elements`
// Should we optionally allow turning off NSView rect clipping like drawing does always?
// Start coding the hard parts, you monkey!

#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG "hs._asm.canvas"
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

@interface ASMCanvasWindow : NSPanel <NSWindowDelegate>
@property                   int          selfRef ;
@property (nonatomic, copy) NSDictionary *elementDefaults ;
@property (nonatomic, copy) NSArray      *elementList ;
@end

@interface ASMCanvasView : NSView
@property int clickDownRef;
@property int clickUpRef;
@end


#pragma mark - Support Functions and Classes

// NOTE: Define and validate functions for element defaults -- put up here to help ensure that they get edited at the same time when defaults are added / removed from the list, rather than hope I remember to do so in multiple places...

static NSDictionary *getElementDefaultsDictionary() {
    return @{
        @"absolutePosition" : @(NO),
        @"absoluteSize"     : @(NO),
        @"stroke"           : @(YES),
        @"strokeColor"      : [NSColor blackColor],
        @"strokeWidth"      : @([NSBezierPath defaultLineWidth]),
        @"fill"             : @(YES),
        @"fillColor"        : [NSColor redColor],
        @"fillGradient"     : @{
//                                   @"startColor" : [NSNull null],
//                                   @"endColor"   : [NSNull null],
                                  @"angle"      : @(0.0),
                              },
        @"roundedRectRadii" : @{
                                  @"xRadius" : @(0.0),
                                  @"yRadius" : @(0.0),
                              },
        @"textFont"         : [[NSFont systemFontOfSize: 27] fontName],
        @"textSize"         : @(27.0),
        @"textStyle"        : @{
                                  @"alignment" : @"natural",
                                  @"lineBreak" : @"wordWrap",
                              },
        @"textColor"        : [NSColor colorWithCalibratedWhite:1.0 alpha:1.0],
        @"imageFrameStyle"  : @"none",
        @"imageAlignment"   : @"center",
        @"imageAnimates"    : @(YES),
        @"imageScaling"     : @"scaleProportionally",
        @"imageRotation"    : @(0.0),
    } ;
}

static BOOL validateElementAttribute(NSString *keyName, id valueForKey) {
    LuaSkin *skin = [LuaSkin shared] ;
    BOOL elementIsGood = YES ;
    NSString *errorMessage = @"element defaults validation failed, but no error specified" ;
    if ([keyName isEqualToString:@"absolutePosition"]) {
        if (!([valueForKey isKindOfClass:[NSNumber class]] && !strcmp(@encode(BOOL), [valueForKey objCType]))) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a boolean", keyName] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"absoluteSize"]) {
        if (!([valueForKey isKindOfClass:[NSNumber class]] && !strcmp(@encode(BOOL), [valueForKey objCType]))) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a boolean", keyName] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"stroke"]) {
        if (!([valueForKey isKindOfClass:[NSNumber class]] && !strcmp(@encode(BOOL), [valueForKey objCType]))) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a boolean", keyName] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"strokeColor"]) {
        if (![valueForKey isKindOfClass:[NSColor class]]) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a color", keyName] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"strokeWidth"]) {
        if (![valueForKey isKindOfClass:[NSNumber class]]) {
            errorMessage = [NSString stringWithFormat:@"angle field of %@ must specify a number", keyName] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"fill"]) {
        if (!([valueForKey isKindOfClass:[NSNumber class]] && !strcmp(@encode(BOOL), [valueForKey objCType]))) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a boolean", keyName] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"fillColor"]) {
        if (![valueForKey isKindOfClass:[NSColor class]]) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a color", keyName] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"fillGradient"]) {
        if (![valueForKey isKindOfClass:[NSDictionary class]]) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a table with startColor, endColor and angle keys", keyName] ;
            elementIsGood = NO ;
        } else if (([valueForKey objectForKey:@"startColor"] || [valueForKey objectForKey:@"endColor"]) &&
           !([valueForKey objectForKey:@"startColor"] && [valueForKey objectForKey:@"endColor"])) {
            errorMessage = [NSString stringWithFormat:@"you must specify both or neither of the startColor and endColor fields for %@", keyName] ;
            elementIsGood = NO ;
        } else if ([valueForKey objectForKey:@"startColor"] && ![[valueForKey objectForKey:@"startColor"] isKindOfClass:[NSColor class]]) {
            errorMessage = [NSString stringWithFormat:@"startColor field of %@ must specify a color", keyName] ;
            elementIsGood = NO ;
        } else if ([valueForKey objectForKey:@"endColor"] && ![[valueForKey objectForKey:@"endColor"] isKindOfClass:[NSColor class]]) {
            errorMessage = [NSString stringWithFormat:@"endColor field of %@ must specify a color", keyName] ;
            elementIsGood = NO ;
        } else if (![[valueForKey objectForKey:@"angle"] isKindOfClass:[NSNumber class]]) {
            errorMessage = [NSString stringWithFormat:@"angle field of %@ must specify a number", keyName] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"roundedRectRadii"]) {
        if (![valueForKey isKindOfClass:[NSDictionary class]]) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a table with XRadius and yRadius keys", keyName] ;
            elementIsGood = NO ;
        } else if (![[valueForKey objectForKey:@"xRadius"] isKindOfClass:[NSNumber class]]) {
            errorMessage = [NSString stringWithFormat:@"xRadius field of %@ must specify a number", keyName] ;
            elementIsGood = NO ;
        } else if (![[valueForKey objectForKey:@"yRadius"] isKindOfClass:[NSNumber class]]) {
            errorMessage = [NSString stringWithFormat:@"yRadius field of %@ must specify a number", keyName] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"textFont"]) {
        if (![valueForKey isKindOfClass:[NSString class]]) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a string", keyName] ;
            elementIsGood = NO ;
        } else if (![NSFont fontWithName:valueForKey size:0.0]) {
            errorMessage = [NSString stringWithFormat:@"%@ is not a valid font for %@", valueForKey, keyName] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"textSize"]) {
        if (![valueForKey isKindOfClass:[NSNumber class]]) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a number", keyName] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"textStyle"]) {
        NSArray *validAlignments = @[ @"left", @"right", @"center", @"justified", @"natural" ];
        NSArray *validLineBreaks = @[ @"wordWrap", @"charWrap", @"clip", @"truncateHead", @"truncateTail", @"truncateMiddle" ];
        if (![valueForKey isKindOfClass:[NSDictionary class]]) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a table with alignment and lineBreak keys", keyName] ;
            elementIsGood = NO ;
        } else if (!([[valueForKey objectForKey:@"alignment"] isKindOfClass:[NSString class]] && [validAlignments containsObject:[valueForKey objectForKey:@"alignment"]])) {
            errorMessage = [NSString stringWithFormat:@"alignment field of %@ must specify a string with a value in { %@ }", keyName, [validAlignments componentsJoinedByString: @", "]] ;
            elementIsGood = NO ;
        } else if (!([[valueForKey objectForKey:@"lineBreak"] isKindOfClass:[NSString class]] && [validLineBreaks containsObject:[valueForKey objectForKey:@"lineBreak"]])) {
            errorMessage = [NSString stringWithFormat:@"lineBreak field of %@ must specify a string with a value in { %@ }", keyName, [validLineBreaks componentsJoinedByString: @", "]] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"textColor"]) {
        if (![valueForKey isKindOfClass:[NSColor class]]) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a color", keyName] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"imageFrameStyle"]) {
        NSArray *valid = @[ @"none", @"photo", @"bezel", @"groove", @"button" ] ;
        if (!([valueForKey isKindOfClass:[NSString class]] && [valid containsObject:valueForKey])) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a string with a value in { %@ }", keyName, [valid componentsJoinedByString: @", "]] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"imageAlignment"]) {
        NSArray *valid = @[ @"center", @"top", @"topLeft", @"topRight", @"left", @"bottom", @"bottomLeft", @"bottomRight", @"right" ] ;
        if (!([valueForKey isKindOfClass:[NSString class]] && [valid containsObject:valueForKey])) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a string with a value in { %@ }", keyName, [valid componentsJoinedByString: @", "]] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"imageAnimates"]) {
        if (!([valueForKey isKindOfClass:[NSNumber class]] && !strcmp(@encode(BOOL), [valueForKey objCType]))) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a boolean", keyName] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"imageScaling"]) {
        NSArray *valid = @[ @"shrinkToFit", @"scaleToFit", @"none", @"scaleProportionally" ] ;
        if (!([valueForKey isKindOfClass:[NSString class]] && [valid containsObject:valueForKey])) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a string with a value in { %@ }", keyName, [valid componentsJoinedByString: @", "]] ;
            elementIsGood = NO ;
        }
    } else if ([keyName isEqualToString:@"imageRotation"]) {
        if (![valueForKey isKindOfClass:[NSNumber class]]) {
            errorMessage = [NSString stringWithFormat:@"%@ must specify a number", keyName] ;
            elementIsGood = NO ;
        }
    } else {
        errorMessage = [NSString stringWithFormat:@"%@ is not a recognized element attribute", keyName] ;
        elementIsGood = NO ;
    }
    if (!elementIsGood) {
        [skin logBreadcrumb:errorMessage] ;
        [skin pushNSObject:errorMessage] ;
    }
    return elementIsGood ;
}

static BOOL validateDefaultsArray(NSDictionary *dictionaryToTest) {
    LuaSkin *skin = [LuaSkin shared] ;
    __block BOOL elementsAreGood = YES ;
    NSArray *defaultElements = [getElementDefaultsDictionary() allKeys] ;

    [dictionaryToTest enumerateKeysAndObjectsUsingBlock:^(id keyName, id valueForKey, BOOL *stop) {
        if (![defaultElements containsObject:keyName]) {
            NSString *errorMessage = [NSString stringWithFormat:@"%@ is not a default element attribute", keyName] ;
            [skin logBreadcrumb:errorMessage] ;
            [skin pushNSObject:errorMessage] ;
            elementsAreGood = NO ;
            *stop = YES ;
        } else if (!validateElementAttribute(keyName, valueForKey)) {
            elementsAreGood = NO ;
            *stop = YES ;
        }
    }];
    return elementsAreGood ;
}

// some keys allow Lua input that is not readily identifiable by the [LuaSkin toNSObjectAtIndex:] parser, or we allow some "laziness" on the part of the programmer either to make things cleaner/easier or for historical reasons... consolidate the fixes in one place
static id massageKeyValueFor(NSString *keyName, id oldValue) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_State *L = [skin L] ;

    id newValue = oldValue ; // assume we're not changing anything

    // catch "...Color" tables missing the __luaSkinType = "NSColor" key-value pair
    if ([keyName hasSuffix:@"Color"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        lua_pushstring(L, "NSColor") ;
        lua_setfield(L, -2, "__luaSkinType") ;
        newValue = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

    // recurse into fields which have subfields to check those as well -- this should be done last in case the dictionary can be coerced into an object, like the color tables handled above
    } else if ([oldValue isKindOfClass:[NSDictionary class]]) {
        newValue = [[NSMutableDictionary alloc] init] ;
        [oldValue enumerateKeysAndObjectsUsingBlock:^(id keyName, id valueForKey, __unused BOOL *stop) {
            [newValue setObject:massageKeyValueFor(keyName, valueForKey) forKey:keyName] ;
        }] ;
    }

    return newValue ;
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

        _elementDefaults = getElementDefaultsDictionary() ;
        _elementList     = nil ;
    }
    return self;
}

#pragma mark - NSWindowDelegate Methods

- (BOOL)windowShouldClose:(id __unused)sender {
    return NO;
}

#pragma mark - Window Animation Methods

- (void)fadeIn:(NSTimeInterval)fadeTime {
    [self setAlphaValue:0.f];
    [self makeKeyAndOrderFront:nil];
    [NSAnimationContext beginGrouping];
      [[NSAnimationContext currentContext] setDuration:fadeTime];
      [[self animator] setAlphaValue:1.f];
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
          if (bself) {
              if (deleteCanvas) {
              LuaSkin *skin = [LuaSkin shared] ;
                  lua_State *L = [skin L] ;
                  lua_pushcfunction(L, userdata_gc) ;
                  [skin pushLuaRef:refTable ref:_selfRef] ;
                  if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
                      [skin logBreadcrumb:[NSString stringWithFormat:@"%s:error invoking _gc for delete (with fade) method:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
                      lua_pop(L, 1) ;
                      [bself close] ;  // the least we can do is close the canvas if an error occurs with __gc
                  }
              } else {
                  [bself orderOut:nil];
                  [bself setAlphaValue:1.f];
              }
          }
      }];
      [[self animator] setAlphaValue:0.f];
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

// The meat of the module...
// - (void)drawRect:(NSRect)rect {
// }

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
// TODO: update non-abs elements here, or flag for drawRect?
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
        lua_pushnumber(L, [canvasWindow alphaValue]) ;
    } else {
        CGFloat newLevel = luaL_checknumber(L, 2);
        [canvasWindow setAlphaValue:((newLevel < 0.0) ? 0.0 : ((newLevel > 1.0) ? 1.0 : newLevel))] ;
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

/// hs.canvas:level([level]) -> canvasObject | currentValue
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

/// hs.canvas:behavior([behavior]) -> canvasObject | currentValue
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
///  * See also (hs._asm.canvas:isOccluded)[#isOccluded].
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
///  * See also (hs._asm.canvas:isShowing)[#isShowing].
static int canvas_isOccluded(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    lua_pushboolean(L, ([canvasWindow occlusionState] & NSWindowOcclusionStateVisible) != NSWindowOcclusionStateVisible) ;
    return 1 ;
}

/// hs._asm.canvas:allElementDefaults() -> table
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
///  * Any key may be set in an element declaration to specify an alternate value when that element is rendered.
///  * To change the defaults for the canvas, use [hs._asm.canvas:elementDefault](#elementDefault).
static int canvas_allElementDefaults(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    [skin pushNSObject:canvasWindow.elementDefaults] ;
    return 1 ;
}

/// hs._asm.canvas:elementDefault(keyName, [newValue]) -> canvasObject | currentValue
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
///  * Any key may be set in an element declaration to specify an alternate value when that element is rendered.
//   * To get a table containing all of the current defaults, use [hs._asm.canvas:elementDefaultsTable](#elementDefaultsTable).
static int canvas_elementDefault(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TBREAK] ;

    ASMCanvasWindow *canvasWindow = [skin luaObjectAtIndex:1 toClass:"ASMCanvasWindow"] ;
    NSString *keyName = [skin toNSObjectAtIndex:2] ;

    if (![canvasWindow.elementDefaults objectForKey:keyName]) {
        return luaL_error(L, "%s is not an element default", [keyName UTF8String]) ;
    }

    if (lua_gettop(L) == 2) {
        [skin pushNSObject:[canvasWindow.elementDefaults objectForKey:keyName]] ;
    } else {
        NSMutableDictionary *bagOfHolding = [canvasWindow.elementDefaults mutableCopy] ;
        id keyValue = massageKeyValueFor(keyName, [skin toNSObjectAtIndex:3]) ;
        [bagOfHolding setObject:keyValue forKey:keyName] ;
        if (validateDefaultsArray(bagOfHolding)) {
            canvasWindow.elementDefaults = bagOfHolding ;
        } else {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(L, 1) ;
            return luaL_error(L, [errorMessage UTF8String]) ;
        }
        canvasWindow.contentView.needsDisplay = true ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.canvas:elements([elementsArray]) -> canvasObject | currentValue
/// Method
/// Get or set the canvas elements for the canvas.
///
/// Parameters:
///  * `elementsArray` - An optional array specifying the canvas elements which are drawn into this canvas. The elements will be drawn in order, and each element in the array is a table with one or more of the following key-value pairs:
///    * REQUIRED key-value pairs:
///      * `type` - Specifies the type of canvas element. This key is required for all canvas elements of the canvas. Valid canvas element types are:
///        * `arc`           - Specifies an arc inscribed on a circle defined by its center and radius.
///        * `circle`        - Specifies a circle defined by its center and radius.
///        * `curve`         - *unimplemented at present* Specifies a single bezier curve. May become syntactic sugar for `segments`.
///        * `ellipticalArc` - Specifies an arc which can be inscribed on a circle or an oval. Internally, the `arc` type is converted into this type.
///        * `image`         - Specifies an image as provided by one of the `hs.image` constructors.
///        * `line`          - Specifies a single straight line. May become syntactic sugar for single item `segments`.
///        * `oval`          - Specifies an oval or circle. Internally, the `circle` type is converted into this type.
///        * `point`         - Specifies a single point (technically a unit rectangle, so may just be syntactic sugar for that)
///        * `rectangle`     - Specifies a rectangle, optionally with rounded corners
///        * `resetClip`     - Special type indicating that the clipping region should be reset to its initial state (i.e. just the boundaries of the canvas itself). No other key-value pairs included with this element will be examined.
///        * `segments`      - *unimplemented at present* Specifies multiple connected line or curve segments which can be closed (i.e. the starting point is also the ending point) or open.
///        * `text`          - Specifies text. Supports the simplified text model of `hs.drawing` as well as the more powerful `hs.styledtext` module.
///
///    * Optional key-value pairs for all element types:
///      * `absolutePosition` - *unimplemented at present* a boolean value specifying whether or not the canvas element's position is absolute within the canvas or relative. If the position is relative, it will be adjusted when the canvas is resized to reflect the changed canvas size and the object's relative distance from the origin (top-left) of the canvas. Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `false` unless changed.
///      * `absoluteSize"     - *unimplemented at present* a boolean value specifying whether or not the canvas element's size is absolute within the canvas or relative. If the size is relative, it will be adjusted when the canvas is resized to reflect the changed canvas size and the object's size relative to it. Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `false` unless changed.
///      * `addToClipRegion`  - *unimplemented at present* Use the canvas element's path as an addition to the canvas clipping path instead of as a visual element of the canvas. Clear all additions tot he clipping path by adding an element of type `resetClip`.
///      * `compositeRule`    - *unimplemented at present* A string which specifies how a canvas element is combined with the earlier elements of the canvas. Valid values for this field can be found in the (hs._asm.canvas.compositeTypes)[#compositeTypes] table. The default compositing rule for the canvas is `sourceOver`.
///      * `id`               - *unimplemented at present* A string or number used as a label which is included as an argument to any callback associated with a canvas element. If this field is not provided and a callback is required, the canvas elements index position in the elements array will be used instead. Since this number may change as you add or remove canvas elements to the canvas, it is recommended that you specify a value for this key if you enable any callbacks for the element.
///      * `trackMouseDown`   - *unimplemented at present* If this is true, and a callback function has been defined for the canvas, generate a callback when a mouse button is clicked within the bounds of this canvas element. The arguments to the callback function will be `canvasObject, "mouseDown", id`. Use `hs.eventtap.checkMouseButtons` within the callback to determine which mouse button is down, if a distinction is required. If multiple canvas elements overlap the location where the mouse click occurred, the order in which they are called back is undetermined. Defaults to nil (false).
///      * `trackMouseUp`     - *unimplemented at present* If this is true, and a callback function has been defined for the canvas, generate a callback when a mouse button is released within the bounds of this canvas element. The arguments to the callback function will be `canvasObject, "mouseUp", id`. If multiple canvas elements overlap the location where the mouse click occurred, the order in which they are called back is undetermined. Defaults to nil (false).
///      * `trackMouseEnter`  - *unimplemented at present* If this is true, and a callback function has been defined for the canvas, generate a callback when the mouse pointer enters the bounds of this canvas element. The arguments to the callback function will be `canvasObject, "mouseEnter", id`. If multiple canvas elements share the same boundary where the crossing occurred, the order in which they are called back is undetermined. Defaults to nil (false).
///      * `trackMouseExit`   - *unimplemented at present* If this is true, and a callback function has been defined for the canvas, generate a callback when the mouse pointer exits the bounds of this canvas element. The arguments to the callback function will be `canvasObject, "mouseExit", id`. If multiple canvas elements share the same boundary where the crossing occurred, the order in which they are called back is undetermined. Defaults to nil (false).
///      * `trackMouseMove`   - *unimplemented at present* If this is true, and a callback function has been defined for the canvas, generate a callback when the mouse pointer moves within the bounds of this canvas element. The arguments to the callback function will be `canvasObject, "mouseMove", id, x, y`, where `x` and `y` specify the mouse pointer's position within the canvas. If multiple canvas elements share the same boundary where the crossing occurred, the order in which they are called back is undetermined. Defaults to nil (false).
///
///    * The following key-value pairs are used to define the specifics for the canvas element type. Not all pairs will be applicable to all element types.
///      * `center`             - Used by the `arc` and `circle` canvas element types to specify the center of the circle. Defaults to `{ x = canvas.w / 2, y = canvas.w / 2 }`. See Notes section below concerning the `arc` and `circle` element types.
///      * `end`                - Used by the `line` canvas element type to specify the ending point of the line segment. Defaults to `{ x = canvas.w, y = canvas.h }` and will be copied into the element definition if not provided initially.
///      * `endAngle`           - Used by the `arc` and `ellipticalArc` canvas element types to specify the ending angle of the arc inscribed on the circle or oval. Defaults to `360` and will be copied into the element definition if not provided initially.
///      * `fill`               - A boolean flag, specifying whether or not a closed canvas element (most of them) should be filled in. Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `true` unless changed.
///      * `fillColor`          - A color table as supported by the `hs.drawing.color` module, specifying the fill color for a closed canvas element (most of them) when `fill` is true. Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `{ red = 1.0, alpha = 1.0 }` (red) unless changed.
///      * `fillGradient`       - A table specifying the starting color, ending color, and angle of a gradient which should be used to fill an object when `fill` is true. If the `startColor` and `endColor` keys of this table are set, this key will override the `fillColor` field. Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `{ startColor = nil, endColor = nil, angle = 0.0 }` unless changed.
///      * `flatness`           - *unimplemented at present*
///      * `flatten`            - *unimplemented at present*
///      * `frame`              - A rect-table specifying the bounding box (size) for the following canvas element types: `oval`, `ellipticalArc`, `image`, `rectangle`, `text`.  Defaults to `{ x = 0, y = 0, h = canvas.h, w = canvas.w }` and will be copied into the element definition if not provided initially.
///      * `image`              - An `hs.image` object specifying the image to be displayed for the canvas element `image` type.
///      * `imageAlignment`     - A string specifying the alignment of an image that doesn't fully fill an image canvas element's `frame`. Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `center` unless changed. Valid values for this string are:
///        * `topLeft`     - the image's top left corner will match the canvas element's top left corner
///        * `top`         - the image's top match the canvas element's top and will be centered horizontally
///        * `topRight`    - the image's top right corner will match the canvas element's top right corner
///        * `left`        - the image's left side will match the canvas element's left side and will be centered vertically
///        * `center`      - the image will be centered vertically and horizontally within the canvas element
///        * `right`       - the image's right side will match the canvas element's right side and will be centered vertically
///        * `bottomLeft`  - the image's bottom left corner will match the canvas element's bottom left corner
///        * `bottom`      - the image's bottom match the canvas element's bottom and will be centered horizontally
///        * `bottomRight` - the image's bottom right corner will match the canvas element's bottom right corner
///      * `imageAnimates`      - A boolean specifying whether or not an animated GIF image should cycle through its animation. Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `true` unless changed.
///      * `imageFrameStyle`    - A string specifying the type of frame should be around the image canvas element. Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `none` unless changed. Valid values for this string are:
///        * `none`   - no frame is drawing around the image
///        * `photo`  - a thin black outline with a white background and a dropped shadow.
///        * `bezel`  - a gray, concave bezel with no background that makes the image look sunken.
///        * `groove` - a thin groove with a gray background that looks etched around the image.
///        * `button` - a convex bezel with a gray background that makes the image stand out in relief, like a button.
///      * `imageRotation`      - A number specifying the the angle in degrees to rotate the image around its center in a clockwise direction. Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `0.0` unless changed.
///      * `imageScaling`       - A string specifying how an image is scaled within the frame of a canvas element containing the image. Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `scaleProportionally` unless changed. Valid values for this string are:
///        * `shrinkToFit`         - shrink the image, preserving the aspect ratio, to fit the drawing frame only if the image is larger than the drawing frame.
///        * `scaleToFi`          - shrink or expand the image to fully fill the drawing frame.  This does not preserve the aspect ratio.
///        * `none`                - perform no scaling or resizing of the image.
///        * `scaleProportionally` - shrink or expand the image to fully fill the drawing frame, preserving the aspect ration.
///      * `radius`             - Used by the `arc` and `circle` canvas element types to specify the radius of the circle. Defaults to `canvas.w / 2`. See Notes section below concerning the `arc` and `circle` element types.
///      * `reversePath`        - *unimplemented at present*
///      * `roundedRectRadii`   - A table specifying the radii of the corners of a canvas element of type `rectangle`. Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `{ xRadius = 0.0, yRadius = 0.0}` unless changed.
///      * `start`              - Used by the `line` canvas element type to specify the starting point of the line segment. Defaults to `{ x = 0, y = 0 }` and will be copied into the element definition if not provided initially.
///      * `startAngle`         - Used by the `arc` and `ellipticalArc` canvas element types to specify the starting angle of the arc inscribed on the circle or oval. Defaults to `0` and will be copied into the element definition if not provided initially.
///      * `stroke`             - A boolean flag, specifying whether or not to stroke the canvas element. The stroke of a canvas element is usually it's outline.  Does not apply to objects of type `image` or `text`.  Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `true` unless changed.
///      * `strokeCapStyle`     - *unimplemented at present*
///      * `strokeColor`        - A color table as supported by the `hs.drawing.color` module, specifying the stroke color for a closed canvas element (most of them) when `stroke` is true. Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `{ alpha = 1.0 }` (black) unless changed.
///      * `strokeDashPattern`  - *unimplemented at present*
///      * `strokeJoinStyle`    - *unimplemented at present*
///      * `strokeMiterLimit`   - *unimplemented at present*
///      * `strokeWidth`        - A number specifying the line width of a canvas element's stroke. Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `1.0` unless changed.
///      * `text`               - The text or `hs.styledtext` object to be displayed when the canvas element type is `text`.  If this field contains an `hs.styledtext` object, the `textColor`, `textFont`, and `textSize` fields only apply to portions of the `hs.styledtext` object which have absolutely no style applied to them. Defaults to the empty string "" and will be copied into the element definition if not provided initially.
///      * `textColor`          - A color table as supported by the `hs.drawing.color` module, specifying the text color for the contents of the `text` key. Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `{ white = 1.0, alpha = 1.0 }` (white) unless changed.
///      * `textFont`           - A string specifying the font name to use when rendering the contents of the `text` key. Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]).
///      * `textStyle`          - A table specifying the `lineBreak` and `alignment` for the contents of the `text` key when the text is provided as a string (this field is ignored if the contents of `text` is an `hs.styledtext` objects).  Defaults to the canvas defaults (see (hs._asm.canvas:allElementDefaults)[#allElementDefaults]) of `{ alignment = "natural", lineBreak = "wordWrap" }` unless changed.
///        * Valid values for the `alignment` subKey: "left", "right", "center", "justified", and "natural"
///        * Valid values for the `lineBreak` subKey: "wordWrap", "charWrap", "clip", "truncateHead", "truncateTail", and "truncateMiddle"
///      * `transformations`    - *unimplemented at present*
///      * `windingRule`        - *unimplemented at present*
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
///
/// Notes:
///  * All coordinates used in defining graphical elements are defined in relationship to the top left corner of the canvas object itself (i.e. `{ x = 0, y = 0 }` is the top left corner of the canvas, not the computer screen).
///  * The frame of the canvas provides the visible area in which canvas elements are rendered. Any portion of a canvas element which extends beyond the edges of the canvas will be clipped.
///
///  * The numeric values for any of the following sub-keys may be specified as a percentage in a string of the format `"n[.n]%"` where the numeric portion ranges from 0 - 100, or of the format `"n[.n]"` where the numeric representation in the string ranges from 0.0 to 1.0, and will be generated from the canvas's size as follows:
///    * `x` and 'w' = percentage specified of canvas's width
///    * `y` and 'h' = percentage specified of canvas's height
///  * For example:
///    * `{ x = "50%", y = "0%", h = "100%", w = "50%" }` specifies a rectangle covering the right half of the canvas.
///    * `{ x = "0.0", y = "0.5", h = "0.5", w = "1.0" }` specifics a rectangle covering the bottom half of the canvas.
///
///  * The `arc` type is only a convenience constructor for creating an `ellipticalArc` object. If you retrieve the elements in the canvas with `hs._asm.canvas:elements()`, it will be returned with the appropriate keys for the equivalent `ellipticalArc`. This is allowed because the way an `arc` is defined may make more sense during its construction, if the desired arc is to be inscribed on a circle.
///
///  * The `circle` type is only a convenience constructor for creating an `oval` object. If you retrieve the elements in the canvas with `hs._asm.canvas:elements()`, it will be returned with the appropriate keys for the equivalent `oval`. This is allowed because the way a `circle` is defined may make more sense during its construction, if the desired element is truly a circle.
static int canvas_elements(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    // do something

//     lua_pushvalue(L, 1) ;
//     return 1 ;
}

/// hs._asm.canvas:insertElement(elementTable, [pos]) -> canvasObject
/// Method
/// Insert the specified canvas element into the canvas object's element array.
///
/// Paramters:
///  * `elementTable` - a single canvas element as specified by the key-value pairs defined for canvas elements for (hs._asm.canvas:elements)[#elements].
///  * `pos`          - an optional integer specifying the index position to insert this element into, shifting up any existing element and those that follow it. Valid values for `pos` are from 1 to the number of canvas elements currently in the canvas + 1. Default value is the current total + 1 so that the new element will be added at the end of the array of existing elements.
///
/// Returns:
///  * The canvas object
static int canvas_insertElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;

    // do something

//     lua_pushvalue(L, 1) ;
//     return 1 ;
}

/// hs._asm.canvas:removeElement(pos) -> canvasObject
/// Method
/// Remove the canvas element at the specified index from the canvas object's element array.
///
/// Paramters:
///  * `pos`          - an integer specifying the index position of the element to remove, shifting all following elements down. Valid values for `pos` are from 1 to the number of canvas elements currently in the canvas. Default value is the number of canvas elements currently in the canvas so that last canvas element of the canvas's element array is removed.
///
/// Returns:
///  * The canvas object
static int canvas_removeElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;

    // do something

//     lua_pushvalue(L, 1) ;
//     return 1 ;
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
      lua_setfield(L, -2, "clear") ;           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_setfield(L, -2, "copy") ;            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_setfield(L, -2, "sourceOver") ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_setfield(L, -2, "sourceIn") ;        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_setfield(L, -2, "sourceOut") ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_setfield(L, -2, "sourceAtop") ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_setfield(L, -2, "destinationOver") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_setfield(L, -2, "destinationIn") ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_setfield(L, -2, "destinationOut") ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_setfield(L, -2, "destinationAtop") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_setfield(L, -2, "XOR") ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_setfield(L, -2, "plusDarker") ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//       lua_setfield(L, -2, "highlight") ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; // mapped to NSCompositeSourceOver
      lua_setfield(L, -2, "plusLighter") ;     lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
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

id toASMCanvasWindowFromLua(lua_State *L, int idx) {
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
            LuaSkin       *skin     = [LuaSkin shared] ;
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
    {"alpha",              canvas_alpha},
    {"behavior",           canvas_behavior},
    {"clickActivating",    canvas_clickActivating},
    {"clickCallback",      canvas_clickCallback},
    {"allElementDefaults", canvas_allElementDefaults},
    {"delete",             canvas_delete},
    {"elementDefault",     canvas_elementDefault},
    {"elements",           canvas_elements},
    {"hide",               canvas_hide},
    {"insertElement",      canvas_insertElement},
    {"isOccluded",         canvas_isOccluded},
    {"isShowing",          canvas_isShowing},
    {"level",              canvas_level},
    {"orderAbove",         canvas_orderAbove},
    {"orderBelow",         canvas_orderBelow},
    {"removeElement",      canvas_removeElement},
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
    {"new", canvas_new},

    {NULL,  NULL}
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

    [skin registerPushNSHelper:pushASMCanvasWindow         forClass:"ASMCanvasWindow"];
    [skin registerLuaObjectHelper:toASMCanvasWindowFromLua forClass:"ASMCanvasWindow"
                                                withUserdataMapping:USERDATA_TAG];

    pushCompositeTypes(L) ; lua_setfield(L, -2, "compositeTypes") ;

    return 1;
}
