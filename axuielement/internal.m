// TODO: Notifications/Observers?
//     * in init.lua, __init should limit returned functions to actual names defined for element -- constants are suggestions/basics
//     * in init.lua, add methods() to generate list of "psuedo functions" for element
//     * in init.lua, add "do" prefix to actions
//     * in init.lua, suffix for parameterizedAttributes
//     * search for element of type/role/subrole for element?  what about lists/multiple?
//
//       clean up browse?
//       document
//       switch userdata to struct or nsobject so we can use udRef counter like in hs.speech to allow the
//              same axuielement to return the same userdata each time to facilitate duplicate detection
//              in lua by allowing table[userdata] to be used to test existence in a table rather than
//              having to loop through and compare each time.

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

#define USERDATA_TAG "hs._asm.axuielement"
static int refTable = LUA_NOREF ;

// #define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))
#define get_axuielementref(L, idx, tag) *((AXUIElementRef*)luaL_checkudata(L, idx, tag))

#pragma mark - Errors and Logging and with hs.logger

static int logFnRef = LUA_NOREF ;

#define _cERROR   "ef"
#define _cWARN    "wf"
#define _cINFO    "f"
#define _cDEBUG   "df"
#define _cVERBOSE "vf"

// allow this to be potentially unused in the module
static int __unused log_to_console(lua_State *L, const char *level, NSString *theMessage) {
    lua_Debug functionDebugObject, callerDebugObject ;
    int status = lua_getstack(L, 0, &functionDebugObject) ;
    status = status + lua_getstack(L, 1, &callerDebugObject) ;
    NSString *fullMessage = nil ;
    if (status == 2) {
        lua_getinfo(L, "n", &functionDebugObject) ;
        lua_getinfo(L, "Sl", &callerDebugObject) ;
        fullMessage = [NSString stringWithFormat:@"%s - %@ (%d:%s)", functionDebugObject.name,
                                                                     theMessage,
                                                                     callerDebugObject.currentline,
                                                                     callerDebugObject.short_src] ;
    } else {
        fullMessage = [NSString stringWithFormat:@"%s callback - %@", USERDATA_TAG,
                                                                      theMessage] ;
    }
    // Except for Debug and Verbose, put it into the system logs, may help with troubleshooting
    if (level[0] != 'd' && level[0] != 'v') CLS_NSLOG(@"%-2s:%s: %@", level, USERDATA_TAG, fullMessage) ;

    // If hs.logger reference set, use it and the level will indicate whether the user sees it or not
    // otherwise we print to the console for everything, just in case we forget to register.
    if (logFnRef != LUA_NOREF) {
        [[LuaSkin shared] pushLuaRef:refTable ref:logFnRef] ;
        lua_getfield(L, -1, level) ; lua_remove(L, -2) ;
    } else {
        lua_getglobal(L, "print") ;
    }

    lua_pushstring(L, [fullMessage UTF8String]) ;
    if (![[LuaSkin shared] protectedCallAndTraceback:1 nresults:0]) { return lua_error(L) ; }
    return 0 ;
}

static int lua_registerLogForC(__unused lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TTABLE, LS_TBREAK] ;
    logFnRef = [[LuaSkin shared] luaRef:refTable] ;
    return 0 ;
}

// allow this to be potentially unused in the module
static int __unused my_lua_error(lua_State *L, NSString *theMessage) {
    lua_Debug functionDebugObject ;
    lua_getstack(L, 0, &functionDebugObject) ;
    lua_getinfo(L, "n", &functionDebugObject) ;
    return luaL_error(L, [[NSString stringWithFormat:@"%s:%s - %@", USERDATA_TAG, functionDebugObject.name, theMessage] UTF8String]) ;
}

#pragma mark - Support Functions

