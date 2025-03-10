@import Cocoa ;
@import LuaSkin ;
@import SceneKit ;

// TODO:    move to object model
//              lines and points validated as added
//              faces/edges created as they are built?
//              see libpmp?

static const char * const USERDATA_TAG = "hs._asm.dimensional" ;
static LSRefTable         refTable     = LUA_NOREF ;

// #define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_anyObjectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

#pragma mark - Support Functions and Classes -

static CGFloat vector4magnitude(SCNVector4 vector) {
    return sqrt(pow(vector.x, 2) + pow(vector.y, 2) + pow(vector.z, 2) + pow(vector.w, 2)) ;
}

static SCNVector4 vector4normalized(SCNVector4 vector) {
    CGFloat magnitude = vector4magnitude(vector) ;
    return SCNVector4Make(vector.x / magnitude, vector.y / magnitude, vector.z / magnitude, vector.w / magnitude) ;
}

static CGFloat vector3magnitude(SCNVector3 vector) {
    return sqrt(pow(vector.x, 2) + pow(vector.y, 2) + pow(vector.z, 2)) ;
}

static SCNVector3 vector3normalized(SCNVector3 vector) {
    CGFloat magnitude = vector3magnitude(vector) ;
    return SCNVector3Make(vector.x / magnitude, vector.y / magnitude, vector.z / magnitude) ;
}

// static SCNVector3 vector3crossProduct(SCNVector3 vec1, SCNVector3 vec2) {
//     return SCNVector3Make(
//         vec1.y * vec2.z - vec1.z * vec2.y,
//         vec1.z * vec2.x - vec1.x * vec2.z,
//         vec1.x * vec2.y - vec1.y * vec2.x,
//     ) ;
// }

// static CGFloat vector3dotProduct(SCNVector3 vec1, SCNVector3 vec2) {
//     return vec1.x * vec2.x + vec1.y * vec2.y + vec1.z * vec2.z ;
// }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"
static BOOL validate_luaTable(lua_State   *L,
                              int         idx,
                              NSUInteger  itemCount,
                              NSUInteger  componentsPerItem,
                              BOOL        isInteger,
                              lua_Integer maxInt) {

// // aiming for fastest here and right now I'm pretty well sanitizing input - may need to add
// // separate validation function if end up going more generic/public with this, as it does have
// // some impact at higher line/point counts.,,
//
//     lua_Integer numItems = luaL_len(L, idx) ;
//     if (itemCount == 0) itemCount = (NSUInteger)numItems ;
//
//     if (numItems == (lua_Integer)itemCount) {
//         for (NSUInteger i = 0 ; i < itemCount ; i++) {
//             if (lua_geti(L, idx, (lua_Integer)(i + 1)) == LUA_TTABLE) {
//                 lua_Integer numComponents = luaL_len(L, -1) ;
//                 if (componentsPerItem == 0) componentsPerItem = (NSUInteger)numComponents ;
//
//                 if (numComponents == (lua_Integer)componentsPerItem) {
//                     for (NSUInteger j = 0 ; j < componentsPerItem ; j++) {
//                         if (lua_geti(L, -1, (lua_Integer)(j + 1)) == LUA_TNUMBER) {
//                             if (isInteger) {
//                                 if (lua_isinteger(L, -1)) {
//                                     lua_Integer t = lua_tointeger(L, -1) ;
//                                     if (t < 1 || t > (maxInt == 0 ? NSMaxInteger : maxInt)) {
//                                         lua_pop(L, 2) ;
//                                         if (maxInt == 0) {
//                                             lua_pushfstring(L, "expected integer greater than 0") ;
//                                         } else {
//                                             lua_pushfstring(L, "expected integer between 1 and %d inclusive for component %d of index %d", maxInt, j + 1, i + 1) ;
//                                         }
//                                         break ;
//                                     }
//                                 } else {
//                                     lua_pop(L, 2) ;
//                                     lua_pushfstring(L, "expected integer for component %d of index %d", j + 1, i + 1) ;
//                                     break ;
//                                 }
//                             }
//                             lua_pop(L, 1) ;
//                         } else {
//                             lua_pop(L, 2) ;
//                             lua_pushfstring(L, "expected %s for component %d of index %d", (isInteger ? "integer" : "number"), j + 1, i + 1) ;
//                             break ;
//                         }
//                     }
//                     if (lua_type(L, -1) == LUA_TSTRING) {
//                         break ;
//                     }
//                 } else {
//                     lua_pop(L, 1) ;
//                     lua_pushfstring(L, "expected table at index %d to contain %d components", i + 1, componentsPerItem) ;
//                     break ;
//                 }
//                 lua_pop(L, 1) ;
//             } else {
//                 lua_pop(L, 1) ;
//                 lua_pushfstring(L, "expected table at index %d", i + 1) ;
//                 break ;
//             }
//         }
//         if (lua_type(L, -1) != LUA_TSTRING) lua_pushboolean(L, YES) ;
//     } else {
//         lua_pushfstring(L, "expected table of %d items", itemCount) ;
//     }
//
//     return (lua_type(L, -1) != LUA_TSTRING) ;
    return YES ;
}
#pragma clang diagnostic pop

