//  Sources/Helpers/Song+Helpers.swift
import Foundation

extension Song {
    /// "Writer · Producer" text the bar shows under the title.
    var artistLine: String {
        creators.joined(separator: " · ")
    }

    /// Where the audio file lives on disk.
    /// (Relies on `fileName` being set when you import the song.)
    var fileURL: URL? {
        guard !fileName.isEmpty else {
            print("⚠️ Song has empty fileName: \(title)")
            return nil
        }
        
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = support
            .appendingPathComponent("ArtistMusic/Audio", isDirectory: true)
            .appendingPathComponent(fileName)
            
        // Verify the file actually exists
        if !FileManager.default.fileExists(atPath: url.path) {
            print("⚠️ Audio file not found: \(url.path)")
            return nil
        }
        
        print("🎵 Found audio file: \(url.path)")
        return url
    }
}
