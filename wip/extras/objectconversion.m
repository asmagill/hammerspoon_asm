#import "objectconversion.h"

// Recursion depth needs to be setable at call time, not necesarily by lua, but
// definately by the calling C function
//
// Recursive depth needs to CLS_LOG? printToConsole?
// Should it set keys (as it does) or just return?
//
// Recursion limit necessary in NS->Lua functions?
//
// Figure out NSNumber->Integer/Real in nsnumber_tolua
//      maybe... need better test than UserDefaults
//
// Test with in use cases... hs.settings, wherelse?
//
// Offer versions which allow you to provide your own decoders

// NSObject to/from Lua
#define maxParseDepth 10

static int parseDepth = 0 ;

// Horked and modified from: http://dev-tricks.net/check-if-a-string-is-valid-utf8
// returns 0 if good utf8, anything else, barf
size_t is_utf8(unsigned char *str, size_t len) {
    size_t i = 0;

    while (i < len) {
        if (str[i] <= 0x7F) { /* 00..7F */
            i += 1;
        } else if (str[i] >= 0xC2 && str[i] <= 0xDF) { /* C2..DF 80..BF */
            if (i + 1 < len) { /* Expect a 2nd byte */
                if (str[i + 1] < 0x80 || str[i + 1] > 0xBF) return i + 1;
            } else
                return i;
            i += 2;
        } else if (str[i] == 0xE0) { /* E0 A0..BF 80..BF */
            if (i + 2 < len) { /* Expect a 2nd and 3rd byte */
                if (str[i + 1] < 0xA0 || str[i + 1] > 0xBF) return i + 1;
                if (str[i + 2] < 0x80 || str[i + 2] > 0xBF) return i + 2;
            } else
                return i;
            i += 3;
        } else if (str[i] >= 0xE1 && str[i] <= 0xEC) { /* E1..EC 80..BF 80..BF */
            if (i + 2 < len) { /* Expect a 2nd and 3rd byte */
                if (str[i + 1] < 0x80 || str[i + 1] > 0xBF) return i + 1;
                if (str[i + 2] < 0x80 || str[i + 2] > 0xBF) return i + 2;
            } else
                return i;
            i += 3;
        } else if (str[i] == 0xED) { /* ED 80..9F 80..BF */
            if (i + 2 < len) { /* Expect a 2nd and 3rd byte */
                if (str[i + 1] < 0x80 || str[i + 1] > 0x9F) return i + 1;
                if (str[i + 2] < 0x80 || str[i + 2] > 0xBF) return i + 2;
            } else
                return i;
            i += 3;
        } else if (str[i] >= 0xEE && str[i] <= 0xEF) { /* EE..EF 80..BF 80..BF */
            if (i + 2 < len) { /* Expect a 2nd and 3rd byte */
                if (str[i + 1] < 0x80 || str[i + 1] > 0xBF) return i + 1;
                if (str[i + 2] < 0x80 || str[i + 2] > 0xBF) return i + 2;
            } else
                return i;
            i += 3;
        } else if (str[i] == 0xF0) { /* F0 90..BF 80..BF 80..BF */
            if (i + 3 < len) { /* Expect a 2nd, 3rd 3th byte */
                if (str[i + 1] < 0x90 || str[i + 1] > 0xBF) return i + 1;
                if (str[i + 2] < 0x80 || str[i + 2] > 0xBF) return i + 2;
                if (str[i + 3] < 0x80 || str[i + 3] > 0xBF) return i + 3;
            } else
                return i;
            i += 4;
        } else if (str[i] >= 0xF1 && str[i] <= 0xF3) { /* F1..F3 80..BF 80..BF 80..BF */
            if (i + 3 < len) { /* Expect a 2nd, 3rd 3th byte */
                if (str[i + 1] < 0x80 || str[i + 1] > 0xBF) return i + 1;
                if (str[i + 2] < 0x80 || str[i + 2] > 0xBF) return i + 2;
                if (str[i + 3] < 0x80 || str[i + 3] > 0xBF) return i + 3;
            } else
                return i;
            i += 4;
        } else if (str[i] == 0xF4) { /* F4 80..8F 80..BF 80..BF */
            if (i + 3 < len) { /* Expect a 2nd, 3rd 3th byte */
                if (str[i + 1] < 0x80 || str[i + 1] > 0x8F) return i + 1;
                if (str[i + 2] < 0x80 || str[i + 2] > 0xBF) return i + 2;
                if (str[i + 3] < 0x80 || str[i + 3] > 0xBF) return i + 3;
            } else
                return i;
            i += 4;
        } else
            return i;
    }
    return 0;
}

