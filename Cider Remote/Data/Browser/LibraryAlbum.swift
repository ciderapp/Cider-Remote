// Made by Lumaa

import Foundation

struct LibraryAlbum: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let artwork: String
    var audioType: Track.AudioType = .unknown

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

    func getAnimatedCover(using device: Device, size: Self.AnimatedCover = .square) async -> (URL?, Track.AudioType) {
        do {
            guard let data = try await device.runAppleMusicAPI(path: "/v1/me/library/albums/\(self.id)/catalog?extend=editorialVideo") as? [[String: Any]] else {
                return (nil, .unknown)
            }
            
            if let attributes: [String: Any] = data[0]["attributes"] as? [String: Any] {
                print(attributes)

                var audio: Track.AudioType = .unknown
                if let audioTraits: [String] = attributes["audioTraits"] as? [String] {
                    print(audioTraits)
                    audio = Track.AudioType.find(audioTraits)
                }

                if let videos: [String: Any] = attributes["editorialVideo"] as? [String: Any], let squareObj: [String: Any] = videos[size.rawValue] as? [String: Any], let squareStr: String = squareObj["video"] as? String {
                    return (URL(string: squareStr), audio)
                } else {
                    return (nil, audio)
                }
            }

            return (nil, .unknown)
        } catch {
            print("Error getting album details: \(error)")
            return (nil, .unknown)
        }
    }

    enum AnimatedCover: String {
        case square = "motionDetailSquare"
        case tall = "motionDetailTall"

        var px: CGSize {
            switch self {
                case .square:
                    return .init(width: 3840, height: 3840)
                case .tall:
                    return .init(width: 2048, height: 2732)
            }
        }

        var ratio: CGFloat {
            return self.px.width / self.px.height
        }
    }
}
