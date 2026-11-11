import Foundation
import AVFoundation
import MediaPlayer
import Combine

@MainActor
final class RadioPlayerManager: NSObject, ObservableObject {
    @Published var currentStation: RadioStation?
    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    @Published var currentTrackMetadata: String?
    @Published var errorMessage: String?
    @Published var volume: Float = 0.85 {
        didSet {
            player?.volume = isMuted ? 0 : volume
            UserDefaults.standard.set(volume, forKey: "kosmoradio_volume")
        }
    }
    @Published var isMuted: Bool = false {
        didSet {
            player?.volume = isMuted ? 0 : volume
        }
    }

    @Published var favorites: [RadioStation] = [] {
        didSet {
            saveFavorites()
        }
    }
    @Published var recentStations: [RadioStation] = []
    @Published var sleepTimerRemainingSeconds: Int? = nil

    private var player: AVPlayer?
    private var metadataOutput: AVPlayerItemMetadataOutput?
    private var timeControlObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private var sleepTimer: Timer?
    private var icyPollTask: Task<Void, Never>?

    private let favoritesKey = "kosmoradio_favorites_v1"
    private let hipHopSeededKey = "kosmoradio_hiphop_seeded_v2"

    override init() {
        LegacyDefaults.migrateIfNeeded()
        super.init()
        let savedVol = UserDefaults.standard.object(forKey: "kosmoradio_volume") as? Float
        if let savedVol {
            self.volume = savedVol
        }
        loadFavorites()
        setupRemoteTransportControls()
    }

