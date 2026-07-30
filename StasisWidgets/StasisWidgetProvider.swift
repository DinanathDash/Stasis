import SwiftUI
import WidgetKit

struct StasisWidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetStatusData
}

struct StasisWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StasisWidgetEntry {
        StasisWidgetEntry(date: Date(), data: .default)
    }

    func getSnapshot(in context: Context, completion: @escaping (StasisWidgetEntry) -> Void) {
        let entry = StasisWidgetEntry(date: Date(), data: WidgetStatusData.load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StasisWidgetEntry>) -> Void) {
        let currentData = WidgetStatusData.load()
        let entry = StasisWidgetEntry(date: Date(), data: currentData)

        // Request background reload every 15 minutes as fallback;
        // WidgetDataManager calls WidgetCenter.shared.reloadAllTimelines() immediately on meaningful state changes.
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
