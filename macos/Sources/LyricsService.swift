import Foundation
import AppKit
import SwiftUI
import Combine

struct LrcLibSearchResult: Codable {
    let id: Int?
    let trackName: String?
    let artistName: String?
    let albumName: String?
    let plainLyrics: String?
    let syncedLyrics: String?
}

struct LyricsOvhResponse: Codable {
    let lyrics: String?
}

@MainActor
final class LyricsManager: ObservableObject {
    static let shared = LyricsManager()

    @Published var isSideDrawerOpen: Bool = false
    @Published var isFloatingWindowOpen: Bool = false
    @Published var isVisualizerLyricsOpen: Bool = false

    @Published var currentRawMetadata: String? = nil
    @Published var manualSearchText: String = ""

    @Published var resolvedTrackTitle: String = ""
    @Published var resolvedArtistName: String = ""
    @Published var resolvedAlbumName: String = ""
    @Published var lyricsText: String = "" {
        didSet {
            rebuildLines()
        }
    }
    @Published var lyricLines: [String] = []
    @Published var inLyricsSearchQuery: String = "" {
        didSet {
            updateInLyricsMatches()
        }
    }
    @Published var matchingLineIndices: [Int] = []
    @Published var currentMatchPointer: Int = 0
    @Published var activeLineIndex: Int? = nil
    @Published var scrollTriggerID: UUID = UUID()
    @Published var showSongSearchField: Bool = false

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var fontSize: CGFloat = 14.5

