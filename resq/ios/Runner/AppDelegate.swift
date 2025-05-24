import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1) let FlutterAppDelegate spin up its engine
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // 2) *then* wire up all your plugins against that engine
    GeneratedPluginRegistrant.register(with: self)

    return launched
  }
}
