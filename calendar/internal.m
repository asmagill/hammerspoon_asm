@import Cocoa ;
@import EventKit ;
@import LuaSkin ;

#if __clang_major__ < 8
#import "xcode7.h"
#endif

static const char *USERDATA_TAG = "hs._asm.calendar" ;
static int        refTable      = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

typedef enum {
  No = 0,
  Yes,
  Undefined
} triStateBOOL;

#pragma mark - Support Functions and Classes

static NSDate* date_from_string(NSString* dateString) {
    // rfc3339 (Internet Date/Time) formated date.  More or less.
    NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [rfc3339DateFormatter setLocale:enUSPOSIXLocale];
    [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
    [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

    NSDate *date = [rfc3339DateFormatter dateFromString:dateString];
    return date;
}

@interface ASMCalendar : NSObject
@property (readonly) EKEventStore *store ;
@property (readonly) NSCalendar   *calendar ;
@property (readonly) triStateBOOL connected ;
@property (readonly) EKEntityType entityType ;
@property            id           reminderFetchIdentifier ;
@property            int          changeNotificationFnRef ;
@end

@implementation ASMCalendar

- (instancetype)initFor:(EKEntityType)type withFunctionRef:(int)fnRef {
    self = [super init] ;
    if (self) {
        _calendar                = [NSCalendar autoupdatingCurrentCalendar] ;
        _connected               = Undefined ;
        _entityType              = type ;
        _changeNotificationFnRef = LUA_NOREF ;
        _reminderFetchIdentifier = nil ;

        _store = [EKEventStore new];
        [_store requestAccessToEntityType:type completion:^(BOOL granted, NSError *error) {
            self->_connected = granted ? Yes : No ;
            if (fnRef != LUA_NOREF) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    LuaSkin   *skin = [LuaSkin shared] ;
                    lua_State *L    = [skin L] ;
                    int       args = 2 ;

                    [skin pushLuaRef:refTable ref:fnRef] ;
                    [skin pushNSObject:self] ;
                    lua_pushboolean(L, granted) ;
                    if (error) {
                        args++ ;
                        [skin pushNSObject:[error localizedDescription]] ;
                    }
                    if (![skin protectedCallAndTraceback:args nresults:0]) {
                        NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
                        lua_pop(L, 1) ;
                        [skin logError:[NSString stringWithFormat:@"%s:access request callback error:%@", USERDATA_TAG, errorMessage]] ;
                    }
                    [skin luaUnref:refTable ref:fnRef] ;
                }) ;
            }
            if (granted) {
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(eventStoreChangedNotification:)
                                                             name:EKEventStoreChangedNotification
                                                           object:nil];
            }
        }];
    }
    return self ;
}

- (void)dealloc {
    if (_connected == YES) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:EKEventStoreChangedNotification
                                                      object:nil] ;
    }
}

- (void)eventStoreChangedNotification:(__unused NSNotification *)notification {
    if (_changeNotificationFnRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            [skin pushLuaRef:refTable ref:self->_changeNotificationFnRef] ;
            [skin pushNSObject:self] ;
            if (![skin protectedCallAndTraceback:1 nresults:0]) {
                NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
                lua_pop(L, 1) ;
                [skin logError:[NSString stringWithFormat:@"%s:change notification callback error:%@", USERDATA_TAG, errorMessage]] ;
            }
        }) ;
    }
}

@end

#pragma mark - Module Functions

static int calendar_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TFUNCTION | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *which = [skin toNSObjectAtIndex:1] ;
    EKEntityType type ;
    if ([which isEqualToString:@"events"]) {
        type = EKEntityTypeEvent ;
    } else if ([which isEqualToString:@"reminders"]) {
        type = EKEntityTypeReminder ;
    } else {
        return luaL_argerror(L, 1, "expected 'events' or 'reminders'") ;
    }

    int fnRef = LUA_NOREF ;
    if (lua_gettop(L) == 2) {
        lua_pushvalue(L, 2) ;
        fnRef = [skin luaRef:refTable] ;
    }
    ASMCalendar *calendar = [[ASMCalendar alloc] initFor:type withFunctionRef:fnRef] ;
    [skin pushNSObject:calendar] ;
    return 1 ;
}

static int calendar_authorizationStatus(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *which = [skin toNSObjectAtIndex:1] ;
    EKEntityType type ;
    if ([which isEqualToString:@"events"]) {
        type = EKEntityTypeEvent ;
    } else if ([which isEqualToString:@"reminders"]) {
        type = EKEntityTypeReminder ;
    } else {
        return luaL_argerror(L, 1, "expected 'events' or 'reminders'") ;
    }

    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:type] ;
    switch(status) {
        case EKAuthorizationStatusNotDetermined: lua_pushstring(L, "undefined") ; break ;
        case EKAuthorizationStatusRestricted:    lua_pushstring(L, "restricted") ; break ;
        case EKAuthorizationStatusDenied:        lua_pushstring(L, "denied") ; break ;
        case EKAuthorizationStatusAuthorized:    lua_pushstring(L, "authorized") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized EKAuthorizationStatus: %ld, notify developers", status]] ;
            break ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int calendar_connected(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMCalendar *calendar = [skin toNSObjectAtIndex:1] ;
    switch (calendar.connected) {
        case Yes:        lua_pushboolean(L, YES) ; break ;
        case No:         lua_pushboolean(L, NO) ;  break ;
        case Undefined : lua_pushnil(L) ;          break ;
    }
    return 1 ;
}

static int calendar_identifier(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMCalendar *calendar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[calendar.store eventStoreIdentifier]] ;
    return 1 ;
}

