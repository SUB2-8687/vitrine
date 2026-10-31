"""Inject test boundaries or mutations into generated sources, never the working tree."""
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
mode = sys.argv[2]


def replace(old, new):
    global source
    if source.count(old) != 1:
        raise SystemExit(f"{mode}: anchor changed: {old}")
    source = source.replace(old, new)


if mode == "seams":
    source = f'#import "{Path(__file__).resolve().with_name("cover-seams.h")}"\n' + source
    replace("SGMotionAlbumCover(artist, album, pixels,", "SGRAlbumTestAlbumCover(artist, album, pixels,")
    replace("SGMotionPoster(file,", "SGRAlbumTestPoster(file,")
    replace("SGRCoverRead(poster,", "SGRAlbumTestStillRead(poster,")
    replace("[AVPlayerLayer playerLayerWithPlayer:_player]", "SGRAlbumTestPlayerLayer(_player)")
    replace("cache = [NSCache new];", "cache = SGRAlbumTestRenderCache();")
elif mode == "edge-step":
    anchor = "CGImageRef image = CGBitmapContextCreateImage(context);"
    replace(anchor, """// Mutation: one bright pixel row at the square/extension seam.
    size_t edge = (size_t)lround(CGRectGetMaxY(d.place) * d.scale) - sharpRows;
    memset((uint8_t *)CGBitmapContextGetData(context) + edge * wide * 4, 255, wide * 4);
    """ + anchor)
elif mode == "still-owner":
    replace("[self sgr_dropMotion];\n    if (!key || !SGEnabled(SGRKeyAlbumMotion)",
            "/* Mutation: leave A installed until B supplies a clip. */\n    if (!key || !SGEnabled(SGRKeyAlbumMotion)")
elif mode == "still-generation":
    replace("hero->_motionGeneration != generation || ", "")
    replace("again->_motionGeneration != generation || ", "")
elif mode == "cache-source":
    replace("if (cached && cached.source == image)", "if (cached)")
elif mode == "field-asked":
    # Kit/SGRField.m: the field reports the colour it was asked for, not the one it paints.
    replace("- (UIColor *)fieldColor {\n    return _shownColor;", "- (UIColor *)fieldColor {\n    return _color;")
else:
    raise SystemExit(f"unknown mutation: {mode}")
path.write_text(source)
