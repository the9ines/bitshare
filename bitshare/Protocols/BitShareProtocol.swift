//
// bitshareProtocol.swift
// bitshare
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation
import CryptoKit

// Privacy-preserving padding utilities
struct MessagePadding {
    // Standard block sizes for padding
    static let blockSizes = [256, 512, 1024, 2048]
    
    // Add PKCS#7-style padding to reach target size
    static func pad(_ data: Data, toSize targetSize: Int) -> Data {
        guard data.count < targetSize else { return data }
        
        let paddingNeeded = targetSize - data.count
        
        // PKCS#7 only supports padding up to 255 bytes
        // If we need more padding than that, don't pad - return original data
        guard paddingNeeded <= 255 else { return data }
        
        var padded = data
        
        // Standard PKCS#7 padding
        var randomBytes = [UInt8](repeating: 0, count: paddingNeeded - 1)
        _ = SecRandomCopyBytes(kSecRandomDefault, paddingNeeded - 1, &randomBytes)
        padded.append(contentsOf: randomBytes)
        padded.append(UInt8(paddingNeeded))
        
        return padded
    }
    
    // Remove padding from data
    static func unpad(_ data: Data) -> Data {
        guard !data.isEmpty else { return data }
        
        // Last byte tells us how much padding to remove
        let paddingLength = Int(data[data.count - 1])
        guard paddingLength > 0 && paddingLength <= data.count else { return data }
        
        return data.prefix(data.count - paddingLength)
    }
    
    // Find optimal block size for data
    static func optimalBlockSize(for dataSize: Int) -> Int {
        // Account for encryption overhead (~16 bytes for AES-GCM tag)
        let totalSize = dataSize + 16
        
        // Find smallest block that fits
        for blockSize in blockSizes {
            if totalSize <= blockSize {
                return blockSize
            }
        }
        
        // For very large messages, just use the original size
        // (will be fragmented anyway)
        return dataSize
    }
}

enum MessageType: UInt8 {
    case announce = 0x01
    case keyExchange = 0x02
    case leave = 0x03
    case message = 0x04  // All user messages (private and broadcast)
    case fragmentStart = 0x05
    case fragmentContinue = 0x06
    case fragmentEnd = 0x07
    case channelAnnounce = 0x08  // Announce password-protected channel status
    case channelRetention = 0x09  // Announce channel retention status
    case deliveryAck = 0x0A  // Acknowledge message received
    case deliveryStatusRequest = 0x0B  // Request delivery status update
    case readReceipt = 0x0C  // Message has been read/viewed
    case protocolAck = 0x0D      // Protocol-level ACK for message reliability (Jack's optimization)
    
    // PRD-Specified File Transfer Types (Section 3.2)
    case FILE_MANIFEST = 0x0E    // File metadata with SHA-256 hash
    case FILE_CHUNK = 0x0F       // 480-byte file segments with chunk index
    case FILE_ACK = 0x10         // Chunk acknowledgment for reliability
}

// Special recipient ID for broadcast messages
struct SpecialRecipients {
    static let broadcast = Data(repeating: 0xFF, count: 8)  // All 0xFF = broadcast
}

struct BitchatPacket: Codable {
    let version: UInt8
    let type: UInt8
    let senderID: Data
    let recipientID: Data?
    let timestamp: UInt64
    let payload: Data
    let signature: Data?
    var ttl: UInt8
    
    init(type: UInt8, senderID: Data, recipientID: Data?, timestamp: UInt64, payload: Data, signature: Data?, ttl: UInt8) {
        self.version = 1
        self.type = type
        self.senderID = senderID
        self.recipientID = recipientID
        self.timestamp = timestamp
        self.payload = payload
        self.signature = signature
        self.ttl = ttl
    }
    
    // Convenience initializer for new binary format
    init(type: UInt8, ttl: UInt8, senderID: String, payload: Data) {
        self.version = 1
        self.type = type
        self.senderID = senderID.data(using: .utf8)!
        self.recipientID = nil
        self.timestamp = UInt64(Date().timeIntervalSince1970 * 1000) // milliseconds
        self.payload = payload
        self.signature = nil
        self.ttl = ttl
    }
    
