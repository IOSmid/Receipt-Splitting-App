import WidgetKit
import SwiftUI
import Charts

// MARK: - CategoryBreakdownData (與 App 端一致)
struct CategoryBreakdownData: Codable {
    let name: String
    let amount: Double
    let colorHex: String
    let percentage: Double
}

// MARK: - Widget 顯示用的資料型別
struct CategoryData: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let color: Color
    let percentage: Double
}

// MARK: - Widget Entry
struct WidgetEntry: TimelineEntry {
    let date: Date
    let categoryBreakdown: [CategoryData]
}

// MARK: - Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), categoryBreakdown: sampleCategories)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    // 讀取 App Group UserDefaults 的資料
    private func loadEntry() -> WidgetEntry {
        let appGroupID = "group.com.receiptsplit.app"
        let defaults = UserDefaults(suiteName: appGroupID)
        if let data = defaults?.data(forKey: "widget_categoryBreakdown"),
           let decoded = try? JSONDecoder().decode([CategoryBreakdownData].self, from: data) {
            return WidgetEntry(
                date: Date(),
                categoryBreakdown: decoded.map {
                    CategoryData(
                        name: $0.name,
                        amount: $0.amount,
                        color: Color(hex: $0.colorHex),
                        percentage: $0.percentage
                    )
                }
            )
        }
        // 無資料時顯示範例
        return WidgetEntry(date: Date(), categoryBreakdown: sampleCategories)
    }
}

// MARK: - Pie Chart View
struct ReceiptSplitLargeWidgetView: View {
    let entry: WidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Spending by Category")
                .font(.headline)
                .padding(.top, 20)
                .padding(.leading, 20)
            if !entry.categoryBreakdown.isEmpty {
                Chart(entry.categoryBreakdown) { category in
                    SectorMark(
                        angle: .value("Amount", category.amount),
                        innerRadius: .ratio(0.55)
                    )
                    .foregroundStyle(category.color)
                    .annotation(position: .overlay) {
                        if category.percentage > 8 {
                            Text("\(Int(category.percentage))%")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(height: 200)
                .padding(.horizontal, 20)
            } else {
                Text("No category data")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 8) {
                ForEach(entry.categoryBreakdown) { category in
                    HStack(spacing: 6) {
                        Circle().fill(category.color).frame(width: 10, height: 10)
                        Text(category.name).font(.caption)
                        Spacer()
                        Text("$\(category.amount, specifier: "%.2f")")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            Spacer(minLength: 12)
            HStack {
                Spacer()
                Text("自動每30分鐘刷新")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)
                Spacer()
            }
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Widget 本體
struct ReceiptSplittingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "ReceiptSplitWidget",
            provider: Provider()
        ) { entry in
            ReceiptSplitLargeWidgetView(entry: entry)
        }
        .configurationDisplayName("Spending by Category")
        .description("See your spending breakdown in a pie chart.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - 支援函式
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        var int = UInt64()
        Scanner(string: hex.hasPrefix("#") ? String(hex.dropFirst()) : hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
    }
}

// MARK: - 範例資料
let sampleCategories: [CategoryData] = [
    CategoryData(name: "Groceries", amount: 450.0, color: .green, percentage: 36.5),
    CategoryData(name: "Dining", amount: 380.0, color: .orange, percentage: 30.8),
    CategoryData(name: "Transportation", amount: 250.0, color: .blue, percentage: 20.2)
]
