#import "luathread.h"

@implementation HSASMBooleanType
-(instancetype)initWithValue:(BOOL)value {
    self = [super init] ;
    if (self) {
        _value = value ;
    }
    return self ;
}

+(instancetype)withTrueValue { return [[HSASMBooleanType alloc] initWithValue:YES] ; }
+(instancetype)withFalseValue { return [[HSASMBooleanType alloc] initWithValue:NO] ; }
@end

// simplified version of what the LuaSkin push/to methods do, since we have more control over the
// types of data being shared
int getHamster(lua_State *L, id obj, NSMutableDictionary *alreadySeen) {
    if ([alreadySeen objectForKey:obj]) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ;
    } else {
        if (!obj || [obj isKindOfClass:[NSNull class]]) {
            lua_pushnil(L) ;
        } else if ([obj isKindOfClass:[NSData class]]) {
            lua_pushlstring(L, [(NSData *)obj bytes], [(NSData *)obj length]) ;
        } else if ([obj isKindOfClass:[NSNumber class]]) {
            NSNumber *number = obj ;
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
                case 'Q': lua_pushinteger(L, (long long)[number unsignedLongLongValue]) ; break ;
                case 'f': lua_pushnumber(L,  [number floatValue]) ; break ;
                case 'd':
                default:  lua_pushnumber(L,  [number doubleValue]) ; break ;
            }
        } else if ([obj isKindOfClass:[NSDictionary class]]) {
            NSArray *keys = [obj allKeys];
            NSArray *values = [obj allValues];
            lua_newtable(L);
            [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(L, LUA_REGISTRYINDEX)] forKey:obj] ;
            lua_rawgeti(L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ;
            for (unsigned long i = 0; i < [keys count]; i++) {
                getHamster(L, [keys objectAtIndex:i], alreadySeen) ;
                getHamster(L, [values objectAtIndex:i], alreadySeen) ;
                lua_settable(L, -3);
            }
        } else if ([obj isKindOfClass:[HSASMBooleanType class]]) {
// Wrapping boolean like this only works here because we know the source and destination are both
// Lua... LuaSkin translates between languages with differing treatments of boolean, so it can't use
// this wrapper.
            lua_pushboolean(L, [(HSASMBooleanType *)obj value]) ;
        } else if ([obj isKindOfClass:[NSArray class]]) {
            lua_newtable(L) ;
            [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(L, LUA_REGISTRYINDEX)] forKey:obj] ;
            lua_rawgeti(L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ;
            for (id item in (NSArray *)obj) {
                getHamster(L, item, alreadySeen) ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
        } else if ([obj isKindOfClass:[NSString class]]) {
            lua_pushstring(L, [obj UTF8String]) ;
        } else {
            lua_pushfstring(L, "** unknown:%s", [[obj description] UTF8String]) ;
        }
    }
    return 1 ;
}

id setHamster(lua_State *L, int idx, NSMutableDictionary *alreadySeen) {
    idx = lua_absindex(L, idx) ;
    if ([alreadySeen objectForKey:[NSValue valueWithPointer:lua_topointer(L, idx)]]) {
        return [alreadySeen objectForKey:[NSValue valueWithPointer:lua_topointer(L, idx)]] ;
    }
    id obj ;
    if (lua_type(L, idx) == LUA_TNIL) {
        obj = nil ;
    } else if (lua_type(L, idx) == LUA_TSTRING) {
        size_t size ;
        unsigned char *junk = (unsigned char *)lua_tolstring(L, idx, &size) ;
        obj = [NSData dataWithBytes:(void *)junk length:size] ;
    } else if (lua_type(L, idx) == LUA_TNUMBER) {
        obj = lua_isinteger(L, idx) ? [NSNumber numberWithLongLong:lua_tointeger(L, idx)] :
                                      [NSNumber numberWithDouble:lua_tonumber(L, idx)] ;
    } else if (lua_type(L, idx) == LUA_TBOOLEAN) {
// Wrapping boolean like this only works here because we know the source and destination are both
// Lua... LuaSkin translates between languages with differing treatments of boolean, so it can't use
// this wrapper.
        obj = lua_toboolean(L, idx) ? [HSASMBooleanType withTrueValue] :
                                      [HSASMBooleanType withFalseValue] ;
    } else if (lua_type(L, idx) == LUA_TTABLE) {
        obj = [[NSMutableDictionary alloc] init] ;
        [alreadySeen setObject:obj forKey:[NSValue valueWithPointer:lua_topointer(L, idx)]] ;

        lua_pushnil(L);
        while (lua_next(L, idx) != 0) {
            id key = setHamster(L, -2, alreadySeen) ;
            id val = setHamster(L, -1, alreadySeen) ;
            if (key) {
                [obj setValue:val forKey:key];
                lua_pop(L, 1);
            } else {
                NSString *errMsg = [NSString stringWithFormat:@"table key (%s) cannot be converted",
                                                             luaL_tolstring(L, -2, NULL)] ;
                lua_pop(L, 3) ; // luaL_tolstring result, lua_next value, and lua_next key
                luaL_error(L, [errMsg UTF8String]) ;
                return nil ;
            }
        }
    } else {
        obj = [NSString stringWithFormat:@"** unsupported type:%s", lua_typename(L, lua_type(L, idx))] ;
    }
    return obj ;
}
