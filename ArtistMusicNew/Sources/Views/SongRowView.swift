// SongRowView.swift
//  ArtistMusic – Updated 15 May 2025

import SwiftUI

struct SongRowView: View {
    let song          : Song
    let isHighlighted : Bool
    let isCurrent     : Bool
    let isPlaying     : Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkThumb(data: song.artworkData)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)
                if !song.version.isEmpty {
                    Text(song.version)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isCurrent {
                Image(systemName: isPlaying
                                   ? "speaker.wave.2.fill"
                                   : "speaker.slash.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 6)
        .padding(.trailing, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(isHighlighted ? Color.accentColor.opacity(0.08)
                                   : Color.clear)
    }
}

private struct ArtworkThumb: View {
    let data: Data?

    var body: some View {
        Group {
            if let d = data, let img = UIImage(data: d) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 48, height: 48)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
