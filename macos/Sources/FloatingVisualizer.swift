import SwiftUI
import AppKit

/// A small always-on-top window with the visualizer, like picture-in-picture.
/// It is opened by dragging the sidebar mini visualizer out of the window
/// (or with its pop-out button) and stays visible over other apps.
@MainActor
final class FloatingVisualizerController: ObservableObject {
    static let shared = FloatingVisualizerController()

    @Published private(set) var isOpen = false
    private var panel: NSPanel?
    private static let frameKey = "kosmoradio_viz_float_frame"
    private static let defaultSize = NSSize(width: 256, height: 144)

    private init() {}

    /// Opens the window. With `centeredAt` (screen coordinates) it appears under
    /// the cursor; otherwise where it was last time, or in the bottom-right corner.
    func open(player: RadioPlayerManager, vizVM: VisualizerViewModel, centeredAt point: NSPoint? = nil) {
        if let panel {
            if let point { move(centerTo: point) }
            panel.orderFrontRegardless()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Kosmo Radio Visualizer"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .black
        panel.contentAspectRatio = NSSize(width: 16, height: 9)
        panel.minSize = NSSize(width: 160, height: 90)
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(
            rootView: FloatingVisualizerView(player: player, vizVM: vizVM, controller: self)
        )

        if let saved = UserDefaults.standard.string(forKey: Self.frameKey) {
            panel.setFrame(NSRectFromString(saved), display: false)
        } else if let visible = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(
                x: visible.maxX - Self.defaultSize.width - 24,
                y: visible.minY + 24
            ))
        }
        self.panel = panel
        if let point { move(centerTo: point) }
        ensureOnScreen()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: panel, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.didClose() }
        }
        panel.orderFrontRegardless()
        isOpen = true
    }

    /// Keeps the window centred under the cursor while it's being dragged out.
    func move(centerTo point: NSPoint) {
        guard let panel else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: point.x - size.width / 2, y: point.y - size.height / 2))
    }

    func close() {
        panel?.close()
    }

    private func ensureOnScreen() {
        guard let panel else { return }
        let screens = NSScreen.screens.map(\.visibleFrame)
        if !screens.contains(where: { $0.intersects(panel.frame) }), let visible = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: visible.maxX - panel.frame.width - 24, y: visible.minY + 24))
        }
    }

    private func didClose() {
        if let panel {
            UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: Self.frameKey)
        }
        panel = nil
        isOpen = false
    }
}

// MARK: - Window content

struct FloatingVisualizerView: View {
    @ObservedObject var player: RadioPlayerManager
    @ObservedObject var vizVM: VisualizerViewModel
    let controller: FloatingVisualizerController
    @ObservedObject var l10n = LocalizationManager.shared
    @State private var hovering = false
    @State private var showVolume = false
    @State private var hideVolumeTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            VisualizerCanvasView(player: player, vizVM: vizVM, isMiniMode: true)

            // Drag anywhere on the picture to move the window; scroll to change the volume.
            WindowDragArea(onScroll: changeVolume)

            if showVolume {
                HStack(spacing: 5) {
                    Image(systemName: volumeSymbol)
                    Text("\(Int((player.isMuted ? 0 : player.volume) * 100))%")
                        .monospacedDigit()
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if hovering {
                VStack {
                    HStack(spacing: 6) {
                        Button {
                            vizVM.nextPreset()
                        } label: {
                            HStack(spacing: 4) {
                                Text(vizVM.currentPreset.icon).font(.system(size: 10))
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
                        .help(l10n.t("Cambia effetto", "Switch effect"))

                        Spacer(minLength: 4)

                        circleButton("xmark", help: l10n.t("Rimetti nella barra laterale", "Put back in the sidebar")) {
                            controller.close()
                        }
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        circleButton(player.isPlaying ? "pause.fill" : "play.fill",
                                     help: l10n.t("Play / Pausa", "Play / Pause")) {
                            player.togglePlayPause()
                        }
                    }
                }
                .padding(7)
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .onHover { inside in
            withAnimation(.easeInOut(duration: 0.15)) { hovering = inside }
        }
    }

    private var volumeSymbol: String {
        let v = player.isMuted ? 0 : player.volume
        if v == 0 { return "speaker.slash.fill" }
        return v < 0.34 ? "speaker.wave.1.fill" : v < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
    }

    /// `step` > 0 raises the volume (wheel or two-finger swipe up), < 0 lowers it.
    private func changeVolume(_ step: Float) {
        let current = player.isMuted ? 0 : player.volume
        let new = min(1, max(0, current + step))
        if player.isMuted && step > 0 { player.isMuted = false }
        player.volume = new
        withAnimation(.easeInOut(duration: 0.12)) { showVolume = true }
        hideVolumeTask?.cancel()
        hideVolumeTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { showVolume = false }
        }
    }

    private func circleButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .frame(width: 20, height: 20)
                .background(Color.black.opacity(0.65))
                .foregroundStyle(.white)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Transparent view that moves its window when dragged and reports scrolling
/// as a volume step (positive = up, whatever the "natural scrolling" setting).
private struct WindowDragArea: NSViewRepresentable {
    let onScroll: (Float) -> Void

    final class DragView: NSView {
        var onScroll: ((Float) -> Void)?

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func scrollWheel(with event: NSEvent) {
            var dy = Float(event.scrollingDeltaY)
            if event.isDirectionInvertedFromDevice { dy = -dy }
            guard dy != 0 else { return }
            // Trackpads send many small precise deltas, mouse wheels a few big notches.
            let step = event.hasPreciseScrollingDeltas ? dy * 0.004 : dy * 0.05
            onScroll?(max(-0.1, min(0.1, step)))
        }
    }

    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.onScroll = onScroll
        return view
    }
    func updateNSView(_ nsView: DragView, context: Context) {
        nsView.onScroll = onScroll
    }
}