static int calendar_defaultCalendar(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMCalendar *calendar = [skin toNSObjectAtIndex:1] ;
    EKCalendar *aCalendar = (calendar.entityType == EKEntityTypeEvent) ? [calendar.store defaultCalendarForNewEvents] : [calendar.store defaultCalendarForNewReminders] ;
    [skin pushNSObject:aCalendar.calendarIdentifier] ;
    return 1 ;
}

static int calendar_sourceIdentifiers(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMCalendar *calendar = [skin toNSObjectAtIndex:1] ;
    lua_newtable(L) ;
    for (EKSource *aSource in [calendar.store sources]) {
        [skin pushNSObject:aSource.sourceIdentifier] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    return 1 ;
}

static int calendar_calendarIdentifiers(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMCalendar *calendar = [skin toNSObjectAtIndex:1] ;
    lua_newtable(L) ;
    for (EKCalendar *aCalendar in [calendar.store calendarsForEntityType:calendar.entityType]) {
        [skin pushNSObject:aCalendar.calendarIdentifier] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    return 1 ;
}

static int calendar_calendarDetails(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    ASMCalendar *calendar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[calendar.store calendarWithIdentifier:[skin toNSObjectAtIndex:2]]] ;
    return 1 ;
}

static int calendar_sourceDetails(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    ASMCalendar *calendar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[calendar.store sourceWithIdentifier:[skin toNSObjectAtIndex:2]]] ;
    return 1 ;
}

static int calendar_itemDetails(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    ASMCalendar *calendar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[calendar.store calendarItemWithIdentifier:[skin toNSObjectAtIndex:2]]] ;
    return 1 ;
}

static int calendar_externalItemDetails(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    ASMCalendar *calendar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[calendar.store calendarItemsWithExternalIdentifier:[skin toNSObjectAtIndex:2]]] ;
    return 1 ;
}

static int calendar_events(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TSTRING, LS_TNUMBER | LS_TSTRING, LS_TTABLE | LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMCalendar *calendar = [skin toNSObjectAtIndex:1] ;
    if (calendar.entityType != EKEntityTypeEvent) {
        return luaL_argerror(L, 1, "not an event calendar object type") ;
    }
    NSDate *start = lua_isnumber(L, 2) ? [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval) lua_tonumber(L,2)] :
                     lua_isstring(L, 2) ? date_from_string([NSString stringWithUTF8String:lua_tostring(L, 2)]) : nil ;

    NSDate *end = lua_isnumber(L, 3) ? [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval) lua_tonumber(L,3)] :
                     lua_isstring(L, 3) ? date_from_string([NSString stringWithUTF8String:lua_tostring(L, 3)]) : nil ;

    NSArray *calendarsToSearch ;
    if (lua_type(L, 4) == LUA_TSTRING) {
        calendarsToSearch = @[ @(lua_tostring(L, 4)) ] ;
    } else if (lua_type(L, 4) == LUA_TTABLE) {
        calendarsToSearch = [skin toNSObjectAtIndex:4] ;
        if ([calendarsToSearch isKindOfClass:[NSArray class]]) {
            BOOL isGood = YES ;
            for (id obj in calendarsToSearch) {
                if (![obj isKindOfClass:[NSString class]]) {
                    isGood = NO ;
                    break ;
                }
            }
            if (!isGood) return luaL_argerror(L, 4, "expected an array of strings") ;
        } else {
            return luaL_argerror(L, 4, "expected an array of strings") ;
        }
    }

    NSMutableArray *calendarsToQuery ;
    for (NSString *identifier in calendarsToSearch) {
        EKCalendar *aCalendar = [calendar.store calendarWithIdentifier:identifier] ;
        if (aCalendar) {
            if (!calendarsToQuery) calendarsToQuery = [[NSMutableArray alloc] init] ;
            [calendarsToQuery addObject:aCalendar] ;
        } else {
            return luaL_argerror(L, 4, [[NSString stringWithFormat:@"%@ is not a recognized calendar identifier", identifier] UTF8String]) ;
        }
    }

    if (!start) {
        return luaL_argerror(L, 2, "expected number of seconds since 1970-01-01 00:00:00Z or string in rfc3339 format (YYYY-MM-DD[T]HH:MM:SS[Z])") ;
    }
    if (!end) {
        return luaL_argerror(L, 3, "expected number of seconds since 1970-01-01 00:00:00Z or string in rfc3339 format (YYYY-MM-DD[T]HH:MM:SS[Z])") ;
    }

    NSPredicate *query = [calendar.store predicateForEventsWithStartDate:start endDate:end calendars:calendarsToQuery] ;
