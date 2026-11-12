import Foundation

@MainActor
final class RadioBrowserService {
    static let shared = RadioBrowserService()

    // As of 2026-11 fi1/at1/nl1 no longer resolve; "all" is Radio Browser's
    // round-robin name, so it keeps working as servers come and go.
    private let mirrors = [
        "https://de1.api.radio-browser.info",
        "https://all.api.radio-browser.info"
    ]

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 14
        config.httpAdditionalHeaders = [
            "User-Agent": "KosmoRadio/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1") (https://github.com/marcellomarch/kosmo-radio-player)"
        ]
        self.session = URLSession(configuration: config)
    }

    func searchStations(
        query: String = "",
        countryCode: String? = nil,
        state: String? = nil,
        tag: String? = nil,
        limit: Int = 60
    ) async throws -> [RadioStation] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "order", value: "clickcount"),
            URLQueryItem(name: "reverse", value: "true"),
            URLQueryItem(name: "hidebroken", value: "true")
        ]

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            queryItems.append(URLQueryItem(name: "name", value: trimmedQuery))
        }
        if let countryCode, !countryCode.isEmpty {
            queryItems.append(URLQueryItem(name: "countrycode", value: countryCode.uppercased()))
        }
        if let state, !state.isEmpty {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }
        if let tag, !tag.isEmpty {
            queryItems.append(URLQueryItem(name: "tag", value: tag.lowercased()))
        }

        var lastError: Error?

        for mirror in mirrors {
            guard var components = URLComponents(string: "\(mirror)/json/stations/search") else {
                continue
            }
            components.queryItems = queryItems
            guard let url = components.url else { continue }

            do {
                let (data, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    let dtos = try JSONDecoder().decode([RadioBrowserStationDTO].self, from: data)
                    var seenURLs = Set<String>()
                    var stations: [RadioStation] = []
                    for dto in dtos {
                        if let st = dto.toRadioStation(), !seenURLs.contains(st.streamURL) {
                            seenURLs.insert(st.streamURL)
                            stations.append(st)
                        }
                    }
                    return stations
                }
            } catch {
                lastError = error
                continue
            }
        }

        if let lastError {
            throw lastError
        }
        return []
    }
}
