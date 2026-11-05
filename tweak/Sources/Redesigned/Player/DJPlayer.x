// The AI DJ's player screen drawn the way the redesign draws the ordinary one: previous, play and next as bare
// glyphs, and one row of glyphs under them (Lyrics, Connect, Queue, the DJ button) without the share button.
// The redesign hooks the ordinary player's units and the DJ has its own, so each hook here is a second one on the
// DJ's unit that calls the ordinary player's function: the play glyph (SGRPlayerPlayGlyphIn, PlayerControls.x), the
// lowered row with the volume row and Follow the cover (SGRPlayerLowerRow), Connect (SGRPlayerConnectGlyphIn, SGRPlayerCoverConnect) and the
// Lyrics glyph (SGRPlayerLyricsGlyphIn, PlayerFooter.x). What is the DJ's own is kept here: the skip glyphs, the
// four places of the footer and its Queue button.
//
// Controls: DJMHeadUnitViewController's view holds the previous, next and play buttons directly. The glyphs go
// inside the buttons over their images, which go transparent; the buttons keep their actions and accessibility.
//
// Footer: DJMFooterUnitView holds the share button, the DJ button, Connect and an empty view, not in a stack.
// Connect and the DJ button stay Spotify's and are only moved, by a transform that survives relayout. Lyrics
// and Queue are the Kit's glyph buttons; Queue, the Music app's list.bullet (issue #109), opens spotify:now-playing:queue.
// The DJ button's blue disc is masked away and the Music app's waveform drawn over it: the mask hides what the button
// draws but not its touches or its accessibility, which stay Spotify's. With Music app icons off (SGRKeyPlayerMusicIcons)
// Connect shows Spotify's own glyph again, Lyrics and Queue draw Spotify's Encore glyphs (SGRPlayerFooterGlyph; the
// DJ's footer has no queue control of Spotify's to give back), and the mask and the waveform come out for the disc.
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Shared/Navigation/Links.h"
#import "Player.h"

static const CGFloat kSkipGlyphSize = 32, kFooterGlyphSize = 20;
// Where the four footer glyphs sit, as parts of the footer's width: Lyrics, Connect, Queue, the DJ button.
static const CGFloat kSlots[4] = {0.2, 0.4, 0.6, 0.8};
// The DJ button's blue disc is 48pt, a good deal more than the glyphs beside it; drawn this much of that.
static const CGFloat kDJButtonScale = 0.88;
static char kPrevKey, kNextKey, kPlayKey, kGlyphKey;
static char kShareKey, kConnectKey, kDJKey, kQueueKey, kWaveKey, kDiscMaskKey, kDiscPriorMaskKey;

#pragma mark - previous and next

// How far below its own middle a previous/next glyph must sit to share a line with the play glyph. Spotify's
// head unit puts the 56pt skip buttons and the 64pt play view on one top edge (y=16), so their middles are
// 44 and 48 apart by 4pt, and the glyphs, centred in their buttons, would be too. Measured in the unit's
// coordinates so it follows whatever sizes the unit lays out with; 0 until both are in place.
static CGFloat skipDrop(UIView *host, UIView *button) {
    UIView *play = SGRFindByIdentifier(host, @"SPTNowPlayingPlayButton", &kPlayKey);
    if (!play || !button.superview || !play.superview) return 0;
    CGFloat skipMid = [host convertPoint:CGPointMake(0, CGRectGetMidY(button.frame)) fromView:button.superview].y;
    CGFloat playMid = [host convertPoint:CGPointMake(0, CGRectGetMidY(play.frame)) fromView:play.superview].y;
    CGFloat dy = playMid - skipMid;
    return fabs(dy) < 12 ? dy : 0;
}

static void skipGlyph(UIView *host, NSString *identifier, const void *findKey, NSString *symbol) {
    UIView *button = SGRFindByIdentifier(host, identifier, findKey);
    if (!button) return;
    static Class icon;
    if (!icon) icon = NSClassFromString(@"SPTEncoreIconView");
    SGRGlyphView *glyph = SGRPlayerGlyphFor(button, &kGlyphKey, symbol, kSkipGlyphSize);
    // Spotify's own icon, a Swift view SGRSuppress cannot keep (PlayerControls.x), or a plain image view.
    SGForEachView(button, ^(UIView *view) {
        if (view == glyph) return;
        if (icon && [view isKindOfClass:icon]) SGRVanish(view);
        else if ([view isKindOfClass:UIImageView.class] && view.superview == button) SGRSuppress(view);
    });
    SGRPlayerPlaceGlyph(glyph, button, skipDrop(host, button));
}

