#import "Shared/LockScreenLyrics/LockScreenLyrics.h"

// The actual chain and saved store consume the same nonempty-original convention as every provider.
static void checkKeptTranslation(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id order = [defaults objectForKey:SGRKeyLyricsAutoTranslationOrder];
    testLanguage = @"en";
    testKeys = [NSSet set];
    deviceAvailable = autoRetryEnabled = YES;
    bingEnabled = NO;
    [defaults setObject:@[@(SGRAutoTranslatorOnDevice)] forKey:SGRKeyLyricsAutoTranslationOrder];
    SGRAutoTranslationSettingsChanged();
    NSString *track = @"kept-line-regression";
    NSArray *texts = @[@"We walk home together.", @"함께 집으로 걸어가요"];
    NSArray<SGKaraokeLine *> *lines = aiLines(texts);
    deviceAnswer = @[@"We walk home together.", @"We are walking home together."];
    NSUInteger revision = SGRAutoTranslationClaim(track, @"en");
    CHECK(revision);
    __block BOOL finished = NO;
    SGRTranslateLyrics(lines, track, @"en", revision,
        ^(NSArray *sent, NSString *song, NSString *language, SGRAutoTranslated progress, SGRAutoTranslated done) {
            SGRAutoTranslateInOrder(sent, song, language, revision, ^BOOL { return YES; }, progress, done);
        }, nil, ^(NSArray *answer, NSString *error) {
            CHECK(!error);
            finished = YES;
        });
    waitFor(^BOOL { return finished; });
    SGRAutoTranslationProgress *status = SGRAutoTranslationProgressFor(track, @"en");
    CHECK(status.phase == SGRAutoTranslationPhaseComplete && status.completed == 2 && status.total == 2);
    CHECK([lines[0].translation isEqual:@"We walk home together."] && lines[0].translationMade);
    CHECK(SGLyricsShownTranslation(lines[0]) == nil);
    CHECK([SGLyricsShownTranslation(lines[1]) isEqual:@"We are walking home together."]);

    NSArray<SGKaraokeLine *> *restored = aiLines(texts);
    SGLyricsSyncSavedTranslation(track, @"en", restored);
    CHECK([restored[0].translation isEqual:@"We walk home together."] && restored[0].translationMade);
    CHECK(SGLyricsShownTranslation(restored[0]) == nil);
    // Clear the session ledger: persistence, not the "already attempted" guard, must prevent a new request.
    SGRAutoTranslationSettingsChanged();
    NSUInteger before = deviceCalls;
    __block BOOL loaded = NO;
    SGRAutoTranslateWithoutView(track, restored, ^BOOL { return YES; }, ^{ loaded = YES; });
    waitFor(^BOOL { return loaded; });
    CHECK(deviceCalls == before && !SGRTranslationJobRunning(track, @"en"));
    __block BOOL deleted = NO;
    SGLyricsDeleteTranslationWithCompletion(track, @"en", ^(NSError *error) {
        CHECK(!error); deleted = YES;
    });
    waitFor(^BOOL { return deleted; });
    SGLyricsSyncSavedTranslation(track, @"en", restored);
    CHECK(!restored[0].translation && !restored[0].translationMade);
    CHECK(!restored[1].translation && !restored[1].translationMade);
    if (order) [defaults setObject:order forKey:SGRKeyLyricsAutoTranslationOrder];
    else [defaults removeObjectForKey:SGRKeyLyricsAutoTranslationOrder];
    deviceAvailable = autoRetryEnabled = NO;
    testLanguage = nil;
    SGRAutoTranslationSettingsChanged();
    CHECK([NSFileManager.defaultManager removeItemAtURL:SGLyricsTestCacheRoot() error:nil]);
    puts("Kept translations: complete, hidden duplicate, persisted/restored, no repeat request, removal passed");
}
