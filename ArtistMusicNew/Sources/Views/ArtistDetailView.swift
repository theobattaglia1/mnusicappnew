import SwiftUI
import UniformTypeIdentifiers

// ────────────────────────────────────────────────────────────
// MARK: – Artist page
// ────────────────────────────────────────────────────────────
struct ArtistDetailView: View {
    
    // Store + nav
    @EnvironmentObject private var store: ArtistStore
    @EnvironmentObject private var player: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    
    // UI state
    @State private var tab: Tab = .allSongs
    @State private var showingImporter = false      // ← add this
    @State private var showingArtistPicker = false
    
    // Single‐sheet handler
    enum ActiveSheet: Identifiable {
        case addPlaylist
        case songArt(UUID)
        case collaborator(String)
        case editArtist(Artist)
        var id: String {
            switch self {
            case .addPlaylist:        return "addPlaylist"
            case .songArt(let id):    return "songArt-\(id)"
            case .collaborator(let n):return "collab-\(n)"
            case .editArtist(let a):  return "editArtist-\(a.id)"
            }
        }
    }
    @State private var activeSheet: ActiveSheet?
    
    // Input
    let artistID: UUID
    @Binding var selectedArtistID: UUID?
    private var artist: Artist? { store.artists.first { $0.id == artistID } }
    
    enum Tab: String, CaseIterable, Identifiable {
        case allSongs, playlists, collaborators
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }
    
    var body: some View {
        if let artist = artist {
            content(for: artist)
        } else {
            VStack { Spacer(); Text("Artist not found").foregroundColor(.secondary); Spacer() }
                .onAppear { dismiss() }
        }
    }
    