    private var lastSearchedQuery: String = ""
    private var fetchTask: Task<Void, Never>? = nil
    private var floatingPanel: NSPanel? = nil

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.httpAdditionalHeaders = [
            "User-Agent": "KosmoRadio/1.3 (https://github.com/marcellomarch/kosmo-radio-player)"
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Panel / Window Toggles

    func toggleSideDrawer() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
            isSideDrawerOpen.toggle()
        }
    }

    func popOutToFloatingWindow() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSideDrawerOpen = false
        }
        openFloatingPanel()
    }

    func dockBackToSideDrawer() {
        closeFloatingPanel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
            isSideDrawerOpen = true
        }
    }

    func openFloatingPanel() {
        if let panel = floatingPanel {
            panel.makeKeyAndOrderFront(nil)
            isFloatingWindowOpen = true
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 160, y: 160, width: 370, height: 540),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "🎤 Kosmo Radio Lyrics"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.11, alpha: 0.96)
        panel.minSize = NSSize(width: 300, height: 360)

        let rootView = LyricsPanelView(
            lyricsManager: self,
            mode: .floatingWindow
        )
        panel.contentView = NSHostingView(rootView: rootView)
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isFloatingWindowOpen = false
                self?.floatingPanel = nil
            }
        }

        self.floatingPanel = panel
        self.isFloatingWindowOpen = true
    }

    func closeFloatingPanel() {
        floatingPanel?.close()
        floatingPanel = nil
        isFloatingWindowOpen = false
    }

    // MARK: - Automatic Metadata Trigger

    func onTrackMetadataChanged(_ rawMeta: String?, stationName: String?) {
        currentRawMetadata = rawMeta
        guard let rawMeta, !rawMeta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        guard let cleaned = cleanRadioMetadata(rawMeta, stationName: stationName) else {
            return
        }

        // Avoid re-fetching the exact same song
        if cleaned.lowercased() == lastSearchedQuery.lowercased() && !lyricsText.isEmpty {
            return
        }

        manualSearchText = cleaned
        searchLyrics(query: cleaned)
    }

    func searchManual() {
        let q = manualSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        searchLyrics(query: q)
    }

    func increaseFontSize() {
        fontSize = min(22.0, fontSize + 1.5)
    }

    func decreaseFontSize() {
        fontSize = max(11.5, fontSize - 1.5)
    }

    // MARK: - In-Lyrics Live Phrase Finder & Karaoke Spotlight

    private func rebuildLines() {
        if lyricsText.isEmpty {
            lyricLines = []
        } else {
            lyricLines = lyricsText.components(separatedBy: .newlines)
        }
        inLyricsSearchQuery = ""
        matchingLineIndices = []
        currentMatchPointer = 0
        activeLineIndex = nil
    }

    private func normalizeForMatch(_ text: String) -> String {
        let lower = text.lowercased()
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "`", with: "")
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let scalars = lower.unicodeScalars.map { allowed.contains($0) ? Character($0) : Character(" ") }
        return String(scalars)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func updateInLyricsMatches() {
        let normalizedQuery = normalizeForMatch(inLyricsSearchQuery)
        guard !normalizedQuery.isEmpty, !lyricLines.isEmpty else {
            matchingLineIndices = []
            currentMatchPointer = 0
            return
        }

        let queryWords = normalizedQuery.components(separatedBy: " ").filter { !$0.isEmpty }
        var matches: [Int] = []

        // 1. Direct normalized substring match on each line
        for (idx, line) in lyricLines.enumerated() {
            let normLine = normalizeForMatch(line)
            if normLine.contains(normalizedQuery) {
                matches.append(idx)
            }
        }

        // 2. If user typed words spanning two consecutive lines or slightly out of order, match lines containing all typed words
        if matches.isEmpty && queryWords.count >= 2 {
            for idx in 0..<lyricLines.count {
                let combined = idx + 1 < lyricLines.count
                    ? normalizeForMatch(lyricLines[idx] + " " + lyricLines[idx + 1])
                    : normalizeForMatch(lyricLines[idx])
                if queryWords.allSatisfy({ combined.contains($0) }) {
                    matches.append(idx)
                }
            }
        }

        matchingLineIndices = matches
        currentMatchPointer = 0
        if let first = matches.first {
            activeLineIndex = first
            scrollTriggerID = UUID()
        }
    }

    func nextMatch() {
        guard !matchingLineIndices.isEmpty else {
            stepActiveLine(by: 1)
            return
        }
        currentMatchPointer = (currentMatchPointer + 1) % matchingLineIndices.count
        activeLineIndex = matchingLineIndices[currentMatchPointer]
        scrollTriggerID = UUID()
    }

    func previousMatch() {
        guard !matchingLineIndices.isEmpty else {
            stepActiveLine(by: -1)
            return
        }
        currentMatchPointer = (currentMatchPointer - 1 + matchingLineIndices.count) % matchingLineIndices.count
        activeLineIndex = matchingLineIndices[currentMatchPointer]
        scrollTriggerID = UUID()
    }

    func selectLine(_ index: Int) {
        guard index >= 0 && index < lyricLines.count else { return }
        activeLineIndex = index
        scrollTriggerID = UUID()
    }

    func stepActiveLine(by delta: Int) {
        guard !lyricLines.isEmpty else { return }
        let start = activeLineIndex ?? 0
        var next = start + delta
        while next >= 0 && next < lyricLines.count && lyricLines[next].trimmingCharacters(in: .whitespaces).isEmpty {
            next += (delta >= 0 ? 1 : -1)
        }
        if next >= 0 && next < lyricLines.count {
            activeLineIndex = next
            scrollTriggerID = UUID()
        }
    }

    func openOnGenius() {
        let q: String
        if !resolvedArtistName.isEmpty && !resolvedTrackTitle.isEmpty {
            q = "\(resolvedArtistName) \(resolvedTrackTitle)"
        } else if !manualSearchText.trimmingCharacters(in: .whitespaces).isEmpty {
            q = manualSearchText
        } else if let raw = currentRawMetadata, !raw.isEmpty {
            q = raw
        } else {
            q = "Hip Hop Lyrics"
        }

        var comps = URLComponents(string: "https://genius.com/search")
        comps?.queryItems = [URLQueryItem(name: "q", value: q)]
        if let url = comps?.url {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Smart Metadata Cleaning

    func cleanRadioMetadata(_ raw: String, stationName: String?) -> String? {
        var text = raw
            .replacingOccurrences(of: "`", with: "'")
            .replacingOccurrences(of: "´", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Ignore very short strings or URLs
        if text.count < 4 || text.lowercased().hasPrefix("http") {
            return nil
        }

        // Remove bracketed/parenthesized radio junk like [Live], (Radio Edit), (Clean), (Explicit)
        let junkPatterns = [
            #"\[[^\]]*\]"#,
            #"\((?:radio edit|clean|explicit|dirty|official[^\)]*|remaster[^\)]*|original mix|extended[^\)]*|\d{4})\)"#,
            #"\b\d{2,3}\s*kbps\b"#
        ]
        for pattern in junkPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                text = regex.stringByReplacingMatches(
                    in: text,
                    options: [],
                    range: NSRange(text.startIndex..., in: text),
                    withTemplate: ""
                )
            }
        }

        text = text
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " -•|"))

        // Ignore if the metadata is just the station's own name or slogan
        let lower = text.lowercased()
        if lower.contains("90s90s - hiphop") ||
           lower.contains("bigfm oldschool") ||
           lower.contains("commercial") ||
           lower.contains("advert") ||
           lower == (stationName ?? "").lowercased() {
            return nil
        }

        return text.isEmpty ? nil : text
    }

    // MARK: - Multi-Source Lyrics Lookup (LRCLIB + Lyrics.ovh fallback)

    func searchLyrics(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lastSearchedQuery = trimmed
        fetchTask?.cancel()
        isLoading = true
        errorMessage = nil

        fetchTask = Task {
            do {
                // 1. Try full query on LRCLIB
                if let match = try await queryLrcLib(trimmed) {
                    applyMatch(match)
                    return
                }

                // 2. If query contains "feat." or "&" or "-", try a simplified query without feat.
                let simplified = simplifyQuery(trimmed)
                if simplified.lowercased() != trimmed.lowercased(),
                   let match2 = try await queryLrcLib(simplified) {
                    applyMatch(match2)
                    return
                }

                // 3. Fallback to lyrics.ovh if we can split "Artist - Title"
                if let (artist, title) = splitArtistAndTitle(simplified),
                   let ovhLyrics = try await queryLyricsOvh(artist: artist, title: title) {
                    self.resolvedArtistName = artist
                    self.resolvedTrackTitle = title
                    self.resolvedAlbumName = ""
                    self.lyricsText = ovhLyrics
                    self.isLoading = false
                    return
                }

                guard !Task.isCancelled else { return }
                self.isLoading = false
                self.lyricsText = ""
                let parts = splitArtistAndTitle(trimmed)
                self.resolvedArtistName = parts?.artist ?? ""
                self.resolvedTrackTitle = parts?.title ?? trimmed
                self.errorMessage = LocalizationManager.shared.t(
                    "Testo non trovato nei database automatici per \"\(trimmed)\". Premi il pulsante Genius.com qui sotto per aprirlo sul web!",
                    "Lyrics not found in automatic databases for \"\(trimmed)\". Click the Genius.com button below to view on the web!"
                )
            } catch {
                guard !Task.isCancelled else { return }
                self.isLoading = false
                self.errorMessage = LocalizationManager.shared.t(
                    "Errore di connessione al database Lyrics. Riprova o apri su Genius.com.",
                    "Connection error while fetching lyrics. Retry or open on Genius.com."
                )
            }
        }
    }

    private func applyMatch(_ match: LrcLibSearchResult) {
        self.resolvedTrackTitle = match.trackName ?? manualSearchText
        self.resolvedArtistName = match.artistName ?? ""
        self.resolvedAlbumName = match.albumName ?? ""

        if let plain = match.plainLyrics, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.lyricsText = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let synced = match.syncedLyrics {
            self.lyricsText = stripLrcTimestamps(synced)
        }
        self.isLoading = false
        self.errorMessage = nil
    }

    private func queryLrcLib(_ q: String) async throws -> LrcLibSearchResult? {
        guard var comps = URLComponents(string: "https://lrclib.net/api/search") else { return nil }
        comps.queryItems = [URLQueryItem(name: "q", value: q)]
        guard let url = comps.url else { return nil }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }

        let results = try JSONDecoder().decode([LrcLibSearchResult].self, from: data)
        return results.first(where: {
            ($0.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ||
            ($0.syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        })
    }

    private func queryLyricsOvh(artist: String, title: String) async throws -> String? {
        guard let encArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let encTitle = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.lyrics.ovh/v1/\(encArtist)/\(encTitle)") else {
            return nil
        }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }
        let decoded = try JSONDecoder().decode(LyricsOvhResponse.self, from: data)
        if let lyr = decoded.lyrics?.trimmingCharacters(in: .whitespacesAndNewlines), !lyr.isEmpty {
            return lyr
        }
        return nil
    }

    private func simplifyQuery(_ q: String) -> String {
        var s = q
        let patterns = [
            #"\b(?:feat\.?|ft\.?|featuring)\s+[^-\(\)]+"#,
            #"\([^\)]*\)"#
        ]
        for p in patterns {
            if let rx = try? NSRegularExpression(pattern: p, options: .caseInsensitive) {
                s = rx.stringByReplacingMatches(
                    in: s,
                    options: [],
                    range: NSRange(s.startIndex..., in: s),
                    withTemplate: ""
                )
            }
        }
        return s.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func splitArtistAndTitle(_ q: String) -> (artist: String, title: String)? {
        let parts = q.components(separatedBy: " - ")
        if parts.count >= 2 {
            let a = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let t = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if !a.isEmpty && !t.isEmpty {
                return (a, t)
            }
        }
        return nil
    }

    private func stripLrcTimestamps(_ lrc: String) -> String {
        guard let rx = try? NSRegularExpression(pattern: #"\[\d{1,2}:\d{2}(?:\.\d{1,3})?\]"#, options: []) else {
            return lrc
        }
        let stripped = rx.stringByReplacingMatches(
            in: lrc,
            options: [],
            range: NSRange(lrc.startIndex..., in: lrc),
            withTemplate: ""
        )
        return stripped
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
