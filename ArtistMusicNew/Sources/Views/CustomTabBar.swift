//
//  CustomTabBar.swift
//  ArtistMusic
//
//  Created by Theo Battaglia on 5/15/25.
//


import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: ArtistDetailView.Tab
    
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 56)
                .padding(.horizontal)
            HStack(spacing: 0) {
                ForEach(ArtistDetailView.Tab.allCases) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        onTap: { selectedTab = tab }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

struct TabButton: View {
    let tab: ArtistDetailView.Tab
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: iconFor(tab))
                    .font(.system(size: isSelected ? 18 : 16))
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(tab.title)
                    .font(.system(size: 12,
                                  weight: isSelected ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        Color.accentColor.opacity(0.3),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(
                                color: Color.accentColor.opacity(0.2),
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                    }
                }
            )
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func iconFor(_ tab: ArtistDetailView.Tab) -> String {
        switch tab {
        case .allSongs:     return "music.note.list"
        case .playlists:   return "rectangle.stack.fill"
        case .collaborators: return "person.2.fill"
        }
    }
}