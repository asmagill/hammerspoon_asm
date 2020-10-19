@import Cocoa ;
@import LuaSkin ;


// make sure this does not collide with the Cursor from Carbon/Cocoa
#define Cursor X11Cursor

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreserved-id-macro"
#pragma clang diagnostic ignored "-Wauto-import"
#import <X11/Xlib.h>
#import <X11/Xatom.h>
#import <X11/Xutil.h>
#pragma clang diagnostic pop

#undef Cursor

static const char * const USERDATA_TAG = "hs.window.x11" ;
static int refTable  = LUA_NOREF;
static int loggerRef = LUA_NOREF ;

// not null if the X11 functions have been loaded
static void *X11Lib_ = NULL;

// X11 function pointers
static Display *(*XOpenDisplayRef)(char *display_name);
static int      (*XCloseDisplayRef)(Display *display);
static int      (*XFreeRef)(void *data);
static int      (*XSetErrorHandlerRef)(int (*handler)(Display *, XErrorEvent *));
static int      (*XGetErrorTextRef)(Display *display, int code, char *buffer_return, int length);
static int      (*XSyncRef)(Display *display, Bool discard);
static Status   (*XGetWindowAttributesRef)(Display *display, Window w, XWindowAttributes *window_attributes_return);
static int      (*XGetWindowPropertyRef)(Display *display, Window w, Atom property, long long_offset, long long_length, Bool delete, Atom req_type, Atom *actual_type_return, int *actual_format_return, unsigned long *nitems_return, unsigned long *bytes_after_return, unsigned char **prop_return);
static Atom     (*XInternAtomRef)(Display *display, char *atom_name, Bool only_if_exists);
static Bool     (*XTranslateCoordinatesRef)(Display *display, Window src_w, Window dest_w, int src_x, int src_y, int *dest_x_return, int *dest_y_return, Window *child_return);
static Atom    *(*XListPropertiesRef)(Display *display, Window w, int *num_prop_return);
static char    *(*XGetAtomNameRef)(Display *display, Atom atom) ;
static int      (*XMapWindowRef)(Display *display, Window w);
static Status   (*XIconifyWindowRef)(Display *display, Window w, int screen_number);
static int      (*XDefaultScreenRef)(Display *display);
static int      (*XMoveWindowRef)(Display *display, Window w, int x, int y);
static int      (*XResizeWindowRef)(Display *display, Window w, unsigned int width, unsigned int height);
static int      (*XMoveResizeWindowRef)(Display *display, Window w, int x, int y, unsigned width, unsigned height);

// static int      (*XUnmapWindowRef)(Display *display, Window w);
// static Status   (*XQueryTreeRef)(Display *display, Window w, Window *root_return, Window *parent_return, Window **children_return, unsigned int *nchildren_return);

// X11 symbols table
#define X11_SYMBOL(s) {&s##Ref,#s}
static void *X11Symbols_[][2] = {
    X11_SYMBOL(XCloseDisplay),
    X11_SYMBOL(XFree),
    X11_SYMBOL(XGetErrorText),
    X11_SYMBOL(XGetWindowAttributes),
    X11_SYMBOL(XGetWindowProperty),
    X11_SYMBOL(XInternAtom),
    X11_SYMBOL(XOpenDisplay),
    X11_SYMBOL(XSetErrorHandler),
    X11_SYMBOL(XSync),
    X11_SYMBOL(XTranslateCoordinates),
    X11_SYMBOL(XListProperties),
    X11_SYMBOL(XGetAtomName),
    X11_SYMBOL(XMapWindow),
    X11_SYMBOL(XIconifyWindow),
    X11_SYMBOL(XDefaultScreen),
    X11_SYMBOL(XMoveWindow),
    X11_SYMBOL(XResizeWindow),
    X11_SYMBOL(XMoveResizeWindow),

//     X11_SYMBOL(XUnmapWindow),
//     X11_SYMBOL(XQueryTree),
};
#undef X11_SYMBOL

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static int moduleLogger(const char *lvl, NSString *message) {
    if (loggerRef == LUA_NOREF) {
        NSString *taggedMessage = [NSString stringWithFormat:@"%s - %@", USERDATA_TAG, message] ;
        if (strlen(lvl) == 1) {
            if        (strncmp(lvl, "d", 1) == 0) {
                [LuaSkin logDebug:taggedMessage] ;
                return 0 ;
            } else if (strncmp(lvl, "e", 1) == 0) {
                [LuaSkin logError:taggedMessage] ;
                return 0 ;
            } else if (strncmp(lvl, "i", 1) == 0) {
                [LuaSkin logInfo:taggedMessage] ;
                return 0 ;
            } else if (strncmp(lvl, "v", 1) == 0) {
                [LuaSkin logVerbose:taggedMessage] ;
                return 0 ;
            } else if (strncmp(lvl, "w", 1) == 0) {
                [LuaSkin logWarn:taggedMessage] ;
                return 0 ;
            }
        }
        [LuaSkin logError:[NSString stringWithFormat:@"%s.moduleLogger invalid specifier '%s'. Message: %@", USERDATA_TAG, lvl, message]] ;
    } else {
        LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L    = skin.L ;
        [skin pushLuaRef:refTable ref:loggerRef] ;
        lua_getfield(L, -1, lvl) ;
        [skin pushNSObject:message] ;
        [skin protectedCallAndError:[NSString stringWithFormat:@"%s.moduleLogger callback", USERDATA_TAG] nargs:1 nresults:0] ;
        lua_pop(L, 1) ; // remove loggerRef
    }
    return 0 ;
}

