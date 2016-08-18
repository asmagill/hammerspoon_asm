@import Cocoa ;
@import LuaSkin ;

#define USERDATA_TAG "hs._asm.canvas.textview"
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static int pushNSRange(lua_State *L, NSRange obj) ;
static NSRange toNSRangeFromLua(lua_State *L, int idx) ;

@interface ASMTextView : NSTextView
@property int callbackRef ;
@end

@implementation ASMTextView

- (instancetype)initWithFrame:(NSRect)frameRect {
    if (!(isfinite(frameRect.origin.x)    && isfinite(frameRect.origin.y) &&
          isfinite(frameRect.size.height) && isfinite(frameRect.size.width))) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:frame must be specified in finite numbers", USERDATA_TAG]];
        return nil;
    }

    self = [super initWithFrame:frameRect];
    if (self) {
        _callbackRef = LUA_NOREF ;

        self.autoresizingMask = (NSViewWidthSizable | NSViewHeightSizable) ;

        self.textContainer.widthTracksTextView = YES ;
        self.textContainer.heightTracksTextView = YES ;
    }
    return self ;
}

// - (void)setFrame:(NSRect)frameRect {
//     [super setFrame:frameRect] ;
//     self.minSize = frameRect.size ;
// }

- (BOOL)canBecomeKeyView {
    return YES ;
}

@end

#pragma mark - Module Functions

static int textview_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    ASMTextView *theView = [[ASMTextView alloc] initWithFrame:frameRect];
    [skin pushNSObject:theView] ;
    return 1 ;
}

#pragma mark - Module Methods

