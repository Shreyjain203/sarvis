import Foundation

/// Config knobs for `Input/CalendarPicker`.
struct CalendarPickerConfig {
    enum Mode {
        case date, dateAndTime, time
    }

    let mode: Mode
    let optional: Bool

    init(spec: ElementSpec) {
        switch spec.config["mode"]?.stringValue {
        case "time":        mode = .time
        case "dateAndTime": mode = .dateAndTime
        default:            mode = .date
        }
        optional = spec.config["optional"]?.boolValue ?? false
    }
}
