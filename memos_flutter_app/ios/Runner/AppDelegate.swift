import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var memoFlowNativeBridge: MemoFlowNativeBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      memoFlowNativeBridge = MemoFlowNativeBridge(
        messenger: controller.binaryMessenger
      )
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if memoFlowNativeBridge?.handleOpenURL(url) == true {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
