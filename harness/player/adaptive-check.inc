// A Spotify-unit fixture, driven through the same hooked layout callbacks as the phone scenarios.
static UIButton *lyricsMenuIn(UIView *stage) {
    __block UIButton *menu = nil;
    SGForEachView(stage, ^(UIView *view) {
        if ([view isKindOfClass:UIButton.class] && ((UIButton *)view).showsMenuAsPrimaryAction && !view.hidden) menu = (UIButton *)view;
    });
    return menu;
}

- (void)runAdaptiveChecks {
    runScript(@[
        @[^BOOL {
            return SGRNowPlayingArtwork(NULL, NULL) != nil;
        }, ^{
            [self layOut];
            [self layOut];
            BOOL wide = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad && !getenv("HARNESS_COMPACT");
            UIView *bottom = SGRFindByIdentifier(self->_host, @"npv.bottomStackView", NULL);
            if (!wide) {
                HARNESS_CHECK(!SGRPlayerTwoColumns());
                HARNESS_CHECK(fabs(bottom.frame.size.width - self->_host.bounds.size.width) < 1);
                HARNESS_CHECK(!SGRPlayerLyricsOpen());
            } else {
                HARNESS_CHECK(SGRPlayerTwoColumns());
                HARNESS_CHECK(getenv("HARNESS_NO_LYRICS") ? SGRPlayerQueueSideShown() : SGRPlayerLyricsOpen());
                UIView *overlay = firstOfClass(self->_host, @"SGRPlayerLyricsOverlay");
                UIView *stage = [overlay valueForKey:@"stage"], *cover = [overlay valueForKey:@"thumb"];
                CGRect art = [cover convertRect:cover.bounds toView:self->_host];
                CGRect side = [stage convertRect:stage.bounds toView:self->_host];
                CGRect controls = [bottom convertRect:bottom.bounds toView:self->_host];
                BOOL rtl = getenv("HARNESS_RTL") != NULL;
                HARNESS_CHECK(art.size.width >= 72 && fabs(art.size.width - art.size.height) < 1);
                HARNESS_CHECK(CGRectGetMaxY(art) <= CGRectGetMinY(controls));
                HARNESS_CHECK(rtl ? CGRectGetMaxX(side) <= CGRectGetMinX(controls) :
                                   CGRectGetMaxX(controls) <= CGRectGetMinX(side));
                HARNESS_CHECK(CGRectContainsRect(self->_host.bounds, side));
                HARNESS_CHECK(CGRectContainsRect(self->_host.bounds, art));
                HARNESS_CHECK(CGRectContainsRect(self.window.rootViewController.view.bounds, self->_host.frame));
                HARNESS_CHECK([self->_host.accessibilityElements indexOfObject:bottom] <
                              [self->_host.accessibilityElements indexOfObject:overlay]);
                SGRGlyphButton *queue = (id)SGRFindByIdentifier(self->_host, @"vitrine.player.queue", NULL);
                HARNESS_CHECK(queue && queue.accessibilityLabel.length && queue.bounds.size.width >= 44);
                queue.onTap();
                HARNESS_CHECK(SGRPlayerQueueSideShown());
                UITableView *list = (id)SGRFindByIdentifier(stage, @"vitrine.queue", NULL);
                HARNESS_CHECK(list && list.window && list.bounds.size.height > 100);
                HARNESS_CHECK([list numberOfSections] > 0);
                SGRPlayerToggleLyrics();
                HARNESS_CHECK(getenv("HARNESS_NO_LYRICS") ? SGRPlayerQueueSideShown() : SGRPlayerLyricsOpen());
                self.window.traitOverrides.horizontalSizeClass = UIUserInterfaceSizeClassCompact;
                [self layOut];
                HARNESS_CHECK(!SGRPlayerTwoColumns() && !overlay.superview);
                HARNESS_CHECK(fabs(bottom.frame.size.width - self->_host.bounds.size.width) < 1);
                CGRect singleControls = bottom.frame;
                self.window.traitOverrides.horizontalSizeClass = UIUserInterfaceSizeClassRegular;
                [self layOut];
                [self layOut];
                HARNESS_CHECK(SGRPlayerTwoColumns());
                if (getenv("HARNESS_SHRINK")) {
                    CGRect fullHost = self->_host.frame;
                    // A short, regular-width window leaves no artwork band over Spotify's control units.
                    CGRect shortHost = fullHost;
                    shortHost.size.height = 480;
                    self->_host.frame = shortHost;
                    CGRect singleColumn = CGRectMake(0, 140, fullHost.size.width, 280);
                    bottom.frame = singleColumn;
                    [self layOut];
                    HARNESS_CHECK(self.window.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular);
                    HARNESS_CHECK(!SGRPlayerTwoColumns() && !overlay.superview && !SGRPlayerLyricsOpen());
                    if (!CGRectEqualToRect(bottom.frame, singleColumn)) {
                        HARNESS_FAIL(@"shrunken controls %@, expected %@", NSStringFromCGRect(bottom.frame), NSStringFromCGRect(singleColumn));
                    }
                    HARNESS_CHECK(self->_covers.alpha == 1);
                    [self layOut];
                    HARNESS_CHECK(CGRectEqualToRect(bottom.frame, singleColumn) && !overlay.superview);
                    self->_host.frame = fullHost;
                    bottom.frame = singleControls;
                    [self layOut];
                    HARNESS_CHECK(SGRPlayerTwoColumns());
                    NSLog(@"[harness] regular-width shrink restores single-column frames: PASS");
                }
                NSLog(@"[harness] adaptive frames: artwork %@ controls %@ side %@", NSStringFromCGRect(art),
                      NSStringFromCGRect(controls), NSStringFromCGRect(side));
            }
        }],
        @[^BOOL {
            if (!SGRPlayerTwoColumns() || SGRPlayerQueueSideShown()) return YES;
            UIView *overlay = firstOfClass(self->_host, @"SGRPlayerLyricsOverlay");
            UIView *lyrics = [overlay valueForKey:@"madeLyrics"];
            CALayer *drawn = lyrics.layer.presentationLayer;
            return drawn && drawn.opacity > 0.99 && lyricsMenuIn([overlay valueForKey:@"stage"]) != nil;
        }, ^{
            if (SGRPlayerTwoColumns()) {
                CGRect safe = self.window.safeAreaLayoutGuide.layoutFrame;
                UIView *footer = self->_units[5].view;
                CGRect row = [footer convertRect:footer.bounds toView:self.window];
                if (!CGRectContainsRect(safe, row)) HARNESS_FAIL(@"footer %@ outside window safe area %@", NSStringFromCGRect(row), NSStringFromCGRect(safe));
                UIView *overlay = firstOfClass(self->_host, @"SGRPlayerLyricsOverlay");
                UIView *stage = [overlay valueForKey:@"stage"];
                CGRect side = [stage convertRect:stage.bounds toView:self.window];
                HARNESS_CHECK(CGRectContainsRect(safe, side));
                if (SGRPlayerLyricsOpen()) {
                    UIButton *options = lyricsMenuIn(stage);
                    HARNESS_CHECK(options != nil && options.accessibilityLabel.length > 0);
                    CGRect frame = [options convertRect:options.bounds toView:self.window];
                    HARNESS_CHECK(CGRectContainsRect(side, frame) && CGRectContainsRect(safe, frame));
                    HARNESS_CHECK(!CGRectIntersectsRect(row, frame));
                }
                NSLog(@"[harness] safe footer %@ lyrics column %@", NSStringFromCGRect(row), NSStringFromCGRect(side));
            }
            NSLog(@"[harness] adaptive checks: PASS");
            fflush(stdout);
        }]
    ], 0);
}
