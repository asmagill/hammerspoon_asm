@import Cocoa ;
@import LuaSkin ;

static const char *EVENT_UD_TAG   = "hs._asm.nsevent" ;
static const char *WATCHER_UD_TAG = "hs._asm.nsevent.watcher" ;

static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

// "borrowed" from hs.eventtap.event
static void new_eventtap_event(lua_State* L, CGEventRef event) {
    CFRetain(event);
    *(CGEventRef*)lua_newuserdata(L, sizeof(CGEventRef*)) = event;
    luaL_getmetatable(L, "hs.eventtap.event");
    lua_setmetatable(L, -2);
}

static int push_eventTypes(lua_State *L) ;

@interface ASMNSEventWatcher : NSObject
@property id         watcher ;
@property int        callbackRef ;
@property int        selfRefCount ;
@property NSUInteger mask ;
@property BOOL       isGlobal ;
@end

@implementation ASMNSEventWatcher

- (instancetype)initGlobal:(BOOL)isGlobal withMask:(NSUInteger)mask {
    self = [super init] ;
    if (self) {
        _watcher      = nil ;
        _callbackRef  = LUA_NOREF ;
        _selfRefCount = 0 ;
        _mask         = mask ;
        _isGlobal     = isGlobal ;
    }
    return self ;
}

- (void)performCallback:(NSEvent *)event {
    [self performSelectorOnMainThread:@selector(_performCallback:) withObject:event waitUntilDone:NO] ;
}

- (void)_performCallback:(NSEvent *)event {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:event] ;
        if (![skin protectedCallAndTraceback:2 nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:callback error:%@", WATCHER_UD_TAG, [skin toNSObjectAtIndex:-1]]] ;
            lua_pop([skin L], 1) ;
        }
    }
}

@end

#pragma mark - Module Functions

static int watcher_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    BOOL isGlobal = (lua_gettop(L) == 1) ? NO : (BOOL)lua_toboolean(L, 2) ;
    NSUInteger __block mask = 0 ;
    NSArray *request = [skin toNSObjectAtIndex:1] ;
    NSString __block *error ;
    if ([request isKindOfClass:[NSArray class]]) {
        push_eventTypes(L) ;
        int eventTypesTable = lua_gettop(L) ;
        [request enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isKindOfClass:[NSNumber class]]) {
                mask |= NSEventMaskFromType([(NSNumber *)obj unsignedIntegerValue]) ;
            } else if ([obj isKindOfClass:[NSString class]]) {
                if ([(NSString *)obj isEqualToString:@"all"]) {
                    mask = NSAnyEventMask ;
                } else {
                    push_eventTypes(L) ;
                    if (lua_getfield(L, eventTypesTable, [(NSString *)obj UTF8String]) == LUA_TNUMBER) {
                        mask |= NSEventMaskFromType((NSUInteger)lua_tointeger(L, -1)) ;
                    } else {
                        error = [NSString stringWithFormat:@"unrecognized type %@ at index %ld", obj, idx + 1] ;
                        *stop = YES ;
                    }
                    lua_pop(L, 1) ;
                }
            } else {
                error = [NSString stringWithFormat:@"expected string or integer at index %ld", idx + 1] ;
                *stop = YES ;
            }
        }] ;
        lua_pop(L, 1) ; // the types table
    } else {
        error = @"expected an array of integers and/or strings" ;
    }
    if (error) return luaL_argerror(L, 1, error.UTF8String) ;

    [skin pushNSObject:[[ASMNSEventWatcher alloc] initGlobal:isGlobal withMask:mask]] ;
    return 1 ;
}

#pragma mark - Watcher Methods

static int watcher_start(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, WATCHER_UD_TAG, LS_TBREAK] ;
    ASMNSEventWatcher *watcher = [skin toNSObjectAtIndex:1] ;
    if (watcher.watcher) {
        [skin logWarn:[NSString stringWithFormat:@"%s:start invoked on already running watcher object", WATCHER_UD_TAG]] ;
    } else {
        if (watcher.isGlobal) {
            watcher.watcher = [NSEvent addGlobalMonitorForEventsMatchingMask:watcher.mask
                                                                     handler:^(NSEvent *event) {
                [watcher performCallback:event] ;
            }] ;
        } else {
            watcher.watcher = [NSEvent addLocalMonitorForEventsMatchingMask:watcher.mask
                                                                    handler:^id(NSEvent *event) {
                [watcher performCallback:event] ;
                return event ;
            }] ;
        }
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int watcher_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, WATCHER_UD_TAG, LS_TBREAK] ;
    ASMNSEventWatcher *watcher = [skin toNSObjectAtIndex:1] ;
    if (watcher.watcher) {
        [NSEvent removeMonitor:watcher.watcher] ;
        watcher.watcher = nil ;
    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s:stop invoked on idle watcher object", WATCHER_UD_TAG]] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;

}

