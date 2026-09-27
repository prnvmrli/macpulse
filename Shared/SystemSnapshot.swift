import Foundation

struct CPUSnapshot: Codable, Equatable {
    var usage: Double
    var logicalCoreCount: Int

    static let empty = CPUSnapshot(
        usage: 0,
        logicalCoreCount: ProcessInfo.processInfo.processorCount
    )
}

struct MemorySnapshot: Codable, Equatable {
    var usedBytes: UInt64
    var totalBytes: UInt64

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes) * 100, 0), 100)
    }

    var formattedUsedAndTotal: String {
        let gb = 1024.0 * 1024.0 * 1024.0
        let usedGB = Double(usedBytes) / gb
        let totalGB = Double(totalBytes) / gb
        return String(format: "%.1f / %.0f GB", usedGB, totalGB)
    }

    static let empty = MemorySnapshot(
        usedBytes: 0,
        totalBytes: ProcessInfo.processInfo.physicalMemory
    )
}

struct SystemSnapshot: Codable, Equatable {
    var timestamp: Date
    var cpu: CPUSnapshot
    var memory: MemorySnapshot

    static let empty = SystemSnapshot(
        timestamp: .distantPast,
        cpu: .empty,
        memory: .empty
    )
}

struct SharedPayload: Codable, Equatable {
    let schemaVersion: Int
    var snapshot: SystemSnapshot

    static let empty = SharedPayload(
        schemaVersion: AppConstants.payloadSchemaVersion,
        snapshot: .empty
    )
}