id luanumber_tons(lua_State *L, int idx) {
    if (lua_isinteger(L, idx))
        return @(lua_tointeger(L, idx)) ;
    else
        return @(lua_tonumber(L, idx));
}
id luastring_tons(lua_State *L, int idx) {
    size_t size ;
    unsigned char *junk = (unsigned char *)lua_tolstring(L, idx, &size) ;

    if (is_utf8(junk, size) == 0) {
        return [NSString stringWithUTF8String:(char *)junk];
    } else {
        return [NSData dataWithBytes:(void *)junk length:size] ;
    }
}
id luanil_tons(lua_State __unused *L, int __unused idx) {
    return [NSNull null] ;
}
id luabool_tons(lua_State *L, int idx) {
    return lua_toboolean(L, idx) ? (id)kCFBooleanTrue : (id)kCFBooleanFalse;
}
id luatable_tons(lua_State *L, int idx) {
    NSMutableDictionary* numerics    = [NSMutableDictionary dictionary];
    NSMutableDictionary* nonNumerics = [NSMutableDictionary dictionary];
    NSMutableIndexSet*   numericKeys = [NSMutableIndexSet indexSet];
    lua_pushnil(L);
    while (lua_next(L, idx) != 0) {
        id key = lua_toNSObject(L, -2);
        id val = lua_toNSObject(L, lua_gettop(L));
        if ([key isKindOfClass: [NSNumber class]] && [key intValue] >= 0) {
            [numericKeys addIndex:[key unsignedIntValue]];
            [numerics setValue:val forKey:key];
        }
        [nonNumerics setValue:val forKey:key];
        lua_pop(L, 1);
    }
    if (([numerics count] == 0) || ([numerics count] != [nonNumerics count])) {
        return [nonNumerics copy];
    } else {
        NSMutableArray* numberArray = [NSMutableArray array];
        for (NSUInteger i = 1; i <= [numericKeys lastIndex]; i++) {
            [numberArray addObject:(
                [numerics objectForKey:[NSNumber numberWithUnsignedInteger:i]] ?
                    [numerics objectForKey:[NSNumber numberWithUnsignedInteger:i]] : [NSNull null]
            )];
        }
        return [numberArray copy];
    }
}
id luaunknown_tons(lua_State *L, int idx) {
    return [NSString stringWithFormat:@"%s: %p", luaL_typename(L, idx), lua_topointer(L, idx)];
}

lua2nsHelpers luaobj_tons_helpers[] = {
//  LUA_TYPE        HELPER_FUNCTION
    {LUA_TNUMBER,   luanumber_tons },
    {LUA_TSTRING,   luastring_tons },
    {LUA_TNIL,      luanil_tons },
    {LUA_TBOOLEAN,  luabool_tons },
    {LUA_TTABLE,    luatable_tons },
    {-1,            luaunknown_tons},
    {INT_MIN,       NULL}
};

// Simple conversion from basic lua types to the corresponding NSObject type.
// This conversion is a straight through conversion based upon lua_type(L, idx) only
// and will replicate tables which share the same address (i.e. are the same) in Lua.
// It will stop at a depth specified in maxParseDepth (default 10) to prevent infinite
// loops.  It returns the standard __tostring value of any type it doesn't recognize.
//
// Numeric only tables are converted to NSArray, with [NSNull null] as the entry for
// missing indexes and any table with even 1 non-numeric key (even the n from table.pack)
// will be converted to NSDictionary, so if this matters, null them out first.

