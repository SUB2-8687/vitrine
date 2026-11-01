// Renders lines of lyrics through the tweak's own SGLyricsClip.m, both styles and every layout, and reads every file back
// with AVFoundation: its length, its size, its frames, and that the words came out where they should.
// Each clip's first frame is kept beside it as a PNG to look at. Exits 1 on any failure.
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "Shared/LockScreenLyrics/SGLyricsClip.h"
#import "Shared/LyricsBackground/LyricsBackground.h"
#import "fixtures.h"

static int failures;
// Full-width 3:4 frame, placed 10% down a 1179x2556 screen. Words occupy screen y=17...65%.
static const CGFloat kWordsFrom = (.17 - .10) / (1179.0 / 2556 * 4 / 3);
static const CGFloat kWordsTo = (.65 - .10) / (1179.0 / 2556 * 4 / 3);

static void check(BOOL ok, NSString *what) {
    printf("  %s %s\n", ok ? "ok  " : "FAIL", what.UTF8String);
    if (!ok) failures++;
}

static CGImageRef newImageAt(NSString *path) {
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
    if (!source) return NULL;
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CFRelease(source);
    return image;
}

static void savePNG(CGImageRef image, NSURL *url) {
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)url, (__bridge CFStringRef)UTTypePNG.identifier, 1, NULL);
    CGImageDestinationAddImage(destination, image, NULL);
    CGImageDestinationFinalize(destination);
    CFRelease(destination);
}

// The share of pixels in a band of rows lighter than the backdrop's by 30 of 255 a channel or more:
// the words, white or dimmed, and not the cover. `backdrop` NULL counts near-white pixels instead.
static double wordsIn(CGImageRef image, CGImageRef backdrop, CGFloat fromY, CGFloat toY) {
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    const uint8_t *pixels = CGBitmapContextGetData(context);
    CGContextRef under = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    if (backdrop) CGContextDrawImage(under, CGRectMake(0, 0, width, height), backdrop);
    const uint8_t *base = CGBitmapContextGetData(under);
    size_t white = 0, all = 0;
    // Rows counted from the top.
    for (size_t y = (size_t)(fromY * height); y < (size_t)(toY * height); y++) {
        for (size_t x = 0; x < width; x++) {
            const uint8_t *p = pixels + y * width * 4 + x * 4;
            const uint8_t *b = base + y * width * 4 + x * 4;
            BOOL lit = backdrop ? p[0] + p[1] + p[2] > b[0] + b[1] + b[2] + 90 : p[0] > 230 && p[1] > 230 && p[2] > 230;
            if (lit) white++;
            all++;
        }
    }
    CGContextRelease(context);
    CGContextRelease(under);
    CGColorSpaceRelease(space);
    return all ? (double)white / all : 0;
}

// The box, in pixels from the top left, of the pixels lighter than the backdrop's as wordsIn counts them.
static CGRect litBounds(CGImageRef image, CGImageRef backdrop) {
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextRef under = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGContextDrawImage(under, CGRectMake(0, 0, width, height), backdrop);
    const uint8_t *pixels = CGBitmapContextGetData(context), *base = CGBitmapContextGetData(under);
    size_t minX = width, maxX = 0, minY = height, maxY = 0;
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            const uint8_t *p = pixels + (y * width + x) * 4, *b = base + (y * width + x) * 4;
            if (p[0] + p[1] + p[2] <= b[0] + b[1] + b[2] + 90) continue;
            minX = MIN(minX, x), maxX = MAX(maxX, x), minY = MIN(minY, y), maxY = MAX(maxY, y);
        }
    }
    CGContextRelease(context);
    CGContextRelease(under);
    CGColorSpaceRelease(space);
    return minX > maxX ? CGRectNull : CGRectMake(minX, minY, maxX - minX + 1, maxY - minY + 1);
}