    var data: Data? {
        BinaryProtocol.encode(self)
    }
    
    func toBinaryData() -> Data? {
        BinaryProtocol.encode(self)
    }
    
    static func from(_ data: Data) -> BitchatPacket? {
        BinaryProtocol.decode(data)
    }
}

// Delivery acknowledgment structure
struct DeliveryAck: Codable {
    let originalMessageID: String
    let ackID: String
    let recipientID: String  // Who received it
    let recipientNickname: String
    let timestamp: Date
    let hopCount: UInt8  // How many hops to reach recipient
    
    init(originalMessageID: String, recipientID: String, recipientNickname: String, hopCount: UInt8) {
        self.originalMessageID = originalMessageID
        self.ackID = UUID().uuidString
        self.recipientID = recipientID
        self.recipientNickname = recipientNickname
        self.timestamp = Date()
        self.hopCount = hopCount
    }
    
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> DeliveryAck? {
        try? JSONDecoder().decode(DeliveryAck.self, from: data)
    }
}

// Read receipt structure
struct ReadReceipt: Codable {
    let originalMessageID: String
    let receiptID: String
    let readerID: String  // Who read it
    let readerNickname: String
    let timestamp: Date
    
    init(originalMessageID: String, readerID: String, readerNickname: String) {
        self.originalMessageID = originalMessageID
        self.receiptID = UUID().uuidString
        self.readerID = readerID
        self.readerNickname = readerNickname
        self.timestamp = Date()
    }
    
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> ReadReceipt? {
        try? JSONDecoder().decode(ReadReceipt.self, from: data)
    }
}

// Protocol ACK structure (Jack's optimization for message reliability)
struct ProtocolAck: Codable {
    let originalMessageID: String
    let ackID: String
    let senderID: String  // Who sent the ACK
    let timestamp: Date
    let hopCount: UInt8   // Number of hops the original message traveled
    
    init(originalMessageID: String, senderID: String, hopCount: UInt8 = 0) {
        self.originalMessageID = originalMessageID
        self.ackID = UUID().uuidString
        self.senderID = senderID
        self.timestamp = Date()
        self.hopCount = hopCount
    }
    
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> ProtocolAck? {
        try? JSONDecoder().decode(ProtocolAck.self, from: data)
    }
}

// Delivery status for messages
enum DeliveryStatus: Codable, Equatable {
    case sending
    case sent  // Left our device
    case delivered(to: String, at: Date)  // Confirmed by recipient
    case read(by: String, at: Date)  // Seen by recipient
    case failed(reason: String)
    case partiallyDelivered(reached: Int, total: Int)  // For rooms
    
    var displayText: String {
        switch self {
        case .sending:
            return "Sending..."
        case .sent:
            return "Sent"
        case .delivered(let nickname, _):
            return "Delivered to \(nickname)"
        case .read(let nickname, _):
            return "Read by \(nickname)"
        case .failed(let reason):
            return "Failed: \(reason)"
        case .partiallyDelivered(let reached, let total):
            return "Delivered to \(reached)/\(total)"
        }
    }
}

struct bitshareMessage: Codable, Equatable {
    let id: String
    let sender: String
    let content: String
    let timestamp: Date
    let isRelay: Bool
    let originalSender: String?
    let isPrivate: Bool
    let recipientNickname: String?
    let senderPeerID: String?
    let mentions: [String]?  // Array of mentioned nicknames
    let channel: String?  // Channel hashtag (e.g., "#general")
    let encryptedContent: Data?  // For password-protected rooms
    let isEncrypted: Bool  // Flag to indicate if content is encrypted
    var deliveryStatus: DeliveryStatus? // Delivery tracking
    