static int pushAXUIElement(lua_State *L, AXUIElementRef theElement) {
    AXUIElementRef* thePtr = lua_newuserdata(L, sizeof(AXUIElementRef)) ;
    *thePtr = CFRetain(theElement) ;

    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static const char *AXErrorAsString(AXError theError) {
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

static BOOL isApplicationOrSystem(AXUIElementRef theRef) {
    BOOL result = NO ;
    CFTypeRef value ;
    AXError errorState = AXUIElementCopyAttributeValue(theRef, (__bridge CFStringRef)@"AXRole", &value) ;
    if ((errorState == kAXErrorSuccess) &&
        (CFGetTypeID(value) == CFStringGetTypeID()) &&
        ([(__bridge NSString *)value isEqualToString:(__bridge NSString *)kAXApplicationRole] ||
         [(__bridge NSString *)value isEqualToString:(__bridge NSString *)kAXSystemWideRole])) {

        result = YES ;
    }
    if (value) CFRelease(value) ;
    return result ;
}

static int errorWrapper(lua_State *L, AXError err) {
    log_to_console(L, _cDEBUG, [NSString stringWithFormat:@"AXError %d: %s", err, AXErrorAsString(err)]) ;
    lua_pushnil(L) ;
    return 1 ;
}

// Because I may want to generalize this as a CFType converter someday, I should keep a list
// of the types possible around.  If something comes up that doesn't have a clean converter,
// at least I can figure out what it is and make a decision...
static int definedTypes(lua_State *L) {
    lua_newtable(L) ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  lua_pushinteger(L, (lua_Integer)ColorSyncCMMGetTypeID()) ;          lua_setfield(L, -2, "ColorSyncCMM") ;
  lua_pushinteger(L, (lua_Integer)ColorSyncProfileGetTypeID()) ;      lua_setfield(L, -2, "ColorSyncProfile") ;
  lua_pushinteger(L, (lua_Integer)ColorSyncTransformGetTypeID()) ;    lua_setfield(L, -2, "ColorSyncTransform") ;
  lua_pushinteger(L, (lua_Integer)AXUIElementGetTypeID()) ;           lua_setfield(L, -2, "AXUIElement") ;
  lua_pushinteger(L, (lua_Integer)AXValueGetTypeID()) ;               lua_setfield(L, -2, "AXValue") ;
  lua_pushinteger(L, (lua_Integer)AXObserverGetTypeID()) ;            lua_setfield(L, -2, "AXObserver") ;
  lua_pushinteger(L, (lua_Integer)CFArrayGetTypeID()) ;               lua_setfield(L, -2, "CFArray") ;
  lua_pushinteger(L, (lua_Integer)CFAttributedStringGetTypeID()) ;    lua_setfield(L, -2, "CFAttributedString") ;
  lua_pushinteger(L, (lua_Integer)CFBagGetTypeID()) ;                 lua_setfield(L, -2, "CFBag") ;
  lua_pushinteger(L, (lua_Integer)CFNullGetTypeID()) ;                lua_setfield(L, -2, "CFNull") ;
  lua_pushinteger(L, (lua_Integer)CFAllocatorGetTypeID()) ;           lua_setfield(L, -2, "CFAllocator") ;
  lua_pushinteger(L, (lua_Integer)CFBinaryHeapGetTypeID()) ;          lua_setfield(L, -2, "CFBinaryHeap") ;
  lua_pushinteger(L, (lua_Integer)CFBitVectorGetTypeID()) ;           lua_setfield(L, -2, "CFBitVector") ;
  lua_pushinteger(L, (lua_Integer)CFBundleGetTypeID()) ;              lua_setfield(L, -2, "CFBundle") ;
  lua_pushinteger(L, (lua_Integer)CFCalendarGetTypeID()) ;            lua_setfield(L, -2, "CFCalendar") ;
  lua_pushinteger(L, (lua_Integer)CFCharacterSetGetTypeID()) ;        lua_setfield(L, -2, "CFCharacterSet") ;
  lua_pushinteger(L, (lua_Integer)CFDataGetTypeID()) ;                lua_setfield(L, -2, "CFData") ;
  lua_pushinteger(L, (lua_Integer)CFDateGetTypeID()) ;                lua_setfield(L, -2, "CFDate") ;
  lua_pushinteger(L, (lua_Integer)CFDateFormatterGetTypeID()) ;       lua_setfield(L, -2, "CFDateFormatter") ;
  lua_pushinteger(L, (lua_Integer)CFDictionaryGetTypeID()) ;          lua_setfield(L, -2, "CFDictionary") ;
  lua_pushinteger(L, (lua_Integer)CFErrorGetTypeID()) ;               lua_setfield(L, -2, "CFError") ;
  lua_pushinteger(L, (lua_Integer)CFFileDescriptorGetTypeID()) ;      lua_setfield(L, -2, "CFFileDescriptor") ;
  lua_pushinteger(L, (lua_Integer)CFFileSecurityGetTypeID()) ;        lua_setfield(L, -2, "CFFileSecurity") ;
  lua_pushinteger(L, (lua_Integer)CFLocaleGetTypeID()) ;              lua_setfield(L, -2, "CFLocale") ;
  lua_pushinteger(L, (lua_Integer)CFMachPortGetTypeID()) ;            lua_setfield(L, -2, "CFMachPort") ;
  lua_pushinteger(L, (lua_Integer)CFMessagePortGetTypeID()) ;         lua_setfield(L, -2, "CFMessagePort") ;
  lua_pushinteger(L, (lua_Integer)CFNotificationCenterGetTypeID()) ;  lua_setfield(L, -2, "CFNotificationCenter") ;
  lua_pushinteger(L, (lua_Integer)CFBooleanGetTypeID()) ;             lua_setfield(L, -2, "CFBoolean") ;
  lua_pushinteger(L, (lua_Integer)CFNumberGetTypeID()) ;              lua_setfield(L, -2, "CFNumber") ;
  lua_pushinteger(L, (lua_Integer)CFNumberFormatterGetTypeID()) ;     lua_setfield(L, -2, "CFNumberFormatter") ;
  lua_pushinteger(L, (lua_Integer)CFPlugInGetTypeID()) ;              lua_setfield(L, -2, "CFPlugIn") ;
  lua_pushinteger(L, (lua_Integer)CFPlugInInstanceGetTypeID()) ;      lua_setfield(L, -2, "CFPlugInInstance") ;
  lua_pushinteger(L, (lua_Integer)CFRunLoopGetTypeID()) ;             lua_setfield(L, -2, "CFRunLoop") ;
  lua_pushinteger(L, (lua_Integer)CFRunLoopSourceGetTypeID()) ;       lua_setfield(L, -2, "CFRunLoopSource") ;
  lua_pushinteger(L, (lua_Integer)CFRunLoopObserverGetTypeID()) ;     lua_setfield(L, -2, "CFRunLoopObserver") ;
  lua_pushinteger(L, (lua_Integer)CFRunLoopTimerGetTypeID()) ;        lua_setfield(L, -2, "CFRunLoopTimer") ;
  lua_pushinteger(L, (lua_Integer)CFSetGetTypeID()) ;                 lua_setfield(L, -2, "CFSet") ;
  lua_pushinteger(L, (lua_Integer)CFSocketGetTypeID()) ;              lua_setfield(L, -2, "CFSocket") ;
  lua_pushinteger(L, (lua_Integer)CFReadStreamGetTypeID()) ;          lua_setfield(L, -2, "CFReadStream") ;
  lua_pushinteger(L, (lua_Integer)CFWriteStreamGetTypeID()) ;         lua_setfield(L, -2, "CFWriteStream") ;
  lua_pushinteger(L, (lua_Integer)CFStringGetTypeID()) ;              lua_setfield(L, -2, "CFString") ;
  lua_pushinteger(L, (lua_Integer)CFStringTokenizerGetTypeID()) ;     lua_setfield(L, -2, "CFStringTokenizer") ;
  lua_pushinteger(L, (lua_Integer)CFTimeZoneGetTypeID()) ;            lua_setfield(L, -2, "CFTimeZone") ;
  lua_pushinteger(L, (lua_Integer)CFTreeGetTypeID()) ;                lua_setfield(L, -2, "CFTree") ;
  lua_pushinteger(L, (lua_Integer)CFURLGetTypeID()) ;                 lua_setfield(L, -2, "CFURL") ;
  lua_pushinteger(L, (lua_Integer)CFUserNotificationGetTypeID()) ;    lua_setfield(L, -2, "CFUserNotification") ;
  lua_pushinteger(L, (lua_Integer)CFUUIDGetTypeID()) ;                lua_setfield(L, -2, "CFUUID") ;
  lua_pushinteger(L, (lua_Integer)CFXMLNodeGetTypeID()) ;             lua_setfield(L, -2, "CFXMLNode") ;
  lua_pushinteger(L, (lua_Integer)CFXMLParserGetTypeID()) ;           lua_setfield(L, -2, "CFXMLParser") ;
  lua_pushinteger(L, (lua_Integer)CGColorGetTypeID()) ;               lua_setfield(L, -2, "CGColor") ;
  lua_pushinteger(L, (lua_Integer)CGColorSpaceGetTypeID()) ;          lua_setfield(L, -2, "CGColorSpace") ;
  lua_pushinteger(L, (lua_Integer)CGContextGetTypeID()) ;             lua_setfield(L, -2, "CGContext") ;
  lua_pushinteger(L, (lua_Integer)CGDataConsumerGetTypeID()) ;        lua_setfield(L, -2, "CGDataConsumer") ;
  lua_pushinteger(L, (lua_Integer)CGDataProviderGetTypeID()) ;        lua_setfield(L, -2, "CGDataProvider") ;
  lua_pushinteger(L, (lua_Integer)CGDisplayModeGetTypeID()) ;         lua_setfield(L, -2, "CGDisplayMode") ;
  lua_pushinteger(L, (lua_Integer)CGDisplayStreamUpdateGetTypeID()) ; lua_setfield(L, -2, "CGDisplayStreamUpdate") ;
  lua_pushinteger(L, (lua_Integer)CGDisplayStreamGetTypeID()) ;       lua_setfield(L, -2, "CGDisplayStream") ;
  lua_pushinteger(L, (lua_Integer)CGEventGetTypeID()) ;               lua_setfield(L, -2, "CGEvent") ;
  lua_pushinteger(L, (lua_Integer)CGEventSourceGetTypeID()) ;         lua_setfield(L, -2, "CGEventSource") ;
  lua_pushinteger(L, (lua_Integer)CGFontGetTypeID()) ;                lua_setfield(L, -2, "CGFont") ;
  lua_pushinteger(L, (lua_Integer)CGFunctionGetTypeID()) ;            lua_setfield(L, -2, "CGFunction") ;
  lua_pushinteger(L, (lua_Integer)CGGradientGetTypeID()) ;            lua_setfield(L, -2, "CGGradient") ;
  lua_pushinteger(L, (lua_Integer)CGImageGetTypeID()) ;               lua_setfield(L, -2, "CGImage") ;
  lua_pushinteger(L, (lua_Integer)CGLayerGetTypeID()) ;               lua_setfield(L, -2, "CGLayer") ;
  lua_pushinteger(L, (lua_Integer)CGPathGetTypeID()) ;                lua_setfield(L, -2, "CGPath") ;
  lua_pushinteger(L, (lua_Integer)CGPatternGetTypeID()) ;             lua_setfield(L, -2, "CGPattern") ;
  lua_pushinteger(L, (lua_Integer)CGPDFDocumentGetTypeID()) ;         lua_setfield(L, -2, "CGPDFDocument") ;
  lua_pushinteger(L, (lua_Integer)CGPDFPageGetTypeID()) ;             lua_setfield(L, -2, "CGPDFPage") ;
  lua_pushinteger(L, (lua_Integer)CGPSConverterGetTypeID()) ;         lua_setfield(L, -2, "CGPSConverter") ;
  lua_pushinteger(L, (lua_Integer)CGShadingGetTypeID()) ;             lua_setfield(L, -2, "CGShading") ;
  lua_pushinteger(L, (lua_Integer)CMBlockBufferGetTypeID()) ;         lua_setfield(L, -2, "CMBlockBuffer") ;
  lua_pushinteger(L, (lua_Integer)CMBufferQueueGetTypeID()) ;         lua_setfield(L, -2, "CMBufferQueue") ;
  lua_pushinteger(L, (lua_Integer)CMFormatDescriptionGetTypeID()) ;   lua_setfield(L, -2, "CMFormatDescription") ;
  lua_pushinteger(L, (lua_Integer)CMMemoryPoolGetTypeID()) ;          lua_setfield(L, -2, "CMMemoryPool") ;
  lua_pushinteger(L, (lua_Integer)CMSampleBufferGetTypeID()) ;        lua_setfield(L, -2, "CMSampleBuffer") ;
  lua_pushinteger(L, (lua_Integer)CMSimpleQueueGetTypeID()) ;         lua_setfield(L, -2, "CMSimpleQueue") ;
  lua_pushinteger(L, (lua_Integer)FSFileOperationGetTypeID()) ;       lua_setfield(L, -2, "FSFileOperation") ;
  lua_pushinteger(L, (lua_Integer)FSFileSecurityGetTypeID()) ;        lua_setfield(L, -2, "FSFileSecurity") ;
  lua_pushinteger(L, (lua_Integer)MDItemGetTypeID()) ;                lua_setfield(L, -2, "MDItem") ;
  lua_pushinteger(L, (lua_Integer)MDLabelGetTypeID()) ;               lua_setfield(L, -2, "MDLabel") ;
  lua_pushinteger(L, (lua_Integer)MDQueryGetTypeID()) ;               lua_setfield(L, -2, "MDQuery") ;
  lua_pushinteger(L, (lua_Integer)CVDisplayLinkGetTypeID()) ;         lua_setfield(L, -2, "CVDisplayLink") ;
  lua_pushinteger(L, (lua_Integer)CVMetalTextureGetTypeID()) ;        lua_setfield(L, -2, "CVMetalTexture") ;
  lua_pushinteger(L, (lua_Integer)CVMetalTextureCacheGetTypeID()) ;   lua_setfield(L, -2, "CVMetalTextureCache") ;
  lua_pushinteger(L, (lua_Integer)CVOpenGLBufferGetTypeID()) ;        lua_setfield(L, -2, "CVOpenGLBuffer") ;
  lua_pushinteger(L, (lua_Integer)CVOpenGLBufferPoolGetTypeID()) ;    lua_setfield(L, -2, "CVOpenGLBufferPool") ;
  lua_pushinteger(L, (lua_Integer)CVOpenGLTextureGetTypeID()) ;       lua_setfield(L, -2, "CVOpenGLTexture") ;
  lua_pushinteger(L, (lua_Integer)CVOpenGLTextureCacheGetTypeID()) ;  lua_setfield(L, -2, "CVOpenGLTextureCache") ;
  lua_pushinteger(L, (lua_Integer)CVPixelBufferGetTypeID()) ;         lua_setfield(L, -2, "CVPixelBuffer") ;
  lua_pushinteger(L, (lua_Integer)CVPixelBufferPoolGetTypeID()) ;     lua_setfield(L, -2, "CVPixelBufferPool") ;
  lua_pushinteger(L, (lua_Integer)DRFileGetTypeID()) ;                lua_setfield(L, -2, "DRFile") ;
  lua_pushinteger(L, (lua_Integer)DRFolderGetTypeID()) ;              lua_setfield(L, -2, "DRFolder") ;
  lua_pushinteger(L, (lua_Integer)DRBurnGetTypeID()) ;                lua_setfield(L, -2, "DRBurn") ;
  lua_pushinteger(L, (lua_Integer)DRDeviceGetTypeID()) ;              lua_setfield(L, -2, "DRDevice") ;
  lua_pushinteger(L, (lua_Integer)DREraseGetTypeID()) ;               lua_setfield(L, -2, "DRErase") ;
  lua_pushinteger(L, (lua_Integer)DRNotificationCenterGetTypeID()) ;  lua_setfield(L, -2, "DRNotificationCenter") ;
  lua_pushinteger(L, (lua_Integer)DRTrackGetTypeID()) ;               lua_setfield(L, -2, "DRTrack") ;
  lua_pushinteger(L, (lua_Integer)GLKMatrixStackGetTypeID()) ;        lua_setfield(L, -2, "GLKMatrixStack") ;
  lua_pushinteger(L, (lua_Integer)CGImageDestinationGetTypeID()) ;    lua_setfield(L, -2, "CGImageDestination") ;
  lua_pushinteger(L, (lua_Integer)CGImageMetadataGetTypeID()) ;       lua_setfield(L, -2, "CGImageMetadata") ;
  lua_pushinteger(L, (lua_Integer)CGImageMetadataTagGetTypeID()) ;    lua_setfield(L, -2, "CGImageMetadataTag") ;
  lua_pushinteger(L, (lua_Integer)CGImageSourceGetTypeID()) ;         lua_setfield(L, -2, "CGImageSource") ;
  lua_pushinteger(L, (lua_Integer)IOHIDDeviceGetTypeID()) ;           lua_setfield(L, -2, "IOHIDDevice") ;
  lua_pushinteger(L, (lua_Integer)IOHIDElementGetTypeID()) ;          lua_setfield(L, -2, "IOHIDElement") ;
  lua_pushinteger(L, (lua_Integer)IOHIDManagerGetTypeID()) ;          lua_setfield(L, -2, "IOHIDManager") ;
  lua_pushinteger(L, (lua_Integer)IOHIDQueueGetTypeID()) ;            lua_setfield(L, -2, "IOHIDQueue") ;
  lua_pushinteger(L, (lua_Integer)IOHIDTransactionGetTypeID()) ;      lua_setfield(L, -2, "IOHIDTransaction") ;
  lua_pushinteger(L, (lua_Integer)IOHIDValueGetTypeID()) ;            lua_setfield(L, -2, "IOHIDValue") ;
  lua_pushinteger(L, (lua_Integer)IOSurfaceGetTypeID()) ;             lua_setfield(L, -2, "IOSurface") ;
  lua_pushinteger(L, (lua_Integer)LSMMapGetTypeID()) ;                lua_setfield(L, -2, "LSMMap") ;
  lua_pushinteger(L, (lua_Integer)LSMTextGetTypeID()) ;               lua_setfield(L, -2, "LSMText") ;
  lua_pushinteger(L, (lua_Integer)LSMResultGetTypeID()) ;             lua_setfield(L, -2, "LSMResult") ;
  lua_pushinteger(L, (lua_Integer)MTAudioProcessingTapGetTypeID()) ;  lua_setfield(L, -2, "MTAudioProcessingTap") ;
  lua_pushinteger(L, (lua_Integer)ODContextGetTypeID()) ;             lua_setfield(L, -2, "ODContext") ;
  lua_pushinteger(L, (lua_Integer)ODNodeGetTypeID()) ;                lua_setfield(L, -2, "ODNode") ;
  lua_pushinteger(L, (lua_Integer)ODQueryGetTypeID()) ;               lua_setfield(L, -2, "ODQuery") ;
  lua_pushinteger(L, (lua_Integer)ODRecordGetTypeID()) ;              lua_setfield(L, -2, "ODRecord") ;
  lua_pushinteger(L, (lua_Integer)ODSessionGetTypeID()) ;             lua_setfield(L, -2, "ODSession") ;
  lua_pushinteger(L, (lua_Integer)CMSDecoderGetTypeID()) ;            lua_setfield(L, -2, "CMSDecoder") ;
  lua_pushinteger(L, (lua_Integer)CMSEncoderGetTypeID()) ;            lua_setfield(L, -2, "CMSEncoder") ;
  lua_pushinteger(L, (lua_Integer)SecAccessGetTypeID()) ;             lua_setfield(L, -2, "SecAccess") ;
  lua_pushinteger(L, (lua_Integer)SecAccessControlGetTypeID()) ;      lua_setfield(L, -2, "SecAccessControl") ;
  lua_pushinteger(L, (lua_Integer)SecACLGetTypeID()) ;                lua_setfield(L, -2, "SecACL") ;
  lua_pushinteger(L, (lua_Integer)SecCertificateGetTypeID()) ;        lua_setfield(L, -2, "SecCertificate") ;
  lua_pushinteger(L, (lua_Integer)SecCodeGetTypeID()) ;               lua_setfield(L, -2, "SecCode") ;
  lua_pushinteger(L, (lua_Integer)SecIdentityGetTypeID()) ;           lua_setfield(L, -2, "SecIdentity") ;
  lua_pushinteger(L, (lua_Integer)SecIdentitySearchGetTypeID()) ;     lua_setfield(L, -2, "SecIdentitySearch") ;
  lua_pushinteger(L, (lua_Integer)SecKeyGetTypeID()) ;                lua_setfield(L, -2, "SecKey") ;
  lua_pushinteger(L, (lua_Integer)SecKeychainGetTypeID()) ;           lua_setfield(L, -2, "SecKeychain") ;
  lua_pushinteger(L, (lua_Integer)SecKeychainItemGetTypeID()) ;       lua_setfield(L, -2, "SecKeychainItem") ;
  lua_pushinteger(L, (lua_Integer)SecKeychainSearchGetTypeID()) ;     lua_setfield(L, -2, "SecKeychainSearch") ;
  lua_pushinteger(L, (lua_Integer)SecPolicyGetTypeID()) ;             lua_setfield(L, -2, "SecPolicy") ;
  lua_pushinteger(L, (lua_Integer)SecPolicySearchGetTypeID()) ;       lua_setfield(L, -2, "SecPolicySearch") ;
  lua_pushinteger(L, (lua_Integer)SecRequirementGetTypeID()) ;        lua_setfield(L, -2, "SecRequirement") ;
  lua_pushinteger(L, (lua_Integer)SecStaticCodeGetTypeID()) ;         lua_setfield(L, -2, "SecStaticCode") ;
  lua_pushinteger(L, (lua_Integer)SecTaskGetTypeID()) ;               lua_setfield(L, -2, "SecTask") ;

// Even calling these to get the type id causes a crash, so ignoring until it matters
//     lua_pushinteger(L, (lua_Integer)SecTransformGetTypeID()) ;          lua_setfield(L, -2, "SecTransform") ;
//     lua_pushinteger(L, (lua_Integer)SecGroupTransformGetTypeID()) ;     lua_setfield(L, -2, "SecGroupTransform") ;

    lua_pushinteger(L, (lua_Integer)SecTrustGetTypeID()) ;              lua_setfield(L, -2, "SecTrust") ;
    lua_pushinteger(L, (lua_Integer)SecTrustedApplicationGetTypeID()) ; lua_setfield(L, -2, "SecTrustedApplication") ;
    lua_pushinteger(L, (lua_Integer)VTFrameSiloGetTypeID()) ;           lua_setfield(L, -2, "VTFrameSilo") ;
    lua_pushinteger(L, (lua_Integer)VTMultiPassStorageGetTypeID()) ;    lua_setfield(L, -2, "VTMultiPassStorage") ;
#pragma clang diagnostic pop
    return 1 ;
}

// Not sure if the alreadySeen trick is working here, but it hasn't crashed yet... of course I don't think I've
// found any loops that don't have a userdata object in-between that drops us back to Lua before deciding whether
// or not to delve deeper, either, so...

// CFPropertyListRef types ( CFData, CFString, CFArray, CFDictionary, CFDate, CFBoolean, and CFNumber.),
// AXUIElementRef, AXValueRef, CFNullRef, CFAttributedStringRef, and CFURL min as per AXUIElement.h
// AXTextMarkerRef, and AXTextMarkerRangeRef mentioned as well, but private, so... no joy for now.
static int pushCFTypeHamster(lua_State *L, CFTypeRef theItem, NSMutableDictionary *alreadySeen) {
    LuaSkin *skin = [LuaSkin shared] ;
    if ([alreadySeen objectForKey:(__bridge id)theItem]) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:(__bridge id)theItem] intValue]) ;
        return 1 ;
    }

    CFTypeID theType = CFGetTypeID(theItem) ;
    if      (theType == CFArrayGetTypeID()) {
        lua_newtable(L) ;
        [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(L, LUA_REGISTRYINDEX)] forKey:(__bridge id)theItem] ;
        lua_rawgeti(L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:(__bridge id)theItem] intValue]) ; // put it back on the stack
        for(id thing in (__bridge NSArray *)theItem) {
            pushCFTypeHamster(L, (__bridge CFTypeRef)thing, alreadySeen) ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else if (theType == CFDictionaryGetTypeID()) {
        lua_newtable(L) ;
        [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(L, LUA_REGISTRYINDEX)] forKey:(__bridge id)theItem] ;
        lua_rawgeti(L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:(__bridge id)theItem] intValue]) ; // put it back on the stack
        NSArray *keys = [(__bridge NSDictionary *)theItem allKeys] ;
        NSArray *values = [(__bridge NSDictionary *)theItem allValues] ;
        for (unsigned long i = 0 ; i < [keys count] ; i++) {
            pushCFTypeHamster(L, (__bridge CFTypeRef)[keys objectAtIndex:i], alreadySeen) ;
            pushCFTypeHamster(L, (__bridge CFTypeRef)[values objectAtIndex:i], alreadySeen) ;
            lua_settable(L, -3) ;
        }
    } else if (theType == AXValueGetTypeID()) {
        switch(AXValueGetType((AXValueRef)theItem)) {
            case kAXValueCGPointType: {
                CGPoint thePoint ;
                AXValueGetValue((AXValueRef)theItem, kAXValueCGPointType, &thePoint) ;
                lua_newtable(L) ;
                  lua_pushnumber(L, thePoint.x) ; lua_setfield(L, -2, "x") ;
                  lua_pushnumber(L, thePoint.y) ; lua_setfield(L, -2, "y") ;
                break ;
            }
            case kAXValueCGSizeType: {
                CGSize theSize ;
                AXValueGetValue((AXValueRef)theItem, kAXValueCGSizeType, &theSize) ;
                lua_newtable(L) ;
                  lua_pushnumber(L, theSize.height) ; lua_setfield(L, -2, "h") ;
                  lua_pushnumber(L, theSize.width) ;  lua_setfield(L, -2, "w") ;
                break ;
            }
            case kAXValueCGRectType: {
                CGRect theRect ;
                AXValueGetValue((AXValueRef)theItem, kAXValueCGRectType, &theRect) ;
                lua_newtable(L) ;
                  lua_pushnumber(L, theRect.origin.x) ;    lua_setfield(L, -2, "x") ;
                  lua_pushnumber(L, theRect.origin.y) ;    lua_setfield(L, -2, "y") ;
                  lua_pushnumber(L, theRect.size.height) ; lua_setfield(L, -2, "h") ;
                  lua_pushnumber(L, theRect.size.width) ;  lua_setfield(L, -2, "w") ;
                break ;
            }
            case kAXValueCFRangeType: {
                CFRange theRange ;
                AXValueGetValue((AXValueRef)theItem, kAXValueCFRangeType, &theRange) ;
                lua_newtable(L) ;
                  lua_pushinteger(L, theRange.location) ; lua_setfield(L, -2, "loc") ;
                  lua_pushinteger(L, theRange.length) ;   lua_setfield(L, -2, "len") ;
                break ;
            }
            case kAXValueAXErrorType: {
                AXError theError ;
                AXValueGetValue((AXValueRef)theItem, kAXValueAXErrorType, &theError) ;
                lua_newtable(L) ;
                  lua_pushinteger(L, theError) ;                 lua_setfield(L, -2, "_code") ;
                  lua_pushstring(L, AXErrorAsString(theError)) ; lua_setfield(L, -2, "error") ;
                break ;
            }
            case kAXValueIllegalType:
            default:
                lua_pushfstring(L, "unrecognized value type (%p)", theItem) ;
                break ;
        }
    } else if (theType == CFAttributedStringGetTypeID()) [skin pushNSObject:(__bridge NSAttributedString *)theItem] ;
      else if (theType == CFNullGetTypeID())             [skin pushNSObject:(__bridge NSNull *)theItem] ;
      else if (theType == CFBooleanGetTypeID() || theType == CFNumberGetTypeID())
                                                         [skin pushNSObject:(__bridge NSNumber *)theItem] ;
      else if (theType == CFDataGetTypeID())             [skin pushNSObject:(__bridge NSData *)theItem] ;
      else if (theType == CFDateGetTypeID())             [skin pushNSObject:(__bridge NSDate *)theItem] ;
      else if (theType == CFStringGetTypeID())           [skin pushNSObject:(__bridge NSString *)theItem] ;
      else if (theType == CFURLGetTypeID())              [skin pushNSObject:(__bridge_transfer NSString *)CFRetain(CFURLGetString(theItem))] ;
      else if (theType == AXUIElementGetTypeID())        pushAXUIElement(L, theItem) ;
      else {
//           lua_pushfstring(L, "unrecognized type %d", CFGetTypeID(theItem)) ;
          definedTypes(L) ;
          lua_pushinteger(L, (lua_Integer)CFGetTypeID(theItem)) ;
          lua_rawget(L, -2) ;
          NSString *typeLabel ;
          if (lua_type(L, -1) == LUA_TSTRING) {
              typeLabel = [NSString stringWithFormat:@"unrecognized type: %@", [skin toNSObjectAtIndex:-1]] ;
          } else {
              typeLabel = [NSString stringWithFormat:@"unrecognized type: %lu", CFGetTypeID(theItem)] ;
          }
          log_to_console(L, _cWARN, typeLabel) ;
          lua_pop(L, 2) ; // the table and the result of lua_rawget
          lua_pushstring(L, [typeLabel UTF8String]) ;
      }
    return 1 ;
}

