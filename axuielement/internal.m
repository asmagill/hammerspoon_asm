#import <Cocoa/Cocoa.h>
// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#import <CoreMedia/CoreMedia.h>
#import <DiscRecording/DiscRecording.h>
#import <GLKit/GLKit.h>
#import <IOKit/hid/IOHIDLib.h>
#import <LatentSemanticMapping/LatentSemanticMapping.h>
#import <MediaToolbox/MediaToolbox.h>
#import <OpenDirectory/OpenDirectory.h>
#import <VideoToolbox/VideoToolbox.h>

#define USERDATA_TAG        "hs._asm.axuielement"
int refTable ;

// #define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

#define get_axuielementref(L, idx, tag) *((AXUIElementRef*)luaL_checkudata(L, idx, tag))

static int pushAXUIElement(lua_State *L, AXUIElementRef theElement) {
    AXUIElementRef* thePtr = lua_newuserdata(L, sizeof(AXUIElementRef));
    *thePtr = CFRetain(theElement) ;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1 ;
}

const char *AXErrorAsString(AXError theError) {
    const char *ans ;
    switch(theError) {
        case kAXErrorSuccess:                           ans = "No error occurred" ; break ;
        case kAXErrorFailure:                           ans = "A system error occurred" ; break ;
        case kAXErrorIllegalArgument:                   ans = "Illegal argument." ; break ;
        case kAXErrorInvalidUIElement:                  ans = "AXUIElementRef is invalid." ; break ;
        case kAXErrorInvalidUIElementObserver:          ans = "Not a valid observer." ; break ;
        case kAXErrorCannotComplete:                    ans = "Messaging failed." ; break ;
        case kAXErrorAttributeUnsupported:              ans = "Attribute is not supported by target." ; break ;
        case kAXErrorActionUnsupported:                 ans = "Action is not supported by target." ; break ;
        case kAXErrorNotificationUnsupported:           ans = "Notification is not supported by target." ; break ;
        case kAXErrorNotImplemented:                    ans = "Function or method not implemented." ; break ;
        case kAXErrorNotificationAlreadyRegistered:     ans = "Notification has already been registered." ; break ;
        case kAXErrorNotificationNotRegistered:         ans = "Notification is not registered yet." ; break ;
        case kAXErrorAPIDisabled:                       ans = "The accessibility API is disabled" ; break ;
        case kAXErrorNoValue:                           ans = "Requested value does not exist." ; break ;
        case kAXErrorParameterizedAttributeUnsupported: ans = "Parameterized attribute is not supported." ; break ;
        case kAXErrorNotEnoughPrecision:                ans = "Not enough precision." ; break ;
        default:                                        ans = "Unrecognized error occured." ; break ;
    }
    return ans ;
}

static int getWindowElement(lua_State *L)      { return pushAXUIElement(L, get_axuielementref(L, 1, "hs.window")) ; }
static int getApplicationElement(lua_State *L) { return pushAXUIElement(L, get_axuielementref(L, 1, "hs.application")) ; }

