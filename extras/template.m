#import <Cocoa/Cocoa.h>
#import <lauxlib.h>

#import <sys/sysctl.h>
#import <mach/host_info.h>
#import <mach/mach_host.h>
#import <mach/task_info.h>
#import <mach/task.h>

// Print a C string to the Hammerspoon console as an error
void showError(lua_State *L, char *message) {
    lua_getglobal(L, "hs");
    lua_getfield(L, -1, "showError");
    lua_remove(L, -2);
    lua_pushstring(L, message);
    lua_pcall(L, 1, 0, 0);
}

/// {PATH}.{MODULE}.showAbout()
/// Function
/// Displays the standard OS X about panel; implicitly focuses {TARGET}.
static int showabout(lua_State* __unused L) {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:nil];
    return 0;
}

/// {PATH}.{MODULE}.fileExists(path) -> exists, isdir
/// Function
/// Checks if a file exists, and whether it's a directory.
static int fileexists(lua_State* L) {
    NSString* path = [NSString stringWithUTF8String:luaL_checkstring(L, 1)];

    BOOL isdir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isdir];

    lua_pushboolean(L, exists);
    lua_pushboolean(L, isdir);
    return 2;
}

/// {PATH}.{MODULE}._version
/// Variable
/// The current {TARGET} version as a string.
static int version(lua_State* L) {
    NSString* ver = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    lua_pushstring(L, [ver UTF8String]);
    return 1;
}

/// {PATH}.{MODULE}._paths[]
/// Variable
/// A table containing the resourcePath, the bundlePath, and the executablePath for the {TARGET} application.
static int paths(lua_State* L) {
    lua_newtable(L) ;
        lua_pushstring(L, [[[NSBundle mainBundle] resourcePath] fileSystemRepresentation]);
        lua_setfield(L, -2, "resourcePath");
        lua_pushstring(L, [[[NSBundle mainBundle] bundlePath] fileSystemRepresentation]);
        lua_setfield(L, -2, "bundlePath");
        lua_pushstring(L, [[[NSBundle mainBundle] executablePath] fileSystemRepresentation]);
        lua_setfield(L, -2, "executablePath");

    return 1;
}

/// {PATH}.{MODULE}.uuid() -> string
/// Function
/// Returns a newly generated UUID as a string
static int uuid(lua_State* L) {
    lua_pushstring(L, [[[NSUUID UUID] UUIDString] UTF8String]);
    return 1;
}

/// {PATH}.{MODULE}.accessibility(shouldprompt) -> isenabled
/// Function
/// Returns whether accessibility is enabled. If passed `true`, prompts the user to enable it.
static int accessibility(lua_State* L) {
    extern BOOL MJAccessibilityIsEnabled(void);
    extern void MJAccessibilityOpenPanel(void);

    BOOL shouldprompt = lua_toboolean(L, 1);
    BOOL enabled = MJAccessibilityIsEnabled();
    if (shouldprompt) { MJAccessibilityOpenPanel(); }
    lua_pushboolean(L, enabled);
    return 1;
}

/// {PATH}.{MODULE}.autoLaunch([arg]) -> bool
/// Function
///  When argument is absent or not a boolean value, this function returns true or false indicating whether or not {TARGET} is set to launch when you first log in.  When a boolean argument is provided, it's true or false value is used to set the auto-launch status.
static int autolaunch(lua_State* L) {
    extern BOOL MJAutoLaunchGet(void);
    extern void MJAutoLaunchSet(BOOL opensAtLogin);

    if (lua_isboolean(L, -1)) { MJAutoLaunchSet(lua_toboolean(L, -1)); }
    lua_pushboolean(L, MJAutoLaunchGet()) ;
    return 1;

}

