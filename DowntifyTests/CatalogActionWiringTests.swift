import Combine
import Foundation
import XCTest
@testable import Downtify

@MainActor
final class CatalogActionWiringTests: XCTestCase {
    private let title = "One"

    func testFreshCatalogSongShowsAddToLibraryAction() throws {
        let model = ServerDownloadPresentationModel(queue: ServerDownloadQueue(transport: CatalogRouteTransport(routes: [:]))) {
            AsyncStream<DeviceSession?> { $0.finish() }
        }
        let song = try decodeSong()

        XCTAssertEqual(model.actionState(for: song), .idle)
        let presentation = MediaActionPresentation.library(model.actionState(for: song), itemTitle: song.title)
        XCTAssertEqual(presentation.title, "Add to Library")
        XCTAssertEqual(presentation.systemImage, "plus.circle")
        XCTAssertTrue(presentation.isEnabled)
    }

    func testQueuedCatalogSongShowsDisabledQueuedAction() async throws {
        let transport = CatalogRouteTransport(routes: [
            "/api/server/info": #"{"product":"Downtify","api_version":1,"server_id":"server"}"#,
            "/api/download/url": #""job-1""#,
            "/api/queue": "[]",
            "/api/queue/state": #"{"paused":false,"state":"idle","active":0}"#
        ])
        let (updates, continuation) = AsyncStream<DeviceSession?>.makeStream()
        let model = ServerDownloadPresentationModel(queue: ServerDownloadQueue(transport: transport)) { updates }
        model.start()
        continuation.yield(makeSession())
        await waitUntil { model.session != nil }
        let song = try decodeSong()

        await model.request(song: song)

        XCTAssertEqual(model.actionState(for: song), .queued(jobID: "job-1"))
        let presentation = MediaActionPresentation.library(model.actionState(for: song), itemTitle: song.title)
        XCTAssertEqual(presentation.systemImage, "clock.arrow.circlepath")
        XCTAssertFalse(presentation.isEnabled)
        continuation.finish()
    }

