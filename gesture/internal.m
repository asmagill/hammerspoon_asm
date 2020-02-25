@import Cocoa ;
@import LuaSkin ;

#define INCLUDE_TOUCHBARMETHODS

static const char * const USERDATA_TAG = "hs.canvas.gesture" ;

static NSArray *gestureClasses ;
static NSArray *gestureLabels ;

static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

// not doing custom gestures at present, so the delegate isn't really necessary, but just in case we add them
// in the future, it's one less thing to forget to do
@interface HSCanvasGesture : NSObject <NSGestureRecognizerDelegate>
@property int                 gestureCallbackRef ;
@property int                 selfRefCount ;
@property int                 recognizerType ;
@property NSGestureRecognizer *specificRecognizer ;
@end

@implementation HSCanvasGesture

- (instancetype)init {
    self = [super init] ;
    if (self) {
        _gestureCallbackRef = LUA_NOREF ;
        _selfRefCount       = 0 ;
        _recognizerType     = -1 ;
        _specificRecognizer = nil ;
    }
    return self ;
}

- (BOOL)assignRecognizer:(NSGestureRecognizer *)recognizer {
    BOOL __block good = NO ;
    [gestureClasses enumerateObjectsUsingBlock:^(Class kind, NSUInteger idx, BOOL *stop) {
        if ([recognizer isKindOfClass:kind]) {
            self->_recognizerType     = (int)idx ;
            self->_specificRecognizer = recognizer ;
            good                      = YES ;
            *stop                     = YES ;
        }
    }] ;
    return good ;
}

- (void)handleGesture:(NSGestureRecognizer *)gestureRecognizer {
    if (_gestureCallbackRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin shared] ;
        lua_State *L    = [skin L] ;
        if ([gestureRecognizer isKindOfClass:[NSClickGestureRecognizer class]]) {
        } else if ([gestureRecognizer isKindOfClass:[NSMagnificationGestureRecognizer class]]) {
        } else if ([gestureRecognizer isKindOfClass:[NSPanGestureRecognizer class]]) {
        } else if ([gestureRecognizer isKindOfClass:[NSPressGestureRecognizer class]]) {
        } else if ([gestureRecognizer isKindOfClass:[NSRotationGestureRecognizer class]]) {
        } else {
            [skin logError:[NSString stringWithFormat:@"%s:callback - unrecognized gesture type received:%@", USERDATA_TAG, [gestureRecognizer className]]] ;
            return ;
        }
        [skin pushLuaRef:refTable ref:_gestureCallbackRef] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:_specificRecognizer.view withOptions:LS_NSDescribeUnknownTypes] ;
        switch (_specificRecognizer.state) {
            case NSGestureRecognizerStatePossible:
                lua_pushstring(L, "possible") ;
                break ;
            case NSGestureRecognizerStateBegan:
                lua_pushstring(L, "began") ;
                break ;
            case NSGestureRecognizerStateChanged:
                lua_pushstring(L, "changed") ;
                break ;
            case NSGestureRecognizerStateEnded:
                lua_pushstring(L, "ended") ;
                break ;
            case NSGestureRecognizerStateCancelled:
                lua_pushstring(L, "cancelled") ;
                break ;
            case NSGestureRecognizerStateFailed:
                lua_pushstring(L, "failed") ;
                break ;
            default:
                [skin pushNSObject:[NSString stringWithFormat:@"** unrecognized state:%ld", _specificRecognizer.state]] ;
        }
        [skin pushNSPoint:[_specificRecognizer locationInView:_specificRecognizer.view]] ;
        if (![skin protectedCallAndTraceback:4 nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:callback - error:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
            lua_pop(L, 1) ;
        }
    }
}

@end

#pragma mark - Module Functions