//     [skin logDebug:[query predicateFormat]] ;
    [skin pushNSObject:[calendar.store eventsMatchingPredicate:query] withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

static int calendar_reminders(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION, LS_TBOOLEAN | LS_TTABLE | LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TTABLE | LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    ASMCalendar *calendar = [skin toNSObjectAtIndex:1] ;

    if (calendar.reminderFetchIdentifier) {
        [skin logWarn:[NSString stringWithFormat:@"%s:reminders query already in progress", USERDATA_TAG]] ;
        lua_pushnil(L) ;
    } else {
        if (calendar.entityType != EKEntityTypeReminder) {
            return luaL_argerror(L, 1, "not a reminder calendar object type") ;
        }

        lua_pushvalue(L, 2) ;
        int fnRef = [skin luaRef:refTable] ;

        triStateBOOL limitToCompleted = lua_isboolean(L, 3) ? (triStateBOOL)(BOOL)lua_toboolean(L, 3) : Undefined ;

        int lastArg = lua_gettop(L) ;
        NSMutableArray *calendarsToQuery ;
        if (lastArg > 2 && lua_type(L, lastArg) != LUA_TBOOLEAN) {
            NSArray *calendarsToSearch ;
            if (lua_type(L, lastArg) == LUA_TSTRING) {
                calendarsToSearch = @[ @(lua_tostring(L, lastArg)) ] ;
            } else if (lua_type(L, lastArg) == LUA_TTABLE) {
                calendarsToSearch = [skin toNSObjectAtIndex:lastArg] ;
                if ([calendarsToSearch isKindOfClass:[NSArray class]]) {
                    BOOL isGood = YES ;
                    for (id obj in calendarsToSearch) {
                        if (![obj isKindOfClass:[NSString class]]) {
                            isGood = NO ;
                            break ;
                        }
                    }
                    if (!isGood) return luaL_argerror(L, lastArg, "expected an array of strings") ;
                } else {
                    return luaL_argerror(L, lastArg, "expected an array of strings") ;
                }
            }

            for (NSString *identifier in calendarsToSearch) {
                EKCalendar *aCalendar = [calendar.store calendarWithIdentifier:identifier] ;
                if (aCalendar) {
                    if (!calendarsToQuery) calendarsToQuery = [[NSMutableArray alloc] init] ;
                    [calendarsToQuery addObject:aCalendar] ;
                } else {
                    return luaL_argerror(L, lastArg, [[NSString stringWithFormat:@"%@ is not a recognized calendar identifier", identifier] UTF8String]) ;
                }
            }
        }

        NSPredicate *query ;
        switch(limitToCompleted) {
            case Yes:
                query = [calendar.store predicateForCompletedRemindersWithCompletionDateStarting:nil ending:nil calendars:calendarsToQuery] ;
                break ;
            case No:
                query = [calendar.store predicateForIncompleteRemindersWithDueDateStarting:nil ending:nil calendars:calendarsToQuery] ;
                break ;
            case Undefined:
                query = [calendar.store predicateForRemindersInCalendars:calendarsToQuery] ;
                break ;
        }

        calendar.reminderFetchIdentifier = [calendar.store fetchRemindersMatchingPredicate:query completion:^(NSArray *reminders) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [skin pushLuaRef:refTable ref:fnRef] ;
                [skin pushNSObject:calendar] ;
                [skin pushNSObject:reminders] ;
                if (![skin protectedCallAndTraceback:2 nresults:0]) {
                    NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
                    lua_pop(L, 1) ;
                    [skin logError:[NSString stringWithFormat:@"%s:reminders fetch callback error:%@", USERDATA_TAG, errorMessage]] ;
                }
                [skin luaUnref:refTable ref:fnRef] ;
                calendar.reminderFetchIdentifier = nil ;
            }) ;
        }] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int calendar_remindersQueryInProgress(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMCalendar *calendar = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, calendar.reminderFetchIdentifier ? YES : NO) ;
    return 1 ;
}

static int calendar_cancelRemindersQuery(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMCalendar *calendar = [skin toNSObjectAtIndex:1] ;

    if (calendar.reminderFetchIdentifier) {
        [calendar.store cancelFetchRequest:calendar.reminderFetchIdentifier] ;
        calendar.reminderFetchIdentifier = nil ;
        lua_pushvalue(L, 1) ;
    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s:no reminders query in progress", USERDATA_TAG]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int calendar_changeNotificationCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    ASMCalendar *calendar = [skin toNSObjectAtIndex:1] ;

    // We're either removing callback(s), or setting new one(s). Either way, remove existing.
    calendar.changeNotificationFnRef = [skin luaUnref:refTable ref:calendar.changeNotificationFnRef];

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        calendar.changeNotificationFnRef = [skin luaRef:refTable] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}


#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMCalendar(lua_State *L, id obj) {
    ASMCalendar *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMCalendar *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static int pushEKSource(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    EKSource *src = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:src.sourceIdentifier] ; lua_setfield(L, -2, "identifier") ;
    [skin pushNSObject:src.title] ; lua_setfield(L, -2, "title") ;
    switch(src.sourceType) {
        case EKSourceTypeLocal:      lua_pushstring(L, "local") ; break ;
        case EKSourceTypeExchange:   lua_pushstring(L, "exchange") ; break ;
        case EKSourceTypeCalDAV:     lua_pushstring(L, "calDAV") ; break ;
        case EKSourceTypeMobileMe:   lua_pushstring(L, "MobileMe") ; break ;
        case EKSourceTypeSubscribed: lua_pushstring(L, "subscribed") ; break ;
        case EKSourceTypeBirthdays:  lua_pushstring(L, "birthdays") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized source type: %ld, notify developers", src.sourceType]] ;
            break ;
    }
    lua_setfield(L, -2, "sourceType") ;
    return 1 ;
}

