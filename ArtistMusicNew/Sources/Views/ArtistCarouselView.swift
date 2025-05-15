// ArtistCarouselView.swift
import SwiftUI

/// Swipe left/right to page through artists
struct ArtistCarouselView: View {
    @EnvironmentObject private var store: ArtistStore
    @Binding var selectedArtistID: UUID?

    var body: some View {
        TabView(selection: $selectedArtistID) {
            ForEach(store.artists) { artist in
                ArtistDetailView(
                    artistID: artist.id,
                    selectedArtistID: $selectedArtistID
                )
                .tag(artist.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .top)
    }
}

#if DEBUG
struct ArtistCarouselView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistCarouselView(
            selectedArtistID: .constant(
                ArtistStore().artists.first?.id ?? UUID()
            )
        )
        .environmentObject(ArtistStore())
        .environmentObject(AudioPlayer())
    }
}
#endif
