import Foundation

// MARK: - Music styles

/// One sidebar entry inside a genre family, e.g. "House" inside "Electronic".
/// Stations come from Radio Browser by `tag`, plus a curated list when there is one.
struct Subgenre: Hashable, Identifiable {
    let id: String          // "electronic.house"
    let familyID: String    // "electronic"
    let icon: String
    let titleIT: String
    let titleEN: String
    let subtitleIT: String?
    let subtitleEN: String?
    let tag: String
    /// Set for the hand-picked Rap & Hip-Hop lists.
    let hipHop: HipHopSubgenre?

    func title(isEnglish: Bool) -> String { isEnglish ? titleEN : titleIT }

    func subtitle(isEnglish: Bool) -> String {
        if let hipHop { return hipHop.subtitle(isEnglish: isEnglish) }
        if let s = isEnglish ? subtitleEN : subtitleIT { return s }
        let name = title(isEnglish: isEnglish)
        return isEnglish
            ? "The most popular live stations for \(name), from all over the world"
            : "Le stazioni in diretta più ascoltate per \(name), da tutto il mondo"
    }

    var curatedStations: [RadioStation] {
        hipHop.map { RadioStation.hipHopStations(for: $0) } ?? []
    }
}

/// A music family the listener can pick in the onboarding. The first subgenre is
/// always the "everything" entry.
struct GenreFamily: Identifiable, Hashable {
    let id: String
    let icon: String
    let titleIT: String
    let titleEN: String
    let subgenres: [Subgenre]

    func title(isEnglish: Bool) -> String { isEnglish ? titleEN : titleIT }
    var all: Subgenre { subgenres[0] }

    /// "House · Techno · Trance…" for the onboarding cards.
    func preview(isEnglish: Bool) -> String {
        subgenres.dropFirst().prefix(4).map { $0.title(isEnglish: isEnglish) }.joined(separator: " · ")
    }
}

enum Catalog {
    // (icon, title IT, title EN, Radio Browser tag)
    private typealias Entry = (icon: String, it: String, en: String, tag: String)

    private static func family(
        _ id: String, _ icon: String, _ it: String, _ en: String, all: Entry, _ subs: [Entry]
    ) -> GenreFamily {
        let entries = [all] + subs
        return GenreFamily(
            id: id, icon: icon, titleIT: it, titleEN: en,
            subgenres: entries.map { e in
                Subgenre(
                    id: "\(id).\(e.tag)", familyID: id, icon: e.icon, titleIT: e.it, titleEN: e.en,
                    subtitleIT: nil, subtitleEN: nil, tag: e.tag, hipHop: nil
                )
            }
        )
    }

    static let hipHop = GenreFamily(
        id: "hiphop", icon: "🎤", titleIT: "Rap & Hip-Hop", titleEN: "Rap & Hip-Hop",
        subgenres: HipHopSubgenre.allCases.map { sub in
            Subgenre(
                id: "hiphop.\(sub.rawValue)", familyID: "hiphop", icon: sub.icon,
                titleIT: sub.title(isEnglish: false), titleEN: sub.title(isEnglish: true),
                subtitleIT: nil, subtitleEN: nil, tag: sub.searchTag, hipHop: sub
            )
        }
    )

