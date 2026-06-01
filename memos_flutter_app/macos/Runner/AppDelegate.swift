import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let menuDispatcher = MemoFlowMenuDispatcher.shared

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    MemoFlowMenuBuilder(dispatcher: menuDispatcher).install()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      for window in NSApp.windows {
        if !window.isVisible {
          window.setIsVisible(true)
        }
        window.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
      }
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  @IBAction func dispatchMemoFlowMenuCommand(_ sender: NSMenuItem) {
    guard let command = sender.representedObject as? String else {
      return
    }
    menuDispatcher.dispatch(command)
  }
}

final class MemoFlowMenuDispatcher {
  static let shared = MemoFlowMenuDispatcher()

  private var channel: FlutterMethodChannel?

  private init() {}

  func configure(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "memoflow/macos_menu",
      binaryMessenger: binaryMessenger
    )
  }

  func dispatch(_ command: String) {
    channel?.invokeMethod("dispatch", arguments: command)
  }
}

final class MemoFlowMenuBuilder {
  private let dispatcher: MemoFlowMenuDispatcher

  init(dispatcher: MemoFlowMenuDispatcher) {
    self.dispatcher = dispatcher
  }

  func install() {
    NSApp.mainMenu = buildMainMenu()
  }

  private func buildMainMenu() -> NSMenu {
    let mainMenu = NSMenu(title: localized("main.menu", "Main Menu"))
    mainMenu.addItem(appMenuItem())
    mainMenu.addItem(menuItem(
      title: localized("menu.memo", "Memo"),
      submenu: memoMenu()
    ))
    mainMenu.addItem(menuItem(
      title: localized("menu.sync", "Sync"),
      submenu: syncMenu()
    ))
    mainMenu.addItem(menuItem(
      title: localized("menu.ai", "AI"),
      submenu: aiMenu()
    ))
    mainMenu.addItem(menuItem(
      title: localized("menu.tools", "Tools"),
      submenu: toolsMenu()
    ))
    mainMenu.addItem(menuItem(
      title: localized("menu.window", "Window"),
      submenu: windowMenu()
    ))
    mainMenu.addItem(menuItem(
      title: localized("menu.help", "Help"),
      submenu: helpMenu()
    ))
    return mainMenu
  }

  private func appMenuItem() -> NSMenuItem {
    let menu = NSMenu(title: "APP_NAME")
    menu.addItem(systemItem(
      title: localized("app.about", "About APP_NAME"),
      action: #selector(NSApplication.orderFrontStandardAboutPanel(_:))
    ))
    menu.addItem(.separator())
    menu.addItem(commandItem(
      title: localized("app.settings", "Settings..."),
      command: "openSettingsWindow",
      keyEquivalent: ","
    ))
    menu.addItem(.separator())

    let servicesItem = NSMenuItem(title: localized("app.services", "Services"), action: nil, keyEquivalent: "")
    let servicesMenu = NSMenu(title: localized("app.services", "Services"))
    servicesItem.submenu = servicesMenu
    NSApp.servicesMenu = servicesMenu
    menu.addItem(servicesItem)
    menu.addItem(.separator())

    menu.addItem(systemItem(
      title: localized("app.hide", "Hide APP_NAME"),
      action: #selector(NSApplication.hide(_:)),
      keyEquivalent: "h"
    ))
    let hideOthers = systemItem(
      title: localized("app.hideOthers", "Hide Others"),
      action: #selector(NSApplication.hideOtherApplications(_:)),
      keyEquivalent: "h"
    )
    hideOthers.keyEquivalentModifierMask = [.command, .option]
    menu.addItem(hideOthers)
    menu.addItem(systemItem(
      title: localized("app.showAll", "Show All"),
      action: #selector(NSApplication.unhideAllApplications(_:))
    ))
    menu.addItem(.separator())
    menu.addItem(systemItem(
      title: localized("app.quit", "Quit APP_NAME"),
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    ))

    let item = menuItem(title: "APP_NAME", submenu: menu)
    return item
  }