// The following two functions will go away someday (soon I hope) and be found in the core
// app of hammerspoon because they are just so darned useful in so many contexts... but they
// have serious limitations as well, and I need to work to clear those... it's an absolute
// requirement for this module, and the way this module is being used *shouldn't* trip the
// issues unless someone absolutely tries to screw them up... and all it does is
// crash Hammerspoon when it happens, so...

static id lua_to_NSObject(lua_State* L, int idx) {
    idx = lua_absindex(L,idx);
    switch (lua_type(L, idx)) {
        case LUA_TNUMBER: return @(lua_tonumber(L, idx));
        case LUA_TSTRING: return [NSString stringWithUTF8String: lua_tostring(L, idx)];
        case LUA_TNIL: return [NSNull null];
        case LUA_TBOOLEAN: return lua_toboolean(L, idx) ? (id)kCFBooleanTrue : (id)kCFBooleanFalse;
        case LUA_TTABLE: {
            NSMutableDictionary* numerics    = [NSMutableDictionary dictionary];
            NSMutableDictionary* nonNumerics = [NSMutableDictionary dictionary];
            NSMutableIndexSet*   numericKeys = [NSMutableIndexSet indexSet];
            NSMutableArray*      numberArray = [NSMutableArray array];
            lua_pushnil(L);
            while (lua_next(L, idx) != 0) {
                id key = lua_to_NSObject(L, -2);
                id val = lua_to_NSObject(L, lua_gettop(L));
                if ([key isKindOfClass: [NSNumber class]]) {
                    [numericKeys addIndex:[key intValue]];
                    [numerics setValue:val forKey:key];
                } else {
                    [nonNumerics setValue:val forKey:key];
                }
                lua_pop(L, 1);
            }
            if (numerics.count > 0) {
                for (unsigned long i = 1; i <= [numericKeys lastIndex]; i++) {
                    [numberArray addObject:(
                        [numerics objectForKey:[NSNumber numberWithInteger:i]] ?
                            [numerics objectForKey:[NSNumber numberWithInteger:i]] : [NSNull null]
                    )];
                }
                if (nonNumerics.count == 0)
                    return [numberArray copy];
            } else {
                return [nonNumerics copy];
            }
            NSMutableDictionary* unionBlob = [NSMutableDictionary dictionary];
            [unionBlob setValue:[NSArray arrayWithObjects:numberArray, nonNumerics, nil] forKey:@"MJ_LUA_TABLE"];
            return [unionBlob copy];
        }
        default: { lua_pushliteral(L, "non-serializable object"); lua_error(L); }
    }
    return nil;
}

