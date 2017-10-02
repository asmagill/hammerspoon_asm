@import Cocoa ;
@import LuaSkin ;

// NOTE: Should only contain methods which can be applied to all NSView based elements (i.e. all of them)
//
//       These will be made available to any element which sets _inheritView in its luaopen_* function,
//       so enything which should be kept to a subset of such elements should be coded in the relevant element
//       files and not here.
//
//       If an element file already defines a method that is named here, the existing method will be used for
//       that element -- it will not be replaced by the common method.

static const char * const USERDATA_TAG = "hs._asm.guitk.element._view" ;

static NSDictionary *VIEW_FOCUSRINGTYPE ;

static void defineInternalDictionaryies() {
    VIEW_FOCUSRINGTYPE = @{
        @"default"  : @(NSFocusRingTypeDefault),
        @"none"     : @(NSFocusRingTypeNone),
        @"exterior" : @(NSFocusRingTypeExterior),
    } ;
}

#pragma mark - Common NSView Methods

static int view__nextResponder(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_type(L, 1) != LUA_TUSERDATA) {
        return luaL_error(L, "ERROR: incorrect type '%s' for argument 1 (expected userdata)", lua_typename(L, lua_type(L, 1))) ;
    }
    NSView *view = [skin toNSObjectAtIndex:1] ;
    if (view.nextResponder) {
        [skin pushNSObject:view.nextResponder] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int view_toolTip(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_type(L, 1) != LUA_TUSERDATA) {
        return luaL_error(L, "ERROR: incorrect type '%s' for argument 1 (expected userdata)", lua_typename(L, lua_type(L, 1))) ;
    }
    NSView *view = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:view.toolTip] ;
    } else {
        if (lua_type(L, 2) != LUA_TSTRING) {
            view.toolTip = nil ;
        } else {
            view.toolTip = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int view_frameCenterRotation(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_type(L, 1) != LUA_TUSERDATA) {
        return luaL_error(L, "ERROR: incorrect type '%s' for argument 1 (expected userdata)", lua_typename(L, lua_type(L, 1))) ;
    }
    NSView *view = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, view.frameCenterRotation) ;
    } else {
        view.frameCenterRotation = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int view_hidden(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_type(L, 1) != LUA_TUSERDATA) {
        return luaL_error(L, "ERROR: incorrect type '%s' for argument 1 (expected userdata)", lua_typename(L, lua_type(L, 1))) ;
    }
    NSView *view = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, view.hidden) ;
    } else if (lua_type(L, 2) == LUA_TNIL) {
        lua_pushboolean(L, view.hiddenOrHasHiddenAncestor) ;
    } else {
        view.hidden = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int view_alphaValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_type(L, 1) != LUA_TUSERDATA) {
        return luaL_error(L, "ERROR: incorrect type '%s' for argument 1 (expected userdata)", lua_typename(L, lua_type(L, 1))) ;
    }
    NSView *view = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, view.alphaValue) ;
    } else {
        CGFloat newAlpha = luaL_checknumber(L, 2);
        view.alphaValue = ((newAlpha < 0.0) ? 0.0 : ((newAlpha > 1.0) ? 1.0 : newAlpha)) ;
        lua_pushvalue(L, 1);
    }
    return 1 ;
}

static int view_focusRingType(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_type(L, 1) != LUA_TUSERDATA) {
        return luaL_error(L, "ERROR: incorrect type '%s' for argument 1 (expected userdata)", lua_typename(L, lua_type(L, 1))) ;
    }
    NSView *view = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *focusRingType = VIEW_FOCUSRINGTYPE[key] ;
        if (focusRingType) {
            view.focusRingType = [focusRingType unsignedIntegerValue] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[VIEW_FOCUSRINGTYPE allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        NSNumber *focusRingType = @(view.focusRingType) ;
        NSArray *temp = [VIEW_FOCUSRINGTYPE allKeysForObject:focusRingType];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized focus ring type %@ -- notify developers", USERDATA_TAG, focusRingType]] ;
            lua_pushnil(L) ;
        }
    }
    return 1;
}

#pragma mark - Hammerspoon/Lua Infrastructure

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"tooltip",        view_toolTip},
    {"rotation",       view_frameCenterRotation},
    {"hidden",         view_hidden},
    {"alphaValue",     view_alphaValue},
    {"focusRingType",  view_focusRingType},
    {"_nextResponder", view__nextResponder},
    {NULL,             NULL}
};

int luaopen_hs__asm_guitk_element__view(lua_State* L) {
    defineInternalDictionaryies() ;

    LuaSkin *skin = [LuaSkin shared] ;
    [skin registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib

    [skin pushNSObject:@[
        @"tooltip",
        @"rotation",
        @"hidden",
        @"alphaValue",
        @"focusRingType",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;

    return 1;
}
