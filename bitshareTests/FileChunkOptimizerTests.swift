//
// FileChunkOptimizerTests.swift
// bitshareTests
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import XCTest
import CryptoKit
@testable import bitchat

class FileChunkOptimizerTests: XCTestCase {
    
    var optimizer: FileChunkOptimizer!
    
    override func setUp() {
        super.setUp()
        optimizer = FileChunkOptimizer.shared
        optimizer.resetStats()
        optimizer.clearCache()
    }
    
    override func tearDown() {
        optimizer.clearCache()
        super.tearDown()
    }
    
    // MARK: - Basic Chunking Tests
    
    func testOptimalChunkSize() {
        // Test small file
        let smallFileSize = 1024 * 5  // 5KB
        let smallChunkSize = optimizer.calculateOptimalChunkSize(fileSize: smallFileSize)
        XCTAssertLessThanOrEqual(smallChunkSize, FileTransferConstants.CHUNK_SIZE)
        
        // Test medium file
        let mediumFileSize = 1024 * 500  // 500KB
        let mediumChunkSize = optimizer.calculateOptimalChunkSize(fileSize: mediumFileSize)
        XCTAssertEqual(mediumChunkSize, FileTransferConstants.CHUNK_SIZE)
        
        // Test large file
        let largeFileSize = 1024 * 1024 * 50  // 50MB
        let largeChunkSize = optimizer.calculateOptimalChunkSize(fileSize: largeFileSize)
        XCTAssertGreaterThanOrEqual(largeChunkSize, FileTransferConstants.CHUNK_SIZE)
        XCTAssertLessThanOrEqual(largeChunkSize, 512)  // BLE MTU constraint
    }
    
    func testCreateOptimizedChunks() {
        let testData = Data("Test data for chunking optimization".utf8)
        let fileID = "chunk-test-123"
        
        var progressUpdates: [Double] = []
        
        let chunks = optimizer.createOptimizedChunks(
            from: testData,
            fileID: fileID,
            progressCallback: { progress in
                progressUpdates.append(progress)
            }
        )
        
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertEqual(chunks.first?.fileID, fileID)
        XCTAssertFalse(progressUpdates.isEmpty)
        XCTAssertEqual(progressUpdates.last, 1.0, accuracy: 0.001)
        
        // Verify chunk reconstruction
        let reconstructedData = chunks.reduce(Data()) { result, chunk in
            result + chunk.payload
        }
        
        XCTAssertEqual(reconstructedData, testData)
    }
    
    func testChunkingLargeFile() {
        let largeData = Data(repeating: 0xAB, count: 1024 * 100)  // 100KB
        let fileID = "large-chunk-test"
        
        let startTime = Date()
        let chunks = optimizer.createOptimizedChunks(from: largeData, fileID: fileID)
        let processingTime = Date().timeIntervalSince(startTime)
        
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertLessThan(processingTime, 2.0, "Large file chunking should be reasonably fast")
        
        // Verify all chunks have correct file ID
        for chunk in chunks {
            XCTAssertEqual(chunk.fileID, fileID)
        }
        
        // Verify last chunk is marked correctly
        XCTAssertTrue(chunks.last?.isLastChunk ?? false)
    }
    
    // MARK: - Compression Tests
    
    func testCompressionOptimization() {
        // Create repetitive data that should compress well
        let repetitiveData = Data(repeating: 0x55, count: 1024 * 20)  // 20KB of same byte
        let fileID = "compression-test"
        
        let chunks = optimizer.createOptimizedChunks(from: repetitiveData, fileID: fileID)
        
        let stats = optimizer.getPerformanceStats()
        
        // Should have some compression activity for large repetitive data
        XCTAssertGreaterThan(stats.totalProcessed, 0)
        
        // Verify chunks can be reconstructed
        let reconstructedData = chunks.reduce(Data()) { result, chunk in
            result + chunk.payload
        }
        
        XCTAssertEqual(reconstructedData, repetitiveData)
    }
    