// static void NSObject_to_lua(lua_State* L, id obj) {
//     if (obj == nil || [obj isEqual: [NSNull null]]) { lua_pushnil(L); }
//     else if ([obj isKindOfClass: [NSDictionary class]]) {
//         BOOL handled = NO;
//         if ([obj count] == 1) {
//             if ([obj objectForKey:@"MJ_LUA_NIL"]) {
//                 lua_pushnil(L);
//                 handled = YES;
//             } else
//             if ([obj objectForKey:@"MJ_LUA_TABLE"]) {
//                 NSArray* parts = [obj objectForKey:@"MJ_LUA_TABLE"] ;
//                 NSArray* numerics = [parts objectAtIndex:0] ;
//                 NSDictionary* nonNumerics = [parts objectAtIndex:1] ;
//                 lua_newtable(L);
//                 int i = 0;
//                 for (id item in numerics) {
//                     NSObject_to_lua(L, item);
//                     lua_rawseti(L, -2, ++i);
//                 }
//                 NSArray *keys = [nonNumerics allKeys];
//                 NSArray *values = [nonNumerics allValues];
//                 for (unsigned long i = 0; i < keys.count; i++) {
//                     NSObject_to_lua(L, [keys objectAtIndex:i]);
//                     NSObject_to_lua(L, [values objectAtIndex:i]);
//                     lua_settable(L, -3);
//                 }
//                 handled = YES;
//             }
//         }
//         if (!handled) {
//             NSArray *keys = [obj allKeys];
//             NSArray *values = [obj allValues];
//             lua_newtable(L);
//             for (unsigned long i = 0; i < keys.count; i++) {
//                 NSObject_to_lua(L, [keys objectAtIndex:i]);
//                 NSObject_to_lua(L, [values objectAtIndex:i]);
//                 lua_settable(L, -3);
//             }
//         }
//     } else if ([obj isKindOfClass: [NSNumber class]]) {
//         NSNumber* number = obj;
//         if (number == (id)kCFBooleanTrue)
//             lua_pushboolean(L, YES);
//         else if (number == (id)kCFBooleanFalse)
//             lua_pushboolean(L, NO);
//         else
//             lua_pushnumber(L, [number doubleValue]);
//     } else if ([obj isKindOfClass: [NSString class]]) {
//         NSString* string = obj;
//         lua_pushstring(L, [string UTF8String]);
//     } else if ([obj isKindOfClass: [NSArray class]]) {
//         int i = 0;
//         NSArray* list = obj;
//         lua_newtable(L);
//         for (id item in list) {
//             NSObject_to_lua(L, item);
//             lua_rawseti(L, -2, ++i);
//         }
//     } else if ([obj isKindOfClass: [NSDate class]]) {
//         lua_pushnumber(L, [(NSDate *) obj timeIntervalSince1970]);
//     } else if ([obj isKindOfClass: [NSData class]]) {
//         lua_pushlstring(L, [obj bytes], [obj length]) ;
//     } else {
//         lua_pushstring(L, [[NSString stringWithFormat:@"<Object> : %@", obj] UTF8String]) ;
//     }
// }

/// {PATH}.{MODULE}.NSLog(luavalue)
/// Function
/// Send a representation of the lua value passed in to the Console application via NSLog.
static int extras_nslog(lua_State* L) {
    id val = lua_to_NSObject(L, 1);
    NSLog(@"%@", val);
    return 0;
}

/// {PATH}.{MODULE}.userDataToString(userdata) -> string
/// Function
/// Returns the userdata object as a binary string. Usually userdata is pretty boring -- containing c pointers, etc.  However, for some of the more complex userdata blobs for callbacks and such this can be useful with {PATH}.{MODULE}.hexdump for debugging to see what parts of the structure are actually getting set, etc.
static int ud_tostring (lua_State *L) {
    void *data = lua_touserdata(L,1);
    int sz;
    if (data == NULL) {
        lua_pushnil(L);
        lua_pushstring(L,"not a userdata type");
        return 2;
    } else {
        sz = lua_rawlen(L,1);
        lua_pushlstring(L,data,sz);
        return 1;
    }
}

/// {PATH}.{MODULE}.listFonts() -> table
/// Function
/// Returns the names of the installed fonts for this system.
static int listFonts(lua_State *L) {
    NSArray *fontNames = [[NSFontManager sharedFontManager] availableFonts];

    lua_newtable(L) ;
    for (unsigned long indFont=0; indFont<[fontNames count]; ++indFont)
    {
        lua_pushstring(L, [[fontNames objectAtIndex:indFont] UTF8String]) ; lua_rawseti(L, -2, indFont + 1);
    }
    return 1 ;
}


// struct vm_statistics64 {
//     natural_t   free_count;         /* # of pages free */
//     natural_t   active_count;       /* # of pages active */
//     natural_t   inactive_count;     /* # of pages inactive */
//     natural_t   wire_count;         /* # of pages wired down */
//     uint64_t    zero_fill_count;    /* # of zero fill pages */
//     uint64_t    reactivations;      /* # of pages reactivated */
//     uint64_t    pageins;            /* # of pageins */
//     uint64_t    pageouts;           /* # of pageouts */
//     uint64_t    faults;             /* # of faults */
//     uint64_t    cow_faults;         /* # of copy-on-writes */
//     uint64_t    lookups;            /* object cache lookups */
//     uint64_t    hits;               /* object cache hits */
//
//     /* added for rev1 */
//     uint64_t    purges;             /* # of pages purged */
//     natural_t   purgeable_count;    /* # of pages purgeable */
//
//     /* added for rev2 */
//     /*
//      * NB: speculative pages are already accounted for in "free_count",
//      * so "speculative_count" is the number of "free" pages that are
//      * used to hold data that was read speculatively from disk but
//      * haven't actually been used by anyone so far.
//      */
//     natural_t   speculative_count;  /* # of pages speculative */
//
// }

