// TODO
//    group items
//    addItemAtPosition
//    removeItemAtPosition

// Usefull?
//    @property(strong) NSMenuItem *menuFormRepresentation
//    @property(strong) NSView *view
//    @property NSSize minSize
//    @property NSSize maxSize

// Hooks into:
//    hs.drawing
//    hs.webview
// -  hs.console

// What would it take to properly support
//    color panel
//    font panel
//    NSSearchField
// -  configuration panel with autosave/resume
//    print?

#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG "hs._asm.toolbar"
static int refTable = LUA_NOREF;

static NSArray * builtinToolbarItems ;

#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_cfobjectFromUserdata(objType, L, idx) *((objType*)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

@interface MJConsoleWindowController : NSWindowController
+ (instancetype)singleton;
- (void)setup;
@end

@interface MJConsoleWindowController ()
@property NSMutableArray *history;
@property NSInteger historyIndex;
@property IBOutlet NSTextView *outputView;
@property (weak) IBOutlet NSTextField *inputField;
@property NSMutableArray *preshownStdouts;
@end

@interface HSToolbar : NSToolbar <NSToolbarDelegate>
@property int                             callbackRef;
@property int                             selfRef;
@property (readonly) NSMutableArray*      allowedIdentifiers ;
@property (readonly) NSMutableArray*      defaultIdentifiers ;
@property (readonly) NSMutableArray*      selectableIdentifiers ;
@property (readonly) NSMutableDictionary* itemDictionary ;
@property (readonly) NSMutableDictionary* fnRefDictionary ;
@property (readonly) NSMutableDictionary* enabledDictionary ;
@property (readonly) NSHashTable*         windowsUsingToolbars ;
@end

@implementation HSToolbar
- (instancetype)initWithIdentifier:(NSString *)identifier itemTableIndex:(int)idx {
    self = [super initWithIdentifier:identifier] ;
    if (self) {
        _callbackRef           = LUA_NOREF;
        _selfRef               = LUA_NOREF;
        _allowedIdentifiers    = [[NSMutableArray alloc] init] ;
        _defaultIdentifiers    = [[NSMutableArray alloc] init] ;
        _selectableIdentifiers = [[NSMutableArray alloc] init] ;
        _itemDictionary        = [[NSMutableDictionary alloc] init] ;
        _fnRefDictionary       = [[NSMutableDictionary alloc] init] ;
        _enabledDictionary     = [[NSMutableDictionary alloc] init] ;
        _windowsUsingToolbars  = [NSHashTable weakObjectsHashTable] ;

        [_allowedIdentifiers addObjectsFromArray:builtinToolbarItems] ;

        LuaSkin     *skin      = [LuaSkin shared] ;
        lua_State   *L         = [skin L] ;
        lua_Integer count      = luaL_len(L, idx) ;
        lua_Integer index      = 0 ;
        BOOL        isGood     = YES ;

        idx = lua_absindex(L, idx) ;
        while (isGood && (index < count)) {
            if (lua_rawgeti(L, idx, index + 1) == LUA_TTABLE) {
                isGood = [self addToolbarItemAtIndex:-1] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:not table at index %lld; ignoring item for toolbar %@",
                                                          USERDATA_TAG, index + 1, identifier]] ;
            }
            lua_pop(L, 1) ;
            index++ ;
        }
        if (!isGood) {
            [skin logError:[NSString stringWithFormat:@"%s:malformed toolbar items encountered", USERDATA_TAG]] ;
            return nil ;
        }

        self.allowsUserCustomization = NO ;
        self.allowsExtensionItems    = NO ;
        self.autosavesConfiguration  = NO ;
        self.delegate                = self ;
    }
    return self ;
}

