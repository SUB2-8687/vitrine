# Lyrics translation check

Run `harness/lyrics-translation/build.sh` from the repository, or `./build.sh` here. It compiles the
checkout's production sources into a Mac Catalyst binary, then runs offline with no simulator. By default the
replies are made up; no real lyrics or API keys are stored and no translation service is contacted.
An explicit `--bing-live` run, described below, contacts Bing.

The checks cover:

- Durable per-record storage (`check-storage.m`): root recreation, retention beyond 200,
  resumable copy-only migration, preserved conflicts, downgrade-proof deletion suppression,
  admission failures, opaque identity transfers, merge/replacement, complete validation before
  applying an import, resumable partial commits, traversal/duplicate-identity/expansion rejection,
  failed-save completion reporting, stale translation/AI deliveries, and management pagination.
  `sh harness/lyrics-translation/build.sh --storage-only` runs these focused checks.
  Management retains one page of descriptors; exports snapshot one record at a time to disk
  before writing bounded ZIP volumes. The lifecycle mutation check runs against a disposable
  source copy, never against the shared build tree.
- Kept target-language lines: `bash harness/lyrics-translation/ondevice-kept-check.sh` exercises the
  actual Swift provider's all-target-language result without downloaded languages. Run
  `harness/lyrics-translation/build.sh --kept-only` for the automatic chain's completion count,
  duplicate suppression, saved/restored originals, no repeat automatic request, and deletion.
  The latter uses a provider stand-in for a mixed-language result; it does not exercise Apple's
  downloaded translation models.
- Musixmatch's community translations matched onto copies of a song's lines by folded text, leaving
  the original lines untouched (`SGMusixmatchTranslatedLines`).
- Gemini's reply and reasons for failure (`SGGeminiTranslationsIn`): a blocked prompt, a recitation or
  safety stop, a different line count, the key and the limit.
