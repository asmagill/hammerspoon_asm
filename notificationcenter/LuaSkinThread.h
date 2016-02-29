@import LuaSkin ;
#import <objc/runtime.h>

// Some helper macros to simplify module writing/converting for LuaSkinThread support
//
// Your modules still need modifying, but this simplifies some of the boilerplate code

#define LST_isAvailable() ([LuaSkin respondsToSelector:@selector(thread)])

#define LST_getLuaSkin() (LST_isAvailable() ? \
                             [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared])

#define LST_getRefTable(skin, tag, variable) ((strcmp(object_getClassName(skin), "LuaSkinThread") == 0) ? \
                                       [(LuaSkinThread *)skin getRefTableForModule:tag] : variable)

#define LST_getRefForLabel(skin, tag, label, variable) ((strcmp(object_getClassName(skin), "LuaSkinThread") == 0) ? \
                                       [(LuaSkinThread *)skin getRefForLabel:label inModule:tag] : variable)

#define LST_setRefTable(skin, tag, variable, value) if (strcmp(object_getClassName(skin), "LuaSkinThread") == 0) { \
            if (![(LuaSkinThread *)skin setRefTable:(value) forModule:tag]) { \
                [skin logError:[NSString stringWithFormat:@"unable to register refTable in thread dictionary for %s", tag]] ; \
            } \
        } else { \
            variable = (value) ; \
        }

#define LST_setRefForLabel(skin, tag, label, variable, value) if (strcmp(object_getClassName(skin), "LuaSkinThread") == 0) { \
            if (![(LuaSkinThread *)skin setRef:(value) forLabel:label inModule:tag]) { \
                [skin logError:[NSString stringWithFormat:@"unable to register refTable in thread dictionary for %s", tag]] ; \
            } \
        } else { \
            variable = (value) ; \
        }

@interface LuaSkinThread : LuaSkin
+(BOOL)inject ;
+(id)thread ;

-(BOOL)setRefTable:(int)refTable forModule:(const char *)module ;
-(BOOL)setRef:(int)refNumber forLabel:(const char *)label inModule:(const char *)module ;

-(int)getRefTableForModule:(const char *)module ;
-(int)getRefForLabel:(const char *)label inModule:(const char *)module ;

@end

