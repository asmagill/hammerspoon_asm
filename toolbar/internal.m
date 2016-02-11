// TODO
//    Documentation
//    group items

#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG  "hs._asm.toolbar"
static int            refTable = LUA_NOREF;
static NSArray        *builtinToolbarItems ;
static NSMutableArray *identifiersInUse ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx) *((objType*)luaL_checkudata(L, idx, USERDATA_TAG))

@interface MJConsoleWindowController : NSWindowController
+ (instancetype)singleton;
- (void)setup;
@end

@interface HSToolbar : NSToolbar <NSToolbarDelegate>
@property            int                 callbackRef;
@property            int                 selfRef;
@property (readonly) NSMutableArray      *allowedIdentifiers ;
@property (readonly) NSMutableArray      *defaultIdentifiers ;
@property (readonly) NSMutableArray      *selectableIdentifiers ;
@property (readonly) NSMutableDictionary *itemDictionary ;
@property (readonly) NSMutableDictionary *fnRefDictionary ;
@property (readonly) NSMutableDictionary *enabledDictionary ;
@property (weak)     NSWindow            *windowUsingToolbar ;
@end

#pragma mark - Support Functions and Classes

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
        _windowUsingToolbar    = nil ;

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

- (instancetype)initWithCopy:(HSToolbar *)original {
    LuaSkin *skin = [LuaSkin shared] ;
    if (original) self = [super initWithIdentifier:[original identifier]] ;
    if (self) {
        _callbackRef           = LUA_NOREF ;
        if (_callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:_callbackRef] ;
            _callbackRef = [skin luaRef:refTable] ;
        }
        _selfRef               = LUA_NOREF;
        _allowedIdentifiers    = original.allowedIdentifiers ;
        _defaultIdentifiers    = original.defaultIdentifiers ;
        _selectableIdentifiers = original.selectableIdentifiers ;
        _itemDictionary        = original.itemDictionary ;
        _fnRefDictionary       = [[NSMutableDictionary alloc] init] ;
        for (NSString *key in [original.fnRefDictionary allKeys]) {
            int theRef = [[original.fnRefDictionary objectForKey:key] intValue] ;
            if (theRef != LUA_NOREF) {
                [skin pushLuaRef:refTable ref:theRef] ;
                theRef = [skin luaRef:refTable] ;
            }
            [_fnRefDictionary setObject:@(theRef) forKey:key] ;
        }
        _enabledDictionary     = [[NSMutableDictionary alloc] initWithDictionary:original.enabledDictionary
                                                                       copyItems:YES] ;
        _windowUsingToolbar    = nil ;

        self.allowsUserCustomization = original.allowsUserCustomization ;
        self.allowsExtensionItems    = original.allowsExtensionItems ;
        self.autosavesConfiguration  = original.autosavesConfiguration ;
        self.delegate                = self ;
    }
    return self ;
}

