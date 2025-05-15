//
//  CollaboratorsList.swift
//  ArtistMusic
//
//  Created by Theo Battaglia on 5/15/25.
//


import SwiftUI

struct CollaboratorsList: View {
    let artist: Artist
    let onTap: (String) -> Void
    
    var body: some View {
        let names = Array(
            Set(artist.songs.flatMap { $0.creators })
        ).sorted()
        
        if names.isEmpty {
            EmptyState(
                icon: "person.3",
                title: "No Collaborators",
                message: "Add song credits to see collaborators."
            )
        } else {
            ForEach(names, id: \.self) { name in
                HStack {
                    Text(name)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture { onTap(name) }
                Divider()
            }
        }
    }
}