static int getAttributeNames(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFArrayRef attributeNames ;
    AXError errorState = AXUIElementCopyAttributeNames(theRef, &attributeNames) ;
    if (errorState == kAXErrorSuccess) {
        lua_newtable(L) ;
        for (id value in (__bridge NSArray *)attributeNames) {
            [[LuaSkin shared] pushNSObject:value] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        CFRelease(attributeNames) ;
    } else {
        if (attributeNames) CFRelease(attributeNames) ;
        return luaL_error(L, "attributeNames:AXError %d: %s", errorState, AXErrorAsString(errorState)) ;
    }
    return 1 ;
}

static int getActionNames(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFArrayRef attributeNames ;
    AXError errorState = AXUIElementCopyActionNames(theRef, &attributeNames) ;
    if (errorState == kAXErrorSuccess) {
        lua_newtable(L) ;
        for (id value in (__bridge NSArray *)attributeNames) {
            [[LuaSkin shared] pushNSObject:value] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        CFRelease(attributeNames) ;
    } else {
        if (attributeNames) CFRelease(attributeNames) ;
        return luaL_error(L, "actionNames:AXError %d: %s", errorState, AXErrorAsString(errorState)) ;
    }
    return 1 ;
}

static int getActionDescription(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *action = [[LuaSkin shared] toNSObjectAtIndex:2] ;
    CFStringRef description ;
    AXError errorState = AXUIElementCopyActionDescription(theRef, (__bridge CFStringRef)action, &description) ;
    if (errorState == kAXErrorSuccess) {
        [[LuaSkin shared] pushNSObject:(__bridge NSString *)description] ;
        CFRelease(description) ;
    } else {
        if (description) CFRelease(description) ;
        return luaL_error(L, "actionDescription:AXError %d: %s", errorState, AXErrorAsString(errorState)) ;
    }
    return 1 ;
}

// Not sure if the alreadySeen trick is working here, but it hasn't crashed yet... of course I don't think I've
// found any loops that don't have a userdata object in-between that drops us back to Lua before deciding whether
// or not to delve deeper, either, so...
static int CFTypeMonkey(lua_State *L, CFTypeRef theItem, NSMutableDictionary *alreadySeen) {
    if ([alreadySeen objectForKey:(__bridge id)theItem]) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:(__bridge id)theItem] intValue]) ;
        return 1 ;
    }

    CFTypeID theType = CFGetTypeID(theItem) ;
    if      (theType == CFArrayGetTypeID()) {
        lua_newtable(L);
        [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(L, LUA_REGISTRYINDEX)] forKey:(__bridge id)theItem] ;
        lua_rawgeti(L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:(__bridge id)theItem] intValue]) ; // put it back on the stack
        for(id thing in (__bridge NSArray *)theItem) {
            CFTypeMonkey(L, (__bridge CFTypeRef)thing, alreadySeen) ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else if (theType == CFDictionaryGetTypeID()) {
        lua_newtable(L);
        [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(L, LUA_REGISTRYINDEX)] forKey:(__bridge id)theItem] ;
        lua_rawgeti(L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:(__bridge id)theItem] intValue]) ; // put it back on the stack
        NSArray *keys = [(__bridge NSDictionary *)theItem allKeys];
        NSArray *values = [(__bridge NSDictionary *)theItem allValues];
        for (unsigned long i = 0; i < [keys count]; i++) {
            CFTypeMonkey(L, (__bridge CFTypeRef)[keys objectAtIndex:i], alreadySeen) ;
            CFTypeMonkey(L, (__bridge CFTypeRef)[values objectAtIndex:i], alreadySeen) ;
            lua_settable(L, -3);
        }
    } else if (theType == AXValueGetTypeID()) {
        switch(AXValueGetType((AXValueRef)theItem)) {
            case kAXValueCGPointType: {
                CGPoint thePoint ;
                AXValueGetValue((AXValueRef)theItem, kAXValueCGPointType, &thePoint);
                lua_newtable(L) ;
                  lua_pushnumber(L, thePoint.x) ; lua_setfield(L, -2, "x") ;
                  lua_pushnumber(L, thePoint.x) ; lua_setfield(L, -2, "y") ;
                break ;
            }
            case kAXValueCGSizeType: {
                CGSize theSize ;
                AXValueGetValue((AXValueRef)theItem, kAXValueCGSizeType, &theSize);
                lua_newtable(L) ;
                  lua_pushnumber(L, theSize.height) ; lua_setfield(L, -2, "h") ;
                  lua_pushnumber(L, theSize.width) ;  lua_setfield(L, -2, "w") ;
                break ;
            }
            case kAXValueCGRectType: {
                CGRect theRect ;
                AXValueGetValue((AXValueRef)theItem, kAXValueCGRectType, &theRect);
                lua_newtable(L) ;
                  lua_pushnumber(L, theRect.origin.x) ;    lua_setfield(L, -2, "x") ;
                  lua_pushnumber(L, theRect.origin.x) ;    lua_setfield(L, -2, "y") ;
                  lua_pushnumber(L, theRect.size.height) ; lua_setfield(L, -2, "h") ;
                  lua_pushnumber(L, theRect.size.width) ;  lua_setfield(L, -2, "w") ;
                break ;
            }
            case kAXValueCFRangeType: {
                CFRange theRange ;
                AXValueGetValue((AXValueRef)theItem, kAXValueCFRangeType, &theRange);
                lua_newtable(L) ;
                  lua_pushinteger(L, theRange.location) ; lua_setfield(L, -2, "location") ;
                  lua_pushinteger(L, theRange.length) ;   lua_setfield(L, -2, "length") ;
                break ;
            }
            case kAXValueAXErrorType: {
                AXError theError ;
                AXValueGetValue((AXValueRef)theItem, kAXValueAXErrorType, &theError);
                lua_newtable(L) ;
                  lua_pushinteger(L, theError) ;                 lua_setfield(L, -2, "code") ;
                  lua_pushstring(L, AXErrorAsString(theError)) ; lua_setfield(L, -2, "error") ;
                break ;
            }
            case kAXValueIllegalType:
            default:
                lua_pushfstring(L, "unrecognized value type (%p)", theItem) ;
                break ;
        }
    } else if (theType == CFAttributedStringGetTypeID()) [[LuaSkin shared] pushNSObject:(__bridge NSAttributedString *)theItem] ;
      else if (theType == CFNullGetTypeID())             [[LuaSkin shared] pushNSObject:(__bridge NSNull *)theItem] ;
      else if (theType == CFBooleanGetTypeID() || theType == CFNumberGetTypeID())
                                                         [[LuaSkin shared] pushNSObject:(__bridge NSNumber *)theItem] ;
      else if (theType == CFDataGetTypeID())             [[LuaSkin shared] pushNSObject:(__bridge NSData *)theItem] ;
      else if (theType == CFDateGetTypeID())             [[LuaSkin shared] pushNSObject:(__bridge NSDate *)theItem] ;
      else if (theType == CFStringGetTypeID())           [[LuaSkin shared] pushNSObject:(__bridge NSString *)theItem] ;
      else if (theType == CFURLGetTypeID())              [[LuaSkin shared] pushNSObject:(__bridge_transfer NSString *)CFRetain(CFURLGetString(theItem))] ;
      else if (theType == AXUIElementGetTypeID())        pushAXUIElement(L, theItem) ;
      else                                               lua_pushfstring(L, "unrecognized type %d", CFGetTypeID(theItem)) ;
    return 1 ;
}