static int gesture_newClickGestureRecognizer(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    HSCanvasGesture *obj = [[HSCanvasGesture alloc] init] ;
    if (obj) {
        [obj assignRecognizer:[[NSClickGestureRecognizer alloc] initWithTarget:obj action:@selector(handleGesture:)]] ;
        [skin pushNSObject:obj] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int gesture_newMagnificationGestureRecognizer(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    HSCanvasGesture *obj = [[HSCanvasGesture alloc] init] ;
    if (obj) {
        [obj assignRecognizer:[[NSMagnificationGestureRecognizer alloc] initWithTarget:obj action:@selector(handleGesture:)]] ;
        [skin pushNSObject:obj] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int gesture_newPanGestureRecognizer(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    HSCanvasGesture *obj = [[HSCanvasGesture alloc] init] ;
    if (obj) {
        [obj assignRecognizer:[[NSPanGestureRecognizer alloc] initWithTarget:obj action:@selector(handleGesture:)]] ;
        [skin pushNSObject:obj] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int gesture_newPressGestureRecognizer(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    HSCanvasGesture *obj = [[HSCanvasGesture alloc] init] ;
    if (obj) {
        [obj assignRecognizer:[[NSPressGestureRecognizer alloc] initWithTarget:obj action:@selector(handleGesture:)]] ;
        [skin pushNSObject:obj] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int gesture_newRotationGestureRecognizer(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    HSCanvasGesture *obj = [[HSCanvasGesture alloc] init] ;
    if (obj) {
        [obj assignRecognizer:[[NSRotationGestureRecognizer alloc] initWithTarget:obj action:@selector(handleGesture:)]] ;
        [skin pushNSObject:obj] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int gesture_addToCanvas(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.canvas", LS_TBREAK] ;
    HSCanvasGesture *obj = [skin toNSObjectAtIndex:1] ;
    if (obj.specificRecognizer.view) {
        return luaL_argerror(L, 1, "already attached to a canvas view") ;
    }
    NSView *canvasView = [skin toNSObjectAtIndex:2] ;
    [canvasView addGestureRecognizer:obj.specificRecognizer] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int gesture_removeFromCanvas(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasGesture *obj = [skin toNSObjectAtIndex:1] ;
    if (obj.specificRecognizer.view) {
        [obj.specificRecognizer.view removeGestureRecognizer:obj.specificRecognizer] ;
    } else {
        return luaL_argerror(L, 1, "not attached to a canvas view") ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int gesture_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasGesture *obj = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        obj.gestureCallbackRef = [skin luaUnref:refTable ref:obj.gestureCallbackRef] ;
        if (lua_type(L, 2) == LUA_TFUNCTION) {
            lua_pushvalue(L, 2) ;
            obj.gestureCallbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (obj.gestureCallbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:obj.gestureCallbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int gesture_enabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasGesture *obj = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        obj.specificRecognizer.enabled = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, obj.specificRecognizer.enabled) ;
    }
    return 1 ;
}

static int gesture_pressureConfiguration(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasGesture *obj = [skin toNSObjectAtIndex:1] ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
    if (lua_gettop(L) == 2) {
        if ([obj.specificRecognizer respondsToSelector:@selector(pressureConfiguration)]) {
            NSString *type = [skin toNSObjectAtIndex:2] ;
            if ([type isEqualToString:@"unknown"]) {
                obj.specificRecognizer.pressureConfiguration = [[NSPressureConfiguration alloc] initWithPressureBehavior:NSPressureBehaviorUnknown] ;
            } else if ([type isEqualToString:@"default"]) {
                obj.specificRecognizer.pressureConfiguration = [[NSPressureConfiguration alloc] initWithPressureBehavior:NSPressureBehaviorPrimaryDefault] ;
            } else if ([type isEqualToString:@"click"]) {
                obj.specificRecognizer.pressureConfiguration = [[NSPressureConfiguration alloc] initWithPressureBehavior:NSPressureBehaviorPrimaryClick] ;
            } else if ([type isEqualToString:@"generic"]) {
                obj.specificRecognizer.pressureConfiguration = [[NSPressureConfiguration alloc] initWithPressureBehavior:NSPressureBehaviorPrimaryGeneric] ;
            } else if ([type isEqualToString:@"accelerator"]) {
                obj.specificRecognizer.pressureConfiguration = [[NSPressureConfiguration alloc] initWithPressureBehavior:NSPressureBehaviorPrimaryAccelerator] ;
            } else if ([type isEqualToString:@"deepClick"]) {
                obj.specificRecognizer.pressureConfiguration = [[NSPressureConfiguration alloc] initWithPressureBehavior:NSPressureBehaviorPrimaryDeepClick] ;
            } else if ([type isEqualToString:@"deepDrag"]) {
                obj.specificRecognizer.pressureConfiguration = [[NSPressureConfiguration alloc] initWithPressureBehavior:NSPressureBehaviorPrimaryDeepDrag] ;
            } else {
                return luaL_argerror(L, 2, [[NSString stringWithFormat:@"unrecognized configuration string %@; must be one of unknown, default, click, generic, accelerator, deepClick, or deepDrag", type] UTF8String]) ;
            }
            [obj.specificRecognizer.pressureConfiguration set] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if ([obj.specificRecognizer respondsToSelector:@selector(pressureConfiguration)] && obj.specificRecognizer.pressureConfiguration) {
            switch(obj.specificRecognizer.pressureConfiguration.pressureBehavior) {
                case NSPressureBehaviorUnknown:
                    lua_pushstring(L, "unknown") ;
                    break ;
                case NSPressureBehaviorPrimaryDefault:
                    lua_pushstring(L, "default") ;
                    break ;
                case NSPressureBehaviorPrimaryClick:
                    lua_pushstring(L, "click") ;
                    break ;
                case NSPressureBehaviorPrimaryGeneric:
                    lua_pushstring(L, "generic") ;
                    break ;
                case NSPressureBehaviorPrimaryAccelerator:
                    lua_pushstring(L, "accelerator") ;
                    break ;
                case NSPressureBehaviorPrimaryDeepClick:
                    lua_pushstring(L, "deepClick") ;
                    break ;
                case NSPressureBehaviorPrimaryDeepDrag:
                    lua_pushstring(L, "deepDrag") ;
                    break ;
                default:
                    [skin pushNSObject:[NSString stringWithFormat:@"** unrecognized pressureConfiguration:%ld", obj.specificRecognizer.pressureConfiguration.pressureBehavior]] ;
            }
        } else {
            lua_pushnil(L) ;
        }
    }
#pragma clang diagnostic pop
    return 1 ;
}

static int gesture_buttonMask(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasGesture *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj.specificRecognizer isKindOfClass:[NSClickGestureRecognizer class]] || [obj.specificRecognizer isKindOfClass:[NSPanGestureRecognizer class]] || [obj.specificRecognizer isKindOfClass:[NSPressGestureRecognizer class]]) {
        if (lua_gettop(L) == 2) {
            NSUInteger buttonMask = 0 ;
            for (NSUInteger i = 0 ; i < 32 ; i++) {
                lua_rawgeti(L, 2, (lua_Integer)(i + 1)) ;
                if (lua_toboolean(L, -1)) buttonMask |= (1 << i) ;
                lua_pop(L, 1) ;
            }
            ((NSClickGestureRecognizer *)obj.specificRecognizer).buttonMask = buttonMask ;
            lua_pushvalue(L, 1) ;
        } else {
            lua_newtable(L) ;
            NSUInteger buttonMask = ((NSClickGestureRecognizer *)obj.specificRecognizer).buttonMask ;
            for (NSUInteger i = 0 ; i < 32 ; i++) {
                lua_pushboolean(L, ((buttonMask & (1 << i)) > 0)) ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
        }
    } else {
        return luaL_argerror(L, 1, "buttonMask only valid for click, pan, and press gestures") ;
    }
    return 1 ;
}

static int gesture_numberOfClicksRequired(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasGesture *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj.specificRecognizer isKindOfClass:[NSClickGestureRecognizer class]]) {
        if (lua_gettop(L) == 2) {
            ((NSClickGestureRecognizer *)obj.specificRecognizer).numberOfClicksRequired = lua_tointeger(L, 2) ;
            lua_pushvalue(L, 1) ;
        } else {
            lua_pushinteger(L, ((NSClickGestureRecognizer *)obj.specificRecognizer).numberOfClicksRequired) ;
        }
    } else {
        return luaL_argerror(L, 1, "mouseClickCount only valid for click gestures") ;
    }
    return 1 ;
}

static int gesture_magnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasGesture *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj.specificRecognizer isKindOfClass:[NSMagnificationGestureRecognizer class]]) {
        if (lua_gettop(L) == 2) {
            ((NSMagnificationGestureRecognizer *)obj.specificRecognizer).magnification = lua_tonumber(L, 2) ;
            lua_pushvalue(L, 1) ;
        } else {
            lua_pushnumber(L, ((NSMagnificationGestureRecognizer *)obj.specificRecognizer).magnification) ;
        }
    } else {
        return luaL_argerror(L, 1, "magnification only valid for magnify gestures") ;
    }
    return 1 ;
}

static int gesture_minimumPressDuration(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasGesture *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj.specificRecognizer isKindOfClass:[NSPressGestureRecognizer class]]) {
        if (lua_gettop(L) == 2) {
            ((NSPressGestureRecognizer *)obj.specificRecognizer).minimumPressDuration = lua_tonumber(L, 2) ;
            lua_pushvalue(L, 1) ;
        } else {
            lua_pushnumber(L, ((NSPressGestureRecognizer *)obj.specificRecognizer).minimumPressDuration) ;
        }
    } else {
        return luaL_argerror(L, 1, "minimumDuration only valid for press gestures") ;
    }
    return 1 ;
}

static int gesture_allowableMovement(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasGesture *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj.specificRecognizer isKindOfClass:[NSPressGestureRecognizer class]]) {
        if (lua_gettop(L) == 2) {
            ((NSPressGestureRecognizer *)obj.specificRecognizer).allowableMovement = lua_tonumber(L, 2) ;
            lua_pushvalue(L, 1) ;
        } else {
            lua_pushnumber(L, ((NSPressGestureRecognizer *)obj.specificRecognizer).allowableMovement) ;
        }
    } else {
        return luaL_argerror(L, 1, "allowableMovement only valid for press gestures") ;
    }
    return 1 ;
}

static int gesture_rotation(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasGesture *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj.specificRecognizer isKindOfClass:[NSRotationGestureRecognizer class]]) {
        if (lua_gettop(L) == 2) {
            ((NSRotationGestureRecognizer *)obj.specificRecognizer).rotation = lua_tonumber(L, 2) ;
            lua_pushvalue(L, 1) ;
        } else {
            lua_pushnumber(L, ((NSRotationGestureRecognizer *)obj.specificRecognizer).rotation) ;
        }
    } else {
        return luaL_argerror(L, 1, "rotation only valid for rotate gestures") ;
    }
    return 1 ;
}

static int gesture_rotationInDegrees(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasGesture *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj.specificRecognizer isKindOfClass:[NSRotationGestureRecognizer class]]) {
        if (lua_gettop(L) == 2) {
            ((NSRotationGestureRecognizer *)obj.specificRecognizer).rotationInDegrees = lua_tonumber(L, 2) ;
            lua_pushvalue(L, 1) ;
        } else {
            lua_pushnumber(L, ((NSRotationGestureRecognizer *)obj.specificRecognizer).rotationInDegrees) ;
        }
    } else {
        return luaL_argerror(L, 1, "rotationInDegrees only valid for rotate gestures") ;
    }
    return 1 ;
}

