# Live Activity page harness

Builds the real `Shared/LiveActivity/LiveActivitySettings.m` page and preview with
activity/sleep-timer doubles. The app exits after checking enable/disable callbacks,
stored menu choices, Lyrics-only rows under Queue and Control menu, and restoration
when returning to Lyrics. It does not cycle previews for screenshots.

```sh
OUT=<temporary-output> sh harness/live-activity-page/build.sh
xcrun simctl install <owned-udid> <temporary-output>/LiveActivityPageHarness.app
xcrun simctl launch --console-pty <owned-udid> com.vojta.liveactivitypageharness
```

Delete the owned simulator and output afterwards. This checks page callbacks, not
ActivityKit rendering, phone behavior or Reduce Motion.