static int X11ErrorHandler(Display *dpy, XErrorEvent *err) {
    char msg[1024] ;
    XGetErrorTextRef(dpy, err->error_code, msg, sizeof(msg)) ;
    const char *lvl = "w" ;
    // as I discover which errors we can truly ignore, I'll reduce their level
    if (err->request_code == 17) { // BadAtom, usually from getProperty and we return nothing for value key
        lvl = "v" ;
    }
    moduleLogger(lvl, [NSString stringWithFormat:@"X11Error: %s (code: %d)", msg, err->request_code]) ;
    return 0 ;
}

NSDictionary *decodeEventMask(long mask) {
    NSMutableArray *events  = [NSMutableArray array] ;

    if (mask == NoEventMask) {
        [events addObject:@"NoEvents"] ;
    } else {
        if ((mask & KeyPressMask) == KeyPressMask)                         [events addObject:@"keyPress"] ;
        if ((mask & KeyReleaseMask) == KeyReleaseMask)                     [events addObject:@"keyRelease"] ;
        if ((mask & ButtonPressMask) == ButtonPressMask)                   [events addObject:@"buttonPress"] ;
        if ((mask & ButtonReleaseMask) == ButtonReleaseMask)               [events addObject:@"buttonRelease"] ;
        if ((mask & EnterWindowMask) == EnterWindowMask)                   [events addObject:@"enterWindow"] ;
        if ((mask & LeaveWindowMask) == LeaveWindowMask)                   [events addObject:@"leaveWindow"] ;
        if ((mask & PointerMotionMask) == PointerMotionMask)               [events addObject:@"pointerMotion"] ;
        if ((mask & PointerMotionHintMask) == PointerMotionHintMask)       [events addObject:@"pointerMotionHint"] ;
        if ((mask & Button1MotionMask) == Button1MotionMask)               [events addObject:@"button1Motion"] ;
        if ((mask & Button2MotionMask) == Button2MotionMask)               [events addObject:@"button2Motion"] ;
        if ((mask & Button3MotionMask) == Button3MotionMask)               [events addObject:@"button3Motion"] ;
        if ((mask & Button4MotionMask) == Button4MotionMask)               [events addObject:@"button4Motion"] ;
        if ((mask & Button5MotionMask) == Button5MotionMask)               [events addObject:@"button5Motion"] ;
        if ((mask & ButtonMotionMask) == ButtonMotionMask)                 [events addObject:@"buttonMotion"] ;
        if ((mask & KeymapStateMask) == KeymapStateMask)                   [events addObject:@"keymapState"] ;
        if ((mask & ExposureMask) == ExposureMask)                         [events addObject:@"exposure"] ;
        if ((mask & VisibilityChangeMask) == VisibilityChangeMask)         [events addObject:@"visibilityChange"] ;
        if ((mask & StructureNotifyMask) == StructureNotifyMask)           [events addObject:@"structureNotify"] ;
        if ((mask & ResizeRedirectMask) == ResizeRedirectMask)             [events addObject:@"resizeRedirect"] ;
        if ((mask & SubstructureNotifyMask) == SubstructureNotifyMask)     [events addObject:@"substructureNotify"] ;
        if ((mask & SubstructureRedirectMask) == SubstructureRedirectMask) [events addObject:@"substructureRedirect"] ;
        if ((mask & FocusChangeMask) == FocusChangeMask)                   [events addObject:@"focusChange"] ;
        if ((mask & PropertyChangeMask) == PropertyChangeMask)             [events addObject:@"propertyChange"] ;
        if ((mask & ColormapChangeMask) == ColormapChangeMask)             [events addObject:@"colormapChange"] ;
        if ((mask & OwnerGrabButtonMask) == OwnerGrabButtonMask)           [events addObject:@"ownerGrabButton"] ;
    }
    long remainingMasks = mask & ~(NoEventMask              | KeyPressMask             |
                                   KeyReleaseMask           | ButtonPressMask          |
                                   ButtonReleaseMask        | EnterWindowMask          |
                                   LeaveWindowMask          | PointerMotionMask        |
                                   PointerMotionHintMask    | Button1MotionMask        |
                                   Button2MotionMask        | Button3MotionMask        |
                                   Button4MotionMask        | Button5MotionMask        |
                                   ButtonMotionMask         | KeymapStateMask          |
                                   ExposureMask             | VisibilityChangeMask     |
                                   StructureNotifyMask      | ResizeRedirectMask       |
                                   SubstructureNotifyMask   | SubstructureRedirectMask |
                                   FocusChangeMask          | PropertyChangeMask       |
                                   ColormapChangeMask       | OwnerGrabButtonMask) ;
    return @{
        @"raw"          : @(mask),
        @"expanded"     : [events copy],
        @"unrecognized" : @(remainingMasks)
    } ;
}

@interface HSX11Window : NSObject
@property (nonatomic, readonly) long pid;
// @property (nonatomic, readonly) AXUIElementRef elementRef;
@property (nonatomic, readonly) Window winID;
// @property (nonatomic, readonly) HSuielement *uiElement;
@property (nonatomic) int selfRefCount ;

@property (nonatomic, readonly, getter=title) NSString *title;
// @property (nonatomic, readonly, getter=role) NSString *role;
// @property (nonatomic, readonly, getter=subRole) NSString *subRole;
// @property (nonatomic, readonly, getter=isStandard) BOOL isStandard;
@property (nonatomic, getter=getTopLeft, setter=setTopLeft:) NSPoint topLeft;
@property (nonatomic, getter=getSize, setter=setSize:) NSSize size;
// @property (nonatomic, getter=isFullscreen, setter=setFullscreen:) BOOL fullscreen;
@property (nonatomic, getter=isMinimized, setter=setMinimized:) BOOL minimized;
// @property (nonatomic, getter=getApplication) id application;
// @property (nonatomic, readonly, getter=getZoomButtonRect) NSRect zoomButtonRect;
// @property (nonatomic, readonly, getter=getTabCount) int tabCount;

