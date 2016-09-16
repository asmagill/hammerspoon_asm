#import "webview.h"

static int           refTable ;
static WKProcessPool *HSWebViewProcessPool ;

#pragma mark - Classes and Delegates

// forward declare so we can use in class definitions
static int NSError_toLua(lua_State *L, id obj) ;
static int SecCertificateRef_toLua(lua_State *L, SecCertificateRef certRef) ;

#pragma mark - our wkwebview object

@implementation HSWebViewView
- (id)initWithFrame:(NSRect)frameRect configuration:(WKWebViewConfiguration *)configuration {
    self = [super initWithFrame:frameRect configuration:configuration] ;
    if (self) {
        self.navigationDelegate     = self ;
        self.UIDelegate             = self ;
        _referenceCount             = 0 ;
        _navigationCallback         = LUA_NOREF ;
        _policyCallback             = LUA_NOREF ;
        _sslCallback                = LUA_NOREF ;
        _allowNewWindows            = YES ;
        _examineInvalidCertificates = NO ;
        _titleFollow                = YES ;
    }
    return self;
}

- (BOOL)isFlipped {
    return YES ;
}

- (BOOL)acceptsFirstMouse:(NSEvent * __unused)theEvent {
    return YES ;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow] ;
    if (_titleFollow) {
        NSString *windowTitle = self.title ? self.title : @"<no title>" ;
        if (self.window) {
            [self.window setTitle:windowTitle] ;
        }
    }
}

#pragma mark -- WKNavigationDelegate stuff

- (void)webView:(WKWebView *)theView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation {
    [self navigationCallbackFor:"didReceiveServerRedirectForProvisionalNavigation" forView:theView
                                                                            withNavigation:navigation
                                                                                 withError:nil] ;
}

- (void)webView:(WKWebView *)theView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [self navigationCallbackFor:"didStartProvisionalNavigation" forView:theView
                                                         withNavigation:navigation
                                                              withError:nil] ;
}

- (void)webView:(WKWebView *)theView didCommitNavigation:(WKNavigation *)navigation {
    [self navigationCallbackFor:"didCommitNavigation" forView:theView
                                               withNavigation:navigation
                                                    withError:nil] ;
}

- (void)webView:(WKWebView *)theView didFinishNavigation:(WKNavigation *)navigation {
    NSString *windowTitle = [theView title] ? [theView title] : @"<no title>" ;
    if (_titleFollow && theView.window) [theView.window setTitle:windowTitle] ;

    [self navigationCallbackFor:"didFinishNavigation" forView:theView
                                               withNavigation:navigation
                                                    withError:nil] ;

}

- (void)webView:(WKWebView *)theView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if ([self navigationCallbackFor:"didFailNavigation" forView:theView
                                                 withNavigation:navigation
                                                      withError:error]) {
//         NSLog(@"didFail: %@", error) ;
        [self handleNavigationFailure:error forView:theView] ;
    }
}

- (void)webView:(WKWebView *)theView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if ([self navigationCallbackFor:"didFailProvisionalNavigation" forView:theView
                                                            withNavigation:navigation
                                                                 withError:error]) {
//         NSLog(@"provisionalFail: %@", error) ;
        if (error.code == NSURLErrorUnsupportedURL) {
            NSDictionary *userInfo = error.userInfo ;
            NSURL *destinationURL = [userInfo objectForKey:NSURLErrorFailingURLErrorKey] ;
            if (destinationURL) {
                if ([[NSWorkspace sharedWorkspace] openURL:destinationURL]) return ;
            } else {
                [LuaSkin logWarn:[NSString stringWithFormat:@"%s:didFailProvisionalNavigation missing NSURLErrorFailingURLErrorKey", USERDATA_TAG]] ;
            }
        }

        [self handleNavigationFailure:error forView:theView] ;
    }
}

- (void)webView:(WKWebView *)theView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
                                                     completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    NSString *hostName = theView.URL.host;

    NSString *authenticationMethod = [[challenge protectionSpace] authenticationMethod];
    if ([authenticationMethod isEqualToString:NSURLAuthenticationMethodDefault]
        || [authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPBasic]
        || [authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPDigest]) {

        NSURLCredential *previousCredential = [challenge proposedCredential] ;

        if (self.policyCallback != LUA_NOREF && [challenge previousFailureCount] < 3) { // don't get in a loop if the callback isn't working
            LuaSkin *skin = [LuaSkin shared] ;
            [skin pushLuaRef:refTable ref:self.policyCallback];
            lua_pushstring([skin L], "authenticationChallenge") ;
            [skin pushNSObject:theView] ;
            [skin pushNSObject:challenge] ;

            if (![skin  protectedCallAndTraceback:3 nresults:1]) {
                const char *errorMsg = lua_tostring([skin L], -1);
                [skin logError:[NSString stringWithFormat:@"hs._asm.enclosure.webview:policyCallback() authenticationChallenge callback error: %s", errorMsg]];
                // allow prompting if error -- fall through
            } else {
                if (lua_type([skin L], -1) == LUA_TTABLE) { // if it's a table, we'll get the username and password from it
                    lua_getfield([skin L], -1, "user") ;
                    NSString *userName = (lua_type([skin L], -1) == LUA_TSTRING) ? [skin toNSObjectAtIndex:-1] : @"" ;
                    lua_pop([skin L], 1) ;

                    lua_getfield([skin L], -1, "password") ;
                    NSString *password = (lua_type([skin L], -1) == LUA_TSTRING) ? [skin toNSObjectAtIndex:-1] : @"" ;
                    lua_pop([skin L], 1) ;

                    NSURLCredential *credential = [[NSURLCredential alloc] initWithUser:userName
                                                                               password:password
                                                                            persistence:NSURLCredentialPersistenceForSession];
                    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
                    lua_pop([skin L], 1) ; // pop return value
                    return ;
                } else if (!lua_toboolean([skin L], -1)) { // if false, don't go forward
                    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
                    lua_pop([skin L], 1) ; // pop return value
                    return ;
                } // fall through
            }
            lua_pop([skin L], 1) ; // pop return value if fall through
        }

        NSWindow *targetWindow = self.window ;
        if (targetWindow) {
            NSString *title = @"Authentication Challenge";
            if (previousCredential && [challenge previousFailureCount] > 0) {
                title = [NSString stringWithFormat:@"%@, attempt %ld", title, [challenge previousFailureCount] + 1] ;
            }
            NSAlert *alert1 = [[NSAlert alloc] init] ;
            [alert1 addButtonWithTitle:@"OK"];
            [alert1 addButtonWithTitle:@"Cancel"];
            [alert1 setMessageText:title] ;
            [alert1 setInformativeText:[NSString stringWithFormat:@"Username for %@", hostName]] ;
            NSTextField *user = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)] ;
            if (previousCredential) {
                NSString *previousUser = [previousCredential user] ? [previousCredential user] : @"" ;
                user.stringValue = previousUser ;
            }
            user.editable = YES ;
            [alert1 setAccessoryView:user] ;

            [alert1 beginSheetModalForWindow:targetWindow completionHandler:^(NSModalResponse returnCode){
                if (returnCode == NSAlertFirstButtonReturn) {
                    NSAlert *alert2 = [[NSAlert alloc] init] ;
                    [alert2 addButtonWithTitle:@"OK"];
                    [alert2 addButtonWithTitle:@"Cancel"];
                    [alert2 setMessageText:title] ;
                    [alert2 setInformativeText:[NSString stringWithFormat:@"password for %@", hostName]] ;
                    NSSecureTextField *pass = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 36, 200, 24)];
                    pass.editable = YES ;
                    [alert2 setAccessoryView:pass] ;
                    [alert2 beginSheetModalForWindow:targetWindow completionHandler:^(NSModalResponse returnCode2){
                        if (returnCode2 == NSAlertFirstButtonReturn) {
                            NSString *userName = user.stringValue ;
                            NSString *password = pass.stringValue ;

                            NSURLCredential *credential = [[NSURLCredential alloc] initWithUser:userName
                                                                                       password:password
                                                                                    persistence:NSURLCredentialPersistenceForSession];

                            completionHandler(NSURLSessionAuthChallengeUseCredential, credential);

                        } else {
                            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
                        }
                    }] ;
                } else {
                    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
                }
            }] ;
        } else {
            [LuaSkin logWarn:[NSString stringWithFormat:@"%s:didReceiveAuthenticationChallenge no target window", USERDATA_TAG]] ;
            completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        }
    } else if ([authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
        SecTrustResultType status ;
        SecTrustEvaluate(serverTrust, &status);

        if (status == kSecTrustResultRecoverableTrustFailure && self.sslCallback != LUA_NOREF) {
            LuaSkin *skin = [LuaSkin shared] ;
            [skin pushLuaRef:refTable ref:self.sslCallback];
            [skin pushNSObject:theView] ;
            [skin pushNSObject:challenge.protectionSpace] ;

            if (![skin  protectedCallAndTraceback:2 nresults:1]) {
                const char *errorMsg = lua_tostring([skin L], -1);
                [skin logError:[NSString stringWithFormat:@"hs._asm.enclosure.webview:sslCallback callback error: %s", errorMsg]];
                completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
            } else {
                if ((lua_type([skin L], -1) == LUA_TBOOLEAN) && lua_toboolean([skin L], -1) && _examineInvalidCertificates) {
                    CFDataRef exceptions = SecTrustCopyExceptions(serverTrust);
                    SecTrustSetExceptions(serverTrust, exceptions);
                    CFRelease(exceptions);
                    completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:serverTrust]);
                } else {
                    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
                }
            }
            lua_pop([skin L], 1) ;
        } else {
            completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        }
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:didReceiveAuthenticationChallenge unhandled challenge type:%@", USERDATA_TAG, [[challenge protectionSpace] authenticationMethod]]] ;
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)webView:(WKWebView *)theView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                                                     decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (self.policyCallback != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:self.policyCallback];
        lua_pushstring([skin L], "navigationAction") ;
        [skin pushNSObject:theView] ;
        [skin pushNSObject:navigationAction] ;

        if (![skin  protectedCallAndTraceback:3 nresults:1]) {
            const char *errorMsg = lua_tostring([skin L], -1);
            [skin logError:[NSString stringWithFormat:@"hs._asm.enclosure.webview:policyCallback() navigationAction callback error: %s", errorMsg]];
            decisionHandler(WKNavigationActionPolicyCancel) ;
        } else {
            if (lua_toboolean([skin L], -1)) {
                decisionHandler(WKNavigationActionPolicyAllow) ;
            } else {
                decisionHandler(WKNavigationActionPolicyCancel) ;
            }
        }
        lua_pop([skin L], 1) ; // clean up after ourselves
    } else {
        decisionHandler(WKNavigationActionPolicyAllow) ;
    }
}

