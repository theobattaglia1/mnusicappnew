// ────────────────────────────────────────────────────────────
//  ArtistStore+Extras.swift
//  ArtistMusic
//
//  Adds a convenience method to create a brand-new Artist.
// ────────────────────────────────────────────────────────────

import Foundation

extension ArtistStore {
    /// Create a new artist with blank banner/avatar and no songs/playlists,
    /// append it to `artists`, and return it.
    @discardableResult
    public func createArtist(name: String) -> Artist {
        let new = Artist(
            id: UUID(),
            name: name,
            bannerData: nil,    // match your Artist init
            avatarData: nil,    // match your Artist init
            songs: [],
            playlists: []
        )
        artists.append(new)
        // TODO: if you have a persistence API, call it here:
        //     saveArtists()
        return new
    }
}