id lua_toNSObject(lua_State* L, int idx) {
    parseDepth++ ;
    if (parseDepth > maxParseDepth) {
        parseDepth-- ;
        return [NSString stringWithFormat:@"-- max recursion depth of %d reached", maxParseDepth];
    }

    idx = lua_absindex(L,idx);
    switch (lua_type(L, idx)) {
        case LUA_TNUMBER:
            if (lua_isinteger(L, idx)) {
                parseDepth-- ;
                return @(lua_tointeger(L, idx)) ;
            } else {
                parseDepth-- ;
                return @(lua_tonumber(L, idx));
            }
            break ;
        case LUA_TSTRING:
            parseDepth-- ;
            size_t size ;
            unsigned char *junk = (unsigned char *)lua_tolstring(L, idx, &size) ;

            if (is_utf8(junk, size) == 0) {
                return [NSString stringWithUTF8String:(char *)junk];
            } else {
                return [NSData dataWithBytes:(void *)junk length:size] ;
            }
            break ;
        case LUA_TNIL:
            parseDepth-- ;
            return [NSNull null];
            break ;
        case LUA_TBOOLEAN:
            parseDepth-- ;
            return lua_toboolean(L, idx) ? (id)kCFBooleanTrue : (id)kCFBooleanFalse;
            break ;
        case LUA_TTABLE: {
                NSMutableDictionary* numerics    = [NSMutableDictionary dictionary];
                NSMutableDictionary* nonNumerics = [NSMutableDictionary dictionary];
                NSMutableIndexSet*   numericKeys = [NSMutableIndexSet indexSet];
                lua_pushnil(L);
                while (lua_next(L, idx) != 0) {
                    id key = lua_toNSObject(L, -2);
                    id val = lua_toNSObject(L, lua_gettop(L));
                    if ([key isKindOfClass: [NSNumber class]] && [key intValue] >= 0) {
                        [numericKeys addIndex:[key unsignedIntValue]];
                        [numerics setValue:val forKey:key];
                    }
                    [nonNumerics setValue:val forKey:key];
                    lua_pop(L, 1);
                }
                if (([numerics count] == 0) || ([numerics count] != [nonNumerics count])) {
                    parseDepth-- ;
                    return [nonNumerics copy];
                } else {
                    NSMutableArray* numberArray = [NSMutableArray array];
                    for (NSUInteger i = 1; i <= [numericKeys lastIndex]; i++) {
                        [numberArray addObject:(
                            [numerics objectForKey:[NSNumber numberWithUnsignedInteger:i]] ?
                                [numerics objectForKey:[NSNumber numberWithUnsignedInteger:i]] : [NSNull null]
                        )];
                    }
                    parseDepth-- ;
                    return [numberArray copy];
                }
            }
            break ;
        default: // mimic lua's tostring semantics for the other types.
            parseDepth-- ;
            return [NSString stringWithFormat:@"%s: %p", luaL_typename(L, idx), lua_topointer(L, idx)];
            break ;
    }
    return nil;
}



// Forward declaration since NSArray and such require recursion...
int NSObject_tolua(lua_State *L, id obj) ;

