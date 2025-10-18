// Made by Lumaa

import SwiftUI

struct DevicesView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction

    @AppStorage("refreshInterval") private var refreshInterval: Double = 10.0

    @State private var isRefreshing: Bool = false
    @State private var viewingDevice: Device? = nil

    @State private var scannedCode: String?
    @State private var isShowingScanner = false
    @State private var isShowingGuide = false

    @State private var activityCheckTimer: Timer? = nil

    private var devices: [Device] {
        DeviceManager.shared.devices
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(devices) { device in
                    Button {
                        guard device.isActive else { return }

                        self.viewingDevice = device
                    } label: {
                        DeviceRowView(device: device)
                    }
                    .tint(Color.primary)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            DeviceManager.shared.remove(device)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .task {
                await self.refreshDevices()
            }
            .refreshable {
                await self.refreshDevices()
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                header
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingGuide = true
                } label: {
                    Label("Connection Guide", systemImage: "questionmark.circle")
                        .foregroundStyle(Color.cider)
                }
            }

            ToolbarSpacer(.fixed, placement: .topBarTrailing)

            ToolbarItem(placement: .topBarTrailing) {
                AddDeviceView(isShowingScanner: $isShowingScanner, scannedCode: $scannedCode) { json in
                    self.fetchDevices(from: json)
                }
                .buttonStyle(.glassProminent)
                .tint(Color.cider)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $viewingDevice) { device in
            MusicPlayerView(device: device)
                .tint(Color.cider)
        }
        .sheet(isPresented: $isShowingGuide) {
            ConnectionGuideView()
        }
        .onAppear {
            self.startActivityChecking()
        }
        .onDisappear {
            self.stopActivityChecking()
        }
    }

    var header: some View {
        HStack(spacing: 12) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 40)

            Text("Remote")
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
    }

    @MainActor
    func refreshDevices() async {
        isRefreshing = true

        for device in DeviceManager.shared.devices {
            await DeviceManager.shared.checkDeviceActivity(device)
        }

        // Simulate a slight delay to show the refresh indicator
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }

    @MainActor
    func refreshDevice(_ device: Device) async {
        isRefreshing = true

        await DeviceManager.shared.checkDeviceActivity(device)

        // Simulate a slight delay to show the refresh indicator
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        isRefreshing = false
    }

    func fetchDevices(from jsonString: String) {
        print("Received JSON string: \(jsonString)")  // Log the received JSON string

        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Error: Unable to convert JSON string to Data")
            AppPrompt.shared.showingPrompt = .oldDevice
            return
        }

        do {
            let connectionInfo = try JSONDecoder().decode(ConnectionInfo.self, from: jsonData)
            DeviceManager.shared.connectionInfo = connectionInfo
            AppPrompt.shared.showingPrompt = .newDevice
        } catch {
            print("Error decoding ConnectionInfo: \(error)")
            AppPrompt.shared.showingPrompt = .oldDevice
        }
    }

    private func finishRefreshing() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isRefreshing = false
        }
    }

    func startActivityChecking() {
        stopActivityChecking() // Ensure we're not running multiple timers

        // Schedule refreshes based on the refresh interval
        activityCheckTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            for device in DeviceManager.shared.devices {
                Task { await DeviceManager.shared.checkDeviceActivity(device) }
            }
        }
    }

    func stopActivityChecking() {
        activityCheckTimer?.invalidate()
        activityCheckTimer = nil
    }
}