- (void)performCallback:(id)sender{
    NSToolbarItem *item = sender;
    NSNumber *theFnRef = [_fnRefDictionary objectForKey:[item itemIdentifier]] ;
    int itemFnRef = theFnRef ? [theFnRef intValue] : LUA_NOREF ;
    int fnRef = (itemFnRef != LUA_NOREF) ? itemFnRef : _callbackRef ;
    if (fnRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            [skin pushLuaRef:refTable ref:fnRef] ;
            if (_windowUsingToolbar) {
                if ([_windowUsingToolbar isEqualTo:[[MJConsoleWindowController singleton] window]]) {
                    lua_pushstring(L, "console") ;
                } else if ([_windowUsingToolbar isKindOfClass:NSClassFromString(@"HSWebViewWindow")]) {
                    [skin pushNSObject:_windowUsingToolbar] ;
                } else {
                    lua_pushstring(L, "** unknown") ;
                }
            } else {
                // shouldn't be possible, but just in case...
                lua_pushstring(L, "** no window attached") ;
            }
            [skin pushNSObject:item] ;
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s: item callback error, %s",
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

- (BOOL)isAttachedToWindow {
    BOOL attached = _windowUsingToolbar && [self isEqualTo:[_windowUsingToolbar toolbar]] ;
    if (!attached) _windowUsingToolbar = nil ; // just to keep it correct
    return attached ;
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
// let the delegate handle this when creating the item
//         [toolbarItem setTarget:self] ;
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

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier
                                            willBeInsertedIntoToolbar:(BOOL)flag {
    NSToolbarItem *item = [[_itemDictionary objectForKey:itemIdentifier] copy] ;
    if (flag) {
        item.target = toolbar ;
    } else {
        item.enabled = YES ;
    }
    return item ;
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

- (void)toolbarWillAddItem:(NSNotification *)notification {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            [skin pushLuaRef:refTable ref:_callbackRef] ;
            lua_pushstring(L, "add") ;
            [skin pushNSObject:[[notification userInfo] objectForKey:@"item"]];
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s: toolbar callback error, %s",
                                                          USERDATA_TAG,
                                                          lua_tostring(L, -1)]] ;
                lua_pop(L, 1) ;
            }
        }) ;
    }
}

- (void)toolbarDidRemoveItem:(NSNotification *)notification {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            [skin pushLuaRef:refTable ref:_callbackRef] ;
            lua_pushstring(L, "remove") ;
            [skin pushNSObject:[[notification userInfo] objectForKey:@"item"]];
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s: toolbar callback error, %s",
                                                          USERDATA_TAG,
                                                          lua_tostring(L, -1)]] ;
                lua_pop(L, 1) ;
            }
        }) ;
    }
}

@end

#pragma mark - Module Functions

static int newHSToolbar(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TTABLE, LS_TBREAK] ;
    NSString *identifier = [skin toNSObjectAtIndex:1] ;

    if (![identifiersInUse containsObject:identifier]) {
        HSToolbar *toolbar = [[HSToolbar alloc] initWithIdentifier:identifier
                                                itemTableIndex:2] ;
        if (toolbar) {
            [skin pushNSObject:toolbar] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        return luaL_argerror(L, 1, "identifier already in use") ;
    }
    return 1 ;
}

static int attachToolbar(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSWindow *theWindow ;
    int toolbarIdx = 2 ;
    if (lua_gettop(L) == 1) {
        theWindow = [[MJConsoleWindowController singleton] window];
        toolbarIdx = 1 ;
        if (lua_type(L, 1) != LUA_TNIL) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
        }
    } else if (luaL_testudata(L, 1, "hs.webview")) {
        theWindow = get_objectFromUserdata(__bridge NSWindow, L, 1, "hs.webview") ;
        if (lua_type(L, 2) != LUA_TNIL) {
            [skin checkArgs:LS_TUSERDATA, "hs.webview", LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
        } else {
            [skin checkArgs:LS_TUSERDATA, "hs.webview", LS_TNIL, LS_TBREAK] ;
        }
    } else {
        return luaL_error(L, "toolbar can only be attached to the console or a webview") ;
    }
    HSToolbar *oldToolbar = (HSToolbar *)theWindow.toolbar ;
    HSToolbar *newToolbar = (lua_type(L, toolbarIdx) == LUA_TNIL) ? nil : [skin toNSObjectAtIndex:toolbarIdx] ;
    if (oldToolbar) {
        [oldToolbar setVisible:NO] ;
        [theWindow setToolbar:nil] ;
        if ([oldToolbar isKindOfClass:[HSToolbar class]]) oldToolbar.windowUsingToolbar = nil ;
    }
    if (newToolbar) {
        if (newToolbar.windowUsingToolbar) [newToolbar.windowUsingToolbar setToolbar:nil] ;
        [theWindow setToolbar:newToolbar] ;
        newToolbar.windowUsingToolbar = theWindow ;
    }
//     [skin logWarn:[NSString stringWithFormat:@"%@ %@ %@", oldToolbar, newToolbar, theWindow]] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Methods

static int isAttachedToWindow(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, [toolbar isAttachedToWindow]) ;
    return 1;
}