  private func memoMenu() -> NSMenu {
    let menu = NSMenu(title: localized("menu.memo", "Memo"))
    menu.addItem(commandItem(title: localized("memo.new", "New Memo"), command: "newMemo", keyEquivalent: "n"))
    menu.addItem(commandItem(title: localized("memo.quickInput", "Quick Input"), command: "quickInput", keyEquivalent: "n", modifiers: [.command, .shift]))
    menu.addItem(commandItem(title: localized("memo.search", "Search Memos"), command: "searchMemos", keyEquivalent: "f"))
    menu.addItem(.separator())
    menu.addItem(commandItem(title: localized("memo.draftBox", "Draft Box"), command: "draftBox"))
    menu.addItem(commandItem(title: localized("memo.tags", "Tags"), command: "tags"))
    menu.addItem(commandItem(title: localized("memo.recycleBin", "Recycle Bin"), command: "recycleBin"))
    return menu
  }

  private func syncMenu() -> NSMenu {
    let menu = NSMenu(title: localized("menu.sync", "Sync"))
    menu.addItem(commandItem(title: localized("sync.now", "Sync Now"), command: "syncNow", keyEquivalent: "s", modifiers: [.command, .shift]))
    menu.addItem(commandItem(title: localized("sync.queue", "Sync Queue"), command: "syncQueue"))
    menu.addItem(commandItem(title: localized("sync.webdavBackup", "WebDAV Backup"), command: "webDavBackup"))
    menu.addItem(.separator())
    menu.addItem(menuItem(title: localized("sync.import", "Import"), submenu: importMenu()))
    menu.addItem(menuItem(title: localized("sync.export", "Export"), submenu: exportMenu()))
    menu.addItem(.separator())
    menu.addItem(commandItem(title: localized("sync.migration", "MemoFlow Migration"), command: "migration"))
    return menu
  }

  private func importMenu() -> NSMenu {
    let menu = NSMenu(title: localized("sync.import", "Import"))
    menu.addItem(commandItem(title: localized("import.file", "Import File"), command: "importFile"))
    menu.addItem(commandItem(title: localized("import.markdown", "Import from Markdown"), command: "importMarkdown"))
    menu.addItem(commandItem(title: localized("import.flomo", "Import from Flomo"), command: "importFlomo"))
    menu.addItem(commandItem(title: localized("import.swashbucklerDiary", "Import from Swashbuckler Diary"), command: "importSwashbucklerDiary"))
    return menu
  }

  private func exportMenu() -> NSMenu {
    let menu = NSMenu(title: localized("sync.export", "Export"))
    menu.addItem(commandItem(title: localized("export.memos", "Export Memos"), command: "exportMemos"))
    return menu
  }

  private func aiMenu() -> NSMenu {
    let menu = NSMenu(title: localized("menu.ai", "AI"))
    menu.addItem(commandItem(title: localized("ai.summary", "AI Summary"), command: "aiSummary"))
    menu.addItem(commandItem(title: localized("ai.reports", "AI Reports"), command: "aiReports"))
    menu.addItem(commandItem(title: localized("ai.quickPrompts", "Quick Prompts"), command: "quickPrompts"))
    menu.addItem(.separator())
    menu.addItem(commandItem(title: localized("ai.settings", "AI Settings"), command: "aiSettings"))
    menu.addItem(commandItem(title: localized("ai.provider", "AI Provider"), command: "aiProvider"))
    return menu
  }

  private func toolsMenu() -> NSMenu {
    let menu = NSMenu(title: localized("menu.tools", "Tools"))
    menu.addItem(commandItem(title: localized("tools.shortcutSettings", "Shortcut Settings"), command: "shortcutSettings"))
    menu.addItem(commandItem(title: localized("tools.desktopShortcutsOverview", "Desktop Shortcuts Overview"), command: "desktopShortcutsOverview"))
    menu.addItem(.separator())
    menu.addItem(commandItem(title: localized("tools.templateSettings", "Template Settings"), command: "templateSettings"))
    menu.addItem(commandItem(title: localized("tools.memoToolbarSettings", "Memo Toolbar Settings"), command: "memoToolbarSettings"))
    menu.addItem(commandItem(title: localized("tools.locationSettings", "Location Settings"), command: "locationSettings"))
    menu.addItem(commandItem(title: localized("tools.imageBedSettings", "Image Bed Settings"), command: "imageBedSettings"))
    menu.addItem(commandItem(title: localized("tools.imageCompression", "Image Compression"), command: "imageCompression"))
    menu.addItem(.separator())
    menu.addItem(commandItem(title: localized("tools.selfRepair", "Self Repair"), command: "selfRepair"))
    menu.addItem(commandItem(title: localized("tools.exportDiagnostics", "Export Diagnostics"), command: "exportDiagnostics"))
    return menu
  }

