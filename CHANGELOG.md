# Changelog

Historical record of Downtify iOS releases (version 0.1.2), newest first. Each build lists the user-facing notes shipped to TestFlight (from `release-notes/`), followed by the notable changes behind them. Issue numbers refer to the project issue tracker.

Builds 0.1.2-7 and earlier predate the curated release notes; their entries are reconstructed from git history.

## 0.1.2 (15) — 2026-11-26

Release notes:
- Tap a downloaded song to play it right away
- Add a catalog song to your library straight from Now Playing
- Shuffle your whole library with Shuffle Library
- On iPad, Now Playing opens beside your library in wide windows

Changes:
- Play a ready download by tapping its row; its separate actions menu keeps Play and device-management controls (#97)
- Request Add to Library for eligible catalog songs directly from Now Playing; show request status and enable library-dependent actions after library sync confirms the song (#100)
- Localize the new Now Playing library-request messages and add fixture coverage for Downloads row playback and library-request states (#97, #100)
- Tap Shuffle Library to play the full music library in random order from either theme. Now Playing shows Shuffle as on, and turning it off keeps the current song playing (#104)
- On iPad, open Now Playing beside the app in wide windows so you can browse while controlling playback; narrow windows use a sheet (#99)

Released from #106.

Contributors:
- Michael Moskie (@michaelmoskie)

## 0.1.2 (14) — 2026-11-25

Release notes:
- Choose a theme in Settings › Appearance: Original, Redesign, or one you import from Files
- Shape the sound with a six-band Equalizer and 20 presets in Settings › Playback
- Autoplay keeps the music going with similar songs when your queue ends
- Crossfade blends each song into the next, up to 12 seconds
- Home can show a Discover card, your artists, and songs downloaded to this device

Changes:
- Runtime themes: data-only JSON themes for colors, card shape and spacing, shelf layout, navigation, font and per-screen layouts, with bundled Original and Redesign themes and import/export from Files; Settings › Appearance splits into Color mode and Theme, and invalid files are rejected without changing the current theme (#89)
- Redesigned screen styles a theme can switch on per screen: drawer navigation with a profile menu, inline profile header, quick-access tiles, a combined library list with filter chips, album and playlist pages tinted from the artwork, a redesigned Now Playing and compact mini player, and chips for Search and Discover (#89)
- Six-band Equalizer (60 Hz–15 kHz, ±12 dB) with a draggable curve and 20 presets, applied in the existing audio tap together with loudness normalization; not applied over AirPlay. Every color follows the theme, with optional equalizer accent, handle and grid colors; fixes white handles that were invisible on the light-mode card (#90, ported from #88)
- Autoplay (on by default): when the last song in the queue starts, similar songs are fetched and appended so playback continues; skipped with repeat, podcasts, or when off, and library-only servers use library songs only (#91, ported from #88)
- Crossfade (0–12 s, off by default) with equal-power fades; consecutive tracks of one album stay gapless and very short songs are not overlapped (#91, ported from #88)
- Autoplay and Crossfade controls follow the theme; Now Playing › Up Next says when Autoplay will continue, and the Play Queue gets an Autoplay card with a switch (#91)
- Covers only a few pixels wide fall back to the artwork placeholder (#91, ported from #88)
- Home sections from #88: a Discover card that opens For You, a Your artists shelf, and a Downloaded to this device card with a play button; themes can order or hide them with new optional homeSections keys, and older theme files show all three (#92)
- Real-audio tests: tones rendered through the playback audio tap check equalizer boosts, cuts, bypass and live changes; the real playback engine is checked for crossfade overlap and release; end-to-end tests cover crossfade and Autoplay with the real engine and controller (#91)
- Theme authoring guide (docs/RUNTIME_THEMES.md) with example themes and a test that keeps them valid; theme tests for equalizer colors and Home sections (#90, #92, #93)
- Turkish translations for the Equalizer, Autoplay, Crossfade and Home text; theme settings text and other languages show English for now (#90, #91, #92)

Released from #95.

Contributors:
- Ahmet Yunus BAYRAM (@AhmetYunusBAYRAM), first contribution: the Equalizer, Autoplay, Crossfade and Home sections come from their redesign in #88
- Michael Moskie (@michaelmoskie)

## 0.1.2 (13) — 2026-11-24

Release notes:
- Translate lyrics into your device's language on iOS 18 and later
- Dragging songs in Up Next now moves them smoothly and drops them exactly where you let go
- More of the app is translated in every supported language

Changes:
- Translate lyrics into the device language on iOS 18 and later, with a toggle back to the original; the choice is remembered, and iOS 17 is unchanged (#74)
- Localize the lyrics translation strings in all locales (#74)
- Fix queue reorder drop placement: drag location and row frames were measured in different coordinate spaces, so drops resolved to the first slot (#84)
- The dragged queue row lifts and follows the finger while other rows slide aside to open a gap; the drop commits exactly what is shown, and Reduce Motion drops the spring (#84)
- Clear queue drag state when the gesture is cancelled or the queue changes mid-drag, so scrolling no longer stays locked (#84)
- Add a close button to the network debug overlay; add unit tests for lyrics translation and queue drag placement, and a drag-down queue UI test in the check script (#74, #84)

## 0.1.2 (12) — 2026-11-21

Release notes:
- Add songs to the front of your queue with Play next, and drag upcoming songs to reorder them
- Tap a synced lyric line in Now Playing to jump to it, and switch between synced and plain lyrics
- Similar keeps loading more songs as you scroll
- Rows near the bottom of screens no longer hide behind the player
- More of the app is translated in every supported language

Changes:
- Add Play next to Library and catalog song menus, inserting songs at the front of the upcoming queue (#67)
- Reorder upcoming queue songs with left-side drag handles and an insertion indicator; VoiceOver gets Move up / Move down actions (#68)
- Localize Play next and queue reorder strings in all locales (#67, #68)
- Keep bottom rows clear of the playback dock, including at accessibility text sizes, on More, About, admin Trash, podcast lists and catalog artist/album pages (#45)
- Extend the debug harness with configurable fixture tracks and a queue order probe; add simulator UI tests, docs and check-script scenarios for Play next and queue reorder
- Tap a timed lyric line in Now Playing to seek to it, switch between synced and static lyrics when both exist, and reset a track's saved lyric timing in one tap; lyrics requests now use the app transport so debug fixtures and staging guards apply (#71)
- Similar results load more as you near the end of the list, seeded from unused recent results, with duplicate and repeated-seed protection, retry on failure and a visible loading and end state (#72)
- Localize the lyric seek, display mode, reset and Similar load-more strings in all locales (#71, #72)
- Extend the debug harness with fixture lyrics and fixture Similar pages (real song titles, one-shot page failure); add simulator UI tests and unit tests for lyric seek, display modes, timing reset and Similar load-more, and include them in the check script (#71, #72)

## 0.1.2 (11) — 2026-11-21

Release notes:
- Now Playing has clear Like, Up Next and Add to Playlist buttons
- Tap the artist or album in Now Playing to open the full artist or album page, including catalog music you don't own yet
- Album artwork now shows on the lock screen and in Control Center
- Catalog artists in Search show their photos
- More of the app is translated in every supported language

Changes:
- Open artist and album pages from Now Playing (#43)
- Make Like, Up Next and Add to Playlist discoverable in Now Playing (#57)
- Show album artwork on the lock screen and in Control Center (#44)
- Show artwork in Catalog Artists search results (#47)
- Localize string-literal ternaries outside Now Playing and add a guard against new ones (ported from #59)
- Localize Now Playing navigation hints flagged by the ternary guard

## 0.1.2 (10) — 2026-11-20

Release notes:
- Songs you already own now show as In Library, and adding them again no longer creates duplicate versions
- The currently playing song is highlighted in song and album lists
- The network debug overlay is now translated in every supported language

Changes:
- Show owned songs as In Library and stop adding duplicate versions (#27)
- Highlight the currently playing song in song and album lists, with a UI regression test (#46)
- Fix localization parity for the network debug overlay
- Add a debug-only harness for repeatable simulator tests (#48)
- Add Add to Library request capture and server trace to issue 27 findings (docs)

## 0.1.2 (9) — 2026-11-17

Release notes:
- Add to Library and Add to Device now clearly distinguish server downloads from offline copies on your phone
- See storage usage and clear app data while keeping your sign-in
- Playback can recover from temporary stream failures and keep the current song's quality when the network changes
- The network debug overlay shows queue and cache readiness and can be resized and moved
- Network diagnostics and the concurrent request limit are now in Settings

Changes:
- Add to Library / Add to Device wording and actions across catalog search, Discover, artist albums, podcasts, Downloads and library menus; localized (#25)
- Show In Library on library-matched catalog rows and on albums already fully in the library, including track-count lookup for owned-looking albums; rows update after Add to Library (#25)
- Offer Add to Device on catalog rows that are in the library (#25)
- Add a Storage section in More with storage usage by category and Clear App Cache and Saved Data, keeping the login (#26)
- Improve playback recovery and network diagnostics; keep bounded skipping for unplayable catalog tracks
- Translate the playback quality setting

## 0.1.2 (8) — 2026-11-16

Release notes:
- Dismiss the keyboard in Search and Finder by tapping outside the field, pressing Done, or scrolling
- Playback on slow or unstable connections now builds a short startup buffer sized to your measured server speed
- Background preloading no longer crowds out album artwork and playback requests: concurrent requests default to 4 and can be changed in More > Diagnostics
- Network debug overlay now shows the effective audio delivery rate
- Likes and playlist favorites made while offline are queued and sent when the connection returns, with pending status in More
- Playlist editing: duplicate-aware add and remove controls, conflict recovery, and localized feedback

Changes:
- Dismiss keyboard from search fields (#17)
- Adapt playback buffering to server throughput
- Add curated release notes and bump build number

## 0.1.2 (7) — 2026-11-13 (TestFlight)

- Finish playlist editing integration (#14)
- Prepare TestFlight 0.1.2 build 7

## 0.1.2 (6) — 2026-11-12

- Prioritize playback and improve album browsing (#11)
- Resolve YouTube Music catalog results by song ID (#10)
- Buffer/Queue (#9)
- Preload the current song and five upcoming songs for offline playback (#8)
- Add TestFlight beta installation instructions (#7)
- Keep final list actions clear of the playback dock (#6)
- Make the About page public (#5)
- Integrate catalog discovery, library search and playlist editing (#4)

## Initial — 2026-11-06

- Initial clean repository snapshot
- Correct About screen license information
- Update About page project links (#1)
