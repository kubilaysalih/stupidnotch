import Foundation

enum AppSettings {
    private static let defaults = UserDefaults.standard

    static var startAtLogin: Bool {
        get { defaults.object(forKey: "startAtLogin") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "startAtLogin") }
    }

    static var cornerRadius: Double {
        get { defaults.object(forKey: "cornerRadius") as? Double ?? 22 }
        set { defaults.set(newValue, forKey: "cornerRadius") }
    }

    static var originalWallpaperPath: String? {
        get { defaults.string(forKey: "originalWallpaperPath") }
        set { defaults.set(newValue, forKey: "originalWallpaperPath") }
    }

    static var cornerStyle: Int {
        get { defaults.object(forKey: "cornerStyle") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "cornerStyle") }
    }
}

enum CornerStyle: Int, CaseIterable {
    case circular = 0
    case continuous = 1

    var label: String {
        switch self {
        case .circular: return "Circular"
        case .continuous: return "Squircle"
        }
    }
}