#pragma mark - Module Functions -

static int dimensional_generateSceneKitObject(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE,
                    LS_TTABLE,
                    LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.node",
                    LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.node",
                    LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.node",
                    LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.node",
                    LS_TBREAK] ;
    NSArray *pointsArray   = [skin toNSObjectAtIndex:1] ;
    NSArray *linesArray    = [skin toNSObjectAtIndex:2] ;
    SCNNode *pointsNode    = [skin toNSObjectAtIndex:3] ;
    SCNNode *linesNode     = [skin toNSObjectAtIndex:4] ;
    SCNNode *pointTemplate = [skin toNSObjectAtIndex:5] ;
    SCNNode *lineTemplate  = [skin toNSObjectAtIndex:6] ;

    NSString *errMsg = nil ;
    if ([pointsArray isKindOfClass:[NSArray class]]) {
        if (!validate_luaTable(L, 1, 0, 0, NO, 0)) {
            errMsg = [NSString stringWithUTF8String:lua_tostring(L, -1)] ;
        }
        lua_pop(L, 1) ;
    } else {
        errMsg = @"expected array type table" ;
    }
    if (errMsg) return luaL_argerror(L, 1, errMsg.UTF8String) ;

    if ([linesArray isKindOfClass:[NSArray class]]) {
        if (!validate_luaTable(L, 2, 0, 2, YES, (lua_Integer)pointsArray.count)) {
            errMsg = [NSString stringWithUTF8String:lua_tostring(L, -1)] ;
        }
        lua_pop(L, 1) ;
    } else {
        errMsg = @"expected array type table" ;
    }
    if (errMsg) return luaL_argerror(L, 2, errMsg.UTF8String) ;

    BOOL createNewPoints = (pointsNode.childNodes.count != pointsArray.count) ;
    BOOL createNewLines  = (linesNode.childNodes.count  != linesArray.count) ;

    if (createNewPoints) {
        while (pointsNode.childNodes.count > 0) {
            [(SCNNode *)pointsNode.childNodes.lastObject removeFromParentNode] ;
        }
    }
    if (createNewLines) {
        while (linesNode.childNodes.count > 0) {
            [(SCNNode *)linesNode.childNodes.lastObject removeFromParentNode] ;
        }
    }

    NSUInteger idx = 0 ;
    for (NSArray *point in pointsArray) {
        NSNumber *x = point.firstObject ;
        NSNumber *y = [point objectAtIndex:1] ;
        NSNumber *z = point.lastObject ;

        SCNNode *thePoint = createNewPoints ? [pointTemplate clone] : pointsNode.childNodes[idx] ;
        thePoint.worldPosition = SCNVector3Make(x.doubleValue, y.doubleValue, z.doubleValue) ;
        if (createNewPoints) {
            thePoint.name = [NSString stringWithFormat:@"point%lu", idx] ;
            [pointsNode addChildNode:thePoint] ;
        }

        idx++ ;
    }

    idx = 0 ;
    for (NSArray *line in linesArray) {
        NSNumber *from = line.firstObject ;
        NSNumber *to   = line.lastObject ;
        NSArray  *p1   = pointsArray[from.unsignedIntegerValue - 1] ;
        NSArray  *p2   = pointsArray[to.unsignedIntegerValue - 1] ;

        NSNumber *p1x  = p1[0] ;
        NSNumber *p1y  = p1[1] ;
        NSNumber *p1z  = p1[2] ;
        NSNumber *p2x  = p2[0] ;
        NSNumber *p2y  = p2[1] ;
        NSNumber *p2z  = p2[2] ;

        SCNVector3 v1 = SCNVector3Make(p1x.doubleValue, p1y.doubleValue, p1z.doubleValue) ;
        SCNVector3 v2 = SCNVector3Make(p2x.doubleValue, p2y.doubleValue, p2z.doubleValue) ;

        CGFloat height = vector3magnitude(SCNVector3Make(v2.x - v1.x, v2.y - v1.y, v2.z - v1.z)) ;

        SCNNode     *theLine      = createNewLines ? [lineTemplate clone] : linesNode.childNodes[idx] ;
        SCNCylinder *lineGeometry = (SCNCylinder *)(createNewLines ? theLine.geometry.copy : theLine.geometry) ;
        if (createNewLines) {
            theLine.name = [NSString stringWithFormat:@"line%lu", idx] ;
            theLine.geometry = lineGeometry ;
            [linesNode addChildNode:theLine] ;
        }
        lineGeometry.height = height ;
        theLine.worldPosition = SCNVector3Make((v1.x + v2.x) / 2, (v1.y + v2.y) / 2, (v1.z + v2.z) / 2) ;

        // see https://stackoverflow.com/a/1171995 and https://stackoverflow.com/a/11741520

        SCNVector3 dir = vector3normalized(
            SCNVector3Make(v2.x - v1.x, v2.y - v1.y, v2.z - v1.z)
        ) ;

        SCNQuaternion q ;
//         SCNVector3 unitY    = SCNVector3Make(0,  1, 0) ;
        SCNVector3 unitNegY = SCNVector3Make(0, -1, 0) ;

        // if 180 degrees, gimbal lock, so handle separately
        if (SCNVector3EqualToVector3(dir, unitNegY)) {
//             SCNVector3 t = vector3crossProduct(v1, unitY) ;
            SCNVector3 t = SCNVector3Make(-v1.z, 0, v1.x) ;
            q = SCNVector4Make(t.x, t.y, t.z, 0) ;
        } else {
//             SCNVector3 t = vector3crossProduct(unitY, dir) ;
            SCNVector3 t = SCNVector3Make(dir.z, 0, -dir.x) ;
            q = SCNVector4Make(
                t.x,
                t.y,
                t.z,
//                 vector3magnitude(dir) * vector3magnitude(unitY) + vector3dotProduct(unitY, dir)
                vector3magnitude(dir) + dir.y
            ) ;
            idx++ ;
        }

        theLine.orientation = vector4normalized(q) ;
    }
    return 0 ;
}

