import Cocoa
import Combine

struct MediaItem: Equatable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let artwork: NSImage?
    let bundleID: String?
    let source: Source

    enum Source: Equatable {
        case mediaRemote
        case spotify
        case appleMusic
        case manual
    }
}

final class MediaController: ObservableObject {
    @Published var nowPlaying: MediaItem? = nil
    @Published var isPlaying: Bool = false
    @Published var elapsed: TimeInterval = 0

    var onTrackChange: ((MediaItem?) -> Void)?

    private var bridgeProcess: Process?
    private var bridgeReadBuffer = Data()
    private var tickTimer: Timer?
    private var pollTimer: Timer?
    private var lastTrackSignature: String = ""

    func start() {

        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(self, selector: #selector(spotifyChanged(_:)), name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil)
        dnc.addObserver(self, selector: #selector(musicChanged(_:)), name: NSNotification.Name("com.apple.Music.playerInfo"), object: nil)

        startBridge()

        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying else { return }
            self.elapsed = min(self.elapsed + 0.5, self.nowPlaying?.duration ?? .infinity)
        }

        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.pollCurrentState()
        }
    }

    func stop() {
        stopBridge()
        tickTimer?.invalidate(); tickTimer = nil
        pollTimer?.invalidate(); pollTimer = nil
        DistributedNotificationCenter.default().removeObserver(self)
    }

