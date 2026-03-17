// Made by Lumaa

import Foundation

class DeviceManager: ObservableObject {
    static let shared: DeviceManager = .init()

    @Published private(set) public var devices: [Device] = []
    @Published public var connectionInfo: ConnectionInfo?

    init(devices: [Device]) {
        self.devices = devices
    }

    init() {
        self.devices = self.loadDevices()
    }

    func add(_ device: Device) {
        DispatchQueue.main.async {
            self.devices.append(device)
            self.saveDevices()
        }
    }

    func set(_ device: Device, at: Int) {
        DispatchQueue.main.async {
            self.devices[at] = device
            self.saveDevices()
        }
    }

    func remove(_ device: Device) {
        DispatchQueue.main.async {
            self.devices.removeAll { $0.id == device.id }
            self.saveDevices()
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.devices.removeAll()
            self.saveDevices()
        }
    }

    func checkDeviceActivity(_ device: Device) async {
        await MainActor.run {
            device.isRefreshing = true
        }

        defer {
            Task { @MainActor in
                device.isRefreshing = false
            }
        }

        guard let url = URL(string: "\(device.fullAddress)/api/v1/playback/active") else {
            print("Invalid URL for device: \(device.friendlyName)")
            return
        }

        var request = URLRequest(url: url)
        request.addValue(device.token, forHTTPHeaderField: "apptoken")

        if let activity = try? await URLSession.shared.data(for: request),
           let httpurl: HTTPURLResponse = activity.1 as? HTTPURLResponse {
            await MainActor.run {
                device.isActive = httpurl.statusCode == 200
            }
        } else {
            await MainActor.run {
                device.isActive = false
            }
        }
    }

    private func saveDevices() {
        if let encodedDevices = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(encodedDevices, forKey: "savedDevices")
            UserDefaults.main.set(encodedDevices, forKey: "savedDevices")
        }
    }

    private func loadDevices() -> [Device] {
        guard let savedDevicesData: Data = UserDefaults.standard.data(forKey: "savedDevices") else { return [] }

        do {
            let decoder = JSONDecoder()
            let decodedDevices: [Device] = try decoder.decode([Device].self, from: savedDevicesData)
            return decodedDevices
        } catch {
            print("Error decoding saved devices: \(error)")
            UserDefaults.standard.set(nil, forKey: "savedDevices") // remove to avoid corruption
            return []
        }
    }
}