static int pushCFTypeToLua(lua_State *L, CFTypeRef theItem) {
    NSMutableDictionary *alreadySeen = [[NSMutableDictionary alloc] init] ;
    pushCFTypeHamster(L, theItem, alreadySeen) ;
    for (id entry in alreadySeen) {
        luaL_unref(L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:entry] intValue]) ;
    }
    return 1 ;
}

// gets the count of items in a table irrespective of whether they are keyed or indexed
static lua_Integer countn (lua_State *L, int idx) {
  lua_Integer max = 0;
  luaL_checktype(L, idx, LUA_TTABLE);
  lua_pushnil(L);  /* first key */
  while (lua_next(L, idx)) {
    lua_pop(L, 1);  /* remove value */
    max++ ;
  }
  return max ;
}

// CFPropertyListRef types ( CFData, CFString, CFArray, CFDictionary, CFDate, CFBoolean, and CFNumber.),
// AXUIElementRef, AXValueRef, CFNullRef, CFAttributedStringRef, and CFURL min as per AXUIElement.h
// AXTextMarkerRef, and AXTextMarkerRangeRef mentioned as well, but private, so... no joy for now.
static CFTypeRef lua_toCFTypeHamster(lua_State *L, int idx, NSMutableDictionary *seen) {
    LuaSkin *skin = [LuaSkin shared] ;
    int index = lua_absindex(L, idx) ;
    NSLog(@"lua_toCFType: idx:%d abs:%d top:%d abstop:%d", idx, index, lua_gettop(L), lua_absindex(L, lua_gettop(L))) ;

    CFTypeRef value = kCFNull ;

    if ([seen objectForKey:[NSValue valueWithPointer:lua_topointer(L, index)]]) {
        my_lua_error(L, @"multiple references to same table not currently supported for conversion") ;
        // once I figure out (a) if we want to support this,
        //                   (b) if we should add a flag like we do for LuaSkin's NS version,
        //               and (c) the best way to store a CFTypeRef in an NSDictionary
        // value = CFRetain(pull CFTypeRef from @{seen}) ;
    } else if (lua_absindex(L, lua_gettop(L)) >= index) {
        int theType = lua_type(L, index) ;
        if (theType == LUA_TSTRING) {
            id holder = [skin toNSObjectAtIndex:index] ;
            if ([holder isKindOfClass:[NSString class]]) {
                value = (__bridge_retained CFStringRef)holder ;
            } else {
                value = (__bridge_retained CFDataRef)holder ;
            }
        } else if (theType == LUA_TBOOLEAN) {
            value = lua_toboolean(L, index) ? kCFBooleanTrue : kCFBooleanFalse ;
        } else if (theType == LUA_TNUMBER) {
            if (lua_isinteger(L, index)) {
                lua_Integer holder = lua_tointeger(L, index) ;
                value = CFNumberCreate(kCFAllocatorDefault, kCFNumberLongLongType, &holder) ;
            } else {
                lua_Number holder = lua_tonumber(L, index) ;
                value = CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &holder) ;
            }
        } else if (theType == LUA_TTABLE) {
        // rect, point, and size are regularly tables in Hammerspoon, differentiated by which of these
        // keys are present.
            BOOL hasX      = (lua_getfield(L, index, "x")        != LUA_TNIL) ; lua_pop(L, 1) ;
            BOOL hasY      = (lua_getfield(L, index, "y")        != LUA_TNIL) ; lua_pop(L, 1) ;
            BOOL hasH      = (lua_getfield(L, index, "h")        != LUA_TNIL) ; lua_pop(L, 1) ;
            BOOL hasW      = (lua_getfield(L, index, "w")        != LUA_TNIL) ; lua_pop(L, 1) ;
        // objc-style indexing for range
            BOOL hasLoc    = (lua_getfield(L, index, "location") != LUA_TNIL) ; lua_pop(L, 1) ;
            BOOL hasLen    = (lua_getfield(L, index, "length")   != LUA_TNIL) ; lua_pop(L, 1) ;
        // lua-style indexing for range
            BOOL hasStarts = (lua_getfield(L, index, "starts")   != LUA_TNIL) ; lua_pop(L, 1) ;
            BOOL hasEnds   = (lua_getfield(L, index, "ends")     != LUA_TNIL) ; lua_pop(L, 1) ;
        // AXError type
            BOOL hasError  = (lua_getfield(L, index, "_code")    != LUA_TNIL) ; lua_pop(L, 1) ;
        // since date is just a number or string, we'll have to make it a "psuedo" table so that it can
        // be uniquely specified on the lua side
            BOOL hasDate   = (lua_getfield(L, index, "_date")    != LUA_TNIL) ; lua_pop(L, 1) ;
        // since url is just a string, we'll have to make it a "psuedo" table so that it can be uniquely
        // specified on the lua side
            BOOL hasURL    = (lua_getfield(L, index, "_URL")     != LUA_TNIL) ; lua_pop(L, 1) ;

            if (hasX && hasY && hasH && hasW) { // CGRect
                lua_getfield(L, index, "x") ;
                lua_getfield(L, index, "y") ;
                lua_getfield(L, index, "w") ;
                lua_getfield(L, index, "h") ;
                CGRect holder = CGRectMake(luaL_checknumber(L, -4), luaL_checknumber(L, -3), luaL_checknumber(L, -2), luaL_checknumber(L, -1)) ;
                value = AXValueCreate(kAXValueCGRectType, &holder) ;
                lua_pop(L, 4) ;
            } else if (hasX && hasY) {          // CGPoint
                lua_getfield(L, index, "x") ;
                lua_getfield(L, index, "y") ;
                CGPoint holder = CGPointMake(luaL_checknumber(L, -2), luaL_checknumber(L, -1)) ;
                value = AXValueCreate(kAXValueCGPointType, &holder) ;
                lua_pop(L, 2) ;
            } else if (hasH && hasW) {          // CGSize
                lua_getfield(L, index, "w") ;
                lua_getfield(L, index, "h") ;
                CGSize holder = CGSizeMake(luaL_checknumber(L, -2), luaL_checknumber(L, -1)) ;
                value = AXValueCreate(kAXValueCGSizeType, &holder) ;
                lua_pop(L, 2) ;
            } else if (hasLoc && hasLen) {      // CFRange objc style
                lua_getfield(L, index, "location") ;
                lua_getfield(L, index, "length") ;
                CFRange holder = CFRangeMake(luaL_checkinteger(L, -2), luaL_checkinteger(L, -1)) ;
                value = AXValueCreate(kAXValueCFRangeType, &holder) ;
                lua_pop(L, 2) ;
            } else if (hasStarts && hasEnds) {  // CFRange lua style
// NOTE: Negative indexes and UTF8 as bytes can't be handled here without context.
//       Maybe on lua side in wrapper functions.
                lua_getfield(L, index, "starts") ;
                lua_getfield(L, index, "ends") ;
                lua_Integer starts = luaL_checkinteger(L, -2) ;
                lua_Integer ends   = luaL_checkinteger(L, -1) ;
                CFRange holder = CFRangeMake(starts - 1, ends + 1 - starts) ;
                value = AXValueCreate(kAXValueCFRangeType, &holder) ;
                lua_pop(L, 2) ;
            } else if (hasError) {              // AXError
                lua_getfield(L, index, "_code") ;
                AXError holder = (AXError)luaL_checkinteger(L, -1) ;
                value = AXValueCreate(kAXValueAXErrorType, &holder) ;
                lua_pop(L, 1) ;
            } else if (hasURL) {                // CFURL
                lua_getfield(L, index, "_url") ;
                value = CFURLCreateWithString(kCFAllocatorDefault, (__bridge CFStringRef)[skin toNSObjectAtIndex:-1], NULL) ;
                lua_pop(L, 1) ;
            } else if (hasDate) {               // CFDate
                int dateType = lua_getfield(L, index, "_date") ;
                if (dateType == LUA_TNUMBER) {
                    value = CFDateCreate(kCFAllocatorDefault, [[NSDate dateWithTimeIntervalSince1970:lua_tonumber(L, -1)] timeIntervalSinceReferenceDate]) ;
                } else if (dateType == LUA_TSTRING) {
                    // rfc3339 (Internet Date/Time) formated date.  More or less.
                    NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init] ;
                    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] ;
                    [rfc3339DateFormatter setLocale:enUSPOSIXLocale] ;
                    [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"] ;
                    [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]] ;
                    value = (__bridge_retained CFDateRef)[rfc3339DateFormatter dateFromString:[skin toNSObjectAtIndex:-1]] ;
                } else {
                    lua_pop(L, 1) ;
                    my_lua_error(L, @"invalid date format specified for conversion") ;
                    return kCFNull ;
                }
                lua_pop(L, 1) ;
            } else {                            // real CFDictionary or CFArray
              [seen setObject:@(YES) forKey:[NSValue valueWithPointer:lua_topointer(L, index)]] ;
              if (luaL_len(L, index) == countn(L, index)) { // CFArray
                  CFMutableArrayRef holder = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks) ;
                  for (lua_Integer i = 0 ; i < luaL_len(L, index) ; i++ ) {
                      lua_geti(L, index, i + 1) ;
                      CFTypeRef theVal = lua_toCFTypeHamster(L, -1, seen) ;
                      CFArrayAppendValue(holder, theVal) ;
                      if (theVal) CFRelease(theVal) ;
                      lua_pop(L, 1) ;
                      value = holder ;
                  }
              } else {                                      // CFDictionary
                  CFMutableDictionaryRef holder = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks) ;
                  lua_pushnil(L) ;
                  while (lua_next(L, index) != 0) {
                      CFTypeRef theKey = lua_toCFTypeHamster(L, -2, seen) ;
                      CFTypeRef theVal = lua_toCFTypeHamster(L, -1, seen) ;
                      CFDictionarySetValue(holder, theKey, theVal) ;
                      if (theKey) CFRelease(theKey) ;
                      if (theVal) CFRelease(theVal) ;
                      lua_pop(L, 1) ;
                      value = holder ;
                  }
              }
            }
        } else if (theType == LUA_TUSERDATA) {
            if (luaL_testudata(L, -1, "hs.styledtext")) {
                value = (__bridge_retained CFAttributedStringRef)[skin toNSObjectAtIndex:-1] ;
            } else if (luaL_testudata(L, -1, USERDATA_TAG)) {
                value = CFRetain(get_axuielementref(L, 1, USERDATA_TAG)) ;
            } else {
                lua_pop(L, -1) ;
                my_lua_error(L, @"unrecognized userdata is not supported for conversion") ;
                return kCFNull ;
            }
        } else if (theType != LUA_TNIL) { // value already set to kCFNull, no specific match necessary
            lua_pop(L, -1) ;
            my_lua_error(L, [NSString stringWithFormat:@"type %s not supported for conversion", lua_typename(L, theType)]) ;
            return kCFNull ;
        }
    }
    return value ;
}

