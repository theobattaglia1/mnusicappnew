//
//  ImportTab.swift
//  ArtistMusic
//
//  Created by Theo Battaglia on 5/16/25.
//


import SwiftUI

/// Import tab: shows the local-/iCloud file system view and the Now-Playing bar.
struct ImportTab: View {
    @EnvironmentObject private var store : ArtistStore
    @EnvironmentObject private var player: AudioPlayer

    var body: some View {
        ZStack(alignment: .bottom) {
            FileSystemView()
                .environmentObject(store)
                .environmentObject(player)

            if player.current != nil {
                NowPlayingBar()
                    .environmentObject(player)
                    .transition(.move(edge: .bottom))
            }
        }
    }
}
