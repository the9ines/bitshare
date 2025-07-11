//
// FileTransferPerformanceTests.swift
// bitshareTests
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import XCTest
import CryptoKit
@testable import bitchat

class FileTransferPerformanceTests: XCTestCase {
    
    var optimizer: FileChunkOptimizer!
    var fileTransferManager: FileTransferManager!
    
    override func setUp() {
        super.setUp()
        optimizer = FileChunkOptimizer.shared
        fileTransferManager = FileTransferManager.shared
        
        optimizer.resetStats()
        optimizer.clearCache()
    }
    
    override func tearDown() {
        optimizer.clearCache()
        super.tearDown()
    }
    
    // MARK: - Chunking Performance Tests
    
    func testChunkingPerformance() {
        let fileSize = 1024 * 1024 * 5  // 5MB
        let testData = Data(repeating: 0xAA, count: fileSize)
        let fileID = "performance-test-chunking"
        
        let startTime = Date()
        
        let chunks = optimizer.createOptimizedChunks(from: testData, fileID: fileID)
        
        let chunkingTime = Date().timeIntervalSince(startTime)
        
        // Performance requirements
        XCTAssertLessThan(chunkingTime, 2.0, "5MB file should be chunked in under 2 seconds")
        XCTAssertFalse(chunks.isEmpty)
        
        // Verify chunking throughput
        let throughput = Double(fileSize) / chunkingTime  // bytes per second
        XCTAssertGreaterThan(throughput, 1024 * 1024 * 2, "Chunking throughput should be > 2MB/s")
        
        print("📊 Chunking Performance: \(String(format: "%.2f", chunkingTime))s for \(fileSize) bytes")
        print("📊 Chunking Throughput: \(String(format: "%.2f", throughput / (1024 * 1024))) MB/s")
    }
    
    func testEncodingPerformance() {
        let chunkCount = 100
        let testData = Data(repeating: 0xBB, count: FileTransferConstants.CHUNK_SIZE)
        
        var chunks: [FILE_CHUNK] = []
        for i in 0..<chunkCount {
            let chunk = FILE_CHUNK(
                fileID: "encoding-test",
                chunkIndex: UInt32(i),
                payload: testData,
                isLastChunk: i == chunkCount - 1
            )
            chunks.append(chunk)
        }
        
        let startTime = Date()
        
        var encodedCount = 0
        for chunk in chunks {
            if chunk.toBinaryPayload() != nil {
                encodedCount += 1
            }
        }
        
        let encodingTime = Date().timeIntervalSince(startTime)
        
        XCTAssertEqual(encodedCount, chunkCount)
        XCTAssertLessThan(encodingTime, 0.5, "100 chunks should encode in under 0.5 seconds")
        
        let chunksPerSecond = Double(chunkCount) / encodingTime
        XCTAssertGreaterThan(chunksPerSecond, 200, "Should encode > 200 chunks per second")
        
        print("📊 Encoding Performance: \(String(format: "%.2f", encodingTime))s for \(chunkCount) chunks")
        print("📊 Encoding Rate: \(String(format: "%.0f", chunksPerSecond)) chunks/s")
    }
    
    func testDecodingPerformance() {
        let chunkCount = 100
        let testData = Data(repeating: 0xCC, count: FileTransferConstants.CHUNK_SIZE)
        
        // Create and encode chunks
        var encodedChunks: [Data] = []
        for i in 0..<chunkCount {
            let chunk = FILE_CHUNK(
                fileID: "decoding-test",
                chunkIndex: UInt32(i),
                payload: testData,
                isLastChunk: i == chunkCount - 1
            )
            
            if let encoded = chunk.toBinaryPayload() {
                encodedChunks.append(encoded)
            }
        }
        
        let startTime = Date()
        
        var decodedCount = 0
        for encodedChunk in encodedChunks {
            if FILE_CHUNK.fromBinaryPayload(encodedChunk) != nil {
                decodedCount += 1
            }
        }
        
        let decodingTime = Date().timeIntervalSince(startTime)
        
        XCTAssertEqual(decodedCount, chunkCount)
        XCTAssertLessThan(decodingTime, 0.5, "100 chunks should decode in under 0.5 seconds")
        
        let chunksPerSecond = Double(chunkCount) / decodingTime
        XCTAssertGreaterThan(chunksPerSecond, 200, "Should decode > 200 chunks per second")
        
        print("📊 Decoding Performance: \(String(format: "%.2f", decodingTime))s for \(chunkCount) chunks")
        print("📊 Decoding Rate: \(String(format: "%.0f", chunksPerSecond)) chunks/s")
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageUnderLoad() {
        let largeFileSize = 1024 * 1024 * 10  // 10MB
        let testData = Data(repeating: 0xDD, count: largeFileSize)
        
        let initialMemory = getCurrentMemoryUsage()
        
        // Process large file
        let chunks = optimizer.createOptimizedChunks(from: testData, fileID: "memory-test")
        
        let peakMemory = getCurrentMemoryUsage()
        let memoryIncrease = peakMemory - initialMemory
        
        // Memory usage should be reasonable
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, "Memory increase should be < 50MB for 10MB file")
        
        // Process chunks to verify memory cleanup
        var processedChunks = 0
        for chunk in chunks {
            if chunk.toBinaryPayload() != nil {
                processedChunks += 1
            }
        }
        
        XCTAssertEqual(processedChunks, chunks.count)
        
        print("📊 Memory Usage: Initial=\(initialMemory/1024/1024)MB, Peak=\(peakMemory/1024/1024)MB, Increase=\(memoryIncrease/1024/1024)MB")
    }
    
