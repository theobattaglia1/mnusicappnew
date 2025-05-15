//
//  SongListUIKitBridge.swift
//  ArtistMusic
//
//  Created by Theo Battaglia on 5/15/25.
//


import SwiftUI
import UIKit

// This class will handle the UIKit representation of our song list
class SongListTableViewController: UITableViewController {
    var songs: [Song] = []
    var artist: Artist?
    var onSongTap: ((Song) -> Void)?
    var onArtTap: ((UUID) -> Void)?
    var onEditTap: ((Song) -> Void)?
    var onAddToPlaylist: ((Song, UUID) -> Void)?
    var playlists: [Playlist] = []
    var selectedSongID: UUID?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .systemBackground
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 70, bottom: 0, right: 0)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 70
        tableView.register(SongTableCell.self, forCellReuseIdentifier: "SongCell")
        tableView.allowsSelection = true
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songs.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SongCell", for: indexPath) as! SongTableCell
        
        let song = songs[indexPath.row]
        cell.configure(with: song, isSelected: song.id == selectedSongID)
        
        // Setup tap handlers
        cell.playButton.addTarget(self, action: #selector(playButtonTapped(_:)), for: .touchUpInside)
        cell.playButton.tag = indexPath.row
        
        cell.artworkView.tag = indexPath.row
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(artworkTapped(_:)))
        cell.artworkView.addGestureRecognizer(tapGesture)
        cell.artworkView.isUserInteractionEnabled = true
        
        cell.menuButton.tag = indexPath.row
        cell.menuButton.addTarget(self, action: #selector(showMenu(_:)), for: .touchUpInside)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let song = songs[indexPath.row]
        selectedSongID = song.id
        tableView.reloadData() // Update selection state
        onSongTap?(song)
    }
    
    @objc func playButtonTapped(_ sender: UIButton) {
        let song = songs[sender.tag]
        selectedSongID = song.id
        tableView.reloadData()
        onSongTap?(song)
    }
    
    @objc func artworkTapped(_ sender: UITapGestureRecognizer) {
        if let view = sender.view, let songID = songs[safe: view.tag]?.id {
            onArtTap?(songID)
        }
    }
    
    @objc func showMenu(_ sender: UIButton) {
        guard let song = songs[safe: sender.tag] else { return }
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Play Action
        alertController.addAction(UIAlertAction(title: "Play", style: .default) { [weak self] _ in
            self?.selectedSongID = song.id
            self?.tableView.reloadData()
            self?.onSongTap?(song)
        })
        
        // Edit Action
        alertController.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
            self?.onEditTap?(song)
        })
        
        // Add to Playlist Actions
        if !playlists.isEmpty {
            let playlistsAction = UIAlertAction(title: "Add to Playlist", style: .default) { [weak self] _ in
                // Show playlist selection
                let playlistPicker = UIAlertController(title: "Select Playlist", message: nil, preferredStyle: .actionSheet)
                
                for playlist in self?.playlists ?? [] {
                    if playlist.name != "All Songs" {
                        playlistPicker.addAction(UIAlertAction(title: playlist.name, style: .default) { _ in
                            self?.onAddToPlaylist?(song, playlist.id)
                        })
                    }
                }
                
                playlistPicker.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                
                // Present the playlist picker
                if let self = self, let presenter = self.presentedViewController {
                    presenter.present(playlistPicker, animated: true)
                } else {
                    self?.present(playlistPicker, animated: true)
                }
            }
            alertController.addAction(playlistsAction)
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = sender
            popoverController.sourceRect = sender.bounds
        }
        
        present(alertController, animated: true)
    }
}

// Custom cell for songs
class SongTableCell: UITableViewCell {
    // Cell components
    let artworkView = UIImageView()
    let titleLabel = UILabel()
    let versionLabel = UILabel()
    let creatorsLabel = UILabel()
    let playButton = UIButton(type: .system)
    let menuButton = UIButton(type: .system)
    let containerView = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Container setup
        contentView.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
        containerView.layer.cornerRadius = 8
        
