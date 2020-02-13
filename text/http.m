@import Foundation;
@import Cocoa;
@import Carbon;
@import LuaSkin;
@import WebKit;

/// === hs.text.http ===
///
/// Perform HTTP requests with hs.text objects
///
/// This submodule is a subet of the `hs.http` module modified to return `hs.text` objects for the response body of http requests. For http methods which allow submitting a body (e.g. POST), `hs.text` object may be used instead of lua strings as well.

#import "text.h"

static int refTable;
static NSMutableArray* delegates;

// Convert a response body to data we can send to Lua
static HSTextObject *responseBodyToId(NSHTTPURLResponse *httpResponse, NSData *bodyData) {
    NSString         *contentType = [httpResponse.allHeaderFields objectForKey:@"Content-Type"];
    HSTextObject     *response    = nil ;
    NSStringEncoding encoding     = 0 ;

    // if "text/..." guess, then use rawData as fallback type; otherwise use rawData
    if ([contentType hasPrefix:@"text/"]) {
        NSString *string   = nil ;
        BOOL     usedLossy = NO ;
        encoding  = [NSString stringEncodingForData:bodyData
                                    encodingOptions:@{
                                        NSStringEncodingDetectionAllowLossyKey  : @(NO),
                                        NSStringEncodingDetectionFromWindowsKey : @(YES)
                                    }
                                    convertedString:&string
                                usedLossyConversion:&usedLossy] ;
        if (!string) encoding = 0 ; // it probably will be anyways, but lets be specific
    }

    response = [[HSTextObject alloc] init:bodyData withEncoding:encoding] ;
    return response ;
}

// Store a created delegate so we can cancel it on garbage collection
static void store_delegate(HSTextHTTPDelegate* delegate) {
    [delegates addObject:delegate];
}

// Remove a delegate either if loading has finished or if it needs to be
// garbage collected. This unreferences the lua callback and sets the callback
// reference in the delegate to LUA_NOREF.
static void remove_delegate(__unused lua_State* L, HSTextHTTPDelegate* delegate) {
    LuaSkin *skin = [LuaSkin shared];

    [delegate.connection cancel];
    delegate.fn = [skin luaUnref:refTable ref:delegate.fn];
    [delegates removeObject:delegate];
}

// Implementation of the HSTextHTTPDelegate. If the property fn equals LUA_NOREF
// no lua operations will be performed in the callbacks
//
// From Apple: In rare cases, for example in the case of an HTTP load where the content type
// of the load data is multipart/x-mixed-replace, the delegate will receive more than one
// connection:didReceiveResponse: message. When this happens, discard (or process) all
// data previously delivered by connection:didReceiveData:, and prepare to handle the
// next part (which could potentially have a different MIME type).
@implementation HSTextHTTPDelegate
- (void)connection:(NSURLConnection * __unused)connection didReceiveResponse:(NSURLResponse *)response {
    [self.receivedData setLength:0];
    self.httpResponse = (NSHTTPURLResponse *)response;
}