static int copyToolbar(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSToolbar *oldToolbar = [skin toNSObjectAtIndex:1] ;
    HSToolbar *newToolbar = [[HSToolbar alloc] initWithCopy:oldToolbar] ;
    if (newToolbar) {
        [skin pushNSObject:newToolbar] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

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

static int insertItemAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TNUMBER, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    NSString  *identifier = [skin toNSObjectAtIndex:2] ;
    NSInteger index = luaL_checkinteger(L, 3) ;

    if ((index < 1) || (index > (NSInteger)([[toolbar items] count] + 1))) {
        return luaL_error(L, "index out of bounds") ;
    }
    [toolbar insertItemWithItemIdentifier:identifier atIndex:(index - 1)] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int removeItemAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    NSInteger index = luaL_checkinteger(L, 2) ;

    if ((index < 1) || (index > (NSInteger)([[toolbar items] count] + 1))) {
        return luaL_error(L, "index out of bounds") ;
    }
    [toolbar removeItemAtIndex:(index - 1)] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int sizeMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        NSString *size = [skin toNSObjectAtIndex:2] ;
        if ([size isEqualToString:@"default"]) {
            [toolbar setSizeMode:NSToolbarSizeModeDefault] ;
        } else if ([size isEqualToString:@"regular"]) {
            [toolbar setSizeMode:NSToolbarSizeModeRegular] ;
        } else if ([size isEqualToString:@"small"]) {
            [toolbar setSizeMode:NSToolbarSizeModeSmall] ;
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"invalid sizeMode:%@", size] UTF8String]) ;
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
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        NSString *type = [skin toNSObjectAtIndex:2] ;
        if ([type isEqualToString:@"default"]) {
            [toolbar setDisplayMode:NSToolbarDisplayModeDefault] ;
        } else if ([type isEqualToString:@"label"]) {
            [toolbar setDisplayMode:NSToolbarDisplayModeLabelOnly] ;
        } else if ([type isEqualToString:@"icon"]) {
            [toolbar setDisplayMode:NSToolbarDisplayModeIconOnly] ;
        } else if ([type isEqualToString:@"both"]) {
            [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel] ;
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"invalid displayMode:%@", type] UTF8String]) ;
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
    NSToolbarItem *activeItem ;
    NSToolbarItem *storedItem = [toolbar.itemDictionary objectForKey:identifier] ;
    for (NSToolbarItem *check in [toolbar items]) {
        if ([identifier isEqualToString:[check itemIdentifier]]) {
            activeItem = check ;
            break ;
        }
    }
    if ((![builtinToolbarItems containsObject:identifier]) && storedItem) {
        if (lua_getfield(L, 2, "label") == LUA_TSTRING) {
            [storedItem setLabel:[skin toNSObjectAtIndex:-1]] ;
            if (activeItem) [activeItem setLabel:[skin toNSObjectAtIndex:-1]] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, 2, "paletteLabel") == LUA_TSTRING) {
            [storedItem setPaletteLabel:[skin toNSObjectAtIndex:-1]] ;
            if (activeItem) [activeItem setPaletteLabel:[skin toNSObjectAtIndex:-1]] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, 2, "tooltip") == LUA_TSTRING) {
            [storedItem setToolTip:[skin toNSObjectAtIndex:-1]] ;
            if (activeItem) [activeItem setToolTip:[skin toNSObjectAtIndex:-1]] ;
        }
        lua_pop(L, 1) ;
        if ((lua_getfield(L, 2, "image") == LUA_TUSERDATA) && luaL_checkudata(L, -1, "hs.image")) {
            [storedItem setImage:[skin toNSObjectAtIndex:-1]] ;
            if (activeItem) [activeItem setImage:[skin toNSObjectAtIndex:-1]] ;
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
            [storedItem setVisibilityPriority:lua_tointeger(L, -1)] ;
            if (activeItem) [activeItem setVisibilityPriority:lua_tointeger(L, -1)] ;
        }
        lua_pop(L, 1) ;
        if ((lua_getfield(L, 2, "tag") == LUA_TNUMBER) && lua_isinteger(L, -1)) {
            [storedItem setTag:lua_tointeger(L, -1)] ;
            if (activeItem) [activeItem setTag:lua_tointeger(L, -1)] ;
        }
        lua_pop(L, 1) ;

    } else {
        return luaL_error(L, "id does not match a user defined toolbar item") ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int detailsForItemIdentifier(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    NSString *identifier = [skin toNSObjectAtIndex:2] ;
    NSToolbarItem *ourItem ;
    for (NSToolbarItem *item in [toolbar items]) {
        if ([identifier isEqualToString:[item itemIdentifier]]) {
            ourItem = item ;
            break ;
        }
    }
    if (!ourItem) ourItem = [toolbar.itemDictionary objectForKey:identifier] ;
    [skin pushNSObject:ourItem] ;
    return 1 ;
}

static int allowedToolbarItems(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:toolbar.allowedIdentifiers] ;
    return 1 ;
}

