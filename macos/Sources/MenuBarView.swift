import SwiftUI
import AppKit
import Combine

@MainActor
final class MenuBarViewState: ObservableObject {
    @Published var selectedTab: Int = 0
}

struct MenuBarView: View {
    @ObservedObject var player: RadioPlayerManager
    @ObservedObject var l10n = LocalizationManager.shared
    @ObservedObject var updater = AppUpdater.shared
    @StateObject private var uiState = MenuBarViewState()
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header / Now Playing Card
            nowPlayingHeader
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.18),
                            Color(NSColor.windowBackgroundColor)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Divider()

            // Quick Category Picker (with Rap/Hip-Hop tab!)
            Picker("", selection: $uiState.selectedTab) {
                Text(l10n.t("⭐ Pref.", "⭐ Favs")).tag(0)
                Text("🎤 Rap").tag(1)
                Text("🇺🇦 UA").tag(2)
                Text("🗽 NYC").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Station List
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(currentTabStations) { station in
                        MenuBarStationRow(
                            station: station,
                            isCurrent: player.currentStation?.id == station.id,
                            isPlaying: player.currentStation?.id == station.id && player.isPlaying,
                            isBuffering: player.currentStation?.id == station.id && player.isBuffering,
                            isFavorite: player.isFavorite(station),
                            onPlay: { player.play(station) },
                            onToggleFavorite: { player.toggleFavorite(station) }
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            .frame(height: 260)

            Divider()

            // Volume & Footer Actions
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        player.isMuted.toggle()
                    } label: {
                        Image(systemName: volumeIcon)
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                    }
                    .buttonStyle(.plain)

                    Slider(
                        value: Binding(
                            get: { Double(player.volume) },
                            set: {
                                player.isMuted = false
                                player.volume = Float($0)
                            }
                        ),
                        in: 0...1
                    )
                    .controlSize(.small)
                }

                HStack(spacing: 8) {
                    Button {
                        openMainWindow()
                    } label: {
                        Label(
                            l10n.t("Esplora & Cerca...", "Explore & Search..."),
                            systemImage: "globe.americas.fill"
                        )
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Spacer()

                    Menu {
                        Button("🌐 System Auto") { l10n.mode = .system }
                        Button("🇮🇹 Italiano") { l10n.mode = .it }
                        Button("🇬🇧 English") { l10n.mode = .en }
                    } label: {
                        Text(l10n.mode.displayBadge)
                            .font(.system(size: 11))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Button {
                        updater.checkForUpdates()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!updater.canCheckForUpdates)
                    .help(l10n.t(
                        "Controlla aggiornamenti… (versione \(updater.currentVersion))",
                        "Check for Updates… (version \(updater.currentVersion))"
                    ))

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Text(l10n.t("Esci", "Quit"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        }
        .frame(width: 350)
    }

    private var currentTabStations: [RadioStation] {
        switch uiState.selectedTab {
        case 0:
            return player.favorites.isEmpty ? RadioStation.defaultHipHopStations : player.favorites
        case 1:
            return RadioStation.defaultHipHopStations
        case 2:
            return RadioStation.defaultUkrainianStations
        case 3:
            return RadioStation.defaultNewYorkStations
        default:
            return player.favorites
        }
    }

    private var volumeIcon: String {
        if player.isMuted || player.volume == 0 {
            return "speaker.slash.fill"
        } else if player.volume < 0.4 {
            return "speaker.wave.1.fill"
        } else if player.volume < 0.75 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    @ViewBuilder
    private var nowPlayingHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(player.isPlaying ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Text(player.currentStation?.flagEmoji ?? "📻")
                        .font(.system(size: 26))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if player.isBuffering {
                            ProgressView()
                                .controlSize(.mini)
                            Text(l10n.t("CONNESSIONE...", "CONNECTING..."))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange)
                        } else if player.isPlaying {
                            LiveBadgeView()
                        } else {
                            Text(l10n.t("PRONTA ALL'ASCOLTO", "READY TO PLAY"))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(player.currentStation?.name ?? l10n.t("Scegli una stazione", "Choose a station"))
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    if let track = player.currentTrackMetadata, !track.isEmpty {
                        Text("♪ \(track)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(1)
                    } else {
                        Text(
                            player.currentStation?.formattedSubtitle
                                ?? l10n.t("Rap, Hip-Hop, Ucraina, NYC & Mondo", "Rap, Hip-Hop, Ukraine, NYC & World")
                        )
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)
            }

            if let err = player.errorMessage {
                Text(err)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                Button {
                    player.playPreviousFavorite()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help(l10n.t("Stazione precedente", "Previous station"))

                Button {
                    player.togglePlayPause()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: (player.isPlaying || player.isBuffering) ? "pause.fill" : "play.fill")
                        Text(
                            (player.isPlaying || player.isBuffering)
                                ? l10n.t("Pausa", "Pause")
                                : l10n.t("Ascolta", "Play")
                        )
                        .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    player.playNextFavorite()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help(l10n.t("Stazione successiva", "Next station"))

                Spacer()

                if let current = player.currentStation {
                    Button {
                        player.toggleFavorite(current)
                    } label: {
                        Image(systemName: player.isFavorite(current) ? "heart.fill" : "heart")
                            .foregroundStyle(player.isFavorite(current) ? .red : .secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help(l10n.t("Aggiungi/Rimuovi dai Preferiti", "Add/Remove Favorite"))
                }
            }
        }
    }

    private func openMainWindow() {
        openWindow(id: "main-window")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

struct MenuBarStationRow: View {
    let station: RadioStation
    let isCurrent: Bool
    let isPlaying: Bool
    let isBuffering: Bool
    let isFavorite: Bool
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onPlay) {
                HStack(spacing: 10) {
                    Text(station.flagEmoji)
                        .font(.system(size: 18))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(station.name)
                            .font(.system(size: 12.5, weight: isCurrent ? .semibold : .regular))
                            .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                            .lineLimit(1)

                        Text(station.formattedSubtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if isBuffering {
                        ProgressView()
                            .controlSize(.mini)
                    } else if isPlaying {
                        AnimatedEqualizerView()
                    } else {
                        Image(systemName: "play.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 11))
                    .foregroundStyle(isFavorite ? .red : .secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isCurrent ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.03))
        )
    }
}

struct LiveBadgeView: View {
    @ObservedObject var l10n = LocalizationManager.shared

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.green)
                .frame(width: 6, height: 6)
            Text(l10n.t("IN ONDA", "LIVE"))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.green)
        }
    }
}

struct AnimatedEqualizerView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate * 4)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    let heights: [[CGFloat]] = [
                        [13, 7, 15, 9],
                        [6, 14, 8, 13],
                        [14, 9, 6, 15],
                        [8, 12, 14, 6]
                    ]
                    let h = heights[abs(tick) % 4][index]
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.accentColor)
                        .frame(width: 2.5, height: h)
                        .animation(.easeInOut(duration: 0.24), value: tick)
                }
            }
            .frame(height: 15)
        }
    }
}
