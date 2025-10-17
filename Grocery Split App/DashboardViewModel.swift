import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Time Frame for Dashboard
enum TimeFrame: String, CaseIterable {
    case day = "Today"
    case week = "This Week"
    case month = "This Month"
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .day:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
            
        case .week:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!
            return (start, end)
            
        case .month:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
        }
    }
}

// MARK: - Category Spending Model
struct CategorySpending: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
    let owedAmount: Double // Outstanding amount others owe you for this category
    let color: Color
    
    var percentage: Double = 0.0
}

// MARK: - Split Summary Model for Enhanced Pie Chart
struct SplitSummary: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
    let color: Color
    var percentage: Double = 0.0
}

// MARK: - Dashboard View Model
@MainActor
class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedTimeFrame: TimeFrame = .week {
        didSet {
            if selectedTimeFrame != oldValue {
                fetchExpenses()
            }
        }
    }
    @Published var totalSpending: Double = 0.0
    @Published var categoryBreakdown: [CategorySpending] = []
    @Published var splitSummary: [SplitSummary] = [] // For enhanced pie chart showing "People owe me" vs "You spent"
    @Published var budgetAmount: Double = 1000.0 // Default budget
    @Published var spendingProgress: Double = 0.0
    @Published var selectedDate: Date? = nil
    @Published var expensesForSelectedDate: [Expense] = []
    @Published var recentExpenses: [Expense] = []
    @Published var datesWithExpenses: Set<DateComponents> = []
    
    // MARK: - Private Properties
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        loadBudgetFromUserDefaults()
        setupTimeFrameObserver()
        setupChangeObservers()
    }
    
    private func setupTimeFrameObserver() {
        // Additional observer for selectedTimeFrame changes using Combine
        $selectedTimeFrame
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                self?.fetchExpenses()
            }
            .store(in: &cancellables)
    }
    
    private func setupChangeObservers() {
        NotificationCenter.default.publisher(for: .expenseDataChanged)
            .sink { [weak self] _ in self?.fetchExpenses() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .splitRequestsChanged)
            .sink { [weak self] _ in self?.fetchExpenses() }
            .store(in: &cancellables)
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchExpenses()
    }
    
    // MARK: - Data Fetching
    func fetchExpenses() {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<Expense>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let allExpenses = try modelContext.fetch(descriptor)
            processExpenses(allExpenses)
        } catch {
            print("Failed to fetch expenses: \(error)")
        }
    }
    
    private func processExpenses(_ expenses: [Expense]) {
        // Filter by selected time frame
        let dateRange = selectedTimeFrame.dateRange
        let filteredExpenses = expenses.filter { expense in
            expense.date >= dateRange.start && expense.date < dateRange.end
        }
        
        // Calculate total spending
        totalSpending = filteredExpenses.reduce(0) { $0 + $1.totalCost }
        
        // Calculate category breakdown including user's net spend vs owed
        calculateCategoryBreakdown(from: filteredExpenses)
        
        // Calculate split summary for enhanced pie chart
        calculateSplitSummary(from: filteredExpenses)
        
        // Update spending progress
        updateSpendingProgress()
        
        // Show all expenses (for full scrolling list in Timeline)
        recentExpenses = expenses
        
        // Mark dates with expenses for calendar
        markDatesWithExpenses(from: expenses)
        
        // Update widget data
        updateWidgetData()
    }
    
    // MARK: - Category Breakdown
    private func calculateCategoryBreakdown(from expenses: [Expense]) {
        var categoryUserTotals: [ExpenseCategory: Double] = [:]
        var categoryOwed: [ExpenseCategory: Double] = [:]

        for expense in expenses {
            // User's own portion for this expense (independent of settlement)
            let myShare = userShare(for: expense)
            categoryUserTotals[expense.category, default: 0] += myShare

            // Outstanding (others still owe me) for this expense
            let outstanding = outstandingOwedToUser(for: expense)
            categoryOwed[expense.category, default: 0] += outstanding
        }

        let total = categoryUserTotals.values.reduce(0, +)

        categoryBreakdown = categoryUserTotals.map { category, amount in
            var spending = CategorySpending(
                category: category.rawValue,
                amount: amount,
                owedAmount: categoryOwed[category, default: 0],
                color: colorForCategory(category)
            )
            spending.percentage = total > 0 ? (amount / total) * 100 : 0
            return spending
        }.sorted { $0.amount > $1.amount }
    }
    
    private func colorForCategory(_ category: ExpenseCategory) -> Color {
        switch category {
        case .groceries: return .green
        case .dining: return .orange
        case .entertainment: return .purple
        case .transport: return .blue
        case .utilities: return .gray
        case .shopping: return .pink
        case .travel: return .cyan
        case .healthcare: return .red
        case .other: return .indigo
        }
    }
    
    // MARK: - Split Summary Calculation
    private func calculateSplitSummary(from expenses: [Expense]) {
        var totalUserShare: Double = 0.0
        var totalOwedToUser: Double = 0.0

        for expense in expenses {
            totalUserShare += userShare(for: expense)
            totalOwedToUser += outstandingOwedToUser(for: expense)
        }

        let total = totalUserShare + totalOwedToUser

        if total > 0 {
            var userSpentItem = SplitSummary(
                label: "You spent",
                amount: totalUserShare,
                color: .blue
            )
            userSpentItem.percentage = (totalUserShare / total) * 100

            var peopleOweItem = SplitSummary(
                label: totalOwedToUser > 0 ? "People owe me" : "All settled 🎉",
                amount: totalOwedToUser,
                color: .green
            )
            peopleOweItem.percentage = total > 0 ? (totalOwedToUser / total) * 100 : 0

            splitSummary = [userSpentItem, peopleOweItem].filter { $0.amount > 0 || $0.label.contains("settled") }
        } else {
            splitSummary = []
        }
    }

    // MARK: - Helpers for shares/owed
    private func normalizedName(_ name: String) -> String {
        return name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func currentUserNameKey() -> String {
        let raw = UserDefaults.standard.string(forKey: "userName").flatMap { $0.isEmpty ? nil : $0 } ?? "Me"
        return normalizedName(raw)
    }

    private func userShare(for expense: Expense) -> Double {
        let me = currentUserNameKey()
        if let mine = expense.splitParticipants.first(where: { normalizedName($0.name) == me }) {
            return max(0, mine.amount)
        }
        // Derive from others' shares if my participant row is missing
        let others = expense.splitParticipants
            .filter { normalizedName($0.name) != me }
            .reduce(0.0) { $0 + max(0, $1.amount) }
        return max(0, expense.totalCost - others)
    }

    private func outstandingOwedToUser(for expense: Expense) -> Double {
        let me = currentUserNameKey()
        let raw = expense.splitRequests
            .filter { req in
                guard req.status != .paid else { return false }
                return normalizedName(req.participantName) != me
            }
            .reduce(0.0) { $0 + max(0, $1.amount) }
        return min(max(raw, 0), expense.totalCost)
    }
    
    // MARK: - Budget Management
    func updateBudget(_ newBudget: Double) {
        budgetAmount = newBudget
        saveBudgetToUserDefaults()
        updateSpendingProgress()
    }
    
    private func updateSpendingProgress() {
        // Always compute month-to-date progress for the bar, regardless of selected timeframe
        if let modelContext = modelContext {
            let now = Date()
            let startOfMonth = Calendar.current.dateInterval(of: .month, for: now)!.start
            let descriptor = FetchDescriptor<Expense>(
                predicate: #Predicate<Expense> { e in e.date >= startOfMonth && e.date <= now },
                sortBy: []
            )
            if let expensesThisMonth = try? modelContext.fetch(descriptor) {
                let spendingMTD = expensesThisMonth.reduce(0) { $0 + $1.totalCost }
                spendingProgress = budgetAmount > 0 ? min(spendingMTD / budgetAmount, 1.0) : 0.0
            } else {
                spendingProgress = 0
            }
        } else {
            spendingProgress = budgetAmount > 0 ? min(totalSpending / budgetAmount, 1.0) : 0.0
        }
        
        // Check if over budget and trigger notification placeholder
        if spendingProgress >= 1.0 {
            triggerOverBudgetNotification()
        }
    }
    
    private func saveBudgetToUserDefaults() {
        UserDefaults.standard.set(budgetAmount, forKey: "monthlyBudget")
    }
    
    private func loadBudgetFromUserDefaults() {
        let saved = UserDefaults.standard.double(forKey: "monthlyBudget")
        if saved > 0 {
            budgetAmount = saved
        }
    }
    
    // MARK: - Calendar Support
    private func markDatesWithExpenses(from expenses: [Expense]) {
        let calendar = Calendar.current
        datesWithExpenses = Set(expenses.map { expense in
            calendar.dateComponents([.year, .month, .day], from: expense.date)
        })
    }
    
    func loadExpensesForDate(_ date: Date) {
        guard let modelContext = modelContext else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate<Expense> { expense in
                expense.date >= startOfDay && expense.date < endOfDay
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            expensesForSelectedDate = try modelContext.fetch(descriptor)
            selectedDate = date
        } catch {
            print("Failed to fetch expenses for date: \(error)")
            expensesForSelectedDate = []
        }
    }
    
    // MARK: - Notification Placeholder
    func triggerOverBudgetNotification() {
        // Placeholder for notification logic
        // In production, this would trigger a local notification
        print("⚠️ Budget exceeded! Current spending: $\(String(format: "%.2f", totalSpending))")
    }
    
    // MARK: - Quick Actions
    func deleteExpense(_ expense: Expense) {
        guard let modelContext = modelContext else { return }
        
        modelContext.delete(expense)
        do {
            try modelContext.save()
            fetchExpenses() // Refresh data
        } catch {
            print("Failed to delete expense: \(error)")
        }
    }
}

// Lightweight wrapper to inject the same view model to child views that need to call methods
final class DashboardViewModelWrapper: ObservableObject {
    let viewModel: DashboardViewModel
    init(viewModel: DashboardViewModel) { self.viewModel = viewModel }
}