static int gesture_translation(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasGesture *obj = [skin toNSObjectAtIndex:1] ;
    if (obj.specificRecognizer.view) {
        if ([obj.specificRecognizer isKindOfClass:[NSPanGestureRecognizer class]]) {
            if (lua_gettop(L) == 2) {
                [(NSPanGestureRecognizer *)obj.specificRecognizer setTranslation:[skin tableToPointAtIndex:2] inView:obj.specificRecognizer.view] ;
                lua_pushvalue(L, 1) ;
            } else {
                [skin pushNSPoint:[(NSPanGestureRecognizer *)obj.specificRecognizer translationInView:obj.specificRecognizer.view]] ;
            }
        } else {
            return luaL_argerror(L, 1, "translation only valid for pan gestures") ;
        }
    } else {
        return luaL_argerror(L, 1, "translation only valid when attached to a canvas view") ;
    }
    return 1 ;
}

static int gesture_velocity(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasGesture *obj = [skin toNSObjectAtIndex:1] ;
    if (obj.specificRecognizer.view) {
        if ([obj.specificRecognizer isKindOfClass:[NSPanGestureRecognizer class]]) {
            [skin pushNSPoint:[(NSPanGestureRecognizer *)obj.specificRecognizer velocityInView:obj.specificRecognizer.view]] ;
        } else {
            return luaL_argerror(L, 1, "velocity only valid for pan gestures") ;
        }
    } else {
        return luaL_argerror(L, 1, "velocity only valid when attached to a canvas view") ;
    }
    return 1 ;
}