static int pushEKCalendar(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    EKCalendar *cal = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:cal.color] ; lua_setfield(L, -2, "color") ;
    [skin pushNSObject:cal.title] ; lua_setfield(L, -2, "title") ;
    [skin pushNSObject:cal.calendarIdentifier] ; lua_setfield(L, -2, "identifier") ;
    [skin pushNSObject:cal.source.sourceIdentifier] ; lua_setfield(L, -2, "sourceIdentifier") ;
    lua_pushboolean(L, cal.immutable) ; lua_setfield(L, -2, "immutable") ;
    lua_pushboolean(L, cal.subscribed) ; lua_setfield(L, -2, "subscribed") ;
    lua_pushboolean(L, cal.allowsContentModifications) ; lua_setfield(L, -2, "editable") ;
    lua_newtable(L) ;
    EKCalendarEventAvailabilityMask mask = cal.supportedEventAvailabilities ;
    if (mask == EKCalendarEventAvailabilityNone) {
        lua_pushstring(L, "none") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    } else {
        if ((mask & EKCalendarEventAvailabilityBusy) > 0) {
            lua_pushstring(L, "busy") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        if ((mask & EKCalendarEventAvailabilityFree) > 0) {
            lua_pushstring(L, "free") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        if ((mask & EKCalendarEventAvailabilityTentative) > 0) {
            lua_pushstring(L, "tentative") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        if ((mask & EKCalendarEventAvailabilityUnavailable) > 0) {
            lua_pushstring(L, "unavailable") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    }
    lua_pushinteger(L, mask) ; lua_setfield(L, -2, "_raw") ;
    lua_setfield(L, -2, "eventAvailabilitySupport") ;
    switch(cal.type) {
        case EKCalendarTypeLocal:        lua_pushstring(L, "local") ; break ;
        case EKCalendarTypeCalDAV:       lua_pushstring(L, "calDAV") ; break ;
        case EKCalendarTypeExchange:     lua_pushstring(L, "exchange") ; break ;
        case EKCalendarTypeSubscription: lua_pushstring(L, "subscription") ; break ;
        case EKCalendarTypeBirthday:     lua_pushstring(L, "birthday") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized calendar type: %ld, notify developers", cal.type]] ;
            break ;
    }
    lua_setfield(L, -2, "calendarType") ;
    lua_newtable(L) ;
    EKEntityMask entityMask = cal.allowedEntityTypes ;
    if ((entityMask & EKEntityMaskEvent) > 0) {
        lua_pushstring(L, "events") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ((entityMask & EKEntityMaskReminder) > 0) {
        lua_pushstring(L, "reminders") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    lua_pushinteger(L, entityMask) ; lua_setfield(L, -2, "_raw") ;
    lua_setfield(L, -2, "entityTypes") ;
    return 1 ;
}

static int pushEKEvent(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    EKEvent *event = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:event.location] ; lua_setfield(L, -2, "location") ;
    [skin pushNSObject:event.notes] ; lua_setfield(L, -2, "notes") ;
    [skin pushNSObject:event.title] ; lua_setfield(L, -2, "title") ;
    [skin pushNSObject:[event.URL absoluteString]] ; lua_setfield(L, -2, "URL") ;
    lua_pushboolean(L, event.hasAlarms) ; lua_setfield(L, -2, "hasAlarms") ;
    lua_pushboolean(L, event.hasAttendees) ; lua_setfield(L, -2, "hasAttendees") ;
    lua_pushboolean(L, event.hasNotes) ; lua_setfield(L, -2, "hasNotes") ;
    lua_pushboolean(L, event.hasRecurrenceRules) ; lua_setfield(L, -2, "hasRecurrenceRules") ;
    [skin pushNSObject:event.creationDate] ; lua_setfield(L, -2, "creationDate") ;
    [skin pushNSObject:event.lastModifiedDate] ; lua_setfield(L, -2, "lastModifiedDate") ;
    [skin pushNSObject:event.calendarItemExternalIdentifier] ; lua_setfield(L, -2, "calendarItemExternalIdentifier") ;
    [skin pushNSObject:event.calendarItemIdentifier] ; lua_setfield(L, -2, "calendarItemIdentifier") ;
    [skin pushNSObject:event.calendar.calendarIdentifier] ; lua_setfield(L, -2, "calendarIdentifier") ;
    [skin pushNSObject:event.timeZone.abbreviation] ; lua_setfield(L, -2, "timeZone") ;
    [skin pushNSObject:event.alarms] ; lua_setfield(L, -2, "alarms") ;
    [skin pushNSObject:event.recurrenceRules] ; lua_setfield(L, -2, "recurrenceRules") ;
    [skin pushNSObject:event.attendees] ; lua_setfield(L, -2, "attendees") ;

    [skin pushNSObject:event.endDate] ; lua_setfield(L, -2, "endDate") ;
    [skin pushNSObject:event.startDate] ; lua_setfield(L, -2, "startDate") ;
    lua_pushboolean(L, event.allDay) ; lua_setfield(L, -2, "allDay") ;
    lua_pushboolean(L, event.isDetached) ; lua_setfield(L, -2, "isDetached") ;
    [skin pushNSObject:event.occurrenceDate] ; lua_setfield(L, -2, "occurrenceDate") ;
    [skin pushNSObject:event.birthdayContactIdentifier] ; lua_setfield(L, -2, "birthdayContactIdentifier") ;
    [skin pushNSObject:event.eventIdentifier] ; lua_setfield(L, -2, "identifier") ;
    switch(event.status) {
        case EKEventStatusNone:      lua_pushstring(L, "none") ; break ;
        case EKEventStatusConfirmed: lua_pushstring(L, "confirmed") ; break ;
        case EKEventStatusTentative: lua_pushstring(L, "tentative") ; break ;
        case EKEventStatusCanceled:  lua_pushstring(L, "canceled") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized event status: %ld, notify developers", event.status]] ;
            break ;
    }
    lua_setfield(L, -2, "status") ;
    switch(event.availability) {
        case EKEventAvailabilityNotSupported: lua_pushstring(L, "notSupported") ; break ;
        case EKEventAvailabilityBusy:         lua_pushstring(L, "busy") ; break ;
        case EKEventAvailabilityFree:         lua_pushstring(L, "free") ; break ;
        case EKEventAvailabilityTentative:    lua_pushstring(L, "tentative") ; break ;
        case EKEventAvailabilityUnavailable:  lua_pushstring(L, "unavailable") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized event availability: %ld, notify developers", event.availability]] ;
            break ;
    }
    lua_setfield(L, -2, "availability") ;
    [skin pushNSObject:event.organizer] ; lua_setfield(L, -2, "organizer") ;
    return 1 ;
}

static int pushEKParticipant(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    EKParticipant *participant = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:participant.name] ; lua_setfield(L, -2, "name") ;
    [skin pushNSObject:participant.URL.absoluteString] ; lua_setfield(L, -2, "URL") ;
    switch(participant.participantRole) {
        case EKParticipantRoleUnknown:        lua_pushstring(L, "unknown") ; break ;
        case EKParticipantRoleRequired:       lua_pushstring(L, "required") ; break ;
        case EKParticipantRoleOptional:       lua_pushstring(L, "optional") ; break ;
        case EKParticipantRoleChair:          lua_pushstring(L, "chair") ; break ;
        case EKParticipantRoleNonParticipant: lua_pushstring(L, "nonParticipant") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized participant role: %ld, notify developers", participant.participantRole]] ;
            break ;
    }
    lua_setfield(L, -2, "role") ;
    switch(participant.participantStatus) {
        case EKParticipantStatusUnknown:   lua_pushstring(L, "unknown") ; break ;
        case EKParticipantStatusPending:   lua_pushstring(L, "pending") ; break ;
        case EKParticipantStatusAccepted:  lua_pushstring(L, "accepted") ; break ;
        case EKParticipantStatusDeclined:  lua_pushstring(L, "declined") ; break ;
        case EKParticipantStatusTentative: lua_pushstring(L, "tentative") ; break ;
        case EKParticipantStatusDelegated: lua_pushstring(L, "delegated") ; break ;
        case EKParticipantStatusCompleted: lua_pushstring(L, "completed") ; break ;
        case EKParticipantStatusInProcess: lua_pushstring(L, "inProcess") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized participant status: %ld, notify developers", participant.participantStatus]] ;
            break ;
    }
    lua_setfield(L, -2, "status") ;
    switch(participant.participantType) {
        case EKParticipantTypeUnknown:  lua_pushstring(L, "unknown") ; break ;
        case EKParticipantTypePerson:   lua_pushstring(L, "person") ; break ;
        case EKParticipantTypeRoom:     lua_pushstring(L, "room") ; break ;
        case EKParticipantTypeResource: lua_pushstring(L, "resource") ; break ;
        case EKParticipantTypeGroup:    lua_pushstring(L, "group") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized participant type: %ld, notify developers", participant.participantType]] ;
            break ;
    }
    lua_setfield(L, -2, "type") ;
    return 1 ;
}

static int pushEKAlarm(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    EKAlarm *alarm = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:alarm.structuredLocation] ; lua_setfield(L, -2, "location") ;
    [skin pushNSObject:alarm.absoluteDate] ;       lua_setfield(L, -2, "date") ;
    [skin pushNSObject:alarm.emailAddress] ;       lua_setfield(L, -2, "email") ;
    [skin pushNSObject:alarm.soundName] ;          lua_setfield(L, -2, "sound") ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [skin pushNSObject:alarm.url.absoluteString] ; lua_setfield(L, -2, "URL") ;
#pragma clang diagnostic pop

    switch(alarm.type) {
        case EKAlarmTypeDisplay:   lua_pushstring(L, "display") ; break ;
        case EKAlarmTypeAudio:     lua_pushstring(L, "audio") ; break ;
        case EKAlarmTypeProcedure: lua_pushstring(L, "procedure") ; break ;
        case EKAlarmTypeEmail:     lua_pushstring(L, "email") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized alarm type: %ld, notify developers", alarm.type]] ;
            break ;
    }
    lua_setfield(L, -2, "type") ;
    switch(alarm.proximity) {
        case EKAlarmProximityNone:  lua_pushstring(L, "none") ; break ;
        case EKAlarmProximityEnter: lua_pushstring(L, "enter") ; break ;
        case EKAlarmProximityLeave: lua_pushstring(L, "leave") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized alarm proximity: %ld, notify developers", alarm.proximity]] ;
            break ;
    }
    lua_setfield(L, -2, "proximity") ;
    lua_pushnumber(L, alarm.relativeOffset) ; lua_setfield(L, -2, "offset") ;
    return 1 ;
}

static int pushEKStructuredLocation(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    EKStructuredLocation *location = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:location.title] ; lua_setfield(L, -2, "title") ;
    [skin pushNSObject:location.geoLocation] ; lua_setfield(L, -2, "geoLocation") ;
    lua_pushnumber(L, location.radius) ; lua_setfield(L, -2, "radius") ;
    return 1 ;
}

static int pushCLLocation(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    CLLocation *location = obj ;
    lua_newtable(L) ;
    lua_pushnumber(L, location.coordinate.latitude) ; lua_setfield(L, -2, "latitude") ;
    lua_pushnumber(L, location.coordinate.longitude) ; lua_setfield(L, -2, "longitude") ;
    lua_pushnumber(L, location.altitude) ; lua_setfield(L, -2, "altitude") ;
    lua_pushnumber(L, location.horizontalAccuracy) ; lua_setfield(L, -2, "horizontalAccuracy") ;
    lua_pushnumber(L, location.verticalAccuracy) ; lua_setfield(L, -2, "verticalAccuracy") ;
    lua_pushnumber(L, location.course) ; lua_setfield(L, -2, "course") ;
    lua_pushnumber(L, location.speed) ; lua_setfield(L, -2, "speed") ;
    [skin pushNSObject:location.description] ; lua_setfield(L, -2, "description") ;
    return 1 ;
}

static int pushEKRecurrenceEnd(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    EKRecurrenceEnd *recurrenceEnd = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:recurrenceEnd.endDate] ; lua_setfield(L, -2, "endDate") ;
    lua_pushinteger(L, (lua_Integer)recurrenceEnd.occurrenceCount) ; lua_setfield(L, -2, "count") ;
    return 1 ;
}

