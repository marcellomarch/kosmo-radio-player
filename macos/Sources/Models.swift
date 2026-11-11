import Foundation

struct RadioStation: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var streamURL: String
    var country: String
    var countryCode: String
    var city: String
    var tags: String
    var faviconURL: String?
    var bitrate: Int?
    var homepage: String?

    var flagEmoji: String {
        let code = countryCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count == 2 else { return "📻" }
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in code.unicodeScalars {
            if let unicode = UnicodeScalar(base + scalar.value) {
                emoji.append(String(unicode))
            }
        }
        return emoji.isEmpty ? "📻" : emoji
    }

    var formattedSubtitle: String {
        var parts: [String] = []
        if !city.isEmpty {
            parts.append(city)
        } else if !country.isEmpty {
            parts.append(country)
        }
        if !tags.isEmpty {
            let cleanTags = tags
                .split(separator: ",")
                .prefix(3)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).capitalized }
                .joined(separator: " • ")
            if !cleanTags.isEmpty {
                parts.append(cleanTags)
            }
        }
        if let br = bitrate, br > 0 {
            parts.append("\(br) kbps")
        }
        return parts.isEmpty ? "Live Radio Stream" : parts.joined(separator: " — ")
    }
}

struct RadioBrowserStationDTO: Codable {
    let stationuuid: String?
    let name: String?
    let url_resolved: String?
    let url: String?
    let homepage: String?
    let favicon: String?
    let tags: String?
    let country: String?
    let countrycode: String?
    let state: String?
    let bitrate: Int?

    func toRadioStation() -> RadioStation? {
        let finalURL = (url_resolved?.isEmpty == false ? url_resolved : url) ?? ""
        let trimmedName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalURL.isEmpty, !trimmedName.isEmpty else { return nil }
        return RadioStation(
            id: stationuuid ?? finalURL,
            name: trimmedName,
            streamURL: finalURL,
            country: country ?? "",
            countryCode: countrycode ?? "",
            city: state ?? "",
            tags: tags ?? "",
            faviconURL: (favicon?.isEmpty == false) ? favicon : nil,
            bitrate: bitrate,
            homepage: homepage
        )
    }
}

enum HipHopSubgenre: String, CaseIterable, Hashable, Identifiable {
    case all = "all"
    case nycEastCoast = "nyc_east"
    case oldSchool90s = "oldschool_90s"
    case westCoastGFunk = "westcoast_gfunk"
    case trapDrillPhonk = "trap_drill"
    case underground = "underground"
    case lofiBeats = "lofi_chillhop"
    case euroUkUa = "euro_uk_ua"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "🎤"
        case .nycEastCoast: return "🗽"
        case .oldSchool90s: return "📼"
        case .westCoastGFunk: return "🌴"
        case .trapDrillPhonk: return "🔊"
        case .underground: return "🎧"
        case .lofiBeats: return "☕"
        case .euroUkUa: return "🌍"
        }
    }

    func title(isEnglish: Bool) -> String {
        switch self {
        case .all:
            return isEnglish ? "All Rap & Hip-Hop" : "Tutto Rap & Hip-Hop"
        case .nycEastCoast:
            return "NYC & East Coast Boom Bap"
        case .oldSchool90s:
            return isEnglish ? "Old School & 90s Golden Era" : "Old School & Anni '90"
        case .westCoastGFunk:
            return "West Coast & G-Funk"
        case .trapDrillPhonk:
            return "Trap, Drill & Phonk"
        case .underground:
            return "Underground & Conscious"
        case .lofiBeats:
            return "Lo-Fi Hip-Hop & Chillhop"
        case .euroUkUa:
            return isEnglish ? "UK, Euro & UA Rap" : "Rap UK, Europa & Ucraina"
        }
    }

    func subtitle(isEnglish: Bool) -> String {
        switch self {
        case .all:
            return isEnglish
                ? "Complete Hip-Hop & Rap hub: NYC icons, 90s Boom Bap, West Coast G-Funk, Trap, Underground & Lo-Fi Beats"
                : "Hub completo Hip-Hop & Rap: icone di NYC, Boom Bap anni '90, West Coast G-Funk, Trap, Underground & Lo-Fi"
        case .nycEastCoast:
            return isEnglish
                ? "The birthplace of Hip-Hop: Hot 97 NYC, Power 105.1, Bronx/Brooklyn/Queens Boom Bap & East Coast classics"
                : "La culla dell'Hip-Hop: Hot 97 NYC, Power 105.1, Boom Bap da Bronx/Brooklyn/Queens e classici East Coast"
        case .oldSchool90s:
            return isEnglish
                ? "80s & 90s Golden Era Hip-Hop, turntablism, classic rhyme masters & throwback R&B"
                : "Golden Era anni '80 e '90, turntablism, classici immortali del Rap e R&B d'annata"
        case .westCoastGFunk:
            return isEnglish
                ? "California sunshine, synthesizers, lowriders, 90s West Coast rap & classic G-Funk"
                : " Atmosfere californiane, synth, lowrider, West Coast rap anni '90 e puro G-Funk"
        case .trapDrillPhonk:
            return isEnglish
                ? "Heavy 808s, modern Trap, Memphis/Houston Phonk, Trill & UK/NY Drill"
                : "808 potenti, Trap moderna, Phonk stile Memphis/Houston, Trill e Drill"
        case .underground:
            return isEnglish
                ? "Raw lyricism, independent MCs, alternative beats, crates & non-commercial Hip-Hop"
                : "Liriche pure, MC indipendenti, beat alternativi, crate digging e Hip-Hop non commerciale"
        case .lofiBeats:
            return isEnglish
                ? "Instrumental Hip-Hop, dusty vinyl samples, Jazz Hop & study/focus beats"
                : "Hip-Hop strumentale, campioni su vinile, Jazz Hop e beat rilassanti per lavorare o studiare"
        case .euroUkUa:
            return isEnglish
                ? "BBC 1Xtra UK Rap & Grime, French Rap scenes (Skyrock, Generations) & Ukrainian urban streams"
                : "UK Rap & Grime (BBC 1Xtra), scena francese (Skyrock, Generations) e radio urban ucraine"
        }
    }

    var searchTag: String {
        switch self {
        case .all: return "hiphop"
        case .nycEastCoast: return "hip-hop"
        case .oldSchool90s: return "old school hip hop"
        case .westCoastGFunk: return "g-funk"
        case .trapDrillPhonk: return "trap"
        case .underground: return "underground hip hop"
        case .lofiBeats: return "lofi hip hop"
        case .euroUkUa: return "rap"
        }
    }
}

