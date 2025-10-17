//
//  ReceiptSplittingWidgetLiveActivity.swift
//  ReceiptSplittingWidget
//
//  Created by fcuiecs on 2025/10/16.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ReceiptSplittingWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ReceiptSplittingWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReceiptSplittingWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ReceiptSplittingWidgetAttributes {
    fileprivate static var preview: ReceiptSplittingWidgetAttributes {
        ReceiptSplittingWidgetAttributes(name: "World")
    }
}

extension ReceiptSplittingWidgetAttributes.ContentState {
    fileprivate static var smiley: ReceiptSplittingWidgetAttributes.ContentState {
        ReceiptSplittingWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ReceiptSplittingWidgetAttributes.ContentState {
         ReceiptSplittingWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ReceiptSplittingWidgetAttributes.preview) {
   ReceiptSplittingWidgetLiveActivity()
} contentStates: {
    ReceiptSplittingWidgetAttributes.ContentState.smiley
    ReceiptSplittingWidgetAttributes.ContentState.starEyes
}
