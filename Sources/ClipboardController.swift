import Cocoa
import Combine

struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let kind: Kind
    let timestamp: Date

    enum Kind: Equatable {
        case text(String)
        case image(NSImage)
        static func == (lhs: Kind, rhs: Kind) -> Bool {
            switch (lhs, rhs) {
            case (.text(let a), .text(let b)): return a == b
            case (.image(let a), .image(let b)): return a.tiffRepresentation == b.tiffRepresentation
            default: return false
            }
        }
    }
}

final class ClipboardController: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private var historySize: Int
    private var pollTimer: Timer?
    private var lastChange: Int = NSPasteboard.general.changeCount

    init(historySize: Int) {
        self.historySize = historySize
    }

    func start() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func setHistorySize(_ size: Int) {
        historySize = size
        trim()
    }

    private func poll() {
        let pb = NSPasteboard.general
        let count = pb.changeCount
        guard count != lastChange else { return }
        lastChange = count

        if let img = readImage(from: pb) {
            insert(.image(img))
        } else if let str = pb.string(forType: .string), !str.isEmpty {
            insert(.text(str))
        }
    }

    private func readImage(from pb: NSPasteboard) -> NSImage? {
        if let data = pb.data(forType: .tiff), let img = NSImage(data: data) { return img }
        if let urlString = pb.string(forType: .fileURL), let url = URL(string: urlString),
           let img = NSImage(contentsOf: url) { return img }
        return nil
    }

    private func insert(_ kind: ClipboardItem.Kind) {
        let item = ClipboardItem(kind: kind, timestamp: Date())
        items.removeAll { $0.kind == kind }
        items.insert(item, at: 0)
        trim()
    }

    private func trim() {
        if items.count > historySize {
            items = Array(items.prefix(historySize))
        }
    }

    func copyToPasteboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text(let s): pb.setString(s, forType: .string)
        case .image(let img):
            if let data = img.tiffRepresentation { pb.setData(data, forType: .tiff) }
        }
        lastChange = pb.changeCount
    }
}
