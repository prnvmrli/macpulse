import Darwin
import Foundation

final class CPUReader {
    private struct Ticks {
        let user: UInt64
        let system: UInt64
        let idle: UInt64
        let nice: UInt64
    }

    private var previous: Ticks?
    private(set) var lastSnapshot: CPUSnapshot = .empty

    func prime() {
        previous = currentTicks()
    }

    func read() -> CPUSnapshot {
        guard let current = currentTicks() else { return lastSnapshot }
        defer { previous = current }
        guard let previous else { return lastSnapshot }

        let userDelta = delta(current.user, previous.user)
        let systemDelta = delta(current.system, previous.system)
        let idleDelta = delta(current.idle, previous.idle)
        let niceDelta = delta(current.nice, previous.nice)
        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
        guard totalDelta > 0 else { return lastSnapshot }

        let activeDelta = userDelta + systemDelta + niceDelta
        let usage = clamp(Double(activeDelta) / Double(totalDelta) * 100)

        let snapshot = CPUSnapshot(
            usage: usage,
            logicalCoreCount: ProcessInfo.processInfo.processorCount
        )
        lastSnapshot = snapshot
        return snapshot
    }

    private func currentTicks() -> Ticks? {
        var load = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &load) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        return Ticks(
            user: UInt64(load.cpu_ticks.0),
            system: UInt64(load.cpu_ticks.1),
            idle: UInt64(load.cpu_ticks.2),
            nice: UInt64(load.cpu_ticks.3)
        )
    }

    private func delta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : 0
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}