    func testCompressionThreshold() {
        // Create small data that shouldn't be compressed
        let smallData = Data("Small data".utf8)
        let fileID = "small-compression-test"
        
        optimizer.resetStats()
        let chunks = optimizer.createOptimizedChunks(from: smallData, fileID: fileID)
        
        let stats = optimizer.getPerformanceStats()
        
        // Small data should not be compressed
        XCTAssertEqual(stats.compressionRatio, 0.0, accuracy: 0.01)
        
        // Verify data integrity
        let reconstructedData = chunks.reduce(Data()) { result, chunk in
            result + chunk.payload
        }
        
        XCTAssertEqual(reconstructedData, smallData)
    }
    
    // MARK: - Memory Management Tests
    
    func testChunkCaching() {
        let testData = Data("Test data for caching".utf8)
        let chunkID = "cache-test-chunk"
        
        // Cache chunk
        optimizer.cacheChunk(chunkID, data: testData)
        
        // Retrieve cached chunk
        let cachedData = optimizer.getCachedChunk(chunkID)
        
        XCTAssertNotNil(cachedData)
        XCTAssertEqual(cachedData, testData)
        
        // Test cache statistics
        let stats = optimizer.getCacheStats()
        XCTAssertGreaterThan(stats.size, 0)
        XCTAssertGreaterThan(stats.capacity, 0)
    }
    