enum SidebarSection: Hashable, Identifiable {
    case favorites
    case style(Subgenre)
    case place(Place)
    case worldSearch

    var id: String {
        switch self {
        case .favorites: return "favorites"
        case .style(let sub): return "style_\(sub.id)"
        case .place(let place): return "place_\(place.id)"
        case .worldSearch: return "worldSearch"
        }
    }
}

extension RadioStation {
    // MARK: - Curated Hip-Hop & Rap Stations by Subgenre

    static let nycEastCoastHipHopStations: [RadioStation] = [
        RadioStation(
            id: "hh-nyc-hot97",
            name: "WQHT Hot 97 (97.1 FM) — New York's Hip-Hop & R&B",
            streamURL: "https://18313.live.streamtheworld.com/WQHTFMAAC.aac",
            country: "United States",
            countryCode: "US",
            city: "New York City",
            tags: "NYC Hip-Hop, Rap, East Coast, Funk Flex, Urban",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://www.hot97.com"
        ),
        RadioStation(
            id: "hh-nyc-power105",
            name: "Power 105.1 FM (WWPR) — New York's Hip-Hop & Breakfast Club",
            streamURL: "https://stream.revma.ihrhls.com/zc1481",
            country: "United States",
            countryCode: "US",
            city: "New York City",
            tags: "NYC Rap, Hip-Hop, R&B, The Breakfast Club",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://power1051.iheart.com"
        ),
        RadioStation(
            id: "hh-generations-us",
            name: "Generations Rap US — Boom Bap & East Coast Underground",
            streamURL: "http://generationfm-underground.ice.infomaniak.ch/generationfm-underground-high.mp3",
            country: "United States / France",
            countryCode: "US",
            city: "New York / Paris",
            tags: "US Rap, Boom Bap, East Coast, Underground Hip-Hop",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://generations.fr"
        ),
        RadioStation(
            id: "hh-181-thebeat",
            name: "181.FM — The Beat (Hip-Hop & Rap)",
            streamURL: "http://listen.181fm.com/181-beat_128k.mp3",
            country: "United States",
            countryCode: "US",
            city: "USA",
            tags: "Hip-Hop, Rap, Urban Beats, US Hits",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://www.181.fm"
        ),
        RadioStation(
            id: "hh-100-hiphop",
            name: "100 Hip-Hop and RNB FM",
            streamURL: "https://streaming.shoutcast.com/100-hip-hop-and-rnb-fm",
            country: "United States",
            countryCode: "US",
            city: "New York / USA",
            tags: "Hip-Hop, Rap, R&B, Urban",
            faviconURL: nil,
            bitrate: 128,
            homepage: nil
        )
    ]