#if defined(INCLUDE_TOUCHBARMETHODS)
static int gesture_numberOfTouchesRequired(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasGesture *obj = [skin toNSObjectAtIndex:1] ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
    if ([obj.specificRecognizer isKindOfClass:[NSClickGestureRecognizer class]] || [obj.specificRecognizer isKindOfClass:[NSPanGestureRecognizer class]] || [obj.specificRecognizer isKindOfClass:[NSPressGestureRecognizer class]]) {
        if (lua_gettop(L) == 2) {
            if ([obj.specificRecognizer respondsToSelector:@selector(numberOfTouchesRequired)]) {
                ((NSClickGestureRecognizer *)obj.specificRecognizer).numberOfTouchesRequired = lua_tointeger(L, 2) ;
            }
            lua_pushvalue(L, 1) ;
        } else {
            if ([obj.specificRecognizer respondsToSelector:@selector(numberOfTouchesRequired)]) {
                lua_pushinteger(L, ((NSClickGestureRecognizer *)obj.specificRecognizer).numberOfTouchesRequired) ;
            } else {
                lua_pushnil(L) ;
            }
        }
    } else {
        return luaL_argerror(L, 1, "touchCount only valid for click, pan, and press gestures") ;
    }
#pragma clang diagnostic pop
    return 1 ;
}
#endif