    func testLRUCacheEviction() {
        let cacheCapacity = 5
        
        // Fill cache beyond capacity
        for i in 0..<(cacheCapacity + 2) {
            let chunkID = "lru-test-\(i)"
            let testData = Data("Test data \(i)".utf8)
            optimizer.cacheChunk(chunkID, data: testData)
        }
        
        // Wait for async cache operations
        let expectation = XCTestExpectation(description: "Cache operations completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let stats = optimizer.getCacheStats()
        XCTAssertLessThanOrEqual(stats.size, cacheCapacity)
        
        // Oldest items should be evicted
        let oldestChunk = optimizer.getCachedChunk("lru-test-0")
        XCTAssertNil(oldestChunk)
        
        // Newest items should still be cached
        let newestChunk = optimizer.getCachedChunk("lru-test-\(cacheCapacity + 1)")
        XCTAssertNotNil(newestChunk)
    }
    
    func testCacheClear() {
        // Add items to cache
        for i in 0..<5 {
            let chunkID = "clear-test-\(i)"
            let testData = Data("Test data \(i)".utf8)
            optimizer.cacheChunk(chunkID, data: testData)
        }
        
        // Clear cache
        optimizer.clearCache()
        
        // Wait for async operation
        let expectation = XCTestExpectation(description: "Cache cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Cache should be empty
        let stats = optimizer.getCacheStats()
        XCTAssertEqual(stats.size, 0)
        
        // No cached items should be retrievable
        let cachedData = optimizer.getCachedChunk("clear-test-0")
        XCTAssertNil(cachedData)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceTracking() {
        let testData = Data(repeating: 0xCC, count: 1024 * 10)  // 10KB
        let fileID = "performance-test"
        
        optimizer.resetStats()
        
        // Process multiple files to get performance data
        for i in 0..<5 {
            let chunks = optimizer.createOptimizedChunks(from: testData, fileID: "\(fileID)-\(i)")
            XCTAssertFalse(chunks.isEmpty)
        }
        
        let stats = optimizer.getPerformanceStats()
        
        XCTAssertGreaterThan(stats.averageChunkTime, 0)
        XCTAssertGreaterThan(stats.totalProcessed, 0)
        XCTAssertGreaterThanOrEqual(stats.compressionRatio, 0.0)
        XCTAssertLessThanOrEqual(stats.compressionRatio, 1.0)
    }
    
    func testMemoryPressureHandling() {
        // Fill cache to simulate memory pressure
        for i in 0..<100 {
            let chunkID = "memory-test-\(i)"
            let testData = Data(repeating: UInt8(i % 256), count: 1024)
            optimizer.cacheChunk(chunkID, data: testData)
        }
        
        // Simulate memory pressure
        let wasUnderPressure = optimizer.isUnderMemoryPressure()
        
        optimizer.handleMemoryPressure()
        
        // Wait for async operations
        let expectation = XCTestExpectation(description: "Memory pressure handled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let stats = optimizer.getCacheStats()
        XCTAssertEqual(stats.size, 0, "Cache should be cleared after memory pressure")
    }
    
    // MARK: - Adaptive Optimization Tests
    
    func testAdaptiveOptimization() {
        // Test adaptation to network conditions
        let highLatency: TimeInterval = 1.0
        let lowBandwidth: UInt64 = 1024 * 50  // 50KB/s
        
        // This should not crash and should handle the adaptation
        optimizer.adaptToPerformance(networkLatency: highLatency, bandwidth: lowBandwidth)
        
        // Test with good network conditions
        let lowLatency: TimeInterval = 0.05
        let highBandwidth: UInt64 = 1024 * 1024 * 10  // 10MB/s
        
        optimizer.adaptToPerformance(networkLatency: lowLatency, bandwidth: highBandwidth)
        
        // No specific assertions here as the adaptation is informational
        // In a real implementation, this would adjust internal parameters
    }
    
    // MARK: - Concurrent Processing Tests
    
    func testConcurrentChunkProcessing() {
        let largeData = Data(repeating: 0xDD, count: 1024 * 50)  // 50KB
        let fileID = "concurrent-test"
        
        let expectation = XCTestExpectation(description: "Concurrent processing completed")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let chunks = self.optimizer.createOptimizedChunks(from: largeData, fileID: fileID)
            
            XCTAssertFalse(chunks.isEmpty)
            
            // Verify data integrity
            let reconstructedData = chunks.reduce(Data()) { result, chunk in
                result + chunk.payload
            }
            
            XCTAssertEqual(reconstructedData, largeData)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testEmptyFileHandling() {
        let emptyData = Data()
        let fileID = "empty-test"
        
        let chunks = optimizer.createOptimizedChunks(from: emptyData, fileID: fileID)
        
        XCTAssertTrue(chunks.isEmpty)
    }
    
    func testProgressCallbackEdgeCases() {
        let testData = Data("Small test data".utf8)
        let fileID = "progress-edge-test"
        
        var progressCallbackCalled = false
        var lastProgress: Double = 0.0
        
        let chunks = optimizer.createOptimizedChunks(
            from: testData,
            fileID: fileID,
            progressCallback: { progress in
                progressCallbackCalled = true
                lastProgress = progress
            }
        )
        
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertTrue(progressCallbackCalled)
        XCTAssertEqual(lastProgress, 1.0, accuracy: 0.001)
    }
    
    // MARK: - Integration Tests
    
    func testOptimizerIntegrationWithFileTransfer() {
        let testData = Data("Integration test data for file transfer".utf8)
        let fileID = "integration-test"
        
        let chunks = optimizer.createOptimizedChunks(from: testData, fileID: fileID)
        
        // Verify chunks are compatible with file transfer protocol
        for chunk in chunks {
            XCTAssertEqual(chunk.fileID, fileID)
            XCTAssertLessThanOrEqual(chunk.payload.count, FileTransferConstants.CHUNK_SIZE)
            XCTAssertFalse(chunk.chunkHash.isEmpty)
            XCTAssertFalse(chunk.chunkMAC.isEmpty)
        }
        
        // Verify last chunk is marked correctly
        if let lastChunk = chunks.last {
            XCTAssertTrue(lastChunk.isLastChunk)
        }
        
        // Cache some chunks for testing
        for (index, chunk) in chunks.enumerated() {
            let cacheKey = "\(fileID)_\(index)"
            optimizer.cacheChunk(cacheKey, data: chunk.payload)
        }
        
        // Verify cached chunks can be retrieved
        for (index, chunk) in chunks.enumerated() {
            let cacheKey = "\(fileID)_\(index)"
            let cachedData = optimizer.getCachedChunk(cacheKey)
            XCTAssertEqual(cachedData, chunk.payload)
        }
    }
}