        // Artwork setup
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        artworkView.contentMode = .scaleAspectFill
        artworkView.layer.cornerRadius = 6
        artworkView.clipsToBounds = true
        artworkView.backgroundColor = UIColor.secondarySystemFill
        containerView.addSubview(artworkView)
        
        // Labels setup
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        containerView.addSubview(titleLabel)
        
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        versionLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        versionLabel.textColor = .secondaryLabel
        containerView.addSubview(versionLabel)
        
        creatorsLabel.translatesAutoresizingMaskIntoConstraints = false
        creatorsLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
        creatorsLabel.textColor = .secondaryLabel
        containerView.addSubview(creatorsLabel)
        
        // Button setup
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        playButton.tintColor = .systemBlue
        containerView.addSubview(playButton)
        
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        menuButton.tintColor = .secondaryLabel
        containerView.addSubview(menuButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            artworkView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            artworkView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            artworkView.widthAnchor.constraint(equalToConstant: 50),
            artworkView.heightAnchor.constraint(equalToConstant: 50),
            
            titleLabel.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: playButton.leadingAnchor, constant: -8),
            
            versionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            versionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            versionLabel.trailingAnchor.constraint(lessThanOrEqualTo: playButton.leadingAnchor, constant: -8),
            
            creatorsLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            creatorsLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 2),
            creatorsLabel.trailingAnchor.constraint(lessThanOrEqualTo: playButton.leadingAnchor, constant: -8),
            creatorsLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -8),
            
            playButton.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -8),
            playButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 44),
            playButton.heightAnchor.constraint(equalToConstant: 44),
            
            menuButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            menuButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 30),
            menuButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Selected state appearance
        selectionStyle = .none
    }
    
    func configure(with song: Song, isSelected: Bool) {
        titleLabel.text = song.title
        versionLabel.text = song.version.isEmpty ? "Version: Unknown" : song.version
        creatorsLabel.text = song.creators.joined(separator: ", ")
        
        // Artwork
        if let data = song.artworkData, let image = UIImage(data: data) {
            artworkView.image = image
        } else {
            // Default artwork with music note
            let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            artworkView.image = UIImage(systemName: "music.note", withConfiguration: config)
            artworkView.tintColor = .secondaryLabel
            artworkView.contentMode = .center
            artworkView.backgroundColor = UIColor.secondarySystemFill
        }
        
        // Selection state
        containerView.backgroundColor = isSelected ? UIColor.systemBlue.withAlphaComponent(0.1) : .clear
        playButton.alpha = isSelected ? 1.0 : 0.7
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        artworkView.image = nil
        containerView.backgroundColor = .clear
    }
}

// MARK: - SwiftUI Bridge
struct SongListUIKitBridge: UIViewControllerRepresentable {
    var songs: [Song]
    var artist: Artist
    var playlists: [Playlist]
    var selectedSongID: UUID?
    var onSongTap: (Song) -> Void
    var onArtTap: (UUID) -> Void
    var onEditTap: (Song) -> Void
    var onAddToPlaylist: (Song, UUID) -> Void
    
    func makeUIViewController(context: Context) -> SongListTableViewController {
        let controller = SongListTableViewController()
        controller.songs = songs
        controller.artist = artist
        controller.playlists = playlists
        controller.selectedSongID = selectedSongID
        controller.onSongTap = onSongTap
        controller.onArtTap = onArtTap
        controller.onEditTap = onEditTap
        controller.onAddToPlaylist = onAddToPlaylist
        return controller
    }
    
    func updateUIViewController(_ uiViewController: SongListTableViewController, context: Context) {
        uiViewController.songs = songs
        uiViewController.playlists = playlists
        uiViewController.selectedSongID = selectedSongID
        uiViewController.tableView.reloadData()
    }
}

// Helper extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
