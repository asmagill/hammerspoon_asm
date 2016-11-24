@import Cocoa ;
@import LuaSkin ;

// minimal module to allow loading this module on an unsupported machine to get at the
// "hs._asm.touchbar.supported" function.  If we don't do it this way, loading
// "hs._asm.touchbar.internal" causes an unresolved symbol error and fails to load... this
// seems "nicer" in that it can still pop up a warning dialog if the user chooses.

static BOOL is_supported() { return NSClassFromString(@"DFRElement") ? YES : NO ; }

/// hs._asm.touchbar.supported([showLink]) -> boolean
/// Function
/// Returns a boolean value indicathing whether or not the Apple Touch Bar is supported on this Macintosh.
///
/// Parameters:
///  * `showLink` - a boolean, default false, specifying whether a dialog prompting the user to download the necessary update is presented if Apple Touch Bar support is not found in the current Operating System.
///
/// Returns:
///  * true if Apple Touch Bar support is found in the current Operating System or false if it is not.
///
/// Notes:
///  * the link in the prompt is https://support.apple.com/kb/dl1897
static int touchbar_supported(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    BOOL showDialog = (lua_gettop(L) == 1) ? (BOOL)lua_toboolean(L, 1) : NO ;
    lua_pushboolean(L, is_supported()) ;
    if (!lua_toboolean(L, -1)) {
        if (showDialog) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Error: could not detect Touch Bar support"];
            [alert setInformativeText:[NSString stringWithFormat:@"We need at least macOS 10.12.1 (Build 16B2657).\n\nYou have: %@.\n", [NSProcessInfo processInfo].operatingSystemVersionString]];
            [alert addButtonWithTitle:@"Cancel"];
            [alert addButtonWithTitle:@"Get macOS Update"];
            NSModalResponse response = [alert runModal];
            if(response == NSAlertSecondButtonReturn) {
                NSURL *appleUpdateURL = [NSURL URLWithString:@"https://support.apple.com/kb/dl1897"] ;
                [[NSWorkspace sharedWorkspace] openURL:appleUpdateURL];
            }
        }
    }
    return 1 ;
}

// placeholder
static int touchbar_new(lua_State *L) {
    lua_pushnil(L) ;
    return 1 ;
}

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"supported", touchbar_supported},
    {"new",       touchbar_new},

    {NULL,        NULL}
};

int luaopen_hs__asm_touchbar_supported(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin registerLibrary:moduleLib metaFunctions:nil] ;

    return 1;
}
