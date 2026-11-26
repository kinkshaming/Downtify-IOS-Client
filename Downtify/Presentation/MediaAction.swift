import Foundation
import SwiftUI

enum MediaDestination { case library, device }

enum DeviceUnavailableReason: Equatable { case notInLibrary }

/// Derived from the library track and offline record; never stored.
enum DeviceSaveState: Equatable {
    case unavailable(DeviceUnavailableReason)
    case notSaved
    case pending
    case transferring(fraction: Double?)
    case saved
    case failed(OfflineDownloadFailure)

    init(track: LibraryTrack?, record: OfflineDownload?) {
        guard track != nil else { self = .unavailable(.notInLibrary); return }
        guard let record else { self = .notSaved; return }
        switch record.state {
        case .preparing, .paused:
            self = .pending
        case .transferring:
            if let length = record.media?.length, length > 0 {
                let fraction = Double(record.receivedBytes) / Double(length)
                self = .transferring(fraction: min(max(fraction, 0), 1))
            } else {
                self = .transferring(fraction: nil)
            }
        case .ready:
            self = .saved
        case .cancelled:
            self = .notSaved
        case .failed(let failure):
            self = .failed(failure)
        }
    }
}

struct MediaActionPresentation: Equatable {
    let title: String
    let systemImage: String?
    let accessibilityLabel: String
    let isEnabled: Bool
    let explanation: String?

    static func library(_ state: ServerDownloadActionState, itemTitle t: String) -> Self {
        switch state {
        case .idle:
            return Self(title: String(localized: "Add to Library"), systemImage: "plus.circle",
                        accessibilityLabel: String(localized: "Add \(t) to Library"),
                        isEnabled: true, explanation: nil)
        case .submitting:
            return Self(title: String(localized: "Adding to Library"), systemImage: nil,
                        accessibilityLabel: String(localized: "Adding \(t) to Library"),
                        isEnabled: false, explanation: nil)
        case .queued:
            return Self(title: String(localized: "Queued for Library"), systemImage: "clock.arrow.circlepath",
                        accessibilityLabel: String(localized: "\(t) is queued for your Library"),
                        isEnabled: false, explanation: nil)
        case .accepted:
            return Self(title: String(localized: "In Library"), systemImage: "checkmark.circle.fill",
                        accessibilityLabel: String(localized: "\(t) is in your Library"),
                        isEnabled: false, explanation: nil)
        case .partiallyAccepted(let successful, let expected):
            return Self(title: String(localized: "\(successful) of \(expected) added to Library"),
                        systemImage: "checkmark.circle",
                        accessibilityLabel: String(localized: "\(successful) of \(expected) added to Library for \(t)"),
                        isEnabled: false, explanation: nil)
        case .outcomeUnknown:
            return Self(title: String(localized: "Library status unknown"), systemImage: "questionmark.circle",
                        accessibilityLabel: String(localized: "Library status unknown for \(t)"),
                        isEnabled: false, explanation: nil)
        case .failed(let message):
            return Self(title: String(localized: "Retry Add to Library"), systemImage: "exclamationmark.arrow.circlepath",
                        accessibilityLabel: String(localized: "Retry adding \(t) to Library"),
                        isEnabled: true, explanation: message)
        }
    }

    static func device(_ state: DeviceSaveState, itemTitle t: String) -> Self {
        switch state {
        case .unavailable(.notInLibrary):
            return Self(title: String(localized: "Add to Device"), systemImage: "iphone.slash",
                        accessibilityLabel: String(localized: "\(t) must be in your Library before it can be added to this device"),
                        isEnabled: false, explanation: String(localized: "Add to Library first"))
        case .notSaved:
            return Self(title: String(localized: "Add to Device"), systemImage: "arrow.down.to.line.circle",
                        accessibilityLabel: String(localized: "Add \(t) to this device"),
                        isEnabled: true, explanation: nil)
        case .pending:
            return Self(title: String(localized: "Waiting to Add to Device"), systemImage: nil,
                        accessibilityLabel: String(localized: "Waiting to add \(t) to this device"),
                        isEnabled: false, explanation: nil)
        case .transferring:
            return Self(title: String(localized: "Adding to Device"), systemImage: nil,
                        accessibilityLabel: String(localized: "Adding \(t) to this device"),
                        isEnabled: false, explanation: nil)
        case .saved:
            return Self(title: String(localized: "On Device"), systemImage: "arrow.down.to.line.circle.fill",
                        accessibilityLabel: String(localized: "\(t) is on this device"),
                        isEnabled: false, explanation: nil)
        case .failed:
            return Self(title: String(localized: "Retry Add to Device"), systemImage: "exclamationmark.triangle",
                        accessibilityLabel: String(localized: "Retry adding \(t) to this device"),
                        isEnabled: true, explanation: nil)
        }
    }
}

