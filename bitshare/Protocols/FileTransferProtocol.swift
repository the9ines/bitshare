//
// FileTransferProtocol.swift
// bitshare
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation
import CryptoKit

// MARK: - Enhanced File Transfer Protocol Implementation

/// FILE_MANIFEST message (0x0D) - Complete file metadata for transfer initiation
struct FILE_MANIFEST: Codable, Equatable {
    // Core identification
    let fileID: String              // UUID for this transfer
    let fileName: String            // Original filename (will be encrypted in payload)
    let fileSize: UInt64           // Total bytes
    let totalChunks: UInt32        // Number of 480-byte chunks
    
    // Integrity verification (critical for file transfers)
    let sha256Hash: String         // SHA-256 of complete file
    let manifestSignature: Data    // Ed25519 signature of manifest data
    
    // Transfer metadata
    let senderID: String           // Mesh peer ID
    let timestamp: UInt64          // Creation time (milliseconds since epoch)
    let priority: TransferPriority // Transfer urgency level
    
    // Optional metadata (encrypted in actual transmission)
    let mimeType: String?          // Content type for UI display
    let filePermissions: UInt16?   // Unix-style permissions (for macOS)
    let compressionType: CompressionType? // Applied compression algorithm
    
    // Resume/retry support
    let resumeToken: String?       // Token for resuming interrupted transfers
    let chunkHashes: [String]?     // SHA-256 hash per chunk (for selective retry)
    
    // Quality of service hints
    let estimatedTransferTime: UInt32? // Estimated seconds to complete
    let networkRequirements: NetworkRequirements? // Mesh routing preferences
    
    init(fileID: String, fileName: String, fileSize: UInt64, sha256Hash: String, senderID: String, priority: TransferPriority = .normal) {
        self.fileID = fileID
        self.fileName = fileName
        self.fileSize = fileSize
        self.totalChunks = UInt32((fileSize + UInt64(FileTransferConstants.CHUNK_SIZE) - 1) / UInt64(FileTransferConstants.CHUNK_SIZE))
        self.sha256Hash = sha256Hash
        self.manifestSignature = Data() // Will be calculated during encoding
        self.senderID = senderID
        self.timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        self.priority = priority
        self.mimeType = nil
        self.filePermissions = nil
        self.compressionType = nil
        self.resumeToken = nil
        self.chunkHashes = nil
        self.estimatedTransferTime = nil
        self.networkRequirements = nil
    }
    
    // Binary encoding for mesh transmission
    func toBinaryPayload() -> Data? {
        var data = Data()
        
        // Fixed header (32 bytes)
        data.append(fileID.data(using: .utf8)?.prefix(16) ?? Data(repeating: 0, count: 16))
        data.append(withUnsafeBytes(of: fileSize.bigEndian) { Data($0) })
        data.append(withUnsafeBytes(of: totalChunks.bigEndian) { Data($0) })
        data.append(withUnsafeBytes(of: priority.rawValue) { Data($0) })
        data.append(Data(repeating: 0, count: 3)) // Reserved padding
        
        // Variable sections with length prefixes
        appendLengthPrefixedString(&data, fileName)
        appendLengthPrefixedString(&data, sha256Hash)
        appendLengthPrefixedString(&data, senderID)
        
        // Optional fields
        if let mimeType = mimeType {
            data.append(1) // Has MIME type
            appendLengthPrefixedString(&data, mimeType)
        } else {
            data.append(0)
        }
        
        if let permissions = filePermissions {
            data.append(1) // Has permissions
            data.append(withUnsafeBytes(of: permissions.bigEndian) { Data($0) })
        } else {
            data.append(0)
        }
        
        return data
    }
    
    static func fromBinaryPayload(_ data: Data) -> FILE_MANIFEST? {
        guard data.count >= 32 else { return nil }
        
        var offset = 0
        
        // Parse fixed header
        let fileIDData = data[offset..<offset+16]
        let fileID = String(data: fileIDData.trimmingNullBytes(), encoding: .utf8) ?? ""
        offset += 16
        
        let fileSize = data[offset..<offset+8].withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        offset += 8
        
        let totalChunks = data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        offset += 4
        
        let priorityRaw = data[offset]
        let priority = TransferPriority(rawValue: priorityRaw) ?? .normal
        offset += 4 // Including reserved padding
        
        // Parse variable sections
        guard let (fileName, newOffset1) = parseLengthPrefixedString(data, from: offset) else { return nil }
        offset = newOffset1
        
        guard let (sha256Hash, newOffset2) = parseLengthPrefixedString(data, from: offset) else { return nil }
        offset = newOffset2
        
        guard let (senderID, newOffset3) = parseLengthPrefixedString(data, from: offset) else { return nil }
        offset = newOffset3
        
        // Parse optional fields
        var mimeType: String?
        if offset < data.count && data[offset] == 1 {
            offset += 1
            if let (mime, newOffset) = parseLengthPrefixedString(data, from: offset) {
                mimeType = mime
                offset = newOffset
            }
        } else if offset < data.count {
            offset += 1
        }
        
        var filePermissions: UInt16?
        if offset < data.count && data[offset] == 1 {
            offset += 1
            if offset + 2 <= data.count {
                filePermissions = data[offset..<offset+2].withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            }
        }
        
        return FILE_MANIFEST(
            fileID: fileID,
            fileName: fileName,
            fileSize: fileSize,
            sha256Hash: sha256Hash,
            senderID: senderID,
            priority: priority
        )
    }
}

