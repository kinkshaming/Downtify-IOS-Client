#if DEBUG
import Foundation
import os

/// Debug-only harness for repeatable simulator tests (issue #48).
/// Active only when the process is launched with `-DowntifyHarness`. Release builds do not compile this file.
/// Harness console: route names, status codes and playback phases only. Never tokens, hosts or credentials.
enum DebugLog {
    static let logger = Logger(subsystem: "app.downtify.ios.harness", category: "console")
}

enum DebugHarnessError: Error, Equatable {
    case missingStagingServer
    case missingStagingCredentials
    case unsupportedScheme
    case hostNotAllowed
    case hostMismatch
    case mutationRefused
    case faultInjected
}

enum DebugFaultKind: String, Equatable {
    case timeout
    case http500
    case offline
    case unauthorized = "401"
}

/// Named routes that accept scripted faults: `-DowntifyFault <route>=<timeout|http500|offline|401>`.
enum DebugRoute: String, CaseIterable, Equatable {
    case serverInfo
    case auth
    case library
    case catalog
    case stream
}

struct DebugHarnessConfiguration: Equatable {
    enum Mode: Equatable {
        case fixture
        case staging
    }

    /// Credentials for staging mode. Never printed; `debugDescription` is redacted.
    struct StagingTarget: Equatable, CustomDebugStringConvertible {
        let server: String
        let host: String
        let username: String
        let password: String
        let allowsMutations: Bool

        var debugDescription: String { "StagingTarget(<redacted>)" }
    }

    let mode: Mode
    let staging: StagingTarget?
    let faults: [DebugRoute: DebugFaultKind]
    /// Number of generated fixture library tracks (`-DowntifyFixtureTracks <n>`, 2...12, default 2).
    var fixtureTrackCount: Int = 2
    /// Seeds two ready downloads for UI-only fixture playback when explicitly requested.
    var fixtureReadyDownloads = false
    /// Allows an opt-in catalog request to appear in the next library feed.
    var fixtureLibraryRequest = false
    /// Set when staging configuration is invalid. The harness then refuses all network traffic (fail closed).
    let configurationError: DebugHarnessError?
    /// `-DowntifyFixtureLyrics none|synced|plain|both|error`. `none` (default) keeps the lyrics capability off.
    var fixtureLyrics: FixtureLyrics = .none
    /// `-DowntifyFixtureSimilar <pages>[,failpage=<n>]`. Absent keeps the discover capability off.
    var fixtureSimilar: FixtureSimilar?

    enum FixtureLyrics: String, Equatable {
        case none, synced, plain, both, error
    }

    struct FixtureSimilar: Equatable {
        let pages: Int
        /// This page's first request fails once with a 500, then succeeds on retry.
        let failPage: Int?
    }

    static let flag = "-DowntifyHarness"

    /// Returns nil unless the harness flag is present.
    static func parse(arguments: [String], environment: [String: String]) -> DebugHarnessConfiguration? {
        guard arguments.contains(flag) else { return nil }
        let faults = parseFaults(arguments)
        let wantsStaging = value(after: "-DowntifyHarnessMode", in: arguments) == "staging"
        guard wantsStaging else {
            var fixture = DebugHarnessConfiguration(mode: .fixture, staging: nil, faults: faults, configurationError: nil)
            if let raw = value(after: "-DowntifyFixtureTracks", in: arguments), let count = Int(raw), (2...12).contains(count) {
                fixture.fixtureTrackCount = count
            }
            if let raw = value(after: "-DowntifyFixtureLyrics", in: arguments), let lyrics = FixtureLyrics(rawValue: raw) {
                fixture.fixtureLyrics = lyrics
            }
            fixture.fixtureSimilar = value(after: "-DowntifyFixtureSimilar", in: arguments).flatMap(parseFixtureSimilar)
            fixture.fixtureReadyDownloads = arguments.contains("-DowntifyFixtureReadyDownloads")
            fixture.fixtureLibraryRequest = arguments.contains("-DowntifyFixtureLibraryRequest")
            return fixture
        }
        do {
            let target = try stagingTarget(environment: environment)
            return DebugHarnessConfiguration(mode: .staging, staging: target, faults: faults, configurationError: nil)
        } catch let error as DebugHarnessError {
            return DebugHarnessConfiguration(mode: .staging, staging: nil, faults: faults, configurationError: error)
        } catch {
            return DebugHarnessConfiguration(mode: .staging, staging: nil, faults: faults, configurationError: .missingStagingServer)
        }
    }

