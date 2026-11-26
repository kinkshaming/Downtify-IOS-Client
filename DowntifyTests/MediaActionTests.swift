import XCTest
@testable import Downtify

final class MediaActionTests: XCTestCase {
    private let title = "Zebra Song"

    func testLibraryPresentationForEveryServerState() {
        let cases: [(ServerDownloadActionState, String, String?, Bool, String?)] = [
            (.idle, "Add to Library", "plus.circle", true, nil),
            (.submitting, "Adding to Library", nil, false, nil),
            (.queued(jobID: "job-1"), "Queued for Library", "clock.arrow.circlepath", false, nil),
            (.queued(jobID: nil), "Queued for Library", "clock.arrow.circlepath", false, nil),
            (.accepted, "In Library", "checkmark.circle.fill", false, nil),
            (.partiallyAccepted(successful: 2, expected: 3), "2 of 3 added to Library", "checkmark.circle", false, nil),
            (.outcomeUnknown, "Library status unknown", "questionmark.circle", false, nil),
            (.failed("Network down"), "Retry Add to Library", "exclamationmark.arrow.circlepath", true, "Network down"),
        ]
        for (state, expectedTitle, icon, enabled, explanation) in cases {
            let presentation = MediaActionPresentation.library(state, itemTitle: title)
            XCTAssertEqual(presentation.title, expectedTitle, "\(state)")
            XCTAssertEqual(presentation.systemImage, icon, "\(state)")
            XCTAssertEqual(presentation.isEnabled, enabled, "\(state)")
            XCTAssertEqual(presentation.explanation, explanation, "\(state)")
        }
    }

    func testOnlyIdleAndFailedLibraryStatesAreEnabled() {
        for state in libraryStates {
            let expected: Bool
            switch state {
            case .idle, .failed: expected = true
            default: expected = false
            }
            XCTAssertEqual(MediaActionPresentation.library(state, itemTitle: title).isEnabled, expected, "\(state)")
        }
    }

    func testFailedLibraryExplanationMatchesMessage() {
        let presentation = MediaActionPresentation.library(.failed("Quota exceeded"), itemTitle: title)
        XCTAssertEqual(presentation.explanation, "Quota exceeded")
    }

    func testSubmittingLibraryStateHasNoIcon() {
        XCTAssertNil(MediaActionPresentation.library(.submitting, itemTitle: title).systemImage)
    }

    func testNowPlayingLibraryRequestStatesDistinguishRequestFromMembership() throws {
        let song = try catalogSong()
        let cases: [(ServerDownloadActionState, String, Bool, String?)] = [
            (.idle, "Add to Library", true, nil),
            (.submitting, "Adding to Library", false, nil),
            (.queued(jobID: "job"), "Queued for Library", false, nil),
            (.accepted, "Requested for Library", false, "The song will appear after library sync."),
            (.partiallyAccepted(successful: 1, expected: 2), "Library status unknown", false,
             "Check Library requests for the current status."),
            (.outcomeUnknown, "Library status unknown", false, nil),
            (.failed("Network down"), "Retry Add to Library", true, "Network down"),
        ]
        for (state, expectedTitle, enabled, explanation) in cases {
            let action = NowPlayingLibraryPresentation.make(song: song, isInLibrary: false,
                externalCatalogAvailable: true, hasSession: true, state: state)
            XCTAssertEqual(action.title, expectedTitle, "\(state)")
            XCTAssertEqual(action.isEnabled, enabled, "\(state)")
            XCTAssertEqual(action.explanation, explanation, "\(state)")
            XCTAssertTrue(action.accessibilityLabel.contains(title), "\(state): \(action.accessibilityLabel)")
            XCTAssertNotEqual(action.title, "In Library", "\(state) is not membership")
        }
    }