    init(id: String? = nil, sender: String, content: String, timestamp: Date, isRelay: Bool, originalSender: String? = nil, isPrivate: Bool = false, recipientNickname: String? = nil, senderPeerID: String? = nil, mentions: [String]? = nil, channel: String? = nil, encryptedContent: Data? = nil, isEncrypted: Bool = false, deliveryStatus: DeliveryStatus? = nil) {
        self.id = id ?? UUID().uuidString
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
        self.isRelay = isRelay
        self.originalSender = originalSender
        self.isPrivate = isPrivate
        self.recipientNickname = recipientNickname
        self.senderPeerID = senderPeerID
        self.mentions = mentions
        self.channel = channel
        self.encryptedContent = encryptedContent
        self.isEncrypted = isEncrypted
        self.deliveryStatus = deliveryStatus ?? (isPrivate ? .sending : nil)
    }
}

protocol BitchatDelegate: AnyObject {
    func didReceiveMessage(_ message: bitshareMessage)
    func didConnectToPeer(_ peerID: String)
    func didDisconnectFromPeer(_ peerID: String)
    func didUpdatePeerList(_ peers: [String])
    func didReceiveChannelLeave(_ channel: String, from peerID: String)
    func didReceivePasswordProtectedChannelAnnouncement(_ channel: String, isProtected: Bool, creatorID: String?, keyCommitment: String?)
    func didReceiveChannelRetentionAnnouncement(_ channel: String, enabled: Bool, creatorID: String?)
    func decryptChannelMessage(_ encryptedContent: Data, channel: String) -> String?
    
    // File Transfer Protocol Methods
    func didReceiveFileManifest(_ manifest: FILE_MANIFEST, from peerID: String, peerNickname: String)
    func didReceiveFileChunk(_ chunk: FILE_CHUNK, from peerID: String)
    func didReceiveFileAck(_ ack: FILE_ACK, from peerID: String)
    
    // Optional method to check if a fingerprint belongs to a favorite peer
    func isFavorite(fingerprint: String) -> Bool
    
    // Delivery confirmation methods
    func didReceiveDeliveryAck(_ ack: DeliveryAck)
    func didReceiveReadReceipt(_ receipt: ReadReceipt)
    func didReceiveProtocolAck(_ ack: ProtocolAck)  // Jack's ACK system
    func didUpdateMessageDeliveryStatus(_ messageID: String, status: DeliveryStatus)
}

// Provide default implementation to make it effectively optional
extension BitchatDelegate {
    func isFavorite(fingerprint: String) -> Bool {
        return false
    }
    
    func didReceiveChannelLeave(_ channel: String, from peerID: String) {
        // Default empty implementation
    }
    
    func didReceivePasswordProtectedChannelAnnouncement(_ channel: String, isProtected: Bool, creatorID: String?, keyCommitment: String?) {
        // Default empty implementation
    }
    
    func didReceiveChannelRetentionAnnouncement(_ channel: String, enabled: Bool, creatorID: String?) {
        // Default empty implementation
    }
    
    func decryptChannelMessage(_ encryptedContent: Data, channel: String) -> String? {
        // Default returns nil (unable to decrypt)
        return nil
    }
    
    func didReceiveDeliveryAck(_ ack: DeliveryAck) {
        // Default empty implementation
    }
    
    func didReceiveReadReceipt(_ receipt: ReadReceipt) {
        // Default empty implementation
    }
    
    func didReceiveProtocolAck(_ ack: ProtocolAck) {
        // Default empty implementation
    }
    
    func didUpdateMessageDeliveryStatus(_ messageID: String, status: DeliveryStatus) {
        // Default empty implementation
    }
}

// MARK: - PRD-Compliant File Transfer Types (Section 3.2)

// PRD: 480-byte chunk size specification for MTU optimization
struct FileTransferConstants {
    static let CHUNK_SIZE: Int = 480        // PRD Section 3.2: 480-byte chunks
    static let MAX_HOPS: UInt8 = 7         // PRD Section 3.1: TTL maximum
}

