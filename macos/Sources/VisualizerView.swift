import SwiftUI
import AppKit
import Combine

enum VisualizerPreset: String, CaseIterable, Identifiable {
    case hyperspaceTunnel = "tunnel"
    case laserPlasma = "plasma"
    case acidKaleidoscope = "kaleidoscope"
    case ledSpectrum = "led"

    /// Reads a saved preset, including the identifiers used before 1.3.4.
    init?(savedValue: String) {
        let legacy = ["milkdrop": "tunnel", "geiss": "plasma", "winamp": "led"]
        self.init(rawValue: legacy[savedValue] ?? savedValue)
    }

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .hyperspaceTunnel: return "🌀"
        case .laserPlasma: return "⚡"
        case .acidKaleidoscope: return "🔮"
        case .ledSpectrum: return "📊"
        }
    }

    func title(isEnglish: Bool) -> String {
        switch self {
        case .hyperspaceTunnel:
            return isEnglish ? "Hyperspace Tunnel" : "Tunnel Iperspazio"
        case .laserPlasma:
            return "Laser Plasma"
        case .acidKaleidoscope:
            return isEnglish ? "Acid Kaleidoscope" : "Caleidoscopio Acido"
        case .ledSpectrum:
            return "LED Spectrum 2000"
        }
    }
}

@MainActor
final class VisualizerViewModel: ObservableObject {
    @Published var isExpandedFullWindow: Bool = false
    @Published var isMacNativeFullScreen: Bool = false
    @Published var currentPreset: VisualizerPreset = .hyperspaceTunnel {
        didSet {
            UserDefaults.standard.set(currentPreset.rawValue, forKey: "kosmoradio_viz_preset")
        }
    }
    @Published var showHUD: Bool = true

    // Peak hold state for the LED spectrum bars
    var peakHolds: [Double] = Array(repeating: 0.05, count: 32)
    var peakVelocities: [Double] = Array(repeating: 0.0, count: 32)
    var lastFrameTime: Double = 0

    private var hudTimer: Timer?

    init() {
        LegacyDefaults.migrateIfNeeded()
        if let saved = UserDefaults.standard.string(forKey: "kosmoradio_viz_preset"),
           let preset = VisualizerPreset(savedValue: saved) {
            self.currentPreset = preset
        }
    }

    func nextPreset() {
        let all = VisualizerPreset.allCases
        if let idx = all.firstIndex(of: currentPreset) {
            currentPreset = all[(idx + 1) % all.count]
        }
    }

    func toggleExpanded() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            isExpandedFullWindow.toggle()
        }
        if isExpandedFullWindow {
            registerUserActivity()
        } else if isMacNativeFullScreen {
            toggleMacFullScreen()
        }
    }

    func toggleMacFullScreen() {
        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first(where: { $0.canBecomeKey }) {
            window.toggleFullScreen(nil)
            isMacNativeFullScreen.toggle()
            if !isExpandedFullWindow {
                isExpandedFullWindow = true
            }
        }
        registerUserActivity()
    }

    func registerUserActivity() {
        if !showHUD {
            withAnimation(.easeInOut(duration: 0.2)) {
                showHUD = true
            }
        }
        hudTimer?.invalidate()
        hudTimer = Timer.scheduledTimer(withTimeInterval: 3.2, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isExpandedFullWindow else { return }
                withAnimation(.easeInOut(duration: 0.45)) {
                    self.showHUD = false
                }
            }
        }
    }
}

// MARK: - Real-Time Audio / Beat Frame Snapshot

struct AudioFrameState {
    let time: Double
    let isPlaying: Bool
    let bass: Double       // 0.0 ... 1.0 (Kick / 808)
    let mid: Double        // 0.0 ... 1.0 (Snare / Vocals)
    let high: Double       // 0.0 ... 1.0 (Hi-Hats / Synth)
    let kickPulse: Double  // Sharp transient spike 0.0 ... 1.0
    let bands: [Double]    // 32 frequency bands
    let waveform: [Double] // 64 oscilloscope samples (-1.0 ... 1.0)