    static let oldSchool90sHipHopStations: [RadioStation] = [
        RadioStation(
            id: "hh-90s90s-hiphop",
            name: "90s90s Hip-Hop & Rap — Golden Era 90s",
            streamURL: "http://streams.90s90s.de/hiphop/mp3-192/streams.90s90s.de/",
            country: "Germany / USA",
            countryCode: "US",
            city: "Golden Era 90s",
            tags: "90s Hip-Hop, Boom Bap, Golden Era, Classic Rap",
            faviconURL: nil,
            bitrate: 192,
            homepage: "https://www.90s90s.de"
        ),
        RadioStation(
            id: "hh-bigfm-oldschool",
            name: "bigFM Oldschool Rap & Hip-Hop",
            streamURL: "https://streams.bigfm.de/bigfm-oldschool-128-mp3",
            country: "Germany / USA",
            countryCode: "US",
            city: "Old School Classics",
            tags: "Old School Rap, 90s Hip-Hop, 80s Beats, Turntablism",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://www.bigfm.de"
        ),
        RadioStation(
            id: "hh-181-oldschool",
            name: "181.FM — Old School Hip-Hop & R&B",
            streamURL: "http://listen.181fm.com/181-oldschool_128k.mp3",
            country: "United States",
            countryCode: "US",
            city: "USA",
            tags: "Old School Hip-Hop, Throwback Rap, Classic R&B",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://www.181.fm"
        ),
        RadioStation(
            id: "hh-skyrock-klassiks",
            name: "Skyrock Klassiks — Rap & Hip-Hop Oldies",
            streamURL: "https://icecast.skyrock.net/s/klassiks_aac_64k?tvr_name=radiofr&tvr_section1=64aac",
            country: "France",
            countryCode: "FR",
            city: "Paris",
            tags: "Classic Rap, 90s & 00s Hip-Hop, Legends",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://skyrock.fm"
        ),
        RadioStation(
            id: "hh-funk-the-planet",
            name: "Funk the Planet — Classic Hip-Hop, Funk & Neo-Soul",
            streamURL: "https://streaming.live365.com/a01484",
            country: "United States",
            countryCode: "US",
            city: "USA",
            tags: "Classic Hip-Hop, P-Funk, New Jack Swing, Neo-Soul",
            faviconURL: nil,
            bitrate: 192,
            homepage: nil
        )
    ]

    static let westCoastGFunkStations: [RadioStation] = [
        RadioStation(
            id: "hh-west-coast-gfunk",
            name: "West Coast — G-Funk & 90s California Hip-Hop",
            streamURL: "https://r.bgp.rodeo/listen/west_coast/radio.mp3",
            country: "United States",
            countryCode: "US",
            city: "Los Angeles / Compton / Long Beach",
            tags: "G-Funk, West Coast Rap, 90s Hip-Hop, Gangsta Rap",
            faviconURL: nil,
            bitrate: 192,
            homepage: nil
        ),
        RadioStation(
            id: "hh-caprice-westcoast",
            name: "West Coast & Gangsta Rap / G-Funk 320k",
            streamURL: "http://79.120.39.202:8004/gangstarap",
            country: "International",
            countryCode: "US",
            city: "West Coast Stream",
            tags: "G-Funk, West Coast Hip-Hop, Lowrider Classics",
            faviconURL: nil,
            bitrate: 320,
            homepage: nil
        )
    ]

    static let trapDrillPhonkStations: [RadioStation] = [
        RadioStation(
            id: "hh-trap-radio",
            name: "TRAP.radio — 24/7 Trap & 808 Beats",
            streamURL: "https://trapradio.streamingmedia.it/play",
            country: "United States",
            countryCode: "US",
            city: "Atlanta / Global",
            tags: "Trap, 808s, Modern Rap, Hip-Hop",
            faviconURL: nil,
            bitrate: 128,
            homepage: nil
        ),
        RadioStation(
            id: "hh-badradio-phonk",
            name: "BadRadio 24/7 — OG Phonk, Memphis, Houston, Trap & Trill",
            streamURL: "https://s2.radio.co/s2b2b68744/listen",
            country: "France / USA",
            countryCode: "US",
            city: "Memphis / Houston Vibes",
            tags: "OG Phonk, Memphis Rap, Houston Chopped & Screwed, Trap, Trill",
            faviconURL: nil,
            bitrate: 128,
            homepage: nil
        )
    ]