    static func parseFixtureSimilar(_ raw: String) -> FixtureSimilar? {
        let parts = raw.split(separator: ",").map(String.init)
        guard let first = parts.first, let pages = Int(first), (1...DebugFixtureTransport.similarMaxPages).contains(pages) else { return nil }
        var failPage: Int?
        for part in parts.dropFirst() where part.hasPrefix("failpage=") {
            failPage = Int(part.dropFirst("failpage=".count)).flatMap { (1...pages).contains($0) ? $0 : nil }
        }
        return FixtureSimilar(pages: pages, failPage: failPage)
    }

    static func parseFaults(_ arguments: [String]) -> [DebugRoute: DebugFaultKind] {
        var result: [DebugRoute: DebugFaultKind] = [:]
        var index = 0
        while index < arguments.count {
            if arguments[index] == "-DowntifyFault", index + 1 < arguments.count {
                let parts = arguments[index + 1].split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count == 2, let route = DebugRoute(rawValue: parts[0]), let fault = DebugFaultKind(rawValue: parts[1]) {
                    result[route] = fault
                }
                index += 2
            } else {
                index += 1
            }
        }
        return result
    }

    static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    /// Staging credentials come only from the test runner environment. Fails closed.
    static func stagingTarget(environment: [String: String]) throws -> StagingTarget {
        guard let server = environment["DOWNTIFY_TEST_SERVER"], !server.isEmpty else { throw DebugHarnessError.missingStagingServer }
        guard let username = environment["DOWNTIFY_TEST_USER"], !username.isEmpty,
              let password = environment["DOWNTIFY_TEST_PASSWORD"], !password.isEmpty else {
            throw DebugHarnessError.missingStagingCredentials
        }
        guard let components = URLComponents(string: server), let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https", let rawHost = components.host, !rawHost.isEmpty else {
            throw DebugHarnessError.missingStagingServer
        }
        let host = normalizedHost(rawHost)
        guard isAllowedHost(host) else { throw DebugHarnessError.hostNotAllowed }
        if let declared = environment["DOWNTIFY_TEST_ALLOWED_HOST"], !declared.isEmpty {
            guard normalizedHost(declared) == host else { throw DebugHarnessError.hostMismatch }
        }
        let mutations = environment["DOWNTIFY_TEST_ALLOW_MUTATIONS"] == "1" && isLoopbackLike(host)
        return StagingTarget(server: server, host: host, username: username, password: password, allowsMutations: mutations)
    }

    static func normalizedHost(_ host: String) -> String {
        var value = host.lowercased()
        if value.hasPrefix("[") && value.hasSuffix("]") { value = String(value.dropFirst().dropLast()) }
        return value
    }

    static func isLoopbackLike(_ host: String) -> Bool {
        let value = normalizedHost(host)
        return value == "localhost" || value == "127.0.0.1" || value == "::1"
            || value.hasSuffix(".localhost") || value.hasSuffix(".test")
    }

    /// Loopback-like hosts, or any host whose name contains staging, dev or qa.
    static func isAllowedHost(_ host: String) -> Bool {
        let value = normalizedHost(host)
        return isLoopbackLike(value) || ["staging", "dev", "qa"].contains { value.contains($0) }
    }
}

/// In-memory session store so harness runs never touch the Keychain.
final class DebugMemorySessionStore: DeviceSessionStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var session: DeviceSession?

    func load() throws -> DeviceSession? { lock.withLock { session } }
    func save(_ session: DeviceSession) throws { lock.withLock { self.session = session } }
    func clear() throws { lock.withLock { session = nil } }
}

