#import "objc.h"

// #ifndef MACOSX
// #define MACOSX
// #endif

// Not sure why this is unpublished as it provides a proper mirror to objc_msgSendSuper
@interface NSInvocation (unpublished)
-(void)invokeSuper ;
@end

static int refTable = LUA_NOREF;

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

// static int extras_nslog(__unused lua_State* L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     id val = [skin toNSObjectAtIndex:1] ;
//     [skin logVerbose:[NSString stringWithFormat:@"%@", val]] ;
//     NSLog(@"%@", val);
//     return 0;
// }

/// hs._asm.objc.imageNames() -> table
/// Function
/// Returns a list of the names of all the loaded Objective-C frameworks and dynamic libraries.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an array of the currently loaded frameworks and dynamic libraries.  Each entry is the complete path to the framework or library.
///
/// Notes:
///  * You can load a framework which is not currently loaded by using the lua builtin `package.loadlib`.  E.g. `package.loadlib("/System/Library/Frameworks/MapKit.framework/Versions/Current/MapKit","*")`
static int objc_getImageNames(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;

    lua_newtable(L) ;
      UInt  count ;
      const char **files = objc_copyImageNames(&count) ;
      for(UInt i = 0 ; i < count ; i++) {
          lua_pushstring(L, files[i]) ;
          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      }
      if (files) free(files) ;
    return 1 ;
}

/// hs._asm.objc.classNamesForImage(imageName) -> table
/// Function
/// Returns a list of the classes within the specified library or framework.
///
/// Parameters:
///  * imageName - the full path of the library or framework image to return the list of classes from.
///
/// Returns:
///  * an array of the class names defined within the specified image.
///
/// Notes:
///  * You can load a framework which is not currently loaded by using the lua builtin `package.loadlib`.  E.g. `package.loadlib("/System/Library/Frameworks/MapKit.framework/Versions/Current/MapKit","*")`
///  * the `imageName` must match the actual path (without symbolic links) that was loaded.  For the example given above, the proper path name (as of OS X 10.11.3) would be "/System/Library/Frameworks/MapKit.framework/Versions/A/MapKit".  You can determine this path by looking at the results from [hs._asm.objc.imageNames](#imageNames).
static int objc_classNamesForImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    lua_newtable(L) ;
      UInt  count ;
      const char **classes = objc_copyClassNamesForImage(luaL_checkstring(L, 1), &count) ;
      for(UInt i = 0 ; i < count ; i++) {
          lua_pushstring(L, classes[i]) ;
          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      }
      if (classes) free(classes) ;
    return 1 ;
}

