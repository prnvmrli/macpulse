import XCTest
@testable import MacPulse

final class MacPulseTests: XCTestCase {
    func testCPUSnapshotInitialization() {
        let cpu = CPUSnapshot(usage: 25.5, logicalCoreCount: 8)
        XCTAssertEqual(cpu.usage, 25.5)
        XCTAssertEqual(cpu.logicalCoreCount, 8)
        XCTAssertEqual(CPUSnapshot.empty.usage, 0)
    }

    func testMemorySnapshotCalculations() {
        let total: UInt64 = 16 * 1024 * 1024 * 1024
        let used: UInt64 = 8 * 1024 * 1024 * 1024
        let memory = MemorySnapshot(usedBytes: used, totalBytes: total)

        XCTAssertEqual(memory.usagePercent, 50.0, accuracy: 0.1)
        XCTAssertEqual(memory.formattedUsedAndTotal, "8.0 / 16 GB")
    }

    func testCPUReaderReadsNonZeroLogicalCores() {
        let reader = CPUReader()
        reader.prime()
        let snapshot = reader.read()
        XCTAssertGreaterThan(snapshot.logicalCoreCount, 0)
        XCTAssertGreaterThanOrEqual(snapshot.usage, 0)
        XCTAssertLessThanOrEqual(snapshot.usage, 100)
    }

    func testMemoryReaderReadsPhysicalMemory() {
        let reader = MemoryReader()
        let snapshot = reader.read()
        XCTAssertGreaterThan(snapshot.totalBytes, 0)
        XCTAssertGreaterThanOrEqual(snapshot.usedBytes, 0)
        XCTAssertLessThanOrEqual(snapshot.usedBytes, snapshot.totalBytes)
        XCTAssertGreaterThanOrEqual(snapshot.usagePercent, 0)
        XCTAssertLessThanOrEqual(snapshot.usagePercent, 100)
    }

    func testSharedSnapshotPersistenceRoundtrip() {
        let snapshot = SystemSnapshot(
            timestamp: Date(),
            cpu: CPUSnapshot(usage: 42.0, logicalCoreCount: 8),
            memory: MemorySnapshot(usedBytes: 4 * 1024 * 1024 * 1024, totalBytes: 16 * 1024 * 1024 * 1024)
        )
        let payload = SharedPayload(schemaVersion: AppConstants.payloadSchemaVersion, snapshot: snapshot)

        XCTAssertTrue(SharedSnapshotStore.save(payload))
        let loaded = SharedSnapshotStore.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.snapshot.cpu.usage, 42.0)
        XCTAssertEqual(loaded?.snapshot.memory.usedBytes, 4 * 1024 * 1024 * 1024)
    }
}
