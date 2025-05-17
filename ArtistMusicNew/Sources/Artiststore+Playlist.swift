//
//  Artiststore+Playlist.swift
//  ArtistMusic
//
//  Created by Theo Battaglia on 5/16/25.
//


import Foundation

extension ArtistStore {
    /// Append a playlist to the artist with `artistID`
    @MainActor
    func add(playlist: Playlist, to artistID: UUID) {
        guard let idx = artists.firstIndex(where: { $0.id == artistID }) else { return }
        artists[idx].playlists.append(playlist)
    }
}
