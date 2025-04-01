//
//  ContentView.swift
//  Cider Remote
//
//  Created by Elijah Klaumann on 8/26/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var colorScheme = ColorSchemeManager()
    @StateObject private var deviceListViewModel = DeviceListViewModel()

    var body: some View {
        ZStack {
            NavigationStack {
                DevicesView()
            }
            .tint(colorScheme.primaryColor)

            if deviceListViewModel.showingNamePrompt {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        FriendlyNamePromptView()
                            .environmentObject(deviceListViewModel)
                            .environmentObject(colorScheme)
                    )
                    .transition(.opacity)
            }
            
            if deviceListViewModel.showingOldDeviceAlert {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .overlay {
                        OldDeviceAlertView(isPresented: $deviceListViewModel.showingOldDeviceAlert)
                            .environmentObject(deviceListViewModel)
                            .environmentObject(colorScheme)
                    }
                    .transition(.opacity)
            }
        }
        .environmentObject(colorScheme)
        .environmentObject(deviceListViewModel)
    }
}

struct OldDeviceAlertView: View {
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var colorSchemeManager: ColorSchemeManager

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                    
                    Text("Outdated Device Detected")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Text("The scanned QR code is from an older version of Cider. Please update your Cider client to the latest version to use this remote.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("OK") {
                    isPresented = false
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
            .background(colorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
            .frame(width: 320)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct FriendlyNamePromptView: View {
    @EnvironmentObject var viewModel: DeviceListViewModel
    @EnvironmentObject var colorScheme: ColorSchemeManager
    @State private var friendlyName: String = ""
    @Environment(\.colorScheme) var systemColorScheme

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 50))
                    .foregroundColor(colorScheme.primaryColor)

                Text("New Device Found")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Text("Please enter a friendly name for this device:")
                .font(.subheadline)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("Friendly Name")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("e.g. Living Room PC", text: $friendlyName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.words)
            }

            HStack(spacing: 16) {
                Button("Cancel") {
                    viewModel.showingNamePrompt = false
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Add Device") {
                    viewModel.addNewDevice(withName: friendlyName)
                    viewModel.showingNamePrompt = false
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(friendlyName.isEmpty)
            }
        }
        .padding(24)
        .background(systemColorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .frame(width: 320)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

struct LazyView<Content: View>: View {
    let build: () -> Content

    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }

    var body: Content {
        build()
    }
}

struct StatusIndicator: View {
    let status: DeviceStatus

    var color: Color {
        switch status {
            case .offline:
                Color.red
            case .online:
                Color.green
            case .refreshing:
                Color.clear
        }
    }

    var body: some View {
        if status != DeviceStatus.refreshing {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: color.opacity(0.5), radius: 2)
        } else {
            ProgressView()
                .progressViewStyle(.circular)
                .frame(width: 12, height: 12)
        }
    }
}

struct ConnectionGuideView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Prerequisites:")
                        .font(.headline)
                    BulletedList(items: [
                        "Cider 2.5.3+ is installed (... > Updates)",
                        "Cider installed and running on your computer (Windows, macOS, or Linux)",
                        "Your Device and Cider on the same local network (If using LAN)",
                        "Cider's RPC & WebSocket server enabled (Settings > Connectivity)"
                    ])
                    
                    Text("Connection Steps:")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 15) {
                        GuideStep(number: 1, text: "Open Cider Remote: Launch the Cider Remote app on your iPhone.")
                        GuideStep(number: 2, text: "Prepare Cider: Open Cider on your Computer, tap the '...' menu, and visit 'Help > Connect a Remote' and create a device. (Some devices may prefer WAN over LAN.)")
                        GuideStep(number: 3, text: "Scan QR Code: In Cider Remote, tap 'Add a New Cider Device' and use the camera to scan the QR code displayed in Cider.")
                        GuideStep(number: 4, text: "Confirm Connection: Your iPhone should now be paired with Cider.")
                    }
                    
                    Text("Troubleshooting:")
                        .font(.headline)
                    Text("If you can't connect:")
                        .font(.subheadline)
                    BulletedList(items: [
                        "Ensure both devices are on the same network",
                        "Check if Cider's RPC server is running (port 10767)",
                        "Restart both Cider and Cider Remote",
                        "Check firewall settings (see below)"
                    ])
                    
                    Text("Firewall Settings:")
                        .font(.subheadline)
                    BulletedList(items: [
                        "Windows: Allow Cider through Windows Defender Firewall (Inbound Port 10767)",
                        "macOS: Add Cider to allowed apps in Security & Privacy > Firewall",
                        "Linux: Use your distribution's firewall tool to allow port 10767"
                    ])
                    
                    Text("For QR code scanning issues:")
                        .font(.subheadline)
                    BulletedList(items: [
                        "Ensure the code is clearly visible and well-lit",
                        "Try adjusting the distance between your phone and the screen"
                    ])
                    
                    Text("For further assistance, please visit our support forum or GitHub issues page.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .padding()
            }
            .navigationBarTitle("Connection Guide", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct DeviceIconView: View {
    let device: Device

    var body: some View {
        Image(uiImage: deviceImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 40, height: 40)
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var deviceImage: UIImage {
        let osType = device.os ?? device.platform
        switch osType.lowercased() {
        case "win32":
            return UIImage(named: "Windows") ?? UIImage(systemName: "desktopcomputer")!
        case "darwin":
            return UIImage(named: "macOS") ?? UIImage(systemName: "desktopcomputer")!
        case "linux":
            return UIImage(named: "Linux") ?? UIImage(systemName: "desktopcomputer")!
        default:
            return UIImage(systemName: "desktopcomputer")!
        }
    }
}

struct DeviceRowView: View {
    @ObservedObject var device: Device

    private var status: DeviceStatus {
        if device.isActive && !device.isRefreshing {
            return .online
        } else if !device.isActive && !device.isRefreshing {
            return .offline
        } else if !device.isActive && device.isRefreshing {
            return .refreshing
        }
        return .offline
    }

    var body: some View {
        HStack(spacing: 12) {
            DeviceIconView(device: device)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.friendlyName)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(device.version) | \(device.platform)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("Host: \(device.host)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            StatusIndicator(status: self.status)
        }
        .padding(.vertical, 8)
    }
}

struct DeleteButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .foregroundColor(.red)
                .offset(x: 60)
        }
        .padding()
    }
}

enum DeviceStatus {
    case offline
    case online
    case refreshing
}

#Preview {
    ContentView()
}