static CFTypeRef lua_toCFType(lua_State *L, int idx) {
    NSMutableDictionary *seen = [[NSMutableDictionary alloc] init] ;
    return lua_toCFTypeHamster(L, idx, seen) ;
}

#pragma mark - Module Functions

static int getWindowElement(lua_State *L)      { return pushAXUIElement(L, get_axuielementref(L, 1, "hs.window")) ; }
static int getApplicationElement(lua_State *L) { return pushAXUIElement(L, get_axuielementref(L, 1, "hs.application")) ; }

static int getSystemWideElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
//     return pushAXUIElement(L, AXUIElementCreateSystemWide()) ;
    AXUIElementRef value = AXUIElementCreateSystemWide() ;
    pushAXUIElement(L, value) ;
    CFRelease(value) ;
    return 1 ;
}

static int getApplicationElementForPID(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER, LS_TBREAK] ;
    pid_t thePid = (pid_t)luaL_checkinteger(L, 1) ;
    AXUIElementRef value = AXUIElementCreateApplication(thePid) ;
    if (value && isApplicationOrSystem(value)) {
        pushAXUIElement(L, value) ;
        CFRelease(value) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int getAttributeNames(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFArrayRef attributeNames ;
    AXError errorState = AXUIElementCopyAttributeNames(theRef, &attributeNames) ;
    if (errorState == kAXErrorSuccess) {
        lua_newtable(L) ;
        for (id value in (__bridge NSArray *)attributeNames) {
            [skin pushNSObject:value] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else {
        errorWrapper(L, errorState) ;
    }
    if (attributeNames) CFRelease(attributeNames) ;
    return 1 ;
}

static int getActionNames(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFArrayRef attributeNames ;
    AXError errorState = AXUIElementCopyActionNames(theRef, &attributeNames) ;
    if (errorState == kAXErrorSuccess) {
        lua_newtable(L) ;
        for (id value in (__bridge NSArray *)attributeNames) {
            [skin pushNSObject:value] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else {
        errorWrapper(L, errorState) ;
    }
    if (attributeNames) CFRelease(attributeNames) ;
    return 1 ;
}

static int getActionDescription(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *action = [skin toNSObjectAtIndex:2] ;
    CFStringRef description ;
    AXError errorState = AXUIElementCopyActionDescription(theRef, (__bridge CFStringRef)action, &description) ;
    if (errorState == kAXErrorSuccess) {
        [skin pushNSObject:(__bridge NSString *)description] ;
    } else {
        errorWrapper(L, errorState) ;
    }
    if (description) CFRelease(description) ;
    return 1 ;
}

static int getAttributeValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *attribute = [skin toNSObjectAtIndex:2] ;
    CFTypeRef value ;
    AXError errorState = AXUIElementCopyAttributeValue(theRef, (__bridge CFStringRef)attribute, &value) ;
    if (errorState == kAXErrorSuccess) {
        pushCFTypeToLua(L, value) ;
    } else {
        errorWrapper(L, errorState) ;
    }
    if (value) CFRelease(value) ;
    return 1 ;
}

static int getAttributeValueCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *attribute = [skin toNSObjectAtIndex:2] ;
    CFIndex count ;
    AXError errorState = AXUIElementGetAttributeValueCount(theRef, (__bridge CFStringRef)attribute, &count) ;
    if (errorState == kAXErrorSuccess) {
        lua_pushinteger(L, count) ;
    } else {
        errorWrapper(L, errorState) ;
    }
    return 1 ;
}

static int getParameterizedAttributeNames(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFArrayRef attributeNames ;
    AXError errorState = AXUIElementCopyParameterizedAttributeNames(theRef, &attributeNames) ;
    if (errorState == kAXErrorSuccess) {
        lua_newtable(L) ;
        for (id value in (__bridge NSArray *)attributeNames) {
            [skin pushNSObject:value] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else {
        errorWrapper(L, errorState) ;
    }
    if (attributeNames) CFRelease(attributeNames) ;
    return 1 ;
}

static int isAttributeSettable(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *attribute = [skin toNSObjectAtIndex:2] ;
    Boolean settable ;
    AXError errorState = AXUIElementIsAttributeSettable(theRef, (__bridge CFStringRef)attribute, &settable) ;
    if (errorState == kAXErrorSuccess) {
        lua_pushboolean(L, settable) ;
    } else {
        errorWrapper(L, errorState) ;
    }
    return 1 ;
}

static int getPid(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    pid_t thePid ;
    AXError errorState = AXUIElementGetPid(theRef, &thePid) ;
    if (errorState == kAXErrorSuccess) {
        lua_pushinteger(L, (lua_Integer)thePid) ;
    } else {
        errorWrapper(L, errorState) ;
    }
    return 1 ;
}

static int performAction(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *action = [skin toNSObjectAtIndex:2] ;
    AXError errorState = AXUIElementPerformAction(theRef, (__bridge CFStringRef)action) ;
    if (errorState == kAXErrorSuccess) {
        lua_pushboolean(L, YES) ;
    } else if (errorState == kAXErrorCannotComplete) {
        lua_pushboolean(L, NO) ;
    } else {
        errorWrapper(L, errorState) ;
    }
    return 1 ;
}

static int getElementAtPosition(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TTABLE, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    if (isApplicationOrSystem(theRef)) {
        float x, y ;
        if (lua_type(L, 2) == LUA_TTABLE && lua_gettop(L) == 2) {
            NSPoint thePoint = [skin tableToPointAtIndex:2] ;
            x = (float)thePoint.x ;
            y = (float)thePoint.y ;
        } else if (lua_gettop(L) == 3) {
            x = (float)lua_tonumber(L, 2) ;
            y = (float)lua_tonumber(L, 3) ;
        } else {
            return my_lua_error(L, @"point table or x and y as numbers expected") ;
        }
        AXUIElementRef value ;
        AXError errorState = AXUIElementCopyElementAtPosition(theRef, x, y, &value) ;
        if (errorState == kAXErrorSuccess) {
            pushAXUIElement(L, value) ;
        } else {
            errorWrapper(L, errorState) ;
        }
        if (value) CFRelease(value) ;
    } else {
        return my_lua_error(L, @"must be application or systemWide element") ;
    }
    return 1 ;
}

static int getParameterizedAttributeValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TANY, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *attribute = [skin toNSObjectAtIndex:2] ;
    CFTypeRef parameter = lua_toCFType(L, 3) ;
    CFTypeRef value ;
    AXError errorState = AXUIElementCopyParameterizedAttributeValue(theRef, (__bridge CFStringRef)attribute, parameter, &value) ;
    if (errorState == kAXErrorSuccess) {
        pushCFTypeToLua(L, value) ;
    } else {
        errorWrapper(L, errorState) ;
    }
    if (value) CFRelease(value) ;
    if (parameter) CFRelease(parameter) ;
    return 1 ;
}

// AXError AXUIElementSetAttributeValue ( AXUIElementRef element, CFStringRef attribute, CFTypeRef value) ;
//
// CFPropertyListRef types ( CFData, CFString, CFArray, CFDictionary, CFDate, CFBoolean, and CFNumber.),
// AXUIElementRef, AXValueRef, CFNullRef, CFAttributedStringRef, and CFURL min as per AXUIElement.h
// AXTextMarkerRef, and AXTextMarkerRangeRef mentioned as well, but private, so... no joy for now.
static int setAttributeValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TANY, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *attribute = [skin toNSObjectAtIndex:2] ;
    CFTypeRef value = lua_toCFType(L, 3) ;
    AXError errorState = AXUIElementSetAttributeValue (theRef, (__bridge CFStringRef)attribute, value) ;
    if (errorState == kAXErrorSuccess) {
        lua_pushvalue(L, 1) ;
    } else {
        errorWrapper(L, errorState) ;
    }
    if (value) CFRelease(value) ;
    return 1 ;
}

#pragma mark - Module Constants


static int pushRolesTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXApplicationRole] ;        lua_setfield(L, -2, "application") ;
    [skin pushNSObject:(__bridge NSString *)kAXSystemWideRole] ;         lua_setfield(L, -2, "systemWide") ;
    [skin pushNSObject:(__bridge NSString *)kAXWindowRole] ;             lua_setfield(L, -2, "window") ;
    [skin pushNSObject:(__bridge NSString *)kAXSheetRole] ;              lua_setfield(L, -2, "sheet") ;
    [skin pushNSObject:(__bridge NSString *)kAXDrawerRole] ;             lua_setfield(L, -2, "drawer") ;
    [skin pushNSObject:(__bridge NSString *)kAXGrowAreaRole] ;           lua_setfield(L, -2, "growArea") ;
    [skin pushNSObject:(__bridge NSString *)kAXImageRole] ;              lua_setfield(L, -2, "image") ;
    [skin pushNSObject:(__bridge NSString *)kAXUnknownRole] ;            lua_setfield(L, -2, "unknown") ;
    [skin pushNSObject:(__bridge NSString *)kAXButtonRole] ;             lua_setfield(L, -2, "button") ;
    [skin pushNSObject:(__bridge NSString *)kAXRadioButtonRole] ;        lua_setfield(L, -2, "radioButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXCheckBoxRole] ;           lua_setfield(L, -2, "checkBox") ;
    [skin pushNSObject:(__bridge NSString *)kAXPopUpButtonRole] ;        lua_setfield(L, -2, "popUpButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuButtonRole] ;         lua_setfield(L, -2, "menuButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXTabGroupRole] ;           lua_setfield(L, -2, "tabGroup") ;
    [skin pushNSObject:(__bridge NSString *)kAXTableRole] ;              lua_setfield(L, -2, "table") ;
    [skin pushNSObject:(__bridge NSString *)kAXColumnRole] ;             lua_setfield(L, -2, "column") ;
    [skin pushNSObject:(__bridge NSString *)kAXRowRole] ;                lua_setfield(L, -2, "row") ;
    [skin pushNSObject:(__bridge NSString *)kAXOutlineRole] ;            lua_setfield(L, -2, "outline") ;
    [skin pushNSObject:(__bridge NSString *)kAXBrowserRole] ;            lua_setfield(L, -2, "browser") ;
    [skin pushNSObject:(__bridge NSString *)kAXScrollAreaRole] ;         lua_setfield(L, -2, "scrollArea") ;
    [skin pushNSObject:(__bridge NSString *)kAXScrollBarRole] ;          lua_setfield(L, -2, "scrollBar") ;
    [skin pushNSObject:(__bridge NSString *)kAXRadioGroupRole] ;         lua_setfield(L, -2, "radioGroup") ;
    [skin pushNSObject:(__bridge NSString *)kAXListRole] ;               lua_setfield(L, -2, "list") ;
    [skin pushNSObject:(__bridge NSString *)kAXGroupRole] ;              lua_setfield(L, -2, "group") ;
    [skin pushNSObject:(__bridge NSString *)kAXValueIndicatorRole] ;     lua_setfield(L, -2, "valueIndicator") ;
    [skin pushNSObject:(__bridge NSString *)kAXComboBoxRole] ;           lua_setfield(L, -2, "comboBox") ;
    [skin pushNSObject:(__bridge NSString *)kAXSliderRole] ;             lua_setfield(L, -2, "slider") ;
    [skin pushNSObject:(__bridge NSString *)kAXIncrementorRole] ;        lua_setfield(L, -2, "incrementor") ;
    [skin pushNSObject:(__bridge NSString *)kAXBusyIndicatorRole] ;      lua_setfield(L, -2, "busyIndicator") ;
    [skin pushNSObject:(__bridge NSString *)kAXProgressIndicatorRole] ;  lua_setfield(L, -2, "progressIndicator") ;
    [skin pushNSObject:(__bridge NSString *)kAXRelevanceIndicatorRole] ; lua_setfield(L, -2, "relevanceIndicator") ;
    [skin pushNSObject:(__bridge NSString *)kAXToolbarRole] ;            lua_setfield(L, -2, "toolbar") ;
    [skin pushNSObject:(__bridge NSString *)kAXDisclosureTriangleRole] ; lua_setfield(L, -2, "disclosureTriangle") ;
    [skin pushNSObject:(__bridge NSString *)kAXTextFieldRole] ;          lua_setfield(L, -2, "textField") ;
    [skin pushNSObject:(__bridge NSString *)kAXTextAreaRole] ;           lua_setfield(L, -2, "textArea") ;
    [skin pushNSObject:(__bridge NSString *)kAXStaticTextRole] ;         lua_setfield(L, -2, "staticText") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuBarRole] ;            lua_setfield(L, -2, "menuBar") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuBarItemRole] ;        lua_setfield(L, -2, "menuBarItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuRole] ;               lua_setfield(L, -2, "menu") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuItemRole] ;           lua_setfield(L, -2, "menuItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXSplitGroupRole] ;         lua_setfield(L, -2, "splitGroup") ;
    [skin pushNSObject:(__bridge NSString *)kAXSplitterRole] ;           lua_setfield(L, -2, "splitter") ;
    [skin pushNSObject:(__bridge NSString *)kAXColorWellRole] ;          lua_setfield(L, -2, "colorWell") ;
    [skin pushNSObject:(__bridge NSString *)kAXTimeFieldRole] ;          lua_setfield(L, -2, "timeField") ;
    [skin pushNSObject:(__bridge NSString *)kAXDateFieldRole] ;          lua_setfield(L, -2, "dateField") ;
    [skin pushNSObject:(__bridge NSString *)kAXHelpTagRole] ;            lua_setfield(L, -2, "helpTag") ;
    [skin pushNSObject:(__bridge NSString *)kAXMatteRole] ;              lua_setfield(L, -2, "matteRole") ;
    [skin pushNSObject:(__bridge NSString *)kAXDockItemRole] ;           lua_setfield(L, -2, "dockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXCellRole] ;               lua_setfield(L, -2, "cell") ;
    [skin pushNSObject:(__bridge NSString *)kAXGridRole] ;               lua_setfield(L, -2, "grid") ;
    [skin pushNSObject:(__bridge NSString *)kAXHandleRole] ;             lua_setfield(L, -2, "handle") ;
    [skin pushNSObject:(__bridge NSString *)kAXLayoutAreaRole] ;         lua_setfield(L, -2, "layoutArea") ;
    [skin pushNSObject:(__bridge NSString *)kAXLayoutItemRole] ;         lua_setfield(L, -2, "layoutItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXLevelIndicatorRole] ;     lua_setfield(L, -2, "levelIndicator") ;
    [skin pushNSObject:(__bridge NSString *)kAXPopoverRole] ;            lua_setfield(L, -2, "popover") ;
    [skin pushNSObject:(__bridge NSString *)kAXRulerMarkerRole] ;        lua_setfield(L, -2, "rulerMarker") ;
    [skin pushNSObject:(__bridge NSString *)kAXRulerRole] ;              lua_setfield(L, -2, "ruler") ;
    return 1 ;
}

static int pushSubrolesTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXCloseButtonSubrole] ;             lua_setfield(L, -2, "closeButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXMinimizeButtonSubrole] ;          lua_setfield(L, -2, "minimizeButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXZoomButtonSubrole] ;              lua_setfield(L, -2, "zoomButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXToolbarButtonSubrole] ;           lua_setfield(L, -2, "toolbarButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXSecureTextFieldSubrole] ;         lua_setfield(L, -2, "secureTextField") ;
    [skin pushNSObject:(__bridge NSString *)kAXTableRowSubrole] ;                lua_setfield(L, -2, "tableRow") ;
    [skin pushNSObject:(__bridge NSString *)kAXOutlineRowSubrole] ;              lua_setfield(L, -2, "outlineRow") ;
    [skin pushNSObject:(__bridge NSString *)kAXUnknownSubrole] ;                 lua_setfield(L, -2, "unknown") ;
    [skin pushNSObject:(__bridge NSString *)kAXStandardWindowSubrole] ;          lua_setfield(L, -2, "standardWindow") ;
    [skin pushNSObject:(__bridge NSString *)kAXDialogSubrole] ;                  lua_setfield(L, -2, "dialog") ;
    [skin pushNSObject:(__bridge NSString *)kAXSystemDialogSubrole] ;            lua_setfield(L, -2, "systemDialog") ;
    [skin pushNSObject:(__bridge NSString *)kAXFloatingWindowSubrole] ;          lua_setfield(L, -2, "floatingWindow") ;
    [skin pushNSObject:(__bridge NSString *)kAXSystemFloatingWindowSubrole] ;    lua_setfield(L, -2, "systemFloatingWindow") ;
    [skin pushNSObject:(__bridge NSString *)kAXIncrementArrowSubrole] ;          lua_setfield(L, -2, "incrementArrow") ;
    [skin pushNSObject:(__bridge NSString *)kAXDecrementArrowSubrole] ;          lua_setfield(L, -2, "decrementArrow") ;
    [skin pushNSObject:(__bridge NSString *)kAXIncrementPageSubrole] ;           lua_setfield(L, -2, "incrementPage") ;
    [skin pushNSObject:(__bridge NSString *)kAXDecrementPageSubrole] ;           lua_setfield(L, -2, "decrementPage") ;
    [skin pushNSObject:(__bridge NSString *)kAXSortButtonSubrole] ;              lua_setfield(L, -2, "sortButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXSearchFieldSubrole] ;             lua_setfield(L, -2, "searchField") ;
    [skin pushNSObject:(__bridge NSString *)kAXApplicationDockItemSubrole] ;     lua_setfield(L, -2, "applicationDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXDocumentDockItemSubrole] ;        lua_setfield(L, -2, "documentDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXFolderDockItemSubrole] ;          lua_setfield(L, -2, "folderDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXMinimizedWindowDockItemSubrole] ; lua_setfield(L, -2, "minimizedWindowDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXURLDockItemSubrole] ;             lua_setfield(L, -2, "URLDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXDockExtraDockItemSubrole] ;       lua_setfield(L, -2, "dockExtraDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXTrashDockItemSubrole] ;           lua_setfield(L, -2, "trashDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXProcessSwitcherListSubrole] ;     lua_setfield(L, -2, "processSwitcherList") ;
    [skin pushNSObject:(__bridge NSString *)kAXContentListSubrole] ;             lua_setfield(L, -2, "contentList") ;
    [skin pushNSObject:(__bridge NSString *)kAXDescriptionListSubrole] ;         lua_setfield(L, -2, "descriptionList") ;
    [skin pushNSObject:(__bridge NSString *)kAXFullScreenButtonSubrole] ;        lua_setfield(L, -2, "fullScreenButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXRatingIndicatorSubrole] ;         lua_setfield(L, -2, "ratingIndicator") ;
    [skin pushNSObject:(__bridge NSString *)kAXSeparatorDockItemSubrole] ;       lua_setfield(L, -2, "separatorDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXSwitchSubrole] ;                  lua_setfield(L, -2, "switch") ;
    [skin pushNSObject:(__bridge NSString *)kAXTimelineSubrole] ;                lua_setfield(L, -2, "timeline") ;
    [skin pushNSObject:(__bridge NSString *)kAXToggleSubrole] ;                  lua_setfield(L, -2, "toggle") ;
    return 1 ;
}

static int pushAttributesTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
//General attributes
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXRoleAttribute] ;              lua_setfield(L, -2, "role") ;
    [skin pushNSObject:(__bridge NSString *)kAXSubroleAttribute] ;           lua_setfield(L, -2, "subrole") ;
    [skin pushNSObject:(__bridge NSString *)kAXRoleDescriptionAttribute] ;   lua_setfield(L, -2, "roleDescription") ;
    [skin pushNSObject:(__bridge NSString *)kAXHelpAttribute] ;              lua_setfield(L, -2, "help") ;
    [skin pushNSObject:(__bridge NSString *)kAXTitleAttribute] ;             lua_setfield(L, -2, "title") ;
    [skin pushNSObject:(__bridge NSString *)kAXValueAttribute] ;             lua_setfield(L, -2, "value") ;
    [skin pushNSObject:(__bridge NSString *)kAXMinValueAttribute] ;          lua_setfield(L, -2, "minValue") ;
    [skin pushNSObject:(__bridge NSString *)kAXMaxValueAttribute] ;          lua_setfield(L, -2, "maxValue") ;
    [skin pushNSObject:(__bridge NSString *)kAXValueIncrementAttribute] ;    lua_setfield(L, -2, "valueIncrement") ;
    [skin pushNSObject:(__bridge NSString *)kAXAllowedValuesAttribute] ;     lua_setfield(L, -2, "allowedValues") ;
    [skin pushNSObject:(__bridge NSString *)kAXEnabledAttribute] ;           lua_setfield(L, -2, "enabled") ;
    [skin pushNSObject:(__bridge NSString *)kAXFocusedAttribute] ;           lua_setfield(L, -2, "focused") ;
    [skin pushNSObject:(__bridge NSString *)kAXParentAttribute] ;            lua_setfield(L, -2, "parent") ;
    [skin pushNSObject:(__bridge NSString *)kAXChildrenAttribute] ;          lua_setfield(L, -2, "children") ;
    [skin pushNSObject:(__bridge NSString *)kAXSelectedChildrenAttribute] ;  lua_setfield(L, -2, "selectedChildren") ;
    [skin pushNSObject:(__bridge NSString *)kAXVisibleChildrenAttribute] ;   lua_setfield(L, -2, "visibleChildren") ;
    [skin pushNSObject:(__bridge NSString *)kAXWindowAttribute] ;            lua_setfield(L, -2, "window") ;
    [skin pushNSObject:(__bridge NSString *)kAXTopLevelUIElementAttribute] ; lua_setfield(L, -2, "topLevelUIElement") ;
    [skin pushNSObject:(__bridge NSString *)kAXPositionAttribute] ;          lua_setfield(L, -2, "position") ;
    [skin pushNSObject:(__bridge NSString *)kAXSizeAttribute] ;              lua_setfield(L, -2, "size") ;
    [skin pushNSObject:(__bridge NSString *)kAXOrientationAttribute] ;       lua_setfield(L, -2, "orientation") ;
    [skin pushNSObject:(__bridge NSString *)kAXDescriptionAttribute] ;       lua_setfield(L, -2, "description") ;
    lua_setfield(L, -2, "general") ;
// Text-specific attributes
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXSelectedTextAttribute] ;          lua_setfield(L, -2, "selectedText") ;
    [skin pushNSObject:(__bridge NSString *)kAXVisibleCharacterRangeAttribute] ; lua_setfield(L, -2, "visibleCharacterRange") ;
    [skin pushNSObject:(__bridge NSString *)kAXSelectedTextRangeAttribute] ;     lua_setfield(L, -2, "selectedTextRange") ;
    [skin pushNSObject:(__bridge NSString *)kAXNumberOfCharactersAttribute] ;    lua_setfield(L, -2, "numberOfCharacters") ;
    [skin pushNSObject:(__bridge NSString *)kAXSharedTextUIElementsAttribute] ;  lua_setfield(L, -2, "sharedTextUIElements") ;
    [skin pushNSObject:(__bridge NSString *)kAXSharedCharacterRangeAttribute] ;  lua_setfield(L, -2, "sharedCharacterRange") ;
    lua_setfield(L, -2, "text") ;
// Window-specific attributes
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXMainAttribute] ;           lua_setfield(L, -2, "main") ;
    [skin pushNSObject:(__bridge NSString *)kAXMinimizedAttribute] ;      lua_setfield(L, -2, "minimized") ;
    [skin pushNSObject:(__bridge NSString *)kAXCloseButtonAttribute] ;    lua_setfield(L, -2, "closeButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXZoomButtonAttribute] ;     lua_setfield(L, -2, "zoomButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXMinimizeButtonAttribute] ; lua_setfield(L, -2, "minimizeButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXToolbarButtonAttribute] ;  lua_setfield(L, -2, "toolbarButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXGrowAreaAttribute] ;       lua_setfield(L, -2, "growArea") ;
    [skin pushNSObject:(__bridge NSString *)kAXProxyAttribute] ;          lua_setfield(L, -2, "proxy") ;
    [skin pushNSObject:(__bridge NSString *)kAXModalAttribute] ;          lua_setfield(L, -2, "modal") ;
    [skin pushNSObject:(__bridge NSString *)kAXDefaultButtonAttribute] ;  lua_setfield(L, -2, "defaultButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXCancelButtonAttribute] ;   lua_setfield(L, -2, "cancelButton") ;
    lua_setfield(L, -2, "window") ;
// Menu-specific attributes
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuItemCmdCharAttribute] ;          lua_setfield(L, -2, "menuItemCmdChar") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuItemCmdVirtualKeyAttribute] ;    lua_setfield(L, -2, "menuItemCmdVirtualKey") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuItemCmdGlyphAttribute] ;         lua_setfield(L, -2, "menuItemCmdGlyph") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuItemCmdModifiersAttribute] ;     lua_setfield(L, -2, "menuItemCmdModifiers") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuItemMarkCharAttribute] ;         lua_setfield(L, -2, "menuItemMarkChar") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuItemPrimaryUIElementAttribute] ; lua_setfield(L, -2, "menuItemPrimaryUIElement") ;
    lua_setfield(L, -2, "menu") ;
