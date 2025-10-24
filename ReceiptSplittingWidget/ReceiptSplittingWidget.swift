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
    let totalSpending: Double
    let budgetAmount: Double
    let totalOwed: Double
    let pendingRequestsCount: Int
    let timeframe: String?
}

// MARK: - Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), categoryBreakdown: sampleCategories, totalSpending: 1234.56, budgetAmount: 2000.0, totalOwed: 456.78, pendingRequestsCount: 2, timeframe: "This Week")
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

        // Read total spending (fallback 0.0)
        let totalSpending = defaults?.double(forKey: "widget_totalSpending") ?? 0.0
        let budgetAmount = defaults?.double(forKey: "widget_budgetAmount") ?? 0.0
        let totalOwed = defaults?.double(forKey: "widget_totalOwed") ?? 0.0
        let pendingRequestsCount = defaults?.integer(forKey: "widget_pendingCount") ?? 0
        let timeframe = defaults?.string(forKey: "widget_timeframe")

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
                },
                totalSpending: totalSpending,
                budgetAmount: budgetAmount,
                totalOwed: totalOwed,
                pendingRequestsCount: pendingRequestsCount,
                timeframe: timeframe
            )
        }
        // 無資料時顯示範例
        return WidgetEntry(date: Date(), categoryBreakdown: sampleCategories, totalSpending: totalSpending > 0 ? totalSpending : 1234.56, budgetAmount: budgetAmount, totalOwed: totalOwed, pendingRequestsCount: pendingRequestsCount, timeframe: timeframe ?? "This Week")
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
                .padding(.bottom, 12) // 加大標題與 Chart 間距

            if !entry.categoryBreakdown.isEmpty {
                Chart(entry.categoryBreakdown) { category in
                    SectorMark(
                        angle: .value("Amount", category.amount),
                        innerRadius: .ratio(0.55)
                    )
                    .foregroundStyle(category.color)
                    .annotation(position: .overlay) {
                        if category.percentage > 5 {
                            Text("\(Int(category.percentage))%")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .lineLimit(1)
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

            // 只顯示前三個佔比最多的
            let top3 = entry.categoryBreakdown
                .sorted { $0.percentage > $1.percentage }
                .prefix(3)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(top3) { category in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(category.color)
                            .frame(width: 10, height: 10)
                        Text(category.name)
                            .font(.caption)
                            .lineLimit(1)
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
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}
// MARK: - Small Widget View (重新設計的小工具)
struct ReceiptSplittingSmallView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(spacing: 0) {
            // 頂部區域 - 主要金額
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                    Text("本週支出")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                }

                HStack {
                    Text("$\(entry.totalSpending, specifier: "%.0f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Spacer()

            // 底部區域 - 預算進度或最大類別
            if entry.budgetAmount > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("預算進度")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text("\(Int(budgetProgress * 100))%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(budgetProgressColor)
                    }

                    // 進度條
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(budgetProgressColor)
                                .frame(width: geo.size.width * CGFloat(min(budgetProgress, 1.0)), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            } else if let topCategory = entry.categoryBreakdown.first {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(topCategory.color)
                            .frame(width: 8, height: 8)
                        Text("最大支出")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }

                    HStack {
                        Text(topCategory.name)
                            .font(.caption)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                        Text("$\(topCategory.amount, specifier: "%.0f")")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .containerBackground(for: .widget) {
            dynamicGradient
        }
    }

    private var budgetProgress: Double {
        if entry.budgetAmount > 0 {
            return entry.totalSpending / entry.budgetAmount
        }
        return 0.0
    }

    private var budgetProgressColor: Color {
        if budgetProgress >= 1.0 { return Color.red.opacity(0.9) }
        if budgetProgress >= 0.8 { return Color.orange.opacity(0.9) }
        return Color.green.opacity(0.9)
    }

    private var dynamicGradient: LinearGradient {
        if let topCategory = entry.categoryBreakdown.first {
            // 使用最大類別顏色生成漸變
            let baseColor = topCategory.color
            return LinearGradient(
                colors: [
                    baseColor.opacity(0.9),
                    baseColor.opacity(0.7),
                    baseColor.opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // 預設漸變（當沒有資料時）
            return LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.4, blue: 0.8),
                    Color(red: 0.4, green: 0.2, blue: 0.6),
                    Color(red: 0.6, green: 0.3, blue: 0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Medium Widget View
struct ReceiptSplittingMediumView: View {
    let entry: WidgetEntry

    var body: some View {
        HStack(spacing: 12) {
            // Left: total spending and budget progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(entry.timeframe ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("$\(entry.totalSpending, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                // Budget progress
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(progressColor)
                                .frame(width: geo.size.width * CGFloat(spendingProgress))
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("Budget: $\(entry.budgetAmount, specifier: "%.0f")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(spendingProgress * 100))%")
                            .font(.caption2)
                            .foregroundColor(progressColor)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Right: top categories or owed
            VStack(alignment: .leading, spacing: 8) {
                if entry.totalOwed > 0 {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Owed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(entry.totalOwed, specifier: "%.2f")")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }

                    if entry.pendingRequestsCount > 0 {
                        Text("\(entry.pendingRequestsCount) pending")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Top Categories")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(entry.categoryBreakdown.prefix(3)) { cat in
                        HStack(spacing: 8) {
                            Circle().fill(cat.color).frame(width: 8, height: 8)
                            Text(cat.name).font(.caption)
                            Spacer()
                            Text("$\(cat.amount, specifier: "%.0f")")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .containerBackground(for: .widget) {
            // 改為與小尺寸小工具相同的動態漸變背景
            dynamicGradient
        }
    }

    private var spendingProgress: Double {
        if entry.budgetAmount > 0 {
            return min(entry.totalSpending / entry.budgetAmount, 1.0)
        }
        return 0.0
    }

    private var progressColor: Color {
        if spendingProgress >= 1.0 { return .red }
        if spendingProgress >= 0.8 { return .orange }
        return .green
    }

    // 與小尺寸小工具相同的背景邏輯
    private var dynamicGradient: LinearGradient {
        // 依據圓餅圖的前 2-3 大分類顏色建立漸層
        let topColors = entry.categoryBreakdown
            .sorted { $0.percentage > $1.percentage }
            .prefix(3)
            .map { $0.color }

        if topColors.count >= 2 {
            // 以多色混合製作更有層次的漸層，略帶透明讓過渡更柔和
            let blended: [Color] = [
                topColors[0].opacity(0.95),
                topColors[1].opacity(0.85),
                (topColors.count >= 3 ? topColors[2] : topColors[0]).opacity(0.75)
            ]
            return LinearGradient(
                colors: blended,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if let only = topColors.first {
            // 僅有一個分類時，使用同色系深淺過渡
            return LinearGradient(
                colors: [
                    only.opacity(0.95),
                    only.opacity(0.8),
                    only.opacity(0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // 沒有資料時的預設漸層
            return LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.4, blue: 0.8),
                    Color(red: 0.4, green: 0.2, blue: 0.6),
                    Color(red: 0.6, green: 0.3, blue: 0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Entry view to select by family
struct ReceiptSplittingWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            ReceiptSplittingSmallView(entry: entry as! WidgetEntry)
        case .systemMedium:
            ReceiptSplittingMediumView(entry: entry as! WidgetEntry)
        default:
            ReceiptSplitLargeWidgetView(entry: entry as! WidgetEntry)
        }
    }
}

// MARK: - Widget 本體 (支援 small + medium + large)
struct ReceiptSplittingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "ReceiptSplitWidget",
            provider: Provider()
        ) { entry in
            ReceiptSplittingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Spending by Category")
        .description("See your spending breakdown in a pie chart.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
