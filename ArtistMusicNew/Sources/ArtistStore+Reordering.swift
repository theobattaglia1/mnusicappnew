import Foundation

extension ArtistStore {
    /// Move songs in All Songs tab
    @MainActor
    func moveSongs(for artistID: UUID,
                   fromOffsets src: IndexSet,
                   toOffset dst: Int) {
        guard let aIdx = artists.firstIndex(where: { $0.id == artistID }) else { return }
        artists[aIdx].songs.move(fromOffsets: src, toOffset: dst)
    }

    /// Move playlists
    @MainActor
    func movePlaylists(for artistID: UUID,
                       fromOffsets src: IndexSet,
                       toOffset dst: Int) {
        guard let aIdx = artists.firstIndex(where: { $0.id == artistID }) else { return }
        artists[aIdx].playlists.move(fromOffsets: src, toOffset: dst)
    }

    /// Move songs within a playlist
    @MainActor
    func moveSongs(in playlistID: UUID,
                   for artistID: UUID,
                   fromOffsets src: IndexSet,
                   toOffset dst: Int) {
        guard let aIdx = artists.firstIndex(where: { $0.id == artistID }) else { return }
        guard let pIdx = artists[aIdx].playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        artists[aIdx].playlists[pIdx].songIDs.move(fromOffsets: src, toOffset: dst)
    }

    /// Remove selected songs from a playlist
    @MainActor
    func remove(songIDs: [UUID],
                from playlistID: UUID,
                artistID: UUID) {
        guard let aIdx = artists.firstIndex(where: { $0.id == artistID }) else { return }
        guard let pIdx = artists[aIdx].playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        artists[aIdx].playlists[pIdx].songIDs.removeAll { songIDs.contains($0) }
    }
}