- (void)webView:(WKWebView *)theView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse
                                                       decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    if (self.policyCallback != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:self.policyCallback];
        lua_pushstring([skin L], "navigationResponse") ;
        [skin pushNSObject:theView] ;
        [skin pushNSObject:navigationResponse] ;

        if (![skin  protectedCallAndTraceback:3 nresults:1]) {
            const char *errorMsg = lua_tostring([skin L], -1);
            [skin logError:[NSString stringWithFormat:@"hs._asm.enclosure.webview:policyCallback() navigationResponse callback error: %s", errorMsg]];
            decisionHandler(WKNavigationResponsePolicyCancel) ;
        } else {
            if (lua_toboolean([skin L], -1)) {
                decisionHandler(WKNavigationResponsePolicyAllow) ;
            } else {
                decisionHandler(WKNavigationResponsePolicyCancel) ;
            }
        }
        lua_pop([skin L], 1) ; // clean up after ourselves
    } else {
        decisionHandler(WKNavigationResponsePolicyAllow) ;
    }
}

// - (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView ;

#pragma mark -- WKUIDelegate stuff

- (WKWebView *)webView:(WKWebView *)theView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
                                                       forNavigationAction:(WKNavigationAction *)navigationAction
                                                            windowFeatures:(WKWindowFeatures *)windowFeatures {
    HSWebViewView *newView = nil ;

    if (_allowNewWindows) {
        LuaSkin *skin = [LuaSkin shared] ;
        lua_State *L  = [skin L] ;

        NSRect initialFrame = self.bounds ;
        newView = [[HSWebViewView alloc] initWithFrame:initialFrame configuration:configuration];

        newView.allowNewWindows            = _allowNewWindows ;
        newView.titleFollow                = _titleFollow ;
        newView.examineInvalidCertificates = _examineInvalidCertificates ;

        newView.allowsMagnification                 = theView.allowsMagnification ;
        newView.allowsBackForwardNavigationGestures = theView.allowsBackForwardNavigationGestures ;
        [newView setValue:[self valueForKey:@"drawsTransparentBackground"] forKey:@"drawsTransparentBackground"];

        if (_navigationCallback != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:_navigationCallback];
            newView.navigationCallback = [skin luaRef:refTable] ;
        }
        if (_policyCallback != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:_policyCallback];
            newView.policyCallback = [skin luaRef:refTable] ;
        }
        if (_sslCallback != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:_sslCallback];
            newView.sslCallback = [skin luaRef:refTable] ;
        }

        if (self.policyCallback != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:self.policyCallback];
            lua_pushstring(L, "newWindow") ;
            [skin pushNSObject:newView] ;
            [skin pushNSObject:navigationAction] ;
            [skin pushNSObject:windowFeatures] ;

            if (![skin  protectedCallAndTraceback:4 nresults:1]) {
                NSString *errorMsg = [skin toNSObjectAtIndex:-1] ;
                [skin logError:[NSString stringWithFormat:@"hs._asm.enclosure.webview:policyCallback() newWindow callback error: %@", errorMsg]];
                newView = nil ;
            } else {
                if (!lua_toboolean(L, -1)) newView = nil ;
            }
            lua_pop(L, 1) ; // returned boolean or error message
        }
    }
    return newView ;
}

- (void)webView:(WKWebView *)theView runJavaScriptAlertPanelWithMessage:(NSString *)message
                                                       initiatedByFrame:(WKFrameInfo *)frame
                                                      completionHandler:(void (^)(void))completionHandler {
    NSAlert *alertPanel = [[NSAlert alloc] init] ;
    [alertPanel addButtonWithTitle:@"OK"];
    [alertPanel setMessageText:[NSString stringWithFormat:@"JavaScript Alert for %@", frame.request.URL.host]] ;
    [alertPanel setInformativeText:message] ;

    NSWindow *targetWindow = theView.window ;
    if (targetWindow) {
        [alertPanel beginSheetModalForWindow:targetWindow completionHandler:^(__unused NSModalResponse returnCode){
            completionHandler() ;
        }] ;
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:runJavaScriptAlertPanelWithMessage no target window", USERDATA_TAG]] ;
    }
}

- (void)webView:(WKWebView *)theView runJavaScriptConfirmPanelWithMessage:(NSString *)message
                                                         initiatedByFrame:(WKFrameInfo *)frame
                                                        completionHandler:(void (^)(BOOL result))completionHandler{
    NSAlert *confirmPanel = [[NSAlert alloc] init] ;
    [confirmPanel addButtonWithTitle:@"OK"] ;
    [confirmPanel addButtonWithTitle:@"Cancel"] ;
    [confirmPanel setMessageText:[NSString stringWithFormat:@"JavaScript Confirm for %@", frame.request.URL.host]] ;
    [confirmPanel setInformativeText:message] ;

    NSWindow *targetWindow = theView.window ;
    if (targetWindow) {
        [confirmPanel beginSheetModalForWindow:targetWindow completionHandler:^(NSModalResponse returnCode){
            completionHandler((returnCode == NSAlertFirstButtonReturn) ? YES : NO) ;
        }] ;
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:runJavaScriptConfirmPanelWithMessage no target window", USERDATA_TAG]] ;
    }
}

- (void)webView:(WKWebView *)theView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt
                                                               defaultText:(NSString *)defaultText
                                                          initiatedByFrame:(WKFrameInfo *)frame
                                                         completionHandler:(void (^)(NSString *result))completionHandler{
    NSAlert *inputPanel = [[NSAlert alloc] init] ;
    [inputPanel addButtonWithTitle:@"OK"] ;
    [inputPanel addButtonWithTitle:@"Cancel"] ;
    [inputPanel setMessageText:[NSString stringWithFormat:@"JavaScript Input for %@", frame.request.URL.host]] ;
    [inputPanel setInformativeText:prompt] ;
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)] ;
    input.stringValue = defaultText ;
    input.editable = YES ;
    [inputPanel setAccessoryView:input] ;

    NSWindow *targetWindow = theView.window ;
    if (targetWindow) {
        [inputPanel beginSheetModalForWindow:targetWindow completionHandler:^(NSModalResponse returnCode){
            if (returnCode == NSAlertFirstButtonReturn)
                completionHandler(input.stringValue) ;
            else
                completionHandler(nil) ;
        }] ;
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:runJavaScriptTextInputPanelWithPrompt no target window", USERDATA_TAG]] ;
    }
}

