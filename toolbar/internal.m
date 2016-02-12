// TODO
//    Documentation

@import Cocoa ;
@import LuaSkin ;

#define USERDATA_TAG  "hs._asm.toolbar"
static int            refTable = LUA_NOREF;
static NSArray        *builtinToolbarItems, *automaticallyIncluded ;
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
@property (readonly) NSMutableDictionary *groupings ;
@property (weak)     NSWindow            *windowUsingToolbar ;
@property            BOOL                notifyToolbarChanges ;
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
        _groupings             = [[NSMutableDictionary alloc] init] ;
        _windowUsingToolbar    = nil ;
        _notifyToolbarChanges  = NO ;

        [_allowedIdentifiers addObjectsFromArray:automaticallyIncluded] ;

        LuaSkin     *skin      = [LuaSkin shared] ;
        lua_State   *L         = [skin L] ;
        lua_Integer count      = luaL_len(L, idx) ;
        lua_Integer index      = 0 ;
        BOOL        isGood     = YES ;

        idx = lua_absindex(L, idx) ;
        while (isGood && (index < count)) {
            if (lua_rawgeti(L, idx, index + 1) == LUA_TTABLE) {
                if (luaL_len(L, -1) > 0)
                    isGood = [self addToolbarItemGroupAtIndex:-1] ;
                else
                    isGood = [self addToolbarItemAtIndex:-1 asPrimaryItem:YES] ;
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

- (void)modifyToolbarItem:(NSToolbarItem *)item fromTableAtIndex:(int)idx thatIsNew:(BOOL)newItem {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_State *L = [skin L] ;
    idx = lua_absindex(L, idx) ;
    NSString *identifier = [item itemIdentifier] ;

    if (lua_getfield(L, idx, "label") == LUA_TSTRING) {
// for grouped sets, the palette label *must* be set or unset in sync with label, otherwise it only
// shows some of the individual labels... so simpler to just forget that there are actually two labels.
// very few will likely care/notice anyways.
        [item setLabel:[skin toNSObjectAtIndex:-1]] ;
        [item setPaletteLabel:[skin toNSObjectAtIndex:-1]] ;
    } else if ((lua_type(L, -1) == LUA_TBOOLEAN) && !lua_toboolean(L, -1)
                                                 && [item isKindOfClass:[NSToolbarItemGroup class]]) {
// this is the only way to switch a grouped set's individual labels back on after turning them off by
// setting a group label...
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
        [(NSToolbarItemGroup *)item setLabel:nil] ;
        [(NSToolbarItemGroup *)item setPaletteLabel:nil] ;
#pragma clang diagnostic pop
    } else if (newItem && ![item isKindOfClass:[NSToolbarItemGroup class]]) {
        [item setLabel:identifier] ;
        [item setPaletteLabel:identifier] ;
    }
    lua_pop(L, 1) ;
    if (lua_getfield(L, idx, "tooltip") == LUA_TSTRING) {
        [item setToolTip:[skin toNSObjectAtIndex:-1]] ;
    } else if ((lua_type(L, -1) == LUA_TBOOLEAN) && !lua_toboolean(L, -1)) {
        [item setToolTip:nil] ;
    }
    lua_pop(L, 1) ;
    if ((lua_getfield(L, idx, "priority") == LUA_TNUMBER) && lua_isinteger(L, -1)) {
        [item setVisibilityPriority:lua_tointeger(L, -1)] ;
    }
    lua_pop(L, 1) ;
    if ((lua_getfield(L, idx, "tag") == LUA_TNUMBER) && lua_isinteger(L, -1)) {
        [item setTag:lua_tointeger(L, -1)] ;
    }
    lua_pop(L, 1) ;

    if ((lua_getfield(L, idx, "image") == LUA_TUSERDATA) && luaL_checkudata(L, -1, "hs.image")) {
        [item setImage:[skin toNSObjectAtIndex:-1]] ;
    } else if ((lua_type(L, -1) == LUA_TBOOLEAN) && !lua_toboolean(L, -1)) {
        [item setImage:nil] ;
    } else if (newItem && ![item isKindOfClass:[NSToolbarItemGroup class]]) {
        [item setImage:[NSImage imageNamed:NSImageNameStatusNone]] ;
    }
    lua_pop(L, 1) ;

    // These should only be adjusted during creation or when changing the itemDictionary version
    if ((newItem || [item isEqualTo:[_itemDictionary objectForKey:identifier]])
                            && ![item isKindOfClass:[NSToolbarItemGroup class]]) {
        if (lua_getfield(L, idx, "enabled") == LUA_TBOOLEAN) {
            [_enabledDictionary setObject:@((BOOL)lua_toboolean(L, -1)) forKey:identifier] ;
        } else if (newItem) {
            [_enabledDictionary setObject:@(YES) forKey:identifier] ;
        }
        lua_pop(L, 1) ;
        if ((lua_getfield(L, idx, "fn") == LUA_TFUNCTION) || (lua_isboolean(L, -1) && !lua_toboolean(L, -1))) {
            if ([[_fnRefDictionary objectForKey:identifier] intValue] != LUA_NOREF) {
                [_fnRefDictionary setObject:@([skin luaUnref:refTable
                                                         ref:[[_fnRefDictionary objectForKey:identifier] intValue]])
                                     forKey:identifier] ;
            }
            if (lua_type(L, -1) == LUA_TFUNCTION) {
                lua_pushvalue(L, -1) ;
                [_fnRefDictionary setObject:@([skin luaRef:refTable]) forKey:identifier] ;
            }
        }
        lua_pop(L, 1) ;
    }
    // default and selectable are handled separately
}

- (BOOL)addToolbarItemGroupAtIndex:(int)idx {
    LuaSkin   *skin      = [LuaSkin shared] ;
    lua_State *L         = [skin L] ;
    idx = lua_absindex(L, idx) ;

    NSString *identifier ;
    if (lua_getfield(L, -1, "id") == LUA_TSTRING) identifier = [skin toNSObjectAtIndex:-1] ;
    lua_pop(L, 1) ;

    if (!identifier) {
        [skin  logWarn:[NSString stringWithFormat:@"%s:id must be present, and it must be a string",
                                                   USERDATA_TAG]] ;
        return NO ;
    } else if ([_itemDictionary objectForKey:identifier]) {
        [skin  logWarn:[NSString stringWithFormat:@"%s:id must be unique or a system defined item",
                                                   USERDATA_TAG]] ;
        return NO ;
    } else if ([builtinToolbarItems containsObject:identifier]) {
        [skin  logWarn:[NSString stringWithFormat:@"%s:group id cannot be a system defined item id",
                                                   USERDATA_TAG]] ;
        return NO ;
    }

    NSToolbarItemGroup *groupItem = [[NSToolbarItemGroup alloc] initWithItemIdentifier:identifier] ;
    [self modifyToolbarItem:groupItem fromTableAtIndex:idx thatIsNew:YES] ;

    NSMutableArray *subItems = [[NSMutableArray alloc] init] ;
    lua_Integer count      = luaL_len(L, idx) ;
    lua_Integer index      = 0 ;
    BOOL        isGood     = YES ;
    while (isGood && (index < count)) {
        if (lua_rawgeti(L, idx, index + 1) == LUA_TTABLE) {
            isGood = [self addToolbarItemAtIndex:-1 asPrimaryItem:NO] ;
            if (isGood) {
                lua_getfield(L, -1, "id") ;
                [subItems addObject:[skin toNSObjectAtIndex:-1]] ;
                lua_pop(L, 1) ;
            }
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:not table at index %lld; ignoring grouped item for toolbar %@",
                                                      USERDATA_TAG, index + 1, identifier]] ;
        }
        lua_pop(L, 1) ;
        index++ ;
    }
    if (!isGood) return NO ;
    [_groupings setObject:subItems forKey:identifier] ;

    [_itemDictionary setObject:groupItem forKey:identifier] ;
    if (![_allowedIdentifiers containsObject:identifier]) [_allowedIdentifiers addObject:identifier] ;

    BOOL included   = (lua_getfield(L, idx, "default") == LUA_TBOOLEAN) ? (BOOL)lua_toboolean(L, -1) : YES ;
    BOOL selectable = (lua_getfield(L, idx, "selectable") == LUA_TBOOLEAN) ? (BOOL)lua_toboolean(L, -1) : NO ;
    lua_pop(L, 2) ;

    if (selectable) [_selectableIdentifiers addObject:identifier] ;
    if (included)   [_defaultIdentifiers addObject:identifier] ;

    return YES ;
}