static void styleControls(UIViewController *unit) {
    UIView *host = unit.viewIfLoaded;
    if (!host || host.bounds.size.width < 100) return;
    skipGlyph(host, @"SPTNowPlayingPreviousTrackButton", &kPrevKey, @"backward.fill");
    skipGlyph(host, @"SPTNowPlayingNextTrackButton", &kNextKey, @"forward.fill");
    SGRPlayerPlayGlyphIn(host);

    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"AI DJ player: glyphs over previous, play and next in %@", NSStringFromClass(host.class)); });
}

#pragma mark - the footer

// The view of `host`'s own that holds `view`.
static UIView *holderIn(UIView *host, UIView *view) {
    for (UIView *v = view; v && v != host; v = v.superview) {
        if (v.superview == host) return v;
    }
    return nil;
}

// Where `point` of `view` is in the host with the holder's own transform left out.
static CGFloat untransformedX(UIView *holder, UIView *view, CGPoint point) {
    CGPoint local = [view convertPoint:point toView:holder];
    return holder.center.x + local.x - CGRectGetMidX(holder.bounds);
}

static void placeHolder(UIView *holder, CGFloat from, CGFloat to, CGFloat scale) {
    CGAffineTransform transform = CGAffineTransformMake(scale, 0, 0, scale, round(to - from), 0);
    if (!CGAffineTransformEqualToTransform(holder.transform, transform)) holder.transform = transform;
}

