// Made by Lumaa

import Foundation

struct ConnectionInfo: Decodable {
    let address: String
    let token: String
    let method: ConnectionMethod
    let initialData: InitialData
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