    private func pollCurrentState() {
        guard let perlScript = Self.adapterScriptURL,
              let framework = Self.adapterFrameworkURL else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            proc.arguments = [perlScript.path, framework.path, "get", "--micros", "--no-artwork"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            var buf = Data()
            let q = DispatchQueue(label: "stupidnotch.bridge.poll")
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty { handle.readabilityHandler = nil }
                else { q.sync { buf.append(chunk) } }
            }
            do {
                try proc.run()
                proc.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil
                let data = q.sync { buf }

                let trimmed = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let isEmpty: Bool
                if trimmed.isEmpty {
                    isEmpty = true
                } else if let obj = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)) as? [String: Any] {
                    let title = (obj["title"] as? String) ?? ""
                    let artist = (obj["artist"] as? String) ?? ""
                    isEmpty = title.isEmpty && artist.isEmpty
                } else {
                    isEmpty = true
                }
                DispatchQueue.main.async {
                    guard let self else { return }
                    if isEmpty && self.nowPlaying != nil {
                        self.isPlaying = false
                        self.applyItem(nil)
                    }
                }
            } catch {
            }
        }
    }

    private func startBridge() {
        guard let perlScript = Self.adapterScriptURL,
              let framework = Self.adapterFrameworkURL else {
            return
        }

        runBridgeOnce(perlScript: perlScript, framework: framework, command: "get")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        proc.arguments = [perlScript.path, framework.path, "stream", "--no-diff", "--micros"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            self?.handleBridgeOutput(chunk)
        }
        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self, self.bridgeProcess == nil else { return }
                self.startBridge()
            }
        }
        do {
            try proc.run()
            bridgeProcess = proc
        } catch {
        }
    }

    private func runBridgeOnce(perlScript: URL, framework: URL, command: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            proc.arguments = [perlScript.path, framework.path, command, "--micros", "--no-artwork"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()

            var buf = Data()
            let q = DispatchQueue(label: "stupidnotch.bridge.oneshot")
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    q.sync { buf.append(chunk) }
                }
            }
            do {
                try proc.run()
                proc.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil
                let data = q.sync { buf }

                let lines = data.split(separator: 0x0A)
                for line in lines {
                    guard let obj = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
                    DispatchQueue.main.async { self?.applyBridgePayload(obj) }
                    break
                }
            } catch {
            }
        }
    }

    private func stopBridge() {
        bridgeProcess?.terminationHandler = nil
        bridgeProcess?.terminate()
        bridgeProcess = nil
        bridgeReadBuffer.removeAll()
    }

    private func handleBridgeOutput(_ chunk: Data) {
        bridgeReadBuffer.append(chunk)

        while let nl = bridgeReadBuffer.firstIndex(of: 0x0A) {
            let line = bridgeReadBuffer[..<nl]
            bridgeReadBuffer.removeSubrange(...nl)
            guard !line.isEmpty,
                  let envelope = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let payload = envelope["payload"] as? [String: Any] else { continue }
            DispatchQueue.main.async { [weak self] in self?.applyBridgePayload(payload) }
        }
    }

    private func applyBridgePayload(_ payload: [String: Any]) {

        guard !payload.isEmpty else { return }

        let title = payload["title"] as? String ?? ""
        let artist = payload["artist"] as? String ?? ""
        let album = payload["album"] as? String ?? ""
        let durationMicros = (payload["durationMicros"] as? Double) ?? ((payload["duration"] as? Double).map { $0 * 1_000_000 } ?? 0)
        let elapsedMicros = (payload["elapsedTimeMicros"] as? Double) ?? ((payload["elapsedTime"] as? Double).map { $0 * 1_000_000 } ?? 0)
        let playing = (payload["playing"] as? Bool) ?? false
        let bundleID = payload["bundleIdentifier"] as? String
        var artwork: NSImage? = nil
        if let b64 = payload["artworkData"] as? String,
           let data = Data(base64Encoded: b64) {
            artwork = NSImage(data: data)
        }

        let currentBundle = nowPlaying?.bundleID
        let isFromCurrentSource = (bundleID != nil && bundleID == currentBundle)
        guard isFromCurrentSource || playing else { return }

        isPlaying = playing
        elapsed = elapsedMicros / 1_000_000

        if title.isEmpty && artist.isEmpty {
            applyItem(nil)
            return
        }
        let item = MediaItem(
            title: title,
            artist: artist,
            album: album,
            duration: durationMicros / 1_000_000,
            artwork: artwork,
            bundleID: bundleID,
            source: .mediaRemote
        )
        applyItem(item)
    }

    @objc private func spotifyChanged(_ note: Notification) {
        guard let info = note.userInfo else { return }
        let state = (info["Player State"] as? String) ?? "Stopped"
        if state == "Stopped" { applyItem(nil); isPlaying = false; return }
        let item = MediaItem(
            title: (info["Name"] as? String) ?? "",
            artist: (info["Artist"] as? String) ?? "",
            album: (info["Album"] as? String) ?? "",
            duration: ((info["Duration"] as? Double) ?? 0) / 1000.0,
            artwork: nil,
            bundleID: "com.spotify.client",
            source: .spotify
        )

        if nowPlaying?.source != .mediaRemote || nowPlaying?.title != item.title {
            applyItem(item)
        }
        isPlaying = state == "Playing"
    }

    @objc private func musicChanged(_ note: Notification) {
        guard let info = note.userInfo else { return }
        let state = (info["Player State"] as? String) ?? "Stopped"
        if state == "Stopped" { applyItem(nil); isPlaying = false; return }
        let totalTime = ((info["Total Time"] as? Double) ?? 0) / 1000.0
        let item = MediaItem(
            title: (info["Name"] as? String) ?? "",
            artist: (info["Artist"] as? String) ?? "",
            album: (info["Album"] as? String) ?? "",
            duration: totalTime,
            artwork: nil,
            bundleID: "com.apple.Music",
            source: .appleMusic
        )
        if nowPlaying?.source != .mediaRemote || nowPlaying?.title != item.title {
            applyItem(item)
        }
        isPlaying = state == "Playing"
    }

    private func applyItem(_ item: MediaItem?) {
        let signature = item.map { "\($0.title)|\($0.artist)|\($0.album)" } ?? "<nil>"
        let changed = signature != lastTrackSignature
        lastTrackSignature = signature
        nowPlaying = item
        if changed { onTrackChange?(item) }
    }

    private static var adapterScriptURL: URL? {
        Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl")
    }

    private static var adapterFrameworkURL: URL? {
        Bundle.main.privateFrameworksURL?.appendingPathComponent("MediaRemoteAdapter.framework")
    }

    private typealias SendCommandFn = @convention(c) (Int, AnyObject?) -> Bool
    private static let sendCommand: SendCommandFn? = {
        let url = NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        guard let bundle = CFBundleCreate(nil, url) else { return nil }
        guard let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) else {
            return nil
        }
        return unsafeBitCast(ptr, to: SendCommandFn.self)
    }()

    func togglePlay() { send(.togglePlayPause) }
    func next()       { send(.next) }
    func previous()   { send(.previous) }

    private enum Command: Int {
        case play = 0, pause = 1, togglePlayPause = 2, stop = 3, next = 4, previous = 5
    }

    private func send(_ command: Command) {
        guard let fn = Self.sendCommand else {
            return
        }
        _ = fn(command.rawValue, nil)
    }
}
