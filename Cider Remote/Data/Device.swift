// Made by Lumaa

import SwiftUI
import Foundation
import Combine
import AppIntents

class Device: Identifiable, Codable, ObservableObject, Hashable {
    let id: UUID
    let host: String
    let token: String
    let friendlyName: String
    let creationTime: Int
    let version: String
	let platform: CiderClient.Framework
	/// = platform "for now"
    let backend: CiderClient.Framework
    let os: CiderClient.Platform?
	let connectionMethod: ConnectionMethod

    @Published var isActive: Bool = false
    @Published var isRefreshing: Bool = false
	@Published var client: CiderClient? = nil

	var useV2: Bool {
		return self.client?.useV2 ?? true
	}

    enum CodingKeys: String, CodingKey {
        case id, host, token, friendlyName, creationTime, version, platform, backend, isActive, connectionMethod, os
    }

	init(
		id: UUID = UUID(),
		host: String,
		token: String,
		friendlyName: String,
		creationTime: Int,
		version: String,
		platform: CiderClient.Framework,
		backend: CiderClient.Framework,
		connectionMethod: ConnectionMethod,
		isActive: Bool = false,
		os: CiderClient.Platform? = nil
	) {
        self.id = id
        self.host = host
        self.token = token
        self.friendlyName = friendlyName
        self.creationTime = creationTime
        self.version = version
        self.platform = platform
        self.backend = backend
        self.connectionMethod = connectionMethod
        self.isActive = isActive
        self.os = os
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode with fallbacks for optional fields
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        host = try container.decode(String.self, forKey: .host)
        token = try container.decode(String.self, forKey: .token)
        friendlyName = try container.decode(String.self, forKey: .friendlyName)
        creationTime = try container.decode(Int.self, forKey: .creationTime)
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "Unknown"
		platform = try container.decodeIfPresent(CiderClient.Framework.self, forKey: .platform) ?? .unknown
		backend = try container.decodeIfPresent(CiderClient.Framework.self, forKey: .backend) ?? .unknown

        // For connectionMethod, use "lan" as default if not present
		connectionMethod = try container.decodeIfPresent(ConnectionMethod.self, forKey: .connectionMethod) ?? .lan

        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
		os = try container.decodeIfPresent(CiderClient.Platform.self, forKey: .os)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(host, forKey: .host)
        try container.encode(token, forKey: .token)
        try container.encode(friendlyName, forKey: .friendlyName)
        try container.encode(creationTime, forKey: .creationTime)
        try container.encode(version, forKey: .version)
        try container.encode(platform, forKey: .platform)
        try container.encode(backend, forKey: .backend)
        try container.encode(connectionMethod, forKey: .connectionMethod)
        try container.encode(isActive, forKey: .isActive)
        try container.encodeIfPresent(os, forKey: .os)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Device, rhs: Device) -> Bool {
        lhs.id == rhs.id
    }

    var fullAddress: String {
        switch connectionMethod {
			case .tunnel:
				return "https://\(host)"
			default: // "lan" or any other value
				return "http://\(host):10767"
        }
    }
}

extension String {
	static let defaultPort: String = "10767"
}

extension Int {
	static let defaultPort: Int = 10767
}

// {"address":"192.168.1.15","token":"jf69gnaglxv68923ire62lfo","method":"lan","initialData":{"version":"400","platform":"genten","os":"darwin"}}

extension Device {
    func runAppleMusicAPI(path: String, returnContent: Bool = true) async throws -> Any {
        do {
			let data = try await sendRequest(endpoint: "amapi/run-v3", method: "POST", body: ["path": path], version: "v1")
            if let jsonDict = data as? [String: Any], let data = jsonDict["data"] as? [String: Any] {
                guard returnContent else { return jsonDict }

                if let subdata = data["data"] as? [String: Any] { // object
                    return subdata
                } else if let subdata = data["data"] as? [[String: Any]] { // array of objects
                    return subdata
                }
            }

            return data
        } catch {
            print("Error running Apple Music API: \(error)")
            throw NetworkError.invalidResponse
        }
    }

	func sendRequest(endpoint: String, method: String = "GET", body: [String: Any]? = nil, version: String? = nil) async throws -> Any {
		let clientVersion: String = self.useV2 ? "v2" : "v1"
		let v: String = version ?? clientVersion

		let baseURL = self.connectionMethod == .tunnel ? "https://\(self.host)" : "http://\(self.host):10767"
        guard let url = URL(string: "\(baseURL)/api/\(v)/\(endpoint)") else {
            throw NetworkError.invalidURL
        }

        print("Sending request to: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue(self.token, forHTTPHeaderField: "apptoken")

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            print("Request body: \(body)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
		print("Response raw: \(String(data: data, encoding: .utf8) ?? "[No data]")")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        print("Response status code: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError("Server responded with status code \(httpResponse.statusCode)")
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
			if self.useV2 {
				let jsonData = (json as! [String: Any])["data"]!
				print(jsonData)
				return jsonData
			} else {
//                print("Received data: \(json)")
				return json
			}
        } catch {
            print(error)
            throw NetworkError.decodingError
        }
    }
}
