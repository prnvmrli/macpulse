import AppKit
import Foundation
import SwiftUI
import WidgetKit

struct MacPulseEntry: TimelineEntry {
    let date: Date
    let snapshot: SystemSnapshot
}

private enum WidgetMetricSampler {
    static func sample() async -> SystemSnapshot {
        let now = Date()

        // If the main menu bar app wrote a recent sample, use it directly.
        if let cached = SharedSnapshotStore.load(),
           now.timeIntervalSince(cached.snapshot.timestamp) < 60 {
            return cached.snapshot
        }

        // Otherwise sample directly via shared metrics readers.
        let cpuReader = CPUReader()
        cpuReader.prime()

        // CPU utilization requires a short observation delta.
        try? await Task.sleep(nanoseconds: 250_000_000)

        let cpu = cpuReader.read()
        let memory = MemoryReader().read()

        return SystemSnapshot(
            timestamp: now,
            cpu: cpu,
            memory: memory
        )
    }
}

struct MacPulseProvider: TimelineProvider {
    func placeholder(in context: Context) -> MacPulseEntry {
        MacPulseEntry(date: .now, snapshot: previewSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (MacPulseEntry) -> Void) {
        if context.isPreview {
            completion(MacPulseEntry(date: .now, snapshot: previewSnapshot))
            return
        }

        Task {
            let snapshot = await WidgetMetricSampler.sample()
            completion(MacPulseEntry(date: .now, snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MacPulseEntry>) -> Void) {
        Task {
            let snapshot = await WidgetMetricSampler.sample()
            let entry = MacPulseEntry(date: .now, snapshot: snapshot)
            let nextRefresh = Date().addingTimeInterval(30)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private var previewSnapshot: SystemSnapshot {
        SystemSnapshot(
            timestamp: .now,
            cpu: CPUSnapshot(usage: 23, logicalCoreCount: ProcessInfo.processInfo.processorCount),
            memory: MemorySnapshot(
                usedBytes: 8_300_000_000,
                totalBytes: 16_000_000_000
            )
        )
    }
}

struct MacPulseWidgetView: View {
    let entry: MacPulseEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .systemSmall {
                smallView
            } else {
                mediumView
            }
        }
        .widgetURL(URL(string: "macpulse://open"))
        .macPulseWidgetBackground()
    }

    private var smallView: some View {
        HStack(spacing: 12) {
            VStack(spacing: 9) {
                WidgetRing(
                    title: "CPU",
                    percentage: entry.snapshot.cpu.usage,
                    diameter: 56
                )
                // Spacer matching RAM subtitle height to align ring centers
                Text(" ")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }

            VStack(spacing: 9) {
                WidgetRing(
                    title: "RAM",
                    percentage: entry.snapshot.memory.usagePercent,
                    diameter: 56
                )
                Text(entry.snapshot.memory.formattedCompactGB)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mediumView: some View {
        HStack(spacing: 36) {
            VStack(spacing: 12) {
                WidgetRing(
                    title: "CPU",
                    percentage: entry.snapshot.cpu.usage,
                    diameter: 80
                )
                Text(" ")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }

            VStack(spacing: 12) {
                WidgetRing(
                    title: "MEMORY",
                    percentage: entry.snapshot.memory.usagePercent,
                    diameter: 80
                )
                Text(entry.snapshot.memory.formattedCompactGB)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WidgetRing: View {
    let title: String
    let percentage: Double
    var tint: Color? = nil
    var diameter: CGFloat = 58

    private var activeTint: Color {
        tint ?? Color.reactiveMetric(for: percentage)
    }

    private var strokeWidth: CGFloat {
        max(diameter * 0.11, 4.5)
    }

    private var fraction: Double {
        min(max(percentage / 100.0, 0), 1)
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: strokeWidth)

            // Progress Arc
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    activeTint,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Percentage and Title inside ring
            VStack(spacing: 0) {
                Text("\(Int(percentage.rounded()))%")
                    .font(.system(size: diameter * 0.25, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(.system(size: max(diameter * 0.12, 8), weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(strokeWidth)
        }
        .frame(width: diameter, height: diameter)
    }
}

private extension View {
    @ViewBuilder
    func macPulseWidgetBackground() -> some View {
        if #available(macOSApplicationExtension 14.0, *) {
            containerBackground(.fill.tertiary, for: .widget)
        } else {
            background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

struct MacPulseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConstants.widgetKind, provider: MacPulseProvider()) { entry in
            MacPulseWidgetView(entry: entry)
        }
        .configurationDisplayName("MacPulse")
        .description("CPU and memory utilization.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct MacPulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        MacPulseWidget()
    }
}
