import WidgetKit
import SwiftUI

// MARK: - Widget Entry
struct WidgetEntry: TimelineEntry {
    let date: Date
    let totalSpending: Double
    let budgetAmount: Double
    let spendingProgress: Double
    let totalOwed: Double
    let pendingRequestsCount: Int
    let recentExpenses: [ExpenseSummary]
    let categoryBreakdown: [CategoryData]
    let timeframe: String
}

// MARK: - Expense Summary
struct ExpenseSummary: Identifiable {
    let id: UUID
    let name: String
    let amount: Double
    let date: Date
    let category: String
    let categoryIcon: String
}

// MARK: - Category Data
struct CategoryData: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let color: Color
    let percentage: Double
}

// MARK: - Widget Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(
            date: Date(),
            totalSpending: 1234.56,
            budgetAmount: 2000.0,
            spendingProgress: 0.62,
            totalOwed: 456.78,
            pendingRequestsCount: 3,
            recentExpenses: [
                ExpenseSummary(id: UUID(), name: "Grocery Store", amount: 89.45, date: Date(), category: "Groceries", categoryIcon: "cart"),
                ExpenseSummary(id: UUID(), name: "Restaurant", amount: 45.20, date: Date(), category: "Dining", categoryIcon: "fork.knife"),
                ExpenseSummary(id: UUID(), name: "Gas Station", amount: 55.00, date: Date(), category: "Transportation", categoryIcon: "car")
            ],
            categoryBreakdown: [
                CategoryData(name: "Groceries", amount: 450.0, color: .green, percentage: 36.5),
                CategoryData(name: "Dining", amount: 380.0, color: .orange, percentage: 30.8),
                CategoryData(name: "Transportation", amount: 250.0, color: .blue, percentage: 20.2)
            ],
            timeframe: "This Week"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry = fetchCurrentData()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let currentDate = Date()
        let entry = fetchCurrentData()
        
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    // MARK: - Data Fetching
    private func fetchCurrentData() -> WidgetEntry {
        let sharedDefaults = UserDefaults(suiteName: "group.com.receiptsplit.app")
        
        // Fetch cached data from shared UserDefaults
        let totalSpending = sharedDefaults?.double(forKey: "widget_totalSpending") ?? 0.0
        let budgetAmount = sharedDefaults?.double(forKey: "widget_budgetAmount") ?? 1000.0
        let totalOwed = sharedDefaults?.double(forKey: "widget_totalOwed") ?? 0.0
        let pendingCount = sharedDefaults?.integer(forKey: "widget_pendingCount") ?? 0
        let timeframe = sharedDefaults?.string(forKey: "widget_timeframe") ?? "This Week"
        
        let spendingProgress = budgetAmount > 0 ? min(totalSpending / budgetAmount, 1.0) : 0.0
        
        // Fetch recent expenses
        let recentExpenses = fetchRecentExpenses(from: sharedDefaults)
        
        // Fetch category breakdown
        let categoryBreakdown = fetchCategoryBreakdown(from: sharedDefaults)
        
        return WidgetEntry(
            date: Date(),
            totalSpending: totalSpending,
            budgetAmount: budgetAmount,
            spendingProgress: spendingProgress,
            totalOwed: totalOwed,
            pendingRequestsCount: pendingCount,
            recentExpenses: recentExpenses,
            categoryBreakdown: categoryBreakdown,
            timeframe: timeframe
        )
    }
    
    private func fetchRecentExpenses(from defaults: UserDefaults?) -> [ExpenseSummary] {
        guard let defaults = defaults,
              let data = defaults.data(forKey: "widget_recentExpenses"),
              let decoded = try? JSONDecoder().decode([ExpenseSummaryData].self, from: data) else {
            return []
        }
        
        return decoded.map { data in
            ExpenseSummary(
                id: data.id,
                name: data.name,
                amount: data.amount,
                date: data.date,
                category: data.category,
                categoryIcon: data.categoryIcon
            )
        }
    }
    
    private func fetchCategoryBreakdown(from defaults: UserDefaults?) -> [CategoryData] {
        guard let defaults = defaults,
              let data = defaults.data(forKey: "widget_categoryBreakdown"),
              let decoded = try? JSONDecoder().decode([CategoryBreakdownData].self, from: data) else {
            return []
        }
        
        return decoded.map { data in
            CategoryData(
                name: data.name,
                amount: data.amount,
                color: colorFromHex(data.colorHex),
                percentage: data.percentage
            )
        }
    }
    
    private func colorFromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return .blue
        }
        
        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Codable Data Models
struct ExpenseSummaryData: Codable {
    let id: UUID
    let name: String
    let amount: Double
    let date: Date
    let category: String
    let categoryIcon: String
}

