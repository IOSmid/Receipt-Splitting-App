import WidgetKit
import SwiftUI
import Charts

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

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> ()) {
        let entry = placeholder(in: context)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Large Widget Pie Chart View
struct ReceiptSplitLargeWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.headline)
                .padding(.top, 12)

            // Pie Chart
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
                .frame(height: 220)
            } else {
                Text("No category data").foregroundColor(.secondary)
                    .frame(height: 220)
            }

            // 顯示各分類金額
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 8) {
                ForEach(entry.categoryBreakdown) { category in
                    HStack(spacing: 6) {
                        Circle().fill(category.color).frame(width: 10, height: 10)
                        Text(category.name)
                            .font(.caption)
                        Spacer()
                        Text("$\(category.amount, specifier: "%.2f")")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Widget Configuration
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
