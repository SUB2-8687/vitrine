// SGRecap.h says what a recap holds.
#import "SGRecap.h"

@implementation SGRecapYear
- (BOOL)eligible { return self.activeDays >= SGRecapActiveDaysNeeded; }
@end
@implementation SGRecap
- (BOOL)eligible { return self.activeDays >= SGRecapActiveDaysNeeded; }
@end

static int64_t unixSeconds(NSDate *date) {
    return (int64_t)floor(date.timeIntervalSince1970);
}

// Each local day holding a play of `sorted` (ordered by end), once, from its first instant. A damaged row's time
// outside NSDate's years is no day, as in SGStreaks.
static void eachDay(NSArray<SGPlay *> *sorted, NSCalendar *cal, void (^day)(NSDate *start)) {
    int64_t dayEnd = INT64_MIN;
    for (SGPlay *play in sorted) {
        if (play.end < -62135596800LL || play.end > 253402300799LL || play.end < dayEnd) continue;
        NSDate *start;
        NSTimeInterval length = 0;
        if (![cal rangeOfUnit:NSCalendarUnitDay startDate:&start interval:&length forDate:[NSDate dateWithTimeIntervalSince1970:play.end]]) continue;
        dayEnd = unixSeconds([start dateByAddingTimeInterval:length]);
        day(start);
    }
}

static NSArray<SGPlay *> *musicByEnd(NSArray<SGPlay *> *plays, int64_t start, int64_t end) {
    return [[[SGChartLog alloc] initWithPlays:plays kind:SGChartKindSongs before:end] playsFrom:start to:end];
}

NSArray<SGRecapYear *> *SGRecapYears(NSArray<SGPlay *> *plays, NSCalendar *calendar) {
    NSCalendar *cal = [calendar copy];
    NSMutableArray<SGRecapYear *> *years = [NSMutableArray array];
    __block SGRecapYear *current;
    eachDay(musicByEnd(plays, INT64_MIN, INT64_MAX), cal, ^(NSDate *start) {
        // The days come in order, so a day past the year's end begins the next year with plays.
        if (!current || [start compare:current.interval.endDate] != NSOrderedAscending) {
            NSDateInterval *year = SGPeriodInterval(SGStatsPeriodYear, start, cal);
            if (!year) return;
            current = [SGRecapYear new];
            current.interval = year;
            [years insertObject:current atIndex:0];
        }
        current.activeDays++;
    });
    return years;
}

// The index of the largest listening time, the first of equals; -1 when none has any.
static NSInteger peakOf(NSArray *buckets) {
    NSInteger peak = -1;
    int64_t most = 0;
    for (NSUInteger i = 0; i < buckets.count; i++) {
        int64_t ms = [[buckets[i] valueForKey:@"ms"] longLongValue];
        if (ms > most) { most = ms; peak = (NSInteger)i; }
    }
    return peak;
}

static NSUInteger countNew(NSDictionary<NSString *, SGChartEntry *> *entries, NSSet<NSString *> *before) {
    NSUInteger count = 0;
    for (NSString *key in entries) if (![before containsObject:key]) count++;
    return count;
}

