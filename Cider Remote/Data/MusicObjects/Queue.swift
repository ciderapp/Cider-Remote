// Made by Lumaa

import Foundation

struct Queue {
    var tracks: [Track]
    let source: Self.Source?

    private(set) var offset: Int = -1

    init(tracks: [Track], source: Self.Source? = nil) {
        self.tracks = tracks
        self.source = source
    }

    struct Source {
        let name: String
        let artworkURL: URL?
        let type: String
    }

	/// Use only for v1 endpoint, helps defining the `offset`, and then find all the next tracks
    mutating func defineCurrent(track: Track) {
        guard let index = self.tracks.firstIndex(where: { $0.id == track.id }), self.tracks.count > 1 else { return }
        
        if index == self.tracks.count - 1 {
            self.tracks = []
            self.offset = self.tracks.count
            return
        }

        let fx = self.tracks[index + 1...max(self.tracks.count - 1, index + 1)]
        self.tracks = Array(fx)
        self.offset = index + 1
    }

	/// Use only for v2, fetches the `offset` from `GET /queue/position`, then fetches all tracks using `offset` query in `GET /queue`
	mutating func fetchCurrent(device: Device, fetchQueue: Bool = true) async throws {
		guard device.useV2 else { throw NetworkError.invalidURL }

		guard let reqRes: [String: Any] = try await device.sendRequest(endpoint: "queue/position") as? [String: Any] else { throw NetworkError.invalidResponse }
		let data: Data = try JSONSerialization.data(withJSONObject: reqRes)
		let pos = try JSONDecoder().decode(QueuePosition.self, from: data)

		if pos.position >= pos.total - 1 {
			self.tracks = []
			self.offset = pos.total
			return
		}

		self.offset = pos.position
		if fetchQueue {
			guard let queue: [[String: Any]] = (try await device.sendRequest(endpoint: "queue", queries: [.init(name: "limit", value: "20"), .init(name: "offset", value: "\(pos.position + 1)")]) as? [String: Any])?["items"] as? [[String: Any]] else {
				throw NetworkError.invalidResponse
			} // this is so ass code for real TODO: fix this shit next version with actual `Codable`s

			self.tracks = queue.compactMap { getTrack(using: $0) }
		} else {
			let fx = self.tracks[pos.position + 1...max(self.tracks.count - 1, pos.position + 1)]
			self.tracks = Array(fx)
		}
	}

    mutating func remove(set: IndexSet) {
        guard let first = set.first, let last = set.last else { return }

        self.tracks.remove(atOffsets: IndexSet(integersIn: first + offset...last + offset))
    }

    mutating func move(from: IndexSet, to: Int) {
        guard let first = from.first, let last = from.last else { return }

        print("first: \(first + offset)")
        print("last: \(last + offset)")

        print("to: \(to + offset)")
        self.tracks.move(fromOffsets: IndexSet(integersIn: (first + offset)...(last + offset)), toOffset: to + offset)
    }

    func firstIndex(of track: Track) -> Int {
        guard let i = tracks.firstIndex(of: track) else { return -1 }
        return i + offset
    }

	private func getTrack(using info: [String: Any]) -> Track? {
		guard let attributes = (info["track"] as? [String : Any])?["attributes"] as? [String: Any] else { return nil }

		let id = (info["track"] as? [String : Any])?["id"] as? String ?? ""
		let title = attributes["name"] as? String ?? ""
		let artist = attributes["artistName"] as? String ?? ""
		let album = attributes["albumName"] as? String ?? ""
		let duration = attributes["durationInMillis"] as? Double ?? 0

		if let artwork = attributes["artwork"] as? [String: Any],
		   var artworkUrl = artwork["url"] as? String {
			// Replace placeholders in artwork URL
			artworkUrl = artworkUrl.replacingOccurrences(of: "{w}", with: "1024")
			artworkUrl = artworkUrl.replacingOccurrences(of: "{h}", with: "1024")

			return Track(id: id,
						 catalogId: id,
						 title: title,
						 artist: artist,
						 album: album,
						 artwork: artworkUrl,
						 duration: duration / 1000,
						 artworkData: Data()
			)
		} else {
			return Track(id: id,
						 catalogId: id,
						 title: title,
						 artist: artist,
						 album: album,
						 artwork: "",
						 duration: duration / 1000,
						 artworkData: Data()
			)
		}
	}
}