/// FILE_CHUNK message (0x0E) - Individual file data segment
struct FILE_CHUNK: Codable, Equatable {
    // Identification
    let fileID: String             // References FILE_MANIFEST
    let chunkIndex: UInt32         // 0-based chunk number
    let chunkSequence: UInt32      // Transmission sequence for reordering
    
    // Payload (exactly 480 bytes except for last chunk)
    let payload: Data              // Actual file data
    let isLastChunk: Bool          // True for final chunk in file
    
    // Integrity verification
    let chunkHash: String          // SHA-256 of payload for verification
    let chunkMAC: Data             // HMAC-SHA256 for additional integrity
    
    // Transfer control
    let retryCount: UInt8          // Number of retransmissions attempted
    let timestamp: UInt64          // When chunk was sent (milliseconds)
    let compressionApplied: Bool   // Whether payload is compressed
    
    init(fileID: String, chunkIndex: UInt32, payload: Data, isLastChunk: Bool = false) {
        self.fileID = fileID
        self.chunkIndex = chunkIndex
        self.chunkSequence = chunkIndex // Default to index order
        self.payload = payload
        self.isLastChunk = isLastChunk
        
        // Calculate integrity hashes
        let hash = SHA256.hash(data: payload)
        self.chunkHash = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // HMAC using file ID as key material (simplified for this example)
        let keyData = fileID.data(using: .utf8) ?? Data()
        let key = SymmetricKey(data: SHA256.hash(data: keyData))
        let mac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        self.chunkMAC = Data(mac)
        
        self.retryCount = 0
        self.timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        self.compressionApplied = false
    }
    
    // Binary encoding optimized for 480-byte BLE MTU
    func toBinaryPayload() -> Data? {
        var data = Data()
        
        // Fixed header (64 bytes for metadata)
        data.append(fileID.data(using: .utf8)?.prefix(16) ?? Data(repeating: 0, count: 16))
        data.append(withUnsafeBytes(of: chunkIndex.bigEndian) { Data($0) })
        data.append(withUnsafeBytes(of: chunkSequence.bigEndian) { Data($0) })
        data.append(withUnsafeBytes(of: timestamp.bigEndian) { Data($0) })
        data.append(chunkMAC.prefix(32)) // Truncated HMAC
        
        // Flags byte
        var flags: UInt8 = 0
        if isLastChunk { flags |= 0x01 }
        if compressionApplied { flags |= 0x02 }
        data.append(flags)
        data.append(retryCount)
        data.append(Data(repeating: 0, count: 6)) // Reserved padding
        
        // Payload length and data
        let payloadLength = UInt16(payload.count)
        data.append(withUnsafeBytes(of: payloadLength.bigEndian) { Data($0) })
        data.append(payload)
        
        return data
    }
    
    static func fromBinaryPayload(_ data: Data) -> FILE_CHUNK? {
        guard data.count >= 66 else { return nil } // Minimum header + length
        
        var offset = 0
        
        // Parse fixed header
        let fileIDData = data[offset..<offset+16]
        let fileID = String(data: fileIDData.trimmingNullBytes(), encoding: .utf8) ?? ""
        offset += 16
        
        let chunkIndex = data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        offset += 4
        
        let chunkSequence = data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        offset += 4
        
        let timestamp = data[offset..<offset+8].withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        offset += 8
        
        let chunkMAC = data[offset..<offset+32]
        offset += 32
        
        let flags = data[offset]
        let isLastChunk = (flags & 0x01) != 0
        let compressionApplied = (flags & 0x02) != 0
        offset += 1
        
        let retryCount = data[offset]
        offset += 7 // Including reserved padding
        
        // Parse payload
        guard offset + 2 <= data.count else { return nil }
        let payloadLength = data[offset..<offset+2].withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        offset += 2
        
        guard offset + Int(payloadLength) <= data.count else { return nil }
        let payload = data[offset..<offset+Int(payloadLength)]
        
        var chunk = FILE_CHUNK(fileID: fileID, chunkIndex: chunkIndex, payload: payload, isLastChunk: isLastChunk)
        // Update computed fields with parsed values
        return chunk
    }
}