// Properties not in HSUICore
@property (nonatomic, readonly) Display *dpy;
@property (nonatomic, getter=getFrame, setter=setFrame:) NSRect frame;

// Class methods
// +(NSArray<NSNumber *>*)orderedWindowIDs;
// +(NSImage *)snapshotForID:(int)windowID keepTransparency:(BOOL)keepTransparency;
+(instancetype)focusedWindow;

// Class methods not in HSUICore
+(NSArray<NSNumber *>*)_windowIDs;
+(instancetype)rootWindow;
+(NSDictionary *)_getProperty:(Atom)atom forWindow:(Window)winID ofDisplay:(Display *)dpy;

// Initialiser
-(instancetype)initWithWindowRef:(Window)winID withDisplay:(Display *)dpy;

// Destructor
-(void)dealloc;

// Instance methods
-(NSString *)title;
// -(NSString *)subRole;
// -(NSString *)role;
// -(BOOL)isStandard;
-(NSPoint)getTopLeft;
-(void)setTopLeft:(NSPoint)topLeft;
-(NSSize)getSize;
-(void)setSize:(NSSize)size;
// -(BOOL)pushButton:(CFStringRef)buttonId;
// -(void)toggleZoom;
// -(NSRect)getZoomButtonRect;
// -(BOOL)close;
// -(BOOL)focusTab:(int)index;
// -(int)getTabCount;
// -(BOOL)isFullscreen;
// -(void)setFullscreen:(BOOL)fullscreen;
-(BOOL)isMinimized;
-(void)setMinimized:(BOOL)minimize;
// -(id)getApplication;
// -(void)becomeMain;
// -(void)raise;
// -(NSImage *)snapshot:(BOOL)keepTransparency;

// Instance methods not in HSUICore
-(NSRect)getFrame;
-(void)setFrame:(NSRect)frame;
-(NSDictionary *)_getProperty:(Atom)atom;
-(NSDictionary *)_getPropertyList;
-(NSDictionary *)_getWindowAttributes;
@end

@implementation HSX11Window
- (instancetype)initWithWindowRef:(Window)winID withDisplay:(Display *)dpy {
    self = [super init] ;
    if (self) {
        _winID        = winID ;
        _dpy          = dpy ;
        _selfRefCount = 0 ;

        NSDictionary *property = [self _getProperty:XInternAtomRef(_dpy, "_NET_WM_PID", False)] ;
        NSNumber *value = property[@"value"] ;
        _pid = (value) ? value.longValue : -1l ;
    }
    return self ;
}

- (void)dealloc {
    if (_dpy != NULL) XCloseDisplayRef(_dpy) ;
    _dpy = NULL ;
}

+(instancetype)rootWindow {
    HSX11Window *window = nil;

    if (X11Lib_ != NULL) {
        Display *dpy = XOpenDisplayRef(NULL) ;
        if (dpy != NULL) {
            Window root = DefaultRootWindow(dpy) ;
            window = [[HSX11Window alloc] initWithWindowRef:root withDisplay:dpy] ;
        } else {
            moduleLogger("e", [NSString stringWithFormat:@"%s.rootWindow - unable to get X display (XOpenDisplay)", USERDATA_TAG]) ;
        }
        if (!window) XCloseDisplayRef(dpy) ;
    }
    return window;
}

+(instancetype)focusedWindow {
    HSX11Window *window = nil;

    if (X11Lib_ != NULL) {
        Display *dpy = XOpenDisplayRef(NULL) ;
        if (dpy != NULL) {
            Window root = DefaultRootWindow(dpy) ;

            NSDictionary *property = [HSX11Window _getProperty:XInternAtomRef(dpy, "_NET_ACTIVE_WINDOW", False)
                                                     forWindow:root
                                                     ofDisplay:dpy] ;

            if (property[@"value"]) {
                NSNumber *winID = property[@"value"] ;
                window = [[HSX11Window alloc] initWithWindowRef:winID.unsignedLongValue withDisplay:dpy] ;
            }
            if (!window) XCloseDisplayRef(dpy) ;
        } else {
            moduleLogger("e", [NSString stringWithFormat:@"%s.focusedWindow - unable to get X display (XOpenDisplay)", USERDATA_TAG]) ;
        }
    }
    return window;
}

+(NSArray<NSNumber *>*)_windowIDs {
    NSArray *windows = [NSArray array] ;

    if (X11Lib_ != NULL) {
        Display *dpy = XOpenDisplayRef(NULL) ;
        if (dpy != NULL) {
            Window root = DefaultRootWindow(dpy) ;

            NSDictionary *property = [HSX11Window _getProperty:XInternAtomRef(dpy, "_NET_CLIENT_LIST", False)
                                                     forWindow:root
                                                     ofDisplay:dpy] ;

            if (property[@"value"]) {
                windows = property[@"value"] ;
                // getProperty returns a singleton rather than an array when there is only one item
                if (![windows isKindOfClass:[NSArray class]]) windows = [NSArray arrayWithObject:windows] ;
            }
            XCloseDisplayRef(dpy) ;
        } else {
            moduleLogger("e", [NSString stringWithFormat:@"%s._windowIDs - unable to get X display (XOpenDisplay)", USERDATA_TAG]) ;
        }
    }

    return windows ;
}

-(NSString *)title {
    NSDictionary *property = [self _getProperty:XInternAtomRef(_dpy, "WM_NAME", False)] ;
    return property[@"value"] ;
}

