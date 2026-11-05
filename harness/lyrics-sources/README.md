# Lyrics sources check

`./build.sh` checks, on the Mac as a Mac Catalyst binary, with no simulator and no network:

- the word splitting in `Shared/Lyrics/KaraokeTiming.m`: long Thai, Lao, Khmer and Burmese lines with no
  spaces come apart at the dictionary's words, the pieces make up the line exactly, and Latin, Chinese and
  Japanese lines split as before. The pieces are printed, so a script the system does not split shows;
- KuGou's KRC (`KuGou.m`, read by `SGLyricsPieceLines` in `NetEase.m`): packed here the way KuGou packs
  it, then unpacked and read, with the word times, the joining and the line ends checked;
- NetEase's yrc and Musixmatch's richsync (`Musixmatch.m`), whose pieces `SGKaraokePieceLine` in
  `KaraokeTiming.m` runs together into words, as the Lyricsfile's are: which pieces join, and where each
  word and line ends;
- the QQ Music and KuGou asks against made-up search replies: titles, singers and lengths that do not
  fit are passed over, the closest KuGou lengths are tried first and at most three, and QQ's LRC is read;
- QQ QRC XML/UTF-8 and zlib payloads, absolute unequal word clocks, joined pieces, entities, non-ASCII,
  malformed clocks and the 1 MiB expansion limit; a failed QRC reply falls back to the old LRC request.
  Short catalog names reject IU/MIURA while keeping exact names, edge aliases and middle joined credits;
- the actual shared JSON transport with a worker session double: JSON decode and pure transforms
  precede main delivery, including large input, malformed JSON and HTTP error bodies. NetEase rejects
  same-artist/same-duration wrong titles and keeps normalized title matches;
- Bugs' second-to-millisecond rounding, malformed and backwards sheets, plain fallback, and title,
  artist and four-second duration matching (a music video's length does not stand in for the track's);
- Genie's bounded HTML rows and entity decoding, browser headers, JSONP removal, numeric-key
  validation and millisecond sorting. A mobile User-Agent returns a rejected redirect in the fixture;
  Genie must use a desktop User-Agent for both requests;
- LyricsPlus' Line, Word and Syllable shapes, joining, backing vocals, catalog credit, primary success without a second request,
  and fallback to lyricsplus.binimum.org when the primary fails;
- Deezer's word/line/plain preference, title/artist/duration matching, missing or unsafe ARL, in-memory
  JWT reuse, and one refresh on either a GraphQL or HTTP authentication failure. Cookies, tokens and
  lyrics in these checks are invented; no Keychain item is read or written;
- odd JSON types, oversized text, non-finite clocks, and completion on main from a worker queue;
- LRCLIB manual search: synced-first and nearest-duration ranking, shaped records, the 20-record
  limit, first 100 input records, 256 KiB UTF-8 / 4000-line sheet caps (including CRLF), empty replies,
  the User-Agent and lookup of a pinned id through the bounded source transport;
- Japanese reading: `君の名前を呼ぶ` becomes `きみのなまえをよぶ`, a kana-only line returns nil,
  Latin and particles stay as written, and changing between romaji and hiragana changes the cache key.
- LRCLIB's Lyricsfile (`Lyricsfile.m`): the spec's example and LRCLIB's own way of writing it read as word
  timed lines, segments run together into words, a file timed only by the line left to the LRC, a broken
  or unknown file refused whole, and the LRCLIB ask taking the words over the LRC and a record with words
  over a closer one without, passing over a search record that is not the track (another song, another
  artist), and counting a record's words only once its Lyricsfile reads. The ask reads a Lyricsfile off the
  main queue and answers on it, later than a record without one.

`./build.sh krc.json qq.json lrclib.json` also reads real replies saved from `lyrics.kugou.com/download`,
QQ's `GetPlayLyricInfo` and LRCLIB's `/api/get/<id>`, and prints how many lines each has; an LRCLIB record
must read as word timed exactly when it says `hasWordSync`. None are kept here, since they are real lyrics.

A successful run ends with:

```text
Bugs, Genie, LyricsPlus, Deezer: parser, matching, fallback, auth and main-queue checks passed
lyrics-sources: all checks passed
```

The transport is replaced by an offline responder. This checks request URLs, headers and bodies, but
not the live services, transport size cancellation, real Deezer authentication, Keychain access or the
settings alert on a phone. This binary does not walk the source order or draw lyrics on a device. The state check below covers the walk. The shared
transport and settings integration can be checked with clang's syntax-only mode without a Theos build.
No replies containing real lyrics are stored in the fixtures.
The QRC grammar follows https://docs.betterlyrics.org/docs/qrc-format (text before each absolute
millisecond clock). Current QQ wire encoding remains a device/provider check: crypt=0,qrc=1 must
return base64 UTF-8 QRC or base64 zlib QRC in `lyric`; otherwise crypt=0,qrc=0 must still return LRC.
This harness does not establish encrypted QRC compatibility or transition-frame timing on a phone.
Build products use a unique temporary directory removed on exit; `LYRICS_SOURCE_ROOT` can point to
an isolated source copy for mutation checks without changing the checkout.

`sh ./state-build.sh` checks the actual keeper and source walk as a second Mac Catalyst binary. Only
Spotify's Logos hooks are omitted; the route getter and the pinned/provider replies are replaced by
made-up answers. It checks offset clamps and deletion, 500-track and 500-pin limits, negative total
delay and seeks, a cached clock read from worker threads, a route notification sent off main,
immediate pin visibility and credit, rejected empty choices, late replies after pin/unpin, a stored
pin fetched before the normal walk, failed-pin fallback, and instrumentals. It also compiles the actual
`LyricsHook.x` code before the Logos declarations: pinned plain/instrumental choices beat later timed
Spotify lines, request generations survive donor rewriting, and stale donor, held and Spotify
deliveries are discarded after pin/unpin (including a change while awaiting the source callback).
Its defaults use a fresh
suite removed on exit. This does not test Bluetooth hardware, the hook installation or Spotify's UI.

The language checks also exercise furigana for `東京の空`, `君の名前を呼ぶ`, `食べる`, kana-only
and Latin lines, a supplementary-plane character before a ruby range, and concurrent cached reads.
Song detection checks made-up Japanese, Korean, English and Spanish lines, repeated chorus lines,
a kana override and uncertain input. The line copy keeps its cultural-reference note independently.
Title simplification has 20 cases, including Korean suffixes, fullwidth and nested brackets, repeated
extras and malformed brackets. Every balanced trailing group is treated as an extra: `Love (Is All)`
becomes `Love`, while `Love (Is All) Around` stays whole because the group is inside the title.
A title made only of extras, or with no recognized extra, stays exactly as it came in.

The state check uses an isolated defaults suite for language rules, optional output pointers,
malformed records, per-track overrides, removal, main-queue notifications and the 500-track bound.
Made-up providers check source type filtering, default early stopping, type-first upgrades, ties in
source order even when a later source learns the track name and imported LRC bypass. Reload checks the cleared state at notification time, pin
preservation and refetch, and the rejection of a reply that arrives after another reload.
Held provider replies also check that Type first releases all waiters, including the color-lyrics
completion, on the first synced answer while the next source is still pending. Later requests use
that cached answer; a later word-timed answer updates the kept lines and credit without answering
twice. Type filters still apply, a successful pin stops the walk, and pinning or reloading during
the continued walk rejects its late result. These checks cover the keeper handoff, not the
redesign's on-screen replacement of already shown lines.
These checks do not open the settings pages or draw ruby text on a phone.