    static let undergroundHipHopStations: [RadioStation] = [
        RadioStation(
            id: "hh-underground-caprice",
            name: "Underground Rap Radio — Pure Lyricism & Indie MCs",
            streamURL: "http://79.111.14.76:8000/undergroundrap",
            country: "International",
            countryCode: "US",
            city: "Underground Scene",
            tags: "Underground Rap, Boom Bap, Conscious Hip-Hop, Indie MCs",
            faviconURL: nil,
            bitrate: 128,
            homepage: nil
        ),
        RadioStation(
            id: "hh-somafm-fluid",
            name: "SomaFM Fluid — Instrumental Hip-Hop, Future Soul & Beats",
            streamURL: "https://ice6.somafm.com/fluid-128-mp3",
            country: "United States",
            countryCode: "US",
            city: "San Francisco",
            tags: "Instrumental Hip-Hop, Abstract Beats, Future Soul, Chilled Trap",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://somafm.com/fluid/"
        )
    ]

    static let lofiChillhopStations: [RadioStation] = [
        RadioStation(
            id: "hh-fluxfm-chillhop",
            name: "FluxFM ChillHop — Lo-Fi Hip-Hop & Dusty Beats (320k)",
            streamURL: "http://streams.fluxfm.de/Chillhop/mp3-320",
            country: "Germany",
            countryCode: "DE",
            city: "Berlin",
            tags: "Chillhop, Lo-Fi Hip-Hop, Jazz Hop, Vinyl Beats",
            faviconURL: nil,
            bitrate: 320,
            homepage: "https://www.fluxfm.de"
        ),
        RadioStation(
            id: "hh-ilove-chillhop",
            name: "I Love Chillhop — Lo-Fi Hip-Hop & Study Beats",
            streamURL: "https://ilm.stream12.radiohost.de/ilm_ilovechillhop_mp3-192",
            country: "Germany",
            countryCode: "DE",
            city: "Berlin",
            tags: "Lo-Fi Hip-Hop, Chill Beats, Instrumental Rap",
            faviconURL: nil,
            bitrate: 192,
            homepage: nil
        ),
        RadioStation(
            id: "hh-0r-lofi",
            name: "0R Lo-Fi Hip-Hop — Smooth Beats & Instrumental",
            streamURL: "https://0nlineradio.radioho.st/0r-lo-fi",
            country: "Germany",
            countryCode: "DE",
            city: "Europe",
            tags: "Lo-Fi Hip-Hop, Study Beats, Smooth Instrumental",
            faviconURL: nil,
            bitrate: 128,
            homepage: nil
        )
    ]

    static let euroUkUaRapStations: [RadioStation] = [
        RadioStation(
            id: "hh-bbc-1xtra",
            name: "BBC Radio 1Xtra — UK Rap, Grime, Drill & Hip-Hop",
            streamURL: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/audio_syndication_low_sbr_v1/aks/bbc_1xtra.m3u8",
            country: "United Kingdom",
            countryCode: "GB",
            city: "London",
            tags: "UK Rap, Grime, UK Drill, Hip-Hop, Afrobeats, R&B",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://www.bbc.co.uk/1xtra"
        ),
        RadioStation(
            id: "hh-skyrock-paris",
            name: "Skyrock 96.0 FM Paris — Premier sur le Rap",
            streamURL: "http://icecast.skyrock.net/s/natio_mp3_128k",
            country: "France",
            countryCode: "FR",
            city: "Paris",
            tags: "French Rap, US Hip-Hop, Planète Rap, Urban",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://skyrock.fm"
        ),
        RadioStation(
            id: "hh-generations-fr-gold",
            name: "Generations Rap FR Gold — Classic French Hip-Hop",
            streamURL: "http://gene-wr06.ice.infomaniak.ch/gene-wr06.mp3",
            country: "France",
            countryCode: "FR",
            city: "Paris / Marseille",
            tags: "French Rap Gold, Marseille & Paris Classics, Boom Bap FR",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://generations.fr"
        ),
        RadioStation(
            id: "hh-ua-pihota",
            name: "Радіо Піхота (Radio Pihota Ukraine) — Rap, Rock & Rebel",
            streamURL: "https://online.pihota.fm/listen/radio/aac64",
            country: "Ukraine",
            countryCode: "UA",
            city: "Kyiv",
            tags: "Ukrainian Rap, Alternative, Rock, Punk",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://pihota.fm"
        )
    ]

