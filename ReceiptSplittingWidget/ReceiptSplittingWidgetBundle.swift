import WidgetKit
import SwiftUI

@main
struct ReceiptSplittingWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReceiptSplittingWidget()
        ReceiptSplittingWidgetControl()
        ReceiptSplittingWidgetLiveActivity()
    }
}