static int pushEKRecurrenceDayOfWeek(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    EKRecurrenceDayOfWeek *dayOfWeek = obj ;
    lua_newtable(L) ;
    switch(dayOfWeek.dayOfTheWeek) {
        case EKWeekdaySunday:    lua_pushstring(L, "Sunday") ; break ;
        case EKWeekdayMonday:    lua_pushstring(L, "Monday") ; break ;
        case EKWeekdayTuesday:   lua_pushstring(L, "Tuesday") ; break ;
        case EKWeekdayWednesday: lua_pushstring(L, "Wednesday") ; break ;
        case EKWeekdayThursday:  lua_pushstring(L, "Thursday") ; break ;
        case EKWeekdayFriday:    lua_pushstring(L, "Friday") ; break ;
        case EKWeekdaySaturday:  lua_pushstring(L, "Saturday") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized day of the week: %ld, notify developers", dayOfWeek.dayOfTheWeek]] ;
            break ;
    }
    lua_setfield(L, -2, "day") ;
    lua_pushinteger(L, dayOfWeek.weekNumber) ; lua_setfield(L, -2, "weekNumber") ;
    return 1 ;
}

static int pushEKRecurrenceRule(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    EKRecurrenceRule *rule = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:rule.recurrenceEnd] ; lua_setfield(L, -2, "endDate") ;
    switch(rule.frequency) {
        case EKRecurrenceFrequencyDaily:   lua_pushstring(L, "daily") ; break ;
        case EKRecurrenceFrequencyWeekly:  lua_pushstring(L, "weekly") ; break ;
        case EKRecurrenceFrequencyMonthly: lua_pushstring(L, "monthly") ; break ;
        case EKRecurrenceFrequencyYearly:  lua_pushstring(L, "yearly") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized recurrence frequency: %ld, notify developers", rule.frequency]] ;
            break ;
    }
    lua_setfield(L, -2, "frequency") ;
    [skin pushNSObject:rule.daysOfTheWeek] ; lua_setfield(L, -2, "daysOfTheWeek") ;
    [skin pushNSObject:rule.daysOfTheMonth] ; lua_setfield(L, -2, "daysOfTheMonth") ;
    [skin pushNSObject:rule.daysOfTheYear] ; lua_setfield(L, -2, "daysOfTheYear") ;
    [skin pushNSObject:rule.monthsOfTheYear] ; lua_setfield(L, -2, "monthsOfTheYear") ;
    [skin pushNSObject:rule.setPositions] ; lua_setfield(L, -2, "setPositions") ;
    [skin pushNSObject:rule.weeksOfTheYear] ; lua_setfield(L, -2, "weeksOfTheYear") ;
    lua_pushinteger(L, rule.firstDayOfTheWeek) ; lua_setfield(L, -2, "firstDayOfTheWeek") ;
    lua_pushinteger(L, rule.interval) ; lua_setfield(L, -2, "interval") ;
    [skin pushNSObject:rule.calendarIdentifier] ; lua_setfield(L, -2, "calendarIdentifier") ;
    return 1 ;
}