static int watcher_isWatching(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, WATCHER_UD_TAG, LS_TBREAK] ;
    ASMNSEventWatcher *watcher = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, watcher.watcher ? YES : NO) ;
    return 1 ;
}

static int watcher_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, WATCHER_UD_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    ASMNSEventWatcher *watcher = [skin toNSObjectAtIndex:1] ;

    watcher.callbackRef = [skin luaUnref:refTable ref:watcher.callbackRef] ;
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2) ;
        watcher.callbackRef = [skin luaRef:refTable] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Event Methods

#pragma mark * General Information

static int event_type(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, event.type) ;
    return 1 ;
}

static int event_locationInWindow(lua_State __unused *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event = [skin toNSObjectAtIndex:1] ;
    [skin pushNSPoint:event.locationInWindow] ;
    return 1 ;
}

static int event_flags(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, event.modifierFlags) ;
    return 1 ;
}

static int event_timestamp(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event = [skin toNSObjectAtIndex:1] ;
    lua_pushnumber(L, event.timestamp) ;
    return 1 ;
}

static int event_windowid(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, event.windowNumber) ;
    return 1 ;
}

static int event_CGEvent(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event = [skin toNSObjectAtIndex:1] ;
    CGEventRef cgevent = event.CGEvent ;
    if (cgevent) {
        new_eventtap_event(L, cgevent) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int event_eventRef(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event = [skin toNSObjectAtIndex:1] ;

    const void *eventRef = event.eventRef ;
    if (eventRef) {
        [skin pushNSObject:[NSString stringWithFormat:@"0x%p", eventRef]] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark * Key Information

static int event_characters(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    BOOL    ignoreMods = (lua_gettop(L) == 1) ? (BOOL)lua_toboolean(L, 2) : NO ;
    NSString *characters ;
    @try {
        characters = ignoreMods ? event.charactersIgnoringModifiers : event.characters ;
    } @catch(NSException *exception) {
        characters = nil ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:characters - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    [skin pushNSObject:characters] ;
    return 1 ;
}

static int event_ARepeat(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushboolean(L, event.ARepeat) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:ARepeat - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_keyCode(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, event.keyCode) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:keyCode - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

#pragma mark * Mouse Information

static int event_buttonNumber(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, event.buttonNumber) ;
    return 1 ;
}

static int event_associatedEventsMask(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;

// associatedEventsMask didn't exist until 10.10.3
    if ([NSEvent instancesRespondToSelector:@selector(associatedEventsMask)]) {
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
            lua_pushinteger(L, (lua_Integer)event.associatedEventsMask) ;
#pragma clang diagnostic pop
        } @catch(NSException *exception) {
            lua_pushnil(L) ;
            if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
                [skin logWarn:[NSString stringWithFormat:@"%s:associatedEventsMask - %@", EVENT_UD_TAG, exception.reason]] ;
            }
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int event_clickCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, event.clickCount) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:clickCount - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

#pragma mark * Mouse Tracking Information

static int event_eventNumber(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, event.eventNumber) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:eventNumber - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_trackingNumber(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, event.trackingNumber) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:trackingNumber - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_trackingArea(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        if (event.trackingArea) {
            [skin pushNSRect:event.trackingArea.rect] ;
        } else {
            lua_newtable(L) ;
        }
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:trackingArea - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

#pragma mark * Custom Information

static int event_data1(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, event.data1) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:data1 - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_data2(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, event.data2) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:data2 - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_subtype(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, event.subtype) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:subtype - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

#pragma mark * Scroll Wheel Information

static int event_deltaX(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushnumber(L, event.deltaX) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:deltaX - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_deltaY(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushnumber(L, event.deltaY) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:deltaY - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_deltaZ(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushnumber(L, event.deltaZ) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:deltaZ - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

#pragma mark * Pressure Information

static int event_pressure(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushnumber(L, (lua_Number)event.pressure) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:pressure - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_stage(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;

// stage didn't exist until 10.10.3
    if ([NSEvent instancesRespondToSelector:@selector(stage)]) {
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
            lua_pushinteger(L, event.stage) ;
#pragma clang diagnostic pop
        } @catch(NSException *exception) {
            lua_pushnil(L) ;
            if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
                [skin logWarn:[NSString stringWithFormat:@"%s:stage - %@", EVENT_UD_TAG, exception.reason]] ;
            }
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int event_stageTransition(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;

// stageTransition didn't exist until 10.10.3
    if ([NSEvent instancesRespondToSelector:@selector(stageTransition)]) {
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
            lua_pushnumber(L, event.stageTransition) ;
#pragma clang diagnostic pop
        } @catch(NSException *exception) {
            lua_pushnil(L) ;
            if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
                [skin logWarn:[NSString stringWithFormat:@"%s:stageTransition - %@", EVENT_UD_TAG, exception.reason]] ;
            }
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int event_pressureBehavior(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;

// pressureBehavior didn't exist until 10.11
    if ([NSEvent instancesRespondToSelector:@selector(pressureBehavior)]) {
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
            NSPressureBehavior pressureBehavior = event.pressureBehavior ;
            switch(pressureBehavior) {
                case NSPressureBehaviorPrimaryDefault:     lua_pushstring(L, "primaryDefault") ; break ;
                case NSPressureBehaviorPrimaryClick:       lua_pushstring(L, "primaryClick") ; break ;
                case NSPressureBehaviorPrimaryGeneric:     lua_pushstring(L, "primaryGeneric") ; break ;
                case NSPressureBehaviorPrimaryAccelerator: lua_pushstring(L, "primaryAccelerator") ; break ;
                case NSPressureBehaviorPrimaryDeepClick:   lua_pushstring(L, "primaryDeepClick") ; break ;
                case NSPressureBehaviorPrimaryDeepDrag:    lua_pushstring(L, "primaryDeepDrag") ; break ;
                case NSPressureBehaviorUnknown:
                default:                                   lua_pushstring(L, "unknown") ; break ;
            }
#pragma clang diagnostic pop
        } @catch(NSException *exception) {
            lua_pushnil(L) ;
            if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
                [skin logWarn:[NSString stringWithFormat:@"%s:pressureBehavior - %@", EVENT_UD_TAG, exception.reason]] ;
            }
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark * Tablet Proximity Information

static int event_capabilityMask(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, (lua_Integer)event.capabilityMask) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:capabilityMask - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_deviceID(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, (lua_Integer)event.deviceID) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:deviceID - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_enteringProximity(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, event.enteringProximity) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:enteringProximity - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_pointingDeviceID(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, (lua_Integer)event.pointingDeviceID) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:pointingDeviceID - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_pointingDeviceSerialNumber(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, (lua_Integer)event.pointingDeviceSerialNumber) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:pointingDeviceSerialNumber - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_pointingDeviceType(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, event.pointingDeviceType) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:pointingDeviceType - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_systemTabletID(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, (lua_Integer)event.systemTabletID) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:systemTabletID - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_tabletID(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, (lua_Integer)event.tabletID) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:tabletID - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_vendorID(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, (lua_Integer)event.vendorID) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:vendorID - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_vendorPointingDeviceType(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, (lua_Integer)event.vendorPointingDeviceType) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:vendorPointingDeviceType - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_uniqueID(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, (lua_Integer)event.uniqueID) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:uniqueID - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

#pragma mark * Tablet Pointing Information

static int event_absoluteX(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, event.absoluteX) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:absoluteX - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_absoluteY(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, event.absoluteY) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:absoluteY - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_absoluteZ(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, event.absoluteZ) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:absoluteZ - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_buttonMask(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, event.buttonMask) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:buttonMask - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_rotation(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushnumber(L, (lua_Number)event.rotation) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:rotation - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_tangentialPressure(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushnumber(L, (lua_Number)event.tangentialPressure) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:tangentialPressure - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_tilt(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        [skin pushNSPoint:event.tilt] ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:tilt - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_vendorDefined(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        [skin pushNSObject:event.vendorDefined withOptions:LS_NSDescribeUnknownTypes] ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:vendorDefined - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

#pragma mark * Touch and Gesture Information

static int event_magnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushnumber(L, (lua_Number)event.magnification) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:magnification - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_touches(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        NSSet *touches = [event touchesMatchingPhase:NSTouchPhaseAny inView:nil] ;
        [skin pushNSObject:touches withOptions:LS_NSDescribeUnknownTypes] ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:touches - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

#pragma mark * Scroll Wheel and Flick Information

static int event_hasPreciseScrollingDeltas(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushboolean(L, event.hasPreciseScrollingDeltas) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:hasPreciseScrollingDeltas - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_scrollingDeltaX(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushnumber(L, (lua_Number)event.scrollingDeltaX) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:scrollingDeltaX - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_scrollingDeltaY(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushnumber(L, (lua_Number)event.scrollingDeltaY) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:scrollingDeltaY - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_momentumPhase(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, event.momentumPhase) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:momentumPhase - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_phase(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushinteger(L, event.phase) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:phase - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

static int event_directionInvertedFromDevice(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_UD_TAG, LS_TBREAK] ;
    NSEvent *event     = [skin toNSObjectAtIndex:1] ;
    @try {
        lua_pushboolean(L, event.directionInvertedFromDevice) ;
    } @catch(NSException *exception) {
        lua_pushnil(L) ;
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            [skin logWarn:[NSString stringWithFormat:@"%s:directionInvertedFromDevice - %@", EVENT_UD_TAG, exception.reason]] ;
        }
    }
    return 1 ;
}

#pragma mark - Module Constants

static int push_eventTypes(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSLeftMouseDown) ;         lua_setfield(L, -2, "leftMouseDown") ;
    lua_pushinteger(L, NSLeftMouseUp) ;           lua_setfield(L, -2, "leftMouseUp") ;
    lua_pushinteger(L, NSRightMouseDown) ;        lua_setfield(L, -2, "rightMouseDown") ;
    lua_pushinteger(L, NSRightMouseUp) ;          lua_setfield(L, -2, "rightMouseUp") ;
    lua_pushinteger(L, NSMouseMoved) ;            lua_setfield(L, -2, "mouseMoved") ;
    lua_pushinteger(L, NSLeftMouseDragged) ;      lua_setfield(L, -2, "leftMouseDragged") ;
    lua_pushinteger(L, NSRightMouseDragged) ;     lua_setfield(L, -2, "rightMouseDragged") ;
    lua_pushinteger(L, NSMouseEntered) ;          lua_setfield(L, -2, "mouseEntered") ;
    lua_pushinteger(L, NSMouseExited) ;           lua_setfield(L, -2, "mouseExited") ;
    lua_pushinteger(L, NSKeyDown) ;               lua_setfield(L, -2, "keyDown") ;
    lua_pushinteger(L, NSKeyUp) ;                 lua_setfield(L, -2, "keyUp") ;
    lua_pushinteger(L, NSFlagsChanged) ;          lua_setfield(L, -2, "flagsChanged") ;
    lua_pushinteger(L, NSAppKitDefined) ;         lua_setfield(L, -2, "appKitDefined") ;
    lua_pushinteger(L, NSSystemDefined) ;         lua_setfield(L, -2, "systemDefined") ;
    lua_pushinteger(L, NSApplicationDefined) ;    lua_setfield(L, -2, "applicationDefined") ;
    lua_pushinteger(L, NSPeriodic) ;              lua_setfield(L, -2, "periodic") ;
    lua_pushinteger(L, NSCursorUpdate) ;          lua_setfield(L, -2, "cursorUpdate") ;
    lua_pushinteger(L, NSScrollWheel) ;           lua_setfield(L, -2, "scrollWheel") ;
    lua_pushinteger(L, NSTabletPoint) ;           lua_setfield(L, -2, "tabletPoint") ;
    lua_pushinteger(L, NSTabletProximity) ;       lua_setfield(L, -2, "tabletProximity") ;
    lua_pushinteger(L, NSOtherMouseDown) ;        lua_setfield(L, -2, "otherMouseDown") ;
    lua_pushinteger(L, NSOtherMouseUp) ;          lua_setfield(L, -2, "otherMouseUp") ;
    lua_pushinteger(L, NSOtherMouseDragged) ;     lua_setfield(L, -2, "otherMouseDragged") ;
    lua_pushinteger(L, NSEventTypeGesture) ;      lua_setfield(L, -2, "eventTypeGesture") ;
    lua_pushinteger(L, NSEventTypeMagnify) ;      lua_setfield(L, -2, "eventTypeMagnify") ;
    lua_pushinteger(L, NSEventTypeSwipe) ;        lua_setfield(L, -2, "eventTypeSwipe") ;
    lua_pushinteger(L, NSEventTypeRotate) ;       lua_setfield(L, -2, "eventTypeRotate") ;
    lua_pushinteger(L, NSEventTypeBeginGesture) ; lua_setfield(L, -2, "eventTypeBeginGesture") ;
    lua_pushinteger(L, NSEventTypeEndGesture) ;   lua_setfield(L, -2, "eventTypeEndGesture") ;
    lua_pushinteger(L, NSEventTypeSmartMagnify) ; lua_setfield(L, -2, "eventTypeSmartMagnify") ;
    lua_pushinteger(L, NSEventTypePressure) ;     lua_setfield(L, -2, "eventTypePressure") ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMNSEventWatcher(lua_State *L, id obj) {
    ASMNSEventWatcher *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMNSEventWatcher *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, WATCHER_UD_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static int pushNSEvent(lua_State *L, id obj) {
    NSEvent *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(NSEvent *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, EVENT_UD_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static int pushNSTouch(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSTouch *value = obj;
    lua_newtable(L) ;
    [skin pushNSObject:value.device withOptions:LS_NSDescribeUnknownTypes] ;
    lua_setfield(L, -2, "device") ;
    [skin pushNSObject:value.identity withOptions:LS_NSDescribeUnknownTypes] ;
    lua_setfield(L, -2, "identity") ;
    lua_pushboolean(L, value.isResting) ;
    lua_setfield(L, -2, "isResting") ;
    [skin pushNSPoint:value.normalizedPosition] ;
    lua_setfield(L, -2, "normalizedPosition") ;
    [skin pushNSSize:value.deviceSize] ;
    lua_setfield(L, -2, "deviceSize") ;
    NSTouchPhase phase = value.phase ;
    lua_newtable(L) ;
    lua_pushinteger(L, (lua_Integer)phase) ; lua_setfield(L, -2, "_raw") ;
    if ((phase & NSTouchPhaseBegan) == NSTouchPhaseBegan) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "began") ;
    }
    if ((phase & NSTouchPhaseMoved) == NSTouchPhaseMoved) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "moved") ;
    }
    if ((phase & NSTouchPhaseStationary) == NSTouchPhaseStationary) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "stationary") ;
    }
    if ((phase & NSTouchPhaseEnded) == NSTouchPhaseEnded) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "ended") ;
    }
    if ((phase & NSTouchPhaseCancelled) == NSTouchPhaseCancelled) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "cancelled") ;
    }
    lua_setfield(L, -2, "phase") ;
    return 1;
}

id toASMNSEventWatcherFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMNSEventWatcher *value ;
    if (luaL_testudata(L, idx, WATCHER_UD_TAG)) {
        value = get_objectFromUserdata(__bridge ASMNSEventWatcher, L, idx, WATCHER_UD_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", WATCHER_UD_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

id toNSEventFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSEvent *value ;
    if (luaL_testudata(L, idx, EVENT_UD_TAG)) {
        value = get_objectFromUserdata(__bridge NSEvent, L, idx, EVENT_UD_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", EVENT_UD_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int watcher_ud_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMNSEventWatcher *obj = [skin luaObjectAtIndex:1 toClass:"ASMNSEventWatcher"] ;
    NSString *title = [NSString stringWithFormat:@"%@:0x%08lx", (obj.isGlobal ? @"global" : @"local"), obj.mask] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", WATCHER_UD_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int event_ud_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSEvent *obj = [skin luaObjectAtIndex:1 toClass:"NSEvent"] ;
    NSString *title = [NSString stringWithFormat:@"0x%08lx", obj.type] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", EVENT_UD_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int watcher_ud_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, WATCHER_UD_TAG) && luaL_testudata(L, 2, WATCHER_UD_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMNSEventWatcher *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMNSEventWatcher"] ;
        ASMNSEventWatcher *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMNSEventWatcher"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int event_ud_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, WATCHER_UD_TAG) && luaL_testudata(L, 2, WATCHER_UD_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        NSEvent *obj1 = [skin luaObjectAtIndex:1 toClass:"NSEvent"] ;
        NSEvent *obj2 = [skin luaObjectAtIndex:2 toClass:"NSEvent"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int watcher_ud_gc(lua_State* L) {
    ASMNSEventWatcher *obj = get_objectFromUserdata(__bridge_transfer ASMNSEventWatcher, L, 1, WATCHER_UD_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin shared] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            if (obj.watcher) {
                [NSEvent removeMonitor:obj.watcher] ;
                obj.watcher = nil ;
            }
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int event_ud_gc(lua_State* L) {
    NSEvent *obj = get_objectFromUserdata(__bridge_transfer NSEvent, L, 1, EVENT_UD_TAG) ;
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
static const luaL_Reg watcher_ud_metaLib[] = {
    {"start",      watcher_start},
    {"stop",       watcher_stop},
    {"isWatching", watcher_isWatching},
    {"callback",   watcher_callback},

    {"__tostring", watcher_ud_tostring},
    {"__eq",       watcher_ud_eq},
    {"__gc",       watcher_ud_gc},
    {NULL,         NULL}
};

static const luaL_Reg event_metaLib[] = {
    {"type",                        event_type},
    {"locationInWindow",            event_locationInWindow},
    {"flags",                       event_flags},
    {"timestamp",                   event_timestamp},
    {"windowID",                    event_windowid},
    {"CGEvent",                     event_CGEvent},
    {"eventRef",                    event_eventRef},
    {"characters",                  event_characters},
    {"ARepeat",                     event_ARepeat},
    {"keyCode",                     event_keyCode},
    {"buttonNumber",                event_buttonNumber},
    {"clickCount",                  event_clickCount},
    {"associatedEvents",            event_associatedEventsMask},
    {"eventNumber",                 event_eventNumber},
    {"trackingNumber",              event_trackingNumber},
    {"trackingArea",                event_trackingArea},
    {"data1",                       event_data1},
    {"data2",                       event_data2},
    {"subtype",                     event_subtype},
    {"deltaX",                      event_deltaX},
    {"deltaY",                      event_deltaY},
    {"deltaZ",                      event_deltaZ},
    {"pressure",                    event_pressure},
    {"stage",                       event_stage},
    {"stageTransition",             event_stageTransition},
    {"pressureBehavior",            event_pressureBehavior},
    {"capabilityMask",              event_capabilityMask},
    {"deviceID",                    event_deviceID},
    {"enteringProximity",           event_enteringProximity},
    {"pointingDeviceID",            event_pointingDeviceID},
    {"pointingDeviceSerialNumber",  event_pointingDeviceSerialNumber},
    {"pointingDeviceType",          event_pointingDeviceType},
    {"systemTabletID",              event_systemTabletID},
    {"tabletID",                    event_tabletID},
    {"vendorID",                    event_vendorID},
    {"vendorPointingDeviceType",    event_vendorPointingDeviceType},
    {"uniqueID",                    event_uniqueID},
    {"absoluteX",                   event_absoluteX},
    {"absoluteY",                   event_absoluteY},
    {"absoluteZ",                   event_absoluteZ},
    {"buttonMask",                  event_buttonMask},
    {"rotation",                    event_rotation},
    {"tangentialPressure",          event_tangentialPressure},
    {"tilt",                        event_tilt},
    {"vendorDefined",               event_vendorDefined},
    {"magnification",               event_magnification},
    {"touches",                     event_touches},
    {"hasPreciseScrollingDeltas",   event_hasPreciseScrollingDeltas},
    {"scrollingDeltaX",             event_scrollingDeltaX},
    {"scrollingDeltaY",             event_scrollingDeltaY},
    {"momentumPhase",               event_momentumPhase},
    {"phase",                       event_phase},
    {"directionInvertedFromDevice", event_directionInvertedFromDevice},

    {"__tostring",                  event_ud_tostring},
    {"__eq",                        event_ud_eq},
    {"__gc",                        event_ud_gc},
    {NULL,                          NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", watcher_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_nsevent_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:WATCHER_UD_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:watcher_ud_metaLib];

    [skin registerObject:EVENT_UD_TAG objectFunctions:event_metaLib] ;

    push_eventTypes(L) ; lua_setfield(L, -2, "types") ;

    [skin registerPushNSHelper:pushASMNSEventWatcher         forClass:"ASMNSEventWatcher"];
    [skin registerLuaObjectHelper:toASMNSEventWatcherFromLua forClass:"ASMNSEventWatcher"
                                                  withUserdataMapping:WATCHER_UD_TAG];

    [skin registerPushNSHelper:pushNSEvent         forClass:"NSEvent"];
    [skin registerLuaObjectHelper:toNSEventFromLua forClass:"NSEvent"
                                        withUserdataMapping:EVENT_UD_TAG];

    [skin registerPushNSHelper:pushNSTouch forClass:"NSTouch"];

    return 1;
}
