#pragma once

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static const char * const USERDATA_TAG = "hs.text" ;
static const char * const UTF16_UD_TAG = "hs.text.utf16" ;
static const char * const HTTP_UD_TAG  = "hs.text.http" ;

extern int luaopen_hs_text_utf16(lua_State *L) ;
extern int luaopen_hs_text_http(lua_State *L) ;

@interface HSTextObject : NSObject
@property NSData           *contents ;
@property int              selfRef ;
@property int              selfRefCount ;
@property NSStringEncoding encoding ;

- (instancetype)init:(NSData *)data withEncoding:(NSStringEncoding)encoding ;
@end

@interface HSTextUTF16Object : NSObject
@property NSString *utf16string ;
@property int      selfRef ;
@property int      selfRefCount ;

- (instancetype)initWithString:(NSString *)string ;
@end

// Definition of the collection delegate to receive callbacks from NSUrlConnection
@interface HSTextHTTPDelegate : NSObject<NSURLConnectionDelegate, NSURLConnectionDataDelegate>
@property lua_State* L;
@property int fn;
@property(nonatomic, retain) NSMutableData* receivedData;
@property(nonatomic, retain) NSHTTPURLResponse* httpResponse;
@property(nonatomic, retain) NSURLConnection* connection;

- (void)connection:(NSURLConnection * __unused)connection didReceiveResponse:(NSURLResponse *)response ;
- (void)connection:(NSURLConnection * __unused)connection didReceiveData:(NSData *)data ;
- (void)connectionDidFinishLoading:(NSURLConnection * __unused)connection ;
- (void)connection:(NSURLConnection * __unused)connection didFailWithError:(NSError *)error ;
@end
