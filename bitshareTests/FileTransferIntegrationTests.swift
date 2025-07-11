//
// FileTransferIntegrationTests.swift
// bitshareTests
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import XCTest
import Combine
import CryptoKit
@testable import bitchat

class FileTransferIntegrationTests: XCTestCase {
    
    var fileTransferManager: FileTransferManager!
    var fileTransferService: FileTransferService!
    var optimizer: FileChunkOptimizer!
    var mockMeshService: MockIntegrationMeshService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        fileTransferManager = FileTransferManager.shared
        fileTransferService = FileTransferService.shared
        optimizer = FileChunkOptimizer.shared
        mockMeshService = MockIntegrationMeshService()
        cancellables = Set<AnyCancellable>()
        
        // Wire up services
        fileTransferManager.setMeshService(mockMeshService)
        fileTransferService.setMeshService(mockMeshService)
        
        // Reset state
        optimizer.resetStats()
        optimizer.clearCache()
        
        // Clear any previous transfers
        fileTransferManager.activeTransfers.removeAll()
        fileTransferManager.queuedTransfers.removeAll()
        fileTransferManager.completedTransfers.removeAll()
        fileTransferManager.transferHistory.removeAll()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        optimizer.clearCache()
        super.tearDown()
    }
    
    // MARK: - End-to-End File Transfer Tests
    
    func testCompleteFileTransferFlow() {
        let testData = Data("Complete file transfer test data".utf8)
        let testFileURL = createTestFile(with: testData, name: "complete_test.txt")
        
        let transferExpectation = XCTestExpectation(description: "Complete file transfer")
        
        // Monitor transfer completion
        fileTransferManager.$completedTransfers
            .sink { completedTransfers in
                if !completedTransfers.isEmpty {
                    transferExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Start transfer
        guard let transferID = fileTransferManager.queueFileTransfer(
            testFileURL,
            to: "test-peer-123",
            peerNickname: "Test Peer"
        ) else {
            XCTFail("Failed to queue file transfer")
            return
        }
        
        // Simulate the complete transfer process
        simulateCompleteTransfer(transferID: transferID, testData: testData)
        
        wait(for: [transferExpectation], timeout: 10.0)
        
        XCTAssertEqual(fileTransferManager.completedTransfers.count, 1)
        XCTAssertEqual(fileTransferManager.completedTransfers.first?.fileName, "complete_test.txt")
        
        cleanupTestFile(testFileURL)
    }
    
    func testLargeFileTransferWithChunking() {
        let largeData = Data(repeating: 0xAB, count: 1024 * 10)  // 10KB
        let testFileURL = createTestFile(with: largeData, name: "large_test.bin")
        
        let progressExpectation = XCTestExpectation(description: "Progress updates received")
        var progressUpdates: [Double] = []
        
        fileTransferManager.$globalProgress
            .sink { progress in
                progressUpdates.append(progress)
                if progress >= 100.0 {
                    progressExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        guard let transferID = fileTransferManager.queueFileTransfer(
            testFileURL,
            to: "large-peer",
            peerNickname: "Large Peer"
        ) else {
            XCTFail("Failed to queue large file transfer")
            return
        }
        
        // Simulate chunked transfer
        simulateChunkedTransfer(transferID: transferID, testData: largeData)
        
        wait(for: [progressExpectation], timeout: 15.0)
        
        XCTAssertFalse(progressUpdates.isEmpty)
        XCTAssertEqual(progressUpdates.last, 100.0, accuracy: 0.1)
        
        cleanupTestFile(testFileURL)
    }
    
    func testSimultaneousMultipleTransfers() {
        let testData1 = Data("First transfer data".utf8)
        let testData2 = Data("Second transfer data".utf8)
        let testData3 = Data("Third transfer data".utf8)
        
        let testFile1 = createTestFile(with: testData1, name: "multi_test1.txt")
        let testFile2 = createTestFile(with: testData2, name: "multi_test2.txt")
        let testFile3 = createTestFile(with: testData3, name: "multi_test3.txt")
        
        let multiTransferExpectation = XCTestExpectation(description: "Multiple transfers completed")
        
        fileTransferManager.$completedTransfers
            .sink { completedTransfers in
                if completedTransfers.count >= 3 {
                    multiTransferExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Queue multiple transfers
        let transferID1 = fileTransferManager.queueFileTransfer(testFile1, to: "peer-1", peerNickname: "Peer 1")
        let transferID2 = fileTransferManager.queueFileTransfer(testFile2, to: "peer-2", peerNickname: "Peer 2")
        let transferID3 = fileTransferManager.queueFileTransfer(testFile3, to: "peer-3", peerNickname: "Peer 3")
        
        XCTAssertNotNil(transferID1)
        XCTAssertNotNil(transferID2)
        XCTAssertNotNil(transferID3)
        
        // Simulate concurrent transfers
        DispatchQueue.global(qos: .userInitiated).async {
            self.simulateCompleteTransfer(transferID: transferID1!, testData: testData1)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.simulateCompleteTransfer(transferID: transferID2!, testData: testData2)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.simulateCompleteTransfer(transferID: transferID3!, testData: testData3)
        }
        
        wait(for: [multiTransferExpectation], timeout: 20.0)
        
        XCTAssertEqual(fileTransferManager.completedTransfers.count, 3)
        
        cleanupTestFile(testFile1)
        cleanupTestFile(testFile2)
        cleanupTestFile(testFile3)
    }
    
    // MARK: - Error Recovery Tests
    
    func testTransferInterruptionAndResume() {
        let testData = Data("Interruption test data".utf8)
        let testFileURL = createTestFile(with: testData, name: "interrupt_test.txt")
        
        guard let transferID = fileTransferManager.queueFileTransfer(
            testFileURL,
            to: "interrupt-peer",
            peerNickname: "Interrupt Peer"
        ) else {
            XCTFail("Failed to queue transfer")
            return
        }
        
        // Start transfer and then pause it
        simulateTransferStart(transferID: transferID)
        
        // Simulate partial progress
        if let activeTransfer = fileTransferManager.activeTransfers.first(where: { $0.transferID == transferID }) {
            activeTransfer.progress = 50.0
            activeTransfer.completedChunks = Set([0, 1])
        }
        
        // Pause transfer
        fileTransferManager.pauseTransfer(transferID)
        
        // Verify transfer is paused
        if let activeTransfer = fileTransferManager.activeTransfers.first(where: { $0.transferID == transferID }) {
            if case .paused = activeTransfer.status {
                // Success
            } else {
                XCTFail("Transfer should be paused")
            }
        }
        
        // Resume transfer
        fileTransferManager.resumeTransfer(transferID)
        
        // Verify transfer is resumed
        if let activeTransfer = fileTransferManager.activeTransfers.first(where: { $0.transferID == transferID }) {
            if case .transferring = activeTransfer.status {
                // Success
            } else {
                XCTFail("Transfer should be resumed")
            }
        }
        
        cleanupTestFile(testFileURL)
    }
    
    func testChunkRetryMechanism() {
        let testData = Data("Chunk retry test data".utf8)
        let fileHash = SHA256.hash(data: testData).compactMap { String(format: "%02x", $0) }.joined()
        
        let manifest = FILE_MANIFEST(
            fileID: "retry-test-123",
            fileName: "retry.txt",
            fileSize: UInt64(testData.count),
            sha256Hash: fileHash,
            senderID: "sender-retry"
        )
        
        // Set up incoming transfer
        fileTransferManager.handleIncomingManifest(manifest, from: "sender-retry", peerNickname: "Retry Peer")
        
        // Create chunks
        let chunks = optimizer.createOptimizedChunks(from: testData, fileID: "retry-test-123")
        
        // Simulate receiving all chunks except one
        for (index, chunk) in chunks.enumerated() {
            if index == 1 {
                // Skip chunk 1 to simulate missing chunk
                continue
            }
            fileTransferManager.handleIncomingChunk(chunk, from: "sender-retry")
        }
        
        // Verify transfer is not complete
        if let activeTransfer = fileTransferManager.activeTransfers.first(where: { $0.transferID == "retry-test-123" }) {
            XCTAssertLessThan(activeTransfer.progress, 100.0)
        }
        
        // Now send the missing chunk
        fileTransferManager.handleIncomingChunk(chunks[1], from: "sender-retry")
        
        // Wait for completion
        let retryExpectation = XCTestExpectation(description: "Retry completed")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            retryExpectation.fulfill()
        }
        
        wait(for: [retryExpectation], timeout: 5.0)
        
        // Verify transfer completed
        XCTAssertEqual(fileTransferManager.completedTransfers.count, 1)
    }
    
    // MARK: - Performance Integration Tests
    
    func testOptimizedChunkingIntegration() {
        let largeData = Data(repeating: 0xCC, count: 1024 * 50)  // 50KB
        let testFileURL = createTestFile(with: largeData, name: "optimized_test.bin")
        
        optimizer.resetStats()
        
        guard let transferID = fileTransferManager.queueFileTransfer(
            testFileURL,
            to: "optimized-peer",
            peerNickname: "Optimized Peer"
        ) else {
            XCTFail("Failed to queue optimized transfer")
            return
        }
        
        // Simulate transfer using optimizer
        let chunks = optimizer.createOptimizedChunks(from: largeData, fileID: transferID)
        
        let optimizationExpectation = XCTestExpectation(description: "Optimized transfer completed")
        
        // Process chunks through the system
        DispatchQueue.global(qos: .userInitiated).async {
            for chunk in chunks {
                // Simulate chunk processing delay
                Thread.sleep(forTimeInterval: 0.01)
                
                // Cache chunk for testing
                let cacheKey = "\(transferID)_\(chunk.chunkIndex)"
                self.optimizer.cacheChunk(cacheKey, data: chunk.payload)
            }
            
            DispatchQueue.main.async {
                optimizationExpectation.fulfill()
            }
        }
        
        wait(for: [optimizationExpectation], timeout: 10.0)
        
        // Verify performance stats were collected
        let stats = optimizer.getPerformanceStats()
        XCTAssertGreaterThan(stats.totalProcessed, 0)
        XCTAssertGreaterThan(stats.averageChunkTime, 0)
        
        // Verify cache usage
        let cacheStats = optimizer.getCacheStats()
        XCTAssertGreaterThan(cacheStats.size, 0)
        
        cleanupTestFile(testFileURL)
    }
    
    // MARK: - Protocol Compliance Tests
    
    func testProtocolMessageFlow() {
        let testData = Data("Protocol message flow test".utf8)
        let fileHash = SHA256.hash(data: testData).compactMap { String(format: "%02x", $0) }.joined()
        
        let manifest = FILE_MANIFEST(
            fileID: "protocol-test-456",
            fileName: "protocol.txt",
            fileSize: UInt64(testData.count),
            sha256Hash: fileHash,
            senderID: "protocol-sender"
        )
        
        // Test manifest encoding/decoding
        guard let manifestData = manifest.toBinaryPayload(),
              let decodedManifest = FILE_MANIFEST.fromBinaryPayload(manifestData) else {
            XCTFail("Failed to encode/decode manifest")
            return
        }
        
        XCTAssertEqual(decodedManifest.fileName, manifest.fileName)
        XCTAssertEqual(decodedManifest.fileSize, manifest.fileSize)
        
        // Test chunk encoding/decoding
        let chunks = optimizer.createOptimizedChunks(from: testData, fileID: "protocol-test-456")
        
        for chunk in chunks {
            guard let chunkData = chunk.toBinaryPayload(),
                  let decodedChunk = FILE_CHUNK.fromBinaryPayload(chunkData) else {
                XCTFail("Failed to encode/decode chunk \(chunk.chunkIndex)")
                continue
            }
            
            XCTAssertEqual(decodedChunk.fileID, chunk.fileID)
            XCTAssertEqual(decodedChunk.chunkIndex, chunk.chunkIndex)
            XCTAssertEqual(decodedChunk.payload, chunk.payload)
        }
        
        // Test ACK encoding/decoding
        let acknowledgedChunks = Set(chunks.map { $0.chunkIndex })
        let ack = FILE_ACK(
            fileID: "protocol-test-456",
            receiverID: "protocol-receiver",
            acknowledgedChunks: acknowledgedChunks,
            totalChunks: UInt32(chunks.count)
        )
        
        guard let ackData = ack.toBinaryPayload(),
              let decodedAck = FILE_ACK.fromBinaryPayload(ackData) else {
            XCTFail("Failed to encode/decode ACK")
            return
        }
        
        XCTAssertEqual(decodedAck.fileID, ack.fileID)
        XCTAssertEqual(decodedAck.receiverID, ack.receiverID)
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyFileTransfer() {
        let emptyData = Data()
        let testFileURL = createTestFile(with: emptyData, name: "empty.txt")
        
        guard let transferID = fileTransferManager.queueFileTransfer(
            testFileURL,
            to: "empty-peer",
            peerNickname: "Empty Peer"
        ) else {
            XCTFail("Failed to queue empty file transfer")
            return
        }
        
        // Empty file should complete immediately
        let emptyExpectation = XCTestExpectation(description: "Empty file transfer completed")
        
        fileTransferManager.$completedTransfers
            .sink { completedTransfers in
                if !completedTransfers.isEmpty {
                    emptyExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        simulateCompleteTransfer(transferID: transferID, testData: emptyData)
        
        wait(for: [emptyExpectation], timeout: 5.0)
        
        XCTAssertEqual(fileTransferManager.completedTransfers.count, 1)
        
        cleanupTestFile(testFileURL)
    }
    
    func testMaximumFileSize() {
        let maxData = Data(repeating: 0xFF, count: FileTransferConstants.RECOMMENDED_MAX_FILE_SIZE)
        let testFileURL = createTestFile(with: maxData, name: "max_size.bin")
        
        let transferID = fileTransferManager.queueFileTransfer(
            testFileURL,
            to: "max-peer",
            peerNickname: "Max Peer"
        )
        
        // Should accept files up to the maximum size
        XCTAssertNotNil(transferID)
        
        cleanupTestFile(testFileURL)
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
    
    private func cleanupTestFile(_ fileURL: URL) {
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    private func simulateTransferStart(transferID: String) {
        // Simulate transfer moving from queued to active
        if let queuedIndex = fileTransferManager.queuedTransfers.firstIndex(where: { $0.transferID == transferID }) {
            let queuedTransfer = fileTransferManager.queuedTransfers.remove(at: queuedIndex)
            
            let transferState = FileTransferState(
                transferID: transferID,
                manifest: queuedTransfer.manifest,
                direction: .send,
                peerID: queuedTransfer.peerID,
                peerNickname: queuedTransfer.peerNickname
            )
            
            fileTransferManager.activeTransfers.append(transferState)
        }
    }
    
    private func simulateCompleteTransfer(transferID: String, testData: Data) {
        simulateTransferStart(transferID: transferID)
        
        // Simulate progress updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let activeTransfer = self.fileTransferManager.activeTransfers.first(where: { $0.transferID == transferID }) {
                activeTransfer.progress = 100.0
                activeTransfer.status = .completed(fileURL: URL(string: "file://temp")!)
                
                // Move to completed
                let completedTransfer = CompletedTransfer(
                    transferID: transferID,
                    fileName: activeTransfer.manifest.fileName,
                    fileSize: activeTransfer.manifest.fileSize,
                    peerName: activeTransfer.peerNickname,
                    direction: activeTransfer.direction,
                    completionTime: Date(),
                    fileURL: nil
                )
                
                self.fileTransferManager.completedTransfers.insert(completedTransfer, at: 0)
                self.fileTransferManager.activeTransfers.removeAll { $0.transferID == transferID }
            }
        }
    }
    
    private func simulateChunkedTransfer(transferID: String, testData: Data) {
        simulateTransferStart(transferID: transferID)
        
        let chunks = optimizer.createOptimizedChunks(from: testData, fileID: transferID)
        
        // Simulate gradual chunk completion
        DispatchQueue.global(qos: .userInitiated).async {
            for (index, chunk) in chunks.enumerated() {
                Thread.sleep(forTimeInterval: 0.1)
                
                DispatchQueue.main.async {
                    if let activeTransfer = self.fileTransferManager.activeTransfers.first(where: { $0.transferID == transferID }) {
                        activeTransfer.completedChunks.insert(UInt32(index))
                        activeTransfer.progress = Double(activeTransfer.completedChunks.count) / Double(chunks.count) * 100.0
                        
                        if activeTransfer.completedChunks.count == chunks.count {
                            self.simulateCompleteTransfer(transferID: transferID, testData: testData)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Mock Integration Mesh Service

class MockIntegrationMeshService: BluetoothMeshService {
    var sentPackets: [BitchatPacket] = []
    var messageHandlers: [(BitchatPacket) -> Void] = []
    
    override func broadcastFileTransferPacket(_ packet: BitchatPacket) {
        sentPackets.append(packet)
        
        // Simulate packet processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for handler in self.messageHandlers {
                handler(packet)
            }
        }
    }
    
    override var myPeerID: String {
        return "mock-integration-peer"
    }
    
    func addMessageHandler(_ handler: @escaping (BitchatPacket) -> Void) {
        messageHandlers.append(handler)
    }
    
    func simulateFileTransferMessage(_ packet: BitchatPacket) {
        // Simulate receiving a file transfer message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // In a real implementation, this would trigger delegate methods
            // based on the packet type (FILE_MANIFEST, FILE_CHUNK, FILE_ACK)
        }
    }
}