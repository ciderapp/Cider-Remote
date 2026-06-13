// Made by Lumaa

import Foundation

struct ConnectionInfo: Decodable {
    let address: String
    let token: String
    let method: ConnectionMethod
    let initialData: InitialData

	init(
		from client: CiderClient,
		using auth: AuthRequest.Result,
		address: String = "localhost",
		connectionMethod: ConnectionMethod = .lan
	) {
		self.address = address
		self.token = auth.token
		self.method = connectionMethod
		self.initialData = .init(using: client)
	}

	enum CodingKeys: CodingKey {
		case address
		case token
		case method
		case initialData
	}

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.address = try container.decode(String.self, forKey: .address)
		self.token = try container.decode(String.self, forKey: .token)
		self.method = try container.decode(ConnectionMethod.self, forKey: .method)
		self.initialData = try container.decode(InitialData.self, forKey: .initialData)
	}
}

enum ConnectionMethod: String, Codable {
    case lan
    case tunnel
}

// {"address":"192.168.1.15","token":"abcdefghijklmopqrstuvwxyz","method":"lan","initialData":{"version":"400","platform":"genten","os":"darwin"}}

struct InitialData: Decodable {
    let version: String
	let platform: CiderClient.Framework
    let os: CiderClient.Platform

	init(version: String, platform: CiderClient.Framework, os: CiderClient.Platform) {
		self.version = version
		self.platform = platform
		self.os = os
	}

	init(using client: CiderClient) {
		self.version = client.version
		self.platform = client.framework
		self.os = client.platform
	}

    // We'll use CodingKeys to handle the missing 'arch' field
    enum CodingKeys: String, CodingKey {
        case version, platform, os
    }
    
    // Custom initializer to set a default value for 'arch'
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let oneVersion = try container.decode(String.self, forKey: .version)
		version = "\(oneVersion[0]).\(oneVersion[1]).\(oneVersion.count > 3 ? "\(oneVersion[2...oneVersion.count - 1])" : "\(oneVersion[2])")"

		platform = try container.decode(CiderClient.Framework.self, forKey: .platform)
        os = try container.decode(CiderClient.Platform.self, forKey: .os)
    }
}