    static var defaultHipHopStations: [RadioStation] {
        nycEastCoastHipHopStations
            + oldSchool90sHipHopStations
            + westCoastGFunkStations
            + trapDrillPhonkStations
            + undergroundHipHopStations
            + lofiChillhopStations
            + euroUkUaRapStations
    }

    static func hipHopStations(for subgenre: HipHopSubgenre) -> [RadioStation] {
        switch subgenre {
        case .all:
            return defaultHipHopStations
        case .nycEastCoast:
            return nycEastCoastHipHopStations
        case .oldSchool90s:
            return oldSchool90sHipHopStations
        case .westCoastGFunk:
            return westCoastGFunkStations
        case .trapDrillPhonk:
            return trapDrillPhonkStations
        case .underground:
            return undergroundHipHopStations
        case .lofiBeats:
            return lofiChillhopStations
        case .euroUkUa:
            return euroUkUaRapStations
        }
    }

    // MARK: - Default Ukrainian & NYC Stations

    static let defaultUkrainianStations: [RadioStation] = [
        RadioStation(
            id: "ua-ukrainske-radio",
            name: "Українське Радіо (Suspilne)",
            streamURL: "http://radio.ukr.radio:8000/ur1-mp3",
            country: "Ukraine",
            countryCode: "UA",
            city: "Kyiv",
            tags: "News, Public Radio, Talk, Culture",
            faviconURL: nil,
            bitrate: 192,
            homepage: "https://ukr.radio"
        ),
        RadioStation(
            id: "ua-radio-promin",
            name: "Радіо Промінь (Radio Promin)",
            streamURL: "http://radio.ukr.radio:8000/ur2-mp3",
            country: "Ukraine",
            countryCode: "UA",
            city: "Kyiv",
            tags: "Ukrainian Music, Pop, Rock, Indie",
            faviconURL: nil,
            bitrate: 192,
            homepage: "https://ukr.radio"
        ),
        RadioStation(
            id: "ua-radio-kultura",
            name: "Радіо Культура (Radio Kultura)",
            streamURL: "http://radio.ukr.radio:8000/ur3-mp3",
            country: "Ukraine",
            countryCode: "UA",
            city: "Kyiv",
            tags: "Classical, Culture, Theatre, Literature",
            faviconURL: nil,
            bitrate: 192,
            homepage: "https://ukr.radio"
        ),
        RadioStation(
            id: "ua-radio-nv",
            name: "Radio NV (Радіо НВ)",
            streamURL: "http://91.218.212.84:8000/radionv.mp3",
            country: "Ukraine",
            countryCode: "UA",
            city: "Kyiv",
            tags: "News, Talk, Politics, Live",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://nv.ua/ukr/radio.html"
        ),
        RadioStation(
            id: "ua-hromadske",
            name: "Громадське Радіо (Hromadske Radio)",
            streamURL: "http://91.218.212.67:8000/stream",
            country: "Ukraine",
            countryCode: "UA",
            city: "Kyiv",
            tags: "Independent News, Talk, Podcasts",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://hromadske.radio"
        ),
        RadioStation(
            id: "ua-kraina-fm",
            name: "Країна ФМ (Kraina FM)",
            streamURL: "http://185.65.245.34:8000/krainafm128",
            country: "Ukraine",
            countryCode: "UA",
            city: "Kyiv",
            tags: "100% Ukrainian Music, Pop, Indie",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://krainafm.com.ua"
        ),
        RadioStation(
            id: "ua-pihota-rap",
            name: "Радіо Піхота (Radio Pihota) — UA Rap & Rock",
            streamURL: "https://online.pihota.fm/listen/radio/aac64",
            country: "Ukraine",
            countryCode: "UA",
            city: "Kyiv",
            tags: "Ukrainian Rap, Rock, Punk, Rebel",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://pihota.fm"
        ),
        RadioStation(
            id: "ua-hit-fm",
            name: "Хіт FM Україна (Hit FM)",
            streamURL: "http://195.95.206.17/HitFM",
            country: "Ukraine",
            countryCode: "UA",
            city: "Kyiv",
            tags: "Pop, Dance, Hits",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://www.hitfm.ua"
        ),
        RadioStation(
            id: "ua-kiss-fm",
            name: "Kiss FM Ukraine HD",
            streamURL: "https://online.kissfm.ua/KissFM_HD",
            country: "Ukraine",
            countryCode: "UA",
            city: "Kyiv",
            tags: "Electronic, Dance, House, Club",
            faviconURL: nil,
            bitrate: 256,
            homepage: "https://www.kissfm.ua"
        ),
        RadioStation(
            id: "ua-lux-fm",
            name: "Люкс FM 103.1 (Lux FM Kyiv)",
            streamURL: "http://lux.radio.tvstitch.com/kyiv/lux_adv_sd",
            country: "Ukraine",
            countryCode: "UA",
            city: "Kyiv",
            tags: "Pop, Morning Show, Hits",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://lux.fm"
        ),
        RadioStation(
            id: "ua-radio-roks",
            name: "Radio ROKS Ukraine",
            streamURL: "http://online.radioroks.ua/RadioROKS_HD",
            country: "Ukraine",
            countryCode: "UA",
            city: "Kyiv",
            tags: "Classic Rock, Hard Rock, Ballads",
            faviconURL: nil,
            bitrate: 256,
            homepage: "https://www.radioroks.ua"
        )
    ]

