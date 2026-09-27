import SwiftUI

struct MetricRingView: View {
    let title: String
    let percentage: Double
    let tint: Color
    var diameter: CGFloat = 64
    var strokeWidth: CGFloat? = nil

    private var actualStroke: CGFloat {
        strokeWidth ?? max(diameter * 0.11, 4.5)
    }

    private var fraction: Double {
        min(max(percentage / 100.0, 0.0), 1.0)
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: actualStroke)

            // Progress arc
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: actualStroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Percentage and Title inside ring
            VStack(spacing: 1) {
                Text("\(Int(percentage.rounded()))%")
                    .font(.system(size: diameter * 0.25, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(.system(size: max(diameter * 0.12, 8), weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(actualStroke)
        }
        .frame(width: diameter, height: diameter)
        .animation(.easeOut(duration: 0.5), value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(Int(percentage.rounded())) percent")
    }
}
