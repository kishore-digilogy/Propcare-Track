import CoreLocation
import Flutter
import UIKit

/// Core Location bridge.
///
/// Mirrors the Kotlin service: it owns the 20-second stationary state machine,
/// appends every fix to a durable queue and streams the same record to Flutter
/// while the app is alive.
final class LocationTrackingManager: NSObject, CLLocationManagerDelegate, FlutterStreamHandler {
    private enum Keys {
        static let tracking = "propcare.tracking.active"
        static let sessionId = "propcare.tracking.sessionId"
        static let employeeId = "propcare.tracking.employeeId"
        static let platform = "propcare.tracking.platform"
        static let interval = "propcare.tracking.intervalMs"
        static let distanceFilter = "propcare.tracking.distanceFilter"
        static let stationaryRadius = "propcare.tracking.stationaryRadius"
        static let stationarySeconds = "propcare.tracking.stationarySeconds"
        static let startedAt = "propcare.tracking.startedAt"
        static let lastFixAt = "propcare.tracking.lastFixAt"
        static let provider = "propcare.tracking.provider"
        static let state = "propcare.tracking.stationaryState"
    }

    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private let manager = CLLocationManager()
    private let defaults = UserDefaults.standard

    private var sink: FlutterEventSink?

    private var sessionId = ""
    private var employeeId = ""
    private var platform = "ios"
    private var intervalMs: TimeInterval = 12
    private var distanceFilter: CLLocationDistance = 5
    private var stationaryRadius: CLLocationDistance = 30
    private var stationarySeconds: TimeInterval = 20

    private var anchor: CLLocation?
    private var anchorSince: Date?
    private var lastInsideAt: Date?
    private var activeId: String?
    private var activeStartAt: Date?
    private var activeLocation: CLLocation?

    private var lastEmittedAt: Date?
    private var lastEmittedLocation: CLLocation?

    private let maxAccuracy: CLLocationAccuracy = 80
    private let breakHysteresis = 1.6

    init(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(name: "propcare/tracking", binaryMessenger: messenger)
        eventChannel = FlutterEventChannel(name: "propcare/tracking_events", binaryMessenger: messenger)
        super.init()

        UIDevice.current.isBatteryMonitoringEnabled = true

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = distanceFilter
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        manager.allowsBackgroundLocationUpdates = true

        restoreConfig()
        restoreState()

        eventChannel.setStreamHandler(self)
        methodChannel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    // ── FlutterStreamHandler ─────────────────────────────────────────────────

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        emitStatus(defaults.bool(forKey: Keys.tracking))
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }

    // ── MethodChannel ────────────────────────────────────────────────────────

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startTracking":
            start(call, result: result)
        case "stopTracking":
            stop(result: result)
        case "isTracking":
            result(defaults.bool(forKey: Keys.tracking))
        case "getStatus":
            result(status())
        case "getPendingRecords":
            result(TrackingStore.shared.records())
        case "ackPendingRecords":
            let args = call.arguments as? [String: Any]
            let ids = Set((args?["ids"] as? [String]) ?? [])
            TrackingStore.shared.ack(ids: ids)
            result(true)
        case "getBatteryLevel":
            result(batteryLevel())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func start(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let requested = args["sessionId"] as? String,
              !requested.isEmpty
        else {
            result(FlutterError(code: "invalid_config", message: "A tracking session id is required.", details: nil))
            return
        }

        sessionId = requested
        employeeId = (args["employeeId"] as? String) ?? ""
        platform = (args["platform"] as? String) ?? "ios"
        if let value = args["intervalMs"] as? NSNumber {
            intervalMs = max(1, value.doubleValue / 1000)
        }
        if let value = args["distanceFilterMeters"] as? NSNumber {
            distanceFilter = max(0, value.doubleValue)
        }
        if let value = args["stationaryRadiusMeters"] as? NSNumber {
            stationaryRadius = max(1, value.doubleValue)
        }
        if let value = args["stationarySeconds"] as? NSNumber {
            stationarySeconds = max(1, value.doubleValue)
        }

        guard CLLocationManager.locationServicesEnabled() else {
            emitError("Location services are turned off. Enable GPS to keep tracking.")
            result(false)
            return
        }

        saveConfig()
        defaults.set(true, forKey: Keys.tracking)
        manager.distanceFilter = distanceFilter
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false

        requestAuthorizationIfNeeded()
        manager.startUpdatingLocation()
        if let last = manager.location {
            handleLocation(last)
        }
        emitStatus(true)
        result(true)
    }

    private func stop(result: @escaping FlutterResult) {
        manager.stopUpdatingLocation()
        defaults.set(false, forKey: Keys.tracking)
        emitStatus(false)
        result(true)
    }