    static let families: [GenreFamily] = [
        hipHop,
        family("electronic", "🎧", "Elettronica & Dance", "Electronic & Dance",
               all: ("🎧", "Tutta l'Elettronica", "All Electronic", "electronic"), [
                ("🏠", "House", "House", "house"),
                ("🌊", "Deep House", "Deep House", "deep house"),
                ("⚙️", "Techno", "Techno", "techno"),
                ("🌀", "Trance", "Trance", "trance"),
                ("🥁", "Drum & Bass", "Drum & Bass", "drum and bass"),
                ("🔊", "Dubstep", "Dubstep", "dubstep"),
                ("🎉", "EDM", "EDM", "edm"),
               ]),
        family("rock", "🎸", "Rock & Alternative", "Rock & Alternative",
               all: ("🎸", "Tutto il Rock", "All Rock", "rock"), [
                ("📀", "Classic Rock", "Classic Rock", "classic rock"),
                ("🌀", "Alternative", "Alternative", "alternative"),
                ("🎒", "Indie Rock", "Indie Rock", "indie rock"),
                ("🤘", "Metal", "Metal", "metal"),
                ("⚡", "Hard Rock", "Hard Rock", "hard rock"),
                ("🧷", "Punk", "Punk", "punk"),
                ("🌌", "Progressive Rock", "Progressive Rock", "progressive rock"),
               ]),
        family("pop", "🌟", "Pop & Hit", "Pop & Hits",
               all: ("🌟", "Tutto il Pop", "All Pop", "pop"), [
                ("🔝", "Top 40", "Top 40", "top 40"),
                ("💃", "Dance", "Dance", "dance"),
                ("📼", "Anni '80", "80s", "80s"),
                ("💿", "Anni '90", "90s", "90s"),
                ("📱", "Anni 2000", "2000s", "2000s"),
                ("📻", "Oldies", "Oldies", "oldies"),
               ]),
        family("soul", "🎶", "R&B, Soul & Funk", "R&B, Soul & Funk",
               all: ("🎶", "Tutto Soul", "All Soul", "soul"), [
                ("💜", "R&B", "R&B", "rnb"),
                ("🕺", "Funk", "Funk", "funk"),
                ("🪩", "Disco", "Disco", "disco"),
                ("🙌", "Gospel", "Gospel", "gospel"),
               ]),
        family("jazz", "🎷", "Jazz & Blues", "Jazz & Blues",
               all: ("🎷", "Tutto il Jazz", "All Jazz", "jazz"), [
                ("🍸", "Smooth Jazz", "Smooth Jazz", "smooth jazz"),
                ("🎺", "Swing", "Swing", "swing"),
                ("🎸", "Blues", "Blues", "blues"),
                ("🛋️", "Lounge", "Lounge", "lounge"),
               ]),
        family("chill", "🌙", "Chill & Ambient", "Chill & Ambient",
               all: ("🌙", "Tutto Chill", "All Chill", "chillout"), [
                ("🌫️", "Ambient", "Ambient", "ambient"),
                ("☕", "Lo-Fi", "Lo-Fi", "lofi"),
                ("🌅", "Downtempo", "Downtempo", "downtempo"),
                ("🧘", "Meditazione", "Meditation", "meditation"),
                ("✨", "New Age", "New Age", "new age"),
               ]),
        family("classical", "🎻", "Classica", "Classical",
               all: ("🎻", "Tutta la Classica", "All Classical", "classical"), [
                ("🎭", "Opera", "Opera", "opera"),
                ("🎹", "Pianoforte", "Piano", "piano"),
                ("🎼", "Strumentale", "Instrumental", "instrumental"),
               ]),
        family("latin", "💃", "Latina", "Latin",
               all: ("💃", "Tutta la Latina", "All Latin", "latin"), [
                ("🔥", "Reggaeton", "Reggaeton", "reggaeton"),
                ("🎺", "Salsa", "Salsa", "salsa"),
                ("🪗", "Cumbia", "Cumbia", "cumbia"),
                ("🌹", "Bachata", "Bachata", "bachata"),
                ("🇧🇷", "Musica Brasiliana", "Brazilian Music", "mpb"),
               ]),
        family("reggae", "🌴", "Reggae & Afro", "Reggae & Afro",
               all: ("🌴", "Tutto il Reggae", "All Reggae", "reggae"), [
                ("🔉", "Dancehall", "Dancehall", "dancehall"),
                ("🎛️", "Dub", "Dub", "dub"),
                ("🌍", "Afrobeats", "Afrobeats", "afrobeats"),
                ("🥁", "Musica Africana", "African Music", "african music"),
               ]),
        family("country", "🤠", "Country & Folk", "Country & Folk",
               all: ("🤠", "Tutto il Country", "All Country", "country"), [
                ("🐎", "Classic Country", "Classic Country", "classic country"),
                ("🪕", "Folk", "Folk", "folk"),
                ("🛣️", "Americana", "Americana", "americana"),
                ("✍️", "Cantautori", "Singer-Songwriter", "singer-songwriter"),
               ]),
        family("news", "🗞️", "News & Parlato", "News & Talk",
               all: ("🗞️", "Tutte le News", "All News", "news"), [
                ("🎙️", "Talk", "Talk", "talk"),
                ("🏛️", "Radio Pubbliche", "Public Radio", "public radio"),
                ("⚽", "Sport", "Sports", "sports"),
                ("📚", "Cultura", "Culture", "culture"),
                ("😂", "Comicità", "Comedy", "comedy"),
               ]),
    ]