// - (void)webViewDidClose:(WKWebView *)webView ;

#pragma mark -- Helper methods to reduce code replication

- (void)handleNavigationFailure:(NSError *)error forView:(WKWebView *)theView {
// TODO: Really need to figure out how NSErrorRecoveryAttempting works so self-signed certs don't have to be pre-approved via Safari

    NSMutableString *theErrorPage = [[NSMutableString alloc] init] ;
    [theErrorPage appendFormat:@"<html><head><title>Webview Error %ld</title></head><body>"
                                "<b>An Error code: %ld in %@ occurred during navigation:</b><br>"
                                "<hr>", (long)error.code, (long)error.code, error.domain] ;

    if (error.localizedDescription)   [theErrorPage appendFormat:@"<i>Description:</i> %@<br>", error.localizedDescription] ;
    if (error.localizedFailureReason) [theErrorPage appendFormat:@"<i>Reason:</i> %@<br>", error.localizedFailureReason] ;
    [theErrorPage appendFormat:@"</body></html>"] ;

    [theView loadHTMLString:theErrorPage baseURL:nil] ;
}

- (BOOL)navigationCallbackFor:(const char *)action forView:(WKWebView *)theView
                                            withNavigation:(WKNavigation *)navigation
                                                 withError:(NSError *)error {

    ((HSWebViewView *)theView).trackingID = navigation ;

    BOOL actionRequiredAfterReturn = YES ;

    if (self.navigationCallback != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        int numberOfArguments = 3 ;
        [skin pushLuaRef:refTable ref:self.navigationCallback];
        lua_pushstring([skin L], action) ;
        [skin pushNSObject:theView] ;
        lua_pushstring([skin L], [[NSString stringWithFormat:@"0x%@", (void *)navigation] UTF8String]) ;

        if (error) {
            numberOfArguments++ ;
            NSError_toLua(skin.L, error) ;
        }

        if (![skin  protectedCallAndTraceback:numberOfArguments nresults:1]) {
            const char *errorMsg = lua_tostring([skin L], -1);
            [skin logError:[NSString stringWithFormat:@"hs._asm.enclosure.webview:navigationCallback() %s callback error: %s", action, errorMsg]];
        } else {
            if (error) {
                if (lua_type([skin L], -1) == LUA_TSTRING) {
                    luaL_tolstring([skin L], -1, NULL) ;
                    NSString *theHTML = [skin toNSObjectAtIndex:-1] ;
                    lua_pop([skin L], 1) ;

                    [theView loadHTMLString:theHTML baseURL:nil] ;
                    actionRequiredAfterReturn = NO ;

                } else if (lua_type([skin L], -1) == LUA_TBOOLEAN && lua_toboolean([skin L], -1)) {
                    actionRequiredAfterReturn = NO ;
                }
            }
        }
        lua_pop([skin L], 1) ; // clean up after ourselves
    }

    return actionRequiredAfterReturn ;
}

@end

// @interface WKPreferences (WKPrivate)
// @property (nonatomic, setter=_setDeveloperExtrasEnabled:) BOOL _developerExtrasEnabled;
// @end

// Yeah, I know the distinction is a little blurry and arbitrary, but it helps my thinking.
#pragma mark - WKWebView Related Methods

#ifdef _WK_DEBUG
static int webview_preferences(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewView          *theView = [skin toNSObjectAtIndex:1] ;
    WKWebViewConfiguration *theConfiguration = [theView configuration] ;
    WKPreferences          *thePreferences = [theConfiguration preferences] ;

    lua_newtable(L) ;
        lua_pushnumber(L, [thePreferences minimumFontSize]) ;
        lua_setfield(L, -2, "minimumFontSize") ;
        lua_pushboolean(L, [thePreferences javaEnabled]) ;
        lua_setfield(L, -2, "javaEnabled") ;
        lua_pushboolean(L, [thePreferences javaScriptEnabled]) ;
        lua_setfield(L, -2, "javaScriptEnabled") ;
        lua_pushboolean(L, [thePreferences plugInsEnabled]) ;
        lua_setfield(L, -2, "plugInsEnabled") ;
        lua_pushboolean(L, [thePreferences javaScriptCanOpenWindowsAutomatically]) ;
        lua_setfield(L, -2, "javaScriptCanOpenWindowsAutomatically") ;
        lua_pushboolean(L, [theConfiguration suppressesIncrementalRendering]) ;
        lua_setfield(L, -2, "suppressesIncrementalRendering") ;
// 10.11, need to also review for 10.12
        lua_pushboolean(L, [[theConfiguration websiteDataStore] isPersistent]) ;
        lua_setfield(L, -2, "persistent") ;
        lua_pushboolean(L, [theConfiguration allowsAirPlayForMediaPlayback]) ;
        lua_setfield(L, -2, "allowsAirPlayForMediaPlayback") ;
        [skin pushNSObject:[theView customUserAgent]] ;
        lua_setfield(L, -2, "customUserAgent") ;
        [skin pushNSObject:[theConfiguration applicationNameForUserAgent]];
        lua_setfield(L, -2, "applicationNameForUserAgent") ;
    return 1 ;
}
#endif

