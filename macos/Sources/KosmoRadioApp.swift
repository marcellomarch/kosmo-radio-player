import SwiftUI
import AppKit

@main
struct KosmoRadioApp: App {
    @StateObject private var player = RadioPlayerManager()
    @ObservedObject private var l10n = LocalizationManager.shared

    var body: some Scene {
        Window(
            l10n.t(
                "Kosmo Radio Player — Rap, Hip-Hop, Ucraina, NYC & Mondo",
                "Kosmo Radio Player — Rap, Hip-Hop, Ukraine, NYC & World"
            ),
            id: "main-window"
        ) {
            MainWindowView(player: player)
                .frame(minWidth: 860, minHeight: 560)
        }
        .defaultSize(width: 1020, height: 680)

        MenuBarExtra {
            MenuBarView(player: player)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: player.isPlaying ? "antenna.radiowaves.left.and.right" : "radio.fill")
                if player.isPlaying, let station = player.currentStation {
                    Text(station.flagEmoji)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
