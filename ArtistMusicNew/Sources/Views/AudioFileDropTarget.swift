import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - AudioFileDropTarget
struct AudioFileDropTarget: ViewModifier {
    @Binding var isTargeted: Bool
    let artistID: UUID
    let store: ArtistStore
    let onImportComplete: ((UUID) -> Void)?
    
    @State private var dragOver = false
    
    func body(content: Content) -> some View {
        ZStack {
            // Highlight when dragging over
            Rectangle()
                .fill(dragOver ? Color.accentColor.opacity(0.15) : Color.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // The actual content
            content
        }
        .overlay(
            AudioDropView(
                isTargeted: $isTargeted,
                dragOver: $dragOver,
                artistID: artistID,
                store: store,
                onImportComplete: onImportComplete
            )
        )
    }
}

// MARK: - AudioDropView (UIViewRepresentable)
struct AudioDropView: UIViewRepresentable {
    @Binding var isTargeted: Bool
    @Binding var dragOver: Bool
    let artistID: UUID
    let store: ArtistStore
    let onImportComplete: ((UUID) -> Void)?
    
    func makeUIView(context: Context) -> AudioDropUIView {
        let view = AudioDropUIView()
        view.coordinator = context.coordinator
        // Set up drop interaction
        let dropInteraction = UIDropInteraction(delegate: context.coordinator)
        view.addInteraction(dropInteraction)
        // Enable drag and drop for the view itself
        view.isUserInteractionEnabled = true
        return view
    }
    
    func updateUIView(_ uiView: AudioDropUIView, context: Context) {
        context.coordinator.artistID = artistID
        context.coordinator.store = store
        context.coordinator.onImportComplete = onImportComplete
        uiView.coordinator = context.coordinator
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Custom UIView that supports drag and drop
    class AudioDropUIView: UIView {
        var coordinator: Coordinator?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            self.backgroundColor = .clear
            self.isUserInteractionEnabled = true
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            self.backgroundColor = .clear
            self.isUserInteractionEnabled = true
        }
    }
    
    class Coordinator: NSObject, UIDropInteractionDelegate {
        var parent: AudioDropView
        var artistID: UUID
        var store: ArtistStore
        var onImportComplete: ((UUID) -> Void)?
        
        init(_ parent: AudioDropView) {
            self.parent = parent
            self.artistID = parent.artistID
            self.store = parent.store
            self.onImportComplete = parent.onImportComplete
            super.init()
        }
        
        // Called when a drag enters the view
        func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
            print("🔵 Drag entered drop view")
            print("🔵 Session identifiers: \(session.items.flatMap { $0.itemProvider.registeredTypeIdentifiers })")
            parent.dragOver = true
            parent.isTargeted = true
        }
        
        // Called when a drag exits the view
        func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
            print("🔵 Drag exited drop view")
            parent.dragOver = false
            parent.isTargeted = false
        }
        
        // Called to check if the drop session can be handled
        func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
            // Log all available type identifiers
            let typeIds = session.items.flatMap { $0.itemProvider.registeredTypeIdentifiers }
            print("🔵 Drag item has types: \(typeIds)")
            
            // Can handle m4a, wav, mp3, and finder node items
            let canHandle = typeIds.contains(where: {
                $0 == "com.apple.m4a-audio" ||
                $0 == "com.microsoft.waveform-audio" ||
                $0 == "public.mp3" ||
                $0 == "com.apple.finder.node" ||
                $0 == "public.audio" ||
                $0 == UTType.audio.identifier
            })
            
