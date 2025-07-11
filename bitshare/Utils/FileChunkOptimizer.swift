//
// FileChunkOptimizer.swift
// bitshare
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation
import CryptoKit

/// Phase 3 Week 8: Advanced file chunking optimization and memory management
class FileChunkOptimizer {
    static let shared = FileChunkOptimizer()
    
    // Memory management constants
    private let maxConcurrentChunks = 10  // Limit concurrent chunk processing
    private let chunkCacheSize = 50       // Maximum chunks to keep in memory
    private let compressionThreshold = 1024 * 10  // 10KB - compress larger chunks
    
    // Performance monitoring
    private var chunkProcessingTimes: [TimeInterval] = []
    private var compressionStats: (compressed: Int, uncompressed: Int) = (0, 0)
    
    // Memory-efficient chunk cache
    private var chunkCache: [String: Data] = [:]
    private var chunkAccessOrder: [String] = []
    private let cacheQueue = DispatchQueue(label: "bitshare.chunkCache", qos: .utility)
    
    private init() {}
    
    // MARK: - Optimized File Chunking
    
    /// Create optimized file chunks with compression and memory management
    func createOptimizedChunks(from fileData: Data, fileID: String, progressCallback: @escaping (Double) -> Void = { _ in }) -> [FILE_CHUNK] {
        let startTime = Date()
        
        // Calculate optimal chunk size based on file size and network conditions
        let optimalChunkSize = calculateOptimalChunkSize(fileSize: fileData.count)
        let totalChunks = (fileData.count + optimalChunkSize - 1) / optimalChunkSize
        
        var chunks: [FILE_CHUNK] = []
        chunks.reserveCapacity(totalChunks)  // Pre-allocate for performance
        
        // Process chunks in batches to manage memory
        let batchSize = min(maxConcurrentChunks, totalChunks)
        
        for batchStart in stride(from: 0, to: totalChunks, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, totalChunks)
            
            // Process batch concurrently
            let batchChunks = processBatch(
                fileData: fileData,
                fileID: fileID,
                startIndex: batchStart,
                endIndex: batchEnd,
                chunkSize: optimalChunkSize,
                totalChunks: UInt32(totalChunks)
            )
            
            chunks.append(contentsOf: batchChunks)
            
            // Update progress
            let progress = Double(batchEnd) / Double(totalChunks)
            progressCallback(progress)
            
            // Yield to other operations
            if batchEnd < totalChunks {
                Thread.sleep(forTimeInterval: 0.001) // 1ms yield
            }
        }
        
        // Record performance metrics
        let processingTime = Date().timeIntervalSince(startTime)
        chunkProcessingTimes.append(processingTime)
        
        // Keep only recent performance data
        if chunkProcessingTimes.count > 100 {
            chunkProcessingTimes.removeFirst(50)
        }
        
        print("📊 Chunking completed: \(chunks.count) chunks in \(String(format: "%.2f", processingTime))s")
        
