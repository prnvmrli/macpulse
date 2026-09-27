import AppKit
import SwiftUI

struct DashboardView: View {
    @ObservedObject var monitor: MonitorStore
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 10) {
                    MetricRingView(
                        title: "CPU",
                        percentage: monitor.snapshot.cpu.usage,
                        diameter: 82
                    )
                    Text(" ")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }

                VStack(spacing: 10) {
                    MetricRingView(
                        title: "MEMORY",
                        percentage: monitor.snapshot.memory.usagePercent,
                        diameter: 82
                    )
                    Text(monitor.snapshot.memory.formattedUsedAndTotal)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .opacity(0.3)

            HStack {
                Text("MacPulse")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit", action: onQuit)
                    .buttonStyle(.borderless)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 228)
    }
}
