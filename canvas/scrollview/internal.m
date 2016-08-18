@import Cocoa ;
@import LuaSkin ;

#define USERDATA_TAG "hs._asm.canvas.scrollview"
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static int pushNSEdgeInsets(lua_State *L, NSEdgeInsets obj) ;
static NSEdgeInsets toNSEdgeInsetsFromLua(lua_State *L, int idx) ;

static void adjustTextViewForScrollbars(NSScrollView *scrollView) {
    NSTextView *textView = scrollView.documentView ;
    if (textView && [textView isKindOfClass:[NSTextView class]]) {
        NSSize contentSize = scrollView.contentSize ;
        if (!scrollView.hasHorizontalScroller && !scrollView.hasVerticalScroller) {
            [textView setVerticallyResizable:NO];
            [textView setHorizontallyResizable:NO];
            [textView setAutoresizingMask:NSViewNotSizable];
            [[textView textContainer] setContainerSize:NSMakeSize(contentSize.width, contentSize.height)];
            [[textView textContainer] setHeightTracksTextView:YES];
            [[textView textContainer] setWidthTracksTextView:YES];
        } else if (!scrollView.hasHorizontalScroller && scrollView.hasVerticalScroller) {
            [textView setVerticallyResizable:YES];
            [textView setHorizontallyResizable:NO];
            [textView setAutoresizingMask:NSViewWidthSizable];
            [[textView textContainer] setContainerSize:NSMakeSize(contentSize.width, CGFLOAT_MAX)];
            [[textView textContainer] setHeightTracksTextView:NO];
            [[textView textContainer] setWidthTracksTextView:YES];
        } else if (scrollView.hasHorizontalScroller && !scrollView.hasVerticalScroller) {
            [textView setVerticallyResizable:NO];
            [textView setHorizontallyResizable:YES];
            [textView setAutoresizingMask:NSViewHeightSizable];
            [[textView textContainer] setContainerSize:NSMakeSize(CGFLOAT_MAX, contentSize.height)];
            [[textView textContainer] setHeightTracksTextView:YES];
            [[textView textContainer] setWidthTracksTextView:NO];
        } else if (scrollView.hasHorizontalScroller && scrollView.hasVerticalScroller) {
            [textView setVerticallyResizable:YES];
            [textView setHorizontallyResizable:YES];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"
            [textView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
#pragma clang diagnostic pop
            [[textView textContainer] setContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
            [[textView textContainer] setHeightTracksTextView:NO];
            [[textView textContainer] setWidthTracksTextView:NO];
        }
    }
}

@interface ASMScrollView : NSScrollView
@end

@implementation ASMScrollView

- (instancetype)initWithFrame:(NSRect)frameRect {
    if (!(isfinite(frameRect.origin.x)    && isfinite(frameRect.origin.y) &&
          isfinite(frameRect.size.height) && isfinite(frameRect.size.width))) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:frame must be specified in finite numbers", USERDATA_TAG]];
        return nil;
    }

    self = [super initWithFrame:frameRect];
//     if (self) {
//
//     }
    return self ;
}

// - (void)setFrame:(NSRect)frameRect {
//     [super setFrame:frameRect] ;
//     self.minSize = frameRect.size ;
// }

- (BOOL)canBecomeKeyView {
    return YES ;
}

@end

#pragma mark - Module Functions

static int scrollview_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    ASMScrollView *theView = [[ASMScrollView alloc] initWithFrame:frameRect];
    [skin pushNSObject:theView] ;
    return 1 ;
}

#pragma mark - Module Methods