    static func compute(at date: Date, isPlaying: Bool, volume: Float, stationSeed: Int) -> AudioFrameState {
        let t = date.timeIntervalSinceReferenceDate
        let vol = Double(max(0.15, volume))

        guard isPlaying else {
            // Subtle idle breathing state when paused
            let idleWave = (0..<64).map { i -> Double in
                let x = Double(i) / 63.0 * .pi * 2.0
                return sin(x + t * 1.4) * 0.08
            }
            let idleBands = (0..<32).map { i -> Double in
                0.04 + 0.03 * sin(t * 1.5 + Double(i) * 0.3)
            }
            return AudioFrameState(
                time: t,
                isPlaying: false,
                bass: 0.08 + 0.04 * sin(t * 1.2),
                mid: 0.06,
                high: 0.05,
                kickPulse: 0.0,
                bands: idleBands,
                waveform: idleWave
            )
        }

        // Dynamic BPM based on station seed (between 88 and 104 BPM for Boom Bap / Hip-Hop feel)
        let bpm = 92.0 + Double(abs(stationSeed) % 14)
        let beatPeriod = 60.0 / bpm
        let beatPhase = (t.truncatingRemainder(dividingBy: beatPeriod)) / beatPeriod
        let barPhase = (t.truncatingRemainder(dividingBy: beatPeriod * 4.0)) / (beatPeriod * 4.0)

        // Sharp 808 / Boom-Bap kick envelope with double-kick groove variation
        let primaryKick = exp(-beatPhase * 6.5)
        let syncopatedKick = (barPhase > 0.35 && barPhase < 0.5) || (barPhase > 0.85)
            ? exp(-((beatPhase * 2.0).truncatingRemainder(dividingBy: 1.0)) * 8.0) * 0.75
            : 0.0
        let rawKick = min(1.0, max(primaryKick, syncopatedKick))

        // Snare hit on beats 2 and 4
        let halfBarPhase = (t.truncatingRemainder(dividingBy: beatPeriod * 2.0)) / (beatPeriod * 2.0)
        let snareDist = abs(halfBarPhase - 0.5)
        let snareHit = snareDist < 0.12 ? exp(-snareDist * 28.0) : 0.0

        // Continuous organic modulation (simulating vocal & melody dynamics)
        let grooveMod = 0.55 + 0.45 * sin(t * 0.85) * cos(t * 0.37)
        let bass = min(1.0, (0.28 + rawKick * 0.72 * grooveMod) * vol)
        let mid = min(1.0, (0.22 + snareHit * 0.55 + 0.28 * abs(sin(t * 3.7 + cos(t * 1.9)))) * vol)
        let high = min(1.0, (0.18 + 0.45 * abs(sin(t * 11.3) * cos(t * 7.1)) + snareHit * 0.3) * vol)
        let kickPulse = pow(rawKick, 1.6) * vol

        // 32 spectrum bands
        var bands = [Double](repeating: 0, count: 32)
        for i in 0..<32 {
            let norm = Double(i) / 31.0
            let subWeight = exp(-norm * 4.2)
            let midWeight = exp(-pow((norm - 0.42) * 3.8, 2))
            let highWeight = exp(-pow((norm - 0.82) * 4.5, 2))

            let harmonicRipple = 0.7 + 0.3 * sin(t * (5.0 + Double(i) * 0.45) + Double(i) * 0.9)
            let val = (bass * subWeight * 1.05 + mid * midWeight * 0.95 + high * highWeight * 0.85) * harmonicRipple
            bands[i] = min(1.0, max(0.04, val))
        }

        // 64 oscilloscope waveform points
        var wave = [Double](repeating: 0, count: 64)
        for i in 0..<64 {
            let x = Double(i) / 63.0 * .pi * 2.0
            let carrier = sin(x * 2.0 + t * 8.0) * bass * 0.55
            let vocal = sin(x * 5.0 - t * 13.0) * mid * 0.35
            let fizz = sin(x * 13.0 + t * 27.0) * high * 0.22
            let envelope = sin(Double(i) / 63.0 * .pi) // Taper ends smoothly
            wave[i] = max(-1.0, min(1.0, (carrier + vocal + fizz) * envelope))
        }

        return AudioFrameState(
            time: t,
            isPlaying: true,
            bass: bass,
            mid: mid,
            high: high,
            kickPulse: kickPulse,
            bands: bands,
            waveform: wave
        )
    }
}