        return chunks
    }
    
    /// Process a batch of chunks concurrently
    private func processBatch(fileData: Data, fileID: String, startIndex: Int, endIndex: Int, chunkSize: Int, totalChunks: UInt32) -> [FILE_CHUNK] {
        let group = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "bitshare.chunkProcessing", qos: .userInitiated, attributes: .concurrent)
        var batchChunks: [FILE_CHUNK?] = Array(repeating: nil, count: endIndex - startIndex)
        
        for i in startIndex..<endIndex {
            group.enter()
            concurrentQueue.async {
                defer { group.leave() }
                
                let batchIndex = i - startIndex
                let start = i * chunkSize
                let end = min(start + chunkSize, fileData.count)
                let chunkData = fileData.subdata(in: start..<end)
                
                // Apply compression if beneficial
                let optimizedData = self.optimizeChunkData(chunkData)
                let isLastChunk = (i == totalChunks - 1)
                
                let chunk = FILE_CHUNK(
                    fileID: fileID,
                    chunkIndex: UInt32(i),
                    payload: optimizedData,
                    isLastChunk: isLastChunk
                )
                
                batchChunks[batchIndex] = chunk
            }
        }
        
        group.wait()
        return batchChunks.compactMap { $0 }
    }
    
    /// Calculate optimal chunk size based on file characteristics and network conditions
    private func calculateOptimalChunkSize(fileSize: Int) -> Int {
        let baseChunkSize = FileTransferConstants.CHUNK_SIZE // 480 bytes
        
        // For very small files, use smaller chunks for faster initial transmission
        if fileSize < 1024 * 10 { // < 10KB
            return min(baseChunkSize / 2, fileSize)
        }
        
        // For medium files, use standard chunk size
        if fileSize < 1024 * 1024 { // < 1MB
            return baseChunkSize
        }
        
        // For larger files, consider slightly larger chunks for efficiency
        // but stay within BLE MTU constraints
        if fileSize > 1024 * 1024 * 10 { // > 10MB
            return min(baseChunkSize + 32, 512) // Up to 512 bytes max
        }
        
        return baseChunkSize
    }
    
    /// Optimize chunk data with compression if beneficial
    private func optimizeChunkData(_ data: Data) -> Data {
        // Only attempt compression for chunks above threshold
        guard data.count > compressionThreshold else {
            compressionStats.uncompressed += 1
            return data
        }
        
        // Try LZ4 compression (fast)
        if let compressed = try? data.compressed(using: .lz4),
           compressed.count < data.count * 9 / 10 { // Only if >10% reduction
            compressionStats.compressed += 1
            return compressed
        }
        
        compressionStats.uncompressed += 1
        return data
    }
    
    // MARK: - Memory Management
    
    /// Add chunk to memory cache with LRU eviction
    func cacheChunk(_ chunkID: String, data: Data) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Remove if already exists to update position
            if let index = self.chunkAccessOrder.firstIndex(of: chunkID) {
                self.chunkAccessOrder.remove(at: index)
            }
            
            // Add to cache and access order
            self.chunkCache[chunkID] = data
            self.chunkAccessOrder.append(chunkID)
            
            // Evict oldest if cache is full
            while self.chunkCache.count > self.chunkCacheSize {
                if let oldestID = self.chunkAccessOrder.first {
                    self.chunkCache.removeValue(forKey: oldestID)
                    self.chunkAccessOrder.removeFirst()
                }
            }
        }
    }
    
    /// Retrieve chunk from cache
    func getCachedChunk(_ chunkID: String) -> Data? {
        return cacheQueue.sync {
            if let data = chunkCache[chunkID] {
                // Update access order (move to end)
                if let index = chunkAccessOrder.firstIndex(of: chunkID) {
                    chunkAccessOrder.remove(at: index)
                    chunkAccessOrder.append(chunkID)
                }
                return data
            }
            return nil
        }
    }
    
    /// Clear cache to free memory
    func clearCache() {
        cacheQueue.async { [weak self] in
            self?.chunkCache.removeAll()
            self?.chunkAccessOrder.removeAll()
        }
    }
    
    /// Get cache statistics
    func getCacheStats() -> (size: Int, capacity: Int, hitRate: Double) {
        return cacheQueue.sync {
            let hitRate = chunkCache.isEmpty ? 0.0 : Double(chunkCache.count) / Double(chunkCacheSize)
            return (chunkCache.count, chunkCacheSize, hitRate)
        }
    }
    
    // MARK: - Performance Analytics
    
    /// Get performance statistics
    func getPerformanceStats() -> (averageChunkTime: TimeInterval, compressionRatio: Double, totalProcessed: Int) {
        let avgTime = chunkProcessingTimes.isEmpty ? 0 : chunkProcessingTimes.reduce(0, +) / Double(chunkProcessingTimes.count)
        let totalChunks = compressionStats.compressed + compressionStats.uncompressed
        let compressionRatio = totalChunks > 0 ? Double(compressionStats.compressed) / Double(totalChunks) : 0
        
        return (avgTime, compressionRatio, totalChunks)
    }
    
    /// Reset performance statistics
    func resetStats() {
        chunkProcessingTimes.removeAll()
        compressionStats = (0, 0)
    }
    
    // MARK: - Adaptive Optimization
    
    /// Adjust parameters based on performance feedback
    func adaptToPerformance(networkLatency: TimeInterval, bandwidth: UInt64) {
        // This could be enhanced with machine learning for optimal parameter selection
        
        // For high latency networks, prefer larger chunks
        if networkLatency > 0.5 { // 500ms+
            // Could increase chunk size slightly within BLE limits
        }
        
        // For low bandwidth, enable more aggressive compression
        if bandwidth < 1024 * 100 { // < 100KB/s
            // Could lower compression threshold
        }
    }
}

// MARK: - Memory Pressure Monitoring

extension FileChunkOptimizer {
    /// Monitor and respond to memory pressure
    func handleMemoryPressure() {
        // Clear non-essential caches
        clearCache()
        
        // Force garbage collection hint
        autoreleasepool {
            // Any temporary objects will be cleaned up
        }
        
        print("⚠️ Memory pressure detected - cleared chunk cache")
    }
    
    /// Check if system is under memory pressure
    func isUnderMemoryPressure() -> Bool {
        // Simple heuristic - in production this could use more sophisticated metrics
        let stats = getCacheStats()
        return stats.size > stats.capacity * 9 / 10  // 90% cache utilization
    }
}