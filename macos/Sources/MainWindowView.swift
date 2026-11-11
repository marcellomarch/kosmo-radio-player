import SwiftUI
import AppKit
import Combine

@MainActor
final class MainWindowViewModel: ObservableObject {
    @Published var selectedSection: SidebarSection = ListenerProfile.shared.homeSection
    @Published var searchText: String = ""
    @Published var remoteStations: [RadioStation] = []
    @Published var isLoadingRemote: Bool = false
    @Published var remoteError: String? = nil
    @Published var showAddCustomSheet: Bool = false

    private var searchTask: Task<Void, Never>? = nil

    init() {
        loadSectionData(for: selectedSection, query: "")
    }

    func onSectionChanged(_ newSection: SidebarSection) {
        loadSectionData(for: newSection, query: searchText)
    }

    func onSearchTextChanged(_ newQuery: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            loadSectionData(for: selectedSection, query: newQuery)
        }
    }

    func loadSectionData(for section: SidebarSection, query: String) {
        remoteError = nil
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        switch section {
        case .favorites:
            isLoadingRemote = false
            return
        case .style(let sub):
            fetchRemote(query: trimmed, countryCode: nil, state: nil, tag: sub.tag)
        case .place(let place):
            fetchRemote(query: trimmed, countryCode: place.countryCode, state: place.state, tag: nil)
        case .worldSearch:
            fetchRemote(query: trimmed, countryCode: nil, state: nil, tag: nil)
        }
    }

    private func fetchRemote(query: String, countryCode: String?, state: String?, tag: String?) {
        isLoadingRemote = true
        Task {
            do {
                let results = try await RadioBrowserService.shared.searchStations(
                    query: query,
                    countryCode: countryCode,
                    state: state,
                    tag: tag,
                    limit: 60
                )
                self.remoteStations = results
                self.isLoadingRemote = false
            } catch {
                self.isLoadingRemote = false
                if self.remoteStations.isEmpty {
                    self.remoteError = LocalizationManager.shared.t(
                        "Impossibile contattare il catalogo online in questo momento. Le stazioni precaricate restano disponibili.",
                        "Unable to reach the online directory right now. Preloaded stations remain available."
                    )
                }
            }
        }
    }
}

struct MainWindowView: View {
    @ObservedObject var player: RadioPlayerManager
    @ObservedObject var l10n = LocalizationManager.shared
    @ObservedObject var lyricsManager = LyricsManager.shared
    @StateObject private var vm = MainWindowViewModel()
    @StateObject private var vizVM = VisualizerViewModel()

