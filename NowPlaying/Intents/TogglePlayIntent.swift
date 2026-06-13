// Made by Lumaa

import Foundation
import WidgetKit
import AppIntents

struct TogglePlayIntent: AppIntent, SetValueIntent {
    static var title: LocalizedStringResource = "Play/Pause a Cider instance"
    static var description: IntentDescription = IntentDescription(stringLiteral: "Allows you press play or press pause in an active Cider instance")

    @Parameter(title: "Action", default: PlaybackEnum.toggle, requestValueDialog: IntentDialog(stringLiteral: "Playback Action"))
    var action: PlaybackEnum

    @Parameter(title: "Device", requestValueDialog: IntentDialog(stringLiteral: "What Cider device do you want to use?"))
    var device: DeviceEntity

    @Parameter(title: "Playing")
    var value: Bool

    init() {}

    init(device: DeviceEntity) {
        self.device = device
    }

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$action) the current track on \(\.$device)")
    }

    func perform() async throws -> some IntentResult {
        let (statusCode, _) = await device.sendRequest(endpoint: "playback/active")

        if statusCode == 200 {
            (_, _) = await device.sendRequest(endpoint: self.action.rawValue, method: "POST")

            let (_, data) = await device.sendRequest(endpoint: "playback/is-playing", method: "GET")
            if let jsonDict = data as? [String: Any] {
                self.device.isPlaying = jsonDict["is_playing"] as? Int == 1

                if #available(iOS 18.0, *) {
                    ControlCenter.shared.reloadControls(ofKind: "sh.cider.CiderRemote.PlayPauseControl")
                }
            }
            return .result()
        } else {
            self.device.isPlaying = false
            print("[AppIntent] - No toggle \(statusCode)")
        }
        return .result()
    }
}

/// This is the exact same as ``TogglePlayIntent`` but used in the ``NowPlayingLiveActivity``
struct TogglePlayButtonIntent: AppIntent {
    static var title: LocalizedStringResource = "Play/Pause a Cider instance"
    static var description: IntentDescription = IntentDescription(stringLiteral: "Allows you press play or press pause in an active Cider instance")

    static var isDiscoverable: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle play/pause on Cider")
    }

    var device: DeviceEntity?

    func perform() async throws -> some IntentResult {
        guard let devices = await self.getDevices() else { return .result() }

        for device in devices {
            let (statusCode, _) = await device.sendRequest(endpoint: "playback/active")

            if statusCode == 200 {
                (_, _) = await device.sendRequest(endpoint: "playback/playpause", method: "POST")

                if #available(iOS 18.0, *) {
                    ControlCenter.shared.reloadControls(ofKind: "sh.cider.CiderRemote.PlayPauseControl")
                }

                return .result()
            } else {
                print("[AppIntent] - No toggle \(statusCode)")
            }
        }

        return .result()
    }

    private func getDevices() async -> [DeviceEntity]? {
        if let device {
            return [device]
        } else {
            return try? await DeviceQuery().suggestedEntities()
        }
    }
}