-(NSPoint)getTopLeft {
    Window            root    = DefaultRootWindow(_dpy) ;
    NSPoint           topLeft = NSZeroPoint ;
    XWindowAttributes wa ;

    if(XGetWindowAttributesRef(_dpy, _winID, &wa)) {
        int    x, y ;
        Window ignored ;
        if(XTranslateCoordinatesRef(_dpy, _winID, root, -wa.border_width, -wa.border_width, &x, &y, &ignored)) {
            topLeft = NSMakePoint(x - wa.x, y - wa.y) ;
        } else {
            moduleLogger("e", [NSString stringWithFormat:@"%s.getTopLeft - unable to translate coordinates (XTranslateCoordinates)", USERDATA_TAG]) ;
        }
    } else {
        moduleLogger("e", [NSString stringWithFormat:@"%s.getTopLeft - Unable to get window attributes (XGetWindowAttributes)", USERDATA_TAG]) ;
    }
    return topLeft ;
}

-(void)setTopLeft:(NSPoint)topLeft {
    XMoveWindowRef(_dpy, _winID, (int)topLeft.x, (int)topLeft.y) ;
    if (!XSyncRef(_dpy, False)) {
        moduleLogger("e", [NSString stringWithFormat:@"%s.setTopLeft - Unable to sync X11 (XSync)", USERDATA_TAG]) ;
    }
}

-(NSSize)getSize {
    NSSize            size = NSZeroSize ;
    XWindowAttributes wa ;
    if(XGetWindowAttributesRef(_dpy, _winID, &wa)) {
        // the height returned is without the window manager decoration - the OSX top bar with buttons, window label and stuff
        // so we need to add it to the height as well because the WindowSize expects the full window
        // the same might be potentially apply to the width
        size = NSMakeSize(wa.width + wa.x, wa.height + wa.y) ;
    } else {
        moduleLogger("e", [NSString stringWithFormat:@"%s.getSize - Unable to get window attributes (XGetWindowAttributes)", USERDATA_TAG]) ;
    }
    return size ;
}

-(void)setSize:(NSSize)size {
    XWindowAttributes wa ;
    if (XGetWindowAttributesRef(_dpy, _winID, &wa)) {
        // the WindowSizer will pass the size of the entire window including its decoration, so we need to subtract that
        XResizeWindowRef(_dpy, _winID, (unsigned int)(size.width - wa.x), (unsigned int)(size.height - wa.y)) ;
        if (!XSyncRef(_dpy, False)) {
            moduleLogger("e", [NSString stringWithFormat:@"%s.setSize - Unable to sync X11 (XSync)", USERDATA_TAG]) ;
        }
    } else {
        moduleLogger("e", [NSString stringWithFormat:@"%s.setSize - Unable to get window attributes (XGetWindowAttributes)", USERDATA_TAG]) ;
    }
}

-(BOOL)isMinimized {
    XWindowAttributes wa ;
    if(XGetWindowAttributesRef(_dpy, _winID, &wa)) {
        return !(wa.map_state == IsViewable) ;
    } else {
        moduleLogger("e", [NSString stringWithFormat:@"%s.isMinimized - Unable to get window attributes (XGetWindowAttributes)", USERDATA_TAG]) ;
        return NO ;
    }
}

-(void)setMinimized:(BOOL)minimize {
    if (minimize) {
//         XUnmapWindowRef(_dpy, _winID) ; // doesn't put in Dock, just vanishes
        XIconifyWindowRef(_dpy, _winID, XDefaultScreenRef(_dpy)) ;
    } else {
        XMapWindowRef(_dpy, _winID) ;
    }
}

-(NSRect)getFrame {
    Window            root  = DefaultRootWindow(_dpy) ;
    NSRect            frame = NSZeroRect ;
    XWindowAttributes wa ;
    if(XGetWindowAttributesRef(_dpy, _winID, &wa)) {
        int    x, y ;
        Window ignored ;
        if(XTranslateCoordinatesRef(_dpy, _winID, root, -wa.border_width, -wa.border_width, &x, &y, &ignored)) {
            // the height returned is without the window manager decoration - the OSX top bar with buttons, window label and stuff
            // so we need to add it to the height as well because the WindowSize expects the full window
            // the same might be potentially apply to the width
           frame = NSMakeRect(x - wa.x, y - wa.y, wa.width + wa.x, wa.height + wa.y);
        } else {
            moduleLogger("e", [NSString stringWithFormat:@"%s.getFrame - unable to translate coordinates (XTranslateCoordinates)", USERDATA_TAG]) ;
        }
    } else {
        moduleLogger("e", [NSString stringWithFormat:@"%s.getFrame - Unable to get window attributes (XGetWindowAttributes)", USERDATA_TAG]) ;
    }
    return frame ;
}

-(void)setFrame:(NSRect)frame {
    XWindowAttributes wa ;
    if (XGetWindowAttributesRef(_dpy, _winID, &wa)) {
        // the WindowSizer will pass the size of the entire window including its decoration, so we need to subtract that
        if (XMoveResizeWindowRef(_dpy, _winID, (int)frame.origin.x, (int)frame.origin.y, (unsigned int)(frame.size.width - wa.x), (unsigned int)(frame.size.height - wa.y))) {
            if (!XSyncRef(_dpy, False)) {
                moduleLogger("e", [NSString stringWithFormat:@"%s.setFrame - Unable to sync X11 (XSync)", USERDATA_TAG]) ;
            }
        } else {
            moduleLogger("e", [NSString stringWithFormat:@"%s.setFrame - Unable to change window geometry (XMoveResizeWindow)", USERDATA_TAG]) ;
        }
    } else {
        moduleLogger("e", [NSString stringWithFormat:@"%s.setFrame - Unable to get window attributes (XGetWindowAttributes)", USERDATA_TAG]) ;
    }
}