    func testOwnedSongRowShowsInLibraryWhileOtherVersionStaysRequestable() throws {
        let track = LibraryTrack(id: "t", file: "Artist/Album/One.flac", title: "One", artist: "A", artists: ["A"], album: "Album",
                                 albumArtist: "A", albumID: "al", artistID: "ar", trackNumber: 1, year: "2026",
                                 duration: 60, codec: "flac", bitrate: 900_000, sampleRate: 44_100, channels: 2,
                                 size: 8, added: 1, hasCover: false, isExplicit: false, playlists: [])
        let membership = LibraryMembership(tracks: [track])
        let owned = try decodeSong()
        let live = try JSONDecoder().decode(CatalogSong.self, from: Data(
            #"{"source":"youtube","song_id":"yt-2","name":"One (Live)","artists":["A"]}"#.utf8))

        let ownedState = ServerDownloadActionState.catalogRow(server: .idle, inLibrary: membership.containsSong(owned))
        XCTAssertEqual(ownedState, .accepted)
        XCTAssertFalse(MediaActionPresentation.library(ownedState, itemTitle: owned.title).isEnabled)
        XCTAssertEqual(ServerDownloadActionState.catalogRow(server: .idle, inLibrary: membership.containsSong(live)), .idle)
    }

    func testCatalogOnlySongHasNoDevicePresentation() throws {
        let state = DeviceSaveState(track: nil, record: nil)
        XCTAssertEqual(state, .unavailable(.notInLibrary))

        let presentation = MediaActionPresentation.device(state, itemTitle: title)
        XCTAssertFalse(presentation.isEnabled)
        XCTAssertNotNil(presentation.explanation)
    }

    func testYouTubeMusicAlbumURLAcceptsOnlyAlbumForms() {
        XCTAssertTrue(ServerDownloadQueue.isYouTubeMusicAlbumURL("https://music.youtube.com/browse/MPREb_abc"))
        XCTAssertTrue(ServerDownloadQueue.isYouTubeMusicAlbumURL("https://music.youtube.com/playlist?list=OLAK5uy_abc"))
        XCTAssertFalse(ServerDownloadQueue.isYouTubeMusicAlbumURL("https://music.youtube.com/channel/UCabc"))
        XCTAssertFalse(ServerDownloadQueue.isYouTubeMusicAlbumURL("https://music.youtube.com/watch?v=abc"))
        XCTAssertFalse(ServerDownloadQueue.isYouTubeMusicAlbumURL("https://open.spotify.com/album/abc"))
        XCTAssertFalse(ServerDownloadQueue.isYouTubeMusicAlbumURL(""))
    }

    func testLibraryMatchedCatalogRowIgnoresServerStateWhenInLibrary() {
        for server in [ServerDownloadActionState.idle, .failed("x"), .outcomeUnknown] {
            XCTAssertEqual(ServerDownloadActionState.catalogRow(server: server, inLibrary: true), .accepted)
        }
    }

    func testCatalogRowKeepsServerStateWhenNotInLibrary() {
        let states: [ServerDownloadActionState] = [
            .idle, .submitting, .queued(jobID: "job-1"), .queued(jobID: nil), .accepted,
            .partiallyAccepted(successful: 1, expected: 2), .outcomeUnknown, .failed("x")
        ]
        for server in states {
            XCTAssertEqual(ServerDownloadActionState.catalogRow(server: server, inLibrary: false), server)
        }
    }

    func testLibraryMatchedCatalogRowShowsInLibraryPresentation() {
        let state = ServerDownloadActionState.catalogRow(server: .idle, inLibrary: true)
        let presentation = MediaActionPresentation.library(state, itemTitle: "T")
        XCTAssertEqual(presentation.title, "In Library")
        XCTAssertEqual(presentation.systemImage, "checkmark.circle.fill")
        XCTAssertFalse(presentation.isEnabled)
    }

    func testRequestPublishesSubmittingThenQueuedState() async throws {
        let (gate, release) = AsyncStream<Void>.makeStream()
        let transport = CatalogRouteTransport(routes: Self.queueRoutes, downloadGate: gate)
        let (updates, continuation) = AsyncStream<DeviceSession?>.makeStream()
        let model = ServerDownloadPresentationModel(queue: ServerDownloadQueue(transport: transport)) { updates }
        model.start()
        continuation.yield(makeSession())
        await waitUntil { model.session != nil }
        let song = try decodeSong()

        let log = StateLog()
        let cancellable = model.objectWillChange.sink { [weak model] in
            Task { @MainActor in
                guard let model else { return }
                log.values.append(model.actionState(for: song))
            }
        }

        let request = Task { await model.request(song: song) }
        await waitUntil { model.actionState(for: song) == .submitting }
        XCTAssertEqual(model.actionState(for: song), .submitting)
        release.yield(())
        await request.value
        await drainMainActor()

        XCTAssertFalse(log.values.isEmpty)
        let submitting = try XCTUnwrap(log.values.firstIndex(of: .submitting))
        let queued = try XCTUnwrap(log.values.firstIndex(of: .queued(jobID: "job-1")))
        XCTAssertLessThan(submitting, queued)
        XCTAssertEqual(log.values.last, .queued(jobID: "job-1"))
        XCTAssertEqual(model.actionState(for: song), .queued(jobID: "job-1"))
        cancellable.cancel()
        continuation.finish()
    }

    func testDuplicateTapWhileSubmittingOrQueuedSendsOneDownloadRequest() async throws {
        let (gate, release) = AsyncStream<Void>.makeStream()
        let transport = CatalogRouteTransport(routes: Self.queueRoutes, downloadGate: gate)
        let (updates, continuation) = AsyncStream<DeviceSession?>.makeStream()
        let model = ServerDownloadPresentationModel(queue: ServerDownloadQueue(transport: transport)) { updates }
        model.start()
        continuation.yield(makeSession())
        await waitUntil { model.session != nil }
        let song = try decodeSong()

        let first = Task { await model.request(song: song) }
        await waitUntil { model.actionState(for: song) == .submitting }
        await waitUntil { transport.downloadRequestCount == 1 }
        await model.request(song: song)
        XCTAssertEqual(transport.downloadRequestCount, 1)
        XCTAssertEqual(model.actionState(for: song), .submitting)

        release.yield(())
        await first.value
        XCTAssertEqual(model.actionState(for: song), .queued(jobID: "job-1"))

        await model.request(song: song)
        XCTAssertEqual(transport.downloadRequestCount, 1)
        XCTAssertEqual(model.actionState(for: song), .queued(jobID: "job-1"))
        continuation.finish()
    }

    func testRequestPreservesProviderPayloadAndURL() async throws {
        let transport = CatalogRouteTransport(routes: Self.queueRoutes)
        let (updates, continuation) = AsyncStream<DeviceSession?>.makeStream()
        let model = ServerDownloadPresentationModel(queue: ServerDownloadQueue(transport: transport)) { updates }
        model.start()
        continuation.yield(makeSession())
        await waitUntil { model.session != nil }
        let source = #"{"source":"youtube","song_id":"yt-1","name":"One","artists":["A"],"url":"https://music.youtube.com/watch?v=yt-1","provider_extra":{"value":42}}"#
        let song = try JSONDecoder().decode(CatalogSong.self, from: Data(source.utf8))

        await model.request(song: song)

        let request = try XCTUnwrap(transport.downloadRequests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        let payload = try XCTUnwrap(request.httpBody)
        let actual = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? NSDictionary)
        let expected = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(source.utf8)) as? NSDictionary)
        XCTAssertEqual(actual, expected)
        XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "url" })?.value, song.url)
        XCTAssertEqual(model.actionState(for: song), .queued(jobID: "job-1"))
        continuation.finish()
    }

    func testServerFailureCanBeRetriedOnce() async throws {
        let transport = CatalogRouteTransport(routes: Self.queueRoutes, failFirstDownload: true)
        let (updates, continuation) = AsyncStream<DeviceSession?>.makeStream()
        let model = ServerDownloadPresentationModel(queue: ServerDownloadQueue(transport: transport)) { updates }
        model.start()
        continuation.yield(makeSession())
        await waitUntil { model.session != nil }
        let song = try decodeSong()

        await model.request(song: song)
        guard case .failed = model.actionState(for: song) else {
            return XCTFail("A definite HTTP failure should permit retry")
        }
        await model.request(song: song)
        XCTAssertEqual(transport.downloadRequestCount, 2)
        XCTAssertEqual(model.actionState(for: song), .queued(jobID: "job-1"))
        continuation.finish()
    }

    func testSessionChangeDiscardsInFlightRequestState() async throws {
        let (gate, release) = AsyncStream<Void>.makeStream()
        let transport = CatalogRouteTransport(routes: Self.queueRoutes, downloadGate: gate)
        let (updates, continuation) = AsyncStream<DeviceSession?>.makeStream()
        let model = ServerDownloadPresentationModel(queue: ServerDownloadQueue(transport: transport)) { updates }
        model.start()
        continuation.yield(makeSession())
        await waitUntil { model.session != nil }
        let song = try decodeSong()
        let request = Task { await model.request(song: song) }
        await waitUntil { transport.downloadRequestCount == 1 }
        XCTAssertEqual(model.actionState(for: song), .submitting)

        continuation.yield(nil)
        await waitUntil { model.session == nil }
        XCTAssertEqual(model.actionState(for: song), .idle)
        release.yield(())
        await request.value
        XCTAssertEqual(model.actionState(for: song), .idle)
        continuation.finish()
    }

    func testPlayerShowsLibraryMembershipSeparatelyFromQueuedRequest() throws {
        let song = try decodeSong()
        let queued = ServerDownloadActionState.queued(jobID: "job-1")
        let track = LibraryTrack(id: "t", file: "Artist/Album/One.flac", title: "One", artist: "A", artists: ["A"], album: "Album",
                                 albumArtist: "A", albumID: "al", artistID: "ar", trackNumber: 1, year: "2026",
                                 duration: 60, codec: "flac", bitrate: 900_000, sampleRate: 44_100, channels: 2,
                                 size: 8, added: 1, hasCover: false, isExplicit: false, playlists: [])
        let absent = LibraryMembership(tracks: []).track(for: song) != nil
        let present = LibraryMembership(tracks: [track]).track(for: song) != nil
        let pending = NowPlayingLibraryPresentation.make(song: song, isInLibrary: absent,
            externalCatalogAvailable: true, hasSession: true, state: queued)
        let confirmed = NowPlayingLibraryPresentation.make(song: song, isInLibrary: present,
            externalCatalogAvailable: true, hasSession: true, state: queued)
        XCTAssertFalse(absent)
        XCTAssertTrue(present)
        XCTAssertEqual(pending.title, "Queued for Library")
        XCTAssertEqual(confirmed.title, "In Library")
        XCTAssertFalse(confirmed.isEnabled)
    }

    func testMissingURLNeverReachesDownloadEndpoint() async throws {
        let transport = CatalogRouteTransport(routes: Self.queueRoutes)
        let (updates, continuation) = AsyncStream<DeviceSession?>.makeStream()
        let model = ServerDownloadPresentationModel(queue: ServerDownloadQueue(transport: transport)) { updates }
        model.start()
        continuation.yield(makeSession())
        await waitUntil { model.session != nil }
        let song = try JSONDecoder().decode(CatalogSong.self, from: Data(
            #"{"source":"youtube","song_id":"yt-1","name":"One","artists":["A"]}"#.utf8))
        let presentation = NowPlayingLibraryPresentation.make(song: song, isInLibrary: false,
            externalCatalogAvailable: true, hasSession: true, state: model.actionState(for: song))
        XCTAssertFalse(presentation.isEnabled)
        // The queue remains defensive even if a caller bypasses the presentation guard.
        await model.request(song: song)
        XCTAssertEqual(transport.downloadRequestCount, 0)
        guard case .failed = model.actionState(for: song) else {
            return XCTFail("A missing URL should fail locally")
        }
        continuation.finish()
    }

    private static let queueRoutes: [String: String] = [
        "/api/server/info": #"{"product":"Downtify","api_version":1,"server_id":"server"}"#,
        "/api/download/url": #""job-1""#,
        "/api/queue": "[]",
        "/api/queue/state": #"{"paused":false,"state":"idle","active":0}"#
    ]

    private func decodeSong() throws -> CatalogSong {
        try JSONDecoder().decode(CatalogSong.self, from: Data(
            #"{"source":"youtube","song_id":"yt-1","name":"One","artists":["A"],"url":"https://music.youtube.com/watch?v=yt-1"}"#.utf8
        ))
    }

    private func makeSession() -> DeviceSession {
        DeviceSession(baseAddress: "https://example.test", serverID: "server", serverName: "Server", deviceID: "device",
                      username: "listener", role: nil, token: "secret", allowsInsecureHTTP: false)
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(1)
        while !condition(), ContinuousClock.now < deadline { await Task.yield() }
    }

    private func drainMainActor() async {
        for _ in 0..<10 { await Task.yield() }
    }
}

@MainActor
private final class StateLog {
    var values: [ServerDownloadActionState] = []
}

private final class CatalogRouteTransport: HTTPDataLoading, @unchecked Sendable {
    private let routes: [String: String]
    private let downloadGate: AsyncStream<Void>?
    private let lock = NSLock()
    private var capturedDownloads: [URLRequest] = []
    private let failFirstDownload: Bool

    init(routes: [String: String], downloadGate: AsyncStream<Void>? = nil, failFirstDownload: Bool = false) {
        self.routes = routes
        self.downloadGate = downloadGate
        self.failFirstDownload = failFirstDownload
    }

    var downloadRequestCount: Int {
        lock.withLock { capturedDownloads.count }
    }

    var downloadRequests: [URLRequest] {
        lock.withLock { capturedDownloads }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let path = request.url?.path ?? ""
        guard let route = routes.keys.first(where: { path.hasSuffix($0) }), let body = routes[route] else {
            throw APIError.invalidResponse
        }
        if route == "/api/download/url" {
            let count = lock.withLock {
                capturedDownloads.append(request)
                return capturedDownloads.count
            }
            if failFirstDownload && count == 1 {
                let response = HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (Data(), response)
            }
            if let downloadGate {
                var iterator = downloadGate.makeAsyncIterator()
                _ = await iterator.next()
            }
        }
        let response = HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}
