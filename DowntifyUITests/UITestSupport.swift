import XCTest

/// Mirror of the app's redacted `debug.state` snapshot. Only these keys exist by design.
struct HarnessState: Decodable, Equatable {
    let playbackPhase: String
    let queueCount: Int
    let currentTrackID: String?
    let position: Double?
    let network: String
    let libraryTrackCount: Int
    let lastErrorCode: String?
    let artworkLoaded: Bool
    let playerVisible: Bool
    let sessionActive: Bool
    let queueTrackIDs: [String]
}

enum DowntifyUITestSupport {
    static let stagingKeys = ["DOWNTIFY_TEST_SERVER", "DOWNTIFY_TEST_USER", "DOWNTIFY_TEST_PASSWORD",
                              "DOWNTIFY_TEST_ALLOWED_HOST", "DOWNTIFY_TEST_ALLOW_MUTATIONS"]

    /// Launches the app in harness mode. Staging values come from the test runner environment only.
    static func launch(faults: [String] = [], staging: Bool = false, fixtureTracks: Int? = nil,
                       fixtureLyrics: String? = nil, fixtureSimilar: String? = nil,
                       fixtureReadyDownloads: Bool = false, fixtureLibraryRequest: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-DowntifyHarness"]
        if staging { arguments += ["-DowntifyHarnessMode", "staging"] }
        if let fixtureTracks { arguments += ["-DowntifyFixtureTracks", String(fixtureTracks)] }
        if fixtureReadyDownloads { arguments.append("-DowntifyFixtureReadyDownloads") }
        if fixtureLibraryRequest { arguments.append("-DowntifyFixtureLibraryRequest") }
        if let fixtureLyrics { arguments += ["-DowntifyFixtureLyrics", fixtureLyrics] }
        if let fixtureSimilar { arguments += ["-DowntifyFixtureSimilar", fixtureSimilar] }
        for fault in faults { arguments += ["-DowntifyFault", fault] }
        app.launchArguments = arguments
        if staging {
            var environment: [String: String] = [:]
            let runner = ProcessInfo.processInfo.environment
            for key in stagingKeys { if let value = runner[key] { environment[key] = value } }
            app.launchEnvironment = environment
        }
        app.launch()
        return app
    }

    /// Current redacted snapshot, or nil if the probe is missing or undecodable.
    static func state(of app: XCUIApplication) -> HarnessState? {
        let element = app.descendants(matching: .any)["debug.state"].firstMatch
        guard element.exists, let value = element.value as? String, let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(HarnessState.self, from: data)
    }

    /// Polls the snapshot until `predicate` holds or the timeout passes.
    static func waitForState(_ app: XCUIApplication, timeout: TimeInterval,
                             where predicate: (HarnessState) -> Bool) -> HarnessState? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let state = state(of: app), predicate(state) { return state }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return nil
    }

    /// Opens the Library tab and switches to the Songs category, where track rows are listed.
    static func openLibrarySongs(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        element(app, "tab.library").tap()
        let songs = app.buttons["Songs"].firstMatch
        XCTAssertTrue(songs.waitForExistence(timeout: 15), "Songs category not visible", file: file, line: line)
        songs.tap()
    }

    static func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