/// {PATH}.{MODULE}.memoryInfo() -> table
/// Function
/// Returns an array containing memory information for this system.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the following keys:
///    * activePages      -- number of active pages
///    * cacheHits        -- number of cache hits
///    * cacheLookups     -- number of cache lookups
///    * cow              -- number of copy-on-writes
///    * faults           -- number of "Translation faults"
///    * freePages        -- number of free pages
///    * inactivePages    -- number of inactive pages
///    * pageIns          -- number of pageins
///    * pageOuts         -- number of pageouts
///    * purgeablePages   -- number of purgeable pages
///    * purgedPages      -- number of purged pages
///    * reactivatedPages -- number of reactivated pages
///    * speculativePages -- number of speculative pages
///    * wiredPages       -- number of wired down pages
///    * zeroFillPages    -- number of zero fill pages
///    * memSize          -- physical memory size in bytes
///    * pageSize         -- page size in bytes
///    * totalPages       -- shortcut for active + inactive + free + wired
///
/// Notes:
///  * Adapted from code sample shared at http://stackoverflow.com/questions/6094444/how-can-i-programmatically-check-free-system-memory-on-mac-like-the-activity-mon
static int memoryInfo(lua_State *L) {
    int mib[6];
    mib[0] = CTL_HW; mib[1] = HW_PAGESIZE;

    unsigned int pagesize;
    size_t length;
    length = sizeof (pagesize);
    if (sysctl (mib, 2, &pagesize, &length, NULL, 0) < 0) {
        char errStr[255] ;
        snprintf(errStr, 255, "Error getting page size (%d): %s", errno, strerror(errno)) ;
        showError(L, errStr) ;
        return 0 ;
    }

    mib[0] = CTL_HW; mib[1] = HW_MEMSIZE;
    unsigned long memsize;
    length = sizeof (memsize);
    if (sysctl (mib, 2, &memsize, &length, NULL, 0) < 0) {
        char errStr[255] ;
        snprintf(errStr, 255, "Error getting mem size (%d): %s", errno, strerror(errno)) ;
        showError(L, errStr) ;
        return 0 ;
    }


    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;

    vm_statistics64_data_t vmstat;
    kern_return_t retVal = host_statistics64 (mach_host_self (), HOST_VM_INFO64, (host_info_t) &vmstat, &count);

    if (retVal != KERN_SUCCESS) {
        char errStr[255] ;
        snprintf(errStr, 255, "Error getting VM Statistics: %s", mach_error_string(retVal)) ;
        showError(L, errStr) ;
        return 0 ;
    }

    unsigned long total = vmstat.wire_count + vmstat.active_count + vmstat.inactive_count + vmstat.free_count;
// Can be done in lua if desired
//     double wired = vmstat.wire_count / total;
//     double active = vmstat.active_count / total;
//     double inactive = vmstat.inactive_count / total;
//     double free = vmstat.free_count / total;
//
//Really begs for a more generic "resident size of applicationObject" method
//     task_basic_info_64_data_t info;
//     unsigned size = sizeof (info);
//     task_info (mach_task_self (), TASK_BASIC_INFO_64, (task_info_t) &info, &size);
//
//     double unit = 1024 * 1024;
//     memLabel.text = [NSString stringWithFormat: @"% 3.1f MB\n% 3.1f MB\n% 3.1f MB",
//         vmstat.free_count * pagesize / unit,
//         (vmstat.free_count + vmstat.inactive_count) * pagesize / unit,
//         info.resident_size / unit];

    lua_newtable(L) ;
        lua_pushnumber(L, total)                    ; lua_setfield(L, -2, "totalPages") ;
        lua_pushnumber(L, vmstat.free_count)        ; lua_setfield(L, -2, "freePages") ;
        lua_pushnumber(L, vmstat.active_count)      ; lua_setfield(L, -2, "activePages") ;
        lua_pushnumber(L, vmstat.inactive_count)    ; lua_setfield(L, -2, "inactivePages") ;
        lua_pushnumber(L, vmstat.wire_count)        ; lua_setfield(L, -2, "wiredPages") ;
        lua_pushnumber(L, vmstat.zero_fill_count)   ; lua_setfield(L, -2, "zeroFillPages") ;
        lua_pushnumber(L, vmstat.reactivations)     ; lua_setfield(L, -2, "reactivatedPages") ;
        lua_pushnumber(L, vmstat.pageins)           ; lua_setfield(L, -2, "pageIns") ;
        lua_pushnumber(L, vmstat.pageouts)          ; lua_setfield(L, -2, "pageOuts") ;
        lua_pushnumber(L, vmstat.faults)            ; lua_setfield(L, -2, "faults") ;
        lua_pushnumber(L, vmstat.cow_faults)        ; lua_setfield(L, -2, "cow") ;
        lua_pushnumber(L, vmstat.lookups)           ; lua_setfield(L, -2, "cacheLookups") ;
        lua_pushnumber(L, vmstat.hits);             ; lua_setfield(L, -2, "cacheHits") ;
        lua_pushnumber(L, vmstat.purges)            ; lua_setfield(L, -2, "purgedPages") ;
        lua_pushnumber(L, vmstat.purgeable_count)   ; lua_setfield(L, -2, "purgeablePages") ;
        lua_pushnumber(L, vmstat.speculative_count) ; lua_setfield(L, -2, "speculativePages") ;
        lua_pushnumber(L, memsize)                  ; lua_setfield(L, -2, "memSize") ;

    return 1 ;
}