static int pushCFTypeToLua(lua_State *L, CFTypeRef theItem) {
    NSMutableDictionary *alreadySeen = [[NSMutableDictionary alloc] init] ;
    CFTypeMonkey(L, theItem, alreadySeen) ;
    for (id entry in alreadySeen) {
        luaL_unref(L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:entry] intValue]) ;
    }
    return 1 ;
}

static int getAttributeValue(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *attribute = [[LuaSkin shared] toNSObjectAtIndex:2] ;
    CFTypeRef value ;
    AXError errorState = AXUIElementCopyAttributeValue(theRef, (__bridge CFStringRef)attribute, &value) ;
    if (errorState == kAXErrorSuccess) {
        pushCFTypeToLua(L, value) ;
        CFRelease(value) ;
    } else {
        if (value) CFRelease(value) ;
        return luaL_error(L, "attributeValue:AXError %d: %s", errorState, AXErrorAsString(errorState)) ;
    }
    return 1 ;
}

static int getSystemWideElement(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    return pushAXUIElement(L, AXUIElementCreateSystemWide()) ;
}

static int getAttributeValueCount(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *attribute = [[LuaSkin shared] toNSObjectAtIndex:2] ;
    CFIndex count ;
    AXError errorState = AXUIElementGetAttributeValueCount(theRef, (__bridge CFStringRef)attribute, &count) ;
    if (errorState == kAXErrorSuccess) {
        lua_pushinteger(L, count) ;
    } else {
        return luaL_error(L, "attributeValueCount:AXError %d: %s", errorState, AXErrorAsString(errorState)) ;
    }
    return 1 ;
}