    static func family(id: String) -> GenreFamily? {
        families.first { $0.id == id }
    }

    // MARK: Places

    /// Countries offered in the onboarding and in "Explore by Country".
    static let countryCodes = [
        "US", "GB", "IT", "FR", "DE", "ES", "UA", "PL", "NL", "BE", "CH", "AT", "PT", "IE",
        "GR", "SE", "NO", "DK", "FI", "CZ", "RO", "HU", "TR", "CA", "MX", "BR", "AR", "CO",
        "CL", "JP", "KR", "IN", "AU", "NZ", "ZA", "NG", "EG",
    ]

    static let places: [Place] = [Place.newYork] + countryCodes.map { Place(id: $0) }

    static func place(id: String) -> Place? {
        places.first { $0.id == id }
    }
}

// MARK: - Places

/// A country (by ISO code) or a curated city.
struct Place: Hashable, Identifiable {
    let id: String  // ISO country code, or "nyc"

    static let newYork = Place(id: "nyc")

    var countryCode: String { id == "nyc" ? "US" : id }
    var state: String? { id == "nyc" ? "New York" : nil }

    var flag: String {
        if id == "nyc" { return "🗽" }
        return RadioStation.flag(for: id)
    }

    func name(isEnglish: Bool) -> String {
        if id == "nyc" { return "New York City" }
        let locale = Locale(identifier: isEnglish ? "en" : "it")
        return locale.localizedString(forRegionCode: id) ?? id
    }

    func subtitle(isEnglish: Bool) -> String {
        switch id {
        case "nyc":
            return isEnglish
                ? "NYC Hip-Hop (Hot 97, Power 105.1), Public Radio (WNYC, WQXR), Jazz (WBGO) & Indie (WFMU)"
                : "NYC Hip-Hop (Hot 97, Power 105.1), Public Radio (WNYC, WQXR), Jazz (WBGO) e Indie (WFMU)"
        case "UA":
            return isEnglish
                ? "National broadcasters, live news, Ukrainian music, rap & stations from Kyiv and Lviv"
                : "Stazioni nazionali, news, musica ucraina, rap e radio da Kyiv e Lviv"
        default:
            let n = name(isEnglish: isEnglish)
            return isEnglish ? "Most popular live stations from \(n)" : "Le stazioni più ascoltate in diretta da: \(n)"
        }
    }

    var curatedStations: [RadioStation] {
        switch id {
        case "nyc": return RadioStation.defaultNewYorkStations
        case "UA": return RadioStation.defaultUkrainianStations
        default: return []
        }
    }
}

extension RadioStation {
    static func flag(for countryCode: String) -> String {
        let code = countryCode.uppercased()
        guard code.count == 2 else { return "📻" }
        var emoji = ""
        for scalar in code.unicodeScalars {
            if let u = UnicodeScalar(127397 + scalar.value) { emoji.append(String(u)) }
        }
        return emoji.isEmpty ? "📻" : emoji
    }
}
