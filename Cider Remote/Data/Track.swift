// Made by Lumaa

import Foundation
import UIKit

struct Track: Codable, Equatable {
    let id: String
    let catalogId: String
    let title: String
    let artist: String
    let album: String
    let artwork: String
    let duration: Double
    var artworkData: Data
    var songHref: String? = nil

    init(
        id: String,
        catalogId: String,
        title: String,
        artist: String,
        album: String,
        artwork: String,
        duration: Double,
        artworkData: Data,
        songHref: String? = nil
    ) {
        self.id = id
        self.catalogId = catalogId
        self.title = title
        self.artist = artist
        self.album = album
        self.artwork = artwork
        self.duration = duration
        self.artworkData = artworkData
        self.songHref = songHref
    }

    init(from library: LibraryTrack) {
        self.id = library.id
        self.catalogId = library.catalogId
        self.title = library.name
        self.artist = library.artist
        self.album = library.album?.title ?? library.name
        self.artwork = library.album?.artwork ?? library.artwork
        self.duration = 0.0
        self.artworkData = Data()
        self.songHref = library.href
    }

    mutating func getArtwork() async -> UIImage? {
        do {
            let url: URL = URL(string: self.artwork)!
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                self.artworkData = data
                return image
            }
        } catch {
            print("Error loading image: \(error)")
        }
        return nil
    }

    func getArtworkLocally() -> UIImage {
        return UIImage(data: self.artworkData) ?? UIImage.logo
    }

    mutating func setArtworkData() async {
        if let (data, _) = try? await URLSession.shared.data(from: URL(string: self.artwork)!) {
            self.artworkData = data
        }
    }

    struct RequestLyrics: Identifiable, Encodable {
        let id: String
        let name: String
        let artist: String
        let album: String
        let duration: Int
        let richSync: Bool

        init(id: String, name: String, artist: String, album: String, duration: Int, richSync: Bool = false) {
            self.id = id
            self.name = name
            self.artist = artist
            self.album = album
            self.duration = duration
            self.richSync = richSync
        }

        init(track: Track, richSync: Bool = false) {
            self.id = track.id
            self.name = track.title
            self.artist = track.artist
            self.album = track.album
            self.duration = Int(track.duration.rounded())
            self.richSync = richSync
        }

        enum CodingKeys: CodingKey {
            case id
            case name
            case artist
            case album
            case duration
            case richSync
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: Track.RequestLyrics.CodingKeys.self)
            try container.encode(self.id, forKey: Track.RequestLyrics.CodingKeys.id)
            try container.encode(self.name, forKey: Track.RequestLyrics.CodingKeys.name)
            try container.encode(self.artist, forKey: Track.RequestLyrics.CodingKeys.artist)
            try container.encode(self.album, forKey: Track.RequestLyrics.CodingKeys.album)
            try container.encode(self.duration, forKey: Track.RequestLyrics.CodingKeys.duration)
            try container.encode(self.richSync, forKey: Track.RequestLyrics.CodingKeys.richSync)
        }
    }

    struct MxmLyrics: Decodable {
        let body: String // html
        let type: String // Line or Word
        let language: String
        let writers: [String]
        let cached: Bool?

        enum CodingKeys: CodingKey {
            case body
            case type
            case language
            case writers
            case cached
        }

        init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<Track.MxmLyrics.CodingKeys> = try decoder.container(
                keyedBy: Track.MxmLyrics.CodingKeys.self
            )
            self.body = try container.decode(String.self, forKey: Track.MxmLyrics.CodingKeys.body)
            self.type = try container.decode(String.self, forKey: Track.MxmLyrics.CodingKeys.type)
            self.language = try container.decode(String.self, forKey: Track.MxmLyrics.CodingKeys.language)
            self.writers = try container.decode([String].self, forKey: Track.MxmLyrics.CodingKeys.writers)
            self.cached = try container.decodeIfPresent(Bool.self, forKey: Track.MxmLyrics.CodingKeys.cached)
        }

        func decodeHtml() -> [LyricLine] {
            guard let data = self.body.data(using: .utf8) else { return [] }
            let xmlParser = XMLParser(data: data)
            let ttmlParser = Parser(provider: .mxm)
            xmlParser.delegate = ttmlParser
            xmlParser.parse()
            return ttmlParser.lyrics
        }

        private func decodeHtml() -> [(start: Double, end: Double, line: String)]? {
            guard let p = self.body.matches(of: /<p .+<\/p>/).first else { return nil }

            print()
            let timeCodes = String("\(p.0)").matches(of: /[a-z]+=\\"[\d:\.]+\\"/)
            let beginStr = timeCodes.filter({ String("\($0.0)").starts(with: "begin") }).map { "\($0)" }
            let endStr = timeCodes.filter({ String("\($0.0)").starts(with: "end") }).map { "\($0)" }

            let beginDouble = beginStr.compactMap { self.toSeconds(using: $0) }
            let endDouble = endStr.compactMap { self.toSeconds(using: $0) }

            guard !(beginDouble.isEmpty || endDouble.isEmpty) else { return nil }

            let lyricsMatches = String("\(p)").matches(of: /<p[^>]*>(.*?)<\/p>/)
            let lyrics = lyricsMatches.compactMap {
                "\($0.output.1)"
            }

            var final: [(start: Double, end: Double, line: String)] = []
            for lyric in lyrics {
                guard let i: Int = lyrics.firstIndex(of: lyric) else { return nil }

                let b: Double = beginDouble[i]
                let e: Double = endDouble[i]

                final.append((start: b, end: e, line: lyric))
            }

            return final
        }

        private func toSeconds(using time: String) -> Double? {
            print("doing stuff with \(time)")
            let components = time.split(separator: ":")
            guard components.count == 3, let hours = Double(components[0]), let minutes = Double(components[1]), let seconds = Double(components[2]) else { return nil }

            return hours * 3600 + minutes * 60 + seconds
        }
    }
}