- (void)connection:(NSURLConnection * __unused)connection didReceiveData:(NSData *)data {
    [self.receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection * __unused)connection {
    if (self.fn == LUA_NOREF) {
        return;
    }
    LuaSkin *skin = [LuaSkin shared];
    lua_State *L = skin.L;
    _lua_stackguard_entry(L);

    [skin pushLuaRef:refTable ref:self.fn];
    lua_pushinteger(L, (int)self.httpResponse.statusCode);
    [skin pushNSObject:responseBodyToId(self.httpResponse, self.receivedData)];
    [skin pushNSObject:self.httpResponse.allHeaderFields];
    [skin protectedCallAndError:@"hs.text.http connectionDelefate:didFinishLoading" nargs:3 nresults:0];

    remove_delegate(L, self);
    _lua_stackguard_exit(L);
}

- (void)connection:(NSURLConnection * __unused)connection didFailWithError:(NSError *)error {
    if (self.fn == LUA_NOREF){
        return;
    }
    LuaSkin *skin = [LuaSkin shared];
    _lua_stackguard_entry(skin.L);

    NSString* errorMessage = [NSString stringWithFormat:@"Connection failed: %@ - %@", [error localizedDescription], [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]];
    [skin pushLuaRef:refTable ref:self.fn];
    lua_pushinteger(self.L, -1);
    [skin pushNSObject:errorMessage];
    [skin protectedCallAndError:@"hs.text.http HSTextHTTPDelegate:didFailWithError" nargs:2 nresults:0];
    remove_delegate(self.L, self);
    _lua_stackguard_exit(skin.L);
}

@end

// If the user specified a request body, get it from stack,
// add it to the request and add the content length header field
static void getBodyFromStack(lua_State* L, int index, NSMutableURLRequest* request){
    if (!lua_isnoneornil(L, index)) {
        LuaSkin *skin = [LuaSkin shared] ;
        NSData *postData ;
        if (lua_type(L, index) == LUA_TSTRING) {
            postData = [skin toNSObjectAtIndex:index withOptions:LS_NSLuaStringAsDataOnly] ;
        } else if (lua_type(L, index) == LUA_TUSERDATA && luaL_testudata(L, index, USERDATA_TAG)) {
            HSTextObject *object = [skin toNSObjectAtIndex:index] ;
            postData = object.contents ;
        } else {
            NSString* body = [NSString stringWithCString:lua_tostring(L, index) encoding:NSASCIIStringEncoding];
            postData = [body dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        }
        if (postData) {
            NSString *postLength = [NSString stringWithFormat:@"%lu", [postData length]];
            [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
            [request setHTTPBody:postData];
        } else {
            [LuaSkin logError:[NSString stringWithFormat:@"%s - getBodyFromStack - non-nil entry at stack index %u but unable to convert to NSData", HTTP_UD_TAG, index]] ;
        }
    }
}

// Gets all information for the request from the stack and creates a request
static NSMutableURLRequest* getRequestFromStack(__unused lua_State* L, NSString* cachePolicy){
    LuaSkin *skin = [LuaSkin shared];
    NSString* url = [skin toNSObjectAtIndex:1];
    NSString* method = [skin toNSObjectAtIndex:2];

    NSUInteger selectedCachePolicy;
    if ([cachePolicy isEqualToString:@"protocolCachePolicy"]) {
        selectedCachePolicy = NSURLRequestUseProtocolCachePolicy;
    } else if ([cachePolicy isEqualToString:@"ignoreLocalCache"]) {
        selectedCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    } else if ([cachePolicy isEqualToString:@"ignoreLocalAndRemoteCache"]) {
        selectedCachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
    } else if ([cachePolicy isEqualToString:@"returnCacheOrLoad"]) {
        selectedCachePolicy = NSURLRequestReturnCacheDataElseLoad;
    } else if ([cachePolicy isEqualToString:@"returnCacheDontLoad"]) {
        selectedCachePolicy = NSURLRequestReturnCacheDataDontLoad;
    } else if ([cachePolicy isEqualToString:@"reloadRevalidatingCache"]) {
        selectedCachePolicy = NSURLRequestReloadRevalidatingCacheData;
    } else {
        selectedCachePolicy = NSURLRequestUseProtocolCachePolicy;
    }

    NSMutableURLRequest *request;
    NSURL *theURL = [NSURL URLWithString:url] ;

    request = [NSMutableURLRequest requestWithURL:theURL
                                      cachePolicy: selectedCachePolicy
                                  timeoutInterval: 60.00];
    [request setHTTPMethod:method];
    return request;
}

// Gets the table for the headers from stack and adds the key value pairs to the request object
static void extractHeadersFromStack(lua_State* L, int index, NSMutableURLRequest* request){
    if (!lua_isnoneornil(L, index)) {
        lua_pushnil(L);
        while (lua_next(L, index) != 0) {
            // TODO check key and value for string type
            NSString* key = [NSString stringWithCString:luaL_checkstring(L, -2) encoding:NSASCIIStringEncoding];
            NSString* value = [NSString stringWithCString:luaL_checkstring(L, -1) encoding:NSASCIIStringEncoding];

            [request setValue:value forHTTPHeaderField:key];

            lua_pop(L, 1);
        }
    }
}

/// hs.text.http.doAsyncRequest(url, method, data, headers, callback, [cachePolicy])
/// Function
/// Creates an HTTP request and executes it asynchronously
///
/// Parameters:
///  * `url`         - A string containing the URL
///  * `method`      - A string containing the HTTP method to use (e.g. "GET", "POST", etc)
///  * `data`        - A string or `hs.text` object containing the request body, or nil to send no body
///  * `headers`     - A table containing string keys and values representing request header keys and values, or nil to add no headers
///  * `callback`    - A function to called when the response is received. The function should accept three arguments:
///   * `code`    - A number containing the HTTP response code
///   * `body`    - An `hs.text` object containing the body of the response
///   * `headers` - A table containing the HTTP headers of the response
///  * `cachePolicy` - An optional string containing the cache policy ("protocolCachePolicy", "ignoreLocalCache", "ignoreLocalAndRemoteCache", "returnCacheOrLoad", "returnCacheDontLoad" or "reloadRevalidatingCache"). Defaults to `protocolCachePolicy`.
///
/// Returns:
///  * None
///
/// Notes:
///  * If authentication is required in order to download the request, the required credentials must be specified as part of the URL (e.g. "http://user:password@host.com/"). If authentication fails, or credentials are missing, the connection will attempt to continue without credentials.
///  * If the Content-Type response header begins `text/` then the response body return value is a UTF8 string. Any other content type passes the response body, unaltered, as a stream of bytes.
static int http_doAsyncRequest(lua_State* L){
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TANY, LS_TTABLE|LS_TNIL, LS_TFUNCTION, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];

    NSString* cachePolicy = [skin toNSObjectAtIndex:6];

    NSMutableURLRequest* request = getRequestFromStack(L, cachePolicy);
    getBodyFromStack(L, 3, request);
    extractHeadersFromStack(L, 4, request);

//     luaL_checktype(L, 5, LUA_TFUNCTION); // checkArgs does this and also supports tables with __call metamethod
    lua_pushvalue(L, 5);

    HSTextHTTPDelegate* delegate = [[HSTextHTTPDelegate alloc] init];
    delegate.L = L;
    delegate.receivedData = [[NSMutableData alloc] init];
    delegate.fn = [skin luaRef:refTable];

    store_delegate(delegate);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSURLConnection* connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
#pragma clang diagnostic pop

    delegate.connection = connection;

    return 0;
}

/// hs.text.http.doRequest(url, method, [data, headers, cachePolicy]) -> int, textObject, table
/// Function
/// Creates an HTTP request and executes it synchronously
///
/// Parameters:
///  * `url`         - A string containing the URL
///  * `method`      - A string containing the HTTP method to use (e.g. "GET", "POST", etc)
///  * `data`        - An optional string or `hs.text` object containing the data to POST to the URL, or nil to send no data
///  * `headers`     - An optional table of string keys and values used as headers for the request, or nil to add no headers
///  * `cachePolicy` - An optional string containing the cache policy ("protocolCachePolicy", "ignoreLocalCache", "ignoreLocalAndRemoteCache", "returnCacheOrLoad", "returnCacheDontLoad" or "reloadRevalidatingCache"). Defaults to `protocolCachePolicy`.
///
/// Returns:
///  * A number containing the HTTP response status code
///  * An `hs.text` object containing the response body
///  * A table containing the response headers
///
/// Notes:
///  * If authentication is required in order to download the request, the required credentials must be specified as part of the URL (e.g. "http://user:password@host.com/"). If authentication fails, or credentials are missing, the connection will attempt to continue without credentials.
///
///  * This function is synchronous and will therefore block all Lua execution until it completes. You are encouraged to use the asynchronous functions.
///  * If you attempt to connect to a local Hammerspoon server created with `hs.httpserver`, then Hammerspoon will block until the connection times out (60 seconds), return a failed result due to the timeout, and then the `hs.httpserver` callback function will be invoked (so any side effects of the function will occur, but it's results will be lost).  Use [hs.text.http.doAsyncRequest](#doAsyncRequest) to avoid this.
///  * If the Content-Type response header begins `text/` then the response body return value is a UTF8 string. Any other content type passes the response body, unaltered, as a stream of bytes.
static int http_doRequest(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TANY|LS_TOPTIONAL, LS_TTABLE|LS_TNIL|LS_TOPTIONAL, LS_TSTRING|LS_TOPTIONAL, LS_TBREAK];

    NSString* cachePolicy = [skin toNSObjectAtIndex:5];

    NSMutableURLRequest *request = getRequestFromStack(L, cachePolicy);
    getBodyFromStack(L, 3, request);
    extractHeadersFromStack(L, 4, request);

    NSData *dataReply;
    NSURLResponse *response;
    NSError *error;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    dataReply = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
#pragma clang diagnostic pop

    NSHTTPURLResponse *httpResponse;
    httpResponse = (NSHTTPURLResponse *)response;

    lua_pushinteger(L, (int)httpResponse.statusCode);
    [skin pushNSObject:responseBodyToId(httpResponse, dataReply)];
    [skin pushNSObject:httpResponse.allHeaderFields];

    return 3;
}

static int http_gc(lua_State* L){
    NSMutableArray* delegatesCopy = [[NSMutableArray alloc] init];
    [delegatesCopy addObjectsFromArray:delegates];

    for (HSTextHTTPDelegate* delegate in delegatesCopy){
        remove_delegate(L, delegate);
    }

    return 0;
}

static const luaL_Reg httplib[] = {
    {"doRequest",       http_doRequest},
    {"doAsyncRequest",  http_doAsyncRequest},

    {NULL, NULL} // This must end with an empty struct
};

static const luaL_Reg metalib[] = {
    {"__gc", http_gc},

    {NULL, NULL} // This must end with an empty struct
};

int luaopen_hs_text_http(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared];

    delegates = [[NSMutableArray alloc] init];
    refTable = [skin registerLibrary:httplib metaFunctions:metalib];

    return 1;
}
