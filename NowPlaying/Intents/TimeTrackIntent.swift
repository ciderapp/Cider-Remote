// Made by Lumaa


// Made by Lumaa

import Foundation
import AppIntents

struct TimeTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Go back or skip a track from a Cider instance"
    static var description: IntentDescription = IntentDescription(stringLiteral: "Allows you to go back a track or skip the currently playing song on any chosen Cider instance")

    @Parameter(title: "Device", requestDisambiguationDialog: IntentDialog(stringLiteral: "What Cider device do you want to use?"))
    var device: DeviceEntity

    @Parameter(title: "Action", default: TimeTrack.skip)
    var timeAction: TimeTrack

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$timeAction) a track on \(\.$device)")
    }

    init() {}

    init(device: DeviceEntity, timeAction: TimeTrack) {
        self.device = device
        self.timeAction = timeAction
    }

    func perform() async throws -> some IntentResult {
//		let path: String = device.useV2 ? "playback/state" : "playback/active"
//        let (statusCode, _) = await device.sendRequest(endpoint: path)
		let (statusCode, _) = await device.sendRequest(endpoint: "playback/active")

        if statusCode == 200 {
            var req: String = "playback/unknown"

            switch timeAction {
                case .back:
                    req = "playback/previous"
                case .skip:
                    req = "playback/next"
            }
            
            (_, _) = await device.sendRequest(endpoint: req, method: "POST")
            return .result()
        }
        return .result()
    }
}

enum TimeTrack: Int, AppEnum {
    case back = 0
    case skip = 1

    static var caseDisplayRepresentations: [TimeTrack : DisplayRepresentation] {
        [
            .back : DisplayRepresentation(stringLiteral: "Go back"),
            .skip : DisplayRepresentation(stringLiteral: "Skip")
        ]
    }
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Action"

    var systemImage: String {
        switch self {
            case .back:
                "backward.fill"
            case .skip:
                "forward.fill"
        }
    }
}
