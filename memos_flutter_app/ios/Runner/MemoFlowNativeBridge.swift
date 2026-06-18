import Flutter
import Foundation
import UIKit
import WidgetKit

final class MemoFlowNativeBridge {
  static let appGroupIdentifier = "group.com.memoflow.hzc073"

  private static let pendingSharePayloadKey = "memoflow.pendingSharePayload"
  private static let dailyReviewWidgetKey = "memoflow.widget.dailyReview"
  private static let quickInputWidgetKey = "memoflow.widget.quickInput"
  private static let calendarWidgetKey = "memoflow.widget.calendar"

  private let widgetChannel: FlutterMethodChannel
  private let shareChannel: FlutterMethodChannel
  private var pendingWidgetLaunch: [String: Any]?
  private var pendingSharePayload: [String: Any]?

  init(messenger: FlutterBinaryMessenger) {
    widgetChannel = FlutterMethodChannel(
      name: "memoflow/widgets",
      binaryMessenger: messenger
    )
    shareChannel = FlutterMethodChannel(
      name: "memoflow/share",
      binaryMessenger: messenger
    )
    configureWidgetChannel()
    configureShareChannel()
  }

  func handleOpenURL(_ url: URL) -> Bool {
    guard url.scheme?.lowercased() == "memoflow" else {
      return false
    }
    switch url.host?.lowercased() {
    case "share":
      dispatchPendingShareFromStore()
      return true
    case "widget":
      dispatchWidgetLaunch(url)
      return true
    default:
      return true
    }
  }

  private var sharedDefaults: UserDefaults? {
    UserDefaults(suiteName: Self.appGroupIdentifier)
  }

  private func configureWidgetChannel() {
    widgetChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "UNAVAILABLE", message: "Bridge released", details: nil))
        return
      }
      switch call.method {
      case "requestPinWidget":
        result(false)
      case "getPendingWidgetLaunch":
        let payload = self.pendingWidgetLaunch
        self.pendingWidgetLaunch = nil
        result(payload)
      case "getPendingWidgetAction":
        let action = self.pendingWidgetLaunch?["widgetType"] as? String
        self.pendingWidgetLaunch = nil
        result(action)
      case "updateDailyReviewWidget":
        self.saveWidgetPayload(
          call.arguments,
          key: Self.dailyReviewWidgetKey,
          reloadKind: MemoFlowWidgetKind.dailyReview
        )
        result(true)
      case "updateQuickInputWidget":
        self.saveWidgetPayload(
          call.arguments,
          key: Self.quickInputWidgetKey,
          reloadKind: MemoFlowWidgetKind.quickInput
        )
        result(true)
      case "updateCalendarWidget":
        self.saveWidgetPayload(
          call.arguments,
          key: Self.calendarWidgetKey,
          reloadKind: MemoFlowWidgetKind.calendar
        )
        result(true)
      case "advanceDailyReviewWidget":
        self.sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "memoflow.widget.dailyReview.advanceAt")
        WidgetCenter.shared.reloadTimelines(ofKind: MemoFlowWidgetKind.dailyReview.rawValue)
        result(true)
      case "clearHomeWidgets":
        self.sharedDefaults?.removeObject(forKey: Self.dailyReviewWidgetKey)
        self.sharedDefaults?.removeObject(forKey: Self.quickInputWidgetKey)
        self.sharedDefaults?.removeObject(forKey: Self.calendarWidgetKey)
        WidgetCenter.shared.reloadAllTimelines()
        result(true)
      case "updateStatsWidget", "moveTaskToBack":
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureShareChannel() {
    shareChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "UNAVAILABLE", message: "Bridge released", details: nil))
        return
      }
      switch call.method {
      case "getPendingShare":
        let payload = self.pendingSharePayload ?? self.readPendingSharePayload()
        self.pendingSharePayload = nil
        self.clearPendingSharePayload()
        result(payload)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func saveWidgetPayload(
    _ rawArguments: Any?,
    key: String,
    reloadKind: MemoFlowWidgetKind
  ) {
    guard var payload = rawArguments as? [String: Any] else {
      sharedDefaults?.removeObject(forKey: key)
      WidgetCenter.shared.reloadTimelines(ofKind: reloadKind.rawValue)
      return
    }
    payload["updatedAt"] = Date().timeIntervalSince1970
    sharedDefaults?.set(payload, forKey: key)
    WidgetCenter.shared.reloadTimelines(ofKind: reloadKind.rawValue)
  }

  private func dispatchWidgetLaunch(_ url: URL) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return
    }
    let query = Dictionary(
      uniqueKeysWithValues: components.queryItems?.compactMap { item in
        item.value.map { (item.name, $0) }
      } ?? []
    )
    let widgetType = query["type"] ?? query["widgetType"]
    var payload: [String: Any] = [
      "widgetType": widgetType?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        ? widgetType!
        : "dailyReview"
    ]
    if let memoUid = query["memoUid"], !memoUid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      payload["memoUid"] = memoUid
    }
    if let rawDayEpochSec = query["dayEpochSec"], let dayEpochSec = Int(rawDayEpochSec) {
      payload["dayEpochSec"] = dayEpochSec
    }
    pendingWidgetLaunch = payload
    widgetChannel.invokeMethod("openWidget", arguments: payload) { [weak self] response in
      if response == nil {
        self?.pendingWidgetLaunch = nil
      }
    }
  }

  private func dispatchPendingShareFromStore() {
    guard let payload = readPendingSharePayload() else {
      return
    }
    pendingSharePayload = payload
    shareChannel.invokeMethod("openShare", arguments: payload) { [weak self] response in
      if response == nil {
        self?.pendingSharePayload = nil
        self?.clearPendingSharePayload()
      }
    }
  }

  private func readPendingSharePayload() -> [String: Any]? {
    guard let payload = sharedDefaults?.dictionary(forKey: Self.pendingSharePayloadKey) else {
      return nil
    }
    return sanitizeSharePayload(payload)
  }

  private func clearPendingSharePayload() {
    sharedDefaults?.removeObject(forKey: Self.pendingSharePayloadKey)
  }

  private func sanitizeSharePayload(_ payload: [String: Any]) -> [String: Any]? {
    let rawType = payload["type"] as? String
    let paths = (payload["paths"] as? [String])?.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
    let text = (payload["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let type: String
    if rawType == "images" || rawType == "image" || !paths.isEmpty {
      type = "images"
    } else if rawType == "text" || rawType == "url" || text?.isEmpty == false {
      type = "text"
    } else {
      return nil
    }

    var sanitized: [String: Any] = [
      "type": type,
      "handlingMode": payload["handlingMode"] as? String ?? "standardShare",
      "paths": paths
    ]
    if let text, !text.isEmpty {
      sanitized["text"] = text
    }
    if let title = (payload["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
       !title.isEmpty {
      sanitized["title"] = title
    }
    return sanitized
  }
}

enum MemoFlowWidgetKind: String {
  case dailyReview = "MemoFlowDailyReviewWidget"
  case quickInput = "MemoFlowQuickInputWidget"
  case calendar = "MemoFlowCalendarWidget"
}