- DeepL's language mapping, unknown tags, ordered translation arrays, missing fields, wrong types and
  oversized translations (`SGDeepLTargetLanguage`, `SGDeepLTranslationsIn`). The language allowlist
  follows [DeepL's text language table](https://developers.deepl.com/docs/getting-started/supported-languages).
- Batches that retain original indices, skip blank lines, stop at 50 texts for DeepL or 3500 UTF-16
  units including joining newlines for Google, and reject oversized lines or songs. Tests include
  the 51st line, exact character boundaries and non-Latin text (`SGLyricsTranslationBatches`).
- Google's language aliases, instrumental markers and bracketed tags, segment concatenation, LF and
  CRLF splitting, and mismatched counts that tell the caller to retry each line. Form tests include
  ampersands, plus signs, equals signs, percent signs, newlines, Korean and emoji
  (`SGGoogleTargetLanguage`, `SGGoogleKeepsLine`, `SGGoogleTranslationTextIn`,
  `SGGoogleTranslationLinesIn`, `SGGoogleTranslationForm`).
- Bing's language mapping, the HTML page's IG/IID/token tuple, missing markers, invalid numbers and
  types, default/minimum token lifetime, malformed or oversized translations, and trailing whitespace
  without dropping line boundaries or leading spaces. Its batches stop at 40 lines or 2800 UTF-16 units.
  Scripted transport exercises the production job: token refresh once, line-count fallback, embedded
  newlines, protected lines unchanged, percent encoding, increasing SFX, configuration reuse, memo
  reuse and invalidation on changed source text, opt-in checks, and a single completion on main.
- Claude's joined text parts, JSON fences, mismatched counts, malformed and oversized content, token
  exhaustion and HTTP/network errors, including 400's error message and 529. The request uses
  `claude-sonnet-5` by default, the Messages API headers, 8192 output tokens and the translation instruction
  shared with the OpenAI-compatible service.
- Every OpenAI-compatible preset's endpoint and model, menu selection, Custom leaving stored values alone,
  trailing-slash matching, and service names. All five preset base URLs pass `SGOpenAICompletionURL`.
- OpenAI-compatible keys belong to the base URL's lowercased host, independent of its path or port.
  Pure checks cover host derivation and legacy migration decisions. An in-memory Keychain exercises
  default/custom-host migration, preserving an existing host key, deleting the old `api-key` item,
  failures and retries, migrating before a preset changes the address, and the ` · no key` row value.
  Lyrics, AI jobs and automatic titles send nothing for a host without a key; requests for configured
  hosts carry only that host's key. The key alert saves to the stored address's host, and the address
  alert migrates the old address's legacy key before it changes (both alerts still need device verification).
- Model lists: Gemini's generate-content models without the `models/` prefix, Anthropic's and OpenAI-compatible
  lists with display names, duplicates, wrong types, control characters, the 2000-model cap and the ID sort.
  `/models` beside each base URL, the three list requests' addresses and headers, no request without a key,
  stored models cleaned, and Gemini's chosen model percent-encoded inside its path segment.
- Indexed lyric translations across the real OpenAI-compatible, Claude and Gemini entry points:
  exact `L0001<TAB>text` IDs/order; recovery of missing IDs, rejection of duplicated, shifted or extra IDs,
  extra delimiters, JSON/fenced replies, refusals and truncation; source tab/newline normalization
  (CRLF is one space); Unicode and size boundaries; empty-row preservation; unchanged saved and
  memoized results after a rejected answer; explicit JSON title-mode isolation.
- AI pronunciation and cultural notes: JSON-array prompts, all three notations, sound rather than meaning,
  sparse notes, composed-character length limits, strict replies, all three service request shapes and safety
  settings, shared in-flight requests, single main-thread completion, memory/disk reuse and deletion while
  a request is running. One track-scoped notification updates peer views; cancelled jobs return no result or error.
  A real blocked-directory failure keeps AI answers in the shared memory cache until cleared.
- Saved AI round trips in a unique temporary folder: empty answers, hashed tuple isolation, malformed
  values, notation zero following the current translation language, the combined saved-file count and deletion, and retention beyond 200 AI files.
- Switching saved translations between services and target languages on the same line objects;
  source translations stay intact and are not copied into generated-translation files. Per-song deletion
  leaves other songs, other target languages and AI notes intact, even directly after a queued save.
  Shared request tokens reject stale callbacks after replacement, per-song deletion or global deletion;
  finishing an old token cannot end a newer request. A real blocked-directory write failure
  retains results for both views in memory until removed; long local-track identifiers save under a bounded hash.
- Title language/script decisions, unchanged Latin artist names, two-line requests, local translation falling
  back when languages are unavailable, main-thread track notifications, service enablement after a missed lookup, target changes,
  out-of-order completion, a two-attempt cap with a 30-second cooldown, settings invalidation and eviction
  after 200 cached title results. The on-device translator is a harness stand-in.
  A custom NSURLProtocol intercepts Gemini HTTP requests to exercise its actual title fallback and cache:
  changed title/artist text makes a new request, while identical text reuses the answer, with no live API call.
- Legacy/generic OpenAI-compatible replies as strict JSON arrays or single-value objects, with and without a JSON
  code fence. Wrong types, malformed fences, excessive sizes and mismatched counts fail. Base URLs
  accept HTTPS, or HTTP for localhost, 127.0.0.1, .local hosts and numeric Tailscale IPv4 addresses
  (100.64.0.0/10), and reject credentials, query strings and fragments. Tailscale checks include both
  CIDR boundaries, adjacent networks, malformed IPs, hostname lookalikes and invalid ports
  (`SGOpenAITranslationsIn`, `SGOpenAICompletionURL`). Requests follow the
  [Chat Completions format](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create).

The connection-test regression can also run on its own:

```sh
harness/lyrics-translation/build.sh --connection-only
```

`check-connection.m` compiles the real `ConnectionTest.m` and calls `SGTestOpenAIConnection` for both
kinds. Its scripted `SendOnce`/`SendOnceUpTo` replacements check that neither kind sends without an
explicit call, that a missing key or an unbuildable address is a configuration report with `sent=no`,
and that the free model check is a GET of the base URL's `/models` with no body or generation. Facts
stay separate: 401/403 is `authentication` with `reachable=yes`, 404/405 on `/models` leaves `models`
unknown (not proof chat fails), an unreadable 200 list still means the key answered, and a transport
`NSError` is `connection` with its domain/code only. The paid sample sends exactly one POST with the
Tailscale endpoint, host-bound fake authorization, saved model and target, and a prompt containing
only the fixed test sentence; its success, 401/403, 400/404, 429/5xx, unreachable, malformed/empty
replies, key echoes, echoed address/URL/lyric, output and payload bounds, and duplicate completion are
covered. Copied `diagnostic` lines are checked for the key, `Bearer`, host, port, `/models`,
`/chat/completions`, the sample lyric and upstream text. Explicit cancellation and stale base, model,
key or target both without a notification and with each settings/redraw notification are covered;
an unchanged generic redraw leaves the request alive. These are service/lifecycle fixture checks;
they do not exercise UI or a network service.

The production `SGLyricsTranslationSendOnce` is separately linked as `SGLyricsTranslationRealSendOnce`.
A scoped ephemeral-configuration method replacement injects only an `NSURLProtocol` fixture into the
real session; production still sets its policies and handles responses. This verifies a 20-second
request timeout, disabled request cookies, single 200/429/503 attempts, main-thread completion,
transport cancellation, and unknown-length payloads at exactly 512 KiB and one byte above it.
Redirect refusal is a direct call to the production delegate, not an end-to-end HTTP redirect test.
No socket server, paid API, real key or simulator is used. Resource timeout expiration, announced
Content-Length rejection, and actual wire redirects are not exercised by this focused check.

Expected output:

```text
DeepL / Google / OpenAI: mapping, malformed replies, line counts, bounds, form encoding and URL checks passed
Bing: language, configuration, bounds, padded lines, token retry, fallback, opt-in, memo and main completion checks passed
OpenAI keys: host derivation, migration decisions, failure retry, preset isolation and lyrics/AI/title request guards passed
Claude / presets: multipart and fenced replies, errors, bounds, all five endpoints and stored selection passed
AI jobs: prompt JSON, notation, note limits, all three requests, strict replies, main completion, coalescing and memo passed
Saved AI: isolated round trip, empty values, tuple isolation, malformed data, combined count/delete and newest 200 passed
Titles: language/script detection, Latin artists, two-line request, local fallback, notification, once per track and 200-result cache passed
Connection checks: configuration/no-key without a send, free GET /models with separate reachability/auth/model facts, paid sample only when asked, error categories, hostile reply redaction, single completion, cancellation and stale configuration passed
Connection transport: real SendOnce, 20s request, 429/503 no retry, cancel, 512 KiB boundary; direct redirect delegate passed
lyrics translation: all checks passed
```

The new translators share the bounded transport in `DeepL.m`, so that file is linked alongside
`GoogleTranslate.m`, `BingTranslate.m` and `OpenAITranslate.m`. It receives at most 512 KiB per reply, uses ephemeral
sessions without disk caching, refuses redirects, and retries 429 up to three times with jittered
1/2/4-second backoff. Google, Bing and OpenAI-compatible services retry 5xx too. Google and Bing check their opt-in
before each attempt and batch. Each service keeps up to 32 successful song/language results in memory,
checks that the source text still matches, and completes on main. DeepL sends at most 50 texts and
16000 UTF-16 units per batch; Google rejects individual lines over 3500 units instead of truncating
or splitting their characters. Bing uses the same structure, with 40-line / 2800-unit batches and
its page configuration cached until 30 seconds before expiry. Whole inputs are limited to 2000 lines and 128000 UTF-16 units.

The harness compiles the network and settings code. Key reads return a fixed test value for explicitly
enabled services, with OpenAI-compatible keys held separately by account in memory. All Keychain read,
add, update and delete functions are replaced, including in the DeepL object; real entries are never
read or written. `SG_LYRICS_TEST_STORE`
redirects only the harness build's saved-file root to a unique temporary directory. Settings changed by
preset and notation tests are restored. `check-ai.m` is included by `check.m`, sharing its transport and
settings stand-ins. DeepL's transport symbol is renamed in its
harness object so an offline wrapper can supply scripted Bing replies; the real transport remains
available for the live mode. `SGLyricsSourceRequest` is a harness stand-in to avoid linking the
unrelated lyrics-provider registry. Its live GET uses a private ephemeral session, no cookies or
credentials, a 2 MiB limit and no redirects, matching the production source transport's constraints.
The live POST uses the actual bounded translation transport from `DeepL.m`.

To make one live translation job with two made-up English sentences and a protected music marker:

```sh
harness/lyrics-translation/build.sh --bing-live
# Or, after building:
harness/lyrics-translation/build/check --bing-live
```

This mode checks a Korean result, the unchanged music marker and main-thread completion, and reports
GET/POST counts. It makes real requests only when explicitly invoked. No tokens or keys are printed.

Not exercised here: real token expiration, transport retry/backoff under 429/5xx, Keychain storage,
settings alerts, real on-device translation, live AI output quality, or lyrics views taking up a result on the iPhone. Settings-page
and menu integration and localization table updates belong to the parent assignment. New visible
strings use SGL with English fallbacks; Korean text is supplied in the implementation handoff.

Title translation uses Apple's Translate first when available, then the first enabled online service in
Bing, Google, DeepL, Gemini, Claude, OpenAI-compatible order. A local failure can mean the required
languages are not installed, so it advances to that first online service; an online failure stops the job.
Only 200 title/artist results stay in memory, with up to 2000 successful identities remembered to avoid
repeat calls after result eviction. Identity includes track, original title/artist and target language.
Without a service no attempt is consumed. Failures allow one retry after 30 seconds, on a later label
refresh; changing service settings resets failed attempts and invalidates pending callbacks.
Both portrait and landscape title labels refresh when the result or translation settings change.

All changed Objective-C implementation files are compiled by this harness. The normal production paths,
including the non-test saved-file root and real Keychain declarations, were additionally checked using
`xcrun --sdk iphoneos clang -target arm64-apple-ios16.1 -fobjc-arc -fblocks -fsyntax-only` with the iOS 26.5
SDK, `-Wall -Wextra -Werror -Wno-unused-parameter` and `-Itweak/Sources`. The landscape notification harness separately compiles the complete Logos controller.

## Explicit automatic Retry against the real provider cache

```sh
harness/lyrics-translation/build.sh --auto-retry-only
```

`check-auto-retry.m` links the actual redesigned `AutoTranslation.m` and the actual
`OpenAITranslate.m` already compiled by this harness. Only transport replies, in-memory credentials,
feature availability and the existing on-device boundary are fixtures; neither the automatic chain nor
OpenAI translation is stubbed. No service is contacted.

Two cases begin with an existing translated line and a real provider response containing either one
translated gap or only empty gaps. After one missing-row repair also returns empty values, the automatic
status becomes Partial or Failed. Neither incomplete result is eligible for the provider memo.
Explicit Retry itself sends nothing; the next automatic chain makes a fresh transport request and
reaches Complete under the real track identity. A second track's seeded cache is reused even between
Retry and that next chain. Both its cache and the existing translations survive the retry. In the
partial case, the harness places the first successful line on the input model as the view would; the
real chain's returned replacements leave both previously translated positions empty. A later ordinary
attempt makes a new request rather than replaying an incomplete provider memo.

## AI gaps and repair

```sh
harness/lyrics-translation/build.sh --ai-gaps-only
```

`check-ai-gaps.m` reproduces the screenshot-shaped case: one translated row followed by blank or
whitespace-only values in an otherwise correctly numbered answer. Before recovery, that answer was
reported as success and memoized indefinitely. All three remote AI providers now request only its
missing rows once, stitch them back by source index, and return an explicit error alongside any
partial result when recovery fails. Only complete answers enter the per-provider memo.

Fixtures cover indexed, JSON and prose formats, a first-N indexed reply, omitted IDs, duplicate
source lines, empty/instrumental rows, CRLF, JSON fences, ambiguous off-by-one numbering, merged and
split rows, and malformed indexed fences. Ambiguous formats fail rather than guessing timing
positions; short JSON arrays fail because they carry no reliable row IDs. Successful repairs reach
Complete through the real automatic chain and saved store. Partial disk maps retain only completed
rows, and old whitespace-only saved values no longer mark a row complete.

Observed: both cases pass, using six scripted HTTP responses total; the integrated default harness
also passes. A temporary negative-control copy under `build/retry-negative-control/` replaced only
`fresh ? nil : track` with `track`, reproducing the old cache routing. It fails the assertion requiring
one new request and consumption of the queued fresh reply. Production sources were not edited for
this control. This specifically exercises OpenAI's actual memo; the other remote providers' fresh
routing is not independently executed here.
