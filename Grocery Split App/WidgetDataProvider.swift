import Foundation
import SwiftUI
import WidgetKit
import SwiftData

// MARK: - Widget Data Provider
/// Manages data synchronization between the main app and widgets
/// Updates shared UserDefaults in App Group for widget consumption
class WidgetDataProvider {
    static let shared = WidgetDataProvider()
    
    private let appGroupID = "group.com.receiptsplit.app"
    private let sharedDefaults: UserDefaults?
    
    private init() {
        sharedDefaults = UserDefaults(suiteName: appGroupID)
    }
    
    // MARK: - Public Update Methods
    
    /// Update all widget data from the app
    func updateWidgetData(
        totalSpending: Double,
        todaySpending: Double,
        budgetAmount: Double,
        totalOwed: Double,
        pendingCount: Int,
        recentExpenses: [Expense],
        categoryBreakdown: [CategorySpending],
        timeframe: String
    ) {
        guard let defaults = sharedDefaults else { return }
        
        // Save basic stats
        defaults.set(totalSpending, forKey: "widget_totalSpending")
        defaults.set(todaySpending, forKey: "widget_todaySpending")
        defaults.set(budgetAmount, forKey: "widget_budgetAmount")
        defaults.set(totalOwed, forKey: "widget_totalOwed")
        defaults.set(pendingCount, forKey: "widget_pendingCount")
        defaults.set(timeframe, forKey: "widget_timeframe")
        
        // Save recent expenses
        let expensesData = recentExpenses.prefix(5).map { expense in
            ExpenseSummaryData(
                id: expense.id,
                name: expense.name,
                amount: expense.totalCost,
                date: expense.date,
                category: expense.category.rawValue,
                categoryIcon: expense.category.icon
            )
        }
        
        if let encoded = try? JSONEncoder().encode(expensesData) {
            defaults.set(encoded, forKey: "widget_recentExpenses")
        }
        
        // Save category breakdown
        let categoryData = categoryBreakdown.map { category in
            CategoryBreakdownData(
                name: category.category,
                amount: category.amount,
                colorHex: colorToHex(category.color),
                percentage: category.percentage
            )
        }
        
        if let encoded = try? JSONEncoder().encode(categoryData) {
            defaults.set(encoded, forKey: "widget_categoryBreakdown")
        }
        
        // Save timestamp for last update
        defaults.set(Date(), forKey: "widget_lastUpdate")
        
        // Notify widgets to reload
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Quick update for spending and budget only (lightweight)
    func updateSpendingData(totalSpending: Double, todaySpending: Double, budgetAmount: Double) {
        guard let defaults = sharedDefaults else { return }
        
        defaults.set(totalSpending, forKey: "widget_totalSpending")
        defaults.set(todaySpending, forKey: "widget_todaySpending")
        defaults.set(budgetAmount, forKey: "widget_budgetAmount")
        defaults.set(Date(), forKey: "widget_lastUpdate")
        
        WidgetCenter.shared.reloadTimelines(ofKind: "ReceiptSplitWidget")
    }
    
    /// Quick update for owed amount only
    func updateOwedData(totalOwed: Double, pendingCount: Int) {
        guard let defaults = sharedDefaults else { return }
        
        defaults.set(totalOwed, forKey: "widget_totalOwed")
        defaults.set(pendingCount, forKey: "widget_pendingCount")
        defaults.set(Date(), forKey: "widget_lastUpdate")
        
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Force refresh all widget timelines
    func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Helper Methods
    
    /// Get last widget update time
    func getLastUpdateTime() -> Date? {
        return sharedDefaults?.object(forKey: "widget_lastUpdate") as? Date
    }
    
    /// Clear all widget data
    func clearWidgetData() {
        guard let defaults = sharedDefaults else { return }
        
        let keys = [
            "widget_totalSpending",
            "widget_todaySpending",
            "widget_budgetAmount",
            "widget_totalOwed",
            "widget_pendingCount",
            "widget_timeframe",
            "widget_recentExpenses",
            "widget_categoryBreakdown",
            "widget_lastUpdate"
        ]
        
        keys.forEach { defaults.removeObject(forKey: $0) }
        
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Data Models (matching Widget models)

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

// MARK: - Color Helper for Hex Conversion
func colorToHex(_ color: Color) -> String {
    guard let components = UIColor(color).cgColor.components else {
        return "000000"
    }
    
    let r = components[0]
    let g = components.count > 1 ? components[1] : components[0]
    let b = components.count > 2 ? components[2] : components[0]
    
    return String(format: "%02lX%02lX%02lX",
                 lroundf(Float(r * 255)),
                 lroundf(Float(g * 255)),
                 lroundf(Float(b * 255)))
}

// MARK: - View Model Extension
/// Extension to DashboardViewModel to support widget updates
extension DashboardViewModel {
    /// Update widget with current dashboard data
    func updateWidgetData() {
        // Calculate today's spending
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let todayExpenses = recentExpenses.filter {
            calendar.isDate($0.date, inSameDayAs: Date())
        }
        let todaySpending = todayExpenses.reduce(0) { $0 + $1.totalCost }
        
        // Calculate total owed
        let totalOwed = categoryBreakdown.reduce(0) { $0 + $1.owedAmount }
        
        // Get pending count from split summary
        let pendingCount = splitSummary.first(where: { $0.label.contains("owe") })?.amount ?? 0
        let pendingCountInt = Int(pendingCount > 0 ? max(1, pendingCount / 50) : 0) // Rough estimate
        
        // Update widget with all data
        WidgetDataProvider.shared.updateWidgetData(
            totalSpending: totalSpending,
            todaySpending: todaySpending,
            budgetAmount: budgetAmount,
            totalOwed: totalOwed,
            pendingCount: pendingCountInt,
            recentExpenses: Array(recentExpenses.prefix(5)),
            categoryBreakdown: categoryBreakdown,
            timeframe: selectedTimeFrame.rawValue
        )
    }
}
