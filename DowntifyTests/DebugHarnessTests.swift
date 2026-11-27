#if DEBUG
import Foundation
import SwiftUI
import XCTest
@testable import Downtify

@MainActor
final class DebugHarnessTests: XCTestCase {
    private let harnessArgs = ["-DowntifyHarness"]
    private let stagingArgs = ["-DowntifyHarness", "-DowntifyHarnessMode", "staging"]

    func testNowPlayingPlacementAdaptsToAvailableSpace() {
        func placement(_ width: CGFloat, _ height: CGFloat, accessibility: Bool = false) -> NowPlayingLayout {
            NowPlayingLayout(size: CGSize(width: width, height: height), isAccessibilitySize: accessibility)
        }
        XCTAssertTrue(placement(768, 1024).isWide) // iPad portrait
        XCTAssertTrue(placement(1024, 768).isWide) // iPad landscape
        XCTAssertFalse(placement(400, 768).isWide) // narrow split view
        XCTAssertTrue(placement(500, 600).isWide)
        XCTAssertFalse(placement(1024, 768, accessibility: true).isWide)
        XCTAssertEqual(placement(768, 1024).artworkSize(redesigned: true), 200)
        XCTAssertEqual(placement(390, 844).artworkSize(redesigned: true), 358)
        XCTAssertEqual(placement(1024, 768).artworkSize(redesigned: true), 200)
        XCTAssertEqual(placement(200, 400).artworkSize(redesigned: true), 168)
        XCTAssertEqual(placement(768, 1024, accessibility: true).artworkSize(redesigned: false), 172)
    }