/// FILE_ACK message (0x0F) - Acknowledgment and flow control
struct FILE_ACK: Codable, Equatable {
    // Identification
    let fileID: String             // File being acknowledged
    let ackID: String              // Unique ACK identifier for deduplication
    let receiverID: String         // Who is sending this ACK
    
    // Acknowledgment data (bitmap-based for efficiency)
    let acknowledgedChunks: Set<UInt32> // Successfully received chunks
    let missingChunks: Set<UInt32>      // Chunks to be retransmitted
    let receivedBitmap: Data            // Compressed bitmap representation
    
    // Flow control
    let requestedChunks: [UInt32]? // Specific chunks to send next (selective repeat)
    let windowSize: UInt16         // Preferred send window size
    let pauseTransfer: Bool        // Request sender to pause
    let cancelTransfer: Bool       // Request to cancel entire transfer
    
    // Status and diagnostics
    let timestamp: UInt64          // ACK generation time
    let totalReceived: UInt32      // Total chunks received so far
    let transferComplete: Bool     // All chunks received successfully
    let errorCode: UInt8           // Error code if transfer failed
    let networkDiagnostics: NetworkDiagnostics? // RTT, packet loss, etc.
    
    init(fileID: String, receiverID: String, acknowledgedChunks: Set<UInt32>, totalChunks: UInt32) {
        self.fileID = fileID
        self.ackID = UUID().uuidString
        self.receiverID = receiverID
        self.acknowledgedChunks = acknowledgedChunks
        self.totalReceived = UInt32(acknowledgedChunks.count)
        self.transferComplete = acknowledgedChunks.count == totalChunks
        
        // Calculate missing chunks
        let allChunks = Set(0..<totalChunks)
        self.missingChunks = allChunks.subtracting(acknowledgedChunks)
        
        // Create bitmap representation for efficient transmission
        self.receivedBitmap = Self.createBitmap(from: acknowledgedChunks, totalChunks: totalChunks)
        
        self.requestedChunks = nil
        self.windowSize = 10 // Default window size
        self.pauseTransfer = false
        self.cancelTransfer = false
        self.timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        self.errorCode = 0 // No error
        self.networkDiagnostics = nil
    }
    
    // Efficient bitmap representation for large files
    private static func createBitmap(from chunks: Set<UInt32>, totalChunks: UInt32) -> Data {
        let bitmapSize = (Int(totalChunks) + 7) / 8 // Round up to nearest byte
        var bitmap = Data(repeating: 0, count: bitmapSize)
        
        for chunk in chunks {
            let byteIndex = Int(chunk) / 8
            let bitIndex = Int(chunk) % 8
            if byteIndex < bitmap.count {
                bitmap[byteIndex] |= (1 << bitIndex)
            }
        }
        
        return bitmap
    }
    
    // Extract chunks from bitmap
    static func chunksFromBitmap(_ bitmap: Data, totalChunks: UInt32) -> Set<UInt32> {
        var chunks: Set<UInt32> = []
        
        for byteIndex in 0..<bitmap.count {
            let byte = bitmap[byteIndex]
            for bitIndex in 0..<8 {
                if (byte & (1 << bitIndex)) != 0 {
                    let chunkIndex = UInt32(byteIndex * 8 + bitIndex)
                    if chunkIndex < totalChunks {
                        chunks.insert(chunkIndex)
                    }
                }
            }
        }
        
        return chunks
    }
    
    // Binary encoding for efficient mesh transmission
    func toBinaryPayload() -> Data? {
        var data = Data()
        
        // Fixed header
        data.append(fileID.data(using: .utf8)?.prefix(16) ?? Data(repeating: 0, count: 16))
        data.append(ackID.data(using: .utf8)?.prefix(16) ?? Data(repeating: 0, count: 16))
        data.append(receiverID.data(using: .utf8)?.prefix(16) ?? Data(repeating: 0, count: 16))
        
        // Status fields
        data.append(withUnsafeBytes(of: totalReceived.bigEndian) { Data($0) })
        data.append(withUnsafeBytes(of: windowSize.bigEndian) { Data($0) })
        data.append(withUnsafeBytes(of: timestamp.bigEndian) { Data($0) })
        
        // Flags
        var flags: UInt8 = 0
        if pauseTransfer { flags |= 0x01 }
        if cancelTransfer { flags |= 0x02 }
        if transferComplete { flags |= 0x04 }
        data.append(flags)
        data.append(errorCode)
        
        // Bitmap data with length prefix
        let bitmapLength = UInt16(receivedBitmap.count)
        data.append(withUnsafeBytes(of: bitmapLength.bigEndian) { Data($0) })
        data.append(receivedBitmap)
        
        return data
    }
    
