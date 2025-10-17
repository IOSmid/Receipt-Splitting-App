//
//  ReceiptSplittingWidgetBundle.swift
//  ReceiptSplittingWidget
//
//  Created by fcuiecs on 2025/10/16.
//

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
