// TODO:
// *  size to fit when manager is not contentView of a window
// *    override fittingSize for HSASMGUITKManager
// ?    optionally recurse through subviews also sizing to fit
// +  item metatable methods to edit like tables
//    additional functions/methods to line up groups of items (a way to treat them as a group or is nesting managers sufficient for this?)
//    add replaceSubview and insert so manager metatables methods can create/replace/remove items
//    need more placement options, possible rewrite of add for additional placement/arrangement argument(s)
//      nextTo
//      above/below
//      padding
//    check into assigning a manager to itself... will likely crash (but I'm curious), so make sure to prevent it

@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.guitk.manager" ;
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSASMGUITKManager : NSView
@property int                 selfRefCount ;
@property int                 passthroughCallbackRef ;
@property NSMutableDictionary *subviewReferences ;
@property NSColor             *frameDebugColor ;
@end

@implementation HSASMGUITKManager

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect] ;
    if (self) {
        _selfRefCount           = 0 ;
        _passthroughCallbackRef = LUA_NOREF ;
        _subviewReferences      = [[NSMutableDictionary alloc] init] ;
        _frameDebugColor        = nil ;
    }
    return self ;
}

- (BOOL)isFlipped { return YES; }

// Not sure if we need this yet or not
// - (BOOL)acceptsFirstMouse:(NSEvent * __unused)theEvent {
//     return YES ;
// }

- (NSSize)fittingSize {
    NSSize fittedContentSize = NSZeroSize ;

    if ([self.subviews count] > 0) {
        __block NSPoint bottomRight = NSZeroPoint ;
        [self.subviews enumerateObjectsUsingBlock:^(NSView *view, __unused NSUInteger idx, __unused BOOL *stop) {
            NSRect frame             = view.frame ;
            NSPoint frameBottomRight = NSMakePoint(frame.origin.x + frame.size.width, frame.origin.y + frame.size.height) ;
            NSSize viewFittingSize   = view.fittingSize ;
            if (!CGSizeEqualToSize(viewFittingSize, NSZeroSize)) {
                frameBottomRight = NSMakePoint(frame.origin.x + viewFittingSize.width, frame.origin.y + viewFittingSize.height) ;
            }
            if (frameBottomRight.x > bottomRight.x) bottomRight.x = frameBottomRight.x ;
            if (frameBottomRight.y > bottomRight.y) bottomRight.y = frameBottomRight.y ;
        }] ;

        fittedContentSize = NSMakeSize(bottomRight.x, bottomRight.y) ;
    }
    return fittedContentSize ;
}

- (void)drawRect:(NSRect)dirtyRect {
    if (_frameDebugColor) {
        NSDisableScreenUpdates() ;
        NSGraphicsContext* gc = [NSGraphicsContext currentContext];
        [gc saveGraphicsState];

        [NSBezierPath setDefaultLineWidth:2.0] ;
        [_frameDebugColor setStroke] ;
        [self.subviews enumerateObjectsUsingBlock:^(NSView *view, __unused NSUInteger idx, __unused BOOL *stop) {
            [NSBezierPath strokeRect:view.frame] ;
        }] ;
        [gc restoreGraphicsState];
        NSEnableScreenUpdates() ;
    }
    [super drawRect:dirtyRect] ;
}

