@import Cocoa ;
@import LuaSkin ;

#define USERDATA_TAG "hs.event"
static int refTable = LUA_NOREF;
static CGEventSourceRef eventSource;

static int pushCGEventRef(lua_State *L, CGEventRef event) ;

// #define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
#define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

static int event_createEvent(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    CGEventRef event = CGEventCreate(eventSource) ;
    if (event) {
        CGEventSetTimestamp(event, mach_absolute_time()) ;
        pushCGEventRef(L, event) ;
        CFRelease(event) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int event_createMouseEvent(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TTABLE, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;

    lua_Integer eventType = lua_tointeger(L, 1) ;
    switch(eventType) {
        case kCGEventLeftMouseDown:
        case kCGEventLeftMouseUp:
        case kCGEventRightMouseDown:
        case kCGEventRightMouseUp:
        case kCGEventMouseMoved:          // FIXME: Test if this one allowed here or not... docs unclear
        case kCGEventLeftMouseDragged:
        case kCGEventRightMouseDragged:
        case kCGEventOtherMouseDown:
        case kCGEventOtherMouseUp:
        case kCGEventOtherMouseDragged:
            break ;
        default:
            return luaL_argerror(L, 1, "must specify a mouse event type") ;
    }
    // FIXME: Test if Coordinate flip required
    CGPoint cursorPosition = NSPointToCGPoint([skin tableToPointAtIndex:2]) ;
    lua_Integer mouseButton = (lua_gettop(L) == 3) ? lua_tointeger(L, 3) : kCGMouseButtonLeft ;
    if (mouseButton < 0 || mouseButton > 31) {
        return luaL_argerror(L, 3, "button must be between 0 and 31") ;
    }
    CGEventRef event = CGEventCreateMouseEvent(eventSource, (CGEventType)eventType, cursorPosition, (CGMouseButton)mouseButton);
    if (event) {
        CGEventSetTimestamp(event, mach_absolute_time()) ;
        pushCGEventRef(L, event) ;
        CFRelease(event) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int event_createKeyEvent(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    CGKeyCode keyCode = (CGKeyCode)lua_tointeger(L, 1) ;
    BOOL keyDown = (lua_gettop(L) == 2) ? (BOOL)lua_toboolean(L, 2) : YES ;
    CGEventRef event = CGEventCreateKeyboardEvent(eventSource, keyCode, keyDown) ;
    if (event) {
        CGEventSetTimestamp(event, mach_absolute_time()) ;
        pushCGEventRef(L, event) ;
        CFRelease(event) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int event_createScrollWheelEvent(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    int32_t x = 0 ;
    int32_t y = 0 ;
    int32_t z = 0 ;
    NSArray *offsets = [skin toNSObjectAtIndex:1] ;
    if ([offsets isKindOfClass:[NSArray class]]) {
        NSUInteger count = offsets.count ;
        if (count > 0) x = [offsets[0] intValue] ;
        if (count > 1) y = [offsets[1] intValue] ;
        if (count > 2) z = [offsets[2] intValue] ;
        if (count > 3) {
            return luaL_argerror(L, 1, "offsets must be an array of up to 3 integers") ;
        }
    } else {
        return luaL_argerror(L, 1, "offsets must be an array of up to 3 integers") ;
    }
    BOOL lineOrPixel = (lua_gettop(L) == 2) ? (BOOL)lua_toboolean(L, 2) : YES ;
    CGEventRef event = CGEventCreateScrollWheelEvent(eventSource, (lineOrPixel ? kCGScrollEventUnitLine : kCGScrollEventUnitPixel), 3, x, y, z) ;
    if (event) {
        CGEventSetTimestamp(event, mach_absolute_time()) ;
        pushCGEventRef(L, event) ;
        CFRelease(event) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int event_modifierFlags(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushinteger(L, [NSEvent modifierFlags]) ;
    return 1 ;
}

static int event_keyRepeatDelay(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushnumber(L, [NSEvent keyRepeatDelay]) ;
    return 1 ;
}

static int event_keyRepeatInterval(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushnumber(L, [NSEvent keyRepeatInterval]) ;
    return 1 ;
}

static int event_pressedMouseButtons(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushinteger(L, (lua_Integer)[NSEvent pressedMouseButtons]) ;
    return 1 ;
}

static int event_doubleClickInterval(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushnumber(L, [NSEvent doubleClickInterval]) ;
    return 1 ;
}

static int event_swipeTracking(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushboolean(L, [NSEvent isSwipeTrackingFromScrollEventsEnabled]) ;
    return 1 ;
}


static int event_mouseLocation(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    NSPoint cursorPoint = [NSEvent mouseLocation] ;
    cursorPoint.y = [[NSScreen screens][0] frame].size.height - cursorPoint.y ;
    [skin pushNSPoint:cursorPoint] ;
    return 1 ;
}

static int event_mouseCoallescing(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) == 1) {
        [NSEvent setMouseCoalescingEnabled:(BOOL)lua_toboolean(L, 1)] ;
    }
    lua_pushboolean(L, [NSEvent isMouseCoalescingEnabled]) ;
    return 1 ;
}

static int event_startPeriodicEvents(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TOPTIONAL, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSTimeInterval delay  = 0.0 ;
    NSTimeInterval period = 1.0 ;
    if (lua_gettop(L) == 1) {
        period = lua_tonumber(L, 1) ;
    } else if (lua_gettop(L) == 2) {
        delay  = lua_tonumber(L, 1) ;
        period = lua_tonumber(L, 2) ;
    }
    @try {
        [NSEvent startPeriodicEventsAfterDelay:delay withPeriod:period] ;
        lua_pushboolean(L, YES) ;
    } @catch (NSException *exception) {
        if (exception.name != NSInternalInconsistencyException) {
            [skin logError:[NSString stringWithFormat:@"%s:startPeriodicEvents - unrecognized exception:%@", USERDATA_TAG, exception.reason]] ;
        }
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int event_stopPeriodicEvents(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    [NSEvent stopPeriodicEvents] ;
    return 0 ;
}

static int event_absoluteTime(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushinteger(L, (lua_Integer)mach_absolute_time()) ;
    return 1 ;
}

#pragma mark - Module Methods

static int event_type(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    CGEventRef event = get_cfobjectFromUserdata(CGEventRef, L, 1, USERDATA_TAG) ;
    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, CGEventGetType(event)) ;
    } else {
        CGEventSetType(event, (CGEventType)(lua_tointeger(L, 2))) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int event_timestamp(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TNIL | LS_TOPTIONAL,
                    LS_TBREAK] ;
    CGEventRef event = get_cfobjectFromUserdata(CGEventRef, L, 1, USERDATA_TAG) ;
    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)CGEventGetTimestamp(event)) ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            CGEventSetTimestamp(event, mach_absolute_time()) ;
        } else {
            CGEventSetTimestamp(event, (CGEventTimestamp)(lua_tointeger(L, 2))) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int event_location(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    CGEventRef event = get_cfobjectFromUserdata(CGEventRef, L, 1, USERDATA_TAG) ;
    if (lua_gettop(L) == 1) {
        [skin pushNSPoint:NSPointFromCGPoint(CGEventGetLocation(event))] ;
    } else {
        CGEventSetLocation(event, NSPointToCGPoint([skin tableToPointAtIndex:2])) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int event_flags(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    CGEventRef event = get_cfobjectFromUserdata(CGEventRef, L, 1, USERDATA_TAG) ;
    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, CGEventGetFlags(event)) ;
    } else {
        CGEventSetFlags(event, (CGEventFlags)(lua_tointeger(L, 2))) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int event_copy(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    CGEventRef event = get_cfobjectFromUserdata(CGEventRef, L, 1, USERDATA_TAG) ;
    CGEventRef copy  = CGEventCreateCopy(event);
    pushCGEventRef(L, copy) ;
    CFRelease(copy);
    return 1;
}

static int event_property(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    CGEventRef event = get_cfobjectFromUserdata(CGEventRef, L, 1, USERDATA_TAG) ;
    CGEventField field = (CGEventField)(lua_tointeger(L, 2)) ;
    BOOL useInteger = YES ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wswitch-enum"
    switch(field) {
#pragma clang diagnostic pop
        case kCGMouseEventPressure:
        case kCGScrollWheelEventFixedPtDeltaAxis1:
        case kCGScrollWheelEventFixedPtDeltaAxis2:
        case kCGScrollWheelEventFixedPtDeltaAxis3:
        case kCGTabletEventPointPressure:
        case kCGTabletEventTiltX:
        case kCGTabletEventTiltY:
        case kCGTabletEventRotation:
        case kCGTabletEventTangentialPressure:
            useInteger = NO ;
        default:
            break ;
    }
    if (lua_gettop(L) == 2) {
        if (useInteger) {
            lua_pushinteger(L, CGEventGetIntegerValueField(event, field)) ;
        } else {
            lua_pushnumber(L, CGEventGetDoubleValueField(event, field)) ;
        }
    } else {
        if (useInteger) {
            CGEventSetIntegerValueField(event, field, lua_tointeger(L, 3)) ;
        } else {
            CGEventSetDoubleValueField(event, field, lua_tonumber(L, 3)) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int event_post(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    CGEventRef event = get_cfobjectFromUserdata(CGEventRef, L, 1, USERDATA_TAG) ;
    if (lua_gettop(L) == 1) {
        CGEventPost(kCGSessionEventTap, event);
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.application", LS_TBREAK] ;
        AXUIElementRef app = *((AXUIElementRef*)luaL_checkudata(L, 2, "hs.application")) ;
        pid_t pid;
        AXUIElementGetPid(app, &pid);
        ProcessSerialNumber psn;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        GetProcessForPID(pid, &psn);
#pragma clang diagnostic pop
        CGEventPostToPSN(&psn, event);
    }
    // TODO: I don't like hardcoded delays... how much does this really help?  Should it be an argument?
    usleep(1000) ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int event_getCharacters(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    CGEventRef event = get_cfobjectFromUserdata(CGEventRef, L, 1, USERDATA_TAG) ;
    BOOL clean = (lua_gettop(L) == 2) ? (BOOL)lua_toboolean(L, 2) : NO ;
    CGEventType cgType = CGEventGetType(event) ;

    if ((cgType == kCGEventKeyDown) || (cgType == kCGEventKeyUp)) {
        if (clean) {
            [skin pushNSObject:[[NSEvent eventWithCGEvent:event] charactersIgnoringModifiers]] ;
        } else {
            [skin pushNSObject:[[NSEvent eventWithCGEvent:event] characters]] ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}

#pragma mark - Module Constants

static int push_eventTypes(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSEventTypeLeftMouseDown) ;      lua_setfield(L, -2, "leftMouseDown") ;
    lua_pushinteger(L, NSEventTypeLeftMouseUp) ;        lua_setfield(L, -2, "leftMouseUp") ;
    lua_pushinteger(L, NSEventTypeRightMouseDown) ;     lua_setfield(L, -2, "rightMouseDown") ;
    lua_pushinteger(L, NSEventTypeRightMouseUp) ;       lua_setfield(L, -2, "rightMouseUp") ;
    lua_pushinteger(L, NSEventTypeMouseMoved) ;         lua_setfield(L, -2, "mouseMoved") ;
    lua_pushinteger(L, NSEventTypeLeftMouseDragged) ;   lua_setfield(L, -2, "leftMouseDragged") ;
    lua_pushinteger(L, NSEventTypeRightMouseDragged) ;  lua_setfield(L, -2, "rightMouseDragged") ;
    lua_pushinteger(L, NSEventTypeMouseEntered) ;       lua_setfield(L, -2, "mouseEntered") ;
    lua_pushinteger(L, NSEventTypeMouseExited) ;        lua_setfield(L, -2, "mouseExited") ;
    lua_pushinteger(L, NSEventTypeKeyDown) ;            lua_setfield(L, -2, "keyDown") ;
    lua_pushinteger(L, NSEventTypeKeyUp) ;              lua_setfield(L, -2, "keyUp") ;
    lua_pushinteger(L, NSEventTypeFlagsChanged) ;       lua_setfield(L, -2, "flagsChanged") ;
    lua_pushinteger(L, NSEventTypeAppKitDefined) ;      lua_setfield(L, -2, "appKitDefined") ;
    lua_pushinteger(L, NSEventTypeSystemDefined) ;      lua_setfield(L, -2, "systemDefined") ;
    lua_pushinteger(L, NSEventTypeApplicationDefined) ; lua_setfield(L, -2, "applicationDefined") ;
    lua_pushinteger(L, NSEventTypePeriodic) ;           lua_setfield(L, -2, "periodic") ;
    lua_pushinteger(L, NSEventTypeCursorUpdate) ;       lua_setfield(L, -2, "cursorUpdate") ;
    lua_pushinteger(L, NSEventTypeRotate) ;             lua_setfield(L, -2, "rotate") ;
    lua_pushinteger(L, NSEventTypeBeginGesture) ;       lua_setfield(L, -2, "beginGesture") ;
    lua_pushinteger(L, NSEventTypeEndGesture) ;         lua_setfield(L, -2, "endGesture") ;
    lua_pushinteger(L, NSEventTypeScrollWheel) ;        lua_setfield(L, -2, "scrollWheel") ;
    lua_pushinteger(L, NSEventTypeTabletPoint) ;        lua_setfield(L, -2, "tabletPoint") ;
    lua_pushinteger(L, NSEventTypeTabletProximity) ;    lua_setfield(L, -2, "tabletProximity") ;
    lua_pushinteger(L, NSEventTypeOtherMouseDown) ;     lua_setfield(L, -2, "otherMouseDown") ;
    lua_pushinteger(L, NSEventTypeOtherMouseUp) ;       lua_setfield(L, -2, "otherMouseUp") ;
    lua_pushinteger(L, NSEventTypeOtherMouseDragged) ;  lua_setfield(L, -2, "otherMouseDragged") ;
    lua_pushinteger(L, NSEventTypeGesture) ;            lua_setfield(L, -2, "gesture") ;
    lua_pushinteger(L, NSEventTypeMagnify) ;            lua_setfield(L, -2, "magnify") ;
    lua_pushinteger(L, NSEventTypeSwipe) ;              lua_setfield(L, -2, "swipe") ;
    lua_pushinteger(L, NSEventTypeSmartMagnify) ;       lua_setfield(L, -2, "smartMagnify") ;
    lua_pushinteger(L, NSEventTypeQuickLook) ;          lua_setfield(L, -2, "quickLook") ;
    lua_pushinteger(L, NSEventTypePressure) ;           lua_setfield(L, -2, "pressure") ;
    lua_pushinteger(L, NSEventTypeDirectTouch) ;        lua_setfield(L, -2, "directTouch") ;
    return 1 ;
}

static int push_eventProperties(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, kCGMouseEventNumber) ;                                        lua_setfield(L, -2, "mouseEventNumber") ;
    lua_pushinteger(L, kCGMouseEventClickState) ;                                    lua_setfield(L, -2, "mouseEventClickState") ;
    lua_pushinteger(L, kCGMouseEventPressure) ;                                      lua_setfield(L, -2, "mouseEventPressure") ;
    lua_pushinteger(L, kCGMouseEventButtonNumber) ;                                  lua_setfield(L, -2, "mouseEventButtonNumber") ;
    lua_pushinteger(L, kCGMouseEventDeltaX) ;                                        lua_setfield(L, -2, "mouseEventDeltaX") ;
    lua_pushinteger(L, kCGMouseEventDeltaY) ;                                        lua_setfield(L, -2, "mouseEventDeltaY") ;
    lua_pushinteger(L, kCGMouseEventInstantMouser) ;                                 lua_setfield(L, -2, "mouseEventInstantMouser") ;
    lua_pushinteger(L, kCGMouseEventSubtype) ;                                       lua_setfield(L, -2, "mouseEventSubtype") ;
    lua_pushinteger(L, kCGKeyboardEventAutorepeat) ;                                 lua_setfield(L, -2, "keyboardEventAutorepeat") ;
    lua_pushinteger(L, kCGKeyboardEventKeycode) ;                                    lua_setfield(L, -2, "keyboardEventKeycode") ;
    lua_pushinteger(L, kCGKeyboardEventKeyboardType) ;                               lua_setfield(L, -2, "keyboardEventKeyboardType") ;
    lua_pushinteger(L, kCGScrollWheelEventDeltaAxis1) ;                              lua_setfield(L, -2, "scrollWheelEventDeltaAxis1") ;
    lua_pushinteger(L, kCGScrollWheelEventDeltaAxis2) ;                              lua_setfield(L, -2, "scrollWheelEventDeltaAxis2") ;
    lua_pushinteger(L, kCGScrollWheelEventDeltaAxis3) ;                              lua_setfield(L, -2, "scrollWheelEventDeltaAxis3") ;
    lua_pushinteger(L, kCGScrollWheelEventFixedPtDeltaAxis1) ;                       lua_setfield(L, -2, "scrollWheelEventFixedPtDeltaAxis1") ;
    lua_pushinteger(L, kCGScrollWheelEventFixedPtDeltaAxis2) ;                       lua_setfield(L, -2, "scrollWheelEventFixedPtDeltaAxis2") ;
    lua_pushinteger(L, kCGScrollWheelEventFixedPtDeltaAxis3) ;                       lua_setfield(L, -2, "scrollWheelEventFixedPtDeltaAxis3") ;
    lua_pushinteger(L, kCGScrollWheelEventPointDeltaAxis1) ;                         lua_setfield(L, -2, "scrollWheelEventPointDeltaAxis1") ;
    lua_pushinteger(L, kCGScrollWheelEventPointDeltaAxis2) ;                         lua_setfield(L, -2, "scrollWheelEventPointDeltaAxis2") ;
    lua_pushinteger(L, kCGScrollWheelEventPointDeltaAxis3) ;                         lua_setfield(L, -2, "scrollWheelEventPointDeltaAxis3") ;
    lua_pushinteger(L, kCGScrollWheelEventScrollPhase) ;                             lua_setfield(L, -2, "scrollWheelEventScrollPhase") ;
    lua_pushinteger(L, kCGScrollWheelEventScrollCount) ;                             lua_setfield(L, -2, "scrollWheelEventScrollCount") ;
    lua_pushinteger(L, kCGScrollWheelEventMomentumPhase) ;                           lua_setfield(L, -2, "scrollWheelEventMomentumPhase") ;
    lua_pushinteger(L, kCGScrollWheelEventInstantMouser) ;                           lua_setfield(L, -2, "scrollWheelEventInstantMouser") ;
    lua_pushinteger(L, kCGTabletEventPointX) ;                                       lua_setfield(L, -2, "tabletEventPointX") ;
    lua_pushinteger(L, kCGTabletEventPointY) ;                                       lua_setfield(L, -2, "tabletEventPointY") ;
    lua_pushinteger(L, kCGTabletEventPointZ) ;                                       lua_setfield(L, -2, "tabletEventPointZ") ;
    lua_pushinteger(L, kCGTabletEventPointButtons) ;                                 lua_setfield(L, -2, "tabletEventPointButtons") ;
    lua_pushinteger(L, kCGTabletEventPointPressure) ;                                lua_setfield(L, -2, "tabletEventPointPressure") ;
    lua_pushinteger(L, kCGTabletEventTiltX) ;                                        lua_setfield(L, -2, "tabletEventTiltX") ;
    lua_pushinteger(L, kCGTabletEventTiltY) ;                                        lua_setfield(L, -2, "tabletEventTiltY") ;
    lua_pushinteger(L, kCGTabletEventRotation) ;                                     lua_setfield(L, -2, "tabletEventRotation") ;
    lua_pushinteger(L, kCGTabletEventTangentialPressure) ;                           lua_setfield(L, -2, "tabletEventTangentialPressure") ;
    lua_pushinteger(L, kCGTabletEventDeviceID) ;                                     lua_setfield(L, -2, "tabletEventDeviceID") ;
    lua_pushinteger(L, kCGTabletEventVendor1) ;                                      lua_setfield(L, -2, "tabletEventVendor1") ;
    lua_pushinteger(L, kCGTabletEventVendor2) ;                                      lua_setfield(L, -2, "tabletEventVendor2") ;
    lua_pushinteger(L, kCGTabletEventVendor3) ;                                      lua_setfield(L, -2, "tabletEventVendor3") ;
    lua_pushinteger(L, kCGTabletProximityEventVendorID) ;                            lua_setfield(L, -2, "tabletProximityEventVendorID") ;
    lua_pushinteger(L, kCGTabletProximityEventTabletID) ;                            lua_setfield(L, -2, "tabletProximityEventTabletID") ;
    lua_pushinteger(L, kCGTabletProximityEventPointerID) ;                           lua_setfield(L, -2, "tabletProximityEventPointerID") ;
    lua_pushinteger(L, kCGTabletProximityEventDeviceID) ;                            lua_setfield(L, -2, "tabletProximityEventDeviceID") ;
    lua_pushinteger(L, kCGTabletProximityEventSystemTabletID) ;                      lua_setfield(L, -2, "tabletProximityEventSystemTabletID") ;
    lua_pushinteger(L, kCGTabletProximityEventVendorPointerType) ;                   lua_setfield(L, -2, "tabletProximityEventVendorPointerType") ;
    lua_pushinteger(L, kCGTabletProximityEventVendorPointerSerialNumber) ;           lua_setfield(L, -2, "tabletProximityEventVendorPointerSerialNumber") ;
    lua_pushinteger(L, kCGTabletProximityEventVendorUniqueID) ;                      lua_setfield(L, -2, "tabletProximityEventVendorUniqueID") ;
    lua_pushinteger(L, kCGTabletProximityEventCapabilityMask) ;                      lua_setfield(L, -2, "tabletProximityEventCapabilityMask") ;
    lua_pushinteger(L, kCGTabletProximityEventPointerType) ;                         lua_setfield(L, -2, "tabletProximityEventPointerType") ;
    lua_pushinteger(L, kCGTabletProximityEventEnterProximity) ;                      lua_setfield(L, -2, "tabletProximityEventEnterProximity") ;
    lua_pushinteger(L, kCGEventTargetProcessSerialNumber) ;                          lua_setfield(L, -2, "eventTargetProcessSerialNumber") ;
    lua_pushinteger(L, kCGEventTargetUnixProcessID) ;                                lua_setfield(L, -2, "eventTargetUnixProcessID") ;
    lua_pushinteger(L, kCGEventSourceUnixProcessID) ;                                lua_setfield(L, -2, "eventSourceUnixProcessID") ;
    lua_pushinteger(L, kCGEventSourceUserData) ;                                     lua_setfield(L, -2, "eventSourceUserData") ;
    lua_pushinteger(L, kCGEventSourceUserID) ;                                       lua_setfield(L, -2, "eventSourceUserID") ;
    lua_pushinteger(L, kCGEventSourceGroupID) ;                                      lua_setfield(L, -2, "eventSourceGroupID") ;
    lua_pushinteger(L, kCGEventSourceStateID) ;                                      lua_setfield(L, -2, "eventSourceStateID") ;
    lua_pushinteger(L, kCGScrollWheelEventIsContinuous) ;                            lua_setfield(L, -2, "scrollWheelEventIsContinuous") ;
    lua_pushinteger(L, kCGMouseEventWindowUnderMousePointer) ;                       lua_setfield(L, -2, "mouseEventWindowUnderMousePointer") ;
    lua_pushinteger(L, kCGMouseEventWindowUnderMousePointerThatCanHandleThisEvent) ; lua_setfield(L, -2, "mouseEventWindowUnderMousePointerThatCanHandleThisEvent") ;
    return 1 ;
}

static int push_flagMasks(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NX_ALPHASHIFTMASK) ;                   lua_setfield(L, -2, "alphaShift") ;
    lua_pushinteger(L, NX_SHIFTMASK) ;                        lua_setfield(L, -2, "shift") ;
    lua_pushinteger(L, NX_CONTROLMASK) ;                      lua_setfield(L, -2, "control") ;
    lua_pushinteger(L, NX_ALTERNATEMASK) ;                    lua_setfield(L, -2, "alternate") ;
    lua_pushinteger(L, NX_COMMANDMASK) ;                      lua_setfield(L, -2, "command") ;
    lua_pushinteger(L, NX_NUMERICPADMASK) ;                   lua_setfield(L, -2, "numericPad") ;
    lua_pushinteger(L, NX_HELPMASK) ;                         lua_setfield(L, -2, "help") ;
    lua_pushinteger(L, NX_SECONDARYFNMASK) ;                  lua_setfield(L, -2, "secondaryFn") ;
    lua_pushinteger(L, NX_DEVICELCTLKEYMASK) ;                lua_setfield(L, -2, "deviceLeftControl") ;
    lua_pushinteger(L, NX_DEVICERCTLKEYMASK) ;                lua_setfield(L, -2, "deviceRightControl") ;
    lua_pushinteger(L, NX_DEVICELSHIFTKEYMASK) ;              lua_setfield(L, -2, "deviceLeftShift") ;
    lua_pushinteger(L, NX_DEVICERSHIFTKEYMASK) ;              lua_setfield(L, -2, "deviceRightShift") ;
    lua_pushinteger(L, NX_DEVICELCMDKEYMASK) ;                lua_setfield(L, -2, "deviceLeftCommand") ;
    lua_pushinteger(L, NX_DEVICERCMDKEYMASK) ;                lua_setfield(L, -2, "deviceRightCommand") ;
    lua_pushinteger(L, NX_DEVICELALTKEYMASK) ;                lua_setfield(L, -2, "deviceLeftAlternate") ;
    lua_pushinteger(L, NX_DEVICERALTKEYMASK) ;                lua_setfield(L, -2, "deviceRightAlternate") ;
    lua_pushinteger(L, NX_ALPHASHIFT_STATELESS_MASK) ;        lua_setfield(L, -2, "alphaShiftStateless") ;
    lua_pushinteger(L, NX_DEVICE_ALPHASHIFT_STATELESS_MASK) ; lua_setfield(L, -2, "deviceAlphaShiftStateless") ;
    lua_pushinteger(L, NX_NONCOALSESCEDMASK) ;                lua_setfield(L, -2, "nonCoalesced") ;
    return 1 ;
}

static int push_unicodeFunctionKeys(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSUpArrowFunctionKey) ;      lua_setfield(L, -2, "UpArrow") ;
    lua_pushinteger(L, NSDownArrowFunctionKey) ;    lua_setfield(L, -2, "DownArrow") ;
    lua_pushinteger(L, NSLeftArrowFunctionKey) ;    lua_setfield(L, -2, "LeftArrow") ;
    lua_pushinteger(L, NSRightArrowFunctionKey) ;   lua_setfield(L, -2, "RightArrow") ;
    lua_pushinteger(L, NSF1FunctionKey) ;           lua_setfield(L, -2, "F1") ;
    lua_pushinteger(L, NSF2FunctionKey) ;           lua_setfield(L, -2, "F2") ;
    lua_pushinteger(L, NSF3FunctionKey) ;           lua_setfield(L, -2, "F3") ;
    lua_pushinteger(L, NSF4FunctionKey) ;           lua_setfield(L, -2, "F4") ;
    lua_pushinteger(L, NSF5FunctionKey) ;           lua_setfield(L, -2, "F5") ;
    lua_pushinteger(L, NSF6FunctionKey) ;           lua_setfield(L, -2, "F6") ;
    lua_pushinteger(L, NSF7FunctionKey) ;           lua_setfield(L, -2, "F7") ;
    lua_pushinteger(L, NSF8FunctionKey) ;           lua_setfield(L, -2, "F8") ;
    lua_pushinteger(L, NSF9FunctionKey) ;           lua_setfield(L, -2, "F9") ;
    lua_pushinteger(L, NSF10FunctionKey) ;          lua_setfield(L, -2, "F10") ;
    lua_pushinteger(L, NSF11FunctionKey) ;          lua_setfield(L, -2, "F11") ;
    lua_pushinteger(L, NSF12FunctionKey) ;          lua_setfield(L, -2, "F12") ;
    lua_pushinteger(L, NSF13FunctionKey) ;          lua_setfield(L, -2, "F13") ;
    lua_pushinteger(L, NSF14FunctionKey) ;          lua_setfield(L, -2, "F14") ;
    lua_pushinteger(L, NSF15FunctionKey) ;          lua_setfield(L, -2, "F15") ;
    lua_pushinteger(L, NSF16FunctionKey) ;          lua_setfield(L, -2, "F16") ;
    lua_pushinteger(L, NSF17FunctionKey) ;          lua_setfield(L, -2, "F17") ;
    lua_pushinteger(L, NSF18FunctionKey) ;          lua_setfield(L, -2, "F18") ;
    lua_pushinteger(L, NSF19FunctionKey) ;          lua_setfield(L, -2, "F19") ;
    lua_pushinteger(L, NSF20FunctionKey) ;          lua_setfield(L, -2, "F20") ;
    lua_pushinteger(L, NSF21FunctionKey) ;          lua_setfield(L, -2, "F21") ;
    lua_pushinteger(L, NSF22FunctionKey) ;          lua_setfield(L, -2, "F22") ;
    lua_pushinteger(L, NSF23FunctionKey) ;          lua_setfield(L, -2, "F23") ;
    lua_pushinteger(L, NSF24FunctionKey) ;          lua_setfield(L, -2, "F24") ;
    lua_pushinteger(L, NSF25FunctionKey) ;          lua_setfield(L, -2, "F25") ;
    lua_pushinteger(L, NSF26FunctionKey) ;          lua_setfield(L, -2, "F26") ;
    lua_pushinteger(L, NSF27FunctionKey) ;          lua_setfield(L, -2, "F27") ;
    lua_pushinteger(L, NSF28FunctionKey) ;          lua_setfield(L, -2, "F28") ;
    lua_pushinteger(L, NSF29FunctionKey) ;          lua_setfield(L, -2, "F29") ;
    lua_pushinteger(L, NSF30FunctionKey) ;          lua_setfield(L, -2, "F30") ;
    lua_pushinteger(L, NSF31FunctionKey) ;          lua_setfield(L, -2, "F31") ;
    lua_pushinteger(L, NSF32FunctionKey) ;          lua_setfield(L, -2, "F32") ;
    lua_pushinteger(L, NSF33FunctionKey) ;          lua_setfield(L, -2, "F33") ;
    lua_pushinteger(L, NSF34FunctionKey) ;          lua_setfield(L, -2, "F34") ;
    lua_pushinteger(L, NSF35FunctionKey) ;          lua_setfield(L, -2, "F35") ;
    lua_pushinteger(L, NSInsertFunctionKey) ;       lua_setfield(L, -2, "Insert") ;
    lua_pushinteger(L, NSDeleteFunctionKey) ;       lua_setfield(L, -2, "Delete") ;
    lua_pushinteger(L, NSHomeFunctionKey) ;         lua_setfield(L, -2, "Home") ;
    lua_pushinteger(L, NSBeginFunctionKey) ;        lua_setfield(L, -2, "Begin") ;
    lua_pushinteger(L, NSEndFunctionKey) ;          lua_setfield(L, -2, "End") ;
    lua_pushinteger(L, NSPageUpFunctionKey) ;       lua_setfield(L, -2, "PageUp") ;
    lua_pushinteger(L, NSPageDownFunctionKey) ;     lua_setfield(L, -2, "PageDown") ;
    lua_pushinteger(L, NSPrintScreenFunctionKey) ;  lua_setfield(L, -2, "PrintScreen") ;
    lua_pushinteger(L, NSScrollLockFunctionKey) ;   lua_setfield(L, -2, "ScrollLock") ;
    lua_pushinteger(L, NSPauseFunctionKey) ;        lua_setfield(L, -2, "Pause") ;
    lua_pushinteger(L, NSSysReqFunctionKey) ;       lua_setfield(L, -2, "SysReq") ;
    lua_pushinteger(L, NSBreakFunctionKey) ;        lua_setfield(L, -2, "Break") ;
    lua_pushinteger(L, NSResetFunctionKey) ;        lua_setfield(L, -2, "Reset") ;
    lua_pushinteger(L, NSStopFunctionKey) ;         lua_setfield(L, -2, "Stop") ;
    lua_pushinteger(L, NSMenuFunctionKey) ;         lua_setfield(L, -2, "Menu") ;
    lua_pushinteger(L, NSUserFunctionKey) ;         lua_setfield(L, -2, "User") ;
    lua_pushinteger(L, NSSystemFunctionKey) ;       lua_setfield(L, -2, "System") ;
    lua_pushinteger(L, NSPrintFunctionKey) ;        lua_setfield(L, -2, "Print") ;
    lua_pushinteger(L, NSClearLineFunctionKey) ;    lua_setfield(L, -2, "ClearLine") ;
    lua_pushinteger(L, NSClearDisplayFunctionKey) ; lua_setfield(L, -2, "ClearDisplay") ;
    lua_pushinteger(L, NSInsertLineFunctionKey) ;   lua_setfield(L, -2, "InsertLine") ;
    lua_pushinteger(L, NSDeleteLineFunctionKey) ;   lua_setfield(L, -2, "DeleteLine") ;
    lua_pushinteger(L, NSInsertCharFunctionKey) ;   lua_setfield(L, -2, "InsertChar") ;
    lua_pushinteger(L, NSDeleteCharFunctionKey) ;   lua_setfield(L, -2, "DeleteChar") ;
    lua_pushinteger(L, NSPrevFunctionKey) ;         lua_setfield(L, -2, "Prev") ;
    lua_pushinteger(L, NSNextFunctionKey) ;         lua_setfield(L, -2, "Next") ;
    lua_pushinteger(L, NSSelectFunctionKey) ;       lua_setfield(L, -2, "Select") ;
    lua_pushinteger(L, NSExecuteFunctionKey) ;      lua_setfield(L, -2, "Execute") ;
    lua_pushinteger(L, NSUndoFunctionKey) ;         lua_setfield(L, -2, "Undo") ;
    lua_pushinteger(L, NSRedoFunctionKey) ;         lua_setfield(L, -2, "Redo") ;
    lua_pushinteger(L, NSFindFunctionKey) ;         lua_setfield(L, -2, "Find") ;
    lua_pushinteger(L, NSHelpFunctionKey) ;         lua_setfield(L, -2, "Help") ;
    lua_pushinteger(L, NSModeSwitchFunctionKey) ;   lua_setfield(L, -2, "ModeSwitch") ;
    return 1 ;
}

#pragma mark - Lua<->CFObject Conversion Functions

static int pushCGEventRef(lua_State *L, CGEventRef event) {
    CFRetain(event) ;
    *(CGEventRef*)lua_newuserdata(L, sizeof(CGEventRef*)) = event ;
    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    CGEventRef event = get_cfobjectFromUserdata(CGEventRef, L, 1, USERDATA_TAG) ;
    CGEventType eventType = CGEventGetType(event) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: type: %d (%p)", USERDATA_TAG, eventType, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State *L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        CGEventRef event1 = get_cfobjectFromUserdata(CGEventRef, L, 1, USERDATA_TAG) ;
        CGEventRef event2 = get_cfobjectFromUserdata(CGEventRef, L, 2, USERDATA_TAG) ;
        lua_pushboolean(L, CFEqual(event1, event2)) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State *L) {
    CGEventRef event = get_cfobjectFromUserdata(CGEventRef, L, 1, USERDATA_TAG) ;
    if (event) {
        CFRelease(event) ;
        event = NULL ;
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(__unused lua_State *L) {
    if (eventSource) {
        CFRelease(eventSource) ;
        eventSource = NULL ;
    }
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"type",          event_type},
    {"timestamp",     event_timestamp},
    {"location",      event_location},
    {"flags",         event_flags},
    {"copy",          event_copy},
    {"property",      event_property},
    {"post",          event_post},
    {"getCharacters", event_getCharacters},

    {"__tostring",    userdata_tostring},
    {"__eq",          userdata_eq},
    {"__gc",          userdata_gc},
    {NULL,            NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"createEvent",            event_createEvent},
    {"createMouseEvent",       event_createMouseEvent},
    {"createKeyEvent",         event_createKeyEvent},
    {"createScrollWheelEvent", event_createScrollWheelEvent},

    {"modifierFlags",          event_modifierFlags},
    {"keyRepeatDelay",         event_keyRepeatDelay},
    {"keyRepeatInterval",      event_keyRepeatInterval},
    {"pressedMouseButtons",    event_pressedMouseButtons},
    {"doubleClickInterval",    event_doubleClickInterval},
    {"mouseLocation",          event_mouseLocation},
    {"swipeTracking",          event_swipeTracking},

    {"absoluteTime",           event_absoluteTime},
    {"mouseCoallescing",       event_mouseCoallescing},
    {"startPeriodicEvents",    event_startPeriodicEvents},
    {"stopPeriodicEvents",     event_stopPeriodicEvents},

    {NULL, NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs_event_internal(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    eventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);

//     [skin registerPushNSHelper:push<moduleType>         forClass:"<moduleType>"];

// // one, but not both, of...
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"
//                                              withUserdataMapping:USERDATA_TAG];
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"];

    push_eventTypes(L) ;          lua_setfield(L, -2, "types") ;
    push_eventProperties(L) ;     lua_setfield(L, -2, "properties") ;
    push_flagMasks(L) ;           lua_setfield(L, -2, "flagMasks") ;
    push_unicodeFunctionKeys(L) ; lua_setfield(L, -2, "unicodeFunctionKeys") ;

    return 1;
}
