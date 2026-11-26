import XCTest

final class DebugHarnessUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRedesignThemeNavigation() throws {
        let app = DowntifyUITestSupport.launch()
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) { $0.sessionActive })
        let drawer = app.buttons["Open navigation menu"].firstMatch
        let account = app.buttons["Account options"].firstMatch
        if drawer.waitForExistence(timeout: 3) {
            drawer.tap()
        } else {
            XCTAssertTrue(account.waitForExistence(timeout: 10))
            account.tap()
        }
        let settings = app.buttons["Settings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        let themePicker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Theme")).firstMatch
        XCTAssertTrue(themePicker.waitForExistence(timeout: 10))
        themePicker.tap()
        let redesign = app.buttons["Redesign"].firstMatch
        XCTAssertTrue(redesign.waitForExistence(timeout: 10))
        redesign.tap()
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(drawer.waitForExistence(timeout: 10))
        drawer.tap()
        XCTAssertTrue(app.buttons["Downloads"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Downloads"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Downloads"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Home"].firstMatch.tap()
        let searchTab = app.buttons["Search"].firstMatch
        XCTAssertTrue(searchTab.waitForExistence(timeout: 10))
        searchTab.tap()
        XCTAssertTrue(app.staticTexts["Browse all"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Charts"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Charts"].firstMatch.tap()
        let charts = app.buttons["Charts"].firstMatch
        XCTAssertTrue(charts.waitForExistence(timeout: 10))
        XCTAssertTrue(charts.isSelected)
        app.buttons["Home"].firstMatch.tap()
        let libraryTab = app.buttons["Your Library"].firstMatch
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 10))
        libraryTab.tap()
        let album = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Fixture Album")).firstMatch
        XCTAssertTrue(album.waitForExistence(timeout: 10))
        album.tap()
        let play = app.buttons["Play"].firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        play.tap()
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) { $0.playerVisible })
        let dock = DowntifyUITestSupport.element(app, "player.dock")
        XCTAssertTrue(dock.waitForExistence(timeout: 10))
        dock.tap()
        XCTAssertTrue(DowntifyUITestSupport.element(app, "player.full").waitForExistence(timeout: 10))
        app.buttons["Done"].firstMatch.tap()
        app.buttons["Home"].firstMatch.tap()
        XCTAssertTrue(drawer.waitForExistence(timeout: 10))
        drawer.tap()
        app.buttons["Settings"].firstMatch.tap()
        let restore = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Theme")).firstMatch
        XCTAssertTrue(restore.waitForExistence(timeout: 10))
        restore.tap()
        let original = app.buttons["Original"].firstMatch
        XCTAssertTrue(original.waitForExistence(timeout: 10))
        original.tap()
        app.buttons["Done"].firstMatch.tap()
    }

    /// Scenario 1: fixture end-to-end. Library loads, playback starts, player visible with artwork.
    func testFixtureLibraryPlaybackEndToEnd() throws {
        let app = DowntifyUITestSupport.launch()
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) {
            $0.sessionActive && $0.libraryTrackCount == 2
        }, "library did not load in fixture mode; last state: \(String(describing: DowntifyUITestSupport.state(of: app)))")

        DowntifyUITestSupport.openLibrarySongs(app)
        let row = DowntifyUITestSupport.element(app, "library.trackRow.fixture-track-1")
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()

        let playing = DowntifyUITestSupport.waitForState(app, timeout: 30) { $0.playbackPhase == "playing" }
        XCTAssertNotNil(playing, "playback never reached playing")
        XCTAssertEqual(playing?.currentTrackID, "fixture-track-1")
        XCTAssertEqual(playing?.playerVisible, true)
        XCTAssertTrue(DowntifyUITestSupport.element(app, "player.dock").waitForExistence(timeout: 10))
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 15) { $0.artworkLoaded })
    }

    /// Issue 97: ready download rows play independently from their actions menus.
    func testReadyDownloadRowsPlayAndKeepMenuIndependent() throws {
        let app = DowntifyUITestSupport.launch(fixtureReadyDownloads: true)
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) {
            $0.sessionActive && $0.libraryTrackCount == 2
        })

        let downloaded = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Downloaded to this device")).firstMatch
        XCTAssertTrue(downloaded.waitForExistence(timeout: 15))
        downloaded.tap()

        let first = app.buttons["downloads.play.fixture-track-1"]
        let second = app.buttons["downloads.play.fixture-track-2"]
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        XCTAssertTrue(second.waitForExistence(timeout: 15))
        XCTAssertTrue(first.label.contains("Fixture One"))
        XCTAssertTrue(second.label.contains("Fixture Two"))

        first.tap()
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) {
            $0.currentTrackID == "fixture-track-1" && $0.playbackPhase == "playing" &&
            $0.queueTrackIDs == ["fixture-track-1"]
        })
        second.tap()
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) {
            $0.currentTrackID == "fixture-track-2" && $0.playbackPhase == "playing" &&
            $0.queueTrackIDs == ["fixture-track-2"]
        })

        let firstActions = app.buttons["downloads.actions.fixture-track-1"]
        XCTAssertTrue(firstActions.waitForExistence(timeout: 10))
        firstActions.tap()
        let play = app.buttons["Play"].firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        let whileMenuOpen = DowntifyUITestSupport.state(of: app)
        XCTAssertEqual(whileMenuOpen?.currentTrackID, "fixture-track-2")
        XCTAssertEqual(whileMenuOpen?.queueTrackIDs, ["fixture-track-2"])
        play.tap()
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) {
            $0.currentTrackID == "fixture-track-1" && $0.playbackPhase == "playing" &&
            $0.queueTrackIDs == ["fixture-track-1"]
        })
    }

    /// Scenario 2: controlled failure. A stream fault must surface as a failed phase with an error code.
    func testInjectedStreamFaultReportsFailure() throws {
        let app = DowntifyUITestSupport.launch(faults: ["stream=http500"])
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) {
            $0.sessionActive && $0.libraryTrackCount == 2
        })

        DowntifyUITestSupport.openLibrarySongs(app)
        DowntifyUITestSupport.element(app, "library.trackRow.fixture-track-1").tap()

        let failed = DowntifyUITestSupport.waitForState(app, timeout: 30) { $0.playbackPhase == "failed" }
        XCTAssertNotNil(failed, "stream fault did not produce a failed phase")
        XCTAssertNotNil(failed?.lastErrorCode)
    }

    /// Issue #46: the current song row is highlighted, moves to a newly played song, and survives pause.
    func testCurrentSongHighlightFollowsQueue() throws {
        let app = DowntifyUITestSupport.launch()
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) {
            $0.sessionActive && $0.libraryTrackCount == 2
        })
        DowntifyUITestSupport.openLibrarySongs(app)
        let first = DowntifyUITestSupport.element(app, "library.trackRow.fixture-track-1")
        let second = DowntifyUITestSupport.element(app, "library.trackRow.fixture-track-2")
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        XCTAssertFalse(value(of: first).contains("Now playing"))
        first.tap()

        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) { $0.playbackPhase == "playing" })
        XCTAssertTrue(waitForValue(of: first, toContain: "Now playing"), "first row value: \(value(of: first))")
        XCTAssertTrue(first.isSelected)
        XCTAssertFalse(second.isSelected)

        second.tap()
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) {
            $0.currentTrackID == "fixture-track-2" && $0.playbackPhase == "playing"
        }, "after selecting the second song: \(String(describing: DowntifyUITestSupport.state(of: app)))")
        XCTAssertTrue(waitForValue(of: second, toContain: "Now playing"), "second row value: \(value(of: second))")
        XCTAssertTrue(second.isSelected)
        XCTAssertFalse(first.isSelected)
        XCTAssertFalse(value(of: first).contains("Now playing"))

        let pause = app.buttons["Pause"].firstMatch
        XCTAssertTrue(pause.waitForExistence(timeout: 10))
        pause.tap()
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 15) { $0.playbackPhase == "paused" })
        XCTAssertTrue(waitForValue(of: second, toContain: "Paused"), "paused row value: \(value(of: second))")
        XCTAssertTrue(second.isSelected, "A paused song stays highlighted")
    }

    /// Issue 57: Like, Add to Playlist, Queue and Up Next are visible and work from Now Playing.
    func testNowPlayingActionsAreDiscoverable() throws {
        let app = DowntifyUITestSupport.launch()
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) {
            $0.sessionActive && $0.libraryTrackCount == 2
        })
        DowntifyUITestSupport.openLibrarySongs(app)
        // Songs default to newest first, so Fixture Two plays first and Fixture One is up next.
        let newest = DowntifyUITestSupport.element(app, "library.trackRow.fixture-track-2")
        XCTAssertTrue(newest.waitForExistence(timeout: 15))
        newest.tap()
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) { $0.playbackPhase == "playing" })

        let dock = DowntifyUITestSupport.element(app, "player.dock")
        XCTAssertTrue(dock.waitForExistence(timeout: 10))
        dock.tap()

        let upNext = DowntifyUITestSupport.element(app, "player.upNext")
        XCTAssertTrue(upNext.waitForExistence(timeout: 10))
        XCTAssertTrue(upNext.label.contains("Fixture One"), "up next label: \(upNext.label)")

        let like = app.buttons["player.like"]
        let addToPlaylist = app.buttons["player.addToPlaylist"]
        let queue = app.buttons["player.queue"]
        XCTAssertTrue(like.waitForExistence(timeout: 10))
        XCTAssertTrue(addToPlaylist.exists)
        XCTAssertTrue(queue.exists)
        XCTAssertTrue(waitForEnabled(like), "Like never enabled")
        XCTAssertEqual(like.label, "Like Fixture Two")
        like.tap()
        XCTAssertTrue(waitForLabel(of: like, toBe: "Unlike Fixture Two"), "like label: \(like.label)")

        XCTAssertTrue(waitForEnabled(addToPlaylist), "Add to Playlist never enabled")
        addToPlaylist.tap()
        let mix = app.buttons["addToPlaylist.Fixture Mix"]
        XCTAssertTrue(mix.waitForExistence(timeout: 10))
        mix.tap()
        // The picker closes only after the server confirms the add; the banner itself is transient.
        XCTAssertTrue(mix.waitForNonExistence(timeout: 15), "picker did not close after adding")

        // Adding the same song again shows it is already there and asks before creating a duplicate.
        XCTAssertTrue(waitForEnabled(addToPlaylist))
        addToPlaylist.tap()
        XCTAssertTrue(mix.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForValue(of: mix, toContain: "Already in this playlist"), "value: \(value(of: mix))")
        mix.tap()
        XCTAssertTrue(app.buttons["Add Again"].waitForExistence(timeout: 10))
        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["Cancel"].firstMatch.tap()

        queue.tap()
        XCTAssertTrue(app.navigationBars["Play Queue"].waitForExistence(timeout: 10))
        app.navigationBars["Play Queue"].buttons["Done"].tap()

        app.buttons["Next track"].firstMatch.tap()
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) { $0.currentTrackID == "fixture-track-1" })
        XCTAssertTrue(waitForLabel(of: upNext, toBe: "Nothing up next"), "up next label: \(upNext.label)")
        XCTAssertFalse(app.buttons["Next track"].firstMatch.isEnabled)
    }

    private func waitForEnabled(_ element: XCUIElement, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.exists && element.isEnabled { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return false
    }

    private func waitForLabel(of element: XCUIElement, toBe text: String, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.exists && element.label == text { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return false
    }

    private func value(of element: XCUIElement) -> String { element.value as? String ?? "" }

    private func waitForValue(of element: XCUIElement, toContain text: String, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if value(of: element).contains(text) { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return false
    }

    /// Scenario 4 (#67): Play next inserts right after the current song; Add to queue still appends.
    func testPlayNextAndAddToQueueFromLibrarySongMenu() throws {
        let app = DowntifyUITestSupport.launch(fixtureTracks: 4)
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) {
            $0.sessionActive && $0.libraryTrackCount == 4
        })
        DowntifyUITestSupport.openLibrarySongs(app)
        // Songs list newest first, so tapping Fixture Four queues [4, 3, 2, 1] with Four current.
        DowntifyUITestSupport.element(app, "library.trackRow.fixture-track-4").tap()
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) { $0.playbackPhase == "playing" })

        DowntifyUITestSupport.element(app, "library.menu.fixture-track-1").tap()
        let playNext = DowntifyUITestSupport.element(app, "library.menu.playNext.fixture-track-1")
        XCTAssertTrue(playNext.waitForExistence(timeout: 10), "Play next missing from the song menu")
        playNext.tap()
        let afterNext = DowntifyUITestSupport.waitForState(app, timeout: 10) { $0.queueCount == 5 }
        XCTAssertEqual(afterNext?.queueTrackIDs,
                       ["fixture-track-4", "fixture-track-1", "fixture-track-3", "fixture-track-2", "fixture-track-1"])
        XCTAssertEqual(afterNext?.currentTrackID, "fixture-track-4")
        XCTAssertEqual(afterNext?.playbackPhase, "playing", "Play next must not interrupt playback")

        DowntifyUITestSupport.element(app, "library.menu.fixture-track-2").tap()
        let addToQueue = DowntifyUITestSupport.element(app, "library.menu.addToQueue.fixture-track-2")
        XCTAssertTrue(addToQueue.waitForExistence(timeout: 10))
        addToQueue.tap()
        let afterAdd = DowntifyUITestSupport.waitForState(app, timeout: 10) { $0.queueCount == 6 }
        XCTAssertEqual(afterAdd?.queueTrackIDs.last, "fixture-track-2")
        XCTAssertEqual(afterAdd?.currentTrackID, "fixture-track-4")
    }

    /// Scenario 5 (#68): drag a queue handle to reorder; the current song and playback are untouched.
    func testQueueHandleDragReordersUpcomingSongs() throws {
        let app = DowntifyUITestSupport.launch(fixtureTracks: 4)
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) {
            $0.sessionActive && $0.libraryTrackCount == 4
        })
        DowntifyUITestSupport.openLibrarySongs(app)
        // Songs list newest first, so tapping Fixture Four queues [4, 3, 2, 1] with Four current.
        DowntifyUITestSupport.element(app, "library.trackRow.fixture-track-4").tap()
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) { $0.playbackPhase == "playing" })

        DowntifyUITestSupport.element(app, "player.dock").tap()
        let queueButton = app.buttons["player.queue"]
        if !queueButton.waitForExistence(timeout: 10) { app.swipeUp() }
        XCTAssertTrue(queueButton.waitForExistence(timeout: 10), "Queue button missing in the player")
        queueButton.tap()

        let lastHandle = DowntifyUITestSupport.element(app, "queue.handle.2")
        let firstRow = DowntifyUITestSupport.element(app, "queue.handle.0")
        XCTAssertTrue(lastHandle.waitForExistence(timeout: 10), "Drag handle missing")
        XCTAssertEqual(lastHandle.label, "Reorder Fixture One")
        // Drop on the top edge of the first upcoming row, which proposes the slot above it.
        let dropPoint = firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
        lastHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.0, thenDragTo: dropPoint)

        let reordered = DowntifyUITestSupport.waitForState(app, timeout: 10) {
            $0.queueTrackIDs == ["fixture-track-4", "fixture-track-1", "fixture-track-3", "fixture-track-2"]
        }
        XCTAssertNotNil(reordered, "queue order after drag: \(String(describing: DowntifyUITestSupport.state(of: app)?.queueTrackIDs))")
        XCTAssertEqual(reordered?.currentTrackID, "fixture-track-4")
        XCTAssertEqual(reordered?.playbackPhase, "playing", "Reordering must not interrupt playback")
    }

    /// Scenario 5b (#84): drag a queue handle downward; rows reflow live and the drop lands where the gap was.
    func testQueueHandleDragDownReordersUpcomingSongs() throws {
        let app = DowntifyUITestSupport.launch(fixtureTracks: 4)
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) {
            $0.sessionActive && $0.libraryTrackCount == 4
        })
        DowntifyUITestSupport.openLibrarySongs(app)
        // Songs list newest first, so tapping Fixture Four queues [4, 3, 2, 1] with Four current.
        DowntifyUITestSupport.element(app, "library.trackRow.fixture-track-4").tap()
        XCTAssertNotNil(DowntifyUITestSupport.waitForState(app, timeout: 30) { $0.playbackPhase == "playing" })

        DowntifyUITestSupport.element(app, "player.dock").tap()
        let queueButton = app.buttons["player.queue"]
        if !queueButton.waitForExistence(timeout: 10) { app.swipeUp() }
        XCTAssertTrue(queueButton.waitForExistence(timeout: 10), "Queue button missing in the player")
        queueButton.tap()

        let firstHandle = DowntifyUITestSupport.element(app, "queue.handle.0")
        let lastHandle = DowntifyUITestSupport.element(app, "queue.handle.2")
        XCTAssertTrue(firstHandle.waitForExistence(timeout: 10), "Drag handle missing")
        XCTAssertEqual(firstHandle.label, "Reorder Fixture Three")
        // Drop below the middle of the last upcoming row, which places the song last.
        let dropPoint = lastHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1))
        // Hold before releasing so the live reflow settles (and is visible in recordings) before the drop.
        firstHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 1.0, thenDragTo: dropPoint, withVelocity: .slow, thenHoldForDuration: 1.0)

        let reordered = DowntifyUITestSupport.waitForState(app, timeout: 10) {
            $0.queueTrackIDs == ["fixture-track-4", "fixture-track-2", "fixture-track-1", "fixture-track-3"]
        }
        XCTAssertNotNil(reordered, "queue order after drag: \(String(describing: DowntifyUITestSupport.state(of: app)?.queueTrackIDs))")
        XCTAssertEqual(reordered?.currentTrackID, "fixture-track-4")
        XCTAssertEqual(reordered?.playbackPhase, "playing", "Reordering must not interrupt playback")
    }

    /// Scenario 3 (optional): real staging server, read-only. Skipped unless the runner provides a server.
    func testRealStagingLibraryLoadsReadOnly() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["DOWNTIFY_TEST_SERVER"] == nil,
                      "No staging server configured for the test runner; scenario not run.")
        let app = DowntifyUITestSupport.launch(staging: true)
        let state = DowntifyUITestSupport.waitForState(app, timeout: 60) { $0.sessionActive }
        XCTAssertNotNil(state, "staging session did not become active")
        XCTAssertNotEqual(state?.playbackPhase, "failed")
    }
}
