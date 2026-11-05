# Clear Downloaded Covers and Artist Photos harness

`clear-check.m` runs the production `SGMotionStore.m`, `SGMotionCatalog.m` and the row in `AnimatedArtworkSettings.m` on
the Mac, in a sandbox: Caches is redirected to a temporary folder, the catalog answers through an offline URL
protocol, the clip transfers are fakes, and the alert is read through a stand-in presenter. It checks that

- the size shown is the clips and the saved answers on disk, and the alert's text and buttons are the specified ones;
- Cancel changes nothing, and Clear removes the store's own clips, the saved answers and the answers in memory, so
  the next requests search and download again;
- a clip a consumer holds stays, and songs, chosen covers, edits, imported lyrics, other caches and unrelated files in
  the same folder are untouched;
- a transfer, a lookup and a queued file from before the clear leave nothing behind and start no download after it, and
  a request made after the clear does not join the old lookup;
- an artist photo and motion request whose search, discography, video resource or photo and video is pending at the
  clear caches nothing and starts no download afterwards, and the next request fetches every step again;
- a clear before any lookup does not read the answers file on the main thread;
- a clip or the answers file that cannot be removed is reported ("Some files couldn't be removed."), and a clear with
  nothing in the way reports nothing.

    sh build.sh        # builds build/artwork-clear-check and runs it

`OUT=<directory>` isolates the binary.
