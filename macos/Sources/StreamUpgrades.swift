import Foundation

/// Stream URLs that changed since earlier versions: http:// streams moved to the
/// broadcaster's official https:// endpoint, and Kraina FM's old stream, which is gone.
/// Applied to saved favorites at launch so they keep working.
/// Keep in sync with HTTPS_OVERRIDES in pwa/tools/gen-catalog.py.
enum StreamUpgrades {
    static let map: [String: String] = [
        "http://fm939.wnyc.org/wnycfm.aac":
            "https://fm939.wnyc.org/wnycfm.aac",
        "http://gene-wr06.ice.infomaniak.ch/gene-wr06.mp3":
            "https://gene-wr06.ice.infomaniak.ch/gene-wr06.mp3",
        "http://generationfm-underground.ice.infomaniak.ch/generationfm-underground-high.mp3":
            "https://generationfm-underground.ice.infomaniak.ch/generationfm-underground-high.mp3",
        "http://icecast.skyrock.net/s/natio_mp3_128k":
            "https://icecast.skyrock.net/s/natio_mp3_128k",
        "http://listen.181fm.com/181-beat_128k.mp3":
            "https://listen.181fm.com/181-beat_128k.mp3",
        "http://listen.181fm.com/181-oldschool_128k.mp3":
            "https://listen.181fm.com/181-oldschool_128k.mp3",
        "http://lux.radio.tvstitch.com/kyiv/lux_adv_sd":
            "https://lux.radio.tvstitch.com/kyiv/lux_adv_sd",
        "http://online.radioroks.ua/RadioROKS_HD":
            "https://online.radioroks.ua/RadioROKS_HD",
        "http://stream0.wfmu.org/freeform-128k":
            "https://stream0.wfmu.org/freeform-128k",
        "http://streams.90s90s.de/hiphop/mp3-192/streams.90s90s.de/":
            "https://streams.90s90s.de/hiphop/mp3-192/streams.90s90s.de/",
        "http://streams.fluxfm.de/Chillhop/mp3-320":
            "https://streams.fluxfm.de/Chillhop/mp3-320",
        "http://radio.ukr.radio:8000/ur1-mp3":
            "https://radio.ukr.radio/ur1-mp3",
        "http://radio.ukr.radio:8000/ur2-mp3":
            "https://radio.ukr.radio/ur2-mp3",
        "http://radio.ukr.radio:8000/ur3-mp3":
            "https://radio.ukr.radio/ur3-mp3",
        "http://91.218.212.84:8000/radionv.mp3":
            "https://online-radio.nv.ua/radionv.mp3",
        "http://91.218.212.67:8000/stream":
            "https://hromadske.radio/radio_https_upstream",
        "http://185.65.245.34:8000/krainafm128":
            "https://live2.radioec.com.ua/kiev128s.mp3",
        "http://195.95.206.17/HitFM":
            "https://online.hitfm.ua/HitFM",
        "http://29314.live.streamtheworld.com:3690/WBBRNYAAC_SC":
            "https://playerservices.streamtheworld.com/api/livestream-redirect/WBBRAMAAC.aac",
    ]

    /// Returns the list with old stream URLs replaced, and whether anything changed.
    static func apply(to stations: [RadioStation]) -> (stations: [RadioStation], changed: Bool) {
        var changed = false
        let upgraded = stations.map { station -> RadioStation in
            guard let newURL = map[station.streamURL] else { return station }
            changed = true
            var s = station
            s.streamURL = newURL
            return s
        }
        return (upgraded, changed)
    }
}