// property change methods?

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSCanvasGesture(lua_State *L, id obj) {
    HSCanvasGesture *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSCanvasGesture *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2);
    return 1;
}

id toHSCanvasGestureFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSCanvasGesture *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSCanvasGesture, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSCanvasGesture *obj = [skin luaObjectAtIndex:1 toClass:"HSCanvasGesture"] ;
    int type = obj.recognizerType ;
    NSString *label = (type > 0 && type < (int)gestureLabels.count) ? gestureLabels[(NSUInteger)type] : @"invalid" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, label, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSCanvasGesture *obj1 = [skin luaObjectAtIndex:1 toClass:"HSCanvasGesture"] ;
        HSCanvasGesture *obj2 = [skin luaObjectAtIndex:2 toClass:"HSCanvasGesture"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSCanvasGesture *obj = get_objectFromUserdata(__bridge_transfer HSCanvasGesture, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        LuaSkin *skin = [LuaSkin shared] ;
        if (obj.selfRefCount == 0) {
            obj.gestureCallbackRef = [skin luaUnref:refTable ref:obj.gestureCallbackRef] ;
            if (obj.specificRecognizer.view) {
                [obj.specificRecognizer.view removeGestureRecognizer:obj.specificRecognizer] ;
            }
            obj.specificRecognizer = nil ;
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
    {"addToCanvas",           gesture_addToCanvas},
    {"removeFromCanvas",      gesture_removeFromCanvas},
    {"callback",              gesture_callback},
    {"enabled",               gesture_enabled},
    {"pressureConfiguration", gesture_pressureConfiguration},
    {"mouseButtons",          gesture_buttonMask},
    {"mouseClickCount",       gesture_numberOfClicksRequired},
    {"magnification",         gesture_magnification},
    {"minimumDuration",       gesture_minimumPressDuration},
    {"allowableMovement",     gesture_allowableMovement},
    {"rotation",              gesture_rotation},
    {"rotationInDegrees",     gesture_rotationInDegrees},
    {"translation",           gesture_translation},
    {"velocity",              gesture_velocity},

#if defined(INCLUDE_TOUCHBARMETHODS)
    {"touchCount",            gesture_numberOfTouchesRequired},
#endif

    {"__tostring",            userdata_tostring},
    {"__eq",                  userdata_eq},
    {"__gc",                  userdata_gc},
    {NULL,                    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"newClickGesture",   gesture_newClickGestureRecognizer},
    {"newMagnifyGesture", gesture_newMagnificationGestureRecognizer},
    {"newPanGesture",     gesture_newPanGestureRecognizer},
    {"newPressGesture",   gesture_newPressGestureRecognizer},
    {"newRotateGesture",  gesture_newRotationGestureRecognizer},
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_canvas_gesture_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    gestureClasses = @[
        [NSClickGestureRecognizer         class],
        [NSMagnificationGestureRecognizer class],
        [NSPanGestureRecognizer           class],
        [NSPressGestureRecognizer         class],
        [NSRotationGestureRecognizer      class],
    ] ;

    gestureLabels = @[
        @"click",
        @"magnify",
        @"pan",
        @"press",
        @"rotate",
    ] ;

    [skin registerPushNSHelper:pushHSCanvasGesture         forClass:"HSCanvasGesture"];
    [skin registerLuaObjectHelper:toHSCanvasGestureFromLua forClass:"HSCanvasGesture"
                                                withUserdataMapping:USERDATA_TAG];

    return 1;
}
