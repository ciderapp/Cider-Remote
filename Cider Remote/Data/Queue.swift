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
	mutating func fetchCurrent(device: Device) async {
		guard device.useV2 else { return }

		
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
}
