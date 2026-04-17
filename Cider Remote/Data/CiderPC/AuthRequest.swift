// Made by Lumaa

import Foundation

struct AuthRequest: Encodable {
	let name: String
	let image: URL?
	let scopes: [Self.Scopes]

	init(name: String, image: URL? = nil, scopes: [Self.Scopes]) {
		self.name = name
		self.image = image
		self.scopes = scopes
	}

	init(name: String, image: String? = nil, scopes: [Self.Scopes]) {
		self.name = name
		self.image = image != nil ? URL(string: image!) : nil
		self.scopes = scopes
	}

	struct Result: Decodable {
		let token: String
		let scopes: [AuthRequest.Scopes]

		init(token: String, scopes: [AuthRequest.Scopes]) {
			self.token = token
			self.scopes = scopes
		}

		init(from decoder: any Decoder) throws {
			let container: KeyedDecodingContainer<Self.CodingKeys> = try decoder.container(keyedBy: Self.CodingKeys.self)
			self.token = try container.decode(String.self, forKey: AuthRequest.Result.CodingKeys.token)
			self.scopes = try container.decode([AuthRequest.Scopes].self, forKey: AuthRequest.Result.CodingKeys.scopes)
		}

		enum CodingKeys: CodingKey {
			case token
			case scopes
		}
	}

	func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: Self.CodingKeys.self)
		try container.encode(self.name, forKey: .name)
		try container.encodeIfPresent(self.image, forKey: .image)
		try container.encode(self.scopes, forKey: .scopes)
	}

	enum CodingKeys: String, CodingKey {
		case name = "app_name"
		case image = "app_image"
		case scopes = "scopes"
	}

	enum Scopes: String, Codable {
		case playback
		case queue
		case library
		case audio
	}

	enum Error: String, Decodable, CaseIterable {
		/// Body shape bad, unknown scope, or empty scopes array
		case invalid = "INVALID_REQUEST"

		/// User clicked Deny
		case denied = "AUTH_REQUEST_DENIED"

		/// 2 min elapsed without user action
		case timeout = "AUTH_REQUEST_TIMEOUT"

		/// Another auth dialog is already pending
		case busy = "AUTH_REQUEST_BUSY"

		/// Rate limit (see `Retry-After` header)
		case cooldown = "AUTH_REQUEST_COOLDOWN"

		/// Rate limit (see `Retry-After` header)
		case banned = "AUTH_REQUEST_BANNED"

		var code: Int {
			switch self {
				case .invalid:
					return 400
				case .denied:
					return 403
				case .timeout:
					return 408
				case .busy:
					return 409
				case .cooldown, .banned:
					return 429
			}
		}

		var description: String {
			switch self {
				case .invalid:
					"Authentication request is invalid, contact Cider Collective to fix this issue."
				case .denied:
					"You have denied the authentication request"
				case .timeout:
					"The authentication request expired"
				case .busy:
					"You are already authenticating a third-party service"
				case .cooldown, .banned:
					"Can you slow down? Try again in 5 minutes..."
			}
		}

		static func matchCode(with code: Int) -> Self? {
			return self.allCases.filter { $0.code == code }.first
		}
	}
}

fileprivate struct CompleteResponse: Decodable {
	let data: CiderClient

	private init(data: CiderClient) {
		self.data = data
	}

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.data = try container.decode(CiderClient.self, forKey: .data)
	}

	enum CodingKeys: CodingKey {
		case data
	}
}

extension AuthRequest {
	static var remoteRequest: AuthRequest {
		return .init(name: "Cider Remote", image: .remoteImage, scopes: [.playback, .queue, .audio, .library])
	}
}

extension AuthRequest.Result {
	func getConnection() async throws -> ConnectionInfo {
		guard let url = URL(string: "http://localhost:\(Int.defaultPort)/api/v2/client/info") else { throw NetworkError.invalidURL }

		var request = URLRequest(url: url)
		request.addValue(self.token, forHTTPHeaderField: "apptoken")

		let response: (Data, URLResponse) = try await URLSession.shared.data(for: request)
		if let http: HTTPURLResponse = response.1 as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
			throw NetworkError.serverError(String(data: response.0, encoding: .utf8) ?? "*No data*")
		}

		if let clientResponse: CompleteResponse = try? JSONDecoder().decode(CompleteResponse.self, from: response.0) {
			return .init(from: clientResponse.data, using: self)
		}
		throw NetworkError.invalidResponse
	}
}

extension URL {
	static var remoteImage: URL? {
		return URL(string: "https://files.lumaa.fr/api/1024x1024.png") // temp path until cider.sh includes it :pray:
	}
}
