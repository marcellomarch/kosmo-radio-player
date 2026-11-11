import SwiftUI
import AppKit

@main
struct KosmoRadioApp: App {
    @StateObject private var player = RadioPlayerManager()
    @ObservedObject private var l10n = LocalizationManager.shared
    @ObservedObject private var updater = AppUpdater.shared

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
        .commands {
            CommandGroup(after: .appInfo) {
                Button(l10n.t("Controlla aggiornamenti…", "Check for Updates…")) {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)

                Button(l10n.t("Personalizza generi e paesi…", "Personalize Genres & Countries…")) {
                    ListenerProfile.shared.isOnboardingPresented = true
                }
            }
        }

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
