import Cocoa
import Combine
import UniformTypeIdentifiers

struct TrayItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let name: String
    let thumbnail: NSImage?
}

final class TrayController: ObservableObject {
    @Published private(set) var items: [TrayItem] = []

    private let storageDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StupidNotch", isDirectory: true)
            .appendingPathComponent("tray", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    init() { loadPersisted() }

    func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, err in
                guard let self, let url else { return }
                DispatchQueue.main.async {
                    self.add(url)
                }
            }
        }
    }

    func add(_ url: URL) {
        let destination = storageDir.appendingPathComponent(url.lastPathComponent)
        var final = destination
        var index = 1
        while FileManager.default.fileExists(atPath: final.path) {
            let base = destination.deletingPathExtension().lastPathComponent
            let ext = destination.pathExtension
            let name = ext.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(ext)"
            final = storageDir.appendingPathComponent(name)
            index += 1
        }
        do {
            try FileManager.default.copyItem(at: url, to: final)
        } catch {
            return
        }
        let thumb = makeThumbnail(for: final)
        let item = TrayItem(id: UUID(), url: final, name: final.lastPathComponent, thumbnail: thumb)
        items.append(item)
    }

    func remove(_ item: TrayItem) {
        items.removeAll { $0.id == item.id }
        try? FileManager.default.removeItem(at: item.url)
    }

    func clear() {
        for item in items {
            try? FileManager.default.removeItem(at: item.url)
        }
        items.removeAll()
    }

    func shareAllViaAirDrop() {
        guard !items.isEmpty else { return }
        let urls = items.map { $0.url }
        let picker = NSSharingServicePicker(items: urls)
        if let service = NSSharingService(named: .sendViaAirDrop) {
            service.perform(withItems: urls)
            return
        }
        if let window = NSApp.keyWindow ?? NSApp.windows.first, let view = window.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }

    private func loadPersisted() {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: storageDir, includingPropertiesForKeys: nil) else { return }
        for url in urls {
            let thumb = makeThumbnail(for: url)
            items.append(TrayItem(id: UUID(), url: url, name: url.lastPathComponent, thumbnail: thumb))
        }
    }

    private func makeThumbnail(for url: URL) -> NSImage? {
        let workspace = NSWorkspace.shared
        if let preview = previewImage(for: url) { return preview }
        return workspace.icon(forFile: url.path)
    }

    private func previewImage(for url: URL) -> NSImage? {
        let ext = url.pathExtension.lowercased()
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "bmp"]
        if imageExts.contains(ext), let img = NSImage(contentsOf: url) {
            return img
        }
        return nil
    }
}