  private func windowMenu() -> NSMenu {
    let menu = NSMenu(title: localized("menu.window", "Window"))
    let closeItem = systemItem(
      title: localized("window.close", "Close"),
      action: #selector(NSWindow.performClose(_:)),
      keyEquivalent: "w"
    )
    closeItem.keyEquivalentModifierMask = [.command]
    menu.addItem(closeItem)
    menu.addItem(systemItem(
      title: localized("window.minimize", "Minimize"),
      action: #selector(NSWindow.performMiniaturize(_:)),
      keyEquivalent: "m"
    ))
    menu.addItem(systemItem(
      title: localized("window.zoom", "Zoom"),
      action: #selector(NSWindow.performZoom(_:))
    ))
    menu.addItem(.separator())
    let fullScreenItem = systemItem(
      title: localized("window.fullScreen", "Enter Full Screen"),
      action: #selector(NSWindow.toggleFullScreen(_:)),
      keyEquivalent: "f"
    )
    fullScreenItem.keyEquivalentModifierMask = [.command, .control]
    menu.addItem(fullScreenItem)
    menu.addItem(.separator())
    menu.addItem(systemItem(
      title: localized("window.bringAllToFront", "Bring All to Front"),
      action: #selector(NSApplication.arrangeInFront(_:))
    ))
    menu.addItem(.separator())
    menu.addItem(commandItem(title: localized("window.openSettings", "Open Settings Window"), command: "openSettingsWindow"))
    menu.addItem(commandItem(title: localized("window.focusQuickInput", "Focus Quick Input"), command: "focusQuickInput"))
    NSApp.windowsMenu = menu
    return menu
  }

  private func helpMenu() -> NSMenu {
    let menu = NSMenu(title: localized("menu.help", "Help"))
    menu.addItem(commandItem(title: localized("help.center", "Help Center"), command: "helpCenter"))
    menu.addItem(commandItem(title: localized("help.backendDocs", "Memos Backend Docs"), command: "memosBackendDocs"))
    menu.addItem(.separator())
    menu.addItem(commandItem(title: localized("help.releaseNotes", "Release Notes"), command: "releaseNotes"))
    menu.addItem(commandItem(title: localized("help.feedback", "Feedback"), command: "feedback"))
    NSApp.helpMenu = menu
    return menu
  }

  private func menuItem(title: String, submenu: NSMenu) -> NSMenuItem {
    let item = NSMenuItem(title: replaceAppName(title), action: nil, keyEquivalent: "")
    submenu.title = replaceAppName(submenu.title)
    item.submenu = submenu
    return item
  }

  private func commandItem(
    title: String,
    command: String,
    keyEquivalent: String = "",
    modifiers: NSEvent.ModifierFlags = [.command]
  ) -> NSMenuItem {
    let item = NSMenuItem(
      title: replaceAppName(title),
      action: #selector(AppDelegate.dispatchMemoFlowMenuCommand(_:)),
      keyEquivalent: keyEquivalent
    )
    item.target = NSApp.delegate
    item.representedObject = command
    item.keyEquivalentModifierMask = modifiers
    return item
  }

  private func systemItem(
    title: String,
    action: Selector,
    keyEquivalent: String = ""
  ) -> NSMenuItem {
    let item = NSMenuItem(
      title: replaceAppName(title),
      action: action,
      keyEquivalent: keyEquivalent
    )
    item.target = nil
    return item
  }

  private func localized(_ key: String, _ fallback: String) -> String {
    return NSLocalizedString(key, tableName: "MainMenu", bundle: .main, value: fallback, comment: "")
  }

  private func replaceAppName(_ value: String) -> String {
    return value.replacingOccurrences(of: "APP_NAME", with: "MemoFlow")
  }
}
