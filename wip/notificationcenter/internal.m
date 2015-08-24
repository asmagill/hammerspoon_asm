#import <Cocoa/Cocoa.h>

#import   <AddressBook/AddressBook.h>
#import   <AddressBook/ABPeoplePickerView.h>
#import   <Accounts/Accounts.h>
#import   <AVFoundation/AVFoundation.h>
#import   <DiscRecordingUI/DiscRecordingUI.h>
#import   <EventKit/EventKit.h>
#import   <GameController/GameController.h>
#import   <IOBluetooth/IOBluetooth.h>
#import   <Kerberos/Kerberos.h>
#import   <MapKit/MapKit.h>
#import   <MediaAccessibility/MediaAccessibility.h>
#import   <PreferencePanes/PreferencePanes.h>
#import   <Quartz/Quartz.h>
#import   <WebKit/WebKit.h>

#import   <CalendarStore/CalendarStore.h>
#import   <CoreWLAN/CoreWLAN.h>
#import   <InstantMessage/IMAVManager.h>
#import   <PubSub/PubSub.h>
#import   <QTKit/QTKit.h>
#import   <SyncServices/SyncServices.h>

#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#define USERDATA_TAG    "hs._asm.notificationcenter"

@interface HSNotificationCenterClass : NSObject
    @property int fn;
    @property NSNotificationCenter *whichCenter ;
    @property NSString *notificationName ;
@end

@implementation HSNotificationCenterClass
    - (void) heard:(NSNotification*)note {
        if (self.fn != LUA_NOREF) {
            LuaSkin *skin = [LuaSkin shared];
            lua_State *_L = skin.L;
            lua_rawgeti(_L, LUA_REGISTRYINDEX, self.fn);
            lua_pushstring(_L, [[note name] UTF8String]);
            [skin pushNSObject:[note object]] ;
            [skin pushNSObject:[note userInfo]] ;
            if (![skin protectedCallAndTraceback:3 nresults:0]) {
                const char *errorMsg = lua_tostring(_L, -1);
                showError(_L, (char *)errorMsg);
            }
        }
    }
@end

static int commonObserverConstruction(lua_State *L, NSNotificationCenter *nc) {
    NSString *notificationName ;

    luaL_checktype(L, 1, LUA_TFUNCTION);
    if (lua_isstring(L, 2)) {
        notificationName = [NSString stringWithUTF8String:luaL_checkstring(L, 2)] ;
    }

    HSNotificationCenterClass* listener = [[HSNotificationCenterClass alloc] init];

    lua_pushvalue(L, 1);
    listener.fn               = luaL_ref(L, LUA_REGISTRYINDEX) ;
    listener.whichCenter      = nc ;
    listener.notificationName = notificationName ;

    void** ud = lua_newuserdata(L, sizeof(id*)) ;
    *ud = (__bridge_retained void*)listener ;

    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;

    return 1;
}

/// hs._asm.notificationcenter.distributedObserver(fn, [name]) -> notificationcenter
/// Constructor
/// Registers a notification observer for distributed (Intra-Application) notifications.
///
/// Parameters:
///  * fn - the callback function to associate with this listener.  The function will receive 3 parameters:
///    * name - a string giving the name of the notification received
///    * object - a table containing information about the notification received
///    * userinfo - an optional table containing information attached to the notification reveived
///  * name - an optional parameter specifying the name of the message you wish to listen for.  If nil or left out, all received notifications will be observed.
///
/// Returns:
///  * a notificationcenter object
static int nc_distributedObserver(lua_State* L) {
    return commonObserverConstruction(L, [NSDistributedNotificationCenter defaultCenter]) ;
}

/// hs._asm.notificationcenter.workspaceObserver(fn, [name]) -> notificationcenter
/// Constructor
/// Registers a notification observer for notifications sent Hammerspoon's shared workspace.
///
/// Parameters:
///  * fn - the callback function to associate with this listener.  The function will receive 3 parameters:
///    * name - a string giving the name of the notification received
///    * object - a table containing information about the notification received
///    * userinfo - an optional table containing information attached to the notification reveived
///  * name - an optional parameter specifying the name of the message you wish to listen for.  If nil or left out, all received notifications will be observed.
///
/// Returns:
///  * a notificationcenter object
static int nc_workspaceObserver(lua_State* L) {
        return commonObserverConstruction(L, [[NSWorkspace sharedWorkspace] notificationCenter]) ;
}

/// hs._asm.notificationcenter.internalObserver(fn, name) -> notificationcenter
/// Constructor
/// Registers a notification observer for notifications sent from within Hammerspoon itself.
///
/// Parameters:
///  * fn - the callback function to associate with this listener.  The function will receive 3 parameters:
///    * name - a string giving the name of the notification received
///    * object - a table containing information about the notification received
///    * userinfo - an optional table containing information attached to the notification reveived
///  * name - a required parameter specifying the name of the message you wish to listen for.
///
/// Returns:
///  * a notificationcenter object
///
/// Notes:
///  * I'm not sure how useful this will be until support is added for creating and posting our own messages to the various message centers.
///  * Listening for all inter-application messages will cause Hammerspoon to bog down completely, so the name of the message to listen for is required for this version of the contructor.
static int nc_internalObserver(lua_State* L) {
    luaL_checktype(L, 2, LUA_TSTRING) ;
    return commonObserverConstruction(L, [NSNotificationCenter defaultCenter]) ;
}