// // // // // BEGIN: hs.application candidate

// // Turning into more of a AXUIElement browser... how does this affect plans for uielement?
// // Must ponder and maybe ask, once the code to retrieve all attributes is added...

// // May eventually go into hs.application with the rest of menu commands... Or not... but
// // isolate relevant code for simplicity later

#define get_app(L, idx) *((AXUIElementRef*)luaL_checkudata(L, idx, "hs.application"))

// // use "open -th AXError" to get reference for AXError numbers... too cumbersome and
// // (hopefully) unlikely/unimportant to bother dereferencing within HS...

// // Indent titles in log to get a sense of hierarchy
// static int depth = -1 ;

// Internal helper function for getMenuArray
static void _buildMenuArray(lua_State* L, AXUIElementRef app, AXUIElementRef menuItem) {

// depth++ ; // NSLog(@"Another recursion") ;

    CFTypeRef cf_title ; NSString* title ;
    AXError error = AXUIElementCopyAttributeValue(menuItem, kAXTitleAttribute, &cf_title);
    if (error == kAXErrorAttributeUnsupported) {
        title = @"-- title unsupported --" ; // Special case, mostly for wrapper objects
    } else if (error) {
        NSLog(@"AXTitleAttribute Error: AXError %d", error) ;
        title = [NSString stringWithFormat:@"-- title error: AXError %d --", error] ;
    } else {
        title = (__bridge_transfer NSString *)cf_title;
    }
    lua_pushstring(L, [title UTF8String]) ; lua_setfield(L, -2, "title") ;

    CFIndex count = -1;
    error = AXUIElementGetAttributeValueCount(menuItem, kAXChildrenAttribute, &count);
    if (error) {
        NSLog(@"Unable to get children count for %@: AXError %d", title, error) ;
        lua_pushfstring(L, "unable to get child count: AXError %d", error) ; lua_setfield(L, -2, "error") ;
        count = -1 ; // just to make sure it didn't get some funky value
    }

// NSLog(@"%*sTitle: %@ (%ld)", depth * 2, "", title, count) ;

    if (count > 0) {
        CFArrayRef cf_children;
        error = AXUIElementCopyAttributeValues(menuItem, kAXChildrenAttribute, 0, count, &cf_children);
        if (error) {
            NSLog(@"Unable to get children for %@: AXError %d", title, error) ;
            lua_pushfstring(L, "unable to get children: AXError %d", error) ; lua_setfield(L, -2, "error") ;
        } else {
            NSMutableArray *toCheck = [[NSMutableArray alloc] init];
            [toCheck addObjectsFromArray:(__bridge NSArray *)cf_children];

            lua_newtable(L) ;
            for(unsigned int i = 0 ; i < [toCheck count] ; i++) {
                AXUIElementRef element = (__bridge AXUIElementRef)[toCheck objectAtIndex: i] ;
                lua_newtable(L) ;
                _buildMenuArray(L, app, element) ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
                CFRelease(element) ;
            }
            lua_setfield(L, -2, "items") ;
        }
    } else if (count == 0) {
        CFTypeRef enabled; error = AXUIElementCopyAttributeValue(menuItem, kAXEnabledAttribute, &enabled);
        if (error) { NSLog(@"AXEnabled Error for %@: AXError %d", title, error) ; }
        lua_pushboolean(L, [(__bridge NSNumber *)enabled boolValue]); lua_setfield(L, -2, "enabled");

        CFTypeRef markchar; error = AXUIElementCopyAttributeValue(menuItem, kAXMenuItemMarkCharAttribute, &markchar);
        if (error && error != kAXErrorNoValue) { NSLog(@"AXMenuItemMarkCharAttribute Error for %@: AXError %d", title, error) ; }
        BOOL marked; if (error == kAXErrorNoValue) { marked = false; } else { marked = true; }
        lua_pushboolean(L, marked); lua_setfield(L, -2, "marked");
    }

// depth-- ;

    return ;
}

