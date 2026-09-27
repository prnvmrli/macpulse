import Darwin
import Foundation

struct MemoryReader {
    func read() -> MemorySnapshot {
        let total = ProcessInfo.processInfo.physicalMemory
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemorySnapshot(usedBytes: 0, totalBytes: total)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let free = (UInt64(statistics.free_count) + UInt64(statistics.speculative_count)) * pageSize
        let inactive = UInt64(statistics.inactive_count) * pageSize
        let purgeable = UInt64(statistics.purgeable_count) * pageSize
        let cached = min(total, inactive + purgeable)
        let reclaimable = min(total, free + cached)
        let used = total > reclaimable ? total - reclaimable : 0

        return MemorySnapshot(usedBytes: used, totalBytes: total)
    }
}