// Application-specific attributes
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuBarAttribute] ;          lua_setfield(L, -2, "menuBar") ;
    [skin pushNSObject:(__bridge NSString *)kAXWindowsAttribute] ;          lua_setfield(L, -2, "windows") ;
    [skin pushNSObject:(__bridge NSString *)kAXFrontmostAttribute] ;        lua_setfield(L, -2, "frontmost") ;
    [skin pushNSObject:(__bridge NSString *)kAXHiddenAttribute] ;           lua_setfield(L, -2, "hidden") ;
    [skin pushNSObject:(__bridge NSString *)kAXMainWindowAttribute] ;       lua_setfield(L, -2, "mainWindow") ;
    [skin pushNSObject:(__bridge NSString *)kAXFocusedWindowAttribute] ;    lua_setfield(L, -2, "focusedWindow") ;
    [skin pushNSObject:(__bridge NSString *)kAXFocusedUIElementAttribute] ; lua_setfield(L, -2, "focusedUIElement") ;
    lua_setfield(L, -2, "application") ;
// Miscellaneous attributes
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXHeaderAttribute] ;                     lua_setfield(L, -2, "header") ;
    [skin pushNSObject:(__bridge NSString *)kAXEditedAttribute] ;                     lua_setfield(L, -2, "edited") ;
    [skin pushNSObject:(__bridge NSString *)kAXValueWrapsAttribute] ;                 lua_setfield(L, -2, "valueWraps") ;
    [skin pushNSObject:(__bridge NSString *)kAXTabsAttribute] ;                       lua_setfield(L, -2, "tabs") ;
    [skin pushNSObject:(__bridge NSString *)kAXTitleUIElementAttribute] ;             lua_setfield(L, -2, "titleUIElement") ;
    [skin pushNSObject:(__bridge NSString *)kAXHorizontalScrollBarAttribute] ;        lua_setfield(L, -2, "horizontalScrollBar") ;
    [skin pushNSObject:(__bridge NSString *)kAXVerticalScrollBarAttribute] ;          lua_setfield(L, -2, "verticalScrollBar") ;
    [skin pushNSObject:(__bridge NSString *)kAXOverflowButtonAttribute] ;             lua_setfield(L, -2, "overflowButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXFilenameAttribute] ;                   lua_setfield(L, -2, "filename") ;
    [skin pushNSObject:(__bridge NSString *)kAXExpandedAttribute] ;                   lua_setfield(L, -2, "expanded") ;
    [skin pushNSObject:(__bridge NSString *)kAXSelectedAttribute] ;                   lua_setfield(L, -2, "selected") ;
    [skin pushNSObject:(__bridge NSString *)kAXSplittersAttribute] ;                  lua_setfield(L, -2, "splitters") ;
    [skin pushNSObject:(__bridge NSString *)kAXNextContentsAttribute] ;               lua_setfield(L, -2, "nextContents") ;
    [skin pushNSObject:(__bridge NSString *)kAXDocumentAttribute] ;                   lua_setfield(L, -2, "document") ;
    [skin pushNSObject:(__bridge NSString *)kAXDecrementButtonAttribute] ;            lua_setfield(L, -2, "decrementButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXIncrementButtonAttribute] ;            lua_setfield(L, -2, "incrementButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXPreviousContentsAttribute] ;           lua_setfield(L, -2, "previousContents") ;
    [skin pushNSObject:(__bridge NSString *)kAXContentsAttribute] ;                   lua_setfield(L, -2, "contents") ;
    [skin pushNSObject:(__bridge NSString *)kAXIncrementorAttribute] ;                lua_setfield(L, -2, "incrementor") ;
    [skin pushNSObject:(__bridge NSString *)kAXHourFieldAttribute] ;                  lua_setfield(L, -2, "hourField") ;
    [skin pushNSObject:(__bridge NSString *)kAXMinuteFieldAttribute] ;                lua_setfield(L, -2, "minuteField") ;
    [skin pushNSObject:(__bridge NSString *)kAXSecondFieldAttribute] ;                lua_setfield(L, -2, "secondField") ;
    [skin pushNSObject:(__bridge NSString *)kAXAMPMFieldAttribute] ;                  lua_setfield(L, -2, "AMPMField") ;
    [skin pushNSObject:(__bridge NSString *)kAXDayFieldAttribute] ;                   lua_setfield(L, -2, "dayField") ;
    [skin pushNSObject:(__bridge NSString *)kAXMonthFieldAttribute] ;                 lua_setfield(L, -2, "monthField") ;
    [skin pushNSObject:(__bridge NSString *)kAXYearFieldAttribute] ;                  lua_setfield(L, -2, "yearField") ;
    [skin pushNSObject:(__bridge NSString *)kAXColumnTitleAttribute] ;                lua_setfield(L, -2, "columnTitles") ;
    [skin pushNSObject:(__bridge NSString *)kAXURLAttribute] ;                        lua_setfield(L, -2, "URL") ;
    [skin pushNSObject:(__bridge NSString *)kAXLabelUIElementsAttribute] ;            lua_setfield(L, -2, "labelUIElements") ;
    [skin pushNSObject:(__bridge NSString *)kAXLabelValueAttribute] ;                 lua_setfield(L, -2, "labelValue") ;
    [skin pushNSObject:(__bridge NSString *)kAXShownMenuUIElementAttribute] ;         lua_setfield(L, -2, "shownMenuUIElement") ;
    [skin pushNSObject:(__bridge NSString *)kAXServesAsTitleForUIElementsAttribute] ; lua_setfield(L, -2, "servesAsTitleForUIElements") ;
    [skin pushNSObject:(__bridge NSString *)kAXLinkedUIElementsAttribute] ;           lua_setfield(L, -2, "linkedUIElements") ;
    lua_setfield(L, -2, "misc") ;
// Table and outline view attributes
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXRowsAttribute] ;                   lua_setfield(L, -2, "rows") ;
    [skin pushNSObject:(__bridge NSString *)kAXVisibleRowsAttribute] ;            lua_setfield(L, -2, "visibleRows") ;
    [skin pushNSObject:(__bridge NSString *)kAXSelectedRowsAttribute] ;           lua_setfield(L, -2, "selectedRows") ;
    [skin pushNSObject:(__bridge NSString *)kAXColumnsAttribute] ;                lua_setfield(L, -2, "columns") ;
    [skin pushNSObject:(__bridge NSString *)kAXVisibleColumnsAttribute] ;         lua_setfield(L, -2, "visibleColumns") ;
    [skin pushNSObject:(__bridge NSString *)kAXSelectedColumnsAttribute] ;        lua_setfield(L, -2, "selectedColumns") ;
    [skin pushNSObject:(__bridge NSString *)kAXSortDirectionAttribute] ;          lua_setfield(L, -2, "sortDirection") ;
    [skin pushNSObject:(__bridge NSString *)kAXColumnHeaderUIElementsAttribute] ; lua_setfield(L, -2, "columnHeaderUIElements") ;
    [skin pushNSObject:(__bridge NSString *)kAXIndexAttribute] ;                  lua_setfield(L, -2, "index") ;
    [skin pushNSObject:(__bridge NSString *)kAXDisclosingAttribute] ;             lua_setfield(L, -2, "disclosing") ;
    [skin pushNSObject:(__bridge NSString *)kAXDisclosedRowsAttribute] ;          lua_setfield(L, -2, "disclosedRows") ;
    [skin pushNSObject:(__bridge NSString *)kAXDisclosedByRowAttribute] ;         lua_setfield(L, -2, "disclosedByRow") ;
    lua_setfield(L, -2, "table") ;