    func testCachePerformance() {
        let itemCount = 1000
        let testData = Data(repeating: 0xEE, count: 1024)  // 1KB per item
        
        let startTime = Date()
        
        // Cache items
        for i in 0..<itemCount {
            let chunkID = "cache-perf-\(i)"
            optimizer.cacheChunk(chunkID, data: testData)
        }
        
        let cachingTime = Date().timeIntervalSince(startTime)
        
        // Retrieve items
        let retrievalStartTime = Date()
        
        var retrievedCount = 0
        for i in 0..<itemCount {
            let chunkID = "cache-perf-\(i)"
            if optimizer.getCachedChunk(chunkID) != nil {
                retrievedCount += 1
            }
        }
        
        let retrievalTime = Date().timeIntervalSince(retrievalStartTime)
        
        XCTAssertLessThan(cachingTime, 2.0, "Caching 1000 items should take < 2 seconds")
        XCTAssertLessThan(retrievalTime, 1.0, "Retrieving 1000 items should take < 1 second")
        
        let cachingRate = Double(itemCount) / cachingTime
        let retrievalRate = Double(retrievedCount) / retrievalTime
        
        XCTAssertGreaterThan(cachingRate, 500, "Should cache > 500 items per second")
        XCTAssertGreaterThan(retrievalRate, 1000, "Should retrieve > 1000 items per second")
        
        print("📊 Cache Performance: Caching=\(String(format: "%.0f", cachingRate)) items/s, Retrieval=\(String(format: "%.0f", retrievalRate)) items/s")
    }
    
    // MARK: - Concurrent Performance Tests
    
    func testConcurrentChunkProcessing() {
        let fileSize = 1024 * 1024 * 2  // 2MB
        let testData = Data(repeating: 0xFF, count: fileSize)
        let fileID = "concurrent-test"
        
        let startTime = Date()
        
        // Test concurrent chunk creation
        let expectation = XCTestExpectation(description: "Concurrent processing completed")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let chunks = self.optimizer.createOptimizedChunks(from: testData, fileID: fileID)
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            XCTAssertFalse(chunks.isEmpty)
            XCTAssertLessThan(processingTime, 3.0, "Concurrent processing should be fast")
            
            // Verify all chunks are valid
            for chunk in chunks {
                XCTAssertEqual(chunk.fileID, fileID)
                XCTAssertFalse(chunk.chunkHash.isEmpty)
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testConcurrentCacheOperations() {
        let operationCount = 500
        let testData = Data(repeating: 0x11, count: 512)
        
        let startTime = Date()
        
        // Concurrent cache operations
        let cacheExpectation = XCTestExpectation(description: "Concurrent cache operations completed")
        
        let dispatchGroup = DispatchGroup()
        
        // Concurrent writes
        for i in 0..<operationCount {
            dispatchGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let chunkID = "concurrent-cache-\(i)"
                self.optimizer.cacheChunk(chunkID, data: testData)
                dispatchGroup.leave()
            }
        }
        
        // Concurrent reads
        for i in 0..<operationCount {
            dispatchGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let chunkID = "concurrent-cache-\(i)"
                _ = self.optimizer.getCachedChunk(chunkID)
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            let totalTime = Date().timeIntervalSince(startTime)
            
            XCTAssertLessThan(totalTime, 5.0, "Concurrent cache operations should complete quickly")
            
            let operationsPerSecond = Double(operationCount * 2) / totalTime
            XCTAssertGreaterThan(operationsPerSecond, 200, "Should handle > 200 operations per second")
            
            print("📊 Concurrent Cache Performance: \(String(format: "%.0f", operationsPerSecond)) ops/s")
            
            cacheExpectation.fulfill()
        }
        
        wait(for: [cacheExpectation], timeout: 15.0)
    }
    
    // MARK: - Compression Performance Tests
    
    func testCompressionPerformance() {
        // Create compressible data
        let baseData = Data("This is a test string that should compress well when repeated many times. ".utf8)
        let repetitions = 1000
        var compressibleData = Data()
        
        for _ in 0..<repetitions {
            compressibleData.append(baseData)
        }
        
        let fileID = "compression-perf-test"
        
        optimizer.resetStats()
        
        let startTime = Date()
        
        let chunks = optimizer.createOptimizedChunks(from: compressibleData, fileID: fileID)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertLessThan(processingTime, 3.0, "Compression processing should be reasonably fast")
        
        let stats = optimizer.getPerformanceStats()
        
        // Verify compression was attempted
        XCTAssertGreaterThan(stats.totalProcessed, 0)
        
        // Verify data integrity
        let reconstructedData = chunks.reduce(Data()) { result, chunk in
            result + chunk.payload
        }
        
        XCTAssertEqual(reconstructedData, compressibleData)
        
        print("📊 Compression Performance: \(String(format: "%.2f", processingTime))s for \(compressibleData.count) bytes")
        print("📊 Compression Stats: \(stats.totalProcessed) chunks processed, \(String(format: "%.2f", stats.compressionRatio * 100))% compression ratio")
    }
    
    // MARK: - Network Simulation Performance Tests
    
    func testHighLatencyNetworkSimulation() {
        let testData = Data(repeating: 0x22, count: 1024 * 10)  // 10KB
        
        // Simulate high latency network conditions
        let highLatency: TimeInterval = 0.8
        let lowBandwidth: UInt64 = 1024 * 50  // 50KB/s
        
        optimizer.adaptToPerformance(networkLatency: highLatency, bandwidth: lowBandwidth)
        
        let startTime = Date()
        
        let chunks = optimizer.createOptimizedChunks(from: testData, fileID: "high-latency-test")
        
        let adaptedTime = Date().timeIntervalSince(startTime)
        
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertLessThan(adaptedTime, 2.0, "Should adapt to high latency conditions efficiently")
        
        // Verify chunks are optimized for high latency
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.payload.count, FileTransferConstants.CHUNK_SIZE)
        }
        
