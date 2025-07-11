//
// FileTransferProtocolTests.swift
// bitshareTests
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import XCTest
import CryptoKit
@testable import bitchat

class FileTransferProtocolTests: XCTestCase {
    
    // MARK: - FILE_MANIFEST Tests
    
    func testFileManifestEncoding() {
        let manifest = FILE_MANIFEST(
            fileID: "test-file-123",
            fileName: "test.txt",
            fileSize: 1024,
            sha256Hash: "abcdef123456",
            senderID: "sender-123"
        )
        
        guard let encoded = manifest.toBinaryPayload() else {
            XCTFail("Failed to encode FILE_MANIFEST")
            return
        }
        
        XCTAssertGreaterThan(encoded.count, 32, "Encoded manifest should be larger than header")
        
        guard let decoded = FILE_MANIFEST.fromBinaryPayload(encoded) else {
            XCTFail("Failed to decode FILE_MANIFEST")
            return
        }
        
        XCTAssertEqual(decoded.fileID, manifest.fileID)
        XCTAssertEqual(decoded.fileName, manifest.fileName)
        XCTAssertEqual(decoded.fileSize, manifest.fileSize)
        XCTAssertEqual(decoded.sha256Hash, manifest.sha256Hash)
        XCTAssertEqual(decoded.senderID, manifest.senderID)
    }
    
    func testFileManifestWithLongFileName() {
        let longFileName = String(repeating: "a", count: 255)
        let manifest = FILE_MANIFEST(
            fileID: "test-file-456",
            fileName: longFileName,
            fileSize: 2048,
            sha256Hash: "fedcba654321",
            senderID: "sender-456"
        )
        
        guard let encoded = manifest.toBinaryPayload() else {
            XCTFail("Failed to encode FILE_MANIFEST with long filename")
            return
        }
        
        guard let decoded = FILE_MANIFEST.fromBinaryPayload(encoded) else {
            XCTFail("Failed to decode FILE_MANIFEST with long filename")
            return
        }
        
        XCTAssertEqual(decoded.fileName, longFileName)
    }
    
    func testFileManifestInvalidData() {
        // Test with empty data
        XCTAssertNil(FILE_MANIFEST.fromBinaryPayload(Data()))
        
        // Test with truncated data
        let truncated = Data(repeating: 0, count: 20)
        XCTAssertNil(FILE_MANIFEST.fromBinaryPayload(truncated))
    }
    
    // MARK: - FILE_CHUNK Tests
    
    func testFileChunkEncoding() {
        let testData = Data("Hello, World!".utf8)
        let chunk = FILE_CHUNK(
            fileID: "test-file-789",
            chunkIndex: 42,
            payload: testData,
            isLastChunk: false
        )
        
        guard let encoded = chunk.toBinaryPayload() else {
            XCTFail("Failed to encode FILE_CHUNK")
            return
        }
        
        XCTAssertGreaterThan(encoded.count, 64, "Encoded chunk should be larger than header")
        
        guard let decoded = FILE_CHUNK.fromBinaryPayload(encoded) else {
            XCTFail("Failed to decode FILE_CHUNK")
            return
        }
        
        XCTAssertEqual(decoded.fileID, chunk.fileID)
        XCTAssertEqual(decoded.chunkIndex, chunk.chunkIndex)
        XCTAssertEqual(decoded.payload, chunk.payload)
        XCTAssertEqual(decoded.isLastChunk, chunk.isLastChunk)
    }
    
    func testFileChunkWithMaxPayload() {
        let maxPayload = Data(repeating: 0xFF, count: FileTransferConstants.CHUNK_SIZE)
        let chunk = FILE_CHUNK(
            fileID: "test-file-max",
            chunkIndex: 0,
            payload: maxPayload,
            isLastChunk: true
        )
        
        guard let encoded = chunk.toBinaryPayload() else {
            XCTFail("Failed to encode FILE_CHUNK with max payload")
            return
        }
        
        guard let decoded = FILE_CHUNK.fromBinaryPayload(encoded) else {
            XCTFail("Failed to decode FILE_CHUNK with max payload")
            return
        }
        
        XCTAssertEqual(decoded.payload.count, FileTransferConstants.CHUNK_SIZE)
        XCTAssertEqual(decoded.isLastChunk, true)
    }
    
    func testFileChunkIntegrity() {
        let testData = Data("Test chunk data".utf8)
        let chunk = FILE_CHUNK(
            fileID: "integrity-test",
            chunkIndex: 1,
            payload: testData
        )
        
        // Verify hash is calculated correctly
        let expectedHash = SHA256.hash(data: testData)
        let expectedHashString = expectedHash.compactMap { String(format: "%02x", $0) }.joined()
        
        XCTAssertEqual(chunk.chunkHash, expectedHashString)
        XCTAssertFalse(chunk.chunkMAC.isEmpty)
    }
    