            print("🔵 Can handle drop with type: \(UTType.audio.identifier)")
            return canHandle
        }
        
        // Called to determine the drop proposal
        func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            // This is critical - we must return .copy as the operation
            return UIDropProposal(operation: .copy)
        }
        
        // Called when the drop is performed
        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            print("🔵 Drop received with \(session.items.count) items")
            parent.dragOver = false
            parent.isTargeted = false
            
            // First try finder node items
            let itemsToProcess = session.items.filter { item in
                item.itemProvider.registeredTypeIdentifiers.contains("com.apple.finder.node") ||
                item.itemProvider.registeredTypeIdentifiers.contains("com.apple.m4a-audio") ||
                item.itemProvider.registeredTypeIdentifiers.contains("public.audio")
            }
            
            guard !itemsToProcess.isEmpty else {
                print("❌ No compatible items found in drop")
                return
            }
            
            for item in itemsToProcess {
                print("🔵 Processing item with types: \(item.itemProvider.registeredTypeIdentifiers)")
                
                // First try Finder node
                if item.itemProvider.hasItemConformingToTypeIdentifier("com.apple.finder.node") {
                    item.itemProvider.loadItem(forTypeIdentifier: "com.apple.finder.node", options: nil) { (data, error) in
                        if let error = error {
                            print("❌ Error loading finder node: \(error)")
                            return
                        }
                        
                        if let url = data as? URL {
                            self.handleDroppedURL(url)
                        } else if let data = data as? Data,
                                  let url = URL(dataRepresentation: data, relativeTo: nil) {
                            self.handleDroppedURL(url)
                        } else {
                            print("❌ Could not extract URL from finder node")
                        }
                    }
                }
                // Try m4a specifically
                else if item.itemProvider.hasItemConformingToTypeIdentifier("com.apple.m4a-audio") {
                    item.itemProvider.loadItem(forTypeIdentifier: "com.apple.m4a-audio", options: nil) { (data, error) in
                        if let error = error {
                            print("❌ Error loading m4a: \(error)")
                            return
                        }
                        
                        if let url = data as? URL {
                            self.handleDroppedURL(url)
                        } else if let data = data as? Data {
                            self.handleDroppedData(data, withExtension: "m4a")
                        } else {
                            print("❌ Could not extract data from m4a")
                        }
                    }
                }
                // Try generic audio
                else if item.itemProvider.hasItemConformingToTypeIdentifier("public.audio") {
                    item.itemProvider.loadItem(forTypeIdentifier: "public.audio", options: nil) { (data, error) in
                        if let error = error {
                            print("❌ Error loading audio: \(error)")
                            return
                        }
                        
                        if let url = data as? URL {
                            self.handleDroppedURL(url)
                        } else if let data = data as? Data {
                            self.handleDroppedData(data, withExtension: "m4a")
                        } else {
                            print("❌ Could not extract data from audio")
                        }
                    }
                }
            }
        }
        
        // Process a dropped URL
        private func handleDroppedURL(_ url: URL) {
            print("✅ Processing dropped URL: \(url.path)")
            
            DispatchQueue.main.async {
                // Try to secure access to the URL
                let didAccess = url.startAccessingSecurityScopedResource()
                
                // Make a copy to a temp location
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension.isEmpty ? "m4a" : url.pathExtension)
                
                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    print("✅ Copied to: \(tempURL.path)")
                    
                    if didAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                    
                    Task { @MainActor in
                        print("🎵 Importing song")
                        self.store.importSong(from: tempURL, artistID: self.artistID)
                        
                        // Wait a bit for the import to complete
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        
                        if let newSong = self.store.artists.first(where: { $0.id == self.artistID })?.songs.last {
                            print("✅ Song imported successfully: \(newSong.title)")
                            self.onImportComplete?(newSong.id)
                        } else {
                            print("⚠️ Could not find newly imported song")
                        }
                    }
                } catch {
                    print("❌ Error copying file: \(error)")
                    
                    if didAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
        }
        
        // Process dropped raw data
        private func handleDroppedData(_ data: Data, withExtension ext: String) {
            print("✅ Processing \(data.count) bytes of audio data")
            
            // Save to a temp file
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            
            do {
                try data.write(to: tempURL)
                print("✅ Wrote data to: \(tempURL.path)")
                
                DispatchQueue.main.async {
                    Task { @MainActor in
                        print("🎵 Importing song")
                        self.store.importSong(from: tempURL, artistID: self.artistID)
                        
                        // Wait a bit for the import to complete
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        
                        if let newSong = self.store.artists.first(where: { $0.id == self.artistID })?.songs.last {
                            print("✅ Song imported successfully: \(newSong.title)")
                            self.onImportComplete?(newSong.id)
                        } else {
                            print("⚠️ Could not find newly imported song")
                        }
                    }
                }
            } catch {
                print("❌ Error writing data: \(error)")
            }
        }
    }
}

// MARK: - View Extension for easy application
extension View {
    func audioFileDropTarget(
        isTargeted: Binding<Bool>,
        artistID: UUID,
        store: ArtistStore,
        onImportComplete: ((UUID) -> Void)? = nil
    ) -> some View {
        self.modifier(AudioFileDropTarget(
            isTargeted: isTargeted,
            artistID: artistID,
            store: store,
            onImportComplete: onImportComplete
        ))
    }
}
