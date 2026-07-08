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

private struct LockScreenView: View {
    let context: ActivityViewContext<PupActivityAttributes>

    var body: some View {
        PupSceneView(scene: context.state.scene,
                     layout: context.state.layout,
                     minHeight: 120)
            .frame(maxWidth: .infinity, minHeight: 120)
            .overlay(alignment: .bottomTrailing) {
                WeatherBadge(scene: context.state.scene,
                             temperatureC: context.state.temperatureC)
            }
            .overlay(alignment: .topLeading) {
                Text(context.attributes.locationName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(context.state.scene.ink)
                    .lineLimit(1)
                    .padding(.leading, 10)
                    .padding(.top, 6)
            }
    }
}

/// Big friendly temperature + condition pinned over the bottom-right of the
/// grass. SF Rounded heavy keeps the chunky pixel-art vibe without shipping
/// a custom font.
struct WeatherBadge: View {
    let scene: PupScene
    let temperatureC: Double

    var body: some View {
        VStack(alignment: .trailing, spacing: -4) {
            Text("\(Int(temperatureC.rounded()))°")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
            Text(scene.label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundStyle(scene.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.trailing, 10)
        .padding(.bottom, 6)
    }
}
