import XCTest
@testable import MacPulseCore

final class MacPulseCoreTests: XCTestCase {
    func testCPUSnapshotDefaults() {
        let empty = CPUSnapshot.empty
        XCTAssertEqual(empty.usage, 0)
        XCTAssertGreaterThan(empty.logicalCoreCount, 0)
    }

    func testMemorySnapshotCalculations() {
        let total: UInt64 = 16 * 1024 * 1024 * 1024
        let used: UInt64 = 8 * 1024 * 1024 * 1024
        let memory = MemorySnapshot(usedBytes: used, totalBytes: total)

        XCTAssertEqual(memory.usagePercent, 50.0, accuracy: 0.1)
        XCTAssertEqual(memory.formattedUsedAndTotal, "8.0 / 16 GB")
        XCTAssertEqual(memory.formattedCompactGB, "8/16 GB")

        let memory13: UInt64 = UInt64(13.2 * Double(1024 * 1024 * 1024))
        let memSnapshot13 = MemorySnapshot(usedBytes: memory13, totalBytes: total)
        XCTAssertEqual(memSnapshot13.formattedCompactGB, "13/16 GB")
    }

    func testSystemSnapshotStructure() {
        let snapshot = SystemSnapshot(
            timestamp: Date(),
            cpu: CPUSnapshot(usage: 30.0, logicalCoreCount: 8),
            memory: MemorySnapshot(usedBytes: 4 * 1024 * 1024 * 1024, totalBytes: 16 * 1024 * 1024 * 1024)
        )
        XCTAssertEqual(snapshot.cpu.usage, 30.0)
        XCTAssertEqual(snapshot.memory.usagePercent, 25.0, accuracy: 0.1)
    }
}