static int getParameterizedAttributeNames(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFArrayRef attributeNames ;
    AXError errorState = AXUIElementCopyParameterizedAttributeNames(theRef, &attributeNames) ;
    if (errorState == kAXErrorSuccess) {
        lua_newtable(L) ;
        for (id value in (__bridge NSArray *)attributeNames) {
            [[LuaSkin shared] pushNSObject:value] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        CFRelease(attributeNames) ;
    } else {
        if (attributeNames) CFRelease(attributeNames) ;
        return luaL_error(L, "parameterizedAttributeNames:AXError %d: %s", errorState, AXErrorAsString(errorState)) ;
    }
    return 1 ;
}

static int isAttributeSettable(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *attribute = [[LuaSkin shared] toNSObjectAtIndex:2] ;
    Boolean settable ;
    AXError errorState = AXUIElementIsAttributeSettable(theRef, (__bridge CFStringRef)attribute, &settable) ;
    if (errorState == kAXErrorSuccess) {
        lua_pushboolean(L, settable) ;
    } else {
        return luaL_error(L, "isAttributeSettable:AXError %d: %s", errorState, AXErrorAsString(errorState)) ;
    }
    return 1 ;
}

static int getPid(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    pid_t thePid ;
    AXError errorState = AXUIElementGetPid(theRef, &thePid) ;
    if (errorState == kAXErrorSuccess) {
        lua_pushinteger(L, (lua_Integer)thePid) ;
    } else {
        return luaL_error(L, "pid:AXError %d: %s", errorState, AXErrorAsString(errorState)) ;
    }
    return 1 ;
}

static int performAction(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *action = [[LuaSkin shared] toNSObjectAtIndex:2] ;
    AXError errorState = AXUIElementPerformAction(theRef, (__bridge CFStringRef)action) ;
    if (errorState == kAXErrorSuccess) {
        lua_pushboolean(L, YES) ;
    } else if (errorState == kAXErrorCannotComplete) {
        lua_pushboolean(L, NO) ;
    } else {
        return luaL_error(L, "performAction:AXError %d: %s", errorState, AXErrorAsString(errorState)) ;
    }
    return 1 ;
}

// AXError AXUIElementCopyElementAtPosition ( AXUIElementRef application, float x, float y, AXUIElementRef *element);

// AXError AXUIElementCopyParameterizedAttributeValue ( AXUIElementRef element, CFStringRef parameterizedAttribute, CFTypeRef parameter, CFTypeRef *result) ;
// AXError AXUIElementSetAttributeValue ( AXUIElementRef element, CFStringRef attribute, CFTypeRef value);
// AXError AXUIElementSetMessagingTimeout ( AXUIElementRef element, float timeoutInSeconds) ;


// Because I may want to generalize this as a CFType converter someday, I should keep a list
// of the types possible around.  If something comes up that doesn't have a clean converter,
// at least I can figure out what it is and make a decision...
static int definedTypes(lua_State *L) {
    lua_newtable(L) ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      lua_pushinteger(L, (lua_Integer)ColorSyncCMMGetTypeID()) ; lua_setfield(L, -2, "ColorSyncCMM") ;
      lua_pushinteger(L, (lua_Integer)ColorSyncProfileGetTypeID()) ; lua_setfield(L, -2, "ColorSyncProfile") ;
      lua_pushinteger(L, (lua_Integer)ColorSyncTransformGetTypeID()) ; lua_setfield(L, -2, "ColorSyncTransform") ;
      lua_pushinteger(L, (lua_Integer)AXUIElementGetTypeID()) ; lua_setfield(L, -2, "AXUIElement") ;
      lua_pushinteger(L, (lua_Integer)AXValueGetTypeID()) ; lua_setfield(L, -2, "AXValue") ;
      lua_pushinteger(L, (lua_Integer)AXObserverGetTypeID()) ; lua_setfield(L, -2, "AXObserver") ;
      lua_pushinteger(L, (lua_Integer)CFArrayGetTypeID()) ; lua_setfield(L, -2, "CFArray") ;
      lua_pushinteger(L, (lua_Integer)CFAttributedStringGetTypeID()) ; lua_setfield(L, -2, "CFAttributedString") ;
      lua_pushinteger(L, (lua_Integer)CFBagGetTypeID()) ; lua_setfield(L, -2, "CFBag") ;
      lua_pushinteger(L, (lua_Integer)CFNullGetTypeID()) ; lua_setfield(L, -2, "CFNull") ;
      lua_pushinteger(L, (lua_Integer)CFAllocatorGetTypeID()) ; lua_setfield(L, -2, "CFAllocator") ;
      lua_pushinteger(L, (lua_Integer)CFBinaryHeapGetTypeID()) ; lua_setfield(L, -2, "CFBinaryHeap") ;
      lua_pushinteger(L, (lua_Integer)CFBitVectorGetTypeID()) ; lua_setfield(L, -2, "CFBitVector") ;
      lua_pushinteger(L, (lua_Integer)CFBundleGetTypeID()) ; lua_setfield(L, -2, "CFBundle") ;
      lua_pushinteger(L, (lua_Integer)CFCalendarGetTypeID()) ; lua_setfield(L, -2, "CFCalendar") ;
      lua_pushinteger(L, (lua_Integer)CFCharacterSetGetTypeID()) ; lua_setfield(L, -2, "CFCharacterSet") ;
      lua_pushinteger(L, (lua_Integer)CFDataGetTypeID()) ; lua_setfield(L, -2, "CFData") ;
      lua_pushinteger(L, (lua_Integer)CFDateGetTypeID()) ; lua_setfield(L, -2, "CFDate") ;
      lua_pushinteger(L, (lua_Integer)CFDateFormatterGetTypeID()) ; lua_setfield(L, -2, "CFDateFormatter") ;
      lua_pushinteger(L, (lua_Integer)CFDictionaryGetTypeID()) ; lua_setfield(L, -2, "CFDictionary") ;
      lua_pushinteger(L, (lua_Integer)CFErrorGetTypeID()) ; lua_setfield(L, -2, "CFError") ;
      lua_pushinteger(L, (lua_Integer)CFFileDescriptorGetTypeID()) ; lua_setfield(L, -2, "CFFileDescriptor") ;
      lua_pushinteger(L, (lua_Integer)CFFileSecurityGetTypeID()) ; lua_setfield(L, -2, "CFFileSecurity") ;
      lua_pushinteger(L, (lua_Integer)CFLocaleGetTypeID()) ; lua_setfield(L, -2, "CFLocale") ;
      lua_pushinteger(L, (lua_Integer)CFMachPortGetTypeID()) ; lua_setfield(L, -2, "CFMachPort") ;
      lua_pushinteger(L, (lua_Integer)CFMessagePortGetTypeID()) ; lua_setfield(L, -2, "CFMessagePort") ;
      lua_pushinteger(L, (lua_Integer)CFNotificationCenterGetTypeID()) ; lua_setfield(L, -2, "CFNotificationCenter") ;
      lua_pushinteger(L, (lua_Integer)CFBooleanGetTypeID()) ; lua_setfield(L, -2, "CFBoolean") ;
      lua_pushinteger(L, (lua_Integer)CFNumberGetTypeID()) ; lua_setfield(L, -2, "CFNumber") ;
      lua_pushinteger(L, (lua_Integer)CFNumberFormatterGetTypeID()) ; lua_setfield(L, -2, "CFNumberFormatter") ;
      lua_pushinteger(L, (lua_Integer)CFPlugInGetTypeID()) ; lua_setfield(L, -2, "CFPlugIn") ;
      lua_pushinteger(L, (lua_Integer)CFPlugInInstanceGetTypeID()) ; lua_setfield(L, -2, "CFPlugInInstance") ;
      lua_pushinteger(L, (lua_Integer)CFRunLoopGetTypeID()) ; lua_setfield(L, -2, "CFRunLoop") ;
      lua_pushinteger(L, (lua_Integer)CFRunLoopSourceGetTypeID()) ; lua_setfield(L, -2, "CFRunLoopSource") ;
      lua_pushinteger(L, (lua_Integer)CFRunLoopObserverGetTypeID()) ; lua_setfield(L, -2, "CFRunLoopObserver") ;
      lua_pushinteger(L, (lua_Integer)CFRunLoopTimerGetTypeID()) ; lua_setfield(L, -2, "CFRunLoopTimer") ;
      lua_pushinteger(L, (lua_Integer)CFSetGetTypeID()) ; lua_setfield(L, -2, "CFSet") ;
      lua_pushinteger(L, (lua_Integer)CFSocketGetTypeID()) ; lua_setfield(L, -2, "CFSocket") ;
      lua_pushinteger(L, (lua_Integer)CFReadStreamGetTypeID()) ; lua_setfield(L, -2, "CFReadStream") ;
      lua_pushinteger(L, (lua_Integer)CFWriteStreamGetTypeID()) ; lua_setfield(L, -2, "CFWriteStream") ;
      lua_pushinteger(L, (lua_Integer)CFStringGetTypeID()) ; lua_setfield(L, -2, "CFString") ;
      lua_pushinteger(L, (lua_Integer)CFStringTokenizerGetTypeID()) ; lua_setfield(L, -2, "CFStringTokenizer") ;
      lua_pushinteger(L, (lua_Integer)CFTimeZoneGetTypeID()) ; lua_setfield(L, -2, "CFTimeZone") ;
      lua_pushinteger(L, (lua_Integer)CFTreeGetTypeID()) ; lua_setfield(L, -2, "CFTree") ;
      lua_pushinteger(L, (lua_Integer)CFURLGetTypeID()) ; lua_setfield(L, -2, "CFURL") ;
      lua_pushinteger(L, (lua_Integer)CFUserNotificationGetTypeID()) ; lua_setfield(L, -2, "CFUserNotification") ;
      lua_pushinteger(L, (lua_Integer)CFUUIDGetTypeID()) ; lua_setfield(L, -2, "CFUUID") ;
      lua_pushinteger(L, (lua_Integer)CFXMLNodeGetTypeID()) ; lua_setfield(L, -2, "CFXMLNode") ;
      lua_pushinteger(L, (lua_Integer)CFXMLParserGetTypeID()) ; lua_setfield(L, -2, "CFXMLParser") ;
      lua_pushinteger(L, (lua_Integer)CGColorGetTypeID()) ; lua_setfield(L, -2, "CGColor") ;
      lua_pushinteger(L, (lua_Integer)CGColorSpaceGetTypeID()) ; lua_setfield(L, -2, "CGColorSpace") ;
      lua_pushinteger(L, (lua_Integer)CGContextGetTypeID()) ; lua_setfield(L, -2, "CGContext") ;
      lua_pushinteger(L, (lua_Integer)CGDataConsumerGetTypeID()) ; lua_setfield(L, -2, "CGDataConsumer") ;
      lua_pushinteger(L, (lua_Integer)CGDataProviderGetTypeID()) ; lua_setfield(L, -2, "CGDataProvider") ;
      lua_pushinteger(L, (lua_Integer)CGDisplayModeGetTypeID()) ; lua_setfield(L, -2, "CGDisplayMode") ;
      lua_pushinteger(L, (lua_Integer)CGDisplayStreamUpdateGetTypeID()) ; lua_setfield(L, -2, "CGDisplayStreamUpdate") ;
      lua_pushinteger(L, (lua_Integer)CGDisplayStreamGetTypeID()) ; lua_setfield(L, -2, "CGDisplayStream") ;
      lua_pushinteger(L, (lua_Integer)CGEventGetTypeID()) ; lua_setfield(L, -2, "CGEvent") ;
      lua_pushinteger(L, (lua_Integer)CGEventSourceGetTypeID()) ; lua_setfield(L, -2, "CGEventSource") ;
      lua_pushinteger(L, (lua_Integer)CGFontGetTypeID()) ; lua_setfield(L, -2, "CGFont") ;
      lua_pushinteger(L, (lua_Integer)CGFunctionGetTypeID()) ; lua_setfield(L, -2, "CGFunction") ;
      lua_pushinteger(L, (lua_Integer)CGGradientGetTypeID()) ; lua_setfield(L, -2, "CGGradient") ;
      lua_pushinteger(L, (lua_Integer)CGImageGetTypeID()) ; lua_setfield(L, -2, "CGImage") ;
      lua_pushinteger(L, (lua_Integer)CGLayerGetTypeID()) ; lua_setfield(L, -2, "CGLayer") ;
      lua_pushinteger(L, (lua_Integer)CGPathGetTypeID()) ; lua_setfield(L, -2, "CGPath") ;
      lua_pushinteger(L, (lua_Integer)CGPatternGetTypeID()) ; lua_setfield(L, -2, "CGPattern") ;
      lua_pushinteger(L, (lua_Integer)CGPDFDocumentGetTypeID()) ; lua_setfield(L, -2, "CGPDFDocument") ;
      lua_pushinteger(L, (lua_Integer)CGPDFPageGetTypeID()) ; lua_setfield(L, -2, "CGPDFPage") ;
      lua_pushinteger(L, (lua_Integer)CGPSConverterGetTypeID()) ; lua_setfield(L, -2, "CGPSConverter") ;
      lua_pushinteger(L, (lua_Integer)CGShadingGetTypeID()) ; lua_setfield(L, -2, "CGShading") ;
      lua_pushinteger(L, (lua_Integer)CMBlockBufferGetTypeID()) ; lua_setfield(L, -2, "CMBlockBuffer") ;
      lua_pushinteger(L, (lua_Integer)CMBufferQueueGetTypeID()) ; lua_setfield(L, -2, "CMBufferQueue") ;
      lua_pushinteger(L, (lua_Integer)CMFormatDescriptionGetTypeID()) ; lua_setfield(L, -2, "CMFormatDescription") ;
      lua_pushinteger(L, (lua_Integer)CMMemoryPoolGetTypeID()) ; lua_setfield(L, -2, "CMMemoryPool") ;
      lua_pushinteger(L, (lua_Integer)CMSampleBufferGetTypeID()) ; lua_setfield(L, -2, "CMSampleBuffer") ;
      lua_pushinteger(L, (lua_Integer)CMSimpleQueueGetTypeID()) ; lua_setfield(L, -2, "CMSimpleQueue") ;
      lua_pushinteger(L, (lua_Integer)FSFileOperationGetTypeID()) ; lua_setfield(L, -2, "FSFileOperation") ;
      lua_pushinteger(L, (lua_Integer)FSFileSecurityGetTypeID()) ; lua_setfield(L, -2, "FSFileSecurity") ;
      lua_pushinteger(L, (lua_Integer)MDItemGetTypeID()) ; lua_setfield(L, -2, "MDItem") ;
      lua_pushinteger(L, (lua_Integer)MDLabelGetTypeID()) ; lua_setfield(L, -2, "MDLabel") ;
      lua_pushinteger(L, (lua_Integer)MDQueryGetTypeID()) ; lua_setfield(L, -2, "MDQuery") ;
      lua_pushinteger(L, (lua_Integer)CVDisplayLinkGetTypeID()) ; lua_setfield(L, -2, "CVDisplayLink") ;
      lua_pushinteger(L, (lua_Integer)CVMetalTextureGetTypeID()) ; lua_setfield(L, -2, "CVMetalTexture") ;
      lua_pushinteger(L, (lua_Integer)CVMetalTextureCacheGetTypeID()) ; lua_setfield(L, -2, "CVMetalTextureCache") ;
      lua_pushinteger(L, (lua_Integer)CVOpenGLBufferGetTypeID()) ; lua_setfield(L, -2, "CVOpenGLBuffer") ;
      lua_pushinteger(L, (lua_Integer)CVOpenGLBufferPoolGetTypeID()) ; lua_setfield(L, -2, "CVOpenGLBufferPool") ;
      lua_pushinteger(L, (lua_Integer)CVOpenGLTextureGetTypeID()) ; lua_setfield(L, -2, "CVOpenGLTexture") ;
      lua_pushinteger(L, (lua_Integer)CVOpenGLTextureCacheGetTypeID()) ; lua_setfield(L, -2, "CVOpenGLTextureCache") ;
      lua_pushinteger(L, (lua_Integer)CVPixelBufferGetTypeID()) ; lua_setfield(L, -2, "CVPixelBuffer") ;
      lua_pushinteger(L, (lua_Integer)CVPixelBufferPoolGetTypeID()) ; lua_setfield(L, -2, "CVPixelBufferPool") ;
      lua_pushinteger(L, (lua_Integer)DRFileGetTypeID()) ; lua_setfield(L, -2, "DRFile") ;
      lua_pushinteger(L, (lua_Integer)DRFolderGetTypeID()) ; lua_setfield(L, -2, "DRFolder") ;
      lua_pushinteger(L, (lua_Integer)DRBurnGetTypeID()) ; lua_setfield(L, -2, "DRBurn") ;
      lua_pushinteger(L, (lua_Integer)DRDeviceGetTypeID()) ; lua_setfield(L, -2, "DRDevice") ;
      lua_pushinteger(L, (lua_Integer)DREraseGetTypeID()) ; lua_setfield(L, -2, "DRErase") ;
      lua_pushinteger(L, (lua_Integer)DRNotificationCenterGetTypeID()) ; lua_setfield(L, -2, "DRNotificationCenter") ;
      lua_pushinteger(L, (lua_Integer)DRTrackGetTypeID()) ; lua_setfield(L, -2, "DRTrack") ;
      lua_pushinteger(L, (lua_Integer)GLKMatrixStackGetTypeID()) ; lua_setfield(L, -2, "GLKMatrixStack") ;
      lua_pushinteger(L, (lua_Integer)CGImageDestinationGetTypeID()) ; lua_setfield(L, -2, "CGImageDestination") ;
      lua_pushinteger(L, (lua_Integer)CGImageMetadataGetTypeID()) ; lua_setfield(L, -2, "CGImageMetadata") ;
      lua_pushinteger(L, (lua_Integer)CGImageMetadataTagGetTypeID()) ; lua_setfield(L, -2, "CGImageMetadataTag") ;
      lua_pushinteger(L, (lua_Integer)CGImageSourceGetTypeID()) ; lua_setfield(L, -2, "CGImageSource") ;
      lua_pushinteger(L, (lua_Integer)IOHIDDeviceGetTypeID()) ; lua_setfield(L, -2, "IOHIDDevice") ;
      lua_pushinteger(L, (lua_Integer)IOHIDElementGetTypeID()) ; lua_setfield(L, -2, "IOHIDElement") ;
      lua_pushinteger(L, (lua_Integer)IOHIDManagerGetTypeID()) ; lua_setfield(L, -2, "IOHIDManager") ;
      lua_pushinteger(L, (lua_Integer)IOHIDQueueGetTypeID()) ; lua_setfield(L, -2, "IOHIDQueue") ;
      lua_pushinteger(L, (lua_Integer)IOHIDTransactionGetTypeID()) ; lua_setfield(L, -2, "IOHIDTransaction") ;
      lua_pushinteger(L, (lua_Integer)IOHIDValueGetTypeID()) ; lua_setfield(L, -2, "IOHIDValue") ;
      lua_pushinteger(L, (lua_Integer)IOSurfaceGetTypeID()) ; lua_setfield(L, -2, "IOSurface") ;
      lua_pushinteger(L, (lua_Integer)LSMMapGetTypeID()) ; lua_setfield(L, -2, "LSMMap") ;
      lua_pushinteger(L, (lua_Integer)LSMTextGetTypeID()) ; lua_setfield(L, -2, "LSMText") ;
      lua_pushinteger(L, (lua_Integer)LSMResultGetTypeID()) ; lua_setfield(L, -2, "LSMResult") ;
      lua_pushinteger(L, (lua_Integer)MTAudioProcessingTapGetTypeID()) ; lua_setfield(L, -2, "MTAudioProcessingTap") ;
      lua_pushinteger(L, (lua_Integer)ODContextGetTypeID()) ; lua_setfield(L, -2, "ODContext") ;
      lua_pushinteger(L, (lua_Integer)ODNodeGetTypeID()) ; lua_setfield(L, -2, "ODNode") ;
      lua_pushinteger(L, (lua_Integer)ODQueryGetTypeID()) ; lua_setfield(L, -2, "ODQuery") ;
      lua_pushinteger(L, (lua_Integer)ODRecordGetTypeID()) ; lua_setfield(L, -2, "ODRecord") ;
      lua_pushinteger(L, (lua_Integer)ODSessionGetTypeID()) ; lua_setfield(L, -2, "ODSession") ;
      lua_pushinteger(L, (lua_Integer)CMSDecoderGetTypeID()) ; lua_setfield(L, -2, "CMSDecoder") ;
      lua_pushinteger(L, (lua_Integer)CMSEncoderGetTypeID()) ; lua_setfield(L, -2, "CMSEncoder") ;
      lua_pushinteger(L, (lua_Integer)SecAccessGetTypeID()) ; lua_setfield(L, -2, "SecAccess") ;
      lua_pushinteger(L, (lua_Integer)SecAccessControlGetTypeID()) ; lua_setfield(L, -2, "SecAccessControl") ;
      lua_pushinteger(L, (lua_Integer)SecACLGetTypeID()) ; lua_setfield(L, -2, "SecACL") ;
      lua_pushinteger(L, (lua_Integer)SecCertificateGetTypeID()) ; lua_setfield(L, -2, "SecCertificate") ;
      lua_pushinteger(L, (lua_Integer)SecCodeGetTypeID()) ; lua_setfield(L, -2, "SecCode") ;
      lua_pushinteger(L, (lua_Integer)SecIdentityGetTypeID()) ; lua_setfield(L, -2, "SecIdentity") ;
      lua_pushinteger(L, (lua_Integer)SecIdentitySearchGetTypeID()) ; lua_setfield(L, -2, "SecIdentitySearch") ;
      lua_pushinteger(L, (lua_Integer)SecKeyGetTypeID()) ; lua_setfield(L, -2, "SecKey") ;
      lua_pushinteger(L, (lua_Integer)SecKeychainGetTypeID()) ; lua_setfield(L, -2, "SecKeychain") ;
      lua_pushinteger(L, (lua_Integer)SecKeychainItemGetTypeID()) ; lua_setfield(L, -2, "SecKeychainItem") ;
      lua_pushinteger(L, (lua_Integer)SecKeychainSearchGetTypeID()) ; lua_setfield(L, -2, "SecKeychainSearch") ;
      lua_pushinteger(L, (lua_Integer)SecPolicyGetTypeID()) ; lua_setfield(L, -2, "SecPolicy") ;
      lua_pushinteger(L, (lua_Integer)SecPolicySearchGetTypeID()) ; lua_setfield(L, -2, "SecPolicySearch") ;
      lua_pushinteger(L, (lua_Integer)SecRequirementGetTypeID()) ; lua_setfield(L, -2, "SecRequirement") ;
      lua_pushinteger(L, (lua_Integer)SecStaticCodeGetTypeID()) ; lua_setfield(L, -2, "SecStaticCode") ;
      lua_pushinteger(L, (lua_Integer)SecTaskGetTypeID()) ; lua_setfield(L, -2, "SecTask") ;

//       lua_pushinteger(L, (lua_Integer)SecTransformGetTypeID()) ; lua_setfield(L, -2, "SecTransform") ;
//       lua_pushinteger(L, (lua_Integer)SecGroupTransformGetTypeID()) ; lua_setfield(L, -2, "SecGroupTransform") ;

      lua_pushinteger(L, (lua_Integer)SecTrustGetTypeID()) ; lua_setfield(L, -2, "SecTrust") ;
      lua_pushinteger(L, (lua_Integer)SecTrustedApplicationGetTypeID()) ; lua_setfield(L, -2, "SecTrustedApplication") ;
      lua_pushinteger(L, (lua_Integer)VTFrameSiloGetTypeID()) ; lua_setfield(L, -2, "VTFrameSilo") ;
      lua_pushinteger(L, (lua_Integer)VTMultiPassStorageGetTypeID()) ; lua_setfield(L, -2, "VTMultiPassStorage") ;
#pragma clang diagnostic pop
    return 1 ;
}

static int userdata_tostring(lua_State* L) {
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    [[LuaSkin shared] pushNSObject:[NSString stringWithFormat:@"%s: %p", USERDATA_TAG, theRef]] ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFRelease(theRef) ;
    return 0 ;
}

static int userdata_eq(lua_State* L) {
    AXUIElementRef theRef1 = get_axuielementref(L, 1, USERDATA_TAG) ;
    AXUIElementRef theRef2 = get_axuielementref(L, 2, USERDATA_TAG) ;
    lua_pushboolean(L, CFEqual(theRef1, theRef2)) ;
    return 1 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"attributeNames",              getAttributeNames},
    {"parameterizedAttributeNames", getParameterizedAttributeNames},
    {"actionNames",                 getActionNames},
    {"actionDescription",           getActionDescription},
    {"attributeValue",              getAttributeValue},
    {"attributeValueCount",         getAttributeValueCount},
    {"isAttributeSettable",         isAttributeSettable},
    {"pid",                         getPid},
    {"performAction",               performAction},

    {"__tostring",                  userdata_tostring},
    {"__eq",                        userdata_eq},
    {"__gc",                        userdata_gc},
    {NULL,                          NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"systemWideElement",  getSystemWideElement},
    {"windowElement",      getWindowElement},
    {"applicationElement", getApplicationElement},

    {NULL,                 NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_axuielement_internal(lua_State* __unused L) {
// Use this if your module doesn't have a module specific object that it returns.
//    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [[LuaSkin shared] registerLibraryWithObject:USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

    definedTypes(L) ; lua_setfield(L, -2, "types") ;

    return 1;
}