static int toolbarItems(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    lua_newtable(L) ;
    for (NSToolbarItem *item in [toolbar items]) {
        [skin pushNSObject:[item itemIdentifier]] ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    return 1 ;
}

static int visibleToolbarItems(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    lua_newtable(L) ;
    for (NSToolbarItem *item in [toolbar visibleItems]) {
        [skin pushNSObject:[item itemIdentifier]] ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    return 1 ;
}

static int selectedToolbarItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        NSString *identifier = nil ;
        if (lua_type(L, 2) == LUA_TSTRING) identifier = [skin toNSObjectAtIndex:2] ;
        [toolbar setSelectedItemIdentifier:identifier] ;
        lua_pushvalue(L, 1) ;
    } else {
        [skin pushNSObject:[toolbar selectedItemIdentifier]] ;
    }
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
    [skin pushNSObject:[toolbar items]] ;               lua_setfield(L, -2, "toolbarItems") ;
    [skin pushNSObject:toolbar.delegate] ;              lua_setfield(L, -2, "delegate") ;

    if (toolbar.windowUsingToolbar) {
        [skin pushNSObject:toolbar.windowUsingToolbar withOptions:LS_NSDescribeUnknownTypes] ;
        lua_setfield(L, -2, "windowUsingToolbar") ;
        lua_pushboolean(L, [[toolbar.windowUsingToolbar toolbar] isEqualTo:toolbar]) ;
        lua_setfield(L, -2, "windowUsingToolbarIsAttached") ;
    }
    return 1 ;
}

#pragma mark - Module Constants

static int systemToolbarItems(__unused lua_State *L) {
    [[LuaSkin shared] pushNSObject:builtinToolbarItems] ;
    return 1 ;
}

static int toolbarItemPriorities(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSToolbarItemVisibilityPriorityStandard) ; lua_setfield(L, -2, "standard") ;
    lua_pushinteger(L, NSToolbarItemVisibilityPriorityLow) ;      lua_setfield(L, -2, "low") ;
    lua_pushinteger(L, NSToolbarItemVisibilityPriorityHigh) ;     lua_setfield(L, -2, "high") ;
    lua_pushinteger(L, NSToolbarItemVisibilityPriorityUser) ;     lua_setfield(L, -2, "user") ;
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
        [identifiersInUse addObject:[value identifier]] ;
    }

    [skin pushLuaRef:refTable ref:value.selfRef] ;
    return 1;
}

