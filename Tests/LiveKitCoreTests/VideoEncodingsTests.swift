/*
 * Copyright 2026 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

@testable import LiveKit
import Testing

@Suite(.tags(.media))
struct VideoEncodingsTests {
    /// A screen share with its own encoding, published as SVC with an H.264 backup.
    private static let options = VideoPublishOptions(encoding: VideoEncoding(maxBitrate: 1_000_000, maxFps: 30),
                                                     screenShareEncoding: VideoEncoding(maxBitrate: 4_000_000, maxFps: 15),
                                                     simulcast: false,
                                                     preferredCodec: .vp9,
                                                     preferredBackupCodec: .h264)

    /// The backup codec's encodings must come from the screen-share settings when the track is
    /// a screen share — the same `isScreenShare` the primary sender's encodings were computed
    /// with — so its layers and the start bitrate derived from them are the configured ones.
    @Test func backupCodecEncodingsFollowScreenShareSettings() throws {
        let dimensions = Dimensions(width: 1920, height: 1080)

        let backup = Utils.computeVideoEncodings(dimensions: dimensions,
                                                 publishOptions: Self.options,
                                                 isScreenShare: true,
                                                 overrideVideoCodec: .h264)
        let primary = Utils.computeVideoEncodings(dimensions: dimensions,
                                                  publishOptions: Self.options,
                                                  isScreenShare: true)

        try #require(backup.count == 1)
        #expect(backup[0].maxBitrateBps?.intValue == 4_000_000)
        #expect(backup[0].maxBitrateBps == primary[0].maxBitrateBps)
        #expect(Transport.startBitrateKbps(for: backup, isScreenShare: true, connectionSetupTime: nil) == 3600)
    }

    /// Without `isScreenShare` the same call falls back to the camera encoding — the
    /// mismatch the backup publish path used to have.
    @Test func omittingScreenShareFlagSelectsCameraEncoding() throws {
        let camera = Utils.computeVideoEncodings(dimensions: Dimensions(width: 1920, height: 1080),
                                                 publishOptions: Self.options,
                                                 overrideVideoCodec: .h264)

        try #require(camera.count == 1)
        #expect(camera[0].maxBitrateBps?.intValue == 1_000_000)
    }

    /// A floor reaches the sender's encoding; without one the encoding carries none, so
    /// WebRTC's own minimum stays in force.
    @Test func bitrateFloorIsWrittenToTheEncoding() throws {
        let dimensions = Dimensions(width: 2560, height: 1440)
        let floored = VideoPublishOptions(screenShareEncoding: VideoEncoding(maxBitrate: 8_000_000, maxFps: 60, minBitrate: 3_000_000),
                                          simulcast: false,
                                          preferredCodec: .h265)

        let encodings = Utils.computeVideoEncodings(dimensions: dimensions, publishOptions: floored, isScreenShare: true)
        try #require(encodings.count == 1)
        #expect(encodings[0].minBitrateBps?.intValue == 3_000_000)
        #expect(encodings[0].maxBitrateBps?.intValue == 8_000_000)

        let plain = Utils.computeVideoEncodings(dimensions: dimensions, publishOptions: Self.options, isScreenShare: true)
        #expect(plain[0].minBitrateBps == nil)
    }

    /// A floor above the ceiling would ask the encoder for the impossible.
    @Test func bitrateFloorIsCappedAtTheCeiling() {
        #expect(VideoEncoding(maxBitrate: 2_000_000, maxFps: 30, minBitrate: 5_000_000).minBitrate == 2_000_000)
        #expect(VideoEncoding(maxBitrate: 2_000_000, maxFps: 30, minBitrate: -1).minBitrate == 0)
        #expect(VideoEncoding(maxBitrate: 2_000_000, maxFps: 30).minBitrate == 0)
    }

    /// A new encoding for a published track replaces the one of its kind and nothing else,
    /// so the backup codec's encodings follow it as well.
    @Test func replacingTheEncodingKeepsTheRestOfTheOptions() throws {
        let next = VideoEncoding(maxBitrate: 2_000_000, maxFps: 30, minBitrate: 500_000)

        let screenShare = Self.options.replacing(encoding: next, isScreenShare: true)
        #expect(screenShare.screenShareEncoding == next)
        #expect(screenShare.encoding == Self.options.encoding)
        #expect(screenShare.preferredCodec == .vp9)
        #expect(screenShare.preferredBackupCodec == .h264)
        #expect(screenShare.simulcast == false)

        let camera = Self.options.replacing(encoding: next, isScreenShare: false)
        #expect(camera.encoding == next)
        #expect(camera.screenShareEncoding == Self.options.screenShareEncoding)

        let backup = Utils.computeVideoEncodings(dimensions: Dimensions(width: 1920, height: 1080),
                                                 publishOptions: screenShare,
                                                 isScreenShare: true,
                                                 overrideVideoCodec: .h264)
        try #require(backup.count == 1)
        #expect(backup[0].maxBitrateBps?.intValue == 2_000_000)
        #expect(backup[0].minBitrateBps?.intValue == 500_000)
    }
}