/// Serves a generated silent WAV (8 kHz, mono, 8-bit, 30 s) for every track. AVPlayer loads media itself,
/// so the stream must be a real file URL rather than an injected byte source.
struct DebugPlaybackStreamResolver: PlaybackStreamResolving {
    let directory: URL
    let faults: [DebugRoute: DebugFaultKind]

    static let sampleRate = 8_000
    static let seconds = 30

    func resolve(track: LibraryTrack, quality: PlaybackQuality, session: DeviceSession) async throws -> PlaybackStream {
        try stream()
    }

    func resolve(catalogSong: CatalogSong, quality: PlaybackQuality, session: DeviceSession) async throws -> PlaybackStream {
        try stream()
    }

    private func stream() throws -> PlaybackStream {
        if let fault = faults[.stream] {
            switch fault {
            case .timeout, .offline: throw PlaybackFailure.network
            case .http500: throw PlaybackFailure.invalidStream
            case .unauthorized: throw PlaybackFailure.unauthorized
            }
        }
        DebugLog.logger.info("stream resolved: generated silent WAV, 30 s")
        let url = try Self.silentWAV(in: directory)
        let length = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)??.int64Value ?? 0
        return PlaybackStream(contentType: "com.microsoft.waveform-audio", fileExtension: "wav", length: length,
                              quality: .original, availableQualities: [.original], fileURL: url) { range in
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(range.lowerBound))
            return handle.readData(ofLength: Int(range.upperBound - range.lowerBound + 1))
        }
    }

    static func silentWAV(in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("silence-\(seconds)s.wav")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let dataSize = sampleRate * seconds            // 8-bit mono: one byte per sample
        var wav = Data()
        func append(_ text: String) { wav.append(contentsOf: Array(text.utf8)) }
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { wav.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { wav.append(contentsOf: $0) } }
        append("RIFF"); append32(UInt32(36 + dataSize)); append("WAVE")
        append("fmt "); append32(16); append16(1); append16(1)
        append32(UInt32(sampleRate)); append32(UInt32(sampleRate)); append16(1); append16(8)
        append("data"); append32(UInt32(dataSize))
        wav.append(Data(repeating: 0x80, count: dataSize)) // 8-bit unsigned silence
        try wav.write(to: url, options: .atomic)
        return url
    }
}

/// Staging transport: GET/HEAD only unless mutations are allowed (loopback-like hosts with opt-in), one host only.
/// When configuration is invalid it refuses every request (fail closed).
final class DebugGuardedTransport: HTTPDataLoading, @unchecked Sendable {
    private let configuration: DebugHarnessConfiguration
    private let inner: any HTTPDataLoading

    init(configuration: DebugHarnessConfiguration, inner: any HTTPDataLoading = URLSession.shared) {
        self.configuration = configuration
        self.inner = inner
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try Self.authorize(request, configuration: configuration)
        return try await inner.data(for: request)
    }

    static func authorize(_ request: URLRequest, configuration: DebugHarnessConfiguration) throws {
        guard configuration.configurationError == nil, let target = configuration.staging else {
            throw DebugHarnessError.hostNotAllowed
        }
        guard let url = request.url, let host = url.host.map(DebugHarnessConfiguration.normalizedHost),
              host == target.host else {
            throw DebugHarnessError.hostMismatch
        }
        let method = (request.httpMethod ?? "GET").uppercased()
        // Password sign-in creates the device session the harness needs. It is the only POST allowed on read-only hosts.
        let isSignIn = method == "POST" && url.path == "/api/auth/token"
        if method != "GET" && method != "HEAD" && !isSignIn && !target.allowsMutations {
            throw DebugHarnessError.mutationRefused
        }
    }
}

/// Process-wide harness state. `current` is nil unless `-DowntifyHarness` is passed.
struct DebugHarness {
    static let current: DebugHarness? = {
        let processInfo = ProcessInfo.processInfo
        guard let configuration = DebugHarnessConfiguration.parse(arguments: processInfo.arguments,
                                                                  environment: processInfo.environment) else { return nil }
        return DebugHarness(configuration: configuration)
    }()