+(NSDictionary *)_getProperty:(Atom)atom forWindow:(Window)winID ofDisplay:(Display *)dpy {
    NSDictionary *results = nil ;
    char         *atom_name = XGetAtomNameRef(dpy, atom) ;

    Atom          actual_type_return   = 0 ;
    int           actual_format_return = 0 ;
    unsigned long nitems_return        = 0l ;
    unsigned long bytes_after_return   = 0l ;
    unsigned char *prop_return         = NULL ;
    if (XGetWindowPropertyRef(dpy, winID, atom, 0, 0x7fffffff, False, AnyPropertyType, &actual_type_return, &actual_format_return, &nitems_return, &bytes_after_return, &prop_return) == Success) {

        char     *type_name = XGetAtomNameRef(dpy, actual_type_return) ;
        NSString *type      = (type_name == NULL) ? @"BadAtom" : [NSString stringWithUTF8String:type_name] ;
        XFreeRef(type_name) ;

        size_t size = nitems_return * (actual_format_return == 16 ? sizeof(short) : (actual_format_return == 32 ? sizeof(long) : 1)) ;
        NSMutableArray *raw = [NSMutableArray arrayWithCapacity:size] ;
        for (unsigned long i = 0 ; i < size ; i++) [raw addObject:[NSNumber numberWithUnsignedChar:prop_return[i]]] ;

        NSObject *value = NULL ;
        if (actual_format_return == 8) {
            value = [NSString stringWithUTF8String:(const char *)prop_return] ;
        } else if (actual_format_return == 16) {
            if (nitems_return == 0) {
                value = [NSNull null] ;
            } else {
                short *numbers = malloc(size) ;
                memcpy(numbers, prop_return, size) ;
                if (nitems_return == 1) {
                    value = [NSNumber numberWithShort:numbers[0]] ;
                } else {
                    NSMutableArray *tmp = [NSMutableArray arrayWithCapacity:nitems_return] ;
                    for (unsigned long i = 0 ; i < nitems_return ; i++) [tmp addObject:[NSNumber numberWithShort:numbers[i]]] ;
                    value = [tmp copy] ; // convert mutable to immutable
                }
                free(numbers) ;
            }
        } else if (actual_format_return == 32) {
            if (nitems_return == 0) {
                value = [NSNull null] ;
            } else {
                long *numbers = malloc(size) ;
                memcpy(numbers, prop_return, size) ;
                if (nitems_return == 1) {
                    value = [NSNumber numberWithLong:numbers[0]] ;
                } else {
                    NSMutableArray *tmp = [NSMutableArray arrayWithCapacity:nitems_return] ;
                    for (unsigned long i = 0 ; i < nitems_return ; i++) [tmp addObject:[NSNumber numberWithLong:numbers[i]]] ;
                    value = [tmp copy] ; // convert mutable to immutable
                }
                free(numbers) ;
            }
        } else if (actual_type_return == None && actual_format_return == 0) {
            value = [NSNull null] ;
        } else {
            moduleLogger("i", [NSString stringWithFormat:@"%s of type %@ has a return format of %d", atom_name, type, actual_format_return]) ;
            value = @"unknown" ;
        }

        if (value) {
            if (value == [NSNull null]) {
                results = @{
                    @"type"         : type,
                    @"typeNumber"   : @(actual_type_return),
                    @"formatNumber" : @(actual_format_return),
                    @"raw"          : [raw copy], // convert mutable to immutable
                    @"size"         : @(nitems_return),
                    @"extra"        : @(bytes_after_return)
                } ;
            } else {
                results = @{
                    @"value"        : value,
                    @"type"         : type,
                    @"typeNumber"   : @(actual_type_return),
                    @"formatNumber" : @(actual_format_return),
                    @"raw"          : [raw copy], // convert mutable to immutable
                    @"size"         : @(nitems_return),
                    @"extra"        : @(bytes_after_return)
                } ;
            }
        }

        if (prop_return != NULL) XFreeRef(prop_return) ;
    } else {
        moduleLogger("e", [NSString stringWithFormat:@"%s.getProperty - Unable to get %s (%lu) (XGetWindowProperty)", USERDATA_TAG, atom_name, atom]) ;
    }

    XFreeRef(atom_name) ;
    return results ;
}

-(NSDictionary *)_getProperty:(Atom)atom {
    return [HSX11Window _getProperty:atom forWindow:_winID ofDisplay:_dpy] ;
}

-(NSDictionary *)_getPropertyList {
    NSMutableDictionary *results = [NSMutableDictionary dictionary] ;

    int num_prop_return ;
    Atom *windowProperties = XListPropertiesRef(_dpy, _winID, &num_prop_return) ;
    for (int idx = 0 ; idx < num_prop_return ; idx++) {
        char     *atom_name = XGetAtomNameRef(_dpy, windowProperties[idx]) ;
        NSString *key       = [NSString stringWithUTF8String:atom_name] ;
        XFreeRef(atom_name) ;

        NSDictionary *value = [self _getProperty:windowProperties[idx]] ;
        if (value) results[key] = value ;
    }
    XFreeRef(windowProperties) ;

    return [results copy] ; // convert mutable to immutable
}

