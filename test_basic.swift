#!/usr/bin/env swift

import Foundation
import CryptoKit

// Basic BitShare Protocol Test
print("🚀 BitShare Basic Protocol Test")
print("================================")

// Test 1: File Chunking Logic
print("\n📦 Test 1: File Chunking Logic")
let testData = Data("This is a test file content for chunking validation.".utf8)
let chunkSize = 480 // BitShare's BLE-optimized chunk size

let totalChunks = (testData.count + chunkSize - 1) / chunkSize
print("• File size: \(testData.count) bytes")
print("• Chunk size: \(chunkSize) bytes")
print("• Total chunks: \(totalChunks)")

// Test 2: Hash Calculation
print("\n🔐 Test 2: Hash Calculation")
let hash = SHA256.hash(data: testData)
let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
print("• SHA-256 hash: \(hashString)")

// Test 3: Basic Protocol Structure
print("\n📡 Test 3: Protocol Structure")
struct MockFileManifest {
    let fileID: String
    let fileName: String
    let fileSize: UInt64
    let sha256Hash: String
    let timestamp: UInt64
    
    init(fileID: String, fileName: String, fileSize: UInt64, sha256Hash: String) {
        self.fileID = fileID
        self.fileName = fileName
        self.fileSize = fileSize
        self.sha256Hash = sha256Hash
        self.timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
    }
}

let manifest = MockFileManifest(
    fileID: UUID().uuidString,
    fileName: "test.txt",
    fileSize: UInt64(testData.count),
    sha256Hash: hashString
)

print("• File ID: \(manifest.fileID)")
print("• File Name: \(manifest.fileName)")
print("• File Size: \(manifest.fileSize)")
print("• Timestamp: \(manifest.timestamp)")

// Test 4: Chunk Creation
print("\n🔧 Test 4: Chunk Creation")
var chunks: [Data] = []
for i in 0..<totalChunks {
    let start = i * chunkSize
    let end = min(start + chunkSize, testData.count)
    let chunkData = testData.subdata(in: start..<end)
    chunks.append(chunkData)
    print("• Chunk \(i): \(chunkData.count) bytes")
}

// Test 5: Chunk Reassembly
print("\n🔄 Test 5: Chunk Reassembly")
let reassembledData = chunks.reduce(Data()) { result, chunk in
    result + chunk
}

let reassembledHash = SHA256.hash(data: reassembledData)
let reassembledHashString = reassembledHash.compactMap { String(format: "%02x", $0) }.joined()

print("• Reassembled size: \(reassembledData.count) bytes")
print("• Reassembled hash: \(reassembledHashString)")
print("• Hash match: \(hashString == reassembledHashString ? "✅ PASS" : "❌ FAIL")")
print("• Data integrity: \(testData == reassembledData ? "✅ PASS" : "❌ FAIL")")

// Test 6: Performance Test
print("\n⚡ Test 6: Performance Test")
let largeData = Data(repeating: 0xAB, count: 1024 * 100) // 100KB
let startTime = Date()

let largeChunks = (largeData.count + chunkSize - 1) / chunkSize
for i in 0..<largeChunks {
    let start = i * chunkSize
    let end = min(start + chunkSize, largeData.count)
    let _ = largeData.subdata(in: start..<end)
}

let processingTime = Date().timeIntervalSince(startTime)
let throughput = Double(largeData.count) / processingTime

print("• Large file size: \(largeData.count) bytes")
print("• Processing time: \(String(format: "%.3f", processingTime)) seconds")
print("• Throughput: \(String(format: "%.2f", throughput / 1024)) KB/s")

print("\n🎉 Basic Protocol Test Complete!")
print("All core chunking and hashing logic appears to be working correctly.")