import Cocoa
import Combine

final class LiveActivityController: ObservableObject {
    @Published var current: LiveActivityModel? = nil

    private var mediaCancellable: AnyCancellable?
    private weak var media: MediaController?

    func start(media: MediaController) {
        self.media = media
        update(from: media.nowPlaying)
        mediaCancellable = media.$nowPlaying.sink { [weak self] item in
            self?.update(from: item)
        }
    }

    func stop() {
        mediaCancellable = nil
        media = nil
        current = nil
    }

    func update(from item: MediaItem?) {
        if let item, !item.title.isEmpty {
            current = LiveActivityModel(kind: .music, label: item.title, detail: item.artist)
        } else {
            current = nil
        }
    }

    func startTimer(label: String, duration: TimeInterval) {
        current = LiveActivityModel(kind: .timer, label: label, detail: formatDuration(duration))
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
