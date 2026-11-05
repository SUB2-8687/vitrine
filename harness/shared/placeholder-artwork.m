#import <UIKit/UIKit.h>

// Preview cards need artwork without loading the player.
UIImage *SGPlaceholderArtwork(UIColor *tint) {
    CGSize size = CGSizeMake(64, 64);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [tint setFill];
        UIRectFill((CGRect){CGPointZero, size});
    }];
}