        print("📊 High Latency Performance: \(String(format: "%.2f", adaptedTime))s with \(highLatency)s latency")
    }
    
    func testLowBandwidthNetworkSimulation() {
        let testData = Data(repeating: 0x33, count: 1024 * 20)  // 20KB
        
        // Simulate low bandwidth network conditions
        let lowLatency: TimeInterval = 0.05
        let lowBandwidth: UInt64 = 1024 * 10  // 10KB/s
        
        optimizer.adaptToPerformance(networkLatency: lowLatency, bandwidth: lowBandwidth)
        
        let startTime = Date()
        
        let chunks = optimizer.createOptimizedChunks(from: testData, fileID: "low-bandwidth-test")
        
        let adaptedTime = Date().timeIntervalSince(startTime)
        
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertLessThan(adaptedTime, 2.0, "Should adapt to low bandwidth conditions efficiently")
        
        print("📊 Low Bandwidth Performance: \(String(format: "%.2f", adaptedTime))s with \(lowBandwidth) bytes/s bandwidth")
    }
    
    // MARK: - Scalability Tests
    
    func testScalabilityWithMultipleFiles() {
        let fileCount = 10
        let fileSize = 1024 * 100  // 100KB each
        
        let startTime = Date()
        
        var allChunks: [FILE_CHUNK] = []
        
        for i in 0..<fileCount {
            let testData = Data(repeating: UInt8(i % 256), count: fileSize)
            let fileID = "scalability-test-\(i)"
            
            let chunks = optimizer.createOptimizedChunks(from: testData, fileID: fileID)
            allChunks.append(contentsOf: chunks)
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        XCTAssertFalse(allChunks.isEmpty)
        XCTAssertLessThan(totalTime, 5.0, "Processing multiple files should scale well")
        
        let totalDataSize = fileCount * fileSize
        let throughput = Double(totalDataSize) / totalTime
        
        XCTAssertGreaterThan(throughput, 1024 * 200, "Should maintain > 200KB/s throughput with multiple files")
        
        print("📊 Scalability Performance: \(fileCount) files, \(String(format: "%.2f", totalTime))s total, \(String(format: "%.2f", throughput / 1024)) KB/s throughput")
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return 0
        }
        
        return Int(info.resident_size)
    }
    
    // MARK: - Stress Tests
    
    func testStressTestLargeFiles() {
        measure {
            let largeFileSize = 1024 * 1024 * 20  // 20MB
            let testData = Data(repeating: 0x44, count: largeFileSize)
            
            let chunks = optimizer.createOptimizedChunks(from: testData, fileID: "stress-test")
            
            XCTAssertFalse(chunks.isEmpty)
            
            // Verify data integrity
            let reconstructedData = chunks.reduce(Data()) { result, chunk in
                result + chunk.payload
            }
            
            XCTAssertEqual(reconstructedData.count, testData.count)
        }
    }
    
    func testStressTestManySmallFiles() {
        measure {
            let fileCount = 100
            let fileSize = 1024 * 5  // 5KB each
            
            var totalChunks = 0
            
            for i in 0..<fileCount {
                let testData = Data(repeating: UInt8(i % 256), count: fileSize)
                let chunks = optimizer.createOptimizedChunks(from: testData, fileID: "stress-small-\(i)")
                totalChunks += chunks.count
            }
            
            XCTAssertGreaterThan(totalChunks, 0)
        }
    }
}