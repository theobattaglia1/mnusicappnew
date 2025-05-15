// ─── FileSystemManager.swift ─────────────────────────────────────────────────
import Foundation
import Combine
import UniformTypeIdentifiers

@MainActor
public final class FileSystemManager: ObservableObject {
    @Published public private(set) var files: [URL] = []
    @Published public private(set) var folders: [URL] = []

    private var watchers: [URL: DispatchSourceFileSystemObject] = [:]
    private weak var store: ArtistStore?

    public init() {}

    // Attach the ArtistStore (internal, since ArtistStore is internal)
    func attach(_ store: ArtistStore) {
        self.store = store
        Task { @MainActor in
            refreshAllFiles()
        }
    }

    /// Watch and persist folder selection
    public func addFolder(_ url: URL, saveBookmark: Bool = true) {
        guard watchers[url] == nil else { return }
        folders.append(url)
        startWatching(url)
        refreshAllFiles()
        if saveBookmark { persistBookmark(for: url) }
    }

    /// Enumerate files & sync playlists
    private func refreshAllFiles() {
        var collected: [URL] = []
        var map: [URL: [URL]] = [:]
        for root in folders {
            guard let enumer = FileManager.default.enumerator(at: root,
                                                               includingPropertiesForKeys: [.contentTypeKey, .isRegularFileKey],
                                                               options: [.skipsHiddenFiles]) else { continue }
            for case let fileURL as URL in enumer {
                guard Self.isAudioFile(fileURL) else { continue }
                collected.append(fileURL)
                let parent = fileURL.deletingLastPathComponent()
                if parent != root {
                    map[parent, default: []].append(fileURL)
                }
            }
        }
        files = collected.sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
        if let store = store {
            store.syncPlaylists(from: map)
        }
    }

    /// Start FS watcher
    private func startWatching(_ folder: URL) {
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd,
                                                            eventMask: [.write, .rename, .delete],
                                                            queue: .main)
        src.setEventHandler { [weak self] in self?.refreshAllFiles() }
        src.setCancelHandler { close(fd) }
        src.resume()
        watchers[folder] = src
    }

    /// Cancel watchers & stop bookmarks
    deinit {
        for src in watchers.values {
            src.cancel()
        }
        Task { @MainActor in
            for url in folders where url.hasDirectoryPath {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    // MARK: – Helpers

    private func persistBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(options: [],
                                               includingResourceValuesForKeys: nil,
                                               relativeTo: nil) else { return }
        var list = UserDefaults.standard.array(forKey: "watchedBookmarks") as? [Data] ?? []
        list.append(data)
        UserDefaults.standard.set(list, forKey: "watchedBookmarks")
    }

    private static func isAudioFile(_ url: URL) -> Bool {
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else { return false }
        return type.conforms(to: .audio)
    }
}