static int webview_privateBrowsing(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    if (NSClassFromString(@"WKWebsiteDataStore")) {
        WKWebViewConfiguration *theConfiguration = [theView configuration] ;
        lua_pushboolean(L, !theConfiguration.websiteDataStore.persistent) ;
    } else {
        [skin logInfo:[NSString stringWithFormat:@"%s:private browsing requires OS X 10.11 and newer", USERDATA_TAG]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int webview_url(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    if (lua_type(L, 2) == LUA_TNONE) {
        [skin pushNSObject:[theView URL]] ;
        return 1 ;
    } else {
        NSURLRequest *theNSURL = [skin luaObjectAtIndex:2 toClass:"NSURLRequest"] ;
        if (theNSURL) {
            WKNavigation *navID = [theView loadRequest:theNSURL] ;
            theView.trackingID = navID ;
            lua_pushvalue(L, 1) ;
            [skin pushNSObject:navID] ;
            return 2 ;
        } else {
            return luaL_error(L, "Invalid URL type.  String or table expected.") ;
        }
    }
}

static int webview_userAgent(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    if ([theView respondsToSelector:NSSelectorFromString(@"customUserAgent")]) {
        if (lua_type(L, 2) == LUA_TNONE) {
            [skin pushNSObject:theView.customUserAgent] ;
        } else {
            theView.customUserAgent = [skin toNSObjectAtIndex:2] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        [skin logInfo:[NSString stringWithFormat:@"%s:userAgent requires OS X 10.11 and newer", USERDATA_TAG]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int webview_certificateChain(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    if ([theView respondsToSelector:NSSelectorFromString(@"certificateChain")]) {
        lua_newtable(L) ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
// FIXME: ssl is a moving target and 10.12 made some changes... need to ponder
        for (id certificate in theView.certificateChain) {
#pragma clang diagnostic pop
            SecCertificateRef_toLua(L, (__bridge SecCertificateRef)certificate) ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else {
        [skin logInfo:[NSString stringWithFormat:@"%s:certificateChain requires OS X 10.11 and newer", USERDATA_TAG]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int webview_title(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:[theView title]] ;
    return 1 ;
}

static int webview_navigationID(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:theView.trackingID] ;
    return 1 ;
}

static int webview_loading(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, [theView isLoading]) ;

    return 1 ;
}

static int webview_stopLoading(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    [theView stopLoading] ;

    lua_settop(L, 1) ;
    return 1 ;
}

static int webview_estimatedProgress(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    lua_pushnumber(L, [theView estimatedProgress]) ;

    return 1 ;
}

static int webview_isOnlySecureContent(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, [theView hasOnlySecureContent]) ;

    return 1 ;
}

static int webview_goForward(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;
    [theView goForward] ;

    lua_settop(L, 1) ;
    return 1 ;
}

static int webview_goBack(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;
    [theView goBack] ;

    lua_settop(L, 1) ;
    return 1 ;
}

static int webview_reload(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    WKNavigation *navID ;
    if (lua_type(L, 2) == LUA_TBOOLEAN && lua_toboolean(L, 2))
        navID = [theView reload] ;
    else
        navID = [theView reloadFromOrigin] ;

    theView.trackingID = navID ;

    lua_pushvalue(L, 1) ;
    [skin pushNSObject:navID] ;
    return 2 ;
}

static int webview_transparent(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, [[theView valueForKey:@"drawsTransparentBackground"] boolValue]);
    } else {
        [theView setValue:@(lua_toboolean(L, 2)) forKey:@"drawsTransparentBackground"];
        lua_settop(L, 1) ;
    }
    return 1 ;
}

static int webview_allowMagnificationGestures(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, [theView allowsMagnification]) ;
    } else {
        [theView setAllowsMagnification:(BOOL)lua_toboolean(L, 2)] ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

static int webview_allowNewWindows(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theView.allowNewWindows) ;
    } else {
        theView.allowNewWindows = (BOOL)lua_toboolean(L, 2) ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

static int webview_examineInvalidCertificates(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theView.examineInvalidCertificates) ;
    } else {
        theView.examineInvalidCertificates = (BOOL)lua_toboolean(L, 2) ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

static int webview_allowNavigationGestures(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, [theView allowsBackForwardNavigationGestures]) ;
    } else {
        [theView setAllowsBackForwardNavigationGestures:(BOOL)lua_toboolean(L, 2)] ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

static int webview_magnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK | LS_TVARARG] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushnumber(L, [theView magnification]) ;
    } else {
        NSPoint centerOn = NSZeroPoint;
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

// Center point doesn't seem to do anything... will investigate further later...
        if (lua_type(L, 3) == LUA_TTABLE) {
            centerOn = [skin tableToPointAtIndex:3] ;
        }

        [theView setMagnification:lua_tonumber(L, 2) centeredAtPoint:centerOn] ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

static int webview_html(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    luaL_tolstring(L, 2, NULL) ;

    NSString *theHTML = [skin toNSObjectAtIndex:-1] ;
    lua_pop(L, 1) ;

    NSString *theBaseURL = (lua_type(L, 3) == LUA_TSTRING) ? [skin toNSObjectAtIndex:3] : nil ;

    WKNavigation *navID = [theView loadHTMLString:theHTML baseURL:[NSURL URLWithString:theBaseURL]] ;
    theView.trackingID = navID ;

    lua_pushvalue(L, 1) ;
    [skin pushNSObject:navID] ;
    return 2 ;
}

static int webview_navigationCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL,
                    LS_TBREAK] ;

    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    // We're either removing a callback, or setting a new one. Either way, we want to clear out any callback that exists
    theView.navigationCallback = [skin luaUnref:refTable ref:theView.navigationCallback] ;

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        theView.navigationCallback = [skin luaRef:refTable] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

static int webview_policyCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL,
                    LS_TBREAK] ;

    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    // We're either removing a callback, or setting a new one. Either way, we want to clear out any callback that exists
    theView.policyCallback = [skin luaUnref:refTable ref:theView.policyCallback] ;

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        theView.policyCallback = [skin luaRef:refTable] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

static int webview_sslCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL,
                    LS_TBREAK] ;

    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    // We're either removing a callback, or setting a new one. Either way, we want to clear out any callback that exists
    theView.sslCallback = [skin luaUnref:refTable ref:theView.sslCallback] ;

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        theView.sslCallback = [skin luaRef:refTable] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

static int webview_historyList(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[theView backForwardList]] ;
    return 1 ;
}

static int webview_evaluateJavaScript(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING,
                    LS_TFUNCTION | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;
    NSString *javascript = [skin toNSObjectAtIndex:2] ;
    int      callbackRef = LUA_NOREF ;

    if (lua_type(L, 3) == LUA_TFUNCTION) {
        lua_pushvalue(L, 3) ;
        callbackRef = [skin luaRef:refTable] ;
    }

    [theView evaluateJavaScript:javascript
              completionHandler:^(id obj, NSError *error){

        if (callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:callbackRef] ;
            [skin pushNSObject:obj] ;
            NSError_toLua(L, error) ;
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                const char *errorMsg = lua_tostring([skin L], -1);
                lua_pop([skin L], 1) ;
                [skin logError:[NSString stringWithFormat:@"hs._asm.enclosure.webview:evaluateJavaScript() callback error: %s", errorMsg]];
            }
            [skin luaUnref:refTable ref:callbackRef] ;
        }
    }] ;

    lua_settop(L, 1) ;
    return 1 ;
}

#pragma mark - Window Related Methods

static int webview_newView(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSRect                  frameRect    = NSZeroRect ;
    int                     optionsTable = 0 ;
    HSUserContentController *ucc         = nil ;

    switch(lua_gettop(L)) {
        case 0:
            break ;
        case 1:
            if (lua_type(L, 1) == LUA_TTABLE) {
                if ((lua_getfield(L, 1, "x") == LUA_TNUMBER) || (lua_getfield(L, 1, "y") == LUA_TNUMBER) ||
                    (lua_getfield(L, 1, "h") == LUA_TNUMBER) || (lua_getfield(L, 1, "w") == LUA_TNUMBER)) {
                    frameRect = [skin tableToRectAtIndex:1] ;
                } else {
                    optionsTable = 1 ;
                }
                lua_settop(L, 1) ;
            } else {
                luaL_checkudata(L, 1, USERDATA_UCC_TAG) ;
                ucc = [skin toNSObjectAtIndex:1] ;
            }
            break ;
        case 2:
            luaL_checktype(L, 1, LUA_TTABLE) ;
            if ((lua_getfield(L, 1, "x") == LUA_TNUMBER) || (lua_getfield(L, 1, "y") == LUA_TNUMBER) ||
                (lua_getfield(L, 1, "h") == LUA_TNUMBER) || (lua_getfield(L, 1, "w") == LUA_TNUMBER)) {
                frameRect = [skin tableToRectAtIndex:1] ;
            } else {
                optionsTable = 1 ;
            }
            lua_settop(L, 2) ;
            if (optionsTable == 1) {
                luaL_checkudata(L, 2, USERDATA_UCC_TAG) ;
                ucc = [skin toNSObjectAtIndex:2] ;
            } else {
                luaL_checktype(L, 2, LUA_TTABLE) ;
                optionsTable = 2 ;
            }
            break ;
        case 3:
            [skin checkArgs:LS_TTABLE, LS_TTABLE, LS_TUSERDATA, USERDATA_UCC_TAG, LS_TBREAK] ;
            frameRect = [skin tableToRectAtIndex:1] ;
            optionsTable = 2 ;
            ucc = [skin toNSObjectAtIndex:3] ;
            break ;
        default:
            return luaL_error(L, "found more than 3 arguments") ;
    }

    // Don't create until actually used...
    if (!HSWebViewProcessPool) HSWebViewProcessPool = [[WKProcessPool alloc] init] ;

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init] ;
    config.processPool = HSWebViewProcessPool ;

    if (optionsTable > 0) {
        WKPreferences *myPreferences = [[WKPreferences alloc] init] ;

        if (lua_getfield(L, optionsTable, "javaEnabled") == LUA_TBOOLEAN) {
            myPreferences.javaEnabled = (BOOL)lua_toboolean(L, -1) ;
        }
        lua_pop(L, 1) ;

        if (lua_getfield(L, optionsTable, "javaScriptEnabled") == LUA_TBOOLEAN) {
            myPreferences.javaScriptEnabled = (BOOL)lua_toboolean(L, -1) ;
        }
        lua_pop(L, 1) ;

        if (lua_getfield(L, optionsTable, "javaScriptCanOpenWindowsAutomatically") == LUA_TBOOLEAN) {
            myPreferences.javaScriptCanOpenWindowsAutomatically = (BOOL)lua_toboolean(L, -1) ;
        }
        lua_pop(L, 1) ;

        if (lua_getfield(L, optionsTable, "plugInsEnabled") == LUA_TBOOLEAN) {
            myPreferences.plugInsEnabled = (BOOL)lua_toboolean(L, -1) ;
        }
        lua_pop(L, 1) ;

        if (lua_getfield(L, optionsTable, "minimumFontSize") == LUA_TNUMBER) {
            myPreferences.minimumFontSize = lua_tonumber(L, -1) ;
        }
        lua_pop(L, 1) ;

        if ((lua_getfield(L, optionsTable, "datastore") == LUA_TUSERDATA) && luaL_testudata(L, -1, USERDATA_DS_TAG)) {
            // this type of userdata is impossible to create if you're not on 10.11, so this is highly unlikely, but...
            if ([config respondsToSelector:NSSelectorFromString(@"setWebsiteDataStore:")]) {
                config.websiteDataStore = [skin toNSObjectAtIndex:-1] ;
            } else {
                [skin logError:[NSString stringWithFormat:@"%s:setting a datastore requires OS X 10.11 or newer", USERDATA_TAG]] ;
            }
        }
        lua_pop(L, 1) ;

        // the privateBrowsing flag should override setting a datastore; you actually shouldn't specify both
        if ((lua_getfield(L, optionsTable, "privateBrowsing") == LUA_TBOOLEAN) && lua_toboolean(L, -1)) {
            if ([config respondsToSelector:NSSelectorFromString(@"setWebsiteDataStore:")]) {
                config.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore] ;
            } else {
                [skin logError:[NSString stringWithFormat:@"%s:private mode browsing requires OS X 10.11 or newer", USERDATA_TAG]] ;
            }
        }
        lua_pop(L, 1) ;

        if (lua_getfield(L, optionsTable, "applicationName") == LUA_TSTRING) {
            if ([config respondsToSelector:NSSelectorFromString(@"applicationNameForUserAgent")]) {
                config.applicationNameForUserAgent = [skin toNSObjectAtIndex:-1] ;
            } else {
                [skin logError:[NSString stringWithFormat:@"%s:setting the user agent application name requires OS X 10.11 or newer", USERDATA_TAG]] ;
            }
        }
        lua_pop(L, 1) ;

