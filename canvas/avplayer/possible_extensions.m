// TODO: AVPlayer Stuff
//   * document
//   * can we tell if a URL is good/bad?
//   * is adding information dumping really all that useful?  this is no longer a good "simple example"
//   * revisit track/step question in assetInformation, add stopByCount, add the following convertors:

// AVAssetTrack:
//     AVAsset                    *asset // probably not, since current use would cause loops
//     CMPersistentTrackID        trackID // typedef int32_t CMPersistentTrackID;
//     NSString                   *mediaType
//     NSArray                    *formatDescriptions
//     BOOL                       enabled
//     BOOL                       playable
//     BOOL                       selfContained
//     long long                  totalSampleDataLength
//     float                      estimatedDataRate
//     NSString                   *languageCode
//     NSString                   *extendedLanguageTag
//     CGSize                     naturalSize
//     CGAffineTransform          preferredTransform
//     float                      preferredVolume
//     float                      nominalFrameRate
//     CMTime                     minFrameDuration
//     BOOL                       requiresFrameReordering
//     NSArray <AVMetadataItem *> *commonMetadata
//     NSArray <NSString *>       *availableMetadataFormats
//     NSArray <AVMetadataItem *> *metadata
//     NSArray <NSString *>       *availableTrackAssociationTypes
//     BOOL                       canProvideSampleCursors
//
//     CMTimeRange                timeRange
//     CMTimeScale                naturalTimeScale
//
//     NSArray <AVAssetTrackSegment *> *segments
//
// AVAssetTrackGroup:
//     NSArray <NSNumber *> *trackIDs
//
// AVAssetTrackSegment:
//     CMTimeMapping timeMapping
//     BOOL          empty
//
// CMTimeRange   // typedef struct { CMTime start; CMTime duration; } CMTimeRange;
// CMTimeScale   // typedef int32_t CMTimeScale;
// CMTimeMapping // typedef struct { CMTimeRange source; CMTimeRange target; } CMTimeMapping;
//
//
// AVPlayerItem.tracks = Array of AVPlayerItemTrack:
//     AVAssetTrack *assetTrack
//     BOOL         enabled
//     float        currentVideoFrameRate