-(NSDictionary *)_getWindowAttributes {
    NSMutableDictionary *results = [NSMutableDictionary dictionary] ;
    XWindowAttributes   wa ;
    if(XGetWindowAttributesRef(_dpy, _winID, &wa)) {
        results[@"x"]            = @(wa.x) ;
        results[@"y"]            = @(wa.y) ;
        results[@"width"]        = @(wa.width) ;
        results[@"height"]       = @(wa.height) ;
        results[@"border_width"] = @(wa.border_width) ;
        results[@"depth"]        = @(wa.depth) ;
        results[@"visual"]       = [NSString stringWithFormat:@"%p", (void *)wa.visual] ;
        results[@"rootID"]       = @(wa.root) ;
        switch(wa.class) {
            case InputOutput: results[@"class"] = @"inputOutput" ; break ;
            case InputOnly:   results[@"class"] = @"inputOnly" ; break ;
            default: results[@"class"] = [NSString stringWithFormat:@"unknown class:%d", wa.class] ;
        }
        switch(wa.bit_gravity) {
            case ForgetGravity:    results[@"bit_gravity"] = @"forgetGravity" ; break ;
            case NorthWestGravity: results[@"bit_gravity"] = @"northWestGravity" ; break ;
            case NorthGravity:     results[@"bit_gravity"] = @"northGravity" ; break ;
            case NorthEastGravity: results[@"bit_gravity"] = @"northEastGravity" ; break ;
            case WestGravity:      results[@"bit_gravity"] = @"westGravity" ; break ;
            case CenterGravity:    results[@"bit_gravity"] = @"centerGravity" ; break ;
            case EastGravity:      results[@"bit_gravity"] = @"eastGravity" ; break ;
            case SouthWestGravity: results[@"bit_gravity"] = @"southWestGravity" ; break ;
            case SouthGravity:     results[@"bit_gravity"] = @"southGravity" ; break ;
            case SouthEastGravity: results[@"bit_gravity"] = @"southEastGravity" ; break ;
            case StaticGravity:    results[@"bit_gravity"] = @"staticGravity" ; break ;
            default: results[@"bit_gravity"] = [NSString stringWithFormat:@"unknown bit_gravity:%d", wa.bit_gravity] ;
        }
        switch(wa.win_gravity) {
            case UnmapGravity:     results[@"win_gravity"] = @"unmapGravity" ; break ;
            case NorthWestGravity: results[@"win_gravity"] = @"northWestGravity" ; break ;
            case NorthGravity:     results[@"win_gravity"] = @"northGravity" ; break ;
            case NorthEastGravity: results[@"win_gravity"] = @"northEastGravity" ; break ;
            case WestGravity:      results[@"win_gravity"] = @"westGravity" ; break ;
            case CenterGravity:    results[@"win_gravity"] = @"centerGravity" ; break ;
            case EastGravity:      results[@"win_gravity"] = @"eastGravity" ; break ;
            case SouthWestGravity: results[@"win_gravity"] = @"southWestGravity" ; break ;
            case SouthGravity:     results[@"win_gravity"] = @"southGravity" ; break ;
            case SouthEastGravity: results[@"win_gravity"] = @"southEastGravity" ; break ;
            case StaticGravity:    results[@"win_gravity"] = @"staticGravity" ; break ;
            default: results[@"win_gravity"] = [NSString stringWithFormat:@"unknown win_gravity:%d", wa.win_gravity] ;
        }
        results[@"backing_store"]  = @(wa.backing_store) ;
        results[@"backing_planes"] = @(wa.backing_planes) ;
        results[@"backing_pixel"]  = @(wa.backing_pixel) ;
        results[@"save_under"]     = wa.save_under == True ? @(YES) : @(NO) ;
        results[@"colormap"]       = @(wa.colormap) ;
        results[@"map_installed"]  = wa.map_installed == True ? @(YES) : @(NO) ;
        switch(wa.map_state) {
            case IsUnmapped:   results[@"map_state"] = @"isUnmapped" ; break ;
            case IsUnviewable: results[@"map_state"] = @"isUnviewable" ; break ;
            case IsViewable:   results[@"map_state"] = @"isViewable" ; break ;
            default: results[@"map_state"] = [NSString stringWithFormat:@"unknown map_state:%d", wa.map_state] ;
        }
        results[@"all_event_masks"]       = decodeEventMask(wa.all_event_masks) ;
        results[@"your_event_mask"]       = decodeEventMask(wa.your_event_mask) ;
        results[@"do_not_propagate_mask"] = decodeEventMask(wa.do_not_propagate_mask) ;
        results[@"override_redirect"]     = wa.override_redirect == True ? @(YES) : @(NO) ;
        results[@"screen"]                = [NSString stringWithFormat:@"%p", (void *)wa.screen] ;
    } else {
        moduleLogger("e", [NSString stringWithFormat:@"%s._getWindowAttributes - Unable to get window attributes (XGetWindowAttributes)", USERDATA_TAG]) ;
    }

    return [results copy] ; // convert mutable to immutable
}

@end

#pragma mark - Module Functions