// Seems to be being ignored, will dig deeper if interest peaks or I have time
        if (lua_getfield(L, optionsTable, "allowsAirPlay") == LUA_TBOOLEAN) {
            if ([config respondsToSelector:NSSelectorFromString(@"setAllowsAirPlayForMediaPlayback:")]) {
                config.allowsAirPlayForMediaPlayback = (BOOL)lua_toboolean(L, -1) ;
            } else {
                [skin logError:[NSString stringWithFormat:@"%s:setting allowsAirPlay requires OS X 10.11 or newer", USERDATA_TAG]] ;
            }
        }
        lua_pop(L, 1) ;

        // this is undocumented in Apples Documentation, but is in the WebKit2 stuff... and it works
        if (lua_getfield(L, optionsTable, "developerExtrasEnabled") == LUA_TBOOLEAN) {
            [myPreferences setValue:@((BOOL)lua_toboolean(L, -1)) forKey:@"developerExtrasEnabled"] ;
        }
        lua_pop(L, 1) ;

        // Technically not in WKPreferences, but it makes sense to set it here
        if (lua_getfield(L, optionsTable, "suppressesIncrementalRendering") == LUA_TBOOLEAN) {
            config.suppressesIncrementalRendering = (BOOL)lua_toboolean(L, -1) ;
        }
        lua_pop(L, 1) ;
        config.preferences = myPreferences ;
    }

    if (ucc) config.userContentController = ucc ;
    HSWebViewView *theView = [[HSWebViewView alloc] initWithFrame:frameRect configuration:config];
    [skin pushNSObject:theView] ;
    return 1 ;
}