    private func status() -> [String: Any] {
        [
            "tracking": defaults.bool(forKey: Keys.tracking),
            "sessionId": defaults.string(forKey: Keys.sessionId) ?? NSNull(),
            "employeeId": defaults.string(forKey: Keys.employeeId) ?? NSNull(),
            "lastFixAt": defaults.integer(forKey: Keys.lastFixAt),
            "provider": defaults.string(forKey: Keys.provider) ?? NSNull(),
            "queueSize": TrackingStore.shared.count(),
        ]
    }

    private func requestAuthorizationIfNeeded() {
        if #available(iOS 14.0, *) {
            switch manager.authorizationStatus {
            case .notDetermined, .authorizedWhenInUse:
                manager.requestAlwaysAuthorization()
            default:
                break
            }
        } else {
            if CLLocationManager.authorizationStatus() == .notDetermined {
                manager.requestAlwaysAuthorization()
            }
        }
    }

    // ── CLLocationManagerDelegate ────────────────────────────────────────────

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if #available(iOS 14.0, *) {
            switch manager.authorizationStatus {
            case .denied, .restricted:
                emitError("Location permission was denied. Open Settings to allow tracking.")
            case .authorizedAlways, .authorizedWhenInUse:
                if defaults.bool(forKey: Keys.tracking) {
                    manager.startUpdatingLocation()
                }
            default:
                break
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .denied || status == .restricted {
            emitError("Location permission was denied. Open Settings to allow tracking.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            handleLocation(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let clError = error as? CLError else { return }
        switch clError.code {
        case .denied:
            emitError("Location permission was revoked. Background tracking is paused.")
        case .locationUnknown:
            break
        default:
            emitError(clError.localizedDescription)
        }
    }

    // ── Record pipeline ──────────────────────────────────────────────────────

    private func handleLocation(_ location: CLLocation) {
        let now = location.timestamp

        // Core Location can replay cached fixes; keep the stream clean.
        if let lastAt = lastEmittedAt, abs(now.timeIntervalSince(lastAt)) < 1.5,
           let previous = lastEmittedLocation, previous.distance(from: location) < 2 {
            return
        }
        lastEmittedAt = now
        lastEmittedLocation = location

        handleStationary(location, now: now)

        let stationary = activeId != nil || (location.speed >= 0 && location.speed < 0.5)
        var record: [String: Any] = [
            "type": "location",
            "id": UUID().uuidString,
            "employeeId": employeeId,
            "sessionId": sessionId,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "battery": batteryLevel(),
            "platform": "ios",
            "movementStatus": stationary ? "stationary" : "moving",
            "recordedAt": milliseconds(now),
            "source": "native",
        ]
        record["speed"] = location.speed >= 0 ? location.speed : NSNull()
        record["bearing"] = location.course >= 0 ? location.course : NSNull()

        TrackingStore.shared.append(record)
        sink?(record)
        defaults.set(milliseconds(now), forKey: Keys.lastFixAt)
        defaults.set(providerName(location), forKey: Keys.provider)
    }

    private func handleStationary(_ location: CLLocation, now: Date) {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= maxAccuracy else { return }

        guard let anchor, let since = anchorSince else {
            setAnchor(location)
            saveState()
            return
        }
        if now < since { return }

        let distance = anchor.distance(from: location)
        if distance <= stationaryRadius * breakHysteresis {
            lastInsideAt = now
            if activeId == nil && now.timeIntervalSince(since) >= stationarySeconds {
                activeId = UUID().uuidString
                activeStartAt = since
                activeLocation = anchor
                emitStationary("stationary_started", now: now, endAt: nil, duration: 0, status: "active")
            } else if activeId != nil {
                let duration = Int(now.timeIntervalSince(activeStartAt ?? since))
                emitStationary("stationary_updated", now: now, endAt: now, duration: duration, status: "active")
            }
        } else {
            if activeId != nil {
                let end = lastInsideAt ?? now
                let duration = Int(end.timeIntervalSince(activeStartAt ?? end))
                emitStationary("stationary_completed", now: now, endAt: end, duration: duration, status: "completed")
                activeId = nil
                activeStartAt = nil
                activeLocation = nil
            }
            setAnchor(location)
        }
        saveState()
    }

    private func setAnchor(_ location: CLLocation) {
        anchor = location
        anchorSince = location.timestamp
        lastInsideAt = location.timestamp
    }

    private func emitStationary(
        _ type: String,
        now: Date,
        endAt: Date?,
        duration: Int,
        status: String
    ) {
        guard let id = activeId, let start = activeStartAt else { return }
        let point = activeLocation ?? anchor
        var event: [String: Any] = [
            "type": type,
            "id": id,
            "employeeId": employeeId,
            "sessionId": sessionId,
            "latitude": point?.coordinate.latitude ?? 0,
            "longitude": point?.coordinate.longitude ?? 0,
            "startAt": milliseconds(start),
            "durationSeconds": max(0, duration),
            "accuracy": point?.horizontalAccuracy ?? 0,
            "battery": batteryLevel(),
            "status": status,
            "radiusMeters": stationaryRadius,
            "recordedAt": milliseconds(now),
            "source": "native",
        ]
        if let endAt {
            event["endAt"] = milliseconds(endAt)
        }
        TrackingStore.shared.append(event)
        sink?(event)
    }

    // ── Persistence ──────────────────────────────────────────────────────────

    private func saveConfig() {
        defaults.set(sessionId, forKey: Keys.sessionId)
        defaults.set(employeeId, forKey: Keys.employeeId)
        defaults.set(platform, forKey: Keys.platform)
        defaults.set(Int(intervalMs * 1000), forKey: Keys.interval)
        defaults.set(distanceFilter, forKey: Keys.distanceFilter)
        defaults.set(stationaryRadius, forKey: Keys.stationaryRadius)
        defaults.set(Int(stationarySeconds), forKey: Keys.stationarySeconds)
        if defaults.object(forKey: Keys.startedAt) == nil {
            defaults.set(milliseconds(Date()), forKey: Keys.startedAt)
        }
    }

    private func restoreConfig() {
        sessionId = defaults.string(forKey: Keys.sessionId) ?? ""
        employeeId = defaults.string(forKey: Keys.employeeId) ?? ""
        platform = defaults.string(forKey: Keys.platform) ?? "ios"
        let storedInterval = defaults.integer(forKey: Keys.interval)
        if storedInterval > 0 {
            intervalMs = TimeInterval(storedInterval) / 1000
        }
        let storedFilter = defaults.double(forKey: Keys.distanceFilter)
        if storedFilter > 0 {
            distanceFilter = storedFilter
            manager.distanceFilter = storedFilter
        }
        let storedRadius = defaults.double(forKey: Keys.stationaryRadius)
        if storedRadius > 0 { stationaryRadius = storedRadius }
        let storedSeconds = defaults.integer(forKey: Keys.stationarySeconds)
        if storedSeconds > 0 { stationarySeconds = TimeInterval(storedSeconds) }
    }

    private func saveState() {
        var state: [String: Any] = [
            "anchorSince": anchorSince.map(milliseconds) ?? NSNull(),
            "lastInsideAt": lastInsideAt.map(milliseconds) ?? NSNull(),
            "activeId": activeId ?? NSNull(),
            "activeStartAt": activeStartAt.map(milliseconds) ?? NSNull(),
        ]
        if let anchor {
            state["anchorLat"] = anchor.coordinate.latitude
            state["anchorLng"] = anchor.coordinate.longitude
        }
        if let activeLocation {
            state["activeLat"] = activeLocation.coordinate.latitude
            state["activeLng"] = activeLocation.coordinate.longitude
            state["activeAccuracy"] = activeLocation.horizontalAccuracy
        }
        guard let data = try? JSONSerialization.data(withJSONObject: state) else { return }
        defaults.set(data, forKey: Keys.state)
    }

    private func restoreState() {
        guard let data = defaults.data(forKey: Keys.state),
              let state = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return }
        if let lat = state["anchorLat"] as? Double,
           let lng = state["anchorLng"] as? Double,
           let since = state["anchorSince"] as? Int {
            anchor = CLLocation(latitude: lat, longitude: lng)
            anchorSince = Date(timeIntervalSince1970: TimeInterval(since) / 1000)
        }
        if let inside = state["lastInsideAt"] as? Int {
            lastInsideAt = Date(timeIntervalSince1970: TimeInterval(inside) / 1000)
        }
        activeId = state["activeId"] as? String
        if let start = state["activeStartAt"] as? Int {
            activeStartAt = Date(timeIntervalSince1970: TimeInterval(start) / 1000)
        }
        if let lat = state["activeLat"] as? Double,
           let lng = state["activeLng"] as? Double {
            activeLocation = CLLocation(latitude: lat, longitude: lng)
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private func emitStatus(_ tracking: Bool) {
        sink?(["type": "status", "tracking": tracking, "sessionId": sessionId])
    }

    private func emitError(_ message: String) {
        sink?(["type": "error", "message": message])
    }

    private func batteryLevel() -> Int {
        let level = UIDevice.current.batteryLevel
        if level < 0 { return 0 }
        return max(0, min(100, Int((level * 100).rounded())))
    }

    private func providerName(_ location: CLLocation) -> String {
        if #available(iOS 15.0, *) {
            if location.sourceInformation?.isSimulatedBySoftware == true {
                return "simulated"
            }
        }
        return "coreLocation"
    }

    private func milliseconds(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 * 1000)
    }
}