/// {PATH}.{MODULE}.getMenuArray(application) -> array
/// Function
/// Returns an array containing the menu items for the specified application.
static int getMenuArray(lua_State *L) {

// depth = -1 ;

    AXUIElementRef app = get_app(L, 1);
    AXUIElementRef menuBar ;
    AXError error = AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute, (CFTypeRef *)&menuBar) ;
    if (error) {
        NSLog(@"Unable to retrieve menuBar object: AXError %d", error) ;
        return luaL_error(L, "Unable to retrieve menuBar object: AXError %d", error) ;
    }
    lua_settop(L, 0) ;
    lua_newtable(L) ;
    _buildMenuArray(L, app, menuBar) ;
    CFRelease(menuBar) ;
    return 1 ;
}

// // // // // END: hs.application candidate

static const luaL_Reg {MODULE}Lib[] = {
    {"showAbout",           showabout },
    {"fileExists",          fileexists },
    {"uuid",                uuid },
    {"accessibility",       accessibility },
    {"autoLaunch",          autolaunch },
    {"NSLog",               extras_nslog },
    {"userDataToString",    ud_tostring},
    {"listFonts",           listFonts},
    {"getMenuArray",        getMenuArray},
    {"memoryInfo",          memoryInfo},
    {NULL,                  NULL}
};

int luaopen_{F_PATH}_{MODULE}_internal(lua_State* L) {
    luaL_newlib(L, {MODULE}Lib);
        version(L) ;
        lua_setfield(L, -2, "_version") ;
        paths(L) ;
        lua_setfield(L, -2, "_paths") ;

    return 1;
}