/// Request state for the current player item. Server acceptance is not library membership.
enum NowPlayingLibraryPresentation {
    static func make(song: CatalogSong?, isInLibrary: Bool, externalCatalogAvailable: Bool,
                     hasSession: Bool, state: ServerDownloadActionState) -> MediaActionPresentation {
        let title = song?.title ?? String(localized: "Unknown title")
        if isInLibrary {
            return .library(.accepted, itemTitle: title)
        }

        let unavailableReason: String?
        if song == nil || song?.source == "library" {
            unavailableReason = String(localized: "This song cannot be requested from the catalog.")
        } else if song?.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            unavailableReason = String(localized: "Provider information is unavailable for this song.")
        } else if !hasSession {
            unavailableReason = String(localized: "Reconnect to add to your Library.")
        } else if !externalCatalogAvailable {
            unavailableReason = String(localized: "Catalog requests are unavailable on this server.")
        } else {
            unavailableReason = nil
        }

        if let unavailableReason {
            return MediaActionPresentation(title: String(localized: "Add to Library"), systemImage: "plus.circle",
                                           accessibilityLabel: String(localized: "Add \(title) to Library"),
                                           isEnabled: false, explanation: unavailableReason)
        }

        switch state {
        case .accepted:
            return MediaActionPresentation(title: String(localized: "Requested for Library"), systemImage: "clock.arrow.circlepath",
                                           accessibilityLabel: String(localized: "\(title) was requested for your Library"),
                                           isEnabled: false,
                                           explanation: String(localized: "The song will appear after library sync."))
        case .partiallyAccepted:
            return MediaActionPresentation(title: String(localized: "Library status unknown"), systemImage: "questionmark.circle",
                                           accessibilityLabel: String(localized: "Library status unknown for \(title)"),
                                           isEnabled: false,
                                           explanation: String(localized: "Check Library requests for the current status."))
        default:
            return .library(state, itemTitle: title)
        }
    }
}

struct MediaActionButton: View {
    enum Style { case icon, label }
    let presentation: MediaActionPresentation
    var style: Style = .icon
    let action: () -> Void

    var body: some View {
        let button = Button(action: action) {
            switch style {
            case .icon:
                if let systemImage = presentation.systemImage {
                    Image(systemName: systemImage)
                } else {
                    ProgressView()
                }
            case .label:
                if let systemImage = presentation.systemImage {
                    Label { Text(verbatim: presentation.title) } icon: { Image(systemName: systemImage) }
                } else {
                    Label { Text(verbatim: presentation.title) } icon: { ProgressView() }
                }
            }
        }
        .disabled(!presentation.isEnabled)
        .accessibilityLabel(Text(verbatim: presentation.accessibilityLabel))
        if let explanation = presentation.explanation {
            button.accessibilityHint(Text(verbatim: explanation))
        } else {
            button
        }
    }
}

extension ServerDownloadActionState {
    /// The library-button state for a catalog row: a row that resolves to a library track is in the library.
    static func catalogRow(server: ServerDownloadActionState, inLibrary: Bool) -> ServerDownloadActionState {
        inLibrary ? .accepted : server
    }
}

/// Confirmation copy shown before an album is added to the server library.
struct AlbumAddConfirmation: Equatable {
    /// Albums at or above this many tracks ask for confirmation before they are added.
    static let threshold = 20

    let title: String
    let message: String
    let confirmLabel: String

