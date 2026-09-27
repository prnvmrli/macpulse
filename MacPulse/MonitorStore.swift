import Combine
import Foundation
import WidgetKit

@MainActor
final class MonitorStore: ObservableObject {
    @Published private(set) var snapshot: SystemSnapshot
    @Published private(set) var isRunning = false
    @Published private(set) var isDashboardVisible = false

    private let cpuReader = CPUReader()
    private let memoryReader = MemoryReader()

    private var loopTask: Task<Void, Never>?
    private var isSampling = false
    private var lastPersist = Date.distantPast
    private var lastWidgetReload = Date.distantPast
    private var lastWidgetReloadSnapshot = SystemSnapshot.empty
    private var wasRunningBeforeSleep = false

    init() {
        let cached = SharedSnapshotStore.load() ?? .empty
        snapshot = cached.snapshot
        cpuReader.prime()
    }

    deinit {
        loopTask?.cancel()
    }

    func start() {
        guard loopTask == nil else { return }
        isRunning = true
        loopTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.sampleOnce()
                let interval = self.currentInterval()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        isRunning = false
        persist(forceWidgetReload: false)
    }

    func pauseForSleep() {
        wasRunningBeforeSleep = isRunning
        stop()
    }

    func resumeAfterWake() {
        cpuReader.prime()
        if wasRunningBeforeSleep {
            start()
        }
        wasRunningBeforeSleep = false
    }

    func setDashboardVisible(_ visible: Bool) {
        isDashboardVisible = visible
        if visible {
            Task { await sampleOnce() }
        }
    }

    func forceRefresh() {
        Task { await sampleOnce(forcePersistence: true) }
    }

    private func currentInterval() -> TimeInterval {
        if ProcessInfo.processInfo.isLowPowerModeEnabled, !isDashboardVisible {
            return 5.0
        }
        return isDashboardVisible ? 1.0 : 2.0
    }

    private func sampleOnce(forcePersistence: Bool = false) async {
        guard !isSampling else { return }
        isSampling = true
        defer { isSampling = false }

        let now = Date()
        let cpu = cpuReader.read()
        let memory = memoryReader.read()

        snapshot = SystemSnapshot(
            timestamp: now,
            cpu: cpu,
            memory: memory
        )

        if forcePersistence || now.timeIntervalSince(lastPersist) >= 2.0 {
            persist(forceWidgetReload: forcePersistence)
            lastPersist = now
        }
    }

    private func persist(forceWidgetReload: Bool) {
        let payload = SharedPayload(
            schemaVersion: AppConstants.payloadSchemaVersion,
            snapshot: snapshot
        )
        SharedSnapshotStore.save(payload)

        let now = Date()
        let minimumGap: TimeInterval = 10
        let heartbeat: TimeInterval = 30
        let significant = widgetChangeIsSignificant(from: lastWidgetReloadSnapshot, to: snapshot)
        let shouldReload = forceWidgetReload
            || now.timeIntervalSince(lastWidgetReload) >= heartbeat
            || (significant && now.timeIntervalSince(lastWidgetReload) >= minimumGap)

        guard shouldReload else { return }
        lastWidgetReload = now
        lastWidgetReloadSnapshot = snapshot
        WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)
    }

    private func widgetChangeIsSignificant(from old: SystemSnapshot, to new: SystemSnapshot) -> Bool {
        if old.timestamp == .distantPast { return true }
        if old.memory.formattedCompactGB != new.memory.formattedCompactGB { return true }
        if abs(old.cpu.usage - new.cpu.usage) >= 5 { return true }
        if abs(old.memory.usagePercent - new.memory.usagePercent) >= 3 { return true }
        return false
    }
}