    /// The example themes in docs/theme-examples must stay valid, and full.json must show every field.
    func testDocumentedExampleThemesDecodeAndCoverEveryField() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/theme-examples")
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertGreaterThanOrEqual(files.count, 3)
        for file in files {
            XCTAssertNoThrow(try DowntifyTheme.decode(Data(contentsOf: file)), file.lastPathComponent)
        }
        let full = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("full.json"))) as? [String: Any])
        let fields = Set(Mirror(reflecting: DowntifyTheme.example).children.compactMap(\.label))
        XCTAssertEqual(Set(full.keys), fields, "full.json should list every theme field; update it and the guide when fields change")
    }

    func testThemeRoundTripAndInvalidInputs() throws {
        let original = try DowntifyTheme.bundled("original")
        let redesign = try DowntifyTheme.bundled("redesign")
        XCTAssertEqual(original.name, "Original")
        XCTAssertEqual(original.surfaceStyle, "system")
        XCTAssertEqual(redesign, .example)
        let data = try JSONEncoder().encode(DowntifyTheme.example)
        XCTAssertEqual(try DowntifyTheme.decode(data), .example)
        var bad = DowntifyTheme.example
        bad.accentDark = "nothex"
        XCTAssertThrowsError(try DowntifyTheme.decode(JSONEncoder().encode(bad)))
        bad = .example
        bad.homeSections = ["recent", "recent", "new"]
        XCTAssertThrowsError(try DowntifyTheme.decode(JSONEncoder().encode(bad)))
        bad = .example
        bad.componentStyles = ["unknown": "redesign"]
        XCTAssertThrowsError(try DowntifyTheme.decode(JSONEncoder().encode(bad)))
        bad = .example
        bad.elevatedDark = nil
        XCTAssertThrowsError(try DowntifyTheme.decode(JSONEncoder().encode(bad)))
        bad = .example
        bad.navigationStyle = "unknown"
        XCTAssertThrowsError(try DowntifyTheme.decode(JSONEncoder().encode(bad)))
        var legacy = DowntifyTheme.example
        legacy.navigationStyle = nil
        legacy.headerStyle = nil
        legacy.recentStyle = nil
        legacy.playerStyle = nil
        legacy.componentStyles = nil
        legacy.elevatedLight = nil
        legacy.elevatedDark = nil
        legacy.brandLight = nil
        legacy.brandDark = nil
        legacy.onBrandLight = nil
        legacy.onBrandDark = nil
        legacy.fontDesign = nil
        legacy.browseColors = nil
        XCTAssertEqual(try DowntifyTheme.decode(JSONEncoder().encode(legacy)), legacy)
        bad = .example
        bad.albumGridMinimum = 999
        XCTAssertThrowsError(try DowntifyTheme.decode(JSONEncoder().encode(bad)))
        XCTAssertThrowsError(try DowntifyTheme.decode(Data(repeating: 32, count: 16_385)))
    }

    func testHomeSectionsAcceptOptionalCardsAndKeepOlderFilesComplete() throws {
        func decode(_ sections: [String]) throws -> DowntifyTheme {
            var theme = DowntifyTheme.example
            theme.homeSections = sections
            return try DowntifyTheme.decode(JSONEncoder().encode(theme))
        }
        // Listed optional sections are shown exactly as ordered; leaving one out hides it.
        XCTAssertEqual(try decode(["artists", "recent", "new", "favorites"]).resolvedHomeSections,
                       ["artists", "recent", "new", "favorites"])
        XCTAssertEqual(try decode(["downloaded", "favorites", "new", "recent", "discover"]).resolvedHomeSections,
                       ["downloaded", "favorites", "new", "recent", "discover"])
        // A file from before the optional sections existed gets all three after its own.
        XCTAssertEqual(try decode(["favorites", "recent", "new"]).resolvedHomeSections,
                       ["favorites", "recent", "new", "discover", "artists", "downloaded"])
        XCTAssertEqual(try DowntifyTheme.bundled("original").resolvedHomeSections,
                       ["recent", "new", "favorites", "discover", "artists", "downloaded"])
        XCTAssertEqual(try DowntifyTheme.bundled("redesign").resolvedHomeSections, DowntifyTheme.standardHomeSections)

        XCTAssertThrowsError(try decode(["recent", "new", "discover"]), "a required section is missing")
        XCTAssertThrowsError(try decode(["recent", "new", "favorites", "artists", "artists"]), "listed twice")
        XCTAssertThrowsError(try decode(["recent", "new", "favorites", "podcasts"]), "unknown section")
    }

    func testEqualizerThemeColorsAreOptionalPairsWithPaletteFallbacks() throws {
        func rgb(_ color: Color, _ style: UIUserInterfaceStyle) -> [Int] {
            let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
            return [r, g, b].map { Int(($0 * 255).rounded()) }
        }
        // Without equalizer fields, the equalizer follows the shared palette.
        let fallback = DowntifyPalette(theme: .example)
        XCTAssertEqual(rgb(fallback.equalizerAccent, .dark), rgb(fallback.accent, .dark))
        XCTAssertEqual(rgb(fallback.equalizerHandle, .light), rgb(fallback.brand, .light))
        XCTAssertEqual(rgb(fallback.equalizerGrid, .dark), rgb(DowntifyStyle.secondaryText, .dark))
        XCTAssertEqual(DowntifyPalette(theme: .example).cardCornerRadius(default: 12), 8)
        XCTAssertEqual(DowntifyPalette().cardCornerRadius(default: 12), 12)

        var themed = DowntifyTheme.example
        themed.equalizerAccentLight = "AA0011"; themed.equalizerAccentDark = "FF3355"
        themed.equalizerHandleLight = "000000"; themed.equalizerHandleDark = "FFFFFF"
        themed.equalizerGridLight = "666666"; themed.equalizerGridDark = "999999"
        let decoded = try DowntifyTheme.decode(JSONEncoder().encode(themed))
        XCTAssertEqual(decoded, themed)
        let palette = DowntifyPalette(theme: decoded)
        XCTAssertEqual(rgb(palette.equalizerAccent, .light), [0xAA, 0x00, 0x11])
        XCTAssertEqual(rgb(palette.equalizerAccent, .dark), [0xFF, 0x33, 0x55])
        XCTAssertEqual(rgb(palette.equalizerHandle, .dark), [0xFF, 0xFF, 0xFF])
        XCTAssertEqual(rgb(palette.equalizerGrid, .light), [0x66, 0x66, 0x66])

        var bad = themed
        bad.equalizerHandleDark = nil
        XCTAssertThrowsError(try DowntifyTheme.decode(JSONEncoder().encode(bad)), "pairs are set together")
        bad = themed
        bad.equalizerGridLight = "#66666"
        XCTAssertThrowsError(try DowntifyTheme.decode(JSONEncoder().encode(bad)), "six hex digits")
    }

    // MARK: Activation and fixture defaults

    func testHarnessIsInactiveWithoutFlag() {
        XCTAssertNil(DebugHarnessConfiguration.parse(arguments: ["-other"], environment: [:]))
    }

    func testFixtureModeIsDefault() throws {
        let config = try XCTUnwrap(DebugHarnessConfiguration.parse(arguments: harnessArgs, environment: [:]))
        XCTAssertEqual(config.mode, .fixture)
        XCTAssertNil(config.staging)
        XCTAssertNil(config.configurationError)
    }

    func testFixtureTrackCountDefaultsToTwoAndAcceptsOverride() throws {
        let defaults = try XCTUnwrap(DebugHarnessConfiguration.parse(arguments: harnessArgs, environment: [:]))
        XCTAssertEqual(defaults.fixtureTrackCount, 2)
        let five = try XCTUnwrap(DebugHarnessConfiguration.parse(arguments: harnessArgs + ["-DowntifyFixtureTracks", "5"], environment: [:]))
        XCTAssertEqual(five.fixtureTrackCount, 5)
        for bad in ["1", "99", "x"] {
            let config = try XCTUnwrap(DebugHarnessConfiguration.parse(arguments: harnessArgs + ["-DowntifyFixtureTracks", bad], environment: [:]))
            XCTAssertEqual(config.fixtureTrackCount, 2, bad)
        }
    }

    func testFixtureLibraryPageGeneratesRequestedTracks() throws {
        for count in [2, 5] {
            let data = Data(DebugFixtureTransport.libraryPage(trackCount: count).utf8)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let tracks = try XCTUnwrap(json["tracks"] as? [[String: Any]])
            XCTAssertEqual(tracks.count, count)
            XCTAssertEqual(tracks.first?["id"] as? String, "fixture-track-1")
            XCTAssertEqual(tracks.last?["id"] as? String, "fixture-track-\(count)")
        }
    }

    // MARK: Fixture options (#70, #71, #72)

    func testFixtureOptionDefaultsLeaveCapabilitiesOff() throws {
        let config = try XCTUnwrap(DebugHarnessConfiguration.parse(arguments: harnessArgs, environment: [:]))
        XCTAssertEqual(config.fixtureLyrics, .none)
        XCTAssertNil(config.fixtureSimilar)
        XCTAssertTrue(DebugFixtureTransport.serverInfo(lyrics: false, discover: false).contains(#""discover":false,"lyrics":false"#))
    }

    func testFixtureOptionsParse() throws {
        let args = harnessArgs + ["-DowntifyFixtureLyrics", "both", "-DowntifyFixtureSimilar", "3,failpage=2"]
        let config = try XCTUnwrap(DebugHarnessConfiguration.parse(arguments: args, environment: [:]))
        XCTAssertEqual(config.fixtureLyrics, .both)
        XCTAssertEqual(config.fixtureSimilar, .init(pages: 3, failPage: 2))
    }

    func testInvalidFixtureOptionsAreIgnored() throws {
        let args = harnessArgs + ["-DowntifyFixtureLyrics", "weird", "-DowntifyFixtureSimilar", "0"]
        let config = try XCTUnwrap(DebugHarnessConfiguration.parse(arguments: args, environment: [:]))
        XCTAssertEqual(config.fixtureLyrics, .none)
        XCTAssertNil(config.fixtureSimilar)
        XCTAssertEqual(DebugHarnessConfiguration.parseFixtureSimilar("2,failpage=9"), .init(pages: 2, failPage: nil))
    }

    func testLyricsFixtureRoutesDecodeAsTrackLyrics() async throws {
        let session = DeviceSession(baseAddress: "https://fixture.test", serverID: DebugFixtureTransport.serverID, serverName: "Fixture",
                                    deviceID: "d", username: nil, role: nil, token: DebugFixtureTransport.token, allowsInsecureHTTP: false)
        for (mode, synced, plain) in [(DebugHarnessConfiguration.FixtureLyrics.both, 4, true), (.synced, 4, false), (.plain, 0, true)] {
            let api = TrackLyricsAPI(transport: DebugFixtureTransport(faults: [:], lyrics: mode))
            let lyrics = try await api.fetch(trackID: "fixture-track-1", session: session)
            XCTAssertEqual(lyrics?.lines.count, synced, "\(mode)")
            XCTAssertEqual(lyrics?.plain.isEmpty == false, plain, "\(mode)")
        }
        let none = try await TrackLyricsAPI(transport: DebugFixtureTransport(faults: [:])).fetch(trackID: "fixture-track-1", session: session)
        XCTAssertNil(none)
        do {
            _ = try await TrackLyricsAPI(transport: DebugFixtureTransport(faults: [:], lyrics: .error)).fetch(trackID: "fixture-track-1", session: session)
            XCTFail("expected a failure")
        } catch {}
    }

    func testSimilarFixturePagesAreDeterministicAndFailOnce() async throws {
        let transport = DebugFixtureTransport(faults: [:], similar: .init(pages: 2, failPage: 2))
        func fetch(_ track: String) async throws -> (Int, [String]) {
            var components = URLComponents(string: "https://fixture.test/api/similar/tracks")!
            components.queryItems = [.init(name: "artist", value: "Similar Artist"), .init(name: "track", value: track)]
            let (data, response) = try await transport.data(for: URLRequest(url: try XCTUnwrap(components.url)))
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { return (status, []) }
            let decoded = try JSONDecoder().decode(CatalogSimilarResults.self, from: data)
            return (status, decoded.tracks.map(\.title))
        }
        let first = try await fetch("Seed")
        XCTAssertEqual(first.0, 200)
        XCTAssertEqual(first.1.count, 20)
        let pool = DebugFixtureTransport.similarPool.map(\.title)
        XCTAssertEqual(first.1.last, pool[19])
        let failed = try await fetch(pool[19])
        XCTAssertEqual(failed.0, 500)
        let second = try await fetch(pool[19])
        XCTAssertEqual(second.1.first, pool[20])
        let dry = try await fetch(pool[39])
        XCTAssertEqual(dry.1, second.1, "past the last page only duplicates come back")
    }

    func testSimilarRouteIsFaultableThroughCatalog() {
        XCTAssertEqual(DebugFixtureTransport.route(for: "/api/similar/tracks"), .catalog)
    }

    // MARK: Fault parsing

    func testFaultsParsePerRoute() {
        let faults = DebugHarnessConfiguration.parseFaults(
            ["-DowntifyFault", "stream=http500", "-DowntifyFault", "library=timeout", "-DowntifyFault", "bogus=offline"])
        XCTAssertEqual(faults, [.stream: .http500, .library: .timeout])
    }

    func testFaultTransportThrowsTimeoutAndReturnsStatusCodes() async throws {
        let url = try XCTUnwrap(URL(string: "https://fixture.test/api/v1/library"))
        let timeout = DebugFixtureTransport(faults: [.library: .timeout])
        do {
            _ = try await timeout.data(for: URLRequest(url: url))
            XCTFail("expected timeout")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        }

        let server = DebugFixtureTransport(faults: [.library: .http500])
        let (_, response) = try await server.data(for: URLRequest(url: url))
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 500)

        let auth = DebugFixtureTransport(faults: [.library: .unauthorized])
        let (_, unauthorized) = try await auth.data(for: URLRequest(url: url))
        XCTAssertEqual((unauthorized as? HTTPURLResponse)?.statusCode, 401)
    }

    func testFixtureSignInCompletesThroughConnectionService() async throws {
        let connection = ConnectionService(transport: DebugFixtureTransport(faults: [:]),
                                           store: DebugMemorySessionStore())
        let target = try await connection.probe("https://fixture.test")
        let session = try await connection.signIn(username: "fixture", password: "fixture-password",
                                                  at: target, deviceName: "Harness")
        XCTAssertEqual(session.serverID, DebugFixtureTransport.serverID)
    }

    // MARK: Staging fail-closed rules

    func testStagingFailsClosedOnDisallowedHost() throws {
        let env = ["DOWNTIFY_TEST_SERVER": "https://music.example.com", "DOWNTIFY_TEST_USER": "u", "DOWNTIFY_TEST_PASSWORD": "p"]
        let config = try XCTUnwrap(DebugHarnessConfiguration.parse(arguments: stagingArgs, environment: env))
        XCTAssertNil(config.staging)
        XCTAssertEqual(config.configurationError, .hostNotAllowed)
    }

    func testStagingFailsClosedWhenServerOrCredentialsMissing() throws {
        let noServer = try XCTUnwrap(DebugHarnessConfiguration.parse(arguments: stagingArgs, environment: [:]))
        XCTAssertEqual(noServer.configurationError, .missingStagingServer)
        let noCreds = try XCTUnwrap(DebugHarnessConfiguration.parse(
            arguments: stagingArgs, environment: ["DOWNTIFY_TEST_SERVER": "http://localhost:8000"]))
        XCTAssertEqual(noCreds.configurationError, .missingStagingCredentials)
    }

    func testAllowedHostDeclarationMustMatch() throws {
        let env = ["DOWNTIFY_TEST_SERVER": "http://localhost:8000", "DOWNTIFY_TEST_USER": "u",
                   "DOWNTIFY_TEST_PASSWORD": "p", "DOWNTIFY_TEST_ALLOWED_HOST": "other.localhost"]
        XCTAssertEqual(try XCTUnwrap(DebugHarnessConfiguration.parse(arguments: stagingArgs, environment: env))
            .configurationError, .hostMismatch)
    }

    func testHostAllowList() {
        for host in ["localhost", "127.0.0.1", "::1", "[::1]", "app.localhost", "x.test", "staging.example.com", "qa.example.org"] {
            XCTAssertTrue(DebugHarnessConfiguration.isAllowedHost(host), host)
        }
        for host in ["music.example.com", "downtify.app", "192.168.1.10"] {
            XCTAssertFalse(DebugHarnessConfiguration.isAllowedHost(host), host)
        }
    }

    // MARK: Mutation rules

    func testMutationsOnlyOnLoopbackWithOptIn() throws {
        let loopback = try staging(server: "http://127.0.0.1:8000", allowMutations: "1")
        XCTAssertTrue(loopback.allowsMutations)

        let remoteStaging = try staging(server: "https://staging.example.com", allowMutations: "1")
        XCTAssertFalse(remoteStaging.allowsMutations, "remote staging hosts are read-only even with opt-in")

        let noOptIn = try staging(server: "http://localhost:8000", allowMutations: nil)
        XCTAssertFalse(noOptIn.allowsMutations)
    }

    func testGuardRefusesMutationWithoutOptInAndForeignHosts() throws {
        let config = try XCTUnwrap(DebugHarnessConfiguration.parse(arguments: stagingArgs, environment: [
            "DOWNTIFY_TEST_SERVER": "https://staging.example.com", "DOWNTIFY_TEST_USER": "u",
            "DOWNTIFY_TEST_PASSWORD": "p", "DOWNTIFY_TEST_ALLOW_MUTATIONS": "1"]))

        var post = URLRequest(url: try XCTUnwrap(URL(string: "https://staging.example.com/api/v1/likes")))
        post.httpMethod = "POST"
        XCTAssertThrowsError(try DebugGuardedTransport.authorize(post, configuration: config)) {
            XCTAssertEqual($0 as? DebugHarnessError, .mutationRefused)
        }

        let other = URLRequest(url: try XCTUnwrap(URL(string: "https://elsewhere.staging.example.com/api/v1/library")))
        XCTAssertThrowsError(try DebugGuardedTransport.authorize(other, configuration: config)) {
            XCTAssertEqual($0 as? DebugHarnessError, .hostMismatch)
        }

        var signIn = URLRequest(url: try XCTUnwrap(URL(string: "https://staging.example.com/api/auth/token")))
        signIn.httpMethod = "POST"
        XCTAssertNoThrow(try DebugGuardedTransport.authorize(signIn, configuration: config))

        var otherPost = URLRequest(url: try XCTUnwrap(URL(string: "https://staging.example.com/api/auth/pair")))
        otherPost.httpMethod = "POST"
        XCTAssertThrowsError(try DebugGuardedTransport.authorize(otherPost, configuration: config))

        let get = URLRequest(url: try XCTUnwrap(URL(string: "https://staging.example.com/api/v1/library")))
        XCTAssertNoThrow(try DebugGuardedTransport.authorize(get, configuration: config))
    }

    func testInvalidConfigurationRefusesAllTraffic() throws {
        let config = try XCTUnwrap(DebugHarnessConfiguration.parse(arguments: stagingArgs, environment: [:]))
        let get = URLRequest(url: try XCTUnwrap(URL(string: "http://localhost:8000/api/v1/library")))
        XCTAssertThrowsError(try DebugGuardedTransport.authorize(get, configuration: config))
    }

    // MARK: Redaction

    func testSnapshotContainsOnlyApprovedKeysAndNoSecrets() throws {
        let snapshot = DebugStateSnapshot(playbackPhase: "playing", queueCount: 2, currentTrackID: "fixture-track-1",
                                          position: 1.5, network: "wifiOrWired", libraryTrackCount: 2,
                                          lastErrorCode: nil, artworkLoaded: true, playerVisible: true, sessionActive: true,
                                          queueTrackIDs: ["fixture-track-1", "fixture-track-2"])
        let json = snapshot.json
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["playbackPhase", "queueCount", "currentTrackID", "position", "network",
                                          "libraryTrackCount", "lastErrorCode", "artworkLoaded", "playerVisible", "sessionActive", "queueTrackIDs"])
        for forbidden in ["token", "username", "password", "http", "server", "title", DebugFixtureTransport.token, "fixture-server"] {
            XCTAssertFalse(json.lowercased().contains(forbidden.lowercased()), forbidden)
        }
    }

    // MARK: Isolation

    func testHarnessWritesNothingToStandardDefaults() throws {
        let before = Set(UserDefaults.standard.dictionaryRepresentation().keys)
        let harness = DebugHarness(configuration: try XCTUnwrap(
            DebugHarnessConfiguration.parse(arguments: harnessArgs, environment: [:])))
        let defaults = harness.makeDefaults()
        PlaybackStateStore(defaults: defaults).saveImmediateQualitySwitch(true)
        defaults.set("probe", forKey: "debug.harness.probe")
        XCTAssertEqual(defaults.string(forKey: "debug.harness.probe"), "probe")

        XCTAssertEqual(Set(UserDefaults.standard.dictionaryRepresentation().keys), before)
    }

    private func staging(server: String, allowMutations: String?) throws -> DebugHarnessConfiguration.StagingTarget {
        var env = ["DOWNTIFY_TEST_SERVER": server, "DOWNTIFY_TEST_USER": "u", "DOWNTIFY_TEST_PASSWORD": "p"]
        if let allowMutations { env["DOWNTIFY_TEST_ALLOW_MUTATIONS"] = allowMutations }
        return try XCTUnwrap(DebugHarnessConfiguration.parse(arguments: stagingArgs, environment: env).flatMap(\.staging))
    }
}
#endif