// Matte attributes
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXMatteHoleAttribute] ;             lua_setfield(L, -2, "matteHole") ;
    [skin pushNSObject:(__bridge NSString *)kAXMatteContentUIElementAttribute] ; lua_setfield(L, -2, "matteContentUIElement") ;
    lua_setfield(L, -2, "matte") ;
// Dock attributes
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXIsApplicationRunningAttribute] ; lua_setfield(L, -2, "isApplicationRunning") ;
    lua_setfield(L, -2, "dock") ;
// System-wide attributes
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXFocusedApplicationAttribute] ; lua_setfield(L, -2, "focusedApplication") ;
    lua_setfield(L, -2, "system") ;
    return 1 ;
}

static int pushParamaterizedAttributesTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXLineForIndexParameterizedAttribute] ;             lua_setfield(L, -2, "lineForIndex") ;
    [skin pushNSObject:(__bridge NSString *)kAXRangeForLineParameterizedAttribute] ;             lua_setfield(L, -2, "rangeForLine") ;
    [skin pushNSObject:(__bridge NSString *)kAXStringForRangeParameterizedAttribute] ;           lua_setfield(L, -2, "stringForRange") ;
    [skin pushNSObject:(__bridge NSString *)kAXRangeForPositionParameterizedAttribute] ;         lua_setfield(L, -2, "rangeForPosition") ;
    [skin pushNSObject:(__bridge NSString *)kAXRangeForIndexParameterizedAttribute] ;            lua_setfield(L, -2, "rangeForIndex") ;
    [skin pushNSObject:(__bridge NSString *)kAXBoundsForRangeParameterizedAttribute] ;           lua_setfield(L, -2, "boundsForRange") ;
    [skin pushNSObject:(__bridge NSString *)kAXRTFForRangeParameterizedAttribute] ;              lua_setfield(L, -2, "RTFForRange") ;
    [skin pushNSObject:(__bridge NSString *)kAXAttributedStringForRangeParameterizedAttribute] ; lua_setfield(L, -2, "attributedStringForRange") ;
    [skin pushNSObject:(__bridge NSString *)kAXStyleRangeForIndexParameterizedAttribute] ;       lua_setfield(L, -2, "styleRangeForIndex") ;
    [skin pushNSObject:(__bridge NSString *)kAXInsertionPointLineNumberAttribute] ;              lua_setfield(L, -2, "insertionPointLineNumber") ;
    return 1 ;
}

