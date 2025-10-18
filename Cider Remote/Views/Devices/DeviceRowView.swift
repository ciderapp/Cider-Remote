// Made by Lumaa

import SwiftUI

struct DeviceRowView: View {
    @ObservedObject var device: Device

    @AppStorage("deviceDetails") private var deviceDetails: Bool = false

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
                    .font(.title2.bold())
                    .lineLimit(1)
                if deviceDetails {
                    Text("\(device.version) | \(device.platform)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("Host: \(device.host)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            StatusIndicator(status: self.status)
        }
        .padding(.vertical, 8)
    }
}