-(void)performCallback:(id)sender{
    NSToolbarItem *item = sender;
    NSNumber *theFnRef = [_fnRefDictionary objectForKey:[item itemIdentifier]] ;
    int itemFnRef = theFnRef ? [theFnRef intValue] : LUA_NOREF ;
    int fnRef = (itemFnRef != LUA_NOREF) ? itemFnRef : _callbackRef ;
    if (fnRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            [skin pushLuaRef:refTable ref:fnRef] ;
//             [skin pushLuaRef:refTable ref:_selfRef] ;
//             [skin pushNSObject:[item itemIdentifier]] ;
//             if (![skin protectedCallAndTraceback:2 nresults:0]) {
            [skin pushNSObject:item] ;
            if (![skin protectedCallAndTraceback:1 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s: callback error, %s",
                                                          USERDATA_TAG,
                                                          lua_tostring(L, -1)]] ;
                lua_pop(L, 1) ;
            }
        }) ;
    }
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem {
    return [[_enabledDictionary objectForKey:[theItem itemIdentifier]] boolValue] ;
}

- (BOOL)addToolbarItemAtIndex:(int)idx {
    LuaSkin   *skin      = [LuaSkin shared] ;
    lua_State *L         = [skin L] ;
    NSString  *identifier ;
    NSString  *label ;
    NSString  *paletteLabel ;
    NSString  *tooltip ;
    BOOL      enabled    = YES ;
    BOOL      included   = YES ;
    BOOL      selectable = NO ;
    NSImage   *image ;
    NSInteger priority   = NSToolbarItemVisibilityPriorityStandard ;
    NSInteger tag        = 0 ;

    idx = lua_absindex(L, idx) ;
    if (lua_getfield(L, idx, "id") == LUA_TSTRING) {
        identifier = [skin toNSObjectAtIndex:-1] ;
    } else {
        lua_pop(L, 1) ;
        [skin  logWarn:[NSString stringWithFormat:@"%s:id must be present, and it must be a string",
                                                   USERDATA_TAG]] ;
        return NO ;
    }
    lua_pop(L, 1) ;
    if (lua_getfield(L, idx, "label") == LUA_TSTRING) {
        label = [skin toNSObjectAtIndex:-1] ;
    } else {
        label = identifier ;
    }
    lua_pop(L, 1) ;
    if (lua_getfield(L, 2, "paletteLabel") == LUA_TSTRING) {
        paletteLabel = [skin toNSObjectAtIndex:-1] ;
    } else {
        paletteLabel = label ;
    }
    lua_pop(L, 1) ;
    if (lua_getfield(L, idx, "tooltip") == LUA_TSTRING) {
        tooltip = [skin toNSObjectAtIndex:-1] ;
    }
    lua_pop(L, 1) ;
    if ((lua_getfield(L, idx, "image") == LUA_TUSERDATA) && luaL_checkudata(L, -1, "hs.image")) {
        image = [skin toNSObjectAtIndex:-1] ;
    } else {
        image = [NSImage imageNamed:NSImageNameStatusNone] ;
    }
    lua_pop(L, 1) ;
    if (lua_getfield(L, idx, "enabled") == LUA_TBOOLEAN) {
        enabled = (BOOL)lua_toboolean(L, -1) ;
    }
    if (lua_getfield(L, idx, "default") == LUA_TBOOLEAN) {
        included = (BOOL)lua_toboolean(L, -1) ;
    }
    lua_pop(L, 1) ;
    if (lua_getfield(L, idx, "selectable") == LUA_TBOOLEAN) {
        selectable = (BOOL)lua_toboolean(L, -1) ;
    }
    lua_pop(L, 1) ;
    if ((lua_getfield(L, idx, "priority") == LUA_TNUMBER) && lua_isinteger(L, -1)) {
        priority = lua_tointeger(L, -1) ;
    }
    lua_pop(L, 1) ;
    if ((lua_getfield(L, idx, "tag") == LUA_TNUMBER) && lua_isinteger(L, -1)) {
        tag = lua_tointeger(L, -1) ;
    }
    lua_pop(L, 1) ;

    if (![builtinToolbarItems containsObject:identifier]) {
        if ([_itemDictionary objectForKey:identifier]) {
            [skin  logWarn:[NSString stringWithFormat:@"%s:id must be unique or a system defined item",
                                                       USERDATA_TAG]] ;
            return NO ;
        }
        NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier] ;
        [toolbarItem setLabel:label] ;
        [toolbarItem setPaletteLabel:paletteLabel] ;
        if (tooltip) [toolbarItem setToolTip:tooltip] ;
        if (image)   [toolbarItem setImage:image] ;
        [_enabledDictionary setObject:@(enabled) forKey:identifier] ;
        [toolbarItem setVisibilityPriority:priority] ;
        [toolbarItem setTag:tag] ;
        [toolbarItem setTarget:self] ;
        [toolbarItem setAction:@selector(performCallback:)] ;

        if (lua_getfield(L, idx, "fn") == LUA_TFUNCTION) {
            [_fnRefDictionary setObject:@([skin luaRef:refTable]) forKey:identifier] ;
        } else {
            [_fnRefDictionary setObject:@(LUA_NOREF) forKey:identifier] ;
            lua_pop(L, 1) ;
        }

        [_itemDictionary setObject:toolbarItem forKey:identifier] ;
        [_allowedIdentifiers addObject:identifier] ;
        if (selectable) [_selectableIdentifiers addObject:identifier] ;
    }
    if (included) [_defaultIdentifiers addObject:identifier] ;
    return YES ;
}

