// Made by Lumaa

import Foundation
import AppIntents

struct DeviceEntity: Identifiable, Codable, AppEntity {
    let id: UUID
    let name: String
    let token: String
    let host: String
    let connectionMethod: String
    var isActive: Bool
    var isPlaying: Bool

    init(
        id: UUID = UUID(),
        name: String,
        token: String,
        host: String,
        connectionMethod: String = "lan",
        isActive: Bool = false,
        isPlaying: Bool = false
    ) {
        self.id = id
        self.name = name
        self.token = token
        self.host = host
        self.connectionMethod = connectionMethod
        self.isActive = isActive
        self.isPlaying = isPlaying
    }

    init(from device: Device) {
        self.id = device.id
        self.name = device.friendlyName
        self.token = device.token
        self.host = device.host
		self.connectionMethod = device.connectionMethod.rawValue
        self.isActive = device.isActive
        self.isPlaying = false
    }

    static var defaultQuery: DeviceQuery = .init()

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Device"
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(stringLiteral: self.name)
    }

    // Never "throws" to prevent control name being displayed
    func sendRequest(endpoint: String, method: String = "GET", body: [String: Any]? = nil) async -> (statusCode: Int, response: Any) {
        let baseURL = self.connectionMethod == "tunnel"
        ? "https://\(self.host)"
        : "http://\(self.host):10767"
        guard let url = URL(string: "\(baseURL)/api/v1/\(endpoint)") else {
            return (statusCode: -1, response: -1)
        }

        print("Sending request to: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue(self.token, forHTTPHeaderField: "apptoken")
        request.timeoutInterval = 3.0

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            print("Request body: \(body)")
        }

        if let (data, response) = try? await URLSession.shared.data(for: request) {
            //        print("Response raw: \(String(data: data, encoding: .utf8) ?? "[No data]")")

            guard let httpResponse = response as? HTTPURLResponse else {
                return (statusCode: -1, response: -1)
            }

            print("Response status code: \(httpResponse.statusCode)")

            //        guard (200...299).contains(httpResponse.statusCode) else {
            //            throw NetworkError.serverError("Server responded with status code \(httpResponse.statusCode)")
            //        }

            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                //            print("Received data: \(json)")
                return (statusCode: httpResponse.statusCode, response: json)
            } catch {
                print(error)
                return (statusCode: -1, response: error)
            }
        } else {
            return (statusCode: -1, response: -1)
        }
    }
}

struct DeviceQuery: EntityQuery {
    init() {}

    private func loadDevices() -> [DeviceEntity] {
        guard let savedDevicesData: Data = UserDefaults.main.data(forKey: "savedDevices") else { return [] }

        do {
            let decoder = JSONDecoder()
            let decodedDevices = try decoder.decode([Device].self, from: savedDevicesData)
            return decodedDevices.map { DeviceEntity(from: $0) }
        } catch {
            print("Error decoding saved devices: \(error)")
            return []
        }
    }

    func entities(for identifiers: [DeviceEntity.ID]) async throws -> [DeviceEntity] {
        let devices: [DeviceEntity] = self.loadDevices().filter { identifiers.contains($0.id) }
        return devices
    }

    func suggestedEntities() async throws -> [DeviceEntity] {
        return self.loadDevices()
    }

    func defaultResult() async -> DeviceEntity? {
        let firstActive: DeviceEntity? = self.loadDevices().filter { $0.isActive }.first
        return firstActive
    }
}
