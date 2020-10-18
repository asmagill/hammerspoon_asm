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
static int      (*XMoveWindowRef)(Display *display, Window w, int x, int y);
static int      (*XResizeWindowRef)(Display *display, Window w, unsigned width, unsigned height);
static int      (*XMoveResizeWindowRef)(Display *display, Window w, int x, int y, unsigned width, unsigned height);
static Status   (*XGetWindowAttributesRef)(Display *display, Window w, XWindowAttributes *window_attributes_return);
static int      (*XGetWindowPropertyRef)(Display *display, Window w, Atom property, long long_offset, long long_length, Bool delete, Atom req_type, Atom *actual_type_return, int *actual_format_return, unsigned long *nitems_return, unsigned long *bytes_after_return, unsigned char **prop_return);
static Atom     (*XInternAtomRef)(Display *display, char *atom_name, Bool only_if_exists);
static Bool     (*XTranslateCoordinatesRef)(Display *display, Window src_w, Window dest_w, int src_x, int src_y, int *dest_x_return, int *dest_y_return, Window *child_return);
static Status   (*XQueryTreeRef)(Display *display, Window w, Window *root_return, Window *parent_return, Window **children_return, unsigned int *nchildren_return);
static Atom    *(*XListPropertiesRef)(Display *display, Window w, int *num_prop_return);
static char    *(*XGetAtomNameRef)(Display *display, Atom atom) ;

// X11 symbols table
#define X11_SYMBOL(s) {&s##Ref,#s}
static void *X11Symbols_[][2] = {
    X11_SYMBOL(XCloseDisplay),
    X11_SYMBOL(XFree),
    X11_SYMBOL(XGetErrorText),
    X11_SYMBOL(XGetWindowAttributes),
    X11_SYMBOL(XGetWindowProperty),
    X11_SYMBOL(XInternAtom),
    X11_SYMBOL(XMoveWindow),
    X11_SYMBOL(XMoveResizeWindow),
    X11_SYMBOL(XOpenDisplay),
    X11_SYMBOL(XResizeWindow),
    X11_SYMBOL(XSetErrorHandler),
    X11_SYMBOL(XSync),
    X11_SYMBOL(XTranslateCoordinates),
    X11_SYMBOL(XQueryTree),
    X11_SYMBOL(XListProperties),
    X11_SYMBOL(XGetAtomName)
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
    moduleLogger("w", [NSString stringWithFormat:@"X11Error: %s (code: %d)", msg, err->request_code]) ;
    return 0 ;
}

@interface HSX11Window : NSObject
@property (nonatomic) int    selfRefCount ;
@property (readonly)  Window winRef ;
// @property (nonatomic, readonly) pid_t pid;
// @property (nonatomic, readonly) AXUIElementRef elementRef;
// @property (nonatomic, readonly) CGWindowID winID;
// @property (nonatomic, readonly) HSuielement *uiElement;

// @property (nonatomic, readonly, getter=title) NSString *title;
// @property (nonatomic, readonly, getter=role) NSString *role;
// @property (nonatomic, readonly, getter=subRole) NSString *subRole;
// @property (nonatomic, readonly, getter=isStandard) BOOL isStandard;
// @property (nonatomic, getter=getTopLeft, setter=setTopLeft:) NSPoint topLeft;
// @property (nonatomic, getter=getSize, setter=setSize:) NSSize size;
// @property (nonatomic, getter=isFullscreen, setter=setFullscreen:) BOOL fullscreen;
// @property (nonatomic, getter=isMinimized, setter=setMinimized:) BOOL minimized;
// @property (nonatomic, getter=getApplication) id application;
// @property (nonatomic, readonly, getter=getZoomButtonRect) NSRect zoomButtonRect;
// @property (nonatomic, readonly, getter=getTabCount) int tabCount;

// Class methods
// +(NSArray<NSNumber *>*)orderedWindowIDs;
// +(NSImage *)snapshotForID:(int)windowID keepTransparency:(BOOL)keepTransparency;
+(HSX11Window *)focusedWindow;

// Initialiser
-(instancetype)initWithWindowRef:(Window)winRef ;
//
// // Destructor
// -(void)dealloc;
//
// // Instance methods
// -(NSString *)title;
// -(NSString *)subRole;
// -(NSString *)role;
// -(BOOL)isStandard;
// -(NSPoint)getTopLeft;
// -(void)setTopLeft:(NSPoint)topLeft;
// -(NSSize)getSize;
// -(void)setSize:(NSSize)size;
// -(BOOL)pushButton:(CFStringRef)buttonId;
// -(void)toggleZoom;
// -(NSRect)getZoomButtonRect;
// -(BOOL)close;
// -(BOOL)focusTab:(int)index;
// -(int)getTabCount;
// -(BOOL)isFullscreen;
// -(void)setFullscreen:(BOOL)fullscreen;
// -(BOOL)isMinimized;
// -(void)setMinimized:(BOOL)minimize;
// -(id)getApplication;
// -(void)becomeMain;
// -(void)raise;
// -(NSImage *)snapshot:(BOOL)keepTransparency;
@end

