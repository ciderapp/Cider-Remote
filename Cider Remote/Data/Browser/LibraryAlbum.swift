// Made by Lumaa

import Foundation

struct LibraryAlbum: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let artwork: String

    var tracks: [LibraryTrack]? = nil

    init(id: String, title: String, artist: String, artwork: String) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artwork = artwork
    }

    init(data: [String: Any]) {
        let attributes: [String: Any] = data["attributes"] as! [String: Any]

        self.id = data["id"] as! String
        self.title = attributes["name"] as! String
        self.artist = attributes["artistName"] as! String

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