/// hs._asm.notificationcenter:start()
/// Method
/// Starts listening for notifications.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the notificationcenter object
static int notificationcenter_start(lua_State* L) {
    HSNotificationCenterClass* listener = (__bridge HSNotificationCenterClass*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    [listener.whichCenter addObserver:listener
                             selector:@selector(heard:)
                                 name:listener.notificationName
                               object:nil];
    lua_settop(L,1);
    return 1;
}

/// hs._asm.notificationcenter:stop()
/// Method
/// Stops listening for notifications.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the notificationcenter object
static int notificationcenter_stop(lua_State* L) {
    HSNotificationCenterClass* listener = (__bridge HSNotificationCenterClass*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    [listener.whichCenter removeObserver:listener];

    lua_settop(L,1);
    return 1;
}

#define push_kv_pair(x,y) lua_pushstring(L, [y UTF8String]) ; lua_setfield(L, -2, x)

static int notificationNamesArray(lua_State *L) {
    lua_newtable(L) ;

        push_kv_pair("AppleColorSyncPreferencesChanged", (__bridge NSString *) kCMPrefsChangedNotification) ;
        push_kv_pair("ColorSyncDeviceProfiles", (__bridge NSString *) kColorSyncDeviceProfilesNotification) ;
        push_kv_pair("ColorSyncDeviceRegistered", (__bridge NSString *) kColorSyncDeviceRegisteredNotification) ;
        push_kv_pair("ColorSyncDeviceUnregistered", (__bridge NSString *) kColorSyncDeviceUnregisteredNotification) ;
        push_kv_pair("ColorSyncDisplayDeviceProfiles", (__bridge NSString *) kColorSyncDisplayDeviceProfilesNotification) ;

// Use with AXObserverCreate(...) -- fodder for another module (extend uielement?)
        push_kv_pair("AXAnnouncementRequested", (__bridge NSString *) kAXAnnouncementRequestedNotification) ;
        push_kv_pair("AXApplicationActivated", (__bridge NSString *) kAXApplicationActivatedNotification) ;
        push_kv_pair("AXApplicationDeactivated", (__bridge NSString *) kAXApplicationDeactivatedNotification) ;
        push_kv_pair("AXApplicationHidden", (__bridge NSString *) kAXApplicationHiddenNotification) ;
        push_kv_pair("AXApplicationShown", (__bridge NSString *) kAXApplicationShownNotification) ;
        push_kv_pair("AXCreated", (__bridge NSString *) kAXCreatedNotification) ;
        push_kv_pair("AXDrawerCreated", (__bridge NSString *) kAXDrawerCreatedNotification) ;
        push_kv_pair("AXElementBusyChanged", (__bridge NSString *) kAXElementBusyChangedNotification) ;
        push_kv_pair("AXFocusedUIElementChanged", (__bridge NSString *) kAXFocusedUIElementChangedNotification) ;
        push_kv_pair("AXFocusedWindowChanged", (__bridge NSString *) kAXFocusedWindowChangedNotification) ;
        push_kv_pair("AXHelpTagCreated", (__bridge NSString *) kAXHelpTagCreatedNotification) ;
        push_kv_pair("AXLayoutChanged", (__bridge NSString *) kAXLayoutChangedNotification) ;
        push_kv_pair("AXMainWindowChanged", (__bridge NSString *) kAXMainWindowChangedNotification) ;
        push_kv_pair("AXMenuClosed", (__bridge NSString *) kAXMenuClosedNotification) ;
        push_kv_pair("AXMenuItemSelected", (__bridge NSString *) kAXMenuItemSelectedNotification) ;
        push_kv_pair("AXMenuOpened", (__bridge NSString *) kAXMenuOpenedNotification) ;
        push_kv_pair("AXMoved", (__bridge NSString *) kAXMovedNotification) ;
        push_kv_pair("AXResized", (__bridge NSString *) kAXResizedNotification) ;
        push_kv_pair("AXRowCollapsed", (__bridge NSString *) kAXRowCollapsedNotification) ;
        push_kv_pair("AXRowCountChanged", (__bridge NSString *) kAXRowCountChangedNotification) ;
        push_kv_pair("AXRowExpanded", (__bridge NSString *) kAXRowExpandedNotification) ;
        push_kv_pair("AXSelectedCellsChanged", (__bridge NSString *) kAXSelectedCellsChangedNotification) ;
        push_kv_pair("AXSelectedChildrenChanged", (__bridge NSString *) kAXSelectedChildrenChangedNotification) ;
        push_kv_pair("AXSelectedChildrenMoved", (__bridge NSString *) kAXSelectedChildrenMovedNotification) ;
        push_kv_pair("AXSelectedColumnsChanged", (__bridge NSString *) kAXSelectedColumnsChangedNotification) ;
        push_kv_pair("AXSelectedRowsChanged", (__bridge NSString *) kAXSelectedRowsChangedNotification) ;
        push_kv_pair("AXSelectedTextChanged", (__bridge NSString *) kAXSelectedTextChangedNotification) ;
        push_kv_pair("AXSheetCreated", (__bridge NSString *) kAXSheetCreatedNotification) ;
        push_kv_pair("AXTitleChanged", (__bridge NSString *) kAXTitleChangedNotification) ;
        push_kv_pair("AXUIElementDestroyed", (__bridge NSString *) kAXUIElementDestroyedNotification) ;
        push_kv_pair("AXUnitsChanged", (__bridge NSString *) kAXUnitsChangedNotification) ;
        push_kv_pair("AXValueChanged", (__bridge NSString *) kAXValueChangedNotification) ;
        push_kv_pair("AXWindowCreated", (__bridge NSString *) kAXWindowCreatedNotification) ;
        push_kv_pair("AXWindowDeminiaturized", (__bridge NSString *) kAXWindowDeminiaturizedNotification) ;
        push_kv_pair("AXWindowMiniaturized", (__bridge NSString *) kAXWindowMiniaturizedNotification) ;
        push_kv_pair("AXWindowMoved", (__bridge NSString *) kAXWindowMovedNotification) ;
        push_kv_pair("AXWindowResized", (__bridge NSString *) kAXWindowResizedNotification) ;

        push_kv_pair("NSAccessibilityAnnouncementRequested", NSAccessibilityAnnouncementRequestedNotification) ;
        push_kv_pair("NSAccessibilityApplicationActivated", NSAccessibilityApplicationActivatedNotification) ;
        push_kv_pair("NSAccessibilityApplicationDeactivated", NSAccessibilityApplicationDeactivatedNotification) ;
        push_kv_pair("NSAccessibilityApplicationHidden", NSAccessibilityApplicationHiddenNotification) ;
        push_kv_pair("NSAccessibilityApplicationShown", NSAccessibilityApplicationShownNotification) ;
        push_kv_pair("NSAccessibilityCreated", NSAccessibilityCreatedNotification) ;
        push_kv_pair("NSAccessibilityDrawerCreated", NSAccessibilityDrawerCreatedNotification) ;
        push_kv_pair("NSAccessibilityFocusedUIElementChanged", NSAccessibilityFocusedUIElementChangedNotification) ;
        push_kv_pair("NSAccessibilityFocusedWindowChanged", NSAccessibilityFocusedWindowChangedNotification) ;
        push_kv_pair("NSAccessibilityHelpTagCreated", NSAccessibilityHelpTagCreatedNotification) ;
        push_kv_pair("NSAccessibilityLayoutChanged", NSAccessibilityLayoutChangedNotification) ;
        push_kv_pair("NSAccessibilityMainWindowChanged", NSAccessibilityMainWindowChangedNotification) ;
        push_kv_pair("NSAccessibilityMoved", NSAccessibilityMovedNotification) ;
        push_kv_pair("NSAccessibilityResized", NSAccessibilityResizedNotification) ;
        push_kv_pair("NSAccessibilityRowCollapsed", NSAccessibilityRowCollapsedNotification) ;
        push_kv_pair("NSAccessibilityRowCountChanged", NSAccessibilityRowCountChangedNotification) ;
        push_kv_pair("NSAccessibilityRowExpanded", NSAccessibilityRowExpandedNotification) ;
        push_kv_pair("NSAccessibilitySelectedCellsChanged", NSAccessibilitySelectedCellsChangedNotification) ;
        push_kv_pair("NSAccessibilitySelectedChildrenChanged", NSAccessibilitySelectedChildrenChangedNotification) ;
        push_kv_pair("NSAccessibilitySelectedChildrenMoved", NSAccessibilitySelectedChildrenMovedNotification) ;
        push_kv_pair("NSAccessibilitySelectedColumnsChanged", NSAccessibilitySelectedColumnsChangedNotification) ;
        push_kv_pair("NSAccessibilitySelectedRowsChanged", NSAccessibilitySelectedRowsChangedNotification) ;
        push_kv_pair("NSAccessibilitySelectedTextChanged", NSAccessibilitySelectedTextChangedNotification) ;
        push_kv_pair("NSAccessibilitySheetCreated", NSAccessibilitySheetCreatedNotification) ;
        push_kv_pair("NSAccessibilityTitleChanged", NSAccessibilityTitleChangedNotification) ;
        push_kv_pair("NSAccessibilityUIElementDestroyed", NSAccessibilityUIElementDestroyedNotification) ;
        push_kv_pair("NSAccessibilityUnitsChanged", NSAccessibilityUnitsChangedNotification) ;
        push_kv_pair("NSAccessibilityValueChanged", NSAccessibilityValueChangedNotification) ;
        push_kv_pair("NSAccessibilityWindowCreated", NSAccessibilityWindowCreatedNotification) ;
        push_kv_pair("NSAccessibilityWindowDeminiaturized", NSAccessibilityWindowDeminiaturizedNotification) ;
        push_kv_pair("NSAccessibilityWindowMiniaturized", NSAccessibilityWindowMiniaturizedNotification) ;
        push_kv_pair("NSAccessibilityWindowMoved", NSAccessibilityWindowMovedNotification) ;
        push_kv_pair("NSAccessibilityWindowResized", NSAccessibilityWindowResizedNotification) ;
        push_kv_pair("NSAntialiasThresholdChanged", NSAntialiasThresholdChangedNotification) ;
        push_kv_pair("NSApplicationDidChangeOcclusionState", NSApplicationDidChangeOcclusionStateNotification) ;
        push_kv_pair("NSApplicationDidChangeScreenParameters", NSApplicationDidChangeScreenParametersNotification) ;
        push_kv_pair("NSApplicationDidFinishLaunching", NSApplicationDidFinishLaunchingNotification) ;
        push_kv_pair("NSApplicationDidFinishRestoringWindows", NSApplicationDidFinishRestoringWindowsNotification) ;
        push_kv_pair("NSBrowserColumnConfigurationDidChange", NSBrowserColumnConfigurationDidChangeNotification) ;
        push_kv_pair("NSBundleDidLoad", NSBundleDidLoadNotification) ;
        push_kv_pair("NSCalendarDayChanged", NSCalendarDayChangedNotification) ;
        push_kv_pair("NSColorListDidChange", NSColorListDidChangeNotification) ;
        push_kv_pair("NSColorPanelColorDidChange", NSColorPanelColorDidChangeNotification) ;
        push_kv_pair("NSComboBoxSelectionDidChange", NSComboBoxSelectionDidChangeNotification) ;
        push_kv_pair("NSConnectionDidDie", NSConnectionDidDieNotification) ;
        push_kv_pair("NSConnectionDidInitialize", NSConnectionDidInitializeNotification) ;
        push_kv_pair("NSControlTextDidChange", NSControlTextDidChangeNotification) ;
        push_kv_pair("NSControlTintDidChange", NSControlTintDidChangeNotification) ;
        push_kv_pair("NSCurrentLocaleDidChange", NSCurrentLocaleDidChangeNotification) ;
        push_kv_pair("NSDidBecomeSingleThreaded", NSDidBecomeSingleThreadedNotification) ;
        push_kv_pair("NSFileHandleConnectionAccepted", NSFileHandleConnectionAcceptedNotification) ;
        push_kv_pair("NSFileHandleDataAvailable", NSFileHandleDataAvailableNotification) ;
        push_kv_pair("NSFileHandleReadCompletion", NSFileHandleReadCompletionNotification) ;
        push_kv_pair("NSFileHandleReadToEndOfFileCompletion", NSFileHandleReadToEndOfFileCompletionNotification) ;
        push_kv_pair("NSFontCollectionDidChange", NSFontCollectionDidChangeNotification) ;
        push_kv_pair("NSFontSetChanged", NSFontSetChangedNotification) ;
        push_kv_pair("NSHTTPCookieManagerAcceptPolicyChanged", NSHTTPCookieManagerAcceptPolicyChangedNotification) ;
        push_kv_pair("NSHTTPCookieManagerCookiesChanged", NSHTTPCookieManagerCookiesChangedNotification) ;
        push_kv_pair("NSImageRepRegistryDidChange", NSImageRepRegistryDidChangeNotification) ;
        push_kv_pair("NSManagedObjectContextDidSave", NSManagedObjectContextDidSaveNotification) ;
        push_kv_pair("NSManagedObjectContextObjectsDidChange", NSManagedObjectContextObjectsDidChangeNotification) ;
        push_kv_pair("NSManagedObjectContextWillSave", NSManagedObjectContextWillSaveNotification) ;
        push_kv_pair("NSMenuDidChangeItem", NSMenuDidChangeItemNotification) ;
        push_kv_pair("NSMetadataQueryDidFinishGathering", NSMetadataQueryDidFinishGatheringNotification) ;
        push_kv_pair("NSMetadataQueryDidStartGathering", NSMetadataQueryDidStartGatheringNotification) ;
        push_kv_pair("NSMetadataQueryDidUpdate", NSMetadataQueryDidUpdateNotification) ;
        push_kv_pair("NSMetadataQueryGatheringProgress", NSMetadataQueryGatheringProgressNotification) ;
        push_kv_pair("NSOutlineViewSelectionDidChange", NSOutlineViewSelectionDidChangeNotification) ;
        push_kv_pair("NSPersistentStoreCoordinatorStoresDidChange", NSPersistentStoreCoordinatorStoresDidChangeNotification) ;
        push_kv_pair("NSPersistentStoreCoordinatorStoresWillChange", NSPersistentStoreCoordinatorStoresWillChangeNotification) ;
        push_kv_pair("NSPersistentStoreCoordinatorWillRemoveStore", NSPersistentStoreCoordinatorWillRemoveStoreNotification) ;
        push_kv_pair("NSPersistentStoreDidImportUbiquitousContentChanges", NSPersistentStoreDidImportUbiquitousContentChangesNotification) ;
        push_kv_pair("NSPopoverDidClose", NSPopoverDidCloseNotification) ;
        push_kv_pair("NSPopoverDidShow", NSPopoverDidShowNotification) ;
        push_kv_pair("NSPopoverWillClose", NSPopoverWillCloseNotification) ;
        push_kv_pair("NSPopoverWillShow", NSPopoverWillShowNotification) ;
        push_kv_pair("NSPortDidBecomeInvalid", NSPortDidBecomeInvalidNotification) ;
        push_kv_pair("NSPreferredScrollerStyleDidChange", NSPreferredScrollerStyleDidChangeNotification) ;
        push_kv_pair("NSProcessInfoThermalStateDidChange", NSProcessInfoThermalStateDidChangeNotification) ;
        push_kv_pair("NSRuleEditorRowsDidChange", NSRuleEditorRowsDidChangeNotification) ;
        push_kv_pair("NSScreenColorSpaceDidChange", NSScreenColorSpaceDidChangeNotification) ;
        push_kv_pair("NSScrollViewDidEndLiveMagnify", NSScrollViewDidEndLiveMagnifyNotification) ;
        push_kv_pair("NSScrollViewDidEndLiveScroll", NSScrollViewDidEndLiveScrollNotification) ;
        push_kv_pair("NSScrollViewDidLiveScroll", NSScrollViewDidLiveScrollNotification) ;
        push_kv_pair("NSScrollViewWillStartLiveMagnify", NSScrollViewWillStartLiveMagnifyNotification) ;
        push_kv_pair("NSScrollViewWillStartLiveScroll", NSScrollViewWillStartLiveScrollNotification) ;
        push_kv_pair("NSSpellCheckerDidChangeAutomaticDashSubstitution", NSSpellCheckerDidChangeAutomaticDashSubstitutionNotification) ;
        push_kv_pair("NSSpellCheckerDidChangeAutomaticQuoteSubstitution", NSSpellCheckerDidChangeAutomaticQuoteSubstitutionNotification) ;
        push_kv_pair("NSSpellCheckerDidChangeAutomaticSpellingCorrection", NSSpellCheckerDidChangeAutomaticSpellingCorrectionNotification) ;
        push_kv_pair("NSSpellCheckerDidChangeAutomaticTextReplacement", NSSpellCheckerDidChangeAutomaticTextReplacementNotification) ;
        push_kv_pair("NSSplitViewWillResizeSubviews", NSSplitViewWillResizeSubviewsNotification) ;
        push_kv_pair("NSSystemClockDidChange", NSSystemClockDidChangeNotification) ;
        push_kv_pair("NSSystemColorsDidChange", NSSystemColorsDidChangeNotification) ;
        push_kv_pair("NSSystemTimeZoneDidChange", NSSystemTimeZoneDidChangeNotification) ;
        push_kv_pair("NSTableViewSelectionDidChange", NSTableViewSelectionDidChangeNotification) ;
        push_kv_pair("NSTaskDidTerminate", NSTaskDidTerminateNotification) ;
        push_kv_pair("NSTextDidChange", NSTextDidChangeNotification) ;
        push_kv_pair("NSTextInputContextKeyboardSelectionDidChange", NSTextInputContextKeyboardSelectionDidChangeNotification) ;
        push_kv_pair("NSTextViewDidChangeSelection", NSTextViewDidChangeSelectionNotification) ;
        push_kv_pair("NSTextViewDidChangeTypingAttributes", NSTextViewDidChangeTypingAttributesNotification) ;
        push_kv_pair("NSTextViewWillChangeNotifyingTextView", NSTextViewWillChangeNotifyingTextViewNotification) ;
        push_kv_pair("NSThreadWillExit", NSThreadWillExitNotification) ;
        push_kv_pair("NSUbiquitousKeyValueStoreDidChangeExternally", NSUbiquitousKeyValueStoreDidChangeExternallyNotification) ;
        push_kv_pair("NSUbiquityIdentityDidChange", NSUbiquityIdentityDidChangeNotification) ;
        push_kv_pair("NSUndoManagerCheckpoint", NSUndoManagerCheckpointNotification) ;
        push_kv_pair("NSUndoManagerDidCloseUndoGroup", NSUndoManagerDidCloseUndoGroupNotification) ;
        push_kv_pair("NSUndoManagerDidOpenUndoGroup", NSUndoManagerDidOpenUndoGroupNotification) ;
        push_kv_pair("NSUndoManagerDidRedoChange", NSUndoManagerDidRedoChangeNotification) ;
        push_kv_pair("NSUndoManagerDidUndoChange", NSUndoManagerDidUndoChangeNotification) ;
        push_kv_pair("NSUndoManagerWillCloseUndoGroup", NSUndoManagerWillCloseUndoGroupNotification) ;
        push_kv_pair("NSUndoManagerWillRedoChange", NSUndoManagerWillRedoChangeNotification) ;
        push_kv_pair("NSUndoManagerWillUndoChange", NSUndoManagerWillUndoChangeNotification) ;
        push_kv_pair("NSURLCredentialStorageChanged", NSURLCredentialStorageChangedNotification) ;
        push_kv_pair("NSUserDefaultsDidChange", NSUserDefaultsDidChangeNotification) ;
        push_kv_pair("NSViewBoundsDidChange", NSViewBoundsDidChangeNotification) ;
        push_kv_pair("NSViewFocusDidChange", NSViewFocusDidChangeNotification) ;
        push_kv_pair("NSViewFrameDidChange", NSViewFrameDidChangeNotification) ;
        push_kv_pair("NSViewGlobalFrameDidChange", NSViewGlobalFrameDidChangeNotification) ;
        push_kv_pair("NSWillBecomeMultiThreaded", NSWillBecomeMultiThreadedNotification) ;
        push_kv_pair("NSWindowDidChangeBackingProperties", NSWindowDidChangeBackingPropertiesNotification) ;
        push_kv_pair("NSWindowDidChangeOcclusionState", NSWindowDidChangeOcclusionStateNotification) ;
        push_kv_pair("NSWindowDidChangeScreen", NSWindowDidChangeScreenNotification) ;
        push_kv_pair("NSWindowDidChangeScreenProfile", NSWindowDidChangeScreenProfileNotification) ;
        push_kv_pair("NSWindowDidEndLiveResize", NSWindowDidEndLiveResizeNotification) ;
        push_kv_pair("NSWindowDidEnterFullScreen", NSWindowDidEnterFullScreenNotification) ;
        push_kv_pair("NSWindowDidEnterVersionBrowser", NSWindowDidEnterVersionBrowserNotification) ;
        push_kv_pair("NSWindowDidExitFullScreen", NSWindowDidExitFullScreenNotification) ;
        push_kv_pair("NSWindowDidExitVersionBrowser", NSWindowDidExitVersionBrowserNotification) ;
        push_kv_pair("NSWindowDidResize", NSWindowDidResizeNotification) ;
        push_kv_pair("NSWindowWillEnterFullScreen", NSWindowWillEnterFullScreenNotification) ;
        push_kv_pair("NSWindowWillEnterVersionBrowser", NSWindowWillEnterVersionBrowserNotification) ;
        push_kv_pair("NSWindowWillExitFullScreen", NSWindowWillExitFullScreenNotification) ;
        push_kv_pair("NSWindowWillExitVersionBrowser", NSWindowWillExitVersionBrowserNotification) ;
        push_kv_pair("NSWindowWillStartLiveResize", NSWindowWillStartLiveResizeNotification) ;
        push_kv_pair("NSWorkspaceAccessibilityDisplayOptionsDidChange", NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification) ;
        push_kv_pair("NSWorkspaceActiveSpaceDidChange", NSWorkspaceActiveSpaceDidChangeNotification) ;
        push_kv_pair("NSWorkspaceDidActivateApplication", NSWorkspaceDidActivateApplicationNotification) ;
        push_kv_pair("NSWorkspaceDidChangeFileLabels", NSWorkspaceDidChangeFileLabelsNotification) ;
        push_kv_pair("NSWorkspaceDidDeactivateApplication", NSWorkspaceDidDeactivateApplicationNotification) ;
        push_kv_pair("NSWorkspaceDidHideApplication", NSWorkspaceDidHideApplicationNotification) ;
        push_kv_pair("NSWorkspaceDidLaunchApplication", NSWorkspaceDidLaunchApplicationNotification) ;
        push_kv_pair("NSWorkspaceDidMount", NSWorkspaceDidMountNotification) ;
        push_kv_pair("NSWorkspaceDidPerformFileOperation", NSWorkspaceDidPerformFileOperationNotification) ;
        push_kv_pair("NSWorkspaceDidRenameVolume", NSWorkspaceDidRenameVolumeNotification) ;
        push_kv_pair("NSWorkspaceDidTerminateApplication", NSWorkspaceDidTerminateApplicationNotification) ;
        push_kv_pair("NSWorkspaceDidUnhideApplication", NSWorkspaceDidUnhideApplicationNotification) ;
        push_kv_pair("NSWorkspaceDidUnmount", NSWorkspaceDidUnmountNotification) ;
        push_kv_pair("NSWorkspaceDidWake", NSWorkspaceDidWakeNotification) ;
        push_kv_pair("NSWorkspaceScreensDidSleep", NSWorkspaceScreensDidSleepNotification) ;
        push_kv_pair("NSWorkspaceScreensDidWake", NSWorkspaceScreensDidWakeNotification) ;
        push_kv_pair("NSWorkspaceSessionDidBecomeActive", NSWorkspaceSessionDidBecomeActiveNotification) ;
        push_kv_pair("NSWorkspaceSessionDidResignActive", NSWorkspaceSessionDidResignActiveNotification) ;
        push_kv_pair("NSWorkspaceWillLaunchApplication", NSWorkspaceWillLaunchApplicationNotification) ;
        push_kv_pair("NSWorkspaceWillPowerOff", NSWorkspaceWillPowerOffNotification) ;
        push_kv_pair("NSWorkspaceWillSleep", NSWorkspaceWillSleepNotification) ;
        push_kv_pair("NSWorkspaceWillUnmount", NSWorkspaceWillUnmountNotification) ;

        push_kv_pair("CFLocaleCurrentLocaleDidChange", (__bridge NSString *) kCFLocaleCurrentLocaleDidChangeNotification) ;
        push_kv_pair("CFTimeZoneSystemTimeZoneDidChange", (__bridge NSString *) kCFTimeZoneSystemTimeZoneDidChangeNotification) ;
        push_kv_pair("CMDefaultDevice", (__bridge NSString *) kCMDefaultDeviceNotification) ;
        push_kv_pair("CMDefaultDeviceProfile", (__bridge NSString *) kCMDefaultDeviceProfileNotification) ;
        push_kv_pair("CMDeviceOffline", (__bridge NSString *) kCMDeviceOfflineNotification) ;
        push_kv_pair("CMDeviceOnline", (__bridge NSString *) kCMDeviceOnlineNotification) ;
        push_kv_pair("CMDeviceProfiles", (__bridge NSString *) kCMDeviceProfilesNotification) ;
        push_kv_pair("CMDeviceRegistered", (__bridge NSString *) kCMDeviceRegisteredNotification) ;
        push_kv_pair("CMDeviceState", (__bridge NSString *) kCMDeviceStateNotification) ;
        push_kv_pair("CMDeviceUnregistered", (__bridge NSString *) kCMDeviceUnregisteredNotification) ;
        push_kv_pair("CMDisplayDeviceProfiles", (__bridge NSString *) kCMDisplayDeviceProfilesNotification) ;
        push_kv_pair("CMPrefsChanged", (__bridge NSString *) kCMPrefsChangedNotification) ;
        push_kv_pair("CTFontManagerRegisteredFontsChanged", (__bridge NSString *) kCTFontManagerRegisteredFontsChangedNotification) ;
        push_kv_pair("CVPixelBufferPoolFreeBuffer", (__bridge NSString *) kCVPixelBufferPoolFreeBufferNotification) ;
        push_kv_pair("MDQueryDidFinish", (__bridge NSString *) kMDQueryDidFinishNotification) ;
        push_kv_pair("MDQueryDidUpdate", (__bridge NSString *) kMDQueryDidUpdateNotification) ;
        push_kv_pair("MDQueryProgress", (__bridge NSString *) kMDQueryProgressNotification) ;
        push_kv_pair("SecTransformActionAttribute", (__bridge NSString *) kSecTransformActionAttributeNotification) ;

// // AddressBook/AddressBook.h
// // AddressBook/ABPeoplePickerView.h
//         push_kv_pair("ABDatabaseChanged", kABDatabaseChangedNotification) ;
//         push_kv_pair("ABDatabaseChangedExternally", kABDatabaseChangedExternallyNotification) ;
//         push_kv_pair("ABPeoplePickerDisplayedPropertyDidChange", ABPeoplePickerDisplayedPropertyDidChangeNotification) ;
//         push_kv_pair("ABPeoplePickerGroupSelectionDidChange", ABPeoplePickerGroupSelectionDidChangeNotification) ;
//         push_kv_pair("ABPeoplePickerNameSelectionDidChange", ABPeoplePickerNameSelectionDidChangeNotification) ;
//         push_kv_pair("ABPeoplePickerValueSelectionDidChange", ABPeoplePickerValueSelectionDidChangeNotification) ;

// // Accounts/Accounts.h
//         push_kv_pair("ACAccountStoreDidChange", ACAccountStoreDidChangeNotification) ;

// AVFoundation/AVFoundation.h
//         push_kv_pair("AVAudioEngineConfigurationChange", AVAudioEngineConfigurationChangeNotification) ;
//         push_kv_pair("AVAudioUnitComponentTagsDidChange", AVAudioUnitComponentTagsDidChangeNotification) ;
//         push_kv_pair("AVCaptureDeviceWasConnected", AVCaptureDeviceWasConnectedNotification) ;
//         push_kv_pair("AVCaptureDeviceWasDisconnected", AVCaptureDeviceWasDisconnectedNotification) ;
//         push_kv_pair("AVCaptureInputPortFormatDescriptionDidChange", AVCaptureInputPortFormatDescriptionDidChangeNotification) ;
//         push_kv_pair("AVCaptureSessionDidStartRunning", AVCaptureSessionDidStartRunningNotification) ;
//         push_kv_pair("AVCaptureSessionDidStopRunning", AVCaptureSessionDidStopRunningNotification) ;
//         push_kv_pair("AVCaptureSessionRuntimeError", AVCaptureSessionRuntimeErrorNotification) ;
//         push_kv_pair("AVFragmentedMovieDurationDidChange", AVFragmentedMovieDurationDidChangeNotification) ;
//         push_kv_pair("AVFragmentedMovieTrackSegmentsDidChange", AVFragmentedMovieTrackSegmentsDidChangeNotification) ;
//         push_kv_pair("AVFragmentedMovieTrackTimeRangeDidChange", AVFragmentedMovieTrackTimeRangeDidChangeNotification) ;
//         push_kv_pair("AVFragmentedMovieTrackTotalSampleDataLengthDidChange", AVFragmentedMovieTrackTotalSampleDataLengthDidChangeNotification) ;
//         push_kv_pair("AVFragmentedMovieWasDefragmented", AVFragmentedMovieWasDefragmentedNotification) ;
//         push_kv_pair("AVPlayerItemDidPlayToEndTime", AVPlayerItemDidPlayToEndTimeNotification) ;
//         push_kv_pair("AVPlayerItemFailedToPlayToEndTime", AVPlayerItemFailedToPlayToEndTimeNotification) ;
//         push_kv_pair("AVPlayerItemNewAccessLogEntry", AVPlayerItemNewAccessLogEntryNotification) ;
//         push_kv_pair("AVPlayerItemNewErrorLogEntry", AVPlayerItemNewErrorLogEntryNotification) ;
//         push_kv_pair("AVPlayerItemPlaybackStalled", AVPlayerItemPlaybackStalledNotification) ;
//         push_kv_pair("AVPlayerItemTimeJumped", AVPlayerItemTimeJumpedNotification) ;
//         push_kv_pair("AVSampleBufferDisplayLayerFailedToDecode", AVSampleBufferDisplayLayerFailedToDecodeNotification) ;

// // DiscRecordingUI/DiscRecordingUI.h
//         push_kv_pair("DRBurnProgressPanelDidFinish", DRBurnProgressPanelDidFinishNotification) ;
//         push_kv_pair("DRBurnProgressPanelWillBegin", DRBurnProgressPanelWillBeginNotification) ;
//         push_kv_pair("DRBurnStatusChanged", (__bridge NSString *) kDRBurnStatusChangedNotification) ;
//         push_kv_pair("DRDeviceAppeared", DRDeviceAppearedNotification) ;
//         push_kv_pair("DRDeviceAppeared", (__bridge NSString *) kDRDeviceAppearedNotification) ;
//         push_kv_pair("DRDeviceDisappeared", DRDeviceDisappearedNotification) ;
//         push_kv_pair("DRDeviceDisappeared", (__bridge NSString *) kDRDeviceDisappearedNotification) ;
//         push_kv_pair("DRDeviceStatusChanged", (__bridge NSString *) kDRDeviceStatusChangedNotification) ;
//         push_kv_pair("DREraseProgressPanelDidFinish", DREraseProgressPanelDidFinishNotification) ;
//         push_kv_pair("DREraseProgressPanelWillBegin", DREraseProgressPanelWillBeginNotification) ;
//         push_kv_pair("DREraseStatusChanged", (__bridge NSString *) kDREraseStatusChangedNotification) ;
//         push_kv_pair("DRSetupPanelDeviceSelectionChanged", DRSetupPanelDeviceSelectionChangedNotification) ;

// // EventKit/EventKit.h
//         push_kv_pair("EKEventStoreChanged", EKEventStoreChangedNotification) ;

// // GameController/GameControll.h
//         push_kv_pair("GCControllerDidConnect", GCControllerDidConnectNotification) ;
//         push_kv_pair("GCControllerDidDisconnect", GCControllerDidDisconnectNotification) ;

// IOBluetooth/IOBluetooth.h
        push_kv_pair("IOBluetoothDeviceInquiryInfoChanged", kIOBluetoothDeviceInquiryInfoChangedNotification) ;
        push_kv_pair("IOBluetoothDeviceNameChanged", kIOBluetoothDeviceNameChangedNotification) ;
        push_kv_pair("IOBluetoothDeviceServicesChanged", kIOBluetoothDeviceServicesChangedNotification) ;
        push_kv_pair("IOBluetoothHostControllerPoweredOff", IOBluetoothHostControllerPoweredOffNotification) ;
        push_kv_pair("IOBluetoothHostControllerPoweredOn", IOBluetoothHostControllerPoweredOnNotification) ;
        push_kv_pair("IOBluetoothL2CAPChannelPublished", IOBluetoothL2CAPChannelPublishedNotification) ;
        push_kv_pair("IOBluetoothL2CAPChannelTerminated", IOBluetoothL2CAPChannelTerminatedNotification) ;

// Kerberos/Kerberos.h
        push_kv_pair("CCAPICacheCollectionChanged", (__bridge NSString *) kCCAPICacheCollectionChangedNotification) ;
        push_kv_pair("CCAPICCacheChanged", (__bridge NSString *) kCCAPICCacheChangedNotification) ;

// // MapKit/MapKit.h
//         push_kv_pair("MKAnnotationCalloutInfoDidChange", MKAnnotationCalloutInfoDidChangeNotification) ;

// MediaAccessibility/MediaAccessibility.h
//         push_kv_pair("MAAudibleMediaSettingsChanged", (__bridge NSString *) kMAAudibleMediaSettingsChangedNotification) ;
//         push_kv_pair("MACaptionAppearanceSettingsChanged", (__bridge NSString *) kMACaptionAppearanceSettingsChangedNotification) ;

// // PreferencePanes/PreferencePanes.h
//         push_kv_pair("NSPreferencePaneCancelUnselect", NSPreferencePaneCancelUnselectNotification) ;
//         push_kv_pair("NSPreferencePaneDoUnselect", NSPreferencePaneDoUnselectNotification) ;

// Quartz/Quartz.h
//         push_kv_pair("IKFilterBrowserFilterDoubleClick", IKFilterBrowserFilterDoubleClickNotification) ;
//         push_kv_pair("IKFilterBrowserFilterSelected", IKFilterBrowserFilterSelectedNotification) ;
//         push_kv_pair("IKFilterBrowserWillPreviewFilter", IKFilterBrowserWillPreviewFilterNotification) ;
//         push_kv_pair("PDFDocumentDidFindMatch", PDFDocumentDidFindMatchNotification) ;
//         push_kv_pair("PDFDocumentDidUnlock", PDFDocumentDidUnlockNotification) ;
//         push_kv_pair("PDFViewChangedHistory", PDFViewChangedHistoryNotification) ;
//         push_kv_pair("PDFViewDisplayBoxChanged", PDFViewDisplayBoxChangedNotification) ;
//         push_kv_pair("PDFViewDisplayModeChanged", PDFViewDisplayModeChangedNotification) ;
//         push_kv_pair("PDFViewDocumentChanged", PDFViewDocumentChangedNotification) ;
//         push_kv_pair("PDFViewPageChanged", PDFViewPageChangedNotification) ;
//         push_kv_pair("PDFViewScaleChanged", PDFViewScaleChangedNotification) ;
//         push_kv_pair("PDFViewSelectionChanged", PDFViewSelectionChangedNotification) ;
//         push_kv_pair("PDFViewVisiblePagesChanged", PDFViewVisiblePagesChangedNotification) ;
//         push_kv_pair("QCCompositionPickerPanelDidSelectComposition", QCCompositionPickerPanelDidSelectCompositionNotification) ;
//         push_kv_pair("QCCompositionPickerViewDidSelectComposition", QCCompositionPickerViewDidSelectCompositionNotification) ;
//         push_kv_pair("QCCompositionRepositoryDidUpdate", QCCompositionRepositoryDidUpdateNotification) ;
//         push_kv_pair("QCViewDidStartRendering", QCViewDidStartRenderingNotification) ;
//         push_kv_pair("QCViewDidStopRendering", QCViewDidStopRenderingNotification) ;
//         push_kv_pair("QuartzFilterManagerDidAddFilter", kQuartzFilterManagerDidAddFilterNotification) ;
//         push_kv_pair("QuartzFilterManagerDidModifyFilter", kQuartzFilterManagerDidModifyFilterNotification) ;
//         push_kv_pair("QuartzFilterManagerDidRemoveFilter", kQuartzFilterManagerDidRemoveFilterNotification) ;
//         push_kv_pair("QuartzFilterManagerDidSelectFilter", kQuartzFilterManagerDidSelectFilterNotification) ;

// WebKit/WebKit.h
        push_kv_pair("WebHistoryAllItemsRemoved", WebHistoryAllItemsRemovedNotification) ;
        push_kv_pair("WebHistoryItemChanged", WebHistoryItemChangedNotification) ;
        push_kv_pair("WebHistoryItemsAdded", WebHistoryItemsAddedNotification) ;
        push_kv_pair("WebHistoryItemsRemoved", WebHistoryItemsRemovedNotification) ;
        push_kv_pair("WebHistoryLoaded", WebHistoryLoadedNotification) ;
        push_kv_pair("WebPreferencesChanged", WebPreferencesChangedNotification) ;
        push_kv_pair("WebViewDidBeginEditing", WebViewDidBeginEditingNotification) ;
        push_kv_pair("WebViewDidChange", WebViewDidChangeNotification) ;
        push_kv_pair("WebViewDidChangeSelection", WebViewDidChangeSelectionNotification) ;
        push_kv_pair("WebViewDidChangeTypingStyle", WebViewDidChangeTypingStyleNotification) ;
        push_kv_pair("WebViewDidEndEditing", WebViewDidEndEditingNotification) ;
        push_kv_pair("WebViewProgressEstimateChanged", WebViewProgressEstimateChangedNotification) ;
        push_kv_pair("WebViewProgressFinished", WebViewProgressFinishedNotification) ;
        push_kv_pair("WebViewProgressStarted", WebViewProgressStartedNotification) ;

    return 1 ;
}

static int deprecatedNamesArray(lua_State *L) {
    lua_newtable(L) ;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// // CalendarStore/CalendarStore.h
//         push_kv_pair("CalCalendarsChangedExternally", CalCalendarsChangedExternallyNotification) ;
//         push_kv_pair("CalCalendarsChanged", CalCalendarsChangedNotification) ;
//         push_kv_pair("CalEventsChangedExternally", CalEventsChangedExternallyNotification) ;
//         push_kv_pair("CalEventsChanged", CalEventsChangedNotification) ;
//         push_kv_pair("CalTasksChangedExternally", CalTasksChangedExternallyNotification) ;
//         push_kv_pair("CalTasksChanged", CalTasksChangedNotification) ;

// Deprecated and require retaining a WIFIElement instance -- should look at newer method as a replacement
// // CoreWLAN/CoreWLAN.h
//         push_kv_pair("CWBSSIDDidChange", CWBSSIDDidChangeNotification) ;
//         push_kv_pair("CWCountryCodeDidChange", CWCountryCodeDidChangeNotification) ;
//         push_kv_pair("CWLinkDidChange", CWLinkDidChangeNotification) ;
//         push_kv_pair("CWLinkQualityDidChange", CWLinkQualityDidChangeNotification) ;
//         push_kv_pair("CWModeDidChange", CWModeDidChangeNotification) ;
//         push_kv_pair("CWPowerDidChange", CWPowerDidChangeNotification) ;
//         push_kv_pair("CWScanCacheDidUpdate", CWScanCacheDidUpdateNotification) ;
//         push_kv_pair("CWSSIDDidChange", CWSSIDDidChangeNotification) ;

// // InstantMessage/IMAVManager.h
//         push_kv_pair("IMAVManagerStateChanged", IMAVManagerStateChangedNotification) ;
//         push_kv_pair("IMAVManagerURLToShareChanged", IMAVManagerURLToShareChangedNotification) ;
//         push_kv_pair("IMMyStatusChanged", IMMyStatusChangedNotification) ;
//         push_kv_pair("IMPersonInfoChanged", IMPersonInfoChangedNotification) ;
//         push_kv_pair("IMPersonStatusChanged", IMPersonStatusChangedNotification) ;
//         push_kv_pair("IMServiceStatusChanged", IMServiceStatusChangedNotification) ;
//         push_kv_pair("IMStatusImagesChangedAppearance", IMStatusImagesChangedAppearanceNotification) ;

// // PubSub/PubSub.h
//         push_kv_pair("PSEnclosureDownloadStateDidChange", PSEnclosureDownloadStateDidChangeNotification) ;
//         push_kv_pair("PSFeedEntriesChanged", PSFeedEntriesChangedNotification) ;
//         push_kv_pair("PSFeedRefreshing", PSFeedRefreshingNotification) ;

// QTKit/QTKit.h
//         push_kv_pair("QTCaptureConnectionAttributeDidChange", QTCaptureConnectionAttributeDidChangeNotification) ;
//         push_kv_pair("QTCaptureConnectionAttributeWillChange", QTCaptureConnectionAttributeWillChangeNotification) ;
//         push_kv_pair("QTCaptureConnectionFormatDescriptionDidChange", QTCaptureConnectionFormatDescriptionDidChangeNotification) ;
//         push_kv_pair("QTCaptureConnectionFormatDescriptionWillChange", QTCaptureConnectionFormatDescriptionWillChangeNotification) ;
//         push_kv_pair("QTCaptureDeviceAttributeDidChange", QTCaptureDeviceAttributeDidChangeNotification) ;
//         push_kv_pair("QTCaptureDeviceAttributeWillChange", QTCaptureDeviceAttributeWillChangeNotification) ;
//         push_kv_pair("QTCaptureDeviceFormatDescriptionsDidChange", QTCaptureDeviceFormatDescriptionsDidChangeNotification) ;
//         push_kv_pair("QTCaptureDeviceFormatDescriptionsWillChange", QTCaptureDeviceFormatDescriptionsWillChangeNotification) ;
//         push_kv_pair("QTCaptureDeviceWasConnected", QTCaptureDeviceWasConnectedNotification) ;
//         push_kv_pair("QTCaptureDeviceWasDisconnected", QTCaptureDeviceWasDisconnectedNotification) ;
//         push_kv_pair("QTCaptureSessionRuntimeError", QTCaptureSessionRuntimeErrorNotification) ;
//         push_kv_pair("QTMovieApertureModeDidChange", QTMovieApertureModeDidChangeNotification) ;
//         push_kv_pair("QTMovieChapterDidChange", QTMovieChapterDidChangeNotification) ;
//         push_kv_pair("QTMovieChapterListDidChange", QTMovieChapterListDidChangeNotification) ;
//         push_kv_pair("QTMovieCloseWindowRequest", QTMovieCloseWindowRequestNotification) ;
//         push_kv_pair("QTMovieDidEnd", QTMovieDidEndNotification) ;
//         push_kv_pair("QTMovieEditabilityDidChange", QTMovieEditabilityDidChangeNotification) ;
//         push_kv_pair("QTMovieEdited", QTMovieEditedNotification) ;
//         push_kv_pair("QTMovieEnterFullScreenRequest", QTMovieEnterFullScreenRequestNotification) ;
//         push_kv_pair("QTMovieExitFullScreenRequest", QTMovieExitFullScreenRequestNotification) ;
//         push_kv_pair("QTMovieLoadStateDidChange", QTMovieLoadStateDidChangeNotification) ;
//         push_kv_pair("QTMovieLoopModeDidChange", QTMovieLoopModeDidChangeNotification) ;
//         push_kv_pair("QTMovieMessageStringPosted", QTMovieMessageStringPostedNotification) ;
//         push_kv_pair("QTMovieNaturalSizeDidChange", QTMovieNaturalSizeDidChangeNotification) ;
//         push_kv_pair("QTMovieRateDidChange", QTMovieRateDidChangeNotification) ;
//         push_kv_pair("QTMovieRateDidChangeNotificationParameter", QTMovieRateDidChangeNotificationParameter) ;
//         push_kv_pair("QTMovieSelectionDidChange", QTMovieSelectionDidChangeNotification) ;
//         push_kv_pair("QTMovieSizeDidChange", QTMovieSizeDidChangeNotification) ;
//         push_kv_pair("QTMovieStatusStringPosted", QTMovieStatusStringPostedNotification) ;
//         push_kv_pair("QTMovieTimeDidChange", QTMovieTimeDidChangeNotification) ;
//         push_kv_pair("QTMovieVolumeDidChange", QTMovieVolumeDidChangeNotification) ;

// // SyncServices/SyncServices.h
//         push_kv_pair("ISyncAvailabilityChanged", ISyncAvailabilityChangedNotification) ;

#pragma clang diagnostic pop

    return 1 ;
}

#undef push_kv_pair

static int notificationcenter_gc(lua_State* L) {
    HSNotificationCenterClass* listener = (__bridge_transfer HSNotificationCenterClass*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    [listener.whichCenter removeObserver:listener];

    listener = nil ;
    return 0;
}

// Metatable for created objects when _new invoked
static const luaL_Reg notificationcenter_metalib[] = {
    {"start",   notificationcenter_start},
    {"stop",    notificationcenter_stop},
    {"__gc",    notificationcenter_gc},
    {NULL,      NULL}
};

// Functions for returned object when module loads
static const luaL_Reg notificationcenterLib[] = {
    {"internalObserver",    nc_internalObserver},
    {"workspaceObserver",   nc_workspaceObserver},
    {"distributedObserver", nc_distributedObserver},
    {NULL,      NULL}
};

int luaopen_hs__asm_notificationcenter_internal(lua_State* L) {
    [[LuaSkin shared] registerLibraryWithObject:USERDATA_TAG
                                      functions:notificationcenterLib
                                  metaFunctions:nil
                                objectFunctions:notificationcenter_metalib];

    // Add notification constants to the returned object
    notificationNamesArray(L) ; lua_setfield(L, -2, "notificationNames") ;
    deprecatedNamesArray(L)   ; lua_setfield(L, -2, "deprecatedNotificationNames") ;

    return 1;
}