static int drawsBackground(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.drawsBackground) ;
    } else {
        theView.drawsBackground = (BOOL)lua_toboolean(L, 2) ;
        theView.needsDisplay = YES ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int allowsDocumentBackgroundColorChange(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.allowsDocumentBackgroundColorChange) ;
    } else {
        theView.allowsDocumentBackgroundColorChange = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int allowsUndo(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.allowsUndo) ;
    } else {
        theView.allowsUndo = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int editable(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.editable) ;
    } else {
        theView.editable = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int selectable(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.selectable) ;
    } else {
        theView.selectable = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int fieldEditor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.fieldEditor) ;
    } else {
        theView.fieldEditor = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int richText(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.richText) ;
    } else {
        theView.richText = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int importsGraphics(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.importsGraphics) ;
    } else {
        theView.importsGraphics = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int allowsImageEditing(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.allowsImageEditing) ;
    } else {
        theView.allowsImageEditing = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int automaticQuoteSubstitutionEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.automaticQuoteSubstitutionEnabled) ;
    } else {
        theView.automaticQuoteSubstitutionEnabled = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int automaticLinkDetectionEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.automaticLinkDetectionEnabled) ;
    } else {
        theView.automaticLinkDetectionEnabled = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int displaysLinkToolTips(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.displaysLinkToolTips) ;
    } else {
        theView.displaysLinkToolTips = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int usesRuler(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.usesRuler) ;
    } else {
        theView.usesRuler = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int rulerVisible(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.rulerVisible) ;
    } else {
        theView.rulerVisible = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int usesInspectorBar(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.usesInspectorBar) ;
    } else {
        theView.usesInspectorBar = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int smartInsertDeleteEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.smartInsertDeleteEnabled) ;
    } else {
        theView.smartInsertDeleteEnabled = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int continuousSpellCheckingEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.continuousSpellCheckingEnabled) ;
    } else {
        theView.continuousSpellCheckingEnabled = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int grammarCheckingEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.grammarCheckingEnabled) ;
    } else {
        theView.grammarCheckingEnabled = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int acceptsGlyphInfo(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.acceptsGlyphInfo) ;
    } else {
        theView.acceptsGlyphInfo = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int usesFontPanel(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.usesFontPanel) ;
    } else {
        theView.usesFontPanel = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int usesFindPanel(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.usesFindPanel) ;
    } else {
        theView.usesFindPanel = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int automaticDashSubstitutionEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.automaticDashSubstitutionEnabled) ;
    } else {
        theView.automaticDashSubstitutionEnabled = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int automaticDataDetectionEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.automaticDataDetectionEnabled) ;
    } else {
        theView.automaticDataDetectionEnabled = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int automaticSpellingCorrectionEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.automaticSpellingCorrectionEnabled) ;
    } else {
        theView.automaticSpellingCorrectionEnabled = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int automaticTextReplacementEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.automaticTextReplacementEnabled) ;
    } else {
        theView.automaticTextReplacementEnabled = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int usesFindBar(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.usesFindBar) ;
    } else {
        theView.usesFindBar = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int incrementalSearchingEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theView.incrementalSearchingEnabled) ;
    } else {
        theView.incrementalSearchingEnabled = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int selectionGranularity(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    NSDictionary *mapping = @{
        @"character" : @(NSSelectByCharacter),
        @"word"      : @(NSSelectByWord),
        @"paragraph" : @(NSSelectByParagraph),
    } ;
    if (lua_gettop(L) == 1) {
        NSString *value = [[mapping allKeysForObject:@(theView.selectionGranularity)] firstObject] ;
        if (value) {
            [skin pushNSObject:value] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized selectionGranularity %@ -- notify developers", USERDATA_TAG, @(theView.selectionGranularity)]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSNumber *value = mapping[[skin toNSObjectAtIndex:2]] ;
        if (value) {
            theView.selectionGranularity = [value unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[mapping allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int backgroundColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSObject:theView.backgroundColor] ;
    } else {
        theView.backgroundColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int insertionPointColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSObject:theView.insertionPointColor] ;
    } else {
        theView.insertionPointColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textContainerInset(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSSize:theView.textContainerInset] ;
    } else {
        theView.textContainerInset = [skin tableToSizeAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int defaultParagraphStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSObject:theView.defaultParagraphStyle] ;
    } else {
        theView.defaultParagraphStyle = [skin luaObjectAtIndex:2 toClass:"NSParagraphStyle"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int selectedRange(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        pushNSRange(L, theView.selectedRange) ;
    } else {
        theView.selectedRange = toNSRangeFromLua(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// static int maxSize(lua_State *L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
//     ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
//     if (lua_gettop(L) == 1) {
//         [skin pushNSSize:theView.maxSize] ;
//     } else {
//         theView.maxSize = [skin tableToSizeAtIndex:2] ;
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }
//
// static int minSize(lua_State *L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
//     ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
//     if (lua_gettop(L) == 1) {
//         [skin pushNSSize:theView.minSize] ;
//     } else {
//         theView.minSize = [skin tableToSizeAtIndex:2] ;
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }
//
// static int horizontallyResizable(lua_State *L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
//     ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
//     if (lua_gettop(L) == 1) {
//         lua_pushboolean(L, theView.horizontallyResizable) ;
//     } else {
//         theView.horizontallyResizable = (BOOL)lua_toboolean(L, 2) ;
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }
//
// static int verticallyResizable(lua_State *L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
//     ASMTextView *theView = [skin toNSObjectAtIndex:1] ;
//     if (lua_gettop(L) == 1) {
//         lua_pushboolean(L, theView.verticallyResizable) ;
//     } else {
//         theView.verticallyResizable = (BOOL)lua_toboolean(L, 2) ;
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMTextView(lua_State *L, id obj) {
    ASMTextView *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMTextView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toASMTextViewFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMTextView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMTextView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSRange(lua_State *L, NSRange obj) {
    lua_newtable(L) ;
    lua_pushnumber(L, obj.location) ; lua_setfield(L, -2, "loc") ;
    lua_pushnumber(L, obj.length) ;   lua_setfield(L, -2, "len") ;
    return 1 ;
}

static NSRange toNSRangeFromLua(lua_State *L, int idx) {
    NSRange range = NSMakeRange(0.0, 0.0) ;
    if (lua_getfield(L, idx, "loc") == LUA_TNUMBER) range.location = (lua_Unsigned)lua_tointeger(L, -1) ;
    lua_pop(L, 1) ;
    if (lua_getfield(L, idx, "len") == LUA_TNUMBER) range.length = (lua_Unsigned)lua_tointeger(L, -1) ;
    lua_pop(L, 1) ;
    return range ;
}


#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMTextView *obj = [skin luaObjectAtIndex:1 toClass:"ASMTextView"] ;
    NSString *title = NSStringFromRect(obj.frame) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMTextView *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMTextView"] ;
        ASMTextView *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMTextView"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMTextView *obj = get_objectFromUserdata(__bridge_transfer ASMTextView, L, 1, USERDATA_TAG) ;
    if (obj) obj = nil ;
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"acceptsGlyphInfo",            acceptsGlyphInfo},
    {"allowsBackgroundColorChange", allowsDocumentBackgroundColorChange},
    {"allowsImageEditing",          allowsImageEditing},
    {"allowsUndo",                  allowsUndo},
    {"automaticDashSubstitution",   automaticDashSubstitutionEnabled},
    {"automaticDataDetection",      automaticDataDetectionEnabled},
    {"automaticLinkDetection",      automaticLinkDetectionEnabled},
    {"automaticQuoteSubstitution",  automaticQuoteSubstitutionEnabled},
    {"automaticSpellingCorrection", automaticSpellingCorrectionEnabled},
    {"automaticTextReplacement",    automaticTextReplacementEnabled},
    {"backgroundColor",             backgroundColor},
    {"continuousSpellChecking",     continuousSpellCheckingEnabled},
    {"defaultParagraphStyle",       defaultParagraphStyle},
    {"displaysLinkToolTips",        displaysLinkToolTips},
    {"drawsBackground",             drawsBackground},
    {"editable",                    editable},
    {"fieldEditor",                 fieldEditor},
    {"grammarChecking",             grammarCheckingEnabled},
    {"importsGraphics",             importsGraphics},
    {"incrementalSearching",        incrementalSearchingEnabled},
    {"insertionPointColor",         insertionPointColor},
    {"richText",                    richText},
    {"rulerVisible",                rulerVisible},
    {"selectable",                  selectable},
    {"selectionGranularity",        selectionGranularity},
    {"smartInsertDelete",           smartInsertDeleteEnabled},
    {"textContainerInset",          textContainerInset},
    {"usesFindBar",                 usesFindBar},
    {"usesFindPanel",               usesFindPanel},
    {"usesFontPanel",               usesFontPanel},
    {"usesInspectorBar",            usesInspectorBar},
    {"usesRuler",                   usesRuler},

    {"selectedRange",               selectedRange},
//     {"maxSize",                     maxSize},
//     {"minSize",                     minSize},
//     {"horizontallyResizable",       horizontallyResizable},
//     {"verticallyResizable",         verticallyResizable},

    {"__tostring",                  userdata_tostring},
    {"__eq",                        userdata_eq},
    {"__gc",                        userdata_gc},
    {NULL,                          NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", textview_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_canvas_textview_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASMTextView         forClass:"ASMTextView"];

    [skin registerLuaObjectHelper:toASMTextViewFromLua forClass:"ASMTextView"
                                             withUserdataMapping:USERDATA_TAG];

    return 1;
}