    let configuration: DebugHarnessConfiguration

    /// Isolation: harness-only Keychain service, UserDefaults suite, and on-disk directory.
    let keychainService = "app.downtify.ios.session.harness"
    let defaultsSuiteName = "app.downtify.ios.harness"

    var rootDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("downtify-harness", isDirectory: true)
    }
    var databaseURL: URL { rootDirectory.appendingPathComponent("library-harness.sqlite") }
    var cachesDirectory: URL { rootDirectory.appendingPathComponent("caches", isDirectory: true) }

    func makeTransport() -> any HTTPDataLoading {
        switch configuration.mode {
        case .fixture: return DebugFixtureTransport(faults: configuration.faults, trackCount: configuration.fixtureTrackCount,
                                                    lyrics: configuration.fixtureLyrics, similar: configuration.fixtureSimilar,
                                                    libraryRequest: configuration.fixtureLibraryRequest)
        case .staging: return DebugGuardedTransport(configuration: configuration)
        }
    }

    func makeSessionStore() -> any DeviceSessionStoring {
        let store = DebugMemorySessionStore()
        if configuration.mode == .fixture && configuration.fixtureReadyDownloads {
            try? store.save(Self.fixtureSession)
        }
        return store
    }

    private static let fixtureSession = DeviceSession(
        baseAddress: "https://fixture.test", serverID: "fixture-server", serverName: "Fixture",
        deviceID: "fixture-device", username: "fixture", role: "admin", token: "fixture-token",
        allowsInsecureHTTP: false)

    /// The debug resolver supplies silent audio; these files only make the manifest internally consistent.
    func seedReadyDownloads(in directory: URL) throws {
        guard configuration.mode == .fixture, configuration.fixtureReadyDownloads else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let records = try (1...2).map { number in
            let title = number == 1 ? "Fixture One" : "Fixture Two"
            let track = LibraryTrack(id: "fixture-track-\(number)", file: "track\(number).wav", title: title,
                                     artist: "Fixture Artist", artists: ["Fixture Artist"], album: "Fixture Album",
                                     albumArtist: "Fixture Artist", albumID: "fixture-album", artistID: "fixture-artist",
                                     trackNumber: number, year: "2026", duration: 30, codec: "wav", bitrate: 64000,
                                     sampleRate: 8000, channels: 1, size: 240044, added: Int64(number),
                                     hasCover: true, isExplicit: false, playlists: [])
            let id = UUID()
            let bytes = Data([0])
            try bytes.write(to: directory.appendingPathComponent(id.uuidString).appendingPathExtension("wav"))
            return OfflineDownload(id: id, track: track, scope: .init(Self.fixtureSession), requestedQuality: .original,
                                   state: .ready, media: OfflineMedia(length: Int64(bytes.count), mime: "audio/wav",
                                                                     type: "audio/wav", fileExtension: "wav",
                                                                     etag: nil, quality: .original),
                                   receivedBytes: Int64(bytes.count))
        }
        try JSONEncoder().encode(records).write(to: directory.appendingPathComponent("downloads.json"), options: .atomic)
    }

    func makeStreamResolver() -> any PlaybackStreamResolving {
        DebugPlaybackStreamResolver(directory: rootDirectory.appendingPathComponent("media", isDirectory: true),
                                    faults: configuration.faults)
    }

    /// Clears the harness suite so every launch starts from the same state. Never touches `UserDefaults.standard`.
    func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: defaultsSuiteName) ?? UserDefaults()
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        return UserDefaults(suiteName: defaultsSuiteName) ?? defaults
    }

    /// Fresh directories for each launch.
    func resetDirectories() throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: rootDirectory.path) { try manager.removeItem(at: rootDirectory) }
        try manager.createDirectory(at: cachesDirectory, withIntermediateDirectories: true)
    }
}
#endif