static int allowsMagnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, scrollView.allowsMagnification) ;
    } else {
        scrollView.allowsMagnification = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int autohidesScrollers(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, scrollView.autohidesScrollers) ;
    } else {
        scrollView.autohidesScrollers = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int automaticallyAdjustsContentInsets(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, scrollView.automaticallyAdjustsContentInsets) ;
    } else {
        scrollView.automaticallyAdjustsContentInsets = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int drawsBackground(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, scrollView.drawsBackground) ;
    } else {
        scrollView.drawsBackground = (BOOL)lua_toboolean(L, 2) ;
        scrollView.needsDisplay = YES ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int hasHorizontalRuler(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, scrollView.hasHorizontalRuler) ;
    } else {
        scrollView.hasHorizontalRuler = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int hasHorizontalScroller(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, scrollView.hasHorizontalScroller) ;
    } else {
        scrollView.hasHorizontalScroller = (BOOL)lua_toboolean(L, 2) ;
        adjustTextViewForScrollbars(scrollView) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int hasVerticalRuler(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, scrollView.hasVerticalRuler) ;
    } else {
        scrollView.hasVerticalRuler = (BOOL)lua_toboolean(L, 2) ;
        adjustTextViewForScrollbars(scrollView) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int hasVerticalScroller(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, scrollView.hasVerticalScroller) ;
    } else {
        scrollView.hasVerticalScroller = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int rulersVisible(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, scrollView.rulersVisible) ;
    } else {
        scrollView.rulersVisible = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scrollsDynamically(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, scrollView.scrollsDynamically) ;
    } else {
        scrollView.scrollsDynamically = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int usesPredominantAxisScrolling(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, scrollView.usesPredominantAxisScrolling) ;
    } else {
        scrollView.usesPredominantAxisScrolling = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int horizontalLineScroll(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, scrollView.horizontalLineScroll) ;
    } else {
        scrollView.horizontalLineScroll = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int horizontalPageScroll(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, scrollView.horizontalPageScroll) ;
    } else {
        scrollView.horizontalPageScroll = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int lineScroll(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, scrollView.lineScroll) ;
    } else {
        scrollView.lineScroll = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int magnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, scrollView.magnification) ;
    } else {
        scrollView.magnification = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int maxMagnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, scrollView.maxMagnification) ;
    } else {
        scrollView.maxMagnification = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int minMagnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, scrollView.minMagnification) ;
    } else {
        scrollView.minMagnification = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int verticalLineScroll(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, scrollView.verticalLineScroll) ;
    } else {
        scrollView.verticalLineScroll = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int verticalPageScroll(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, scrollView.verticalPageScroll) ;
    } else {
        scrollView.verticalPageScroll = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int pageScroll(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, scrollView.pageScroll) ;
    } else {
        scrollView.pageScroll = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int backgroundColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSObject:scrollView.backgroundColor] ;
    } else {
        scrollView.backgroundColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int borderType(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    NSDictionary *mapping = @{
        @"none"   : @(NSNoBorder),
        @"line"   : @(NSLineBorder),
        @"bezel"  : @(NSBezelBorder),
        @"groove" : @(NSGrooveBorder),
    } ;
    if (lua_gettop(L) == 1) {
        NSString *value = [[mapping allKeysForObject:@(scrollView.borderType)] firstObject] ;
        if (value) {
            [skin pushNSObject:value] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized borderType %@ -- notify developers", USERDATA_TAG, @(scrollView.borderType)]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSNumber *value = mapping[[skin toNSObjectAtIndex:2]] ;
        if (value) {
            scrollView.borderType = [value unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[mapping allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int horizontalScrollElasticity(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    NSDictionary *mapping = @{
          @"automatic" : @(NSScrollElasticityAutomatic),
          @"none"      : @(NSScrollElasticityNone),
          @"allowed"   : @(NSScrollElasticityAllowed),
    } ;
    if (lua_gettop(L) == 1) {
        NSString *value = [[mapping allKeysForObject:@(scrollView.horizontalScrollElasticity)] firstObject] ;
        if (value) {
            [skin pushNSObject:value] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized horizontalScrollElasticity %@ -- notify developers", USERDATA_TAG, @(scrollView.horizontalScrollElasticity)]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSNumber *value = mapping[[skin toNSObjectAtIndex:2]] ;
        if (value) {
            scrollView.horizontalScrollElasticity = [value integerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[mapping allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int verticalScrollElasticity(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    NSDictionary *mapping = @{
          @"automatic" : @(NSScrollElasticityAutomatic),
          @"none"      : @(NSScrollElasticityNone),
          @"allowed"   : @(NSScrollElasticityAllowed),
    } ;
    if (lua_gettop(L) == 1) {
        NSString *value = [[mapping allKeysForObject:@(scrollView.verticalScrollElasticity)] firstObject] ;
        if (value) {
            [skin pushNSObject:value] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized verticalScrollElasticity %@ -- notify developers", USERDATA_TAG, @(scrollView.verticalScrollElasticity)]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSNumber *value = mapping[[skin toNSObjectAtIndex:2]] ;
        if (value) {
            scrollView.verticalScrollElasticity = [value integerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[mapping allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int scrollerKnobStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    NSDictionary *mapping = @{
          @"default" : @(NSScrollerKnobStyleDefault),
          @"dark"    : @(NSScrollerKnobStyleDark),
          @"light"   : @(NSScrollerKnobStyleLight),
    } ;
    if (lua_gettop(L) == 1) {
        NSString *value = [[mapping allKeysForObject:@(scrollView.scrollerKnobStyle)] firstObject] ;
        if (value) {
            [skin pushNSObject:value] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized scrollerKnobStyle %@ -- notify developers", USERDATA_TAG, @(scrollView.scrollerKnobStyle)]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSNumber *value = mapping[[skin toNSObjectAtIndex:2]] ;
        if (value) {
            scrollView.scrollerKnobStyle = [value integerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[mapping allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int scrollerStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    NSDictionary *mapping = @{
        @"legacy"  : @(NSScrollerStyleLegacy),
        @"overlay" : @(NSScrollerStyleOverlay),
    } ;
    if (lua_gettop(L) == 1) {
        NSString *value = [[mapping allKeysForObject:@(scrollView.scrollerStyle)] firstObject] ;
        if (value) {
            [skin pushNSObject:value] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized scrollerStyle %@ -- notify developers", USERDATA_TAG, @(scrollView.scrollerStyle)]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSNumber *value = mapping[[skin toNSObjectAtIndex:2]] ;
        if (value) {
            scrollView.scrollerStyle = [value integerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[mapping allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int findBarPosition(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    NSDictionary *mapping = @{
        @"aboveRuler"   : @(NSScrollViewFindBarPositionAboveHorizontalRuler),
        @"aboveContent" : @(NSScrollViewFindBarPositionAboveContent),
        @"belowContent" : @(NSScrollViewFindBarPositionBelowContent),
    } ;
    if (lua_gettop(L) == 1) {
        NSString *value = [[mapping allKeysForObject:@(scrollView.findBarPosition)] firstObject] ;
        if (value) {
            [skin pushNSObject:value] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized findBarPosition %@ -- notify developers", USERDATA_TAG, @(scrollView.findBarPosition)]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSNumber *value = mapping[[skin toNSObjectAtIndex:2]] ;
        if (value) {
            scrollView.findBarPosition = [value integerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[mapping allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int contentInsets(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        pushNSEdgeInsets(L, scrollView.contentInsets) ;
    } else {
        scrollView.contentInsets = toNSEdgeInsetsFromLua(L, 2) ;
    }
    return 1 ;
}

static int scrollerInsets(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        pushNSEdgeInsets(L, scrollView.scrollerInsets) ;
    } else {
        scrollView.scrollerInsets = toNSEdgeInsetsFromLua(L, 2) ;
    }
    return 1 ;
}

static int documentView(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSObject:scrollView.documentView] ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
        id object = [skin toNSObjectAtIndex:2] ;
        if (object && [object isKindOfClass:[NSNull class]]) object = nil ;
        if (object && ![object isKindOfClass:[NSView class]]) {
            luaL_argerror(L, 2, "must represent an NSView subclass") ;
        }
        scrollView.documentView = object ;
        adjustTextViewForScrollbars(scrollView) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int flashScrollers(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    [scrollView flashScrollers] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int magnifyToFitRect(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    [scrollView magnifyToFitRect:[skin tableToRectAtIndex:2]] ;
    return 1 ;
}

static int setMagnificationAtPoint(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMScrollView *scrollView = [skin toNSObjectAtIndex:1] ;
    CGFloat magnification = lua_tonumber(L, 2) ;
    NSPoint point         = NSZeroPoint ;
    if (lua_gettop(L) == 2) {
        point.x = scrollView.contentSize.width / 2 ;
        point.y = scrollView.contentSize.height / 2 ;
    } else {
        point = [skin tableToPointAtIndex:3] ;
    }
    [scrollView setMagnification:magnification centeredAtPoint:point] ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMScrollView(lua_State *L, id obj) {
    ASMScrollView *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMScrollView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toASMScrollViewFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMScrollView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMScrollView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSEdgeInsets(lua_State *L, NSEdgeInsets obj) {
    lua_newtable(L) ;
    lua_pushnumber(L, obj.top) ;    lua_setfield(L, -2, "t") ;
    lua_pushnumber(L, obj.left) ;   lua_setfield(L, -2, "l") ;
    lua_pushnumber(L, obj.bottom) ; lua_setfield(L, -2, "b") ;
    lua_pushnumber(L, obj.right) ;  lua_setfield(L, -2, "r") ;
    return 1 ;
}

static NSEdgeInsets toNSEdgeInsetsFromLua(lua_State *L, int idx) {
    NSEdgeInsets edgeInsets = NSEdgeInsetsMake(0.0, 0.0, 0.0, 0.0) ;
    if (lua_getfield(L, idx, "t") == LUA_TNUMBER) edgeInsets.top = lua_tonumber(L, -1) ;
    lua_pop(L, 1) ;
    if (lua_getfield(L, idx, "l") == LUA_TNUMBER) edgeInsets.left = lua_tonumber(L, -1) ;
    lua_pop(L, 1) ;
    if (lua_getfield(L, idx, "b") == LUA_TNUMBER) edgeInsets.bottom = lua_tonumber(L, -1) ;
    lua_pop(L, 1) ;
    if (lua_getfield(L, idx, "r") == LUA_TNUMBER) edgeInsets.right = lua_tonumber(L, -1) ;
    lua_pop(L, 1) ;
    return edgeInsets ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMScrollView *obj = [skin luaObjectAtIndex:1 toClass:"ASMScrollView"] ;
    NSString *title = NSStringFromRect(obj.frame) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMScrollView *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMScrollView"] ;
        ASMScrollView *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMScrollView"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMScrollView *obj = get_objectFromUserdata(__bridge_transfer ASMScrollView, L, 1, USERDATA_TAG) ;
    if (obj) obj = nil ;
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
    {"allowsMagnification",               allowsMagnification},
    {"autohidesScrollers",                autohidesScrollers},
    {"automaticallyAdjustsContentInsets", automaticallyAdjustsContentInsets},
    {"drawsBackground",                   drawsBackground},
    {"hasHorizontalRuler",                hasHorizontalRuler},
    {"hasHorizontalScroller",             hasHorizontalScroller},
    {"hasVerticalRuler",                  hasVerticalRuler},
    {"hasVerticalScroller",               hasVerticalScroller},
    {"rulersVisible",                     rulersVisible},
    {"scrollsDynamically",                scrollsDynamically},
    {"usesPredominantAxisScrolling",      usesPredominantAxisScrolling},
    {"horizontalLineScroll",              horizontalLineScroll},
    {"horizontalPageScroll",              horizontalPageScroll},
    {"lineScroll",                        lineScroll},
    {"magnification",                     magnification},
    {"maxMagnification",                  maxMagnification},
    {"minMagnification",                  minMagnification},
    {"verticalLineScroll",                verticalLineScroll},
    {"verticalPageScroll",                verticalPageScroll},
    {"pageScroll",                        pageScroll},
    {"backgroundColor",                   backgroundColor},
    {"borderType",                        borderType},
    {"horizontalScrollElasticity",        horizontalScrollElasticity},
    {"verticalScrollElasticity",          verticalScrollElasticity},
    {"scrollerKnobStyle",                 scrollerKnobStyle},
    {"scrollerStyle",                     scrollerStyle},
    {"findBarPosition",                   findBarPosition},
    {"contentInsets",                     contentInsets},
    {"scrollerInsets",                    scrollerInsets},
    {"documentView",                      documentView},

    {"flashScrollers",                    flashScrollers},
    {"magnifyToFitRect",                  magnifyToFitRect},
    {"setMagnificationAtPoint",           setMagnificationAtPoint},

    {"__tostring",                        userdata_tostring},
    {"__eq",                              userdata_eq},
    {"__gc",                              userdata_gc},
    {NULL,                                NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", scrollview_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_canvas_scrollview_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASMScrollView         forClass:"ASMScrollView"];
    [skin registerLuaObjectHelper:toASMScrollViewFromLua forClass:"ASMScrollView"
                                             withUserdataMapping:USERDATA_TAG];

    return 1;
}
