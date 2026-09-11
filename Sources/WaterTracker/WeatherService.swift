import Foundation
import CoreLocation

struct WeatherConditions: Equatable {
    var temperatureC: Double
    var humidity: Double
    var city: String

    /// Celsius stays the internal unit — the heat-index maths and its tiers are
    /// defined in it — but everything shown to the reader is Fahrenheit.
    static func fahrenheit(_ celsius: Double) -> Int {
        Int((celsius * 9 / 5 + 32).rounded())
    }

    var temperatureF: Int { Self.fahrenheit(temperatureC) }
    var heatIndexF: Int { Self.fahrenheit(heatIndexC) }

    /// Apparent temperature — what the body actually has to cope with. Humid air
    /// blocks evaporative cooling, so sweat losses climb faster than the raw
    /// thermometer reading suggests.
    var heatIndexC: Double {
        // Below ~27°C the heat index and air temperature agree closely enough.
        guard temperatureC >= 27 else { return temperatureC }

        let t = temperatureC * 9 / 5 + 32
        let r = humidity

        var hi = -42.379
            + 2.04901523 * t
            + 10.14333127 * r
            - 0.22475541 * t * r
            - 0.00683783 * t * t
            - 0.05481717 * r * r
            + 0.00122874 * t * t * r
            + 0.00085282 * t * r * r
            - 0.00000199 * t * t * r * r

        // Rothfusz overshoots in dry heat; the NWS applies this correction.
        if r < 13, t >= 80, t <= 112 {
            hi -= ((13 - r) / 4) * ((17 - abs(t - 95)) / 17).squareRoot()
        }

        return (hi - 32) * 5 / 9
    }

    /// Extra water to offset heat and humidity, in millilitres.
    var extraML: Int {
        switch heatIndexC {
        case ..<27: return 0
        case 27..<32: return 250
        case 32..<39: return 500
        case 39..<45: return 750
        default: return 1000
        }
    }

    var summary: String {
        if heatIndexF > temperatureF {
            return "\(temperatureF)°F, \(Int(humidity))% humidity, feels like \(heatIndexF)°F"
        }
        return "\(temperatureF)°F, \(Int(humidity))% humidity"
    }

    var isHeatwave: Bool { heatIndexC >= 39 }
}

@MainActor
final class WeatherService: NSObject, ObservableObject {
    @Published private(set) var conditions: WeatherConditions?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var authorizationDenied = false

    private let manager = CLLocationManager()
    private var lastFetch: Date?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Weather only matters at city scale, so a cached reading stays good for a while.
    func refreshIfStale() {
        if let lastFetch, Date().timeIntervalSince(lastFetch) < 1800 { return }
        refresh()
    }

    func refresh() {
        errorMessage = nil

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            authorizationDenied = true
            conditions = nil
        default:
            authorizationDenied = false
            isLoading = true
            manager.requestLocation()
        }
    }

    private func fetch(for location: CLLocation) async {
        defer { isLoading = false }

        let coordinate = location.coordinate
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m")
        ]

        guard let url = components.url else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let city = await cityName(for: location)

            conditions = WeatherConditions(
                temperatureC: response.current.temperature_2m,
                humidity: response.current.relative_humidity_2m,
                city: city
            )
            lastFetch = Date()
        } catch {
            errorMessage = "Couldn't load local weather."
        }
    }

    private func cityName(for location: CLLocation) async -> String {
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        guard let place = placemarks?.first else { return "Your area" }
        return place.locality ?? place.administrativeArea ?? "Your area"
    }

    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let relative_humidity_2m: Double
        }
        let current: Current
    }
}

extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            await fetch(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            isLoading = false
            errorMessage = "Couldn't determine your location."
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                authorizationDenied = false
                isLoading = true
                manager.requestLocation()
            case .denied, .restricted:
                authorizationDenied = true
                isLoading = false
                conditions = nil
            default:
                break
            }
        }
    }
}