    func play(_ station: RadioStation) {
        if currentStation?.id == station.id && (isPlaying || isBuffering) {
            togglePlayPause()
            return
        }

        stop()
        currentStation = station
        currentTrackMetadata = nil
        errorMessage = nil
        isBuffering = true

        guard let url = URL(string: station.streamURL) else {
            errorMessage = LocalizationManager.shared.t(
                "URL non valido: \(station.streamURL)",
                "Invalid URL: \(station.streamURL)"
            )
            isBuffering = false
            return
        }

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 4.0

        let output = AVPlayerItemMetadataOutput(identifiers: nil)
        output.setDelegate(self, queue: .main)
        item.add(output)
        self.metadataOutput = output

        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.volume = isMuted ? 0 : volume
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        self.player = newPlayer

        statusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .failed:
                    self.isPlaying = false
                    self.isBuffering = false
                    self.errorMessage = LocalizationManager.shared.t(
                        "Connessione allo stream non riuscita. Prova un'altra stazione.",
                        "Failed to connect to stream. Please try another station."
                    )
                    self.updateNowPlayingInfo()
                case .readyToPlay:
                    self.errorMessage = nil
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        timeControlObserver = newPlayer.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self else { return }
                switch player.timeControlStatus {
                case .playing:
                    self.isPlaying = true
                    self.isBuffering = false
                    self.errorMessage = nil
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                case .paused:
                    self.isPlaying = false
                    self.isBuffering = false
                @unknown default:
                    break
                }
                self.updateNowPlayingInfo()
            }
        }

        newPlayer.play()
        startIcyMetadataPolling(for: url, stationName: station.name)
        addToRecents(station)
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        guard let station = currentStation else {
            if let first = favorites.first ?? RadioStation.defaultHipHopStations.first {
                play(first)
            }
            return
        }
        if isPlaying || isBuffering {
            stop()
            currentStation = station
        } else {
            play(station)
        }
    }

    func stop() {
        icyPollTask?.cancel()
        icyPollTask = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        timeControlObserver?.invalidate()
        statusObserver?.invalidate()
        timeControlObserver = nil
        statusObserver = nil
        player = nil
        isPlaying = false
        isBuffering = false
        updateNowPlayingInfo()
    }

    func playNextFavorite() {
        let pool = favorites.isEmpty ? (RadioStation.defaultHipHopStations + RadioStation.defaultUkrainianStations) : favorites
        guard !pool.isEmpty else { return }
        if let current = currentStation, let idx = pool.firstIndex(where: { $0.id == current.id }) {
            let nextIdx = (idx + 1) % pool.count
            play(pool[nextIdx])
        } else if let first = pool.first {
            play(first)
        }
    }

    func playPreviousFavorite() {
        let pool = favorites.isEmpty ? (RadioStation.defaultHipHopStations + RadioStation.defaultUkrainianStations) : favorites
        guard !pool.isEmpty else { return }
        if let current = currentStation, let idx = pool.firstIndex(where: { $0.id == current.id }) {
            let prevIdx = (idx - 1 + pool.count) % pool.count
            play(pool[prevIdx])
        } else if let first = pool.first {
            play(first)
        }
    }

    // MARK: - Favorites

    func isFavorite(_ station: RadioStation) -> Bool {
        favorites.contains(where: { $0.id == station.id || $0.streamURL == station.streamURL })
    }

    func toggleFavorite(_ station: RadioStation) {
        if let idx = favorites.firstIndex(where: { $0.id == station.id || $0.streamURL == station.streamURL }) {
            favorites.remove(at: idx)
        } else {
            favorites.insert(station, at: 0)
        }
    }

    func addCustomStation(name: String, streamURL: String, country: String, countryCode: String, city: String, tags: String) {
        let station = RadioStation(
            id: "custom-\(UUID().uuidString)",
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            streamURL: streamURL.trimmingCharacters(in: .whitespacesAndNewlines),
            country: country.trimmingCharacters(in: .whitespacesAndNewlines),
            countryCode: countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags.trimmingCharacters(in: .whitespacesAndNewlines),
            faviconURL: nil,
            bitrate: nil,
            homepage: nil
        )
        favorites.insert(station, at: 0)
        play(station)
    }

    /// Adds stations to the top of Favorites, skipping ones already saved.
    func addFavorites(_ stations: [RadioStation]) {
        for st in stations.reversed() where !isFavorite(st) {
            favorites.insert(st, at: 0)
        }
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([RadioStation].self, from: data),
           !decoded.isEmpty {
            favorites = decoded
            if !UserDefaults.standard.bool(forKey: hipHopSeededKey) {
                let topRap = [
                    RadioStation.nycEastCoastHipHopStations[0], // WQHT Hot 97 NYC
                    RadioStation.nycEastCoastHipHopStations[1], // Power 105.1 NYC
                    RadioStation.oldSchool90sHipHopStations[0], // 90s90s Hip-Hop & Rap
                    RadioStation.nycEastCoastHipHopStations[2]  // Generations Rap US
                ]
                for st in topRap.reversed() {
                    if !isFavorite(st) {
                        favorites.insert(st, at: 0)
                    }
                }
                UserDefaults.standard.set(true, forKey: hipHopSeededKey)
            }
        } else {
            // First launch: the onboarding fills Favorites from the listener's picks.
            favorites = []
            UserDefaults.standard.set(true, forKey: hipHopSeededKey)
        }
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }

    private func addToRecents(_ station: RadioStation) {
        recentStations.removeAll(where: { $0.id == station.id })
        recentStations.insert(station, at: 0)
        if recentStations.count > 15 {
            recentStations = Array(recentStations.prefix(15))
        }
    }

    // MARK: - Sleep Timer

    func setSleepTimer(minutes: Int?) {
        sleepTimer?.invalidate()
        sleepTimer = nil
        guard let minutes, minutes > 0 else {
            sleepTimerRemainingSeconds = nil
            return
        }
        sleepTimerRemainingSeconds = minutes * 60
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let rem = self.sleepTimerRemainingSeconds {
                    if rem <= 1 {
                        self.stop()
                        self.sleepTimerRemainingSeconds = nil
                        self.sleepTimer?.invalidate()
                        self.sleepTimer = nil
                    } else {
                        self.sleepTimerRemainingSeconds = rem - 1
                    }
                }
            }
        }
    }

    // MARK: - macOS Media Keys & Control Center

    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stop() }
            return .success
        }
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playNextFavorite() }
            return .success
        }
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playPreviousFavorite() }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let station = currentStation else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTrackMetadata ?? station.name,
            MPMediaItemPropertyArtist: currentTrackMetadata != nil ? "\(station.flagEmoji) \(station.name)" : "\(station.flagEmoji) \(station.formattedSubtitle)",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    // MARK: - Live ICY StreamTitle Reader (for Icecast / SHOUTcast MP3 & AAC streams)

    private func startIcyMetadataPolling(for url: URL, stationName: String) {
        icyPollTask?.cancel()
        // Skip HLS m3u8 playlists (they use AVPlayerItemMetadataOutput natively)
        if url.pathExtension.lowercased() == "m3u8" { return }

        icyPollTask = Task {
            while !Task.isCancelled {
                if let title = await Self.fetchIcyStreamTitle(from: url) {
                    let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty, self.currentTrackMetadata != cleaned {
                        self.currentTrackMetadata = cleaned
                        self.updateNowPlayingInfo()
                        LyricsManager.shared.onTrackMetadataChanged(cleaned, stationName: stationName)
                    }
                }
                try? await Task.sleep(nanoseconds: 12_000_000_000)
            }
        }
    }

    nonisolated private static func fetchIcyStreamTitle(from url: URL) async -> String? {
        var req = URLRequest(url: url)
        req.setValue("1", forHTTPHeaderField: "Icy-MetaData")
        req.setValue("KosmoRadio/1.3", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 5

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 6
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        do {
            let (bytes, response) = try await session.bytes(for: req)
            guard let http = response as? HTTPURLResponse,
                  let metaintStr = http.value(forHTTPHeaderField: "icy-metaint"),
                  let metaint = Int(metaintStr),
                  metaint > 0 && metaint <= 131072 else {
                return nil
            }

            var iterator = bytes.makeAsyncIterator()
            // Skip audio frame bytes up to metaint
            for _ in 0..<metaint {
                if try await iterator.next() == nil { return nil }
            }

            guard let lengthByte = try await iterator.next() else { return nil }
            let metaLength = Int(lengthByte) * 16
            if metaLength == 0 || metaLength > 4096 { return nil }

            var metaData = Data(capacity: metaLength)
            for _ in 0..<metaLength {
                guard let b = try await iterator.next() else { break }
                if b != 0 {
                    metaData.append(b)
                }
            }

            guard let metaString = String(data: metaData, encoding: .utf8)
                    ?? String(data: metaData, encoding: .isoLatin1) else {
                return nil
            }

            if let range = metaString.range(of: "StreamTitle='") {
                let after = metaString[range.upperBound...]
                if let endRange = after.range(of: "';") ?? after.range(of: "'") {
                    let extracted = String(after[..<endRange.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return extracted.isEmpty ? nil : extracted
                }
            }
            return nil
        } catch {
            return nil
        }
    }
}

extension RadioPlayerManager: @preconcurrency AVPlayerItemMetadataOutputPushDelegate {
    func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        for group in groups {
            for item in group.items {
                Task { @MainActor in
                    if let str = try? await item.load(.stringValue) {
                        let cleaned = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleaned.isEmpty {
                            self.currentTrackMetadata = cleaned
                            self.updateNowPlayingInfo()
                            LyricsManager.shared.onTrackMetadataChanged(
                                cleaned,
                                stationName: self.currentStation?.name
                            )
                        }
                    }
                }
            }
        }
    }
}
