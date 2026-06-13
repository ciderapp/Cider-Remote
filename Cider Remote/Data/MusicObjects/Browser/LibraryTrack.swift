// Made by Lumaa

import Foundation

struct LibraryTrack: Identifiable, Hashable {
    let id: String

    let name: String
    let artist: String
    let album: LibraryAlbum?
    let artwork: String

    let discNumber: Int
    let trackNumber: Int

    let catalogId: String

    var href: String {
        "/v1/me/library/songs/\(self.id)"
    }

    init(
        id: String,
        name: String,
        artist: String,
        artwork: String,
        album: LibraryAlbum? = nil,
        discNumber: Int = 1,
        trackNumber: Int,
        catalogId: String
    ) {
        self.id = id
        self.name = name
        self.artist = artist
        self.artwork = artwork
        self.album = album
        self.discNumber = discNumber
        self.trackNumber = trackNumber
        self.catalogId = catalogId
    }

    init(data: [String: Any], from album: LibraryAlbum? = nil) {
        let attributes: [String: Any] = data["attributes"] as! [String: Any]
        let playParams: [String: Any]? = attributes["playParams"] as? [String: Any]
    
        self.album = album

        self.id = data["id"] as! String
        self.name = attributes["name"] as! String
        self.artist = attributes["artistName"] as! String

        self.discNumber = attributes["discNumber"] as! Int
        self.trackNumber = attributes["trackNumber"] as! Int

        if let playParams {
            self.catalogId = (playParams["catalogId"] as? String) ?? "[LOCAL]"
        } else {
            self.catalogId = "[UNKNOWN]"
        }

        if let artwork: [String: Any] = attributes["artwork"] as? [String: Any] {
            if let w = artwork["width"] as? Int {
                self.artwork = (artwork["url"] as! String).replacing(/\{(w|h)\}/, with: "\(w)")
            } else {
                self.artwork = (artwork["url"] as! String).replacing(/\{(w|h)\}/, with: "\(700)")
            }
        } else {
            self.artwork = "[NONE]"
        }
    }
}
