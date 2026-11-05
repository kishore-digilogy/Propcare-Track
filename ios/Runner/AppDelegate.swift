import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var trackingManager: LocationTrackingManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyDbB0fHk_8TQ85wQfqn_7I6RMKlVUQlkW0")
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    setupTrackingChannelIfNeeded()
    return launched
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    setupTrackingChannelIfNeeded()
    super.applicationDidBecomeActive(application)
  }

  private func setupTrackingChannelIfNeeded() {
    guard trackingManager == nil else { return }
    if let registrar = registrar(forPlugin: "PropCareTracking") {
      trackingManager = LocationTrackingManager(messenger: registrar.messenger())
    } else if let controller = window?.rootViewController as? FlutterViewController {
      trackingManager = LocationTrackingManager(messenger: controller.binaryMessenger)
    }
  }
}