    @ObservedObject var profile = ListenerProfile.shared

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                NavigationSplitView {
                    sidebarView
                        .navigationSplitViewColumnWidth(min: 225, ideal: 245, max: 280)
                } detail: {
                    HStack(spacing: 0) {
                        mainContentView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if lyricsManager.isSideDrawerOpen {
                            Divider()
                            LyricsPanelView(
                                lyricsManager: lyricsManager,
                                mode: .sideDrawer
                            )
                            .frame(width: 345)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                }

                Divider()

                bottomPlayerBar
            }
            .sheet(isPresented: $profile.isOnboardingPresented) {
                OnboardingView(player: player) {
                    vm.selectedSection = profile.homeSection
                }
            }

            if vizVM.isExpandedFullWindow {
                FullScreenVisualizerOverlay(player: player, vizVM: vizVM)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(100)
            }
        }
        .sheet(isPresented: $vm.showAddCustomSheet) {
            AddCustomStationSheet(player: player)
        }
        .onChange(of: vm.selectedSection) { _, newSection in
            vm.onSectionChanged(newSection)
        }
        .onChange(of: vm.searchText) { _, newQuery in
            vm.onSearchTextChanged(newQuery)
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        List(selection: $vm.selectedSection) {
            Section(l10n.t("La Tua Radio", "Your Radio")) {
                NavigationLink(value: SidebarSection.favorites) {
                    Label {
                        HStack {
                            Text(l10n.t("Preferite", "Favorites"))
                            Spacer()
                            Text("\(player.favorites.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    } icon: {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }

                ForEach(profile.places) { place in
                    NavigationLink(value: SidebarSection.place(place)) {
                        Label {
                            Text(place.name(isEnglish: l10n.isEnglish))
                        } icon: {
                            Text(place.flag)
                        }
                    }
                }

                NavigationLink(value: SidebarSection.worldSearch) {
                    Label(
                        l10n.t("Cerca nel Mondo", "Search Worldwide"),
                        systemImage: "globe.americas.fill"
                    )
                }
            }

            ForEach(profile.families) { family in
                let name = family.title(isEnglish: l10n.isEnglish)
                Section(l10n.t("\(family.icon) Focus \(name)", "\(family.icon) \(name) Focus")) {
                    ForEach(family.subgenres) { sub in
                        NavigationLink(value: SidebarSection.style(sub)) {
                            Label {
                                Text(sub.title(isEnglish: l10n.isEnglish))
                            } icon: {
                                Text(sub.icon)
                            }
                        }
                    }
                }
            }

            Section(
                profile.families.isEmpty
                    ? l10n.t("Generi Musicali", "Music Genres")
                    : l10n.t("Altri Generi Musicali", "Other Music Genres")
            ) {
                ForEach(profile.otherFamilies) { family in
                    NavigationLink(value: SidebarSection.style(family.all)) {
                        Label {
                            Text(family.title(isEnglish: l10n.isEnglish))
                        } icon: {
                            Text(family.icon)
                        }
                    }
                }
            }

            Section(l10n.t("Esplora per Paese", "Explore by Country")) {
                ForEach(profile.otherPlaces) { place in
                    NavigationLink(value: SidebarSection.place(place)) {
                        Label {
                            Text(place.name(isEnglish: l10n.isEnglish))
                        } icon: {
                            Text(place.flag)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Divider()

                SidebarVisualizerMiniView(player: player, vizVM: vizVM)

                Button {
                    profile.isOnboardingPresented = true
                } label: {
                    Label(
                        l10n.t("Personalizza generi e paesi…", "Personalize genres & countries…"),
                        systemImage: "slider.horizontal.3"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)

                Button {
                    vm.showAddCustomSheet = true
                } label: {
                    Label(
                        l10n.t("Aggiungi URL Stream...", "Add Custom Stream URL..."),
                        systemImage: "plus.circle.fill"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Main Content

    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Top Header & Search Bar
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sectionHeaderTitle)
                            .font(.system(size: 22, weight: .bold))
                        Text(sectionHeaderSubtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Search field
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(
                            l10n.t(
                                "Cerca radio, artista, città o stile...",
                                "Search station, city, or style..."
                            ),
                            text: $vm.searchText
                        )
                        .textFieldStyle(.plain)
                        .frame(width: 220)
                        .onSubmit {
                            if vm.selectedSection == .favorites && !vm.searchText.isEmpty {
                                vm.selectedSection = .worldSearch
                            }
                            vm.loadSectionData(for: vm.selectedSection, query: vm.searchText)
                        }
                        if !vm.searchText.isEmpty {
                            Button {
                                vm.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                    // Language Switcher Menu
                    Menu {
                        Button("🌐 System Auto (macOS)") { l10n.mode = .system }
                        Divider()
                        Button("🇮🇹 Italiano") { l10n.mode = .it }
                        Button("🇬🇧 English") { l10n.mode = .en }
                    } label: {
                        Text(l10n.mode.displayBadge)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .menuStyle(.borderedButton)
                    .fixedSize()
                    .help(l10n.t("Lingua dell'interfaccia (Auto/IT/EN)", "Interface Language (Auto/IT/EN)"))

                    Button {
                        vm.showAddCustomSheet = true
                    } label: {
                        Label(l10n.t("Nuova Radio", "Add Station"), systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                // Inside a genre family, show quick subgenre pills
                if case .style(let activeSubgenre) = vm.selectedSection,
                   let family = Catalog.family(id: activeSubgenre.familyID) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(family.subgenres) { sub in
                                let isSelected = (sub == activeSubgenre)
                                Button {
                                    vm.selectedSection = .style(sub)
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(sub.icon)
                                        Text(sub.title(isEnglish: l10n.isEnglish))
                                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(
                                                isSelected
                                                    ? Color.accentColor
                                                    : Color(NSColor.controlBackgroundColor)
                                            )
                                    )
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                isSelected ? Color.clear : Color.primary.opacity(0.12),
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Station Grid
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if vm.isLoadingRemote {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text(
                                l10n.t(
                                    "Ricerca stazioni nel catalogo mondiale in corso...",
                                    "Searching stations in the global radio directory..."
                                )
                            )
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 12)
                    }

                    if let remoteError = vm.remoteError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(remoteError)
                                .font(.system(size: 12))
                            Spacer()
                            Button(l10n.t("Riprova", "Retry")) {
                                vm.loadSectionData(for: vm.selectedSection, query: vm.searchText)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    let stationsToDisplay = displayedStations
                    if stationsToDisplay.isEmpty && !vm.isLoadingRemote {
                        emptyStateView
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 270, maximum: 380), spacing: 14)
                            ],
                            spacing: 14
                        ) {
                            ForEach(stationsToDisplay) { station in
                                StationCardView(
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
                    }
                }
                .padding(24)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "radio")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(l10n.t("Nessuna stazione trovata", "No stations found"))
                .font(.headline)
            Text(
                l10n.t(
                    "Prova a cercare il nome di una radio, una città (es. Kyiv, Brooklyn, Bronx, London) o ripristina le stazioni predefinite.",
                    "Try searching for a station name, city (e.g. Kyiv, Brooklyn, Bronx, London), or restore the default presets."
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 420)

            if vm.selectedSection == .favorites {
                Button(l10n.t("Aggiungi le radio consigliate per te", "Add stations suggested for you")) {
                    Task { player.addFavorites(await profile.starterStations()) }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var sectionHeaderTitle: String {
        switch vm.selectedSection {
        case .favorites:
            return l10n.t("⭐ Le Tue Radio Preferite", "⭐ Your Favorite Stations")
        case .style(let sub):
            return "\(sub.icon) \(sub.title(isEnglish: l10n.isEnglish))"
        case .place(let place):
            return "\(place.flag) \(place.name(isEnglish: l10n.isEnglish))"
        case .worldSearch:
            return l10n.t("🌍 Esplora il Catalogo Mondiale", "🌍 Explore Global Radio Directory")
        }
    }

    private var sectionHeaderSubtitle: String {
        switch vm.selectedSection {
        case .favorites:
            return l10n.t(
                "Le tue stazioni salvate (sincronizzate anche nella Menu Bar in alto)",
                "Your saved stations (synced with the top macOS Menu Bar)"
            )
        case .style(let sub):
            return sub.subtitle(isEnglish: l10n.isEnglish)
        case .place(let place):
            return place.subtitle(isEnglish: l10n.isEnglish)
        case .worldSearch:
            return l10n.t(
                "Cerca tra oltre 40.000 stazioni in diretta da tutto il mondo (Radio Browser API)",
                "Search across 40,000+ live radio stations worldwide (Radio Browser API)"
            )
        }
    }

    private var displayedStations: [RadioStation] {
        let q = vm.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let base: [RadioStation]
        switch vm.selectedSection {
        case .favorites:
            base = player.favorites
        case .style(let sub):
            base = mergeUnique(primary: sub.curatedStations, secondary: vm.remoteStations)
        case .place(let place):
            base = mergeUnique(primary: place.curatedStations, secondary: vm.remoteStations)
        case .worldSearch:
            return vm.remoteStations
        }
        if q.isEmpty { return base }
        return base.filter { matchesQuery($0, query: q) }
    }

    private func matchesQuery(_ station: RadioStation, query: String) -> Bool {
        station.name.lowercased().contains(query) ||
        station.city.lowercased().contains(query) ||
        station.country.lowercased().contains(query) ||
        station.tags.lowercased().contains(query)
    }

    private func mergeUnique(primary: [RadioStation], secondary: [RadioStation]) -> [RadioStation] {
        var result = primary
        var urls = Set(primary.map { $0.streamURL })
        for item in secondary {
            if !urls.contains(item.streamURL) {
                urls.insert(item.streamURL)
                result.append(item)
            }
        }
        return result
    }

    // MARK: - Bottom Player Bar

    private var bottomPlayerBar: some View {
        HStack(spacing: 18) {
            // Station info
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(player.isPlaying ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Text(player.currentStation?.flagEmoji ?? "📻")
                        .font(.system(size: 26))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(
                            player.currentStation?.name
                                ?? l10n.t("Nessuna stazione in riproduzione", "No station playing")
                        )
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                        if player.isBuffering {
                            ProgressView()
                                .controlSize(.mini)
                        } else if player.isPlaying {
                            LiveBadgeView()
                        }
                    }

                    if let track = player.currentTrackMetadata, !track.isEmpty {
                        Button {
                            lyricsManager.toggleSideDrawer()
                        } label: {
                            HStack(spacing: 4) {
                                Text("♪ \(track)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.accentColor)
                                    .lineLimit(1)
                                Image(systemName: "quote.bubble")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.accentColor.opacity(0.8))
                            }
                        }
                        .buttonStyle(.plain)
                        .help(l10n.t("Clicca per aprire il testo di questa canzone", "Click to open lyrics for this song"))
                    } else if let err = player.errorMessage {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    } else {
                        Text(
                            player.currentStation?.formattedSubtitle
                                ?? l10n.t(
                                    "Seleziona una stazione dalla lista per ascoltare in diretta",
                                    "Select a station from the list to listen live"
                                )
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                }
            }
            .frame(minWidth: 250, maxWidth: 380, alignment: .leading)

            Spacer()

            // Transport Controls
            HStack(spacing: 18) {
                Button {
                    player.playPreviousFavorite()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .help(l10n.t("Stazione precedente", "Previous station"))

                Button {
                    player.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 40, height: 40)
                        Image(systemName: (player.isPlaying || player.isBuffering) ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .help(l10n.t("Play / Pausa", "Play / Pause"))

                Button {
                    player.playNextFavorite()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .help(l10n.t("Stazione successiva", "Next station"))

                if let current = player.currentStation {
                    Button {
                        player.toggleFavorite(current)
                    } label: {
                        Image(systemName: player.isFavorite(current) ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundStyle(player.isFavorite(current) ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(l10n.t("Salva nelle Preferite", "Save to Favorites"))
                }
            }

            Spacer()

            // Lyrics, Visualizer, Sleep Timer & Volume
            HStack(spacing: 10) {
                Button {
                    if lyricsManager.isFloatingWindowOpen {
                        lyricsManager.openFloatingPanel()
                    } else {
                        lyricsManager.toggleSideDrawer()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text("🎤")
                        Text("Lyrics")
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize()
                        if !lyricsManager.lyricsText.isEmpty {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        (lyricsManager.isSideDrawerOpen || lyricsManager.isFloatingWindowOpen)
                            ? Color.accentColor
                            : Color.accentColor.opacity(0.16)
                    )
                    .foregroundStyle(
                        (lyricsManager.isSideDrawerOpen || lyricsManager.isFloatingWindowOpen)
                            ? Color.white
                            : Color.accentColor
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(l10n.t("Apri / Chiudi pannello Lyrics della canzone in onda", "Open / Close live song Lyrics panel"))

                Button {
                    vizVM.toggleExpanded()
                } label: {
                    HStack(spacing: 5) {
                        Text(vizVM.currentPreset.icon)
                        Text("Visualizer")
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.16))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(l10n.t("Apri Visualizer Psichedelico a Tutto Schermo", "Open Full-Screen Psychedelic Visualizer"))

                Menu {
                    Button(l10n.t("Disattivato", "Off")) { player.setSleepTimer(minutes: nil) }
                    Divider()
                    Button(l10n.t("Tra 15 minuti", "In 15 minutes")) { player.setSleepTimer(minutes: 15) }
                    Button(l10n.t("Tra 30 minuti", "In 30 minutes")) { player.setSleepTimer(minutes: 30) }
                    Button(l10n.t("Tra 60 minuti", "In 60 minutes")) { player.setSleepTimer(minutes: 60) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.zzz.fill")
                        if let rem = player.sleepTimerRemainingSeconds {
                            Text("\(rem / 60)m")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .foregroundStyle(player.sleepTimerRemainingSeconds != nil ? Color.accentColor : .secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(l10n.t("Timer di spegnimento automatico", "Sleep Timer"))

                HStack(spacing: 6) {
                    Button {
                        player.isMuted.toggle()
                    } label: {
                        Image(systemName: player.isMuted || player.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .foregroundStyle(.secondary)
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
                    .frame(width: 100)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}

struct StationCardView: View {
    let station: RadioStation
    let isCurrent: Bool
    let isPlaying: Bool
    let isBuffering: Bool
    let isFavorite: Bool
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void
    @ObservedObject var l10n = LocalizationManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isCurrent ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.12))
                            .frame(width: 46, height: 46)

                        if isBuffering {
                            ProgressView()
                                .controlSize(.small)
                        } else if isPlaying {
                            AnimatedEqualizerView()
                        } else {
                            Text(station.flagEmoji)
                                .font(.system(size: 24))
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(station.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                            .lineLimit(1)

                        Text(station.formattedSubtitle)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 14))
                    .foregroundStyle(isFavorite ? .red : .secondary.opacity(0.7))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help(
                isFavorite
                    ? l10n.t("Rimuovi dalle Preferite", "Remove from Favorites")
                    : l10n.t("Aggiungi alle Preferite", "Add to Favorites")
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isCurrent ? Color.accentColor.opacity(0.8) : Color.primary.opacity(0.08),
                    lineWidth: isCurrent ? 1.5 : 1
                )
        )
    }
}

@MainActor
final class CustomStationFormModel: ObservableObject {
    @Published var name: String = ""
    @Published var streamURL: String = ""
    @Published var country: String = ""
    @Published var countryCode: String = "US"
    @Published var city: String = ""
    @Published var tags: String = "Hip-Hop, Rap"
}

struct AddCustomStationSheet: View {
    @ObservedObject var player: RadioPlayerManager
    @ObservedObject var l10n = LocalizationManager.shared
    @StateObject private var form = CustomStationFormModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(l10n.t("Aggiungi Stazione Personalizzata", "Add Custom Radio Station"))
                .font(.title3.bold())

            Text(
                l10n.t(
                    "Incolla l'indirizzo diretto dello streaming audio (MP3, AAC, M3U8 o Icecast).",
                    "Paste the direct audio stream URL (MP3, AAC, M3U8, or Icecast)."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Form {
                TextField(
                    l10n.t("Nome della Radio (es. Shade 45 / Radio Lviv)", "Station Name (e.g. Shade 45 / Radio Lviv)"),
                    text: $form.name
                )
                TextField(
                    l10n.t("URL Streaming (https://...)", "Stream URL (https://...)"),
                    text: $form.streamURL
                )
                HStack {
                    TextField(
                        l10n.t("Città (es. New York, Kyiv)", "City (e.g. New York, Kyiv)"),
                        text: $form.city
                    )
                    TextField(
                        l10n.t("Sigla Paese (es. US, UA)", "Country Code (e.g. US, UA)"),
                        text: $form.countryCode
                    )
                    .frame(width: 140)
                }
                TextField(
                    l10n.t("Generi / Note (es. Hip-Hop, Boom Bap, News)", "Genres / Tags (e.g. Hip-Hop, Boom Bap, News)"),
                    text: $form.tags
                )
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button(l10n.t("Annulla", "Cancel")) {
                    dismiss()
                }
                Button(l10n.t("Salva e Ascolta", "Save & Play")) {
                    player.addCustomStation(
                        name: form.name,
                        streamURL: form.streamURL,
                        country: form.country,
                        countryCode: form.countryCode,
                        city: form.city,
                        tags: form.tags
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(form.name.trimmingCharacters(in: .whitespaces).isEmpty || form.streamURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
