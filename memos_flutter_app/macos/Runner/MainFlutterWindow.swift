import Cocoa
import FlutterMacOS
import connectivity_plus
import cryptography_flutter
import desktop_multi_window
import device_info_plus
import file_picker
import file_selector_macos
import flutter_local_notifications
import flutter_secure_storage_macos
import flutter_timezone
import local_notifier
import package_info_plus
import path_provider_foundation
import screen_retriever_macos
import sqflite_darwin
import url_launcher_macos

private func RegisterMemoFlowSubWindowPlugins(registry: FlutterPluginRegistry) {
  ConnectivityPlusPlugin.register(with: registry.registrar(forPlugin: "ConnectivityPlusPlugin"))
  CryptographyFlutterPlugin.register(with: registry.registrar(forPlugin: "CryptographyFlutterPlugin"))
  DeviceInfoPlusMacosPlugin.register(with: registry.registrar(forPlugin: "DeviceInfoPlusMacosPlugin"))
  FilePickerPlugin.register(with: registry.registrar(forPlugin: "FilePickerPlugin"))
  FileSelectorPlugin.register(with: registry.registrar(forPlugin: "FileSelectorPlugin"))
  FlutterLocalNotificationsPlugin.register(with: registry.registrar(forPlugin: "FlutterLocalNotificationsPlugin"))
  FlutterSecureStoragePlugin.register(with: registry.registrar(forPlugin: "FlutterSecureStoragePlugin"))
  FlutterTimezonePlugin.register(with: registry.registrar(forPlugin: "FlutterTimezonePlugin"))
  LocalNotifierPlugin.register(with: registry.registrar(forPlugin: "LocalNotifierPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
  ScreenRetrieverMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
  SqflitePlugin.register(with: registry.registrar(forPlugin: "SqflitePlugin"))
  UrlLauncherPlugin.register(with: registry.registrar(forPlugin: "UrlLauncherPlugin"))
}

private func ConfigureMemoFlowMainWindowChrome(_ window: NSWindow) {
  // Keep native macOS traffic lights and system window semantics while allowing
  // Flutter to draw home toolbar content inside the titlebar region.
  window.styleMask.insert(.fullSizeContentView)
  window.titlebarAppearsTransparent = true
  window.titleVisibility = .hidden
  window.isMovableByWindowBackground = true
  window.minSize = NSSize(width: 960, height: 640)
}

private func ConfigureMemoFlowInitialMainWindowSize(_ window: NSWindow) {
  let templateSize = NSSize(width: 800, height: 600)
  let desiredContentSize = NSSize(width: 1360, height: 860)
  let currentSize = window.frame.size
  let stillUsingTemplateSize =
    abs(currentSize.width - templateSize.width) < 1 &&
    abs(currentSize.height - templateSize.height) < 1
  if stillUsingTemplateSize {
    var targetContentSize = desiredContentSize
    if let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
      let margin: CGFloat = 48
      targetContentSize.width = min(
        desiredContentSize.width,
        max(window.minSize.width, visibleFrame.width - margin)
      )
      targetContentSize.height = min(
        desiredContentSize.height,
        max(window.minSize.height, visibleFrame.height - margin)
      )
    }
    window.setContentSize(targetContentSize)
    window.center()
  }
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    ConfigureMemoFlowMainWindowChrome(self)
    ConfigureMemoFlowInitialMainWindowSize(self)

    RegisterGeneratedPlugins(registry: flutterViewController)
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterMemoFlowSubWindowPlugins(registry: controller)
    }
    MemoFlowMenuDispatcher.shared.configure(binaryMessenger: flutterViewController.engine.binaryMessenger)
    MemoFlowMenuBuilder(dispatcher: MemoFlowMenuDispatcher.shared).install()

    super.awakeFromNib()
  }
}