/*
 {
 "body": "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<tt xmlns=\"http://www.w3.org/ns/ttml\" xmlns:tts=\"http://www.w3.org/ns/ttml\" xml:lang=\"en\">\n <body>\n  <div xml:lang=\"en\">\n   <p begin=\"00:00:07.300\" end=\"00:00:10.690\">Darling, I'm with St. Bernard's</p>\n   <p begin=\"00:00:10.690\" end=\"00:00:14.260\">And we are scouring the Alps and the Andes</p>\n   <p begin=\"00:00:14.260\" end=\"00:00:17.980\">And if they die, then it is on my head</p>\n   <p begin=\"00:00:17.980\" end=\"00:00:20.770\">They followed paw prints in the snow</p>\n   <p begin=\"00:00:20.770\" end=\"00:00:22.220\">To my throne, to my bed</p>\n   <p begin=\"00:00:22.220\" end=\"00:00:23.920\">You're pouting in your sleep</p>\n   <p begin=\"00:00:23.920\" end=\"00:00:25.870\">I'm waking, still yawning</p>\n   <p begin=\"00:00:25.870\" end=\"00:00:30.060\">We're proving to each other that romance is boring</p>\n   <p begin=\"00:00:30.060\" end=\"00:00:31.940\">Sure, there are things I could do</p>\n   <p begin=\"00:00:31.940\" end=\"00:00:33.560\">If I was half prepared to</p>\n   <p begin=\"00:00:33.560\" end=\"00:00:37.150\">Prove to each other that romance is boring</p>\n   <p begin=\"00:00:37.150\" end=\"00:00:46.710\"></p>\n   <p begin=\"00:00:46.710\" end=\"00:00:49.560\">Start as you mean to continue</p>\n   <p begin=\"00:00:49.560\" end=\"00:00:51.480\">Complacent and self-involved</p>\n   <p begin=\"00:00:51.480\" end=\"00:00:54.160\">You're trying not to be nervous</p>\n   <p begin=\"00:00:54.160\" end=\"00:00:56.050\">If you are trying at all</p>\n   <p begin=\"00:00:56.050\" end=\"00:00:58.930\">I will wait, I will bake phallic cake</p>\n   <p begin=\"00:00:58.930\" end=\"00:01:02.540\">Take your diffidence, make it my clubhouse</p>\n   <p begin=\"00:01:02.540\" end=\"00:01:04.600\">But my strength's within lies</p>\n   <p begin=\"00:01:04.600\" end=\"00:01:06.480\">Ventricle cauterized</p>\n   <p begin=\"00:01:06.480\" end=\"00:01:10.540\">It's the way of living that I espouse</p>\n   <p begin=\"00:01:10.540\" end=\"00:01:12.100\">You're pouting in your sleep</p>\n   <p begin=\"00:01:12.100\" end=\"00:01:14.030\">I'm waking, still yawning</p>\n   <p begin=\"00:01:14.030\" end=\"00:01:18.580\">We're proving to each other that romance is boring</p>\n   <p begin=\"00:01:18.580\" end=\"00:01:20.010\">Sure, there are things I could do</p>\n   <p begin=\"00:01:20.010\" end=\"00:01:22.160\">If I was half prepared to</p>\n   <p begin=\"00:01:22.160\" end=\"00:01:25.940\">Prove to each other that romance is boring</p>\n   <p begin=\"00:01:25.940\" end=\"00:01:59.150\"></p>\n   <p begin=\"00:01:59.150\" end=\"00:02:02.760\">We are two ships that pass in the night</p>\n   <p begin=\"00:02:02.760\" end=\"00:02:06.520\">You and I, we are nothing alike</p>\n   <p begin=\"00:02:06.520\" end=\"00:02:08.050\">I am a pleasure cruise</p>\n   <p begin=\"00:02:08.050\" end=\"00:02:09.530\">You are gone out to trawl</p>\n   <p begin=\"00:02:09.530\" end=\"00:02:11.020\">Return nets empty</p>\n   <p begin=\"00:02:11.020\" end=\"00:02:12.340\">Nothing there at all</p>\n   <p begin=\"00:02:12.340\" end=\"00:02:13.900\">You're pouting in your sleep</p>\n   <p begin=\"00:02:13.900\" end=\"00:02:15.910\">I'm waking, still yawning</p>\n   <p begin=\"00:02:15.910\" end=\"00:02:20.120\">We're proving to each other that romance is boring</p>\n   <p begin=\"00:02:20.120\" end=\"00:02:22.020\">Sure, there are things I could do</p>\n   <p begin=\"00:02:22.020\" end=\"00:02:23.530\">If I was half prepared to</p>\n   <p begin=\"00:02:23.530\" end=\"00:02:28.500\">Prove to each other that romance is boring</p>\n  </div>\n </body>\n</tt>\n",
 "type": "Line",
 "language": "en",
 "writers": [
 "Gareth Paisey",
 " Thomas Bromley"
 ],
 "internalVersion": ""
 }
 */

// ([a-z]+=\\"(\d|:|\.)+\\")
// <p .+<\/p>
// [\d:\.]+