- (BOOL)addToolbarItemAtIndex:(int)idx asPrimaryItem:(BOOL)isPrimary {
    LuaSkin   *skin      = [LuaSkin shared] ;
    lua_State *L         = [skin L] ;
    idx = lua_absindex(L, idx) ;

    NSString *identifier ;
    if (lua_getfield(L, -1, "id") == LUA_TSTRING) identifier = [skin toNSObjectAtIndex:-1] ;
    lua_pop(L, 1) ;

    if (!identifier) {
        [skin  logWarn:[NSString stringWithFormat:@"%s:id must be present, and it must be a string",
                                                   USERDATA_TAG]] ;
        return NO ;
    } else if ([_itemDictionary objectForKey:identifier]) {
        [skin  logWarn:[NSString stringWithFormat:@"%s:id must be unique or a system defined item",
                                                   USERDATA_TAG]] ;
        return NO ;
    }

    BOOL included   = (lua_getfield(L, idx, "default") == LUA_TBOOLEAN) ?
                                             (BOOL)lua_toboolean(L, -1) : (isPrimary ? YES : NO) ;
    BOOL selectable = (lua_getfield(L, idx, "selectable") == LUA_TBOOLEAN) ? (BOOL)lua_toboolean(L, -1) : NO ;
    lua_pop(L, 2) ;

    if (![builtinToolbarItems containsObject:identifier]) {
        NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier] ;
        [self modifyToolbarItem:toolbarItem fromTableAtIndex:idx thatIsNew:YES] ;

        [toolbarItem setAction:@selector(performCallback:)] ;

        [_itemDictionary setObject:toolbarItem forKey:identifier] ;
        if (selectable) [_selectableIdentifiers addObject:identifier] ;
    }
    // by adjusting _allowedIdentifiers out here, we allow builtin items, even if we don't exactly
    // advertise them, plus we may add support for duplicate id's at some point if someone comes up with
    // a reason...
    if (![_allowedIdentifiers containsObject:identifier] && isPrimary) [_allowedIdentifiers addObject:identifier] ;
    if (included) [_defaultIdentifiers addObject:identifier] ;

    return YES ;
}

