// Made by Lumaa

import Foundation

/// A json-decoded API response from Cider PC
///
/// How to use:
/// ```swift
/// let data: Data = device.sendRequest(endpoint: "queue/position")
/// let encoder: APIResponse<Track, Track>? = try? JSONDecoder().decode(APIResponse<Track, Track>.self, from: data)
/// ```
struct APIResponse<ResponseData : Decodable, MetaData : Decodable>: Decodable {
	let data: ResponseData
	let meta: MetaData?

	private init(data: ResponseData, meta: MetaData? = nil) {
		self.data = data
		self.meta = meta
	}

	init(from decoder: any Decoder) throws {
		let container: KeyedDecodingContainer<APIResponse<ResponseData, MetaData>.CodingKeys> = try decoder.container(
			keyedBy: APIResponse<ResponseData, MetaData>.CodingKeys.self
		)
		self.data = try container.decode(ResponseData.self, forKey: APIResponse<ResponseData, MetaData>.CodingKeys.data)
		self.meta = try container.decodeIfPresent(MetaData.self, forKey: APIResponse<ResponseData, MetaData>.CodingKeys.meta)
	}

	enum CodingKeys: CodingKey {
		case data
		case meta
	}
}

struct AirResponse: Decodable {}
