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

    private var badgeScale: Double {
        WeatherBadgeMetrics.clampedToHardRange(context.state.resolvedBadgeScale)
    }

    var body: some View {
        PupSceneView(scene: context.state.scene,
                     layout: context.state.layout,
                     minHeight: 120,
                     reservedTrailingWidth: WeatherBadgeMetrics.reservedWidth(
                         temperatureC: context.state.temperatureC,
                         label: context.state.scene.label,
                         scale: badgeScale))
            .frame(maxWidth: .infinity, minHeight: 120)
            .overlay(alignment: .bottomTrailing) {
                WeatherBadge(scene: context.state.scene,
                             temperatureC: context.state.temperatureC,
                             scale: badgeScale)
                    .padding(.trailing, WeatherBadgeMetrics.trailingMargin)
                    .padding(.bottom, WeatherBadgeMetrics.bottomMargin)
            }
            .overlay(alignment: .bottomLeading) {
                Text(context.attributes.locationName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(context.state.scene.ink)
                    .lineLimit(1)
                    .padding(.leading, 10)
                    .padding(.bottom, WeatherBadgeMetrics.bottomMargin)
            }
    }
}
