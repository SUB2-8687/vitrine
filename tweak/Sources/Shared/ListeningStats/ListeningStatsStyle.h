// What Listening stats' pages share (ListeningStatsPage.m defines it): how a time, a count of plays or days and a
// date are written, the type and layout of the cards drawn on the pages' dark rows, and the pages the main one opens.
#import <UIKit/UIKit.h>
#import "SGTopCharts.h"

NSString *SGStatsDuration(int64_t ms);       // "<1 min", "42 min", "3 h 5 min"
NSString *SGStatsPlays(NSUInteger plays);    // "1 play", "12 plays"
NSString *SGStatsDays(NSUInteger days);      // "1 day", "30 days"
NSString *SGStatsCount(NSUInteger count);    // grouped digits
NSDateFormatter *SGStatsDateFormatter(NSCalendar *calendar, NSString *localizedTemplate);
// What is added up for `interval` from a log's snapshot is cached under this: the interval, the calendar's identity,
// time zone and first weekday, and the log's playsGeneration and play count.
NSString *SGStatsCacheKey(NSDateInterval *interval, NSCalendar *calendar, NSUInteger playsGeneration, NSUInteger plays);

// Spotify's typeface in bold at `size` for the default text size, grown with the title font and capped.
UIFont *SGStatsStrongFont(CGFloat size, CGFloat largest);
UILabel *SGStatsLabel(UIColor *color);   // wrapping, in `color`
// A card's content between the cell's side margins, `vertical` from its top and bottom.
void SGStatsPinToCard(UIView *view, UITableViewCell *cell, CGFloat vertical);
// A row drawn as a card: the card's color, no highlight, VoiceOver reaching the elements inside.
void SGStatsPrepareCard(UITableViewCell *cell);

// A figure on a card: its symbol and caption, the value large, a note under it. Read as one element.
@interface SGStatsColumn : UIStackView
- (instancetype)initWithSymbol:(NSString *)symbol caption:(NSString *)caption;
- (void)showValue:(NSString *)value note:(NSString *)note;
@end
// Two figures side by side on one card, one over the other at the accessibility text sizes.
@interface SGStatsPairCell : UITableViewCell
- (instancetype)initWithFirst:(SGStatsColumn *)first second:(SGStatsColumn *)second;
@property (nonatomic, readonly) SGStatsColumn *first, *second;
- (void)render;   // again on every pass, for a text size changed while the page is open
@end

// The chart behind a Top heading (TopChartPage.m), for the period of `period` holding `start`, named `periodTitle`.
UIViewController *SGTopChartPage(SGChartKind kind, SGStatsPeriod period, NSDate *start, NSString *periodTitle);
// The years with plays, each opening its recap story (RecapStory.m). `importHistory` runs the page's Import history.
UIViewController *SGRecapYearsPage(void (^importHistory)(void));
@class SGRecapYear;
// The year of `years` whose recap the Recap row points out now (see RecapStory.m); nil when none is due.
SGRecapYear *SGRecapDueYear(NSArray<SGRecapYear *> *years, NSDate *now, NSCalendar *calendar);