    @ViewBuilder
    private func content(for artist: Artist) -> some View {
        VStack(spacing: 0) {
            // ───────── HEADER ─────────
            Header(
                artist:           artist,
                onEdit:           { activeSheet = .editArtist(artist) },
                onChangeArtist:   { showingArtistPicker = true },
                selectedArtistID: $selectedArtistID
            )
            
            CustomTabBar(selectedTab: $tab)
            
            // ───────── BODY TABS ─────────
            switch tab {
            case .allSongs:
                SongsList(
                    showingImporter: $showingImporter,   // ← use your real binding
                    artistID:        artist.id,
                    onArtTap:        { id in activeSheet = .songArt(id) }
                )
            case .playlists:
                PlaylistsList(artistID: artist.id)
            case .collaborators:
                CollaboratorsList(
                    artist: artist,
                    onTap:  { name in activeSheet = .collaborator(name) }
                )
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(
            for: Notification.Name("AddPlaylistTapped"))
        ) { _ in activeSheet = .addPlaylist }
            .confirmationDialog("Switch artist…",
                                isPresented: $showingArtistPicker,
                                titleVisibility: .visible) {
                ForEach(store.artists) { a in
                    Button(a.name) { selectedArtistID = a.id }
                }
            }
                                .sheet(item: $activeSheet) { sheet in
                                    switch sheet {
                                    case .addPlaylist:
                                        AddPlaylistSheet(artistID: artistID)
                                            .environmentObject(store)
                                    case .songArt(let id):
                                        ImagePicker(data: Binding<Data?>(
                                            get: {
                                                store.artists
                                                    .first { $0.id == artistID }?
                                                    .songs
                                                    .first  { $0.id == id }?
                                                    .artworkData
                                            },
                                            set: { newData in
                                                store.setArtwork(newData, for: id, artistID: artistID)
                                            }
                                            
                                        ))
                                    case .collaborator(let name):
                                        CollaboratorDetailView(name: name)
                                            .environmentObject(store)
                                    case .editArtist(let artist):
                                        EditArtistSheet(artist: artist)
                                            .environmentObject(store)
                                    }
                                    
                                }
        // at the bottom of content(for:) before the modifier chain ends
                                .onDrop(of: [.fileURL, .audio], isTargeted: nil) { providers in
                                    print("🚩 D dropped on detail view:", providers)
                                    return true
                                }
        
        
    }
    
    // ────────────────────────────────────────────────────────────
    // MARK: – Header (long-press → horizontal drag to switch artists)
    // ────────────────────────────────────────────────────────────
    private struct Header: View {
        let artist: Artist
        let onEdit: () -> Void
        let onChangeArtist: () -> Void
        
        @Binding var selectedArtistID: UUID?
        @EnvironmentObject private var store: ArtistStore
        
        // how long to hold before you can swipe:
        private let holdDuration: Double = 0.5
        @State private var dragOffset: CGSize = .zero
        @State private var isPressing = false
        
        var body: some View {
            ZStack(alignment: .bottomLeading) {
                // Banner with drag-&-drop + swipe gestures
                banner
                    .resizable()
                    .scaledToFill()
                    .frame(height: 260)
                    .clipped()
                    .onDrop(of: [.fileURL, .image], isTargeted: nil) { providers in
                        // 1) Prefer file URLs
                        if let provider = providers.first(where: {
                            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                        }) {
                            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier,
                                              options: nil) { item, _ in
                                guard
                                    let data = item as? Data,
                                    let url  = URL(dataRepresentation: data, relativeTo: nil),
                                    let imgD = try? Data(contentsOf: url)
                                else { return }
                                DispatchQueue.main.async {
                                    store.setBanner(imgD, for: artist.id)
                                }
                            }
                            return true
                        }
                        // 2) Otherwise accept raw image data
                        if let provider = providers.first(where: {
                            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
                        }) {
                            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                                guard let imgD = data else { return }
                                DispatchQueue.main.async {
                                    store.setBanner(imgD, for: artist.id)
                                }
                            }
                            return true
                        }
                        return false
                    }
                // long-press to enable swipe
                    .gesture(
                        LongPressGesture(minimumDuration: holdDuration)
                            .onEnded { _ in isPressing = true }
                    )
                    .highPriorityGesture(
                        DragGesture()
                            .onChanged { g in
                                guard isPressing else { return }
                                dragOffset = g.translation
                            }
                            .onEnded { _ in
                                guard isPressing else { return }
                                handleSwipe(translation: dragOffset)
                                isPressing = false
                                dragOffset = .zero
                            }
                    )
                
                HStack(spacing: 12) {
                    // Avatar with drag-&-drop + long-press to switch
                    avatar
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                        .onDrop(of: [.fileURL, .image], isTargeted: nil) { providers in
                            // file URLs
                            if let provider = providers.first(where: {
                                $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                            }) {
                                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier,
                                                  options: nil) { item, _ in
                                    guard
                                        let data = item as? Data,
                                        let url  = URL(dataRepresentation: data, relativeTo: nil),
                                        let imgD = try? Data(contentsOf: url)
                                    else { return }
                                    DispatchQueue.main.async {
                                        store.setAvatar(imgD, for: artist.id)
                                    }
                                }
                                return true
                            }
                            // raw image data
                            if let provider = providers.first(where: {
                                $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
                            }) {
                                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                                    guard let imgD = data else { return }
                                    DispatchQueue.main.async {
                                        store.setAvatar(imgD, for: artist.id)
                                    }
                                }
                                return true
                            }
                            return false
                        }
                        .onLongPressGesture {
                            onChangeArtist()
                        }
                    
                    // Artist name (long-press to switch)
                    Text(artist.name)
                        .font(.title).bold()
                        .foregroundColor(.white)
                        .shadow(radius: 3)
                        .onLongPressGesture(minimumDuration: holdDuration) {
                            onChangeArtist()
                        }
                    
                    // Edit pencil
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .frame(width: 32, height: 32)    // larger hit area
                            .contentShape(Rectangle())
                            .foregroundColor(.white)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding([.leading, .bottom], 16)
            }
        }
        
        // ────────────────────────────────────────────────────────────
        private func handleSwipe(translation: CGSize) {
            let threshold: CGFloat = 50
            guard let idx = store.artists.firstIndex(where: { $0.id == artist.id }) else { return }
            if translation.width < -threshold, idx < store.artists.count - 1 {
                selectedArtistID = store.artists[idx + 1].id
            } else if translation.width > threshold, idx > 0 {
                selectedArtistID = store.artists[idx - 1].id
            }
        }
        
        // ────────────────────────────────────────────────────────────
        private var banner: Image {
            artist.bannerData
                .flatMap(UIImage.init(data:))
                .map(Image.init(uiImage:))
            ?? Image(systemName: "photo")
        }
        
        // ────────────────────────────────────────────────────────────
        private var avatar: Image {
            artist.avatarData
                .flatMap(UIImage.init(data:))
                .map(Image.init(uiImage:))
            ?? Image(systemName: "person.circle")
        }
    }
    
    
    // ────────────────────────────────────────────────────────────
    // MARK: – SongsList (drop on the List itself)
    // ────────────────────────────────────────────────────────────
    private struct SongsList: View {
        @Binding var showingImporter: Bool
        @EnvironmentObject private var store: ArtistStore
        @EnvironmentObject private var player: AudioPlayer
        let artistID: UUID
        let onArtTap: (UUID) -> Void

        @State private var selection: Set<UUID> = []
        @State private var editMode:   EditMode = .inactive
        @State private var batchSheet          = false
        @State private var editSong:   Song?

        private var artist: Artist? {
            store.artists.first { $0.id == artistID }
        }

        var body: some View {
            if let artist = artist {
                VStack(spacing: 0) {
                    // ── TOP BAR ──
                    HStack {
                        Text("Songs")
                            .font(.title3).fontWeight(.semibold)
                        Spacer()
                        if editMode == .active {
                            if !selection.isEmpty {
                                Button(role: .destructive) {
                                    let ids = Array(selection)
                                    store.delete(songs: ids, for: artistID)
                                    selection.removeAll()
                                    editMode = .inactive
                                } label: {
                                    Text("Delete (\(selection.count))")
                                }
                                .padding(.trailing, 8)
                            }
                            Button("Done") {
                                editMode = .inactive
                                selection.removeAll()
                            }
                        } else {
                            Button { showingImporter = true } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                            .padding(.trailing, 8)
                            Button("Edit") { editMode = .active }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    // ── SONGS LIST ──
                    List(selection: $selection) {
                        ForEach(artist.chronologicalSongs) { song in
                            row(for: song, artist: artist)
                        }
                        .onDelete { idxs in
                            let ids = idxs.map { artist.chronologicalSongs[$0].id }
                            store.delete(songs: ids, for: artistID)
                        }
                    }
                    // ── DROP HANDLER ON THE ENTIRE VSTACK ──
                    .onDrop(
                        of: [UTType.fileURL, UTType.audio, UTType.item],
                        isTargeted: nil
                    ) { providers in
                        // 1) File URL or generic item → import
                        if let p = providers.first(
                            where: {
                                $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                                || $0.hasItemConformingToTypeIdentifier(UTType.item.identifier)
                            }
                        ) {
                            p.loadItem(
                                forTypeIdentifier: UTType.fileURL.identifier,
                                options: nil
                            ) { item, _ in
                                guard
                                    let data = item as? Data,
                                    let url  = URL(dataRepresentation: data, relativeTo: nil)
                                else { return }
                                DispatchQueue.main.async {
                                    store.importSong(from: url, artistID: artistID)
                                }
                            }
                            return true
                        }

                        // 2) Raw audio blob → write temp → import
                        if let p = providers.first(
                            where: { $0.hasItemConformingToTypeIdentifier(UTType.audio.identifier) }
                        ) {
                            p.loadDataRepresentation(
                                forTypeIdentifier: UTType.audio.identifier
                            ) { data, _ in
                                guard let data = data else { return }
                                let tmp = FileManager.default.temporaryDirectory
                                    .appendingPathComponent(UUID().uuidString)
                                    .appendingPathExtension("m4a")
                                do {
                                    try data.write(to: tmp)
                                    DispatchQueue.main.async {
                                        store.importSong(from: tmp, artistID: artistID)
                                    }
                                } catch {
                                    print("❌ temp write failed:", error)
                                }
                            }
                            return true
                        }

                        return false
                    }
                    .environment(\.editMode, $editMode)

                    // ── bulk importer & sheets ──
                    .fileImporter(
                        isPresented: $showingImporter,
                        allowedContentTypes: [.audio],
                        allowsMultipleSelection: true
                    ) { result in
                        switch result {
                        case .success(let urls):
                            for url in urls {
                                let didAccess = url.startAccessingSecurityScopedResource()
                                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                                store.importSong(from: url, artistID: artistID)
                            }
                        case .failure(let err):
                            print("Import error:", err)
                        }
                    }
                    .sheet(isPresented: $batchSheet) {
                        BatchEditSheet(
                            artistID: artist.id,
                            songIDs: Array(selection)
                        )
                        .environmentObject(store)
                        .onDisappear { selection.removeAll() }
                    }
                    .sheet(item: $editSong) { song in
                        EditSongSheet(artistID: artist.id, song: song)
                            .environmentObject(store)
                    }
                }
            }
        }

        // ────────────────────────────────────────────────────────────
        @ViewBuilder
        private func row(for song: Song, artist: Artist) -> some View {
            HStack {
                art(for: song)
                    .onTapGesture { onArtTap(song.id) }
                VStack(alignment: .leading) {
                    Text(song.title)
                    Text(song.version)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if editMode == .inactive { player.playSong(song) }
                }
            }
            .contentShape(Rectangle())
            .contextMenu {
                Button("Edit") { editSong = song }
                Menu("Add to Playlist") {
                    ForEach(artist.playlists.filter { $0.name != "All Songs" }) { pl in
                        Button(pl.name) {
                            store.add(songID: song.id,
                                      to: pl.id,
                                      for: artistID)
                        }
                    }
                }
            }
            .onDrag { NSItemProvider(object: song.id.uuidString as NSString) }
        }

        // ────────────────────────────────────────────────────────────
        private func art(for song: Song) -> some View {
            Group {
                if let data = song.artworkData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .resizable().scaledToFit()
                        .padding(10)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            .background(Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }


    // ────────────────────────────────────────────────────────────
    // MARK: – PlaylistsList (drop songs or audio into each playlist)
    // ────────────────────────────────────────────────────────────
    private struct PlaylistsList: View {
        @EnvironmentObject private var store: ArtistStore
        @EnvironmentObject private var player: AudioPlayer
        
        let artistID: UUID
        @State private var selectedPlaylist: UUID?
        @State private var isEditMode = false
        @State private var selectedPlaylists = Set<UUID>()
        
        private var artist: Artist? {
            store.artists.first { $0.id == artistID }
        }
        
        var body: some View {
            VStack(spacing: 0) {
                header
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(artist?.playlists ?? []) { pl in
                            playlistRow(pl)
                        }
                    }
                }
                .toolbar { ToolbarItemGroup(placement: .navigationBarTrailing) { EditButton() } }
                .fullScreenCover(item: $selectedPlaylist) { openPlaylistDetail($0) }
            }
        }
        
        // ────────────────────────────────────────────────────────────
        // Header
        private var header: some View {
            HStack {
                Text("Playlists (\(artist?.playlists.count ?? 0))")
                    .font(.title3).fontWeight(.semibold)
                Spacer()
                Button { NotificationCenter.default.post(name: .init("AddPlaylistTapped"), object: nil) }
                label: { Image(systemName: "plus.circle.fill").font(.title3) }
                Button(isEditMode ? "Done" : "Edit") { toggleEditMode() }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, isEditMode ? 4 : 12)
        }
        
        private func toggleEditMode() {
            isEditMode.toggle()
            if !isEditMode { selectedPlaylists.removeAll() }
        }
        
        // ────────────────────────────────────────────────────────────
        // Single‐row
        @ViewBuilder
        private func playlistRow(_ pl: Playlist) -> some View {
            HStack(spacing: 12) {
                Group {
                    if let d = pl.artworkData, let ui = UIImage(data: d) {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else {
                        ZStack {
                            Color.secondary.opacity(0.1)
                            Image(systemName: "music.note.list")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(pl.name).lineLimit(1)
                    Text("\(pl.songIDs.count) track\(pl.songIDs.count == 1 ? "" : "s")")
                        .font(.caption).foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !isEditMode {
                    Image(systemName: "chevron.right").foregroundColor(.gray)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(isEditMode && selectedPlaylists.contains(pl.id)
                        ? Color.accentColor.opacity(0.05)
                        : .clear)
            .contentShape(Rectangle())
            .onTapGesture { if !isEditMode { selectedPlaylist = pl.id } }
            .onDrop(of: [UTType.fileURL, UTType.audio, UTType.plainText], isTargeted: nil) {
                handleDrop($0, into: pl)
            }
            Divider().padding(.leading, isEditMode ? 56 : 78)
        }
        
        // ────────────────────────────────────────────────────────────
        // Open detail
        private func openPlaylistDetail(_ playlistID: UUID) -> some View {
            guard let pl = artist?.playlists.first(where: { $0.id == playlistID }) else {
                return AnyView(EmptyView())
            }
            return AnyView(
                PlaylistDetailSheet(artist: artist!, playlist: pl)
                    .environmentObject(store)
                    .environmentObject(player)
                    .padding(.bottom, player.current != nil ? 90 : 0)
            )
        }
        
        // ────────────────────────────────────────────────────────────
        // Drop handler
        private func handleDrop(_ providers: [NSItemProvider], into pl: Playlist) -> Bool {
            // 1) Plain-text = existing song UUID
            if let p = providers.first(
                where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }
            ) {
                p.loadObject(ofClass: NSString.self) { reading, _ in
                    // downcast from NSItemProviderReading → NSString → String
                    guard
                        let ns = reading as? NSString,
                        let sid = UUID(uuidString: ns as String)
                    else { return }
                    
                    DispatchQueue.main.async {
                        _ = store.add(songID: sid, to: pl.id, for: artistID)
                    }
                }
                return true
            }
            
            
            // 2) File URL
            if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) })
            {
                p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url  = URL(dataRepresentation: data, relativeTo: nil)
                    else { return }
                    store.importSong(from: url, artistID: artistID)
                    if let newSong = store.artists.first(where: { $0.id == artistID })?.songs.last {
                        DispatchQueue.main.async {
                            _ = store.add(songID: newSong.id, to: pl.id, for: artistID)
                        }
                    }
                }
                return true
            }
            
            // 2) Drop raw-audio blob → write & import on main thread
            if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.audio.identifier) }) {
                p.loadDataRepresentation(forTypeIdentifier: UTType.audio.identifier) { data, _ in
                    guard let data = data else { return }
                    let tmp = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("m4a")
                    do {
                        try data.write(to: tmp)
                        DispatchQueue.main.async {
                            store.importSong(from: tmp, artistID: artistID)
                        }
                    } catch {
                        print("❌ temp write failed:", error)
                    }
                }
                return true
            }
            return false
        }
    }
    
    // ────────────────────────────────────────────────────────────
    // MARK: – PlaylistHeaderView (used by PlaylistDetailSheet)
    // ────────────────────────────────────────────────────────────
    private struct PlaylistHeaderView: View {
        let playlist:    Playlist
        let artist:      Artist
        let playlistSongs: [Song]
        let onImageTap:  () -> Void

        @EnvironmentObject private var player: AudioPlayer

        var body: some View {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 15) {
                    Button(action: onImageTap) {
                        Group {
                            if let d = playlist.artworkData,
                               let ui = UIImage(data: d)
                            {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    Color.gray.opacity(0.2)
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 30))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(playlist.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(playlistSongs.count) songs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if !playlistSongs.isEmpty {
                            Button {
                                player.enqueue(playlistSongs)
                            } label: {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Play")
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                            }
                            .padding(.top, 5)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .background(Color.secondary.opacity(0.05))
        }
    }

    
    // ────────────────────────────────────────────────────────────
    // MARK: – PlaylistDetailSheet (drop audio into this playlist)
    // ────────────────────────────────────────────────────────────
    private struct PlaylistDetailSheet: View {
        @Environment(\.dismiss) private var dismiss
        @EnvironmentObject private var store: ArtistStore
        @EnvironmentObject private var player: AudioPlayer

        let artist:   Artist
        let playlist: Playlist

        @State private var isEditing       = false
        @State private var showImagePicker = false
        @State private var editName        = ""
        @State private var showRenameAlert = false

        private var playlistSongs: [Song] {
            playlist.songIDs.compactMap { id in
                artist.songs.first { $0.id == id }
            }
        }

        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    // — Header with artwork + play button —
                    PlaylistHeaderView(
                        playlist:       playlist,
                        artist:         artist,
                        playlistSongs:  playlistSongs,
                        onImageTap:     { showImagePicker = true }
                    )
                    Divider()

                    // — List of songs —
                    List {
                        if !playlistSongs.isEmpty {
                            ForEach(playlistSongs) { song in
                                HStack {
                                    // your existing artwork + title UI…
                                }
                            }
                            .onDelete { idxs in
                                let toRemove = idxs.map { playlistSongs[$0].id }
                                for id in toRemove {
                                    store.removeSong(id: id,
                                                     from: playlist.id,
                                                     for: artist.id)
                                }
                            }
                        } else {
                            Text("No songs in this playlist")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        }
                    }
                    // — 🌟 DROPPING AUDIO HERE! 🌟 —
                    .onDrop(of: [.fileURL, .audio], isTargeted: nil) { providers in
                        // 1) File URLs → import & add
                        if let p = providers.first(
                            where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
                        ) {
                            p.loadItem(forTypeIdentifier: UTType.fileURL.identifier,
                                       options: nil) { item, _ in
                                guard
                                    let data = item as? Data,
                                    let url  = URL(dataRepresentation: data,
                                                   relativeTo: nil)
                                else { return }

                                DispatchQueue.main.async {
                                    store.importSong(from: url, artistID: artist.id)
                                    // grab the very last song and add it
                                    if let newSong = store.artists
                                        .first(where: { $0.id == artist.id })?
                                        .songs.last
                                    {
                                        store.add(songID: newSong.id,
                                                  to: playlist.id,
                                                  for: artist.id)
                                    }
                                }
                            }
                            return true
                        }

                        // 2) Raw audio blob → write temp, import & add
                        if let p = providers.first(
                            where: { $0.hasItemConformingToTypeIdentifier(UTType.audio.identifier) }
                        ) {
                            p.loadDataRepresentation(
                                forTypeIdentifier: UTType.audio.identifier
                            ) { data, _ in
                                guard let raw = data else { return }
                                let tmp = FileManager.default.temporaryDirectory
                                    .appendingPathComponent(UUID().uuidString)
                                    .appendingPathExtension("m4a")
                                do {
                                    try raw.write(to: tmp)
                                    DispatchQueue.main.async {
                                        store.importSong(from: tmp, artistID: artist.id)
                                        if let newSong = store.artists
                                            .first(where: { $0.id == artist.id })?
                                            .songs.last
                                        {
                                            store.add(songID: newSong.id,
                                                      to: playlist.id,
                                                      for: artist.id)
                                        }
                                    }
                                } catch {
                                    print("❌ temp write failed:", error)
                                }
                            }
                            return true
                        }

                        return false
                    }

                    // — rest of your toolbar, sheets, alerts —
                }
                .navigationTitle(playlist.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(isEditing ? "Done" : "Edit") {
                            isEditing.toggle()
                        }
                    }
                    if isEditing {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu {
                                Button("Rename") {
                                    editName = playlist.name
                                    showRenameAlert = true
                                }
                                Button("Set Cover Image") {
                                    showImagePicker = true
                                }
                                if playlist.name != "All Songs" {
                                    Button("Delete Playlist", role: .destructive) {
                                        store.deletePlaylist(
                                            playlist.id,
                                            for: artist.id
                                        )
                                        dismiss()
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(data: Binding(
                        get: { playlist.artworkData },
                        set: { newData in
                            store.setPlaylistArtwork(
                                newData,
                                for: playlist.id,
                                artistID: artist.id
                            )
                        }
                    ))
                }
                .alert("Rename Playlist", isPresented: $showRenameAlert) {
                    TextField("Playlist Name", text: $editName)
                    Button("Cancel", role: .cancel) {}
                    Button("Save") {
                        if !editName.isEmpty {
                            store.updatePlaylistName(
                                playlist.id,
                                newName: editName,
                                for: artist.id
                            )
                        }
                    }
                } message: {
                    Text("Enter a new name for this playlist.")
                }
            }
        }
    }
    // ────────────────────────────────────────────────────────────
    // MARK: CollaboratorsList
    // ────────────────────────────────────────────────────────────
    private struct CollaboratorsList: View {
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
    
    // ────────────────────────────────────────────────────────────
    // MARK: Custom Tab Components
    // ────────────────────────────────────────────────────────────
    private struct CustomTabBar: View {
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
    
    private struct TabButton: View {
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
    
    // ────────────────────────────────────────────────────────────
    // MARK: Empty-state helper
    // ────────────────────────────────────────────────────────────
    private struct EmptyState: View {
        let icon: String, title: String, message: String
        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text(title).font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 80)
        }
    }
    
    
    
}
