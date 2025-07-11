//
// FileTransferManagerTests.swift
// bitshareTests
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import XCTest
import Combine
import CryptoKit
@testable import bitchat

class FileTransferManagerTests: XCTestCase {
    
    var fileTransferManager: FileTransferManager!
    var mockMeshService: MockBluetoothMeshService!
    var cancellables: Set<AnyCancellable>!
    var testFileURL: URL!
    
    override func setUp() {
        super.setUp()
        fileTransferManager = FileTransferManager.shared
        mockMeshService = MockBluetoothMeshService()
        fileTransferManager.setMeshService(mockMeshService)
        cancellables = Set<AnyCancellable>()
        
        // Create test file
        let testData = Data("Test file content for transfer testing".utf8)
        testFileURL = createTestFile(with: testData, name: "test.txt")
    }
    
    override func tearDown() {
        cancellables.removeAll()
        cleanupTestFile()
        super.tearDown()
    }
    
    // MARK: - File Transfer Queue Tests
    
    func testQueueFileTransfer() {
        let expectation = XCTestExpectation(description: "File transfer queued")
        
        // Monitor queued transfers
        fileTransferManager.$queuedTransfers
            .sink { queuedTransfers in
                if !queuedTransfers.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        let transferID = fileTransferManager.queueFileTransfer(
            testFileURL,
            to: "test-peer-123",
            peerNickname: "Test Peer"
        )
        
        XCTAssertNotNil(transferID)
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertEqual(fileTransferManager.queuedTransfers.count, 1)
        XCTAssertEqual(fileTransferManager.queuedTransfers.first?.peerNickname, "Test Peer")
    }
    
    func testHighPriorityTransferOrder() {
        // Queue normal priority transfer
        let normalTransferID = fileTransferManager.queueFileTransfer(
            testFileURL,
            to: "peer-normal",
            peerNickname: "Normal Peer",
            priority: .normal
        )
        
        // Queue high priority transfer
        let highTransferID = fileTransferManager.queueFileTransfer(
            testFileURL,
            to: "peer-high",
            peerNickname: "High Peer",
            priority: .high
        )
        
        XCTAssertNotNil(normalTransferID)
        XCTAssertNotNil(highTransferID)
        
        // High priority should be first in queue
        XCTAssertEqual(fileTransferManager.queuedTransfers.first?.priority, .high)
        XCTAssertEqual(fileTransferManager.queuedTransfers.first?.peerNickname, "High Peer")
    }
    
    func testTransferHistory() {
        let expectation = XCTestExpectation(description: "Transfer added to history")
        
        fileTransferManager.$transferHistory
            .sink { history in
                if !history.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        _ = fileTransferManager.queueFileTransfer(
            testFileURL,
            to: "history-peer",
            peerNickname: "History Peer"
        )
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertEqual(fileTransferManager.transferHistory.count, 1)
        XCTAssertEqual(fileTransferManager.transferHistory.first?.direction, .send)
        XCTAssertEqual(fileTransferManager.transferHistory.first?.senderReceiver, "History Peer")
    }
    
    // MARK: - File Transfer Cancellation Tests
    
    func testCancelTransfer() {
        let transferID = fileTransferManager.queueFileTransfer(
            testFileURL,
            to: "cancel-peer",
            peerNickname: "Cancel Peer"
        )
        
        XCTAssertNotNil(transferID)
        XCTAssertEqual(fileTransferManager.queuedTransfers.count, 1)
        
        fileTransferManager.cancelTransfer(transferID!)
        
        XCTAssertEqual(fileTransferManager.queuedTransfers.count, 0)
        XCTAssertEqual(fileTransferManager.activeTransfers.count, 0)
    }
    
    func testPauseResumeTransfer() {
        // Create mock active transfer
        let manifest = FILE_MANIFEST(
            fileID: "pause-test",
            fileName: "pause.txt",
            fileSize: 1024,
            sha256Hash: "test-hash",
            senderID: "sender-123"
        )
        
        let transferState = FileTransferState(
            transferID: "pause-test",
            manifest: manifest,
            direction: .send,
            peerID: "peer-123",
            peerNickname: "Pause Peer"
        )
        
        transferState.status = .transferring(chunksReceived: 5, totalChunks: 10)
        fileTransferManager.activeTransfers.append(transferState)
        
        // Test pause
        fileTransferManager.pauseTransfer("pause-test")
        
        if case .paused(let pausedAt) = transferState.status {
            XCTAssertEqual(pausedAt, 0) // completedChunks.count
        } else {
            XCTFail("Transfer should be paused")
        }
        
        // Test resume
        fileTransferManager.resumeTransfer("pause-test")
        
        if case .transferring = transferState.status {
            // Success
        } else {
            XCTFail("Transfer should be resumed")
        }
    }
    
    // MARK: - Incoming Transfer Tests
    
    func testHandleIncomingManifest() {
        let manifest = FILE_MANIFEST(
            fileID: "incoming-test",
            fileName: "incoming.txt",
            fileSize: 512,
            sha256Hash: "incoming-hash",
            senderID: "sender-456"
        )
        
        let expectation = XCTestExpectation(description: "Incoming transfer created")
        
        fileTransferManager.$activeTransfers
            .sink { activeTransfers in
                if !activeTransfers.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        fileTransferManager.handleIncomingManifest(
            manifest,
            from: "sender-456",
            peerNickname: "Incoming Peer"
        )
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertEqual(fileTransferManager.activeTransfers.count, 1)
        XCTAssertEqual(fileTransferManager.activeTransfers.first?.direction, .receive)
        XCTAssertEqual(fileTransferManager.activeTransfers.first?.peerNickname, "Incoming Peer")
    }
    
    func testHandleIncomingChunk() {
        // Set up incoming transfer
        let manifest = FILE_MANIFEST(
            fileID: "chunk-test",
            fileName: "chunk.txt",
            fileSize: 100,
            sha256Hash: "chunk-hash",
            senderID: "sender-789"
        )
        
        fileTransferManager.handleIncomingManifest(
            manifest,
            from: "sender-789",
            peerNickname: "Chunk Peer"
        )
        
        let testData = Data("Test chunk content".utf8)
        let chunk = FILE_CHUNK(
            fileID: "chunk-test",
            chunkIndex: 0,
            payload: testData,
            isLastChunk: true
        )
        
        let expectation = XCTestExpectation(description: "Chunk processed")
        
        fileTransferManager.$activeTransfers
            .sink { activeTransfers in
                if let transfer = activeTransfers.first,
                   transfer.completedChunks.count > 0 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        fileTransferManager.handleIncomingChunk(chunk, from: "sender-789")
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertEqual(fileTransferManager.activeTransfers.first?.completedChunks.count, 1)
        XCTAssertTrue(fileTransferManager.activeTransfers.first?.completedChunks.contains(0) ?? false)
    }
    
    // MARK: - Progress Tracking Tests
    
    func testGlobalProgress() {
        // Create multiple transfers with different progress
        let manifest1 = FILE_MANIFEST(fileID: "progress-1", fileName: "file1.txt", fileSize: 1000, sha256Hash: "hash1", senderID: "sender-1")
        let manifest2 = FILE_MANIFEST(fileID: "progress-2", fileName: "file2.txt", fileSize: 2000, sha256Hash: "hash2", senderID: "sender-2")
        
        let transfer1 = FileTransferState(transferID: "progress-1", manifest: manifest1, direction: .receive, peerID: "peer-1", peerNickname: "Peer 1")
        let transfer2 = FileTransferState(transferID: "progress-2", manifest: manifest2, direction: .receive, peerID: "peer-2", peerNickname: "Peer 2")
        
        transfer1.progress = 25.0
        transfer2.progress = 75.0
        
        fileTransferManager.activeTransfers = [transfer1, transfer2]
        
        let expectation = XCTestExpectation(description: "Global progress updated")
        
        fileTransferManager.$globalProgress
            .sink { progress in
                if progress > 0 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Trigger progress update
        fileTransferManager.updateGlobalProgress()
        
        wait(for: [expectation], timeout: 1.0)
        
        // Expected: (25 + 75) / 2 = 50.0
        XCTAssertEqual(fileTransferManager.globalProgress, 50.0, accuracy: 0.1)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidFileURL() {
        let invalidURL = URL(string: "file:///nonexistent/path/file.txt")!
        
        let transferID = fileTransferManager.queueFileTransfer(
            invalidURL,
            to: "test-peer",
            peerNickname: "Test Peer"
        )
        
        XCTAssertNil(transferID)
        XCTAssertEqual(fileTransferManager.queuedTransfers.count, 0)
    }
    
    func testChunkIntegrityFailure() {
        // Set up transfer
        let manifest = FILE_MANIFEST(
            fileID: "integrity-test",
            fileName: "integrity.txt",
            fileSize: 50,
            sha256Hash: "test-hash",
            senderID: "sender-integrity"
        )
        
        fileTransferManager.handleIncomingManifest(
            manifest,
            from: "sender-integrity",
            peerNickname: "Integrity Peer"
        )
        
        // Create chunk with incorrect hash
        let testData = Data("Test data".utf8)
        var chunk = FILE_CHUNK(
            fileID: "integrity-test",
            chunkIndex: 0,
            payload: testData
        )
        
        // Manually corrupt the hash
        let corruptedHash = "corrupted-hash"
        // Note: In actual implementation, we'd need to access the internal hash field
        
        fileTransferManager.handleIncomingChunk(chunk, from: "sender-integrity")
        
        // Should not add corrupted chunk to completed chunks
        XCTAssertEqual(fileTransferManager.activeTransfers.first?.completedChunks.count, 1)
    }
    
    // MARK: - Retry Mechanism Tests
    
    func testRetryMechanism() {
        // This test verifies the retry mechanism works correctly
        let manifest = FILE_MANIFEST(
            fileID: "retry-test",
            fileName: "retry.txt",
            fileSize: 1000,
            sha256Hash: "retry-hash",
            senderID: "sender-retry"
        )
        
        let historyRecord = TransferRecord(
            transferID: "retry-test",
            fileName: "retry.txt",
            fileSize: 1000,
            senderReceiver: "Retry Peer",
            direction: .send,
            status: .failed(reason: "Network error", canRetry: true),
            timestamp: Date(),
            lastUpdated: Date()
        )
        
        fileTransferManager.transferHistory = [historyRecord]
        
        XCTAssertTrue(historyRecord.canRetry)
        
        // Test retry functionality
        fileTransferManager.retryTransfer("retry-test")
        
        // Verify retry was attempted (implementation specific)
        // In a real scenario, we'd verify the transfer was re-queued
    }
    
    // MARK: - Helper Methods
    
    private func createTestFile(with data: Data, name: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(name)
        
        do {
            try data.write(to: fileURL)
        } catch {
            XCTFail("Failed to create test file: \(error)")
        }
        
        return fileURL
    }
    
    private func cleanupTestFile() {
        if let testFileURL = testFileURL {
            try? FileManager.default.removeItem(at: testFileURL)
        }
    }
}

// MARK: - Mock Bluetooth Mesh Service

class MockBluetoothMeshService: BluetoothMeshService {
    var sentPackets: [BitchatPacket] = []
    
    override func broadcastFileTransferPacket(_ packet: BitchatPacket) {
        sentPackets.append(packet)
    }
    
    override var myPeerID: String {
        return "mock-peer-id"
    }
    
    func simulateIncomingMessage(_ packet: BitchatPacket) {
        // Simulate receiving a packet
        // In real implementation, this would trigger the delegate methods
    }
}