static int window_x11_loadLibrary(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    // if no args, just return whether or not the library has been loaded yet
    if (lua_gettop(L) == 0) {
        if (X11Lib_ != NULL) {
            lua_pushboolean(L, YES) ;
            return 1 ;
        } else {
            lua_pushboolean(L, NO) ;
            lua_pushstring(L, "no library currently loaded") ;
            return 2 ;
        }
    }

    [skin checkArgs:LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *libPath = [skin toNSObjectAtIndex:1] ;
    BOOL     testOnly = lua_gettop(L) > 1 ? (BOOL)(lua_toboolean(L, 2)) : NO ;

    // if not testing a new path, and we've already loaded a library, bail
    if (X11Lib_ != NULL && !testOnly) {
        lua_pushboolean(L, NO) ;
        lua_pushstring(L, "valid library already loaded") ;
        return 2 ;
    }

    // if library isn't accessible to user, bail
    if (access(libPath.UTF8String, X_OK) != 0) {
        lua_pushboolean(L, NO) ;
        lua_pushstring(L, strerror(errno)) ;
        return 2 ;
    }

    // if library can't be loaded, bail
    void *libBlob = dlopen(libPath.UTF8String, RTLD_LOCAL | RTLD_NOW) ;
    if (!libBlob) {
        lua_pushboolean(L, NO) ;
        lua_pushstring(L, dlerror()) ;
        return 2 ;
    }

    // now check symbols
    char *err = NULL;
    for (size_t i=0; i<sizeof(X11Symbols_)/sizeof(X11Symbols_[0]); i++) {
        void *func = dlsym(libBlob, X11Symbols_[i][1]) ;
        if ((err = dlerror()) != NULL) {
            dlclose(libBlob) ;
            lua_pushboolean(L, NO) ;
            lua_pushfstring(L, "unable to resolve symbol %s: %s",  X11Symbols_[i][1], err) ;
            return 2 ;
        } else if (!testOnly) {
            *(void **)(X11Symbols_[i][0]) = func ;
        }
    }

    // we made it this far, so it's a valid library; cleanup and return true
    if (testOnly) {
        dlclose(libBlob) ;
    } else {
        // actually unnecessary, but maybe someday we'll allow swapping them out?
        if (X11Lib_ != NULL) dlclose(X11Lib_) ;
        X11Lib_ = libBlob ;
        XSetErrorHandlerRef(&X11ErrorHandler) ;
    }
    lua_pushboolean(L, YES) ;
    return 1 ;
}

static int window_x11_setLoggerRef(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    [skin luaUnref:refTable ref:loggerRef] ;
    loggerRef = [skin luaRef:refTable atIndex:1] ;
    return 0 ;
}

static int window_x11_windowIDs(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:[HSX11Window _windowIDs]] ;
    return 1;
}

static int window_x11_windowForID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    Window winID = (Window)lua_tointeger(L, 1) ;
    BOOL bypass = lua_gettop(L) > 1 ? (BOOL)(lua_toboolean(L, 2)) : NO ;

    HSX11Window *window = nil ;
    NSArray *windowIDs = [HSX11Window _windowIDs] ;
    if (bypass || [windowIDs containsObject:@(winID)]) {
        Display *dpy = XOpenDisplayRef(NULL) ;
        if (dpy != NULL) {
            window = [[HSX11Window alloc] initWithWindowRef:winID withDisplay:dpy] ;
            if (!window) XCloseDisplayRef(dpy) ;
        } else {
            moduleLogger("e", [NSString stringWithFormat:@"%s._windowForID - unable to get X display (XOpenDisplay)", USERDATA_TAG]) ;
        }
    }

    [skin pushNSObject:window] ;
    return 1 ;
}

/// hs.window.x11.focusedWindow() -> x11Window
/// Constructor
/// Returns the X11 Window that has keyboard/mouse focus
///
/// Parameters:
///  * None
///
/// Returns:
///  * An `hs.window.x11` object representing the currently focused window
static int window_x11_focusedwindow(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];
    [skin pushNSObject:[HSX11Window focusedWindow]];
    return 1;
}

static int window_x11_rootWindow(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];
    [skin pushNSObject:[HSX11Window rootWindow]];
    return 1;
}

#pragma mark - Module Methods

/// hs.window.x11:frame() -> hs.geometry rect
/// Method
/// Gets the frame of the window in absolute coordinates
///
/// Parameters:
///  * None
///
/// Returns:
///  * An hs.geometry rect containing the co-ordinates of the top left corner of the window and its width and height
static int window_x11_frame(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *window = [skin toNSObjectAtIndex:1] ;
    [skin pushNSRect:window.frame];
    return 1;
}

/// hs.window.x11:topLeft() -> point
/// Method
/// Gets the absolute co-ordinates of the top left of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A point-table containing the absolute co-ordinates of the top left corner of the window
static int window_x11_topLeft(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *window = [skin toNSObjectAtIndex:1] ;
    [skin pushNSPoint:window.topLeft];
    return 1;
}

/// hs.window.x11:size() -> size
/// Method
/// Gets the size of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A size-table containing the width and height of the window
static int window_x11_size(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *window = [skin toNSObjectAtIndex:1] ;
    [skin pushNSSize:window.size];
    return 1;
}

/// hs.window.x11:setFrame(rect) -> hs.window.x11 object
/// Method
/// Sets the frame of the window in absolute coordinates
///
/// Parameters:
///  * rect - An hs.geometry rect, or constructor argument, describing the frame to be applied to the window
///
/// Returns:
///  * The `hs.window.x11` object
static int window_x11_setFrame(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    HSX11Window *window = [skin toNSObjectAtIndex:1] ;
    window.frame = [skin tableToRectAtIndex:2];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window.x11:setTopLeft(point) -> window
/// Method
/// Moves the window to a given point
///
/// Parameters:
///  * point - A point-table containing the absolute co-ordinates the window should be moved to
///
/// Returns:
///  * The `hs.window.x11` object
static int window_x11_setTopLeft(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    HSX11Window *window = [skin toNSObjectAtIndex:1] ;
    window.topLeft = [skin tableToPointAtIndex:2];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window.x11:setSize(size) -> window
/// Method
/// Resizes the window
///
/// Parameters:
///  * size - A size-table containing the width and height the window should be resized to
///
/// Returns:
///  * The `hs.window.x11` object
static int window_x11_setSize(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    HSX11Window *window = [skin toNSObjectAtIndex:1] ;
    window.size = [skin tableToSizeAtIndex:2];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window.x11:minimize() -> window
/// Method
/// Minimizes the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.window.x11` object
static int window_x11_minimize(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *window = [skin toNSObjectAtIndex:1] ;
    window.minimized = YES;
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window.x11:unminimize() -> window
/// Method
/// Un-minimizes the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.window.x11` object
static int window_x11_unminimize(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *window = [skin toNSObjectAtIndex:1] ;
    window.minimized = NO;
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window.x11:isMinimized() -> bool
/// Method
/// Gets the minimized state of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the window is minimized, otherwise false
static int window_x11_isminimized(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *window = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, window.minimized);
    return 1;
}

/// hs.window.x11:id() -> number
/// Method
/// Gets the unique identifier of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the unique identifier of the window
static int window_x11_id(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *window = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, (lua_Integer)window.winID) ;
    return 1 ;
}

static int window_x11_pid(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window  *window   = [skin toNSObjectAtIndex:1] ;
    if (window.pid < 0) {
        lua_pushnil(L) ;
    } else {
        lua_pushinteger(L, window.pid);
    }
    return 1;
}

/// hs.window.x11:title() -> string
/// Method
/// Gets the title of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the title of the window or nil if there was an error
static int window_x11_title(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window  *window = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:window.title];
    return 1;
}

static int window_x11_propertyList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *window = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[window _getPropertyList]];
    return 1;
}