static id toHSToolbarFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSToolbar *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSToolbar, L, idx, USERDATA_TAG) ;
        // since this function is called every time a toolbar function/method is called, we
        // can keep the window reference valid by checking here...
        [value isAttachedToWindow] ;
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
//     [skin pushNSObject:[value target]];              lua_setfield(L, -2, "target") ;
//     [skin pushNSObject:NSStringFromSelector([value action])] ;
//     lua_setfield(L, -2, "action") ;
//     [skin pushNSObject:[value menuFormRepresentation]] ;
//     lua_setfield(L, -2, "menuFormRepresentation") ;
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
    HSToolbar *obj = get_objectFromUserdata(__bridge_transfer HSToolbar, L, 1, USERDATA_TAG) ;
    if (obj) {
        for (NSNumber *fnRef in [obj.fnRefDictionary allValues]) [skin luaUnref:refTable ref:[fnRef intValue]] ;

        if (obj.windowUsingToolbar && [[obj.windowUsingToolbar toolbar] isEqualTo:obj])
            [obj.windowUsingToolbar setToolbar:nil] ;

        obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef];
        obj.selfRef = [skin luaUnref:refTable ref:obj.selfRef] ;
        obj.delegate = nil ;
        // they should be properly balanced, but lets check just in case...
        NSUInteger identifierIndex = [identifiersInUse indexOfObject:[obj identifier]] ;
        if (identifierIndex != NSNotFound) [identifiersInUse removeObjectAtIndex:identifierIndex] ;
        obj = nil ;
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(__unused lua_State* L) {
    [identifiersInUse removeAllObjects] ;
    identifiersInUse = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"delete",          userdata_gc},
    {"copyToolbar",     copyToolbar},
    {"isAttached",      isAttachedToWindow},
    {"savedSettings",   configurationDictionary},

    {"identifier",      toolbarIdentifier},
    {"setCallback",     setCallback},
    {"displayMode",     displayMode},
    {"sizeMode",        sizeMode},
    {"visible",         visible},
    {"autosaves",       toolbarCanAutosave},
    {"separator",       showsBaselineSeparator},

    {"modifyItem",      modifyToolbarItem},
    {"insertItem",      insertItemAtIndex},
    {"removeItem",      removeItemAtIndex},

    {"items",           toolbarItems},
    {"visibleItems",    visibleToolbarItems},
    {"selectedItem",    selectedToolbarItem},
    {"allowedItems",    allowedToolbarItems},
    {"itemDetails",     detailsForItemIdentifier},

    {"customizePanel",  customizeToolbar},
    {"isCustomizing",   toolbarIsCustomizing},
    {"canCustomize",    toolbarCanCustomize},

    {"infoDump",        infoDump},

    {"__tostring",      userdata_tostring},
    {"__eq",            userdata_eq},
    {"__gc",            userdata_gc},
    {NULL,              NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",           newHSToolbar},
    {"attachToolbar", attachToolbar},
    {NULL,            NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs__asm_toolbar_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    builtinToolbarItems = @[
                              NSToolbarSpaceItemIdentifier,
                              NSToolbarFlexibleSpaceItemIdentifier,
//                               NSToolbarShowColorsItemIdentifier,       // require additional support
//                               NSToolbarShowFontsItemIdentifier,        // require additional support
//                               NSToolbarPrintItemIdentifier,            // require additional support
//                               NSToolbarSeparatorItemIdentifier,        // deprecated
//                               NSToolbarCustomizeToolbarItemIdentifier, // deprecated
                          ] ;

    identifiersInUse = [[NSMutableArray alloc] init] ;

    systemToolbarItems(L) ;    lua_setfield(L, -2, "systemToolbarItems") ;
    toolbarItemPriorities(L) ; lua_setfield(L, -2, "itemPriorities") ;

    [skin registerPushNSHelper:pushHSToolbar         forClass:"HSToolbar"];
    [skin registerLuaObjectHelper:toHSToolbarFromLua forClass:"HSToolbar" withUserdataMapping:USERDATA_TAG];
    [skin registerPushNSHelper:pushNSToolbarItem     forClass:"NSToolbarItem"];

    return 1;
}