// should check for 3 and 4 line faces
static int dimensional_facesFromLines(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE,  // lines
                    LS_TBREAK] ;

    NSArray *linesArray    = [skin toNSObjectAtIndex:1] ;

    NSString *errMsg = nil ;
    if ([linesArray isKindOfClass:[NSArray class]]) {
        if (!validate_luaTable(L, 1, 0, 2, YES, 0)) {
            errMsg = [NSString stringWithUTF8String:lua_tostring(L, -1)] ;
        }
        lua_pop(L, 1) ;
    } else {
        errMsg = @"expected array type table" ;
    }
    if (errMsg) return luaL_argerror(L, 1, errMsg.UTF8String) ;

    NSUInteger     lineCount = linesArray.count ;
    NSMutableArray *faces    = [NSMutableArray array] ;

// NSUInteger totalCount = 0 ;
// double     timeAvg    = 0.0 ;

    for (NSUInteger a = 0; a < lineCount ; a++) {
        for (NSUInteger b = 0; b < lineCount ; b++) {
            if (a == b) continue ;
            for (NSUInteger c = 0; c < lineCount ; c++) {
                if ((a == c) || (b == c)) continue ;
// TODO: check for three point sides?
                for (NSUInteger d = 0; d < lineCount ; d++) {
                    if ((a == d) || (b == d) || (c == d)) continue ;
// NSDate *start = [NSDate now] ;
// [LuaSkin logInfo:@"%lu %lu %lu %lu", a, b, c, d] ;
                    lua_Integer a1 = ((NSNumber *)((NSArray *)linesArray[a])[0]).integerValue ;
                    lua_Integer a2 = ((NSNumber *)((NSArray *)linesArray[a])[1]).integerValue ;
                    lua_Integer b1 = ((NSNumber *)((NSArray *)linesArray[b])[0]).integerValue ;
                    lua_Integer b2 = ((NSNumber *)((NSArray *)linesArray[b])[1]).integerValue ;
                    lua_Integer c1 = ((NSNumber *)((NSArray *)linesArray[c])[0]).integerValue ;
                    lua_Integer c2 = ((NSNumber *)((NSArray *)linesArray[c])[1]).integerValue ;
                    lua_Integer d1 = ((NSNumber *)((NSArray *)linesArray[d])[0]).integerValue ;
                    lua_Integer d2 = ((NSNumber *)((NSArray *)linesArray[d])[1]).integerValue ;
// [LuaSkin logInfo:@"%ld %ld %ld %ld %ld %ld %ld %ld", a1, a2, b1, b2, c1, c2, d1, d2] ;
                    if ((d1 == a1 || d1 == a2 || d2 == a1 || d2 == a2) &&
                        (a1 == b1 || a1 == b2 || a2 == b1 || a2 == b2) &&
                        (b1 == c1 || b1 == c2 || b2 == c1 || b2 == c2) &&
                        (c1 == d1 || c1 == d2 || c2 == d1 || c2 == d2))
                    {
                        // is it actually a closed path?
                        NSMutableDictionary *pointCounts = [NSMutableDictionary dictionary] ;
                        pointCounts[@(a1)] = @((pointCounts[@(a1)] ? ((NSNumber *)pointCounts[@(a1)]).integerValue : 0) + 1) ;
                        pointCounts[@(a2)] = @((pointCounts[@(a2)] ? ((NSNumber *)pointCounts[@(a2)]).integerValue : 0) + 1) ;
                        pointCounts[@(b1)] = @((pointCounts[@(b1)] ? ((NSNumber *)pointCounts[@(b1)]).integerValue : 0) + 1) ;
                        pointCounts[@(b2)] = @((pointCounts[@(b2)] ? ((NSNumber *)pointCounts[@(b2)]).integerValue : 0) + 1) ;
                        pointCounts[@(c1)] = @((pointCounts[@(c1)] ? ((NSNumber *)pointCounts[@(c1)]).integerValue : 0) + 1) ;
                        pointCounts[@(c2)] = @((pointCounts[@(c2)] ? ((NSNumber *)pointCounts[@(c2)]).integerValue : 0) + 1) ;
                        pointCounts[@(d1)] = @((pointCounts[@(d1)] ? ((NSNumber *)pointCounts[@(d1)]).integerValue : 0) + 1) ;
                        pointCounts[@(d2)] = @((pointCounts[@(d2)] ? ((NSNumber *)pointCounts[@(d2)]).integerValue : 0) + 1) ;
// [LuaSkin logInfo:@"%@", pointCounts];
                        __block BOOL isBad = NO ;
                        [pointCounts enumerateKeysAndObjectsUsingBlock:^(__unused NSNumber *key, NSNumber *val, BOOL *stop) {
                            isBad = (val.integerValue != 2) ;
                            *stop = isBad ;
                        }] ;

                        // if not isBad, then check if it's one we've already captured
                        if (!isBad) {
                            __block BOOL alreadySeen = NO ;
                            [faces enumerateObjectsUsingBlock:^(NSArray *val, __unused NSUInteger idx, BOOL *stop) {
                                alreadySeen = [val containsObject:@(a + 1)] &&
                                              [val containsObject:@(b + 1)] &&
                                              [val containsObject:@(c + 1)] &&
                                              [val containsObject:@(d + 1)] ;
                                *stop = alreadySeen ;
                            }] ;

                            if (!alreadySeen) [faces addObject:@[ @(a + 1), @(b + 1), @(c + 1), @(d + 1) ]] ;
                        }
                    }
// timeAvg = timeAvg + start.timeIntervalSinceNow ;
// totalCount++ ;
                }
            }
        }
    }