// perform callback for subviews which don't have a callback defined; see button.m for how to allow this chaining
- (void)preformPassthroughCallback:(NSArray *)arguments {
    if (_passthroughCallbackRef != LUA_NOREF) {
        LuaSkin *skin    = [LuaSkin shared] ;
        int     argCount = 1 ;

        [skin pushLuaRef:refTable ref:_passthroughCallbackRef] ;
        [skin pushNSObject:self] ;
        if (arguments) {
            [skin pushNSObject:arguments] ;
            argCount += 1 ;
        }
        if (![skin protectedCallAndTraceback:argCount nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:passthroughCallback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    } else {
        // allow next responder a chance since we don't have a callback set
        id nextInChain = [self nextResponder] ;
        if (nextInChain) {
            SEL passthroughCallback = NSSelectorFromString(@"preformPassthroughCallback:") ;
            if ([nextInChain respondsToSelector:passthroughCallback]) {
                [nextInChain performSelectorOnMainThread:passthroughCallback
                                              withObject:@[ self, arguments ]
                                           waitUntilDone:YES] ;
            }
        }
    }
}

- (void)didAddSubview:(NSView *)subview {
    LuaSkin   *skin = [LuaSkin shared] ;
    lua_State *L    = skin.L ;
    [skin pushNSObject:subview] ;
    if (lua_type(L, -1) == LUA_TUSERDATA) {
        // increase reference count of subview and save for later use
        _subviewReferences[@([skin luaRef:refTable])] = subview ;
    } else {
        lua_pop(L, 1) ;
        [skin logDebug:[NSString stringWithFormat:@"%s:didAddSubview - unrecognized subview added:%@", USERDATA_TAG, subview]] ;
    }
}

- (void)willRemoveSubview:(NSView *)subview {
    LuaSkin *skin = [LuaSkin shared] ;
    NSArray *references = [_subviewReferences allKeysForObject:subview] ;
    if (references.count > 0) {
        if (references.count > 1) {
            [skin logWarn:[NSString stringWithFormat:@"%s:willRemoveSubview - more then one reference to subview %@ found:%@", USERDATA_TAG, subview, references]] ;
        }
        // decrease reference count of subview
        for (NSNumber *ref in references) {
            [skin luaUnref:refTable ref:ref.intValue] ;
            _subviewReferences[ref] = nil ;
        }
    } else {
        [skin logDebug:[NSString stringWithFormat:@"%s:willRemoveSubview - unrecognized subview being removed:%@", USERDATA_TAG, subview]] ;
    }
}

@end

#pragma mark - Module Functions

static int manager_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSASMGUITKManager *manager = [[HSASMGUITKManager alloc] initWithFrame:frameRect] ;
    if (manager) {
        [skin pushNSObject:manager] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int manager_highlightFrames(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKManager *manager = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        if (manager.frameDebugColor) {
            [skin pushNSObject:manager.frameDebugColor] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (lua_type(L, 2) == LUA_TTABLE) {
            manager.frameDebugColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TNIL, LS_TBREAK] ;
            if (lua_toboolean(L, 2)) {
                manager.frameDebugColor = [NSColor keyboardFocusIndicatorColor] ;
            } else {
                manager.frameDebugColor = nil ;
            }
        }
        manager.needsDisplay = YES ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int manager_addElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TTABLE | LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKManager *manager = [skin toNSObjectAtIndex:1] ;
    NSView *item = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
    if (!item || ![item isKindOfClass:[NSView class]]) {
        return luaL_argerror(L, 2, "expected userdata representing a gui element (NSView subclass)") ;
    }
    if ([manager.subviews containsObject:item]) {
        return luaL_argerror(L, 2, "element already managed by this content manager") ;
    }
    NSPoint newOrigin ;
    if ((lua_gettop(L) == 3) && (lua_type(L, 3)) == LUA_TTABLE) {
        newOrigin = [skin tableToPointAtIndex:3] ;
        BOOL hasSize = NO ;
        CGFloat h = 0.0 ;
        CGFloat w = 0.0 ;
        if (lua_getfield(L, 3, "h") == LUA_TNUMBER) {
            hasSize = YES ;
            h = lua_tonumber(L, -1) ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, 3, "w") == LUA_TNUMBER) {
            hasSize = YES ;
            w = lua_tonumber(L, -1) ;
        }
        lua_pop(L, 1) ;
        if (hasSize) [item setFrameSize:NSMakeSize(w, h)] ;
    } else {
        NSRect lastItemFrame = manager.subviews.lastObject.frame ;
        newOrigin = NSMakePoint(lastItemFrame.origin.x, lastItemFrame.origin.y + lastItemFrame.size.height + 1) ;
        if ((lua_type(L, 3) == LUA_TBOOLEAN) && lua_toboolean(L, 3)) [item setFrameSize:[item fittingSize]] ;
    }

    [manager addSubview:item] ;
    [item setFrameOrigin:newOrigin] ;
    manager.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int manager_removeElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
    HSASMGUITKManager *manager = [skin toNSObjectAtIndex:1] ;
    NSView *item = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
    if (!item || ![item isKindOfClass:[NSView class]]) {
        return luaL_argerror(L, 2, "expected userdata representing a gui element (NSView subclass)") ;
    }
    if (![manager.subviews containsObject:item]) {
        return luaL_argerror(L, 2, "element not managed by this content manager") ;
    }
    [item removeFromSuperview] ;
    manager.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int manager_elementFittingSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
    HSASMGUITKManager *manager = [skin toNSObjectAtIndex:1] ;
    NSView *item = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
    if (!item || ![item isKindOfClass:[NSView class]]) {
        return luaL_argerror(L, 2, "expected userdata representing a gui element (NSView subclass)") ;
    }
    if (![manager.subviews containsObject:item]) {
        return luaL_argerror(L, 2, "element not managed by this content manager") ;
    }
    [skin pushNSSize:item.fittingSize] ;
    return 1 ;
}

static int manager_autosizeElements(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMGUITKManager *manager = [skin toNSObjectAtIndex:1] ;
    if (manager.subviews.count > 0) {
        [manager.subviews enumerateObjectsUsingBlock:^(NSView *view, __unused NSUInteger idx, __unused BOOL *stop) {
            NSSize viewFittingSize   = view.fittingSize ;
            if (!CGSizeEqualToSize(viewFittingSize, NSZeroSize)) [view setFrameSize:viewFittingSize] ;
        }] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int manager_sizeToFit(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKManager *manager = [skin toNSObjectAtIndex:1] ;

    CGFloat hPadding = (lua_gettop(L) > 1) ? lua_tonumber(L, 2) : 0.0 ;
    CGFloat vPadding = (lua_gettop(L) > 2) ? lua_tonumber(L, 3) : ((lua_gettop(L) > 1) ? hPadding : 0.0) ;

//     if ([manager isEqualTo:manager.window.contentView] && [manager.window isKindOfClass:NSClassFromString(@"HSASMGuiWindow")] && manager.subviews.count > 0) {
    if (manager.subviews.count > 0) {
        __block NSPoint topLeft     = manager.subviews.firstObject.frame.origin ;
        __block NSPoint bottomRight = NSZeroPoint ;
        [manager.subviews enumerateObjectsUsingBlock:^(NSView *view, __unused NSUInteger idx, __unused BOOL *stop) {
            NSRect frame = view.frame ;
            if (frame.origin.x < topLeft.x) topLeft.x = frame.origin.x ;
            if (frame.origin.y < topLeft.y) topLeft.y = frame.origin.y ;
            NSPoint frameBottomRight = NSMakePoint(frame.origin.x + frame.size.width, frame.origin.y + frame.size.height) ;
            if (frameBottomRight.x > bottomRight.x) bottomRight.x = frameBottomRight.x ;
            if (frameBottomRight.y > bottomRight.y) bottomRight.y = frameBottomRight.y ;
        }] ;
        [manager.subviews enumerateObjectsUsingBlock:^(NSView *view, __unused NSUInteger idx, __unused BOOL *stop) {
            NSRect frame = view.frame ;
            frame.origin.x = frame.origin.x + hPadding - topLeft.x ;
            frame.origin.y = frame.origin.y + vPadding - topLeft.y ;
            view.frame = frame ;
        }] ;

        NSSize oldContentSize = manager.frame.size ;
        NSSize newContentSize = NSMakeSize(2 * hPadding + bottomRight.x - topLeft.x, 2 * vPadding + bottomRight.y - topLeft.y) ;

        if (manager.window && [manager isEqualTo:manager.window.contentView]) {
            NSRect oldFrame = manager.window.frame ;
            NSSize newSize  = NSMakeSize(
                newContentSize.width  + (oldFrame.size.width - oldContentSize.width),
                newContentSize.height + (oldFrame.size.height - oldContentSize.height)
            ) ;
            NSRect newFrame = NSMakeRect
                (oldFrame.origin.x,
                oldFrame.origin.y + oldFrame.size.height - newSize.height,
                newSize.width,
                newSize.height
            ) ;
            [manager.window setFrame:newFrame display:YES animate:NO] ;
        } else {
            [manager setFrameSize:newContentSize] ;
        }
    }
    manager.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int manager_elementLocation(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TTABLE | LS_TNIL | LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKManager *manager = [skin toNSObjectAtIndex:1] ;
    NSView *item = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
    if (!item || ![item isKindOfClass:[NSView class]]) {
        return luaL_argerror(L, 2, "expected userdata representing a gui element (NSView subclass)") ;
    }
    if (![manager.subviews containsObject:item]) {
        return luaL_argerror(L, 2, "element not managed by this content manager") ;
    }
    if (lua_gettop(L) == 2) {
        [skin pushNSRect:item.frame] ;
    } else {
        NSRect newRect = item.frame ;
        if (lua_type(L, 3) == LUA_TTABLE) {
            if (lua_getfield(L, 3, "x") == LUA_TNUMBER) newRect.origin.x    = lua_tonumber(L, -1) ;
            lua_pop(L, 1) ;
            if (lua_getfield(L, 3, "y") == LUA_TNUMBER) newRect.origin.y    = lua_tonumber(L, -1) ;
            lua_pop(L, 1) ;
            if (lua_getfield(L, 3, "h") == LUA_TNUMBER) newRect.size.height = lua_tonumber(L, -1) ;
            lua_pop(L, 1) ;
            if (lua_getfield(L, 3, "w") == LUA_TNUMBER) newRect.size.width  = lua_tonumber(L, -1) ;
            lua_pop(L, 1) ;
        } else {
            newRect.size = [item fittingSize] ;
        }
        item.frame = newRect ;
        manager.needsDisplay = YES ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int manager_elements(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKManager *manager = [skin toNSObjectAtIndex:1] ;
    LS_NSConversionOptions options = (lua_gettop(L) == 1) ? LS_TNONE : (lua_toboolean(L, 2) ? LS_NSDescribeUnknownTypes : LS_TNONE) ;
    [skin pushNSObject:manager.subviews withOptions:options] ;
    return 1 ;
}

static int manager_passthroughCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSASMGUITKManager *manager = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        manager.passthroughCallbackRef = [skin luaUnref:refTable ref:manager.passthroughCallbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            manager.passthroughCallbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (manager.passthroughCallbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:manager.passthroughCallbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int manager__nextResponder(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSASMGUITKManager *manager = [skin toNSObjectAtIndex:1] ;
    if (manager.nextResponder) {
        [skin pushNSObject:manager.nextResponder] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSASMGUITKManager(lua_State *L, id obj) {
    HSASMGUITKManager *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSASMGUITKManager *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toHSASMGUITKManagerFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMGUITKManager *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSASMGUITKManager, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSASMGUITKManager *obj = [skin luaObjectAtIndex:1 toClass:"HSASMGUITKManager"] ;
    NSString *title = NSStringFromRect(obj.frame) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSASMGUITKManager *obj1 = [skin luaObjectAtIndex:1 toClass:"HSASMGUITKManager"] ;
        HSASMGUITKManager *obj2 = [skin luaObjectAtIndex:2 toClass:"HSASMGUITKManager"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSASMGUITKManager *obj = get_objectFromUserdata(__bridge_transfer HSASMGUITKManager, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin shared] ;
            obj.passthroughCallbackRef = [skin luaUnref:refTable ref:obj.passthroughCallbackRef] ;
            [obj.subviewReferences enumerateKeysAndObjectsUsingBlock:^(NSNumber *ref, NSView *view, __unused BOOL *stop) {
                [skin luaUnref:refTable ref:ref.intValue] ;
                [view removeFromSuperview] ;
            }] ;
            obj.subviewReferences = nil ;
        }
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
    {"add",                 manager_addElement},
    {"remove",              manager_removeElement},
    {"elementLocation",     manager_elementLocation},
    {"elements",            manager_elements},
    {"passthroughCallback", manager_passthroughCallback},
    {"sizeToFit",           manager_sizeToFit},
    {"elementFittingSize",  manager_elementFittingSize},
    {"autosizeElements",    manager_autosizeElements},

    {"_debugFrames",        manager_highlightFrames},
    {"_nextResponder",      manager__nextResponder},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", manager_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_guitk_manager_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSASMGUITKManager         forClass:"HSASMGUITKManager"];
    [skin registerLuaObjectHelper:toHSASMGUITKManagerFromLua forClass:"HSASMGUITKManager"
                                                  withUserdataMapping:USERDATA_TAG];

    return 1;
}