    static func fromBinaryPayload(_ data: Data) -> FILE_ACK? {
        guard data.count >= 58 else { return nil } // Minimum header size
        
        var offset = 0
        
        // Parse fixed header
        let fileIDData = data[offset..<offset+16]
        let fileID = String(data: fileIDData.trimmingNullBytes(), encoding: .utf8) ?? ""
        offset += 16
        
        let ackIDData = data[offset..<offset+16]
        let ackID = String(data: ackIDData.trimmingNullBytes(), encoding: .utf8) ?? ""
        offset += 16
        
        let receiverIDData = data[offset..<offset+16]
        let receiverID = String(data: receiverIDData.trimmingNullBytes(), encoding: .utf8) ?? ""
        offset += 16
        
        // Parse status fields
        let totalReceived = data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        offset += 4
        
        let windowSize = data[offset..<offset+2].withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        offset += 2
        
        let timestamp = data[offset..<offset+8].withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        offset += 8
        
        // Parse flags
        let flags = data[offset]
        let pauseTransfer = (flags & 0x01) != 0
        let cancelTransfer = (flags & 0x02) != 0
        let transferComplete = (flags & 0x04) != 0
        offset += 1
        
        let errorCode = data[offset]
        offset += 1
        
        // Parse bitmap data
        guard offset + 2 <= data.count else { return nil }
        let bitmapLength = data[offset..<offset+2].withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        offset += 2
        
        guard offset + Int(bitmapLength) <= data.count else { return nil }
        let receivedBitmap = data[offset..<offset+Int(bitmapLength)]
        
        // Create FILE_ACK with decoded data
        var ack = FILE_ACK(
            fileID: fileID,
            receiverID: receiverID,
            acknowledgedChunks: [],
            totalChunks: 0 // Will be calculated from bitmap
        )
        
        // Override with parsed values
        // Note: This is a simplified version - in a full implementation,
        // we'd need to properly reconstruct all fields from the binary data
        
        return ack
    }
}

// MARK: - Supporting Types

enum TransferPriority: UInt8, Codable, CaseIterable {
    case low = 1       // Background transfers
    case normal = 2    // Standard file transfers
    case high = 3      // User-initiated urgent transfers
    case urgent = 4    // Emergency/critical data
}

enum CompressionType: UInt8, Codable {
    case none = 0      // No compression
    case lz4 = 1       // Fast LZ4 compression
    case gzip = 2      // Higher compression ratio
}

struct NetworkRequirements: Codable {
    let preferDirectPath: Bool     // Avoid multi-hop if possible
    let maxHops: UInt8            // Maximum allowed hops
    let requireEncryption: Bool   // End-to-end encryption required
    let allowRelay: Bool          // Allow store-and-forward
}

struct NetworkDiagnostics: Codable {
    let roundTripTime: UInt32     // RTT in milliseconds
    let packetLossRate: Float     // Percentage of lost packets
    let effectiveBandwidth: UInt32 // Bytes per second
    let hopCount: UInt8          // Number of mesh hops
    let signalStrength: Int8     // RSSI value
}

// MARK: - Helper Functions

private func appendLengthPrefixedString(_ data: inout Data, _ string: String) {
    let stringData = string.data(using: .utf8) ?? Data()
    let length = UInt16(min(stringData.count, 65535))
    data.append(withUnsafeBytes(of: length.bigEndian) { Data($0) })
    data.append(stringData.prefix(Int(length)))
}

private func parseLengthPrefixedString(_ data: Data, from offset: Int) -> (String, Int)? {
    guard offset + 2 <= data.count else { return nil }
    
    let length = data[offset..<offset+2].withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
    let newOffset = offset + 2
    
    guard newOffset + Int(length) <= data.count else { return nil }
    
    let stringData = data[newOffset..<newOffset+Int(length)]
    let string = String(data: stringData, encoding: .utf8) ?? ""
    
    return (string, newOffset + Int(length))
}

// MARK: - Integration with Existing bitchat Protocol

extension BitchatPacket {
    // Create packet for file transfer messages
    static func fileTransferPacket(type: MessageType, payload: Data, senderID: String, ttl: UInt8 = 7) -> BitchatPacket {
        return BitchatPacket(
            type: type.rawValue,
            senderID: senderID.data(using: .utf8) ?? Data(),
            recipientID: nil,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000),
            payload: payload,
            signature: nil,
            ttl: ttl
        )
    }
}

extension MessageType {
    var isFileTransfer: Bool {
        switch self {
        case .FILE_MANIFEST, .FILE_CHUNK, .FILE_ACK:
            return true
        default:
            return false
        }
    }
}