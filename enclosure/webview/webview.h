
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreserved-id-macro"
#define _WK_DEBUG
#pragma clang diagnostic pop

@import Cocoa ;
@import WebKit ;

@import LuaSkin ;

#if __clang_major__ < 8
#import "xcode7.h"
#endif

static const char *USERDATA_TAG     = "hs._asm.enclosure.webview" ;
static const char *USERDATA_UCC_TAG = "hs._asm.enclosure.webview.usercontent" ;
static const char *USERDATA_DS_TAG  = "hs._asm.enclosure.webview.datastore" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

@interface HSWebViewView : WKWebView <WKNavigationDelegate, WKUIDelegate>
@property int          navigationCallback ;
@property int          policyCallback ;
@property int          sslCallback ;
@property BOOL         allowNewWindows ;
@property BOOL         examineInvalidCertificates ;
@property BOOL         titleFollow ;
@property WKNavigation *trackingID ;
@end

@interface HSUserContentController : WKUserContentController <WKScriptMessageHandler>
@property NSString *name ;
@property int      userContentCallback ;
@property int      udRef ;
@end
