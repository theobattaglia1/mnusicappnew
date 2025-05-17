import SwiftUI
import UniformTypeIdentifiers

/// Custom tab bar that auto‑switches to **Playlists** as soon as you drag songs into its button.
struct CustomTabBar: View {
    @Binding var selectedTab: ArtistDetailView.Tab

    var body: some View {
        ZStack(alignment: .top) {
            // Background bar
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 56)
                .padding(.horizontal)

            // Tab buttons
            HStack(spacing: 0) {
                ForEach(ArtistDetailView.Tab.allCases) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        onTap: { selectedTab = tab },
                        selectedTab: $selectedTab
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

// MARK: – Tab button
private struct TabButton: View {
    let tab: ArtistDetailView.Tab
    let isSelected: Bool
    let onTap: () -> Void
    @Binding var selectedTab: ArtistDetailView.Tab

    @State private var hoverDrop = false
    static let songUTI = ["com.theo.artistmusic.song-id"]

    var body: some View {
        Button(action: onTap) {
            label
                .background(isSelected ? selectedBackground : nil)
                .foregroundColor(isSelected ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        // Handle drag hover & drop events
        .onDrop(of: TabButton.songUTI, delegate: TabHoverDelegate(selected: $selectedTab, target: tab))
    }

    private var label: some View {
        VStack(spacing: 6) {
            Image(systemName: icon(for: tab))
                .font(.system(size: isSelected ? 18 : 16))
                .fontWeight(isSelected ? .semibold : .regular)
            Text(tab.title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var selectedBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: Color.accentColor.opacity(0.2), radius: 4, x: 0, y: 2)
    }

    private func icon(for tab: ArtistDetailView.Tab) -> String {
        switch tab {
        case .allSongs:     return "music.note.list"
        case .playlists:    return "rectangle.stack.fill"
        case .collaborators:return "person.2.fill"
        }
    }
}

// MARK: – Hover delegate for debug & auto-switch
private struct TabHoverDelegate: DropDelegate {
    @Binding var selected: ArtistDetailView.Tab
    let target: ArtistDetailView.Tab

    func validateDrop(_ info: DropInfo) -> Bool {
        // only accept our custom UTI
        info.hasItemsConforming(to: TabButton.songUTI)
    }

    func dropEntered(_ info: DropInfo) {
        // auto-switch when drag enters the tab area
        if target == .playlists {
            print("Drag entered Playlists tab – switching")
            selected = .playlists
        }
    }

    func dropExited(_ info: DropInfo) {
        // nothing
    }

    func performDrop(info: DropInfo) -> Bool {
        // allow drop-through; actual drop handled by destination view
        return false
    }
}