struct CategoryBreakdownData: Codable {
    let name: String
    let amount: Double
    let colorHex: String
    let percentage: Double
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    let entry: WidgetEntry
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                        .foregroundColor(.blue)
                    Spacer()
                    Text(entry.timeframe)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spending")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(entry.totalSpending, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                
                // Budget Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor)
                            .frame(width: geometry.size.width * entry.spendingProgress)
                    }
                }
                .frame(height: 6)
                
                Text("$\(entry.budgetAmount, specifier: "%.0f") budget")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
    
    private var progressColor: Color {
        if entry.spendingProgress >= 1.0 {
            return .red
        } else if entry.spendingProgress >= 0.8 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    let entry: WidgetEntry
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            HStack(spacing: 16) {
                // Left Side - Spending Overview
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                        Text(entry.timeframe)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Spending")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("$\(entry.totalSpending, specifier: "%.2f")")
                            .font(.title)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Budget Progress
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Budget")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(entry.spendingProgress * 100))%")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(progressColor)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(progressColor)
                                    .frame(width: geometry.size.width * entry.spendingProgress)
                            }
                        }
                        .frame(height: 8)
                    }
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // Right Side - Top Categories or Owed
                VStack(alignment: .leading, spacing: 8) {
                    if entry.totalOwed > 0 {
                        owedSection
                    } else {
                        categoriesSection
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }
    
    private var owedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.body)
                    .foregroundColor(.green)
                Text("Owed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("$\(entry.totalOwed, specifier: "%.2f")")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.green)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            
            if entry.pendingRequestsCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(entry.pendingRequestsCount) pending")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Categories")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(entry.categoryBreakdown.prefix(3)) { category in
                HStack(spacing: 8) {
                    Circle()
                        .fill(category.color)
                        .frame(width: 8, height: 8)
                    
                    Text(category.name)
                        .font(.caption)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("$\(category.amount, specifier: "%.0f")")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
        }
    }
    
    private var progressColor: Color {
        if entry.spendingProgress >= 1.0 {
            return .red
        } else if entry.spendingProgress >= 0.8 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Large Widget View
struct LargeWidgetView: View {
    let entry: WidgetEntry
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.06), Color.purple.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 16) {
                // Header Row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Receipt Split")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text(entry.timeframe)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                // Stats Row
                HStack(spacing: 12) {
                    // Spending Card
                    StatCard(
                        icon: "dollarsign.circle.fill",
                        iconColor: .blue,
                        label: "Spending",
                        value: "$\(entry.totalSpending, specifier: "%.2f")",
                        subtitle: "of $\(entry.budgetAmount, specifier: "%.0f")"
                    )
                    
                    // Owed Card
                    StatCard(
                        icon: "arrow.down.circle.fill",
                        iconColor: .green,
                        label: "Owed",
                        value: "$\(entry.totalOwed, specifier: "%.2f")",
                        subtitle: "\(entry.pendingRequestsCount) pending"
                    )
                }
                
                // Budget Progress
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Budget Progress")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(entry.spendingProgress * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(progressColor)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(progressColor)
                                .frame(width: geometry.size.width * entry.spendingProgress)
                        }
                    }
                    .frame(height: 10)
                }
                
                Divider()
                
                // Recent Expenses
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Expenses")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    if entry.recentExpenses.isEmpty {
                        Text("No expenses yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(entry.recentExpenses.prefix(4)) { expense in
                            HStack(spacing: 8) {
                                Image(systemName: expense.categoryIcon)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                
                                Text(expense.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text("$\(expense.amount, specifier: "%.2f")")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var progressColor: Color {
        if entry.spendingProgress >= 1.0 {
            return .red
        } else if entry.spendingProgress >= 0.8 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground).opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - Widget Configuration
struct ReceiptSplitWidget: Widget {
    let kind: String = "ReceiptSplitWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ReceiptSplitWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Receipt Split")
        .description("Track your expenses and splits at a glance")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Entry View
struct ReceiptSplitWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Color Helper
func colorToHex(_ color: Color) -> String {
    let components = UIColor(color).cgColor.components
    let r = components?[0] ?? 0.0
    let g = components?[1] ?? 0.0
    let b = components?[2] ?? 0.0
    
    return String(format: "%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
}

// MARK: - Preview
struct ReceiptSplitWidget_Previews: PreviewProvider {
    static var previews: some View {
        let entry = WidgetEntry(
            date: Date(),
            totalSpending: 1234.56,
            budgetAmount: 2000.0,
            spendingProgress: 0.62,
            totalOwed: 456.78,
            pendingRequestsCount: 3,
            recentExpenses: [
                ExpenseSummary(id: UUID(), name: "Grocery Store", amount: 89.45, date: Date(), category: "Groceries", categoryIcon: "cart"),
                ExpenseSummary(id: UUID(), name: "Restaurant", amount: 45.20, date: Date(), category: "Dining", categoryIcon: "fork.knife"),
                ExpenseSummary(id: UUID(), name: "Gas Station", amount: 55.00, date: Date(), category: "Transportation", categoryIcon: "car")
            ],
            categoryBreakdown: [
                CategoryData(name: "Groceries", amount: 450.0, color: .green, percentage: 36.5),
                CategoryData(name: "Dining", amount: 380.0, color: .orange, percentage: 30.8),
                CategoryData(name: "Transportation", amount: 250.0, color: .blue, percentage: 20.2)
            ],
            timeframe: "This Week"
        )
        
        Group {
            ReceiptSplitWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small")
            
            ReceiptSplitWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")
            
            ReceiptSplitWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large")
        }
    }
}