    // MARK: - FILE_ACK Tests
    
    func testFileAckEncoding() {
        let acknowledgedChunks: Set<UInt32> = [0, 1, 2, 5, 10]
        let ack = FILE_ACK(
            fileID: "test-file-ack",
            receiverID: "receiver-123",
            acknowledgedChunks: acknowledgedChunks,
            totalChunks: 20
        )
        
        guard let encoded = ack.toBinaryPayload() else {
            XCTFail("Failed to encode FILE_ACK")
            return
        }
        
        XCTAssertGreaterThan(encoded.count, 58, "Encoded ACK should be larger than minimum header")
        
        guard let decoded = FILE_ACK.fromBinaryPayload(encoded) else {
            XCTFail("Failed to decode FILE_ACK")
            return
        }
        
        XCTAssertEqual(decoded.fileID, ack.fileID)
        XCTAssertEqual(decoded.receiverID, ack.receiverID)
        XCTAssertEqual(decoded.totalReceived, UInt32(acknowledgedChunks.count))
    }
    
    func testFileAckBitmap() {
        let acknowledgedChunks: Set<UInt32> = [0, 2, 4, 6, 8, 10]
        let totalChunks: UInt32 = 12
        
        let bitmap = FILE_ACK.createBitmap(from: acknowledgedChunks, totalChunks: totalChunks)
        let extractedChunks = FILE_ACK.chunksFromBitmap(bitmap, totalChunks: totalChunks)
        
        XCTAssertEqual(extractedChunks, acknowledgedChunks)
    }
    
    func testFileAckCompleteness() {
        let totalChunks: UInt32 = 5
        let allChunks: Set<UInt32> = Set(0..<totalChunks)
        
        let ack = FILE_ACK(
            fileID: "complete-test",
            receiverID: "receiver-456",
            acknowledgedChunks: allChunks,
            totalChunks: totalChunks
        )
        
        XCTAssertTrue(ack.transferComplete)
        XCTAssertTrue(ack.missingChunks.isEmpty)
    }
    
    // MARK: - Integration Tests
    
    func testFileTransferProtocolFlow() {
        // 1. Create manifest
        let testFileData = Data("This is a test file for protocol flow testing.".utf8)
        let fileHash = SHA256.hash(data: testFileData).compactMap { String(format: "%02x", $0) }.joined()
        
        let manifest = FILE_MANIFEST(
            fileID: "flow-test-123",
            fileName: "flow_test.txt",
            fileSize: UInt64(testFileData.count),
            sha256Hash: fileHash,
            senderID: "sender-flow"
        )
        
        // 2. Create chunks
        let chunkSize = FileTransferConstants.CHUNK_SIZE
        let totalChunks = (testFileData.count + chunkSize - 1) / chunkSize
        var chunks: [FILE_CHUNK] = []
        
        for i in 0..<totalChunks {
            let start = i * chunkSize
            let end = min(start + chunkSize, testFileData.count)
            let chunkData = testFileData.subdata(in: start..<end)
            let isLastChunk = (i == totalChunks - 1)
            
            let chunk = FILE_CHUNK(
                fileID: manifest.fileID,
                chunkIndex: UInt32(i),
                payload: chunkData,
                isLastChunk: isLastChunk
            )
            chunks.append(chunk)
        }
        
        // 3. Test encoding/decoding of all chunks
        var reconstructedData = Data()
        for chunk in chunks {
            guard let encoded = chunk.toBinaryPayload(),
                  let decoded = FILE_CHUNK.fromBinaryPayload(encoded) else {
                XCTFail("Failed to encode/decode chunk \(chunk.chunkIndex)")
                return
            }
            
            reconstructedData.append(decoded.payload)
        }
        
        // 4. Verify reconstructed data matches original
        XCTAssertEqual(reconstructedData, testFileData)
        
        // 5. Create ACK for all chunks
        let acknowledgedChunks = Set(chunks.map { $0.chunkIndex })
        let ack = FILE_ACK(
            fileID: manifest.fileID,
            receiverID: "receiver-flow",
            acknowledgedChunks: acknowledgedChunks,
            totalChunks: manifest.totalChunks
        )
        
        XCTAssertTrue(ack.transferComplete)
        XCTAssertEqual(ack.totalReceived, manifest.totalChunks)
    }
    
    // MARK: - Performance Tests
    
