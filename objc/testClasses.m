/*

  This file contains a couple of classes used for testing during development.  It is not required for
  use of this module and will likely go away at some point since it just takes up space.

  However, it is a convenient place to create test cases for troubleshooting and isolating specific
  behaviors during development.  As such, it's a hodge-podge of whatever was needed at the time and
  doesn't really make much sense as an object per-se.

 */
@import Cocoa ;
@import Darwin.C.stdlib ;
@import Darwin.C.math ;


@interface OBJCTest : NSObject
@property BOOL    lastBool ;
@property int     lastInt ;
@property NSArray *wordList ;
@property NSRect  myRectangle ;
@end

@implementation OBJCTest
- (id)init {
    self = [super init] ;
    if (self) {
        NSString *string = [NSString stringWithContentsOfFile:@"/usr/share/dict/words"
                                                     encoding:NSASCIIStringEncoding
                                                        error:NULL] ;
        _wordList = [string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] ;
        _lastBool = NO ;
        _lastInt  = 1 ;
        _myRectangle = NSMakeRect(10.0, 12.0, 100.0, 120.0) ;
    }
    return self ;
}

- (BOOL)returnBool            { _lastBool = !_lastBool ; return _lastBool ; }
- (int) returnRandomInt       { return (int)arc4random() ; }
- (int) returnInt             { _lastInt++ ; return _lastInt ; }
- (const char *)returnCString { return [[_wordList objectAtIndex:arc4random()%[_wordList count]] UTF8String]; }
- (NSString *)returnNSString  { return  [_wordList objectAtIndex:arc4random()%[_wordList count]]; }
- (SEL)returnSelector         { return @selector(returnInt) ; }
- (float)returnFloat          { return (float)(atan(1)*4) ; }
- (double)returnDouble        { return (double)(atan(1)*4) ; }
@end

@interface OBJCTest2 : OBJCTest
@end

@implementation OBJCTest2
- (id)init {
    self = [super init] ;
    return self ;
}

- (const char *)returnCString { return "This is a test" ; }
@end
