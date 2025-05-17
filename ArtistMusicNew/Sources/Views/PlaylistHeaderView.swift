//
//  PlaylistHeaderView.swift
//  ArtistMusic
//
//  Created by Theo Battaglia on 5/15/25.
//


//
//  PlaylistHeaderView.swift
//  ArtistMusic
//
//  Minimal header component so PlaylistDetailSheet compiles. Adjust UI as needed.
//

import SwiftUI

struct PlaylistHeaderView: View {
    let playlist: Playlist
    let artist: Artist
    let playlistSongs: [Song]
    let onImageTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Button(action: onImageTap) {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.title2.bold())
                Text("\(playlistSongs.count) song\(playlistSongs.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