    static let defaultNewYorkStations: [RadioStation] = [
        nycEastCoastHipHopStations[0], // WQHT Hot 97 NYC Hip-Hop
        nycEastCoastHipHopStations[1], // Power 105.1 NYC Hip-Hop
        RadioStation(
            id: "nyc-wnyc-fm",
            name: "WNYC 93.9 FM — New York Public Radio",
            streamURL: "http://fm939.wnyc.org/wnycfm.aac",
            country: "United States",
            countryCode: "US",
            city: "New York City",
            tags: "NPR, News, Talk, NYC Culture",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://www.wnyc.org"
        ),
        RadioStation(
            id: "nyc-wqxr",
            name: "WQXR 105.9 FM — Classical New York",
            streamURL: "https://stream.wqxr.org/wqxr-web",
            country: "United States",
            countryCode: "US",
            city: "New York City",
            tags: "Classical, Orchestra, Carnegie Hall",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://www.wqxr.org"
        ),
        RadioStation(
            id: "nyc-wbgo",
            name: "WBGO 88.3 FM — Newark / NYC Jazz",
            streamURL: "https://ais-sa8.cdnstream1.com/3629_128.mp3",
            country: "United States",
            countryCode: "US",
            city: "New York Area",
            tags: "Jazz, Blues, Soul, Live Jazz",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://www.wbgo.org"
        ),
        RadioStation(
            id: "nyc-wfmu",
            name: "WFMU 91.1 FM — Freeform Radio",
            streamURL: "http://stream0.wfmu.org/freeform-128k",
            country: "United States",
            countryCode: "US",
            city: "New York / Jersey City",
            tags: "Indie, Eclectic, Freeform, Underground",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://wfmu.org"
        ),
        RadioStation(
            id: "nyc-wfuv",
            name: "WFUV 90.7 FM — Fordham University NYC",
            streamURL: "https://onair.wfuv.org/onair-aacplus",
            country: "United States",
            countryCode: "US",
            city: "Bronx, New York",
            tags: "Adult Alternative, Indie Rock, Americana",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://wfuv.org"
        ),
        RadioStation(
            id: "nyc-bloomberg",
            name: "Bloomberg Radio 1130 AM New York",
            streamURL: "http://29314.live.streamtheworld.com:3690/WBBRNYAAC_SC",
            country: "United States",
            countryCode: "US",
            city: "New York City",
            tags: "Business, Finance, Wall Street, News",
            faviconURL: nil,
            bitrate: 96,
            homepage: "https://www.bloomberg.com/audio"
        ),
        RadioStation(
            id: "nyc-z100",
            name: "Z100 New York (WHTZ 100.3 FM)",
            streamURL: "https://stream.revma.ihrhls.com/zc1469",
            country: "United States",
            countryCode: "US",
            city: "New York City",
            tags: "Top 40, Pop, NYC Hit Music",
            faviconURL: nil,
            bitrate: 128,
            homepage: "https://z100.iheart.com"
        ),
        RadioStation(
            id: "nyc-classic-vinyl",
            name: "Classic Vinyl HD — New York",
            streamURL: "https://icecast.walmradio.com:8443/classic",
            country: "United States",
            countryCode: "US",
            city: "New York",
            tags: "Jazz, Swing, Crooners, Vintage Vinyl",
            faviconURL: nil,
            bitrate: 320,
            homepage: "https://walmradio.com"
        )
    ]
}
