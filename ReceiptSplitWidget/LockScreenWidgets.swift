import WidgetKit
import SwiftUI

// MARK: - Lock Screen Widget Entry
struct LockScreenEntry: TimelineEntry {
    let date: Date
    let totalOwed: Double
    let todaySpending: Double
    let budgetRemaining: Double
    let pendingCount: Int
}

// MARK: - Lock Screen Provider
struct LockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenEntry {
        LockScreenEntry(
            date: Date(),
            totalOwed: 456.78,
            todaySpending: 89.50,
            budgetRemaining: 765.44,
            pendingCount: 3
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
        let entry = fetchLockScreenData()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
        let currentDate = Date()
        let entry = fetchLockScreenData()
        
        // Update every 30 minutes for lock screen
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func fetchLockScreenData() -> LockScreenEntry {
        let sharedDefaults = UserDefaults(suiteName: "group.com.receiptsplit.app")
        
        let totalOwed = sharedDefaults?.double(forKey: "widget_totalOwed") ?? 0.0
        let todaySpending = sharedDefaults?.double(forKey: "widget_todaySpending") ?? 0.0
        let budgetAmount = sharedDefaults?.double(forKey: "widget_budgetAmount") ?? 1000.0
        let totalSpending = sharedDefaults?.double(forKey: "widget_totalSpending") ?? 0.0
        let pendingCount = sharedDefaults?.integer(forKey: "widget_pendingCount") ?? 0
        
        let budgetRemaining = max(0, budgetAmount - totalSpending)
        
        return LockScreenEntry(
            date: Date(),
            totalOwed: totalOwed,
            todaySpending: todaySpending,
            budgetRemaining: budgetRemaining,
            pendingCount: pendingCount
        )
    }
}

// MARK: - Circular Lock Screen Widget (Owed Amount)
struct CircularLockScreenView: View {
    let entry: LockScreenEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 2) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
                Text("$\(entry.totalOwed, specifier: "%.0f")")
                    .font(.system(size: 14, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Rectangular Lock Screen Widget (Budget Status)
struct RectangularLockScreenView: View {
    let entry: LockScreenEntry
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 16))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Today: $\(entry.todaySpending, specifier: "%.0f")")
                    .font(.system(size: 12, weight: .semibold))
                
                Text("Left: $\(entry.budgetRemaining, specifier: "%.0f")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Inline Lock Screen Widget (Simple Text)
struct InlineLockScreenView: View {
    let entry: LockScreenEntry
    
    var body: some View {
        if entry.totalOwed > 0 {
            Text("Owed: $\(entry.totalOwed, specifier: "%.0f") • \(entry.pendingCount) pending")
        } else {
            Text("Today: $\(entry.todaySpending, specifier: "%.2f")")
        }
    }
}

// MARK: - Lock Screen Widget Configuration
@available(iOS 17.0, *)
struct ReceiptSplitLockScreenWidget: Widget {
    let kind: String = "ReceiptSplitLockScreenWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Receipt Split Lock Screen")
        .description("Quick access to your expenses on the lock screen")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Lock Screen Entry View
@available(iOS 17.0, *)
struct LockScreenWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: LockScreenProvider.Entry
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularLockScreenView(entry: entry)
        case .accessoryRectangular:
            RectangularLockScreenView(entry: entry)
        case .accessoryInline:
            InlineLockScreenView(entry: entry)
        default:
            CircularLockScreenView(entry: entry)
        }
    }
}

// MARK: - Preview
@available(iOS 17.0, *)
struct LockScreenWidget_Previews: PreviewProvider {
    static var previews: some View {
        let entry = LockScreenEntry(
            date: Date(),
            totalOwed: 456.78,
            todaySpending: 89.50,
            budgetRemaining: 765.44,
            pendingCount: 3
        )
        
        Group {
            LockScreenWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Circular")
            
            LockScreenWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Rectangular")
            
            LockScreenWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
                .previewDisplayName("Inline")
        }
    }
}

