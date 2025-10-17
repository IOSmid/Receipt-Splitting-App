import WidgetKit
import SwiftUI

// MARK: - Widget Bundle
@main
struct ReceiptSplitWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReceiptSplitWidget()
        if #available(iOS 17.0, *) {
            ReceiptSplitLockScreenWidget()
        }
    }
}

