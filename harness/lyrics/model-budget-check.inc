NSArray<SGKaraokeLine *> *SGTTMLLines(NSString *xml);

@interface SGRKaraokeView (BudgetHarness)
- (void)showLinesInSight;
@end

// Keep the visibility algorithm real while controlling what building a row costs: a controlled clock, so a slow
// runner cannot make the fast case spend its budget.
@interface SGBudgetView : SGRKaraokeView
@property (nonatomic) BOOL slow;
@property (nonatomic) CFTimeInterval now;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *built;
@end
@implementation SGBudgetView
- (CFTimeInterval)lineCreationClock { return self.now; }
- (CGFloat)topOfLine:(NSInteger)index { return index * 20; }
- (BOOL)isSung:(NSInteger)index { return NO; }
- (id)viewForLine:(NSInteger)index {
    if (self.slow) self.now += 0.002;
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
    ((NSMutableDictionary *)[self valueForKey:@"shown"])[@(index)] = row;
    [self.built addObject:@(index)];
    return row;
}
@end

static SGKaraokeLine *modelLine(NSString *attribute, NSArray<NSString *> *words, BOOL explicitBacking) {
    NSMutableString *xml = [NSMutableString stringWithFormat:@"<tt xmlns:ns=\"urn:test\" %@><body><p begin=\"0\" end=\"10\">", attribute];
    [words enumerateObjectsUsingBlock:^(NSString *text, NSUInteger i, BOOL *stop) {
        [xml appendFormat:@"<span begin=\"%lu\" end=\"%lu\">%@</span>", (unsigned long)i, (unsigned long)i + 1, text];
    }];
    if (explicitBacking) [xml appendString:@"<span role=\"x-bg\"><span begin=\"8\" end=\"9\">(explicit)</span></span>"];
    [xml appendString:@"</p></body></tt>"];
    return SGTTMLLines(xml).firstObject;
}

static void modelBudgetChecks(void) {
    NSArray *cases = @[
        @[@"byModel=\"true\"", @[@"Main", @"(one", @"two)"], @[@"Main"], @[@"(one", @"two)"]],
        @[@"byModel=\"true\"", @[@"(one)", @"Main", @"(two)"], @[@"Main"], @[@"(one)", @"(two)"]],
        @[@"ns:byModel=\"true\"", @[@"Main", @"(one)"], @[@"Main"], @[@"(one)"]],
        @[@"byModel=\"false\"", @[@"Main", @"(one)"], @[@"Main", @"(one)"], @[]],
        @[@"", @[@"Main", @"(one)"], @[@"Main", @"(one)"], @[]],
        @[@"byModel=\"TRUE\"", @[@"Main", @"(one)"], @[@"Main", @"(one)"], @[]],
        @[@"byModel=\"true\"", @[@"Main", @"(open"], @[@"Main", @"(open"], @[]],
        @[@"byModel=\"true\"", @[@"(all", @"words)"], @[@"(all", @"words)"], @[]],
        @[@"byModel=\"true\"", @[@"Main", @"(one)", @"(open"], @[@"Main", @"(open"], @[@"(one)"]],
    ];
    for (NSArray *c in cases) {
        SGKaraokeLine *line = modelLine(c[0], c[1], NO);
        check([[line.words valueForKey:@"text"] isEqual:c[2]] &&
              [[line.backing.words valueForKey:@"text"] ?: @[] isEqual:c[3]],
              [NSString stringWithFormat:@"model backing %@ %@", c[0], c[1]]);
        if (line.backing) {
            check(!line.words.firstObject.joined && !line.backing.words.firstObject.joined &&
                  line.backing.timing == SGKaraokeTimingWords,
                  @"split rows start unjoined and retain word timing");
        }
    }
    SGKaraokeLine *explicit = modelLine(@"byModel=\"true\"", @[@"Main", @"(one)"], YES);
    check([[explicit.words valueForKey:@"text"] isEqual:@[@"Main", @"(one)"]] &&
          [SGKaraokeLineText(explicit.backing) isEqual:@"(explicit)"], @"explicit backing wins");
    SGKaraokeLine *timed = modelLine(@"byModel=\"true\"", @[@"Main", @"(one", @"two)"], NO);
    check(timed.backing.start == 1000 && timed.backing.end == 3000, @"backing uses its own word clocks");
    SGKaraokeLine *estimated = SGTTMLLines(@"<tt byModel=\"true\"><body><p begin=\"0\" end=\"10\">Main (one two)</p></body></tt>").firstObject;
    check([SGKaraokeLineText(estimated) isEqual:@"Main"] &&
          [SGKaraokeLineText(estimated.backing) isEqual:@"(one two)"] &&
          estimated.backing.timing == SGKaraokeTimingLine, @"estimated backing retains line timing");

    for (NSNumber *slow in @[@YES, @NO]) {
        SGBudgetView *view = [[SGBudgetView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        view.slow = slow.boolValue;
        view.built = [NSMutableArray array];
        [view setValue:@[@0, @20, @40, @60, @80, @100, @120, @140] forKey:@"tops"];
        [view setValue:[NSMutableDictionary dictionary] forKey:@"shown"];
        [view setValue:@(-CGFLOAT_MAX) forKey:@"sightOffset"];
        [view showLinesInSight];
        check(view.built.count == (slow.boolValue ? 1 : 4),
              slow.boolValue ? @"slow creation stops after the first row" : @"fast creation retains four-row cap");
        check([@[@2, @3] containsObject:view.built.firstObject], @"creation starts nearest viewport centre");
        for (NSUInteger pass = 0; pass < 8; pass++) [view showLinesInSight];
        check(view.built.count == 8 && [NSSet setWithArray:view.built].count == 8,
              @"unchanged viewport resumes until every visible row is built");
    }
}