static int pushEKReminder(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    EKReminder *reminder = obj ;
    lua_newtable(L) ;

    [skin pushNSObject:reminder.location] ; lua_setfield(L, -2, "location") ;
    [skin pushNSObject:reminder.notes] ; lua_setfield(L, -2, "notes") ;
    [skin pushNSObject:reminder.title] ; lua_setfield(L, -2, "title") ;
    [skin pushNSObject:[reminder.URL absoluteString]] ; lua_setfield(L, -2, "URL") ;
    lua_pushboolean(L, reminder.hasAlarms) ; lua_setfield(L, -2, "hasAlarms") ;
    lua_pushboolean(L, reminder.hasAttendees) ; lua_setfield(L, -2, "hasAttendees") ;
    lua_pushboolean(L, reminder.hasNotes) ; lua_setfield(L, -2, "hasNotes") ;
    lua_pushboolean(L, reminder.hasRecurrenceRules) ; lua_setfield(L, -2, "hasRecurrenceRules") ;
    [skin pushNSObject:reminder.creationDate] ; lua_setfield(L, -2, "creationDate") ;
    [skin pushNSObject:reminder.lastModifiedDate] ; lua_setfield(L, -2, "lastModifiedDate") ;
    [skin pushNSObject:reminder.calendarItemExternalIdentifier] ; lua_setfield(L, -2, "calendarItemExternalIdentifier") ;
    [skin pushNSObject:reminder.calendarItemIdentifier] ; lua_setfield(L, -2, "calendarItemIdentifier") ;
    [skin pushNSObject:reminder.calendar.calendarIdentifier] ; lua_setfield(L, -2, "calendarIdentifier") ;
    [skin pushNSObject:reminder.timeZone.abbreviation] ; lua_setfield(L, -2, "timeZone") ;
    [skin pushNSObject:reminder.alarms] ; lua_setfield(L, -2, "alarms") ;
    [skin pushNSObject:reminder.recurrenceRules] ; lua_setfield(L, -2, "recurrenceRules") ;
    [skin pushNSObject:reminder.attendees] ; lua_setfield(L, -2, "attendees") ;

    [skin pushNSObject:reminder.completionDate] ; lua_setfield(L, -2, "completionDate") ;
    [skin pushNSObject:reminder.dueDateComponents] ; lua_setfield(L, -2, "dueDateComponents") ;
    [skin pushNSObject:reminder.startDateComponents] ; lua_setfield(L, -2, "startDateComponents") ;
    lua_pushboolean(L, reminder.completed) ; lua_setfield(L, -2, "completed") ;

    return 1 ;
}