// MARK: - Sidebar Mini-Visor View (Y2K CRT box)

struct SidebarVisualizerMiniView: View {
    @ObservedObject var player: RadioPlayerManager
    @ObservedObject var vizVM: VisualizerViewModel
    @ObservedObject var l10n = LocalizationManager.shared
    @ObservedObject var floating = FloatingVisualizerController.shared
    /// True while the mini visualizer is being dragged out into its own window.
    @State private var draggingOut = false

    var body: some View {
        if floating.isOpen && !draggingOut {
            detachedRow
        } else {
            miniVisualizer
        }
    }

    /// Shown in the sidebar while the visualizer lives in its floating window.
    private var detachedRow: some View {
        Button {
            floating.close()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "pip.enter")
                Text(l10n.t("Visualizer in finestra · Riaggancia", "Visualizer in its window · Dock back"))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .help(l10n.t("Chiudi la finestra flottante e rimetti il visualizer qui", "Close the floating window and put the visualizer back here"))
    }

    private func popOut(at point: NSPoint? = nil) {
        floating.open(player: player, vizVM: vizVM, centeredAt: point)
    }

    private var dragOut: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { value in
                let distance = hypot(value.translation.width, value.translation.height)
                if !draggingOut {
                    guard distance > 40 else { return }
                    draggingOut = true
                    popOut(at: NSEvent.mouseLocation)
                } else {
                    floating.move(centerTo: NSEvent.mouseLocation)
                }
            }
            .onEnded { _ in
                draggingOut = false
            }
    }

    private var miniVisualizer: some View {
        ZStack {
            VisualizerCanvasView(
                player: player,
                vizVM: vizVM,
                isMiniMode: true
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Subtle CRT scanline & glossy bezel overlay
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.accentColor.opacity(0.45),
                            Color.purple.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )

            // Top & Bottom Mini Controls Overlay
            VStack {
                HStack(spacing: 6) {
                    // Preset switcher pill
                    Button {
                        vizVM.nextPreset()
                    } label: {
                        HStack(spacing: 4) {
                            Text(vizVM.currentPreset.icon)
                                .font(.system(size: 10))
                            Text(vizVM.currentPreset.title(isEnglish: l10n.isEnglish))
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.65))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(l10n.t("Cambia effetto psichedelico", "Switch psychedelic preset"))

                    Spacer()

                    // Pop out into a floating always-on-top window
                    Button {
                        popOut()
                    } label: {
                        Image(systemName: "pip.exit")
                            .font(.system(size: 9, weight: .bold))
                            .padding(5)
                            .background(Color.black.opacity(0.65))
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(l10n.t("Stacca in una finestretta sempre in primo piano", "Pop out into a small always-on-top window"))

                    // Expand icon badge
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(5)
                    .background(Color.black.opacity(0.65))
                    .foregroundStyle(.white)
                    .clipShape(Circle())
                }
                .padding(7)

                Spacer()

                HStack {
                    Text(
                        player.isPlaying
                            ? l10n.t("CLIC: FULL SCREEN · TRASCINA: STACCA", "CLICK: FULL SCREEN · DRAG: POP OUT")
                            : l10n.t("VISUALIZER Y2K (IN PAUSA)", "Y2K VISUALIZER (PAUSED)")
                    )
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())

                    Spacer()
                }
                .padding(.horizontal, 7)
                .padding(.bottom, 6)
            }
        }
        .frame(height: 132)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .gesture(dragOut)
        .onTapGesture {
            vizVM.toggleExpanded()
        }
        .help(l10n.t(
            "Clicca per il Visualizer a tutto schermo, trascinalo fuori per staccarlo in una finestretta",
            "Click for the full-screen Visualizer, drag it out to pop it into a small window"
        ))
    }
}