    func testNowPlayingLibraryRequestRequiresEligibleSongAndConnection() throws {
        let song = try catalogSong()
        let librarySong = try catalogSong(source: "library")
        let missingURL = try catalogSong(url: "")
        let whitespaceURL = try catalogSong(url: "   ")
        let cases: [(CatalogSong?, Bool, Bool, String)] = [
            (nil, true, true, "This song cannot be requested from the catalog."),
            (librarySong, true, true, "This song cannot be requested from the catalog."),
            (missingURL, true, true, "Provider information is unavailable for this song."),
            (whitespaceURL, true, true, "Provider information is unavailable for this song."),
            (song, false, true, "Catalog requests are unavailable on this server."),
            (song, true, false, "Reconnect to add to your Library."),
        ]
        for (item, catalogAvailable, hasSession, explanation) in cases {
            for state in [ServerDownloadActionState.idle, .failed("Network down")] {
                let action = NowPlayingLibraryPresentation.make(song: item, isInLibrary: false,
                    externalCatalogAvailable: catalogAvailable, hasSession: hasSession, state: state)
                XCTAssertFalse(action.isEnabled, "\(explanation): \(state)")
                XCTAssertEqual(action.explanation, explanation)
                XCTAssertTrue(action.accessibilityLabel.contains(item?.title ?? "Unknown title"))
            }
        }
    }

    func testNowPlayingConfirmedMembershipSupersedesRequestAndAvailability() throws {
        let song = try catalogSong()
        for state in libraryStates {
            let action = NowPlayingLibraryPresentation.make(song: song, isInLibrary: true,
                externalCatalogAvailable: false, hasSession: false, state: state)
            XCTAssertEqual(action.title, "In Library", "\(state)")
            XCTAssertEqual(action.accessibilityLabel, "\(title) is in your Library")
            XCTAssertFalse(action.isEnabled, "\(state)")
        }
    }

    func testDevicePresentationForEveryState() {
        let cases: [(DeviceSaveState, String, String?, Bool, String?)] = [
            (.unavailable(.notInLibrary), "Add to Device", "iphone.slash", false, "Add to Library first"),
            (.notSaved, "Add to Device", "arrow.down.to.line.circle", true, nil),
            (.pending, "Waiting to Add to Device", nil, false, nil),
            (.transferring(fraction: nil), "Adding to Device", nil, false, nil),
            (.transferring(fraction: 0.5), "Adding to Device", nil, false, nil),
            (.saved, "On Device", "arrow.down.to.line.circle.fill", false, nil),
            (.failed(.network), "Retry Add to Device", "exclamationmark.triangle", true, nil),
        ]
        for (state, expectedTitle, icon, enabled, explanation) in cases {
            let presentation = MediaActionPresentation.device(state, itemTitle: title)
            XCTAssertEqual(presentation.title, expectedTitle, "\(state)")
            XCTAssertEqual(presentation.systemImage, icon, "\(state)")
            XCTAssertEqual(presentation.isEnabled, enabled, "\(state)")
            XCTAssertEqual(presentation.explanation, explanation, "\(state)")
        }
    }

    func testOnlyNotSavedAndFailedDeviceStatesAreEnabled() {
        for state in deviceStates {
            let expected: Bool
            switch state {
            case .notSaved, .failed: expected = true
            default: expected = false
            }
            XCTAssertEqual(MediaActionPresentation.device(state, itemTitle: title).isEnabled, expected, "\(state)")
        }
    }

    func testNotInLibraryDeviceStateIsDisabledWithExplanation() {
        let presentation = MediaActionPresentation.device(.unavailable(.notInLibrary), itemTitle: title)
        XCTAssertFalse(presentation.isEnabled)
        XCTAssertNotNil(presentation.explanation)
    }

    func testDeviceSaveStateWithoutTrackIsNotInLibrary() {
        XCTAssertEqual(DeviceSaveState(track: nil, record: record(state: .ready, bytes: 8)),
                       .unavailable(.notInLibrary))
        XCTAssertEqual(DeviceSaveState(track: nil, record: nil), .unavailable(.notInLibrary))
    }

