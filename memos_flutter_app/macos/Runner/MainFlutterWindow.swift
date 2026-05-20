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
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    ConfigureMemoFlowMainWindowChrome(self)

    RegisterGeneratedPlugins(registry: flutterViewController)
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterMemoFlowSubWindowPlugins(registry: controller)
    }
    MemoFlowMenuDispatcher.shared.configure(binaryMessenger: flutterViewController.engine.binaryMessenger)
    MemoFlowMenuBuilder(dispatcher: MemoFlowMenuDispatcher.shared).install()

    super.awakeFromNib()
  }
}