// simplistic maybe, but useful to be called individually if I ever put these into hammerspoon.h
// or a hammerspoon framework.
int nsnull_tolua(lua_State *L, __unused id obj) {
    lua_pushnil(L);
    return 1 ;
}
int nsnumber_tolua(lua_State *L, id obj) {
    NSNumber    *number = obj ;
    if (number == (id)kCFBooleanTrue)
        lua_pushboolean(L, YES);
    else if (number == (id)kCFBooleanFalse)
        lua_pushboolean(L, NO);
    else {
//         lua_pushnumber(L, [number doubleValue]);
        switch([number objCType][0]) {
            case 'c': lua_pushinteger(L, [number charValue]) ; break ;
            case 'C': lua_pushinteger(L, [number unsignedCharValue]) ; break ;

            case 'i': lua_pushinteger(L, [number intValue]) ; break ;
            case 'I': lua_pushinteger(L, [number unsignedIntValue]) ; break ;

            case 's': lua_pushinteger(L, [number shortValue]) ; break ;
            case 'S': lua_pushinteger(L, [number unsignedShortValue]) ; break ;

            case 'l': lua_pushinteger(L, [number longValue]) ; break ;
            case 'L': lua_pushinteger(L, (long long)[number unsignedLongValue]) ; break ;

            case 'q': lua_pushinteger(L, [number longLongValue]) ; break ;

            // Lua only does signed long long, not unsigned, so we keep it an integer as
            // far as we can; after that, sorry -- lua has to treat it as a number (real)
            // or it will wrap and we lose the whole point of being unsigned.
            case 'Q': if ([number unsignedLongLongValue] < 0x8000000000000000)
                          lua_pushinteger(L, (long long)[number unsignedLongLongValue]) ;
                      else
                          lua_pushnumber(L, [number unsignedLongLongValue]) ;
                      break ;

            case 'f': lua_pushnumber(L,  [number floatValue]) ; break ;
            case 'd': lua_pushnumber(L,  [number doubleValue]) ; break ;

            default:
                CLS_NSLOG(@"Unrecognized numerical type '%s' for '%@'", [number objCType], number) ;
                printToConsole(L, (char *)[[NSString stringWithFormat:@"Unrecognized numerical type '%s' for '%@'", [number objCType], number] UTF8String]) ;
                lua_pushnumber(L, [number doubleValue]) ;
                break ;
        }
    }
    return 1 ;
}
int nsstring_tolua(lua_State *L, id obj) {
    NSString *string = obj;
    lua_pushstring(L, [string UTF8String]);
    return 1 ;
}
int nsdata_tolua(lua_State *L, id obj) {
    NSData *data = obj;
    lua_pushlstring(L, [data bytes], [data length]) ;
    return 1 ;
}
int nsdate_tolua(lua_State *L, id obj) {
    NSDate *date = obj ;
    lua_pushnumber(L, [date timeIntervalSince1970]);
    return 1 ;
}
int nsarray_tolua(lua_State *L, id obj) {
    NSArray* list = obj;
    lua_newtable(L);
    for (id item in list) {
        NSObject_tolua(L, item);
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    return 1 ;
}
int nsset_tolua(lua_State *L, id obj) {
    NSSet* list = obj;
    lua_newtable(L);
    for (id item in list) {
        NSObject_tolua(L, item);
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    return 1 ;
}
int nsdictionary_tolua(lua_State *L, id obj) {
    NSArray *keys = [obj allKeys];
    NSArray *values = [obj allValues];
    lua_newtable(L);
    for (unsigned long i = 0; i < [keys count]; i++) {
//        NSLog(@"%@", [keys objectAtIndex:i]) ;
        NSObject_tolua(L, [keys objectAtIndex:i]);
        NSObject_tolua(L, [values objectAtIndex:i]);
        lua_settable(L, -3);
    }
    return 1 ;
}
int nsunknown_tolua(lua_State *L, id obj) {
    lua_pushstring(L, [[NSString stringWithFormat:@"Unknown object: %@", obj] UTF8String]) ;
    return 1 ;
}

// The first class an object returns YES to will be used. "NSObject" is supposed to
// match all of them, so we use it as a "default".
ns2luaHelpers nsobj_tolua_helpers[] = {
//  CLASS_NAME        HELPER_FUNCTION
    {"NSNull",        nsnull_tolua },
    {"NSNumber",      nsnumber_tolua },
    {"NSString",      nsstring_tolua },
    {"NSData",        nsdata_tolua },
    {"NSDate",        nsdate_tolua },
    {"NSArray",       nsarray_tolua },
    {"NSSet",         nsset_tolua },
    {"NSDictionary",  nsdictionary_tolua },

    {"NSObject",      nsunknown_tolua },
    {NULL,            NULL}
};

int NSObject_tolua(lua_State *L, id obj) {
    if (obj == nil) {
    // special case -- shouldn't happen (things should return [NSNull null]), but it does...
        lua_pushnil(L) ;
    } else {
        BOOL found = NO ;
        for( ns2luaHelpers *pos = nsobj_tolua_helpers ; pos->name != NULL ; pos++) {
            if ([obj isKindOfClass: NSClassFromString([NSString stringWithUTF8String:pos->name])]) {
                found = YES ;
                pos->func(L, obj) ;
                break ;
            }
        }
        if (!found) {
            CLS_NSLOG(@"Uncaught NSObject type for '%@'", obj) ;
            printToConsole(L, (char *)[[NSString stringWithFormat:@"Uncaught NSObject type for '%@'", obj] UTF8String]) ;
            nsunknown_tolua(L, obj) ;
        }
    }
    return 1 ;
}

// int luaopen_hs__asm_extras_objectconversion(lua_State* L) {
//     lua_pushstring(L, "C helper library to be loaded at runtime") ;
//     return 1;
// }