SGRecap *SGRecapBuild(NSArray<SGPlay *> *plays, NSDate *date, NSDate *now, NSCalendar *calendar) {
    NSCalendar *cal = [calendar copy];
    NSDateInterval *year = SGPeriodInterval(SGStatsPeriodYear, date, cal);
    if (!year) return nil;
    int64_t start = unixSeconds(year.startDate), end = unixSeconds(year.endDate);
    SGRecap *recap = [SGRecap new];
    recap.year = year;

    SGChartLog *songs = [[SGChartLog alloc] initWithPlays:plays kind:SGChartKindSongs before:end];
    SGChartLog *artists = [[SGChartLog alloc] initWithPlays:plays kind:SGChartKindArtists before:end];
    SGChartLog *albums = [[SGChartLog alloc] initWithPlays:plays kind:SGChartKindAlbums before:end];
    NSArray<SGPlay *> *inYear = [songs playsFrom:start to:end];
    recap.plays = inYear.count;
    for (SGPlay *play in inYear) recap.ms += play.ms;
    eachDay(inYear, cal, ^(NSDate *day) { recap.activeDays++; });

    NSDictionary<NSString *, SGChartEntry *> *songEntries = [songs entriesFrom:start to:end], *artistEntries = [artists entriesFrom:start to:end];
    recap.songs = SGChartRank(songEntries, SGRecapTopLength);
    recap.artists = SGChartRank(artistEntries, SGRecapTopLength);
    recap.albums = SGChartRank([albums entriesFrom:start to:end], SGRecapTopLength);
    NSSet<NSString *> *artistsBefore = [artists keysBefore:start];
    recap.newSongs = countNew(songEntries, [songs keysBefore:start]);
    recap.newArtists = countNew(artistEntries, artistsBefore);
    for (SGChartEntry *entry in SGChartRank(artistEntries, NSUIntegerMax)) {
        if ([artistsBefore containsObject:entry.key]) continue;
        recap.topNewArtist = entry;
        break;
    }

    // As of the year's last instant, or now while it runs, so the best streak is the year's own.
    NSDate *last = [year.endDate dateByAddingTimeInterval:-1];
    SGListeningStreaks *streaks = SGStreaks(inYear, [now compare:last] == NSOrderedAscending ? now : last, cal);
    recap.longestStreak = streaks.best;
    recap.streakStart = streaks.bestStart;
    recap.streakEnd = streaks.bestEnd;

    NSArray<SGStatEntry *> *hours = SGHourlyStatsBetween(inYear, start, end, cal);
    NSInteger hour = peakOf(hours);
    recap.peakHour = hour;
    recap.peakHourMs = hour < 0 ? 0 : hours[(NSUInteger)hour].ms;
    NSArray<SGStatBucket *> *months = SGPeriodBuckets(inYear, SGStatsPeriodYear, year.startDate, cal);
    NSInteger month = peakOf(months);
    recap.peakMonth = month < 0 ? nil : [NSDate dateWithTimeIntervalSince1970:months[(NSUInteger)month].start];
    recap.peakMonthMs = month < 0 ? 0 : months[(NSUInteger)month].ms;

    NSMutableArray<NSNumber *> *cards = [NSMutableArray array];
    if (recap.plays) [cards addObject:@(SGRecapCardTotal)];
    if (recap.artists.count) [cards addObject:@(SGRecapCardArtists)];
    if (recap.songs.count) [cards addObject:@(SGRecapCardSongs)];
    if (recap.albums.count) [cards addObject:@(SGRecapCardAlbums)];
    if (recap.newArtists || recap.newSongs) [cards addObject:@(SGRecapCardDiscoveries)];
    if (recap.activeDays) [cards addObject:@(SGRecapCardDays)];
    if (recap.peakHourMs && recap.peakMonthMs) [cards addObject:@(SGRecapCardPeak)];
    recap.cards = cards;
    return recap;
}

SGRecapAnnouncement SGRecapAnnouncementFrom(NSInteger stored) {
    return stored >= SGRecapAnnounceOnLaunch && stored <= SGRecapAnnounceOff ? (SGRecapAnnouncement)stored : SGRecapAnnounceInSettings;
}

NSDateInterval *SGRecapAnnouncedYear(NSDate *now, NSCalendar *calendar) {
    NSCalendar *cal = [calendar copy];
    NSDateInterval *year = SGPeriodInterval(SGStatsPeriodYear, now, cal);
    NSDate *after = year ? [cal dateByAddingUnit:NSCalendarUnitDay value:SGRecapAnnouncementDays toDate:year.startDate options:0] : nil;
    if (!after || [now compare:[cal startOfDayForDate:after]] != NSOrderedAscending) return nil;
    return SGPeriodStep(SGStatsPeriodYear, year.startDate, -1, cal);
}

NSInteger SGRecapYearNumber(NSDateInterval *year, NSCalendar *calendar) {
    return [calendar component:NSCalendarUnitYear fromDate:[year.startDate dateByAddingTimeInterval:year.duration / 2]];
}

NSString *SGRecapYearTitle(NSDateInterval *year, NSCalendar *calendar) {
    return [NSString stringWithFormat:@"%ld", (long)SGRecapYearNumber(year, calendar)];
}

NSDateInterval *SGRecapUnannouncedYear(NSDate *now, NSCalendar *calendar, SGRecapAnnouncement preference, NSInteger announcedYear) {
    NSDateInterval *ended = SGRecapAnnouncedYear(now, calendar);
    if (!ended || preference == SGRecapAnnounceOff || announcedYear >= SGRecapYearNumber(ended, calendar)) return nil;
    return ended;
}

BOOL SGRecapPromptDue(NSDateInterval *year, NSDate *now, NSCalendar *calendar, SGRecapAnnouncement preference, NSInteger announcedYear) {
    NSDateInterval *due = SGRecapUnannouncedYear(now, calendar, preference, announcedYear);
    return preference == SGRecapAnnounceOnLaunch && due && SGRecapYearNumber(due, calendar) == SGRecapYearNumber(year, calendar);
}
