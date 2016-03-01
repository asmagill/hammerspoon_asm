/*

    Public Interface to LuaSkinThread sub-class of LuaSkin

    Creates a LuaSkin subclass which can be unique per thread

    This is not quite a drop-in replacement for LuaSkin in modules which use LuaSkin...

    At a minimum, all references to [LuaSkin shared] need to be replaced with
        [LuaSkin performSelector:@selector(thread)].

    If you wish for a module to work in more than one luathread instance at the same time,
        or if you wish for your module to work in both Hammerspoon and `hs._asm.luathread`
        without requiring a separate compiled version, you should also store refTable
        values in the thread dictionary using the macros defined below.

    Modules will also need additional changes if they dispatch blocks to the main queue or
        explicitly call selectors on the main thread... some examples of changes that work
        can be found in the modules/ sub-directory of the luathread repository

    An example of a third-party module which is written to be compatible with both core
        Hammerspoon and luathreads can be seen in `hs._asm.notificationcenter`, located
        in the repository at https://github.com/asmagill/hammerspoon_asm.

*/

@import LuaSkin ;
#import <objc/runtime.h>

#pragma mark - Helper Macros to aid in integrating with Hammerspoon module code
// Your modules still need modifying, but this simplifies some of the boilerplate code

// a simple check to see if LuaSkinThread has been properly injected into LuaSkin, returns Bool
#define LST_isAvailable() ([LuaSkin respondsToSelector:@selector(thread)])

// a replacement for [LuaSkin shared] which will work whether LuaSkinThread has been loaded or not
#define LST_getLuaSkin() (LST_isAvailable() ? \
                             [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared])

// For the following macros, the arguments are defined as follows:
//    skin     - the LuaSkin or LuaSkinThread value in use for the module in this particular instance.
//               Often, this will be simply `LST_getLuaSkin()` or its value stored in a local variable.
//    tag      - a tag identifying the specific module.  Most modules in the core use a variable of
//               type (const char *) or macro definition with the label `USERDATA_TAG` and it is usually
//               simplest for this argument to take that value.
//    label    - when storing or retrieving a reference for something other then the module's refTable,
//               this is a c-string (const char *) containing the label to use when accessing the
//               value in a LuaSkinThread's thread dictionary.  By convention, this is usually the same
//               as the variable name (but in quotes so it is a c-string)
//    variable - the variable name of the int which should be assigned-to/read-from when the skin is
//               a traditional LuaSkin instance.
//    value    - when storing a reference value, this is the int value to store.

// LuaSkin uses individual reference tables (usually stored in a module's global space as the integer
// "luaRef" in the core modules) for each module rather than LUA_REGISTRYINDEX.  This macro will
// return the value in the specified variable, if the current skin is LuaSkin, or check for the
// stored value in the thread dictionary, if the current skin is a LuaSkinThread.
#define LST_getRefTable(skin, tag, variable) ((strcmp(object_getClassName(skin), "LuaSkinThread") == 0) ? \
                                       [(LuaSkinThread *)skin getRefForLabel:"_refTable" inModule:tag] : variable)

// LuaSkin uses individual reference tables (usually stored in a module's global space as the integer
// "luaRef" in the core modules) for each module rather than LUA_REGISTRYINDEX.  This macro will
// set the value for the reference table in the specified variable, if the current skin is LuaSkin, or
// set it in the thread dictionary, if the current skin is a LuaSkinThread.
#define LST_setRefTable(skin, tag, variable, value) if (strcmp(object_getClassName(skin), "LuaSkinThread") == 0) { \
            if (![(LuaSkinThread *)skin setRef:(value) forLabel:"_refTable" inModule:tag]) { \
                [skin logError:[NSString stringWithFormat:@"unable to register refTable in thread dictionary for %s", tag]] ; \
            } \
        } else { \
            variable = (value) ; \
        }

// Other references are sometimes stored in variables in the core modules (hs.drawing.color uses one
// to store a reference to the defined color lists).  This macro is a more generic version of the
// LST_getRefTable that also allows for a label to be specified.  If skin == LuaSkin, the specified
// variable will be returned; if skin == LuaSkinThread, the specified label name will be looked up in
// the stored references in the thread's dictionary.
#define LST_getRefForLabel(skin, tag, label, variable) ((strcmp(object_getClassName(skin), "LuaSkinThread") == 0) ? \
                                       [(LuaSkinThread *)skin getRefForLabel:label inModule:tag] : variable)

// A more generic version of LST_setRefTable which lets you set the label used in the thread dictionary
// for the reference to be stored.
#define LST_setRefForLabel(skin, tag, label, variable, value) if (strcmp(object_getClassName(skin), "LuaSkinThread") == 0) { \
            if (![(LuaSkinThread *)skin setRef:(value) forLabel:label inModule:tag]) { \
                [skin logError:[NSString stringWithFormat:@"unable to register %s in thread dictionary for %s", label, tag]] ; \
            } \
        } else { \
            variable = (value) ; \
        }

#pragma mark - LuaSkinThread class public interface

@interface LuaSkinThread : LuaSkin
+(id)thread ;

-(BOOL)setRef:(int)refNumber forLabel:(const char *)label inModule:(const char *)module ;
-(int)getRefForLabel:(const char *)label inModule:(const char *)module ;
@end

