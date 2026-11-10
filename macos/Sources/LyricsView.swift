import SwiftUI
import AppKit

enum LyricsPanelDisplayMode {
    case sideDrawer
    case floatingWindow
    case visualizerOverlay
}

struct LyricsPanelView: View {
    @ObservedObject var lyricsManager: LyricsManager
    @ObservedObject var l10n = LocalizationManager.shared
    let mode: LyricsPanelDisplayMode

    var body: some View {
        VStack(spacing: 0) {
            // Top Header
            headerBar
                .padding(.horizontal, 16)
                .padding(.top, mode == .floatingWindow ? 28 : 14)
                .padding(.bottom, 10)

            Divider()
                .overlay(Color.white.opacity(0.1))

            // Search & Karaoke Finder Section
            searchAndActionsSection
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider()
                .overlay(Color.white.opacity(0.08))

            // Main Scrollable Lyrics Content with Auto-Center Spotlight
            lyricsContentArea
        }
        .background(backgroundView)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch mode {
        case .sideDrawer:
            Color(NSColor.controlBackgroundColor)
        case .floatingWindow:
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.17),
                    Color(red: 0.04, green: 0.05, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .visualizerOverlay:
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
        }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("🎤 LYRICS")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.accentColor)

                    if lyricsManager.isLoading {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }

