// Real Bing parsing, automatic chain and saved store; only the HTTP response is scripted.
static void checkBingCompletion(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id savedOrder = [defaults objectForKey:SGRKeyLyricsAutoTranslationOrder];
    NSString *savedLanguage = testLanguage;
    BOOL savedBing = bingEnabled, savedAuto = autoRetryEnabled;
    testLanguage = @"ko-KR";
    bingEnabled = autoRetryEnabled = YES;
    [defaults setObject:@[@(SGRAutoTranslatorBing)] forKey:SGRKeyLyricsAutoTranslationOrder];
    SGRAutoTranslationSettingsChanged();

    // A full reply must leave Running even when every missing line was filled in one callback.
    // A skip after sending may keep that answer, but must still retire the old song's job.
    for (NSNumber *skip in @[@NO, @YES]) {
        NSString *track = skip.boolValue ? @"bing-completion-skipped" : @"bing-completion-visible";
        NSArray *texts = @[@"Already translated", @"Blue robot", @"Green robot"];
        NSArray<SGKaraokeLine *> *lines = aiLines(texts);
        lines[0].translation = @"원본 번역";
        bingReplies = [@[bingReply(@"파란 로봇\n초록 로봇")] mutableCopy];
        NSUInteger revision = SGRAutoTranslationClaim(track, @"ko-KR");
        CHECK(revision);
        __block BOOL visible = YES, finished = NO;
        SGRTranslateLyrics(lines, track, @"ko-KR", revision,
            ^(NSArray *sent, NSString *song, NSString *language, SGRAutoTranslated progress, SGRAutoTranslated done) {
                SGRAutoTranslateInOrder(sent, song, language, revision, ^BOOL { return visible; }, progress, done);
            }, nil, ^(NSArray *answer, NSString *error) {
                CHECK(!error);
                finished = YES;
            });
        if (skip.boolValue) visible = NO;
        waitFor(^BOOL { return finished; });
        SGRAutoTranslationProgress *status = SGRAutoTranslationProgressFor(track, @"ko-KR");
        CHECK(status.phase == SGRAutoTranslationPhaseComplete && status.completed == 2 && status.total == 2);
        CHECK(!SGRTranslationJobRunning(track, @"ko-KR"));
        CHECK([lines[0].translation isEqual:@"원본 번역"]);
        CHECK([SGLyricsShownTranslation(lines[1]) isEqual:@"파란 로봇"]);
        CHECK([SGLyricsShownTranslation(lines[2]) isEqual:@"초록 로봇"]);
        NSArray<SGKaraokeLine *> *restored = aiLines(texts);
        SGLyricsSyncSavedTranslation(track, @"ko-KR", restored);
        CHECK([SGLyricsShownTranslation(restored[1]) isEqual:@"파란 로봇"]);
        CHECK([SGLyricsShownTranslation(restored[2]) isEqual:@"초록 로봇"]);
        __block BOOL deleted = NO;
        SGLyricsDeleteTranslationWithCompletion(track, @"ko-KR", ^(NSError *error) {
            CHECK(!error); deleted = YES;
        });
        waitFor(^BOOL { return deleted; });
    }

    if (savedOrder) [defaults setObject:savedOrder forKey:SGRKeyLyricsAutoTranslationOrder];
    else [defaults removeObjectForKey:SGRKeyLyricsAutoTranslationOrder];
    testLanguage = savedLanguage; bingEnabled = savedBing; autoRetryEnabled = savedAuto;
    bingReplies = nil;
    SGRAutoTranslationSettingsChanged();
    CHECK([NSFileManager.defaultManager removeItemAtURL:SGLyricsTestCacheRoot() error:nil]);
    puts("Bing completion: full reply finishes, missing rows map and persist, skip retires the old job");
}
