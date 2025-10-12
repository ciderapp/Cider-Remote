// Made by Lumaa

import Foundation

struct LibraryPlaylist: Identifiable, Hashable {
    let id: String

    let name: String
    let artwork: String

    var tracks: [LibraryTrack]? = nil

    init(id: String, name: String, artwork: String) {
        self.id = id
        self.name = name
        self.artwork = artwork
    }

    init(data: [String: Any]) {
        let attributes: [String: Any] = data["attributes"] as! [String: Any]
        let playParams: [String: Any] = attributes["playParams"] as! [String: Any]

        self.id = playParams["id"] as? String ?? data["id"] as! String // use all IDs known to fucking AM
        self.name = attributes["name"] as! String

        if let artwork: [String: Any] = attributes["artwork"] as? [String: Any] {
            if let w = artwork["width"] as? Int {
                self.artwork = (artwork["url"] as! String).replacing(/\{(w|h)\}/, with: "\(w)")
            } else {
                self.artwork = (artwork["url"] as! String).replacing(/\{(w|h)\}/, with: "\(700)")
            }
        } else {
            self.artwork = ""
        }
    }
}