static SGRGlyphButton *glyphButtonIn(UIView *host, const void *key, NSString *symbol, NSString *title, UIColor *tint, void (^tap)(void)) {
    SGRGlyphButton *button = objc_getAssociatedObject(host, key);
    if (!button) {
        button = [SGRGlyphButton buttonWithSymbol:symbol pointSize:kFooterGlyphSize title:title];
        button.glyph.tintColor = tint;
        button.onTap = tap;
        objc_setAssociatedObject(host, key, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (button.superview != host) [host addSubview:button];
    return button;
}

// The DJ button as the Music app's waveform while Music app icons is on: an empty mask on its holder, so nothing of the
// disc is drawn while the button keeps its touches and accessibility, and the glyph over it, which takes neither. Off,
// the mask goes (a mask the holder had before ours comes back) and so does the glyph.
static void drawDJButton(UIView *host, UIView *djHolder) {
    CALayer *mask = objc_getAssociatedObject(djHolder, &kDiscMaskKey);
    SGRGlyphView *wave = objc_getAssociatedObject(host, &kWaveKey);
    if (!SGEnabled(SGRKeyPlayerMusicIcons)) {
        if (mask && djHolder.layer.mask == mask) {
            djHolder.layer.mask = objc_getAssociatedObject(djHolder, &kDiscPriorMaskKey);
            objc_setAssociatedObject(djHolder, &kDiscPriorMaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (wave.superview) [wave removeFromSuperview];
        return;
    }
    if (!mask) {
        mask = [CALayer layer];
        objc_setAssociatedObject(djHolder, &kDiscMaskKey, mask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (djHolder.layer.mask != mask) {
        objc_setAssociatedObject(djHolder, &kDiscPriorMaskKey, djHolder.layer.mask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        djHolder.layer.mask = mask;
    }
    wave = SGRPlayerGlyphFor(host, &kWaveKey, @"waveform", kFooterGlyphSize);
    if (wave.superview != host) [host addSubview:wave];
    else if (host.subviews.lastObject != wave) [host bringSubviewToFront:wave];
    // Where the holder is drawn: its center moved by the transform that places it (placeHolder scales about the center).
    CGPoint drawn = CGPointMake(djHolder.center.x + djHolder.transform.tx, djHolder.center.y + djHolder.transform.ty);
    if (!CGPointEqualToPoint(wave.center, drawn)) wave.center = drawn;
}

#pragma mark the row

static void styleFooter(UIViewController *unit) {
    UIView *host = unit.viewIfLoaded;
    if (!host || host.bounds.size.width < 100) return;
    // Laid out again when Music app icons is flipped on the Player page (SGRKeyPlayerMusicIcons): Connect follows it
    // through SGRPlayerConnectGlyphIn, Lyrics and Queue through SGRPlayerFooterGlyph, the DJ button through drawDJButton.
    SGRPlayerWatchLook(host);
    CGFloat width = host.bounds.size.width, middleY = CGRectGetMidY(host.bounds);
    BOOL rtl = host.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    CGFloat (^slot)(NSUInteger) = ^CGFloat(NSUInteger i) { return round(width * (rtl ? 1 - kSlots[i] : kSlots[i])); };

    // No share button; its holder goes too, since a view that takes touches swallows them with nothing on it. Spotify
    // gives both their alpha back after the footer lays out, which the disc over them hid and the waveform does not, so
    // both are masked away too (SGRBlankView), and the DJ button goes above the holder (below).
    UIView *share = SGRFindByIdentifier(host, @"ShareButtonNowPlayingView", &kShareKey);
    UIView *shareHolder = holderIn(host, share);
    SGRVanish(share);
    SGRBlankView(share);
    SGRVanish(shareHolder);
    SGRBlankView(shareHolder);

    SGRGlyphButton *lyrics = SGRPlayerLyricsGlyphIn(host);
    lyrics.bounds = CGRectMake(0, 0, 44, 44);
    lyrics.center = CGPointMake(slot(0), middleY);
    SGRPlayerLyricsChanged();

    // Connect: the glyph alone, its device name gone, at the second place; left where Spotify put it until the glyph has a size.
    UIView *connect = SGRFindByIdentifier(host, @"Components.ConnectButtonOutputSwitcher", &kConnectKey);
    UIView *connectHolder = holderIn(host, connect);
    UIView *glyph = SGRPlayerConnectGlyphIn(host, connect);
    if (connectHolder && glyph) {
        CGFloat from = untransformedX(connectHolder, glyph, CGPointMake(CGRectGetMidX(glyph.bounds), CGRectGetMidY(glyph.bounds)));
        placeHolder(connectHolder, from, slot(1), 1);
        // Its view reaches far to the right of the glyph, over Queue and the DJ button: touches only over the glyph.
        SGRPlayerCoverConnect(connectHolder, glyph);
    }

    SGRGlyphButton *queue = glyphButtonIn(host, &kQueueKey, @"list.bullet", @"Queue", SGRPrimary(), ^{
        SGOpenSpotifyURI([NSURL URLWithString:@"spotify:now-playing:queue"]);
    });
    queue.bounds = CGRectMake(0, 0, 44, 44);
    queue.center = CGPointMake(slot(2), middleY);
    SGRPlayerFooterGlyph(queue, @"queue");

    // The DJ button at the last place. Connect's view reaches a long way to the right of its glyph, and the share
    // holder sits under the button, so the DJ's goes above both, or they would take its touches.
    UIView *dj = SGRFindByIdentifier(host, @"Components.UI.NeffleButtonNowPlayingContainerView", &kDJKey);
    UIView *djHolder = holderIn(host, dj);
    if (djHolder) {
        placeHolder(djHolder, djHolder.center.x, slot(3), kDJButtonScale);
        NSArray<UIView *> *order = host.subviews;
        NSUInteger djAt = [order indexOfObject:djHolder];
        for (UIView *below in @[connectHolder ?: djHolder, shareHolder ?: djHolder]) {
            if (djAt < [order indexOfObject:below]) {
                [host bringSubviewToFront:djHolder];
                break;
            }
        }
        drawDJButton(host, djHolder);
    }

    SGRPlayerLowerRow(host);

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGLog(@"AI DJ player: footer %.0f wide, lyrics %.0f, connect %@ to %.0f, queue %.0f, DJ %@ to %.0f, share %@", width, slot(0),
              glyph ? @"glyph" : @"button", slot(1), slot(2), djHolder ? @"found" : @"not found", slot(3), share ? @"gone" : @"not found");
    });
}

#pragma mark - hooks

// Groups only, installed when the build has the DJ's classes.
%group SGRDJHeadHooks
%hook SGRDJHeadUnit
- (void)viewDidLayoutSubviews {
    %orig;
    styleControls((UIViewController *)self);
}
%end
%end

%group SGRDJFooterHooks
%hook SGRDJFooterUnit
- (void)viewDidLayoutSubviews {
    %orig;
    styleFooter((UIViewController *)self);
}
%end
%end

%ctor {
    if (!SGRedesignedUI()) return;
    Class head = SGRDJClass(@"DJMHeadUnitViewController");
    if (head) {
        %init(SGRDJHeadHooks, SGRDJHeadUnit = head);
    } else {
        SGLog(@"class DJMHeadUnitViewController not found, the AI DJ controls keep Spotify's own");
    }
    Class footer = SGRDJClass(@"DJMFooterUnitViewController");
    if (footer) {
        %init(SGRDJFooterHooks, SGRDJFooterUnit = footer);
    } else {
        SGLog(@"class DJMFooterUnitViewController not found, the AI DJ footer keeps Spotify's own");
    }
}
