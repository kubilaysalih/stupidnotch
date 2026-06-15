import Cocoa
import Combine
import IOKit.ps

final class BatteryController: ObservableObject {
    @Published var percent: Double? = nil
    @Published var isCharging: Bool = false
    @Published var timeToFull: TimeInterval = 0
    @Published var timeToEmpty: TimeInterval = 0

    private var timer: Timer?
    private var source: CFRunLoopSource?

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    var iconName: String {
        guard let p = percent else { return "bolt.slash" }
        if isCharging { return "battery.100.bolt" }
        switch p {
        case 80...: return "battery.100"
        case 50...: return "battery.75"
        case 25...: return "battery.50"
        case 10...: return "battery.25"
        default:    return "battery.0"
        }
    }

    private func refresh() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return }
        for src in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, src)?.takeUnretainedValue() as? [String: Any] else { continue }
            if let current = info[kIOPSCurrentCapacityKey] as? Double,
               let max = info[kIOPSMaxCapacityKey] as? Double, max > 0 {
                percent = current / max * 100
            }
            if let state = info[kIOPSPowerSourceStateKey] as? String {
                isCharging = (state == kIOPSACPowerValue)
            }
            if let toFull = info[kIOPSTimeToFullChargeKey] as? Double {
                timeToFull = toFull * 60
            }
            if let toEmpty = info[kIOPSTimeToEmptyKey] as? Double {
                timeToEmpty = toEmpty * 60
            }
        }
    }
}
