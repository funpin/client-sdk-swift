# B:SPACE fork of the LiveKit Swift SDK

This is [livekit/client-sdk-swift](https://github.com/livekit/client-sdk-swift) with three small
additions that the native macOS client of [B:SPACE](https://github.com/funpin/B-SPACE) needs to
publish a screen share from its shell. Everything else is upstream, unchanged. The branch
`b-space` is cut from the upstream release named in its history; the app pins a commit of it.

## What is added

1. **An audio track under a source of the app's choosing.**
   `LocalAudioTrack.createTrack(name:source:options:reportStatistics:)`. Upstream creates every
   local audio track as `.microphone`. A participant whose token allows only `screen_share` and
   `screen_share_audio` cannot publish that, and subscribers cannot tell app audio from a voice.
   With manual rendering mode and `AudioManager.shared.mixer.capture(appAudio:)` this publishes
   audio the app supplies itself as `.screenShareAudio`, without opening a device.

2. **A bitrate floor.** `VideoEncoding.minBitrate` and
   `VideoEncoding(maxBitrate:maxFps:minBitrate:bitratePriority:networkPriority:)`. It is written
   to the encoding's `minBitrateBps`, so the encoder is given at least that much while the
   bandwidth estimate is lower. Without it an estimate that starts low or collapses makes the
   encoder drop frames for seconds.

3. **A new encoding for a published video track.**
   `LocalTrackPublication.set(videoEncoding:)` changes the bitrate ceiling and floor and the
   frame rate ceiling without publishing the track again. It replaces the encoding in the
   track's publish options and re-computes the sender's parameters, for the primary sender and
   for a backup codec's sender alike. The re-computation that follows a change of the captured
   size now covers the backup codec's sender too.

## Relation to upstream

Upstream has a draft that covers the first addition in its own way
([#1084](https://github.com/livekit/client-sdk-swift/pull/1084), a separate track fed through an
`ExternalAudioSource`). When it is released, the first addition here is dropped in its favour.
The other two are offered upstream as they are.

## Updating

Rebase `b-space` onto the new upstream release tag, build with Xcode's toolchain, run the SDK's
own tests, then run B:SPACE's `StreamProbe` against a LiveKit server (see
`packages/desktop-macos/README.md` in the B:SPACE repository) before moving the pin.