static int pushActionsTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXPressAction] ;           lua_setfield(L, -2, "press") ;
    [skin pushNSObject:(__bridge NSString *)kAXIncrementAction] ;       lua_setfield(L, -2, "increment") ;
    [skin pushNSObject:(__bridge NSString *)kAXDecrementAction] ;       lua_setfield(L, -2, "decrement") ;
    [skin pushNSObject:(__bridge NSString *)kAXConfirmAction] ;         lua_setfield(L, -2, "confirm") ;
    [skin pushNSObject:(__bridge NSString *)kAXCancelAction] ;          lua_setfield(L, -2, "cancel") ;
    [skin pushNSObject:(__bridge NSString *)kAXRaiseAction] ;           lua_setfield(L, -2, "raise") ;
    [skin pushNSObject:(__bridge NSString *)kAXShowMenuAction] ;        lua_setfield(L, -2, "showMenu") ;
    [skin pushNSObject:(__bridge NSString *)kAXShowAlternateUIAction] ; lua_setfield(L, -2, "showAlternateUI") ;
    [skin pushNSObject:(__bridge NSString *)kAXShowDefaultUIAction] ;   lua_setfield(L, -2, "showDefaultUI") ;
    [skin pushNSObject:(__bridge NSString *)kAXPickAction] ;            lua_setfield(L, -2, "pick") ;
    return 1 ;
}