static int webview_windowTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    if (lua_isnoneornil(L, 2)) {
        theView.titleFollow = YES ;
        NSString *windowTitle = theView.title ? theView.title : @"<no title>" ;
        if (theView.window) {
            [theView.window setTitle:windowTitle] ;
        }
    } else {
        luaL_checktype(L, 2, LUA_TSTRING) ;
        theView.titleFollow = NO ;
        if (theView.window) {
            [theView.window setTitle:[skin toNSObjectAtIndex:2]] ;
        }
    }

    lua_settop(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants

static int webview_pushCertificateOIDs(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDADC_CERT_POLICY] ;                           lua_setfield(L, -2, "ADC_CERT_POLICY") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_CERT_POLICY] ;                         lua_setfield(L, -2, "APPLE_CERT_POLICY") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EKU_CODE_SIGNING] ;                    lua_setfield(L, -2, "APPLE_EKU_CODE_SIGNING") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EKU_CODE_SIGNING_DEV] ;                lua_setfield(L, -2, "APPLE_EKU_CODE_SIGNING_DEV") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EKU_ICHAT_ENCRYPTION] ;                lua_setfield(L, -2, "APPLE_EKU_ICHAT_ENCRYPTION") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EKU_ICHAT_SIGNING] ;                   lua_setfield(L, -2, "APPLE_EKU_ICHAT_SIGNING") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EKU_RESOURCE_SIGNING] ;                lua_setfield(L, -2, "APPLE_EKU_RESOURCE_SIGNING") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EKU_SYSTEM_IDENTITY] ;                 lua_setfield(L, -2, "APPLE_EKU_SYSTEM_IDENTITY") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION] ;                           lua_setfield(L, -2, "APPLE_EXTENSION") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_ADC_APPLE_SIGNING] ;         lua_setfield(L, -2, "APPLE_EXTENSION_ADC_APPLE_SIGNING") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_ADC_DEV_SIGNING] ;           lua_setfield(L, -2, "APPLE_EXTENSION_ADC_DEV_SIGNING") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_APPLE_SIGNING] ;             lua_setfield(L, -2, "APPLE_EXTENSION_APPLE_SIGNING") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_CODE_SIGNING] ;              lua_setfield(L, -2, "APPLE_EXTENSION_CODE_SIGNING") ;
//     [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_INTERMEDIATE_MARKER] ;       lua_setfield(L, -2, "APPLE_EXTENSION_INTERMEDIATE_MARKER") ;
//     [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_WWDR_INTERMEDIATE] ;         lua_setfield(L, -2, "APPLE_EXTENSION_WWDR_INTERMEDIATE") ;
//     [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_ITMS_INTERMEDIATE] ;         lua_setfield(L, -2, "APPLE_EXTENSION_ITMS_INTERMEDIATE") ;
//     [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_AAI_INTERMEDIATE] ;          lua_setfield(L, -2, "APPLE_EXTENSION_AAI_INTERMEDIATE") ;
//     [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_APPLEID_INTERMEDIATE] ;      lua_setfield(L, -2, "APPLE_EXTENSION_APPLEID_INTERMEDIATE") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAuthorityInfoAccess] ;                       lua_setfield(L, -2, "authorityInfoAccess") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAuthorityKeyIdentifier] ;                    lua_setfield(L, -2, "authorityKeyIdentifier") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDBasicConstraints] ;                          lua_setfield(L, -2, "basicConstraints") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDBiometricInfo] ;                             lua_setfield(L, -2, "biometricInfo") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCSSMKeyStruct] ;                             lua_setfield(L, -2, "CSSMKeyStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCertIssuer] ;                                lua_setfield(L, -2, "certIssuer") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCertificatePolicies] ;                       lua_setfield(L, -2, "certificatePolicies") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDClientAuth] ;                                lua_setfield(L, -2, "clientAuth") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCollectiveStateProvinceName] ;               lua_setfield(L, -2, "collectiveStateProvinceName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCollectiveStreetAddress] ;                   lua_setfield(L, -2, "collectiveStreetAddress") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCommonName] ;                                lua_setfield(L, -2, "commonName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCountryName] ;                               lua_setfield(L, -2, "countryName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCrlDistributionPoints] ;                     lua_setfield(L, -2, "crlDistributionPoints") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCrlNumber] ;                                 lua_setfield(L, -2, "crlNumber") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCrlReason] ;                                 lua_setfield(L, -2, "crlReason") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDDOTMAC_CERT_EMAIL_ENCRYPT] ;                 lua_setfield(L, -2, "DOTMAC_CERT_EMAIL_ENCRYPT") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDDOTMAC_CERT_EMAIL_SIGN] ;                    lua_setfield(L, -2, "DOTMAC_CERT_EMAIL_SIGN") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDDOTMAC_CERT_EXTENSION] ;                     lua_setfield(L, -2, "DOTMAC_CERT_EXTENSION") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDDOTMAC_CERT_IDENTITY] ;                      lua_setfield(L, -2, "DOTMAC_CERT_IDENTITY") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDDOTMAC_CERT_POLICY] ;                        lua_setfield(L, -2, "DOTMAC_CERT_POLICY") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDDeltaCrlIndicator] ;                         lua_setfield(L, -2, "deltaCrlIndicator") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDDescription] ;                               lua_setfield(L, -2, "description") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDEKU_IPSec] ;                                 lua_setfield(L, -2, "EKU_IPSec") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDEmailAddress] ;                              lua_setfield(L, -2, "emailAddress") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDEmailProtection] ;                           lua_setfield(L, -2, "emailProtection") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDExtendedKeyUsage] ;                          lua_setfield(L, -2, "extendedKeyUsage") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDExtendedKeyUsageAny] ;                       lua_setfield(L, -2, "extendedKeyUsageAny") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDExtendedUseCodeSigning] ;                    lua_setfield(L, -2, "extendedUseCodeSigning") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDGivenName] ;                                 lua_setfield(L, -2, "givenName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDHoldInstructionCode] ;                       lua_setfield(L, -2, "holdInstructionCode") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDInvalidityDate] ;                            lua_setfield(L, -2, "invalidityDate") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDIssuerAltName] ;                             lua_setfield(L, -2, "issuerAltName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDIssuingDistributionPoint] ;                  lua_setfield(L, -2, "issuingDistributionPoint") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDIssuingDistributionPoints] ;                 lua_setfield(L, -2, "issuingDistributionPoints") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDKERBv5_PKINIT_KP_CLIENT_AUTH] ;              lua_setfield(L, -2, "KERBv5_PKINIT_KP_CLIENT_AUTH") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDKERBv5_PKINIT_KP_KDC] ;                      lua_setfield(L, -2, "KERBv5_PKINIT_KP_KDC") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDKeyUsage] ;                                  lua_setfield(L, -2, "keyUsage") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDLocalityName] ;                              lua_setfield(L, -2, "localityName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDMS_NTPrincipalName] ;                        lua_setfield(L, -2, "MS_NTPrincipalName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDMicrosoftSGC] ;                              lua_setfield(L, -2, "microsoftSGC") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDNameConstraints] ;                           lua_setfield(L, -2, "nameConstraints") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDNetscapeCertSequence] ;                      lua_setfield(L, -2, "netscapeCertSequence") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDNetscapeCertType] ;                          lua_setfield(L, -2, "netscapeCertType") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDNetscapeSGC] ;                               lua_setfield(L, -2, "netscapeSGC") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDOCSPSigning] ;                               lua_setfield(L, -2, "OCSPSigning") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDOrganizationName] ;                          lua_setfield(L, -2, "organizationName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDOrganizationalUnitName] ;                    lua_setfield(L, -2, "organizationalUnitName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDPolicyConstraints] ;                         lua_setfield(L, -2, "policyConstraints") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDPolicyMappings] ;                            lua_setfield(L, -2, "policyMappings") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDPrivateKeyUsagePeriod] ;                     lua_setfield(L, -2, "privateKeyUsagePeriod") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDQC_Statements] ;                             lua_setfield(L, -2, "QC_Statements") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSerialNumber] ;                              lua_setfield(L, -2, "serialNumber") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDServerAuth] ;                                lua_setfield(L, -2, "serverAuth") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDStateProvinceName] ;                         lua_setfield(L, -2, "stateProvinceName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDStreetAddress] ;                             lua_setfield(L, -2, "streetAddress") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSubjectAltName] ;                            lua_setfield(L, -2, "subjectAltName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSubjectDirectoryAttributes] ;                lua_setfield(L, -2, "subjectDirectoryAttributes") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSubjectEmailAddress] ;                       lua_setfield(L, -2, "subjectEmailAddress") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSubjectInfoAccess] ;                         lua_setfield(L, -2, "subjectInfoAccess") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSubjectKeyIdentifier] ;                      lua_setfield(L, -2, "subjectKeyIdentifier") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSubjectPicture] ;                            lua_setfield(L, -2, "subjectPicture") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSubjectSignatureBitmap] ;                    lua_setfield(L, -2, "subjectSignatureBitmap") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSurname] ;                                   lua_setfield(L, -2, "surname") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDTimeStamping] ;                              lua_setfield(L, -2, "timeStamping") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDTitle] ;                                     lua_setfield(L, -2, "title") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDUseExemptions] ;                             lua_setfield(L, -2, "useExemptions") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1CertificateIssuerUniqueId] ;           lua_setfield(L, -2, "X509V1CertificateIssuerUniqueId") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1CertificateSubjectUniqueId] ;          lua_setfield(L, -2, "X509V1CertificateSubjectUniqueId") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1IssuerName] ;                          lua_setfield(L, -2, "X509V1IssuerName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1IssuerNameCStruct] ;                   lua_setfield(L, -2, "X509V1IssuerNameCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1IssuerNameLDAP] ;                      lua_setfield(L, -2, "X509V1IssuerNameLDAP") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1IssuerNameStd] ;                       lua_setfield(L, -2, "X509V1IssuerNameStd") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SerialNumber] ;                        lua_setfield(L, -2, "X509V1SerialNumber") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1Signature] ;                           lua_setfield(L, -2, "X509V1Signature") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SignatureAlgorithm] ;                  lua_setfield(L, -2, "X509V1SignatureAlgorithm") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SignatureAlgorithmParameters] ;        lua_setfield(L, -2, "X509V1SignatureAlgorithmParameters") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SignatureAlgorithmTBS] ;               lua_setfield(L, -2, "X509V1SignatureAlgorithmTBS") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SignatureCStruct] ;                    lua_setfield(L, -2, "X509V1SignatureCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SignatureStruct] ;                     lua_setfield(L, -2, "X509V1SignatureStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectName] ;                         lua_setfield(L, -2, "X509V1SubjectName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectNameCStruct] ;                  lua_setfield(L, -2, "X509V1SubjectNameCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectNameLDAP] ;                     lua_setfield(L, -2, "X509V1SubjectNameLDAP") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectNameStd] ;                      lua_setfield(L, -2, "X509V1SubjectNameStd") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectPublicKey] ;                    lua_setfield(L, -2, "X509V1SubjectPublicKey") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectPublicKeyAlgorithm] ;           lua_setfield(L, -2, "X509V1SubjectPublicKeyAlgorithm") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectPublicKeyAlgorithmParameters] ; lua_setfield(L, -2, "X509V1SubjectPublicKeyAlgorithmParameters") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectPublicKeyCStruct] ;             lua_setfield(L, -2, "X509V1SubjectPublicKeyCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1ValidityNotAfter] ;                    lua_setfield(L, -2, "X509V1ValidityNotAfter") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1ValidityNotBefore] ;                   lua_setfield(L, -2, "X509V1ValidityNotBefore") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1Version] ;                             lua_setfield(L, -2, "X509V1Version") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3Certificate] ;                         lua_setfield(L, -2, "X509V3Certificate") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateCStruct] ;                  lua_setfield(L, -2, "X509V3CertificateCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionCStruct] ;         lua_setfield(L, -2, "X509V3CertificateExtensionCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionCritical] ;        lua_setfield(L, -2, "X509V3CertificateExtensionCritical") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionId] ;              lua_setfield(L, -2, "X509V3CertificateExtensionId") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionStruct] ;          lua_setfield(L, -2, "X509V3CertificateExtensionStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionType] ;            lua_setfield(L, -2, "X509V3CertificateExtensionType") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionValue] ;           lua_setfield(L, -2, "X509V3CertificateExtensionValue") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionsCStruct] ;        lua_setfield(L, -2, "X509V3CertificateExtensionsCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionsStruct] ;         lua_setfield(L, -2, "X509V3CertificateExtensionsStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateNumberOfExtensions] ;       lua_setfield(L, -2, "X509V3CertificateNumberOfExtensions") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3SignedCertificate] ;                   lua_setfield(L, -2, "X509V3SignedCertificate") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3SignedCertificateCStruct] ;            lua_setfield(L, -2, "X509V3SignedCertificateCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSRVName] ;                                   lua_setfield(L, -2, "SRVName") ;
    return 1;
}

#pragma mark - NS<->lua conversion tools

static int HSWebViewView_toLua(lua_State *L, id obj) {
    HSWebViewView *value = obj;
    value.referenceCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSWebViewView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id luaTo_HSWebViewView(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSWebViewView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int WKNavigationAction_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    WKNavigationAction *navAction = obj ;

    lua_newtable(L) ;
      [skin pushNSObject:[navAction request]] ;      lua_setfield(L, -2, "request") ;
      [skin pushNSObject:[navAction sourceFrame]] ;  lua_setfield(L, -2, "sourceFrame") ;
      [skin pushNSObject:[navAction targetFrame]] ;  lua_setfield(L, -2, "targetFrame") ;
      lua_pushinteger(L, [navAction buttonNumber]) ; lua_setfield(L, -2, "buttonNumber") ;
      unsigned long theFlags = [navAction modifierFlags] ;
      lua_newtable(L) ;
        if (theFlags & NSEventModifierFlagCapsLock) { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "capslock") ; }
        if (theFlags & NSEventModifierFlagShift)    { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "shift") ; }
        if (theFlags & NSEventModifierFlagControl)  { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "ctrl") ; }
        if (theFlags & NSEventModifierFlagOption)   { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "alt") ; }
        if (theFlags & NSEventModifierFlagCommand)  { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "cmd") ; }
        if (theFlags & NSEventModifierFlagFunction) { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "fn") ; }
        lua_pushinteger(L, (lua_Integer)theFlags); lua_setfield(L, -2, "_raw");
      lua_setfield(L, -2, "modifierFlags") ;
      switch([navAction navigationType]) {
          case WKNavigationTypeLinkActivated:   lua_pushstring(L, "linkActivated") ; break ;
          case WKNavigationTypeFormSubmitted:   lua_pushstring(L, "formSubmitted") ; break ;
          case WKNavigationTypeBackForward:     lua_pushstring(L, "backForward") ; break ;
          case WKNavigationTypeReload:          lua_pushstring(L, "reload") ; break ;
          case WKNavigationTypeFormResubmitted: lua_pushstring(L, "formResubmitted") ; break ;
          case WKNavigationTypeOther:           lua_pushstring(L, "other") ; break ;
          default:                              lua_pushstring(L, "unknown") ; break ;
      }
      lua_setfield(L, -2, "navigationType") ;

    return 1 ;
}

