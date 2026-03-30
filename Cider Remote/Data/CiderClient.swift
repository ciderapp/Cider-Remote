// Made by Lumaa

import Foundation

struct CiderClient: Decodable {
	let framework: Self.Framework
	let platform: Self.Platform
	let osVersion: String
	let port: Int
	let production: Bool
	/// Currently running Cider version
	let version: String

	init(framework: Self.Framework, platform: Self.Platform, osVersion: String, port: Int, production: Bool, version: String) {
		self.framework = framework
		self.platform = platform
		self.osVersion = osVersion
		self.port = port
		self.production = production
		self.version = version
	}

	init(device: Device) {
		self.framework = device.platform
		self.platform = device.os ?? .unknown
		self.osVersion = "Unknown"
		self.port = device.host.contains(":") ? Int(device.host.split(separator: ":")[1]) ?? .defaultPort : .defaultPort
		self.production = true
		self.version = device.version
	}

	var useV2: Bool {
		let core: String = String(version.split(separator: ".")[0]) // "4.0.0" > 4
		let int: Int = Int(core) ?? 0
		return int >= 4
	}

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.framework = try container.decode(Self.Framework.self, forKey: .framework)
		self.platform = try container.decode(Self.Platform.self, forKey: .platform)
		self.osVersion = try container.decode(String.self, forKey: .osVersion)
		self.port = try container.decode(Int.self, forKey: .port)
		self.production = try container.decode(Bool.self, forKey: .production)
		self.version = try container.decode(String.self, forKey: .version)
	}

	enum Framework: String, Codable {
		case dotnet = "dotnet"
		case genten = "genten"
		case universal = "universal"
		case unknown = "unknown"

		var display: String {
			switch self {
				case .dotnet:
					".NET"
				case .genten:
					"GenTen"
				case .universal:
					"Universal"
				case .unknown:
					"Unknown"
			}
		}
	}

	enum Platform: String, Codable {
		case windows = "win32"
		case macos = "darwin"
		case linux = "linux"
		case web = "web"
		case unknown = "unknown"

		var display: String {
			switch self {
				case .windows:
					"Windows"
				case .macos:
					"macOS"
				case .linux:
					"Linux"
				case .web:
					"Web"
				case .unknown:
					"Unknown"
			}
		}
	}

	enum CodingKeys: CodingKey {
		case framework
		case platform
		case osVersion
		case port
		case production
		case version
	}
}