    func testDeviceSaveStateWithTrackMapsRecordState() {
        let track = track()
        XCTAssertEqual(DeviceSaveState(track: track, record: nil), .notSaved)
        XCTAssertEqual(DeviceSaveState(track: track, record: record(state: .preparing, bytes: 0)), .pending)
        XCTAssertEqual(DeviceSaveState(track: track, record: record(state: .paused, bytes: 3)), .pending)
        XCTAssertEqual(DeviceSaveState(track: track, record: record(state: .transferring, bytes: 3)),
                       .transferring(fraction: 0.375))
        XCTAssertEqual(DeviceSaveState(track: track, record: record(state: .transferring, bytes: 3, hasMedia: false)),
                       .transferring(fraction: nil))
        XCTAssertEqual(DeviceSaveState(track: track, record: record(state: .transferring, bytes: 20)),
                       .transferring(fraction: 1))
        XCTAssertEqual(DeviceSaveState(track: track, record: record(state: .ready, bytes: 8)), .saved)
        XCTAssertEqual(DeviceSaveState(track: track, record: record(state: .cancelled, bytes: 3)), .notSaved)
        XCTAssertEqual(DeviceSaveState(track: track, record: record(state: .failed(.insufficientStorage), bytes: 3)),
                       .failed(.insufficientStorage))
    }

    func testLibraryAndDeviceIconsAreDisjointAndExcludeLegacyIcon() {
        let libraryIcons = Set(libraryStates.compactMap {
            MediaActionPresentation.library($0, itemTitle: title).systemImage
        })
        let deviceIcons = Set(deviceStates.compactMap {
            MediaActionPresentation.device($0, itemTitle: title).systemImage
        })
        XCTAssertTrue(libraryIcons.isDisjoint(with: deviceIcons))
        XCTAssertFalse(libraryIcons.contains("arrow.down.circle"))
        XCTAssertFalse(deviceIcons.contains("arrow.down.circle"))
    }

    func testEveryAccessibilityLabelContainsItemTitle() {
        for state in libraryStates {
            let label = MediaActionPresentation.library(state, itemTitle: title).accessibilityLabel
            XCTAssertTrue(label.contains(title), "\(state): \(label)")
        }
        for state in deviceStates {
            let label = MediaActionPresentation.device(state, itemTitle: title).accessibilityLabel
            XCTAssertTrue(label.contains(title), "\(state): \(label)")
        }
    }

    // MARK: - Fixtures

    private func catalogSong(source: String = "youtube", url: String = "https://music.youtube.com/watch?v=test") throws -> CatalogSong {
        let payload: [String: String] = ["source": source, "song_id": "test", "name": title,
                                         "artist": "Artist", "url": url]
        return try JSONDecoder().decode(CatalogSong.self, from: JSONSerialization.data(withJSONObject: payload))
    }

    private var libraryStates: [ServerDownloadActionState] {
        [
            .idle, .submitting, .queued(jobID: nil), .accepted,
            .partiallyAccepted(successful: 2, expected: 3), .outcomeUnknown, .failed("Network down"),
        ]
    }

    private var deviceStates: [DeviceSaveState] {
        [
            .unavailable(.notInLibrary), .notSaved, .pending, .transferring(fraction: nil),
            .transferring(fraction: 0.5), .saved, .failed(.network),
        ]
    }

    private func track() -> LibraryTrack {
        LibraryTrack(id: "song", file: "Song.mp3", title: title, artist: "Artist", artists: [],
                     album: "", albumArtist: "", albumID: "", artistID: "", trackNumber: 0, year: "",
                     duration: 60, codec: "mp3", bitrate: 0, sampleRate: 0, channels: 0, size: 8,
                     added: 0, hasCover: false, isExplicit: false, playlists: [])
    }

    private func session() -> DeviceSession {
        DeviceSession(baseAddress: "https://music.local/proxy", serverID: "server", serverName: "Music",
                      deviceID: "device", username: "user", role: nil, token: "test-token", allowsInsecureHTTP: false)
    }

    private func media() -> OfflineMedia {
        OfflineMedia(length: 8, mime: "audio/mpeg", type: "public.mp3",
                     fileExtension: "mp3", etag: "\"version\"", quality: .original)
    }

    private func record(state: OfflineDownload.State, bytes: Int64, hasMedia: Bool = true) -> OfflineDownload {
        OfflineDownload(id: UUID(), track: track(), scope: .init(session()), requestedQuality: .original,
                        state: state, media: hasMedia ? media() : nil, receivedBytes: bytes)
    }

    func testAlbumAddBelowThresholdNeedsNoConfirmation() {
        XCTAssertNil(AlbumAddConfirmation.make(albumTitle: "Small Album", trackCount: 5))
        XCTAssertNil(AlbumAddConfirmation.make(albumTitle: "Small Album", trackCount: 19))
    }

