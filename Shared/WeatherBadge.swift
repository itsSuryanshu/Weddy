import SwiftUI
import UIKit

/// Big friendly temperature + condition pinned over the bottom-right of the
/// grass. SF Rounded heavy keeps the chunky pixel-art vibe without shipping
/// a custom font.
///
/// Text only — the widget adds the corner margins and the in-app editor wraps
/// it in resize chrome. `scale` multiplies the font sizes rather than using
/// `scaleEffect` so Live Activity text stays crisp and the footprint is
/// exactly linear in scale (area ∝ scale²), which the 30%-area cap relies on.
struct WeatherBadge: View {
    let scene: PupScene
    let temperatureC: Double
    var scale: Double = 1.0

    var body: some View {
        VStack(alignment: .trailing, spacing: WeatherBadgeMetrics.spacing * scale) {
            Text("\(Int(temperatureC.rounded()))°")
                .font(.system(size: WeatherBadgeMetrics.tempSize * scale, weight: .heavy, design: .rounded))
            Text(scene.label)
                .font(.system(size: WeatherBadgeMetrics.labelSize * scale, weight: .bold, design: .rounded))
        }
        .foregroundStyle(scene.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

/// Deterministic badge geometry shared by the app and the widget so the
/// editor's clamp, the dog's keep-out zone, and the widget's rendering all
/// agree. Measures with UIKit fonts instead of SwiftUI layout because a Live
/// Activity can't feed GeometryReader measurements back into state.
enum WeatherBadgeMetrics {
    static let tempSize: CGFloat = 30
    static let labelSize: CGFloat = 13
    static let spacing: CGFloat = -4
    /// Gap between the badge and the activity's trailing/bottom edges.
    static let trailingMargin: CGFloat = 10
    static let bottomMargin: CGFloat = 6
    /// 1.0 is the pre-customization badge size.
    static let minScale: Double = 1.0
    /// Widget-side sanity clamp. The real ceiling is the 30%-area cap, which
    /// only the app can compute (it needs a measured container); this just
    /// bounds a corrupt/hand-crafted payload.
    static let hardMaxScale: Double = 2.5
    /// The badge may cover at most this fraction of the Live Activity.
    static let maxAreaFraction: Double = 0.30

    /// Text-block size at scale 1 for a specific temperature and label.
    static func intrinsicSize(temperatureC: Double, label: String) -> CGSize {
        let temp = "\(Int(temperatureC.rounded()))°" as NSString
        let tempBounds = temp.size(withAttributes: [.font: roundedFont(size: tempSize, weight: .heavy)])
        let labelBounds = (label as NSString).size(withAttributes: [.font: roundedFont(size: labelSize, weight: .bold)])
        return CGSize(width: max(tempBounds.width, labelBounds.width),
                      height: tempBounds.height + labelBounds.height + spacing)
    }

    /// Worst case across every scene label with a wide temperature string.
    /// The 30% cap is computed against this so one global scale stays legal
    /// no matter which scene/temperature a location is showing.
    static let worstCaseIntrinsicSize: CGSize = PupScene.allCases.reduce(.zero) { acc, scene in
        let size = intrinsicSize(temperatureC: -88, label: scene.label)
        return CGSize(width: max(acc.width, size.width), height: max(acc.height, size.height))
    }

    /// Largest scale whose worst-case footprint stays within
    /// `maxAreaFraction` of the container.
    static func maxScale(in container: CGSize) -> Double {
        let containerArea = Double(container.width * container.height)
        let worstArea = Double(worstCaseIntrinsicSize.width * worstCaseIntrinsicSize.height)
        guard containerArea > 0, worstArea > 0 else { return minScale }
        return max(minScale, (maxAreaFraction * containerArea / worstArea).squareRoot())
    }

    /// Editor clamp: today's size up to the 30%-area cap for the measured
    /// container (never past the hard ceiling).
    static func clamped(_ scale: Double, in container: CGSize) -> Double {
        min(max(scale, minScale), min(maxScale(in: container), hardMaxScale))
    }

    /// Widget clamp: it can't measure its container reactively, so it trusts
    /// the app's cap and only bounds the value to a sane range.
    static func clampedToHardRange(_ scale: Double) -> Double {
        min(max(scale, minScale), hardMaxScale)
    }

    /// Horizontal keep-out width for the dog, in points from the trailing
    /// edge: the scaled text block plus its edge margin.
    static func reservedWidth(temperatureC: Double, label: String, scale: Double) -> CGFloat {
        intrinsicSize(temperatureC: temperatureC, label: label).width * scale + trailingMargin
    }

    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: size)
    }
}