static int WKNavigationResponse_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    WKNavigationResponse *navResponse = obj ;

    lua_newtable(L) ;
      lua_pushboolean(L, [navResponse canShowMIMEType]) ; lua_setfield(L, -2, "canShowMIMEType") ;
      lua_pushboolean(L, [navResponse isForMainFrame]) ;  lua_setfield(L, -2, "forMainFrame") ;
      [skin pushNSObject:[navResponse response]] ;        lua_setfield(L, -2, "response") ;
    return 1 ;
}

static int WKFrameInfo_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    WKFrameInfo *frameInfo = obj ;

    lua_newtable(L) ;
    lua_pushboolean(L, frameInfo.mainFrame) ; lua_setfield(L, -2, "mainFrame") ;
    [skin pushNSObject:frameInfo.request] ;     lua_setfield(L, -2, "request") ;
    if (NSClassFromString(@"WKSecurityOrigin") && [frameInfo respondsToSelector:@selector(securityOrigin)]) {
        [skin pushNSObject:frameInfo.securityOrigin] ; lua_setfield(L, -2, "securityOrigin") ;
    }
    return 1 ;
}

static int WKBackForwardListItem_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    WKBackForwardListItem *item = obj ;

    lua_newtable(L) ;
      [skin pushNSObject:[item URL]] ;        lua_setfield(L, -2, "URL") ;
      [skin pushNSObject:[item initialURL]] ; lua_setfield(L, -2, "initialURL") ;
      [skin pushNSObject:[item title]] ;      lua_setfield(L, -2, "title") ;
    return 1 ;
}

static int WKBackForwardList_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    WKBackForwardList *theList = obj ;

    lua_newtable(L) ;
    if (theList) {
        NSArray *previousList = [theList backList] ;
        NSArray *nextList = [theList forwardList] ;

        for(id value in previousList) {
            [skin pushNSObject:value] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        if ([theList currentItem]) {
            [skin pushNSObject:[theList currentItem]] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        lua_pushinteger(L, luaL_len(L, -1)) ; lua_setfield(L, -2, "current") ;

        for(id value in nextList) {
            [skin pushNSObject:value] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else {
        lua_pushinteger(L, 0) ; lua_setfield(L, -2, "current") ;
    }
    return 1 ;
}

static int WKNavigation_toLua(lua_State *L, id obj) {
    WKNavigation *navID = obj ;
    lua_pushstring(L, [[NSString stringWithFormat:@"0x%p", (void *)navID] UTF8String]) ;
    return 1 ;
}

static int NSError_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSError *theError = obj ;

    lua_newtable(L) ;
        lua_pushinteger(L, [theError code]) ;                        lua_setfield(L, -2, "code") ;
        [skin pushNSObject:[theError domain]] ;                      lua_setfield(L, -2, "domain") ;
        [skin pushNSObject:[theError helpAnchor]] ;                  lua_setfield(L, -2, "helpAnchor") ;
        [skin pushNSObject:[theError localizedDescription]] ;        lua_setfield(L, -2, "localizedDescription") ;
        [skin pushNSObject:[theError localizedRecoveryOptions]] ;    lua_setfield(L, -2, "localizedRecoveryOptions") ;
        [skin pushNSObject:[theError localizedRecoverySuggestion]] ; lua_setfield(L, -2, "localizedRecoverySuggestion") ;
        [skin pushNSObject:[theError localizedFailureReason]] ;      lua_setfield(L, -2, "localizedFailureReason") ;
#ifdef _WK_DEBUG
        [skin pushNSObject:[theError userInfo] withOptions:LS_NSDescribeUnknownTypes] ;                    lua_setfield(L, -2, "userInfo") ;
#endif
    return 1 ;
}

static int WKWindowFeatures_toLua(lua_State *L, id obj) {
    WKWindowFeatures *features = obj ;

    lua_newtable(L) ;
      if (features.menuBarVisibility) {
          lua_pushboolean(L, [features.menuBarVisibility boolValue]) ;
          lua_setfield(L, -2, "menuBarVisibility") ;
      }
      if (features.statusBarVisibility) {
          lua_pushboolean(L, [features.statusBarVisibility boolValue]) ;
          lua_setfield(L, -2, "statusBarVisibility") ;
      }
      if (features.toolbarsVisibility) {
          lua_pushboolean(L, [features.toolbarsVisibility boolValue]) ;
          lua_setfield(L, -2, "toolbarsVisibility") ;
      }
      if (features.allowsResizing) {
          lua_pushboolean(L, [features.allowsResizing boolValue]) ;
          lua_setfield(L, -2, "allowsResizing") ;
      }
      if (features.x) {
          lua_pushnumber(L, [features.x doubleValue]) ;
          lua_setfield(L, -2, "x") ;
      }
      if (features.y) {
          lua_pushnumber(L, [features.y doubleValue]) ;
          lua_setfield(L, -2, "y") ;
      }
      if (features.height) {
          lua_pushnumber(L, [features.height doubleValue]) ;
          lua_setfield(L, -2, "h") ;
      }
      if (features.width) {
          lua_pushnumber(L, [features.width doubleValue]) ;
          lua_setfield(L, -2, "w") ;
      }

    return 1 ;
}

static int NSURLAuthenticationChallenge_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSURLAuthenticationChallenge *challenge = obj ;

    lua_newtable(L) ;
        lua_pushinteger(L, [challenge previousFailureCount]) ; lua_setfield(L, -2, "previousFailureCount") ;
        [skin pushNSObject:[challenge error]] ;                lua_setfield(L, -2, "error") ;
        [skin pushNSObject:[challenge failureResponse]] ;      lua_setfield(L, -2, "failureResponse") ;
        [skin pushNSObject:[challenge proposedCredential]] ;   lua_setfield(L, -2, "proposedCredential") ;
        [skin pushNSObject:[challenge protectionSpace]] ;      lua_setfield(L, -2, "protectionSpace") ;

    return 1 ;
}

static int SecCertificateRef_toLua(lua_State *L, SecCertificateRef certRef) {
    LuaSkin *skin = [LuaSkin shared] ;
    lua_newtable(L) ;
    CFStringRef commonName = NULL ;
    SecCertificateCopyCommonName(certRef, &commonName);
    if (commonName) {
        [skin pushNSObject:(__bridge NSString *)commonName] ; lua_setfield(L, -2, "commonName") ;
        CFRelease(commonName);
    }
    CFDictionaryRef values = SecCertificateCopyValues(certRef, NULL, NULL);
    if (values) {
        [skin pushNSObject:(__bridge NSDictionary *)values withOptions:LS_NSDescribeUnknownTypes] ;
        lua_setfield(L, -2, "values") ;
        CFRelease(values) ;
    }
    return 1 ;
}

static int NSURLProtectionSpace_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSURLProtectionSpace *theSpace = obj ;

    lua_newtable(L) ;
        lua_pushboolean(L, [theSpace isProxy]) ;                    lua_setfield(L, -2, "isProxy") ;
        lua_pushinteger(L, [theSpace port]) ;                       lua_setfield(L, -2, "port") ;
        lua_pushboolean(L, [theSpace receivesCredentialSecurely]) ; lua_setfield(L, -2, "receivesCredentialSecurely") ;
        NSString *method = @"unknown" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodDefault])           method = @"default" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodHTTPBasic])         method = @"HTTPBasic" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodHTTPDigest])        method = @"HTTPDigest" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodHTMLForm])          method = @"HTMLForm" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodNegotiate])         method = @"negotiate" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodNTLM])              method = @"NTLM" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodClientCertificate]) method = @"clientCertificate" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust])       method = @"serverTrust" ;
        [skin pushNSObject:method] ;              lua_setfield(L, -2, "authenticationMethod") ;

        [skin pushNSObject:[theSpace host]] ;     lua_setfield(L, -2, "host") ;
        [skin pushNSObject:[theSpace protocol]] ; lua_setfield(L, -2, "protocol") ;
        NSString *proxy = @"unknown" ;
        if ([[theSpace proxyType] isEqualToString:NSURLProtectionSpaceHTTPProxy])  proxy = @"http" ;
        if ([[theSpace proxyType] isEqualToString:NSURLProtectionSpaceHTTPSProxy]) proxy = @"https" ;
        if ([[theSpace proxyType] isEqualToString:NSURLProtectionSpaceFTPProxy])   proxy = @"ftp" ;
        if ([[theSpace proxyType] isEqualToString:NSURLProtectionSpaceSOCKSProxy]) proxy = @"socks" ;
        [skin pushNSObject:proxy] ;            lua_setfield(L, -2, "proxyType") ;

        [skin pushNSObject:[theSpace realm]] ; lua_setfield(L, -2, "realm") ;

        SecTrustRef serverTrust = [theSpace serverTrust] ;
        if (serverTrust) {
            lua_newtable(L) ;
            SecTrustEvaluate(serverTrust, NULL);
            CFIndex count = SecTrustGetCertificateCount(serverTrust);
            for (CFIndex idx = 0 ; idx < count ; idx++) {
                SecCertificateRef_toLua(L, SecTrustGetCertificateAtIndex(serverTrust, idx)) ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
            lua_setfield(L, -2, "certificates") ;
        }

    return 1 ;
}