static void verify(NSURL *url, CGImageRef backdrop, CGSize size, SGLyricsClipStyle style, BOOL hasWords) {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @YES}];
    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    double seconds = CMTimeGetSeconds(asset.duration);
    double wanted = style == SGLyricsClipAnimated ? 4 : 2;
    check(track != nil, @"has a video track");
    if (!track) return;
    check(track.naturalSize.width * 4 == track.naturalSize.height * 3
          && fmod(track.naturalSize.width, 2) == 0 && fmod(track.naturalSize.height, 2) == 0,
          @"cover clip is exactly 3:4 with even sides");
    check(fabs(seconds - wanted) < 0.05, [NSString stringWithFormat:@"lasts %.3f s (want %.0f)", seconds, wanted]);
    check(CGSizeEqualToSize(track.naturalSize, size), [NSString stringWithFormat:@"is %.0fx%.0f (want %.0fx%.0f)",
        track.naturalSize.width, track.naturalSize.height, size.width, size.height]);
    FourCharCode codec = CMFormatDescriptionGetMediaSubType((__bridge CMFormatDescriptionRef)track.formatDescriptions.firstObject);
    check(codec == kCMVideoCodecType_H264, @"is H.264");

    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:nil];
    AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:nil];
    [reader addOutput:output];
    [reader startReading];
    int samples = 0;
    CMSampleBufferRef sample;
    while ((sample = [output copyNextSampleBuffer])) {
        if (CMSampleBufferGetNumSamples(sample)) samples++;
        CFRelease(sample);
    }
    int wantedSamples = style == SGLyricsClipAnimated ? 60 : 1;
    check(samples == wantedSamples, [NSString stringWithFormat:@"holds %d frames (want %d)", samples, wantedSamples]);

    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.requestedTimeToleranceBefore = generator.requestedTimeToleranceAfter = kCMTimeZero;
    CGImageRef first = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:nil];
    CGImageRef late = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(wanted - 0.1, 600) actualTime:NULL error:nil];
    check(first && late, @"frames read back at the start and the end");
    if (first) {
        savePNG(first, [url URLByAppendingPathExtension:@"png"]);
        // Against the backdrop, so the dimmed lines count too.
        double middle = wordsIn(first, backdrop, kWordsFrom, kWordsTo);
        double top = wordsIn(first, backdrop, 0, kWordsFrom), bottom = wordsIn(first, backdrop, kWordsTo, 1);
        // Keep the same minimum ink count as 0.2% of the old half-frame band, independent of
        // the now larger safe region's area. A wider safe region must not dilute a valid small line.
        if (hasWords) check(middle * (kWordsTo - kWordsFrom) > 0.001,[NSString stringWithFormat:@"words between the clock and the controls (%.2f%% lit)", middle * 100]);
        else check(middle < 0.001, [NSString stringWithFormat:@"no words when there are none (%.2f%% lit)", middle * 100]);
        check(top < 0.001 && bottom < 0.001, [NSString stringWithFormat:@"no words under the clock or the controls (%.3f%% / %.3f%% lit)",
                                                                        top * 100, bottom * 100]);
    }
    if (first && late) {
        // A still holds its frame to the end; it is the frame the preview image shows too. The encoder's loss on the
        // edges of the letters grows with them: a block filling the space can move by some 4%.
        double a = wordsIn(first, NULL, kWordsFrom, kWordsTo), b = wordsIn(late, NULL, kWordsFrom, kWordsTo);
        check(fabs(a - b) < MAX(0.002, a * 0.06), [NSString stringWithFormat:@"the words hold still to the end (%.3f%% / %.3f%%)", a * 100, b * 100]);
        // Coverage alone passes a block moved whole: its box must stay put too, within the encoder's few pixels.
        if (hasWords) {
            CGRect from = litBounds(first, backdrop), to = litBounds(late, backdrop);
            BOOL same = !CGRectIsNull(from) && !CGRectIsNull(to) && fabs(CGRectGetMinX(from) - CGRectGetMinX(to)) <= 4
                && fabs(CGRectGetMinY(from) - CGRectGetMinY(to)) <= 4 && fabs(CGRectGetMaxX(from) - CGRectGetMaxX(to)) <= 4
                && fabs(CGRectGetMaxY(from) - CGRectGetMaxY(to)) <= 4;
            check(same, [NSString stringWithFormat:@"the words' box holds still to the end (%@ / %@)", NSStringFromRect(from), NSStringFromRect(to)]);
        }
    }
    CGImageRelease(first);
    CGImageRelease(late);
}

