import SwiftUI
import WidgetKit

private let appGroupIdentifier = "group.com.memoflow.hzc073"

struct MemoFlowWidgetEntry: TimelineEntry {
  let date: Date
  let title: String
  let body: String
  let footer: String
  let widgetType: String
}

struct MemoFlowWidgetProvider: TimelineProvider {
  let widgetType: String

  func placeholder(in context: Context) -> MemoFlowWidgetEntry {
    entry(title: "MemoFlow", body: "Ready when you are.", footer: "", date: Date())
  }

  func getSnapshot(in context: Context, completion: @escaping (MemoFlowWidgetEntry) -> Void) {
    completion(loadEntry(date: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<MemoFlowWidgetEntry>) -> Void) {
    let entry = loadEntry(date: Date())
    completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
  }

  private func loadEntry(date: Date) -> MemoFlowWidgetEntry {
    switch widgetType {
    case "quickInput":
      return quickInputEntry(date: date)
    case "calendar":
      return calendarEntry(date: date)
    default:
      return dailyReviewEntry(date: date)
    }
  }

  private func dailyReviewEntry(date: Date) -> MemoFlowWidgetEntry {
    let payload = sharedDefaults()?.dictionary(forKey: "memoflow.widget.dailyReview") ?? [:]
    let title = string(payload["title"], fallback: "Random Review")
    let body = firstDailyReviewExcerpt(payload) ?? string(payload["fallbackBody"], fallback: "Open MemoFlow to review your notes.")
    let footer = firstDailyReviewDateLabel(payload) ?? ""
    return entry(title: title, body: body, footer: footer, date: date)
  }

  private func quickInputEntry(date: Date) -> MemoFlowWidgetEntry {
    let payload = sharedDefaults()?.dictionary(forKey: "memoflow.widget.quickInput") ?? [:]
    let hint = string(payload["hint"], fallback: "What's on your mind?")
    return entry(title: "MemoFlow", body: hint, footer: "Quick input", date: date)
  }

  private func calendarEntry(date: Date) -> MemoFlowWidgetEntry {
    let payload = sharedDefaults()?.dictionary(forKey: "memoflow.widget.calendar") ?? [:]
    let title = string(payload["monthLabel"], fallback: "Calendar")
    let days = payload["days"] as? [[String: Any]] ?? []
    let activeDays = days.filter { item in
      if let intensity = item["intensity"] as? Int {
        return intensity > 0
      }
      if let number = item["intensity"] as? NSNumber {
        return number.intValue > 0
      }
      return false
    }.count
    let body = activeDays > 0
      ? "\(activeDays) days with notes"
      : "Open MemoFlow to build your month."
    return entry(title: title, body: body, footer: "Monthly activity", date: date)
  }

  private func entry(
    title: String,
    body: String,
    footer: String,
    date: Date
  ) -> MemoFlowWidgetEntry {
    MemoFlowWidgetEntry(
      date: date,
      title: title,
      body: body,
      footer: footer,
      widgetType: widgetType
    )
  }

  private func sharedDefaults() -> UserDefaults? {
    UserDefaults(suiteName: appGroupIdentifier)
  }

  private func firstDailyReviewExcerpt(_ payload: [String: Any]) -> String? {
    guard let items = payload["items"] as? [[String: Any]] else {
      return nil
    }
    return items.compactMap { item in
      string(item["excerpt"], fallback: "").isEmpty ? nil : string(item["excerpt"], fallback: "")
    }.first
  }

  private func firstDailyReviewDateLabel(_ payload: [String: Any]) -> String? {
    guard let items = payload["items"] as? [[String: Any]] else {
      return nil
    }
    return items.compactMap { item in
      string(item["dateLabel"], fallback: "").isEmpty ? nil : string(item["dateLabel"], fallback: "")
    }.first
  }

  private func string(_ value: Any?, fallback: String) -> String {
    let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return text.isEmpty ? fallback : text
  }
}

struct MemoFlowWidgetView: View {
  let entry: MemoFlowWidgetEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(entry.title)
        .font(.headline)
        .lineLimit(2)
      Text(entry.body)
        .font(.body)
        .lineLimit(4)
        .foregroundColor(.secondary)
      Spacer(minLength: 0)
      if !entry.footer.isEmpty {
        Text(entry.footer)
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding()
    .widgetURL(URL(string: "memoflow://widget?type=\(entry.widgetType)"))
  }
}

struct MemoFlowDailyReviewWidget: Widget {
  let kind = "MemoFlowDailyReviewWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: MemoFlowWidgetProvider(widgetType: "dailyReview")) { entry in
      MemoFlowWidgetView(entry: entry)
    }
    .configurationDisplayName("MemoFlow Review")
    .description("Review recent memo highlights.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct MemoFlowQuickInputWidget: Widget {
  let kind = "MemoFlowQuickInputWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: MemoFlowWidgetProvider(widgetType: "quickInput")) { entry in
      MemoFlowWidgetView(entry: entry)
    }
    .configurationDisplayName("MemoFlow Quick Input")
    .description("Open MemoFlow for quick capture.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct MemoFlowCalendarWidget: Widget {
  let kind = "MemoFlowCalendarWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: MemoFlowWidgetProvider(widgetType: "calendar")) { entry in
      MemoFlowWidgetView(entry: entry)
    }
    .configurationDisplayName("MemoFlow Calendar")
    .description("Show monthly memo activity.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct MemoFlowWidgetBundle: WidgetBundle {
  var body: some Widget {
    MemoFlowDailyReviewWidget()
    MemoFlowQuickInputWidget()
    MemoFlowCalendarWidget()
  }
}