// PRD: FILE_MANIFEST structure with required metadata
struct FileManifest: Codable, Equatable {
    let fileID: String                     // Unique identifier for transfer
    let fileName: String                   // Original filename
    let fileSize: UInt64                   // Total bytes
    let sha256Hash: String                 // PRD requirement: SHA-256 integrity
    let totalChunks: UInt32               // Based on 480-byte chunks
    let chunkSize: UInt16 = 480           // PRD specification
    let senderID: String                   // File source
    let timestamp: Date                    // Creation time
    let mimeType: String?                  // Content type (optional)
    
    init(fileID: String, fileName: String, fileSize: UInt64, sha256Hash: String, senderID: String, mimeType: String? = nil) {
        self.fileID = fileID
        self.fileName = fileName
        self.fileSize = fileSize
        self.sha256Hash = sha256Hash
        self.totalChunks = UInt32((fileSize + UInt64(FileTransferConstants.CHUNK_SIZE) - 1) / UInt64(FileTransferConstants.CHUNK_SIZE))
        self.senderID = senderID
        self.timestamp = Date()
        self.mimeType = mimeType
    }
    
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> FileManifest? {
        try? JSONDecoder().decode(FileManifest.self, from: data)
    }
}

// PRD: FILE_CHUNK structure with exact payload requirements
struct FileChunk: Codable, Equatable {
    let fileID: String                     // References FileManifest
    let chunkIndex: UInt32                 // 0-based chunk number (PRD requirement)
    let payload: Data                      // Exactly 480 bytes (except last chunk)
    let chunkHash: String                  // SHA-256 of this chunk for integrity
    
    init(fileID: String, chunkIndex: UInt32, payload: Data) {
        self.fileID = fileID
        self.chunkIndex = chunkIndex
        self.payload = payload
        
        // Calculate SHA-256 hash for chunk integrity
        let hash = SHA256.hash(data: payload)
        self.chunkHash = hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> FileChunk? {
        try? JSONDecoder().decode(FileChunk.self, from: data)
    }
}

// PRD: FILE_ACK structure for reliability and retransmission
struct FileChunkAck: Codable, Equatable {
    let fileID: String                     // File being transferred
    let chunkIndex: UInt32                 // Chunk successfully received
    let receiverID: String                 // Who received it
    let timestamp: Date                    // When received
    let ackID: String                      // Unique acknowledgment ID
    
    init(fileID: String, chunkIndex: UInt32, receiverID: String) {
        self.fileID = fileID
        self.chunkIndex = chunkIndex
        self.receiverID = receiverID
        self.timestamp = Date()
        self.ackID = UUID().uuidString
    }
    
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> FileChunkAck? {
        try? JSONDecoder().decode(FileChunkAck.self, from: data)
    }
}

// PRD: Transfer status with progress tracking requirements
enum FileTransferStatus: Codable, Equatable {
    case preparing                         // Calculating hash, chunking
    case transferring(chunksReceived: UInt32, totalChunks: UInt32)  // PRD: specific progress
    case paused(at: UInt32)               // PRD Section 3.2: Resume capabilities
    case completed(fileURL: URL)          // Successful completion
    case failed(reason: String)           // Transfer failure
    case cancelled                        // User cancelled
    
    // PRD requirement: percentage complete calculation
    var percentageComplete: Double {
        switch self {
        case .preparing: return 0.0
        case .transferring(let received, let total):
            guard total > 0 else { return 0.0 }
            return Double(received) / Double(total) * 100.0
        case .paused(let at): return Double(at) / 100.0 * 100.0  // Estimate
        case .completed: return 100.0
        case .failed, .cancelled: return 0.0
        }
    }
    
    var displayText: String {
        switch self {
        case .preparing: return "Preparing transfer..."
        case .transferring(let received, let total):
            return "Transferring: \(received)/\(total) chunks"
        case .paused(let at): return "Paused at chunk \(at)"
        case .completed: return "Transfer complete"
        case .failed(let reason): return "Failed: \(reason)"
        case .cancelled: return "Cancelled"
        }
    }
}