/// hs._asm.objc.objc_msgSend([flags], target, selector, ...) -> result
/// Function
/// The core Objective-C message sending interface.  There are a variety of method wrappers described elsewhere which are probably more clear in context, but they all reduce down to this function.
///
/// Parameters:
///  * flags    - an optional integer used as a bit flag to alter the message being sent:
///    * 0x01 - if bit 1 is set, the message should actually be sent to the class or object's superclass.  This is equivalent to `[[target super] selector]`
///    * 0x02 - if bit 2 is set, and the `target` is a class, then the selector is sent to `[target alloc]` and the result is returned.  This is a shorthand for allocating and initializing an object at the same time.
///  * target   - a class object or an object instance to which the message should be sent.
///  * selector - a selector (message) to send to the target.
///  * optional additional arguments are passed to the target as arguments for the selector specified.
///
/// Returns:
///  * the result (if any) of the message sent.  If an exception occurs during the sending of the message, this function returns nil as the first argument, and a second argument of a table containing the traceback information for the exception.
///
/// Notes:
///  * In general, it will probably be clearer in most contexts to use one of the wrapper methods to this function.  They are described in the appropriate places in the [hs._asm.objc.class](#class) and [hs._asm.objc.object](#object) sections of this documentation.
///
///  * The following example shows the most basic form for sending the messages necessary to create a newly initialized NSObject.
///  * In it's most raw form, a newly initialized NSObject is created as follows:
///    *
///    ~~~lua
///      hs._asm.objc.objc_msgSend(
///           hs._asm.objc.objc_msgSend(
///               hs._asm.objc.class.fromString("NSObject"),
///               hs._asm.objc.selector.fromString("alloc")
///           ), hs._asm.objc.selector.fromString("init")
///       )
///     ~~~
///
///  * Using the optional bit-flag, this can be shortened to:
///    *
///    ~~~lua
///      hs._asm.objc.objc_msgSend(0x02,
///          hs._asm.objc.class.fromString("NSObject"),
///          hs._asm.objc.selector.fromString("init")
///      )
///    ~~~
///
///  * Note that `.fromString` is optional for the [hs._asm.objc.class.fromString](#fromString) and [hs._asm.objc.selector.fromString](#fromString3) functions as described in the documentation for each -- they are provided here for completeness and clarity.
///  * Even shorter variants are possible and will be documented where appropriate.
///
///  * Note that an alloc'd but not initialized object is generally an unsafe object to access in any fashion -- it is why almost every programming guide for Objective-C tells you to **always** combine the two into one statement.  This is for two very important reasons that also apply when using this module:
///    * allocating an object just sets aside the memory for the object -- it does not set any defaults and there is no way of telling what may be in the memory space provided... at best garbage; more likely something that will crash your program if you try to examine or use it assuming that it conforms to the object class or it's properties.
///    * the `init` method does not always return the same object that the message was passed to.  If you do the equivalent of the following: `a = [someClass alloc] ; [a init] ;`, you cannot be certain that `a` is the initialized object.  Only by performing the equivalent of `a = [[someClass alloc] init]` can you be certain of what `a` contains.
///    * some classes with an initializer that takes no arguments (e.g. NSObject) provide `new` as a shortcut: `a = [someClass new]` as the equivalent to `a = [[someClass alloc] init]`.  I'm not sure why this seems to be unpopular in some circles, though.
///    * other classes provide their own shortcuts (e.g. NSString allows `a = [NSString stringWithUTF8String:"c-string"]` as a shortcut for `a = [[NSString alloc] initWithUTF8String:"c-string"]`).
///  * Whatever style you use, make sure that you're working with a properly allocated **AND** initialized object; otherwise you're gonna get an earth-shattering kaboom.
static int invocator(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    BOOL hasFlags   = (lua_type(L, 1) == LUA_TNUMBER) ;
    int  objIndex   = hasFlags ? 2 : 1 ;
    int  selIndex   = objIndex + 1 ;
    int  argCount   = lua_gettop(L) - selIndex ;

    long flags      = hasFlags ? lua_tointeger(L, 1) : 0 ;
    BOOL callSuper  = ((flags & 0x01) != 0) ;
    BOOL allocFirst = ((flags & 0x02) != 0) ;

    id   rcv ;
    Class cls ;
    if (luaL_testudata(L, objIndex, CLASS_USERDATA_TAG)) {
        cls         = get_objectFromUserdata(__bridge Class, L, objIndex, CLASS_USERDATA_TAG) ;
        if (allocFirst) rcv = [cls alloc] ;
    } else if(luaL_testudata(L, objIndex, ID_USERDATA_TAG) && !allocFirst) {
        rcv         = get_objectFromUserdata(__bridge id, L, objIndex, ID_USERDATA_TAG) ;
        cls         = [(NSObject *)rcv class] ;
    } else {
        return luaL_argerror(L, objIndex, "must be a class object or an id object") ;
    }
    SEL  sel        = get_objectFromUserdata(SEL, L, selIndex, SEL_USERDATA_TAG) ;

    NSString *selName = NSStringFromSelector(sel) ;

    NSMethodSignature *signature = (rcv) ? [cls instanceMethodSignatureForSelector:sel]
                                         : [cls methodSignatureForSelector:sel];
    if (!signature) {
        return luaL_error(L, [[NSString stringWithFormat:@"no selector %@ for %@",
                                                         selName,
                                                         rcv] UTF8String]) ;
    }
    if (signature.numberOfArguments != (NSUInteger)(argCount + 2))
        return luaL_error(L, "invalid number of arguments") ;

    const char *returnType = [signature methodReturnType] ;
    UInt typePos ;
    switch(returnType[0]) {
        case 'r':   // const
        case 'n':   // in
        case 'N':   // inout
        case 'o':   // out
        case 'O':   // bycopy
        case 'R':   // byref
        case 'V':   // oneway
            typePos = 1 ; break ;
        default:
            typePos = 0 ; break ;
    }

#if defined(DEBUG_msgSend)
    {
        Class forLog = callSuper ? class_getSuperclass(cls) : cls ; // shuts up compiler
        [skin logDebug:[NSString stringWithFormat:@"%s = [%s%@%s %@] with %d arguments",
                                                    returnType,
                                                    (rcv ? "<" : ""),
                                                    NSStringFromClass(forLog),
                                                    (rcv ? ">" : ""),
                                                    selName,
                                                    argCount]] ;
    }
#endif

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:rcv ? rcv : cls];
    [invocation setSelector:sel];
    for (NSUInteger idx = 0 ; idx < (NSUInteger)argCount ; idx++) {
        int        invocationIndex = (int)idx + 2 ;
        int        luaIndex        = (int)idx + selIndex + 1 ;
        const char *argumentType = [signature getArgumentTypeAtIndex:(NSUInteger)invocationIndex] ;
        UInt argTypePos ;
        switch(argumentType[0]) {
            case 'r':   // const
            case 'n':   // in
            case 'N':   // inout
            case 'o':   // out
            case 'O':   // bycopy
            case 'R':   // byref
            case 'V':   // oneway
                argTypePos = 1 ; break ;
            default:
                argTypePos = 0 ; break ;
        }

        switch(argumentType[argTypePos]) {
            case 'c': { // char
                char val ;
                if (lua_type(L, luaIndex) == LUA_TBOOLEAN) {
                    val = (char)lua_toboolean(L, luaIndex) ;
                } else {
                    val = (char)luaL_checkinteger(L, luaIndex) ;
                }
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case 's': { // short
                short val = (short)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case 'i': { // int
                int val = (int)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case 'l': { // long
                long val = (long)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case 'q': { // long long
                long long val = (long long)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case 'Q': { // unsigned long long
                unsigned long long val = (unsigned long long)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case 'L': { // unsigned long
                unsigned long val = (unsigned long)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case 'I': { // unsigned int
                unsigned int val = (unsigned int)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case 'S': { // unsigned short
                unsigned short val = (unsigned short)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case 'C': { // unsigned char
                unsigned char val = (unsigned char)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case 'B': { // C++ bool or a C99 _Bool
                Boolean val = (Boolean)lua_toboolean(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
//             case 'v':   // void
//                 break ;
            case '*': { // char *
                const char *val = lua_tostring(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case 'f': { // float
                float val = (float)luaL_checknumber(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case 'd': { // double
                double val = (double)luaL_checknumber(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case '@': { // ID
                id val ;
                if (lua_type(L, luaIndex) != LUA_TNIL) {
                    val = get_objectFromUserdata(__bridge id, L, luaIndex, ID_USERDATA_TAG) ;
                }
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case '#': { // Class
                Class val = get_objectFromUserdata(__bridge Class, L, luaIndex, CLASS_USERDATA_TAG) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case ':': { // SEL
                SEL val = get_objectFromUserdata(SEL, L, luaIndex, SEL_USERDATA_TAG) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case '{': { // struct
                NSValue *val = [skin toNSObjectAtIndex:luaIndex] ;
                if ([val isKindOfClass:[NSValue class]]) {
                    if (!strcmp(argumentType, [val objCType])) {
                        NSUInteger actualSize ;
                        NSGetSizeAndAlignment([val objCType], &actualSize, NULL) ;
                        void* ptr = malloc(actualSize) ;
                        [val getValue:ptr] ;
                        [invocation setArgument:ptr atIndex:invocationIndex] ;
                        [invocation retainArguments] ;
                        free(ptr) ;
                    } else {
                        return luaL_error(L, "wrong structure:found %s, expected %s", [val objCType], argumentType) ;
                    }
                } else {
                    return luaL_error(L, "argument is not a recognized structure") ;
                }
            }   break ;

            // partial support, for when it's NULL
            case '^': {
                if (lua_type(L, luaIndex) == LUA_TNIL) {
                    id val ;
                    [invocation setArgument:&val atIndex:invocationIndex] ;
                    [invocation retainArguments] ;
                    break ;
                }
            }
    //     [array type]    An array
    //     (name=type...)  A union
    //     bnum            A bit field of num bits
    //     ^type           A pointer to type
    //     ?               An unknown type (among other things, this code is used for function pointers)

            default:
                return luaL_error(L, "unsupported argument type %s for position %d", argumentType, idx + 1) ;
                break ;
        }
    }

    @try {
        if (callSuper) {
            [invocation invokeSuper] ;
        } else {
            [invocation invoke] ;
        }
    } @catch (NSException *theException) {
        lua_pushnil(L) ;
        [skin pushNSObject:theException] ;
        return 2 ;
    }

    NSUInteger length = [signature methodReturnLength] ;
    switch(returnType[typePos]) {
        case 'c': { // char
            char result ;
            [invocation getReturnValue:&result] ;
            // this type sucks because if 0 or 1, it's *usually* boolean... except when it's not.
            // we have to make a choice since lua treats only nil and false as false, unlike C, so
            // we can't just return 0 and hope the lua coder knows the difference.
            if (result == 0 || result == 1)
                lua_pushboolean(L, result) ;
            else
                lua_pushinteger(L, result) ;
        }   break ;
        case 's': { // short
            short result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, result) ;
        }   break ;
        case 'i': { // int
            int result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, result) ;
        }   break ;
        case 'l': { // long
            long result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, result) ;
        }   break ;
        case 'q': { // long long
            long long result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, result) ;
        }   break ;
        case 'Q': { // unsigned long long
            unsigned long long result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, (long long)result) ; // lua can't do unsigned long long
        }   break ;
        case 'L': { // unsigned long
            unsigned long result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, (long long)result) ; // lua can't do unsigned long
        }   break ;
        case 'I': { // unsigned int
            unsigned int result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, result) ;
        }   break ;
        case 'S': { // unsigned short
            unsigned short result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, result) ;
        }   break ;
        case 'C': { // unsigned char
            unsigned char result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, result) ;
        }   break ;
        case 'B': { // C++ bool or a C99 _Bool
            _Bool result ;
            [invocation getReturnValue:&result] ;
            lua_pushboolean(L, result) ;
        }   break ;
        case 'v':   // void
            lua_pushnil(L) ;
            break ;
        case '*': { // char *
            char *result ;
            [invocation getReturnValue:&result] ;
            lua_pushstring(L, result) ;
        }   break ;
        case 'f': { // float
            float result ;
            [invocation getReturnValue:&result] ;
            lua_pushnumber(L, (lua_Number)result) ;
        }   break ;
        case 'd': { // double
            double result ;
            [invocation getReturnValue:&result] ;
            lua_pushnumber(L, result) ;
        }   break ;
        case '@': { // ID
        // NSInvocation's return of an ID object confusels ARC...
        // see http://stackoverflow.com/a/11569236
            CFTypeRef result;
            [invocation getReturnValue:&result];
            if (result) CFRetain(result);
            push_object(L, (__bridge_transfer id)result) ;
        }   break ;
        case '#': { // Class
            Class result ;
            [invocation getReturnValue:&result] ;
            push_class(L, result) ;
        }   break ;
        case ':': { // SEL
            SEL result ;
            [invocation getReturnValue:&result] ;
            push_selector(L, result) ;
        }   break ;
        case '{': { // struct
            NSUInteger actualSize ;
            NSGetSizeAndAlignment(returnType, &actualSize, NULL) ;
            void* ptr = malloc(actualSize) ;
            [invocation getReturnValue:ptr] ;
            NSValue *val = [NSValue valueWithBytes:ptr objCType:returnType] ;
            [skin pushNSObject:val] ;
            free(ptr) ;
        }   break ;

//     [array type]    An array
//     (name=type...)  A union
//     bnum            A bit field of num bits
//     ^type           A pointer to type
//     ?               An unknown type (among other things, this code is used for function pointers)

        default:
            [skin logWarn:[NSString stringWithFormat:@"%s return type not supported yet", returnType]] ;
            void *result = malloc(length) ;
            [invocation getReturnValue:result] ;
            lua_newtable(L) ;
            lua_pushinteger(L, (lua_Integer)length) ;    lua_setfield(L, -2, "length") ;
            lua_pushstring(L, returnType) ;              lua_setfield(L, -2, "type") ;
            lua_pushlstring(L, (char *)result, length) ; lua_setfield(L, -2, "contents") ;
            free(result) ;
            break ;
    }
    return 1 ;
}


#pragma mark - Module Methods

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int NSMethodSignature_toLua(lua_State *L, id obj) {
    NSMethodSignature *sig = obj ;
    lua_newtable(L) ;
      lua_pushstring(L, [sig methodReturnType]) ;                 lua_setfield(L, -2, "methodReturnType") ;
      lua_pushinteger(L, (lua_Integer)[sig methodReturnLength]) ; lua_setfield(L, -2, "methodReturnLength") ;
      lua_pushinteger(L, (lua_Integer)[sig frameLength]) ;        lua_setfield(L, -2, "frameLength") ;
      lua_pushinteger(L, (lua_Integer)[sig numberOfArguments]) ;  lua_setfield(L, -2, "numberOfArguments") ;
      lua_newtable(L) ;
        for (NSUInteger i = 0 ; i < [sig numberOfArguments] ; i++) {
            lua_pushstring(L, [sig getArgumentTypeAtIndex:i]) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
      lua_setfield(L, -2, "arguments") ;

    return 1 ;
}

static int NSException_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSException *theError = obj ;

    lua_newtable(L) ;
      [skin pushNSObject:[theError name]] ;                     lua_setfield(L, -2, "name") ;
      [skin pushNSObject:[theError reason]] ;                   lua_setfield(L, -2, "reason") ;
      [skin pushNSObject:[theError userInfo]] ;                 lua_setfield(L, -2, "userInfo") ;
      [skin pushNSObject:[theError callStackReturnAddresses]] ; lua_setfield(L, -2, "callStackReturnAddresses") ;
      [skin pushNSObject:[theError callStackSymbols]] ;         lua_setfield(L, -2, "callStackSymbols") ;
    return 1 ;
}


#pragma mark - Hammerspoon/Lua Infrastructure

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"objc_msgSend",       invocator},
    {"imageNames",         objc_getImageNames},
    {"classNamesForImage", objc_classNamesForImage},
//     {"nslog",              extras_nslog},

    {NULL,                 NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;

    refTable = [skin registerLibrary:moduleLib metaFunctions:nil] ;

    [skin registerPushNSHelper:NSMethodSignature_toLua forClass:"NSMethodSignature"] ;
    [skin registerPushNSHelper:NSException_toLua       forClass:"NSException"] ;

    luaopen_hs__asm_objc_class(L) ;    lua_setfield(L, -2, "class") ;
    luaopen_hs__asm_objc_ivar(L) ;     lua_setfield(L, -2, "ivar") ;
    luaopen_hs__asm_objc_method(L) ;   lua_setfield(L, -2, "method") ;
    luaopen_hs__asm_objc_object(L) ;   lua_setfield(L, -2, "object") ;
    luaopen_hs__asm_objc_property(L) ; lua_setfield(L, -2, "property") ;
    luaopen_hs__asm_objc_protocol(L) ; lua_setfield(L, -2, "protocol") ;
    luaopen_hs__asm_objc_selector(L) ; lua_setfield(L, -2, "selector") ;

    return 1;
}