int motionMain(NSURL *out, int argc, char **argv);
int scenesMain(NSURL *out, CGImageRef cover);

int main(int argc, char **argv) {
    @autoreleasepool {
        NSString *here = [[NSString stringWithUTF8String:argv[0]] stringByDeletingLastPathComponent];
        if (argc > 1 && !strcmp(argv[1], "motion")) {
            NSURL *motionOut = [NSURL fileURLWithPath:[here stringByAppendingPathComponent:@"motion"] isDirectory:YES];
            [NSFileManager.defaultManager createDirectoryAtURL:motionOut withIntermediateDirectories:YES attributes:nil error:nil];
            return motionMain(motionOut, argc - 2, argv + 2);
        }
        NSURL *scenesOut = [NSURL fileURLWithPath:[here stringByAppendingPathComponent:@"scenes"] isDirectory:YES];
        [NSFileManager.defaultManager createDirectoryAtURL:scenesOut withIntermediateDirectories:YES attributes:nil error:nil];
        if (argc > 1 && !strcmp(argv[1], "scenes")) {
            CGImageRef cover = argc > 2 ? newImageAt([NSString stringWithUTF8String:argv[2]]) : newCover();
            int failed = scenesMain(scenesOut, cover);
            CGImageRelease(cover);
            return failed ? 1 : 0;
        }
        NSURL *out = [NSURL fileURLWithPath:[here stringByAppendingPathComponent:@"clips"] isDirectory:YES];
        [NSFileManager.defaultManager createDirectoryAtURL:out withIntermediateDirectories:YES attributes:nil error:nil];
        CGImageRef cover = argc > 1 ? newImageAt([NSString stringWithUTF8String:argv[1]]) : newCover();
        // Fallbacks use the screen raster, not the independent moving-artwork download width.
        for (NSNumber *pixels in @[@904, @1170, @1179, @1206]) {
            CGSize raster = SGLyricsClipSize(pixels.doubleValue);
            check(raster.width * 4 == raster.height * 3 && fmod(raster.width, 16) == 0
                  && fmod(raster.height, 16) == 0 && raster.width <= pixels.doubleValue,
                  [NSString stringWithFormat:@"fallback raster for %@ pixels is exactly 3:4 and encoder-aligned", pixels]);
        }
        CGSize size = SGLyricsClipSize(1170);
        CFAbsoluteTime made = CFAbsoluteTimeGetCurrent();
        CGImageRef backdrop = SGLyricsClipBackdrop(cover, size);
        printf("the default backdrop, %.0fx%.0f: %.0f ms\n", size.width, size.height, (CFAbsoluteTimeGetCurrent() - made) * 1000);
        CGImageRef plain = SGLyricsClipBackdrop(NULL, size);
        NSArray *cases = clipCases();
        // Every case in each layout, Left (the files' plain names) in both styles, the others Still.
        NSArray *layoutNames = @[@"", @"-centered", @"-poster"];
        for (SGLyricsClipLayout layout = SGLyricsClipLeft; layout <= SGLyricsClipPoster; layout++) {
            for (NSArray *c in cases) {
                SGLyricsClipStyle last = layout == SGLyricsClipLeft ? SGLyricsClipAnimated : SGLyricsClipStill;
                for (SGLyricsClipStyle style = SGLyricsClipStill; style <= last; style++) {
                    NSString *name = [NSString stringWithFormat:@"%@%@-%@.mp4", c[0], layoutNames[layout], style == SGLyricsClipStill ? @"still" : @"animated"];
                    NSURL *url = [out URLByAppendingPathComponent:name];
                    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
                    BOOL written = SGLyricsClipWriteWithLayout(url, [c[0] isEqual:@"empty"] ? plain : backdrop, NULL, nil, c[1], c[2], c[3],
                                                               size, style, layout);
                    double ms = (CFAbsoluteTimeGetCurrent() - start) * 1000;
                    printf("%s\n", name.UTF8String);
                    check(written, [NSString stringWithFormat:@"written in %.0f ms", ms]);
                    CGImageRef preview = SGLyricsClipFrameWithLayout([c[0] isEqual:@"empty"] ? plain : backdrop, NULL, nil,
                                                                      c[1], c[2], c[3], size, layout);
                    check(preview && CGImageGetWidth(preview) == size.width && CGImageGetHeight(preview) == size.height
                          && CGImageGetWidth(preview) * 4 == CGImageGetHeight(preview) * 3,
                          @"cover preview matches the exact 3:4 clip raster");
                    CGImageRelease(preview);
                    if (!written) continue;
                    NSNumber *bytes = nil;
                    [url getResourceValue:&bytes forKey:NSURLFileSizeKey error:nil];
                    printf("  %.0f KB\n", bytes.doubleValue / 1024);
                    verify(url, [c[0] isEqual:@"empty"] ? plain : backdrop, size, style, [c[1] length] || [c[3] length]);
                }
            }
        }
        // What each layout does with the words, on the preview frame (the clip's, before the encoder).
        printf("layouts\n");
        {
            CGImageRef leftFrame = SGLyricsClipFrame(backdrop, @"Hold on", nil, @"we're almost there", size);
            CGImageRef centredFrame = SGLyricsClipFrameWithLayout(backdrop, NULL, nil, @"Hold on", nil, @"we're almost there", size,
                                                                  SGLyricsClipCentered);
            CGRect left = litBounds(leftFrame, backdrop), centred = litBounds(centredFrame, backdrop);
            CGImageRelease(leftFrame);
            CGImageRelease(centredFrame);
            CGFloat strip = size.width, from = 0;
            check(fabs(CGRectGetMinX(left) - (from + strip * 0.08)) < size.width * 0.01,
                  [NSString stringWithFormat:@"Left starts 8%% of the strip in (at %.0f, want %.0f)", CGRectGetMinX(left), from + strip * 0.08]);
            check(fabs(CGRectGetMidX(centred) - size.width / 2) < size.width * 0.01 && CGRectGetMinX(centred) > CGRectGetMinX(left) + size.width * 0.05,
                  [NSString stringWithFormat:@"Centered sits in the middle (%.0f to %.0f of %.0f)", CGRectGetMinX(centred), CGRectGetMaxX(centred), size.width]);
            check(fabs(CGRectGetMidY(centred) - CGRectGetMidY(left)) < 2, @"Centered at Left's height");
            CGImageRef alone = SGLyricsClipFrame(backdrop, @"Hold on", nil, nil, size);
            CGImageRef poster = SGLyricsClipFrameWithLayout(backdrop, NULL, nil, @"Hold on", nil, nil, size, SGLyricsClipPoster);
            CGImageRef posterNext = SGLyricsClipFrameWithLayout(backdrop, NULL, nil, @"Hold on", nil, @"we're almost there", size,
                                                                SGLyricsClipPoster);
            CGImageRef posterTold = SGLyricsClipFrameWithLayout(backdrop, NULL, nil, @"Hold on", @"조금만 버텨", @"we're almost there",
                                                                size, SGLyricsClipPoster);
            double small = wordsIn(alone, backdrop, kWordsFrom, kWordsTo), large = wordsIn(poster, backdrop, kWordsFrom, kWordsTo);
            CGRect a = litBounds(alone, backdrop), p = litBounds(poster, backdrop);
            check(p.size.height > a.size.height * 1.45 && large > small * 2,
                  [NSString stringWithFormat:@"Poster's line is larger and heavier (%.0f px tall, %.2f%% lit; Left %.0f px, %.2f%%)",
                   p.size.height, large * 100, a.size.height, small * 100]);
            check(fabs(CGRectGetMinX(p) - CGRectGetMinX(a)) < size.width * 0.01, @"Poster is left-aligned as Left is");
            check(fabs(wordsIn(posterNext, backdrop, 0, 1) - wordsIn(poster, backdrop, 0, 1)) < 0.00001, @"Poster shows no next line");
            check(wordsIn(posterTold, backdrop, kWordsFrom, kWordsTo) > wordsIn(posterNext, backdrop, kWordsFrom, kWordsTo),
                  @"Poster keeps the translation under the line");
            savePNG(posterTold, [out URLByAppendingPathComponent:@"preview-poster-translated.png"]);
            CGImageRelease(alone);
            CGImageRelease(poster);
            CGImageRelease(posterNext);
            CGImageRelease(posterTold);
        }
        for (SGLyricsBackgroundMode mode = SGLyricsBackgroundCover; mode <= SGLyricsBackgroundSolid; mode++) {
            SGLyricsBackgroundStyle backgroundStyle = {mode, .45, 20, 0x18354C};
            CGImageRef selected = SGLyricsBackgroundCreate(cover, size, backgroundStyle);
            NSURL *url = [out URLByAppendingPathComponent:[NSString stringWithFormat:@"background-%ld.mp4", (long)mode]];
            BOOL written = SGLyricsClipWrite(url, selected, @"Hold on", @"조금만 버텨", @"we're almost there", size, SGLyricsClipStill);
            check(written, [NSString stringWithFormat:@"selected background %ld writes", (long)mode]);
            if (written) verify(url, selected, size, SGLyricsClipStill, YES);
            CGImageRelease(selected);
        }
        // A translation adds words under the line, and none without the line it belongs to.
        {
            CGImageRef bare = SGLyricsClipFrame(backdrop, @"Hold on", nil, @"we're almost there", size);
            CGImageRef told = SGLyricsClipFrame(backdrop, @"Hold on", @"조금만 버텨", @"we're almost there", size);
            CGImageRef alone = SGLyricsClipFrame(backdrop, nil, @"조금만 버텨", @"we're almost there", size);
            CGImageRef next = SGLyricsClipFrame(backdrop, nil, nil, @"we're almost there", size);
            double without = wordsIn(bare, backdrop, kWordsFrom, kWordsTo), with = wordsIn(told, backdrop, kWordsFrom, kWordsTo);
            check(with > without, [NSString stringWithFormat:@"the translation adds words under the line (%.2f%% white, %.2f%% without)",
                                          with * 100, without * 100]);
            check(fabs(wordsIn(alone, backdrop, kWordsFrom, kWordsTo) - wordsIn(next, backdrop, kWordsFrom, kWordsTo)) < 0.0001,
                  @"no translation without its line");
            savePNG(told, [out URLByAppendingPathComponent:@"preview-translated.png"]);
            CGImageRelease(bare);
            CGImageRelease(told);
            CGImageRelease(alone);
            CGImageRelease(next);
        }
        CGImageRef preview = SGLyricsClipFrame(backdrop, @"Hold on", nil, @"we're almost there", size);
        check(preview && CGImageGetWidth(preview) == size.width && CGImageGetHeight(preview) == size.height, @"the preview frame is the clip's size");
        savePNG(preview, [out URLByAppendingPathComponent:@"preview.png"]);
        CGImageRelease(preview);
        failures += scenesMain(scenesOut, cover);
        CGImageRelease(backdrop);
        CGImageRelease(plain);
        CGImageRelease(cover);
        printf("%s, clips in %s\n", failures ? "FAILED" : "all passed", out.path.UTF8String);
        return failures ? 1 : 0;
    }
}
