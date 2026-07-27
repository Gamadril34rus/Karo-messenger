import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // VoIP push notifications for call signaling
    if #available(iOS 14.0, *) {
      // VoIP category is configured via UNUserNotificationCenter in Flutter plugin
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