#pragma mark - NSToolbarDelegate stuff

- (NSToolbarItem *)toolbar:(__unused NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier
                                                     willBeInsertedIntoToolbar:(__unused BOOL)flag {
    return [_itemDictionary objectForKey:itemIdentifier] ;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(__unused NSToolbar *)toolbar  {
    return _allowedIdentifiers ;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(__unused NSToolbar *)toolbar {
    return _defaultIdentifiers ;
}

- (NSArray *)toolbarSelectableItemIdentifiers:(__unused NSToolbar *)toolbar {
    return _selectableIdentifiers ;
}

// - (void)toolbarWillAddItem:(NSNotification *)notification {}
// - (void)toolbarDidRemoveItem:(NSNotification *)notification {}

@end

#pragma mark - Module Functions

static int newHSToolbar(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TTABLE, LS_TBREAK] ;
    HSToolbar *toolbar = [[HSToolbar alloc] initWithIdentifier:[skin toNSObjectAtIndex:1]
                                            itemTableIndex:2] ;
    if (toolbar) {
        [skin pushNSObject:toolbar] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    // in either case, we need to remove an existing callback, so...
    toolbar.callbackRef = [skin luaUnref:refTable ref:toolbar.callbackRef] ;
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2) ;
        toolbar.callbackRef = [skin luaRef:refTable] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int configurationDictionary(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[toolbar configurationDictionary]] ;
    return 1 ;
}

static int showsBaselineSeparator(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) != 1) {
        [toolbar setShowsBaselineSeparator:(BOOL)lua_toboolean(L, 2)] ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, [toolbar showsBaselineSeparator]) ;
    }
    return 1 ;
}

static int visible(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) != 1) {
        [toolbar setVisible:(BOOL)lua_toboolean(L, 2)] ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, [toolbar isVisible]) ;
    }
    return 1 ;
}

static int sizeMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        if (lua_type(L, 2) == LUA_TNIL) {
            [toolbar setSizeMode:NSToolbarSizeModeDefault] ;
        } else {
            NSString *size = [skin toNSObjectAtIndex:2] ;
            if ([size isEqualToString:@"regular"]) {
                [toolbar setSizeMode:NSToolbarSizeModeRegular] ;
            } else if ([size isEqualToString:@"small"]) {
                [toolbar setSizeMode:NSToolbarSizeModeSmall] ;
            } else {
                return luaL_error(L, [[NSString stringWithFormat:@"invalid sizeMode:%@", size] UTF8String]) ;
            }
        }
        lua_pushvalue(L, 1) ;
    } else {
        switch(toolbar.sizeMode) {
            case NSToolbarSizeModeDefault:
                [skin pushNSObject:@"default"] ;
                break ;
            case NSToolbarSizeModeRegular:
                [skin pushNSObject:@"regular"] ;
                break ;
            case NSToolbarSizeModeSmall:
                [skin pushNSObject:@"small"] ;
                break ;
            default:
                [skin pushNSObject:[NSString stringWithFormat:@"** unrecognized sizeMode (%tu)",
                                                              toolbar.sizeMode]] ;
                break ;
        }
    }
    return 1 ;
}