static int pushNotificationsTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
// Focus notifications
    [skin pushNSObject:(__bridge NSString *)kAXMainWindowChangedNotification] ;       lua_setfield(L, -2, "mainWindowChanged") ;
    [skin pushNSObject:(__bridge NSString *)kAXFocusedWindowChangedNotification] ;    lua_setfield(L, -2, "focusedWindowChanged") ;
    [skin pushNSObject:(__bridge NSString *)kAXFocusedUIElementChangedNotification] ; lua_setfield(L, -2, "focusedUIElementChanged") ;
// Application notifications
    [skin pushNSObject:(__bridge NSString *)kAXApplicationActivatedNotification] ;    lua_setfield(L, -2, "applicationActivated") ;
    [skin pushNSObject:(__bridge NSString *)kAXApplicationDeactivatedNotification] ;  lua_setfield(L, -2, "applicationDeactivated") ;
    [skin pushNSObject:(__bridge NSString *)kAXApplicationHiddenNotification] ;       lua_setfield(L, -2, "applicationHidden") ;
    [skin pushNSObject:(__bridge NSString *)kAXApplicationShownNotification] ;        lua_setfield(L, -2, "applicationShown") ;
// Window notifications
    [skin pushNSObject:(__bridge NSString *)kAXWindowCreatedNotification] ;           lua_setfield(L, -2, "windowCreated") ;
    [skin pushNSObject:(__bridge NSString *)kAXWindowMovedNotification] ;             lua_setfield(L, -2, "windowMoved") ;
    [skin pushNSObject:(__bridge NSString *)kAXWindowResizedNotification] ;           lua_setfield(L, -2, "windowResized") ;
    [skin pushNSObject:(__bridge NSString *)kAXWindowMiniaturizedNotification] ;      lua_setfield(L, -2, "windowMiniaturized") ;
    [skin pushNSObject:(__bridge NSString *)kAXWindowDeminiaturizedNotification] ;    lua_setfield(L, -2, "windowDeminiaturized") ;
// New drawer, sheet, and help tag notifications
    [skin pushNSObject:(__bridge NSString *)kAXDrawerCreatedNotification] ;           lua_setfield(L, -2, "drawerCreated") ;
    [skin pushNSObject:(__bridge NSString *)kAXSheetCreatedNotification] ;            lua_setfield(L, -2, "sheetCreated") ;
    [skin pushNSObject:(__bridge NSString *)kAXHelpTagCreatedNotification] ;          lua_setfield(L, -2, "helpTagCreated") ;
// Element notifications
    [skin pushNSObject:(__bridge NSString *)kAXValueChangedNotification] ;            lua_setfield(L, -2, "valueChanged") ;
    [skin pushNSObject:(__bridge NSString *)kAXUIElementDestroyedNotification] ;      lua_setfield(L, -2, "UIElementDestroyed") ;
// Menu notifications
    [skin pushNSObject:(__bridge NSString *)kAXMenuOpenedNotification] ;              lua_setfield(L, -2, "menuOpened") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuClosedNotification] ;              lua_setfield(L, -2, "menuClosed") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuItemSelectedNotification] ;        lua_setfield(L, -2, "menuItemSelected") ;
// Table and outline view notifications
    [skin pushNSObject:(__bridge NSString *)kAXRowCountChangedNotification] ;         lua_setfield(L, -2, "rowCountChanged") ;
// Miscellaneous notifications
    [skin pushNSObject:(__bridge NSString *)kAXSelectedChildrenChangedNotification] ; lua_setfield(L, -2, "selectedChildrenChanged") ;
    [skin pushNSObject:(__bridge NSString *)kAXResizedNotification] ;                 lua_setfield(L, -2, "resized") ;
    [skin pushNSObject:(__bridge NSString *)kAXMovedNotification] ;                   lua_setfield(L, -2, "moved") ;
    [skin pushNSObject:(__bridge NSString *)kAXCreatedNotification] ;                 lua_setfield(L, -2, "created") ;
    return 1 ;
}


static int pushDirectionsTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
// Orientations
    [skin pushNSObject:(__bridge NSString *)kAXHorizontalOrientationValue] ; lua_setfield(L, -2, "HorizontalOrientation") ;
    [skin pushNSObject:(__bridge NSString *)kAXVerticalOrientationValue] ; lua_setfield(L, -2, "VerticalOrientation") ;
    [skin pushNSObject:(__bridge NSString *)kAXUnknownOrientationValue] ; lua_setfield(L, -2, "UnknownOrientation") ;
// Sort directions
    [skin pushNSObject:(__bridge NSString *)kAXAscendingSortDirectionValue] ; lua_setfield(L, -2, "AscendingSortDirection") ;
    [skin pushNSObject:(__bridge NSString *)kAXDescendingSortDirectionValue] ; lua_setfield(L, -2, "DescendingSortDirection") ;
    [skin pushNSObject:(__bridge NSString *)kAXUnknownSortDirectionValue] ; lua_setfield(L, -2, "UnknownSortDirection") ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFTypeRef value ;
    AXError errorState = AXUIElementCopyAttributeValue(theRef, (__bridge CFStringRef)@"AXRole", &value) ;
    NSString *title = @"*AXRole undefined*" ;
    if (errorState == kAXErrorSuccess) {
        title = (__bridge NSString *)value ;
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, theRef]] ;
    if (value) CFRelease(value) ;
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
    {"parameterizedAttributeValue", getParameterizedAttributeValue},
    {"attributeValueCount",         getAttributeValueCount},
    {"isAttributeSettable",         isAttributeSettable},
    {"pid",                         getPid},
    {"performAction",               performAction},
    {"elementAtPosition",           getElementAtPosition},
    {"setAttributeValue",           setAttributeValue},

    {"__tostring",                  userdata_tostring},
    {"__eq",                        userdata_eq},
    {"__gc",                        userdata_gc},
    {NULL,                          NULL}
} ;

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"systemWideElement",        getSystemWideElement},
    {"windowElement",            getWindowElement},
    {"applicationElement",       getApplicationElement},
    {"applicationElementForPID", getApplicationElementForPID},

    {"_registerLogForC",         lua_registerLogForC},
    {NULL,                       NULL}
} ;

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// } ;

int luaopen_hs__asm_axuielement_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib] ;

// For reference, since the object __init wrapper in init.lua and the keys for elementSearch don't
// actually use them in case the user wants to use an Application defined attribute or action not
// defined in the OS X headers.
    pushAttributesTable(L) ;              lua_setfield(L, -2, "attributes") ;
    pushParamaterizedAttributesTable(L) ; lua_setfield(L, -2, "parameterizedAttributes") ;
    pushActionsTable(L) ;                 lua_setfield(L, -2, "actions") ;

// ditto on these, since they are are actually results, not query-able parameters or actionable
// commands; however they can be used with elementSearch as values in the criteria to find such.
    pushRolesTable(L) ;                   lua_setfield(L, -2, "roles") ;
    pushSubrolesTable(L) ;                lua_setfield(L, -2, "subroles") ;
    pushDirectionsTable(L) ;              lua_setfield(L, -2, "directions") ;

// not sure about this yet... we're not handling observers (yet? that gets into what I believe
// hs.uielement is for (I really should check it out again), so the questions are does this offer
// more and can/should we extend that instead?)
    pushNotificationsTable(L) ;           lua_setfield(L, -2, "notifications") ;

    return 1 ;
}