                if !lyricsManager.resolvedTrackTitle.isEmpty {
                    Text(lyricsManager.resolvedTrackTitle)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                    if !lyricsManager.resolvedArtistName.isEmpty {
                        Text(lyricsManager.resolvedArtistName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else if let raw = lyricsManager.currentRawMetadata, !raw.isEmpty {
                    Text(raw)
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                } else {
                    Text(l10n.t("Testo della canzone", "Song Lyrics"))
                        .font(.system(size: 14, weight: .bold))
                }
            }

            Spacer()

            // Toggle manual song title search
            if !lyricsManager.lyricsText.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        lyricsManager.showSongSearchField.toggle()
                    }
                } label: {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(6)
                        .background(
                            lyricsManager.showSongSearchField
                                ? Color.accentColor.opacity(0.25)
                                : Color.primary.opacity(0.08)
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(l10n.t("Cerca un altro titolo canzone", "Search a different song title"))
            }

            // Font size controls
            HStack(spacing: 4) {
                Button {
                    lyricsManager.decreaseFontSize()
                } label: {
                    Text("A-")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(l10n.t("Riduci testo", "Smaller text"))

                Button {
                    lyricsManager.increaseFontSize()
                } label: {
                    Text("A+")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(l10n.t("Ingrandisci testo", "Larger text"))
            }

            // Mode switch / Close buttons
            if mode == .sideDrawer {
                Button {
                    lyricsManager.popOutToFloatingWindow()
                } label: {
                    Image(systemName: "pip.exit")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(6)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(l10n.t("Stacca in finestrella flottante", "Pop out to floating window"))

                Button {
                    lyricsManager.toggleSideDrawer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .padding(6)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(l10n.t("Chiudi pannello Lyrics", "Close Lyrics panel"))
            } else if mode == .floatingWindow {
                Button {
                    lyricsManager.dockBackToSideDrawer()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pip.enter")
                        Text(l10n.t("Aggancia", "Dock"))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(l10n.t("Riporta dentro la finestra principale", "Dock back into main window"))
            } else if mode == .visualizerOverlay {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        lyricsManager.isVisualizerLyricsOpen = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .padding(6)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var searchAndActionsSection: some View {
        VStack(spacing: 8) {
            // 1. Live In-Lyrics Phrase Finder ("Scrivi le parole che senti...")
            if !lyricsManager.lyricsText.isEmpty {
                HStack(spacing: 6) {
                    Text("🎯")
                        .font(.system(size: 13))

                    TextField(
                        l10n.t(
                            "Scrivi le parole che senti per saltare al punto...",
                            "Type the words you hear to jump to that line..."
                        ),
                        text: $lyricsManager.inLyricsSearchQuery
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .medium))
                    .onSubmit {
                        lyricsManager.nextMatch()
                    }

                    if !lyricsManager.inLyricsSearchQuery.isEmpty {
                        if !lyricsManager.matchingLineIndices.isEmpty {
                            Text("\(lyricsManager.currentMatchPointer + 1)/\(lyricsManager.matchingLineIndices.count)")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.14))
                                .clipShape(Capsule())
                        } else {
                            Text("0")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange)
                        }

                        Button {
                            lyricsManager.inLyricsSearchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Step Up / Down buttons (works both for matches and for stepping line-by-line!)
                    HStack(spacing: 3) {
                        Button {
                            lyricsManager.previousMatch()
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 20, height: 20)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                        .help(l10n.t("Occorrenza / Riga precedente", "Previous match / line"))

                        Button {
                            lyricsManager.nextMatch()
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 20, height: 20)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                        .help(l10n.t("Occorrenza / Riga successiva (Invio)", "Next match / line (Enter)"))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.38), lineWidth: 1)
                )
            }

            // 2. Song Title Lookup Field (shown when no lyrics loaded OR when toggled open)
            if lyricsManager.lyricsText.isEmpty || lyricsManager.showSongSearchField {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    TextField(
                        l10n.t("Cerca brano (es.Artista - Titolo)...", "Search song (e.g. Artist - Title)..."),
                        text: $lyricsManager.manualSearchText
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        lyricsManager.searchManual()
                    }

                    if !lyricsManager.manualSearchText.isEmpty {
                        Button {
                            lyricsManager.manualSearchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        lyricsManager.searchManual()
                    } label: {
                        Text(l10n.t("Cerca Brano", "Find Song"))
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
            }

            // 3. Quick Action Row: Genius.com + Copy
            HStack(spacing: 8) {
                Button {
                    lyricsManager.openOnGenius()
                } label: {
                    HStack(spacing: 5) {
                        Text("🎤")
                        Text(l10n.t("Apri su Genius.com", "Open on Genius.com"))
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.18))
                    .foregroundStyle(mode == .sideDrawer ? Color.primary : Color.yellow)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(l10n.t("Apri il brano e le annotazioni Rap su Genius.com", "Open song and Rap annotations on Genius.com"))

                Spacer()

                if lyricsManager.activeLineIndex != nil {
                    Button {
                        lyricsManager.activeLineIndex = nil
                        lyricsManager.inLyricsSearchQuery = ""
                    } label: {
                        Text(l10n.t("Pulisci selezione", "Clear highlight"))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if !lyricsManager.lyricsText.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(lyricsManager.lyricsText, forType: .string)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text(l10n.t("Copia", "Copy"))
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var lyricsContentArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if lyricsManager.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(
                                l10n.t(
                                    "Ricerca del testo della canzone in corso...",
                                    "Searching song lyrics..."
                                )
                            )
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                    } else if !lyricsManager.lyricLines.isEmpty {
                        if !lyricsManager.resolvedAlbumName.isEmpty {
                            Text("💿 \(lyricsManager.resolvedAlbumName)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.bottom, 6)
                        }

                        ForEach(Array(lyricsManager.lyricLines.enumerated()), id: \.offset) { idx, line in
                            LyricsLineRow(
                                line: line,
                                index: idx,
                                isActive: lyricsManager.activeLineIndex == idx,
                                isNextAfterActive: lyricsManager.activeLineIndex != nil && lyricsManager.activeLineIndex! + 1 == idx,
                                isOtherMatch: lyricsManager.matchingLineIndices.contains(idx) && lyricsManager.activeLineIndex != idx,
                                fontSize: lyricsManager.fontSize,
                                onSelect: {
                                    lyricsManager.selectLine(idx)
                                }
                            )
                            .id(idx)
                        }
                    } else if let err = lyricsManager.errorMessage {
                        VStack(spacing: 14) {
                            Image(systemName: "music.mic")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text(err)
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button {
                                lyricsManager.openOnGenius()
                            } label: {
                                Label(
                                    l10n.t("Cerca su Genius.com 🎤", "Search on Genius.com 🎤"),
                                    systemImage: "safari"
                                )
                                .font(.system(size: 12, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "quote.bubble.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(Color.accentColor.opacity(0.75))

                            Text(
                                l10n.t(
                                    "In attesa del titolo del brano dalla radio...",
                                    "Waiting for live song title from the station..."
                                )
                            )
                            .font(.system(size: 13, weight: .semibold))
                            .multilineTextAlignment(.center)

                            Text(
                                l10n.t(
                                    "Appena la radio trasmette il nome della canzone, il testo apparirà qui in automatico!\n\nPuoi anche scrivere qualsiasi titolo o artista nella barra qui sopra.",
                                    "As soon as the radio broadcasts the track title, the lyrics will appear here automatically!\n\nYou can also type any song or artist in the search box above."
                                )
                            )
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 14)
            }
            .onChange(of: lyricsManager.scrollTriggerID) { _, _ in
                if let target = lyricsManager.activeLineIndex {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
        }
    }
}

struct LyricsLineRow: View {
    let line: String
    let index: Int
    let isActive: Bool
    let isNextAfterActive: Bool
    let isOtherMatch: Bool
    let fontSize: CGFloat
    let onSelect: () -> Void

    var body: some View {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            Spacer()
                .frame(height: 10)
        } else {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 8) {
                    if isActive {
                        Text("▶")
                            .font(.system(size: fontSize * 0.85, weight: .black))
                            .foregroundStyle(Color.accentColor)
                            .padding(.top, 2)
                    }

                    Text(line)
                        .font(
                            .system(
                                size: isActive ? fontSize + 1.5 : fontSize,
                                weight: isActive ? .bold : (isNextAfterActive ? .semibold : .medium)
                            )
                        )
                        .foregroundStyle(
                            isActive
                                ? Color.primary
                                : (isNextAfterActive ? Color.primary.opacity(0.92) : Color.primary.opacity(0.78))
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, isActive ? 8 : 4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            isActive
                                ? Color.accentColor.opacity(0.24)
                                : (isOtherMatch ? Color.yellow.opacity(0.14) : Color.clear)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            isActive
                                ? Color.accentColor.opacity(0.85)
                                : (isOtherMatch ? Color.yellow.opacity(0.45) : Color.clear),
                            lineWidth: isActive ? 1.5 : 1
                        )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
