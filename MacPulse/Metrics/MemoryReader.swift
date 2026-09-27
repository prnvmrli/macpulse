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
        let internalPages = UInt64(statistics.internal_page_count)
        let purgeablePages = UInt64(statistics.purgeable_count)
        let appMemory = internalPages > purgeablePages ? (internalPages - purgeablePages) * pageSize : 0
        let wiredMemory = UInt64(statistics.wire_count) * pageSize
        let compressedMemory = UInt64(statistics.compressor_page_count) * pageSize
        let used = min(total, appMemory + wiredMemory + compressedMemory)

        return MemorySnapshot(usedBytes: used, totalBytes: total)
    }
}