// [LuaSkin logInfo:@"%f %ld (∂t = %f)", timeAvg, totalCount, (timeAvg / (double)totalCount)] ;

    [skin pushNSObject:faces] ;
    return 1 ;
}

// static int dimensional_mapLinesToFaces(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TTABLE,                // lines
//                     LS_TTABLE | LS_TOPTIONAL, // faces (or will call dimensional_facesFromLines)
//                     LS_TBREAK] ;
//
//     return 1 ;
// }
//
// static int dimensional_catmullClarkSubdivision(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TTABLE,                // points
//                     LS_TTABLE,                // lines
//                     LS_TTABLE | LS_TOPTIONAL, // faces (or will call dimensional_facesFromLines)
//                     LS_TBREAK] ;
//
//     return 1 ;
// }
//
// static int dimensional_projectCoordinatesDown(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TTABLE,                  // points table
//                     LS_TNUMBER,                 // eyeDistance
//                     LS_TNUMBER | LS_TOPTIONAL,  // scale (default 1)
//                     LS_TNUMBER | LS_TOPTIONAL,  // offset (default 0)
//                     LS_TBREAK] ;
//
//     return 1 ;
// }

#pragma mark - Module Methods -

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -

#pragma mark - Hammerspoon/Lua Infrastructure -

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// // Metatable for userdata objects
// static const luaL_Reg userdata_metaLib[] = {
//     {"__tostring", userdata_tostring},
//     {"__eq",       userdata_eq},
//     {"__gc",       userdata_gc},
//     {NULL, NULL}
// };

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"generate3dObject",         dimensional_generateSceneKitObject},
    {"facesFromLines",           dimensional_facesFromLines},
//     {"mapLinesToFaces",          dimensional_mapLinesToFaces},
//     {"catmullClarkSubdivision",  dimensional_catmullClarkSubdivision},
//     {"projectCoordinatesDown",   dimensional_projectCoordinatesDown},
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL, NULL}
// };

int luaopen_hs__asm_libdimensional(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:USERDATA_TAG
                           functions:moduleLib
                       metaFunctions:nil] ; // or module_metaLib

    return 1;
}