static int displayMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        if (lua_type(L, 2) == LUA_TNIL) {
            [toolbar setDisplayMode:NSToolbarDisplayModeDefault] ;
        } else {
            NSString *type = [skin toNSObjectAtIndex:2] ;
            if ([type isEqualToString:@"label"]) {
                [toolbar setDisplayMode:NSToolbarDisplayModeLabelOnly] ;
            } else if ([type isEqualToString:@"icon"]) {
                [toolbar setDisplayMode:NSToolbarDisplayModeIconOnly] ;
            } else if ([type isEqualToString:@"both"]) {
                [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel] ;
            } else {
                return luaL_error(L, [[NSString stringWithFormat:@"invalid displayMode:%@", type] UTF8String]) ;
            }
        }
        lua_pushvalue(L, 1) ;
    } else {
        switch(toolbar.displayMode) {
            case NSToolbarDisplayModeDefault:
                [skin pushNSObject:@"default"] ;
                break ;
            case NSToolbarDisplayModeLabelOnly:
                [skin pushNSObject:@"label"] ;
                break ;
            case NSToolbarDisplayModeIconOnly:
                [skin pushNSObject:@"icon"] ;
                break ;
            case NSToolbarDisplayModeIconAndLabel:
                [skin pushNSObject:@"both"] ;
                break ;
            default:
                [skin pushNSObject:[NSString stringWithFormat:@"** unrecognized displayMode (%tu)",
                                                              toolbar.displayMode]] ;
                break ;
        }
    }
    return 1 ;
}

static int modifyToolbarItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    NSString *identifier ;

    if (lua_getfield(L, 2, "id") == LUA_TSTRING) {
        identifier = [skin toNSObjectAtIndex:-1] ;
    } else {
        lua_pop(L, 1) ;
        return luaL_error(L, "id must be present, and it must be a string") ;
    }
    lua_pop(L, 1) ;
    NSToolbarItem *theItem = [toolbar.itemDictionary objectForKey:identifier] ;
    if ((![builtinToolbarItems containsObject:identifier]) && theItem) {
        if (lua_getfield(L, 2, "label") == LUA_TSTRING) {
            [theItem setLabel:[skin toNSObjectAtIndex:-1]] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, 2, "paletteLabel") == LUA_TSTRING) {
            [theItem setPaletteLabel:[skin toNSObjectAtIndex:-1]] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, 2, "tooltip") == LUA_TSTRING) {
            [theItem setToolTip:[skin toNSObjectAtIndex:-1]] ;
        }
        lua_pop(L, 1) ;
        if ((lua_getfield(L, 2, "image") == LUA_TUSERDATA) && luaL_checkudata(L, -1, "hs.image")) {
            [theItem setImage:[skin toNSObjectAtIndex:-1]] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, 2, "enabled") == LUA_TBOOLEAN) {
            [toolbar.enabledDictionary setObject:@((BOOL)lua_toboolean(L, -1)) forKey:identifier] ;
        }
        lua_pop(L, 1) ;
        lua_getfield(L, 2, "fn") ;
        if ((lua_type(L, -1) == LUA_TFUNCTION) || ((lua_type(L, -1) == LUA_TBOOLEAN) && !lua_toboolean(L, -1))) {
            NSNumber *theNumber = [toolbar.fnRefDictionary objectForKey:identifier] ;
            if (theNumber) [toolbar.fnRefDictionary setObject:@([skin luaUnref:refTable ref:[theNumber intValue]])
                                                       forKey:identifier] ;
            if (lua_type(L, -1) == LUA_TFUNCTION) {
                [toolbar.fnRefDictionary setObject:@([skin luaRef:refTable])
                                            forKey:identifier] ;
            } else {
                lua_pop(L, 1) ;
            }
        } else {
            lua_pop(L, 1) ;
        }
        if ((lua_getfield(L, 2, "priority") == LUA_TNUMBER) && lua_isinteger(L, -1)) {
            [theItem setVisibilityPriority:lua_tointeger(L, -1)] ;
        }
        lua_pop(L, 1) ;
        if ((lua_getfield(L, 2, "tag") == LUA_TNUMBER) && lua_isinteger(L, -1)) {
            [theItem setTag:lua_tointeger(L, -1)] ;
        }
        lua_pop(L, 1) ;
    } else {
        return luaL_error(L, "id does not match a user defined toolbar item") ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int toolbarItems(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[toolbar items]] ;
    return 1 ;
}

