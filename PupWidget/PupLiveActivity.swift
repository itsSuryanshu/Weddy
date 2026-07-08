import ActivityKit
import SwiftUI
import WidgetKit

struct PupLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PupActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(context.state.scene.skyTop)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { _ in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    EmptyView()
                }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                EmptyView()
            } minimal: {
                EmptyView()
            }
            .keylineTint(.clear)
        }
    }
}

private func temperature(_ state: PupActivityAttributes.ContentState) -> String {
    "\(Int(state.temperatureC.rounded()))°"
}

private struct LockScreenView: View {
    let context: ActivityViewContext<PupActivityAttributes>

    var body: some View {
        PupSceneView(scene: context.state.scene,
                     layout: context.state.layout,
                     minHeight: 120)
            .frame(maxWidth: .infinity, minHeight: 120)
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(temperature(context.state))C · \(context.state.scene.label)")
                        .font(.caption.bold())
                    if let place = context.state.placeName {
                        Text(place)
                            .font(.caption2)
                            .opacity(0.85)
                    }
                }
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .shadow(color: .black.opacity(0.65), radius: 1, y: 1)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 5))
                .padding(.trailing, 8)
                .padding(.bottom, 6)
            }
    }
}