// MARK: - Full-Screen / Full-Window Psychedelic Visualizer Overlay

struct FullScreenVisualizerOverlay: View {
    @ObservedObject var player: RadioPlayerManager
    @ObservedObject var vizVM: VisualizerViewModel
    @ObservedObject var lyricsManager = LyricsManager.shared
    @ObservedObject var l10n = LocalizationManager.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Main high-fps Psychedelic Canvas
            VisualizerCanvasView(
                player: player,
                vizVM: vizVM,
                isMiniMode: false
            )
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                vizVM.toggleMacFullScreen()
            }
            .onTapGesture(count: 1) {
                vizVM.toggleExpanded()
            }
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    vizVM.registerUserActivity()
                case .ended:
                    break
                }
            }

            // Floating Lyrics Overlay Card on the right when enabled in Full Screen
            if lyricsManager.isVisualizerLyricsOpen {
                HStack {
                    Spacer()
                    LyricsPanelView(
                        lyricsManager: lyricsManager,
                        mode: .visualizerOverlay
                    )
                    .frame(width: 370)
                    .padding(.top, 74)
                    .padding(.bottom, 145)
                    .padding(.trailing, 24)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                .zIndex(20)
            }

            // Floating HUD (Top Bar + Bottom Control Dock)
            if vizVM.showHUD {
                VStack {
                    // Top Bar
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Text("✨ Y2K PSYCHO-VISION")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.cyan)
                            Text("•")
                                .foregroundStyle(.white.opacity(0.4))
                            Text(
                                l10n.t(
                                    "Clic sullo sfondo per ridurre • Doppio clic per Schermo Intero Mac",
                                    "Click background to exit • Double-click for Mac Full Screen"
                                )
                            )
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.75))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                                lyricsManager.isVisualizerLyricsOpen.toggle()
                            }
                            vizVM.registerUserActivity()
                        } label: {
                            HStack(spacing: 5) {
                                Text("🎤")
                                Text("Lyrics")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(
                                lyricsManager.isVisualizerLyricsOpen
                                    ? Color.accentColor
                                    : Color.white.opacity(0.18)
                            )
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            vizVM.toggleMacFullScreen()
                        } label: {
                            Label(
                                l10n.t("Schermo Intero Mac", "Mac Full Screen"),
                                systemImage: "macwindow.on.rectangle"
                            )
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            vizVM.toggleExpanded()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                Text(l10n.t("Riduci", "Minimize"))
                            }
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.2))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.escape, modifiers: [])
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    Spacer()

                    // Bottom Floating HUD
                    VStack(spacing: 14) {
                        // Preset Selector Pills
                        HStack(spacing: 10) {
                            ForEach(VisualizerPreset.allCases) { preset in
                                let selected = (vizVM.currentPreset == preset)
                                Button {
                                    vizVM.currentPreset = preset
                                    vizVM.registerUserActivity()
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(preset.icon)
                                        Text(preset.title(isEnglish: l10n.isEnglish))
                                            .font(.system(size: 12, weight: selected ? .bold : .medium, design: .monospaced))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(selected ? Color.accentColor : Color.black.opacity(0.55))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(selected ? 0.5 : 0.18), lineWidth: 1)
                                    )
                                    .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Station & Transport Bar
                        HStack(spacing: 20) {
                            HStack(spacing: 12) {
                                Text(player.currentStation?.flagEmoji ?? "📻")
                                    .font(.system(size: 30))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(
                                        player.currentStation?.name
                                            ?? l10n.t("Scegli una stazione", "Choose a station")
                                    )
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                    if let track = player.currentTrackMetadata, !track.isEmpty {
                                        Text("♪ \(track)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.cyan)
                                            .lineLimit(1)
                                    } else {
                                        Text(player.currentStation?.formattedSubtitle ?? "Kosmo Radio Visualizer")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white.opacity(0.7))
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .frame(maxWidth: 340, alignment: .leading)

                            Spacer()

                            HStack(spacing: 18) {
                                Button {
                                    player.playPreviousFavorite()
                                    vizVM.registerUserActivity()
                                } label: {
                                    Image(systemName: "backward.end.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    player.togglePlayPause()
                                    vizVM.registerUserActivity()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.accentColor)
                                            .frame(width: 44, height: 44)
                                        Image(systemName: (player.isPlaying || player.isBuffering) ? "pause.fill" : "play.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(.plain)

                                Button {
                                    player.playNextFavorite()
                                    vizVM.registerUserActivity()
                                } label: {
                                    Image(systemName: "forward.end.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()

                            HStack(spacing: 8) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(.white.opacity(0.75))
                                Slider(
                                    value: Binding(
                                        get: { Double(player.volume) },
                                        set: {
                                            player.isMuted = false
                                            player.volume = Float($0)
                                            vizVM.registerUserActivity()
                                        }
                                    ),
                                    in: 0...1
                                )
                                .frame(width: 110)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .frame(maxWidth: 860)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Core 60/120 FPS Psychedelic Canvas Renderer

struct VisualizerCanvasView: View {
    @ObservedObject var player: RadioPlayerManager
    @ObservedObject var vizVM: VisualizerViewModel
    let isMiniMode: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let seed = player.currentStation?.id.hashValue ?? 42
            let frame = AudioFrameState.compute(
                at: timeline.date,
                isPlaying: player.isPlaying,
                volume: player.isMuted ? 0 : player.volume,
                stationSeed: seed
            )

            Canvas { context, size in
                switch vizVM.currentPreset {
                case .hyperspaceTunnel:
                    drawHyperspaceTunnel(context: &context, size: size, frame: frame)
                case .laserPlasma:
                    drawLaserPlasma(context: &context, size: size, frame: frame)
                case .acidKaleidoscope:
                    drawAcidKaleidoscope(context: &context, size: size, frame: frame)
                case .ledSpectrum:
                    drawLEDSpectrum(context: &context, size: size, frame: frame)
                }
            }
        }
    }

    // MARK: 1. Hyperspace Tunnel

    private func drawHyperspaceTunnel(
        context: inout GraphicsContext,
        size: CGSize,
        frame: AudioFrameState
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = hypot(size.width, size.height) * 0.62
        let t = frame.time

        // Deep reactive background glow
        let bgHue = (t * 0.06).truncatingRemainder(dividingBy: 1.0)
        let bgRect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(bgRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(hue: bgHue, saturation: 0.85, brightness: 0.22 + frame.kickPulse * 0.28),
                    Color(red: 0.02, green: 0.01, blue: 0.06)
                ]),
                center: center,
                startRadius: 2,
                endRadius: maxRadius
            )
        )

        let ringCount = isMiniMode ? 14 : 24
        let speed = frame.isPlaying ? 0.55 : 0.12

        // Draw 3D perspective warping polygon rings
        for i in 0..<ringCount {
            let progress = ((Double(i) / Double(ringCount)) + t * speed).truncatingRemainder(dividingBy: 1.0)
            let depth = pow(progress, 2.35) // Exponential perspective depth
            let radius = max(4.0, depth * maxRadius * (1.0 + frame.kickPulse * 0.18))

            // Vortex spiral drift
            let wobbleX = cos(t * 2.1 + progress * 6.0) * (1.0 - progress) * (isMiniMode ? 14 : 42) * (0.4 + frame.bass)
            let wobbleY = sin(t * 1.7 + progress * 6.0) * (1.0 - progress) * (isMiniMode ? 14 : 42) * (0.4 + frame.mid)
            let ringCenter = CGPoint(x: center.x + wobbleX, y: center.y + wobbleY)

            let sides = 6
            let rotation = t * 0.9 + progress * 4.5 + frame.bass * 0.6
            var poly = Path()

            for s in 0...sides {
                let angle = Double(s) / Double(sides) * .pi * 2.0 + rotation
                let bandVal = frame.bands[(i + s * 3) % frame.bands.count]
                let rMod = radius * (1.0 + bandVal * 0.22 * sin(Double(s) * 2.0 + t * 5.0))
                let pt = CGPoint(
                    x: ringCenter.x + cos(angle) * rMod,
                    y: ringCenter.y + sin(angle) * rMod
                )
                if s == 0 {
                    poly.move(to: pt)
                } else {
                    poly.addLine(to: pt)
                }
            }
            poly.closeSubpath()

            let hue = (bgHue + progress * 0.65 + frame.kickPulse * 0.15).truncatingRemainder(dividingBy: 1.0)
            let alpha = min(1.0, progress * 1.35) * (0.35 + frame.bass * 0.65)
            let lineWidth = CGFloat(1.0 + depth * (isMiniMode ? 2.8 : 5.5) * (0.7 + frame.kickPulse * 0.6))

            context.stroke(
                poly,
                with: .color(Color(hue: hue, saturation: 0.9, brightness: 1.0, opacity: alpha)),
                lineWidth: lineWidth
            )
        }

        // Central Reactive Oscilloscope Ring
        let baseR = min(size.width, size.height) * (isMiniMode ? 0.22 : 0.18) * (0.85 + frame.bass * 0.45)
        var waveRing = Path()
        let count = frame.waveform.count
        for i in 0...count {
            let idx = i % count
            let angle = Double(i) / Double(count) * .pi * 2.0 - t * 1.5
            let displacement = frame.waveform[idx] * baseR * 0.55
            let r = baseR + displacement
            let pt = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if i == 0 {
                waveRing.move(to: pt)
            } else {
                waveRing.addLine(to: pt)
            }
        }
        waveRing.closeSubpath()

        context.stroke(
            waveRing,
            with: .color(Color.cyan.opacity(0.92)),
            lineWidth: isMiniMode ? 1.8 : 3.0
        )
    }

    // MARK: 2. Laser Plasma & Scope

    private func drawLaserPlasma(
        context: inout GraphicsContext,
        size: CGSize,
        frame: AudioFrameState
    ) {
        let t = frame.time
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // Dark plasma background
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(red: 0.03, green: 0.01, blue: 0.07))
        )

        // Glowing Plasma Orbs
        let orbCount = isMiniMode ? 5 : 8
        for i in 0..<orbCount {
            let fi = Double(i)
            let hue = ((t * 0.08) + fi * 0.14).truncatingRemainder(dividingBy: 1.0)
            let orbX = center.x + cos(t * (0.7 + fi * 0.15) + fi * 1.3) * size.width * 0.34
            let orbY = center.y + sin(t * (0.9 + fi * 0.12) + fi * 2.1) * size.height * 0.32
            let orbR = min(size.width, size.height) * (0.28 + frame.bands[i * 3] * 0.32)

            let orbCenter = CGPoint(x: orbX, y: orbY)
            let orbRect = CGRect(x: orbX - orbR, y: orbY - orbR, width: orbR * 2, height: orbR * 2)

            context.fill(
                Path(ellipseIn: orbRect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(hue: hue, saturation: 0.95, brightness: 1.0, opacity: 0.42 + frame.kickPulse * 0.25),
                        Color(hue: hue, saturation: 0.95, brightness: 0.5, opacity: 0.0)
                    ]),
                    center: orbCenter,
                    startRadius: 2,
                    endRadius: orbR
                )
            )
        }

        // Dual Laser Oscilloscope Ribbon Waves
        for layer in 0..<3 {
            let layerOffset = Double(layer) * 0.45
            var path = Path()
            let points = frame.waveform.count
            for i in 0..<points {
                let x = CGFloat(Double(i) / Double(points - 1)) * size.width
                let sample = frame.waveform[i]
                let harmonic = sin(Double(i) * 0.22 + t * 6.0 + layerOffset) * frame.mid * 0.35
                let amp = size.height * 0.36 * (sample + harmonic)
                let y = center.y + CGFloat(amp)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            let laserHue = ((t * 0.15) + Double(layer) * 0.28).truncatingRemainder(dividingBy: 1.0)
            // Outer neon glow
            context.stroke(
                path,
                with: .color(Color(hue: laserHue, saturation: 0.9, brightness: 1.0, opacity: 0.45)),
                lineWidth: isMiniMode ? 4.5 : 9.0
            )
            // Inner hot core
            context.stroke(
                path,
                with: .color(Color.white.opacity(layer == 0 ? 0.95 : 0.65)),
                lineWidth: isMiniMode ? 1.5 : 2.5
            )
        }
    }

    // MARK: 3. Acid Kaleidoscope

    private func drawAcidKaleidoscope(
        context: inout GraphicsContext,
        size: CGSize,
        frame: AudioFrameState
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let minDim = min(size.width, size.height)
        let t = frame.time

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(red: 0.02, green: 0.02, blue: 0.05))
        )

        let symmetry = 10
        let layers = isMiniMode ? 3 : 5

        for layer in 0..<layers {
            let fl = Double(layer)
            let baseRadius = minDim * (0.12 + fl * 0.085) * (0.85 + frame.bass * 0.38)
            let hue = ((t * 0.09) + fl * 0.18 + frame.kickPulse * 0.12).truncatingRemainder(dividingBy: 1.0)

            var mandala = Path()
            let steps = 72
            for s in 0...steps {
                let theta = Double(s) / Double(steps) * .pi * 2.0
                let petalWave = sin(theta * Double(symmetry) + t * (1.8 + fl * 0.4))
                let subPetal = cos(theta * Double(symmetry * 2) - t * 2.5) * frame.mid
                let bandVal = frame.bands[(s + layer * 5) % frame.bands.count]

                let r = baseRadius * (1.0 + 0.35 * petalWave * (0.4 + bandVal) + 0.2 * subPetal)
                let rotTheta = theta + t * (layer.isMultiple(of: 2) ? 0.35 : -0.35)
                let pt = CGPoint(
                    x: center.x + cos(rotTheta) * r,
                    y: center.y + sin(rotTheta) * r
                )
                if s == 0 {
                    mandala.move(to: pt)
                } else {
                    mandala.addLine(to: pt)
                }
            }
            mandala.closeSubpath()

            context.stroke(
                mandala,
                with: .color(Color(hue: hue, saturation: 0.85, brightness: 1.0, opacity: 0.78)),
                lineWidth: isMiniMode ? 1.8 : 3.2
            )
        }

        // Sparkling radial rays on kicks & hi-hats
        let rayCount = isMiniMode ? 12 : 20
        for rIdx in 0..<rayCount {
            let angle = Double(rIdx) / Double(rayCount) * .pi * 2.0 + t * 0.5
            let bandVal = frame.bands[rIdx % frame.bands.count]
            let innerR = minDim * 0.05
            let outerR = minDim * (0.15 + bandVal * 0.34 + frame.kickPulse * 0.12)

            var ray = Path()
            ray.move(to: CGPoint(x: center.x + cos(angle) * innerR, y: center.y + sin(angle) * innerR))
            ray.addLine(to: CGPoint(x: center.x + cos(angle) * outerR, y: center.y + sin(angle) * outerR))

            let rayHue = ((t * 0.12) + Double(rIdx) / Double(rayCount)).truncatingRemainder(dividingBy: 1.0)
            context.stroke(
                ray,
                with: .color(Color(hue: rayHue, saturation: 0.75, brightness: 1.0, opacity: 0.55)),
                lineWidth: isMiniMode ? 1.2 : 2.2
            )
        }
    }

    // MARK: 4. LED Spectrum + Oscilloscope

    private func drawLEDSpectrum(
        context: inout GraphicsContext,
        size: CGSize,
        frame: AudioFrameState
    ) {
        // Dark metallic CRT background + grid
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.10),
                    Color(red: 0.01, green: 0.02, blue: 0.04)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        // Subtle CRT grid lines
        let gridRows = isMiniMode ? 6 : 12
        for r in 1..<gridRows {
            let y = size.height * CGFloat(r) / CGFloat(gridRows)
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(line, with: .color(Color.white.opacity(0.05)), lineWidth: 1)
        }

        // Top Oscilloscope Wave (cyan/green)
        var scope = Path()
        let scopeCenterY = size.height * 0.22
        let scopeAmp = size.height * 0.14
        for (i, sample) in frame.waveform.enumerated() {
            let x = CGFloat(Double(i) / Double(frame.waveform.count - 1)) * size.width
            let y = scopeCenterY + CGFloat(sample) * scopeAmp
            if i == 0 {
                scope.move(to: CGPoint(x: x, y: y))
            } else {
                scope.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.stroke(
            scope,
            with: .color(Color(red: 0.0, green: 0.95, blue: 0.85, opacity: 0.9)),
            lineWidth: isMiniMode ? 1.5 : 2.5
        )

        // Bottom 32-Band Segmented LED Bars
        let barCount = isMiniMode ? 20 : 32
        let hPadding: CGFloat = isMiniMode ? 10 : 28
        let usableWidth = size.width - hPadding * 2
        let spacing: CGFloat = isMiniMode ? 3 : 5
        let barWidth = max(2, (usableWidth - spacing * CGFloat(barCount - 1)) / CGFloat(barCount))
        let maxBarHeight = size.height * 0.60
        let baselineY = size.height - (isMiniMode ? 10 : 24)

        for i in 0..<barCount {
            let bandVal = frame.bands[i % frame.bands.count]
            let x = hPadding + CGFloat(i) * (barWidth + spacing)

            // Draw segmented LED blocks
            let segments = isMiniMode ? 12 : 22
            let segSpacing: CGFloat = 1.5
            let segHeight = (maxBarHeight - segSpacing * CGFloat(segments - 1)) / CGFloat(segments)
            let activeSegments = Int(round(bandVal * Double(segments)))

            for s in 0..<activeSegments {
                let segY = baselineY - CGFloat(s + 1) * (segHeight + segSpacing)
                let segRect = CGRect(x: x, y: segY, width: barWidth, height: segHeight)
                let frac = Double(s) / Double(segments)

                let segColor: Color
                if frac < 0.55 {
                    segColor = Color(red: 0.15, green: 0.92, blue: 0.38) // Classic LED green
                } else if frac < 0.80 {
                    segColor = Color(red: 1.0, green: 0.82, blue: 0.12) // Yellow/Amber
                } else {
                    segColor = Color(red: 1.0, green: 0.22, blue: 0.32) // Red Peak
                }

                context.fill(Path(roundedRect: segRect, cornerRadius: 1.5), with: .color(segColor))
            }

            // Floating Peak-Hold Cap
            let peakFactor = min(1.0, bandVal + 0.08 + 0.06 * abs(sin(frame.time * 2.8 + Double(i) * 0.4)))
            let peakY = baselineY - CGFloat(peakFactor) * maxBarHeight - 3
            let capRect = CGRect(x: x, y: peakY, width: barWidth, height: isMiniMode ? 2.0 : 3.0)
            context.fill(
                Path(roundedRect: capRect, cornerRadius: 1),
                with: .color(Color.white.opacity(0.92))
            )
        }
    }
}
