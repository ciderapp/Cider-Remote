import Foundation
import MediaPlayer
import MusicKit

class CurrentMusicService: ObservableObject {
    static let shared = CurrentMusicService()
    
    @Published var currentTrack: CurrentTrack?
    @Published var isPlaying: Bool = false
    @Published var hasMediaAccess: Bool = false
    
    private init() {
        checkMediaPermissions()
        setupNowPlayingObserver()
    }
    
    deinit {
        MPMusicPlayerController.systemMusicPlayer.endGeneratingPlaybackNotifications()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func checkMediaPermissions() {
        let status = MPMediaLibrary.authorizationStatus()
        hasMediaAccess = status == .authorized
        
        if status == .notDetermined {
            MPMediaLibrary.requestAuthorization { [weak self] newStatus in
                DispatchQueue.main.async {
                    self?.hasMediaAccess = newStatus == .authorized
                    if newStatus == .authorized {
                        self?.updateCurrentTrack()
                    }
                }
            }
        }
    }
    
    private func setupNowPlayingObserver() {
        // Enable notifications for system music player
        MPMusicPlayerController.systemMusicPlayer.beginGeneratingPlaybackNotifications()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingInfoDidChange),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: MPMusicPlayerController.systemMusicPlayer
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingInfoDidChange),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: MPMusicPlayerController.systemMusicPlayer
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingInfoDidChange),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: nil
        )
    }
    
    @objc private func nowPlayingInfoDidChange() {
        updateCurrentTrack()
    }
    
    func updateCurrentTrack() {
        guard hasMediaAccess else {
            checkMediaPermissions()
            DispatchQueue.main.async {
                self.currentTrack = nil
                self.isPlaying = false
            }
            return
        }
        
        // Try to get info from the system music player
        let systemMusicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        // First try to get info from system music player
        guard let nowPlayingItem = systemMusicPlayer.nowPlayingItem else {
            // Fallback to MPNowPlayingInfoCenter for apps that use it
            let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
            
            guard let nowPlayingInfo = nowPlayingInfo else {
                DispatchQueue.main.async {
                    self.currentTrack = nil
                    self.isPlaying = false
                }
                return
            }
            
            // Handle MPNowPlayingInfoCenter data
            self.processNowPlayingInfo(nowPlayingInfo)
            return
        }
        
        // Handle MPMediaItem from system music player
        self.processNowPlayingItem(nowPlayingItem, player: systemMusicPlayer)
    }
    
    private func processNowPlayingItem(_ item: MPMediaItem, player: MPMusicPlayerController) {
        let title = item.title ?? "Unknown Title"
        let artist = item.artist ?? "Unknown Artist"
        let album = item.albumTitle ?? "Unknown Album"
        let duration = item.playbackDuration
        let playbackTime = player.currentPlaybackTime
        
        // Get artwork if available
        var artworkData: Data?
        if let artwork = item.artwork {
            let size = CGSize(width: 300, height: 300)
            if size.width > 0 && size.height > 0 && size.width.isFinite && size.height.isFinite {
                let image = artwork.image(at: size)
                artworkData = image?.pngData()
            }
        }
        
        let track = CurrentTrack(
            title: title,
            artist: artist,
            album: album,
            duration: duration.isFinite ? duration : 0,
            currentTime: playbackTime.isFinite ? playbackTime : 0,
            artworkData: artworkData
        )
        
        DispatchQueue.main.async {
            self.currentTrack = track
            self.isPlaying = player.playbackState == .playing
        }
    }
    
    private func processNowPlayingInfo(_ nowPlayingInfo: [String: Any]) {
        let title = nowPlayingInfo[MPMediaItemPropertyTitle] as? String ?? "Unknown Title"
        let artist = nowPlayingInfo[MPMediaItemPropertyArtist] as? String ?? "Unknown Artist"
        let album = nowPlayingInfo[MPMediaItemPropertyAlbumTitle] as? String ?? "Unknown Album"
        let duration = nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double ?? 0
        let playbackTime = nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double ?? 0
        
        // Get artwork if available, with proper dimension validation
        var artworkData: Data?
        if let artwork = nowPlayingInfo[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
            let size = CGSize(width: 300, height: 300)
            // Validate dimensions to prevent "Invalid frame dimension" error
            if size.width > 0 && size.height > 0 && size.width.isFinite && size.height.isFinite {
                let image = artwork.image(at: size)
                artworkData = image?.pngData()
            }
        }
        
        let track = CurrentTrack(
            title: title,
            artist: artist,
            album: album,
            duration: duration.isFinite ? duration : 0,
            currentTime: playbackTime.isFinite ? playbackTime : 0,
            artworkData: artworkData
        )
        
        DispatchQueue.main.async {
            self.currentTrack = track
            self.isPlaying = true // Assume playing if we have info
        }
    }
    
    /// Send the current track to a Cider device
    func sendToCider(device: Device) async -> Bool {
        guard let track = currentTrack else {
            return false
        }
        
        guard track.hasValidData else {
            return false
        }
        
        // Search for the track on Apple Music using Cider's API
        return await searchAndPlayTrack(track: track, device: device)
    }
    
    private func searchAndPlayTrack(track: CurrentTrack, device: Device) async -> Bool {
        do {
            // First, get the storefront
            guard let storefront = await getStorefront(device: device) else {
                return false
            }
            
            // Try multiple search strategies
            let searchStrategies = [
                "\(track.title) \(track.artist)",  // Original approach
                track.title,                       // Title only
                "\"\(track.title)\" \(track.artist)", // Quoted title
                "\(track.artist) \(track.title)"   // Artist first
            ]
            
            // Also try the legacy search API as fallback
            let legacyResult = await tryLegacySearch(track: track, device: device)
            if legacyResult {
                return true
            }
            
            for searchTerm in searchStrategies {
                guard let encodedQuery = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                    continue
                }
                
                let searchPath = "/v1/catalog/\(storefront)/search?term=\(encodedQuery)&types=songs&limit=5"
                let searchData = try await device.runAppleMusicAPI(path: searchPath)
                
                // Parse response structure
                var songData: [[String: Any]] = []
                
                if let searchResult = searchData as? [String: Any] {
                    // Try the correct structure: data.results.songs.data
                    if let data = searchResult["data"] as? [String: Any],
                       let results = data["results"] as? [String: Any],
                       let songs = results["songs"] as? [String: Any],
                       let songsData = songs["data"] as? [[String: Any]] {
                        songData = songsData
                    }
                    // Fallback to old structure: results.songs.data
                    else if let results = searchResult["results"] as? [String: Any],
                            let songs = results["songs"] as? [String: Any],
                            let resultsData = songs["data"] as? [[String: Any]] {
                        songData = resultsData
                    }
                } else if let searchArray = searchData as? [[String: Any]] {
                    songData = searchArray
                }
                
                if !songData.isEmpty {
                    // Look for the best match
                    for song in songData {
                        let songId = song["id"] as? String ?? "unknown"
                        let attributes = song["attributes"] as? [String: Any] ?? [:]
                        let songTitle = attributes["name"] as? String ?? "unknown"
                        let songArtist = attributes["artistName"] as? String ?? "unknown"
                        
                        // Simple matching - if title contains our search term or vice versa
                        if titleMatches(original: track.title, found: songTitle) && 
                           artistMatches(original: track.artist, found: songArtist) {
                            return await playTrack(songId: songId, track: track, device: device)
                        }
                    }
                    
                    // If no exact match, try the first result as fallback
                    if let firstSong = songData.first,
                       let songId = firstSong["id"] as? String {
                        return await playTrack(songId: songId, track: track, device: device)
                    }
                }
            }
            
            return false
        } catch {
            return false
        }
    }
    
    private func tryLegacySearch(track: CurrentTrack, device: Device) async -> Bool {
        do {
            // Try the original search method from the codebase
            let searchData: [String: Any] = [
                "term": "\(track.artist) \(track.title)",
                "types": ["songs"],
                "limit": 5
            ]
            
            let searchResult = try await device.sendRequest(
                endpoint: "amapi/search",
                method: "POST",
                body: searchData
            )
            
            // Parse response similar to the original implementation
            if let resultDict = searchResult as? [String: Any],
               let songs = resultDict["songs"] as? [[String: Any]],
               let firstSong = songs.first,
               let songId = firstSong["id"] as? String {
                
                return await playTrack(songId: songId, track: track, device: device)
            }
            
        } catch {
            // Legacy search failed, continue with other methods
        }
        
        return false
    }
    
    private func titleMatches(original: String, found: String) -> Bool {
        let cleaningSet = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let originalClean = original.lowercased().trimmingCharacters(in: cleaningSet)
        let foundClean = found.lowercased().trimmingCharacters(in: cleaningSet)
        
        return originalClean.contains(foundClean) || foundClean.contains(originalClean) || 
               originalClean == foundClean
    }
    
    private func artistMatches(original: String, found: String) -> Bool {
        let cleaningSet = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let originalClean = original.lowercased().trimmingCharacters(in: cleaningSet)
        let foundClean = found.lowercased().trimmingCharacters(in: cleaningSet)
        
        return originalClean.contains(foundClean) || foundClean.contains(originalClean) || 
               originalClean == foundClean
    }
    
    private func playTrack(songId: String, track: CurrentTrack, device: Device) async -> Bool {
        do {
            // First get the song's href URL which is needed for play-item-href
            let songHref = "/v1/catalog/in/songs/\(songId)"
            
            // Clear the current queue to ensure our song plays
            do {
                _ = try await device.sendRequest(
                    endpoint: "playback/queue/clear-queue",
                    method: "POST"
                )
            } catch {
                // Continue anyway if queue clear fails
            }
            
            // Use play-item-href to start the new song
            _ = try await device.sendRequest(
                endpoint: "playback/play-item-href",
                method: "POST",
                body: ["href": songHref]
            )
            
            // Wait for the song to load and start
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Seek to the correct position if needed
            if track.currentTime > 0 {
                let seekData: [String: Any] = ["position": track.currentTime]
                do {
                    _ = try await device.sendRequest(
                        endpoint: "playback/seek",
                        method: "POST",
                        body: seekData
                    )
                } catch {
                    // Continue anyway if seek fails
                }
            }
            
            return true
        } catch {
            return false
        }
    }
    
    private func getStorefront(device: Device) async -> String? {
        do {
            let data = try await device.runAppleMusicAPI(path: "/v1/me/storefront?limit=1")
            
            guard let storefrontData = data as? [[String: Any]],
                  let firstStorefront = storefrontData.first,
                  let storefrontId = firstStorefront["id"] as? String else {
                return nil
            }
            
            return storefrontId
        } catch {
            return nil
        }
    }
}

/// Represents the current track playing on the device
struct CurrentTrack {
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let currentTime: Double
    let artworkData: Data?
    
    var hasValidData: Bool {
        return !title.isEmpty && !artist.isEmpty && title != "Unknown Title"
    }
}