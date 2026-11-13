#import "AudioQualityRules.h"
#import "Core/SGLocalize.h"

SGAudioTier SGAudioTierForBitrateLevel(long long bitrateLevel) {
    switch (bitrateLevel) {
        case 1: return SGAudioTierLow;
        case 2: return SGAudioTierNormal;
        case 3: return SGAudioTierHigh;
        case 4: return SGAudioTierVeryHigh;
        case 5: return SGAudioTierLossless;
        case 6: return SGAudioTierLossless24;
        default: return SGAudioTierNone;
    }
}

SGAudioSource SGAudioSourceForStrategy(long long strategy) {
    switch (strategy) {
        case 1: case 2: return SGAudioSourceStreamed;
        case 3: return SGAudioSourceDownloaded;
        case 4: return SGAudioSourceCached;
        case 5: return SGAudioSourceLocalFile;
        default: return SGAudioSourceUnknown;
    }
}

SGAudioTier SGAudioTierShown(BOOL on, BOOL playingLocally, NSString *trackURI, long long bitrateLevel) {
    if (!on || !playingLocally || ![trackURI hasPrefix:@"spotify:track:"]) return SGAudioTierNone;
    return SGAudioTierForBitrateLevel(bitrateLevel);
}

BOOL SGAudioTierIsLossless(SGAudioTier tier) {
    return tier == SGAudioTierLossless || tier == SGAudioTierLossless24;
}

NSString *SGAudioTierName(SGAudioTier tier) {
    switch (tier) {
        case SGAudioTierNone: return nil;
        case SGAudioTierLow: return SGL(@"player.audio_quality.tier.low", @"Low");
        case SGAudioTierNormal: return SGL(@"player.audio_quality.tier.normal", @"Normal");
        case SGAudioTierHigh: return SGL(@"player.audio_quality.tier.high", @"High");
        case SGAudioTierVeryHigh: return SGL(@"player.audio_quality.tier.very_high", @"Very high");
        case SGAudioTierLossless: return SGL(@"player.audio_quality.tier.lossless", @"Lossless");
        case SGAudioTierLossless24: return SGL(@"player.audio_quality.tier.lossless_24", @"Lossless 24-bit");
    }
    return nil;
}

NSString *SGAudioSourceName(SGAudioSource source) {
    switch (source) {
        case SGAudioSourceUnknown: return nil;
        case SGAudioSourceStreamed: return SGL(@"player.audio_quality.source.streamed", @"Streamed");
        case SGAudioSourceDownloaded: return SGL(@"player.audio_quality.source.downloaded", @"Downloaded");
        case SGAudioSourceCached: return SGL(@"player.audio_quality.source.cached", @"Cached");
        case SGAudioSourceLocalFile: return SGL(@"player.audio_quality.source.local_file", @"Local file");
    }
    return nil;
}

BOOL SGAudioQualityDetailsStay(NSString *openedFor, NSString *playing, SGAudioTier tier, BOOL badgeShown) {
    return openedFor && [openedFor isEqualToString:playing] && tier != SGAudioTierNone && badgeShown;
}

// UIKit's own floor for a view that takes touches.
static const CGFloat kDrawnAlpha = 0.01;

BOOL SGAudioQualityViewDrawn(id<SGAudioQualityViewChain> view) {
    if (!view) return NO;
    for (id<SGAudioQualityViewChain> v = view; v; v = [v superview]) {
        if ([v isHidden] || [v alpha] < kDrawnAlpha) return NO;
    }
    return YES;
}

NSString *SGAudioSampleRateText(long long hertz) {
    if (hertz <= 0) return nil;
    // Spotify writes its own rates with a point in every language ("16-bit/44.1 kHz").
    NSString *kilohertz = hertz % 1000 == 0 ? [NSString stringWithFormat:@"%lld", hertz / 1000]
                                            : [NSString stringWithFormat:@"%.1f", hertz / 1000.0];
    return [NSString stringWithFormat:SGL(@"player.audio_quality.khz", @"%@ kHz"), kilohertz];
}
