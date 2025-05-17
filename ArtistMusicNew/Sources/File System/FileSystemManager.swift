//
//  FileSystemManager.swift
//  ArtistMusic
//
//  Compatible with Swift 6 — 16 May 2025
//

import Foundation

/// Manages background rescans of the App-Support audio folder, then
/// reconciles playlists with `ArtistStore`.
///
/// * ObservableObject so a `View` can watch progress.
/// * @MainActor because it ultimately mutates the shared `ArtistStore`.
@MainActor
final class FileSystemManager: ObservableObject {

    /// Simple progress indicator (0…1) for UI, if desired.
    @Published var progress: Double = 0

    /// Timestamp of the most recent successful sync.
    @Published var lastSync: Date?

    /// Public initializer ⇒ allows `@StateObject` in SwiftUI.
    init() {}

    /// Kick off a **quick** scan on the main actor.
    func sync(with store: ArtistStore) {
        progress = 0
        store.syncPlaylists()                // ← currently a stub
        progress = 1
        lastSync = .now
        print("✅ File-system sync finished")
    }

    /// Heavy scan on a background task, updating `progress` safely.
    func runBackgroundScan(store: ArtistStore) {
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }

            // pretend to do heavy work
            for step in 0...10 {
                try? await Task.sleep(for: .milliseconds(200))
                await MainActor.run { self.progress = Double(step) / 10 }
            }

            await MainActor.run {
                store.syncPlaylists()
                self.lastSync = .now
            }
        }
    }
}