@implementation HSX11Window
- (instancetype)initWithWindowRef:(Window)winRef {
    self = [super init] ;
    if (self) {
        _winRef       = winRef ;
        _selfRefCount = 0 ;
    }
    return self ;
}

// - (void)dealloc {
//     if (_winRef != NULL) XFreeRef(_winRef) ;
//     _winRef = NULL ;
// }

+(instancetype)rootWindow {
    HSX11Window *window = nil;

    if (X11Lib_ != NULL) {
        Display *dpy = XOpenDisplayRef(NULL) ;
        if (dpy != NULL) {
            XSetErrorHandlerRef(&X11ErrorHandler) ;
            Window root = DefaultRootWindow(dpy) ;
            window = [[HSX11Window alloc] initWithWindowRef:root] ;
            XCloseDisplayRef(dpy) ;
        }
    }
    return window;
}

+(instancetype)focusedWindow {
    HSX11Window *window = nil;

    if (X11Lib_ != NULL) {
        Display *dpy = XOpenDisplayRef(NULL) ;
        if (dpy != NULL) {
            XSetErrorHandlerRef(&X11ErrorHandler) ;
            Window root = DefaultRootWindow(dpy) ;

            // following are for the params that are not used
            int not_used_int;
            unsigned long not_used_long;

            Atom actual_type = 0;
            unsigned char *prop_return = NULL;

            if(XGetWindowPropertyRef(dpy, root, XInternAtomRef(dpy, "_NET_ACTIVE_WINDOW", False), 0, 0x7fffffff, False,
                                     XA_WINDOW, &actual_type, &not_used_int, &not_used_long, &not_used_long,
                                     &prop_return) == Success) {
                if (prop_return != NULL && *((Window *) prop_return) != 0) {
                    Window *winRef = (Window *)prop_return ;
                    window = [[HSX11Window alloc] initWithWindowRef:*winRef] ;
                    XFreeRef(prop_return) ;
                } else {
                    moduleLogger("i",  @"No X11 active window found") ;
                }
            } else {
                moduleLogger("e",  @"Unable to get active window (XGetWindowProperty)") ;
            }
            XCloseDisplayRef(dpy) ;
        }
    }
    return window;
}

+(NSArray<NSNumber *>*)windowIDs {
    NSMutableArray *windows = [NSMutableArray array] ;

    if (X11Lib_ != NULL) {
        Display *dpy = XOpenDisplayRef(NULL) ;
        if (dpy != NULL) {
            XSetErrorHandlerRef(&X11ErrorHandler) ;
            Window root = DefaultRootWindow(dpy) ;

            Atom          actual_type_return   = 0 ;
            int           actual_format_return = 0 ;
            unsigned long nitems_return        = 0l ;
            unsigned long bytes_after_return   = 0l ;
            unsigned char *prop_return         = NULL ;

            if (XGetWindowPropertyRef(
                                        dpy,
                                        root,
                                        XInternAtomRef(dpy, "_NET_CLIENT_LIST", False),
                                        0,
                                        0x7fffffff,
                                        False,
                                        XA_WINDOW,
                                        &actual_type_return,
                                        &actual_format_return,
                                        &nitems_return,
                                        &bytes_after_return,
                                        &prop_return
                                     ) == Success) {

                if (prop_return != NULL && *((Window *) prop_return) != 0) {
                    Window *winRefs = (Window *)prop_return ;
                    for (unsigned long i = 0 ; i < nitems_return ; i++) {
                        Window ref = winRefs[i] ;
                        [windows addObject:[NSNumber numberWithUnsignedLong:ref]] ;
                    }
                    XFreeRef(prop_return) ;
                } else {
                    moduleLogger("i",  @"No X11 window list found") ;
                }
            } else {
                moduleLogger("e",  @"Unable to get active window list (XGetWindowProperty)") ;
            }
            XCloseDisplayRef(dpy) ;
        }
    }

    return [windows copy] ;
}