    func testAlbumAddAtThresholdNeedsConfirmationWithCount() throws {
        let confirmation = try XCTUnwrap(AlbumAddConfirmation.make(albumTitle: "Big Album", trackCount: 20))
        XCTAssertTrue(confirmation.message.contains("20"), confirmation.message)
        XCTAssertFalse(confirmation.message.contains("unknown"), confirmation.message)
    }

    func testAlbumAddUnknownCountNeedsConfirmation() throws {
        let unknown = try XCTUnwrap(AlbumAddConfirmation.make(albumTitle: "Mystery Album", trackCount: nil))
        XCTAssertTrue(unknown.message.contains("unknown"), unknown.message)
        let zero = try XCTUnwrap(AlbumAddConfirmation.make(albumTitle: "Mystery Album", trackCount: 0))
        XCTAssertEqual(zero, unknown)
    }

    func testAlbumAddConfirmationTitleContainsAlbumTitle() throws {
        let confirmation = try XCTUnwrap(AlbumAddConfirmation.make(albumTitle: "Zebra Album", trackCount: nil))
        XCTAssertTrue(confirmation.title.contains("Zebra Album"), confirmation.title)
    }
}

final class NowPlayingActionTests: XCTestCase {
    func testLikeIsEnabledForLibraryTrackWithLikes() {
        let like = NowPlayingLikePresentation.make(itemTitle: "Song", isInLibrary: true, likesAvailable: true,
                                                   liked: false, pending: false, busy: false)
        XCTAssertTrue(like.isEnabled)
        XCTAssertFalse(like.isLiked)
        XCTAssertEqual(like.systemImage, "heart")
        XCTAssertEqual(like.title, "Like")
        XCTAssertEqual(like.accessibilityLabel, "Like Song")
        XCTAssertNil(like.explanation)
    }

    func testLikedTrackOffersUnlike() {
        let like = NowPlayingLikePresentation.make(itemTitle: "Song", isInLibrary: true, likesAvailable: true,
                                                   liked: true, pending: true, busy: false)
        XCTAssertTrue(like.isLiked)
        XCTAssertTrue(like.isPending)
        XCTAssertEqual(like.systemImage, "heart.fill")
        XCTAssertEqual(like.title, "Liked")
        XCTAssertEqual(like.accessibilityLabel, "Unlike Song")
    }

    func testLikeExplainsWhyItIsDisabled() {
        let notInLibrary = NowPlayingLikePresentation.make(itemTitle: "Song", isInLibrary: false, likesAvailable: true,
                                                           liked: true, pending: true, busy: false)
        XCTAssertFalse(notInLibrary.isEnabled)
        XCTAssertFalse(notInLibrary.isLiked, "A catalog song never shows a stale library like")
        XCTAssertFalse(notInLibrary.isPending)
        XCTAssertEqual(notInLibrary.explanation, "Add to Library first")

        let noLikes = NowPlayingLikePresentation.make(itemTitle: "Song", isInLibrary: true, likesAvailable: false,
                                                      liked: false, pending: false, busy: false)
        XCTAssertFalse(noLikes.isEnabled)
        XCTAssertEqual(noLikes.explanation, "Likes are unavailable")

        let busy = NowPlayingLikePresentation.make(itemTitle: "Song", isInLibrary: true, likesAvailable: true,
                                                   liked: false, pending: false, busy: true)
        XCTAssertFalse(busy.isEnabled)
        XCTAssertNil(busy.explanation)
    }

    func testPlaylistActionStates() {
        let cases: [(Bool, Bool, Int, Bool, Bool, String?)] = [
            (true, true, 2, false, true, nil),
            (true, true, 2, true, false, nil),
            (false, true, 2, false, false, "Add to Library first"),
            (true, false, 2, false, false, "This server can't edit playlists"),
            (true, true, 0, false, false, "No playlists you can edit"),
        ]
        for (inLibrary, supports, count, busy, enabled, explanation) in cases {
            let action = NowPlayingPlaylistPresentation.make(itemTitle: "Song", isInLibrary: inLibrary,
                                                             supportsEditing: supports, editablePlaylistCount: count,
                                                             busy: busy)
            XCTAssertEqual(action.isEnabled, enabled, "\(inLibrary) \(supports) \(count) \(busy)")
            XCTAssertEqual(action.explanation, explanation, "\(inLibrary) \(supports) \(count) \(busy)")
            XCTAssertEqual(action.accessibilityLabel, "Add Song to a playlist")
        }
    }