static int pushNSDateComponents(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSDateComponents *dc = obj ;
    NSCalendar       *cal = dc.calendar ? dc.calendar : [NSCalendar currentCalendar] ;

    lua_newtable(L) ;
    if (dc.era != NSDateComponentUndefined) {
        NSArray *symbols = cal.eraSymbols ;
        if ((NSUInteger)dc.era < symbols.count) {
            [skin pushNSObject:symbols[(NSUInteger)dc.era]] ;
        } else {
            lua_pushinteger(L, dc.era) ;
        }
        lua_setfield(L, -2, "era") ;
    }
    if (dc.year != NSDateComponentUndefined) { lua_pushinteger(L, dc.year) ; lua_setfield(L, -2, "year") ; }
    if (dc.month != NSDateComponentUndefined) { lua_pushinteger(L, dc.month) ; lua_setfield(L, -2, "month") ; }
    if (dc.day != NSDateComponentUndefined) { lua_pushinteger(L, dc.day) ; lua_setfield(L, -2, "day") ; }
    if (dc.hour != NSDateComponentUndefined) { lua_pushinteger(L, dc.hour) ; lua_setfield(L, -2, "hour") ; }
    if (dc.minute != NSDateComponentUndefined) { lua_pushinteger(L, dc.minute) ; lua_setfield(L, -2, "minute") ; }
    if (dc.second != NSDateComponentUndefined) { lua_pushinteger(L, dc.second) ; lua_setfield(L, -2, "second") ; }
    if (dc.nanosecond != NSDateComponentUndefined) { lua_pushinteger(L, dc.nanosecond) ; lua_setfield(L, -2, "nanosecond") ; }
    if (dc.weekday != NSDateComponentUndefined) { lua_pushinteger(L, dc.weekday) ; lua_setfield(L, -2, "weekday") ; }
    if (dc.weekdayOrdinal != NSDateComponentUndefined) { lua_pushinteger(L, dc.weekdayOrdinal) ; lua_setfield(L, -2, "weekdayOrdinal") ; }
    if (dc.quarter != NSDateComponentUndefined) { lua_pushinteger(L, dc.quarter) ; lua_setfield(L, -2, "quarter") ; }
    if (dc.weekOfMonth != NSDateComponentUndefined) { lua_pushinteger(L, dc.weekOfMonth) ; lua_setfield(L, -2, "weekOfMonth") ; }
    if (dc.weekOfYear != NSDateComponentUndefined) { lua_pushinteger(L, dc.weekOfYear) ; lua_setfield(L, -2, "weekOfYear") ; }
    if (dc.yearForWeekOfYear != NSDateComponentUndefined) { lua_pushinteger(L, dc.yearForWeekOfYear) ; lua_setfield(L, -2, "yearForWeekOfYear") ; }
    [skin pushNSObject:cal.calendarIdentifier] ; lua_setfield(L, -2, "calendarIdentifier") ;
    [skin pushNSObject:dc.timeZone.abbreviation] ; lua_setfield(L, -2, "timeZone") ;
    lua_pushboolean(L, dc.leapMonth) ; lua_setfield(L, -2, "leapMonth") ;
    lua_pushboolean(L, dc.validDate) ; lua_setfield(L, -2, "validDate") ;
    [skin pushNSObject:dc.date] ; lua_setfield(L, -2, "date") ;
    return 1 ;
}