static int avplayer_assetInformation(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMAVPlayerView *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayerItem    *playerItem = playerView.player.currentItem ;

    if (playerItem) {
        [skin pushNSObject:playerItem.asset] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int pushAVMetadataItem(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    AVMetadataItem *metadata = obj ;
    if (metadata) {
        lua_newtable(L) ;
        [skin pushNSObject:metadata.identifier] ;                lua_setfield(L, -2, "identifier") ;
        [skin pushNSObject:metadata.extendedLanguageTag] ;       lua_setfield(L, -2, "extendedLanguageTag") ;
        [skin pushNSObject:metadata.dataType] ;                  lua_setfield(L, -2, "dataType") ;
        [skin pushNSObject:metadata.locale.localeIdentifier] ;   lua_setfield(L, -2, "locale") ;
        [skin pushNSObject:metadata.keySpace] ;                  lua_setfield(L, -2, "keySpace") ;
        [skin pushNSObject:metadata.commonKey] ;                 lua_setfield(L, -2, "commonKey") ;
        lua_pushnumber(L, CMTimeGetSeconds(metadata.duration)) ; lua_setfield(L, -2, "duration") ;
        lua_pushnumber(L, CMTimeGetSeconds(metadata.time)) ;     lua_setfield(L, -2, "time") ;

        [skin pushNSObject:metadata.key withOptions:LS_NSDescribeUnknownTypes] ;
        lua_setfield(L, -2, "key") ;
        [skin pushNSObject:metadata.value withOptions:LS_NSDescribeUnknownTypes] ;
        lua_setfield(L, -2, "value") ;
        [skin pushNSObject:metadata.extraAttributes withOptions:LS_NSDescribeUnknownTypes] ;
        lua_setfield(L, -2, "extraAttributes") ;

// Until we know that the value field isn't usable enough, don't pollute the results (any more than we already do)
//         [skin pushNSObject:metadata.stringValue] ; lua_setfield(L, -2, "stringValue") ;
//         [skin pushNSObject:metadata.numberValue] ; lua_setfield(L, -2, "numberValue") ;
//         [skin pushNSObject:metadata.dateValue] ;   lua_setfield(L, -2, "dateValue") ;
//         [skin pushNSObject:metadata.dataValue] ;   lua_setfield(L, -2, "dataValue") ;
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}

static int pushAVAsset(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    AVAsset *asset = obj ;
    if (asset) {
        lua_newtable(L) ;
        [skin pushNSObject:asset.availableMetadataFormats] ;
        lua_setfield(L, -2, "availableMetadataFormats") ;
        [skin pushNSObject:asset.lyrics] ;
        lua_setfield(L, -2, "lyrics") ;
        [skin pushNSObject:asset.availableMediaCharacteristicsWithMediaSelectionOptions] ;
        lua_setfield(L, -2, "availableMediaCharacteristicsWithMediaSelectionOptions") ;
        lua_pushboolean(L, asset.hasProtectedContent) ; lua_setfield(L, -2, "hasProtectedContent") ;
        lua_pushboolean(L, asset.playable) ; lua_setfield(L, -2, "playable") ;
        lua_pushboolean(L, asset.exportable) ; lua_setfield(L, -2, "exportable") ;
        lua_pushboolean(L, asset.readable) ; lua_setfield(L, -2, "readable") ;
        lua_pushboolean(L, asset.composable) ; lua_setfield(L, -2, "composable") ;
        lua_pushboolean(L, asset.providesPreciseDurationAndTiming) ; lua_setfield(L, -2, "providesPreciseDurationAndTiming") ;
        lua_pushnumber(L, (lua_Number)asset.preferredRate) ; lua_setfield(L, -2, "preferredRate") ;
        lua_pushnumber(L, (lua_Number)asset.preferredVolume) ; lua_setfield(L, -2, "preferredVolume") ;
        lua_pushnumber(L, CMTimeGetSeconds(asset.duration)) ; lua_setfield(L, -2, "duration") ;
        [skin pushNSSize:asset.naturalSize] ; lua_setfield(L, -2, "naturalSize") ;

        NSUInteger restrictions = asset.referenceRestrictions ;
        if (restrictions == AVAssetReferenceRestrictionForbidNone) {
            lua_pushstring(L, "forbidNone") ;
        } else if ((restrictions & AVAssetReferenceRestrictionForbidAll) == AVAssetReferenceRestrictionForbidAll) {
            lua_pushstring(L, "forbidAll") ;
        } else {
            lua_newtable(L) ;
            lua_pushinteger(L, (lua_Integer)restrictions) ; lua_setfield(L, -2, "_raw") ;
            if ((restrictions & AVAssetReferenceRestrictionForbidRemoteReferenceToLocal) == AVAssetReferenceRestrictionForbidRemoteReferenceToLocal) {
                lua_pushstring(L, "forbidRemoteReferenceToLocal") ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
            if ((restrictions & AVAssetReferenceRestrictionForbidLocalReferenceToRemote) == AVAssetReferenceRestrictionForbidLocalReferenceToRemote) {
                lua_pushstring(L, "forbidLocalReferenceToRemote") ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
            if ((restrictions & AVAssetReferenceRestrictionForbidCrossSiteReference) == AVAssetReferenceRestrictionForbidCrossSiteReference) {
                lua_pushstring(L, "forbidCrossSiteReference") ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
            if ((restrictions & AVAssetReferenceRestrictionForbidLocalReferenceToLocal) == AVAssetReferenceRestrictionForbidLocalReferenceToLocal) {
                lua_pushstring(L, "forbidLocalReferenceToLocal") ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
        }
        lua_setfield(L, -2, "referenceRestrictions") ;
        lua_newtable(L) ;
        lua_pushnumber(L, asset.preferredTransform.a) ;  lua_setfield(L, -2, "m11") ;
        lua_pushnumber(L, asset.preferredTransform.b) ;  lua_setfield(L, -2, "m12") ;
        lua_pushnumber(L, asset.preferredTransform.c) ;  lua_setfield(L, -2, "m21") ;
        lua_pushnumber(L, asset.preferredTransform.d) ;  lua_setfield(L, -2, "m22") ;
        lua_pushnumber(L, asset.preferredTransform.tx) ; lua_setfield(L, -2, "tX") ;
        lua_pushnumber(L, asset.preferredTransform.ty) ; lua_setfield(L, -2, "tY") ;
        lua_setfield(L, -2, "preferredTransform") ;

    // skipping for now... we're not supporting tracks yet...
        // NSArray <AVAssetTrack *> *tracks
        // NSArray <AVAssetTrackGroup *> *trackGroups

        lua_newtable(L) ;
        for (NSLocale *aLocale in asset.availableChapterLocales) {
            [skin pushNSObject:aLocale.localeIdentifier] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        lua_setfield(L, -2, "availableChapterLocales") ;

        [skin pushNSObject:asset.metadata] ; lua_setfield(L, -2, "metadata") ;
        [skin pushNSObject:asset.commonMetadata] ; lua_setfield(L, -2, "commonMetadata") ;
        [skin pushNSObject:asset.creationDate] ; lua_setfield(L, -2, "creationDate") ;
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}



    {"assetInformation",      avplayer_assetInformation},

    [skin registerPushNSHelper:pushAVAsset        forClass:"AVAsset"] ;
    [skin registerPushNSHelper:pushAVMetadataItem forClass:"AVMetadataItem"] ;