static int window_x11_attributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *window = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[window _getWindowAttributes]];
    return 1;
}

static int window_x11_getProperty(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK];
    HSX11Window *window   = [skin toNSObjectAtIndex:1] ;
    NSString    *atomName = [skin toNSObjectAtIndex:2] ;
    // (char *)(uintptr_t) casts away the const
    Atom atom = XInternAtomRef(window.dpy, (char *)(uintptr_t)atomName.UTF8String, True) ;
    if (atom == None) {
        lua_pushnil(L) ;
    } else {
        [skin pushNSObject:[window _getProperty:atom]] ;
    }
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSX11Window(lua_State *L, id obj) {
    HSX11Window *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSX11Window *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toHSX11WindowFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSX11Window *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSX11Window, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSX11Window *obj = [skin luaObjectAtIndex:1 toClass:"HSX11Window"] ;
    NSString *title = obj.title ;
    if (!title) title = @"<unknown>" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSX11Window *obj1 = [skin luaObjectAtIndex:1 toClass:"HSX11Window"] ;
        HSX11Window *obj2 = [skin luaObjectAtIndex:2 toClass:"HSX11Window"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSX11Window *obj = get_objectFromUserdata(__bridge_transfer HSX11Window, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            obj = nil ;
        }

    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* L) {
    if (X11Lib_ != NULL) {
        dlclose(X11Lib_) ;
        X11Lib_ = NULL ;
    }
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    loggerRef = [skin luaUnref:refTable ref:loggerRef] ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"title",          window_x11_title},
//     {"subrole",        window_x11_subrole},
//     {"role",           window_x11_role},
//     {"isStandard",     window_x11_isstandard},
    {"_topLeft",       window_x11_topLeft},
    {"_size",          window_x11_size},
    {"_setTopLeft",    window_x11_setTopLeft},
    {"_setSize",       window_x11_setSize},
    {"_minimize",      window_x11_minimize},
    {"_unminimize",    window_x11_unminimize},
    {"isMinimized",    window_x11_isminimized},
//     {"isMaximizable",  window_x11_isMaximizable},
    {"pid",            window_x11_pid},
//     {"application",    window_x11_application},
//     {"focusTab",       window_x11_focustab},
//     {"tabCount",       window_x11_tabcount},
//     {"becomeMain",     window_x11_becomemain},
//     {"raise",          window_x11_raise},
    {"id",             window_x11_id},
//     {"_toggleZoom",    window_x11_togglezoom},
//     {"zoomButtonRect", window_x11_getZoomButtonRect},
//     {"_close",         window_x11_close},
//     {"_setFullScreen", window_x11_setfullscreen},
//     {"isFullScreen",   window_x11_isfullscreen},
//     {"snapshot",       window_x11_snapshot},

//     // hs.uielement methods
//     {"isApplication",  window_x11_uielement_isApplication},
//     {"isWindow",       window_x11_uielement_isWindow},
//     {"role",           window_x11_uielement_role},
//     {"selectedText",   window_x11_uielement_selectedText},
//     {"newWatcher",     window_x11_uielement_newWatcher},

    {"_frame",         window_x11_frame},
    {"_setFrame",      window_x11_setFrame},
    {"_getProperty",   window_x11_getProperty},
    {"_properties",    window_x11_propertyList},
    {"_attributes",    window_x11_attributes},

    {"__tostring",     userdata_tostring},
    {"__eq",           userdata_eq},
    {"__gc",           userdata_gc},
    {NULL,             NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"focusedWindow",  window_x11_focusedwindow},
//     {"_orderedwinids", window__orderedwinids},
//     {"setShadows",     window_x11_setShadows},
//     {"snapshotForID",  window_x11_snapshotForID},
//     {"timeout",        window_x11_timeout},
//     {"list",           window_x11_list},

    {"_rootWindow",    window_x11_rootWindow},
    {"_loadLibrary",   window_x11_loadLibrary},
    {"_setLoggerRef",  window_x11_setLoggerRef},
    {"_windowIDs",     window_x11_windowIDs},
    {"_windowForID",   window_x11_windowForID},

    {NULL,             NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_window_x11_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSX11Window         forClass:"HSX11Window"];
    [skin registerLuaObjectHelper:toHSX11WindowFromLua forClass:"HSX11Window"
                                            withUserdataMapping:USERDATA_TAG];

    return 1;
}
