//
//  ArtistsTab.swift
//  ArtistMusic
//
//  Created by Theo Battaglia on 5/16/25.
//


//
//  ArtistsTab.swift
//  ArtistMusic
//
//  Restored full‑function UI for the Artists tab.
//  • Shows first artist automatically
//  • Empty‑state prompt when no artists exist
//  • Add‑artist sheet
//  • Now‑playing bar persistently at bottom
//
import SwiftUI

struct ArtistsTab: View {
    @EnvironmentObject private var store : ArtistStore
    @EnvironmentObject private var player: AudioPlayer

    @Binding var selectedArtistID : UUID?
    @Binding var showingAddArtist : Bool

    // MARK: – Body
    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                if let currentID = selectedArtistID ?? store.artists.first?.id {
                    ArtistDetailView(
                        artistID: currentID,
                        selectedArtistID: $selectedArtistID
                    )
                } else {
                    emptyState
                }
            }
            .sheet(isPresented: $showingAddArtist) {
                AddArtistSheet(selectedArtistID: $selectedArtistID)
                    .environmentObject(store)
            }

            if player.current != nil {
                NowPlayingBar()
                    .environmentObject(player)
                    .transition(.move(edge: .bottom))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("No artists yet")
                .font(.title3)
                .foregroundColor(.secondary)
            Button("Add Artist") {
                showingAddArtist = true
            }
        }
    }
}
