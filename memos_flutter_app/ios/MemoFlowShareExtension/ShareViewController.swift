import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
  private let appGroupIdentifier = "group.com.memoflow.hzc073"
  private let pendingSharePayloadKey = "memoflow.pendingSharePayload"
  private let payloadQueue = DispatchQueue(label: "com.memoflow.share.payload")
  private var didStart = false
  private var collectedTexts: [String] = []
  private var collectedTitles: [String] = []
  private var collectedPaths: [String] = []

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !didStart else {
      return
    }
    didStart = true
    collectPayload()
  }

  private func collectPayload() {
    let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
    let group = DispatchGroup()

    for item in items {
      appendTitle(item.attributedTitle?.string)
      appendTitle(item.attributedContentText?.string)
      for provider in item.attachments ?? [] {
        loadPayload(from: provider, group: group)
      }
    }

    group.notify(queue: .main) { [weak self] in
      self?.persistAndOpenApp()
    }
  }

  private func loadPayload(from provider: NSItemProvider, group: DispatchGroup) {
    if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
      loadURLPayload(from: provider, typeIdentifier: UTType.url.identifier, group: group)
      return
    }
    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
      loadTextPayload(from: provider, typeIdentifier: UTType.plainText.identifier, group: group)
      return
    }
    if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
      loadFilePayload(from: provider, typeIdentifier: UTType.movie.identifier, group: group)
      return
    }
    if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
      loadFilePayload(from: provider, typeIdentifier: UTType.image.identifier, group: group)
      return
    }
    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
      loadURLPayload(from: provider, typeIdentifier: UTType.fileURL.identifier, group: group)
    }
  }

  private func loadURLPayload(
    from provider: NSItemProvider,
    typeIdentifier: String,
    group: DispatchGroup
  ) {
    group.enter()
    provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] item, _ in
      defer { group.leave() }
      guard let self else {
        return
      }
      if let url = item as? URL {
        if url.isFileURL {
          self.copySharedFile(url)
        } else {
          self.appendText(url.absoluteString)
        }
        return
      }
      if let text = item as? String {
        self.appendText(text)
        return
      }
      if let text = item as? NSString {
        self.appendText(text as String)
      }
    }
  }

  private func loadTextPayload(
    from provider: NSItemProvider,
    typeIdentifier: String,
    group: DispatchGroup
  ) {
    group.enter()
    provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] item, _ in
      defer { group.leave() }
      guard let self else {
        return
      }
      if let text = item as? String {
        self.appendText(text)
        return
      }
      if let text = item as? NSString {
        self.appendText(text as String)
        return
      }
      if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
        self.appendText(text)
      }
    }
  }

  private func loadFilePayload(
    from provider: NSItemProvider,
    typeIdentifier: String,
    group: DispatchGroup
  ) {
    group.enter()
    provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] fileURL, _ in
      defer { group.leave() }
      guard let fileURL else {
        return
      }
      self?.copySharedFile(fileURL)
    }
  }

  private func copySharedFile(_ sourceURL: URL) {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    ) else {
      return
    }
    let directory = container.appendingPathComponent("ShareIntake", isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      let filename = sanitizedFilename(sourceURL.lastPathComponent)
      let target = directory.appendingPathComponent("\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString)-\(filename)")
      if FileManager.default.fileExists(atPath: target.path) {
        try FileManager.default.removeItem(at: target)
      }
      try FileManager.default.copyItem(at: sourceURL, to: target)
      appendPath(target.path)
    } catch {
      return
    }
  }

  private func persistAndOpenApp() {
    let payload = payloadQueue.sync { () -> [String: Any]? in
      let paths = collectedPaths
      let text = collectedTexts
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
      let title = collectedTitles
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }

      if paths.isEmpty && text.isEmpty {
        return nil
      }

      var payload: [String: Any] = [
        "type": paths.isEmpty ? "text" : "images",
        "handlingMode": "standardShare",
        "paths": paths
      ]
      if !text.isEmpty {
        payload["text"] = text
      }
      if let title {
        payload["title"] = title
      }
      return payload
    }

    guard let payload else {
      complete()
      return
    }
    let defaults = UserDefaults(suiteName: appGroupIdentifier)
    defaults?.set(payload, forKey: pendingSharePayloadKey)
    defaults?.synchronize()
    openMemoFlow()
  }

  private func openMemoFlow() {
    guard let url = URL(string: "memoflow://share") else {
      complete()
      return
    }
    extensionContext?.open(url) { [weak self] _ in
      self?.complete()
    }
  }

  private func complete() {
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  private func appendText(_ raw: String?) {
    let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !text.isEmpty else {
      return
    }
    payloadQueue.sync {
      collectedTexts.append(text)
    }
  }

  private func appendTitle(_ raw: String?) {
    let title = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !title.isEmpty else {
      return
    }
    payloadQueue.sync {
      collectedTitles.append(title)
    }
  }

  private func appendPath(_ path: String) {
    let normalized = path.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else {
      return
    }
    payloadQueue.sync {
      collectedPaths.append(normalized)
    }
  }

  private func sanitizedFilename(_ raw: String) -> String {
    let fallback = "shared-file"
    let candidate = raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? fallback
      : raw
    let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
    let parts = candidate.components(separatedBy: invalid)
    let sanitized = parts.joined(separator: "_")
    return sanitized.isEmpty ? fallback : sanitized
  }
}