    func testEditablePlaylistsKeepOnlyManualEditableWithFavoritesFirst() {
        let lists = [
            playlist("zeta", manual: true, editable: true),
            playlist("Smart", manual: false, editable: true),
            playlist("Shared read-only", manual: true, editable: false),
            playlist("alpha", manual: true, editable: true),
            playlist("Favorite", manual: true, editable: true, favorite: true),
        ]
        XCTAssertEqual(EditablePlaylists.sorted(lists, supportsEditing: true).map(\.name), ["Favorite", "alpha", "zeta"])
        XCTAssertEqual(EditablePlaylists.sorted(lists, supportsEditing: false), [])
        XCTAssertEqual(EditablePlaylists.sorted(nil, supportsEditing: true), [])
    }

    func testUpNextShowsFollowingEntryAndRemainingCount() throws {
        var queue = PlaybackQueue()
        queue.replace([track("a"), track("b"), track("c")], startingAt: 0)
        let summary = try XCTUnwrap(UpNextSummary(queue: queue))
        XCTAssertEqual(summary.entry.item.libraryTrack?.id, "b")
        XCTAssertEqual(summary.laterCount, 1)
        XCTAssertFalse(summary.wrapsToStart)
    }

    func testUpNextIsNilAtEndWithoutRepeatAndWrapsWithRepeatAll() throws {
        var queue = PlaybackQueue()
        queue.replace([track("a"), track("b")], startingAt: 1)
        XCTAssertNil(UpNextSummary(queue: queue))

        queue.repeatMode = .all
        let summary = try XCTUnwrap(UpNextSummary(queue: queue))
        XCTAssertEqual(summary.entry.item.libraryTrack?.id, "a")
        XCTAssertTrue(summary.wrapsToStart)
        XCTAssertEqual(summary.laterCount, 0)
    }

    func testUpNextIgnoresRepeatOneForManualNextAndSingleTrackLoops() throws {
        var queue = PlaybackQueue()
        queue.replace([track("a"), track("b")], startingAt: 0)
        queue.repeatMode = .one
        XCTAssertEqual(try XCTUnwrap(UpNextSummary(queue: queue)).entry.item.libraryTrack?.id, "b")

        queue.replace([track("solo")], startingAt: 0)
        queue.repeatMode = .all
        XCTAssertNil(UpNextSummary(queue: queue), "Looping a single song has nothing else up next")
    }

    func testUpNextFollowsShuffleOrderAndDistinguishesDuplicates() throws {
        var queue = PlaybackQueue()
        queue.replace([track("a"), track("a"), track("b")], startingAt: 0)
        queue.setShuffle(true)
        let summary = try XCTUnwrap(UpNextSummary(queue: queue))
        let order = queue.order
        XCTAssertEqual(summary.entry.id, order[1].id)
        XCTAssertNotEqual(summary.entry.id, queue.currentID)
        XCTAssertEqual(summary.laterCount, 1)
    }

    private func track(_ id: String) -> LibraryTrack {
        LibraryTrack(id: id, file: "\(id).mp3", title: id, artist: "Artist", artists: ["Artist"], album: "Album",
                     albumArtist: "Artist", albumID: "album", artistID: "artist", trackNumber: 1, year: "2026",
                     duration: 100, codec: "mp3", bitrate: 128_000, sampleRate: 44_100, channels: 2, size: 100,
                     added: 0, hasCover: false, isExplicit: false, playlists: [])
    }

    private func playlist(_ name: String, manual: Bool, editable: Bool, favorite: Bool = false) -> LibraryPlaylist {
        LibraryPlaylist(name: name, displayName: nil, liked: nil, favorite: favorite, trackIDs: [], cover: nil,
                        owner: nil, mine: true, manual: manual, canEditTracks: editable, visibility: nil,
                        sharedWithMe: nil, sharedWith: nil, editors: nil)
    }
}
