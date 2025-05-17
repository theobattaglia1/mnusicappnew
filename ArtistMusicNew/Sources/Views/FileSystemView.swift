//
//  FileSystemView.swift
//  ArtistMusic
//
//  Compatible with Swift 6 — 16 May 2025
//

import SwiftUI

struct FileSystemView: View {

    @EnvironmentObject private var store: ArtistStore
    @StateObject private var fs = FileSystemManager()

    var body: some View {
        VStack(spacing: 24) {

            if let stamp = fs.lastSync {
                Text("Last synced \(stamp.formatted(.dateTime))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("No sync has run yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: fs.progress)
                .progressViewStyle(.linear)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button("Sync Now") {
                    fs.sync(with: store)
                }
                .buttonStyle(.borderedProminent)

                Button("Deep Scan") {
                    fs.runBackgroundScan(store: store)
                }
            }
        }
        .padding()
        .navigationTitle("File System")
    }
}
