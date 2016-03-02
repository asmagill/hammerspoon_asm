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

// a simple check to see if LuaSkinThread has been properly injected into LuaSkin; returns Bool
#define LST_isAvailable() ([LuaSkin respondsToSelector:@selector(thread)])

// a replacement for [LuaSkin shared] which will work whether LuaSkinThread has been loaded or not
#define LST_getLuaSkin() (LST_isAvailable() ? \
                             [LuaSkin performSelector:@selector(thread)] : [LuaSkin shared])

// a simple check to see if the specified skin is a LuaSkinThread object; returns Bool
#define LST_skinIsLuaSkinThread(skin) ((strcmp(object_getClassName(skin), "LuaSkinThread") == 0))

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


// Lua references are aften stored in variables in the core modules.  Most modules which use LuaSkin
// store a reference to a table where callback references are stored and this reference is traditionally
// saved in a local variable.  Other references can be stored this way as well (hs.drawing.color uses
// one to store a reference to the defined color lists).  The following two macros are designed to wrap
// these in a way that requires minimal changes to your module code and yet remain usable in both
// Hammerspoon and in `hs._asm.luathread` instances.


// This macro gets a reference that has been stored.  If the current skin is a LuaSkin instance, the
// value is returned from the specified variable.  If the current skin is a LuaSkinThread instance,
// the value stored for the label in the shared thread dictionary will be returned.
#define LST_getRefForLabel(skin, tag, label, variable) (LST_skinIsLuaSkinThread(skin) ? \
                                       [(LuaSkinThread *)skin getRefForLabel:label inModule:tag] : variable)


// This macro stores a reference in a manner that allows the same module to be used in both Hammerspoon
// and `hs._asm.luathread` instances simultaneously.  If the current skin is a LuaSkin instance, the
// reference is stored in the local variable specified.  If the skin is a LuaSkinThread instance, the
// value is stored with the specified label in the thread's share dictionary.
#define LST_setRefForLabel(skin, tag, label, variable, value) if (LST_skinIsLuaSkinThread(skin)) { \
            if (![(LuaSkinThread *)skin setRef:(value) forLabel:label inModule:tag]) { \
                [skin logError:[NSString stringWithFormat:@"unable to register %s in thread dictionary for %s", label, tag]] ; \
            } \
        } else { \
            variable = (value) ; \
        }


// This macro is for retrieving the refTable reference returned by LuaSkin when a userdata object is
// first registered with Lua.  It is a shortcut to LST_getRefForLabel using a predefined label expected
// within LuaSkinThread methods.
#define LST_getRefTable(skin, tag, variable) LST_getRefForLabel(skin, tag, "_refTable", variable)


// This macro is for storing the refTable reference returned by LuaSkin when a userdata object is
// first registered with Lua.  It is a shortcut to LST_setRefForLabel using a predefined label expected
// within LuaSkinThread methods.
#define LST_setRefTable(skin, tag, variable, value) LST_setRefForLabel(skin, tag, "_refTable", variable, value)


#pragma mark - LuaSkinThread class public interface

@interface LuaSkinThread : LuaSkin
+(id)thread ;

-(BOOL)setRef:(int)refNumber forLabel:(const char *)label inModule:(const char *)module ;
-(int)getRefForLabel:(const char *)label inModule:(const char *)module ;
@end