    /// Returns nil when the album can be added immediately. An unknown count (nil or non-positive)
    /// always needs confirmation because the server may add more tracks than the app can show.
    static func make(albumTitle: String, trackCount: Int?, threshold: Int = AlbumAddConfirmation.threshold) -> AlbumAddConfirmation? {
        let title = String(localized: "Add \(albumTitle) to Library?")
        let confirmLabel = String(localized: "Add Album")
        guard let count = trackCount, count > 0 else {
            return AlbumAddConfirmation(
                title: title,
                message: String(localized: "The number of songs in this album is unknown. Everything the server finds for this album will be added to your library."),
                confirmLabel: confirmLabel)
        }
        guard count >= threshold else { return nil }
        return AlbumAddConfirmation(
            title: title,
            message: String(localized: "This adds \(Int(count)) songs from this album to your server library."),
            confirmLabel: confirmLabel)
    }
}

/// An album add waiting on confirmation; `resolved` is captured at tap time.
struct PendingAlbumAdd: Identifiable {
    let url: String
    let resolved: [CatalogSong]?
    let confirmation: AlbumAddConfirmation

    var id: String { url }
}

/// Now Playing quick action state for liking the current song. Likes need a library track.
struct NowPlayingLikePresentation: Equatable {
    let isEnabled: Bool
    let isLiked: Bool
    let isPending: Bool
    let systemImage: String
    let title: String
    let accessibilityLabel: String
    let explanation: String?

    static func make(itemTitle t: String, isInLibrary: Bool, likesAvailable: Bool,
                     liked: Bool, pending: Bool, busy: Bool) -> Self {
        let explanation: String?
        if !isInLibrary {
            explanation = String(localized: "Add to Library first")
        } else if !likesAvailable {
            explanation = String(localized: "Likes are unavailable")
        } else {
            explanation = nil
        }
        let liked = isInLibrary && liked
        return Self(
            isEnabled: explanation == nil && !busy,
            isLiked: liked,
            isPending: isInLibrary && pending,
            systemImage: liked ? "heart.fill" : "heart",
            title: liked ? String(localized: "Liked") : String(localized: "Like"),
            accessibilityLabel: liked ? String(localized: "Unlike \(t)") : String(localized: "Like \(t)"),
            explanation: explanation)
    }
}

/// Now Playing quick action state for adding the current song to a playlist.
struct NowPlayingPlaylistPresentation: Equatable {
    let isEnabled: Bool
    let accessibilityLabel: String
    let explanation: String?

    static func make(itemTitle t: String, isInLibrary: Bool, supportsEditing: Bool,
                     editablePlaylistCount: Int, busy: Bool) -> Self {
        let explanation: String?
        if !isInLibrary {
            explanation = String(localized: "Add to Library first")
        } else if !supportsEditing {
            explanation = String(localized: "This server can't edit playlists")
        } else if editablePlaylistCount == 0 {
            explanation = String(localized: "No playlists you can edit")
        } else {
            explanation = nil
        }
        return Self(isEnabled: explanation == nil && !busy,
                    accessibilityLabel: String(localized: "Add \(t) to a playlist"),
                    explanation: explanation)
    }
}

/// Playlists that accept added tracks: manual, editable, favorites first, then by title.
enum EditablePlaylists {
    static func sorted(_ playlists: [LibraryPlaylist]?, supportsEditing: Bool) -> [LibraryPlaylist] {
        guard supportsEditing else { return [] }
        return (playlists ?? [])
            .filter { $0.manual == true && $0.canEditTracks == true }
            .sorted {
                let lhsFavorite = $0.favorite == true, rhsFavorite = $1.favorite == true
                if lhsFavorite != rhsFavorite { return lhsFavorite }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }
}

/// What plays after the current entry when the listener taps Next.
struct UpNextSummary: Equatable {
    let entry: PlaybackQueueEntry
    /// Upcoming entries after `entry` before the queue ends (or loops back to the current entry).
    let laterCount: Int
    /// True when `entry` is reached by looping back to the start under repeat-all.
    let wrapsToStart: Bool

    init?(queue: PlaybackQueue) {
        guard let currentIndex = queue.currentIndex,
              let nextID = queue.next(automatic: false),
              nextID != queue.currentID,
              let entry = queue.order.first(where: { $0.id == nextID }) else { return nil }
        self.entry = entry
        self.laterCount = max(0, queue.upcomingCount - 1)
        self.wrapsToStart = currentIndex + 1 >= queue.order.count
    }
}