static id toASMCalendarFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMCalendar *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMCalendar, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMCalendar *obj = [skin luaObjectAtIndex:1 toClass:"ASMCalendar"] ;
    NSString *title = (obj.entityType == EKEntityTypeEvent) ? @"events" : @"reminders" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMCalendar *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMCalendar"] ;
        ASMCalendar *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMCalendar"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMCalendar *obj = get_objectFromUserdata(__bridge_transfer ASMCalendar, L, 1, USERDATA_TAG) ;
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
    {"connected",           calendar_connected},
    {"identifier",          calendar_identifier},
    {"sourceIdentifiers",   calendar_sourceIdentifiers},
    {"calendarIdentifiers", calendar_calendarIdentifiers},
    {"events",              calendar_events},
    {"calendarDetails",     calendar_calendarDetails},
    {"sourceDetails",       calendar_sourceDetails},
    {"itemDetails",         calendar_itemDetails},
    {"externalItemDetails", calendar_externalItemDetails},
    {"defaultCalendar",     calendar_defaultCalendar},
    {"callbackWhenChanges", calendar_changeNotificationCallback},
    {"reminders",           calendar_reminders},
    {"remindersFetching",   calendar_remindersQueryInProgress},
    {"remindersCancel",     calendar_cancelRemindersQuery},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"_new",                calendar_new},
    {"authorizationStatus", calendar_authorizationStatus},

    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_calendar_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASMCalendar         forClass:"ASMCalendar"];
    [skin registerLuaObjectHelper:toASMCalendarFromLua forClass:"ASMCalendar"
                                             withUserdataMapping:USERDATA_TAG];

    // return values for this module
    [skin registerPushNSHelper:pushEKCalendar forClass:"EKCalendar"] ;
    [skin registerPushNSHelper:pushEKSource   forClass:"EKSource"] ;
    [skin registerPushNSHelper:pushEKEvent    forClass:"EKEvent"] ;
    [skin registerPushNSHelper:pushEKReminder forClass:"EKReminder"] ;

    // support for above return values
    [skin registerPushNSHelper:pushEKStructuredLocation  forClass:"EKStructuredLocation"] ;
    [skin registerPushNSHelper:pushEKRecurrenceEnd       forClass:"EKRecurrenceEnd"] ;
    [skin registerPushNSHelper:pushEKRecurrenceDayOfWeek forClass:"EKRecurrenceDayOfWeek"] ;
    [skin registerPushNSHelper:pushEKRecurrenceRule      forClass:"EKRecurrenceRule"] ;
    [skin registerPushNSHelper:pushEKParticipant         forClass:"EKParticipant"] ;
    [skin registerPushNSHelper:pushEKAlarm               forClass:"EKAlarm"] ;

// really belongs in hs.location if hs._asm.geocoder gets added, and I'm thinking more and
// more that it should...
    [skin registerPushNSHelper:pushCLLocation            forClass:"CLLocation"] ;

    [skin registerPushNSHelper:pushNSDateComponents      forClass:"NSDateComponents"] ;
//     [skin registerPushNSHelper:pushNSCalendar            forClass:"NSCalendar"] ;

    return 1;
}
