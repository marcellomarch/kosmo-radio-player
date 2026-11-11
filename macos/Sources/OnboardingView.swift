import SwiftUI
import AppKit

/// First-launch flow (and "Personalize…" later): pick genres and places, which
/// become the listener's own sidebar sections, and fill Favorites to start.
struct OnboardingView: View {
    @ObservedObject var player: RadioPlayerManager
    let onFinish: () -> Void

    @ObservedObject private var l10n = LocalizationManager.shared
    @ObservedObject private var profile = ListenerProfile.shared
    @Environment(\.dismiss) private var dismiss

    private enum Step: Int { case welcome, genres, places, done }

    @State private var step: Step = .welcome
    @State private var families: [String] = []
    @State private var places: [String] = []
    @State private var addStarters = true
    @State private var isFinishing = false
    @State private var didLoad = false

    private var isFirstRun: Bool { !profile.isCompleted }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: welcome
                case .genres: genres
                case .places: placesStep
                case .done: done
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 28)

            Divider()
            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
        }
        .frame(width: 680, height: 580)
        .onAppear(perform: load)
        .interactiveDismissDisabled(isFirstRun)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        families = profile.familyIDs
        places = profile.placeIDs
        if isFirstRun {
            // Suggest the listener's own country to start with.
            if let region = Locale.current.region?.identifier, Catalog.place(id: region) != nil {
                places = [region]
            }
        } else {
            step = .genres
            addStarters = false
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
            Text(l10n.t("Benvenuto in Kosmo Radio", "Welcome to Kosmo Radio"))
                .font(.system(size: 28, weight: .bold))
            Text(l10n.t(
                "Oltre 40.000 radio in diretta da tutto il mondo. Dimmi cosa ti piace ascoltare e costruisco la barra laterale intorno ai tuoi gusti, con i sottogeneri di ciascuno.",
                "40,000+ live stations from all over the world. Tell me what you like and I'll build the sidebar around your taste, with subgenres for each pick."
            ))
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 460)

            Picker(l10n.t("Lingua", "Language"), selection: $l10n.mode) {
                Text("🌐 Auto").tag(AppLanguageMode.system)
                Text("🇮🇹 Italiano").tag(AppLanguageMode.it)
                Text("🇬🇧 English").tag(AppLanguageMode.en)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 300)
            .padding(.top, 6)

            Text(l10n.t(
                "Puoi rifarlo quando vuoi: barra laterale ▸ Personalizza, o menu Kosmo Radio.",
                "You can redo this anytime: sidebar ▸ Personalize, or the Kosmo Radio menu."
            ))
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private var genres: some View {
        VStack(alignment: .leading, spacing: 14) {
            header(
                l10n.t("Cosa ascolti?", "What do you listen to?"),
                l10n.t(
                    "Scegli uno o più generi: ognuno avrà la sua sezione con i sottogeneri. L'ordine di scelta è l'ordine nella barra laterale.",
                    "Pick one or more genres: each gets its own section with subgenres. The order you pick them is the sidebar order."
                )
            )
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], spacing: 10) {
                    ForEach(Catalog.families) { family in
                        let index = families.firstIndex(of: family.id)
                        Button {
                            toggle(family.id, in: &families)
                        } label: {
                            choiceCard(
                                icon: family.icon,
                                title: family.title(isEnglish: l10n.isEnglish),
                                detail: family.preview(isEnglish: l10n.isEnglish),
                                badge: index.map { "\($0 + 1)" }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var placesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            header(
                l10n.t("Da dove vuoi ascoltare?", "Where do you want to listen from?"),
                l10n.t(
                    "Paesi e città che finiscono in cima, sotto le Preferite. Facoltativo: puoi anche saltare.",
                    "Countries and cities that go at the top, under Favorites. Optional: you can skip this."
                )
            )
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(Catalog.places) { place in
                        let selected = places.contains(place.id)
                        Button {
                            toggle(place.id, in: &places)
                        } label: {
                            HStack(spacing: 7) {
                                Text(place.flag).font(.system(size: 17))
                                Text(place.name(isEnglish: l10n.isEnglish))
                                    .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                if selected {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(cardBackground(selected))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(
                l10n.t("Ecco la tua radio", "Here's your radio"),
                l10n.t("Questa sarà la tua barra laterale.", "This will be your sidebar.")
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    let pickedFamilies = families.compactMap(Catalog.family(id:))
                    let pickedPlaces = places.compactMap(Catalog.place(id:))
                    if !pickedPlaces.isEmpty {
                        summaryRow(
                            l10n.t("In cima", "At the top"),
                            pickedPlaces.map { "\($0.flag) \($0.name(isEnglish: l10n.isEnglish))" }
                        )
                    }
                    ForEach(pickedFamilies) { family in
                        summaryRow(
                            "\(family.icon) \(family.title(isEnglish: l10n.isEnglish))",
                            family.subgenres.dropFirst().map { "\($0.icon) \($0.title(isEnglish: l10n.isEnglish))" }
                        )
                    }
                    if pickedFamilies.isEmpty {
                        Text(l10n.t(
                            "Nessun genere scelto: li troverai tutti in \"Generi Musicali\".",
                            "No genre picked: you'll find them all under \"Music Genres\"."
                        ))
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Toggle(isOn: $addStarters) {
                Text(l10n.t(
                    "Aggiungi alle Preferite qualche radio consigliata per ogni scelta",
                    "Add a few suggested stations for each pick to Favorites"
                ))
            }
            .toggleStyle(.checkbox)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if step != .welcome && !(step == .genres && !isFirstRun) {
                Button(l10n.t("Indietro", "Back")) { go(-1) }
            }
            if !isFirstRun {
                Button(l10n.t("Annulla", "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<4) { i in
                    Circle()
                        .fill(i == step.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            Spacer()
            if isFinishing {
                ProgressView().controlSize(.small).padding(.trailing, 6)
            }
            switch step {
            case .welcome:
                Button(l10n.t("Iniziamo", "Let's start")) { go(1) }
                    .keyboardShortcut(.defaultAction)
            case .genres:
                Button(families.isEmpty ? l10n.t("Salta", "Skip") : l10n.t("Continua", "Continue")) { go(1) }
                    .keyboardShortcut(.defaultAction)
            case .places:
                Button(places.isEmpty ? l10n.t("Salta", "Skip") : l10n.t("Continua", "Continue")) { go(1) }
                    .keyboardShortcut(.defaultAction)
            case .done:
                Button(l10n.t("Inizia ad ascoltare", "Start listening")) { finish() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isFinishing)
            }
        }
        .controlSize(.large)
    }

    private func go(_ delta: Int) {
        if let next = Step(rawValue: step.rawValue + delta) {
            withAnimation(.easeInOut(duration: 0.2)) { step = next }
        }
    }

    private func finish() {
        isFinishing = true
        profile.update(families: families, places: places)
        Task {
            if addStarters {
                player.addFavorites(await profile.starterStations())
            }
            isFinishing = false
            onFinish()
            dismiss()
        }
    }

    // MARK: Pieces

    private func toggle(_ id: String, in list: inout [String]) {
        if let i = list.firstIndex(of: id) { list.remove(at: i) } else { list.append(id) }
    }

    private func header(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 24, weight: .bold))
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }

    private func choiceCard(icon: String, title: String, detail: String, badge: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(icon).font(.system(size: 26))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let badge {
                Text(badge)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.accentColor))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        .background(cardBackground(badge != nil))
    }

    private func cardBackground(_ selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selected ? Color.accentColor.opacity(0.14) : Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: selected ? 1.5 : 1)
            )
    }

    private func summaryRow(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(items.joined(separator: "   "))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