#pragma mark - NSToolbarDelegate stuff

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier
                                            willBeInsertedIntoToolbar:(BOOL)flag {
    if ([_groupings objectForKey:itemIdentifier]) {
        NSToolbarItemGroup *item = [[_itemDictionary objectForKey:itemIdentifier] copy] ;
        item.enabled = YES ;
        NSMutableArray *subItems = [[NSMutableArray alloc] init] ;
        for (NSString *theId in [_groupings objectForKey:itemIdentifier]) {
            NSToolbarItem *newItem = [[_itemDictionary objectForKey:theId] copy] ;
            newItem.enabled = YES ;
            if (flag) {
                newItem.target = toolbar ;
            }
            [subItems addObject:newItem] ;
        }
        [item setSubitems:subItems] ;
        // NSToolbarItemGroup is dumb...
        // see http://stackoverflow.com/questions/15949835/nstoolbaritemgroup-doesnt-work
        NSSize minSize = NSZeroSize;
        NSSize maxSize = NSZeroSize;
        for (NSToolbarItem* tmpItem in item.subitems)
        {
            minSize.width += tmpItem.minSize.width;
            minSize.height = MAX(minSize.height, tmpItem.minSize.height);
            maxSize.width += tmpItem.maxSize.width;
            maxSize.height = MAX(maxSize.height, tmpItem.maxSize.height);
        }
        item.minSize = minSize;
        item.maxSize = maxSize;

        return item ;
    } else {
        NSToolbarItem *item = [[_itemDictionary objectForKey:itemIdentifier] copy] ;
        item.enabled = YES ;
        if (flag) {
            item.target = toolbar ;
        }
        return item ;
    }
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
    if (_notifyToolbarChanges && (_callbackRef != LUA_NOREF)) {
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
    if (_notifyToolbarChanges && (_callbackRef != LUA_NOREF)) {
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
        [newToolbar setVisible:YES] ;
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

static int notifyWhenToolbarChanges(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) != 1) {
        toolbar.notifyToolbarChanges = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, toolbar.notifyToolbarChanges) ;
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
        [toolbar modifyToolbarItem:storedItem fromTableAtIndex:2 thatIsNew:NO] ;
        if (activeItem) [toolbar modifyToolbarItem:activeItem fromTableAtIndex:2 thatIsNew:NO] ;
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
    [[LuaSkin shared] pushNSObject:automaticallyIncluded] ;
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
//     [skin pushNSObject:[value paletteLabel]] ;       lua_setfield(L, -2, "paletteLabel") ;
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
    if ([obj isKindOfClass:[NSToolbarItemGroup class]]) {
        [skin pushNSObject:[obj subitems]] ; lua_setfield(L, -2, "subitems") ;
    }
//     [skin pushNSSize:[value minSize]] ;              lua_setfield(L, -2, "minSize") ;
//     [skin pushNSSize:[value maxSize]] ;              lua_setfield(L, -2, "maxSize") ;

//     [skin pushNSObject:[value target]];              lua_setfield(L, -2, "target") ;
//     [skin pushNSObject:NSStringFromSelector([value action])] ;
//     lua_setfield(L, -2, "action") ;
//     [skin pushNSObject:[value menuFormRepresentation] withOptions:LS_NSDescribeUnknownTypes] ;
//     lua_setfield(L, -2, "menuFormRepresentation") ;
//     [skin pushNSObject:[value view] withOptions:LS_NSDescribeUnknownTypes] ;
//     lua_setfield(L, -2, "view") ;
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

    {"notifyOnChange",  notifyWhenToolbarChanges},
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
                              NSToolbarShowColorsItemIdentifier,       // require additional support
                              NSToolbarShowFontsItemIdentifier,        // require additional support
                              NSToolbarPrintItemIdentifier,            // require additional support
                              NSToolbarSeparatorItemIdentifier,        // deprecated
                              NSToolbarCustomizeToolbarItemIdentifier, // deprecated
                          ] ;
    automaticallyIncluded = @[
                                NSToolbarSpaceItemIdentifier,
                                NSToolbarFlexibleSpaceItemIdentifier,
                            ] ;

    identifiersInUse = [[NSMutableArray alloc] init] ;

    systemToolbarItems(L) ;    lua_setfield(L, -2, "systemToolbarItems") ;
    toolbarItemPriorities(L) ; lua_setfield(L, -2, "itemPriorities") ;

    [skin registerPushNSHelper:pushHSToolbar         forClass:"HSToolbar"];
    [skin registerLuaObjectHelper:toHSToolbarFromLua forClass:"HSToolbar" withUserdataMapping:USERDATA_TAG];
    [skin registerPushNSHelper:pushNSToolbarItem     forClass:"NSToolbarItem"];

    return 1;
}