    func testLargeFileChunking() {
        let largeData = Data(repeating: 0xAA, count: 1024 * 1024) // 1MB
        let fileHash = SHA256.hash(data: largeData).compactMap { String(format: "%02x", $0) }.joined()
        
        let manifest = FILE_MANIFEST(
            fileID: "large-file-test",
            fileName: "large_test.bin",
            fileSize: UInt64(largeData.count),
            sha256Hash: fileHash,
            senderID: "sender-large"
        )
        
        let startTime = Date()
        
        // Create chunks
        let chunkSize = FileTransferConstants.CHUNK_SIZE
        let totalChunks = (largeData.count + chunkSize - 1) / chunkSize
        var chunks: [FILE_CHUNK] = []
        
        for i in 0..<totalChunks {
            let start = i * chunkSize
            let end = min(start + chunkSize, largeData.count)
            let chunkData = largeData.subdata(in: start..<end)
            
            let chunk = FILE_CHUNK(
                fileID: manifest.fileID,
                chunkIndex: UInt32(i),
                payload: chunkData,
                isLastChunk: (i == totalChunks - 1)
            )
            chunks.append(chunk)
        }
        
        let chunkingTime = Date().timeIntervalSince(startTime)
        
        // Verify chunking performance (should be fast)
        XCTAssertLessThan(chunkingTime, 1.0, "Chunking 1MB should take less than 1 second")
        XCTAssertEqual(chunks.count, totalChunks)
        
        // Test encoding performance
        let encodingStartTime = Date()
        var encodedCount = 0
        
        for chunk in chunks.prefix(10) { // Test first 10 chunks
            if chunk.toBinaryPayload() != nil {
                encodedCount += 1
            }
        }
        
        let encodingTime = Date().timeIntervalSince(encodingStartTime)
        XCTAssertEqual(encodedCount, 10)
        XCTAssertLessThan(encodingTime, 0.1, "Encoding 10 chunks should be very fast")
    }
    
    // MARK: - Error Handling Tests
    
    func testMalformedProtocolData() {
        // Test with random data
        let randomData = Data((0..<100).map { _ in UInt8.random(in: 0...255) })
        
        XCTAssertNil(FILE_MANIFEST.fromBinaryPayload(randomData))
        XCTAssertNil(FILE_CHUNK.fromBinaryPayload(randomData))
        XCTAssertNil(FILE_ACK.fromBinaryPayload(randomData))
    }
    
    func testCorruptedChunkData() {
        let originalData = Data("Original chunk data".utf8)
        let chunk = FILE_CHUNK(
            fileID: "corruption-test",
            chunkIndex: 0,
            payload: originalData
        )
        
        // Corrupt the payload
        let corruptedData = Data("Corrupted chunk data".utf8)
        let corruptedChunk = FILE_CHUNK(
            fileID: chunk.fileID,
            chunkIndex: chunk.chunkIndex,
            payload: corruptedData
        )
        
        // Hashes should be different
        XCTAssertNotEqual(chunk.chunkHash, corruptedChunk.chunkHash)
    }
    
    // MARK: - Boundary Tests
    
    func testEmptyFileTransfer() {
        let emptyData = Data()
        let fileHash = SHA256.hash(data: emptyData).compactMap { String(format: "%02x", $0) }.joined()
        
        let manifest = FILE_MANIFEST(
            fileID: "empty-file-test",
            fileName: "empty.txt",
            fileSize: 0,
            sha256Hash: fileHash,
            senderID: "sender-empty"
        )
        
        XCTAssertEqual(manifest.totalChunks, 0)
        
        // Empty file should have complete ACK immediately
        let ack = FILE_ACK(
            fileID: manifest.fileID,
            receiverID: "receiver-empty",
            acknowledgedChunks: [],
            totalChunks: 0
        )
        
        XCTAssertTrue(ack.transferComplete)
    }
    
    func testSingleByteFile() {
        let singleByteData = Data([0x42])
        let fileHash = SHA256.hash(data: singleByteData).compactMap { String(format: "%02x", $0) }.joined()
        
        let manifest = FILE_MANIFEST(
            fileID: "single-byte-test",
            fileName: "single.bin",
            fileSize: 1,
            sha256Hash: fileHash,
            senderID: "sender-single"
        )
        
        XCTAssertEqual(manifest.totalChunks, 1)
        
        let chunk = FILE_CHUNK(
            fileID: manifest.fileID,
            chunkIndex: 0,
            payload: singleByteData,
            isLastChunk: true
        )
        
        XCTAssertEqual(chunk.payload.count, 1)
        XCTAssertTrue(chunk.isLastChunk)
    }
}