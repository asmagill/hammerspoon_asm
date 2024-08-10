#import "objc.h"

// #ifndef MACOSX
// #define MACOSX
// #endif

// Not sure why this is unpublished as it provides a proper mirror to objc_msgSendSuper
@interface NSInvocation (unpublished)
-(void)invokeSuper ;
@end

static LSRefTable refTable = LUA_NOREF;

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

// static int extras_nslog(lua_State* L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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
    UInt returnTypePos ;
    switch(returnType[0]) {
// ??? what can we do to better support these? do we need/want to?
        case _C_CONST:
        case _C_IN:
        case _C_INOUT:
        case _C_OUT:
        case _C_BYCOPY:
        case _C_BYREF:
        case _C_ONEWAY:
// ??? what are _C_COMPLEX ('j'), _C_ATOMIC ('A'), _C_GNUREGISTER ('*')
            returnTypePos = 1 ; break ;
        default:
            returnTypePos = 0 ; break ;
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
// ??? what can we do to better support these? do we need/want to?
            case _C_CONST:
            case _C_IN:
            case _C_INOUT:
            case _C_OUT:
            case _C_BYCOPY:
            case _C_BYREF:
            case _C_ONEWAY:
// ??? what are _C_COMPLEX ('j'), _C_ATOMIC ('A'), _C_GNUREGISTER ('*')
                argTypePos = 1 ; break ;
            default:
                argTypePos = 0 ; break ;
        }

        switch(argumentType[argTypePos]) {
            case _C_CHR: { // char
                char val ;
                if (lua_type(L, luaIndex) == LUA_TBOOLEAN) {
                    val = (char)lua_toboolean(L, luaIndex) ;
                } else {
                    val = (char)luaL_checkinteger(L, luaIndex) ;
                }
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_SHT: { // short
                short val = (short)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_INT: { // int
                int val = (int)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_LNG: { // long
                long val = (long)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_LNG_LNG: { // long long
                long long val = (long long)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_ULNG_LNG: { // unsigned long long
                unsigned long long val = (unsigned long long)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_ULNG: { // unsigned long
                unsigned long val = (unsigned long)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_UINT: { // unsigned int
                unsigned int val = (unsigned int)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_USHT: { // unsigned short
                unsigned short val = (unsigned short)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_UCHR: { // unsigned char
                unsigned char val = (unsigned char)luaL_checkinteger(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_BOOL: { // C++ bool or a C99 _Bool
                Boolean val = (Boolean)lua_toboolean(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
//             case _C_VOID:   // void
//                 break ;
            case _C_CHARPTR: { // char *
                const char *val = lua_tostring(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_FLT: { // float
                float val = (float)luaL_checknumber(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_DBL: { // double
                double val = (double)luaL_checknumber(L, luaIndex) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_ID: { // ID
                id val ;
                if (lua_type(L, luaIndex) != LUA_TNIL) {
                    val = get_objectFromUserdata(__bridge id, L, luaIndex, ID_USERDATA_TAG) ;
                }
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_CLASS: { // Class
                Class val = get_objectFromUserdata(__bridge Class, L, luaIndex, CLASS_USERDATA_TAG) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_SEL: { // SEL
                SEL val = get_objectFromUserdata(SEL, L, luaIndex, SEL_USERDATA_TAG) ;
                [invocation setArgument:&val atIndex:invocationIndex] ;
                [invocation retainArguments] ;
            }   break ;
            case _C_STRUCT_B: { // struct
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
// ??? what can we do to better support these? do we need/want to?
                    return luaL_error(L, "argument is not recognized as a structure") ;
                }
            }   break ;

// ??? what can we do to better support these? do we need/want to?
            // partial support, for when it's NULL
            case _C_PTR: {
                if (lua_type(L, luaIndex) == LUA_TNIL) {
                    id val ;
                    [invocation setArgument:&val atIndex:invocationIndex] ;
                    [invocation retainArguments] ;
                    break ;
                }
            }
//     _C_ARY_B/E   [array type]    An array
//     _C_UNION_B/E (name=type...)  A union
//     _C_BFLD      bnum            A bit field of num bits
//     _C_PTR       ^type           A pointer to type
//     _C_UNDEF     ?               An unknown type (among other things, this code is used for function pointers)
//     _C_INT128      't'
//     _C_UINT128     'T'
//     _C_LNG_DBL     'D'
//     _C_ATOM        '%'
//     _C_VECTOR      '!'

            default:
                return luaL_error(L, "unsupported argument type %s for position %d", argumentType, idx + 1) ;
//                 break ;
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
    switch(returnType[returnTypePos]) {
        case _C_CHR: { // char
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
        case _C_SHT: { // short
            short result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, result) ;
        }   break ;
        case _C_INT: { // int
            int result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, result) ;
        }   break ;
        case _C_LNG: { // long
            long result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, result) ;
        }   break ;
        case _C_LNG_LNG: { // long long
            long long result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, result) ;
        }   break ;
        case _C_ULNG_LNG: { // unsigned long long
            unsigned long long result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, (long long)result) ; // lua can't do unsigned long long
        }   break ;
        case _C_ULNG: { // unsigned long
            unsigned long result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, (long long)result) ; // lua can't do unsigned long
        }   break ;
        case _C_UINT: { // unsigned int
            unsigned int result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, result) ;
        }   break ;
        case _C_USHT: { // unsigned short
            unsigned short result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, result) ;
        }   break ;
        case _C_UCHR: { // unsigned char
            unsigned char result ;
            [invocation getReturnValue:&result] ;
            lua_pushinteger(L, result) ;
        }   break ;
        case _C_BOOL: { // C++ bool or a C99 _Bool
            _Bool result ;
            [invocation getReturnValue:&result] ;
            lua_pushboolean(L, result) ;
        }   break ;
        case _C_VOID:   // void
            lua_pushnil(L) ;
            break ;
        case _C_CHARPTR: { // char *
            char *result ;
            [invocation getReturnValue:&result] ;
            lua_pushstring(L, result) ;
        }   break ;
        case _C_FLT: { // float
            float result ;
            [invocation getReturnValue:&result] ;
            lua_pushnumber(L, (lua_Number)result) ;
        }   break ;
        case _C_DBL: { // double
            double result ;
            [invocation getReturnValue:&result] ;
            lua_pushnumber(L, result) ;
        }   break ;
        case _C_ID: { // ID
        // NSInvocation's return of an ID object confusels ARC...
        // see http://stackoverflow.com/a/11569236
            CFTypeRef result;
            [invocation getReturnValue:&result];
            if (result) CFRetain(result);
            push_object(L, (__bridge_transfer id)result) ;
        }   break ;
        case _C_CLASS: { // Class
            Class result ;
            [invocation getReturnValue:&result] ;
            push_class(L, result) ;
        }   break ;
        case _C_SEL: { // SEL
            SEL result ;
            [invocation getReturnValue:&result] ;
            push_selector(L, result) ;
        }   break ;
        case _C_STRUCT_B: { // struct
            NSUInteger actualSize ;
            NSGetSizeAndAlignment(returnType, &actualSize, NULL) ;
            void* ptr = malloc(actualSize) ;
            [invocation getReturnValue:ptr] ;
            NSValue *val = [NSValue valueWithBytes:ptr objCType:returnType] ;
            [skin pushNSObject:val] ;
            // alignedSize is irrelevant and distracting; should be removed in LuaSkin,
            // but given talk of move to Swift not sure if it's the time for that now
            if (lua_type(L, -1) == LUA_TTABLE) {
                lua_pushnil(L) ;
                lua_setfield(L, -2, "alignedSize") ;
            }

// a real mess; lets do the conversions in lua -- should work fine unless we come across
// something where the alignment and the data size don't match -- we'll deal with that if
// it comes up
//
//             lua_newtable(L) ;
//             lua_pushstring(L, returnType) ; lua_setfield(L, -2, "objCType") ;
//             [skin pushNSObject:[NSData dataWithBytes:ptr length:actualSize]] ;
//             lua_setfield(L, -2, "data") ;
//
//             lua_newtable(L) ;
//             void*      data  = ptr ;
//             const char *type = returnType + 3 ; // need better way to identify '{.*=' at begining
//             NSUInteger size, align ;
//             while(*type != 0) {
//                 lua_newtable(L) ;
//                 lua_pushstring(L, type) ; lua_setfield(L, -2, "type") ;
//                 @try {
//                     type = NSGetSizeAndAlignment(type, &size, &align) ;
//                     lua_pushinteger(L, (lua_Integer)size) ;  lua_setfield(L, -2, "size") ;
//                     lua_pushinteger(L, (lua_Integer)align) ; lua_setfield(L, -2, "align") ;
//                 } @catch (NSException *exception) {
//                     [skin pushNSObject:exception.reason] ;
//                     type++ ;
//                 } @finally {
// //                     lua_pushstring(L, type) ; lua_setfield(L, -2, "typeAfter") ;
//                     lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
//                 }
//             }
//             lua_setfield(L, -2, "breakdown") ;

            free(ptr) ;
        }   break ;

//     _C_ARY_B/E   [array type]    An array
//     _C_UNION_B/E (name=type...)  A union
//     _C_BFLD      bnum            A bit field of num bits
//     _C_PTR       ^type           A pointer to type
//     _C_UNDEF     ?               An unknown type (among other things, this code is used for function pointers)
//     _C_INT128      't'
//     _C_UINT128     'T'
//     _C_LNG_DBL     'D'
//     _C_ATOM        '%'
//     _C_VECTOR      '!'

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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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

int luaopen_hs__asm_libobjc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    refTable = [skin registerLibrary:ROOT_USERDATA_TAG functions:moduleLib metaFunctions:nil] ;

    [skin registerPushNSHelper:NSMethodSignature_toLua forClass:"NSMethodSignature"] ;
    [skin registerPushNSHelper:NSException_toLua       forClass:"NSException"] ;

    luaopen_hs__asm_libobjc_class(L) ;    lua_setfield(L, -2, "class") ;
    luaopen_hs__asm_libobjc_ivar(L) ;     lua_setfield(L, -2, "ivar") ;
    luaopen_hs__asm_libobjc_method(L) ;   lua_setfield(L, -2, "method") ;
    luaopen_hs__asm_libobjc_object(L) ;   lua_setfield(L, -2, "object") ;
    luaopen_hs__asm_libobjc_property(L) ; lua_setfield(L, -2, "property") ;
    luaopen_hs__asm_libobjc_protocol(L) ; lua_setfield(L, -2, "protocol") ;
    luaopen_hs__asm_libobjc_selector(L) ; lua_setfield(L, -2, "selector") ;

    return 1;
}