-(NSDictionary *)propertyList {
    NSMutableDictionary *results = [NSMutableDictionary dictionary] ;

    Display *dpy = XOpenDisplayRef(NULL) ;
    if (dpy != NULL) {
        XSetErrorHandlerRef(&X11ErrorHandler) ;
        int num_prop_return ;
        Atom *windowProperties = XListPropertiesRef(dpy, _winRef, &num_prop_return) ;

        for (int idx = 0 ; idx < num_prop_return ; idx++) {
            char     *atom_name = XGetAtomNameRef(dpy, windowProperties[idx]) ;
            NSString *key       = [NSString stringWithUTF8String:atom_name] ;
            XFreeRef(atom_name) ;

            Atom          actual_type_return   = 0 ;
            int           actual_format_return = 0 ;
            unsigned long nitems_return        = 0l ;
            unsigned long bytes_after_return   = 0l ;
            unsigned char *prop_return         = NULL ;
            if (XGetWindowPropertyRef(
                                        dpy,
                                        _winRef,
                                        windowProperties[idx],
                                        0,
                                        0x7fffffff,
                                        False,
                                        AnyPropertyType,
                                        &actual_type_return,
                                        &actual_format_return,
                                        &nitems_return,
                                        &bytes_after_return,
                                        &prop_return
                                     ) == Success) {
                char     *type_name = XGetAtomNameRef(dpy, actual_type_return) ;
                NSString *type      = [NSString stringWithUTF8String:type_name] ;
                XFreeRef(type_name) ;
                if (actual_format_return == 8) {
                    NSString *value = [NSString stringWithUTF8String:(const char *)prop_return] ;
                    results[key] = @{ @"value": value, @"type" :type, @"size" : @(nitems_return) } ;
                } else if (actual_format_return == 16) {
                    short *numbers = (short *)prop_return ;
                    NSMutableArray *value = [NSMutableArray arrayWithCapacity:nitems_return] ;
                    for (unsigned long i = 0 ; i < nitems_return ; i++) [value addObject:[NSNumber numberWithShort:numbers[i]]] ;
                    results[key] = @{ @"value": [value copy], @"type" : type, @"size" : @(nitems_return) } ;
                } else if (actual_format_return == 32) {
                    long *numbers = (long *)prop_return ;
                    NSMutableArray *value = [NSMutableArray arrayWithCapacity:nitems_return] ;
                    for (unsigned long i = 0 ; i < nitems_return ; i++) [value addObject:[NSNumber numberWithLong:numbers[i]]] ;
                    results[key] = @{ @"value": [value copy], @"type" : type, @"size" : @(nitems_return) } ;
                } else if (actual_format_return != 0) {
                    moduleLogger("i", [NSString stringWithFormat:@"%@ has a return format of %d", key, actual_format_return]) ;
                }
                XFreeRef(prop_return) ;
            }
        }

        XFreeRef(windowProperties) ;
        XCloseDisplayRef(dpy) ;
    }

    return [results copy] ;
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
    [skin pushNSObject:[HSX11Window windowIDs]] ;
    return 1;
}

static int window_x11_windowForID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    Window winID = (Window)lua_tointeger(L, 1) ;
    BOOL bypass = lua_gettop(L) > 1 ? (BOOL)(lua_toboolean(L, 2)) : NO ;

    HSX11Window *window = nil ;
    NSArray *windowIDs = [HSX11Window windowIDs] ;
    if (bypass || [windowIDs containsObject:@(winID)]) {
        window = [[HSX11Window alloc] initWithWindowRef:winID] ;
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

static int window_x11_propertyList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *window = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:[window propertyList]];
    return 1;
}

static int window_x11_id(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *window = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, (lua_Integer)window.winRef) ;
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
    #pragma message "need to fix title for __tostring"
//     HSX11Window *obj = [skin luaObjectAtIndex:1 toClass:"HSX11Window"] ;
    NSString *title = @"<X11Window>" ;
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
//     {"title",          window_x11_title},
//     {"subrole",        window_x11_subrole},
//     {"role",           window_x11_role},
//     {"isStandard",     window_x11_isstandard},
//     {"topLeft",        window_x11_topleft},
//     {"size",           window_x11_size},
//     {"setTopLeft",     window_x11_settopleft},
//     {"setSize",        window_x11_setsize},
//     {"minimize",       window_x11_minimize},
//     {"unminimize",     window_x11_unminimize},
//     {"isMinimized",    window_x11_isminimized},
//     {"isMaximizable",  window_x11_isMaximizable},
//     {"pid",            window_x11_pid},
//     {"application",    window_x11_application},
//     {"focusTab",       window_x11_focustab},
//     {"tabCount",       window_x11_tabcount},
//     {"becomeMain",     window_x11_becomemain},
//     {"raise",          window_x11_raise},
    {"id",             window_x11_id},
//     {"toggleZoom",     window_x11_togglezoom},
//     {"zoomButtonRect", window_x11_getZoomButtonRect},
//     {"close",          window_x11_close},
//     {"setFullScreen",  window_x11_setfullscreen},
//     {"isFullScreen",   window_x11_isfullscreen},
//     {"snapshot",       window_x11_snapshot},

//     // hs.uielement methods
//     {"isApplication",  window_x11_uielement_isApplication},
//     {"isWindow",       window_x11_uielement_isWindow},
//     {"role",           window_x11_uielement_role},
//     {"selectedText",   window_x11_uielement_selectedText},
//     {"newWatcher",     window_x11_uielement_newWatcher},

    {"propertyList",   window_x11_propertyList},

    {"__tostring",     userdata_tostring},
    {"__eq",           userdata_eq},
    {"__gc",           userdata_gc},
    {NULL,             NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"_loadLibrary",   window_x11_loadLibrary},
    {"_setLoggerRef",  window_x11_setLoggerRef},

    {"rootWindow",     window_x11_rootWindow},
    {"focusedWindow",  window_x11_focusedwindow},
    {"windowIDs",      window_x11_windowIDs},
    {"windowForID",    window_x11_windowForID},

//     {"setShadows",     window_x11_setShadows},
//     {"snapshotForID",  window_x11_snapshotForID},
//     {"timeout",        window_x11_timeout},
//     {"list",           window_x11_list},
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
