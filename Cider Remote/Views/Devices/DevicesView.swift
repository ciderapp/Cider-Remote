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
    
    // Send to Cider functionality
    @StateObject private var currentMusicService = CurrentMusicService.shared
    @State private var showingSendToCiderAlert = false
    @State private var selectedDeviceForSending: Device?
    @State private var isSendingToCider = false
    @State private var sendResultAlert: SendResultAlert? = nil

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
                        DeviceRowView(device: device, hasCurrentMusic: currentMusicService.currentTrack?.hasValidData == true)
                    }
                    .tint(Color.primary)
                    .onLongPressGesture {
                        guard device.isActive else { return }
                        selectedDeviceForSending = device
                        currentMusicService.updateCurrentTrack()
                        // Add a small delay to allow track info to update
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showingSendToCiderAlert = true
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            DeviceManager.shared.remove(device)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        if device.isActive {
                            Button {
                                selectedDeviceForSending = device
                                currentMusicService.updateCurrentTrack()
                                // Add a small delay to allow track info to update
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showingSendToCiderAlert = true
                                }
                            } label: {
                                Label("Send to Cider", systemImage: "music.note.list")
                            }
                            .disabled(currentMusicService.currentTrack?.hasValidData != true)
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
        .alert("Send to Cider", isPresented: $showingSendToCiderAlert) {
            Button("Cancel", role: .cancel) { }
            if !currentMusicService.hasMediaAccess {
                Button("Grant Permission") {
                    // This will trigger permission request
                    currentMusicService.updateCurrentTrack()
                }
            } else if let track = currentMusicService.currentTrack, track.hasValidData {
                Button("Send") {
                    if let device = selectedDeviceForSending {
                        sendCurrentMusicToCider(device: device)
                    }
                }
                .disabled(isSendingToCider)
            } else {
                Button("Refresh") {
                    currentMusicService.updateCurrentTrack()
                    // Re-show alert after refresh
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showingSendToCiderAlert = true
                    }
                }
            }
        } message: {
            if !currentMusicService.hasMediaAccess {
                Text("This app needs permission to access your media library to detect currently playing music. Please grant permission to continue.")
            } else if let track = currentMusicService.currentTrack, track.hasValidData {
                if isSendingToCider {
                    Text("Sending \"\(track.title)\" by \(track.artist) to \(selectedDeviceForSending?.friendlyName ?? "Cider")...")
                } else {
                    Text("Send \"\(track.title)\" by \(track.artist) to \(selectedDeviceForSending?.friendlyName ?? "Cider")?")
                }
            } else {
                Text("No music is currently playing on this device. Start playing music in Apple Music, Spotify, or another music app, then try 'Refresh'.")
            }
        }
        .alert(item: $sendResultAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            self.startActivityChecking()
            currentMusicService.updateCurrentTrack()
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
    
    private func sendCurrentMusicToCider(device: Device) {
        guard !isSendingToCider else { return }
        
        isSendingToCider = true
        
        Task {
            let success = await currentMusicService.sendToCider(device: device)
            
            await MainActor.run {
                isSendingToCider = false
                
                if success {
                    sendResultAlert = SendResultAlert(
                        title: "Success",
                        message: "Successfully sent music to \(device.friendlyName)"
                    )
                } else {
                    sendResultAlert = SendResultAlert(
                        title: "Failed",
                        message: "Could not send music to \(device.friendlyName). Make sure the device is connected and try again."
                    )
                }
            }
        }
    }
}

struct SendResultAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
