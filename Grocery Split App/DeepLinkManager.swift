import Foundation
import SwiftUI

// MARK: - Deep Link Manager
/// Manages deep linking from widgets to specific app screens
class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()
    
    @Published var activeDestination: DeepLinkDestination?
    
    private init() {}
    
    // MARK: - Deep Link Destinations
    enum DeepLinkDestination: Equatable {
        case timeline
        case dashboard
        case splitHistory
        case addExpense
        case expenseDetail(id: UUID)
        case budgetSettings
        
        var url: URL? {
            switch self {
            case .timeline:
                return URL(string: "receiptsplit://timeline")
            case .dashboard:
                return URL(string: "receiptsplit://dashboard")
            case .splitHistory:
                return URL(string: "receiptsplit://splithistory")
            case .addExpense:
                return URL(string: "receiptsplit://addexpense")
            case .expenseDetail(let id):
                return URL(string: "receiptsplit://expense/\(id.uuidString)")
            case .budgetSettings:
                return URL(string: "receiptsplit://budget")
            }
        }
    }
    
    // MARK: - URL Handling
    func handle(url: URL) {
        guard url.scheme == "receiptsplit" else { return }
        
        let host = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        switch host {
        case "timeline":
            activeDestination = .timeline
        case "dashboard":
            activeDestination = .dashboard
        case "splithistory":
            activeDestination = .splitHistory
        case "addexpense":
            activeDestination = .addExpense
        case "budget":
            activeDestination = .budgetSettings
        case "expense":
            if let idString = pathComponents.first,
               let uuid = UUID(uuidString: idString) {
                activeDestination = .expenseDetail(id: uuid)
            }
        default:
            activeDestination = .timeline
        }
    }
    
    // MARK: - Navigate to Destination
    func navigate(to destination: DeepLinkDestination) {
        activeDestination = destination
    }
    
    // MARK: - Clear Destination
    func clearDestination() {
        activeDestination = nil
    }
}

// MARK: - Widget Link Modifier
struct WidgetLinkModifier: ViewModifier {
    let destination: DeepLinkManager.DeepLinkDestination
    
    func body(content: Content) -> some View {
        if let url = destination.url {
            content.widgetURL(url)
        } else {
            content
        }
    }
}

extension View {
    func widgetLink(to destination: DeepLinkManager.DeepLinkDestination) -> some View {
        modifier(WidgetLinkModifier(destination: destination))
    }
}

// MARK: - App Deep Link Handler
/// Use this in your main app to handle incoming URLs
extension View {
    func handleDeepLinks() -> some View {
        self.onOpenURL { url in
            DeepLinkManager.shared.handle(url: url)
        }
    }
}

