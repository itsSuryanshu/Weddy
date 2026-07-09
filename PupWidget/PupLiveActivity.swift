import ActivityKit
import SwiftUI
import WidgetKit

struct PupLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PupActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(context.state.resolvedSceneStyle == .ascii
                                        ? AsciiSceneRenderer.backdrop
                                        : context.state.scene.skyTop)
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

    private var locationAlignment: Alignment {
        switch context.state.resolvedLocationPosition {
        case .topLeft: .topLeading
        case .bottomLeft: .bottomLeading
        case .bottomCenter: .bottom
        }
    }

    var body: some View {
        PupSceneView(scene: context.state.scene,
                     layout: context.state.layout,
                     minHeight: 120,
                     reservedTrailingWidth: WeatherBadgeMetrics.reservedWidth(
                         temperatureC: context.state.temperatureC,
                         label: context.state.scene.label,
                         scale: badgeScale),
                     style: context.state.resolvedSceneStyle)
            .frame(maxWidth: .infinity, minHeight: 120)
            .overlay(alignment: .bottomTrailing) {
                WeatherBadge(scene: context.state.scene,
                             temperatureC: context.state.temperatureC,
                             scale: badgeScale,
                             style: context.state.resolvedSceneStyle)
                    .padding(.trailing, WeatherBadgeMetrics.trailingMargin)
                    .padding(.bottom, WeatherBadgeMetrics.bottomMargin)
            }
            .overlay(alignment: locationAlignment) {
                let position = context.state.resolvedLocationPosition
                Text(context.attributes.locationName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(context.state.scene.ink(for: context.state.resolvedSceneStyle))
                    .lineLimit(1)
                    .padding(.leading, position == .bottomCenter ? 0 : 10)
                    .padding(.top, position == .topLeft ? 6 : 0)
                    .padding(.bottom, position == .topLeft ? 0 : WeatherBadgeMetrics.bottomMargin)
            }
    }
}
