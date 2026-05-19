import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    MemoFlowMenuDispatcher.shared.configure(binaryMessenger: flutterViewController.engine.binaryMessenger)
    MemoFlowMenuBuilder(dispatcher: MemoFlowMenuDispatcher.shared).install()

    super.awakeFromNib()
  }
}