static int NSURLCredential_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSURLCredential *credential = obj ;

    lua_newtable(L) ;
        lua_pushboolean(L, [credential hasPassword]) ; lua_setfield(L, -2, "hasPassword") ;
        switch([credential persistence]) {
            case NSURLCredentialPersistenceNone:           lua_pushstring(L, "none") ; break ;
            case NSURLCredentialPersistenceForSession:     lua_pushstring(L, "session") ; break ;
            case NSURLCredentialPersistencePermanent:      lua_pushstring(L, "permanent") ; break ;
            case NSURLCredentialPersistenceSynchronizable: lua_pushstring(L, "synchronized") ; break ;
            default:                                       lua_pushstring(L, "unknown") ; break ;
        }
      lua_setfield(L, -2, "persistence") ;

        [skin pushNSObject:[credential user]] ;     lua_setfield(L, -2, "user") ;
        [skin pushNSObject:[credential password]] ; lua_setfield(L, -2, "password") ;

// // if we ever support client certificates, this may become important. until then...
//         [skin pushNSObject:[credential certificates]] ; lua_setfield(L, -2, "certificates") ;
//         lua_pushstring([skin L], [[NSString stringWithFormat:@"0x%p", (void *)[credential identity]] UTF8String]) ;
//         lua_setfield(L, -2, "identity") ;

    return 1 ;
}

static int WKSecurityOrigin_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    WKSecurityOrigin *origin = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:origin.host] ;     lua_setfield(L, -2, "host") ;
    lua_pushinteger(L, origin.port) ;     lua_setfield(L, -2, "port") ;
    [skin pushNSObject:origin.protocol] ; lua_setfield(L, -2, "protocol") ;
    return 1 ;
}

#pragma mark - Lua Framework Stuff

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;
    NSString *title ;

    if (theView.window) { title = [theView title] ; } else { title = @"<unattached>" ; }
    if (!title) { title = @"" ; }

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSWebViewView *obj1 = [skin luaObjectAtIndex:1 toClass:"HSWebViewView"] ;
        HSWebViewView *obj2 = [skin luaObjectAtIndex:2 toClass:"HSWebViewView"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewView *theView = [skin toNSObjectAtIndex:1] ;

    if (theView) {
        theView.referenceCount-- ;
        if (theView.referenceCount == 0) {
            theView.navigationCallback = [skin luaUnref:refTable ref:theView.navigationCallback] ;
            theView.policyCallback     = [skin luaUnref:refTable ref:theView.policyCallback] ;
            theView.sslCallback        = [skin luaUnref:refTable ref:theView.sslCallback] ;

            theView.navigationDelegate = nil ;
            theView.UIDelegate         = nil ;
            theView                    = nil ;
        }
    }

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0;
}

static int meta_gc(lua_State* __unused L) {
    if (HSWebViewProcessPool) {
        HSWebViewProcessPool = nil ;
    }
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    // Webview Related
    {"goBack",                     webview_goBack},
    {"goForward",                  webview_goForward},
    {"url",                        webview_url},
    {"title",                      webview_title},
    {"navigationID",               webview_navigationID},
    {"reload",                     webview_reload},
    {"transparent",                webview_transparent},
    {"magnification",              webview_magnification},
    {"allowMagnificationGestures", webview_allowMagnificationGestures},
    {"allowNewWindows",            webview_allowNewWindows},
    {"allowNavigationGestures",    webview_allowNavigationGestures},
    {"isOnlySecureContent",        webview_isOnlySecureContent},
    {"estimatedProgress",          webview_estimatedProgress},
    {"loading",                    webview_loading},
    {"stopLoading",                webview_stopLoading},
    {"html",                       webview_html},
    {"historyList",                webview_historyList},
    {"navigationCallback",         webview_navigationCallback},
    {"policyCallback",             webview_policyCallback},
    {"sslCallback",                webview_sslCallback},
    {"evaluateJavaScript",         webview_evaluateJavaScript},
    {"privateBrowsing",            webview_privateBrowsing},
    {"userAgent",                  webview_userAgent},
    {"certificateChain",           webview_certificateChain},
    {"windowTitle",                webview_windowTitle},

    {"examineInvalidCertificates",   webview_examineInvalidCertificates},
#ifdef _WK_DEBUG
    {"preferences",                webview_preferences},
#endif

    // Window related

    {"__tostring",                 userdata_tostring},
    {"__eq",                       userdata_eq},
    {"__gc",                       userdata_gc},
    {NULL,                         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"newView",  webview_newView},

    {NULL,       NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs__asm_enclosure_webview_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    if (!NSClassFromString(@"WKWebView")) {
        [skin logError:[NSString stringWithFormat:@"%s requires WKWebView support, found in OS X 10.10 or newer", USERDATA_TAG]] ;
        // nil gets interpreted as "nothing" and thus "true" by require...
        lua_pushboolean(L, NO) ;
    } else {
        refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                                     functions:moduleLib
                                                 metaFunctions:module_metaLib
                                               objectFunctions:userdata_metaLib];

        // module userdata specific conversions
        [skin registerPushNSHelper:HSWebViewView_toLua              forClass:"HSWebViewView"] ;
        [skin registerLuaObjectHelper:luaTo_HSWebViewView           forClass:"HSWebViewView"
                                                         withUserdataMapping:USERDATA_TAG] ;


        // classes used primarily (solely?) by this module
        [skin registerPushNSHelper:WKBackForwardListItem_toLua        forClass:"WKBackForwardListItem"] ;
        [skin registerPushNSHelper:WKBackForwardList_toLua            forClass:"WKBackForwardList"] ;
        [skin registerPushNSHelper:WKNavigationAction_toLua           forClass:"WKNavigationAction"] ;
        [skin registerPushNSHelper:WKNavigationResponse_toLua         forClass:"WKNavigationResponse"] ;
        [skin registerPushNSHelper:WKFrameInfo_toLua                  forClass:"WKFrameInfo"] ;
        [skin registerPushNSHelper:WKNavigation_toLua                 forClass:"WKNavigation"] ;
        [skin registerPushNSHelper:WKWindowFeatures_toLua             forClass:"WKWindowFeatures"] ;

        if (NSClassFromString(@"WKSecurityOrigin")) {
            [skin registerPushNSHelper:WKSecurityOrigin_toLua             forClass:"WKSecurityOrigin"] ;
        }

        // classes that may find a better home elsewhere someday... (hs.http perhaps)
        [skin registerPushNSHelper:NSURLAuthenticationChallenge_toLua forClass:"NSURLAuthenticationChallenge"] ;
        [skin registerPushNSHelper:NSURLProtectionSpace_toLua         forClass:"NSURLProtectionSpace"] ;
        [skin registerPushNSHelper:NSURLCredential_toLua              forClass:"NSURLCredential"] ;

        webview_pushCertificateOIDs(L) ; lua_setfield(L, -2, "certificateOIDs") ;

    }
    return 1;
}