static int visibleToolbarItems(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[toolbar visibleItems]] ;
    return 1 ;
}

static int selectedToolbarItem(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[toolbar selectedItemIdentifier]] ;
    return 1 ;
}

static int toolbarIdentifier(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[toolbar identifier]] ;
    return 1 ;
}

static int customizeToolbar(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    [toolbar runCustomizationPalette:toolbar] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int toolbarIsCustomizing(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, toolbar.customizationPaletteIsRunning) ;
    return 1 ;
}

static int toolbarCanCustomize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, toolbar.allowsUserCustomization) ;
    } else {
        [toolbar setAllowsUserCustomization:(BOOL)lua_toboolean(L, 2)] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int toolbarCanAutosave(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, toolbar.autosavesConfiguration) ;
    } else {
        [toolbar setAutosavesConfiguration:(BOOL)lua_toboolean(L, 2)] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int attachToConsole(lua_State *L) {
    LuaSkin *skin     = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    NSWindow *console = [[MJConsoleWindowController singleton] window];
    if (lua_toboolean(L, 2)) {
        [console setToolbar:toolbar] ;
        [toolbar.windowsUsingToolbars addObject:console] ;
    } else {
        [console setToolbar:nil] ;
        [toolbar.windowsUsingToolbars removeObject:console] ;    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int infoDump(lua_State *L) {
    LuaSkin *skin     = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    lua_newtable(L) ;
    [skin pushNSObject:toolbar.allowedIdentifiers] ;    lua_setfield(L, -2, "allowedIdentifiers") ;
    [skin pushNSObject:toolbar.defaultIdentifiers] ;    lua_setfield(L, -2, "defaultIdentifiers") ;
    [skin pushNSObject:toolbar.selectableIdentifiers] ; lua_setfield(L, -2, "selectableIdentifiers") ;
    [skin pushNSObject:toolbar.itemDictionary] ;        lua_setfield(L, -2, "itemDictionary") ;
    [skin pushNSObject:toolbar.fnRefDictionary] ;       lua_setfield(L, -2, "fnRefDictionary") ;
    [skin pushNSObject:toolbar.enabledDictionary] ;     lua_setfield(L, -2, "enabledDictionary") ;
    lua_pushinteger(L, toolbar.callbackRef) ;           lua_setfield(L, -2, "callbackRef") ;
    lua_pushinteger(L, toolbar.selfRef) ;               lua_setfield(L, -2, "selfRef") ;

    lua_pushinteger(L, (lua_Integer)[toolbar.windowsUsingToolbars count]) ;
    lua_setfield(L, -2, "windowsCount") ;
    [skin pushNSObject:toolbar.windowsUsingToolbars withOptions:LS_NSDescribeUnknownTypes] ;
    lua_setfield(L, -2, "windowsUsingToolbars") ;
    return 1 ;
}

#pragma mark - Module Constants

static int systemToolbarItems(__unused lua_State *L) {
    [[LuaSkin shared] pushNSObject:builtinToolbarItems] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSToolbar(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSToolbar *value = obj;
    if (value.selfRef == LUA_NOREF) {
        void** valuePtr = lua_newuserdata(L, sizeof(HSToolbar *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
        value.selfRef = [skin luaRef:refTable] ;
    }

    [skin pushLuaRef:refTable ref:value.selfRef] ;
    return 1;
}

static id toHSToolbarFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSToolbar *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSToolbar, L, idx) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSToolbarItem(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSToolbarItem *value = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:[value itemIdentifier]] ;     lua_setfield(L, -2, "id") ;
    [skin pushNSObject:[value label]] ;              lua_setfield(L, -2, "label") ;
    [skin pushNSObject:[value paletteLabel]] ;       lua_setfield(L, -2, "paletteLabel") ;
    [skin pushNSObject:[value toolTip]] ;            lua_setfield(L, -2, "tooltip") ;
    [skin pushNSObject:[value image]] ;              lua_setfield(L, -2, "image") ;
    lua_pushinteger(L, [value visibilityPriority]) ; lua_setfield(L, -2, "priority") ;
    lua_pushboolean(L, [value isEnabled]) ;          lua_setfield(L, -2, "enable") ;
    lua_pushinteger(L, [value tag]) ;                lua_setfield(L, -2, "tag") ;

    if ([[value toolbar] isKindOfClass:[HSToolbar class]]) {
        [skin pushNSObject:[value toolbar]] ;        lua_setfield(L, -2, "toolbar") ;
        HSToolbar *ourToolbar = (HSToolbar *)[value toolbar] ;
        lua_pushboolean(L, [ourToolbar.selectableIdentifiers containsObject:[value itemIdentifier]]) ;
        lua_setfield(L, -2, "selectable") ;
    }

//     [skin pushNSSize:[value minSize]] ;              lua_setfield(L, -2, "minSize") ;
//     [skin pushNSSize:[value maxSize]] ;              lua_setfield(L, -2, "maxSize") ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSToolbar *obj = [skin luaObjectAtIndex:1 toClass:"HSToolbar"] ;
    NSString *title = obj.identifier ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSToolbar *obj1 = [skin luaObjectAtIndex:1 toClass:"HSToolbar"] ;
        HSToolbar *obj2 = [skin luaObjectAtIndex:2 toClass:"HSToolbar"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSToolbar *obj = get_objectFromUserdata(__bridge_transfer HSToolbar, L, 1) ;
    if (obj) {
        for (NSNumber *fnRef in [obj.fnRefDictionary allValues]) {
            [skin luaUnref:refTable ref:[fnRef intValue]] ;
        }
    // FIXME: remove from all windows... probably need observer to get them from drawing and webview
        for (NSWindow *window in obj.windowsUsingToolbars) {
            if (window && [window.toolbar isEqualTo:obj]) [window setToolbar:nil] ;
        }
        LuaSkin *skin = [LuaSkin shared] ;
        obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef];
        obj.selfRef = [skin luaUnref:refTable ref:obj.selfRef] ;
        obj.delegate = nil ;
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
    {"identifier",      toolbarIdentifier},
    {"setCallback",     setCallback},
    {"displayMode",     displayMode},
    {"sizeMode",        sizeMode},
    {"visible",         visible},
    {"modifyItem",      modifyToolbarItem},
    {"items",           toolbarItems},
    {"visibleItems",    visibleToolbarItems},
    {"selectedItem",    selectedToolbarItem},

    {"attachToConsole", attachToConsole},

    {"infoDump",        infoDump},

    {"customizePanel",  customizeToolbar},
    {"isCustomizing",   toolbarIsCustomizing},
    {"canCustomize",    toolbarCanCustomize},
    {"autosaves",       toolbarCanAutosave},

    {"separator",       showsBaselineSeparator},
    {"dictionary",      configurationDictionary},

    {"delete",          userdata_gc},

    {"__tostring",      userdata_tostring},
    {"__eq",            userdata_eq},
    {"__gc",            userdata_gc},
    {NULL,              NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", newHSToolbar},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_toolbar_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    builtinToolbarItems = @[
//                               NSToolbarSeparatorItemIdentifier, // deprecated
                              NSToolbarSpaceItemIdentifier,
                              NSToolbarFlexibleSpaceItemIdentifier,
                              NSToolbarShowColorsItemIdentifier,
                              NSToolbarShowFontsItemIdentifier,
//                               NSToolbarCustomizeToolbarItemIdentifier, // deprecated
                              NSToolbarPrintItemIdentifier,
                          ] ;

    systemToolbarItems(L) ; lua_setfield(L, -2, "systemToolbarItems") ;

    [skin registerPushNSHelper:pushHSToolbar         forClass:"HSToolbar"];
    [skin registerLuaObjectHelper:toHSToolbarFromLua forClass:"HSToolbar" withUserdataMapping:USERDATA_TAG];

    [skin registerPushNSHelper:pushNSToolbarItem     forClass:"NSToolbarItem"];

    return 1;
}
